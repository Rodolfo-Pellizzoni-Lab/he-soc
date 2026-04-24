#################################################################
## Example MMMC SDC files
#################################################################
##
## There are 5 files in this fictional MMMC (multi-mode multi-corner)
## analysis setup:
##   - src/sample/mmmc_shared.sdc        SDC file with common constraints
##   - src/sample/mmmc_functional.sdc    Functional mode constraints
##   - src/sample/mmmc_test.sdc          Test mode constraints
##   - src/sample/mmmc_hold.sdc          Hold timing analysis mode
##   - src/sample/mmmc.view.tcl          Sample TCL file that can be adapted
##
## Please note these are just for reference, develop your own scripts!
##
#################################################################


## You can use a separate file to keep options that are common between
## multiple modes. In this example we will assume that the output load 
## and input transition are the same.

#set_analysis_view -update_timing 


set_input_transition 0.5 [all_inputs]

#Hyperram Datasheet 8.2  -  2V/ns with 20pF load
set_input_transition [expr 1.8 / 2] [get_ports {hyper_dq* hyper_rwds_io hyper_ck_* hyper_cs_*}]

set output_ports {{hyper_dq_io[*]} hyper_rwds_io};   # list of output ports


set_load 0.005 [all_output]
set_load 10 [get_ports {hyper_dq* hyper_rwds_io hyper_ck_* hyper_cs_*}]
