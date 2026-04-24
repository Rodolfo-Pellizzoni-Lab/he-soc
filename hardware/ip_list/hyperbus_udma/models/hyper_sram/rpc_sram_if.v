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
//  File name : rpc_sram_if.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//    V1.1      yise             13 Jul 16    Supported wrap to incr burst
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_if (/*AUTOARG*/
   // Outputs
   wr_det, target, rd_valid, wr_data_valid, rd_address, wr_address, 
   read_ready, 
   // Inputs
   cs_n, wp_n, reset, reset_or_csn, if_clk, dq_in, burst_length, 
   read_latency, wrap_incr_burst, rds_stall_control, 
   rds_stall_length
   );
   input cs_n;
   input wp_n;
   
   input  reset;
   input  reset_or_csn;
   
   input  if_clk;
   input [15:0] dq_in;
   
   input [`BURST_LENGTH_BITS-1:0] burst_length;
   input [`READ_LATENCY_BITS-1:0] read_latency;
   input                          wrap_incr_burst;
   
   input                          rds_stall_control;
   input [3:0]                    rds_stall_length;

   output      wr_det;
   output      target;
   output      rd_valid;
   output      wr_data_valid;
   output [`ADDR_BITS-1:0] rd_address;
   output [`ADDR_BITS-1:0] wr_address;

//   output                rdy_en;
//   output                  output_tri;
   output                  read_ready;
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 burst_type;             // From ca_decoder of rpc_sram_ca_decoder.v
   wire                 pre_read_ready;         // From read_latency_control of rpc_sram_read_latency_control.v
   wire                 rd_det;                 // From ca_decoder of rpc_sram_ca_decoder.v
   // End of automatics
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   // End of automatics
   wire                 rd_valid;

   assign               rd_valid = pre_read_ready;
   
/*
   // rdy_en
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        rdy_en <= 1'b0;
      else
        rdy_en <= read_ready;
   end
   
   // output_tri
   always @(negedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        output_tri <= 1'b1;
      else if (read_ready)
        output_tri <= 1'b0;
   end
*/
   
   rpc_sram_ca_decoder
     ca_decoder (/*AUTOINST*/
                 // Outputs
                 .rd_det                (rd_det),
                 .wr_det                (wr_det),
                 .target                (target),
                 .burst_type            (burst_type),
                 .wr_address            (wr_address[`ADDR_BITS-1:0]),
                 .rd_address            (rd_address[`ADDR_BITS-1:0]),
                 .wr_data_valid         (wr_data_valid),
                 // Inputs
                 .if_clk                (if_clk),
                 .cs_n                  (cs_n),
                 .dq_in                 (dq_in[15:0]),
                 .reset                 (reset),
                 .reset_or_csn          (reset_or_csn),
                 .rd_valid              (rd_valid),
                 .burst_length          (burst_length[`BURST_LENGTH_BITS-1:0]),
                 .wp_n                  (wp_n),
                 .wrap_incr_burst       (wrap_incr_burst));

   rpc_sram_read_latency_control 
     read_latency_control (/*AUTOINST*/
                           // Outputs
                           .read_ready  (read_ready),
                           .pre_read_ready(pre_read_ready),
                           // Inputs
                           .if_clk      (if_clk),
                           .reset_or_csn(reset_or_csn),
                           .rd_det      (rd_det),
                           .burst_type  (burst_type),
                           .read_latency(read_latency[`READ_LATENCY_BITS-1:0]),
                           .rds_stall_control(rds_stall_control),
                           .rds_stall_length(rds_stall_length[3:0]));


endmodule // rpc_sram_if

