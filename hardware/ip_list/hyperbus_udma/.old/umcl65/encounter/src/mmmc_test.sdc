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

## In our example, the test mode is projected to run much slower
 create_clock -period  20 [get_ports {clk_sys_i}] 

## for some reason I/O timing is different
set_input_delay 5 -clock {clk_sys_i} [remove_from_collection [all_inputs] [get_ports {clk_sys_i}]] 
set_output_delay 5 -clock {clk_sys_i} [all_outputs] 


## In this mode, the following pin is always set to the given value
set_case_analysis 1 [get_ports test_en_ti] 

## note that the false paths from 'ScanEn_TI' and 'RamTest_TI' 
## in the functional mode are not declared here. But another path is
## disabled


set_false_path -from [get_ports clk_sys_i] -to [get_ports hyper_ck_o]
set_false_path -from [get_ports clk_sys_i] -to [get_ports hyper_ck_no]


