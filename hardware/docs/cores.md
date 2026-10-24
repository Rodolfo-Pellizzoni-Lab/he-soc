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

## Utilization on the xcvu9p (VCU118), 50 MHz, OpenDRAM, LLC, Ethernet

| Design | CLB LUTs | Registers | BRAM tiles | SLR LUT % | Timing |
|---|---|---|---|---|---|
| main, 4 cores | 764,604 (64.7 %) | 356,412 | 842.5 | 60 / 71 / 63 | setup met, 8 adv_timer hold endpoints |
| branch, 4 cores (`plic_tree_4c`) | 550,097 (46.5 %) | 347,780 | 842.5 | 33 / 50 / 57 | setup met, all routed; 12 hold endpoints at -0.077 ns on the uDMA SPI master's async clears (fabric-clock removal class) |
| branch, 8 cores (`cores8`) | 802,444 (67.9 %) | 473,229 | 1,162 | 72 / 71 / 61 | setup met, all routed; 389 hold endpoints at -0.213 ns, all in the uDMA SPI masters' async clears, plus the 8 adv_timer ones |

One CVA6 is about 55k LUTs, 28k registers, 91 BRAM tiles and 27 DSPs. The CCU grows from 3.9k LUTs at five ports
to 6.1k at nine, the PLIC from 12.1k at 8 contexts to 24.1k at 16. Both bitstreams were built with `fpga_build`
(50 MHz, OpenDRAM) and not run on the board. Beyond eight cores the budget is roughly 61k LUTs per core (core plus
its PLIC contexts), so ten would land near 80 % of the device.

## Verified in xsim

- 4 cores, branch RTL: the soc regression passes (t_mem, t_atomics, t_smp, t_irq, t_socket, t_qos, t_cbqri,
  t_dram, t_dma, t_iotag, t_eth, hello_culsans, quad_boot; t_part needs more than the 2-hour run limit when 14
  simulations share the machine with Vivado, run it alone).
- 8 cores (`NUM_CVA6=8`): t_smp built for 8 cores (all eight harts woken, contended AMO and LR/SC counters
  exact, the QoS monitor sees cores 0 to 7), quad_boot, hello_culsans, t_irq, t_eth, t_atomics, t_cbqri, t_dma,
  t_socket, t_qos built for 8 cores.

What more cores do not give: the CCU serialises every shareable access (one 16-byte transaction at a time for all
ports), so eight harts share the same aggregate memory bandwidth four do.
