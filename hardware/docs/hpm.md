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

## rdcycle stands still under Linux on these bitstreams

With the SBI PMU driver the kernel stops every counter when a CPU comes up, so that perf owns them, and OpenSBI 1.3
implements that for the fixed cycle and instret counters by setting `mcountinhibit` bits 0 and 2. The old CVA6 ignored
the write; this one honours it, so after boot `rdcycle` and `rdinstret` return a constant on all four harts (checked
with a pinned probe on every CPU). `rdtime` (25 MHz) is unaffected, and so is everything the kernel times. A program
or module that measures with `rdcycle` must first open a perf cycles event on that CPU (perf_event_open from user space,
`perf_event_create_kernel_counter` in a module): OpenSBI then starts the fixed cycle counter there and `rdcycle` runs
until the event is closed. alsaqr-software's `linux/llcpart` does this since 2026-10-24. The bare-metal tests are not
affected (nothing inhibits the counters there, and `t_hpm` restores `mcountinhibit` to 0).
