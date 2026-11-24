# CSAT: documentation for agents

CSAT describes the AlSaqr SoC in this repository in layers, from the general to the exact:

1. `csat/system.md`: what the SoC is, its parts and how they connect.
2. `csat/blocks/<name>.md`: what one part does and how it works.
3. The alsaqr-mcp tools: exact facts, simulation, builds and the board.
4. The source files themselves.

## Reading order

- Always read `system.md` first.
- Follow a `Docs:` line only when the task touches that part.
- Get exact facts (addresses, parameters, signal and module names, struct layouts) from the alsaqr-mcp tools,
  especially `soc_lookup`, never from memory.
- Open source files when you modify them.

## Tools (~/alsaqr-mcp, MCP server and CLI)

- **Navigation and software:** `soc_lookup` (addresses, windows, modules, structs), `soc_bootflow` (how the
  simulation starts each core), `sw_build`.
- **Simulation:** `sim_run`, `sim_status`, `sim_uart`, `sim_kill`, `sim_session` (probe and force signals),
  `sim_stall_trace`.
- **RTL editing:** `rtl_changes`, `rtl_recompile`.
- **Validation:** `sim_regress` (the SoC test suite in simulation).
- **Accelerators:** `accel_add`, `accel_list`, `accel_unit_test`, `accel_soc_test`, `accel_remove`.
- **FPGA:** `fpga_build`, `fpga_status`.
- **Board:** `board_program`, `board_run`, `board_regress`, `board_stop`.
- **Linux:** `linux_boot`, `linux_status`, `linux_cmd`, `linux_copy`.

`python3 -m alsaqr_mcp list` prints every tool's schema.

## Keeping the docs current

The rules are in `~/mafsa/docs/system-level.md`. For every change, ask its questions: does it change which parts
exist, what a part is or its configuration, how the parts connect, what software runs or where the SoC runs, or
which build knobs change the SoC's contents? If yes, update `system.md` in the same commit as the change. Block docs
describe each block as it is, not how it changed.
