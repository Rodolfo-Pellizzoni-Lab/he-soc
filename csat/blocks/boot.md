# Boot

This page covers how harts leave reset, where they wait, and how a program or the Linux payload reaches memory and
starts them. The parts are the boot ROM, the start-up code of bare-metal programs, JTAG loading, and the network
loader that fetches Linux over Ethernet.

## How it works

**Boot ROM.** Every hart resets into the boot ROM. Its address is `ariane_soc::ROMBase`, the core boot address set
in `cva6_subsystem`. `bootrom.S` puts the stack in the on-chip SRAM, points `mtvec` at a `wfi` loop and calls `main`
(`src/main.c`). `main` sets `a0` to the hart ID and `a1` to the device tree built into the ROM (`occamy.dts`: one
CPU, no `bootargs`). It then parks the hart:
- **Harts 0 and 1** sleep in `wfi` until the claim register of their S-mode PLIC context (2h+1) returns the SCMI
  mailbox interrupt.
- **Hart h >= 2** sleeps in one `wfi` and is woken by the overflow interrupt of APMU counter h-2.

The ROM then completes the interrupt and clears enable word 0 of the context. On this PLIC, a write to one enable
word clears every other enable word of that context too. The ROM clears the mailbox doorbell and jumps to the
address in mailbox word 0.

Three properties follow:
- The ROM runs with `mie` clear, so only a source enabled on the hart's S-mode context ends its `wfi`.
- For harts 2 and up, the ROM completes the source without claiming it. The source stays pending and the counter
  stays overflowed until the waking program clears the counter and claims and completes the source.
  `soc_wake_all()` in `soc_test.h` does this.
- The ROM never fetches code. A debugger or a loader puts programs in memory. `cva6_subsystem` holds the first debug
  request back for `DmiDelCycles` so that `a0` and `a1` are set before a debugger can halt a hart.

**Start-up code** (`software/common/crt.S`, `syscalls.c`), shared by all bare-metal programs:
- Each hart takes its own stack slice (`__stack_harts` x `__stack_size`; `test.ld` reserves 8 x 8 KB, and
  `crt.S` assumes 4 x 8 KB for a linker script that sets neither). A hart beyond the slices parks.
- Board builds clear `.bss` on hart 0.
- In `_init`, hart 0 sets up the UART, enables the mailbox interrupt on hart 1's S-mode context, writes the start of
  `.text.init` (the DRAM entry of `test.ld` programs) into mailbox word 0 and rings the doorbell, so hart 1 enters
  the same program.
- Every hart sets its bit in `harts_up`. The weak `thread_entry` parks harts other than 0.
- Harts 2 and up run only once the program wakes them.
- The exit code goes to `tohost` in the on-chip SRAM.

**JTAG loading.**
- *Simulation:* the testbench (`hardware/tb/ariane_tb.sv`) halts hart 0 through the debug module, writes the ELF into
  the DRAM model and the SRAM, resumes hart 0 at the entry and finally reads `tohost`.
- *Board:* OpenOCD and GDB from alsaqr-software load the ELF and resume it. alsaqr-mcp `board_run` drives harts 0 and
  1 as OpenOCD's SMP group. It resumes harts 2 and up with debug-module writes into the ROM's park loop.

**Network loader** (`software/netboot`). This bare-metal program is loaded over JTAG onto hart 0. It is linked high
in DRAM (`netboot.ld`), clear of what it loads. It runs these steps:
1. Widens the LLC's cached address range to all of DRAM. Out of reset the range covers the first 8 MB.
2. Brings up the Xilinx AXI Ethernet (`xeth.h`).
3. Takes an address by DHCP, or a static one.
4. Finds the server by UDP broadcast, or asks `SERVER_IP`. Fetches `alsaqr.dtb` and `fw_payload.bin` with TFTP to
   where OpenSBI expects them. It retries indefinitely and answers ARP and ping meanwhile.
5. `jump()` stops the Ethernet DMA, writes `enter_payload` into the mailbox, rings hart 1 and wakes harts 2 and up
   with `soc_wake_all()`.
6. All harts enter the payload with `a0` = hart ID and `a1` = DTB. Hart 0 goes first and is OpenSBI's cold-boot
   hart.

The loader's own `syscalls.c` differs from the common one only in that it does not send hart 1 to the entry.

## Configuration

- **ROM image.**
  - `make` in `hardware/host/bootrom` builds `bootrom.elf` and generates `bootrom.sv` (`gen_rom_sv.py`), which the
    simulation uses.
  - The FPGA uses `hardware/fpga/ddr/boot_rom.sv`: a 1024 x 64-bit Xilinx ROM IP initialised from `boot_code.coe`.
    `make fpga-coe` generates that file from `bootrom.sv`.
  - `hardware/host/bootrom_aplic` is the ROM for `USE_APLIC` builds. No flow of this SoC defines `USE_APLIC`.
- **Network loader `make` variables.**
  - `fpga=1`: build for the board.
  - `SERVER_IP`: a fixed server address.
  - `STATIC_IP`, `STATIC_MASK`, `STATIC_GW`: a static address instead of DHCP.
  - `LLC_CACHED_END`: the end of the LLC cached range. 0 keeps the reset range. It is read only with `SERVER_IP`.
  - `SOC_NUM_CORES` or `NUM_CVA6`: the harts released into the payload. The default is 4.
  - `QOS_KERNEL=<RCID | MCID << 16>`: every hart enters the payload with the HS bit of `mqosctl` set and `hqosid` =
    `QOS_KERNEL`, so kernel (HS-mode) accesses carry these IDs.
  - `QOS_USER`: hart 0's `srmcfg`. Hart h gets `QOS_USER` plus h in both RCID and MCID. The default is 0, and it is
    read only with `QOS_KERNEL`.

  - `QOS_FIRMWARE=<RCID | MCID << 16>` (with `QOS_KERNEL`): also sets the M bit of `mqosctl` and `mqosid`, so
    OpenSBI's accesses carry these IDs.

  Without the QoS CSRs, the loader leaves the IDs at their reset values. Without `QOS_FIRMWARE`, M-mode (OpenSBI)
  carries `srmcfg`, so firmware work on a hart is throttled with the task running there; next to a hard-limited
  group this stalls other cores through kernel locks (hardware/docs/qos.md, `t_bchol` entry).

## Using it

- **Harts 1 and up:** override `thread_entry(cid, nc)` to run code on them. `soc_wake_all()` starts harts 2 and up.
- **Network boot:** build the loader with `make fpga=1 SERVER_IP=... STATIC_IP=...` and serve a directory holding
  `alsaqr.dtb` and `fw_payload.bin` with alsaqr-mcp `scripts/netboot_server.py`. `linux_boot netboot=true` loads a
  built loader over JTAG and serves the payload and device tree itself.
- **Constants:** the mailbox, PLIC source and context numbers are in `bootrom/src/main.c` and `soc_test.h`.
  `soc_lookup` returns the addresses. `soc_bootflow` describes the simulated boot.

## Verification

In alsaqr-mcp's `sim_regress` `soc` suite:
- `hello_culsans` checks harts 0 and 1 through the mailbox.
- `quad_boot` checks harts 0 to 3 through the mailbox and the APMU wake-up.
- `soc_tests/t_smp` checks every core.

For the network loader, `linux_status` reports its milestones (link, transfer, OpenSBI, kernel, shell).

## Code

- `hardware/host/bootrom/`: the ROM source (`bootrom.S`, `src/main.c`), `occamy.dts`, and the generators.
- `hardware/fpga/ddr/boot_rom.sv`, `hardware/fpga/alsaqr/tcl/ips/boot_rom/`: the FPGA ROM and its `.coe`.
- `hardware/host/cva6_subsystem.sv`: the ROM instance, boot address and debug-request delay.
- `software/common/`: start-up code and `test.ld`.
- `software/soc_tests/include/soc_test.h`: `soc_wake_all`, `soc_wait_harts`.
- `software/netboot/`: the network loader.
- `software/eth/include/xeth.h`: the Ethernet and DMA driver.
- `hardware/tb/ariane_tb.sv`: JTAG load in simulation.

## Reference

- `hardware/docs/ethernet.md`: the network loader and the host link.
- `hardware/docs/cores.md`: more than four harts.
- alsaqr-mcp `README.md`: `soc_bootflow`, `board_run`, `linux_boot`.
