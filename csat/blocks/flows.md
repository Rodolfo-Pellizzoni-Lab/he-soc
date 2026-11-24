# Build and run flows

How the SoC is configured, simulated in Vivado xsim, built into a bitstream for the AMD VCU118 board and run there,
and the agent tools (alsaqr-mcp) that drive each step.

## How it works

**Sources.** Bender (`hardware/Bender.yml`, binary `hardware/bender`) lists every RTL file per target (`rtl`, `tb`,
`fpga`, `xilinx`, `ddr`, the CVA6 configuration `cv64a6_imafdc_sv39_wb`). `hardware/Makefile` turns make variables
into defines and writes tool scripts with `bender script`. Every Makefile target requires `RISCV` and
`QUESTASIM_HOME` to be set. Its Questa targets (`scripts_vip`, `sim`) are not part of the flows below, which use xsim
and Vivado.

**Simulation** (`hardware/xsim`). `build.sh` runs `bender script vsim` with the targets and defines of `env.sh`,
converts the result with `vsim2xsim.py` into `compile.sh` (one `xvlog`/`xvhdl` call per Bender block), compiles the
work library, builds `libdpi.so` (SimJTAG, ELF loader, remote bitbang) and generates the Ethernet AXI DMA's
simulation sources (`xilinx_ip.sh`). `run.sh <l2|l3> <elf>` recompiles the testbench `tb/ariane_tb.sv` with the
flow's defines, elaborates snapshot `tb_<flow>` and runs it under a watchdog that kills a run whose simulated time
stops. The testbench writes the ELF straight into the on-chip SRAM and the simulated DRAM, starts hart 0 over JTAG,
polls `tohost` and prints `[JTAG] SUCCESS` (exit code 0, `run.sh` then exits 0) or `[JTAG] FAILED`. `l3` programs
live in DRAM (`make build`), `l2` programs in the 32 KB SRAM (`make build_l2`). In the simulation:
- DRAM: `axi_sim_mem` behind the LLC (`XSIM_SIM_DRAM`), reached through a clock-domain crossing and an `axi_delayer`
  with random stalls, as on the board; `XSIM_DRAM_IDEAL` connects it directly.
- Console: `mock_uart`. Ethernet: the real AXI DMA with a loopback MAC model.
- Off at elaboration: the flash, EEPROM, SD card, CAN, camera and USART device models (`GENERICS` in `env.sh`).
- The RTL carries xsim switches (`XSIM_*` defines).

**FPGA** (`hardware/fpga`, part `xcvu9p-flga2104-2L-e`). `make scripts-bender-fpga-ddr` writes
`fpga/alsaqr/tcl/generated/compile.tcl`; `make ips` generates the Vivado IPs from `alsaqr/tcl/ips/*/run.tcl` (boot
ROM, clock manager, DDR4 MIG, QSPI, Ethernet, Ethernet DMA, OpenTitan ROM/OTP); `make constr` concatenates the
constraints; `run.tcl` creates the project, reads IPs and constraint files chosen by environment variables (`BOARD`,
`XILINX_PART`, `MAIN_MEM`, `NUM_CORES`, `USE_OT`, `XILINX_ETH`, `OPENDRAM`) and synthesizes. The top
`fpga/ddr/alsaqr_xilinx.sv` holds the MIG (`ddr4_0`), the clock manager (`xilinx_clk_mngr`, from the 250 MHz DDR
system clock), the SoC and an `axi_cdc` from the LLC's memory port into the MIG clock. The SoC clock, also the RTC
input, is 50 MHz for `MAIN_MEM=DDR4 NUM_CORES=4` (`ips/clk_mngr/run.tcl`, `SRC_CLK_PERIOD` in `run.tcl`).
`fpga/setup.sh` exports the variables interactively; alsaqr-mcp's `config.json` holds them for the tools.

**Board.** The bitstream is programmed through Vivado's hardware server. Programs are loaded over JTAG (Olimex
ARM-USB-OCD-H on PMOD0) with OpenOCD and GDB from `alsaqr-software`; the console is the board's USB-UART at 38400
8N1. Linux (OpenSBI platform `fpga/alsaqr` and a Buildroot kernel, `alsaqr-software: linux/cva6-sdk`) boots either
from a payload and device tree loaded over JTAG or through the loader `software/netboot`, which fetches both with TFTP
over the Ethernet from `alsaqr-mcp/scripts/netboot_server.py`.

## Configuration

Make variables (or environment) of `hardware/Makefile`, applied to both simulation and FPGA defines:

| Knob | Changes |
|---|---|
| `NUM_CVA6=<n>` | core count; sizes CCU, CLINT, PLIC, debug module, APMU ports, AXI user field |
| `QOS_RCID_WIDTH`, `QOS_MCID_WIDTH` | QoS ID widths |
| `QOS_PRIV_ASSOC`, `QOS_NUM_VRCID`, `QOS_NUM_VMCID` | per-privilege QoS IDs, vRCID and vMCID tables (0 removes) |
| `SOCK_QOS_RANGES`, `ACCEL_JOB_DEPTH` | accelerator socket tag ranges, template job queue (0 removes) |
| `QOS_LLC_BC`, `QOS_LLC_WBUF`, `QOS_DMA_GATE` | LLC bandwidth controller, its write buffer, DMA admission gates (0 removes) |
| `QOS_LLC_BC_POOL` | descriptors in the bandwidth controller's parking pool |
| `xilinx-ethernet=1` + `exclude-ethernet=1` | AMD Ethernet and DMA |
| `exclude-llc=1` | no LLC |
| `simple-padframe=1` | FPGA pad frame |

Defaults live in `ip_list/cva6/core/include/ariane_pkg.sv`, `include/ariane_soc_pkg.sv`, `accel/accel_socket.sv`
(`SOCK_QOS_RANGES`) and the template accelerators (`ACCEL_JOB_DEPTH`). `quad-core`,
`exclude-cluster` and `exclude-rot` leave the contents unchanged: `QUAD_CORE` and `EXCLUDE_CLUSTER` are defined in
the sources and the OpenTitan block of `al_saqr.sv` is commented out. Source-level switches: `USE_SLOWDOWN`,
`APMU_IP`, `APMU_IOPMP` (`host/host_domain.sv`), `HTM` (`host/apb_subsystem.sv`). FPGA only: `OPENDRAM=1` puts
OpenDRAM in place of the MIG's controller. xsim only: `SOC_EXTRA_DEFINES` (e.g. `NUM_CVA6=8`) and `XSIM_WORK` (a
separate work directory per configuration). Software: `SOC_NUM_CORES`/`NUM_CVA6` must match the hardware;
`fpga=1` builds for the board.

## Using it

Agent tools: `python3 -m alsaqr_mcp serve` (MCP) or `python3 -m alsaqr_mcp <tool> key=value`; settings in
`config.json`.

| Group | Tools |
|---|---|
| Simulation | `sim_run`, `sim_status`, `sim_uart`, `sim_kill`, `sim_session` (probe/force signals), `sim_stall_trace` |
| RTL edits | `rtl_changes`, `rtl_recompile` |
| Software, navigation | `sw_build`, `soc_lookup` (addresses, modules, structs, identifiers), `soc_bootflow` |
| Validation | `sim_regress` |
| Accelerators | `accel_add`, `accel_list`, `accel_unit_test`, `accel_soc_test`, `accel_remove` |
| FPGA | `fpga_build`, `fpga_status` |
| Board | `board_program`, `board_run`, `board_regress`, `board_stop` |
| Linux | `linux_boot` (JTAG or `netboot=true`), `linux_status`, `linux_cmd` (SSH or console), `linux_copy` |

`fpga_build` regenerates the Vivado file list with `config.json`'s make line, runs `run.tcl` up to synthesis,
writes one linked checkpoint, then `scripts/fpga_impl.tcl` (opt, place, route, gate, bitstream). Its `env`
argument reaches the hardware Makefile too, so `NUM_CVA6` and the `QOS_*` knobs apply. The gate passes a build only
with no failing setup endpoint, no hold failure outside the advanced timers' clock-as-data endpoints, every net
routed, and the clock manager producing the SoC clock. The simulation tools run programs in the `l3` layout and
simulate the compiled library: an edited RTL file takes effect once `rtl_recompile` compiles it.

## Verification

- `sim_regress` suite `soc`: `software/soc_tests` `t_mem`, `t_atomics`, `t_smp`, `t_irq`, `t_socket`, `t_qos`,
  `t_cbqri`, `t_dram`, `t_dma`, `t_iotag`, `t_part`, `t_eth`, plus `hello_culsans` and `quad_boot`; suite `accel`:
  each registered accelerator's test. `board_regress` runs the same `soc_tests` on the board (its `soc` suite has no `hello_culsans` or
  `quad_boot`; its `accel` suite is `example` and `crc32`). Each prints
  `TEST PASS`/`TEST FAIL` and exits with its number of failed checks.
- Unit benches without the SoC: `hardware/xsim/tests/run_*.sh`, `hardware/deps/rv_plic/test/run_xsim.sh`.

## Properties

- An xsim run needs about 40 s of wall clock per simulated millisecond and about 2 GB of memory; elaboration about
  4 minutes.
- A bitstream build needs about 40 minutes of synthesis and 2-3 hours of implementation.

## Code

- `hardware/Makefile`, `hardware/Bender.yml`: knobs, file lists.
- `hardware/xsim/`: build and run scripts, `tools/comb_fix.py`, unit benches in `tests/`.
- `hardware/tb/ariane_tb.sv`, `hardware/tb/dpi/`: testbench, JTAG and ELF DPI.
- `hardware/fpga/`: `Makefile`, `run.tcl`, `setup.sh`, `ddr/alsaqr_xilinx.sv` (top), `alsaqr/tcl/` (constraints, IP
  scripts).
- `software/common.mk`, `software/common/`: bare-metal build, linker scripts, start-up.
- `alsaqr-mcp: alsaqr_mcp/tools.py` (registry), `scripts/` (FPGA, board, Linux runners), `config.json`.
- `alsaqr-software`: toolchains, OpenOCD, `linux/`, `tests/`.

## Reference

- `hardware/xsim/README.md`: xsim patches and debugging a stalled run.
- `alsaqr-mcp: README.md`: every tool's inputs and outputs.
- `alsaqr-resctrl: README_ALSAQR.md`: Linux with resctrl.
