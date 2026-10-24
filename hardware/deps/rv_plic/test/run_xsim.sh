#!/bin/bash
# PLIC equivalence testbench (tb_plic_equiv.sv) in xsim. usage: run_xsim.sh [work dir]   exit 0 = PASS
set -e
D=$(cd "$(dirname "$0")" && pwd); R=$D/../rtl; W=${1:-$D/work}
mkdir -p "$W"; cd "$W"
command -v xvlog >/dev/null 2>&1 || source "${VIVADO_SETTINGS:-/tools/Xilinx/Vivado/2024.2/settings64.sh}"
xvlog -sv "$R/reg_intf_pkg.sv" "$R/rv_plic_target.sv" "$R/rv_plic_gateway.sv" "$R/plic_regmap.sv" "$R/plic_top.sv" \
  "$D/plic_regs_gen256x8.sv" "$D/plic_regs_gen256x16.sv" "$D/plic_top_ref.sv" "$D/tb_plic_equiv.sv" > xvlog.log 2>&1 \
  || { grep -E "ERROR" xvlog.log | head; exit 1; }
xelab -timescale 1ns/1ps tb_plic_equiv -s tb_plic_equiv > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head; exit 1; }
xsim tb_plic_equiv -R 2>&1 | tee xsim.log | grep -E "mismatch|PLIC EQUIV|cycles\]"
grep -q "PLIC EQUIV PASS" xsim.log
