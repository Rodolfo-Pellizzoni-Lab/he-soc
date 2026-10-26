# The coherent memory path: measurements, model and the decoupled CCU

The eight-core work (cores.md) ended with the coherence unit as the bottleneck: four to eight harts together stream
at 15 to 17 MB/s at 50 MHz, one 16-byte line every 46 to 52 cycles, whatever the core count. This note measures
where those cycles go, fits a cycle-level model to the measurements, uses the model to rank the remedies, and
describes the one implemented: the CCU state machine no longer waits for the LLC's response.

## Measuring: t_bw

`software/soc_tests/t_bw` streams misses from 1, 2, 4 and 8 harts at once and reports cycles per 16-byte line.
Every hart owns 256 lines (4 KB) of cached DRAM, far below the 16 KB L1; before each window every hart flushes
its L1 with `fence.i` (a plain `fence` does not flush a coherent CVA6 cache: `controller.sv` skips the flush when
`DCACHE_COHERENT`), so each access misses L1 once and hits the LLC, which the warm-up filled. Harts that do not
take part spin on a cached flag (L1 hits, no coherence traffic). Three modes:

- `rd`: loads of the own region: a ReadShared per line, data from the LLC;
- `wr`: stores to the own region: a ReadUnique per line, data from the LLC; the next `fence.i` then writes the
  256 dirty lines back (`wb`, timed as that fence);
- `sh`: all active harts read hart 0's region: the first miss fetches the line from the LLC, the other harts get
  it from that L1 through the snoop channel (`READ_SNP_DATA`).

`[BW] k=<harts> <mode> aggregate: <lines> lines in <cycles> cycles = <cycles/line>, <B/kcycle>` lines come out
at the end, one per phase, plus per-hart lines. The same binary runs on the board (`sw_build ... fpga=1`).

## Where one read goes: the cycle trace

sim_session traces of one hart streaming (4-core library, `scratchpad ccu/trace_k1rd.txt`, `trace_k1wr.txt`):
the period is 43 cycles per line, the same for ReadShared and ReadUnique.

| cycles | where |
|---|---|
| 2 | AR from the core's CCU port to the state machine (demux spill register, mux spill register) |
| 2 | IDLE sees the request, DECODE_R, SEND_READ |
| 5 | snoop round: AC accepted by the three other L1s in 1 cycle, their CR after 3 (WAIT_GNT, EVAL_FLAGS, SEND_CR_RESP), one state |
| 1 | SEND_AXI_REQ_R: AR accepted by the outer mux |
| 24 | AR leaves the CCU → first R beat back: 9 cycles to the LLC's port, 6 in the LLC, 9 back |
| 3 | second beat, READ_MEM → IDLE |
| 2 | R from the state machine to the core's port (mux spill, demux spill) |
| 5 | core: refill written, load replayed, next load misses, next AR |

The state machine is busy 34 of the 43 cycles and spends 27 of them waiting in READ_MEM. With four harts
streaming (`trace_k4rd.txt`) its period is exactly 35 cycles: one IDLE cycle, then the same 2 + 5 + 1 + 27, the
initiators served round robin and the snoop round still 5 cycles, so the snooped L1s are not slowed by their own
refills. The 18 cycles of
interconnect between the CCU and the LLC are the crossbar with spill registers on every port (`AXI_XBAR_CFG`
LatencyMode `CUT_ALL_PORTS`, an FPGA-timing choice, originally `NO_LATENCY`), the atomics adapter and an
`axi_cut` in front of the LLC; the CCU's own `CUT_ALL_PORTS` adds the 2 + 2 cycles on the core side.

Write-backs do not go through the state machine: `ace_trs_dec` routes WriteBack (AWSNOOP 011) to the
non-shareable path. The miss handler writes one dirty line at a time and waits for B (`trace_k1wb.txt`): AW and
W leave the core's port, 2 cycles to the CCU's master port, 9 to the LLC, 6 for the LLC's B, 9 back, 2 to the
core, 7 in the flush state machine before the next AW: 34 cycles per written-back line for one hart. The shared
write path takes one 16-byte write per 25 cycles when four harts flush at once (fence times 35 / 67 / 99 / 67
cycles per line for the four harts), so flushing dirty data is bounded by the write path, not by the CCU.

## The model

`scratchpad ccu/ccu_model.py` (copied to `hardware/docs/ccu_model.py`) is a discrete-event model of N cores with a
blocking miss path, the state machine, the snoop round and the memory path, driven by the latencies above. It
reproduces the measurements of the unchanged design (xsim, 4 cores, cycles per 16-byte line):

| | 1 hart | 2 harts | 4 harts | 8 harts |
|---|---|---|---|---|
| rd, measured, 4 cores (t_bw) | 48 (43 steady state) | 35 | 35 | |
| rd, measured, 8 cores | 50 | 36 | 36 | 35 |
| rd, model | 43 | 35 | 35 | 35 |
| wr (ReadUnique), measured, 4 / 8 cores | 43 / 46 | 34 / 36 | 34 / 35 | 34 |
| sh, measured, 4 / 8 cores | 48 / 51 | 25 / 26 | 17 / 18 | |
| sh, model | 43 | 23.5 | 17.8 | |

(The t_bw window includes the first miss and the instruction fetches after `fence.i`, hence 48 against the
43-cycle steady state; the eight-core SoC snoops seven ports instead of three and adds a cycle.)

With more than one hart the aggregate is the state machine's occupancy, 35 cycles per transaction (34 busy +
1 idle), no matter how many harts ask. The model's variants:

| variant | what changes | rd aggregate at 4 harts (cycles/line) |
|---|---|---|
| base | the design as measured | 35 |
| decouple | the memory read leaves the state machine when its AR is accepted; responses return by AXI id | 10.8 |
| decouple + snoop filter | lines no other L1 holds skip the snoop round | 9.5 |
| spec | memory read issued together with the snoop round | 30 |
| ccu_nocut | CCU LatencyMode NO_LATENCY | 37 (latency 39) |
| xbar_nocut | crossbar LatencyMode NO_LATENCY | 31 (latency 39) |
| decouple + both nocut | | 9.0 (latency 35) |

Decoupling the memory phase is the only change that moves the aggregate by more than a few percent, because it
turns the 27-cycle wait into overlap: the serial part left is 9 cycles (IDLE, DECODE_R, the 5-cycle snoop round,
the AR issue, back to IDLE). Removing spill registers trims latency (43 → 35 for one hart) but not throughput.
Speculative memory reads save the snoop round's 5 cycles only. A snoop filter would cut the serial part further
but needs a directory of what every L1 holds.

## The change: DecoupledReads in ccu_fsm.sv

`ip_list/ace/src/ccu_fsm.sv`, parameters `DecoupledReads` (default 1; 0 restores the old behaviour) and
`NumInflight` (8):

- a read that has to go to memory (ReadShared, ReadUnique, ReadOnce with no L1 answering) leaves the state
  machine as soon as the outer mux accepts its AR: `SEND_AXI_REQ_R → IDLE` instead of `READ_MEM`. LR (`ar.lock`),
  the read half of an AMO and a read when the table is full still wait in `READ_MEM`, which now ends on the last
  beat of its own id;
- the memory R beats pass through to the inner mux whenever the state machine is not sending R beats of its own
  (`own_r`: `WAIT_INVALID_R`'s CleanUnique response and `READ_SNP_DATA`); the mux routes them to the initiator by
  the port bits in the id, as it always did for `READ_MEM`;
- an in-flight table holds the line address and id of every read handed over; a new AR or AW to one of those
  lines is not taken from IDLE until that read's last beat has passed (`ar_take` / `aw_take`). That keeps the
  protocol's serialisation per line: no snoop can reach a cache for a line whose data is still on its way to it.

Nothing changes for the L1s or the snoop channel; write-backs were never in the state machine.

Three details the first version got wrong, all caught by the regression (t_atomics, t_smp and t_qos hung after
their first atomic; t_eth lost one frame in 33 checks):

- the read half of an atomic (`aw.atop[5]`): the old `WRITE_MEM → READ_MEM` waited for the AMO's R after B, but
  with the pass-through on in `WRITE_MEM` that R may already have gone to the core before B arrives, and
  `READ_MEM` then waits forever. The state machine now goes to IDLE after B and lets the R pass whenever it comes;
- bursts: a DMA read of several beats spans several 16-byte lines, so the table holds the first and last line of
  the burst (INCR from its address, WRAP its aligned window) and a new request waits if its own range overlaps;
- AXI ordering: read data of one id must return in order. A port with two reads outstanding under one id (the
  DMA port; a core has one miss at a time) could get the second answered from a snooped L1 before the first's
  memory data arrived, so a read whose id matches a read in flight waits as well.

Measured with t_bw on the four-core library (cycles per 16-byte line; the model's prediction in brackets):

| | 1 hart | 2 harts aggregate | 4 harts aggregate |
|---|---|---|---|
| rd, before | 48 | 35 | 35 |
| rd, after | 47 | 23 (21.5) | 11 (10.8) |
| wr (ReadUnique), before | 43 | 34 | 34 |
| wr, after | 42 | 21 | 10 |
| sh, before / after | 48 / 47 | 25 / 24 | 17 / 17 |
| wb (not in the state machine) | 35 / 35 | | |

With four harts each hart keeps its single-hart rate (46 to 47 cycles per line each), so the aggregate is 3.2
times the old one and the snoop round plus decode, 9 cycles, is the new serial part. The eight-core library
(t_bw built with SOC_NUM_CORES=8, 76 checks):

| 8-core SoC, cycles per line | 1 hart | 2 harts | 4 harts | 8 harts |
|---|---|---|---|---|
| rd, before → after | 50 → 47 | 36 → 23 | 36 → 12 | 35 → 8.5 (model 9.0) |
| wr, before → after | 46 → 42 | 36 → 21 | 35 → 11 | 34 → 8.5 |
| sh, before → after | 51 → 47 | 26 → 25 | 18 → 17 | – → 14 |

Eight harts share one 16-byte line every 8.5 cycles instead of 35: at 50 MHz the coherence unit's ceiling for
LLC hits rises from 23 MB/s to 94 MB/s, and the eighth loaded hart no longer takes from the others.

**Latency under load** is the other face of the same change. t_part's all-shared phase runs a pointer-chasing
app, a streaming core and the accelerator's DMA at once (4 cores, cycles per app hop / per accelerator word,
alone → shared):

| | old CCU | decoupled CCU |
|---|---|---|
| app, LLC-hit pointer chase | 45 → 159 (3.5×); 225 with the DRAM model (5×) | 45 → 49.5 (1.1×); 50.4 (1.12×) |
| accelerator, DMA words | 107 → 360 (3.4×); 493 | 107 → 126 (1.17×); 137 |

With the serial unit every hit of the app queued behind a whole transaction of each neighbour; now it queues
behind their 9-cycle serial parts only. t_part's two checks that asserted the old penalty (at least 30 % slower
when shared, and lines lost to sharing) were rewritten for the new behaviour (at most 30 %; capacity evidence
from the Q, B1 and R phases). t_stopm, the stop_machine port that found the eight-core livelock, passes on the final version with
4 cores (20 rounds) and with 8 cores and side effects (10 rounds).

## Verification

| library | what | result |
|---|---|---|
| 4 cores | soc regression: t_mem, t_atomics, t_smp, t_irq, t_socket, t_qos, t_cbqri, t_dram, t_dma, t_iotag, t_eth, hello_culsans, quad_boot | 13 of 13 pass (2026-10-25, final version) |
| 4 cores | t_part alone (exceeds the regression's 2 h limit) | running on rpsrvr1 |
| 4 cores | t_stopm (stop_machine port, 20 rounds), t_bw (36 checks) | pass |
| 8 cores | t_stopm with side effects (10 rounds), t_bw (76 checks) | pass (t_bw on rpsrvr1) |
| 8 cores | soc regression | t_atomics, t_smp, t_irq, t_socket, t_cbqri pass; t_mem, t_dram and the second half paused for the bitstream builds |
| 8 cores | t_part alone | not yet run on the final version |
| VCU118 | bitstream `cores4_dec` (4 cores, built on rpsrvr2 in 2 h 28) | 552,632 LUTs (46.7 %, 2.5k more than `plic_tree_4c`), setup met at 50 MHz, all routed; hold: the usual adv_timer clock-as-data (8) and uDMA SPI async-clear classes |
| VCU118, `cores4_dec` | Linux 4 CPUs boots (shell 90 s); bw sweep, 4 harts: DRAM read 49.3 MB/s (was 15.5), LLC-hit read 52.6 (was 16.5), each hart at 97 % of its solo rate; t_atomics and hello_culsans bare metal pass | pass (cores.md has the table) |
| VCU118 | bitstream `cores8_dec3` (NUM_CVA6=8) | building |

The first version of the change failed t_atomics, t_smp, t_qos (hang) and t_eth (one frame); the three fixes
above made them pass. Everything above ran on the final version. The shared-line mode does
not change: the followers' requests to a line still in flight wait in the conflict table until the LLC's data has
arrived, then are answered from that L1 as before. The model, fitted to the old design only, predicted the new
numbers within 7 %.
