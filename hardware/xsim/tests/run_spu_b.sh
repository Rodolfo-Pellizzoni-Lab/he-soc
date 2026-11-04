#!/usr/bin/env bash
# Unit test of the SPU's write-response events (tests/tb_spu_b.sv) on ip_list/spu/src/axi_spu_top.sv: a B the master
# holds (b_valid without b_ready) must give one W_RESP event, paired with its own AW, also while a second write of
# the same ID is outstanding (18196e8c: new_b_resp_q never left 1, so the second write took the first one's B).
# Needs no built SoC: the SPU and the few packages it uses are compiled into $WORK/spu_b. SPU_TOP_SV=<file> tests
# another axi_spu_top.sv (e.g. one with the old line put back, which must FAIL). ace_spu_top.sv (the core SPUs) has
# the same B logic: its "Write Response channel" block is identical.
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
top=$(realpath "${SPU_TOP_SV:-$IP/spu/src/axi_spu_top.sv}")
mkdir -p "$WORK/spu_b"
cd "$WORK/spu_b"
xvlog -sv -i "$IP/axi/include" -i "$IP/common_cells/include" \
  "$IP/common_cells/src/cf_math_pkg.sv" "$IP/axi/src/axi_pkg.sv" "$IP/axi/src/axi_intf.sv" "$IP/apmu/src/pmu_pkg.sv" \
  "$IP/spu/src/spu_pkg.sv" "$IP/common_cells/src/addr_decode_dync.sv" "$IP/common_cells/src/addr_decode.sv" \
  "$IP/common_cells/src/fifo_v3.sv" "$IP/spu/src/spu_arbiter.sv" "$IP/spu/src/spu_ax_chan.sv" \
  "$IP/spu/src/spu_r_chan.sv" "$IP/spu/src/spu_w_chan.sv" "$top" "$XSIM_DIR/tests/tb_spu_b.sv" \
  > xvlog_spu_b.log 2>&1 || { grep -E "ERROR" xvlog_spu_b.log | head -5; exit 1; }
xelab tb_spu_b -s spu_b --timescale 1ns/1ps --mt off \
  > xelab_spu_b.log 2>&1 || { grep -E "ERROR" xelab_spu_b.log | head -5; exit 1; }
rc=0
timeout 300 xsim spu_b -R -log spu_b.log > spu_b_stdout.log 2>&1 || rc=$?
grep -E "^  B |^FAIL|SPU B UNIT" spu_b_stdout.log || true
[ $rc = 124 ] && { echo "SPU B UNIT FAIL: xsim still running after 300 s"; exit 1; }
# xsim may exit zero after $fatal or with $error messages, so require the explicit success marker and no errors.
! grep -qE "^(Error|Fatal|ERROR|FATAL)" spu_b_stdout.log && grep -q 'SPU B UNIT PASS' spu_b_stdout.log
