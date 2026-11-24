# Quality of service

Every memory request carries a QoS tag naming the software or DMA job that issued it. The LLC's two RISC-V CBQRI
controllers use it to partition cache ways and to regulate memory bandwidth per tag. Linux drives both through resctrl.

## How it works

**Tag.** The tag is {AT, MCID, RCID}:
- RCID is the resource-control ID.
- MCID is the monitoring-counter ID.
- AT is the CBQRI access type: 1 for instruction fetches, 0 otherwise.

The cores implement Ssqosid (CSR `srmcfg`). `cva6.sv` tags every AR and AW (not W, R or B) in the AXI `user` field,
above a low field into which the coherence unit (CCU) writes its source port; everything up to the LLC passes it
through. LLC refills and evictions carry the tag of the request that caused them, flush write-backs carry 0. Masters
other than the cores and the accelerator socket, the Ethernet DMA included, carry tag 0.

**Which IDs a core uses** (`csr_regfile.sv`, `gen_qos_ids`). There are two selections: instruction fetches use the
current privilege, and loads and stores use the effective privilege (MPRV, HLV/HSV). For each, the first matching rule
wins:

| Accesses from | Condition | IDs used |
|---|---|---|
| M mode | `mqosctl[0]` set | `mqosid` |
| HS mode | `mqosctl[1]` set | `hqosid` |
| VS mode | `mqosctl[2]` set | `sqosid` |
| V=1 | `hqosctl.VEN` set | `vsrmcfg` |
| anything else | | `srmcfg` |

This per-privilege association plays the role of AMD PLZA and of Arm MPAM's per-exception-level PARTIDs: with
`mqosctl[1]` set, kernel accesses carry `hqosid` while user accesses keep the task's `srmcfg`. A CSR write or a
privilege change applies from the next cycle; each request, store-buffer drains and write-backs included, takes the
IDs current when it leaves the core.

**vRCID / vMCID.** With `hqosctl.VEN` set, VS mode reads and writes `srmcfg` and `sqosid` without trapping and sees
virtual IDs; every guest access carries the physical IDs from the hypervisor's tables `hrcidmap0/1` and
`hmcidmap0/1`, or the default RCID / MCID of `hqosctl` for an unmapped ID. With VEN clear, a V=1 access to `srmcfg`
raises a virtual-instruction exception, as VU mode always does; in U mode it is an illegal instruction.

**Capacity controller** (`axi_llc_cbqri_cc`). One capacity block is one LLC way; each (RCID, AT) pair has a way mask
(`CONFIG_LIMIT`, `READ_LIMIT`). `axi_llc_hit_miss` locks the ways outside the mask, together with the per-source
masks of `axi_llc_config`, when it picks a victim; hits use any way. A mask that leaves no usable way is ignored.

**Bandwidth controller** (`axi_llc_cbqri_bc`), between the hit/miss unit and the eviction unit. Every descriptor
that needs memory waits in a parking pool; a refill or a dirty eviction costs one line, charged to its RCID. 1024
blocks stand for `BC_CAPACITY` bytes per `BC_PERIOD` cycles; each RCID has a reservation (Rbwb) and a weight
(Mweight). Release order: (1) descriptors that cost nothing, and those a reserved waiter depends on (priority
inheritance); (2) RCIDs inside their reservation, oldest first; (3) the rest by Mweight (stride scheduling). A
reservation is earned at a constant rate over the period, so reserved traffic interleaves with the rest. Mweight 0
is a hard limit: a constant rate of Rbwb / 1024 of the capacity. `BC_CTRL.PACE` makes a token bucket pace all
releases; the bucket keeps one line that only classes (1) and (2) take, so a reserved RCID's request finds tokens
when it comes. A release takes two cycles: one chooses a descriptor, the next releases it. The pool keeps per-ID
order, and a refill never passes an older eviction of the same line. Per-MCID byte counters monitor the traffic.

**Write-data buffer** (`axi_llc_w_buffer`). Each write's W beats get a slot of their own, so a parked write holds up
only its own AXI ID; a write too long for one slot stays in AW order.

**DMA admission gates** (`axi_llc_bc_gate`, one in front of each CCU DMA port). The CCU's single state machine waits
for every coherent DMA write's response, so each gate holds a DMA AR or AW until the bandwidth controller admits it
(the RCID's bytes used plus the worst case of its in-flight requests). Only hard-limited RCIDs can be refused; an
admitted request is never parked, and a refused one holds up only its own port.

**Device DMA tags.** The accelerator socket chooses each DMA request's tag: per job, by address range, or the slot
default (see the accelerator block).

## Configuration

Knobs can be set as `make` variables (`QOS_KNOBS` in `hardware/Makefile`), as `fpga_build` env, or through xsim
`SOC_EXTRA_DEFINES`. Their defaults are in `ariane_pkg.sv`.

| Knob | Effect |
|---|---|
| `QOS_RCID_WIDTH`, `QOS_MCID_WIDTH` | ID bits, 4 each by default (16 RCIDs, 16 MCIDs), at most 12. They size the user field and every table. |
| `QOS_PRIV_ASSOC` | 0 removes `mqosctl`, `mqosid`, `hqosid` and `sqosid`. |
| `QOS_NUM_VRCID`, `QOS_NUM_VMCID` | Translation entries (16, at most 16). 0 removes the CSRs. Translation needs the H extension. |
| `QOS_LLC_BC`, `QOS_LLC_BC_POOL` | Bandwidth controller (on) and its pool size (16). |
| `QOS_LLC_WBUF` | Write-buffer slots (8). 0 removes the buffer. |
| `QOS_DMA_GATE` | The admission gates. They need `QOS_LLC_BC`. |

The source-port field is `ceil(log2(cores + 2))` bits wide, so the position of the RCID depends on `NUM_CVA6`.

## Using it

- **Bare metal:** CSR numbers in `riscv_pkg.sv`; controller register layouts in the headers of `axi_llc_cbqri_cc.sv`
  and `axi_llc_cbqri_bc.sv` (64-bit registers as two 32-bit words; writing the word that holds OP completes the
  operation in that cycle). `soc_lookup` returns the addresses.
- **Netboot loader** (`software/netboot`, built with `QOS_KERNEL=` and `QOS_USER=`): sets `hqosid` and `mqosctl[1]`
  on every hart before Linux starts; with `QOS_FIRMWARE=` also `mqosid` and `mqosctl[0]`. Use both with hard
  limits: kernel or firmware work charged to a hard-limited task is throttled too and holds up other cores.
- **resctrl kernel** (`alsaqr-resctrl`: Linux 7.2 with the RISC-V CBQRI series and a device-tree front end): switches
  `srmcfg` per task; the capacity controller is resctrl `L3`, the bandwidth controller `MB_MIN` (Rbwb) and `MB_WGHT`
  (Mweight); no monitoring is exposed; `BC_CTRL`, `BC_PERIOD`, `BC_CAPACITY` are set from user space.
- **Linux tools** (alsaqr-software `linux/`): `qosprobe` (IDs that user and kernel accesses carry), `resctrl/rdtpart`
  and `resctrl/rdtbw` (partition and bandwidth workloads), `llcpart` (LLC partitioning kernel module).

## Verification

- `t_qos`, `t_cbqri` (suite `soc` of `sim_regress` and `board_regress`): `srmcfg`, tags read back through the socket's
  QoS probe, way isolation, code/data masks.
- `t_qosv` (`sim_run`): association, MPRV/HLV, translation, which CSRs exist under each knob.
- `t_bc`, `t_bcw`, `t_bcd` (`sim_run`, `board_run`): shares, hard limits, monitors, and which requests a throttled
  write or a gated DMA stalls.
- `hardware/xsim/tests/run_llc_bc.sh`, `run_llc_wbuf.sh`, `run_bc_gate.sh`: unit tests of the controller, the write
  buffer and the gate.
- In every simulation `host/qos_monitor.sv` checks the tags at the core ports, the LLC input and output, and
  `axi_llc_hit_miss` checks that every refill lands in its mask; `sim_status` reports failures as `qos_errors`.

## Properties

- The capacity controller has no occupancy monitoring and no `FLUSH_RCID`. The bandwidth controller has no per-AT
  allocation and does not regulate traffic that bypasses the LLC.
- More waiting misses than the pool holds stall the LLC lookup.

## Code

- `hardware/ip_list/cva6/core/csr_regfile.sv`, `cva6.sv`, `include/ariane_pkg.sv`: CSRs, tagging, knob defaults.
- `hardware/include/ariane_axi_soc_pkg.sv`: the SoC user layout (`QosUserLsb`).
- `hardware/ip_list/axi_llc/src/axi_llc_cbqri_cc.sv`, `axi_llc_cbqri_bc.sv`, `axi_llc_w_buffer.sv`, `axi_llc_bc_gate.sv`: the QoS hardware in the LLC.
- `hardware/host/host_domain.sv` (LLC parameters), `cva6_subsystem.sv` (the gates), `qos_monitor.sv` (the scoreboard).
- `software/soc_tests/t_qos*`, `t_cbqri`, `t_bc*`: the tests.

## Reference

- `hardware/docs/qos.md`
- alsaqr-resctrl: `README_ALSAQR.md`
