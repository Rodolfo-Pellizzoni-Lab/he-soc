#!/usr/bin/env bash
# Unit test of the LLC's CBQRI bandwidth controller (tests/tb_llc_bc.sv) on ip_list/axi_llc/src/axi_llc_cbqri_bc.sv:
# ordering rules, registers and STATUS codes, reservation floors, Mweight sharing, hard limits, priority inheritance
# for ordered writes, monitoring counters, a random drain, and a reserved hard limit next to a best-effort RCID. Needs no built SoC. BC_SV=<file> tests another
# controller (a broken one must FAIL), BC_RUN=<name> uses its own work directory.
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/llc_bc${BC_RUN:+_$BC_RUN}"; mkdir -p "$D"
cd "$D"
xvlog -sv -i "$IP/axi/include" -i "$IP/common_cells/include" \
  "$IP/common_cells/src/cf_math_pkg.sv" "$IP/axi/src/axi_pkg.sv" \
  "$(realpath "${BC_SV:-$IP/axi_llc/src/axi_llc_cbqri_bc.sv}")" "$XSIM_DIR/tests/tb_llc_bc.sv" \
  > xvlog_llc_bc.log 2>&1 || { grep -E "ERROR" xvlog_llc_bc.log | head -8; exit 1; }
xelab tb_llc_bc -s llc_bc --timescale 1ns/1ps --mt off \
  > xelab_llc_bc.log 2>&1 || { grep -E "ERROR" xelab_llc_bc.log | head -8; exit 1; }
rc=0
timeout 1800 xsim llc_bc -R -log llc_bc.log > llc_bc_stdout.log 2>&1 || rc=$?
grep -E "^  [A-N]|^FAIL|LLC BC UNIT" llc_bc_stdout.log || true
[ $rc = 124 ] && { echo "LLC BC UNIT FAIL: xsim still running after 1800 s"; exit 1; }
! grep -qE "^(Error|Fatal|ERROR|FATAL)" llc_bc_stdout.log && grep -q 'LLC BC UNIT PASS' llc_bc_stdout.log
