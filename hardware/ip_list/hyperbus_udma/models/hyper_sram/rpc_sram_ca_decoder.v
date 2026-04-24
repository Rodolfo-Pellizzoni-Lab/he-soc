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
//  File name : rpc_sram_ca_decoder.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//    V1.1      yise             13 Jul 16    Supported wrap to incr burst
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_ca_decoder (/*AUTOARG*/
   // Outputs
   rd_det, wr_det, target, burst_type, wr_address, rd_address, 
   wr_data_valid, 
   // Inputs
   if_clk, cs_n, dq_in, reset, reset_or_csn, rd_valid, burst_length, 
   wp_n, wrap_incr_burst
   );
   input if_clk;
   input cs_n;
   input [15:0] dq_in;
   input        reset;
   input        reset_or_csn;
   input        rd_valid;
   input [`BURST_LENGTH_BITS-1:0] burst_length;
   input                          wp_n;
   input                          wrap_incr_burst;

   output       rd_det;
   output       wr_det;
   output       target;
   output       burst_type;
   output [`ADDR_BITS-1:0] wr_address;
   output [`ADDR_BITS-1:0] rd_address;
   output wr_data_valid;

   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 ca0_cyc;                // From ca_counter of rpc_sram_ca_counter.v
   wire                 ca1_cyc;                // From ca_counter of rpc_sram_ca_counter.v
   wire                 ca2_cyc;                // From ca_counter of rpc_sram_ca_counter.v
   wire                 data_cyc;               // From ca_counter of rpc_sram_ca_counter.v
   // End of automatics
   wire [`ADDR_BITS-1:0] address;
   wire [`ADDR_BITS-1:0] rd_address;
   wire [`ADDR_BITS-1:0] wr_address;
   wire [`ADDR_BITS-1:0] next_wrap_boundary;
   wire [`ADDR_BITS-1:0] wrap_boundary;
   wire [4:0]            burst_length_mask;
   
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   reg                  burst_type;
   reg                  rd_det;
   reg                  target;
   reg                  wr_data_valid;
   // End of automatics
   reg                  wr_det;
   reg [`PAGE_ADDR_BITS-1:0] page_address;
   reg [`ADDR_BITS-1:0]      rw_counter;
   reg [5:0]                 wrap_counter;
   
   assign address = {page_address, {`WORD_ADDR_BITS{1'b0}}};
   assign rd_address = (burst_type) ? rw_counter : wrap_boundary | (rw_counter & {{(`ADDR_BITS-5){1'b0}}, burst_length_mask});
   assign wr_address = (burst_type) ? rw_counter : wrap_boundary | (rw_counter & {{(`ADDR_BITS-5){1'b0}}, burst_length_mask});
   
   assign burst_length_mask = (burst_length == `BURST_LENGTH_16B) ? 5'b0_0111 :
                              (burst_length == `BURST_LENGTH_32B) ? 5'b0_1111 :
                              (burst_length == `BURST_LENGTH_64B) ? 5'b1_1111 : 5'b1_1111;
   assign next_wrap_boundary = (address + burst_length_mask + 1'b1) & {{(`ADDR_BITS-5){1'b1}}, ~burst_length_mask};
   assign wrap_boundary = address & {{(`ADDR_BITS-5){1'b1}}, ~burst_length_mask};
   
   rpc_sram_ca_counter ca_counter (/*AUTOINST*/
                                   // Outputs
                                   .ca0_cyc(ca0_cyc),
                                   .ca1_cyc(ca1_cyc),
                                   .ca2_cyc(ca2_cyc),
                                   .data_cyc(data_cyc),
                                   // Inputs
                                   .if_clk(if_clk),
                                   .reset_or_csn(reset_or_csn));

   // rd_det
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        rd_det <= 1'b0;
      else if (ca0_cyc && ~cs_n)
        rd_det <= dq_in[`CA0_RW_ADDR_LSB];
   end
   
   // wr_det
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        wr_det <= 1'b0;
      else if (ca0_cyc && ~cs_n)
        wr_det <= ~dq_in[`CA0_RW_ADDR_LSB];
   end
 
   // wr_data_valid
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        wr_data_valid <= 1'b0;
      else if (ca2_cyc && wp_n)
        wr_data_valid <= wr_det;
   end
   
   // page_address
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        page_address <= {`PAGE_ADDR_BITS{1'b0}};
      else if (ca0_cyc && ~cs_n)
        page_address[`PAGE_ADDR_BITS-1:`PAGE_ADDR_BITS-`CA0_PAGE_ADDR_BITS] <= dq_in[`CA0_PAGE_ADDR_MSB:`CA0_PAGE_ADDR_LSB];
      else if (ca1_cyc && ~cs_n)
        page_address[`CA1_PAGE_ADDR_BITS-1:0] <= dq_in[`CA1_PAGE_ADDR_MSB:`CA1_PAGE_ADDR_LSB];
   end

   // wrap_counter
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        wrap_counter <= 6'h0;
      else if (~wrap_incr_burst)
        wrap_counter <= 6'h0;
      else if (ca0_cyc && ~cs_n)
        wrap_counter <= 6'h0;
      else if (ca2_cyc && ~burst_type)
        wrap_counter <= burst_length_mask + 1'b1;
      else if ((rd_valid || wr_data_valid) && |wrap_counter)
        wrap_counter <= wrap_counter - 1'b1;
   end

   // rw_counter
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        rw_counter <= {`ADDR_BITS{1'b0}};
      else if (ca1_cyc)
        rw_counter <= {`ADDR_BITS{1'b0}};
      else if (ca2_cyc)
        rw_counter <= {page_address[`PAGE_ADDR_BITS-1:0], dq_in[`CA2_WORD_ADDR_MSB:`CA2_WORD_ADDR_LSB]};
      else if (wrap_counter == 6'h1)
        rw_counter <= next_wrap_boundary[`ADDR_BITS-1:0];
      else if (wr_data_valid || rd_valid)
        rw_counter <= rw_counter + 1'b1;
   end
 
   // burst_type
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        burst_type <= 1'b0;
      else if (ca0_cyc && ~cs_n)
        burst_type <= dq_in[`CA0_BURST_TYPE_LSB];
      else if (wrap_counter == 6'h1)
        burst_type <= 1'b1;
   end

   // target 0:memory 1:register
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        target <= 1'b0;
      else if (ca0_cyc)
        target <= dq_in[`CA0_TARGET_LSB];
   end
endmodule // rpc_sram_ca_decoder
