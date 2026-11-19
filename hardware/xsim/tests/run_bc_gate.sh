#!/usr/bin/env bash
# Unit test of the DMA admission gate (tests/tb_bc_gate.sv) on ip_list/axi_llc/src/axi_llc_bc_gate.sv: random
# reads and writes through the gate to an out-of-order slave with random admission grants. Needs no built SoC.
# GATE_SV=<file> tests another gate, GATE_RUN=<name> uses its own work directory.
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/bc_gate${GATE_RUN:+_$GATE_RUN}"; mkdir -p "$D"
cd "$D"
xvlog -sv -i "$IP/axi/include" -i "$IP/common_cells/include" \
  "$IP/common_cells/src/cf_math_pkg.sv" "$IP/axi/src/axi_pkg.sv" \
  "$(realpath "${GATE_SV:-$IP/axi_llc/src/axi_llc_bc_gate.sv}")" "$XSIM_DIR/tests/tb_bc_gate.sv" \
  > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_bc_gate -s bc_gate --timescale 1ns/1ps --mt off \
  > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 1800 xsim bc_gate -R -log bc_gate.log > stdout.log 2>&1 || rc=$?
grep -E "^  |FAIL|BC GATE|Error|ERROR" stdout.log | head -30 || true
[ $rc = 124 ] && { echo "BC GATE FAIL: xsim still running after 1800 s"; exit 1; }
grep -q 'BC GATE PASS' stdout.log
