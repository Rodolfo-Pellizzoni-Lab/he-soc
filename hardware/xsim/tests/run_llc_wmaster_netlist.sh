#!/usr/bin/env bash
# The LLC's write unit as synthesised: an out-of-context Vivado synthesis of axi_llc_w_master (tests/wm_synth_wrap.sv,
# the VCU118's part), and tests/tb_llc_wmaster.sv on the netlist. Catches a difference between what the simulator
# and the synthesis make of the RTL.  PEND=<n> (4)   other variables as run_llc_wmaster.sh   RESYNTH=1 synthesise again
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
P=${PEND:-4}
D="$WORK/wm_netlist/p$P${LLC_RUN:+_$LLC_RUN}"; N="$WORK/wm_netlist/wm_netlist_p$P.v"; mkdir -p "$D"
cd "$D"
if [ ! -s "$N" ] || [ -n "${RESYNTH:-}" ]; then
  cat > synth.tcl <<TCL
read_verilog -sv [list $IP/common_cells/src/cf_math_pkg.sv $IP/common_cells/src/fifo_v3.sv $IP/common_cells/src/delta_counter.sv $IP/common_cells/src/counter.sv $IP/common_cells/src/cb_filter_pkg.sv $IP/axi/src/axi_pkg.sv $IP/axi_llc/src/axi_llc_pkg.sv $IP/axi_llc/src/eviction_refill/axi_llc_w_master.sv $XSIM_DIR/tests/wm_synth_wrap.sv]
synth_design -top wm_synth_wrap -part xcvu9p-flga2104-2L-e -mode out_of_context -include_dirs [list $IP/common_cells/include $IP/axi/include] -generic PEND=$P -flatten_hierarchy rebuilt
report_utilization -file util_p$P.rpt
write_verilog -mode funcsim -force $N
TCL
  vivado -mode batch -nojournal -log synth_p$P.log -source synth.tcl > /dev/null 2>&1 || { grep -E "^ERROR" synth_p$P.log | head -8; exit 1; }
  grep -E "^(ERROR|CRITICAL WARNING)|inferred latch|Latch" synth_p$P.log | head -8 || true
fi
xvlog "$N" "$XILINX_VIVADO/data/verilog/src/glbl.v" > xvlog_net.log 2>&1 || { grep ERROR xvlog_net.log | head -5; exit 1; }
xvlog -sv -d WM_NETLIST -i "$IP/common_cells/include" -i "$IP/axi/include" \
  "$IP/common_cells/src/cf_math_pkg.sv" "$IP/common_cells/src/cb_filter_pkg.sv" "$IP/axi/src/axi_pkg.sv" "$IP/axi_llc/src/axi_llc_pkg.sv" "$XSIM_DIR/tests/tb_llc_wmaster.sv" > xvlog.log 2>&1 || { grep ERROR xvlog.log | head -8; exit 1; }
xelab tb_llc_wmaster glbl -L unisims_ver -L secureip -s wm_net --timescale 1ns/1ps --mt off \
  -generic_top "PEND=$P" -generic_top "NDESC=${NDESC:-30000}" -generic_top "NLINE=${NLINE:-6}" \
  -generic_top "NID=${NID:-3}" -generic_top "BMIN=${BMIN:-0}" -generic_top "BMAX=${BMAX:-60}" \
  -generic_top "BREORDER=${BREORDER:-1}" -generic_top "LEGAL=${LEGAL:-1}" -generic_top "PRDY=${PRDY:-3}" \
  > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 7200 xsim wm_net -R -sv_seed "${SEED:-1}" -log wm_net.log > stdout.log 2>&1 || rc=$?
grep -E "^  [0-9t]|FAIL|LLC WMASTER" stdout.log | head -${SHOW:-14} || true
grep -q 'LLC WMASTER PASS' stdout.log
