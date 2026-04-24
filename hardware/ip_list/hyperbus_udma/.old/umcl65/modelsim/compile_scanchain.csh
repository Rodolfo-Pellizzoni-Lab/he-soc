#! /bin/tcsh -f

set VER=10.6b
set LIB=scan


if (-e ${LIB}) then
  rm -rf ${LIB}
endif

vlib-${VER} ${LIB}

#vlog-${VER} -work ${LIB} ../synopsys/netlists/hyperbus_macro.v
vlog-${VER} -work ${LIB} ../encounter/out/hyperbus_macro.v
vlog-${VER} -work ${LIB} ../tetramax/scanchain_tb.v


vlog-${VER} -sv -work ${LIB} \
    ../src/axi/src/axi_pkg.sv \
    ../src/axi/src/axi_intf.sv \
    ../src/axi/src/axi_test.sv \
    ../src/register_interface/src/reg_intf.sv \
    ../src/register_interface/src/reg_test.sv \
    ../src/scanchain_tb.sv
