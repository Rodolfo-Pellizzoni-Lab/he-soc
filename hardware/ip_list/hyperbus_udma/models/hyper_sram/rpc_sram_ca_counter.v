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
//  File name : rpc_sram_ca_counter.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_ca_counter (/*AUTOARG*/
   // Outputs
   ca0_cyc, ca1_cyc, ca2_cyc, data_cyc,
   // Inputs
   if_clk, reset_or_csn
   );
   input if_clk;
   input reset_or_csn;

   output ca0_cyc;
   output ca1_cyc;
   output ca2_cyc;
   output data_cyc;
   
   reg [2:0] counter;

   wire      ca0_cyc;
   wire      ca1_cyc;
   wire      ca2_cyc;
   wire      data_cyc;
   
   assign ca0_cyc = (counter == 3'b001) ? 1'b1 : 1'b0;
   assign ca1_cyc = (counter == 3'b010) ? 1'b1 : 1'b0;
   assign ca2_cyc = (counter == 3'b011) ? 1'b1 : 1'b0;
   assign data_cyc = (counter == 3'b100) ? 1'b1 : 1'b0;
   
   always @(posedge if_clk or posedge reset_or_csn) begin
      if (reset_or_csn)
        counter <= 3'b1;
      else begin
        if (counter < 3'h5)
          counter <= counter + 1'b1;
        else
          counter <= counter;
      end
   end
endmodule // rpc_sram_ca_counter


     
