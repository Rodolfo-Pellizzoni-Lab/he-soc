#!/usr/bin/env bash
# LLC write-data buffer test (tests/tb_llc_wbuf.sv): axi_llc_top with the CBQRI bandwidth controller and the
# write-data buffer, eight concurrent AXI IDs with full-width and narrow bursts, a reference memory per ID, regulation
# off and then one RCID hard-limited. Needs only the SoC's compile script for the file list (ip_list sources).
#   WBUF=<slots> (default 8; 0: the original LLC, every write in AW order)   NOPS=<n> per thread and phase (400)
#   PEND=<n> write-backs that may wait for their response (default 0: the original write unit; see run_llc_wbpend.sh)
#   SEED=<n> random seed   LLC_RUN=<name> its own work directory
#   OVERRIDE="<file name>=<path> ..." compile <path> instead of the ip_list source of that name (mutation tests)
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/llc_wbuf${LLC_RUN:+_$LLC_RUN}"; mkdir -p "$D"
cd "$D"
FILES=$(tr ' ' '\n' < "$WORK/compile.sh" | grep -E "\.s?v$" |
        grep -E "ip_list/(common_cells|tech_cells_generic|axi|axi_llc)/" | grep -v "axi_test.sv" | awk '!seen[$0]++' |
        sed "s#\(.*axi_llc/src/axi_llc_top.sv\)#$IP/axi_llc/src/axi_llc_w_buffer.sv \1#" |
        sed "s#\(.*axi_llc/src/axi_llc_hit_miss.sv\)#$IP/axi_llc/src/hit_miss_detect/axi_llc_lock_box_exact.sv \1#" |
        tr ' ' '\n' | awk '!seen[$0]++')
for o in ${OVERRIDE:-}; do FILES=$(echo "$FILES" | sed "s#^.*/${o%%=*}\$#${o#*=}#"); done
xvlog -sv -i "$IP/common_cells/include" -i "$IP/axi/include" -d COMMON_CELLS_ASSERTS_OFF \
  $FILES "$XSIM_DIR/tests/tb_llc_wbuf.sv" > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_llc_wbuf -s llc_wbuf --timescale 1ns/1ps --mt off \
  -generic_top "WBUF=${WBUF:-8}" -generic_top "NOPS=${NOPS:-400}" -generic_top "PEND=${PEND:-0}" \
  > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
rc=0
timeout 3600 xsim llc_wbuf -R -sv_seed "${SEED:-1}" -log llc_wbuf.log > stdout.log 2>&1 || rc=$?
grep -E "^  |FAIL|LLC WBUF" stdout.log | head -30 || true
[ $rc = 124 ] && { echo "LLC WBUF FAIL: xsim still running after 3600 s"; exit 1; }
! grep -qE "^(Error|Fatal|ERROR|FATAL)" stdout.log && grep -q 'LLC WBUF PASS' stdout.log
