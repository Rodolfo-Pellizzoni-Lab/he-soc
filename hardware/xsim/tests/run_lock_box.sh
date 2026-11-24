#!/usr/bin/env bash
# Unit test of the LLC's exact lock box (tests/tb_lock_box.sv). Needs no built SoC.
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/lock_box"; mkdir -p "$D"
cd "$D"
xvlog -sv -i "$IP/common_cells/include" -i "$IP/axi/include" \
  "$IP/common_cells/src/cf_math_pkg.sv" "$IP/common_cells/src/cb_filter_pkg.sv" "$IP/axi/src/axi_pkg.sv" \
  "$IP/axi_llc/src/axi_llc_pkg.sv" "$IP/axi_llc/src/hit_miss_detect/axi_llc_lock_box_exact.sv" \
  "$XSIM_DIR/tests/tb_lock_box.sv" > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_lock_box -s lock_box --timescale 1ns/1ps --mt off > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 600 xsim lock_box -R -log lock_box.log > stdout.log 2>&1 || rc=$?
grep -E "^  |^FAIL|LOCK BOX UNIT|LLC-LOCK" stdout.log | head -20 || true
grep -q 'LOCK BOX UNIT PASS' stdout.log
