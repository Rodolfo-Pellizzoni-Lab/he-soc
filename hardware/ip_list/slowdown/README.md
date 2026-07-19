# Slowdown IP — memory bandwidth & latency regulator

## What it is, in one sentence

The **slowdown** IP sits on the AXI path between the last-level cache (LLC, via
the SPU) and main memory, and it deliberately makes that memory **slower in two
independent, controllable ways**: it *caps how often* a request may reach memory
(a throughput limit), and it *adds a fixed delay* to every response coming back
(a latency injection). It never changes the data — only the timing.

Why you'd want that: on a multi-core SoC, one core hammering memory can starve
the others. A regulator that meters memory traffic lets you study and enforce
timing predictability — how a core behaves when its memory bandwidth is bounded.

---

## Where it sits

```
        CVA6 cores ── L1 ─┐
                          ├── coherent interconnect ── LLC ──┐
        CVA6 cores ── L1 ─┘                                  │
                                                             ▼
                                                     ┌───────────────┐
                                                     │  axi_spu_top  │  (event monitor,
                                                     │  i_spu_llc_mem│   pure pass-through)
                                                     └───────┬───────┘
                                       slowdown_mem_slv      │  (AXI4)
                                                             ▼
                                              ┌─────────────────────────────┐
                                              │      slowdown_mem_top        │
                                              │  ┌────────────┐  request →   │
                                              │  │ throughput │  AR/AW/W     │
                                              │  │ regulator  │  (throttle)  │
                                              │  └────────────┘              │
                                              │  ┌────────────┐  ← response  │
                                              │  │  latency   │  R/B         │
                                              │  │  injectors │  (delay)     │
                                              │  └────────────┘              │
                                              └──────────────┬──────────────┘
                                       slowdown_mem_mst       │  (AXI4)
                                                              ▼
                                                    main memory (MIG DDR / HyperRAM)
```

Two important integration facts:

- It is enabled by `` `define USE_SLOWDOWN `` in `hardware/host/host_domain.sv`.
  With it defined, the SPU's memory master goes **SPU → slowdown → memory**;
  without it, **SPU → memory** directly (a clean bypass for A/B comparison).
- The LLC only caches a configurable address window (default
  `0x8000_0000..0x8080_0000`). **Traffic outside that window bypasses the LLC and
  therefore never reaches the slowdown.** Software that wants its traffic
  regulated must widen the cached region first (see *Using it from software*).

---

## The two halves of the design

AXI has five channels. They split naturally into a **request path** (master →
memory: AR, AW, W) and a **response path** (memory → master: R, B). The slowdown
treats them separately, because throughput and latency are different knobs.

### 1. Request path → throughput regulation  (`throughput_regulator.sv`)

The idea: **queue every incoming request, and release at most one address to
memory every `Throughput_timer_param` cycles.** That single rule is what caps
bandwidth.

```
        AR in ─▶┌──────────┐                    ┌─────────────┐
                │ ar_fifo  │──┐                 │   shared    │
                └──────────┘  │   ┌──────────┐  │  throttle   │
        AW in ─▶┌──────────┐  ├──▶│ arbiter  │◀─│  (1 addr /  │
                │ aw_fifo  │──┤   │ (1-bit   │  │   period)   │
                └──────────┘  │   │ round-   │  └─────────────┘
        W  in ─▶┌──────────┐  │   │ robin)   │
                │ dw_fifo  │──┘   └────┬─────┘
                └──────────┘          │ grant
                                      ▼
                          ┌───────────────────────┐
                          │  read FSM   write FSM │──▶ AR / AW / W out
                          │  RD_WAIT    WR_WAIT   │
                          │  RD_SEND    WR_SEND   │
                          └───────────────────────┘
```

Key design choices, and *why* each one matters:

- **Reads and writes have separate queues (`ar_fifo`, `aw_fifo`, `dw_fifo`).**
  AXI reads and writes are independent channels. If they shared a queue, a write
  waiting for its data could sit in front of a read and block it. Separate queues
  let reads and writes make progress independently — a stalled write can never
  hold up a read.

- **One shared throttle, and its countdown only starts *after* an accept.** A
  single down-counter (`period_cnt`) gates releases. The exact sequence for one
  request is:

  1. `period_cnt == 0` (elapsed) **and** a request is queued → **grant**: the FSM
     moves `WAIT → SEND` and starts *offering* the FIFO head (drives
     `ARVALID`/`AWVALID`). It does **not** pop the FIFO yet — the head is held
     stable on the bus.
  2. **Hold** until the slave asserts `READY`. While waiting, a `release_pending`
     flag blocks any new grant, and `period_cnt` just **sits at 0 — it is not
     counting**. So if memory back-pressures, we don't burn the period while
     waiting for it.
  3. **Handshake (`VALID & READY`)** → three things happen together: the FIFO
     **pops**, the counter **reloads** to `Throughput_timer_param − 1`, and the
     FSM returns to `WAIT`.
  4. The countdown now runs (`period_cnt` → 0); no new address is offered until it
     reaches 0.

  So "reload on accept" means the counter restarts its countdown **on the
  handshake, never before** — which guarantees consecutive *accepted* requests
  stay `≥ Throughput_timer_param` cycles apart no matter how irregular the
  back-pressure. A 1-bit round-robin bit breaks ties when a read and a write are
  both ready.

  For a write, "the accept" is the **AW (address) handshake**: the counter reloads
  the moment `AWREADY` arrives, and the W beats then drain *without* re-arming the
  throttle. The throttle paces addresses (one AR/AW per period), not data beats —
  so the countdown and a write's W-burst drain run in parallel.

  ```mermaid
  stateDiagram-v2
      [*] --> WAIT
      WAIT --> SEND: period_cnt==0 AND request queued (grant)
      SEND --> SEND: hold VALID, wait for READY (counter frozen at 0)
      SEND --> WAIT: VALID and READY (pop FIFO, reload counter)
  ```

- **A write offers its AW and its W *concurrently* (single `WR_SEND` state).**
  This is the subtle one. AXI4 requires the master to assert `WVALID` *without*
  waiting for `AWREADY`, because a legal slave may wait for `WVALID` before it
  asserts `AWREADY` — if the master also waited for `AWREADY` first, the two would
  wait on each other forever. So the FSM asserts `WVALID` from the first cycle (the
  first W beat is already buffered) and retires the write only when **both** its AW
  is accepted **and** its whole W burst (`AWLEN+1` beats) has drained. A direct
  consequence: a second write's AW can
  **never** be released while the first write's W burst is still draining
  (`grant_write` requires the FSM to be back in `WR_WAIT`), so two W bursts can
  never interleave — which matters because AXI4 has no `WID` to untangle them. If
  the throttle fires mid-drain, that slot can only release a *read* (a different
  channel — always safe).

  The write FSM (single-in-flight, so W bursts can't interleave):

  ```mermaid
  stateDiagram-v2
      [*] --> WR_WAIT
      WR_WAIT --> WR_SEND: grant_write (timer elapsed, aw_fifo and dw_fifo non-empty)
      WR_SEND --> WR_SEND: drive AWVALID and WVALID together; aw_sent on AWREADY, w_done on last W
      WR_SEND --> WR_WAIT: aw_sent AND w_done (AW accepted and whole burst drained)
  ```

  Offering AW and W together works even against a slave that waits for `WVALID`
  before it asserts `AWREADY`:

  ```mermaid
  sequenceDiagram
      participant R as Regulator (master)
      participant M as Store-and-forward slave
      R->>M: AWVALID=1 and WVALID=1 (W already buffered)
      M-->>R: AWREADY=1 (accepts AW after seeing WVALID)
      M-->>R: WREADY=1 (accepts W beats)
      R->>M: remaining W beats ... last
      M-->>R: BVALID (write complete)
  ```

### 2. Response path → latency injection  (`latency_r_chan.sv`, `latency_b_chan.sv`)

The idea: **push each returning response through a `Latency_param`-deep,
handshake-aware shift pipeline.** Every R beat and every B response comes out
exactly `Latency_param` cycles later than it arrived.

```
   memory ──▶  [ stage 0 ][ stage 1 ] ... [ stage L-1 ] ──▶ back to LLC
   R.valid /    (valid + payload shift together, one stage per cycle,
   B.valid       and only shift when the output slot is free or accepted)
```

"Handshake-aware" is the important qualifier: the pipeline only advances when the
downstream is ready (`shift_en = output-slot-empty | ready`), so under
back-pressure it holds beats instead of dropping or duplicating them. The valid
bit and its payload always move together, so a response is never mismatched to
the wrong id/data.

---

## Parameters

| Parameter | Meaning | Platform value |
|---|---|---|
| `Throughput_timer_param` | Min cycles between accepted requests (the bandwidth cap) | `10` |
| `Latency_param` | Cycles of delay added to every R and B response | `20` |
| `Throughput_FIFO_depth` | Depth of each request queue (AR/AW/W) | `8` |

Larger `Throughput_timer_param` → less bandwidth. Larger `Latency_param` → more
latency. They are **RTL parameters** (fixed per bitstream), not runtime registers.

> `Throughput_COUNTER_WIDTH` is a `localparam` derived inside `slowdown_mem_top`
> as `$clog2(Throughput_timer_param + 1)` — do not override it.

---

## Source map

```
src/throughput_regulator.sv   request path: queues + shared throttle + RD/WR FSMs
src/latency_r_chan.sv         response path: R-channel delay pipeline
src/latency_b_chan.sv         response path: B-channel delay pipeline
src/fifo_sync.sv              first-word-fall-through FIFO (AR/AW queues)
src/data_write_fifo.sv        first-word-fall-through FIFO (W beats)
src/slowdown_mem_top.sv       top wrapper + sim-only tracer/checker (see below)
```
(`src/countdown_timer.sv` is an unused leftover — the throttle is a plain counter
inside `throughput_regulator`.)

---

## Using it from software

Two things your program must do for its traffic to actually be regulated:

1. **Widen the LLC cached region** so your working set is cached (and thus routed
   through the slowdown), e.g.:
   ```c
   write_32b(0x1A106000 + 0x1C, 0xA0000000);   // cache 0x8000_0000..0xA000_0000
   ```
2. **Exceed the LLC** with a streaming, cache-line-strided working set, so the LLC
   cannot absorb it and every access becomes a real memory request through the IP.

See the two reference tests:

- **`software/slowdown_qc/`** — 4 cores (2 read + 2 write), disjoint regions
  > LLC. Proves multi-core traffic *flows* correctly and reports per-core
  main-memory request counts. Runs to completion in-system.
- **`software/slowdown_bw/`** — single core. *Measures* the regulation: streaming
  read/write bandwidth (cycles per 64 B line vs. the throttle) and a pointer-chase
  latency probe (cycles per dependent load, carrying the injected latency).

---

## Verifying it

### Standalone unit suite — `test/` (self-contained, Questa)

```
cd hardware/ip_list/slowdown/test
make            # T1–T16 + always-on checks (all AXI corners, random back-pressure)
make t19        # store-and-forward slave: gates AWREADY on WVALID (AXI4 write-dep corner)
make rwtest     # T18: read-behind-stalled-write independence
```
The suite drives millions of transactions with an in-testbench scoreboard that
checks: no dropped/duplicated beats, correct burst lengths, id/data preserved,
throughput spacing honored, exact latency, and AXI valid/payload stability.

### Live observability in the full-platform sim — `trace_slowdown.log`

`slowdown_mem_top.sv` carries a **simulation-only** (`translate_off`, so Vivado
strips it from the bitstream) instrument that makes the regulator observable in a
long platform run, like a core commit trace:

- **`trace_slowdown.log`** (in the sim's working dir): every downstream release
  plus a periodic *full-state heartbeat* — FSM state, throttle counter, FIFO
  occupancy, in-flight counts, and both boundaries' valid/ready.
- **Transcript**: a rare `[slowdown] alive:` liveness beat, and — if the IP is
  ever busy but makes no handshake for a long time — a **loud STALL report** that
  prints the exact upstream/downstream state, so a hang is instantly localized to
  *the software (upstream idle) / memory (downstream not accepting) / the
  regulator itself*, with no guessing.

> Note on a common trap: during the traffic phase the software emits no UART, and
> the regulator throttles to one request per `Throughput_timer_param` cycles, so a
> large working set takes millions of cycles. **A silent sim is not a hung sim** —
> check the heartbeat in `trace_slowdown.log`.

---

## Provenance

Originally developed on branch `esarkar/quad_core/slowdown/opentitan_excluded`,
where these lived as loose files under `hardware/host/`. Moved here under
`ip_list/slowdown/src/`, registered in `hardware/Bender.yml` (before
`host/host_domain.sv`), and instantiated in `host_domain.sv` as `i_slowdown`.

## Status

- Unit suite (T1–T19, 3M+ transactions, all AXI corners, including the
  AWREADY-on-WVALID write-dependency corner): **passing**.
- In-system quad-core traffic (`slowdown_qc`): **runs to completion**, correct
  per-core traffic counts.
- Linux boots on the slowdown bitstream.
