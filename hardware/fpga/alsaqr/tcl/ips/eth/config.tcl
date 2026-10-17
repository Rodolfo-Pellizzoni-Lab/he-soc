# AXI 1G Ethernet Subsystem for the VCU118's on-board DP83867: SGMII over LVDS (HP bank, no transceiver), the
# 625 MHz clock from the PHY, MDIO and PHY reset through the board interfaces, AXI side on the 50 MHz SoC clock.
# The board preset (sgmii_over_lvds_preset) fixes the lane placement. Needs the tri_mode_eth_mac license key.
set ETH_IP_VERSION 7.2
set ETH_CONFIG [list \
  CONFIG.PHY_TYPE {SGMII} \
  CONFIG.ENABLE_LVDS {true} \
  CONFIG.lvdsclkrate {625} \
  CONFIG.tx_in_upper_nibble {false} \
  CONFIG.rxnibblebitslice0used {false} \
  CONFIG.txlane0_placement {DIFF_PAIR_2} \
  CONFIG.rxlane0_placement {DIFF_PAIR_0} \
  CONFIG.ETHERNET_BOARD_INTERFACE {sgmii_lvds} \
  CONFIG.DIFFCLK_BOARD_INTERFACE {sgmii_phyclk} \
  CONFIG.MDIO_BOARD_INTERFACE {mdio_mdc} \
  CONFIG.PHYRST_BOARD_INTERFACE {phy_reset_out} \
  CONFIG.USE_BOARD_FLOW {true} \
  CONFIG.axiliteclkrate {50.0} \
  CONFIG.axisclkrate {50.0} \
  CONFIG.RXMEM {8k} \
  CONFIG.TXMEM {8k} \
  CONFIG.Statistics_Counters {true} \
]
