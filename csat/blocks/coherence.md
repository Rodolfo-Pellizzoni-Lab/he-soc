# Coherence (Culsans CCU)

The cache coherence unit (CCU) is a snooping ACE interconnect from PULP's Culsans. It keeps the cores' write-back L1
data caches coherent with each other and with the two DMA masters that share it: the accelerator socket's DMA and
the Ethernet's DMA. All of its traffic leaves on one AXI port towards the crossbar and the LLC.

## How it works

**Ports.** One `ace_ccu_top` (instantiated in `cva6_synth_wrap.sv`) has `NumCVA6 + 2` slave ports: the cores, then
the accelerator DMA, then the Ethernet DMA (`CcuAccelPort`, `CcuEthPort` in `ariane_soc_pkg.sv`). The DMA ports
never cache anything. The wrapper turns their reads into ReadOnce and their writes into WriteUnique, and answers every
snoop to them with "no data". Both DMA masters issue single-beat 64-bit requests.

**Split by type.** On each port, `ace_trs_dec` and an `axi_demux` route each request:

- WriteBack and the non-snooping requests go straight to the output `axi_mux`. L1 write-backs never enter the state
  machine.
- Shareable requests (ReadShared, ReadUnique, ReadOnce, CleanUnique, WriteUnique, LR, atomics) are multiplexed into
  the single state machine `ccu_fsm`.

**State machine** (`ccu_fsm.sv`). It takes one shareable request at a time from `IDLE` and snoops every port except
the initiator's.

- A read sends its snoop type to the other ports. If a cache answers with data, the FSM forwards that line
  (`READ_SNP_DATA`). Otherwise it reads memory.
- A CleanUnique or an LR sends CleanInvalid to the other ports and writes back any dirty data they return. An LR
  then reads memory.
- A write or atomic sends CleanInvalid, writes back any dirty data, then performs the write or atomic in memory.
- The FSM writes the source port into the low bits of the AXI `user` field. A write-back of snooped data carries
  the port that held the data.

**Decoupled reads.** With `DecoupledReads` set, a memory read leaves the FSM once its AR is accepted, and its R
beats return to the initiator by AXI ID. An in-flight table (`NumInflight` entries: line range and ID) makes a new
request to such a line, or a read with an in-flight read's ID, wait in `IDLE`. That way no snoop for a line reaches a
cache while the line's data is on its way to it. LRs, and reads issued while the table is full, wait in `READ_MEM`.

**L1 side** (`std_nbdcache` and friends in `ip_list/cva6/core/cache_subsystem`). 16-byte lines with `valid`,
`shared` and per-byte `dirty` state. The miss handler, the snoop controller and three cache controllers share one
SRAM through a fixed-priority arbiter.

- A store hit on a shared line first gets a CleanUnique (`MAKE_UNIQUE`).
- A ReadShared snoop hit marks the line shared. The owner keeps it dirty and returns the data with PassDirty 0.
- Atomics write back and invalidate the local copy, then run in memory.
- Race guards (`colliding_read`/`colliding_clean`, `store_hold_o`, `refill_req_o`) order a snoop against a
  store or refill to the same line or way.

**Downstream.** CCU → `axi_cut` → `cva6_axi_id_remap` (IDs become {source prefix, slot}, at most `RemapMaxUniqIds`
IDs × `RemapTxnsPerId` in flight per direction) → CDC to the SoC clock → host crossbar port `CVA6` →
`axi_riscv_atomics_wrap` (AMOs and LR/SC, with reservations keyed by the `user` source bits) → `axi_cut` → LLC.

## Configuration

- `NUM_CVA6`: the core count, and with it the number of CCU ports and snoop targets.
- `CCU_CFG` (`cva6_synth_wrap.sv`): `LatencyMode = CUT_ALL_PORTS` (spill registers on every demux/mux channel, for
  50 MHz FPGA timing), the slave ID width of 4 (CVA6's), and the outstanding-transaction limits.
- `ccu_fsm` parameters `DecoupledReads` and `NumInflight` (`ace_ccu_top` leaves them at the defaults in
  `ccu_fsm.sv`). With `DecoupledReads` 0, a memory read holds the FSM until its last beat.
- L1 D$: CVA6 configuration `cv64a6_imafdc_sv39_wb`: 16 KiB, 8 ways, 16-byte lines, coherent.

## Using it

Software does no cache maintenance for coherence between cores or with the socket and Ethernet DMA. A `fence` does
not flush the coherent L1. A `fence.i` writes back and invalidates the whole L1 D$. Other crossbar masters (debug
module system bus, uDMA, APMU) reach DRAM through the LLC without snooping, so they are not coherent with the L1s.

## Verification

- `software/soc_tests` in the `soc` suite of `sim_regress` (alsaqr-mcp): `t_mem`, `t_atomics`, `t_smp`, `t_dma`,
  `t_eth`, `hello_culsans`, `quad_boot`.
- By name (`sim_regress tests=[...]`):
  - `t_stopm`: one writer against spinning readers, Linux `multi_cpu_stop`.
  - `t_chk`: data-integrity stress; `-DCHK_SHARED` adds snooped shared lines.
  - `t_bw`: cycles per line for 1 to N harts.
- Build with `SOC_NUM_CORES=<n>` for an n-core SoC. `board_run` and `board_regress` run the same programs on the
  VCU118.
- Under Linux: alsaqr-software `linux/memstress` (`chk`, `chk2`, `par shared`).

## Properties

- The FSM serves one shareable transaction at a time. Its decode and snoop round wait for every other port's
  snoop response, so a snoop held in one L1 stalls the CCU for every port.
- Up to `NumInflight` memory reads overlap. Writes, write-backs of snooped data, LRs and atomics hold the FSM until
  their response.
- The snoop-data path carries one 16-byte line.
- One hart streaming LLC hits takes about 43-47 cycles per 16-byte line. The serial part per shareable transaction
  is about 9 cycles, which bounds the aggregate shareable traffic (`hardware/docs/ccu_model.md`).
- The L1 miss handler writes back one line at a time.
- The CCU is the only coherence point: the LLC neither snoops nor enforces inclusion.

## Code

- `hardware/ip_list/ace/src/ace_ccu_top.sv`: CCU top (decoders, demuxes, muxes, FSM).
- `hardware/ip_list/ace/src/ccu_fsm.sv`: the state machine and the in-flight table.
- `hardware/ip_list/ace/src/ace_trs_dec.sv`: the shareable/non-shareable decision.
- `hardware/ip_list/ace/test/`: upstream CCU testbenches.
- `hardware/host/cva6_synth_wrap.sv`: CCU instance, `CCU_CFG`, DMA-port ACE conversion, ID remapper, CDC.
- `hardware/host/cva6_axi_id_remap.sv`: the ID remapper.
- `hardware/host/cva6_subsystem.sv`: DMA gates and spill stages, crossbar, atomics adapter.
- `hardware/include/ariane_soc_pkg.sv`: port numbering, source/ID widths, remapper sizes.
- `hardware/ip_list/cva6/core/cache_subsystem/`: the L1 D$ (`std_nbdcache`, `cache_ctrl`, `miss_handler`,
  `snoop_cache_ctrl`).

## Reference

- `hardware/docs/coherence.md`: L1 and snoop-controller state machines and race guards.
- `hardware/docs/ccu_model.md`, `ccu_model.py`: cycle traces and the CCU performance model.
