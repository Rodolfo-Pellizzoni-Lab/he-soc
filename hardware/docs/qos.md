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

Sources: `riscv_pkg.sv` (`CSR_SRMCFG`), `csr_regfile.sv` (register, access checks, `qos_rcid_o` / `qos_mcid_o`),
`cva6.sv` (tagging of the core's AXI port).

## The tag on the buses

Inside CVA6, every AR and AW leaving the core gets `user[QOS_TAG_WIDTH-1:0] = {AT, MCID, RCID}`:

- **AT** is the CBQRI access type: 1 for instruction fetches (I$ refills, AXI ID `4'b0000` in the WB cache
  subsystem), 0 for data.
- Data covers loads, stores, AMOs, page-table walks, D$ refills and write-backs, and uncached accesses.
- The W, R and B channels are not tagged.

On the SoC buses (`ariane_axi_soc` package), the user field is 12 bits:

```
user[2:0]   source port of the CCU (written by the CCU): 0-3 the cores, 4 the accelerator socket's DMA port
user[3+:4]  RCID
user[7+:4]  MCID
user[11]    AT
```

(`QosUserLsb` is `$clog2(NumCVA6 + 1)`: the CCU writes its port index into the low bits, and the socket's DMA is its
fifth port, see `hardware/accel/README.md`.)

Use `ariane_axi_soc::qos_tag(user)` to decode a SoC user field into an `ariane_pkg::qos_tag_t {at, mcid, rcid}`,
and `ariane_axi_soc::qos_user(tag)` to build one.

| Where | What happens to the tag |
|---|---|
| `cva6_synth_wrap` | moves the core's tag above the source-port bits |
| CCU (`ip_list/ace`) | passes the requester's tag through. Dirty data snooped from another core usually moves to the requester's cache, and the requester's own write-backs carry its tag later. When the CCU writes the data back itself (CleanUnique or LR that invalidates a dirty line), that write carries the tag of the request that caused it, and its source port is the core that supplied the data. `t_qos` does not reach this case |
| host xbar, CDC FIFOs, ID remapper, AMO/LR-SC adapters | pass `user` through |
| LLC (`ip_list/axi_llc`) | allocates by the tag's RCID and AT (next section). Refills and evictions carry the tag of the request that caused them (new descriptor field `a_x_user`); config-port flushes carry 0 |
| DRAM / HyperRAM / peripherals | ignore it |
| Other masters (debug module, iDMA, uDMA, accelerator socket, cluster) | tag 0 (RCID 0, MCID 0) |

**The source-port bits also key LR/SC reservations.** Both `axi_riscv_atomics` adapters (L2 and L3,
`host/cva6_subsystem.sv`) track reservations per `user[2:0]` (`AXI_USER_AS_ID`, one entry per CCU port) instead of per
AXI ID. The core-side ID remapper (`cva6_axi_id_remap`, separate read and write tables) does not keep the LR's AR ID
and the SC's AW ID equal when other transactions are in flight, so an ID-keyed table only worked by timing luck: on the
VCU118 every SC to the uncached L2 failed while simulation (instant UART / L2 responses) passed. The address-based clear
on any write is unchanged. Masters other than the cores share entry 0.

## LLC capacity controller (CBQRI)

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
- **Parameters.** `axi_llc_top` takes `QosRcidWidth` (0 turns the controller off), `QosRcidLsb`, `QosAtBit`
  and `QosCcOffset`.

## Checking it

**Tests** (both in the `sim_regress` suite `soc`):

- **`t_qos`** checks `srmcfg`: reset value, WARL behaviour, and access in M, S, U, VS and VU mode.
  - Through the accelerator socket's **QoS probe** at `0x103F_0000`, every core reads back the user field
    of its own uncached read and write. `+0x0` returns that read's user field; `+0x4` returns the last
    write's.
  - It generates cached traffic with per-core tags, cross-core sharing, AMOs, LR/SC, and 48 dirty lines in
    one 16-way LLC set, so the LLC evicts to memory.
- **`t_cbqri`** has four parts:
  - **Register interface.** All fields, STATUS codes, and `CONFIG_LIMIT`/`READ_LIMIT` round trips.
  - **Isolation.** 8 victim lines (RCID 1, ways 0–7) and 80 reads of 40 aggressor lines (RCID 2,
    ways 8–15) share one LLC set. Reading the victims again causes **0** LLC read misses, counted by the
    SoC control block's LLC miss counter at `0x1A10_6008`. With shared masks the same sequence causes **8**.
  - **Code/data split.** Code fetched under RCID 3 goes only into that RCID's code ways.
  - **4-core stress.** RCIDs 4–7 have disjoint 4-way masks and write and read 16 lines each in one set.

**Simulation checkers** (both in every simulation; `sim_status` reports their errors as `qos_errors`, and
`sim_regress` fails a test that has any):

- **Scoreboard** (`host/qos_monitor.sv`) checks every request:
  - At each **core port**, a new request must carry the hart's current `srmcfg` RCID/MCID, and AT = 1
    exactly for instruction fetches.
  - At the **LLC input**, a request must carry a tag its source core issued for that 64-byte line, or, for
    CCU write-backs, a tag another core issued for that line.
  - At the **LLC output**, a refill must carry the user field of a recent LLC request to that line. An
    eviction must carry the user field of a recent request to that set.
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
- The CCU's own write-back path, which needs a CleanUnique/LR race on a dirty line.
- The cluster build (`EXCLUDE_CLUSTER` off).

## Next steps

- A CBQRI bandwidth controller, or bandwidth/occupancy monitoring per MCID, at the LLC memory port
  (`llc_out`).
- Capacity usage monitoring (`cc_mon_ctl`), which would need an occupancy count per MCID kept with the LLC
  tags.
