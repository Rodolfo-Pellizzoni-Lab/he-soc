#!/bin/bash
# Locate an xsim stall: build a --debug typical snapshot, step from <start_ns> in <step_ns> slices until
# simulation time stops advancing, then ptrace 500 ns around that point and rank the spinning processes.
# usage: chain_dbg.sh <tag> <elf> <start_ns> <steps> <step_ns>
# The tb in the work library is used as last compiled by run.sh (i.e. the flow of the last run).
source "$(dirname "$0")/env.sh"
tag=$1; elf=$(realpath "$2"); start=$3; steps=$4; step=$5; snap=tb_${tag}dbg
cd "$WORK" || exit 1
PA="-testplusarg CORE_ID=0 -testplusarg CVA6_STRING=$elf -testplusarg CL_STRING=none -testplusarg OT_SRAM=none"
PA="$PA -testplusarg OT_FLASH=none -testplusarg OT_CLUSTER=none -testplusarg BOOTMODE=0 -testplusarg UVM_NO_RELNOTES"
xelab -relax -L uvm -timescale 1ps/1ps --ignore_assertions --debug typical --snapshot $snap work.ariane_tb \
      -sv_root "$WORK" -sv_lib libdpi $GENERICS > xelab_$snap.log 2>&1 || { echo "xelab failed"; exit 1; }
echo "xelab ok $(date +%T)"
cat > st_$tag.tcl <<EOT
set top [lindex [get_scopes /*] 0]; set C "\$top/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane\[0\].i_ariane"
set f [open st_$tag.txt w]
run ${start}ns; puts \$f "REACHED [current_time]"; flush \$f
for {set i 0} {\$i < $steps} {incr i} { run ${step}ns; set line "REACHED [current_time]"; foreach s [list \$C/commit_stage_i/commit_instr_i] { if {[catch {set v [get_value -radix hex \$s]}]} {set v ?}; append line " pc=[string range \$v 0 30]" }; puts \$f \$line; flush \$f }
puts \$f "NOSTALL"; flush \$f
quit
EOT
rm -f st_$tag.txt
timeout 900 xsim $snap -t st_$tag.tcl -nolog $PA > st_$tag.log 2>&1 &
XP=$!
( sleep 200; while kill -0 $XP 2>/dev/null; do a=$(tail -1 st_$tag.txt 2>/dev/null); sleep 45; b=$(tail -1 st_$tag.txt 2>/dev/null)
    [ "$a" = "$b" ] && [ -n "$a" ] && { echo "STALL $a" >> st_$tag.txt; for p in $(pgrep -f "x[s]imk.*$snap"); do kill -9 $p; done; break; }
  done ) &
wait $XP
last=$(grep '^REACHED' st_$tag.txt | tail -1 | awk '{print $2, $3}'); echo "last marker: $last"
grep -q NOSTALL st_$tag.txt && { echo "no stall in window"; exit 0; }
v=$(echo $last | awk '{ if ($2=="us") print $1*1000; else if ($2=="ns") print $1; else if ($2=="ps") print $1/1000; else print $1*1000000 }')
from=$(awk -v v="$v" 'BEGIN{printf "%d", v-200}')
printf "run ${from}ns\nptrace on\nrun 500ns\nquit\n" > pt_$tag.tcl
timeout 400 xsim $snap -t pt_$tag.tcl -nolog $PA 2>&1 | head -c 500000000 > ptrace_$tag.log
for p in $(pgrep -f "x[s]imk.*$snap"); do kill -9 $p; done
echo "=== top processes"
grep -E '^INFO: /ariane_tb' ptrace_$tag.log | sed 's/^INFO: \/ariane_tb([^)]*)\///' | sort | uniq -c | sort -rn | head -12 | cut -c1-230
echo "=== top source lines"
grep -E "^INFO: $HW/" ptrace_$tag.log | sort | uniq -c | sort -rn | head -12 | sed "s|$HW/||"
