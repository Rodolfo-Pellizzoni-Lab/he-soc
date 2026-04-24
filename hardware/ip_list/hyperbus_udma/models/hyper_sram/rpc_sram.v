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
//  File name : rpc_sram.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//    V1.1      yise             13 Jul 16    Connected rsto_n and int_n port
//                                            Supported wrap to incr burst
//    V1.2      yise             14 Apr 30    Supported CK2 option
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module rpc_sram (
`ifdef CK2
   ck2,
   ck2_n,
`endif
   /*AUTOARG*/
   // Outputs
   rds, int_n, rsto_n, 
   // Inouts
   dq, 
   // Inputs
   ck, ck_n, cs_n, wp_n, hwreset_n
   );
   input                ck;
   input                ck_n;
   input                cs_n;
   input                wp_n;
   input                hwreset_n;
   output               rds;
   inout [7:0]          dq;
   output               int_n;
   output               rsto_n;
`ifdef CK2
   input                ck2;
   input                ck2_n;
`endif
   
//   input [`BURST_LENGTH_BITS-1:0] burst_length;
//   input [`READ_LATENCY_BITS-1:0] read_latency;
   
//   input                        rds_stall_control;
//   input [3:0]                          rds_stall_length;
//   input                        wrap_incr_burst;
   
   /*AUTOINPUT*/
   // Beginning of automatic inputs (from unused autoinst inputs)
   // End of automatics

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [15:0]          dq_in;                  // From rpc_io of rpc_sram_io.v
   wire [15:0]          dq_out;                 // From rpc_logic of rpc_sram_logic.v
   wire                 if_clk;                 // From rpc_io of rpc_sram_io.v
   wire                 read_ready;             // From rpc_logic of rpc_sram_logic.v
   wire                 wr_det;                 // From rpc_logic of rpc_sram_logic.v
   // End of automatics
   wire                 reset = ~hwreset_n;

`ifdef FPGA
   assign               int_n = 1'bz;
`else
   assign               int_n = (wr_det) ? 1'b0: 1'bz;
`endif
   
`ifdef FPGA
   assign               rsto_n = 1'bz;
`else
`ifdef RSTO
   reg                  rsto_n;
   initial begin
      rsto_n = 1'b0;
      #300000; //tVCS
      rsto_n = 1'bz;
   end
`else
   assign rsto_n = (hwreset_n) ? 1'bz: 1'b0;
`endif
`endif

   rpc_sram_io 
     rpc_io (
             `ifdef CK2
             .ck2                       (ck2),
             .ck2_n                     (ck2_n),
             `endif
             /*AUTOINST*/
             // Outputs
             .rds                       (rds),
             .if_clk                    (if_clk),
             .dq_in                     (dq_in[15:0]),
             // Inouts
             .dq                        (dq[7:0]),
             // Inputs
             .ck                        (ck),
             .ck_n                      (ck_n),
             .cs_n                      (cs_n),
             .reset                     (reset),
             .read_ready                (read_ready),
             .dq_out                    (dq_out[15:0]));
   
   rpc_sram_logic
     rpc_logic (/*AUTOINST*/
                // Outputs
                .dq_out                 (dq_out[15:0]),
                .wr_det                 (wr_det),
                .read_ready             (read_ready),
                // Inputs
                .if_clk                 (if_clk),
                .reset                  (reset),
                .cs_n                   (cs_n),
                .dq_in                  (dq_in[15:0]),
                .wp_n                   (wp_n));
   
endmodule // rpc_sram
