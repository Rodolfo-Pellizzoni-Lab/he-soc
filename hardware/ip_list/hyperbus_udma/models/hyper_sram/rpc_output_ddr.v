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
//  File name : rpc_output_ddr.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//////////////////////////////////////////////////////////////////////////////

module rpc_output_ddr (/*AUTOARG*/
   // Outputs
   q,
   // Inputs
   rst, clk0, clk1, en, d0, d1
   );
   input rst;
   
   input clk0;
   input clk1;
   input en;
   input d0;  // data for clk0
   input d1;  // data for clk1
   output q;

`ifdef FPGA
   ODDR2 #(.SRTYPE("ASYNC"), .INIT(1'b1)) oddr2 (.Q(q),
                                                 //input
                                                 .D0(d0),
                                                 .D1(d1),
                                                 .C0(clk0),
                                                 .C1(clk1),
                                                 .CE(en),
                                                 .R(rst),
                                                 .S(1'b0)
                                                 );
`else
   /*AUTOREG*/
   // Beginning of automatic regs (for this module's undeclared outputs)
   reg                  q;
   // End of automatics

   always @(posedge clk0 or posedge rst) begin
      if (rst)
        q <= 1'b0;
      else if (en)
        q <= d0;
   end

   always @(posedge clk1 or posedge rst) begin
      if (rst)
        q <= 1'b0;
      else if (en)
        q <= d1;
   end
`endif
endmodule // rpc_output_ddr
