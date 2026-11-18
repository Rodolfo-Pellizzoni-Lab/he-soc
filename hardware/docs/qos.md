# QoS identifiers (Ssqosid, for CBQRI)

The cores implement the RISC-V **Ssqosid** extension, and every memory request in the SoC carries the requesting
hart's QoS identifiers in the AXI `user` field. The LLC has a RISC-V **CBQRI capacity controller** (Capacity and
Bandwidth QoS Register Interface v1.0): software assigns each RCID and access type a set of LLC ways it may allocate
into (way partitioning). There is no bandwidth controller and no capacity monitoring.

## CPU side: `srmcfg` (CSR 0x181)

| Bits | Field | Implemented |
|---|---|---|
| 11:0 | RCID (resource control ID: capacity / bandwidth allocation) | low `ariane_pkg::QOS_RCID_WIDTH` = 4 bits |
| 27:16 | MCID (monitoring counter ID) | low `ariane_pkg::QOS_MCID_WIDTH` = 4 bits |
| others | | read-only zero |

- WARL: bits beyond the implemented widths are dropped, so software finds the widths by writing all ones
  and reading back (`0x000F000F` here). Reset value 0.
- Readable and writable in M and HS/S mode. U mode: illegal-instruction exception. VS and VU mode (V=1):
  virtual-instruction exception. (Smstateen is not implemented, so `mstateen0.SRMCFG` does not exist.)
- A write takes effect on the next request the core issues. A request already waiting for `ready` keeps
  its tag (AXI payload stability).
- The widths are set in `ip_list/cva6/core/include/ariane_pkg.sv` (at most 12 each). The SoC user width follows
  from them.

Sources: `riscv_pkg.sv` (`CSR_SRMCFG`), `csr_regfile.sv` (register, access checks, `qos_fetch_ids_o` /
`qos_data_ids_o`), `cva6.sv` (tagging of the core's AXI port).

## Privilege association and virtualized RCIDs / MCIDs (custom CSRs)

Two custom extensions on top of Ssqosid, modelled on Arm MPAM's per-exception-level PARTID registers
(`MPAM3_EL3`, `MPAM2_EL2`, `MPAM1_EL1`) and its virtual-PARTID mapping (`MPAMVPMn_EL2`):

- **Privilege association**: M-mode, HS-mode and VS-mode accesses can carry IDs of their own instead of
  `srmcfg`, so firmware, the hypervisor (or a non-virtualized kernel, which runs in HS mode) and a guest kernel
  are each charged to their own RCID/MCID while U-mode keeps the per-process `srmcfg`.
- **vRCID / vMCID translation**: a guest gets its own RCID and MCID spaces. With translation on, VS mode reads and
  writes `srmcfg` (and `sqosid`) without trapping; the values are virtual, and every V=1 access carries the
  physical RCID and MCID that hypervisor-owned tables give the guest's. Unlike MPAM, whose monitoring group (PMG)
  lives inside a PARTID and so needs no translation of its own, CBQRI selects monitoring counters by MCID alone:
  without translation two guests using the same MCID would share counters.

| CSR | Address | Access | Layout | Meaning |
|---|---|---|---|---|
| `mqosctl` | 0x7C1 | M | [0] M, [1] HS, [2] VS (WARL) | privilege association enables |
| `mqosid` | 0x7C0 | M | as `srmcfg` | IDs of M-mode accesses (`mqosctl[0]`) |
| `hqosid` | 0x6C4 | HS, M | as `srmcfg` | IDs of HS-mode accesses (`mqosctl[1]`) |
| `sqosid` | 0x5C0 | HS, M; VS only when `hqosctl[0]` | as `srmcfg` | IDs of VS-mode accesses (`mqosctl[2]`); virtual when `hqosctl[0]` |
| `hqosctl` | 0x6C0 | HS, M | [0] VEN, [15:4] default MCID, [27:16] default RCID | guest ID translation enable; the physical MCID / RCID of unmapped virtual IDs |
| `hrcidmap0` | 0x6C1 | HS, M | 8 bytes, byte i = {V (bit 7), physical RCID} | vRCID i -> physical RCID, i = 0..7 |
| `hrcidmap1` | 0x6C2 | HS, M | same | vRCIDs 8..15 |
| `vsrmcfg` | 0x6C3 | HS, M | as `srmcfg` | the guest's `srmcfg` (what VS mode sees as `srmcfg` when VEN = 1), for save/restore on a world switch |
| `hmcidmap0` | 0x6C5 | HS, M | 8 bytes, byte i = {V (bit 7), physical MCID} | vMCID i -> physical MCID, i = 0..7 |
| `hmcidmap1` | 0x6C6 | HS, M | same | vMCIDs 8..15 |

All reset to 0 (association off, translation off: the behaviour of plain Ssqosid). The tables have
`ariane_pkg::QOS_NUM_VRCID` = 16 and `QOS_NUM_VMCID` = 16 entries with 4-bit IDs (2^ID width, at most 16 on RV64).

**Build knobs** (defines with defaults in `ariane_pkg.sv`; set them as make variables / environment for the
Questa and FPGA flows, `SOC_EXTRA_DEFINES="QOS_NUM_VRCID=0 ..."` for xsim, `env` of the MCP's `fpga_build`), so
area and timing can be compared with and without each addition:

| Define | Default | Effect |
|---|---|---|
| `QOS_RCID_WIDTH` | 4 | implemented RCID bits (at most 12); sizes the SoC user field, the LLC's CBQRI table and the vRCID table |
| `QOS_MCID_WIDTH` | 4 | implemented MCID bits (at most 12) |
| `QOS_PRIV_ASSOC` | 1 | 0: no privilege association; `mqosctl`, `mqosid`, `hqosid`, `sqosid` are illegal CSRs, their logic is removed |
| `QOS_NUM_VRCID` | 16 | vRCID table entries (capped at 2^`QOS_RCID_WIDTH` and 16 on RV64); 0: no translation, `hqosctl`, `hrcidmap0/1`, `vsrmcfg` (and the vMCID CSRs) are illegal, their logic is removed |
| `QOS_NUM_VMCID` | 16 | vMCID table entries (capped at 2^`QOS_MCID_WIDTH` and 16 on RV64); 0: guest MCIDs pass through untranslated, `hmcidmap0/1` are illegal, `hqosctl[15:4]` reads 0. Needs the vRCID CSRs |

With both features off, the core behaves as plain Ssqosid (only `srmcfg`). Translation and the VS parts also need
the hypervisor extension (`CVA6ConfigHExtEn`). `t_qosv` detects which features exist (an absent CSR must raise an
illegal-instruction exception) and checks the rest. Verified configurations: the defaults.

**Which IDs an access carries.** For each access, the first matching rule applies. Instruction fetches use the
current privilege; loads and stores use the effective load/store privilege (`mstatus.MPRV`/`MPP`/`MPV`, and
`hstatus.SPVP` for HLV/HSV):

| Access from | Condition | IDs |
|---|---|---|
| M | `mqosctl[0]` | `mqosid` |
| HS (S, V=0) | `mqosctl[1]` | `hqosid` |
| VS (S, V=1) | `mqosctl[2]` | `sqosid`, RCID and MCID translated if VEN |
| VS, VU (V=1) | VEN | `vsrmcfg`, RCID and MCID translated |
| anything else | | `srmcfg` |

Translation: vRCID r maps to `hrcidmap[r].prcid` when that entry is valid, else to the default RCID of `hqosctl`;
vMCID m likewise through `hmcidmap[m]` and the default MCID. Device DMA submitted by a guest carries the translated
IDs too (the doorbell write is tagged by the core).

**Guest access.** VEN = 0: VS/VU accesses to `srmcfg` and `sqosid` raise a virtual-instruction exception (Ssqosid
behaviour, the hypervisor emulates; with `mqosctl[2]` set, `sqosid` then holds physical IDs the hypervisor chose).
VEN = 1: VS mode reads and writes `vsrmcfg` through `srmcfg` and `sqosid` directly; VU mode still raises a
virtual-instruction exception. U mode: illegal instruction for both.

**Timing.** The selected IDs are registered in the CSR file: a CSR write or a privilege change applies to requests
raised from the next cycle on. As for `srmcfg`, the tag is taken when the request leaves the core, so a store that
drains from the store buffer, or a write-back of a line, after a privilege change carries the new privilege's IDs.

Tested by `software/soc_tests/t_qosv` (see "Checking it").

## The tag on the buses

Inside CVA6, every AR and AW leaving the core gets `user[QOS_TAG_WIDTH-1:0] = {AT, MCID, RCID}`:

- **AT** is the CBQRI access type: 1 for instruction fetches (I$ refills, AXI ID `4'b0000` in the WB cache
  subsystem), 0 for data.
- Data covers loads, stores, AMOs, page-table walks, D$ refills and write-backs, and uncached accesses.
- The W, R and B channels are not tagged.

On the SoC buses (`ariane_axi_soc` package), the user field is `QosUserLsb + 9` bits wide, where `QosUserLsb =
$clog2(NumCVA6 + 2)` is the width of the CCU source-port field: 3 bits (a 12-bit user word) up to 6 cores, 4 bits
(13-bit) for 7 to 14 cores. With the four cores of the default build:

```
user[2:0]   source port of the CCU (written by the CCU): 0-3 the cores, 4 the accelerator socket's DMA, 5 the
            Xilinx Ethernet's DMA (NumCVA6 and NumCVA6 + 1 in general: ariane_soc::CcuAccelPort, CcuEthPort)
user[3+:4]  RCID                     (user[QosUserLsb +: 4] in general)
user[7+:4]  MCID                     (user[QosUserLsb+4 +: 4])
user[11]    AT                       (user[QosUserLsb+8])
```

Software that decodes the word (the QoS probe in `soc_tests/t_qos`, `soc_test.h`'s `SOC_SRC_BITS`) derives the
port width from `SOC_NUM_CORES`; with `NUM_CVA6=8` the RCID starts at bit 4.

(`QosUserLsb` is `ariane_soc::CcuSrcWidth`, `$clog2(NumCcuPorts)` with `NumCcuPorts` the cores plus the two DMA
ports: the CCU writes its port index into the low bits, see `hardware/accel/README.md`. The same bits tell the APMU's
SPU on the LLC memory port the source of a request; the APMU's source field, which numbers the other crossbar masters
too, is wider: 4 bits with up to four cores, 5 with more (`pmu_pkg::SOURCE_ID_BITS`), see
`hardware/ip_list/apmu/README.md`.)

Use `ariane_axi_soc::qos_tag(user)` to decode a SoC user field into an `ariane_pkg::qos_tag_t {at, mcid, rcid}`,
and `ariane_axi_soc::qos_user(tag)` to build one.

| Where | What happens to the tag |
|---|---|
| `cva6_synth_wrap` | moves the core's tag above the source-port bits |
| CCU (`ip_list/ace`) | passes the requester's tag through. Dirty data snooped from another core usually moves to the requester's cache, and the requester's own write-backs carry its tag later. When the CCU writes the data back itself (CleanUnique or LR that invalidates a dirty line), that write carries the tag of the request that caused it, and its source port is the core that supplied the data. `t_qos` does not reach this case |
| host xbar, CDC FIFOs, ID remapper, AMO/LR-SC adapters | pass `user` through |
| LLC (`ip_list/axi_llc`) | allocates by the tag's RCID and AT (next section). Refills and evictions carry the tag of the request that caused them (new descriptor field `a_x_user`); config-port flushes carry 0 |
| DRAM / HyperRAM / peripherals | ignore it |
| Accelerator socket (`hardware/accel`, CCU port `CcuAccelPort`: 4, 8 with eight cores) | tags each DMA request with the device's per-job tag (the template: the tag of the write that started or submitted the job), an address range's tag, or the slot's default, by the rules of the next section; `LAST_USER` / `LAST_SRC` read back the last request's tag and rule. `t_iotag`, `t_iojob` |
| Other masters (debug module, iDMA, uDMA, cluster, the Xilinx Ethernet DMA on CCU port `CcuEthPort`: 5, 9 with eight cores) | tag 0 (RCID 0, MCID 0) |

**The source-port bits also key LR/SC reservations.** Both `axi_riscv_atomics` adapters (L2 and L3,
`host/cva6_subsystem.sv`) track reservations per `user[QosUserLsb-1:0]` (`user[2:0]` with four cores, `user[3:0]` with
eight; `AXI_USER_AS_ID`, one entry per CCU port) instead of per AXI ID. The core-side ID remapper (`cva6_axi_id_remap`,
separate read and write tables) does not keep the LR's AR ID and the SC's AW ID equal when other transactions are in
flight, so an ID-keyed table only worked by timing luck: on the VCU118 every SC to the uncached L2 failed while
simulation (instant UART / L2 responses) passed. The address-based clear on any write is unchanged. Masters other than
the cores share entry 0.

## Device DMA: per-job tags, address ranges, defaults

The goal: a device's DMA is charged to whoever asked for the work, per RCID, also when several tenants (and VMs, with
their own RCID spaces) share the device. The cores already put a hardware-set tag on every request, so the write that
hands a device its work (the doorbell) carries the submitter's tag: `srmcfg`, the privilege-associated IDs, or a
guest's vRCID translated by `hrcidmap` (the previous section). That tag is physical by the time it reaches the device;
the socket translates nothing.

**Trust model ("Design 1").** A device that keeps the doorbell's tag with each job and puts it on that job's DMA is
trusted to do so, the way a PCIe device is trusted to stamp the right requester ID and PASID on each DMA (which the
IOMMU uses for the memory-isolation decision itself). The socket does not check per-job tags; it can only override
them per slot. A socket-held job table that hands the device handles instead of tags (so the device cannot use a tag
nobody submitted) is the stronger alternative; it is not built.

**Rules.** The socket picks each DMA request's tag (registers and the rule table: `hardware/accel/README.md`, "Tag
rules"; RTL: `hardware/accel/accel_socket.sv`):

1. `FORCE` -> the slot's default tag: the device as its own principal, the IOMMU device context's `DC.ta` model.
2. `RANGE_EN` and a range entry for the slot holds the address -> that entry's tag: **charged to the owner of the
   memory**, for devices that do not tag per job. Right when each tenant's buffers are its own (per-tenant buffer
   pools registered once); shared buffers and the device's own memory are charged to whichever entry or default
   covers them. Physical pages, programmed by the host; a guest's ranges would go through the hypervisor (trap and
   translate the tag).
3. the device tags per job (`QOS_CAP.JOB`, `DEV_OFF` clear) -> the device's tag: **charged to whoever submitted the
   job**.
4. otherwise -> the slot's default.

**Job queue.** The template accelerator queues jobs from several submitters, each with its own tag: a job is a
descriptor in memory and one 32-bit `SUBMIT` write queues it with that write's tag (README, "Job queue"). Its
descriptor read, data and completion write all carry the tag. A device that runs several jobs at once needs the same
per-job tag column in whatever job table it already has, carried to its DMA port with each request.

**Software.**

- The tag is taken when a request leaves the core: change `srmcfg` (or the privilege) only after the doorbell write
  has left (`accel_submit()` reads a device register back). A kernel that submits for a task while it runs that
  task's `srmcfg` charges the task; with the HS privilege association on (`mqosctl[1]`), kernel accesses carry
  `hqosid` instead, so a driver submitting for a task must switch `hqosid` (or leave the association off).
- Work done for someone else (deferred submission, a hypervisor's I/O thread under virtio) carries the submitter's
  tag unless that software switches it around the doorbell write.
- Linux does not write `srmcfg` on context switch yet; nothing under Linux is charged per task until it does.

**IOMMU.** Not needed for the tags. The SoC's RISC-V IOMMU (`ip_list/riscv-iommu`, no QoS-ID support) sits only in
front of the S-mode iDMA; the socket's DMA reaches the coherence unit with physical addresses. An IOMMU in front of
the socket is needed to give a slot (or a VF) to a VM: memory isolation, not tagging. The range check then belongs
after it, on host-physical addresses.

**Not built.** Virtual functions (per-VF register pages, default tags and range matching, a VF ID on the memory port;
planned knob `ACCEL_NUM_VFS`, 0 = today), the IOMMU in front of the socket, the socket-held job table, weighted
attribution of batched work, Linux support.

**Build knobs** (defines, `make` variables, `fpga_build` environment), next to the CPU-side ones:

| Knob | Default | Effect |
|---|---|---|
| `SOCK_QOS_RANGES` | 16 | address-range entries; 0 removes the table and its comparators |
| `ACCEL_JOB_DEPTH` | 4 | job-queue depth of template accelerators; 0 removes the queue |

## LLC capacity controller (CBQRI)

What way partitioning buys an accelerator and the cores, measured on the VCU118 (capacity: exactly what the masks
say; latency under load: set by the coherence unit's serialization, not by the masks): `hardware/accel/README.md`,
"LLC way partitioning", `software/soc_tests/t_part`.

The registers sit at **`0x1040_1800`**, the upper half of the LLC configuration window. The LLC's own
configuration registers stay at `0x1040_1000`. Source: `ip_list/axi_llc/src/axi_llc_cbqri_cc.sv`.

| Offset | Register | Here |
|---|---|---|
| 0x00 | `cc_capabilities` | `0x1010`: VER 1.0, NCBLKS = 16 (one capacity block per LLC way), FRCID = CUNITS = RPFX = P = 0 |
| 0x08, 0x10 | `cc_mon_ctl`, `cc_mon_ctr_val` | read-only zero: no capacity usage monitoring |
| 0x18 | `cc_alloc_ctl` | OP [4:0], AT [7:5], RCID [19:8], STATUS [38:32], BUSY [39] |
| 0x20 | `cc_block_mask` | bits 15:0, one per way |
| 0x28 | `cc_cunits` | read-only zero (CUNITS = 0) |

- **Operations.**
  - `CONFIG_LIMIT` (OP 1) sets the mask of (RCID, AT) to `cc_block_mask`.
  - `READ_LIMIT` (OP 2) copies that mask into `cc_block_mask`.
  - `FLUSH_RCID` and any other OP return STATUS 2.
- **STATUS codes.** 1 success, 2 bad or unsupported OP, 3 RCID ≥ 16, 4 AT > 1, 5 `CONFIG_LIMIT` with an
  empty mask.
- **When an operation runs.** It completes in the cycle of the write, so BUSY always reads 0. On the 32-bit
  configuration bus, the write of the low word of `cc_alloc_ctl` (the word holding OP) starts it.
- **Masks.** Every (RCID 0–15, AT 0/1) pair has its own mask. AT 0 is data and AT 1 is code, which gives
  code/data prioritization. Masks reset to all ways and may overlap.
- **What a mask restricts.** It limits **allocation only**: on a miss, the PLRU victim is chosen among the
  ways of the requester's mask. Hits are served from any way, as CBQRI specifies. If a mask leaves no usable
  way (for example, it covers only ways configured as SPM), the request ignores it.
- **How it is wired.** `axi_llc_hit_miss` locks the ways outside the mask for the replacement decision of the
  descriptor under lookup. That decision uses the RCID/AT of `desc_q`, which is stable for the whole lookup.
  It ORs with the SPM lock and the old AXI-ID partitioning (`SourceIDStart/End`, still there, default off).
- **The DMA ports share cores' old per-ID masks.** The old masks (16 bits each from `0x1040_1040`) are indexed by the
  AXI ID above the remapper's slot bits, `ID[7:2]`: the crossbar port, then the CCU source as far as it fits. The ID
  holds only the source's low two bits (`ariane_soc::RemapSrcWidth`), so index k serves every CCU source s with s mod
  4 = k: with four cores core k, and also the accelerator socket's DMA port (source 4) for k = 0 and the Ethernet
  DMA's (source 5) for k = 1; with eight cores cores k and k + 4, and the socket's DMA (source 8) for k = 0 and the
  Ethernet DMA (source 9) for k = 1. So the socket's DMA uses **core 0's mask** and the Ethernet DMA **core 1's** (the
  remapper puts the plain low source bits into the ID; until the Ethernet DMA had a CCU port of its own it shared the
  socket's, and with it core 0's mask). With the old masks programmed, a DMA's LLC misses allocate in that core's ways
  and evict its lines, so a per-core isolation result for core 0 includes the socket's traffic and one for core 1 the
  Ethernet's (and with eight cores core k's includes core k + 4's). CBQRI is unaffected: it takes the RCID and AT from
  the user field (`user[QosUserLsb +: 4]`, `user[QosUserLsb+8]`: `user[6:3]` and `user[11]` with four cores), which
  neither the remapper nor the CCU changes, so the socket's DMA allocates by the RCID of its tag and the Ethernet DMA
  by RCID 0. The PMU benches that still program the old masks (`pmu_evu_bench`, `pmu_evu_simple_sim`, and in
  alsaqr-software `pmu_mempol_synth`, `pmu_sdvb`, `pmu_sad_profile`) give each of four cores four ways this way. On
  bitstreams with the old remapper (2026-10-16 to -25) every core's refills used core 2's mask and the DMA port's
  traffic core 3's, so no DMA master has ever had a mask of its own. Giving them one would take the LLC indexing the
  masks by the full source from the user field (`{ID[7:4], user[QosUserLsb-1:0]}`); the masks are kept as they are,
  and partitioning uses CBQRI (decided 2026-10-27).
- **Parameters.** `axi_llc_top` takes `QosRcidWidth` (0 turns the controller off), `QosRcidLsb`, `QosAtBit`
  and `QosCcOffset`.

## Memory bandwidth controller (CBQRI)

`ip_list/axi_llc/src/axi_llc_cbqri_bc.sv`, inside the LLC (`axi_llc_top`, parameter `QosBc`; build knob `QOS_LLC_BC`,
default 1, and `QOS_LLC_BC_POOL`, the pool size, default 16). It regulates the LLC's memory traffic per RCID with the
CBQRI v1.0 bandwidth-controller interface: reserved bandwidth blocks (Rbwb) and weights (Mweight) per RCID, and
per-MCID byte counters. Registers at `0x1040_1C00` (the LLC configuration space; the capacity controller is at
`0x1040_1800`), 64-bit, read and written as two 32-bit words, low word last (the low word holding OP starts an
operation, which completes in the cycle of the write: BUSY is always 0).

**Where it sits.** Between the hit/miss unit and the eviction unit. A descriptor that needs the memory leaves the
lookup there with its victim way chosen and its line locked: `refill` reads one 64-byte line, `evict` writes one (a
dirty victim). Each such descriptor enters a parking pool, and an arbiter releases the pool into the eviction/refill
pipeline, charging 64 bytes per line moved to the RCID in the descriptor's user field. The pipeline behind it is in
order and short (eviction FIFO 4, miss buffer 2, refill FIFO 4, every refill on one AXI ID), so a throttle after the
memory port would stall every RCID's misses and, once those FIFOs fill, the lookup and every hit too. The pool takes
the waiting off the lookup: while an RCID waits for bandwidth, the others' hits and misses go on.

**What it hands out.** `NBWBLKS = 1024` blocks stand for `BC_CAPACITY` bytes per accounting period of `BC_PERIOD`
cycles, so an RCID's reservation is `Rbwb * BC_CAPACITY / 1024` bytes per period. With `BC_CTRL.PACE` (the reset value)
a token bucket paces all releases to `BC_CAPACITY / BC_PERIOD` bytes per cycle (bursts of two lines): the controller is
then the bottleneck by construction and the waiting happens in its pool, where the arbiter orders it. Without pacing
the queues behind it (the refill path and the memory's own FIFOs) decide the order whenever memory is the bottleneck,
because each core has only one or two misses in flight and the pool would hold no choice. Set `BC_CAPACITY` at or a
little below what the memory sustains per period (`t_bc` hands out 90 %).

**Release order** among descriptors the ordering rules allow:
1. descriptors that cost nothing (hits the LLC routes through the miss pipeline to keep AXI order, flushes), and
   descriptors that a waiting descriptor of an RCID still inside its reservation depends on (priority inheritance, two
   levels), oldest first;
2. descriptors of RCIDs inside their reservation this period, oldest first (the floor: CBQRI's "bandwidth made
   available to an RCID ... even when all other RCID are using their full allocation");
3. descriptors of RCIDs past their reservation with Mweight > 0, sharing what is left in proportion to Mweight (stride
   scheduling: each release adds `4096 / Mweight` per line to the RCID's pass, lowest pass first; reset every period);
RCIDs past their reservation with Mweight = 0 wait for the next period: a hard limit, as CBQRI defines Mweight 0.
Within the paced rate the arbiter is work-conserving.

**Ordering rules** (the LLC's own, kept by the pool): descriptors of one AXI ID leave in order; all writes leave in
order (the LLC's write unit takes W beats in arrival order, and AXI4 W beats carry no ID); a flush leaves in order with
everything. So a write miss of a throttled RCID can hold later writes of other RCIDs; priority inheritance releases it
(charged to its owner) when a write of an RCID inside its reservation waits behind it.

| Offset | Register | |
|---|---|---|
| 0x00 | `bc_capabilities` | RO: VER 0x10, NBWBLKS 1024, RPFX 0, P 0, MRBWB 819 (80 %) |
| 0x08 | `bc_mon_ctl` | OP [4:0] (1 CONFIG_EVENT, 2 READ_COUNTER), AT [7:5] RO 0, MCID [19:8], EVT_ID [27:20] (0 none, 1 read+write bytes, 2 read bytes, 3 write bytes; configuring resets the counter), ATV [28] RO 0, STATUS [38:32] (1 ok, 2 bad OP, 3 MCID >= 16, 4 EVT_ID > 3), BUSY [39] 0 |
| 0x10 | `bc_mon_ctr_val` | RO: CTR [61:0] (48 bits implemented), INV [62] (no event configured), OVF [63] |
| 0x18 | `bc_alloc_ctl` | OP [4:0] (1 CONFIG_LIMIT, 2 READ_LIMIT), AT [7:5] RO 0 (no per-AT allocation), RCID [19:8], STATUS [38:32] (1 ok, 2 bad OP, 3 RCID >= 16, 5 Rbwb = 0, Rbwb > MRBWB or the sum over RCIDs > MRBWB; the allocation is then unchanged), BUSY [39] 0 |
| 0x20 | `bc_bw_alloc` | Rbwb [15:0], Mweight [27:20], sharedAT [30:28] RO 0, useShared [31] RO 0 |
| 0x80 | `BC_CTRL` | [0] EN regulation, [1] PACE (reset 1); monitoring and the pool work either way |
| 0x88 | `BC_PERIOD` | accounting period, cycles (reset 10000) |
| 0x90 | `BC_CAPACITY` | bytes per period the 1024 blocks stand for (reset 64000) |
| 0x98 | `BC_POOL` | RO: [7:0] descriptors in the pool, [15:8] high-water mark (a write clears it) |
| 0xA0 | `BC_FULL` | cycles a descriptor waited because the pool was full (a write clears it) |
| 0xA8 | `BC_RATE` | RO: pacing rate, bytes per cycle in 16.16 (`BC_CAPACITY * 2^16 / BC_PERIOD`, 48 cycles after a write of either) |

Reset (CBQRI: "all available bandwidth to RCID 0"): RCID 0 Rbwb = MRBWB and Mweight 255, every other RCID Rbwb 0 and
Mweight 1 (UNSPECIFIED in CBQRI), regulation off: the pool is then a FIFO and nothing changes for software that does
not know the controller. Software lowers RCID 0 before it gives other RCIDs blocks (the sum rule holds at every step).
Monitoring counts the bytes of refills (read) and evictions (write) as the controller releases them, per the MCID of
the descriptor, regulation on or off. The lock box's Bloom filter (`axi_llc_pkg::BloomHashWidth`) is 8 bits (256
counters, was 6): parked misses keep their lines locked, and a few dozen locked lines in 64 counters gave frequent false
lock stalls and could overflow the 3-bit counters.

Not covered: traffic that bypasses the LLC (uncached ranges) is not regulated; per-AT allocation (code/data) is not
implemented (AT read-only zero, allowed by CBQRI); the pool holds 16 descriptors, so more than 16 waiting misses (more
than four cores with several each) would stall the lookup again.

## Checking it

**Tests** (`t_qos` and `t_cbqri` are in the `sim_regress` suite `soc`; `t_qosv` and `t_iojob` run on their own):

- **`t_qos`** checks `srmcfg`: reset value, WARL behaviour, and access in M, S, U, VS and VU mode.
  - Through the accelerator socket's **QoS probe** at `0x103F_0000`, every core reads back the user field
    of its own uncached read and write. `+0x0` returns that read's user field; `+0x4` returns the last
    write's.
  - It generates cached traffic with per-core tags, cross-core sharing, AMOs, LR/SC, and 48 dirty lines in
    one 16-way LLC set, so the LLC evicts to memory.
- **`t_qosv`** checks the privilege association and vRCID translation (core 0, every tag read back through the
  QoS probe): reset values and WARL masks of the new CSRs; M/HS/VS association on and off, U/VU keeping
  `srmcfg`; loads under MPRV (MPP = S, U; MPV = 1) and HLV from M mode taking the effective privilege's IDs;
  VS/VU access to `srmcfg`/`sqosid` trapping with translation off and reaching the guest copies (no trap,
  virtual values read back, host `srmcfg` untouched) with it on; translation through both map CSRs, the default
  RCID for an invalid entry, a remap applying to the next access; the same for guest MCIDs through `hmcidmap`
  (untranslated again once VEN is cleared), and the vMCID CSRs illegal when `QOS_NUM_VMCID=0`.
- **`t_iojob`** checks device DMA tags (accelerator socket, "Device DMA" above): capability and reset values, write
  masks; three jobs queued by one core under three `srmcfg` values, each job's completion carrying its submitter's
  tag; jobs queued by cores 1 and 2 (their source ports in the tag); a full queue (OVF, DROPPED, the dropped job never
  runs); an M-mode `SUBMIT` with `mqosctl.M` carrying `mqosid`; the range rules (lowest entry wins, inclusive bounds,
  V and slot bits, RANGE_EN / DEV_OFF / FORCE, misses to the device's tag or the default) on the example and crc32,
  read back through `LAST_USER` / `LAST_SRC`. Builds without the queue or the table check that they are absent. The
  accelerator unit test (`accel_unit_test(name='example')`) checks the tag of every DMA request of three queued jobs
  (`mem_user_of(addr)` in `hardware/accel/tb/accel_tb.sv`).
- **`t_cbqri`** has four parts:
  - **Register interface.** All fields, STATUS codes, and `CONFIG_LIMIT`/`READ_LIMIT` round trips.
  - **Isolation.** 8 victim lines (RCID 1, ways 0–7) and 80 reads of 40 aggressor lines (RCID 2,
    ways 8–15) share one LLC set. Reading the victims again causes **0** LLC read misses, counted by the
    SoC control block's LLC miss counter at `0x1A10_6008`. With shared masks the same sequence causes **8**.
  - **Code/data split.** Code fetched under RCID 3 goes only into that RCID's code ways.
  - **All-core stress.** Every core c, with RCID 4 + c and a disjoint data mask of 16 / `SOC_NUM_CORES` ways,
    writes 64 / `SOC_NUM_CORES` lines in one LLC set and must read back what it wrote. With four cores, RCIDs 4–7
    have 4 ways and 16 lines each; with eight, RCIDs 4–11 have 2 ways and 8 lines each.

**Simulation checkers** (both in every simulation; `sim_status` reports their errors as `qos_errors`, and
`sim_regress` fails a test that has any):

- **Scoreboard** (`host/qos_monitor.sv`) checks every request:
  - At each **core port**, a new request must carry the RCID/MCID the hart's CSR file currently selects
    (`srmcfg`, or a privilege-associated register with the guest RCID translated: the fetch IDs for
    instruction fetches, the load/store IDs otherwise), and AT = 1 exactly for instruction fetches.
  - At the **LLC input**, a request must carry a tag its source core issued for that 64-byte line, or, for
    CCU write-backs, a tag another core or the accelerator socket issued for that line. (The socket's requests are
    recorded at its port into the CCU, role `dma`: a socket write to a line dirty in a core's cache makes the CCU
    write the core's data back with the socket's tag and the core's source port.)
  - At the **LLC output**, a refill must carry the user field of a recent LLC request to that line. An
    eviction must carry the user field of a recent request to that set. A write-back of an LLC flush has no
    requester: it carries user field 0 and AXI ID 0, so the memory SPU charges it to source 0, core 0's code
    (`hardware/ip_list/apmu/README.md`). The LLC isolates its slave port while it flushes, so every eviction in that
    window is a flush write-back: each must carry user field 0, uses up one of the LLC's `evict_flush` events (one
    per line a flush writes back), and counts as `flush` if it matches no recent request.
- **Allocation checker** (`axi_llc_hit_miss`): every refill must land in a way of its (RCID, AT) mask.

`sim_status(run_id, qos=true)` shows the checkers' summaries. It also lists per-RCID allocation counts and the
ways used (`[QOS] llc_alloc rcid=.. at=.. n=.. ways=.. mask=..`), and the request counts per tag at the LLC.

**Board-like memory timing.** By default the simulation's DRAM sits behind the same clock-domain crossing as the
FPGA's DDR4 controller and answers with random per-transfer stalls, so reads can overtake writes
(`hardware/xsim/README.md`, section 2). The whole `sim_regress` suite, the `fpga=1` board binaries, and a 4-core
thrash of 48 dirty lines in one LLC set pass in that mode with 0 checker errors (2026-10-14).

**Mutation-tested** (2026-10-14). Three bugs were injected into the RTL, and each was caught:

| Injected bug | Caught by |
|---|---|
| The core corrupts the RCID on writes | core-port scoreboard and `t_qos` probe |
| The LLC drops the tag on refills | LLC-output scoreboard |
| The LLC ignores the CBQRI mask | allocation checker, plus `t_cbqri`'s miss-count check (8 misses instead of 0) |

**Not covered:**

- Page-table walks (no test turns on virtual memory). They go through the D$ like other loads.
- The CCU's own write-back path for a core's CleanUnique/LR race on a dirty line. (Its write-back on behalf of
  the accelerator socket is reached: in `t_iojob` the socket's writes to lines dirty in core 0's D$ make the CCU
  write core 0's data back with the socket's tag and core 0's port, 131 times, all matching the socket's tags.)
- The cluster build (`EXCLUDE_CLUSTER` off).

## Next steps

- Per-AT bandwidth allocation in the memory bandwidth controller, and regulation of traffic that bypasses the LLC.
- Capacity usage monitoring (`cc_mon_ctl`), which would need an occupancy count per MCID kept with the LLC
  tags.

## The LLC's cached address range under Linux (2026-10-19)

The LLC caches only `0x8000_0000-0x8080_0000` out of reset (SoC control `0x1A10_6018/1C`): under Linux that is the
kernel image, nothing else. The netboot loader now sets the end to the top of RAM before the payload runs. Widening
the range on a running system is safe (the new region has no lines in the LLC), but **shrinking it is not**: the
dropped region's lines, dirty ones included, stay in the LLC while new accesses to those addresses bypass it, and the
SoC wedges shortly after. Reproduced from a kernel module three times, once with a flush first and every hart
quiesced under `stop_machine`. Set the range once, at boot. `alsaqr-software/linux/llcpart` (the way-partitioning
test module) widens it if needed and never restores it. The probe at `0x103F_0000` reads fine from Linux with any
`srmcfg`; the 3-bit source-port field (`QosUserLsb` = 3 with four cores) puts the RCID at bits [6:3] of the value.
