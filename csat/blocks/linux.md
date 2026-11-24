# Linux

OpenSBI and Linux, with a BusyBox root filesystem, run on the CVA6 cores of the VCU118 build. This page covers the
kernels, their device trees, how they boot, and the SoC-specific kernel module and tools. All of them are built
outside this repository: in alsaqr-software (`linux/`), and the resctrl kernel in alsaqr-resctrl.

## How it works

**Payload.** OpenSBI `fw_payload` is built for the platform `fpga/alsaqr` (`cva6-sdk/opensbi`) and carries the
kernel `Image` with an initramfs root filesystem. OpenSBI sits at the start of DRAM. It copies the device tree passed
in `a1` to its FDT address (`FW_PAYLOAD_FDT_ADDR` in `objects.mk`). It drives the PLIC, the CLINT (ACLINT) and the
ns16550 UART.

**Kernels.**
- **Prebuilt default** (alsaqr-software `linux/prebuilt`): Linux 5.10.7, with `alsaqr.dts`. That tree describes four
  CPUs, a 38400 console and a 1 MHz timebase, and its `bootargs` say `maxcpus=1`.
- **Bundle build** (`linux/cva6-sdk`, output `install64/`): Buildroot with Linux 6.1.183 (`configs/`: SMP, UIO,
  Xilinx AXI Ethernet), BusyBox and dropbear. The rootfs overlay `rootfs/` holds, among other files:
  - `S45eth`, a static address on the private link to the host PC.
  - the SSH host keys.
  - `apmuctl` and `socket_dma`.
- **Eight harts** (`linux/prebuilt/8core`): OpenSBI built for eight harts around the 6.1.183 image, an eight-CPU
  device tree, and the network loader built for eight cores.
- **resctrl** (alsaqr-resctrl): Linux 7.2 with the RISC-V QoS series (Ssqosid `srmcfg` context switching, the
  `riscv_cbqri` driver, resctrl glue) and a device-tree front end, `drivers/resctrl/cbqri_dt.c`
  (`CONFIG_RISCV_CBQRI_DT`), which registers `riscv,cbqri-cache` and `riscv,cbqri-bandwidth` nodes as controllers shared by all CPUs.
  - The LLC's capacity controller (16 ways, 16 RCIDs, code/data, no monitoring) is the resctrl `L3` resource.
  - The bandwidth controller is `MB_MIN` (Rbwb) and `MB_WGHT` (Mweight). The driver leaves its non-CBQRI
    implementation registers (period, capacity, enable/pacing) to software.
  - Config: `alsaqr_resctrl_defconfig`. Device tree: `dts/alsaqr-resctrl.dts`, with `ssqosid` CPUs, L1s, the LLC as
    L3, and both CBQRI nodes.

**Device trees** (alsaqr-software `cva6-sdk`):

| File | What it describes |
|---|---|
| `alsaqr-socket.dts` | The tree for the built kernel: a 115200 console, a 25 MHz timebase (CLINT `mtime`), Ethernet and DMA, a `generic-uio` node for the accelerator socket, and a 16 MB `shared-dma-pool`. |
| `alsaqr-socket8.dts` | The same with eight CPUs. |
| `alsaqr-pmu-counting.dts` | The socket tree plus `configs/cva6-pmu.dtsi`, the SBI PMU mappings for the six HPM counters. |
| `alsaqr-pmu.dts` | The counting tree with `sscofpmf` in `riscv,isa`. |
| `alsaqr.dts` | OpenSBI's `fdt_gen` output. |

**Boot over JTAG.** alsaqr-software `linux/scripts/boot_linux.sh`, `make openocd` + `make gdb-load-payload`, and
alsaqr-mcp `linux_boot` load the DTB, set every hart's PC to the payload start, load the payload and continue.
- `linux_boot` always sets `a1` to the DTB. `boot_linux.sh` sets it only when given `DTB=`. Otherwise OpenSBI uses
  the boot ROM's tree (one CPU, no `bootargs`).
- `linux_boot` can write `srmcfg` per hart before release.

**Boot over Ethernet.** The network loader (boot.md) fetches the DTB and `fw_payload.bin` from alsaqr-mcp
`scripts/netboot_server.py` and releases every hart into the payload (`linux_boot netboot=true`). dropbear accepts
SSH logins as `root`.

**QoS IDs.**
- The 7.2 kernel switches `srmcfg` per task from resctrl groups.
- The 5.10 and 6.1 kernels write no QoS CSR. Their IDs come from `linux_boot`'s per-hart `srmcfg`, or from a loader
  built with `QOS_KERNEL`/`QOS_USER`, which gives kernel accesses `hqosid`.
- resctrl uses the loader built without `QOS_KERNEL`, so that kernel accesses carry the task's `srmcfg`.

### SoC-specific modules and tools

| Tool | Location | Purpose |
|---|---|---|
| `apmuctl` | alsaqr-software `linux/apmu` | APMU control over `/dev/mem`: load ISPM/DSPM images; run, halt or reset the APMU core; counters, selects, event info, budgets; scratchpad dumps. `apmu_abi.h` is the host↔apmu-os interface. |
| `pmu/tests` | `linux/pmu` | Host checks of the PMU device-tree bindings and of OpenSBI's `sbi_pmu` helper. |
| `llcpart.ko` | `linux/llcpart` | Kernel module: LLC way partitioning per RCID with a pointer chase (capacity, isolation against an aggressor, latency sweep). `insmodp` is a static `insmod` that passes module parameters. |
| `bw`, `chk`, `chk2`, `par` | `linux/memstress` | Per-hart bandwidth, data integrity under load, and CPU, memory and atomic stress. |
| `qosprobe` | `linux/qosprobe` | RCID and MCID of each CPU's user and kernel accesses, read through the socket's QoS probe. |
| `rdtpart`, `rdtbw` | `linux/resctrl` | resctrl workloads: partition isolation, and bandwidth per group. |
| `socket_dma` | he-soc `software/linux/socket_dma` | Socket slot 0 from user space: DMA pool, process pages, `/dev/uio0`, interrupt. |
| `t_storm_linux`, `t_iopmp_linux_n<N>` | he-soc `software/soc_tests/*/linux` | Linux ports of those bare-metal tests. |

`llcpart` builds against Buildroot's kernel tree. The others are static binaries built with Buildroot's cross
compiler; `socket_dma`'s Makefile installs it into the rootfs overlay, the others' Makefiles copy them to the board
over SSH.

## Configuration

- `NUM_HARTS` and `TARGET_FREQ` set OpenSBI's hart count, UART clock and baud rate. The baud rate follows from
  `TARGET_FREQ` in `objects.mk`.
  - `linux/scripts/build.sh` defaults to 4 harts at 50 MHz.
  - Make does not track `NUM_HARTS`: changing it needs a clean OpenSBI build.
- Loading: `PAYLOAD`, `DTB_FILE`/`DTB`, `DTB_ADDR`, and `linux_boot`'s `payload`/`dtb`.
- alsaqr-mcp `config.json` (`board.linux`) names the default JTAG payload (the prebuilt one) and the netboot set (the
  bundle build with `alsaqr-socket.dtb`).

## Using it

- Bundle kernel: `linux/scripts/build.sh`, or `make images`.
- resctrl kernel: alsaqr-resctrl `README_ALSAQR.md`.
- On the board: boot with `linux_boot`, follow with `linux_status`, run commands with `linux_cmd` (SSH after a
  netboot, otherwise the console), copy files with `linux_copy`.
- Register addresses that the tools use live in the SoC packages and `software/quad_boot/pmu_defines.h`.
  `soc_lookup` returns them.

## Verification

Checks are run by hand, not as a suite:
- `linux_status` milestones (OpenSBI, kernel, shell).
- `linux_cmd cmd=socket_dma` printing `SOCKET_DMA PASS`.
- `qosprobe`.
- `apmuctl example_bubble`.
- `rdtpart` and `rdtbw`.
- `pmu/tests`.

## Properties

- `rdcycle` stands still under the SBI PMU driver: OpenSBI sets `mcountinhibit` and CVA6 honours it. A perf cycles
  event clears the inhibit bit on its CPU. `rdtime` always runs.
- Out of reset the LLC caches the first 8 MB of DRAM. Shrinking the cached range on a running system wedges the SoC.
  The network loader widens it to all of DRAM before anything else runs.
- Linux starts every CPU in the device tree. A hart that did not enter OpenSBI fails to come online.
- OpenSBI's memory is PMP-protected against `/dev/mem`.

## Code

- alsaqr-software `linux/cva6-sdk/`:
  - `configs/`: Buildroot, kernel and BusyBox configs.
  - `opensbi/platform/fpga/alsaqr`: the OpenSBI platform.
  - device trees.
  - `rootfs/`: the rootfs overlay.
  - `linux_patch_6.1`: kernel patches.
- alsaqr-software `linux/prebuilt/`: prebuilt payloads and device trees.
- alsaqr-software `linux/scripts/`: payload build and JTAG boot.
- alsaqr-software `linux/apmu`, `pmu`, `llcpart`, `memstress`, `qosprobe`, `resctrl`: the SoC tools.
- alsaqr-software `Makefile`: `openocd`, `gdb-load-payload`, `images`, `dtb`.
- alsaqr-resctrl `kernel/`, `dts/alsaqr-resctrl.dts`: the 7.2 resctrl kernel and its device tree.
- he-soc `software/linux/socket_dma/`: the socket DMA test.

## Reference

- alsaqr-resctrl `README_ALSAQR.md`.
- he-soc `hardware/docs/ethernet.md`, `hardware/docs/qos.md`.
- alsaqr-software `linux/llcpart/README.md`, `linux/memstress/README.md`, `linux/prebuilt/8core/README.md`.
- alsaqr-mcp `README.md`: `linux_boot`, `linux_cmd`, `linux_copy`.
