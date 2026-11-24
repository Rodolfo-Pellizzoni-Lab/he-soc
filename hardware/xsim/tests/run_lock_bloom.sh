#!/usr/bin/env bash
# False-positive rate of the LLC lock box's bloom filter (tests/tb_lock_bloom.sv) for several hash widths and rounds.
# Needs no built SoC.
set -e
source "$(dirname "$0")/../env.sh"
IP=$HW/ip_list
D="$WORK/lock_bloom"; mkdir -p "$D"
cd "$D"
xvlog -sv "$IP/common_cells/src/sub_per_hash.sv" "$XSIM_DIR/tests/tb_lock_bloom.sv" \
  > xvlog.log 2>&1 || { grep -E "ERROR" xvlog.log | head -8; exit 1; }
xelab tb_lock_bloom -s lock_bloom --timescale 1ns/1ps --mt off > xelab.log 2>&1 || { grep -E "ERROR" xelab.log | head -8; exit 1; }
timeout 1800 xsim lock_bloom -R -log lock_bloom.log > stdout.log 2>&1 || true
grep -E "^LOCK BLOOM|^  " stdout.log
