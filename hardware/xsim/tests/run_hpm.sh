#!/usr/bin/env bash
set -e
source "$(dirname "$0")/../env.sh"
cd "$WORK"
xvlog -sv -work work "$XSIM_DIR/tests/tb_hpm.sv"
xelab work.tb_hpm -L work -s hpm_unit --timescale 1ns/1ps --ignore_assertions > xelab_hpm_unit.log 2>&1
xsim hpm_unit -R -log hpm_unit.log > hpm_unit_stdout.log 2>&1
cat hpm_unit_stdout.log
# xsim may exit zero after $fatal, so require the explicit success marker.
grep -q 'HPM UNIT PASS' hpm_unit_stdout.log
