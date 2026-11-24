# APMU

The APMU (Advanced Performance Monitoring Unit) is the SoC's own central performance monitor. Event sources in the
cores (EVUs) and on the interconnect (SPUs) feed one bank of programmable counters, and a small Ibex core inside the
APMU, the processing element (PE), runs monitoring and regulation policies off the application cores. Per-core token
buckets, configured by the cores or the PE, throttle each core's memory traffic.

## How it works

- **Event ports.** Each source sends an event word (event ID, 17-bit info, source ID; `pmu_pkg::pmu_event_t`) to
  one port. With *N* cores there are 2*N*+2 ports: the EVUs, the SPUs on the cores' ports to the coherence unit, the
  SPU on the LLC memory port, the SPU on the accelerator socket's DMA (`ariane_soc::Apmu*Idx`). `pmu_port_wrap`
  matches every port against every counter's select.
- **EVU** (`perf_counters_evu` in CVA6). Four slots per core, each set to one event ID (cache/TLB misses, loads,
  stores, branches, instruction classes, bubbles, PC-milestone hits, `scontext`/`hcontext` changes). The event field
  is a bitmap of the slots that fired; the source is the hart's virtualization mode and privilege; the info is the
  hit PC milestone (four per core) or the context CSR's value after a change. Registers: `perfc_evu_cfg_regs`.
- **SPU** (`axi_spu_top`, `ace_spu_top`). A transparent snooper emitting read/write request and response events for
  DRAM addresses; requests carry their size, responses their latency in SoC cycles. The memory-port SPU's source
  names the master behind the traffic (`ariane_axi_soc::mem_src`).
- **Counter bank** (`pmu_counter`, 32 instances). Each counter has four registers: Counter, Event Sel (value and
  mask for port, source, event), Event Info (opcode, info slice, compare limits, info enable, overflow-interrupt
  enable), Initial Budget. Without info a counter adds the number of matching ports per cycle; with info it applies
  one of 19 opcodes (add, keep max/min, increment or add on a compare or range). The counter word holds an overflow
  flag and a pending flag; every count and every Period reload sets pending.
- **Timer and Period.** A 64-bit timer counts to the Period register; at each wrap every counter is reloaded from
  its Initial Budget and marked pending: the base for MemGuard-style per-period budgets.
- **Processing element** (`pmu_core`). An Ibex (`ip_list/ibex_pmu`, RV32IMC, no PMP, interrupt inputs tied off) with an
  instruction scratchpad (ISPM) and a data scratchpad (DSPM). Custom instructions read, write, snapshot and wait on
  counters (`apmu_ibex_pkg::pmc_op_e`). Its data port reaches the DSPM, the APMU registers and, through the APMU's
  AXI master, the EVU and token-bucket registers. The Status register's stall bit holds it; Boot Addr sets its
  start. Firmware: `apmu-firmware.md`.
- **Interrupts.** One line per counter to the PLIC (`ariane_peripherals.sv`), following the overflow flag while the
  counter's overflow-interrupt enable is set. The boot ROM parks harts 2 and up until their counter's overflow
  reaches their S-mode context.
- **Token buckets** (`ip_list/token_bucket`). One per core, between the core and its SPU. A bucket gains a set number
  of tokens per interval up to a limit; each AR and AW costs a set number and waits while unpaid. Registers:
  `token_bucket_cfg_regs`, one block for all cores.

Registers and scratchpads share one AXI4-Lite window of `axi_lite_subsystem`.

## Configuration

- `NUM_CVA6` (define, default 4): EVU, core-SPU and bucket count; 2*N*+2 ports. Above four cores the Event Sel port
  and source fields grow from 4 to 5 bits (`pmu_pkg::PORT_ID_BITS`, `SOURCE_ID_BITS`), enough for 14 cores. Software
  needs the matching `-DSOC_NUM_CORES` (`software/common.mk` takes `SOC_NUM_CORES` or `NUM_CVA6`).
- `APMU_IP`: a `` `define `` written into `host_domain.sv`, `cva6_subsystem.sv`, `cva6_synth_wrap.sv`,
  `axi_lite_subsystem.sv`, `ariane_peripherals.sv`, not a make variable. Without it: no counters, SPUs or EVU path;
  the token buckets stay.
- `APMU_IOPMP` (`host_domain.sv`): the APMU's AXI master passes through the IOPMP.
- `pmu_top` parameters in `host_domain.sv`: 32 counters, 8 KiB ISPM, 128 KiB DSPM, the PE's window onto the EVU and
  token-bucket pages. SPU `CAM_DEPTH` is set per instance.

## Using it

- **Cores:** program Event Sel, Event Info, Initial Budget, Period; read or write counters; hold or release the PE.
  Macros: `software/inc/pmu/pmu_defines.h` (`EVSEL_*`, `APMU_PORT_*`, `APMU_SRC_*`, `MEM_SEL`, `EVINFO_*`),
  `evu_defines.h`, `tb_defines.h`; soc_tests include `software/quad_boot/pmu_defines.h`. `soc_lookup` (alsaqr-mcp)
  returns windows, register layouts (`pmu_pkg::event_sel_cfg_t`, `event_info_cfg_t`) and PLIC source numbers.
- **Waking a parked core:** enable the counter's PLIC source and its overflow-interrupt enable, then overflow it.
  `soc_wake_all()` (`software/soc_tests/include/soc_test.h`) wakes harts 2 and up this way.
- **Linux:** no kernel driver; `apmuctl` (alsaqr-software `linux/apmu`, in the root filesystem) drives the APMU
  through `/dev/mem`.

## Verification

- `software/soc_tests` (alsaqr-mcp `sim_run`, `sim_regress tests=[...]`, `board_run`): `t_evu` (EVU registers,
  port/slot routing), `t_srcid` (memory-port sources), `t_spulat` (SPU latencies), `t_storm` (every source at once
  with PE sampling; `t_storm/linux` under Linux). `t_smp` and `quad_boot` (`soc` suite) wake cores through counter
  interrupts.
- `software/token_bucket_regs`, `token_bucket_throttle`, `pmu_cntr_test`, `pmu_snap`.
- Unit benches: `hardware/ip_list/apmu/test`, `hardware/ip_list/token_bucket/tb`, `hardware/xsim/tests/run_spu_b.sh`.

## Properties

- An event value of 0 turns a counter off; no select counts every event of a port.
- A counter with info enabled takes one port's info per cycle, the highest-numbered match.
- A select encoded for another core count matches another port or none, without any error.
- With its overflow-interrupt enable clear, a counter's interrupt line holds its last value.
- The timer runs only while Period is non-zero; each wrap reloads all 32 counters.
- A CPU write to a counter waits for a cycle in which the counter is not updating.
- A PE access outside its windows is never granted: the PE stalls, it does not trap.
- The scratchpads index their SRAM by byte address; the cores fill them with aligned 32-bit stores.
- The core-port SPUs' source is one AXI ID bit; the port identifies the core.
- A token bucket gates only AR and AW, adds no latency, and goes into debt by at most one cost.

## Code

- `hardware/ip_list/apmu/src/`: `pmu_top`, `pmu_counter`, `pmu_port(_wrap)`, `pmu_core`, scratchpads, `pmu_pkg`.
- `hardware/ip_list/ibex_pmu/`: the PE's Ibex with the counter instructions.
- `hardware/ip_list/spu/src/`: SPU tops and channel trackers.
- `hardware/ip_list/token_bucket/src/`: bucket, register block, package.
- `hardware/ip_list/cva6/core/perf_counters_evu.sv`: the EVU; `cva6.sv` builds its event word.
- `hardware/host/perfc_evu_cfg_regs.sv`: EVU registers.
- `hardware/host/cva6_synth_wrap.sv`: buckets, core SPUs, EVU and bucket register blocks.
- `hardware/host/host_domain.sv`: `pmu_top`, memory-port SPU; `cva6_subsystem.sv`: socket SPU.
- `hardware/include/ariane_soc_pkg.sv`: port indexes, source codes, EVU and bucket windows.
- `software/inc/pmu/`, `software/quad_boot/pmu_defines.h`: software headers.

## Reference

- `hardware/ip_list/apmu/README.md`: register map, select examples, source tables.
- `hardware/ip_list/spu/README.md`: SPU instances and event fields.
- `hardware/docs/cores.md`: the APMU with more than four cores.
