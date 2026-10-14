# AlSaqr on Vivado xsim

This branch runs the full AlSaqr SoC RTL simulation on the Vivado xsim simulator (verified with
Vivado 2024.2) instead of Questa. The RTL and testbench sources in `hardware/` carry the xsim patches
directly (section 2). This directory holds the build/run scripts.

| | hello_culsans (L2 flow) | quad_boot (L3 flow) |
|---|---|---|
| Cores that print | 0, 1 | 0, 1, 2, 3 |
| Simulated time to `[JTAG] SUCCESS` | 4.17 ms | 2.84 ms |
| Wall clock for the run (after elaboration) | ~2.6 min | ~1.5 min |
| Peak RSS | 2.0 GB | 2.1 GB |
| Elaboration (xelab) | ~4 min | ~4 min |

Rule of thumb: about 40 s of wall clock per simulated millisecond; a `--debug typical` snapshot is ~2x slower.

## Quick start

```sh
cd hardware/xsim
./build.sh                                   # bender -> work/compile.sh -> work library + libdpi.so

# test programs (any RV64 bare-metal GCC; tested with riscv64-unknown-elf-gcc 16.1)
export SW_HOME=$PWD/../../software HW_HOME=$PWD/..
GCC="riscv64-unknown-elf-gcc -include $HW_HOME/xsim/sw/uint_compat.h -Wno-error=int-conversion -Wno-error=implicit-function-declaration"
(cd $SW_HOME/hello_culsans && make build_l2 RISCV_GCC="$GCC")   # L2 flow
(cd $SW_HOME/quad_boot     && make build    RISCV_GCC="$GCC")   # L3 flow

./run.sh l2 $SW_HOME/hello_culsans/hello_culsans.riscv hello
./run.sh l3 $SW_HOME/quad_boot/quad_boot.riscv quad
```

`VIVADO_SETTINGS` points at the Vivado `settings64.sh` if `xvlog` is not already on `PATH`
(default `/tools/Xilinx/Vivado/2024.2/settings64.sh`); `XSIM_WORK` moves the work directory
(default `hardware/xsim/work`). The extra GCC flags are needed with recent GCC versions: `pmu_test_func.c`
uses a bare `uint` (`-Duint=unsigned` does not work, hence the header) and some tests rely on implicit
declarations.

`run.sh` recompiles only the testbench with the flow's defines, elaborates the snapshot `tb_<flow>`, runs it
and exits 0 iff `[JTAG] SUCCESS` is printed. Expected markers, in order: `[JTAG] Initialization success`
(~1 ms), `[JTAG] Halted hart 0` (~2.1 ms), `[XSIM-L2]/[XSIM-L3] section ...`, `[JTAG] Resumed hart 0`,
`Mock uart` lines, `[JTAG] SUCCESS`. Logs land in `work/`: `<name>_stdout.log` (simulation output),
`wd_<name>.txt` (watchdog: sim-time tick, idle time and RSS every 30 s; it kills a run that has not advanced
for 180 s), `xelab_<name>.log`.

Pick the flow by where the program lives:

| Flow | Build | Entry | tohost | Notes |
|---|---|---|---|---|
| `l2` | `make build_l2` (`test_l2.ld`) | 0x1C00_0000 | 0x1C00_0140 | 32 KB budget; core 1 released by DUAL_BOOT |
| `l3` | `make build` (`test.ld`) | 0x8000_0000 (sim DRAM) | 0x1C00_0000 | anything that wakes secondary cores through the mailbox or the APMU, since the boot ROM jumps them to 0x8000_0000 |

## Files

```
build.sh        full build: bender 'script vsim' -> vsim2xsim.py -> work/compile.sh, runs it, builds work/libdpi.so
run.sh          tb recompile + elaboration + run with stall watchdog:  run.sh <l2|l3> <elf> [name] [timeout_s]
env.sh          shared configuration: bender targets, SoC/xsim defines, disabled device models
vsim2xsim.py    bender vsim Tcl -> one xvlog/xvhdl call per bender block (keeps each block's +incdir/+define)
chain_dbg.sh    stall finder: debug snapshot, step to the stall, ptrace ranking of the spinning processes
tools/comb_fix.py  mechanical rewrite of a combinational ring (section 2): comb_fix.py <file> <var> [<var> ...]
sw/uint_compat.h   'typedef unsigned int uint' for the software build
```

## 1. What hardware is simulated

The DUT is `al_saqr` → `host_domain`, elaborated from the repo's bender file list (targets of the Makefile's
`scripts_vip` flow) with the defines in `env.sh`. 519 SystemVerilog modules plus the VHDL CAN controller
are elaborated.

### Host domain (all present, all real RTL)

| Block | Instance / module | Notes |
|---|---|---|
| 4x CVA6 (RV64GC + H, SV39x4, FPU) | `cva6_synth_wrap` → `gen_ariane[0..3].i_ariane` | TARGET_CV64A6_IMAFDC_SV39_WB; WB/ACE cache subsystem (`std_cache_subsystem`) |
| Cache coherency unit | `i_ccu` (`ace_ccu_top`, `ccu_fsm`) | snoop ports to all 4 cores |
| SPU (snoop/perf units) + EVU perf counters | `ace_spu_top`, `perf_counters_evu`, `i_spu_llc_mem` | APMU_IP is `define`d inside host_domain.sv, so SPUs sit between cores and CCU and between LLC and memory |
| APMU | `i_pmu_top` (`pmu_top`, `ibex_pmu_core`, `pmu_counter`, ISPM/DSPM) | counters, overflow interrupts to PLIC IDs 156..; used by quad_boot |
| Last-level cache | `i_axi_llc` (`axi_llc_top`, PLRU, tag/data SRAM) | master port terminated in a sim DRAM (section 2) |
| L2 memory | `i_l2_subsystem` (8 word-interleaved `tc_sram` banks) | 0x1C00_0000–0x1C00_8000 usable by the preload task |
| Boot ROM | `bootrom` | mailbox/PLIC/APMU boot protocol |
| Debug | `dm_top` (`dm_csrs`, `dm_mem`, `dm_sba`), `dmi_jtag`, SimJTAG/remote_bitbang DPI, local JTAG driver in the tb | halt/resume/abstract commands and SBA reads work; the program is preloaded directly instead of through SBA (too slow) |
| Interrupts | `plic_top` (rv_plic, 4 cores x M/S contexts), `clint`, `clint_sync` | APLIC is not instantiated in this configuration |
| IOMMU / IOPMP | `riscv_iommu`, `riscv_iopmp`, `i_riscv_iopmp` | present, not exercised by the two tests |
| CFI snooper | `snooper`, `snooping_engine`, `trace_regs` | present |
| Mailboxes | 2x `axi_lite_mailbox`, SCMI mailbox (`scmi_reg_top`) | core-1 wake-up path |
| APB peripherals | `apb_subsystem`: `apb_timer`, `apb_adv_timer`, `apb_gpio`, SoC control, FLL interface, 2x `can_top_apb` (VHDL) | CAN controllers are in, the CAN bus VIP is not |
| uDMA | `udma_subsystem`: UART, SPI-M, I2C, SDIO, camera, HyperBus-uDMA, filter | present; their external device models are not |
| UART | `mock_uart` (tb model behind the APB UART slot) | same as the Questa RTL sim |
| HyperBus controller | `hyperbus_axi`/`hyperbus_phy` etc. | instantiated but idle: its AXI slave port gets a tied-off bus |
| Clocks / resets | `alsaqr_clk_rst_gen`, `fll_dummy`, `rstgen_bypass_ckg` | FLL dummy clocks; frequency meter disabled (XSIM_NO_FREQMETER) |
| Pad frame | `alsaqr_periph_padframe` + behavioral `pad_alsaqr` | pads present, driven by the tb wires |

### Not simulated

| Block | Why | Where decided |
|---|---|---|
| PULP cluster | EXCLUDE_CLUSTER (an `axi_err_slv` answers its address range) | `env.sh` |
| Ethernet subsystem | EXCLUDE_ETHERNET | `env.sh` |
| OpenTitan security island (RoT) | the `ifndef EXCLUDE_ROT` block in `al_saqr.sv` is commented out in this repo; `ot_axi_req` is tied to 0 | repo |
| HyperRAM chips (`s27ks0641` tb models) | NO_L3_CONNECTION: the tb leaves the hyper pads unconnected; DRAM is emulated by `axi_sim_mem` behind the LLC instead | `env.sh` + host_domain |
| Flash `s25fs256s` (x7), I2C EEPROM `24FC1025`, SD card `sdModel`, CAN VIP, USART VIP, camera (SDVT_CPI) VIP | `-generic_top USE_*=0` at elaboration; the seven 32M-entry flash arrays alone cost 29 GB in xsim | `env.sh` (GENERICS) |
| tb `AXI_BUS_DV` master driver | XSIM_NO_AXI_DRV: unused, and its clocking block sampled every SoC clock edge | `run.sh` |
| ~400 `tran`/`tranif1` pad-mux switches in the tb | xsim has no `tran`; the VIP muxing they implemented is moot with the VIPs off | removed from the tb |
| CVA6 instruction tracer, SVA assertions | XSIM_NO_TRACER; `xelab --ignore_assertions` (unbounded `##[1:$]` threads leaked) | `env.sh` + `run.sh` |

## 2. How the sources differ from the Questa flow

### Combinational "ring" rewrites (the root cause of every stall and the memory blow-up)

xsim turns each intermediate write of a default-then-override `always_comb` into a net event on the port;
Questa lets dependents see only the final value. On a combinational ready/valid ring the values are stable,
so no delta limit trips, the event queue grows without bound (100–190 MB/s) and simulation time stops.
The fix (`tools/comb_fix.py`) rewrites the block to assign every cross-block variable once at the end through
a shadow variable (`<var>_xc`, lines marked `// xsim:`). Rewritten:

| Ring | Files | Showed up at |
|---|---|---|
| LLC hit/miss ctrl ↔ tag store | `axi_llc_hit_miss.sv`, `axi_llc_tag_store.sv` | t=0 (BIST) and 2.55 ms |
| CVA6 miss handler pack block ↔ bypass arbiter | `cva6/core/cache_subsystem/miss_handler.sv` | t=0 |
| AXI atop filter ↔ demux | `axi_atop_filter.sv`, `axi_demux_simple.sv` | 1.5 ms |
| CDC reset controller ↔ 4-phase handshake (DMI) | `cdc_reset_ctrlr.sv`, `cdc_4phase.sv` | 1.9 ms |

The rewrite's final assignment must sit at the top level of the block. An earlier revision of the
`miss_handler.sv` rewrite left `bypass_ports_req = bpr;` inside the innermost `else`, which turned the port array into
a latch: atomics/SC (and LR to shareable DRAM) never reached the bypass arbiter in xsim ("AMO hang"), and on the FPGA
they only worked through a latch data-vs-enable race that depended on placement (fixed 2026-09-16). After running
`comb_fix.py`, check the Vivado synthesis log for `inferring latch` in the rewritten file.
| Debug module memory: rw-logic ↔ hart control queue | `riscv-dbg/src/dm_mem.sv` (+ `dm_csrs.sv` outputs) | first "halted" write, 2.016 ms |
| AXI data-width downsizer W/R blocks ↔ fall-through fifo | `axi_dw_downsizer.sv`, `fifo_v3.sv` (data_o) | first UART write, 2.53 ms |

### Other xsim patches

- `tc_sram`: array initialised once in an `initial` instead of `sram <= init` on every reset clock (XSIM_SRAM_INIT_ONCE); reads/writes guarded against X addresses (XSIM_SRAM_NO_X_WRITE).
- `rstgen_bypass_ckg`, `sync`: do not re-write an unchanged reset register every cycle (XSIM_RST_NO_REWRITE; the guards use `!==`, since `!=` with X silently disables the reset).
- `fll_dummy`: clocks idle while RSTB is not 1 (XSIM_FLL_IDLE_IN_RESET).
- `jtag_pkg`, `jtag_test`: `timescale 1ps/1ps` and time literals — xsim rescaled the `parameter time TA/TT` overrides, so JTAG never initialised.
- `default disable iff` removed (not supported by xsim); `tran` removed from the tb; struct-literal `'{` fixes in `cva6.sv`; `logic` on inout tb nets; VHDL `mod` width in CAN `bit_(de)stuffing`; use-before-declare in `sdModel.v`; compilation-unit `timeunit` in `hwpe_ctrl_interfaces.sv`; anonymous instance in `apb_subsystem.sv`; behavioral `pad_alsaqr` models rewritten with continuous assignments.
- `host_domain.sv`: XSIM_SIM_DRAM — `axi_sim_mem` (zero-initialised) on `mem_axi_bus`, HyperBus slave port tied off, and a `wfi; j -4` loop preloaded at 0x8000_0000 so a core sent there by the L2-flow startup code parks instead of wedging.
- Testbench: direct ELF preload (XSIM_L2_PRELOAD: L2 banks, plus the sim DRAM with XSIM_L3_FLOW) instead of JTAG SBA bit-banging; XSIM_L3_FLOW selects entry 0x8000_0000 / tohost 0x1C00_0000; XSIM_TICK prints a heartbeat every 10 µs for the watchdog.
- Left in the sources, off by default: bisection hooks used while hunting the rings (`XSIM_CUT_<inst>`, `XSIM_V_CLK/RST/IN` in host_domain, `XSIM_INIT_REGS`, `XSIM_FORCE_RESET/REGS`, `XSIM_LLC_DEBUG`, `XSIM_DMI_DEBUG`, ...).

### Real repo issues found on the way (not xsim artefacts)

- `tb/ariane_tb.sv`: with NO_L3_CONNECTION, TOHOST was 0x1C000100 but `software/common/test_l2.ld` places `.tohost` at 0x1C000140 (fixed to 0x1C000140 here).
- `host/cva6_subsystem.sv` instantiates `ariane_peripherals` with the default `AxiUserWidth=1` while the SoC uses 2 (xsim warns, Questa is silent).
- `software/common/syscalls.c` wakes core 1 through the mailbox with a hard-coded 0x8000_0000 entry; in the L2 flow that sends core 1 into unbacked memory. CVA6 then offloads the all-zero opcode to the absent CV-X-IF coprocessor and never commits, so a later JTAG halt cannot be taken (the WFI loop above works around it).

## 3. Changing RTL or the testbench

After editing a file, recompile just that file with the options `compile.sh` used for it, then re-run
(`run.sh` re-elaborates):

```sh
source hardware/xsim/env.sh; cd $WORK
f=$HW/<path>; line=$(grep -E "^xvlog .*[ /]$(basename $f)( |$)" compile.sh | head -1)
xvlog -sv -work work -L uvm $(echo "$line" | grep -oE '(-i|-d) [^ ]+' | tr '\n' ' ') $f
```

Changing `env.sh` or adding files needs a full `./build.sh`.

## 4. Debugging a stall

- Watchdog says `STALLED at <t>` with growing RSS: a combinational ring. `./chain_dbg.sh <tag> <elf> <t-10us in ns> 40 500`
  builds a `--debug typical` snapshot, steps to the exact time and prints the ptrace ranking of the spinning
  processes; feed the block's written variables to `tools/comb_fix.py` (it also accepts `always_comb (* xprop_off *) begin`).
- Stall with flat RSS: a deadlock. Probe with a `--debug typical` snapshot and `get_value -radix hex <path>` in a Tcl
  script (`run 3000us; puts [get_value ...]`); `current_scope <inst>; get_objects` lists a scope. Full instance
  paths start at `/ariane_tb(...)/dut/i_host_domain/...` (use `[lindex [get_scopes /*] 0]` to get the top).
- `add_force` on ports collapses onto the whole net and cannot force structs; forcing a sub-block clock freezes
  the whole clock net.
- Never `pkill -f` a pattern that appears in your own command line (it kills the calling shell).

## 5. Known limits

- L2 is 32 KB in this configuration; bigger programs must be L3 builds.
- The sim DRAM is zero-initialised (plus the WFI loop at 0x8000_0000) and holds only what the preload writes.
- No HyperBus timing, no flash/SD/CAN/Ethernet traffic: those device models are off.
- The Questa flow (`make` in `hardware/`) is not maintained on this branch.
- xsim itself: no `tran`, no `default disable iff`, `time` parameter overrides are rescaled, port `add_force`
  collapses onto the net, the kernel crashes when run outside the `xsim` front end (no gdb).
- Verilator: the whole DUT lints (`--lint-only --timing`) with the same patches, but `--cc --build` was OOM-killed
  above 51 GB RSS on a 61 GB machine.

## 6. Validation tests and custom accelerators

- `software/soc_tests/` holds self-checking SoC tests (L3 flow, `make build`): `t_mem` (DRAM through L1/CCU/LLC with
  every access size and an eviction sweep, on-chip SRAM), `t_atomics` (every AMO + LR/SC on DRAM and SRAM), `t_smp`
  (4 cores: AMO/LR-SC counters, coherence, message passing), `t_irq` (CLINT software/timer interrupts, PLIC
  registers), `t_socket` (accelerator socket error responses). Each prints `TEST PASS`/`TEST FAIL` and exits with the
  number of failed checks; `include/soc_test.h` has the helpers (CHECK, trap guard, 4-core wake-up, barrier).
- The PULP cluster's place is taken by the accelerator socket (`hardware/accel/`, see its README.md): 8 slots of
  64 KB at 0x1000_0000, each with a register port, a memory master port and an interrupt (PLIC ID 9). Before the
  socket, the error slave meant to answer the excluded cluster's window sat on an undriven bus
  (`tlb_to_cluster_axi_bus`), while the xbar's cluster port (`soc_to_cluster_axi_bus`) had no responder at all.
- The alsaqr-mcp tools `sim_regress`, `accel_add`, `accel_unit_test` and `accel_soc_test` drive both.

