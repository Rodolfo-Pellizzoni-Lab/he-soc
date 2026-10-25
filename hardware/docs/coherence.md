# Coherence between the CVA6 L1 data caches and the CCU

How a cached store or load travels through the write-back L1 (`ip_list/cva6/core/cache_subsystem`, the
Culsans variant of CVA6's `std_nbdcache`) and the coherence unit (`ip_list/ace`), what the snoop controller does on
each snoop, which races the controllers guard against, and the one they did not: the store/ReadShared livelock that
hangs Linux with seven or eight cores (hardware/docs/cores.md). Written 2026-10-25 from the RTL and from
interactive-simulation traces of the eight-core library.

## The pieces

**CCU** (`ace_ccu_top.sv`, one instance, `NumCVA6 + 1` slave ports: the cores and the accelerator socket's DMA).
Every core's AXI master goes through an `ace_trs_dec` + `axi_demux` pair: WriteBack and the NoSnoop transactions go
straight to the memory mux, everything shareable (ReadShared, ReadUnique, ReadOnce, CleanUnique, WriteUnique,
atomics) is serialised by an `axi_mux` into **one `ccu_fsm`** that handles **one transaction at a time**:

- read class (`DECODE_R`): a CleanUnique or an LR goes `SEND_INVALID_R` (CleanInvalid snoop to every other port)
  -> `WAIT_INVALID_R` (collect the snoop responses; the R response to the initiator, one beat, no data, is sent in the
  cycle the last response arrives); if a snooped core returned dirty data it is written back to memory first
  (`SEND_AXI_REQ_WRITE_BACK_R`, `WRITE_BACK_MEM_R`). Any other read goes `SEND_READ` (the request's own snoop type to
  every other port) -> `WAIT_RESP_R` -> `READ_SNP_DATA` (forward the first responder's two CD beats as the R data,
  RRESP[3] = IsShared, RRESP[2] = PassDirty) or, if no port has the line, `SEND_AXI_REQ_R` / `READ_MEM`.
- write class (`DECODE_W`): CleanInvalid to every other port, write back dirty data if any, then the write (or the
  atomic) to memory; an ATOP gets its R beat from memory.

The initiator is never snooped (`ac_ready <= initiator_q` in `DECODE_*`). The next transaction is taken in `IDLE`
after the current one is complete, so snoop requests of transaction k+1 are only ever sent after the response of
transaction k has been handed over (three cycles later at the earliest: `IDLE`, `DECODE_R`, `SEND_READ`).
`LatencyMode = CUT_ALL_PORTS` (chosen for 50 MHz FPGA timing) puts a spill register on every channel of the demux
and the mux, so a response leaves the FSM and reaches the core's adapter two cycles later, while the snoop channel
(`slv_snp_req_o`) is wired straight from the FSM to the core.

**L1 data cache** (`std_nbdcache.sv`): one tag/data SRAM with a fixed-priority arbiter (`tag_cmp.sv`): port 0 miss
handler, port 1 snoop controller, ports 2 to 4 the three `cache_ctrl` instances (PTW, load unit, store unit).
Lines are 16 bytes (`DcacheLineWords == 2`) with `valid`, `dirty` (per byte) and `shared` bits.

- `cache_ctrl.sv`: a load or store reads the tags (`WAIT_TAG`). A store hit on a *unique* line (`shared == 0`) goes
  to `STORE_REQ` and writes the data with `shared = 0`, `dirty = 1`. A store hit on a *shared* line goes to
  `MAKE_UNIQUE`: it asks the miss handler for a CleanUnique and waits for `miss_gnt_i`, then `STORE_REQ`. A miss goes
  to the miss handler (`WAIT_REFILL_GNT`, `WAIT_CRITICAL_WORD`).
- `miss_handler.sv`: single MSHR. A refill is a ReadShared (load) or ReadUnique (store, data merged into the line
  on `SAVE_CACHELINE`, installed `shared = 0`). A `MAKE_UNIQUE` request is `SEND_CLEAN`: CleanUnique through the
  miss adapter, `miss_gnt_o` to the cache controller when the response arrives (`valid_miss_fsm`). Atomics are
  memory-side: `AMO_WB` writes a dirty copy back and invalidates the line, then the AMO goes through the bypass
  adapter (CCU write class). `serving_amo_o` covers the local phase only.
- `snoop_cache_ctrl.sv`: accepts a snoop in `IDLE` (unless flushing, or an AMO to the same line is in its local
  phase), reads the tags (`WAIT_GNT`, `EVAL_FLAGS`, holding the SRAM port with priority), then: ReadShared/ReadOnce
  hit -> `UPDATE_SHARED` (sets `shared = 1`, keeps `dirty`, pulses `readshared_done_o`), responds with the two data
  beats, PassDirty forced to 0 (the owner keeps the dirty line); CleanInvalid/ReadUnique hit -> `INVALIDATE`
  (pulses `invalidate_o`), responds with the data if dirty (PassDirty).

**Collision guards** in `cache_ctrl.sv`: `colliding_clean` (a snoop invalidated the line we are about to write:
re-read the tags, or in the miss handler re-fetch as ReadUnique) and `colliding_read` (a ReadShared snoop was
answered while we were in `MAKE_UNIQUE` or `STORE_REQ`: the line is shared again, so `STORE_REQ` goes back to
`MAKE_UNIQUE` and issues the CleanUnique again instead of writing). `updating_cache` keeps the snoop controller from
reading the SRAM while a controller writes a line.

## The store/ReadShared livelock

One core (the writer) stores to a line that the other cores spin-read (Linux's `multi_cpu_stop`, the bare-metal
`soc_tests/t_stopm`). Cycle trace of the eight-core simulation (`sim_session`, 100 MHz simulation clock, the
writer is core 0 on CCU port 0):

1. The writer's line is shared, the store sits in `MAKE_UNIQUE`; its CleanUnique waits at the CCU mux behind the
   readers' ReadShared refills. Each refill snoops the writer, which answers with data and pulses
   `readshared_done`: `colliding_read` is set.
2. The CCU serves the CleanUnique: CleanInvalid to the seven readers, response to the writer. The readers miss
   again at once and queue seven new ReadShared requests.
3. The response reaches the writer's miss handler two cycles later (spill registers), `miss_gnt_i`, `STORE_REQ`.
   The first ReadShared's snoop arrives in the same cycle the controller first asks for the SRAM write port; the
   snoop controller has priority, reads the tags, sets `shared`, pulses `readshared_done`, answers with the old
   data. `STORE_REQ` sees `colliding_read` and goes back to `MAKE_UNIQUE`: go to 1.

With the readers' refills strictly back to back and the writer's retry always queued behind them, the CCU repeats
the identical sequence every 120 cycles, the writer's miss handler is pinned in `SEND_CLEAN`, the readers refill the
old value forever, and the writer sits in the fence after its store. Three spinning readers leave a gap often
enough for the store to land; five to seven do not (board: the replica hangs with six, seven and eight cores,
passes with four; Linux boots with six CPUs most of the time and never with seven or eight).

Two things make the retry policy wrong for this pattern: `colliding_read` counts snoops that were answered
*before* the CleanUnique was performed (harmless: the CleanUnique invalidated those readers again), and a snoop
that arrives between the CleanUnique response and the SRAM write is served first because the snoop controller has
the higher SRAM priority, which makes the store lose that race by construction.

## The change (2026-10-25)

Two parts, both in the L1, both following patterns the controllers already use:

1. `cache_ctrl.sv`, `MAKE_UNIQUE`: when the CleanUnique response arrives (`miss_gnt_i`), `colliding_read` is cleared.
   Every ReadShared answered up to that cycle went to a reader that the CleanUnique has invalidated again, so it
   cannot leave a stale copy behind; a pulse in that very cycle is still kept as a collision. `STORE_REQ` keeps its
   collision detection as the safety net for anything answered after the response.
2. `snoop_cache_ctrl.sv`: a snoop to a line for which a cache controller is in `STORE_REQ`, or in `MAKE_UNIQUE`
   receiving its response, is not accepted until the store has been written (`store_hold_o` /
   `store_hold_addr_o` of each `cache_ctrl`, wired in `std_nbdcache.sv`). This is the same mechanism the snoop
   controller already uses for the local phase of an atomic (`amo_valid_i`). With it, the store cannot lose the
   SRAM race against a snoop that arrives between the response and the write, and the ReadShared that follows the
   store returns the new data.

Why it is safe:

- *Coherence.* A store writes `shared = 0` only in `STORE_REQ`, which it reaches with the line unique: either the tag
  check saw it unique, or its CleanUnique has completed. Between that point and the SRAM write no snoop to the line is
  accepted, so no reader can obtain a copy of the old data that the store would leave valid. A snoop accepted before
  the hold began and still in progress is caught by `STORE_REQ`'s `colliding_read` / `colliding_clean` checks exactly
  as before (one redo, not a loop, since it needs a one-cycle coincidence).
- *No deadlock.* A held snoop stalls the CCU (it waits for every port's `ac_ready`). The hold lasts only while the
  store needs nothing but the local SRAM port: it is never asserted while the CleanUnique is still waiting at the CCU
  (holding then would make the CCU wait for a core whose own request sits behind the held transaction), and it drops
  as soon as the controller leaves `STORE_REQ` for `WAIT_MSHR` (its line's set is being served by the miss handler,
  which may need the CCU) or any other state. The SRAM port is taken from the controller only by the miss handler,
  for single cycles, so the write completes within a few cycles.
- *Ordering.* With `CUT_ALL_PORTS` the response needs three cycles from the CCU to `miss_gnt_i` and the next
  snoop one; the store now writes in the cycle after `miss_gnt_i`, four cycles before that snoop can be accepted.
  Without the spill registers (`NO_LATENCY`) the snoop would arrive in the store's write cycle, which is what the
  hold is for.

## Verification

Simulation (xsim, both libraries recompiled with the change; `software/soc_tests/t_stopm` is the faithful
`multi_cpu_stop` port, ten rounds of four states, a stall report if any core spins 10,000 iterations without a
state change):

| Library | Program | Before | After |
|---|---|---|---|
| 8 cores (`NUM_CVA6=8`) | t_stopm, 8 cores, bare spin (`NO_SIDE_EFFECTS`) | livelock in the first store of round 0 (>1.4 ms simulated, CCU repeating every 120 cycles) | TEST PASS, 10 rounds, 40 advances, first round 0.25 ms, then about 50 us per round |
| 8 cores | t_stopm, 8 cores, with the kernel loop's side effects (a store and an atomic on the core's own line per iteration) | hangs on the board with 6, 7, 8 cores | TEST PASS, 10 rounds, 40 advances, about 80 us per round |
| 4 cores | t_stopm, 4 cores, with the kernel loop's side effects | passes (not affected) | TEST PASS, 20 rounds, 80 advances, about 70 us per round |
| 8 cores | t_smp, t_qos, t_iotag built for 8 cores (contended AMO and LR/SC counters, QoS scoreboard on every refill and write-back, DMA tags) | pass | TEST PASS 82 / 63 / 27 checks |
| 8 cores | soc regression, 4-core builds: t_mem, t_atomics, t_smp, t_irq, t_socket, t_cbqri, t_dram, t_dma, t_eth, hello_culsans, quad_boot | pass | pass (t_qos and t_iotag fail as 4-core builds on 8 cores as before: the tag layout; t_part exceeds the 2 h regression limit on this library and is run alone) |
| 4 cores | soc regression: t_mem, t_atomics, t_smp, t_irq, t_socket, t_qos, t_cbqri, t_dram, t_dma, t_iotag, t_eth, hello_culsans, quad_boot, and t_part alone (3 h 15, 49 ms simulated) | pass | pass, 14 of 14; t_part TEST PASS 202 checks |
| 8 cores | t_part alone, 4-core build, 4 h (44.7 ms simulated, the partition and latency phases) | n/a | only the two QoS-tag checks fail (the 4-core tag layout, as t_qos/t_iotag); the 8-core build runs separately |

Board (VCU118, bitstream `cores8_fix`, eight cores, 2026-10-25): t_stopm built for eight cores runs its 200 rounds
(800 advances, no stall; before: hung with six, seven and eight cores), t_smp / t_qos / t_iotag eight-core builds
pass, and Linux 6.1.183 boots to the shell with eight CPUs three times out of three (111 s), where it never got
past the first `stop_machine` before. Six and four CPUs boot as before. hardware/docs/cores.md has the bandwidth
numbers taken on that system.
