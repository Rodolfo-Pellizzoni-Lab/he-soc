#!/bin/sh
# Kernel QoS-ID policy x how the tenant makes its memory traffic.   exp10.sh <mode 1..4> <user|sys|pf|loop> <MB_MIN> <MB_WGHT> [secs]
#   victim: streaming reader, group g1, CPU 1.  tenant: three katk in g2 on CPUs 2, 3, 0 (MB_MIN - : no cap).
R=/sys/fs/resctrl; cd /root
mode=$1; atk=$2; mn=$3; wg=$4; secs=${5:-6}
echo 2 > /proc/sys/kernel/perf_user_access
echo 1048576 > /proc/sys/vm/dirty_background_bytes; echo 4194304 > /proc/sys/vm/dirty_bytes
reset_groups() { for g in g1 g2 g3 g4 g5 g6 g7 g8; do echo "MB_WGHT:0=255" > $R/$g/schemata; echo "MB_MIN:0=1" > $R/$g/schemata; done; echo "MB_MIN:0=100" > $R/schemata; }
reset_groups; devmem 0x1A106100 32 0
devmem 0x10401C88 32 50000; devmem 0x10401C90 32 47000; devmem 0x10401C80 32 3
echo $mode > /sys/module/qos/parameters/kqos_mode
pids=""
# kernel workers stay off the victim's CPU: this is about memory traffic, not CPU time
echo d > /sys/devices/virtual/workqueue/cpumask
rm -f /tmp/a2.out /tmp/a3.out /tmp/a0.out; [ "$atk" = none ] && echo "ready ready ready" | tr " " "\n" > /tmp/a2.out; touch /tmp/a3.out /tmp/a0.out
[ "$atk" = none ] || for ci in 2:0 3:1 0:2; do c=${ci%:*}; ./katk $atk $c g2 ${ci#*:} > /tmp/a$c.out 2>&1 & pids="$pids $!"; done
n=0; until [ "$(cat /tmp/a2.out /tmp/a3.out /tmp/a0.out | grep -c ready)" = 3 ]; do sleep 1; n=x$n; [ ${#n} -gt 60 ] && break; done
if [ "$mn" != "-" ]; then echo "MB_MIN:0=$mn" > $R/g2/schemata; echo "MB_WGHT:0=$wg" > $R/g2/schemata; fi
# lift the cap whatever happens (a throttled kernel path may never return)
( sleep 45; echo "MB_WGHT:0=255" > $R/g2/schemata ) > /dev/null 2>&1 &
guard=$!
echo "== mode $mode tenant $atk cap $mn/$wg"
# the window: 5 s inside the victim's 6 s
RDTSER_MID="./bcmon start; kill -USR1 $pids 2>/dev/null; sleep 5; ./bcmon read > /tmp/bc.out; kill -USR2 $pids 2>/dev/null; sleep 1" ./rdtser2 $secs 16 0 1:g1 | grep -E "^1:"
cat /tmp/bc.out
echo "MB_WGHT:0=255" > $R/g2/schemata; echo "MB_MIN:0=1" > $R/g2/schemata
n=0; while [ -n "$(ps | grep ' ./katk ' | grep -v grep)" ]; do sleep 1; n=x$n; [ ${#n} -gt 40 ] && { killall -9 katk; break; }; done
cat /tmp/a2.out /tmp/a3.out /tmp/a0.out | grep -v ready
kill $guard 2>/dev/null
devmem 0x10401C80 32 0; echo 0 > /sys/module/qos/parameters/kqos_mode 2>/dev/null
echo "oopses $(dmesg | grep -c Oops)"; echo RUNDONE
