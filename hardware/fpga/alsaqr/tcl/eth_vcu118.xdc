# VCU118 on-board 1G Ethernet (TI DP83867, SGMII over LVDS), for the Xilinx AXI Ethernet subsystem
# (hardware/host/xilinx_eth_subsys.sv, XILINX_ETHERNET). Pins and standards from the board file
# (vcu118 part0_pins.xml): DIFF_HSTL_I_DCI_18 lanes in an HP bank with 0.9 V internal VREF, LVDS 625 MHz PHY clock.
set_property PACKAGE_PIN AU24 [get_ports xeth_sgmii_rxp]
set_property PACKAGE_PIN AV24 [get_ports xeth_sgmii_rxn]
set_property PACKAGE_PIN AU21 [get_ports xeth_sgmii_txp]
set_property PACKAGE_PIN AV21 [get_ports xeth_sgmii_txn]
set_property IOSTANDARD DIFF_HSTL_I_DCI_18 [get_ports {xeth_sgmii_rxp xeth_sgmii_rxn xeth_sgmii_txp xeth_sgmii_txn}]
set_property ODT RTT_48 [get_ports {xeth_sgmii_rxp xeth_sgmii_rxn}]
set_property OUTPUT_IMPEDANCE RDRV_48_48 [get_ports {xeth_sgmii_txp xeth_sgmii_txn}]
set_property INTERNAL_VREF 0.90 [get_iobanks -of_objects [get_package_pins AU24]]

set_property PACKAGE_PIN AT22 [get_ports xeth_lvds_clk_p]
set_property PACKAGE_PIN AU22 [get_ports xeth_lvds_clk_n]
set_property IOSTANDARD LVDS [get_ports {xeth_lvds_clk_p xeth_lvds_clk_n}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {xeth_lvds_clk_p xeth_lvds_clk_n}]

set_property PACKAGE_PIN AV23 [get_ports xeth_mdc]
set_property PACKAGE_PIN AR23 [get_ports xeth_mdio]
set_property PACKAGE_PIN BA21 [get_ports xeth_phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports {xeth_mdc xeth_mdio xeth_phy_rst_n}]

# The IP constrains the 625 MHz clock on its own port (create_clock on refclk625_p, scoped) and derives its
# 312.5/125 MHz clocks from it; they are all asynchronous to the SoC clock (AXI side) and to the DDR clocks.
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks -of_objects [get_ports xeth_lvds_clk_p]]
