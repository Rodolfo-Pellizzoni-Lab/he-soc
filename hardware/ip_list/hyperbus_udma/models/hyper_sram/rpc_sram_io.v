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
//  File name : rpc_sram_io.v
//////////////////////////////////////////////////////////////////////////////
//  MODIFICATION HISTORY :
//
//  version:  | author:        |   date:    | changes made:
//    V1.0      yise             13 May 22    Initial release
//    V1.2      yise             14 Apr 30    Supported CK2 option
//////////////////////////////////////////////////////////////////////////////

module rpc_sram_io (
`ifdef CK2
   ck2,
   ck2_n,
`endif
   /*AUTOARG*/
   // Outputs
   rds, if_clk, dq_in, 
   // Inouts
   dq, 
   // Inputs
   ck, ck_n, cs_n, reset, read_ready, dq_out
   );
   input ck;
   input ck_n;
   input cs_n;
   output rds;
   inout [7:0] dq;
`ifdef CK2
   input       ck2;
   input       ck2_n;
`endif
   input       reset;
   
   output      if_clk;

   input       read_ready;
   
   input [15:0] dq_out;
   output [15:0] dq_in;
  
//   input       rd_det;   
//   output      wr_d_clk;
//   output      rd_done;
   
   wire [15:0]   dq_in;
   wire [7:0]    dq_wire;
   
   wire          if_clk = ck_n;
   wire          reset_or_csn = reset | cs_n;
   
   wire          rds_edge_align;

   reg           rdy_en; 
   reg           output_tri;
   reg [7:0]     dq_wire_in;
   
   assign dq_in = {dq_wire_in[7:0], dq[7:0]};
   
   assign rds = (cs_n) ? 1'bz : rds_edge_align;
   assign dq = (output_tri) ? 8'hzz: dq_wire[7:0];
   
   // rdy enable
`ifdef CK2
   reg    read_ready_ff;
   always @(posedge ck or posedge reset_or_csn) begin
      if (reset_or_csn)
        read_ready_ff <= 1'b0;
      else
        read_ready_ff <= read_ready;
   end
   
   always @(posedge ck2_n or posedge reset_or_csn) begin
      if (reset_or_csn)
        rdy_en <= 1'b0;
      else
        rdy_en <= read_ready_ff;
   end
`else
   always @(posedge ck_n or posedge reset_or_csn) begin
      if (reset_or_csn)
        rdy_en <= 1'b0;
      else
        rdy_en <= read_ready;
   end
`endif
   
   // dq output tristate enable
   always @(posedge ck or posedge reset_or_csn) begin
      if (reset_or_csn)
        output_tri <= 1'b1;
      else if (read_ready)
        output_tri <= 1'b0;
   end
   
//   wr_d_clk_delay wr_d_clk_delay (/*AUTOINST*/
//                                // Outputs
//                                .wr_d_clk             (wr_d_clk),
//                                // Inputs
//                                .cs_n                 (cs_n));

//   rd_done_delay rd_done_delay (/*AUTOINST*/
//                              // Outputs
//                              .rd_done        (rd_done),
//                              // Inputs
//                              .cs_n           (cs_n),
//                              .rd_det         (rd_det));
   
   // dq_wire_in
   always @(posedge ck or posedge reset) begin
      if (reset)
        dq_wire_in <= 8'h00;
      else if (~cs_n)
        dq_wire_in <= dq[7:0];
   end

   /* rpc_output_ddr AUTO_TEMPLATE (
    .q(dq_wire[@]),
    .rst(reset),
    .clk0(ck),
    .clk1(ck_n),
    .en(~cs_n),
    .d0(dq_out[@"(+ 8 @)"]),
    .d1(dq_out[@]),
    );
    */
   rpc_output_ddr oddr_0 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[0]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[8]),             // Templated
                          .d1           (dq_out[0]));            // Templated
   rpc_output_ddr oddr_1 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[1]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[9]),             // Templated
                          .d1           (dq_out[1]));            // Templated
   rpc_output_ddr oddr_2 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[2]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[10]),            // Templated
                          .d1           (dq_out[2]));            // Templated
   rpc_output_ddr oddr_3 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[3]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[11]),            // Templated
                          .d1           (dq_out[3]));            // Templated
   rpc_output_ddr oddr_4 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[4]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[12]),            // Templated
                          .d1           (dq_out[4]));            // Templated
   rpc_output_ddr oddr_5 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[5]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[13]),            // Templated
                          .d1           (dq_out[5]));            // Templated
   rpc_output_ddr oddr_6 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[6]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[14]),            // Templated
                          .d1           (dq_out[6]));            // Templated
   rpc_output_ddr oddr_7 (/*AUTOINST*/
                          // Outputs
                          .q            (dq_wire[7]),            // Templated
                          // Inputs
                          .rst          (reset),                 // Templated
                          .clk0         (ck),                    // Templated
                          .clk1         (ck_n),                  // Templated
                          .en           (~cs_n),                 // Templated
                          .d0           (dq_out[15]),            // Templated
                          .d1           (dq_out[7]));            // Templated

`ifdef CK2
   /* rpc_output_ddr AUTO_TEMPLATE (
    .q(rds_edge_align),
    .rst(reset),
    .clk0(ck2),
    .clk1(ck2_n),
    .en(rdy_en),
    .d0(1'b1),
    .d1(1'b0),
    );
    */
   rpc_output_ddr oddr_rds (/*AUTOINST*/
                            // Outputs
                            .q          (rds_edge_align),        // Templated
                            // Inputs
                            .rst        (reset),                 // Templated
                            .clk0       (ck2),                   // Templated
                            .clk1       (ck2_n),                 // Templated
                            .en         (rdy_en),                // Templated
                            .d0         (1'b1),                  // Templated
                            .d1         (1'b0));                         // Templated
`else
   /* rpc_output_ddr AUTO_TEMPLATE (
    .q(rds_edge_align),
    .rst(reset),
    .clk0(ck),
    .clk1(ck_n),
    .en(rdy_en),
    .d0(1'b1),
    .d1(1'b0),
    );
    */
   rpc_output_ddr oddr_rds (/*AUTOINST*/
                            // Outputs
                            .q          (rds_edge_align),        // Templated
                            // Inputs
                            .rst        (reset),                 // Templated
                            .clk0       (ck),                    // Templated
                            .clk1       (ck_n),                  // Templated
                            .en         (rdy_en),                // Templated
                            .d0         (1'b1),                  // Templated
                            .d1         (1'b0));                         // Templated
`endif
endmodule // rpc_sram_io
