# Peripherals

The memory-mapped devices on the host AXI crossbar other than memory, caches and QoS controllers: the interrupt
controllers (PLIC, CLINT), the console UART, the RISC-V debug module behind JTAG, the AMD AXI Ethernet with its DMA,
and the peripheral subsystem inherited from the AlSaqr SoC.

## How it works

Every device is a slave of the host crossbar `i_xbar` in `cva6_subsystem` (index `ariane_soc::axi_slaves_t`, window
`soc_bus_start_t` and the `*Length` constants). Most sit in `ariane_peripherals`, which also gathers every interrupt
line of the SoC into the PLIC's source vector `irq_sources`.

**PLIC** (`plic_top`, `deps/rv_plic`): 255 sources, two contexts per hart (machine, supervisor), 7 priority levels,
every source level-sensitive; reached through `axi2apb_64_32` and `apb_to_reg`. Parts:
- `rv_plic_gateway`: per source; keeps it pending until claimed, accepts it again after the complete.
- `rv_plic_target`, one per context, `TREE` algorithm: a balanced binary max-finder, log2(sources) levels. A source
  competes only with a priority strictly above the context's threshold; on a tie the lower ID wins; the output is
  registered.
- `plic_regs` (`plic_regmap.sv`): the register map, parameterised in sources and contexts.

Sources: UART, QSPI, APB timer, Ethernet MAC and DMA TX/RX, accelerator socket, mailboxes, CFI snooper, IOPMP,
IOMMU, uDMA events, CAN, advanced timers, 32 APMU counter overflows, 64 GPIOs.

**CLINT** (`deps/clint`): software-interrupt and timer-compare registers per hart and one `mtime`; its interrupts go
to the cores directly. `mtime` advances once every two RTC cycles (`rtc_clint` halves the RTC input). The VCU118 top feeds the SoC clock as
RTC, so `mtime` runs at half the SoC clock; the testbench feeds a slow RTC.

**Console UART** (`apb_uart`, `deps/apb_uart`, 16550-compatible VHDL), instantiated in `TARGET_SYNTHESIS` (Vivado)
builds; RTL simulation puts `mock_uart` in its slot, which prints whole lines. The divisor latch's low byte is a
constant: any write stores the divisor for 38400 baud at a 50 MHz SoC clock; the high byte stays writable. FPGA
builds have a second `apb_uart` in the APB subsystem.

**Debug** (`dm_top` + `dmi_jtag`, PULP `riscv-dbg`): a RISC-V debug module (specification 0.13) for all harts behind
a JTAG TAP. Its debug memory is crossbar slave `Debug_Slv`, its system-bus access crossbar master `DEBUG_MST`. Debug
requests are masked for `DmiDelCycles` after reset so the boot ROM runs first. Its bus bridge resets with `ndmreset`,
like the crossbar; the module itself only at power-on. On the VCU118 the TAP is on the PMOD0 header.

**Ethernet** (`xilinx_eth_subsys`, define `XILINX_ETHERNET`): the AMD AXI 1G/2.5G Ethernet Subsystem 7.2 (tri-mode
MAC, SGMII-over-LVDS PCS/PMA, 8 KB buffers, statistics counters) and AXI DMA 7.1 (scatter-gather with control and
status streams, 64-bit data). One crossbar window holds both register files (cut, width converter, AXI-Lite bridge,
demux). The DMA's three masters (descriptors, TX reads, RX writes) are muxed with distinct IDs, split into single
beats and enter the coherence unit on their own DMA port (`ariane_soc::CcuEthPort`), so frames and descriptors are
coherent with the L1 data caches. Interrupts: MAC, DMA TX, DMA RX; the DMA's pass only after its reset-out lines have
been high for 8 cycles. Both IPs run on the SoC clock; the PCS/PMA takes the 625 MHz LVDS clock of the board's
DP83867 PHY. In xsim `eth_dma` is the IP's VHDL and `eth_sgmii` is `tb/eth_sgmii_model.sv` (MDIO emulation, a MAC
that loops every frame back).

**Other crossbar slaves:**

| Slave | Device |
|---|---|
| `ROM` | boot ROM (`bootrom`; a Xilinx ROM IP on the FPGA) |
| `Timer` | `apb_timer`: two timers, four interrupts |
| `SPI` | FPGA: AMD AXI Quad SPI on the STARTUP primitive (configuration flash); else an error responder |
| `SDMA_CFG`, `IOMMU_CFG` | S-mode iDMA (`dma_core_wrap`) behind `riscv_iommu` |
| `PMUS_IOPMP` | the `riscv_iopmp` in front of the APMU's master port |
| `Snooper` | CFI snooper (`deps/snooper`) |
| `AXILiteDom` | `axi_lite_subsystem`: LLC configuration, two `axi_lite_mailbox`, the SCMI mailbox (wakes hart 1), APMU, EVU and token-bucket configuration |
| `APB_SLVS` | `apb_subsystem`: SoC control (`apb_soc_control`), clock control, GPIO, advanced timers, 2 CAN, pad frame, monitor counters, HTM block, uDMA (`udma_subsystem`: SPI, I2C, UART, USART, SDIO, camera, HyperBus) |
| `MDMA_CFG`, `IOPMP_CFG`, `IMSIC` | error slaves |

## Configuration

- `NUM_CVA6` sets the PLIC contexts and the harts of the CLINT and the debug module.
- `xilinx-ethernet=1` with `exclude-ethernet=1` (both flows) builds the AMD Ethernet; with neither, the window holds
  the PULP RGMII MAC (`framing_top`); with `exclude-ethernet=1` alone, an error slave.
- `USE_APLIC` would replace the PLIC by an APLIC and IMSIC; no flow defines it.
- Ethernet IP settings: `hardware/fpga/alsaqr/tcl/ips/{eth,eth_dma}/config.tcl`; `hardware/xsim/xilinx_ip.sh`
  generates the simulation DMA from the same `eth_dma` configuration.

## Using it

- Windows, PLIC source numbers and register layouts are in `ariane_soc_pkg.sv`, the `irq_sources` assignments of
  `ariane_peripherals.sv` and the header of `plic_regmap.sv`; `soc_lookup` (alsaqr-mcp) returns them.
- Bare metal: `software/soc_tests/include/soc_test.h` (console, wake-up of the other harts) and
  `software/eth/include/xeth.h` (polled Ethernet driver; register names of Linux's `xilinx_axienet.h`).
- Linux: `alsaqr-software: linux/cva6-sdk/alsaqr-socket.dts` (`riscv,clint0`, `riscv,plic0`, `ns16550`,
  `xlnx,axi-ethernet`, `xlnx,axi-dma`). The console runs at 38400 baud whatever divisor the driver writes.
- Debugger: OpenOCD and GDB from `alsaqr-software`, Olimex ARM-USB-OCD-H on PMOD0.

## Verification

- `software/soc_tests/t_irq`: CLINT interrupts, PLIC registers. `t_eth`: DMA rings, MDIO, looped-back frames of 14
  to 1514 bytes from cached buffers, both DMA interrupts at the PLIC. `hello_culsans`, `quad_boot`: console and
  wake-up. All four are in the `soc` suite of `sim_regress`; `t_irq` and `t_eth` also in `board_regress`
  (alsaqr-mcp).
- `hardware/deps/rv_plic/test/run_xsim.sh`: PLIC versus generated register maps, cycle by cycle.
- `hardware/xsim/tests/run_dm_bridge.sh`: the debug bus bridge across `ndmreset`.

## Properties

- A write to one enable word of a PLIC context stores that word and clears the context's other enable words.
- The Ethernet DMA issues single-beat requests to 32-bit addresses and shares the coherence unit with the cores and
  the accelerator socket's DMA.

## Code

- `hardware/host/ariane_peripherals.sv`: PLIC, UART, QSPI, Ethernet choice, timer, iDMA, IOMMU, interrupt map.
- `hardware/host/cva6_subsystem.sv`: crossbar, address rules, CLINT, debug module, boot ROM.
- `hardware/include/ariane_soc_pkg.sv`: slave indices, windows, PLIC sizes.
- `hardware/deps/rv_plic/`, `hardware/deps/clint/`, `hardware/deps/apb_uart/`, `hardware/ip_list/riscv-dbg/`.
- `hardware/host/xilinx_eth_subsys.sv`, `hardware/tb/eth_sgmii_model.sv`: Ethernet, simulation stand-in.
- `hardware/host/axi_lite_subsystem.sv`, `apb_subsystem.sv`, `udma_subsystem.sv`, `apb_soc_control.sv`.
- `hardware/fpga/alsaqr/tcl/fmc_board_vcu118.xdc`, `eth_vcu118.xdc`: board pins.

## Reference

- `hardware/docs/ethernet.md`: Ethernet registers, DMA traffic, Linux driver setup.
