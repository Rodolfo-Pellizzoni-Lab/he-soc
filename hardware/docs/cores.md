# Number of CVA6 cores

`ariane_soc_pkg::NumCVA6` sizes the whole host: the CCU ports (`NumCVA6 + 1`, the extra one is the accelerator
socket's DMA port), the CLINT, the PLIC contexts (`2 * NumCVA6`), the debug module, the APMU event ports, the
QoS monitor and the port-index field at the bottom of the SoC AXI user word (`QosUserLsb = $clog2(NumCVA6 + 1)`,
see `qos.md`). It is 4 under `QUAD_CORE` (set in the package itself) and can be overridden with a define:

| Flow | How |
|---|---|
| Questa / Bender file lists | `make NUM_CVA6=8 ...` (also read from the environment) |
| Vivado bitstream (`fpga_build`) | `env={"NUM_CVA6": "8"}` (reaches the Makefile's Bender define list) |
| xsim | `SOC_EXTRA_DEFINES="NUM_CVA6=8" XSIM_WORK=$PWD/work8 ./build.sh`, then `XSIM_WORK=... ./run.sh` |
| soc_tests | build with `-DSOC_NUM_CORES=8` (sw_build `extra_cflags`): wake-up of harts 2..n-1, t_smp's core count, the width of the user word's port field |

What had to change for a fifth core and up (branch `more-cores`, 2026-10-24):

- the PLIC register map was a file generated for 255 sources and 8 contexts; it is a parameterised module now;
- the per-core hart ID vector in `host/cva6_synth_wrap.sv` was 2 bits wide;
- the boot ROM dispatched harts 2 and 3 by name (`host/bootrom/src/main.c`); it now parks hart h on its own
  S-mode PLIC context `2h+1` and, for h >= 2, wakes on the overflow of APMU counter `h-2` (PLIC source `156+h-2`);
- the soc_tests harness woke harts 2 and 3 only.

Not done: the Linux side (device-tree CPU nodes, OpenSBI's `NUM_HARTS` build variable, the `llcpart` module and
docs that assume a 3-bit port field in the user word).

## The PLIC was the limit

`rv_plic_target` was instantiated with its `MATRIX` algorithm, `N*(N-1)/2` priority comparators per context:
32,385 at 255 sources, times eight contexts. The routed quad-core design spent 217,888 LUTs on the PLIC, as much
as the four cores, and each added core (two contexts) would have cost another 54k. The branch adds a `TREE`
algorithm (a balanced max-finder, `$clog2(N)` levels, the lower source index wins a tie exactly like the
matrix's leading-one detector) and uses it. `deps/rv_plic/test/run_xsim.sh` compares the new PLIC with the old
one cycle by cycle under random sources and random register traffic (40,000 cycles, zero mismatches: whole PLIC
at 255x8, register map at 255x16 against the generator's output, finder at 255/30/1 sources).

| PLIC, 255 sources | LUTs | Note |
|---|---|---|
| MATRIX, 8 contexts, out of context | 478,800 | all 255 sources live |
| TREE, 8 contexts, out of context | 21,042 | worst path 4.8 ns |
| TREE, 16 contexts, out of context | 41,679 | |
| MATRIX, 8 contexts, routed quad-core SoC | 217,888 | main, `alsaqr_opendram_ethernet_16x_hpm` |
| TREE, 8 contexts, routed quad-core SoC | 12,091 | branch, build `plic_tree_4c` |

## Utilization on the xcvu9p (VCU118), 50 MHz, LLC, Ethernet

| Design | CLB LUTs | Registers | BRAM tiles | SLR LUT % | Timing |
|---|---|---|---|---|---|
| main, 4 cores | 764,604 (64.7 %) | 356,412 | 842.5 | 60 / 71 / 63 | setup met, 8 adv_timer hold endpoints |
| branch, 4 cores (`plic_tree_4c`) | 550,097 (46.5 %) | 347,780 | 842.5 | 33 / 50 / 57 | setup met, all routed; 12 hold endpoints at -0.077 ns on the uDMA SPI master's async clears (fabric-clock removal class) |
| branch, 8 cores (`cores8`) | 802,444 (67.9 %) | 473,229 | 1,162 | 72 / 71 / 61 | setup met, all routed; 389 hold endpoints at -0.213 ns, all in the uDMA SPI masters' async clears, plus the 8 adv_timer ones |

One CVA6 is about 55k LUTs, 28k registers, 91 BRAM tiles and 27 DSPs. The CCU grows from 3.9k LUTs at five ports
to 6.1k at nine, the PLIC from 12.1k at 8 contexts to 24.1k at 16. The two branch bitstreams were built with
`fpga_build` at 50 MHz with the MIG's DDR4 controller (no `OPENDRAM=1`); the main bitstream in the first row is the
OpenDRAM 16x one (`alsaqr_opendram_ethernet_16x_hpm.bit`), so a few thousand LUTs of the difference are the memory
controller, the rest is the PLIC. Beyond eight cores the budget is roughly 61k LUTs per core (core plus its PLIC
contexts), so ten would land near 80 % of the device.

## On the VCU118 with eight cores (2026-10-24, bitstream `cores8`)

Bare metal: t_smp, t_qos, t_iotag, t_irq and t_part built with `-DSOC_NUM_CORES=8` pass on the board, the rest of the
soc suite passes as built for four cores (the two tag tests fail as four-core builds because the RCID moves up one
bit). OpenSBI built with `NUM_HARTS=8` registers all eight harts (`Domain0 HARTs 0*..7*`); the netboot loader and
the board scripts release harts 2 to 7 (`alsaqr-mcp` `board.num_harts`).

### Memory bandwidth, six-CPU Linux on the eight-core bitstream against four-CPU Linux on main

`bw` (the streaming benchmark of 2026-10-24, one process pinned per hart; MB/s) on the six-CPU Linux of `cores8` and
on the four-CPU Linux of the main bitstream. The DRAM columns are not comparable between the rows: `cores8` runs the
MIG controller at full speed, the main bitstream the OpenDRAM 16x timing model (that is where the single-hart DRAM
numbers of `cores8` are higher). The LLC-hit columns are, and they show what more cores buy: nothing per core. The
coherence unit serialises every shareable access, so six harts together stream at the rate of four, and one hart
alone gets two to three times the per-hart share.

| Linux, bitstream | harts | DRAM read | DRAM write | memcpy | LLC-hit read | LLC-hit write |
|---|---|---|---|---|---|---|
| 4 CPUs, main (OpenDRAM 16x) | 1 | 7.8 | 4.8 | 6.1 | 11.7 | 7.7 |
| 4 CPUs, main (OpenDRAM 16x) | 4, sum | 10.1 | 7.6 | 8.7 | 8.8 † | 8.5 † |
| 6 CPUs, `cores8` (MIG) | 1 | 9.5 | 6.4 | 8.0 | 10.8 | 7.2 |
| 6 CPUs, `cores8` (MIG) | 4, sum | 13.9 | 13.0 | 13.3 | 14.9 | 11.5 † |
| 6 CPUs, `cores8` (MIG) | 6, sum | 14.1 | 13.2 | 13.7 | 12.0 † | 12.5 † |

† sum of harts 1 to n-1 only. The `bw` processes are not synchronised between phases and hart 0's DRAM phases take
10 to 30 % longer than the others' (see the note on arbitration under the next table), so from four harts on it
reaches the short LLC-hit phases after the other harts have finished theirs and runs them at its single-hart rate
(8.1 and 7.6 MB/s in the six-hart run, against 2.4 for each other hart). An earlier version of this section read
those figures as a CCU priority for port 0; they are not. Per hart in the six-hart run: 2.0 to 2.5 MB/s DRAM read,
2.4 MB/s LLC-hit read. The raw output is `board8/bw6_out.txt` in the session scratchpad.

### Linux on seven or eight CPUs

*(Findings on the unfixed design, 2026-10-24; the fix and the eight-CPU results follow in the next section.)*

Linux 6.1.183 boots to the shell with up to **six** CPUs on this bitstream (any six harts: 0-5, or 0,1,4-7) and
hangs with seven or eight; the threshold is not sharp, one of five six-CPU boots stalled later, in the init scripts. The kernel log, read from DRAM over the debug module's system bus, shows a normal boot
up to `smp: Brought up 1 node, 8 CPUs` and stops where a working boot prints `Switched to clocksource`, i.e. in
the `stop_machine` of the clocksource switch: all CPUs spin in `multi_cpu_stop` with interrupts off and the
state never advances. (Nothing reaches the UART because this kernel has no SBI console: `earlycon=sbi` and
`console=hvc0` are inert and output starts only when the 8250 driver registers ttyS0, after the hang.)

`software/soc_tests/t_stopm` is a bare-metal port of `multi_cpu_stop`: every core spins on the shared state word,
acknowledges each state with an atomic decrement of the counter that shares its 16-byte line, and the last acker
writes the next state with plain stores. On the eight-core board it passes with four participating cores and
hangs with six, seven or eight, with or without the per-iteration atomics the kernel loop does; variants with the
counter in its own line and a fixed leader pass on eight. Its stall report (core 0 prints the shared words and,
per core, the last state acknowledged, the value its decrement returned, how often it advanced the state and a
heartbeat) shows what hangs: every decrement of a state completes and returns a distinct value (8 down to 1), so
the atomics are fine; what never lands is the **plain store of the next state**: the other cores keep reading the
previous state from their caches, and the writer's heartbeat freezes in that store.

The eight-core xsim library reproduces it in the first store of round 0, and an interactive session
(`sim_session` probes of the cores' cache controllers and of the CCU's `ccu_fsm`) shows a **livelock** between
one writer and the spinning readers, inside the L1's store path:

1. The writer's line is shared (the readers refilled from it), so its store takes the `MAKE_UNIQUE` path of
   `cache_ctrl.sv`: the miss handler sends a CleanUnique (`SEND_CLEAN`), the CCU broadcasts CleanInvalid and every
   reader drops its copy.
2. All readers miss at once and queue ReadShared requests; the CCU serves them back to back, each one snoops the
   writer, which still holds the line, answers with data and raises `readshared_done`.
3. Back in `STORE_REQ` after the CleanUnique, the writer's cache controller sees the colliding ReadShared
   (`colliding_read_q`) and, by design ("there has been a colliding readshared request during a makeunique+write;
   redo CleanUnique"), issues the CleanUnique again instead of writing. Go to 1.

In the simulation the CCU's state machine repeats the identical sequence every 1.2 us: the CleanUnique of port 0
(`WAIT_INVALID_R`), then ReadShared from ports 1, 3, 2, 4, 5, 6, 7 answered from snoop data; the writer's miss
handler is pinned in `SEND_CLEAN`, every reader's load port cycles `WAIT_REFILL_GNT`, `WAIT_CRITICAL_WORD`, the
readers run their loop with the old value each time and the writer sits in the fence after its store. With three
readers the burst of refills is over before the writer retries and the store lands; with five to seven a
ReadShared is always in flight at the writer when it retries. That is the threshold Linux shows: `multi_cpu_stop`
is exactly one writer and N-1 CPUs spinning on one line, with no back-off in `cpu_relax`. The CCU's serialisation
makes the refills strictly back to back, but the retry policy is in the L1. Four-core Linux has simply not hit
it. The fix (2026-10-25, `cache_ctrl.sv` / `snoop_cache_ctrl.sv`): a ReadShared answered *before* the CleanUnique
response no longer counts as a collision, and the snoop controller holds snoops to a line whose store owns it
until the store is written. hardware/docs/coherence.md has the protocol walk-through, the cycle trace, the
safety argument and the verification.

### With the L1 fix (2026-10-25, bitstream `cores8_fix`, commit ed236f7a)

Same eight-core design with the store-hold change in the L1 (hardware/docs/coherence.md), routed at 50 MHz:
799,632 LUTs (67.6 %), setup met, the same uDMA SPI hold class as before. On the VCU118:

- bare metal, eight cores: t_stopm (the `multi_cpu_stop` port that hung with six, seven and eight cores) completes
  its 200 rounds, 800 state advances, no stall; t_smp 82 checks, t_qos 63, t_iotag 27.
- Linux 6.1.183 over Ethernet: **eight CPUs boot to the shell**, three out of three attempts, shell after 111 s
  (`smp: Brought up 1 node, 8 CPUs`); six and four CPUs (`nr_cpus=`) boot as before, 99 s and 92 s.

Bandwidth on that bitstream (`bw`, 4 MiB buffers, one pinned process per hart; the single-hart row uses 8 MiB;
MB/s; all rows on the same MIG controller, so every column is comparable, unlike the OpenDRAM main numbers above).
The DRAM phases of all harts overlap (they are long and start together); the LLC-hit phases are short and
unsynchronised, so where hart 0 ran its LLC-hit phase apart from the others (its phase time at most 75 % of theirs)
the cell is the sum of harts 1 to n-1 (†):

| Linux | harts loaded | DRAM read | DRAM write | memcpy | LLC-hit read | LLC-hit write |
|---|---|---|---|---|---|---|
| 4 CPUs | 1 | 11.2 | 7.5 | 9.3 | 12.5 | 8.3 |
| 4 CPUs | 2 | 14.5 | 12.4 | 13.5 | 15.5 | 15.2 |
| 4 CPUs | 3 | 15.5 | 14.4 | 15.0 | 17.3 | 18.9 |
| 4 CPUs | 4 | 15.5 | 14.3 | 14.8 | 16.5 | 12.7 † |
| 6 CPUs | 1 | 10.0 | 6.7 | 8.3 | 11.2 | 7.5 |
| 6 CPUs | 2 | 13.8 | 12.0 | 12.9 | 15.1 | 14.4 |
| 6 CPUs | 4 | 14.2 | 13.2 | 13.7 | 15.2 | 11.7 † |
| 6 CPUs | 6 | 14.3 | 13.2 | 13.8 | 12.0 † | 12.7 † |
| 8 CPUs | 1 | 9.8 | 6.5 | 8.1 | 10.8 | 7.2 |
| 8 CPUs | 2 | 13.5 | 11.6 | 12.5 | 14.7 | 13.8 |
| 8 CPUs | 3 | 13.6 | 12.6 | 13.1 | 15.1 | 17.2 |
| 8 CPUs | 4 | 13.5 | 12.4 | 12.9 | 15.5 | 10.8 † |
| 8 CPUs | 6 | 13.2 | 12.2 | 12.8 | 11.4 † | 10.8 † |
| 8 CPUs | 8 | 12.9 | 12.2 | 12.9 | 11.7 † | 13.1 † |

Where the load peaks:

- **Everything saturates at two to three loaded harts**: DRAM reads at 15.5 MB/s with four CPUs online, 14.3 with
  six, 13.6 with eight; LLC-hit reads at 15 to 17 MB/s; LLC-hit writes at 15 to 19. Beyond that the aggregate is
  flat or falls (12 to 13 MB/s with six to eight harts loaded, LLC hit or DRAM alike) while the per-hart share drops
  in proportion (with eight harts each gets 1.2 to 1.7 MB/s read). More CPUs online *lower* the ceiling and the
  single-hart figure (11.2, 10.0, 9.8): the idle CPUs' tick and idle-loop traffic takes its turn at the serial CCU.
- **The arbitration is fair.** Harts 1 to n-1 are within 3 % of each other in every run. The CCU's request
  arbiter is `rr_arb_tree` in its fair round-robin mode (`FairArb`, `LockIn`) inside the `axi_mux` that feeds the
  single `ccu_fsm` (`ip_list/ace/src/ace_ccu_top.sv`), one arbiter for the read channel and one for the write
  channel, and the state machine alternates between the two channels when both have a request pending (`prio_q`
  in `ccu_fsm.sv`). An earlier version of this section read hart 0's 8 to 11 MB/s LLC-hit figures as a port-0
  priority; they were measured after the other harts had drained (†). Hart 0 is in fact the *slowest* hart in every
  overlapped phase, by a constant 0.4 to 0.5 MB/s whatever the hart count (6.5 against 7.0 MB/s with two harts,
  1.2 against 1.6 with eight): a fixed number of memory transactions per second taken from it, which fits CPU 0's
  kernel housekeeping (timekeeping CPU, PLIC interrupt target, the launching shell) and not an arbiter, whose bias
  would be proportional to the share and would show between ports 1 to 7 as well.
- So the configuration with the highest usable bandwidth is still four CPUs, and the highest aggregate load the
  coherence unit sustains is about 15 to 17 MB/s, reached with two to four loaded harts, whatever the core count.
  At 50 MHz that is 0.3 bytes per cycle, one 16-byte line every 50 cycles: the time the `ccu_fsm` holds a
  transaction from the snoop round to the memory response. Raising it means overlapping transactions in the state
  machine (or a wider line), not arbitration. Raw sweeps: `board8/fix/sweep_cpus{8_full,6,4}.lines` in the session
  scratchpad, summarised by `bw_sweep_summ.py` and, per hart against hart 0, `fair_summ.py`.


### With the decoupled CCU (2026-10-25 evening, bitstream `cores4_dec`, commit b9e40af1)

The coherence unit no longer waits for the LLC's response (hardware/docs/ccu_model.md). Same `bw` program and
sweep as above, Linux with 4 CPUs, every phase of all harts overlapped (hart 0 within 3 % of the others), MB/s:

| Linux, 4 CPUs | harts loaded | DRAM read | DRAM write | memcpy | LLC-hit read | LLC-hit write |
|---|---|---|---|---|---|---|
| serial CCU (`cores8_fix`, above) | 1 | 11.2 | 7.5 | 9.3 | 12.5 | 8.3 |
| decoupled CCU (`cores4_dec`) | 1 | 12.6 | 8.3 | 10.4 | 14.1 | 9.2 |
| serial | 2 | 14.5 | 12.4 | 13.5 | 15.5 | 15.2 |
| decoupled | 2 | 25.3 | 16.6 | 20.8 | 28.5 | 18.5 |
| serial | 3 | 15.5 | 14.4 | 15.0 | 17.3 | 18.9 |
| decoupled | 3 | 37.6 | 24.9 | 30.8 | 42.1 | 27.8 |
| serial | 4 | 15.5 | 14.3 | 14.8 | 16.5 | 12.7 † |
| decoupled | 4 | 49.3 | 32.4 | 40.1 | 52.6 | 35.0 |

Each of the four harts keeps 97 % of its solo rate (12.2 to 12.4 MB/s DRAM read each against 12.6 alone): the
ceiling the serial unit imposed at two harts is gone, reads scale 3.2 times at four harts and the write path,
now the first limit, 2.3 times. A single hart gains 10 to 13 %. The raw sweep is `ccu/sweep_cores4_dec.lines` in
the session scratchpad. The eight-CPU and six-CPU rows follow with the `cores8_dec3` bitstream.

## Verified in xsim

- 4 cores, branch RTL: the soc regression passes (t_mem, t_atomics, t_smp, t_irq, t_socket, t_qos, t_cbqri,
  t_dram, t_dma, t_iotag, t_eth, hello_culsans, quad_boot; t_part needs more than the 2-hour run limit when 14
  simulations share the machine with Vivado, run it alone).
- 8 cores (`NUM_CVA6=8`): t_smp built for 8 cores (all eight harts woken, contended AMO and LR/SC counters
  exact, the QoS monitor sees cores 0 to 7), quad_boot, hello_culsans, t_irq, t_eth, t_atomics, t_cbqri, t_dma,
  t_socket, t_qos built for 8 cores. t_stopm built for 8 cores livelocks in round 0 (above); the variant with
  the counter in its own line completes its rounds.

What more cores do not give: the CCU serialises every shareable access (one 16-byte transaction at a time for all
ports), so eight harts share the same aggregate memory bandwidth four do.
