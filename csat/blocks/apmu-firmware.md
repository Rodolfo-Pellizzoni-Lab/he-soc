# APMU firmware

Programs for the APMU's processing element (PE): a 32-bit Ibex that runs from the APMU's instruction scratchpad
(ISPM) with its data in the data scratchpad (DSPM), and reads, writes and waits on the APMU counters with custom
instructions. This doc covers how to write, compile, load and start such a program. The hardware is in `apmu.md`.

## How it works

- **Machine.** RV32IM with Zicsr (`mcycle` works), no interrupts, no PMP, no caches. Instructions come only from the
  ISPM (8 KiB). Loads and stores reach the DSPM (128 KiB), the APMU's own registers (counters, Event Sel, Event
  Info, Initial Budget, timer, Period) and the cores' EVU and token-bucket registers. Nothing else in the SoC is
  reachable from the PE.
- **Counter instructions** (encoded in the LOAD-FP major opcode, which the PE has no other use for;
  `software/inc/pmu/pmu_hw_desc.h`): `cnt_rd` (read a counter), `cnt_rds` (read its snapshot), `cnt_wr` (write it),
  `cnt_snap` (copy every counter of a mask into the snapshot registers in one cycle), `cnt_wfp` (stall until a
  counter of the mask is pending, return which, clear their pending flags), `cnt_wfo` (stall until one overflows).
  GCC emits them through `.insn`; the APMU LLVM knows them by name. The snapshot registers are reachable only from
  the PE.
- **Event loop.** Without interrupts, a policy waits with `cnt_wfp` / `cnt_wfo` or polls `mcycle`. A Period wrap
  marks every counter pending, so `cnt_wfp` doubles as a periodic tick. To act on a core, firmware writes its token
  bucket registers or overflows a counter whose interrupt the core takes.
- **Start and stop.** The Status register's stall bit holds the PE (set at reset). Clearing it starts the PE at the
  Boot Addr register (reset value: the ISPM base; Ibex uses the address with its low 8 bits cleared). Setting it
  cancels a pending wait; clearing it again restarts the PE at Boot Addr, not where it stopped.
- **Image.** `objcopy` turns the ELF into `text_section.bin` (`.text`, for the ISPM) and `data_rodata_bss.bin`
  (`.data`, `.rodata`, `.bss`, for the DSPM), each loaded where the linker script placed it. Host and PE talk
  through DSPM words whose layout each program defines.

### Two kinds of firmware

- **Bare firmware** (he-soc `software/*/pmu_firmware/`): `crt0.s` (clear registers and `.bss`, set the stack, a trap
  handler that spins, call `main`, spin after it returns), `linker.ld` (ISPM base; data at a fixed offset into the
  DSPM, below which the host's mailbox words live), `main.c`, a Makefile with `all` and `generate-bin-files`. Small
  programs are also written as assembly (`soc_tests/t_storm/pe_fw.S`) or as instruction words in the host program
  (`soc_tests/t_evu`).
- **apmu-os** (external repository `maskedarray/apmu-os`): a small OS for the PE. A base component owns the event
  loop and installs or removes components at run time into dynamic ISPM and DSPM regions; each component registers a
  counter bitmask with an event handler and a request handler. The host sends requests through a request queue and
  reads answers from a response queue in the DSPM, and rings counter 0 (writing its pending bit) as a doorbell. The
  DSPM also holds a ready word, an exports table, the last trap, and a `printf` buffer (`debug_printf.h`). A trap
  restarts apmu-os cold. The host-side layout is `linux/apmu/apmu_abi.h` in alsaqr-software, kept identical to
  apmu-os's copy. apmu-os links its data at the DSPM base.

## Configuration

- Bare firmware: `-march=rv32im_zicsr -mabi=ilp32 -mcmodel=medlow -ffreestanding -nostdlib -O2`, compiled with an
  rv64 GCC. `token_bucket_regs` and `pmu_snap` use the `RISCV_PREFIX` their parent passes down
  (`software/common.mk`), `pmu_evu_bench` and `pmu_evu_simple_sim` default it to `/opt/riscv64/bin`, `pmu_test2`
  calls `riscv64-unknown-elf-gcc` from `PATH`; these add `_zicsr` when the compiler takes it. `pmu_cntr_test` names
  `/opt/riscv64/bin` and builds with `-march=rv32im`. Firmware that loops over cores (`token_bucket_regs`) takes
  `-DSOC_NUM_CORES` from the parent through `FW_DEFS`.
- alsaqr-software ships `toolchain/rv32` (`riscv32-unknown-elf-gcc` 15.1.0) and `toolchain/shim`
  (`riscv-none-elf-gcc`, `-objcopy`, `-objdump`, the names its firmware Makefiles use); `source ./source.sh` puts
  both on `PATH`.
- apmu-os needs the APMU LLVM (clang 18 with the counter instructions) and riscv32 newlib-nano; its `env.sh` sets
  `LLVM_BIN`, `RISCV_SYSROOT`, `NEWLIB_BUILD`, `LIBGCC_A` (`QUICKSTART-APMUOS.md`).
- Addresses and sizes for firmware and loaders: `software/inc/pmu/pmu_defines.h` (`ISPM_BASE_ADDR`,
  `DSPM_BASE_ADDR`, `ISPM_SIZE`, `DSPM_SIZE`, `PMC_STATUS_ADDR`, `PMC_BOOT_ADDR`); `soc_lookup` (alsaqr-mcp) returns
  the ISPM and DSPM windows.

## Using it

**Compile.**
- he-soc program with embedded firmware: `make build` in its directory (e.g. `software/token_bucket_regs`) builds
  `pmu_firmware` (its `all` target, which includes `generate-bin-files`), then turns the two binaries into objects
  with `pmu_text_wrapper.S` / `pmu_data_wrapper.S` (`.incbin`, symbols `_binary_text_section_bin_start` ...) and
  links them into the CVA6 ELF. alsaqr-mcp `sw_build` does the same.
- `soc_tests/t_storm`: `make pe_fw.h` assembles `pe_fw.S` and writes its words into `pe_fw.h`.
- alsaqr-software: `./scripts/build.sh tests/pmu_mempol_synth pmu_bench` (firmware plus host program).
- apmu-os: `make generate-bin-files` with `env.sh` sourced; output in `build/`.

**Load and start from a bare-metal CVA6 program.** Set the stall bit; write the text words to the ISPM and the
data words to the address the linker script gives, each with an aligned 32-bit store; write Boot Addr; clear the
stall bit; then poll the agreed DSPM status word. `software/token_bucket_regs/tb_regs.c` and
`soc_tests/t_storm/t_storm.c` are complete examples.

**Load and start from Linux.** `apmuctl` (root, `/dev/mem`):
`apmuctl load TEXT.bin [DATA.bin [DATA_ADDR]]` halts the PE, writes and verifies both images (data at the DSPM base
by default); `apmuctl run` releases the stall; also `halt`, `reset`, `info`, `counters`, `ispm`/`dspm OFF N`,
`peek`, `poke`, `watch`, and `example_bubble` (loads and runs a known program).
Programs can link `linux/apmu/apmu_mmio.c` for the same operations and for apmu-os requests
(`apmu_comp_request`, `apmu_comp_wait`). `soc_tests/t_storm/linux` loads `pe_fw.h` from a Linux program.

## Verification

`apmuctl example_bubble` on the board (alsaqr-mcp `linux_cmd`). Programs that run PE firmware and check it, through
`sim_run` or `board_run`: `soc_tests/t_evu`, `soc_tests/t_storm`, `pmu_cntr_test` (exit code = failed checks),
`software/token_bucket_regs` (prints PASSED or FAILED, exits 0).
Other programs with PE firmware: `pmu_snap` (snapshots), `pmu_test2` (bubble sort on CVA6 and PE),
`pmu_evu_bench`.

## Properties

- A load or store outside the PE's windows is never granted, so the PE hangs there instead of trapping.
- The bare `crt0.s` trap handler spins; nothing reports a trap to the host.
- The cores write the scratchpads with aligned 32-bit stores; a sub-word store lands in a lane the PE does not read,
  so a byte-wise `memcpy` corrupts an image.
- `.text` must fit the ISPM; `apmu_load_raw` refuses a larger image.
- `tests/pmu_mempol_synth` and `pmu_sdvb` in alsaqr-software carry their own `pmu_defines.h`, `pmu_hw_desc.h` and
  `linker.ld`, whose DSPM base differs from `software/inc/pmu/pmu_defines.h`.

## Code

- he-soc `software/inc/pmu/`: `pmu_defines.h`, `pmu_hw_desc.h`, `evu_defines.h`, `tb_defines.h`.
- he-soc `software/{token_bucket_regs,pmu_snap,pmu_cntr_test,pmu_test2,pmu_evu_bench,pmu_evu_simple_sim}/pmu_firmware/`:
  bare firmware with host programs.
- he-soc `software/soc_tests/t_storm/pe_fw.S`, `t_evu/t_evu.c`: small PE programs.
- alsaqr-software `linux/apmu/`: `apmuctl`, `apmu_mmio`, `apmu_regs.h`, `apmu_abi.h`.
- alsaqr-software `tests/pmu_mempol_synth`, `pmu_sdvb`: software bandwidth regulation on the PE (a token-bucket
  policer that pauses core 0).
- `hardware/ip_list/ibex_pmu/`: the PE's RTL.

## Reference

- alsaqr-software `QUICKSTART-APMUOS.md`: apmu-os hello world, the APMU LLVM (`maskedarray/llvm-project`, branch
  `rv-apmu-sw`), `apmuctl`, `printf` read-back.
- alsaqr-software `README.md`: bundle layout and the PMU tests.
