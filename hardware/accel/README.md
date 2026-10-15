# Accelerator socket

Custom accelerators plug into the SoC in place of the PULP cluster (the SoC is built with `EXCLUDE_CLUSTER`).
`accel_socket.sv` is instantiated in `host/al_saqr.sv`:

```
CPU --AXI4, cluster window 0x1000_0000-0x103F_FFFF--> accel_socket --register port--> slot 0..7
slot 0..7 --memory port--> round-robin --> axi_from_mem --AXI4--> host xbar (cluster master port) --> DRAM, SRAM, ...
slot 0..7 --irq_o--> OR --> PLIC source 8 = interrupt ID 9 (the cluster end-of-computation line)
```

| | |
|---|---|
| Registers of slot `s` | `0x1000_0000 + s * 0x1_0000`, 64 KB, 32-bit registers |
| Empty slot / past slot 7 | DECERR, read data `0xdeadbeef` (CVA6 takes no exception on AXI errors: software just sees the data) |
| QoS probe `0x103F_0000` (8 bytes) | read `+0x0`: AXI user field of that read; `+0x4`: user field of the last write there (QoS tag, see `hardware/docs/qos.md`) |
| Accelerator does not acknowledge in 4096 cycles | SLVERR, read data `0xdeadbeef` (the simulation does not hang) |
| 64-bit CPU access | two register accesses, low word first |
| Atomics (AMO) to the window | refused, SLVERR |
| Interrupt | PLIC ID 9, level, shared by all slots |
| Clock | SoC clock (`s_soc_clk`), same domain as the host xbar |

## Port contract (every accelerator has exactly these ports)

```systemverilog
module <name> (
  input  logic clk_i, rst_ni,
  // register port
  input  logic        reg_req_i,    // one-cycle strobe
  input  logic        reg_we_i,
  input  logic [15:0] reg_addr_i,   // byte offset in the 64 KB window, word aligned
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ack_o,    // exactly one pulse per strobe, same cycle or later
  output logic [31:0] reg_rdata_o,  // valid in the ack cycle
  // memory port (64-bit, physical byte addresses, 8-byte aligned)
  output logic        mem_req_o,    // hold it and the fields below stable until mem_gnt_i
  input  logic        mem_gnt_i,
  output logic        mem_we_o,
  output logic [63:0] mem_addr_o,
  output logic [63:0] mem_wdata_o,
  output logic [7:0]  mem_strb_o,
  input  logic        mem_rvalid_i, // one pulse per granted request (reads AND writes), in request order
  input  logic [63:0] mem_rdata_i,  // read data, valid with mem_rvalid_i
  input  logic        mem_err_i,    // bus error, valid with mem_rvalid_i
  output logic        irq_o         // level
);
```

Rules: `mem_req_o` must not depend combinationally on `mem_gnt_i`; up to 4 requests may be outstanding across
all slots. Registers that start work should act on the strobe (`reg_req_i && reg_we_i`), never on a level.
In always_comb blocks, assign every output once (case/if-else chains or continuous assigns): xsim propagates the
transient value of "default, then override" writes through ports, which can loop forever at one time step
(see `hardware/xsim/README.md`).

## Memory and caches

The accelerator's memory traffic enters the host xbar after the coherence unit: it is **not coherent with the
cores' data caches**, and all of DRAM (0x8000_0000-0x9FFF_FFFF) is cacheable. Put buffers shared with the
accelerator in the on-chip SRAM (0x1C00_0000, 32 KB, uncached; `ACCEL_BUF` in `software/accel/include/accel.h`).

## Files

```
accel_socket.sv        AXI slave FSM, memory arbiter, axi_from_mem, irq OR
accel_slots.sv         GENERATED from slots.json (one instance per occupied slot)
slots.json             registry: slot -> accelerator
templates/             RTL / unit-test / C templates used by accel_add
tb/accel_tb.sv         generic unit testbench (register driver, stalling memory model, protocol checks)
<name>/<name>.sv       an accelerator (every .sv in the directory is compiled; *_pkg.sv first)
<name>/accel_test.svh  its unit test (body of the testbench's initial block)
../../software/accel/<name>/<name>.c   its SoC test (prints TEST PASS / FAIL, exit code = failed checks)
```

The `Bender.yml` block between `# accel: begin` and `# accel: end` is generated too, so full builds
(`hardware/xsim/build.sh`, FPGA flow) include the accelerators.

## Workflow (alsaqr-mcp tools)

```
accel_add(name)          scaffold from the template (a working DMA-style example), register, wire in
accel_unit_test(name)    unit testbench alone, ~5 s
accel_soc_test(name)     compile changed sources, build + run the C test on the whole SoC, ~6-8 min
sim_regress(suite=all)   SoC validation suite + every accelerator's C test, in parallel
```
