# Last-level cache (axi_llc)

The LLC is the SoC's shared, write-back last-level cache. Every DRAM access from the cores, the DMA masters and the
other crossbar masters passes through it. It is PULP's `axi_llc` with tree pseudo-LRU replacement, way partitioning
(per AXI source and per CBQRI RCID), a CBQRI bandwidth controller for its memory traffic and a write-data buffer. This
doc describes the structure. Partitioning and regulation policy are in the QoS block doc (`csat/blocks/qos.md`).

## How it works

**Size.** 16 ways × 1024 sets × 64-byte lines (8 blocks of 64 bits) = 1 MiB (`LLC_SET_ASSOC`, `LLC_NUM_LINES`,
`LLC_NUM_BLOCKS` in `ariane_soc_pkg.sv`). The slave and memory ports are 64-bit AXI4+ATOP. The memory port's ID is
one bit wider than the slave port's.

**Address routing.** `axi_llc_config` decodes every request against two windows. The *cached window* has its start
and end in SoC control registers (`apb_soc_control`, `llc_cache_addr_start/end`). The *SPM window* starts at
`llc_spm_addr_start`. Ways set in `CfgSpm` serve as directly addressed scratchpad. The host crossbar maps a 128 KiB
SPM region to the LLC. Requests outside both windows go through the bypass (`axi_llc_demux` → `axi_mux`) straight to
the memory port. An `axi_isolate` stalls new requests while a flush runs.

**Pipeline.** A request is cut into per-line descriptors that carry the request's ID, address, burst and `user`
field (the QoS tag):

1. `axi_llc_chan_splitter` cuts the AW and AR channels. AW descriptors go through `axi_llc_w_buffer`.
2. An arbitration tree merges flush, read and write descriptors, followed by a spill register.
3. `axi_llc_hit_miss` holds the tag store with the PLRU state in SRAM, an exact table of locked lines and miss counters.
   It locks the line and picks the victim way. Hits take the hit bypass to the read or write unit and may overtake
   misses of other AXI IDs. A hit with the same ID as an outstanding miss stays in order through the miss pipeline.
4. With the bandwidth controller, misses go to `axi_llc_cbqri_bc`, a parking pool that releases descriptors into
   the miss pipeline by RCID budget.
5. `axi_llc_evict_unit` writes back a dirty victim and `axi_llc_refill_unit` reads the line. Both are strictly in
   order, and both carry the request's `user` field to memory. `axi_llc_merge_unit` hands the descriptor on.
   A write-back does not hold the pipeline until its write response: the descriptor goes on once its last W beat
   is sent, and the write-back waits for the response in a table of `QOS_LLC_WBPEND` entries (`axi_llc_w_master`).
   Only a refill of a line whose write-back is still in the table waits for that response, because a read sent
   before it could be served first and return the memory's stale copy. A write-back needs a free entry to start.
6. `axi_llc_write_unit` / `axi_llc_read_unit` access `axi_llc_ways`, the data SRAMs, one per way.

**Replacement and way locking.** `axi_llc_plru` (tree PLRU, selected in `axi_llc_evict_box`) chooses the victim among
ways that are not locked. Three masks lock ways:

- ways configured as SPM;
- the per-source way mask from `axi_llc_config`, indexed by the AXI ID bits `SourceIDStart..SourceIDEnd`, which are
  {crossbar port, remapper source prefix};
- the CBQRI capacity mask of the request's (RCID, AT), from `axi_llc_cbqri_cc`.

The CBQRI mask is ignored for a request when it would leave no way unlocked. Masks restrict allocation only; a hit
is served from any way.

**Write-data buffer** (`axi_llc_w_buffer`). Each write descriptor of up to one line at full width gets a slot that
captures its W beats. Writes then need only per-ID order. Longer or narrower bursts take no slot and stay in AW order
with every other write.

**Configuration port.** One AXI4-Lite port, demultiplexed by offset (`QosCcOffset`, `QosBcOffset`):

- the LLC's own registers (`CfgSpm`, `CfgFlush`, `Flushed`, `BistOut`, the read-only geometry, then `NumCfgRegcp`
  per-source way masks);
- the CBQRI capacity controller;
- the CBQRI bandwidth controller.

**Events.** `axi_llc_events_o` drives the read/write hit/miss counters in `apb_soc_control` and, in simulation, the
QoS scoreboard (`qos_monitor`).

## Configuration

- Geometry: `LLC_SET_ASSOC`, `LLC_NUM_LINES`, `LLC_NUM_BLOCKS` (`ariane_soc_pkg.sv`).
- `axi_llc_top` parameters set in `host_domain.sv`: `SourceIDStart/End` and `NumCfgRegcp` (per-source masks),
  `QosRcidWidth`/`QosRcidLsb`/`QosAtBit` (where the tag sits in `user`), `QosBc`, `QosBcPoolDepth`,
  `QosWBufSlots`, `EvictPendDepth`, `QosGates`/`QosGateSrcMask`.
- Make variables and defines (defaults in `ariane_pkg.sv`):
  - `QOS_RCID_WIDTH`/`QOS_MCID_WIDTH`: RCID and MCID widths, which size the per-RCID tables.
  - `QOS_LLC_BC`: 0 removes the bandwidth controller.
  - `QOS_LLC_BC_POOL`: pool depth.
  - `QOS_LLC_WBUF`: write-buffer slots; 0 removes the buffer.
  - `QOS_LLC_WBPEND`: write-backs that may wait for their write response while the miss pipeline goes on (4); 0
    makes every miss behind a write-back wait for its response, as in the original LLC.
  - `QOS_DMA_GATE`: admission gates for the CCU's DMA ports; needs `QOS_LLC_BC`.
- `EXCLUDE_LLC` (`exclude-llc=1`): the crossbar's DRAM route connects straight to memory, with no LLC, slowdown or
  DRAM model.

## Using it

- **Cached window.** The netboot loader (`software/netboot`) widens it to all DRAM before Linux. The alsaqr-software
  `llcpart` module widens it from Linux. Addresses outside it bypass the LLC.
- **SPM and flush.** Set ways in `CfgSpm`, write `CfgFlush`, poll `Flushed`. A flush is reported done only when
  the memory has answered every write-back.
- **Hit/miss counters.** SoC control registers next to the window registers.
- **Partitioning and bandwidth.** CBQRI from bare metal (`t_cbqri`, `t_bc`) or from Linux resctrl (alsaqr-resctrl
  worktree, alsaqr-software `linux/resctrl` and `linux/llcpart`).

`soc_lookup` (alsaqr-mcp) returns the windows' addresses. The register layouts are in the header comments of
`axi_llc_config.sv`, `axi_llc_cbqri_cc.sv` and `axi_llc_cbqri_bc.sv`, and in `soc_control_regs.hjson`.

## Verification

- `sim_regress` suite `soc`: `t_mem` (eviction sweep), `t_cbqri` (capacity controller registers and isolation),
  `t_part` (way partitioning between cores and accelerator DMA, as performance), `t_dram`.
- By name: `t_bc`, `t_bcw`, `t_bcd` (bandwidth controller, write ordering, DMA gates), `t_sweep` (latency against
  working-set size: L1, LLC, DRAM).
- By name: `t_wbhol` (how much another core's write-backs cost a reader, with the DRAM timing model), `t_wbrace`
  (stores must survive when lines leave the LLC dirty and are read back at once; also on the board).
- Unit testbenches in `hardware/xsim/tests` (`run_*.sh`): `tb_llc_bc` (bandwidth controller), `tb_llc_wbuf` (write
  buffer with out-of-order writes), `tb_llc_wbpend` (write-backs without the wait for their response, in front of
  a memory that applies a write only with its response, answers late and out of order and serves reads early;
  `MUTANT=` variants without the waits must fail), `tb_llc_wmaster` (the write stage alone against a model; the
  same on a synthesised netlist with `run_llc_wmaster_netlist.sh`), `tb_bc_gate` (admission gate). `hardware/ip_list/axi_llc/test/tb_axi_llc.sv` is
  the upstream testbench.

## Properties

- Line size 64 B against the L1's 16 B. An LLC miss refills 8 beats. Bypassed traffic reaches memory as the L1's
  2-beat fills.
- The eviction/refill pipeline is in order. A refill never reaches the memory before the write response of an
  older write-back of the same line; refills of other lines do not wait for write responses.
- The memory must answer the refills in the order they were sent (the refill unit does not look at the R ID) and
  the write-backs of one AXI ID in order; write responses of different IDs may come in any order.
- Refills and evictions carry the `user` field of the request that caused them. Flushes from the configuration port
  carry 0.
- Shrinking the cached window on a running system does not write back the lines of the removed region.

## Code

- `hardware/ip_list/axi_llc/src/axi_llc_top.sv`: top, descriptor type, wiring of all units.
- `hardware/ip_list/axi_llc/src/axi_llc_config.sv`: LLC registers, per-source masks, windows, flush.
- `hardware/ip_list/axi_llc/src/axi_llc_hit_miss.sv`, `hit_miss_detect/`: tag store, PLRU, locks, way masking.
- `hardware/ip_list/axi_llc/src/axi_llc_cbqri_cc.sv`, `axi_llc_cbqri_bc.sv`, `axi_llc_bc_gate.sv`: CBQRI capacity
  controller, bandwidth controller, DMA admission gate.
- `hardware/ip_list/axi_llc/src/axi_llc_w_buffer.sv`: write-data buffer.
- `hardware/ip_list/axi_llc/src/eviction_refill/`, `axi_llc_{evict,refill,merge,read,write}_unit.sv`,
  `axi_llc_ways.sv`: miss pipeline and data storage.
- `hardware/host/host_domain.sv`: instance and parameters.
- `hardware/host/apb_soc_control.sv`, `hardware/deps/apb_host_control_regs/soc_control_regs.hjson`: window and
  counter registers.

## Reference

- `hardware/docs/qos.md`: CBQRI register layouts, release order, gates.
- `hardware/ip_list/axi_llc/doc/axi_llc.md`: upstream LLC architecture and register map.
