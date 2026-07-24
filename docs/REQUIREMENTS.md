# Requirements

## Hardware

- **Simulation:** a Linux host with **Siemens QuestaSim** installed.
- **FPGA / board (optional — only to reproduce the paper's on-board results):** a Xilinx
  **VCU118** evaluation board.

## Software

| Tool | Purpose | Version used |
|------|---------|--------------|
| Siemens **QuestaSim** | RTL simulation (`vsim`) | <!-- e.g. 2021.2 --> |
| AMD **Vivado** | FPGA bitstream for VCU118 | <!-- e.g. 2021.2 --> |
| **RISC-V GCC** (`riscv64-unknown-elf-`) | build the bare-metal tests | <!-- e.g. installed at /opt/riscv64 --> |
| Host **OS** | — | <!-- e.g. Ubuntu 20.04 --> |

All IP dependencies, verification IPs (VIPs), and the `bender` binary are **vendored** in
the repository (on the `main` branch), so **no network access or `make init` is required**
for simulation.
