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
//  File name : rpc_sram_sync_sram.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_sync_sram (/*AUTOARG*/
   // Outputs
   dout,
   // Inputs
   clk, rd_en, rd_addr, wr_en, wr_addr, din
   );
   parameter SRAM_ADDR_BITS = 13;
   parameter SRAM_DATA_WIDTH = 16;
   
   input clk;

   input rd_en;
   input [SRAM_ADDR_BITS-1:0] rd_addr;
   output [SRAM_DATA_WIDTH-1:0] dout;

   input                        wr_en;
   input [SRAM_ADDR_BITS-1:0]   wr_addr;
   input [SRAM_DATA_WIDTH-1:0]  din;

   reg [SRAM_DATA_WIDTH-1:0]    mem[0:(1<<SRAM_ADDR_BITS)-1];
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   reg [SRAM_DATA_WIDTH-1:0] dout;
   // End of automatics

   integer                   i;
   
   initial begin
      for (i = 0; i < (1<<SRAM_ADDR_BITS); i=i+1)
        mem[i] = {SRAM_DATA_WIDTH{1'b1}};
   end
   
   // Read
   always @(posedge clk) begin
      if (rd_en)
        dout <= mem[rd_addr];
   end
   
   // Write
   always @(posedge clk) begin
      if (wr_en)
        mem[wr_addr] <= din[SRAM_DATA_WIDTH-1:0];
   end
endmodule // rpc_sram_sync_sram
