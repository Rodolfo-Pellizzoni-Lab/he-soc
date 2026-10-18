# Ethernet on the VCU118: the AMD AXI Ethernet subsystem in the SoC

Branch `ethernet`. The board's on-board 1G port (TI DP83867 PHY, SGMII over LVDS into an HP bank, no transceiver)
is driven by the AMD **AXI 1G/2.5G Ethernet Subsystem** (axi_ethernet 7.2: tri-mode MAC + SGMII PCS/PMA) with an
**AXI DMA** (axi_dma 7.1, scatter-gather). The PULP ethernet that used to sit on the host crossbar's Ethernet port
is excluded from the build (`exclude-ethernet=1 xilinx-ethernet=1`, macro `XILINX_ETHERNET`); the Xilinx pair takes
that port. Purpose: boot Linux over the network instead of JTAG, and give the host a way to send traffic to the
SoC for tests.

## Hardware

`hardware/host/xilinx_eth_subsys.sv`, instantiated by `ariane_peripherals` (`InclXilinxEth`):

| Where | What |
|---|---|
| 0x3000_0000, 256 KB | AXI Ethernet registers (AXI-Lite, 32-bit; the 64-bit xbar port goes through cut, width converter, AXI-Lite bridge, demux on address bit 18) |
| 0x3004_0000, 64 KB | AXI DMA registers (MM2S = TX at +0x00, S2MM = RX at +0x30) |
| PLIC 3 | the Ethernet subsystem's interrupt |
| PLIC 11 / 15 | DMA TX / RX completion (previously unused sources), taken only once the DMA's reset-out lines have been high for 8 cycles |

**DMA path.** The DMA's three AXI masters (descriptors, 32-bit; TX reads and RX writes, 64-bit) are upsized, muxed
(IDs 0, 2, 4) and split into single beats (`axi_burst_splitter`). In `cva6_subsystem` they are muxed with the
accelerator socket's DMA on 3-bit IDs into a 4-bit one, which is the coherence unit's own ID width
(`axi_id_width_adapt` zero-extends and truncates around it), and enter the CCU's DMA port (`cva6_synth_wrap`,
`DmaCcuPort`): every read is a ReadOnce, every write a WriteUnique, so received frames and descriptor updates are
coherent with the cores' write-back L1 caches without any software maintenance. That is what Linux 5.10 on RISC-V
needs (it has no non-coherent DMA support). Both DMAs share one in-order port, so they serialise each other.
(`axi_id_serialize` with one unique ID was tried first and deadlocked: it re-issued a read whose response it then
refused; the probes are in the branch history.)

**Clocks and pins.** The AXI side of both IPs runs on the 50 MHz SoC clock (the IP's AXI clock range is 10-300
MHz). The IP takes the PHY's 625 MHz LVDS clock directly (`xeth_lvds_clk_p/n`, AT22/AU22) and derives its own
312.5/125 MHz; `hardware/fpga/alsaqr/tcl/eth_vcu118.xdc` has the pins (SGMII RX AU24/AV24, TX AU21/AV21,
DIFF_HSTL_I_DCI_18 with 0.9 V internal VREF, MDC AV23, MDIO AR23, PHY reset BA21) and declares the IP's clocks
asynchronous to the SoC. The pins are threaded as `pad_to_xeth_t`/`xeth_to_pad_t` (ariane_soc_pkg) from
`ariane_peripherals` up to `al_saqr`, which has the MDIO IOBUF, and the FPGA top `fpga/ddr/alsaqr_xilinx.sv`.

**The IPs in the flow.** `hardware/fpga/alsaqr/tcl/ips/eth` and `ips/eth_dma` generate them (`make ips`); the
configuration lives in each `config.tcl` and is shared with the simulation. `run.tcl` reads the two xci files and
the pin file when `XILINX_ETH=1` (alsaqr-mcp `config.json` sets it, with `exclude-ethernet=1 xilinx-ethernet=1`
in the bender make line). The AXI Ethernet needs the `tri_mode_eth_mac` license key; the AVB key it also lists is
covered by Vivado's bundled design-linking licenses.

**Simulation.** The same `xilinx_eth_subsys` runs in xsim: `eth_dma` is the IP's own VHDL (plain RTL, no
license), generated from `ips/eth_dma/config.tcl` by `hardware/xsim/xilinx_ip.sh` into `work/xilinx_ip` and
compiled into its eight libraries (`libs.txt`, picked up with `-L` by run.sh and the alsaqr-mcp runners);
`eth_sgmii` is `tb/eth_sgmii_model.sv`, a register file with MDIO emulation of the DP83867 (address 3) and the
PCS/PMA (address 1), and a MAC that loops every transmitted frame back as a received one with the 6-word status
stream the DMA expects (tag + app0-4, length in the last word). The DMA control stream's tag word is produced by
the DMA itself, so the stand-in accepts and ignores that stream.

Two simulation-only aids live in the RTL under `ifndef SYNTHESIS`: `tb/axi_x_monitor.sv` instances on the DMA's
output, on the coherence unit's DMA port and on both sides of the LLC report the first AXI handshakes that carry
an X (none in a healthy run), and the interrupt gate above exists because of a start-up glitch of the IP's VHDL:
about 90 ns after reset release its reset-out lines go high for one cycle and drop again, and in that cycle its
interrupt registers are recomputed from not-yet-initialised flags, so both interrupt outputs are X for one cycle.
The PLIC gateway latches that into its sticky interrupt-active bits, a later read of the pending register returns
X, and the branch that tests it poisons the core's frontend (this showed up as a livelock after the burst phase of
t_eth; the trail is in the branch history).

## Software

`software/eth/include/xeth.h`: polled driver (MDIO, DP83867 extended registers, descriptor rings in cached
DRAM, MAC setup, PHY link, PCS loopback). Register names are the Linux driver's (`xilinx_axienet.h`).

`software/soc_tests/t_eth`: bring-up (DMA reset, rings, MDIO scan), frames of 14 to 1514 bytes through the
loopback from cached buffers written by the core and into cached buffers the core had read before (coherence),
a burst that fills the TX ring, the two DMA interrupts at the PLIC (a gateway keeps a source pending until it is
claimed, so the test clears the DMA status register and then claims and completes at the hart 0 context), and on
the board a listen window on the LAN.
In xsim the loopback is the stand-in's; on the VCU118 it is the PCS/PMA's own loopback bit, so no cable is needed
for the checks. The test first writes the PHY's SGMIICTL register (0x4000: 6-wire mode) because the DP83867 only
drives the 625 MHz clock the PCS needs once that bit is set, as the IP's own example design does; only then does the
PCS/PMA answer on MDIO (at address 1, and at 0, with the identifier 0x0174/0x0C00), and the MAC's interrupt status
shows RxDcmLock, MgtRdy and PhyRstCmplt. On the board (bitstream `ethernet`, 2026-10-17): TEST PASS 37 checks, round
trips 2332 cycles for 14 bytes to 27981 for 1514. The test needs about 60 s on the board (`board_regress
sleep_ms=90000`).

`software/netboot`: the network boot loader. Linked at 0x8F00_0000 (`netboot.ld`), it brings the link up, gets
an address with DHCP (or `STATIC_IP=`), finds the server with a UDP broadcast (`ALSAQR-NETBOOT?` on port 6969,
fallback `SERVER_IP=`), fetches `alsaqr.dtb` to 0x8180_0000 and `fw_payload.bin` to 0x8000_0000 with TFTP
(blksize 1428) and jumps to the payload with a0 = hart id, a1 = the DTB, which is what the JTAG flow sets up.
It answers ARP and ping meanwhile. The server is `alsaqr-mcp/scripts/netboot_server.py --dir <install64>`,
unprivileged (port 6969). Build: `make fpga=1 SERVER_IP=<host>`.

**Linux** (alsaqr-software bundle): `configs/linux64_defconfig` now enables networking, `XILINX_AXI_EMAC`
(phylink) and `DP83867_PHY`; `alsaqr-socket.dts` has the `ethernet@30000000` node (phy-mode sgmii, the PHY at
MDIO 3 with `ti,sgmii-ref-clock-output-enable`) and `dma@30040000` (`axistream-connected`, interrupts TX 11, RX
15); busybox gets ifconfig/ip/ping/route/udhcpc/tftp/nc/arp/netstat/wget/telnetd, and `rootfs/etc/init.d/S45eth`
brings eth0 up with DHCP at boot. The 5.10 axienet driver does not manage the PCS/PMA itself; the PCS's SGMII
auto-negotiation with the PHY is on by default and the MAC speed follows the PHY through phylink.
