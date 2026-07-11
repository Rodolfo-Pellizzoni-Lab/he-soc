# slowdown — memory-bandwidth regulator IP

AXI memory-bandwidth regulator ("slowdown") inserted in the host domain between the
SPU (post-LLC event monitor) and main memory:

```
LLC (i_axi_llc) → axi_spu_top (i_spu_llc_mem) → slowdown_mem_top (i_slowdown) → mem_axi_bus → DDR
```

## Files (`src/`)
- `slowdown_mem_top.sv`     — top; wraps the R/B latency injectors + throughput regulator
- `latency_r_chan.sv`       — read-channel latency injector
- `latency_b_chan.sv`       — write-response-channel latency injector
- `throughput_regulator.sv` — bandwidth/throughput limiter
- `fifo_sync.sv`, `countdown_timer.sv`, `data_write_fifo.sv` — helper building blocks

## Provenance
Ported from branch `esarkar/quad_core/slowdown/opentitan_excluded`, where these lived as
loose files under `hardware/host/`. Moved here under `ip_list/slowdown/src/` and registered
in `hardware/Bender.yml` (before `host/host_domain.sv`). Instantiated in
`hardware/host/host_domain.sv` as `i_slowdown`.

> NOTE: brought in for structural integration; functional debug is a follow-up step.
> `Throughput_COUNTER_WIDTH` is a `localparam` inside `slowdown_mem_top` (do not override it).
