#######################
# QSPI MASTER 0       #
#######################

# define the clocks at the peripheral output
# SPI MASTER  50MHz

set_dont_touch         [get_cells i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[0].i_spim/u_clockgen/clk_mux_i]
set_case_analysis 0    [get_pins  i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[0].i_spim/u_clockgen/r_clockout_mux_reg/Q]

create_generated_clock [get_pins  i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[0].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q] -name SPIM_CLK_0 -source [get_pins  alsaqr_clk_manager/clk_out1] -divide_by 4
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_0]

#################
## SDIO        ##
#################

create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_sdio_gen[0].i_sdio/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SDIO_CLK_0 -source  [get_pins alsaqr_clk_manager/clk_out1] -divide_by 4
set_clock_groups -asynchronous -group [get_clocks SDIO_CLK_0]

set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_sdio_gen[0].i_sdio/u_clockgen/r_clockout_mux_reg/Q}]

#########################################
## Remaining uDMA SPI / QSPI / SDIO    ##
#########################################

# Each udma_clkgen output is its own clock tree (LUT mux + BUFG). Left
# undeclared it is timed as ALSAQR_CLK with ~3 ns skew. -divide_by 1 so the
# reset-state bypass (div = 0, full 50 MHz) is covered too.
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[1].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[1].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_1 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_1]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[2].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[2].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_2 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_2]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[3].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[3].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_3 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_3]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[4].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[4].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_4 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_4]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[5].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[5].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_5 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_5]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[6].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[6].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_6 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_6]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[7].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[7].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_7 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_7]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[8].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[8].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_8 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_8]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[9].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[9].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_9 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_9]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[10].i_spim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_spim_gen[10].i_spim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SPIM_CLK_10 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SPIM_CLK_10]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_qspim_gen[0].i_qspim/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_qspim_gen[0].i_qspim/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name QSPIM_CLK_0 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks QSPIM_CLK_0]
set_case_analysis 0    [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_sdio_gen[1].i_sdio/u_clockgen/r_clockout_mux_reg/Q}]
create_generated_clock [get_pins {i_alsaqr/i_host_domain/i_apb_subsystem/i_udma_subsystem/i_sdio_gen[1].i_sdio/u_clockgen/i_clkdiv_cnt/clk_o_reg/Q}] -name SDIO_CLK_1 -source [get_pins alsaqr_clk_manager/clk_out1] -divide_by 1
set_clock_groups -asynchronous -group [get_clocks SDIO_CLK_1]
