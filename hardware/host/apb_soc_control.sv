// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"
`include "common_cells/registers.svh"
`include "apb_macros.sv"

module apb_soc_control
  import apb_soc_pkg::*;
  import control_register_config_reg_pkg::*;
#(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
) (
    input logic          clk_i,
    input logic          rst_ni,
    APB.Slave            apb_slave,
    output logic         cluster_ctrl_rstn_o,
    output logic         cluster_en_sa_boot_o,
    output logic         cluster_fetch_en_o,
    output logic[31:0]   llc_cache_addr_start_o,
    output logic[31:0]   llc_cache_addr_end_o,
    output logic[31:0]   llc_spm_addr_start_o,
    input logic          llc_read_hit_cache_i, 
    input logic          llc_read_miss_cache_i, 
    input logic          llc_write_hit_cache_i, 
    input logic          llc_write_miss_cache_i,
    output logic [1:0]   ot_clk_sel_o,
    output logic [31:0]  ot_clk_div_q_o,
    output logic         ot_clk_div_qe_o,
    output logic         ot_clk_gate_en_o,
    output logic [127:0] cluster_lock_xor_key_o,
    output logic [127:0] iommu_lock_xor_key_o,
    output logic [127:0] iopmp_lock_xor_key_o,
    output logic [127:0] aia_lock_xor_key_o,
    // DRAM timing model (host/axi_dram_timing.sv): configuration and counters, registers at +0x100
    output dram_model_pkg::cfg_t dram_model_cfg_o,
    input  dram_model_pkg::cnt_t dram_model_cnt_i
   );

   // Logic Locking Keys
   logic [127:0] cluster_key_a, iommu_key_a, iopmp_key_a, aia_key_a;
   logic [127:0] cluster_key_b, iommu_key_b, iopmp_key_b, aia_key_b;

   localparam RegAw  = 32;
   localparam RegDw  = 32;
   typedef logic [RegAw-1:0]   reg_addr_t;
   typedef logic [RegDw-1:0]   reg_data_t;
   typedef logic [RegDw/8-1:0] reg_strb_t;
   `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
   `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)
   reg_req_t   reg_req;
   reg_rsp_t   reg_rsp;
   `REG_BUS_ASSIGN_TO_REQ(reg_req,cfg_reg_master)
   `REG_BUS_ASSIGN_FROM_RSP(cfg_reg_master,reg_rsp)
   control_register_config_reg_pkg::control_register_config_reg2hw_t reg2hw_socctrl;
   control_register_config_reg_pkg::control_register_config_hw2reg_t hw2reg_socctrl;

   logic [RegDw-1:0] llc_read_hit_cache_d, llc_read_hit_cache_q;
   logic [RegDw-1:0] llc_read_miss_cache_d, llc_read_miss_cache_q;
   logic [RegDw-1:0] llc_write_hit_cache_d, llc_write_hit_cache_q;
   logic [RegDw-1:0] llc_write_miss_cache_d, llc_write_miss_cache_q;

   logic             s_llc_counter_enable;

   always_comb begin
      llc_read_hit_cache_d = llc_read_hit_cache_q;
      llc_write_hit_cache_d = llc_write_hit_cache_q;
      llc_read_miss_cache_d = llc_read_miss_cache_q;
      llc_write_miss_cache_d = llc_write_miss_cache_q;
      if(llc_read_hit_cache_i && s_llc_counter_enable) begin
         llc_read_hit_cache_d = llc_read_hit_cache_q + 1;
      end
      if(llc_read_miss_cache_i && s_llc_counter_enable) begin
         llc_read_miss_cache_d = llc_read_miss_cache_q + 1;
      end
      if(llc_write_hit_cache_i && s_llc_counter_enable) begin
         llc_write_hit_cache_d = llc_write_hit_cache_q + 1;
      end
      if(llc_write_miss_cache_i && s_llc_counter_enable) begin
         llc_write_miss_cache_d = llc_write_miss_cache_q + 1;
      end
   end

   `FFARN(llc_read_hit_cache_q,llc_read_hit_cache_d, '0, clk_i, rst_ni)
   `FFARN(llc_read_miss_cache_q,llc_read_miss_cache_d, '0, clk_i, rst_ni)
   `FFARN(llc_write_hit_cache_q,llc_write_hit_cache_d, '0, clk_i, rst_ni)
   `FFARN(llc_write_miss_cache_q,llc_write_miss_cache_d, '0, clk_i, rst_ni)

   REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
       ) cfg_reg_master (.clk_i(clk_i));

    apb_to_reg i_apb_to_socctrlcfg
      (
       .clk_i     ( clk_i       ),
       .rst_ni    ( rst_ni      ),

       .penable_i ( apb_slave.penable ),
       .pwrite_i  ( apb_slave.pwrite  ),
       .paddr_i   ( apb_slave.paddr   ),
       .psel_i    ( apb_slave.psel    ),
       .pwdata_i  ( apb_slave.pwdata  ),
       .prdata_o  ( apb_slave.prdata  ),
       .pready_o  ( apb_slave.pready  ),
       .pslverr_o ( apb_slave.pslverr ),

       .reg_o     ( cfg_reg_master    )
      );

   // ---------------------------------------------------------------- DRAM timing model registers, +0x100..+0x1FF
   // The generated block decodes addr[7:0] only, so it gets the requests below +0x100 and this block the others:
   //   0x100 CTRL        bit 0 enable (RW); bit 1 written 1: clear the counters
   //   0x104 LAT_RD      [15:0] target cycles, accepted AR -> first read beat
   //   0x108 LAT_WR      [15:0] target cycles, accepted AW -> write response (plus the burst's bus time)
   //   0x10C OCC16       [15:0] data-bus time per 8-byte beat in 1/16 target cycles (bandwidth; 0 = unlimited)
   //   0x110 RD_COUNT  0x114 WR_COUNT  0x118 RD_LATE  0x11C LATE_CYCLES  0x120 HOLD_CYCLES   read-only
   //   0x124 ID          0xD2A3_0001 read-only (the model is present)
   //   0x128 RD_BEATS    read beats delivered (8 bytes each)
   reg_req_t reg_req_top;
   reg_rsp_t reg_rsp_top;
   logic     dm_sel;
   logic [31:0] dm_rdata;
   dram_model_pkg::cfg_t dm_cfg_q;
   assign dm_sel = reg_req.addr[11:8] == 4'h1;
   always_comb begin
      reg_req_top       = reg_req;
      reg_req_top.valid = reg_req.valid && !dm_sel;
   end
   always_comb begin
      case (reg_req.addr[7:0])
         8'h00:   dm_rdata = {31'b0, dm_cfg_q.enable};
         8'h04:   dm_rdata = {16'b0, dm_cfg_q.lat_rd};
         8'h08:   dm_rdata = {16'b0, dm_cfg_q.lat_wr};
         8'h0C:   dm_rdata = {16'b0, dm_cfg_q.occ16};
         8'h10:   dm_rdata = dram_model_cnt_i.rd_count;
         8'h14:   dm_rdata = dram_model_cnt_i.wr_count;
         8'h18:   dm_rdata = dram_model_cnt_i.rd_late;
         8'h1C:   dm_rdata = dram_model_cnt_i.late_cycles;
         8'h20:   dm_rdata = dram_model_cnt_i.hold_cycles;
         8'h24:   dm_rdata = dram_model_pkg::ID;
         8'h28:   dm_rdata = dram_model_cnt_i.rd_beats;
         default: dm_rdata = '0;
      endcase
   end
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         dm_cfg_q <= '0;
      end else begin
         dm_cfg_q.clear <= 1'b0;
         if (reg_req.valid && dm_sel && reg_req.write) begin
            case (reg_req.addr[7:0])
               8'h00: begin dm_cfg_q.enable <= reg_req.wdata[0]; dm_cfg_q.clear <= reg_req.wdata[1]; end
               8'h04: dm_cfg_q.lat_rd <= reg_req.wdata[15:0];
               8'h08: dm_cfg_q.lat_wr <= reg_req.wdata[15:0];
               8'h0C: dm_cfg_q.occ16  <= reg_req.wdata[15:0];
               default: ;
            endcase
         end
      end
   end
   assign dram_model_cfg_o = dm_cfg_q;
   assign reg_rsp = dm_sel ? reg_rsp_t'{rdata: dm_rdata, error: 1'b0, ready: 1'b1} : reg_rsp_top;

    control_register_config_reg_top  #(
        .reg_req_t (reg_req_t),
        .reg_rsp_t (reg_rsp_t)
    ) i_soc_ctrl (
       .clk_i      ( clk_i           ),
       .rst_ni     ( rst_ni          ),
       .reg_req_i  ( reg_req_top     ),
       .reg_rsp_o  ( reg_rsp_top     ),
       .reg2hw     ( reg2hw_socctrl  ),
       .hw2reg     ( hw2reg_socctrl  ),
       .devmode_i  ( '0              )
   );

   for(genvar i=0;i<4;i++) begin : keysassign
      assign cluster_key_a[(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_cluster_key_a[i].q;
      assign cluster_key_b[(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_cluster_key_b[i].q;
      assign iopmp_key_a  [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_iopmp_key_a[i].q;
      assign iopmp_key_b  [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_iopmp_key_b[i].q;
      assign iommu_key_a  [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_iommu_key_a[i].q;
      assign iommu_key_b  [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_iommu_key_b[i].q;
      assign aia_key_a    [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_aia_key_a[i].q;
      assign aia_key_b    [(i+1)*32 -1 -: 32] = reg2hw_socctrl.logic_locking_aia_key_b[i].q;
   end

   // XOR Logic Locking Keys
   assign cluster_lock_xor_key_o = cluster_key_a ^ cluster_key_b;
   assign iommu_lock_xor_key_o = iommu_key_a ^ iommu_key_b;
   assign iopmp_lock_xor_key_o = iopmp_key_a ^ iopmp_key_b;
   assign aia_lock_xor_key_o = aia_key_a ^ aia_key_b;

   assign cluster_ctrl_rstn_o = reg2hw_socctrl.control_cluster.reset_n.q;
   assign cluster_en_sa_boot_o = reg2hw_socctrl.control_cluster.en_sa_boot.q;
   assign cluster_fetch_en_o = reg2hw_socctrl.control_cluster.fetch_en.q;
   assign llc_cache_addr_start_o = reg2hw_socctrl.llc_cache_addr_start.q;
   assign llc_cache_addr_end_o = reg2hw_socctrl.llc_cache_addr_end.q;
   assign llc_spm_addr_start_o = reg2hw_socctrl.llc_spm_addr_start.q;
   assign s_llc_counter_enable = reg2hw_socctrl.enable_llc_counters.q;

   assign ot_clk_sel_o = reg2hw_socctrl.ot_clk_sel.q;
   assign ot_clk_div_q_o = reg2hw_socctrl.ot_clk_div.q;
   assign ot_clk_div_qe_o = reg2hw_socctrl.ot_clk_div.qe;
   assign ot_clk_gate_en_o = reg2hw_socctrl.ot_clk_gate_en.q;

   assign hw2reg_socctrl.llc_write_hit_cache.de = 1'b1;
   assign hw2reg_socctrl.llc_write_hit_cache.d = llc_write_hit_cache_q;
   assign hw2reg_socctrl.llc_write_miss_cache.de = 1'b1;
   assign hw2reg_socctrl.llc_write_miss_cache.d = llc_write_miss_cache_q;
   assign hw2reg_socctrl.llc_read_hit_cache.de = 1'b1;
   assign hw2reg_socctrl.llc_read_hit_cache.d = llc_read_hit_cache_q;
   assign hw2reg_socctrl.llc_read_miss_cache.de = 1'b1;
   assign hw2reg_socctrl.llc_read_miss_cache.d = llc_read_miss_cache_q;



endmodule
