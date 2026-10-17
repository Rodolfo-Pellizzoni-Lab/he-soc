#!/bin/bash
# Simulation sources of the Xilinx IP the SoC instantiates (today: the AXI DMA of the Ethernet subsystem, whose
# RTL is plain VHDL/Verilog and needs no license). Vivado generates them from the same configuration the FPGA flow
# uses (hardware/fpga/alsaqr/tcl/ips/eth_dma/config.tcl) into $WORK/xilinx_ip, and they are compiled into their
# own xsim libraries (libs.txt), which the elaborations pick up with -L. Nothing is kept in the tree.
# usage: xilinx_ip.sh [-f]     -f: regenerate even if the sources exist
set -e
source "$(dirname "$0")/env.sh"
IPDIR=$XILINX_IP_DIR
CFG=$HW/fpga/alsaqr/tcl/ips/eth_dma/config.tcl
stamp=$(md5sum "$CFG" | cut -c1-8)
if [ "$1" != "-f" ] && [ -f "$IPDIR/libs.txt" ] && [ "$(cat "$IPDIR/stamp" 2>/dev/null)" = "$stamp" ] \
   && [ -d "$WORK/xsim.dir/axi_dma_v7_1_34" -o -d "$WORK/xsim.dir/$(tail -2 "$IPDIR/libs.txt" | head -1)" ]; then
  echo "xilinx_ip: up to date ($IPDIR)"; exit 0
fi
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

# compile, one library at a time, in the IP's compile order; the top (xil_defaultlib) goes into work
cd "$WORK"
: > "$IPDIR/libs.txt"
while read -r lib type path; do
  [ "$lib" = "xil_defaultlib" ] && lib=work
  case "$type" in
    VHDL*)    xvhdl -work "$lib" "$path" >> "$IPDIR/compile.log" 2>&1 || { grep ERROR "$IPDIR/compile.log" | head -3; exit 1; } ;;
    Verilog*) xvlog -work "$lib" "$path" >> "$IPDIR/compile.log" 2>&1 || { grep ERROR "$IPDIR/compile.log" | head -3; exit 1; } ;;
    *) echo "xilinx_ip: skipping $type $path" ;;
  esac
  [ "$lib" != "work" ] && ! grep -qx "$lib" "$IPDIR/libs.txt" && echo "$lib" >> "$IPDIR/libs.txt"
done < "$IPDIR/files.txt"
echo "$stamp" > "$IPDIR/stamp"
echo "xilinx_ip: $(wc -l < "$IPDIR/files.txt") files in $(wc -l < "$IPDIR/libs.txt") libraries + work"
