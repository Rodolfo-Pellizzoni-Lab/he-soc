set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)
source ./config.tcl

create_project eth_dma . -part $partNumber
set_property board_part $boardName [current_project]
create_ip -name axi_dma -vendor xilinx.com -library ip -version $ETH_DMA_IP_VERSION -module_name eth_dma
set_property -dict $ETH_DMA_CONFIG [get_ips eth_dma]
generate_target all [get_files ./eth_dma.srcs/sources_1/ip/eth_dma/eth_dma.xci]
catch { config_ip_cache -export [get_ips -all eth_dma] }
export_ip_user_files -of_objects [get_files ./eth_dma.srcs/sources_1/ip/eth_dma/eth_dma.xci] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] ./eth_dma.srcs/sources_1/ip/eth_dma/eth_dma.xci]
launch_runs -jobs 16 eth_dma_synth_1
wait_on_run eth_dma_synth_1
