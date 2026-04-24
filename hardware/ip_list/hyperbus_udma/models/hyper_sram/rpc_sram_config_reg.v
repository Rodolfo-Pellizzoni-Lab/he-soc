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
//  File name : rpc_sram_config_reg.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             14 Jan 10    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_config_reg (/*AUTOARG*/
   // Outputs
   reg_dout, burst_length, read_latency, wrap_incr_burst, 
   rds_stall_control, rds_stall_length, 
   // Inputs
   if_clk, reset, wr_data_valid, dq_in, rd_valid
   );
   input if_clk;
   input reset;
   
   // write
   input wr_data_valid;
   input [15:0] dq_in;
   // read
   input        rd_valid;
   output [15:0] reg_dout;

   output [`BURST_LENGTH_BITS-1:0]burst_length;
   output [`READ_LATENCY_BITS-1:0]read_latency;
   output                         wrap_incr_burst;
   output                         rds_stall_control;
   output [3:0]                   rds_stall_length;
   
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   reg [15:0]           reg_dout;
   // End of automatics
   reg [15:0]    config_register;

   assign        burst_length = config_register[1:0];
   assign        wrap_incr_burst = ~config_register[2];
   assign        read_latency = config_register[7:4];
   assign        rds_stall_control = ~config_register[15];
   assign        rds_stall_length = config_register[11:8];
   
   // write
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        config_register <= 16'h8FB7;
      else if (wr_data_valid)
        config_register <= dq_in;
   end

   // read
   always @(posedge if_clk or posedge reset) begin
      if (reset)
        reg_dout <= 16'h0000;
      else if (rd_valid)
        reg_dout <= config_register;
   end

endmodule // rpc_sram_config_reg
