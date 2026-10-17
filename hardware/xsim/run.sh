#!/bin/bash
# Run one test on the xsim build.
# usage: run.sh <l2|l3> <elf> [name] [timeout_s]
#   l2: program in L2 (entry 0x1C000000, tohost 0x1C000140), core 1 released via DUAL_BOOT (make build_l2)
#   l3: program in the sim DRAM behind the LLC (entry 0x80000000, tohost 0x1C000000) (make build)
# env: NO_ELAB=1 reuses the existing tb_<flow> snapshot instead of recompiling the tb and re-elaborating.
# Output: $WORK/<name>_stdout.log (sim output), $WORK/wd_<name>.txt (watchdog). Exit 0 iff "[JTAG] SUCCESS".
source "$(dirname "$0")/env.sh"
flow=$1; elf=$(realpath "$2" 2>/dev/null); name=${3:-$flow}; to=${4:-7200}
[ -f "$elf" ] && [[ "$flow" =~ ^l[23]$ ]] || { sed -n '2,8p' "$0"; exit 2; }
cd "$WORK" || { echo "no $WORK - run build.sh first"; exit 1; }

case $flow in
  l2) tbdefs="-d DUAL_BOOT -d XSIM_NO_AXI_DRV -d XSIM_L2_PRELOAD" ;;
  l3) tbdefs="-d XSIM_NO_AXI_DRV -d XSIM_L2_PRELOAD -d XSIM_L3_FLOW" ;;
esac
snap=tb_$flow
if [ -z "$NO_ELAB" ]; then
  tbopts=$(grep -E "^xvlog .*[ /]ariane_tb\.sv( |$)" compile.sh | head -1 | grep -oE "(-i|-d) [^ ]+" | tr "\n" " ")
  xvlog -sv -work work -L uvm $tbopts $tbdefs "$HW/tb/ariane_tb.sv" > xvlog_$name.log 2>&1 \
    || { grep ERROR xvlog_$name.log | head -3; exit 1; }
  xelab -relax -L uvm $(xilinx_ip_libs) -timescale 1ps/1ps --ignore_assertions --snapshot $snap work.ariane_tb \
        -sv_root "$WORK" -sv_lib libdpi $GENERICS > xelab_$name.log 2>&1 \
    || { grep ERROR xelab_$name.log | head -3; exit 1; }
  echo "[$name] xelab ok $(date +%T)"
fi

PA="-testplusarg CORE_ID=0 -testplusarg CVA6_STRING=$elf -testplusarg CL_STRING=none -testplusarg OT_SRAM=none"
PA="$PA -testplusarg OT_FLASH=none -testplusarg OT_CLUSTER=none -testplusarg BOOTMODE=0 -testplusarg UVM_NO_RELNOTES"
PA="$PA -testplusarg MAX_CYCLES=10000000 -testplusarg UVM_TESTNAME=core_test"

# watchdog: the tb prints a TICK every 10 us of sim time; no new TICK for 180 s means xsim is spinning
# (a combinational ring, see README.md) or deadlocked, so kill it instead of burning the timeout.
( last=""; since=$(date +%s); sleep 20
  while pgrep -f "x[s]imk.*$snap" >/dev/null; do
    t=$(grep TICK ${name}_stdout.log 2>/dev/null | tail -1 | awk '{print $2}'); now=$(date +%s)
    [ "$t" != "$last" ] && { last=$t; since=$now; }
    echo "WD $(date +%T) tick=$t idle=$((now-since))s rss=$(ps -o rss= -C xsimk | awk '{s+=$1} END {print int(s/1024)}')MB"
    [ -n "$t" ] && [ $((now-since)) -ge 180 ] && { echo "STALLED at $t"; pkill -f "x[s]imk.*$snap"; break; }
    sleep 30
  done ) > wd_$name.txt 2>&1 &

timeout $to xsim $snap -R -log xsim_$name.log $PA > ${name}_stdout.log 2>&1; rc=$?
echo "[$name] xsim rc=$rc"
grep -E '\[JTAG\]|XSIM-L[23]|Mock uart|SUCCESS|FAILED|Fatal|\$finish|xsim:' ${name}_stdout.log | head -40
grep -q 'STALLED' wd_$name.txt && tail -1 wd_$name.txt
grep -q '\[JTAG\] SUCCESS' ${name}_stdout.log
