set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)
source ./config.tcl

create_project eth_sgmii . -part $partNumber
set_property board_part $boardName [current_project]
create_ip -name axi_ethernet -vendor xilinx.com -library ip -version $ETH_IP_VERSION -module_name eth_sgmii
set_property -dict $ETH_CONFIG [get_ips eth_sgmii]
generate_target all [get_files ./eth_sgmii.srcs/sources_1/ip/eth_sgmii/eth_sgmii.xci]
catch { config_ip_cache -export [get_ips -all eth_sgmii] }
export_ip_user_files -of_objects [get_files ./eth_sgmii.srcs/sources_1/ip/eth_sgmii/eth_sgmii.xci] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] ./eth_sgmii.srcs/sources_1/ip/eth_sgmii/eth_sgmii.xci]
launch_runs -jobs 16 eth_sgmii_synth_1
wait_on_run eth_sgmii_synth_1
