onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[0]/i_ariane/clk_i}
add wave -noupdate -expand -group {Core0 Signals} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[0]/i_ariane/hart_id_i}
add wave -noupdate -expand -group {Core0 Signals} -color Red {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[0]/i_ariane/irq_i}
add wave -noupdate -expand -group {Core1 Signals} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[1]/i_ariane/boot_addr_i}
add wave -noupdate -expand -group {Core1 Signals} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[1]/i_ariane/hart_id_i}
add wave -noupdate -expand -group {Core1 Signals} -color Blue {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[1]/i_ariane/irq_i}
add wave -noupdate -expand -group {Core2 Signals} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[2]/i_ariane/hart_id_i}
add wave -noupdate -expand -group {Core2 Signals} -color Gold {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[2]/i_ariane/irq_i}
add wave -noupdate -expand -group {Core3 Signals} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[3]/i_ariane/hart_id_i}
add wave -noupdate -expand -group {Core3 Signals} -color {Medium Spring Green} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_wrap/gen_ariane[3]/i_ariane/irq_i}
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/resp_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/cc_re_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/cc_we_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/cc_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/threshold_re_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/threshold_we_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/threshold_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ie_re_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ie_we_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ie_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ip_re_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/prio_re_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/prio_we_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/prio_o
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/req_i
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/cc_i
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/threshold_i
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ie_i
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/ip_i
add wave -noupdate -group {PLIC Regs} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/i_plic_regs/prio_i
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[162]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[161]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[160]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[159]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[158]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[157]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[156]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[155]}
add wave -noupdate -expand -group {PLIC Input Output} {/ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i[9]}
add wave -noupdate -expand -group {PLIC Input Output} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/irq_sources_i
add wave -noupdate -expand -group {PLIC Input Output} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/eip_targets_o
add wave -noupdate -expand -group {PLIC Req Resp} -expand /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/req_i
add wave -noupdate -expand -group {PLIC Req Resp} /ariane_tb/dut/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/i_plic/resp_o
add wave -noupdate -expand -group {PMU CFG Req Resp} /ariane_tb/dut/i_host_domain/i_axi_lite_subsystem/apmu_cfg_resp
add wave -noupdate -expand -group {PMU CFG Req Resp} -subitemconfig {/ariane_tb/dut/i_host_domain/i_axi_lite_subsystem/apmu_cfg_req.aw -expand /ariane_tb/dut/i_host_domain/i_axi_lite_subsystem/apmu_cfg_req.w -expand} /ariane_tb/dut/i_host_domain/i_axi_lite_subsystem/apmu_cfg_req
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{WFI Core1} {2728308000 ps} 1} {{Cursor 2} {3908090000 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 235
configure wave -valuecolwidth 262
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
configure wave -timelineunits ps
update
WaveRestoreZoom {3906495091 ps} {3909944910 ps}
