# AXI-LLC — Waterloo modifications (PLRU replacement + cache partitioning)

> **This is the PULP AXI-LLC with two additions from the University of Waterloo**, used as
> the last-level cache in the he-soc SoC of our EMSOFT 2026 paper. The upstream PULP AXI-LLC
> README is preserved unchanged below this section.

**1. Pseudo-LRU (PLRU) replacement.** A new replacement module —
[`src/hit_miss_detect/axi_llc_plru.sv`](./src/hit_miss_detect/axi_llc_plru.sv), by
**G. Thayyil** — implements tree-based pseudo-LRU way selection for 2-, 4-, 8-, 16-, 32-, and
64-way set-associative configurations, keeping the PLRU state bits in SRAM (tree encoding:
`0 → left, 1 → right`). It provides the eviction victim in the hit/miss path.

**2. AXI-ID-based cache partitioning.** The LLC can partition its ways across masters: a set
of AXI4-Lite configuration registers assigns each source/master AXI ID a **way bitmask**, so
a given requester may only allocate into (and be evicted from) its assigned subset of ways.
Partitioning is active when more than one partition config register is present
(`NumCfgRegcp > 1`); with a single register the cache behaves as the unpartitioned upstream
LLC. This is what lets the paper allocate a fixed slice of LLC capacity per core in the
regulation and contention experiments.

**Where the changes are:**

| File | Change |
|------|--------|
| `src/hit_miss_detect/axi_llc_plru.sv` | **New (Waterloo).** Pseudo-LRU replacement module (2–64 way). |
| `src/axi_llc_config.sv` | AXI4-Lite config registers holding the per-AXI-ID partition way-bitmasks. |
| `src/axi_llc_hit_miss.sv` | Applies the partition bitmask to restrict the allocatable ways, and drives the PLRU victim selection. |
| `src/axi_llc_top.sv` | Threads the source-ID / partition-bitmask signals through the LLC. |

**License.** The base AXI-LLC is © ETH Zurich / University of Bologna under the **Solderpad
Hardware License v0.51**; the Waterloo additions above are released under the same license.

---

<!-- ================= Upstream PULP AXI-LLC README below ================= -->

# AXI LLC
[![CI status](https://akurth.net/usrv/ig/shields/pipeline/github-mirror/axi_llc/master.svg)](https://iis-git.ee.ethz.ch/github-mirror/axi_llc/commits/master)
[![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/pulp-platform/axi_llc?color=blue&label=current&sort=semver)](CHANGELOG.md)
[![SHL-0.51 license](https://img.shields.io/badge/license-SHL--0.51-green)](LICENSE)

Home of the AXI LLC - a parameterizable and runtime-configurable AXI4-compliant last-level cache (LLC). The AXI LLC is part of the [PULP (Parallel Ultra-Low-Power) platform](https://pulp-platform.org/).

## Documentation
The [`latest documentation`](doc/axi_llc.md) can be accessed pre-built.

## License
iDMA is released under Solderpad v0.51 (SHL-0.51) see [`LICENSE`](LICENSE):

## Contributing
We are happy to accept pull requests and issues from any contributors. See [`CONTRIBUTING.md`](CONTRIBUTING.md)
for additional information.

## Getting Started

### Prerequisites
LLC can directly be integrated after cloning it from this repository. However, to build the
documentation, and run various checks on the source code, various tools are required.

- [`bender >= v0.26.1`](https://github.com/pulp-platform/bender)
- [`morty >= v0.8.0`](https://github.com/pulp-platform/morty)
- [`Verible >= v0.0-1051-gd4cd328`](https://github.com/chipsalliance/verible)
- `Python3 >= 3.8` including some the libraries listed in [`requirements.txt`](requirements.txt)


### Building the Documentation
Use `make doc` to build the documentation. The output is located at `doc/morty`.

### Simulation

We currently do not include any free and open-source simulation setup. However, if you have access to
[*Questa advanced simulator*](https://eda.sw.siemens.com/en-US/ic/questa/simulation/advanced-simulator/),
a simulation can be launched using:
```
sh> make scripts/compile_vsim.tcl
sh> questa-2021.3 vsim -64
vsim> source scripts/compile_vsim.tcl
vsim> source scripts/start_vsim.tcl
vsim> do scripts/waves/tb_axi_llc.vsim.do
vsim> run -all
```

The simulation should complete after 53.168ms.


### Force PLRU to BRAMs in FPGA Emulation (Workaround)

To force PLRU SRAMs to be BRAMs (for FPGA Emulation), follow the steps mentioned below
- include the "tc_sram_xilinx.sv" file from the following repository (https://github.com/pulp-platform/tech_cells_generic.git) into the hit_miss_detect folder
- change the file name and module name to "axi_llc_tc_sram"
- change MEMORY_PRIMITIVE parameter to "block"
- change the "tc_sram" instantiation in the "axi_llc_plru" file to "axi_llc_tc_sram" 
- update the .bender file to include the new "axi_llc_tc_sram" file (above "axi_llc_plru")

