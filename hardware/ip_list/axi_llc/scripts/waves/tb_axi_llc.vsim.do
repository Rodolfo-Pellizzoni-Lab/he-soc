
log * -r

add wave -position end -label Clock -color "light blue"  sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/clk_i
add wave -position end -label Reset -color "orange"      sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/rst_ni

add wave -position end -divider "AXI SLV"
add wave -position end -label AXI_SLV_REQ -color "pink"  sim:/tb_axi_llc/i_axi_llc_dut/slv_req_i
add wave -position end -label AXI_SLV_RESP -color "pink" sim:/tb_axi_llc/i_axi_llc_dut/slv_resp_o

add wave -position end -divider "AXI MST"
add wave -position end -label AXI_MST_REQ  sim:/tb_axi_llc/i_axi_llc_dut/mst_req_o
add wave -position end -label AXI_MST_RESP sim:/tb_axi_llc/i_axi_llc_dut/mst_resp_i

add wave -position end -divider "AXI CFG"
add wave -position end -label AXI_MST_REQ  sim:/tb_axi_llc/i_axi_llc_dut/conf_req_i
add wave -position end -label AXI_MST_RESP sim:/tb_axi_llc/i_axi_llc_dut/conf_resp_o

add wave -position end -divider "DESC"
add wave -position end -label "rw_desc"       sim:/tb_axi_llc/i_axi_llc_dut/rw_desc
add wave -position end -label "rw_desc_valid" sim:/tb_axi_llc/i_axi_llc_dut/rw_desc_valid
add wave -position end -label "rw_desc_ready" sim:/tb_axi_llc/i_axi_llc_dut/rw_desc_ready

add wave -position end -divider "DESC"
add wave -position end -label "desc"       sim:/tb_axi_llc/i_axi_llc_dut/desc
add wave -position end -label "hit_valid" sim:/tb_axi_llc/i_axi_llc_dut/hit_valid
add wave -position end -label "hit_ready" sim:/tb_axi_llc/i_axi_llc_dut/hit_ready
add wave -position end -label "miss_valid" sim:/tb_axi_llc/i_axi_llc_dut/miss_valid
add wave -position end -label "miss_ready" sim:/tb_axi_llc/i_axi_llc_dut/miss_ready



add wave -position end -divider "RAM"
add wave -position end -label "way_inp"       sim:/tb_axi_llc/i_axi_llc_dut/to_way
add wave -position end -label "way_inp_valid" sim:/tb_axi_llc/i_axi_llc_dut/to_way_valid
add wave -position end -label "way_inp_ready" sim:/tb_axi_llc/i_axi_llc_dut/to_way_ready
add wave -position end -label "evict_way_out"       sim:/tb_axi_llc/i_axi_llc_dut/evict_way_out
add wave -position end -label "evict_way_out_valid" sim:/tb_axi_llc/i_axi_llc_dut/evict_way_out_valid
add wave -position end -label "read_way_out"        sim:/tb_axi_llc/i_axi_llc_dut/read_way_out
add wave -position end -label "read_way_out_valid"  sim:/tb_axi_llc/i_axi_llc_dut/read_way_out_valid



add wave -position end -divider "RAM CONTENT"
add wave -position end -label "inp_valid_dist" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/way_inp_valid

add wave -position end -label "out_dist" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/way_out
add wave -position end -label "out_valid_dist" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/way_out_valid

#add wave -position end -label "Way7: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[7]/i_data_way/i_data_sram/ram

#add wave -position end -label "Way6: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[6]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way5: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[5]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way4: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[4]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way3: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[3]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way2: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[2]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way1: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[1]/i_data_way/i_data_sram/ram
#add wave -position end -label "Way0: RAM" sim:/tb_axi_llc/i_axi_llc_dut/i_llc_ways/genblk2[0]/i_data_way/i_data_sram/ram





add wave -position end -divider "AXI ISOLATE"
add wave -position end -label "Isolate_IN_slv_req_i"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_isolate_flush/slv_req_i
add wave -position end -label "Isolate_OUT_demux_req"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_isolate_flush/mst_req_o
add wave -position end -label "LLC_Isolate_i"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_isolate_flush/isolate_i
add wave -position end -label "LLC_Isolated_o"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_isolate_flush/isolated_o


add wave -position end -divider "AXI DEMUX"
add wave -position end -label "DEMUX_IN_slv_req_i"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_bypass_demux/slv_req_i
add wave -position end -label "DEMUX_Control_AW"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_bypass_demux/slv_aw_select_i
add wave -position end -label "DEMUX_Control_AR"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_bypass_demux/slv_ar_select_i
add wave -position end -label "DEMUX_OUT_mst_reqs_o"       sim:/tb_axi_llc/i_axi_llc_dut/i_axi_bypass_demux/mst_reqs_o


add wave -position end -divider "AXI AW CHAN SPLITTER"
add wave -position end -label "SPLIT_AW"       sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/ax_chan_slv_i
add wave -position end -label "SPLIT_AW_VALID"       sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/ax_chan_valid_i
add wave -position end -label "SPLIT_AW_READY"       sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/ax_chan_ready_o
add wave -position end -label "SPLIT_DESC_O"       sim:/tb_axi_llc/i_axi_llc_dut/i_aw_splitter/desc_o


add wave -position end -divider "AXI AR CHAN SPLITTER"
add wave -position end -label "SPLIT_AR"       sim:/tb_axi_llc/i_axi_llc_dut/i_ar_splitter/ax_chan_slv_i
add wave -position end -label "SPLIT_AR_VALID"       sim:/tb_axi_llc/i_axi_llc_dut/i_ar_splitter/ax_chan_valid_i
add wave -position end -label "SPLIT_AR_READY"       sim:/tb_axi_llc/i_axi_llc_dut/i_ar_splitter/ax_chan_ready_o
add wave -position end -label "SPLIT_DESC_O"       sim:/tb_axi_llc/i_axi_llc_dut/i_ar_splitter/desc_o



add wave -position end -divider "RR_ARB_COMBINE"
add wave -position end -label "RR_ARB_OUT"       sim:/tb_axi_llc/i_axi_llc_dut/i_rw_arb_tree/data_o


add wave -position end -divider "SPILL_REGISTER"
add wave -position end -label "SPILL_REG"       sim:/tb_axi_llc/i_axi_llc_dut/i_rw_spill/data_o







add wave -position end -divider "HIT MISS UNIT"
add wave -position end -label "Desc_i_ID"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/desc_i.a_x_id
add wave -position end -label "Desc_valid_i"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/valid_i
add wave -position end -label "Sel_Bits"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/temp_bitmask
add wave -position end -label "Locked_Conf_Reg"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/id_bitmask_i
add wave -position end -label "Lock_Select"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/axiID_bitmask
add wave -position end -label "Spm_Lock"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/spm_lock_i
add wave -position end -label "Total_Lock"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/total_lock_i




add wave -position end -divider "HIT MISS DETECTION"
add wave -position end -label "Desc_to_Tag_Store"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/store_req
add wave -position end -label "tag_store_req_q"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/req_q
add wave -position end -label "tag_store_hit_req"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/hit_req
add wave -position end -label "tag_Store_hit_inp"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/hit_inp
add wave -position end -label "tag_store_evict_req"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/evict_req
add wave -position end -label "tag_store_bist_req"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/bist_req
add wave -position end -label "total_lock_i"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/total_lock_i
add wave -position end -label "plru_out_way_ind"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/i_evict_box/way_ind_o
add wave -position end -label "plru_valid_o"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/i_evict_box/valid_o
add wave -position end -label "plru_valid_o_pl"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/i_evict_box/valid_o_plru
add wave -position end -label "plru_evict_o"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/i_tag_store/i_evict_box/evict_o
add wave -position end -label "Desc_from_Tag_Store"       sim:/tb_axi_llc/i_axi_llc_dut/i_hit_miss_unit/store_res




run 61ns
#mem load -i /scratch/msc19f10/llc/umcL65/modelsim/scripts/memcontent/main.mem -format mti -startaddress 4095 -endaddress 0 /tb_axi_llc/i_memory/ram

