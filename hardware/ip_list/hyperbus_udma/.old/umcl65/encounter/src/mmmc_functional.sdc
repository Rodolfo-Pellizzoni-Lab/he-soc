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

## In our fictional example the circuit has a main operational mode
## In a standard SDC file (without MMMC) we would only use these
## constraints. 

# create_clock -period  8 [get_ports {Clk_CI}]

# set_input_delay  2 -clock {Clk_CI} [remove_from_collection [all_inputs] [get_ports {Clk_CI}]]
# set_output_delay 3 -clock {Clk_CI} [all_outputs]

## In this mode, the following pin is always set to the given value
set_case_analysis 0 [get_ports {scan_en_ti}]
set_case_analysis 0 [get_ports {test_en_ti}]

## set_case_analysis sets a constant value
## ste_false_path removes it from timing calculation.
## Use set_false_path as a last resort. 
#set_false_path -from [get_ports {ScanEn_TI}]
#set_false_path -from [get_ports {RamTest_TI}]

# current_instance i_hyperbus
# source ../synopsys/netlists/hyperbus.sdc



source ../synopsys/netlists/hyperbus_macro.sdc

set period_phy 6.0
set period_sys 4.0


# 
set padDelayInput 1.0
set padDelayOutput 3.0
set insertionDelayRwds [expr $period_phy/4 + $padDelayInput - 0.2]
set insertionDelayRwds 2.3

#set_clock_latency  $insertionDelayRwds hyper_rwds_io
set_propagated_clock hyper_rwds_io

set margin      0.5
set input_clock hyper_rwds_io;           # Name of input clock
set skew_bre    [expr 0.45 + $margin];   # Data invalid before the rising clock edge
set skew_are    [expr 0.45 + $margin];   # Data invalid after the rising clock edge
set skew_bfe    [expr 0.45 + $margin];   # Data invalid before the falling clock edge
set skew_afe    [expr 0.45 + $margin];   # Data invalid after the falling clock edge
set input_ports {hyper_dq_io[*]};        # List of input ports

# Input Delay Constraint 
set options -network_latency_included
set_input_delay -clock $input_clock -max [expr $period_phy/2 + $skew_afe ] [get_ports $input_ports] $options;
set_input_delay -clock $input_clock -min [expr $period_phy/2 - $skew_bfe ] [get_ports $input_ports] $options;
set_input_delay -clock $input_clock -max [expr $period_phy/2 + $skew_are ] [get_ports $input_ports] -clock_fall -add_delay $options;
set_input_delay -clock $input_clock -min [expr $period_phy/2 - $skew_bre ] [get_ports $input_ports] -clock_fall -add_delay $options;

#Hyperram Datasheet 8.2  -  2V/ns with 20pF load
set_input_transition [expr 1.8 / 2] [get_ports hyper_*_io] $options


#  Double Data Rate Source Synchronous Outputs 
#
#  Source synchronous output interfaces can be constrained either by the max data skew
#  relative to the generated clock or by the destination device setup/hold requirements.
#
#  Setup/Hold Case:
#  Setup and hold requirements for the destination device and board trace delays are known.
#
# forwarded                        _________________________________
# clock                 __________|                                 |______________
#                                 |                                 |
#                           tsu_r |  thd_r                    tsu_f | thd_f
#                         <------>|<------->                <------>|<----->
#                         ________|_________                ________|_______
# data @ destination   XXX__________________XXXXXXXXXXXXXXXX________________XXXXX
#
# Example of creating generated clock at clock output port
create_generated_clock -name hyper_ck_o -edges {1 2 3} -source [get_pins i_deflate/i_hyperbus/ddr_clk/clk90_o] [get_ports hyper_ck_o]
set_clock_latency $padDelayOutput hyper_ck_o

set margin       0.45
set fwclk        hyper_ck_o;                         # forwarded clock name (generated using create_generated_clock at output clock port)        
set tsu_r        [expr 0.6 + $margin];               # destination device setup time requirement for rising edge
set thd_r        [expr 0.6 + $margin];               # destination device hold time requirement for rising edge
set tsu_f        [expr 0.6 + $margin];               # destination device setup time requirement for falling edge
set thd_f        [expr 0.6 + $margin];               # destination device hold time requirement for falling edge
set output_ports {{hyper_dq_io[*]} hyper_rwds_io};   # list of output ports

# Output Delay Constraints
set_output_delay -clock $fwclk -max [expr    $tsu_r] [get_ports $output_ports];
set_output_delay -clock $fwclk -min [expr  - $thd_r] [get_ports $output_ports];
set_output_delay -clock $fwclk -max [expr    $tsu_f] [get_ports $output_ports] -clock_fall -add_delay;
set_output_delay -clock $fwclk -min [expr  - $thd_f] [get_ports $output_ports] -clock_fall -add_delay;

set_output_delay -clock $fwclk [expr $period_phy/2] [get_ports hyper_cs_*];


# false paths through cdc_2phase cells
set CDC_NETS_2PHASE [get_nets -hierarchical {*async_req *async_ack *async_data*}]
set_max_delay \
    -from [all_fanin -to $CDC_NETS_2PHASE -flat] \
    -to [all_fanout -from $CDC_NETS_2PHASE -flat] \
    [expr $period_sys/2.0]

# set_false_path -hold \
#     -from [all_fanin -to $CDC_NETS_2PHASE -flat -only_cells] \
#     -to [all_fanout -from $CDC_NETS_2PHASE -flat -only_cells]

# false paths through cdc_fifo cells
set_max_delay \
    -from [all_fanin -to [get_nets -hierarchical *src_wptr_gray_q*] -flat -only_cells] \
    -to [all_fanout -from [get_nets -hierarchical *dst_wptr_gray_q[*]] -flat -only_cells] \
    [expr $period_sys/2.0]

# set_false_path -hold \
#     -from [all_fanin -to [get_nets -hierarchical *src_wptr_gray_q*] -flat -only_cells] \
#     -to [all_fanout -from [get_nets -hierarchical *dst_wptr_gray_q*] -flat -only_cells]

set_max_delay \
    -from [all_fanin -to [get_nets -hierarchical *dst_rptr_gray_q*] -flat -only_cells] \
    -to [all_fanout -from [get_nets -hierarchical *src_rptr_gray_q[*]] -flat -only_cells] \
    [expr $period_sys/2.0]

# set_false_path -hold \
#     -from [all_fanin -to [get_nets -hierarchical *dst_rptr_gray_q*] -flat -only_cells] \
#     -to [all_fanout -from [get_nets -hierarchical *src_rptr_gray_q*] -flat -only_cells]

set_false_path \
    -from [all_fanin -to [get_nets -hierarchical *fifo_data_q*] -flat -only_cells] \
    -to [all_fanout -from [get_nets -hierarchical *dst_data_o*] -flat] 

# output port from axi are no fanout...
set_false_path \
    -from [all_fanin -to [get_nets -hierarchical *fifo_data_q*] -flat -only_cells] \
    -to [get_ports {axi_i_r_resp* axi_i_r_data* axi_i_r_last}] 

# false paths for other signals
set CDC_FALSE_PATHS [get_nets -hierarchical {*config_t_* *read_clk_en_i}]
set_max_delay \
    -from [all_fanin -to $CDC_FALSE_PATHS -flat -only_cells] \
    -to [all_fanout -from $CDC_FALSE_PATHS -flat -only_cells] \
    $period_sys

set_max_delay \
    -from [get_pins i_deflate/i_hyperbus/phy_i/hyper_*_oe_o_reg/Q] \
    -to [get_ports hyper_*_io] \
    [expr $period_phy/2.0]

set_false_path -hold \
    -from [get_pins i_deflate/i_hyperbus/phy_i/hyper_*_oe_o_reg/Q] \
    -to [get_ports hyper_*_io]

set_max_delay -from [get_pins i_deflate/i_hyperbus/phy_i/read_clk_en_reg/Q] -to [all_fanin -to [get_nets i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/clk_rwds_orig] -only_cells -pin_levels 1] [expr $period_phy/2.0]
set_max_delay -from [get_pins i_deflate/i_hyperbus/phy_i/read_clk_en_reg/Q] -to [get_pins i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/read_in_valid_reg/RB] [expr $period_phy/2.0]


set_false_path -from [get_pins i_deflate/i_hyperbus/ddr_clk/clk0_o] -to [get_ports hyper_*_io]


#hold false paths
set_false_path -hold -from [get_clocks hyper_rwds_io] -to [get_clocks clk0]
set_false_path -hold -from [get_clocks clk0] -to [get_clocks hyper_rwds_io]
set_false_path -hold -from [get_clocks clk0] -to [get_clocks clk_sys_i]
set_false_path -hold -from [get_clocks clk_sys_i] -to [get_clocks clk0]
set_false_path -hold -from [get_clocks clk_phy_i] -to [get_clocks hyper_rwds_io]


set_false_path -through [get_ports rst_ni]

set_false_path -from [get_pins i_deflate/i_hyperbus/i_rstgen_phy/s_rst_n_reg/Q] -to [get_clocks hyper_rwds_io]
