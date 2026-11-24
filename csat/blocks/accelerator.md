# Accelerator socket

The accelerator socket holds custom accelerators in the place of the PULP cluster (`al_saqr.sv` always defines
`EXCLUDE_CLUSTER`). Its eight slots each get a register window, a share of one 64-bit DMA master that is coherent with
the cores' L1 caches, and a shared interrupt. The socket chooses the QoS tag of every DMA request.

## How it works

`accel_socket.sv`, instantiated in `host/al_saqr.sv` in the cluster window, has three parts.

**Register side.** An AXI slave FSM turns every 32-bit word of an access into one register strobe on the addressed
slot (a 64-bit access: two strobes, low word first; bursts beat by beat; atomics: SLVERR). An empty slot or an address
past the last slot answers DECERR with a fixed pattern as read data; a slot that does not acknowledge within
`TimeoutCycles` gets SLVERR. CVA6 takes no exception on AXI errors, so software sees the data. Each strobe hands the
slot `reg_user_i`, the AXI user field of the access (source port, RCID, MCID, AT).

**Memory side.**
1. A round-robin arbiter over the slots' memory ports feeds `axi_from_mem`, which issues single-beat 64-bit AXI
   requests with ID 0, at most four open across all slots.
2. R and B responses are buffered, so the socket accepts every response in the cycle it is offered; they return to
   the slots in request order.
3. The master passes the APMU SPU `i_spu_accel`, then its admission gate (QoS block), and enters the coherence unit
   at its own port, `ariane_soc::CcuAccelPort` (`cva6_subsystem.sv`).
4. `cva6_synth_wrap` makes every read an ACE ReadOnce and every write a WriteUnique, so shared buffers need no
   cache maintenance on either side.

**Interrupt.** The OR of all slots' `irq_o` drives PLIC source 8, interrupt ID 9 (the cluster end-of-computation line).

**QoS probe.** A small window returns the AXI user field of the read that reaches it and of the last write to it.

**DMA tag rules** (per request, first match wins):

| | Condition | Tag |
|---|---|---|
| 1 | `TAG_POLICY.FORCE` is set | the slot's default tag |
| 2 | `TAG_POLICY.RANGE_EN` is set and a valid range entry for the slot covers the physical page | the tag of the lowest matching entry |
| 3 | the device tags per job (`QOS_CAP.JOB`, from the parameter `JobTagSlots`) and `DEV_OFF` is clear | the device's `mem_user_o` |
| 4 | none of the above | the slot's default tag |

The socket clears the source-port bits of the tag (the CCU writes them). `LAST_USER` and `LAST_SRC` read back the tag
and the rule of the slot's latest request. The socket is the trusted tagging point: a device can only ask for a tag.

**Accelerators** (`slots.json`). Slot 0: `example`, a template engine (`dst[i] = compute(src[i], ARG)`) with a job
queue. Slot 1: `crc32`, a single-job CRC-32 reader. Both put the user field of the write that started a job (`TAG`)
on that job's DMA. In the job queue a job is a 32-byte descriptor in memory; a write of its address (in 8-byte units)
to `SUBMIT` queues it with that write's tag. Jobs run in order, one at a time; the descriptor read and the completion
record carry the job's tag. A `SUBMIT` to a full queue is dropped (`QSTAT.OVF`, `DROPPED`).

## Configuration

- **Slots:** 8 slots of 64 KB each (`NumSlots`).
- **`SOCK_QOS_RANGES`:** number of address-range entries, 16 by default; 0 removes the table.
- **`ACCEL_JOB_DEPTH`:** queue depth of template accelerators, 4 by default; 0 removes the queue.
- Both knobs are in the `QOS_KNOBS` list of `hardware/Makefile` and are accepted as `fpga_build` env.
- **Tag width:** the default tag is as wide as the SoC user field (`ariane_axi_soc::UserWidth`), which grows by one
  bit above six cores.

## Using it

- **Port contract.** Every accelerator has a register port (a one-cycle `reg_req_i` strobe, exactly one `reg_ack_o`
  pulse per strobe, `reg_user_i`), a memory port (`mem_req_o` and its fields held stable until `mem_gnt_i`, one
  `mem_rvalid_i` per granted request in order, `mem_user_o`) and a level `irq_o`. `mem_req_o` must not depend
  combinationally on `mem_gnt_i`. The header of `hardware/accel/templates/accel_template.sv` states the contract and
  holds the template register map.
- **Adding an accelerator.** alsaqr-mcp `accel_add(name)` creates RTL, unit test and C test from the template,
  registers the slot in `slots.json` and regenerates `accel_slots.sv` and the managed `Bender.yml` block;
  `accel_list`, `accel_remove`.
- **Bare metal.** `software/accel/include/accel.h`: register macros, `ACCEL_USER()`, `accel_range_set()` (writes the
  entry invalid while it changes it) and `accel_submit()` (fences, writes `SUBMIT`, reads `QSTAT` back, so `srmcfg`
  cannot change before the doorbell leaves the core). It holds the window, probe, policy and range addresses;
  `soc_lookup` returns them too.
- **Linux.** alsaqr-software `linux/cva6-sdk/alsaqr-socket.dts` (`alsaqr-socket8.dts` for eight cores) has a
  `generic-uio` node for the whole window (`/dev/uio0`, PLIC interrupt 9) and a 16 MB `shared-dma-pool`.
  `software/linux/socket_dma` drives slot 0 from user space (pool buffers, process pages, UIO interrupt).

## Verification

- `accel_unit_test(name)`: one accelerator alone in `hardware/accel/tb/accel_tb.sv` (stalling memory model,
  port-protocol checks).
- `accel_soc_test(name)` and `sim_regress(suite=accel)`: each accelerator's C test (`software/accel/<name>/`) on the
  whole SoC.
- `hardware/xsim/tests/run_accel_socket.sh` (`tb_accel_socket.sv`): the socket's memory side and tag policy with
  several open requests and out-of-order R and B.
- `software/soc_tests/`: `t_socket` (DECERR past the last slot), `t_dma` (DMA coherence, cycles per word), `t_iotag`
  (inherited and forced tags), `t_part` (LLC way partitioning between accelerator and cores), `t_iojob` (job queue,
  range rules, privilege-associated `SUBMIT`), `t_srcid` and `t_spulat` (APMU view of the DMA). `t_socket`, `t_dma`,
  `t_iotag` and `t_part` are in the `soc` suite of `sim_regress` and `board_regress`; the others run by name.
- The simulation QoS scoreboard (`qos_monitor`, role `dma`, in `al_saqr.sv`) records the tags of the socket's DMA.

## Properties

- The CCU handles one snooped transaction at a time, so each DMA word costs a snoop round trip.
- The DMA port never caches data and answers snoops with no data.
- The SPU on the DMA master does not record the slot.
- A `TAG_POLICY` write applies to requests offered after it; a waiting request keeps its tag.

## Code

- `hardware/accel/accel_socket.sv`: the socket.
- `hardware/accel/accel_slots.sv`: generated from `slots.json`.
- `hardware/accel/example/`, `crc32/`, `templates/`, `tb/accel_tb.sv`: accelerators, `accel_add` templates, unit
  testbench.
- `hardware/host/al_saqr.sv`: instantiation. `hardware/host/cva6_subsystem.sv`: SPU, gate, CCU DMA port.
- `software/accel/`: `accel.h` and the per-accelerator C tests.
- `software/linux/socket_dma/`: Linux user-space driver test.

## Reference

- `hardware/accel/README.md`: register tables and the job descriptor layout.
- `hardware/docs/qos.md`: the device-DMA tagging design.
