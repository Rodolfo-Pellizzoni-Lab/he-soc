#! /bin/tcsh -f

# example file to compile GATE-LEVEL sourcecode


set VER=10.6b
set LIB=gate


if (-e ${LIB}) then
  rm -rf ${LIB}
endif

vlib-${VER} ${LIB}

# vlog-${VER} -work ${LIB} \
#    /usr/pack/umc-65-kgf/umc/ll/uk65lscllmvbbl/b03/verilog/uk65lscllmvbbl_sdf21.v \
#    /usr/pack/umc-65-kgf/umc/ll/uk65lscllmvbbr/b03/verilog/uk65lscllmvbbr_sdf21.v \
#    /usr/pack/umc-65-kgf/umc/ll/uk65lscllmvbbh/b03/verilog/uk65lscllmvbbh_sdf21.v \
#    /usr/pack/umc-65-kgf/umc/ll/u065gioll25mvir/b04/verilog/u065gioll25mvir.v 

#hyperram model
vlog-${VER} -work ${LIB} ../models/s27ks0641/s27ks0641.v

# testbench
vlog-${VER} -sv -work ${LIB} \
    ../src/axi/src/axi_pkg.sv \
    ../src/axi/src/axi_intf.sv \
    ../src/axi/src/axi_test.sv \
    ../src/register_interface/src/reg_intf.sv \
    ../src/register_interface/src/reg_test.sv \
    ../src/pad_io.sv \
    ../src/hyperbus_deflate.sv \
    ../src/hyperbus_tb.sv \
    ../src/hyperbus_phy_tb.sv


# gate-level netlist
#vlog-${VER} -work ${LIB} ../synopsys/netlists/hyperbus_macro.v
vlog-${VER} -work ${LIB} ../encounter/out/hyperbus_macro.v

# run with the sim_postlayout.csh script
