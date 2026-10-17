# AXI DMA for the Xilinx AXI Ethernet subsystem, as the Linux axienet driver expects it: scatter-gather with the
# Ethernet control/status streams, the receive length taken from the status stream, data realignment on both
# channels, 32-bit streams, 64-bit memory side (the SoC xbar width), 32-bit addresses (DRAM is below 4 GB).
# Shared by the FPGA flow (run.tcl) and the xsim flow (hardware/xsim/xilinx_ip.sh).
set ETH_DMA_IP_VERSION 7.1
set ETH_DMA_CONFIG [list \
  CONFIG.c_include_sg {1} \
  CONFIG.c_sg_include_stscntrl_strm {1} \
  CONFIG.c_sg_use_stsapp_length {1} \
  CONFIG.c_sg_length_width {16} \
  CONFIG.c_include_mm2s {1} \
  CONFIG.c_include_s2mm {1} \
  CONFIG.c_include_mm2s_dre {1} \
  CONFIG.c_include_s2mm_dre {1} \
  CONFIG.c_m_axi_mm2s_data_width {64} \
  CONFIG.c_m_axi_s2mm_data_width {64} \
  CONFIG.c_m_axis_mm2s_tdata_width {32} \
  CONFIG.c_s_axis_s2mm_tdata_width {32} \
  CONFIG.c_mm2s_burst_size {16} \
  CONFIG.c_s2mm_burst_size {16} \
  CONFIG.c_addr_width {32} \
]
