# SoC tests

These are bare-metal, self-checking C programs for the CVA6 cores, one per SoC feature. Each test runs unchanged in
the xsim simulation and on the VCU118. This page also sorts the other directories under `software/` and lists the
board programs in alsaqr-software.

## How it works

**Build.**
- Each test is a directory `software/soc_tests/t_<name>/`. Its Makefile sets `APP` and includes
  `soc_tests/common.mk`.
- `soc_tests/common.mk` adds `soc_tests/include` and `software/quad_boot` (for `pmu_defines.h`, the APMU register
  map) to `software/common.mk`.
- `make build` links with `software/common/test.ld`: code and data go in DRAM, and `tohost` plus the `SOC_SRAM`
  variables go in the uncached on-chip SRAM. The start-up code is `software/common/crt.S` and `syscalls.c` (see
  boot.md).
- The compiler is `riscv64-unknown-elf-gcc`.

**Helpers** (`soc_tests/include/soc_test.h`):
- `soc_test_begin(name)` prints `TEST <name>` and installs a trap guard. Any exception prints a `TRAP mcause=..
  mepc=.. mtval=..` line and exits with code 127.
- `CHECK(cond, fmt, ...)` counts a check and prints `CHECK FAIL <file>:<line>` when it fails.
- `return soc_test_end()` prints `TEST PASS` or `TEST FAIL` and exits with the number of failed checks.
- `soc_wake_all()` starts harts 2 and up and returns the mask of harts that started.
- `soc_wait_harts()` waits for harts to start, and `soc_barrier()` is a barrier in SRAM.
- `SOC_SRC_BITS`, `REG32`/`REG64` and `soc_cycles()` complete the helpers.
- The runtime's `printf` is 32-bit only. Print 64-bit values with `H64`.

**Tests** (**S**: in the `soc` suite of `sim_regress` and `board_regress`):

| Test | Checks |
|---|---|
| t_mem **S** | Core 0 on cached DRAM: every access size and an eviction sweep larger than the L1. The same on the on-chip SRAM. |
| t_atomics **S** | Every AMO with its old value, and LR/SC success and failure, on DRAM and on SRAM. |
| t_smp **S** | Wake-up of all cores, a contended `amoadd`, LR/SC, per-core lines read by core 0, and a message-passing ring. |
| t_irq **S** | CLINT software and timer interrupts, and PLIC registers. |
| t_socket **S** | Accelerator socket accesses past the last slot return an error response and do not hang the core. |
| t_qos **S** | `srmcfg` CSR access rules, each core's QoS tag read through the socket's QoS probe, and cached traffic checked by the simulation's QoS scoreboard. |
| t_cbqri **S** | LLC CBQRI capacity controller: registers and STATUS codes, isolation by way masks, code/data masks, and per-core partitions. |
| t_dram **S** | DRAM timing model: latency, late detection, the bandwidth limit, the write path, and off. |
| t_dma **S** | Accelerator-socket DMA against the write-back L1s: device reads of dirty lines, core reads of device writes, and the cost of `fence.i`. |
| t_iotag **S** | Socket DMA tags: inherited from the requester, forced by `TAG_POLICY`, and seen at the LLC partitions. |
| t_part **S** | LLC way partitioning between an app core, a streamer and the accelerator, measured as performance, with the DRAM model off and on. |
| t_eth **S** | Xilinx Ethernet and DMA with frames looped back, coherent buffers, a full TX ring, and the DMA interrupts. |
| t_bc | LLC CBQRI bandwidth controller: shares under Rbwb/Mweight, hard limits, per-MCID monitors against the APMU, and registers. |
| t_bcw | Cost of the bandwidth controller's write ordering (stall and leak), with and without `QOS_LLC_WBUF`. |
| t_bcd | Which victims a throttled write or DMA stops, and the wait at the DMA admission gate. |
| t_bchol | A limit on one RCID does not slow another: a best-effort reader next to 1 to 3 hard-limited readers, with and without a reservation. |
| t_trap | `stvec` reads back as written; instructions the core does not decode raise an illegal-instruction exception. |
| t_qosv | Privilege association (`mqosctl`, `mqosid`, `hqosid`, `sqosid`) and vRCID/vMCID translation. |
| t_iojob | Per-job DMA tags from the socket's job queue, address-range tags, a queue overflow, and builds without them. |
| t_evu | Core EVU registers from core 0 and from the APMU core, and per-core event counting through the APMU. |
| t_iopmp | IOPMP in front of the APMU core: entries, NAPOT/TOR, priority, and source domains. |
| t_storm | Every master at once (cores, both socket slots, Ethernet DMA) while every APMU event source counts, checked against the APMU core's samples. |
| t_srcid | The memory-port SPU credits every DRAM request to its source: each core, the socket and the Ethernet. |
| t_spulat | Latency sums, minimum and maximum that the SPUs report for DRAM writes and socket DMA. |
| t_hpm | CVA6 HPM counters from S, U, VS and VU mode. |
| t_sscofpmf | Sscofpmf filtering, access rules, and the counter-3 overflow interrupt. |
| t_hpm_irq | Overflow interrupt of all six counters on every hart, sampling, and S-mode delegation. |
| t_chk | Data integrity of the coherent path under load on every core. Modes: `CHK_MODE`, `CHK_TRAFFIC`, `CHK_SHARED`. |
| t_stopm | Linux's `multi_cpu_stop` handshake on every core, with a stall report. |
| t_bw | Cycles per line of the coherent path for 1 to N harts (read, write, shared). |
| t_sweep | Latency sweep (L1 → LLC → DRAM) with the DRAM model off and at 1 GHz settings. `plot_sweep.py` plots it. |
| t_sweep_probe | Print-only probes of how the DRAM model's hold reaches the core. |
| t_wfi | Where the timer interrupt that ends a `wfi` is taken: CVA6 takes it some instructions after the `wfi`. |

`hello_culsans` and `quad_boot` are also in `sim_regress`'s `soc` suite. `software/accel/<name>` holds the C test of each socket
accelerator (`accel` suite). It uses the same harness through `accel/common.mk`.

## Configuration

- `SOC_NUM_CORES=<n>` or `NUM_CVA6=<n>` on the make command line builds for an n-core SoC. Without it the code
  assumes 4. It sets the wake-up set, the core loops and the user-word layout. The tag checks of `t_qos`,
  `t_iotag` and `t_part` hold only for the core count they were built for.
- `fpga=1` builds for the board: `FPGA_EMULATION`, board-sized loops, and `.bss` cleared at start.
- Tests take further `-D` knobs, named in each test's header comment, for example `LINES`, `CHK_*`,
  `DMA_NONCOHERENT`, `NO_SIDE_EFFECTS` and `VERBOSE`. Pass them with `sw_build extra_cflags`.

## Using it

- Use alsaqr-mcp: `sw_build test=soc_tests/t_x`, then `sim_run` and `sim_status`, or `sim_regress suite=soc|accel|all`.
  `sim_status qos=true` adds the QoS scoreboard.
- On the board: `board_run binary=t_x` builds with `fpga=1` and runs over JTAG, and `board_regress` runs a suite.
- Register addresses come from the SoC packages and `pmu_defines.h`. `soc_lookup` returns them.

### Other programs in `software/`

- **In use with this SoC:** `accel/`, `hello_culsans/`, `quad_boot/`, `netboot/` (boot.md), `linux/socket_dma`
  (linux.md), `eth/include` (Xilinx Ethernet driver), `common/`, `inc/`, `common.mk`.
- **APMU, EVU and memory-regulation programs**, run one at a time and in no suite: `pmu_test`, `pmu_test2`,
  `pmu_cntr_test`, `pmu_perfc_test`, `pmu_L3_test_v2`, `pmu_IOPMP_L2RW_test`, `pmu_evu_bench`, `pmu_evu_c1_track`,
  `pmu_evu_simple_sim`, `pmu_snap`, `cva6_evu`, `c1_v2`, `slowdown_bw`, `slowdown_qc`, `slowdown_st`,
  `token_bucket_regs`, `token_bucket_throttle`.
- **Outside every flow of this SoC.** No flow, suite or doc of this SoC builds or references these; most target
  blocks this SoC does not build:
  - *PULP cluster* (excluded; the accelerator socket takes its window): `pulp-runtime`, `common_pulp`, `hello_pulp*`,
    `par_matmul*`, `fft_cluster`, `conv_cluster`, `cl_core_tests`, `fpu_pulp`, `fpu_tests`, `redmule`, `dma`,
    `mailbox`, `shared_data`, `wce`, `l1_test_random`, `mm_int`, `axi_tlb`, `cluster_regression.list`,
    `compile_all.sh`, `README.md`.
  - *HyperBus memory*: `hyperbus`, `axi_hyper_fibonacci`, `l3_test*`, `elf_to_slm.py`.
  - *uDMA peripherals, padframe, FLL, ASIC:* `peripherals`, `can`, `gpios`, `timer`, `fll_to_pad`, `backend_test`,
    `bypass_cva6_dco`, `regression.list`.
  - *APLIC* (`USE_APLIC`, which no flow defines): `aia`, `common_aplic`, `mbox_test`, `pmu_aplic_test`.
  - *Other CVA6 programs:* `hello`, `hello_dual_boot*`, `l1_test`, `l2_test`, `l2_full_test`, `l2_test_restricted`,
    `llc_spm_test`, `mm`, `conv`, `fft`, `kmeans`, `LU`, `dhrystone`, `htm`, `litmus`, `zicfiss`, `iommu`, `iopmp`,
    `snooper_test`, `monitor_counter`, `culsans_bare_perf`, `cachetest`.

### Board programs in alsaqr-software

Built with `scripts/build.sh <dir> <target>` (`fpga=1`) and run with `scripts/load.sh`, which loads the program over
JTAG, runs it for a set time and dumps a result region.
- `pmu_mempol_synth`: a token-bucket bandwidth policer on the APMU core regulating core 0; `pmu_mempol_synth_sim`
  is its xsim build.
- `pmu_sdvb`: SD-VBS under APMU regulation with interference.
- `pmu_sad_profile`: profiles `computeSAD`, alone and with interference.
- `pmu_test`: core 0 writes the APMU counter bundles and runs a bubble sort on the APMU core.
- `march_test`, `march_retention`: DRAM March C- and data retention.
- `freertos_hello`: a FreeRTOS port.

The APMU programs' `pmu_defines.h` give a DSPM base that differs from he-soc `software/quad_boot/pmu_defines.h`, which
matches the RTL.

## Verification

The tests are self-checking: each prints `TEST PASS` or `TEST FAIL` and exits with its number of failed checks
(127 on a trap). alsaqr-mcp `sim_regress suite=soc` runs the twelve **S** tests plus `hello_culsans` and
`quad_boot` in xsim; `board_regress suite=soc` runs the twelve **S** tests on the board.

## Code

- `software/soc_tests/`: the tests, `common.mk`, `include/soc_test.h` and `plot_sweep.py`.
- `software/common/`, `software/inc/`, `software/common.mk`: the runtime, drivers and build rules.
- `software/quad_boot/pmu_defines.h`: the APMU register map used by the tests.
- `software/accel/`: accelerator tests and `accel.h`.
- alsaqr-software `tests/`: board programs.
- alsaqr-mcp `alsaqr_mcp/regress.py`, `board.py`: the `soc` and `accel` suites.

## Reference

- Each test's header comment: what it checks and its knobs.
- alsaqr-mcp `README.md`: `sim_regress`, `board_run`, `sw_build`.
- `hardware/xsim/README.md`: the simulation flow.
