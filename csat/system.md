# AlSaqr

AlSaqr is a multicore RISC-V SoC built from PULP-platform IP, for research on centralized performance monitoring and
on regulating what cores, an accelerator and DMA devices share: the last-level cache and DRAM bandwidth. It runs in
simulation and on an FPGA board, where it boots Linux.

## Structure

A core's memory request passes a token bucket and a snooper of the performance-monitoring unit (APMU) into the
coherence unit (CCU), which keeps the L1 data caches coherent. The accelerator socket's DMA and the Ethernet DMA enter
the CCU on ports of their own, each behind an admission gate. From the CCU, requests cross the host AXI crossbar and
an atomics adapter to the last-level cache (LLC); its misses and write-backs pass a snooper, a slowdown regulator and
a DRAM timing model to DRAM. Other crossbar masters (debug module, peripheral DMAs, APMU) reach the LLC without
passing the CCU, so they are not snooped. Peripherals are crossbar slaves. Event units in the cores and snoopers
report to the APMU.

## Features

### CVA6 application cores
- Four 64-bit CVA6 cores by default (a build knob).
- RV64IMAFDC with the hypervisor extension; Sv39; 16-entry TLBs; 8 PMP entries.
- L1: I$ 8 KiB 2-way; D$ 16 KiB 8-way, write-back, 16-byte lines, coherent over ACE.
- Six programmable HPM counters with Sscofpmf; an event unit (EVU) per core feeds the APMU.
- Ssqosid plus custom per-privilege and guest QoS IDs.

Docs: csat/blocks/cores.md

### Interconnect
#### Coherence unit (CCU)
- PULP Culsans snooping ACE interconnect: one port per core plus two non-caching, coherent DMA ports.
- One state machine handles shareable transactions one at a time; up to 8 memory reads overlap inside it.
- An ID remapper between the CCU and the crossbar holds 4 IDs with one transaction each per direction: at most 4
  reads and 4 writes from all CCU ports together are in flight to the LLC.

Docs: csat/blocks/coherence.md

#### Crossbars
- Host AXI crossbar: 10 master ports, 20 slave windows.
- AXI4-Lite crossbar for configuration registers; APB bridge for the inherited peripherals.

Docs: csat/blocks/peripherals.md

### Memory
#### Last-level cache
- PULP axi_llc: 1 MiB, 16 ways, 1024 sets, 64-byte lines, write-back, tree pseudo-LRU.
- Ways can serve as scratchpad; addresses outside a programmable cached window bypass it.

Docs: csat/blocks/llc.md

#### DRAM
- VCU118: 512 MB DDR4 behind the AMD DDR4 MIG; OpenDRAM, an open controller, can replace the MIG's.
- A slowdown regulator with compile-time settings caps the request rate and delays responses.
- Our DRAM timing model, in the style of FASED, holds each response until a programmed latency and data-bus time
  have passed, counted in SoC cycles, so DRAM shows the timing of a modelled target; responses the real DRAM
  delivers later than modelled are counted. It is off at reset.

Docs: csat/blocks/dram.md

### Quality of service
Requests from the cores and the accelerator socket carry a QoS tag: a resource-control ID (RCID), a
monitoring-counter ID (MCID) and the access type; other masters carry tag 0. Beyond Ssqosid, the cores
give M, HS and VS mode IDs of their own, the analogue of AMD PLZA, and translate a guest's virtual IDs through
hypervisor tables. The LLC enforces the tags with two RISC-V CBQRI controllers: a capacity controller with a way mask
per RCID and access type, and our bandwidth controller, which shares the LLC's memory traffic among RCIDs by
reservation and weight, with hard limits, and counts bytes per MCID. A write buffer and DMA admission gates keep a
throttled requester from holding up others. Linux drives the controllers through resctrl.

Docs: csat/blocks/qos.md

### Accelerator socket
Our socket for custom accelerators, in the place of PULP's multicore cluster, which is not built. Its eight slots each
get a 64 KB register window and share one interrupt and one DMA master, which is coherent with the cores' caches. The
socket tags each DMA request per job, by address range or by slot. Two accelerators are fitted: an example and CRC32.

Docs: csat/blocks/accelerator.md

### Performance monitoring (APMU)
The Advanced Performance Monitoring Unit is our central monitor. The cores' event units and snoopers (SPUs) on the
cores' CCU ports, the LLC memory port and the accelerator DMA feed 32 programmable counters, each able to interrupt.
A periodic timer reloads per-period budgets, for MemGuard-style regulation. A 32-bit Ibex with 8 KiB instruction and
128 KiB data scratchpads runs policies off the application cores, reaching the counters, the event units and a token
bucket per core that limits the core's request rate.

Docs: csat/blocks/apmu.md

### Peripherals and I/O
- PLIC (255 sources, M and S context per hart) and CLINT.
- 16550 UART console at 38400 baud, set in hardware.
- RISC-V debug module (0.13) over JTAG.
- AMD AXI Ethernet subsystem at 1 Gb/s (SGMII) with a scatter-gather AXI DMA.
- IOMMU-backed DMA, IOPMP, mailboxes, GPIOs, timers, CAN, PULP uDMA.
- Not built: PULP cluster, OpenTitan, APLIC/IMSIC.

Docs: csat/blocks/peripherals.md

## Software
Bare-metal programs are built in this repository. Toolchains, OpenOCD, OpenSBI and Linux, and board benchmarks are in
alsaqr-software; a Linux 7.2 kernel with resctrl support is in alsaqr-resctrl.

### Boot
A boot ROM parks every hart until an interrupt (mailbox for harts 0 and 1, APMU counter for the others), then jumps
to an address left in the mailbox. Programs load over JTAG. A network loader fetches Linux over Ethernet with TFTP and
can give kernel and user code separate QoS IDs.

Docs: csat/blocks/boot.md

### Linux
- OpenSBI and Linux with a BusyBox initramfs, four harts (eight for the eight-core build).
- Kernels: Linux 5.10.7 prebuilt for JTAG boot; Linux 6.1.183 with Ethernet and SSH, booted over Ethernet; Linux
  7.2 with resctrl.
- SoC tools for the APMU, LLC partitioning, QoS probing and accelerator DMA.

Docs: csat/blocks/linux.md

### Bare-metal tests
33 SoC test programs, each built from the same source for simulation or for the board; most are self-checking,
a few are mainly measurements. 12 of them and two boot tests form the regression suite. Most other bare-metal
directories are inherited PULP programs.

Docs: csat/blocks/soc-tests.md

### APMU firmware
RV32IM programs for the APMU's Ibex, bare or as components of apmu-os (a small OS for it), loaded by a CVA6
program or from Linux.

Docs: csat/blocks/apmu-firmware.md

## Platforms
- Simulation: Vivado xsim with behavioural DRAM; every run checks QoS tags and LLC allocations.
- FPGA: AMD VCU118, 50 MHz, four cores, DDR4; boots Linux.
- The alsaqr-mcp agent tools drive both.

Docs: csat/blocks/flows.md

## Variants
Hardware build variables, also settable through the FPGA build environment or simulation defines:
- `NUM_CVA6`: core count (4).
- `QOS_RCID_WIDTH`, `QOS_MCID_WIDTH`: QoS ID bits (4).
- `QOS_PRIV_ASSOC`, `QOS_NUM_VRCID`, `QOS_NUM_VMCID`: per-privilege IDs, guest ID translation (16 entries).
- `SOCK_QOS_RANGES`, `ACCEL_JOB_DEPTH`: socket range tags (16), per-job queue (4).
- `QOS_LLC_BC`, `QOS_LLC_BC_POOL`, `QOS_LLC_WBUF`, `QOS_DMA_GATE`: bandwidth controller (16-entry pool), write
  buffer (8), DMA gates.
- `xilinx-ethernet`: the AMD Ethernet and its DMA (set in the simulation and FPGA flows). `exclude-llc`: no LLC. `OPENDRAM=1` (FPGA): OpenDRAM.

## Repository
- `csat/`: system and block docs.
- `hardware/host/`, `hardware/include/`: SoC integration and packages.
- `hardware/ip_list/`, `hardware/deps/`: IP (CVA6, CCU, LLC, APMU, PLIC, ...).
- `hardware/accel/`: accelerator socket.
- `hardware/xsim/`, `hardware/tb/`: simulation.
- `hardware/fpga/`: VCU118 build.
- `software/`: bare-metal programs.
- `hardware/docs/`: detailed design notes and measurements.
- `docs/`: artifact-evaluation documents.

## Glossary
- **APMU:** Advanced Performance Monitoring Unit.
- **CBQRI:** RISC-V Capacity and Bandwidth QoS Register Interface.
- **CCU:** cache coherence unit (PULP Culsans).
- **EVU:** a core's event unit.
- **FASED:** a style of FPGA memory timing model.
- **MemGuard:** per-period memory budgets per core.
- **MIG:** AMD DDR4 memory interface IP.
- **PLZA:** AMD Privilege Level Zero Association: kernel-mode accesses get QoS IDs of their own.
- **RCID / MCID:** resource-control / monitoring-counter ID.
- **Ssqosid:** RISC-V extension giving a hart QoS IDs.
- **SPU:** snooper reporting an AXI port's traffic to the APMU.
