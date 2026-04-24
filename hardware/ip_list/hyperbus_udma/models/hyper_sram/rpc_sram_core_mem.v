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
//  File name : rpc_sram_core_mem.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_core_mem (/*AUTOARG*/
   // Outputs
   dq_out, 
   // Inputs
   if_clk, wr_data_valid, dq_in, wr_address, pre_read_ready, 
   rd_address
   );
//   input reset;
   input if_clk;
   
   // write
   input wr_data_valid;
   input [15:0] dq_in;
   input [`ADDR_BITS-1:0] wr_address;
   // read
   input                  pre_read_ready;
   input [`ADDR_BITS-1:0] rd_address;

   output [15:0]          dq_out;

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [15:0]          dout;                   // From sync_sram of rpc_sram_sync_sram.v
   // End of automatics
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   reg [15:0]           dq_out;
   // End of automatics
   

   always @(posedge if_clk) begin
      dq_out <= dout[15:0];
   end
   
   /* rpc_sram_sync_sram AUTO_TEMPLATE (
    .dout(dout[15:0]),
    .clk(if_clk),
    .rd_en(pre_read_ready),
    .rd_addr(rd_address[`CORE_MEM_ADDR_BITS-1:0]),
    .wr_en(wr_data_valid),
    .wr_addr(wr_address[`CORE_MEM_ADDR_BITS-1:0]),
    .din(dq_in[15:0]),
    );
    */
   rpc_sram_sync_sram #(`CORE_MEM_ADDR_BITS,
                        16
               ) sync_sram (/*AUTOINST*/
                            // Outputs
                            .dout       (dout[15:0]),            // Templated
                            // Inputs
                            .clk        (if_clk),                // Templated
                            .rd_en      (pre_read_ready),        // Templated
                            .rd_addr    (rd_address[`CORE_MEM_ADDR_BITS-1:0]), // Templated
                            .wr_en      (wr_data_valid),         // Templated
                            .wr_addr    (wr_address[`CORE_MEM_ADDR_BITS-1:0]), // Templated
                            .din        (dq_in[15:0]));          // Templated

endmodule // rpc_sram_core_mem
