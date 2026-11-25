#!/usr/bin/env bash
# The LLC's write unit on its own (tests/tb_llc_wmaster.sv): order, W data, the wait of a refill for the write-back of
# its own line, the wait of a flush, the bound on unanswered write-backs, progress; checked against a model.
#   PEND=<n> (4; 0: the original unit)   NDESC=<descriptors> (30000)   NLINE=<lines per set> (6)   NID=<AXI IDs> (3)
#   BMIN / BMAX=<cycles to the response> (0, 60)   BREORDER=<0|1> (1)   PRDY=<back-pressure> (3; 0: none)
#   LEGAL=0 descriptors and responses a real cache never makes (the unit's own assertions then fire and are not
#   counted)   SEED=<n>   LLC_RUN=<name>   MUTANT=nohold|noflushwait|fifo as in run_llc_wbpend.sh (must FAIL)
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/llc_wmaster${LLC_RUN:+_$LLC_RUN}"; mkdir -p "$D"
cd "$D"
FILES=$(tr ' ' '\n' < "$WORK/compile.sh" | grep -E "\.s?v$" |
        grep -E "ip_list/(common_cells|tech_cells_generic|axi)/|axi_llc/src/axi_llc_pkg.sv|axi_llc_w_master.sv" |
        grep -v "axi_test.sv" | awk '!seen[$0]++')
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
  $FILES "$XSIM_DIR/tests/tb_llc_wmaster.sv" > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_llc_wmaster -s llc_wmaster --timescale 1ns/1ps --mt off \
  -generic_top "PEND=${PEND:-4}" -generic_top "NDESC=${NDESC:-30000}" -generic_top "NLINE=${NLINE:-6}" \
  -generic_top "NID=${NID:-3}" -generic_top "BMIN=${BMIN:-0}" -generic_top "BMAX=${BMAX:-60}" \
  -generic_top "BREORDER=${BREORDER:-1}" -generic_top "LEGAL=${LEGAL:-1}" -generic_top "PRDY=${PRDY:-3}" \
  > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 3600 xsim llc_wmaster -R -sv_seed "${SEED:-1}" -log llc_wmaster.log > stdout.log 2>&1 || rc=$?
grep -E "^  |FAIL|LLC WMASTER" stdout.log | head -${SHOW:-14} || true
[ $rc = 124 ] && { echo "LLC WMASTER FAIL: xsim still running after 3600 s"; exit 1; }
pass=0
grep -q 'LLC WMASTER PASS' stdout.log && pass=1
# with LEGAL=1 the unit's own assertions must stay silent too
[ "${LEGAL:-1}" = 1 ] && grep -qE "^(Error|Fatal|ERROR|FATAL)" stdout.log && pass=0
if [ -n "${MUTANT:-}" ]; then
  [ $pass = 0 ] && { echo "MUTANT ${MUTANT} caught"; exit 0; }
  echo "MUTANT ${MUTANT} NOT caught: the test passed"; exit 1
fi
[ $pass = 1 ]
