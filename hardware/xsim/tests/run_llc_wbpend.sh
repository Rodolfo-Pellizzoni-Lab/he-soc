#!/usr/bin/env bash
# LLC write-back test (tests/tb_llc_wbpend.sv): axi_llc_top in front of a memory that applies a write-back only with
# its write response, answers late and out of order, and serves a read from what it held when the AR came. Needs only
# the SoC's compile script for the file list (ip_list sources).
#   PEND=<n> write-backs that may wait for their response (default 4; 0: the original unit)   WBUF=<slots> (8)
#   NOPS=<n> per thread and phase (400)   REGION=<bytes per thread> (1024)   BMIN / BMAX=<cycles to the response>
#   BREORDER=<0|1> responses of different IDs out of order (1)   SEED=<n>   LLC_RUN=<name> its own work directory
#   RMIN / RMAX=<cycles to the first R beat>   HOT=<threads walking HOTL lines of HOTS sets> (0, 6, 2)
#   BYP=1 bypass traffic too   AWLIM=<n> the memory takes an AW only with fewer than n writes unanswered
#   BBURST=1 write responses held, then one per cycle   FLUSHMID=<n> flushes of random ways during the traffic
#   MUTANT=nohold       the write unit without the wait of a refill for the write-back of its own line
#   MUTANT=noflushwait  ... without the wait of a flush for the outstanding responses
#   MUTANT=fifo         ... with every response taken as the oldest write-back's, whatever its ID
#   (a mutant must FAIL: the script then exits 0 and prints "MUTANT ... caught")
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/llc_wbpend${LLC_RUN:+_$LLC_RUN}"; mkdir -p "$D"
cd "$D"
FILES=$(tr ' ' '\n' < "$WORK/compile.sh" | grep -E "\.s?v$" |
        grep -E "ip_list/(common_cells|tech_cells_generic|axi|axi_llc)/" | grep -v "axi_test.sv" | awk '!seen[$0]++' |
        sed "s#\(.*axi_llc/src/axi_llc_top.sv\)#$IP/axi_llc/src/axi_llc_w_buffer.sv \1#" |
        sed "s#\(.*axi_llc/src/axi_llc_hit_miss.sv\)#$IP/axi_llc/src/hit_miss_detect/axi_llc_lock_box_exact.sv \1#" |
        tr ' ' '\n' | awk '!seen[$0]++')
WM=$IP/axi_llc/src/eviction_refill/axi_llc_w_master.sv
case "${MUTANT:-}" in
  "")          ;;
  nohold)      sed 's/desc_valid_o = ~(desc_q.refill & pend_hit);/desc_valid_o = 1'"'"'b1;/' "$WM" > w_master_mut.sv ;;
  noflushwait) sed 's/if (pend_empty) begin/if (1'"'"'b1) begin/' "$WM" > w_master_mut.sv ;;
  fifo)        sed 's/if (!found \&\& b_is\[i\]) begin/if (!found \&\& v_q[i]) begin/' "$WM" > w_master_mut.sv ;;
  *) echo "unknown MUTANT ${MUTANT}"; exit 2 ;;
esac
if [ -n "${MUTANT:-}" ]; then
  cmp -s "$WM" w_master_mut.sv && { echo "MUTANT ${MUTANT}: the source line to change was not found"; exit 2; }
  FILES=$(echo "$FILES" | sed "s#^.*/axi_llc_w_master.sv\$#$D/w_master_mut.sv#")
fi
xvlog -sv -i "$IP/common_cells/include" -i "$IP/axi/include" -d COMMON_CELLS_ASSERTS_OFF \
  $FILES "$XSIM_DIR/tests/tb_llc_wbpend.sv" > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_llc_wbpend -s llc_wbpend --timescale 1ns/1ps --mt off \
  -generic_top "PEND=${PEND:-4}" -generic_top "WBUF=${WBUF:-8}" -generic_top "NOPS=${NOPS:-400}" \
  -generic_top "REGION=${REGION:-1024}" -generic_top "BMIN=${BMIN:-20}" -generic_top "BMAX=${BMAX:-250}" \
  -generic_top "BREORDER=${BREORDER:-1}" -generic_top "RMIN=${RMIN:-2}" -generic_top "RMAX=${RMAX:-40}" \
  -generic_top "HOT=${HOT:-0}" -generic_top "HOTL=${HOTL:-6}" -generic_top "HOTS=${HOTS:-2}" \
  -generic_top "BYP=${BYP:-0}" -generic_top "AWLIM=${AWLIM:-0}" -generic_top "BBURST=${BBURST:-0}" \
  -generic_top "FLUSHMID=${FLUSHMID:-0}" -generic_top "COVER=${COVER:-1}" \
  > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 3600 xsim llc_wbpend -R -sv_seed "${SEED:-1}" -log llc_wbpend.log > stdout.log 2>&1 || rc=$?
grep -E "^  |FAIL|LLC WBPEND|^Error|LLC-WB\] t=.*(no free|no write-back|written back again)" stdout.log | head -${SHOW:-30} || true
[ $rc = 124 ] && { echo "LLC WBPEND FAIL: xsim still running after 3600 s"; exit 1; }
pass=0
! grep -qE "^(Error|Fatal|ERROR|FATAL)" stdout.log && grep -q 'LLC WBPEND PASS' stdout.log && pass=1
if [ -n "${MUTANT:-}" ]; then
  [ $pass = 0 ] && { echo "MUTANT ${MUTANT} caught"; exit 0; }
  echo "MUTANT ${MUTANT} NOT caught: the test passed"; exit 1
fi
[ $pass = 1 ]
