# Keep the SGMII receive logic (312.5 MHz) next to its bitslices in SLR1; the placer otherwise drags it into SLR2.
create_pblock pblock_eth_rx
resize_pblock pblock_eth_rx -add {SLICE_X95Y300:SLICE_X135Y419}
add_cells_to_pblock pblock_eth_rx [get_cells {i_alsaqr/i_host_domain/i_cva6_subsystem/i_ariane_peripherals/gen_xilinx_eth.i_xilinx_eth/i_mac/inst/pcs_pma/inst/pcs_pma_block_i/gen_lvds_transceiver*}]
