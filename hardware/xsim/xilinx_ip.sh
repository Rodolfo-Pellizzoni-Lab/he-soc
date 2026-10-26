#!/bin/bash
# Simulation sources of the Xilinx IP the SoC instantiates (today: the AXI DMA of the Ethernet subsystem, whose
# RTL is plain VHDL/Verilog and needs no license). Vivado generates them from the same configuration the FPGA flow
# uses (hardware/fpga/alsaqr/tcl/ips/eth_dma/config.tcl) into $WORK/xilinx_ip. The IP's own libraries (libs.txt)
# are the ones Vivado ships precompiled for xsim and maps in its global xsim.ini (axi_dma_v7_1_34, ...): those are
# not compiled again (an `xvhdl -work <lib>` of such a name writes INTO the installation, which two builds running
# at once corrupt), the elaborations pick them up with -L. Only the IP's top (xil_defaultlib) goes into work, and
# a library the installation does not provide is compiled into $WORK/xsim.dir/<lib>. Nothing is kept in the tree.
# usage: xilinx_ip.sh [-f]     -f: regenerate even if the sources exist
set -e
source "$(dirname "$0")/env.sh"
IPDIR=$XILINX_IP_DIR
CFG=$HW/fpga/alsaqr/tcl/ips/eth_dma/config.tcl
stamp=$(md5sum "$CFG" | cut -c1-8)
if [ "$1" != "-f" ] && [ -f "$IPDIR/libs.txt" ] && [ "$(cat "$IPDIR/stamp" 2>/dev/null)" = "$stamp" ] \
   && ls "$WORK"/xsim.dir/work/eth_dma*.sdb >/dev/null 2>&1; then
  echo "xilinx_ip: up to date ($IPDIR)"; exit 0
fi
GLOBAL_INI=${XILINX_VIVADO:?}/data/xsim/xsim.ini
rm -rf "$IPDIR"; mkdir -p "$IPDIR"; cd "$IPDIR"
cat > gen.tcl <<TCL
source $CFG
create_project xilinx_ip ./proj -part xcvu9p-flga2104-2L-e -force
set_property target_language Verilog [current_project]
set_property target_simulator XSim [current_project]
create_ip -name axi_dma -vendor xilinx.com -library ip -version \$ETH_DMA_IP_VERSION -module_name eth_dma
set_property -dict \$ETH_DMA_CONFIG [get_ips eth_dma]
generate_target simulation [get_ips eth_dma]
set f [open files.txt w]
foreach x [get_files -compile_order sources -used_in simulation -of_objects [get_files -of_objects [get_ips eth_dma] -filter {FILE_TYPE == IP-XACT}]] {
  puts \$f "[get_property LIBRARY \$x] [get_property FILE_TYPE \$x] \$x"
}
close \$f
TCL
vivado -mode batch -nojournal -nolog -source gen.tcl > gen.log 2>&1 || { grep -E "^ERROR" gen.log | head -5; exit 1; }
[ -s files.txt ] || { echo "xilinx_ip: no simulation files listed (gen.log)"; exit 1; }

# the top (xil_defaultlib) goes into work; a library Vivado ships precompiled (global xsim.ini) is only listed;
# anything else is compiled into its own local library, in the IP's compile order
cd "$WORK"
: > "$IPDIR/libs.txt"; : > "$IPDIR/compile.log"
while read -r lib type path; do
  [ "$lib" = "xil_defaultlib" ] && lib=work
  if [ "$lib" != "work" ] && grep -q "^$lib=" "$GLOBAL_INI"; then
    echo "precompiled: $lib $path" >> "$IPDIR/compile.log"; dest=""
  elif [ "$lib" = "work" ]; then dest="work"
  else dest="$lib=$WORK/xsim.dir/$lib"
  fi
  if [ -n "$dest" ]; then
    case "$type" in
      VHDL*)    xvhdl -work "$dest" "$path" >> "$IPDIR/compile.log" 2>&1 || { grep ERROR "$IPDIR/compile.log" | head -3; exit 1; } ;;
      Verilog*) xvlog -work "$dest" "$path" >> "$IPDIR/compile.log" 2>&1 || { grep ERROR "$IPDIR/compile.log" | head -3; exit 1; } ;;
      *) echo "xilinx_ip: skipping $type $path" ;;
    esac
  fi
  [ "$lib" != "work" ] && ! grep -qx "$lib" "$IPDIR/libs.txt" && echo "$lib" >> "$IPDIR/libs.txt"
done < "$IPDIR/files.txt"
echo "$stamp" > "$IPDIR/stamp"
echo "xilinx_ip: $(wc -l < "$IPDIR/files.txt") files in $(wc -l < "$IPDIR/libs.txt") libraries + work"
