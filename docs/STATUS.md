# Artifact Evaluation — Status

We are applying for the **Artifacts Available** badge.

## Why the artifact deserves the "Available" badge

We believe this artifact deserves the **Available** badge for the reasons below. It is the
RTL of a PULP-based SoC with our centralized performance-monitoring infrastructure — the
per-core **Event Monitoring Units (EVUs)**, the **SPU** event snoopers, and the **Advanced
Performance Monitoring Unit (APMU)** — integrated and working end-to-end, together with
bare-metal bring-up tests that exercise it in simulation. It is:

- **Open-source.** The IPs we author — the **APMU**, the **SPU**, and the **CVA6 EVU**
  (`hardware/ip_list/cva6/core/perf_counters_evu.sv`) — are released under the **Solderpad
  Hardware License v0.51** (APMU/SPU license text in `hardware/ip_list/apmu/LICENSE` and
  `hardware/ip_list/spu/LICENSE`; the EVU carries the SHL-0.51 header and is licensed via
  its standalone `cva6` repository). SHL-0.51 explicitly permits the work to be treated, at
  the licensee's option, as **Apache License 2.0** — an OSI-approved open-source license —
  so the availability requirement is met. Upstream components (CVA6, lowRISC Ibex, the
  AlSaqr base SoC) retain their original open licenses.

## Why not "Functional" / "Reusable"

Building and running this artifact requires **commercial, license-locked EDA tools**
(Siemens QuestaSim for RTL simulation; AMD Vivado for the FPGA bitstream) and, to
reproduce the paper's measurements, a physical **Xilinx VCU118** FPGA board. These tools
cannot be redistributed inside a VM or container, and reviewers are unlikely to have the
board. A reviewer-run functional/reproduction evaluation is therefore not feasible, so we
pursue the Available badge only.
