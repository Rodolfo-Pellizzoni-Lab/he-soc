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
| Tag policy of slot `s`: `0x103F_0100 + 8*s` | `+0` TAG_POLICY (RW): bit 31 FORCE, `[11:0]` the user field to stamp on the slot's DMA while forced; `+4` LAST_USER (R): the user field of the slot's most recent DMA request, after the policy (see "QoS tags" below) |
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
  input  logic [15:0] reg_user_i,   // who is accessing: the SoC user field (source port, RCID, MCID, AT)
  output logic        reg_ack_o,    // exactly one pulse per strobe, same cycle or later
  output logic [31:0] reg_rdata_o,  // valid in the ack cycle
  // memory port (64-bit, physical byte addresses, 8-byte aligned)
  output logic        mem_req_o,    // hold it and the fields below stable until mem_gnt_i
  input  logic        mem_gnt_i,
  output logic        mem_we_o,
  output logic [63:0] mem_addr_o,
  output logic [63:0] mem_wdata_o,
  output logic [7:0]  mem_strb_o,
  output logic [15:0] mem_user_o,   // the QoS tag this request carries (same layout; the port bits are the CCU's)
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

## Memory, caches and DMA

The socket's memory port is a port of the coherence unit (`host/cva6_synth_wrap.sv`, CCU port `NumCVA6` = 4, next
to the four cores): every read is an ACE ReadOnce and every write a WriteUnique in the shareable domain, the same
transactions the cores use for their own uncached accesses. A read therefore returns the data a core still holds
dirty in its write-back L1, and a write invalidates the cores' copies (after a write-back when one was dirty) before
it reaches the LLC or the DRAM. The port never caches anything and answers every snoop with "no data". Buffers
shared with an accelerator can live anywhere (DRAM, the LLC window, the on-chip SRAM) and need **no cache
maintenance on either side**. Software still orders its own writes before the start (`fence` before the START
register write: the cores' uncached stores are posted) and reads the result after DONE / the interrupt.

Rules for the DMA master, from the CCU's snoop-data path: single-beat 64-bit requests inside one 16-byte line
(len 0, size 3), AXI ID 0. `axi_from_mem` in `accel_socket.sv` issues exactly that for the slots' memory ports.

What the port costs (`software/soc_tests/t_dma`, slot 0 `example`, one word in flight, cycles per 64-bit word,
read + write): the CCU handles one snooped transaction at a time and each one is a snoop round trip through the
four L1s, so a word takes 45-87 cycles in simulation and 90-128 on the VCU118 (real DDR latency inside each round
trip) instead of 15-28 through the plain crossbar path it replaced. The `t_dma` test prints the numbers for the
design it runs on, and whether the source and destination hazards came out coherent; on the VCU118 bitstream
with this port it reports both coherent and the soc suite passes 9/9.

Before this port the socket master entered the host xbar directly, after the coherence unit, and `t_dma` measured
what that means on this SoC: a core's writes stay dirty in its 16 KB L1 (the device read stale data), the device's
writes do not invalidate the core's copies (the core read stale data), a plain `fence` does nothing to the data
cache (CVA6 `controller.sv`: the write-back cache is coherent, so FENCE skips the flush), and only `fence.i` writes
back and invalidates the whole L1 (~2000 cycles with 32 dirty lines, ~300 clean). On such a design the recipe is
`fence.i` before START and after DONE, or buffers in the uncached SRAM (`ACCEL_BUF`).

## QoS tags: I/O on behalf of an RCID

The SoC tags every core request with the hart's QoS IDs (Ssqosid `srmcfg`: RCID, MCID, plus the access type AT
and the source port, in the AXI user field, `hardware/docs/qos.md`), and the LLC's CBQRI capacity controller
partitions its ways by (RCID, AT). Work that a hart hands to an accelerator leaves that accounting unless the
accelerator's DMA is tagged too. The socket supports both ways of tagging I/O traffic, and the policy is selectable:

- **Who sent the request.** Every register strobe carries the requester's user field on `reg_user_i`. The template
  latches it when START is written (`TAG` register, `0x28`, read-only) and presents it on `mem_user_o` with every
  DMA request of that run: **the accelerator's traffic is charged to the hart that started the work**, including its
  source port, so software can read back which hart that was.
- **The socket decides.** `TAG_POLICY` of the slot (`0x103F_0100 + 8*s`, bit 31 FORCE, `[11:0]` the tag) makes the
  socket stamp an OS-chosen tag on the slot's DMA instead of whatever the accelerator presents: the device as its
  own QoS principal, the way an IOMMU's device context assigns IDs to a device. The accelerator still sees the
  requester on `reg_user_i`; it just cannot choose the tag. `LAST_USER` (`+4`) reads back what the last request
  carried, so software can verify either policy from the CPU.

The socket is the trusted tagging point: an accelerator can only ask for a tag, and the policy register, which lives
in the socket's own window, can override it. The CCU writes its port index into the low `QosUserLsb` bits of the
user field, so the socket clears them; `LAST_USER` therefore shows the tag with source port 0 while `TAG` inside
the accelerator keeps the requester's port.

An accelerator must keep `mem_user_o` stable with the rest of the request until `mem_gnt_i` (the unit testbench
checks it, and `set_user()` sets the user field its register driver presents; `last_mem_user` holds the tag of the
most recent granted request). `software/soc_tests/t_iotag` verifies the mechanism in the SoC (27 checks): TAG and
LAST_USER against `srmcfg` for runs started by core 0 (`0x0C8` = RCID 9, MCID 1) and by core 1 (`0x5B1` = port 1,
RCID 6, MCID 11), the forced policy (`LAST_USER 0x160` = RCID 12, MCID 2 while TAG keeps the requester), and that
the tag reaches the LLC: with the accelerator's DMA as the CBQRI aggressor, 8 victim lines of RCID 1 (ways 0-7)
are read again with 0 LLC misses when the DMA inherits RCID 2 (ways 8-15) and with 8 misses when the policy forces
it into RCID 1. In simulation the QoS scoreboard prints the user fields the socket presented at the LLC
(`[QOS] llc_in socket user=0x14 src=4 rcid=2 ...: 80 requests`).

On the VCU118 (bitstream `iotag`, 50 MHz, timing gate OK) `t_iotag` passes the same 27 checks with the same values
(TAG/LAST_USER `0xc8`, forced `0x160`, core 1 `0x5b1`, victims 0 misses inherited vs 8 forced). Under Linux the
registers are reachable with `devmem`: after `taskset 0x2 socket_dma pool` the slot's `TAG` reads `0x1` (hart 1 wrote
START; Linux leaves `srmcfg` at 0, so RCID = MCID = 0) and `LAST_USER` `0x0`; writing `0x80000160` to the slot's
`TAG_POLICY` makes the next run's `LAST_USER` read `0x160` while `TAG` stays `0x1`, and clearing the policy returns
it to `0x0`. Charging Linux processes to RCIDs needs the kernel to write `srmcfg` on context switch (not in the 5.10
kernel of the bundle); until then the FORCE policy is the way to give a device an RCID from Linux.

## Linux

The socket is exposed to Linux by the device tree (alsaqr-software `linux/cva6-sdk/alsaqr-socket.dts`) and the
kernel configuration (`configs/linux64_defconfig`, both rebuilt with `linux/cva6-sdk`):

- one `generic-uio` node for the whole window (`accel-socket@10000000`, 4 MB, PLIC interrupt 9) bound by
  `uio_pdrv_genirq` (`CONFIG_UIO_PDRV_GENIRQ=y`, `uio_pdrv_genirq.of_id=generic-uio` in bootargs): a user-space
  driver maps the registers through `/dev/uio0` (map 0) and waits for the interrupt with `read()`;
- a 16 MB `shared-dma-pool` at 0x9F00_0000 (`reserved-memory`, `no-map`): physically contiguous buffers at a known
  address for user-space drivers (`/dev/mem`), and the coherent pool of a kernel driver whose node names it in
  `memory-region`;
- `CONFIG_PROC_PAGE_MONITOR=y`, so a process can hand the device the physical address of its own locked pages
  (`/proc/self/pagemap`), which is what a kernel driver's streaming mapping does;
- `CONFIG_VIRTIO_MMIO/BLK/CONSOLE/NET/INPUT=y` for emulated I/O devices plugged into a slot: a virtio-mmio device
  (registers in the slot's 64 KB window, DMA through the socket's port, PLIC 9) is a `virtio,mmio` node with the
  slot's address, and the stock drivers see a disk, a console, a NIC.

`software/linux/socket_dma` (static binary, shipped in the rootfs as `/usr/bin/socket_dma`) drives slot 0 from
user space in the three ways a driver can: buffers in the pool (`/dev/mem`), buffers in the process's own cached
memory (`pagemap`), registers through `/dev/uio0` and completion by the interrupt. It checks every word with no
cache maintenance and prints `SOCKET_DMA <mode> ok|FAIL ...` per mode. The OpenSBI payload of the bundle takes the
device tree the loader passes in `a1` (the boot ROM leaves its own built-in DTB there, so the loader must set the
register: alsaqr-mcp `linux_boot` does).

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
