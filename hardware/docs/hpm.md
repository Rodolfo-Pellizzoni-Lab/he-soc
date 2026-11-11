# CVA6 performance counters (HPM) on AlSaqr

Abdur Rahman's series of 2026-10-22 (he-soc 3c3b0fc0, 22788ebe, 5635178b; alsaqr-software f620434c, 487c92fc,
85773ff5) makes the six programmable counters architectural: `mhpmcounter3..8` with their `hpmcounter` aliases,
`mcountinhibit`, the counter-enable chain through `mcounteren`/`hcounteren`/`scounteren` with the right trap causes,
WARL-zero selectors for the absent counters, cycle (0x17) and retired-instruction (0x18) selectors, per-lane retire
counts, and Sscofpmf (mode filtering, sticky overflow, local interrupt 13). Tests: `software/soc_tests/t_hpm` (67
checks), `t_sscofpmf` (110), and the unit bench `hardware/xsim/tests/run_hpm.sh`. On the Linux side the bundle gains
`CONFIG_RISCV_PMU_SBI`, OpenSBI's FDT PMU setup for the AlSaqr platform, and two opt-in device trees:
`alsaqr-pmu-counting.dts` (event mappings, no sampling) and `alsaqr-pmu.dts` (advertises `sscofpmf`; only with a
bitstream of this series).

First bitstream with the series: the OpenDRAM 16x build of merged main 15cca8d8 (2026-10-24,
`alsaqr-software/bitstreams/alsaqr_opendram_ethernet_16x_hpm.bit`): t_hpm and t_sscofpmf pass on the board along
with the rest of the suite.

## The overflow interrupt of every counter: t_hpm_irq

`software/soc_tests/t_hpm_irq` checks local interrupt 13 for all six counters on every hart: each counter alone (its
own bit in `scountovf`), all six wrapping together (one interrupt, all six bits), a counter loaded with 2^64-K that
wraps on exactly the K-th event of a fixed code region (instructions, loads, stores, control flow, calls, returns,
integer instructions), the other events on a workload that makes many of them, sampling of user code (period 500,
every sample's `mepc` inside the user loop), delegation to S-mode, the enables (`mie.LCOFIE`, `mcountinhibit`, MINH),
and every hart taking its own six interrupts at the same time. `mcycle` and `minstret` have no overflow bit: Sscofpmf
covers only the programmable counters. On the VCU118 on 2026-11-10, with `alsaqr_main_8core_20261107.bit` and
`alsaqr_main_4core_20261107.bit`, it passed (152 checks on 8 cores, 124 on 4), and so did t_hpm and t_sscofpmf.

Linux samples only with a device tree that describes the counters and advertises `sscofpmf`: alsaqr-software's
`linux/cva6-sdk/alsaqr-pmu.dts` (4 harts) and `alsaqr-pmu8.dts` (8 harts, compiled in
`linux/prebuilt/8core/alsaqr-pmu8.dtb`). With them, on the same two bitstreams and Linux 6.1 from `linux/cva6-sdk`,
every CPU counted a user loop of 1,000,000 iterations to within 30 events (instructions, loads, stores, control
flow), sampled six events at once through the riscv-pmu interrupt (100 samples each, every PC inside the loop, none
lost), and `perf stat` and `perf record` worked. With the plain socket device trees perf counts only cycles and
instructions, in all modes, and cannot sample.

## rdcycle stands still under Linux on these bitstreams

With the SBI PMU driver the kernel stops every counter when a CPU comes up, so that perf owns them, and OpenSBI 1.3
implements that for the fixed cycle and instret counters by setting `mcountinhibit` bits 0 and 2. The old CVA6 ignored
the write; this one honours it, so after boot `rdcycle` and `rdinstret` return a constant on all four harts (checked
with a pinned probe on every CPU). `rdtime` (25 MHz) is unaffected, and so is everything the kernel times. A program
or module that measures with `rdcycle` must first open a perf cycles event on that CPU (perf_event_open from user space,
`perf_event_create_kernel_counter` in a module): OpenSBI then starts the fixed cycle counter there and `rdcycle` runs
until the event is closed. alsaqr-software's `linux/llcpart` does this since 2026-10-24. The bare-metal tests are not
affected (nothing inhibits the counters there, and `t_hpm` restores `mcountinhibit` to 0).
