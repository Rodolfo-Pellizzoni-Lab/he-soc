# OpenDRAM in the he-soc FPGA build

OpenDRAM is a DDR4 memory controller that takes the place of the memory
controller inside the Xilinx DDR4 MIG. The MIG keeps its PHY, calibration and
AXI front end. Setting `OPENDRAM=1` makes the FPGA build (`hardware/fpga/run.tcl`)
use it; without it the build is unchanged and uses the MIG's own controller.

## What is here

| path | what |
|---|---|
| `rtl/` | OpenDRAM's RTL, the 18 files of `src/opendram/` of the OpenDRAM repository (github.com/Sarkar22/OpenDRAM), branch `vivado-2024.2-fixes`, commit 663ea1e, copied unchanged |
| `patches/` | the changes OpenDRAM needs in two files the MIG generates: `ddr4_0_ddr4_mem_intfc.sv` (instantiates `opendram_mc` in place of the MIG's controller `ddr4_v2_2_24_mc`) and `ddr4_v2_2_mc_ctl.sv` (takes OpenDRAM's per-slot commands `sel_cmd0..3` instead of the MIG's arbiter) |
| `opendram.tcl` | what `run.tcl` runs when `OPENDRAM=1` (below) |

This is the unpipelined OpenDRAM (command scheduler V5) with both refresh fixes
of that branch (its `issues/README.md`):

- the tRFC pad: `rtl/opendram_mc.sv` passes `tRFC + MC_REF_TRFC_PAD` (20) to
  the MIG's refresh logic, so that the first command after a refresh no longer
  goes out while the DRAM is still refreshing;
- fix B: `rtl/request_scheduler/request_scheduler_wrapper.sv` gives a periodic
  read to the lowest open bank even when that bank's queue is full, so that a
  periodic-read request can no longer be lost (which stopped refresh for good).

## How the build uses it

With `OPENDRAM=1`, `run.tcl` does not read the prebuilt
`alsaqr/tcl/ips/ddr/ip/ddr4_0.xci` and sources `opendram.tcl`, which:

1. creates the DDR4 MIG in the project, with the settings of
   `alsaqr/tcl/ips/ddr/run.tcl` except `AUTO_AP_COL_A3`, which is off: OpenDRAM
   keeps its own record of which banks are open, from the PRE and ACT commands
   it issues, and a read or write with auto-precharge would close a bank
   without it knowing;
2. generates it with no out-of-context synthesis, so the MIG's RTL is
   synthesized together with the rest of the design, and locks it, so Vivado
   cannot regenerate the files patched next;
3. checks that the MIG is Vivado 2024.2's (module prefix `ddr4_v2_2_24_`) and
   applies `patches/*.patch` with no fuzz: a patch that does not fit exactly
   stops the build. It then checks that the `ddr4_0_ddr4_mem_intfc.sv` Vivado
   will synthesize is the patched one;
4. puts `rtl/` on the include path. OpenDRAM's files reach synthesis through
   the `` `include `` in the patched `ddr4_0_ddr4_mem_intfc.sv`; they are not
   design sources and are not in `Bender.yml`.

Everything else is the same as in the standard DDR4 build: the SoC and its
clock (`alsaqr/tcl/ips/clk_mngr/run.tcl`: 50 MHz with 4 cores), the clock
crossing to the MIG, the pins and the constraints. The other IPs come from
`make ips` as usual; the prebuilt DDR4 IP is not needed.

The patches are OpenDRAM's (its `patches/`, made for Vivado 2024.2) with two
kinds of change: the `` `include `` lines name the files alone instead of a path
into the OpenDRAM repository, and one context line has `sys_clk_i` instead of
`sys_clk_p`, because he-soc's MIG takes its system clock unbuffered
(`System_Clock No_Buffer`). Every line they add or remove is otherwise
identical to OpenDRAM's. Their context lines keep the trailing whitespace of
AMD's files, which they need to apply with no fuzz (`.editorconfig` here stops
editors from trimming it): make them with `diff`, do not edit them by hand.

A unified diff carries the lines it replaces and a few unchanged lines around
each change, so the patches contain fragments of AMD's MIG source (about 700
lines in all), which remain under AMD's copyright and terms. The complete AMD
files are not in this repository.

## With he-soc's MIG

he-soc's MIG drives one x16 MT40A256M16GE-083E (16-bit DQ) at DDR4-1250
(tCK 1600 ps, controller clock 156.25 MHz), CL 9, CWL 9, with a 64-bit AXI
port. OpenDRAM was developed, and is simulated, with four of the same part
(64-bit DQ) at DDR4-2400 (tCK 833 ps), CL 18, CWL 12, with a 512-bit AXI port.
The MIG that Vivado 2024.2 generates with he-soc's settings has:

- refresh: tRFC = 163 clocks and tREFI = 4875 clocks (7.8 us). With the pad of
  20, OpenDRAM's first command after a refresh comes 169 clocks after the REF,
  6 clocks after tRFC (computed with the formula in `rtl/opendram_mc.sv`, not
  simulated);
- periodic reads: PER_RD_INTVL = 157. The MIG registers its compare, so the
  interval is 160 controller cycles (1.02 us), and a periodic read goes out at
  the end of each interval in which no read was issued.

OpenDRAM's own timing constants (`rtl/command_scheduler/time_constraints.vh`)
are DDR4-2400 values in DRAM clocks (CL 18, CWL 12). Checked against he-soc's
MIG (one rank, CL 9, CWL 9), every constraint they produce is at least what the
device needs: the ones set in ns (tRCD, tRP, tRAS, tRC, tWR, tWTR, tRTP, tRRD,
tFAW, tCCD_L) span more clocks than needed, tCCD_S (4 clocks) is the same, and
the read/write turnarounds, which depend on CL and CWL rather than on the clock
period, are longer (read to write 12-14 clocks against 6, write to read 22-26
against 15-18). That is correct, but not as fast as constants made for
DDR4-1250 would be. The file's tRFC and tREFI are not used: refresh timing
comes from the MIG.

OpenDRAM is not simulated in he-soc: the xsim flow uses a behavioural memory
in place of the MIG. OpenDRAM's own simulation and tests (in its repository)
use its own MIG configuration above, not he-soc's.

## Updating OpenDRAM

Copy `src/opendram/` of the OpenDRAM repository over `rtl/`, and update the
branch and commit in the table above. If OpenDRAM's patches changed, make the
he-soc patches again: generate the MIG with the settings in `opendram.tcl`,
apply OpenDRAM's patches with the two changes above, and save the result as
unified diffs from the generated files.

This works with Vivado 2024.2 only. The MIG's module prefix
(`ddr4_v2_2_24_` in 2024.2) changes with every Vivado release, and it is
hard-coded in OpenDRAM's patches, in the four MIG instantiations in OpenDRAM's
`src/opendram/opendram_mc.sv` (`mc_ctl`, `mc_periodic`, `mc_ref`, `mc_ecc`)
and in `od_mig_rev` in `opendram.tcl`. For another Vivado version, port
OpenDRAM itself first (its `patches/README.md`, "Another Vivado version"), then
copy `rtl/` again, set `od_mig_rev`, and make the he-soc patches again.
