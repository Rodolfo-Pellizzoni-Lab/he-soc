# CVA6 application cores

The application processors: a configurable number of 64-bit in-order CVA6 cores (four by default) with private,
coherent L1 caches. They run the boot ROM, bare-metal tests, OpenSBI and Linux, and every request they issue carries
the issuing software's QoS IDs.

## How it works

`host/cva6_synth_wrap.sv` instantiates one `cva6` per core (`gen_ariane`). The configuration comes from the CVA6
config package `cv64a6_imafdc_sv39_wb` (ISA, caches, TLBs, PMP) and from `ariane_soc::ArianeSocCfg` (branch
predictors; cached, executable and non-idempotent regions: only the DRAM window is cached and shared).

- **ISA:** RV64IMAFDC, M/S/U modes, hypervisor extension (H), external debug. No B, V or Zcb. A custom `fence.t`
  instruction (custom-0 opcode) flushes the L1 caches and microarchitectural state, padded through the
  `CSR_FENCE_T_PAD` / `CSR_FENCE_T_CEIL` CSRs.
- **MMU:** Sv39 with Sv39x4 G-stage translation; 56-bit physical addresses; 16-entry I-TLB and D-TLB; 8 PMP entries.
- **L1 caches (`std_cache_subsystem`):** I$ `cva6_icache`, not snooped. D$ `std_nbdcache`: write-back,
  write-allocate, `valid`/`shared`/per-byte `dirty` state, one MSHR (`miss_handler.sv`), ACE to the coherence unit
  (CCU), snoops answered by `snoop_cache_ctrl.sv`. Atomics run memory-side after the D$ writes back and invalidates
  the line. The protocol is in the coherence block.
- **Performance counters (`perf_counters.sv`):** `mcycle`, `minstret` and six programmable 64-bit counters
  `mhpmcounter3..8` / `mhpmevent3..8`; `mcountinhibit` covers all of them; `mcounteren`/`hcounteren`/`scounteren`
  gate lower-privilege access. Sscofpmf: each `mhpmevent` has OF and the MINH/SINH/UINH/VSINH/VUINH filters; a wrap
  sets OF, shows in `scountovf` and raises local interrupt 13 (LCOFI). The 5-bit selector offers 22
  microarchitectural events (cache/TLB misses and accesses, loads, stores, branches, stalls, ...) plus cycles
  and retired instructions.
- **Event unit (EVU, `perf_counters_evu.sv`):** four event slots per core, exported to the APMU (the SoC's
  performance-monitoring unit). A slot selects one of the same events, a match of the committed PC against four
  PC-milestone registers, or a change of `scontext`/`hcontext`. Each cycle the core sends an `ariane_pkg::pmu_event_t`
  (event bits, info, privilege and V) to APMU port c + 1. Slot and milestone registers are in
  `host/perfc_evu_cfg_regs.sv`.
- **QoS IDs (`csr_regfile.sv`, `cva6.sv`):** Ssqosid `srmcfg` (RCID, MCID), plus custom CSRs for privilege
  association (`mqosctl`, `mqosid`, `hqosid`, `sqosid`: M, HS, VS accesses carry their own IDs) and guest ID
  translation (`hqosctl`, `hrcidmap0/1`, `hmcidmap0/1`, `vsrmcfg`: a guest's virtual RCIDs/MCIDs map to physical
  ones). The CSR file registers one ID pair for fetches (current privilege) and one for loads/stores (effective
  privilege: MPRV, HLV/HSV); `cva6.sv` writes `{AT, MCID, RCID}` (`ariane_pkg::qos_tag_t`, AT = 1 for
  instruction fetches) into the `user` field of every AR and AW. Rules and bus layout: QoS block.

Between each core and its CCU port, `cva6_synth_wrap` moves the tag above the CCU source-port bits and inserts a
`token_bucket` (per-core AR/AW rate limiter, `token_bucket_cfg_regs`) and an APMU SPU. Cores 0 and 1 export
control-transfer records (`ctr_unit.sv`) to the trace `snooper`.

## Configuration

| Knob | Effect |
|---|---|
| `NUM_CVA6` (make/env, xsim `SOC_EXTRA_DEFINES`, `fpga_build` `env`) | core count; default 4 (`QUAD_CORE` in `ariane_soc_pkg.sv`). Sizes CCU ports, CLINT, PLIC contexts (2 per core), debug module, APMU ports, AXI user field. Hart ID = core index. APMU fields allow up to 14 cores |
| `QOS_RCID_WIDTH`, `QOS_MCID_WIDTH` | implemented ID bits (4 each, at most 12) |
| `QOS_PRIV_ASSOC` | 0 removes the privilege-association CSRs |
| `QOS_NUM_VRCID`, `QOS_NUM_VMCID` | guest translation table entries (16 each); 0 removes them |
| `CVA6_PKG` (`hardware/Makefile`) | CVA6 config package Bender target |

Fixed by the config package: I$ 8 KiB 2-way, D$ 16 KiB 8-way, 16-byte lines; 2 commit ports; 8 scoreboard entries;
BTB 32, BHT 128, RAS 2; 64-bit AXI data, 4-bit AXI IDs. soc_tests target another core count with
`-DSOC_NUM_CORES=<n>`.

## Using it

- Cores start in the boot ROM and park in `wfi`: harts 0 and 1 until the mailbox interrupt, hart h >= 2 until APMU
  counter h-2 overflows; then they jump to the entry the mailbox holds.
- QoS: software sets `srmcfg` per task (Linux Ssqosid support, resctrl). The netboot loader (`QOS_KERNEL`,
  `QOS_USER`) sets `mqosctl`/`hqosid` so kernel accesses carry their own IDs. `alsaqr-software: linux/qosprobe`
  reads back each CPU's IDs.
- Counters: CSRs on bare metal; Linux SBI PMU driver and perf. Sampling needs a device tree listing `sscofpmf`
  (`alsaqr-software: linux/cva6-sdk/alsaqr-pmu.dts`). `mcountinhibit` stops `mcycle`/`minstret` too, so `rdcycle`
  stands still while OpenSBI's PMU support inhibits them.
- EVU: a core or the APMU's processor writes a core's event IDs and PC milestones.
- CSR numbers: `riscv_pkg.sv`; layouts: `csr_regfile.sv`, `ariane_pkg.sv`; EVU / token-bucket offsets:
  `ariane_soc_pkg.sv`. `soc_lookup` (alsaqr-mcp) returns them.

## Verification

`software/soc_tests/`, run with `sim_regress` (xsim) or `board_run` / `board_regress` (VCU118):

- In the `soc` suite: `t_smp` (all cores: wake-up, contended AMO and LR/SC, sharing), `t_atomics`, `t_irq`,
  `t_mem`, `t_qos`.
- `t_stopm` (one writer, N-1 spinning readers on one line), `t_chk` (data integrity under all-core load).
- `t_hpm`, `t_sscofpmf`, `t_hpm_irq` (overflow of every counter on every hart); `t_evu`; `t_qosv`.
- `hardware/xsim/tests/run_hpm.sh`: counter unit bench.
- `host/qos_monitor.sv` checks in every simulation that each core request carries the IDs its CSR file selects.

## Properties

- One outstanding D$ miss or CleanUnique per core.
- A store to a shared line first makes it unique with a CleanUnique; a ReadShared snoop answered after that
  response makes it issue the CleanUnique again.
- The interrupt that ends a `wfi` is taken a few instructions after it: the instructions decoded behind a `wfi` are
  not flushed (`t_wfi`).
- A request waiting for `ready` keeps the QoS tag it started with.
- No coprocessor is attached and the CVXIF port is off in the core's configuration: an instruction the core does
  not decode raises an illegal-instruction exception in the decoder (`t_trap`).

## Code

- `hardware/ip_list/cva6/`: CVA6 (in-tree); `core/include/cv64a6_imafdc_sv39_wb_config_pkg.sv` the config used.
- `hardware/ip_list/cva6/core/include/ariane_pkg.sv`, `riscv_pkg.sv`: QoS knobs, cache geometry, CSR numbers.
- `hardware/ip_list/cva6/core/csr_regfile.sv`: CSRs, QoS ID selection.
- `hardware/ip_list/cva6/core/perf_counters.sv`, `perf_counters_evu.sv`: counters, EVU.
- `hardware/include/ariane_soc_pkg.sv`: `NumCVA6`, `ArianeSocCfg`, EVU / token-bucket windows.
- `hardware/host/cva6_synth_wrap.sv`: core instances, tag placement, token buckets, SPUs.
- `hardware/host/perfc_evu_cfg_regs.sv`: EVU registers. `hardware/host/bootrom/`: boot ROM.

## Reference

- `hardware/docs/qos.md` (QoS CSRs), `hardware/docs/coherence.md` (L1/CCU), `hardware/docs/hpm.md` (counters),
  `hardware/ip_list/apmu/README.md` (EVU event format).
