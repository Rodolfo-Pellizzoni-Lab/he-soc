# Advanced Performance Monitoring Unit (APMU)

The **APMU** is a centralized, AXI4-based performance-monitoring unit. It aggregates the
microarchitectural events forwarded by the per-core **Event Monitoring Units (EVUs)** and
the **SPU** interconnect snoopers, counts and correlates them in a bank of programmable
counters, and runs event-driven monitoring policies on an embedded processing element (a
lowRISC **Ibex** core) — entirely off the application cores. It is the central IP of the
performance-monitoring architecture in our EMSOFT 2026 paper.

<p align="center"><img src="./apmu_block_diagram.png" alt="APMU block diagram" width="760"></p>

## How it works

- **Event ports** (`pmu_port`, `pmu_port_wrap`). Each EVU connects to a dedicated APMU port
  (`Port_1 … Port_M`) that receives its microarchitectural-event stream.
- **Event Filter + Counter Block** (`pmu_counter`), replicated `NUM_COUNTERS` times. Each
  counter selects the event(s) it tracks (its *Event-Select* register), optionally captures
  an info field (e.g. per-access latency), and raises an **overflow interrupt** to the
  system interrupt controller when it crosses its budget/threshold.
- **APMU processing element (APMU-PE) and scratchpads** (`pmu_core`, `pmu_ispm`,
  `pmu_dspm`). A lowRISC Ibex core with instruction (`I$`) and data (`D$`) scratchpad
  memories runs the monitoring firmware that programs the counters, reads results, and
  reacts to events (e.g. memory-bandwidth regulation) without involving the application
  cores.
- **APMU interconnect** ties the core, counters, and register interface together.
- **Register ports.** The **Read-Write Manager port** lets the APMU core reach out to the
  rest of the system; the **Read-Write Subordinate port** exposes the APMU's registers and
  scratchpads to the application cores over **AXI4-Lite**.

## Source layout (`src/`)

| File | Role |
|------|------|
| `pmu_top.sv` | Top-level integration (register interface, counters, core, ports). |
| `pmu_core.sv` | Ibex-based processing element wrapper. |
| `pmu_counter.sv` | Event filter + programmable counter (instantiated `NUM_COUNTERS`×). |
| `pmu_port.sv`, `pmu_port_wrap.sv` | EVU event-ingress ports. |
| `pmu_ispm.sv`, `pmu_dspm.sv` | Instruction / data scratchpad memories for the PE. |
| `pmu_gnt_to_axi_lite.sv` | Request-grant → AXI4-Lite adapter. |
| `pmu_pkg.sv` | Package: types and parameters. |

Depends on the `ibex_pmu` core and the PULP `axi` / `common_cells` libraries (see
[`Bender.yml`](./Bender.yml)). The AXI4-Lite register interface is implemented in the style
of AlSaqr's `axi_lite_regs` / `axi_llc_config`.

## Register map

Each counter and its configuration registers occupy a separate 4 KiB page:

| Register | Address | Page |
|----------|---------|------|
| Timer | `0x10405000` | – |
| Period Reg | `0x10405008` | – |
| Status Reg | `0x10406000` | – |
| Boot Addr Reg | `0x10406004` | – |
| Counter 0 | `0x10407000` | Page 0 |
| Event Sel 0 | `0x10407004` | Page 0 |
| Event Info 0 | `0x10407008` | Page 0 |
| Info Budget 0 | `0x1040700C` | Page 0 |
| Counter 1 | `0x10408000` | Page 1 |
| … | … | … |
| ISPM (8 KiB) | `0x10427000` | – |
| DSPM (128 KiB) | `0x10429000` | – |

The scratchpads are those of `pmu_top` in `hardware/host/host_domain.sv` (the DSPM moved from `0x10428000` when the
ISPM grew to 8 KiB in 05eee786). The PE fetches from the ISPM; its data port reaches only the DSPM, the registers
above (`0x10405000`-`0x10426FFF`) and the cores' EVU registers (`0x10606000`-`0x106060FF`). A PE load or store to any
other address is never granted: the PE stalls instead of trapping (`pmu_core.sv`). The cores reach both scratchpads
over AXI4-Lite. Load them with aligned 32-bit stores: the scratchpads index their SRAM by byte address, so a byte or
halfword store lands in a lane the PE does not read (the bare-metal `memcpy`, `software/common/syscalls.c`, stores
bytes unless the size is a multiple of 8). `software/quad_boot/pmu_defines.h` has the addresses for the cores and the
PE firmware; the firmware's linker scripts put its data at `DSPM + 0x200`, where the loaders copy it.

A counter overflows when its bit 30 sets (counting past `0x3FFFFFFF`, or a write of `0x40000000`). With
`overflow_intr_en` (Event Info bit 24, `OVERFLOW_EN`) set, counter *i* raises PLIC source 156 + *i* (`pmu_top.sv`,
`hardware/host/ariane_peripherals.sv`). Harts 2 and up wait in a WFI of the boot ROM: software wakes hart *h* by
enabling source 156 + *h* - 2 on its S-mode PLIC context 2*h* + 1 and overflowing counter *h* - 2, so sources 156 and
157 on contexts 5 and 7 with four cores (`soc_wake_all()` in `software/soc_tests/include/soc_test.h`, which also
takes the wake-up back).

### Event select and sources (AlSaqr)

A counter's Event Sel register is {port value [23:20], port mask [19:16], source value [15:12], source mask [11:8],
event value [7:4], event mask [3:0]} (`pmu_pkg::event_sel_cfg_t`). The counter counts an event when
`(mask & field) == value` holds for all three fields and the event value is not 0: an event value of 0 turns the
counter off (`pmu_port.sv`), so no select counts every event of a port; count each event ID on a counter of its own.
Ports with four cores: 1-4 the cores' EVUs, 5-8 the SPUs on the cores' ports to the LLC, 9 the SPU on the LLC memory
port (all DRAM traffic). SPU events: 1 read request, 2 write request, 3 read response, 4 write response. On ports 5-8
the source is bit 0 of the core's AXI ID (`i_spu_core_llc` in `hardware/host/cva6_synth_wrap.sv`), which does not tell
masters apart: the port is the core.

On ports 1-4 the event field is a bitmap of the core's four EVU slots, bit *s* set in a cycle in which slot *s* sees
its event, and the source is 0: slot *s* of core *c* is the select with port value *c* + 1 and event value and mask
`1 << s` (`0x1F0022`: core 0, slot 1). A slot's event ID picks its event
(`hardware/ip_list/cva6/core/perf_counters_evu.sv`):

| ID | Event | ID | Event | ID | Event |
|---|---|---|---|---|---|
| 0x00 | off | 0x08 | exception return | 0x10 | L1 I-cache access |
| 0x01 | L1 I-cache miss | 0x09 | branch | 0x11 | L1 D-cache access |
| 0x02 | L1 D-cache miss | 0x0A | branch mispredict | 0x12 | cache eviction |
| 0x03 | ITLB miss | 0x0B | branch exception | 0x13 | I-TLB flush |
| 0x04 | DTLB miss | 0x0C | call | 0x14 | integer instruction |
| 0x05 | load | 0x0D | return | 0x15 | FP instruction |
| 0x06 | store | 0x0E | MSB full | 0x16 | pipeline bubble |
| 0x07 | exception | 0x0F | instruction fetch empty | 0x17 | PC milestone |

The event IDs are 32-bit registers at `0x10606000 + 0x30*c` (`hardware/host/cva6_synth_wrap.sv`) in reverse slot
order: `+0x0` programs slot 3, `+0xC` slot 0 (`EVU_EID_REG(core, slot)` in `software/quad_boot/pmu_defines.h`). The
four 64-bit PC milestones follow in order, milestone *m* at `+0x10 + 8*m`. A slot with event ID 0x17 fires when the
core commits one of the milestone PCs, and bit *m* of the event's info field says which; an Event Info configuration
that adds that bit counts one milestone (`software/c1_v2`).

On port 9 the source says who caused the traffic (`hardware/include/ariane_soc_pkg.sv`, `ariane_axi_soc::mem_src`;
the numbers with four cores):

| Source | Master |
|---|---|
| 0-3 | the cores (ports 0-3 of the coherence unit) |
| 4 | the accelerator socket's DMA (coherence-unit port 4, `ariane_soc::CcuAccelPort`) |
| 5 | the Xilinx Ethernet's AXI DMA (coherence-unit port 5, `CcuEthPort`) |
| 6 | debug module |
| 7, 8 | cluster port, RoT (idle) |
| 9, 10 | uDMA TX, uDMA RX |
| 11, 12 | IOMMU completion port (iDMA), IOMMU data structures |
| 13, 14 | IOPMP initiator (idle), APMU master (does not reach DRAM) |

The cores' and the two DMA masters' numbers are the coherence unit's source port, which travels in the AXI user field
(`user[QosUserLsb-1:0]`, `hardware/docs/qos.md`). The other masters get `NumCcuPorts + p - 1` for crossbar port `p`
(until the Ethernet DMA had a coherence-unit port of its own, source 4 was both DMAs and every number from the debug
module's on was one lower). A response counts for the source of its request. A write-back the coherence unit issues
for snooped dirty data counts for the core that held the data, an LLC eviction for the request whose miss caused it,
and LLC flushes for source 0. The numbers follow the package when masters are added; the simulation checks that
`NumMemSrcs` fits the 4-bit source field: the 15 codes of four cores do, the 19 of eight cores do not, so an
eight-core simulation stops at time 0 until the field is widened. Examples: `0x9F4F1F` counts the socket DMA's read
requests, `0x9F5F1F` the Ethernet DMA's, `0x9F001F` every read request on port 9 (`software/quad_boot/pmu_defines.h`;
`software/soc_tests/t_srcid` checks them).

> **Implementation note.** The AXI4-Lite reads/writes are serviced by AlSaqr's
> `axi_lite_regs` IP, which expects a *contiguous* byte array, whereas the counters are
> paged at 4 KiB boundaries. `pmu_top.sv` bridges the two: a register at address
> `0x104X_Y00Z` maps onto the contiguous space at byte `XYZ` (a simple bit-shift), using a
> `PadB_NumBytes` padding that depends on the APMU base address.

## Simulation

Unit testbenches are under [`test/`](./test) (`tb_pmu.sv`, `tb_pmu_spm.sv`, `tb_pmu_pkg.sv`,
`tb_axi_lite_regs.sv`); compile/run scripts are in [`scripts/`](./scripts)
(`compile_vsim.sh`, `run_vsim.sh`). In the full SoC the APMU is instantiated in
`hardware/host/host_domain.sv`.

## License

Released under the **Solderpad Hardware License v0.51** (treatable, at the licensee's
option, as Apache-2.0). See [`LICENSE`](./LICENSE).
