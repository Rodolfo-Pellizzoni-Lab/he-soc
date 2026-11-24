#!/bin/bash
# run10.sh <tag> "<mode atk min wght>" ...: exp10 runs on the board, one after the other
S=/tmp/claude-1000/-home-mhassen-he-soc/508b8202-db72-4036-ab02-c975d3dae090/scratchpad
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10"
tag=$1; shift
for r in "$@"; do
  timeout 20 ssh $SSHO root@10.42.0.2 "cd /root; sh exp10.sh $r > /tmp/e10.out 2>&1 < /dev/null & echo started $r" > /dev/null
  sleep 22
  for i in $(seq 1 24); do timeout 15 ssh $SSHO root@10.42.0.2 'grep -q -E "RUNDONE|syntax error" /tmp/e10.out' && break; sleep 5; done
  timeout 20 ssh $SSHO root@10.42.0.2 'cat /tmp/e10.out' 2>&1 | grep -v RUNDONE | cut -c1-120 | tee -a $S/e10_$tag.out
done
