# OpenDRAM in the he-soc FPGA build

OpenDRAM is a DDR4 memory controller that takes the place of the memory
controller inside the Xilinx DDR4 MIG. The MIG keeps its PHY, calibration and
AXI front end. Setting `OPENDRAM=1` makes the FPGA build (`hardware/fpga/run.tcl`)
use it; without it the build is unchanged and uses the MIG's own controller.

Everything he-soc needs for it is in this directory, next to the other frozen
IPs. OpenDRAM's own repository stays generic and knows nothing about he-soc.

## What is here

| path | what |
|---|---|
| `rtl/` | OpenDRAM's RTL, the 18 files of `src/opendram/` of the OpenDRAM repository (github.com/Sarkar22/OpenDRAM), branch `vivado-2024.2-fixes`, commit 663ea1e, copied unchanged except the 16x timing change of this branch (below): `command_scheduler/time_constraints.vh` and `command_scheduler/command_scheduler.sv` (c2c758d8) |
| `patches/` | the changes OpenDRAM needs in two files the MIG generates: `ddr4_0_ddr4_mem_intfc.sv` (instantiates `opendram_mc` in place of the MIG's controller `ddr4_v2_2_24_mc`) and `ddr4_v2_2_mc_ctl.sv` (takes OpenDRAM's per-slot commands `sel_cmd0..3` instead of the MIG's arbiter) |
| `opendram.tcl` | what `run.tcl` runs when `OPENDRAM=1` (below) |
| `sim/` | a recipe that simulates OpenDRAM with he-soc's MIG configuration in OpenDRAM's own testbench, and its result |

This is the unpipelined OpenDRAM (command scheduler V5) with both refresh fixes
of that branch (its `issues/README.md`):

- the tRFC pad: `rtl/opendram_mc.sv` passes `tRFC + MC_REF_TRFC_PAD` (20) to
  the MIG's refresh logic, so that the first command after a refresh no longer
  goes out while the DRAM is still refreshing;
- fix B: `rtl/request_scheduler/request_scheduler_wrapper.sv` gives a periodic
  read to the lowest open bank even when that bank's queue is full, so that a
  periodic-read request can no longer be lost (which stopped refresh for good).

## This branch: DRAM timing constraints 16x

This branch, `es/opendram-2024.2-16x`, makes memory deliberately slower, so
that interference and slowdown effects become visible. It is the change of
682d6682 on `es/opendram-16x-timing` (Ali Abbasi's proposal), applied to this
copy in c2c758d8:

- all 27 numeric macros in `rtl/command_scheduler/time_constraints.vh` are
  multiplied by 16 (tRCD 16 -> 256, tRC 61 -> 976, ...);
- `TIME_WIDTH` in `rtl/command_scheduler/command_scheduler.sv` goes from 4 to
  8 bits, or every scaled value would wrap. The largest stored value is 244
  (tRC), so 16x is the largest factor that fits.

Every constraint OpenDRAM enforces is 16 times longer than the ones described
below: read to write 164-196 clocks, write to read 352-416. Refresh itself is
not slowed, because the MIG times it. But the drain before each refresh and
the restart after it are slower: in simulation, refresh held requests off for
13.3% of the time, against 4.9% at 1x. Periodic reads wait longer to be
accepted (up to 540 controller cycles in simulation, 9 at 1x). None is lost,
and nothing in the MIG has a timeout for them.

The old 16x factor was sized for a 20 MHz SoC. At 50 MHz it puts the DRAM's
command ceiling about 2.5x below the SoC side's AXI bandwidth, a harder
bottleneck than before. It is kept at 16x for comparability.

`sim/README.md` has the 16x simulation. The board results further down are
for the 1x builds of `es/opendram-2024.2`.

## How the build uses it

With `OPENDRAM=1`, `hardware/fpga/run.tcl` does not read the prebuilt
`hardware/fpga/alsaqr/tcl/ips/ddr/ip/ddr4_0.xci` and sources `opendram.tcl`, which:

1. creates the DDR4 MIG in the project, with the settings of
   `hardware/fpga/alsaqr/tcl/ips/ddr/run.tcl` except `AUTO_AP_COL_A3`, which is off: OpenDRAM
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
clock (`hardware/fpga/alsaqr/tcl/ips/clk_mngr/run.tcl`: 50 MHz with 4 cores), the clock
crossing to the MIG and the pins. The other IPs come from `make ips` in
`hardware/fpga` as usual; the prebuilt DDR4 IP is not needed.

One constraint change on this branch applies to every build, with or without
`OPENDRAM=1`: `hardware/fpga/alsaqr/tcl/constraints.xdc` no longer creates a
clock of its own on `u_ddr4_0/c0_ddr4_ui_clk` (08706a3d). That clock was
asynchronous to everything else, so the paths between the axi_cdc and the
MIG's AXI port, which run on one clock, were never timed. Once timed, they
turned out to fail by up to 1.09 ns in an OpenDRAM build.

## Building

Run `make ips` in `hardware/fpga` once (every IP except `ddr`), then build as
usual with `OPENDRAM=1` in the environment. The bitstreams of this branch were
built with alsaqr-mcp's `fpga_build`, with `"OPENDRAM": "1"` added to its
config's `fpga.env`. That environment, for the record:

```
BOARD=vcu118 XILINX_PART=xcvu9p-flga2104-2L-e XILINX_BOARD=xilinx.com:vcu118:part0:2.0
AXI_ID_DDR_WIDTH=9 MAIN_MEM=DDR4 SIMPLE_PAD=SPI-I2C-UART-SDIO USE_OT=0 ETH2FMC_NO_PAD=0
NUM_CORES=4 XILINX_ETH=1 OPENDRAM=1
bender: simple-padframe=1 exclude-cluster=1 exclude-rot=1 quad-core=1
        exclude-ethernet=1 xilinx-ethernet=1 scripts-bender-fpga-ddr
```

`make run` in `hardware/fpga` runs the same `run.tcl`, but it was not used end
to end for these builds.

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
  6 clocks after tRFC. The formula in `rtl/opendram_mc.sv` gives it, and the
  simulation in `sim/` measured it on the DDR4 pins;
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

he-soc's xsim flow uses a behavioural memory in place of the MIG, so it does
not simulate OpenDRAM. `sim/` runs OpenDRAM's own testbench with he-soc's MIG
configuration: the MIG traffic generator passes with every read compared, and
the JEDEC referee finds no violation (`sim/README.md`).

## On the board (VCU118)

Two builds of this branch were tested on the VCU118 (Vivado 2024.2, SoC at
50 MHz, 4 cores, Ethernet):

- e42d2051, before the constraint fix:
  - he-soc's bare-metal board suite: 12 of 12;
  - March C- for 4 hours: 84 passes over 123 MB, 0 errors;
  - retention: 379 MB written, then 24 minutes with only refresh running,
    0 bit flips;
  - memtester under Linux 6.1, one instance per core: 4 x 64 MB fast tests
    and 4 x 2 MB with all 18 tests, 0 failures;
  - 40 SSH and raw TCP transfers, all checksums matching.
- 08706a3d, published as `alsaqr-software/bitstreams/alsaqr_opendram_ethernet.bit`:
  - setup timing met everywhere, including the paths between the axi_cdc and
    the MIG (+0.221 ns MIG to CDC, +0.325 ns CDC to MIG);
  - the only timing misses: 7 hold (reset removal) checks of -0.031 to
    -0.053 ns inside `i_spim_gen[1]`, the unused SPI master 1, besides the
    known adv_timer hold paths;
  - Linux 6.1 netboots, and 20 of 20 16 MiB scp uploads pass.

Linux 6.1.183 needs alsaqr-software's `linux/cva6-sdk/linux_patch_6.1`
(0166940b). Without it, `__vdso_clock_gettime()` can crash any process. This
shows up as SSH sessions dropping during long transfers, with the stock MIG
as well as with OpenDRAM.

## Updating OpenDRAM

Copy `src/opendram/` of the OpenDRAM repository over `rtl/`, and update the
branch and commit in the table above. Then check that
`sim/opendram_hesoc_mig.patch` still applies to that commit, and rerun the
simulation in `sim/`. If OpenDRAM's patches changed, make the
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
