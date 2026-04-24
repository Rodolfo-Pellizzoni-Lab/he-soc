onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /hyperbus_tb/axi_i/aw_id
add wave -noupdate /hyperbus_tb/axi_i/aw_addr
add wave -noupdate /hyperbus_tb/axi_i/aw_len
add wave -noupdate /hyperbus_tb/axi_i/aw_size
add wave -noupdate /hyperbus_tb/axi_i/aw_burst
add wave -noupdate /hyperbus_tb/axi_i/aw_lock
add wave -noupdate /hyperbus_tb/axi_i/aw_cache
add wave -noupdate /hyperbus_tb/axi_i/aw_prot
add wave -noupdate /hyperbus_tb/axi_i/aw_qos
add wave -noupdate /hyperbus_tb/axi_i/aw_region
add wave -noupdate /hyperbus_tb/axi_i/aw_user
add wave -noupdate /hyperbus_tb/axi_i/aw_valid
add wave -noupdate /hyperbus_tb/axi_i/aw_ready
add wave -noupdate /hyperbus_tb/axi_i/w_data
add wave -noupdate /hyperbus_tb/axi_i/w_strb
add wave -noupdate /hyperbus_tb/axi_i/w_last
add wave -noupdate /hyperbus_tb/axi_i/w_user
add wave -noupdate /hyperbus_tb/axi_i/w_valid
add wave -noupdate /hyperbus_tb/axi_i/w_ready
add wave -noupdate /hyperbus_tb/axi_i/b_id
add wave -noupdate /hyperbus_tb/axi_i/b_resp
add wave -noupdate /hyperbus_tb/axi_i/b_user
add wave -noupdate /hyperbus_tb/axi_i/b_valid
add wave -noupdate /hyperbus_tb/axi_i/b_ready
add wave -noupdate /hyperbus_tb/axi_i/ar_id
add wave -noupdate /hyperbus_tb/axi_i/ar_addr
add wave -noupdate /hyperbus_tb/axi_i/ar_len
add wave -noupdate /hyperbus_tb/axi_i/ar_size
add wave -noupdate /hyperbus_tb/axi_i/ar_burst
add wave -noupdate /hyperbus_tb/axi_i/ar_lock
add wave -noupdate /hyperbus_tb/axi_i/ar_cache
add wave -noupdate /hyperbus_tb/axi_i/ar_prot
add wave -noupdate /hyperbus_tb/axi_i/ar_qos
add wave -noupdate /hyperbus_tb/axi_i/ar_region
add wave -noupdate /hyperbus_tb/axi_i/ar_user
add wave -noupdate /hyperbus_tb/axi_i/ar_valid
add wave -noupdate /hyperbus_tb/axi_i/ar_ready
add wave -noupdate /hyperbus_tb/axi_i/r_id
add wave -noupdate /hyperbus_tb/axi_i/r_data
add wave -noupdate /hyperbus_tb/axi_i/r_resp
add wave -noupdate /hyperbus_tb/axi_i/r_last
add wave -noupdate /hyperbus_tb/axi_i/r_user
add wave -noupdate /hyperbus_tb/axi_i/r_valid
add wave -noupdate /hyperbus_tb/axi_i/r_ready
add wave -noupdate /hyperbus_tb/wire_rwds
add wave -noupdate /hyperbus_tb/wire_reset_no
add wave -noupdate /hyperbus_tb/wire_dq_io
add wave -noupdate /hyperbus_tb/wire_cs_no
add wave -noupdate /hyperbus_tb/wire_ck_o
add wave -noupdate /hyperbus_tb/wire_ck_no
add wave -noupdate /hyperbus_tb/dut_i/i_inflate/i_deflate/hyper_dq_i
add wave -noupdate /hyperbus_tb/dut_i/i_inflate/i_deflate/hyper_rwds_i
add wave -noupdate /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyper_rwds_i_d
add wave -noupdate -label clk_rwds /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/CTS_8
add wave -noupdate /hyperbus_tb/dut_i/i_inflate/i_deflate/i_hyperbus/config_t_rwds_delay_line
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {150000885 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {157762500 ps}
