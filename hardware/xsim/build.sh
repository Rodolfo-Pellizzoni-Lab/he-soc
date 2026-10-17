#!/bin/bash
# Full xsim build: bender file list -> compile.sh (one xvlog/xvhdl call per bender block) -> work library,
# plus the DPI library (elfloader, SimJTAG, remote_bitbang).
# usage: build.sh [-j]     -j: only regenerate compile.sh and libdpi.so, do not compile the RTL
set -e
source "$(dirname "$0")/env.sh"
mkdir -p "$WORK"; cd "$WORK"

defs=$(echo $SOC_DEFINES $XSIM_DEFINES | tr ' ' ',')
( cd "$HW" && ./bender script vsim $BENDER_TARGETS ) > vsim.tcl
python3 "$XSIM_DIR/vsim2xsim.py" vsim.tcl compile.sh "$HW" "$defs"
chmod +x compile.sh

echo "### DPI library"
xsc --gcc_compile_options "-std=c++11 -I$HW/tb/dpi" --gcc_link_options "-std=c++11" \
    -o libdpi.so "$HW/tb/dpi/SimJTAG.cc" "$HW/tb/dpi/elfloader.cc" "$HW/tb/dpi/remote_bitbang.cc" > xsc.log 2>&1 \
  || { tail -20 xsc.log; exit 1; }

[ "$1" = "-j" ] && exit 0
echo "### Xilinx IP simulation sources (AXI DMA)"
"$XSIM_DIR/xilinx_ip.sh" || exit 1
echo "### compiling RTL into $WORK/xsim.dir/work (log: compile.log)"
start=$(date +%s)
./compile.sh > compile.log 2>&1 || { grep -E 'ERROR|FAILED' compile.log | head -5; exit 1; }
echo "### compile ok in $(( $(date +%s) - start )) s"
