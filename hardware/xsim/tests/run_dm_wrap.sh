#!/usr/bin/env bash
# Unit test of the DRAM timing model's time base across the point where its old 48-bit counter wrapped
# (tests/tb_dm_wrap.sv on host/axi_dram_timing.sv): reads and writes before, across and after 2^48 sixteenths of a
# cycle (2^44 cycles, 4.07 days at 50 MHz after a reset) must come out on time. On a built work dir: XSIM_WORK=<dir>,
# for the SoC's AXI packages. The model and the tb compile into their own library (dm_wrap), so the work library keeps
# the SoC's model; they read the SoC's packages under the name soc. DM_SV=<file> tests another axi_dram_timing.sv.
# CONTROL=1 also runs the model with TW = 48, which must FAIL: its responses stop at the wrap.
set -e
source "$(dirname "$0")/../env.sh"
WORK=$(realpath "$WORK")
model=$(realpath "${DM_SV:-$HW/host/axi_dram_timing.sv}")
cd "$WORK"
exec 9>"$WORK/elab.lock"; flock 9
soc="soc=$WORK/xsim.dir/work"
run() {   # run <model.sv> <label> : prints the tb's lines, returns 0 on DM WRAP UNIT PASS
  local lib=dm_wrap_$2
  xvlog -sv -work $lib -L "$soc" "$1" "$XSIM_DIR/tests/tb_dm_wrap.sv" \
    > xvlog_$lib.log 2>&1 || { grep -E "ERROR" xvlog_$lib.log | head -5; return 2; }
  xelab $lib.tb_dm_wrap -L $lib -L "$soc" -s $lib --timescale 1ns/1ps --mt off \
    > xelab_$lib.log 2>&1 || { grep -E "ERROR" xelab_$lib.log | head -5; return 2; }
  local rc=0
  timeout 300 xsim $lib -R -log $lib.log > ${lib}_stdout.log 2>&1 || rc=$?
  sed -n 's/^/  /;/time base\|^  ok\|^  FAIL\|DM WRAP UNIT/p' ${lib}_stdout.log
  [ $rc = 124 ] && { echo "  xsim still running after 300 s"; return 1; }
  ! grep -qE "^(Error|Fatal|ERROR|FATAL)" ${lib}_stdout.log && grep -q 'DM WRAP UNIT PASS' ${lib}_stdout.log
}
echo "model: $model"
run "$model" head || { echo "DM WRAP UNIT FAIL"; exit 1; }
if [ "${CONTROL:-0}" = 1 ]; then
  ctl=$WORK/dm_wrap_tw48.sv
  sed 's/localparam int unsigned TW = [0-9]*;/localparam int unsigned TW = 48;/' "$model" > "$ctl"
  grep -q 'localparam int unsigned TW = 48;' "$ctl" || { echo "DM WRAP UNIT FAIL: no TW in $model"; exit 1; }
  echo "control, TW = 48 (must fail):"
  if run "$ctl" tw48; then echo "DM WRAP UNIT FAIL: the 48-bit control passed"; exit 1; fi
fi
echo "DM WRAP UNIT PASS"
