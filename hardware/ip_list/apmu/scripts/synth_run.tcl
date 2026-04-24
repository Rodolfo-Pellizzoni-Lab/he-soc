file mkdir synth_apmu
set PROJECT_HOME [file join [pwd] "synth_apmu"]
set BOARD "vcu118"
set XILINX_PART "xcvu9p-flga2104-2L-e"
set XILINX_BOARD "xilinx.com:vcu118:part0:2.0"
create_project apmu $PROJECT_HOME -part $XILINX_PART
source ./compile.tcl
set_property top pmu_top [current_fileset]
add_files -fileset constrs_1 -norecurse "constraints/constraints.xdc"
update_compile_order -fileset sources_1
auto_detect_xpm
synth_design
update_compile_order -fileset sources_1
opt_design
place_design
report_route_status -file synth_apmu/post_route_status.rpt
report_timing_summary -file synth_apmu/post_route_timing_summary.rpt
report_power -file synth_apmu/post_route_power.rpt
report_drc -file synth_apmu/post_imp_drc.rpt
