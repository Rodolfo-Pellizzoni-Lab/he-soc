# OpenDRAM simulated with he-soc's MIG configuration

he-soc's own xsim flow uses a behavioural memory in place of the MIG, so it never simulates OpenDRAM. This
directory holds a recipe for that check instead. It runs OpenDRAM's own testbench, from the OpenDRAM repository
(github.com/Sarkar22/OpenDRAM, commit 663ea1e, the commit `../rtl/` is copied from), with the MIG generated the way
he-soc generates it. OpenDRAM's RTL is not changed.

`opendram_hesoc_mig.patch` changes three files of that repository:

- **`gen_opendram.tcl`:** the MIG, set up like he-soc's. That is one x16 MT40A256M16GE-083E at DDR4-1250
  (tCK 1600 ps), CL 9 / CWL 9, a 64-bit AXI port, ID width 9, auto-precharge off, and no DDR4 board interface.
  The system clock input stays differential (he-soc's is `No_Buffer`). Only the input buffer differs, and
  OpenDRAM's patches still apply with no fuzz.
- **`src/axi_vip/jedec_checker_inc.svh`:** the JEDEC referee's device minimums for tCK 1600 ps, taken from the
  Micron model's DDR4-1333 timing set (the one it uses from 1500 to 1874 ps), and tRFC 163 / tREFI 4875 from the
  MIG.
- **`issues/pins_decode.tcl`:** `PINS_TCK` 1600 for the check on the DDR4 pins.

Only `make sim` is adapted. It runs the MIG's own AXI traffic generator, which compares every read. `make bench`,
`sim_regression` and `equiv` still assume OpenDRAM's own MIG (512-bit AXI), so they do not run with this patch.

## Running it (Vivado 2024.2)

```
git clone https://github.com/Sarkar22/OpenDRAM && cd OpenDRAM
git checkout 663ea1e
git apply <he-soc>/hardware/ip_list/opendram/sim/opendram_hesoc_mig.patch
make project
touch /tmp/od_sim_start && make sim
```

To check the refreshes on the DDR4 pins, replay the simulation `make sim` just elaborated. Do it right after
`make sim`, with nothing else using the project:

```
printf 'source {%s/issues/pins_decode.tcl}\nrun 60us\npins_report\nquit\n' "$PWD" > /tmp/pins_hesoc.tcl
bash issues/replay.sh /tmp/pins_hesoc.tcl /tmp/pins.log /tmp/od_sim_start
grep '^PINS' /tmp/pins.log
```

## Result (2026-10-22)

- **`make sim`:** TEST PASSED. The traffic generator compared every read.
- **JEDEC referee:** 0 violations in 62,429 rule checks over 12,194 controller cycles. It checks tRCD, tRP, tRAS,
  tRC, tRRD_S/L, tFAW, tCCD_S/L, tRTP, tWR, tWTR_S/L, tPPD, tRFC and tREFI. tZQCS was not exercised in a run this
  short.
- **Refresh:** 9 refreshes, all on time. The first command after each REF comes 169 DRAM clocks after it, against
  tRFC = 163.
  - The referee sees that.
  - On the DDR4 pins, 5 of the 6 REFs within 60 us were followed by a command at +169 clocks. After the other one,
    no request was waiting, so the next command came at +801.
- **Periodic reads:** 12 requested and 12 accepted.
- **Read returns:** none duplicated and none orphaned.
