# Requirements

## Hardware

- **Simulation:** a Linux host with **Siemens QuestaSim** installed.
- **FPGA / board (optional — only to reproduce the paper's on-board results):** a Xilinx
  **VCU118** evaluation board.

## Software

| Tool | Purpose | Version used |
|------|---------|--------------|
| Siemens **QuestaSim** | RTL simulation (`vsim`) | 2022.4 |
| AMD **Vivado** | FPGA bitstream for VCU118 | 2021.2 |
| **RISC-V GCC** (`riscv64-unknown-elf-`) | build the bare-metal tests | SiFive GCC 8.3.0 (2020.04.0) |
| Host **OS** | — | Ubuntu (Linux) |

All IP dependencies, verification IPs (VIPs), and the `bender` binary are **vendored** in
the repository (on the `main` branch), so **no network access or `make init` is required**
for simulation.
