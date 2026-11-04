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
                                              ┌─────────────────────────────┐
                                              │  axi_dram_timing            │  DRAM timing model,
                                              │  i_axi_dram_timing          │  a wire until enabled
                                              └──────────────┬──────────────┘  (0x1A10_6100)
                                                              ▼
                                                    main memory (MIG DDR4 / OpenDRAM)
```

Two important integration facts:

- It is enabled by `` `define USE_SLOWDOWN `` at the top of `hardware/host/host_domain.sv`.
  With it defined, the SPU's memory master goes **SPU → slowdown → DRAM timing model → memory**;
  without it, **SPU → DRAM timing model → memory** (a clean bypass for A/B comparison).
  The DRAM timing model (`hardware/host/axi_dram_timing.sv`, `hardware/docs/dram_model.md`)
  is a wire until software enables it, so with the model off the slowdown is the only
  added delay. The SPU sits before both, so the APMU's memory-side latencies include the
  slowdown's and the model's delays.
- The LLC only caches a configurable address window (default
  `0x8000_0000..0x8080_0000`). Traffic outside that window is not cached, but it still
  leaves through the LLC's memory port (the LLC's bypass mux feeds the same master port),
  so it **does pass through the SPU and the slowdown** — as the L1's own 16-byte (2-beat)
  fills rather than 64-byte line refills. Widen the cached region (see *Using it from
  software*) when you want line-sized memory traffic.

---

## The two halves of the design

AXI has five channels. They split naturally into a **request path** (master →
memory: AR, AW, W) and a **response path** (memory → master: R, B). The slowdown
treats them separately, because throughput and latency are different knobs.

### 1. Request path → throughput regulation  (`throughput_regulator.sv`)

The idea: **queue every incoming request, and release at most one address to
memory every `Throughput_timer_param + 1` cycles** (11 on the platform). That
single rule is what caps bandwidth.

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
  mean a queued write never sits in front of a queued read. They still share the
  one release slot: an address offered downstream and waiting for `READY` holds
  it for both directions (`release_pending`, step 2 below), so a write whose AW
  memory back-pressures holds up the reads until it is accepted (and an AR the
  writes). Behind the DRAM timing model that takes 8 write responses buffered and
  8 more writes outstanding in the model, e.g. a burst of evictions at a large
  `LAT_WR`.

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
  4. The countdown now runs (`period_cnt` → 0, `Throughput_timer_param − 1`
     cycles); a grant needs it at 0, and the granted address goes on the bus one
     cycle after the grant.

  So "reload on accept" means the counter restarts its countdown **on the
  handshake, never before** — which guarantees consecutive *accepted* requests
  stay `≥ Throughput_timer_param + 1` cycles apart (11 on the platform: the
  reload, 9 cycles of countdown, the grant) no matter how irregular the
  back-pressure. A 1-bit round-robin bit breaks ties when a read and a write are
  both ready.

  For a write, "the accept" is the **AW (address) handshake**: the counter reloads
  the moment `AWREADY` arrives, and the W beats then drain *without* re-arming the
  throttle. The throttle paces addresses (one AR/AW per period), not data beats —
  so the countdown and a write's W-burst drain run in parallel.

  ```mermaid
  stateDiagram-v2
      [*] --> WAIT
      WAIT --> SEND: counter at 0 and a request is queued
      SEND --> SEND: hold VALID until the slave asserts READY
      SEND --> WAIT: handshake pops the FIFO and reloads the counter
  ```

- **A 1-bit round-robin arbiter decides *who* takes each throttle slot.** The
  throttle opens the gate once per period; the arbiter picks read-or-write for
  that one slot. `rr_q` (0 favours read, 1 favours write) flips on every grant:

  ```
  grant_read  = gate_open & read_waiting  & (no_write_waiting | rr_q==0)
  grant_write = gate_open & write_waiting & (no_read_waiting  | rr_q==1)
  ```

  - If **only one** side is waiting, it takes every slot (the `rr_q` term is
    bypassed by `no_*_waiting`) — the arbiter never idles a slot or starves the
    busy side.
  - If **both** are waiting, `rr_q` alone breaks the tie (0 → read, 1 → write),
    then flips — so they strictly alternate read, write, read, write, each spaced
    by one throttle period. The two grants are mutually exclusive, so at most one
    release ever happens per period.

  AR and AW never *compete at intake* — they land in separate FIFOs with
  independent `READY`, so a simultaneous AR+AW is not a conflict. They only meet
  here, at the release-side arbiter.

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
      WR_WAIT --> WR_SEND: grant_write
      WR_SEND --> WR_SEND: offer AWVALID and WVALID together
      WR_SEND --> WR_WAIT: AW accepted AND whole W burst drained
  ```

  **Worked example — a *slow* W burst can never let the next AW escape.** Suppose
  the throttle period elapses while W1 is still draining:

  | cycle | `wr_q` | `aw_sent` | `w_done` | `period_cnt` | AW2 released? |
  |---|---|---|---|---|---|
  | AW1 accepted | `WR_SEND` | 1 | 0 | reloads | — |
  | W1 draining slowly | `WR_SEND` | 1 | 0 | counting down | no |
  | counter hits 0, W1 not done | `WR_SEND` | 1 | 0 | **0** | **no** — a grant needs `WR_WAIT` |
  | W1 last beat accepted | `WR_SEND` | 1 | →1 | 0 | — |
  | FSM retires | `WR_WAIT` | 0 | 0 | 0 | **yes, immediately** |

  The counter reaching 0 is *permission, not a trigger* — it never pushes anything
  out. A write is launched only from `WR_WAIT`, so while W1 drains, AW2 simply waits
  in `aw_fifo` and `aw_valid_o` on the downstream bus is 0 (AW1 is already accepted,
  AW2 hasn't started). When W1's last beat lands, the FSM returns to `WR_WAIT` and —
  because the throttle credit is already earned (counter is 0) — AW2 fires at once.
  Memory therefore always sees **AW1 → all of W1 → AW2 → all of W2**, never
  interleaved.

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
| `Throughput_timer_param` | Throttle period: accepted requests are at least `Throughput_timer_param + 1` cycles apart (the bandwidth cap) | `10` (11 cycles) |
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

1. **Widen the LLC cached region** so your working set is cached and reaches memory as
   64-byte line refills (uncached traffic also goes through the slowdown, but as the
   L1's 16-byte fills), e.g.:
   ```c
   write_32b(0x1A106000 + 0x1C, 0xA0000000);   // cache 0x8000_0000..0xA000_0000
   ```
2. **Miss the LLC**: exceed it with a streaming, cache-line-strided working set, or
   flush it (`CfgFlush`, `0x1040_1008` = `0xFFFF`, plus `fence.i` for the L1) before
   each phase, so every access becomes a real memory request through the IP.

See the reference tests (TEST PASS/FAIL and exit code as the soc_tests,
`software/soc_tests/include/soc_test.h`; working sets follow `fpga=1` as in t_sweep):

- **`software/slowdown_qc/`** — 4 cores (2 read + 2 write), disjoint regions
  (> LLC on the board, 4 x 32 KB in RTL sim). Proves multi-core traffic *flows*
  correctly: every core comes up and finishes, and its main-memory read count
  covers its cold misses (per-core attribution at the memory SPU, APMU port 9 with
  four cores).
- **`software/slowdown_st/`** — single core, set-conflict and streaming traffic
  that keeps AR and AW busy for the in-RTL checker; checks the read and write-back
  counts its access pattern forces.
- **`software/slowdown_bw/`** — single core. *Measures* what one main-memory access
  costs: a read stream, a write stream (and the write-back of its dirty lines) and
  a pointer chase, each from flushed caches, with the memory SPU's requests and cycles
  per request of each phase. One core has one data-cache miss in flight, so all of
  them are bound by the miss latency (the chase's cycles per load include the
  injected latency), not by the throttle: they are not bandwidth figures.

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

### Checker and live observability in the full-platform sim

`slowdown_mem_top.sv` carries a **simulation-only** (`translate_off`, so Vivado
strips it from the bitstream) instrument that checks the IP and makes the regulator
observable in a long platform run, like a core commit trace:

- **Checker**: dropped or duplicated beats (in-flight bounds, out never above in),
  AXI valid and payload stability, and downstream addresses closer than
  `Throughput_timer_param + 1` cycles are reported as `[slowdown]` `$error`s (the
  first 20; all are counted). They are procedural checks, not SVA, so they also run
  in the xsim flow, which elaborates with `--ignore_assertions`. A run's verdict
  should fail on them; the end-of-sim summary repeats the count, reports what is
  still inside the IP (an error when nothing moved for 20 000 cycles before the
  end, in flight otherwise) and counts the same-cycle AR+AW intakes, which are legal.
- **`+SLOWDOWN_TRACE=<file>`** (xsim: `-testplusarg SLOWDOWN_TRACE=<file>`): every
  downstream release plus a periodic *full-state heartbeat* — FSM state, throttle
  counter, FIFO occupancy, in-flight counts, and both boundaries' valid/ready. Off
  by default: simulations share the xsim work directory, so give each run its own
  file (e.g. in its run directory).
- **Transcript**: a rare `[slowdown] alive:` liveness beat, and — if the IP is
  ever busy but makes no handshake for a long time — a **loud STALL report** that
  prints the exact upstream/downstream state, so a hang is instantly localized to
  *the software (upstream idle) / memory (downstream not accepting) / the
  regulator itself*, with no guessing.

> Note on a common trap: during the traffic phase the software emits no UART, and
> every miss waits for memory (one request per `Throughput_timer_param + 1` cycles
> at the most), so a large working set takes millions of cycles. **A silent sim is
> not a hung sim** — check the `[slowdown] alive:` beat in the transcript (every
> 200 000 cycles), or the heartbeat in the trace file if you enabled one.

---

## Provenance

First generation developed on branch `esarkar/quad_core/slowdown/opentitan_excluded`
(tip 30835b71; that branch was removed from origin on 2026-10-25), where these lived as
loose files under `hardware/host/`. Fixed and moved under `ip_list/slowdown/src/` on
`es/quad-evu-standalone/slowdown` (20 MHz SoC). Ported onto main on `es/main-slowdown`:
registered in `hardware/Bender.yml` (before `host/host_domain.sv`) and instantiated in
`host_domain.sv` as `i_slowdown`, between the SPU and the DRAM timing model.

## Status

- Unit suite (T1–T19, 3M+ transactions, all AXI corners, including the
  AWREADY-on-WVALID write-dependency corner): **passing**.
- In-system quad-core traffic (`slowdown_qc`): **runs to completion**, correct
  per-core traffic counts.
- Linux boots on the slowdown bitstream.
