#! /bin/tcsh -f

set VER=10.6b
set LIB=work


if (-e ${LIB}) then
  rm -rf ${LIB}
endif

vlib-${VER} ${LIB}

vlog-${VER} -work ${LIB} ../models/s27ks0641/s27ks0641.v

vlog-${VER} -sv -work ${LIB} \
    ../src/tech_cells_generic/pulp_clock_xor2.sv \
    ../src/tech_cells_generic/pulp_clock_mux2.sv \
    ../src/tech_cells_generic/pulp_clock_gating.sv \
    ../src/tech_cells_generic/pulp_clock_inverter.sv \
    ../src/common_cells/src/cdc_fifo_gray.sv \
    ../src/common_cells/src/cdc_2phase.sv \
    ../src/common_cells/src/graycode.sv \
    ../src/common_cells/src/rstgen.sv \
    ../src/axi/src/axi_pkg.sv \
    ../src/axi/src/axi_intf.sv \
    ../src/axi/src/axi_test.sv \
    ../src/register_interface/src/reg_intf.sv \
    ../src/register_interface/src/reg_test.sv \
    ../src/register_interface/src/reg_uniform.sv \
    ../src/config_registers.sv \
    ../src/config_registers_tb.sv \
    ../src/delayline/PROGDEL8.v \
    ../src/clock_diff_out.sv \
    ../src/clk_gen.sv \
    ../src/ddr_out.sv \
    ../src/hyperbus_delay_line.sv \
    ../src/pad_io.sv \
    ../src/read_clk_rwds.sv \
    ../src/hyperbus.sv \
    ../src/hyperbus_macro.sv \
    ../src/hyperbus_deflate.sv \
    ../src/hyperbus_phy.sv \
    ../src/hyperbus_axi.sv \
    ../src/cmd_addr_gen.sv \
    ../src/ddr_in.sv \
    ../src/hyperbus_tb.sv \
    ../src/hyperbus_phy_tb.sv
