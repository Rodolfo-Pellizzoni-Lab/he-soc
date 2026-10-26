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
| 8 cores | t_part alone, 4-core build, 4 h (44.7 ms simulated, the partition and latency phases) | n/a | only the two QoS-tag checks fail (the 4-core tag layout, as t_qos/t_iotag) |
| 8 cores | t_part alone, 8-core build (3 h 46, 49.5 ms simulated) | n/a | TEST PASS 202 checks, no CHECK FAIL |

Board (VCU118, bitstream `cores8_fix`, eight cores, 2026-10-25): t_stopm built for eight cores runs its 200 rounds
(800 advances, no stall; before: hung with six, seven and eight cores), t_smp / t_qos / t_iotag eight-core builds
pass, and Linux 6.1.183 boots to the shell with eight CPUs three times out of three (111 s), where it never got
past the first `stop_machine` before. Six and four CPUs boot as before. hardware/docs/cores.md has the bandwidth
numbers taken on that system.

## The refill / snoop-write race (2026-10-26)

Found with the decoupled CCU (`ccu_fsm` DecoupledReads, hardware/docs/ccu_model.md): under load on the VCU118 single
8-byte words came back with the previous round's value, always the word whose store had missed, never its
neighbour stored a few cycles later as a hit (cores.md). The serial CCU was clean under the same stress.

### What happens

The snoop controller serves a snoop in four steps on the single SRAM port: it reads the set (`WAIT_GNT`, the cycle it
is granted), evaluates the tags one cycle later and latches `hit_way_q`, `dirty_way_q`, `shared_way_q` and the data
(`EVAL_FLAGS`), then writes the status of that way (`UPDATE_SHARED`: valid, shared = 1, dirty as it was;
`INVALIDATE`: valid = 0) one or more cycles later, with `be_o.vldrty[hit_way_q]` and without looking at the tag again.
The miss handler's refill (`SAVE_CACHELINE`) writes tag, data and status of its victim way in the single cycle the
line arrives, and has priority on the port. If that cycle falls between the snoop's read and its write, and the
victim way is the way the snoop hit, the snoop's write lands on the new line:

- the victim was a clean shared line Y (a clean victim stays valid until the refill overwrites it; a dirty one is
  invalidated when its write-back completes, `INVALIDATE_ON_FLUSH`), another core requests Y, the snoop hits Y in
  way W and decides its response from Y;
- the refill of line X lands in W with the missed store merged into it (`mshr_q.we`), dirty bits set for the stored
  bytes, `shared = 0`;
- `UPDATE_SHARED` (the other core's ReadShared) then writes W as valid, shared, dirty = 0 (Y was clean): the stored
  bytes are no longer dirty. The next store to the line finds it shared, goes through a CleanUnique and writes its
  own bytes dirty; the eventual write-back carries strobes for those bytes only, and the first store's word stays
  at its old value in the LLC. `INVALIDATE` (a CleanUnique or ReadUnique) drops the whole line with the merged store;
  the next store to the line misses, refills the old line and merges only itself.

Both leave exactly one stale word per event: the one merged into the refill. The race needs a snoop *hit* while a
refill is pending, which is why a stress on private buffers (every snoop misses) is clean and Linux (kernel data
shared by all CPUs) is not, and why one hart never fails. With the serial CCU the snoop round of the next transaction
could only start after the fsm had delivered the last beat of the refill, so the snoop's read was always at least
one cycle after the refill write (`updating_cache_i` covers the remaining one-cycle case); the decoupled CCU runs
other cores' snoop rounds while a core's read is in flight.

### Reproducer

`software/soc_tests/t_chk` with `-DCHK_SHARED`: every core streams through its private region and touches one line
of a 32 KB array shared by all cores per private line, so clean shared lines sit in every L1 and get evicted by the
private refills while the other cores snoop them. On the VCU118 (eight cores, 40 rounds of 512 KB, bare metal over
JTAG, 20 s): private regions only, 0 bad words in 84 M; CHK_SHARED=1 (one in eight shared accesses a store), 22 to
4868 bad words per core; CHK_SHARED=2 (shared lines only loaded: only ReadShared snoops hit) 22 to 882 bad per core;
CHK_SHARED=3 (only stored: the shared lines are dirty in their owner and die at their write-back) 0 bad. Linux
`chk` found about one bad word per 5 M on the same bitstream; the bare-metal reproducer makes it a 20-second test.

### The fix

`miss_handler.sv` reports its refill writes (`refill_req_o`, the only writes with the tag byte enables set, at the
address it already reports for invalidations); `snoop_cache_ctrl.sv` collects, from its lookup on, the refills into
the set it looked up (`miss_refill_req_q`, cleared in `IDLE` and `WAIT_GNT` like `miss_invalidate_req_q`) and, in
`UPDATE_SHARED` and `INVALIDATE`, skips the status write when one of them hit `hit_way_q`: the way holds another
line now, there is nothing to mark shared or to invalidate. The response already decided stands: the data was read
while Y was valid and clean (or, during a dirty victim's write-back, equal to memory), and Y is gone from this cache
either way. `readshared_done_o` is not pulsed in that case (no line was marked shared). `std_nbdcache.sv` wires the
signal and carries a simulation-only monitor (`MON SNOOP WRITE RACE`) that reports a snoop status write on a way
refilled since the lookup.

### Verification

Simulation, libraries recompiled with the fix:

| Library | Program | Result |
|---|---|---|
| 8 cores | t_stopm (8 cores, 10 rounds x 4 states), t_smp, t_qos, t_iotag, t_atomics, 8-core builds | TEST PASS 17 / 82 / 63 / 27 / 24 checks |
| 4 cores | t_chk CHK_SHARED=2, one round (12 ms simulated) | TEST PASS, 0 bad; the monitor saw refills land in a snooped set about 100 times per ms and, three times, on the way the snoop had hit (core 0, `UPDATE_SHARED`): the writes the fix skips |
| 4 cores (second library, rpsrvr1) | t_chk CHK_SHARED=2, three rounds (33 ms simulated, 357 refills into snooped sets, two on the snoop's hit way) | TEST PASS, 0 bad |
| 4 cores | soc regression: t_mem, t_atomics, t_smp, t_irq, t_socket, t_qos, t_cbqri, t_dram, t_dma, t_iotag, t_eth, hello_culsans, quad_boot | 13 of 13 pass (t_part exceeds the 2 h regression limit as always and runs alone) |
| 8 cores | soc regression, 4-core builds | 11 of 11 pass; t_qos and t_iotag fail exactly as before the fix (the 4-core tag layout on 8 cores, identical CHECK FAIL lines; their 8-core builds pass above); t_part exceeds the regression limit as always |
| 8 cores | t_part alone, 8-core build (the LLC way partitioning, QoS tags and latency under load; 4 h) | TEST PASS 202 checks, every scenario's hop times and LLC misses within a few percent of the run before the fix (e.g. S: 532 vs 537 misses) |
| 4 cores, unfixed cache controllers + the monitor (control, same server and library as the three-round run above) | t_chk CHK_SHARED=2, three rounds | TEST FAIL: core 0 28 bad words, core 1 4, every one at offset 0 of its line with the neighbour intact; the monitor reports 18 snoop status writes landing on refilled ways (all `UPDATE_SHARED`, 17 on core 0, 1 on core 1: the two cores with bad words; a verify pass counts a lost word up to four times, and a race on a clean line loses nothing). With the fix, same test, same library: TEST PASS, 0 bad |
| 4 cores, unfixed library (control) | t_chk CHK_SHARED=1, one round (11.6 ms simulated) | TEST PASS, 0 bad: one round is too short for the same-way coincidence (the 8-core library stalls the simulator about 1 ms into t_chk, fixed or not); the board shows it thousands of times in 20 s |

| 4 cores | t_part alone (3 h, 49 ms simulated) | TEST PASS 202 checks |
| 4 cores | t_stopm | TEST PASS 9 checks |

Board (VCU118, bitstream `cores8_fix2_r1`: the fix on the eight-core decoupled-CCU design, built on rpsrvr1; setup
is met everywhere but 37 endpoints of the Ethernet SGMII serdes at -1.03 ns, hold only in the known adv_timer /
uDMA classes; Ethernet still works: t_eth passes and Linux netboots), 2026-10-26:

| Program | `cores8_dec3` (before) | `cores8_fix2_r1` (after) |
|---|---|---|
| t_chk CHK_SHARED=2 (shared lines loaded only), 8 cores x 40 rounds x 512 KB | 22 to 882 bad words per core | 0 bad on all eight cores |
| t_chk CHK_SHARED=1 (one shared access in eight a store) | up to 4868 bad per core | 0 bad |
| t_chk CHK_MODE=2 + CHK_SHARED=1 (fence.i flush and refetch) | 2 to 136 bad per core | 0 bad |
| t_chk private regions only | 0 bad | 0 bad |
| t_stopm / t_smp / t_qos / t_iotag, 8-core builds | pass | TEST PASS 17 / 82 / 63 / 27 checks |
| soc suite (4-core builds) | - | 9 pass; t_qos, t_iotag and t_part fail only their QoS-tag checks (the 4-core tag layout on 8 cores, as in simulation); t_eth 37 checks |
| Linux 6.1.183, 8 CPUs, Ethernet boot | shell in 85 s | shell in 85 s (three boots) |
| Linux `chk`, 8 harts x 4 MiB x 20 rounds (the stress that found the bug) | 6 to 14 bad words per hart on 6 of 8 harts | 0 bad on all 8 harts (42 M words each, 75 s) |
| Linux `chk` with a read-back of every stored word, 8 harts x 10 rounds | Linux hung within 5 minutes (no console, no network) | 0 bad, 40 s, Linux fine |
| Linux bandwidth sweep, 8 harts (cores.md) | DRAM reads 82 MB/s, LLC hits 83, writes 58 | 82.4 / 82.5 / 58.2 MB/s, memcpy 68.7; 7 harts 76.7: the fix costs nothing |
