#!/usr/bin/env bash
# Unit test of the debug module's AXI slave bridge across ndmreset (tests/tb_dm_bridge.sv): the bridge (axi2mem,
# i_dm_axi2mem in host/cva6_subsystem.sv) behind a crossbar configured as the SoC's, ndmreset asserted at every
# cycle offset of the debug ROM's park loop, then a halt sequence that must get through. Needs no built SoC.
# The bridge gets the reset its instance in cva6_subsystem.sv has: ndmreset_n must never wedge. CONTROL=1 also
# runs the power-on wiring the SoC had before (rst_ni), which must wedge exactly at the offsets where the reset finds
# the bridge waiting for a write's W (WAIT_WVALID). The FPGA build compiles ip_list/axi_mem_if/src/axi2mem.sv and
# deps/util/axi2mem.sv, identical but for a function name; AXI2MEM_SV=<file> picks one (default: the later one).
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
CC=$IP/common_cells/src
bridge=$(realpath "${AXI2MEM_SV:-$HW/deps/util/axi2mem.sv}")
rst=$(sed -n '/) i_dm_axi2mem (/,/);/p' "$HW/host/cva6_subsystem.sv" | sed -n 's/.*\.rst_ni *( *\([A-Za-z_]*\) *).*/\1/p')
case "$rst" in
  ndmreset_n) soc=1 ;;
  rst_ni)     soc=0 ;;
  *) echo "DM BRIDGE UNIT FAIL: cannot read i_dm_axi2mem's reset in cva6_subsystem.sv ('$rst')"; exit 1 ;;
esac
mkdir -p "$WORK/dm_bridge"
cd "$WORK/dm_bridge"
xvlog -sv -i "$IP/axi/include" -i "$IP/common_cells/include" \
  "$CC/cf_math_pkg.sv" "$IP/axi/src/axi_pkg.sv" "$IP/axi/src/axi_intf.sv" "$CC/spill_register_flushable.sv" \
  "$CC/spill_register.sv" "$CC/stream_register.sv" "$CC/fifo_v3.sv" "$CC/lzc.sv" "$CC/rr_arb_tree.sv" "$CC/delta_counter.sv" "$CC/counter.sv" \
  "$CC/addr_decode_dync.sv" "$CC/addr_decode.sv" "$IP/axi/src/axi_id_prepend.sv" "$IP/axi/src/axi_atop_filter.sv" \
  "$IP/axi/src/axi_err_slv.sv" "$IP/axi/src/axi_demux_simple.sv" "$IP/axi/src/axi_demux.sv" "$IP/axi/src/axi_mux.sv" \
  "$IP/axi/src/axi_cut.sv" "$IP/axi/src/axi_multicut.sv" "$IP/axi/src/axi_xbar_unmuxed.sv" "$IP/axi/src/axi_xbar.sv" \
  "$bridge" "$XSIM_DIR/tests/tb_dm_bridge.sv" \
  > xvlog_dm_bridge.log 2>&1 || { grep -E "ERROR" xvlog_dm_bridge.log | head -5 | cut -c1-300; exit 1; }
run() {   # run <BRIDGE_ON_NDMRESET> <label>
  xelab tb_dm_bridge -s "dm_bridge_$2" --timescale 1ns/1ps --mt off -generic_top "BRIDGE_ON_NDMRESET=$1" \
    > "xelab_$2.log" 2>&1 || { grep -E "ERROR" "xelab_$2.log" | head -5 | cut -c1-300; return 1; }
  local rc=0
  timeout 300 xsim "dm_bridge_$2" -R -log "dm_bridge_$2.log" > "dm_bridge_$2_stdout.log" 2>&1 || rc=$?
  grep -E "^tb_dm_bridge|^  (reset|wedged|offset)|^FAIL|DM BRIDGE UNIT" "dm_bridge_$2_stdout.log" || true
  [ $rc = 124 ] && { echo "DM BRIDGE UNIT FAIL ($2): xsim still running after 300 s"; return 1; }
  # xsim may exit zero after $fatal or with $error messages, so require the explicit marker and no errors.
  ! grep -qE "^(Error|Fatal|ERROR|FATAL)" "dm_bridge_$2_stdout.log" && grep -q 'DM BRIDGE UNIT PASS' "dm_bridge_$2_stdout.log"
}
echo "== cva6_subsystem.sv: i_dm_axi2mem on $rst"
run "$soc" soc || exit 1
[ "$soc" = 0 ] && { echo "DM BRIDGE UNIT FAIL: the bridge is on the power-on reset (rst_ni)"; exit 1; }
if [ "${CONTROL:-0}" = 1 ]; then
  echo "== control: the bridge on the power-on reset (must wedge exactly in WAIT_WVALID)"
  run 0 por
fi
