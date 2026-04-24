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
//  File name : rpc_sram_read_latency_control.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_read_latency_control (/*AUTOARG*/
   // Outputs
   read_ready, pre_read_ready, 
   // Inputs
   if_clk, reset_or_csn, rd_det, burst_type, read_latency, 
   rds_stall_control, rds_stall_length
   );
   input if_clk;
   input reset_or_csn;
   input rd_det;
   input burst_type;
   input [`READ_LATENCY_BITS-1:0] read_latency;
   
   input rds_stall_control;
   input [3:0] rds_stall_length;
   
   output                         read_ready;
   output                         pre_read_ready;
   
   reg                            read_ready;
   reg [4:0]                      down_counter;

   reg [3:0]                      stall_count;
   
   wire                           pre_read_ready;
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 latency_cyc;            // From latency_counter of rpc_sram_latency_counter.v
   // End of automatics
   
   
   assign pre_read_ready = (down_counter != 0) ? 1'b1 : 1'b0;

   rpc_sram_latency_counter 
     latency_counter (/*AUTOINST*/
                      // Outputs
                      .latency_cyc      (latency_cyc),
                      // Inputs
                      .if_clk           (if_clk),
                      .reset_or_csn     (reset_or_csn),
                      .rd_det           (rd_det),
                      .read_latency     (read_latency[`READ_LATENCY_BITS-1:0]));
   
/*
   // read_ready
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        read_ready <= 1'b0;
      else
        read_ready <= pre_read_ready;
   end
*/
   // support RDS stall
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        stall_count <= 4'h0;
      else if (pre_read_ready && ~(&stall_count))
        stall_count <= stall_count + 1'b1;
   end

   // read_ready
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        read_ready <= 1'b0;
      else if (rds_stall_control && (stall_count >= rds_stall_length))
        read_ready <= 1'b0;
      else
        read_ready <= pre_read_ready;
   end
        
   // down_counter
   always @(posedge if_clk or posedge reset_or_csn) begin
     if (reset_or_csn)
       down_counter <= 5'b0_0000;
     else if (latency_cyc)
        down_counter <= 16;
     else if ((down_counter != 0) && (burst_type))
       down_counter <= down_counter - 1'b1;
   end
endmodule // rpc_sram_read_latency_countrol
