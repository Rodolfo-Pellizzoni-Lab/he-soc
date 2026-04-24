
set period 30;

create_generated_clock -name hyper_ck_o -source [get_pins clk_generation_i/clk_phy_90] -multiply_by 1 [get_ports hyper_ck_o]

create_clock -period $period [get_ports hyper_rwds_io]
set_case_analysis 1 [get_pins hyperbus_i/phy_i/i_read_clk_rwds/cdc_read_ck_gating/clock_gating/CE]

## cdc_fifo in read_clk_rwds
set_max_delay -datapath_only -from [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/dst_rptr_gray_q_reg[*]/C}] -to [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/src_rptr_gray_q_reg[*]/D}] 5
set_max_delay -datapath_only -from [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/src_wptr_gray_q_reg[*]/C}] -to [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/dst_wptr_gray_q_reg[*]/D}] 5
set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/g_word[*].fifo_data_q_reg[*][*]/C] -to [get_pins hyperbus_i/i_cdc_RX_fifo/g_word[*].fifo_data_q_reg[*][*]/D] 10

# needed as bin is the same as the gray register --> removed by optimization
set_max_delay -datapath_only -from [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/dst_rptr_bin_q_reg[3]/C}] -to [get_pins {hyperbus_i/phy_i/i_read_clk_rwds/i_cdc_fifo_hyper/src_rptr_gray_q_reg[3]/D}] 5

set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/read_clk_en_reg/C] -to [get_pins hyperbus_i/phy_i/i_read_clk_rwds/read_in_valid_reg/CLR] 10.0
set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/read_clk_en_reg/C] -to [get_pins hyperbus_i/phy_i/i_read_clk_rwds/cdc_read_ck_gating/clock_gating/CE] 10
set_max_delay -datapath_only -from [get_ports hyper_rwds_io] -to [get_pins hyperbus_i/phy_i/hyper_rwds_i_syn_reg/D] 5

#needed as input is sampled with clk_rwds but output is clk0 - see saved report
set_false_path -from [get_ports hyper_rwds_io] -to [get_ports hyper_rwds_io]

set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/hyper_dq_oe_o_reg/C] -to [get_ports {hyper_dq_io[*]}] 15
set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/hyper_rwds_oe_o_reg/C] -to [get_ports {hyper_rwds_io}] 15

set_max_delay -datapath_only -from [get_pins {hyperbus_i/phy_i/hyper_trans_state_reg[*]/C}] -to [get_pins {hyperbus_i/phy_i/hyper_cs_no_reg[*]/D}] 12.5
set_max_delay -datapath_only -from [get_pins {hyperbus_i/phy_i/local_cs_reg[*]/C}] -to [get_pins {hyperbus_i/phy_i/hyper_cs_no_reg[*]/D}] 12.5
set_max_delay -datapath_only -from [get_pins hyperbus_i/phy_i/en_cs_reg/C] -to [get_pins {hyperbus_i/phy_i/hyper_cs_no_reg[*]/D}] 12.5

# Setting input and output delays.
set_output_delay -clock clk_phy_90_clk_generation_slow [expr [expr $period/2 - 5] ]  [get_ports hyper_cs_*]


# Edge-Aligned Double Data Rate Source Synchronous Inputs
# (Using a direct FF connection)
#
# For an edge-aligned Source Synchronous interface, the clock
# transition occurs at the same time as the data transitions.
# In this template, the clock is aligned with the beginning of the
# data. The constraints below rely on the default timing
# analysis (setup = 1/2 cycle, hold = 0 cycle).
#
# input            _________________________________
# clock  _________|                                 |___________________________
#                 |                                 |
#         skew_bre|skew_are                 skew_bfe|skew_afe
#         <------>|<------>                 <------>|<------>
#        _        |        _________________        |        _________________
# data   _XXXXXXXXXXXXXXXXX____Rise_Data____XXXXXXXXXXXXXXXXX____Fall_Data____XX
#


# Input Delay Constraint
set input_clock         hyper_rwds_io;      # Name of input clock
set skew_bre            0.45+1;             # Data invalid before the rising clock edge
set skew_are            0.45+5;             # Data invalid after the rising clock edge
set skew_bfe            0.45+1;             # Data invalid before the falling clock edge
set skew_afe            0.45+5;             # Data invalid after the falling clock edge
set input_ports         {hyper_dq_io[*]};   # List of input ports

# Input Delay Constraint
set_input_delay -clock $input_clock -max [expr $period/2 + $skew_afe] [get_ports $input_ports];
set_input_delay -clock $input_clock -min [expr $period/2 - $skew_bfe] [get_ports $input_ports];
set_input_delay -clock $input_clock -max [expr $period/2 + $skew_are] [get_ports $input_ports] -clock_fall -add_delay;
set_input_delay -clock $input_clock -min [expr $period/2 - $skew_bre] [get_ports $input_ports] -clock_fall -add_delay;


# Report Timing Template
# report_timing -rise_from [get_ports $input_ports] -max_paths 20 -nworst 1 -delay_type min_max -name src_sync_edge_ddr_in_rise -file src_sync_edge_ddr_in_rise.txt;
# report_timing -fall_from [get_ports $input_ports] -max_paths 20 -nworst 1 -delay_type min_max -name src_sync_edge_ddr_in_fall -file src_sync_edge_ddr_in_fall.txt;

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
# create_generated_clock -name <gen_clock_name> -multiply_by 1 -source [get_pins <source_pin>] [get_ports <output_clock_port>]
# gen_clock_name is the name of forwarded clock here. It should be used below for defining "fwclk".	

set fwclk        hyper_ck_o;       # forwarded clock name (generated using create_generated_clock at output clock port)        
set tsu_r        0.6+5;            # destination device setup time requirement for rising edge
set thd_r        0.6+5;            # destination device hold time requirement for rising edge
set tsu_f        0.6+5;            # destination device setup time requirement for falling edge
set thd_f        0.6+5;            # destination device hold time requirement for falling edge
set output_ports {{hyper_dq_io[*]} hyper_rwds_io};   # list of output ports
# Output Delay Constraints
set_output_delay -clock $fwclk -max [expr             $tsu_r] [get_ports $output_ports];
set_output_delay -clock $fwclk -min [expr $period/2 - $thd_r] [get_ports $output_ports];
set_output_delay -clock $fwclk -max [expr             $tsu_f] [get_ports $output_ports] -clock_fall -add_delay;
set_output_delay -clock $fwclk -min [expr $period/2 - $thd_f] [get_ports $output_ports] -clock_fall -add_delay;

# Report Timing Template
# report_timing -rise_to [get_ports $output_ports] -max_paths 20 -nworst 2 -delay_type min_max -name src_sync_ddr_out_rise -file src_sync_ddr_out_rise.txt;
# report_timing -fall_to [get_ports $output_ports] -max_paths 20 -nworst 2 -delay_type min_max -name src_sync_ddr_out_fall -file src_sync_ddr_out_fall.txt;


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {pad_sim/io_buf[0].IOBUF_inst/O}]
