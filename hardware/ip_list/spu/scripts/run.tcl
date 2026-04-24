set outputDir "reports"
set PROJECT_HOME "synth"
set XILINX_PART "xczu9eg-ffvb1156-2-e"
create_project spu synth -part xczu9eg-ffvb1156-2-e
source ./synth/compile.tcl
set_property top spu_top [current_fileset]
update_compile_order -fileset sources_1
auto_detect_xpm
synth_design
update_compile_order -fileset sources_1
opt_design
place_design
write_checkpoint post_place.dcp
report_utilization -file $outputDir/post_place_util.rpt
route_design
write_checkpoint post_route.dcp