/**************************************************************************
* Copyright (C)2013-2014 Spansion LLC All Rights Reserved. 
*
* This source code is owned and published by: 
* Spansion LLC 915 DeGuigne Dr. Sunnyvale, CA  94088-3453 ("Spansion").
*
* BY INSTALLING OR USING THIS HYPERBUS MASTER CONTROLLER RTL SOURCE CODE, 
* YOU AGREE TO BE BOUND BY ALL THE TERMS AND CONDITIONS SET FORTH IN SPANSION 
* LICENSE AGREEMENT AND BELOW.
*
* This source code is licensed by Spansion to be adapted only 
* for use in the development of HyperBus Master Controller. Spansion is not
* responsible for misuse or illegal use of this source code.  Spansion is 
* providing this source code "AS IS" and will not be responsible for issues 
* arising from incorrect user implementation of the source code herein.  
*
* SPANSION MAKES NO WARRANTY, EXPRESS OR IMPLIED, ARISING BY LAW OR OTHERWISE, 
* REGARDING THE SOURCE CODE, ITS PERFORMANCE OR SUITABILITY FOR YOUR INTENDED 
* USE, INCLUDING, WITHOUT LIMITATION, NO IMPLIED WARRANTY OF MERCHANTABILITY, 
* FITNESS FOR A  PARTICULAR PURPOSE OR USE, OR NONINFRINGEMENT.  SPANSION WILL 
* HAVE NO LIABILITY (WHETHER IN CONTRACT, WARRANTY, TORT, NEGLIGENCE OR 
* OTHERWISE) FOR ANY DAMAGES ARISING FROM USE OR INABILITY TO USE THE SOURCE CODE, 
* INCLUDING, WITHOUT LIMITATION, ANY DIRECT, INDIRECT, INCIDENTAL, 
* SPECIAL, OR CONSEQUENTIAL DAMAGES OR LOSS OF DATA, SAVINGS OR PROFITS, 
* EVEN IF SPANSION HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.  
*
* This source code may be replicated in part or whole for the licensed use, 
* with the restriction that this Copyright notice must be included with 
* this source code, whether used in part or whole, at all times.  
*/
//////////////////////////////////////////////////////////////////////////////
//  File name : rpc_sram_logic.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////
module rpc_sram_logic (/*AUTOARG*/
   // Outputs
   dq_out, wr_det, read_ready, 
   // Inputs
   if_clk, reset, cs_n, dq_in, wp_n
   );
   input                if_clk;
   input                reset;
   input                cs_n;
   input [15:0]         dq_in;
   input                wp_n;

   //   input [`BURST_LENGTH_BITS-1:0]burst_length;
   //   input [`READ_LATENCY_BITS-1:0]read_latency;
   //   input           rds_stall_control;
   //   input [3:0]     rds_stall_length;
   //   input           wrap_incr_burst;
   /*AUTOINPUT*/
   // Beginning of automatic inputs (from unused autoinst inputs)
   // End of automatics

   output [15:0]        dq_out;
//   output             output_tri;
//   output             rdy_en;
   output               wr_det;
   output               read_ready;

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`BURST_LENGTH_BITS-1:0]burst_length;   // From config_reg of rpc_sram_config_reg.v
   wire [`ADDR_BITS-1:0]rd_address;             // From rpc_if of rpc_sram_if.v
   wire                 rd_valid;               // From rpc_if of rpc_sram_if.v
   wire                 rds_stall_control;      // From config_reg of rpc_sram_config_reg.v
   wire [3:0]           rds_stall_length;       // From config_reg of rpc_sram_config_reg.v
   wire [`READ_LATENCY_BITS-1:0]read_latency;   // From config_reg of rpc_sram_config_reg.v
   wire                 target;                 // From rpc_if of rpc_sram_if.v
   wire [`ADDR_BITS-1:0]wr_address;             // From rpc_if of rpc_sram_if.v
   wire                 wr_data_valid;          // From rpc_if of rpc_sram_if.v
   wire                 wrap_incr_burst;        // From config_reg of rpc_sram_config_reg.v
   // End of automatics
   wire                 reset_or_csn;
   wire                 pre_read_ready;
   wire [15:0]          mem_dout;
   wire [15:0]          reg_dout;
   wire                 mem_wr_en = wr_data_valid&~target;
   wire                 reg_wr_en = wr_data_valid&target;
   
   assign               reset_or_csn = reset | cs_n;
   assign               pre_read_ready = rd_valid;
   assign               dq_out = (target) ? reg_dout[15:0]: mem_dout[15:0];
   
   rpc_sram_if
     rpc_if (/*AUTOINST*/
             // Outputs
             .wr_det                    (wr_det),
             .target                    (target),
             .rd_valid                  (rd_valid),
             .wr_data_valid             (wr_data_valid),
             .rd_address                (rd_address[`ADDR_BITS-1:0]),
             .wr_address                (wr_address[`ADDR_BITS-1:0]),
             .read_ready                (read_ready),
             // Inputs
             .cs_n                      (cs_n),
             .wp_n                      (wp_n),
             .reset                     (reset),
             .reset_or_csn              (reset_or_csn),
             .if_clk                    (if_clk),
             .dq_in                     (dq_in[15:0]),
             .burst_length              (burst_length[`BURST_LENGTH_BITS-1:0]),
             .read_latency              (read_latency[`READ_LATENCY_BITS-1:0]),
             .wrap_incr_burst           (wrap_incr_burst),
             .rds_stall_control         (rds_stall_control),
             .rds_stall_length          (rds_stall_length[3:0]));

   /* rpc_sram_core_mem AUTO_TEMPLATE (
    .dq_out(mem_dout[15:0]),
    .wr_data_valid(mem_wr_en),
    );
    */
   rpc_sram_core_mem
     core_mem (/*AUTOINST*/
               // Outputs
               .dq_out                  (mem_dout[15:0]),        // Templated
               // Inputs
               .if_clk                  (if_clk),
               .wr_data_valid           (mem_wr_en),             // Templated
               .dq_in                   (dq_in[15:0]),
               .wr_address              (wr_address[`ADDR_BITS-1:0]),
               .pre_read_ready          (pre_read_ready),
               .rd_address              (rd_address[`ADDR_BITS-1:0]));

   /* rpc_sram_config_reg AUTO_TEMPLATE (
    .wr_data_valid(reg_wr_en),
    );
    */
   rpc_sram_config_reg
     config_reg (/*AUTOINST*/
                 // Outputs
                 .reg_dout              (reg_dout[15:0]),
                 .burst_length          (burst_length[`BURST_LENGTH_BITS-1:0]),
                 .read_latency          (read_latency[`READ_LATENCY_BITS-1:0]),
                 .wrap_incr_burst       (wrap_incr_burst),
                 .rds_stall_control     (rds_stall_control),
                 .rds_stall_length      (rds_stall_length[3:0]),
                 // Inputs
                 .if_clk                (if_clk),
                 .reset                 (reset),
                 .wr_data_valid         (reg_wr_en),             // Templated
                 .dq_in                 (dq_in[15:0]),
                 .rd_valid              (rd_valid));
   
endmodule // rpc_sram_logic
