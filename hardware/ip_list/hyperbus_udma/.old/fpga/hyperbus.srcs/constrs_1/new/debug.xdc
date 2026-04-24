


create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 3 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_generation_i/inst/clk_phy_0]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {hyperbus_i/phy_i/i_read_clk_rwds/data_o[0]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[1]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[2]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[3]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[4]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[5]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[6]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[7]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[8]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[9]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[10]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[11]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[12]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[13]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[14]} {hyperbus_i/phy_i/i_read_clk_rwds/data_o[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {hyperbus_i/phy_i/data_out[0]} {hyperbus_i/phy_i/data_out[1]} {hyperbus_i/phy_i/data_out[2]} {hyperbus_i/phy_i/data_out[3]} {hyperbus_i/phy_i/data_out[4]} {hyperbus_i/phy_i/data_out[5]} {hyperbus_i/phy_i/data_out[6]} {hyperbus_i/phy_i/data_out[7]} {hyperbus_i/phy_i/data_out[8]} {hyperbus_i/phy_i/data_out[9]} {hyperbus_i/phy_i/data_out[10]} {hyperbus_i/phy_i/data_out[11]} {hyperbus_i/phy_i/data_out[12]} {hyperbus_i/phy_i/data_out[13]} {hyperbus_i/phy_i/data_out[14]} {hyperbus_i/phy_i/data_out[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {hyperbus_i/phy_i/hyper_trans_state[0]} {hyperbus_i/phy_i/hyper_trans_state[1]} {hyperbus_i/phy_i/hyper_trans_state[2]} {hyperbus_i/phy_i/hyper_trans_state[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {hyperbus_i/axi_i\\.ar_len[0]} {hyperbus_i/axi_i\\.ar_len[1]} {hyperbus_i/axi_i\\.ar_len[2]} {hyperbus_i/axi_i\\.ar_len[3]} {hyperbus_i/axi_i\\.ar_len[4]} {hyperbus_i/axi_i\\.ar_len[5]} {hyperbus_i/axi_i\\.ar_len[6]} {hyperbus_i/axi_i\\.ar_len[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe4]
set_property port_width 3 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {hyperbus_i/axi2phy_i/trans_state[0]} {hyperbus_i/axi2phy_i/trans_state[1]} {hyperbus_i/axi2phy_i/trans_state[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {hyperbus_i/axi_i\\.b_resp[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {hyperbus_i/axi_i\\.r_resp[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe7]
set_property port_width 16 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {hyperbus_i/axi_i\\.r_data[0]} {hyperbus_i/axi_i\\.r_data[1]} {hyperbus_i/axi_i\\.r_data[2]} {hyperbus_i/axi_i\\.r_data[3]} {hyperbus_i/axi_i\\.r_data[4]} {hyperbus_i/axi_i\\.r_data[5]} {hyperbus_i/axi_i\\.r_data[6]} {hyperbus_i/axi_i\\.r_data[7]} {hyperbus_i/axi_i\\.r_data[8]} {hyperbus_i/axi_i\\.r_data[9]} {hyperbus_i/axi_i\\.r_data[10]} {hyperbus_i/axi_i\\.r_data[11]} {hyperbus_i/axi_i\\.r_data[12]} {hyperbus_i/axi_i\\.r_data[13]} {hyperbus_i/axi_i\\.r_data[14]} {hyperbus_i/axi_i\\.r_data[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {hyperbus_i/axi_i\\.ar_valid}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {hyperbus_i/axi_i\\.aw_valid}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {hyperbus_i/axi_i\\.r_valid}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list hyperbus_i/hyper_dq_oe_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list hyperbus_i/phy_i/i_read_clk_rwds/hyper_rwds_i]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list hyperbus_i/hyper_rwds_oe_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list hyperbus_i/phy_i/i_read_clk_rwds/read_clk_en_i]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list hyperbus_i/phy_i/read_fifo_rst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list hyperbus_i/phy_i/read_fifo_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list hyperbus_i/phy_i/clock_enable]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list hyperbus_i/phy_i/i_read_clk_rwds/valid_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list hyperbus_i/phy_i/i_read_clk_rwds/ready_i]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_i]
