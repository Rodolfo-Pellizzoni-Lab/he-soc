onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /hyperbus_phy_tb/wire_rwds
add wave -noupdate /hyperbus_phy_tb/wire_reset_no
add wave -noupdate /hyperbus_phy_tb/wire_dq_io
add wave -noupdate /hyperbus_phy_tb/wire_cs_no
add wave -noupdate /hyperbus_phy_tb/wire_ck_o
add wave -noupdate /hyperbus_phy_tb/wire_ck_no
add wave -noupdate /hyperbus_phy_tb/tx_valid_i
add wave -noupdate /hyperbus_phy_tb/tx_ready_o
add wave -noupdate /hyperbus_phy_tb/hyper_dq_o
add wave -noupdate /hyperbus_phy_tb/hyper_cs_no
add wave -noupdate /hyperbus_phy_tb/hyper_ck_o
add wave -noupdate /hyperbus_phy_tb/clk0
add wave -noupdate /hyperbus_phy_tb/dut_i/hyper_trans_state
add wave -noupdate /hyperbus_phy_tb/dut_i/cmd_addr_sel
add wave -noupdate /hyperbus_phy_tb/dut_i/write_strb
add wave -noupdate /hyperbus_phy_tb/dut_i/write_data
add wave -noupdate /hyperbus_phy_tb/dut_i/burst_cnt
add wave -noupdate /hyperbus_phy_tb/tx_valid_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {150435513 ps} 0}
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
WaveRestoreZoom {150417871 ps} {150455911 ps}
