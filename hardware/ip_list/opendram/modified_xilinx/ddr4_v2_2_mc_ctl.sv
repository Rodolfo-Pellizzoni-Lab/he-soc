/******************************************************************************
// (c) Copyright 2013 - 2014 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
******************************************************************************/
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 1.1
//  \   \         Application        : MIG
//  /   /         Filename           : ddr4_v2_2_14_mc_ctl.sv
// /___/   /\     Date Last Modified : $Date: 2014/09/03 $
// \   \  /  \    Date Created       : Thu Apr 18 2013
//  \___\/\___\
//
// Device           : UltraScale
// Design Name      : DDR4 SDRAM & DDR3 SDRAM
// Purpose          :
//                   ddr4_v2_2_14_mc_ctl module
// Reference        :
// Revision History :
//*****************************************************************************

`timescale 1ns/100ps

`include "global.svh"

`ifdef USE_RELATIVE_PATH_INCLUDES
   `include "ddr4_v2_2_cal_mc_odt.sv"
`endif // `ifdef USE_RELATIVE_PATH_INCLUDES

module ddr4_v2_2_14_mc_ctl #(parameter
    RANKS = 1			   
   ,RANK_SLOT = 1
   ,RKBITS = 2
   ,RANK_SLAB = 4
   ,ABITS = 18
   ,BABITS = 2
   ,BGBITS = 2
   ,S_HEIGHT = 1
   ,LR_WIDTH = 1
   ,CKEBITS = 4
   ,COLBITS = 10
   ,CSBITS = 4
   ,ODTBITS = 4
   ,tCCD_3ds = 4         // read to read and write to write, to different group, at speed great than 1866 requires 5 nCK
   ,MR6      = 13'b0_1000_0000_0000
   ,MEM = "DDR4"
   ,NOP_ADD_LOW = 1'b1
   ,tCK         = 938
   ,CLAMSHELL = "OFF"
   ,REG_CTRL  = "OFF"

   ,ODTWR = 16'h8421
   ,ODTWRDEL = 5'd9
   ,ODTWRDUR = 4'd6
   ,ODTWRODEL = 5'd9
   ,ODTWRODUR = 4'd6

   ,ODTRD = 16'h0000
   ,ODTRDDEL = 5'd9
   ,ODTRDDUR = 4'd6
   ,ODTRDODEL = 5'd9
   ,ODTRDODUR = 4'd6

   ,ODTNOP = 4'b0000
   ,TCQ        = 0.1   

   ,CMD_WIDTH  =  3
   ,CH_WIDTH   =  1
   ,RNK_WIDTH  =  1
   ,LRNK_WIDTH =  1
   ,BG_WIDTH   =  2
   ,BNK_WIDTH  =  2
   ,ROW_WIDTH  =  15
   ,COL_WIDTH  =  10

)(
    input clk
   ,input rst

   ,output reg           [7:0] mc_ACT_n
   ,output reg           [7:0] mc_CAS_n
   ,output reg           [7:0] mc_RAS_n
   ,output reg           [7:0] mc_WE_n
   ,output reg   [ABITS*8-1:0] mc_ADR
   ,output reg  [BABITS*8-1:0] mc_BA
   ,output reg  [BGBITS*8-1:0] mc_BG
   ,output reg [LR_WIDTH*8-1:0]mc_C
   ,output reg [CKEBITS*8-1:0] mc_CKE
   ,output reg  [CSBITS*8-1:0] mc_CS_n
   ,output     [ODTBITS*8-1:0] mc_ODT

   ,output wire        casSlot2
   ,output reg        tranSentC
   ,output reg        prevCmdAP

   ,input         [1:0] winBankAT
   ,input         [1:0] win_bank_cas
   ,input         [1:0] winBankPT
   ,input         [1:0] winGroupAT
   ,input         [1:0] win_group_cas
   ,input         [1:0] winGroupPT
   ,input               winAP
   ,input [COLBITS-1:0] winCol
   ,input               winAct
   ,input         [3:0] winPortC
   ,input         [3:0] winPortP
   ,input  [RKBITS-1:0] winRankA
   ,input  [RKBITS-1:0] win_rank_cas
   ,input  [RKBITS-1:0] winRankP
   ,input [LR_WIDTH-1:0] winLRankAT
   ,input [LR_WIDTH-1:0] win_l_rank_cas
   ,input [LR_WIDTH-1:0] winLRankPT
   ,output wire       winRead
   ,input   [ABITS-1:0] winRowA
   ,output wire       winWrite

   ,input               preIss
   ,input               refIss
   ,input               zqIss
   ,input               zqIssAll
   ,input  [RKBITS-1:0] refRank
   ,input [LR_WIDTH-1:0] refLRank
   ,input               per_cas_block_req

   ,input  int_sreIss
   ,input [RANKS-1:0] int_sreCkeDis
   ,input int_srxIss

   ,input   wire   [CMD_WIDTH-1:0] sel_cmd0
	,input   wire   [CMD_WIDTH-1:0] sel_cmd1
	,input   wire   [CMD_WIDTH-1:0] sel_cmd2
	,input   wire   [CMD_WIDTH-1:0] sel_cmd3

	,input   wire   [CH_WIDTH-1:0] sel_ch0
	,input   wire   [CH_WIDTH-1:0] sel_ch1
	,input   wire   [CH_WIDTH-1:0] sel_ch2
	,input   wire   [CH_WIDTH-1:0] sel_ch3

	,input   wire   [RNK_WIDTH-1:0] sel_rnk0
	,input   wire   [RNK_WIDTH-1:0] sel_rnk1
	,input   wire   [RNK_WIDTH-1:0] sel_rnk2
	,input   wire   [RNK_WIDTH-1:0] sel_rnk3

   ,input   wire   [LRNK_WIDTH-1:0] sel_lrnk0
	,input   wire   [LRNK_WIDTH-1:0] sel_lrnk1
	,input   wire   [LRNK_WIDTH-1:0] sel_lrnk2
	,input   wire   [LRNK_WIDTH-1:0] sel_lrnk3

	,input   wire   [BG_WIDTH-1:0] sel_bg0
	,input   wire   [BG_WIDTH-1:0] sel_bg1
	,input   wire   [BG_WIDTH-1:0] sel_bg2
	,input   wire   [BG_WIDTH-1:0] sel_bg3

	,input   wire   [BNK_WIDTH-1:0] sel_bnk0
	,input   wire   [BNK_WIDTH-1:0] sel_bnk1
	,input   wire   [BNK_WIDTH-1:0] sel_bnk2
	,input   wire   [BNK_WIDTH-1:0] sel_bnk3

	,input   wire [ROW_WIDTH-1:0]    sel_row0
	,input   wire [ROW_WIDTH-1:0]    sel_row1
	,input   wire [ROW_WIDTH-1:0]    sel_row2
	,input   wire [ROW_WIDTH-1:0]    sel_row3
	
	,input   wire [COL_WIDTH-1:0]    sel_col0
	,input   wire [COL_WIDTH-1:0]    sel_col1
	,input   wire [COL_WIDTH-1:0]    sel_col2
	,input   wire [COL_WIDTH-1:0]    sel_col3
);


// Parameter used to enforce 8 tCK spacing for rank switching
// for DDR speeds greater than 1866.
localparam LONG_RANK_SWITCH = ( tCK < 1070 ) & ( RANKS > 1 );

localparam 
    MRS = 3'b000
   ,REF = 3'b001
   ,PRE = 3'b010
   ,ACT = 3'b011
   ,WR  = 3'b100
   ,RD  = 3'b101
   ,ZQC = 3'b110
   ,NOP = 3'b111
;


integer i;
integer bn;
integer rank_index;


reg [7:0] mc_ADRR[0:ABITS-1];
reg [7:0] mc_BAR[0:BABITS-1];
reg [7:0] mc_BGR[0:BGBITS-1];
reg [7:0] mc_CR[0:LR_WIDTH-1];
reg [7:0] mc_CKER[0:CKEBITS-1];
reg [7:0] mc_CS_nR[0:CSBITS-1];

always @(*) begin
   for (i = 0; i < ABITS; i++) mc_ADR[i*8+:8] = mc_ADRR[i];
   for (i = 0; i < BABITS; i++) mc_BA[i*8+:8] = mc_BAR[i];
   for (i = 0; i < BGBITS; i++) mc_BG[i*8+:8] = mc_BGR[i];
   for (i = 0; i < LR_WIDTH; i++) mc_C[i*8+:8] = mc_CR[i];
   for (i = 0; i < CKEBITS; i++) mc_CKE[i*8+:8] = mc_CKER[i];
   for (i = 0; i < CSBITS; i++) mc_CS_n[i*8+:8] = mc_CS_nR[i];
end

reg [7:0] d_mc_ACT_n;
reg [7:0] d_mc_RAS_n;
reg [7:0] d_mc_CAS_n;
reg [7:0] d_mc_WE_n;
reg [7:0] d_mc_ADRR[0:17];
reg [7:0] d_mc_BAR[0:BABITS-1];
reg [7:0] d_mc_BGR[0:BGBITS-1];
reg [7:0] d_mc_CR[0:LR_WIDTH-1];
reg [7:0] d_mc_CS_nR[0:CSBITS-1];
reg [7:0] d_mc_CKER[0:CKEBITS-1];


always @(*) begin
   mc_ACT_n = d_mc_ACT_n;
   mc_RAS_n = d_mc_RAS_n;
   mc_CAS_n = d_mc_CAS_n;
   mc_WE_n = d_mc_WE_n;
   for (i = 0; i < ABITS; i++) mc_ADRR[i] = d_mc_ADRR[i];
   for (i = 0; i < BABITS; i++) mc_BAR[i] = d_mc_BAR[i];
   for (i = 0; i < BGBITS; i++) mc_BGR[i] = d_mc_BGR[i];
   for (i = 0; i < LR_WIDTH; i++) mc_CR[i] = d_mc_CR[i];
   for (i = 0; i < CKEBITS; i++) mc_CKER[i] = d_mc_CKER[i];
   for (i = 0; i < CSBITS; i++) begin
     if (CLAMSHELL == "ON") begin
       mc_CS_nR[i] = d_mc_CS_nR[i/2];
     end else begin
       mc_CS_nR[i] = d_mc_CS_nR[i];
     end
   end
end

reg [RKBITS-1:0] d_prevRank;
reg [BGBITS-1:0] d_prevGroup;
reg [LR_WIDTH-1:0] d_prevLRank;
reg       d_prevSlot2;
wire       d_prevCmdAP;

reg       prev2CAS;
reg       prevSlot2;

always @(posedge clk) if (rst) begin
   prevCmdAP <= #TCQ 1'b0;
end else begin
   prevCmdAP <= #TCQ d_prevCmdAP;
end

localparam RRI = ((RANK_SLOT == 4) && (REG_CTRL == "ON")) ? 0 : 1 ;  // Refresh Rank Index
localparam RR  = ((RANK_SLOT == 4) && (REG_CTRL == "ON")) ? 2 : 4 ;   // Refresf Rank to be compared

assign winRead = sel_cmd0 == `CASRD | sel_cmd0 == `CASRDA | sel_cmd2 == `CASRD | sel_cmd2 == `CASRDA;
assign winWrite = sel_cmd0 == `CASWR | sel_cmd0 == `CASWRA | sel_cmd2 == `CASWR | sel_cmd2 == `CASWRA;
wire winReadAllowed = winRead & ~per_cas_block_req;
wire [RKBITS-1:0] rank_cas = casSlot2 ? sel_rnk2 : sel_rnk0;
wire ap0 = sel_cmd0 == `CASRDA | sel_cmd0 == `CASWRA;
wire ap2 = sel_cmd2 == `CASRDA | sel_cmd2 == `CASWRA;
wire zq_ref_pre_stall = zqIss | refIss | int_sreIss | preIss;

assign d_prevCmdAP = (tranSentC) ? (ap0|ap2) : 1'b0;

assign casSlot2  = sel_cmd2 == `CASRD | sel_cmd2 == `CASRDA | sel_cmd2 == `CASWR | sel_cmd2 == `CASWRA;

// generating tranSentC
always @(*) begin
   casez ({winReadAllowed, winWrite})
     2'b10, 2'b01: begin
	    tranSentC  = 1'b1;
	 end
   // default: tranSentC  = 1'b0;
   default: tranSentC  = ~(winRead & per_cas_block_req);

   endcase
end

// First Slot
generate
always @(*) begin
   reg [16:14] op;
   d_mc_ACT_n[1:0] = 2'b11;
   d_mc_RAS_n[1:0] = 2'b11;
   d_mc_CAS_n[1:0] = 2'b11;
   d_mc_WE_n[1:0] = 2'b11;
   d_mc_ADRR[17][1:0]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 14; i < 17; i++)     d_mc_ADRR[i][1:0]  = 2'b11;
   for (i =  0; i < 14; i++)     d_mc_ADRR[i][1:0]  = NOP_ADD_LOW ? '0 : (tranSentC ? 2'b00 : 2'b11);
   for (i =  0; i < BABITS; i++) d_mc_BAR[i][1:0]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < BGBITS; i++) d_mc_BGR[i][1:0]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < LR_WIDTH; i++) d_mc_CR[i][1:0]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 0; i < CKEBITS; i++) d_mc_CKER[i][1:0]  = int_sreIss && (refRank[RRI:0] == (i%RR)) ? 2'b11 :
	                                         int_sreCkeDis[i] ? 2'b00 : 
	                                         int_srxIss       ? 2'b00 :
  	                                                            2'b11; 
   for (i =  0; i < CSBITS; i++) d_mc_CS_nR[i][1:0] = 2'b11;
      case(sel_cmd0)
         `PRE : begin
            op = PRE; // op = 3'b010
            for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][1:0] = {2{1'b0}};         
            d_mc_ADRR[14][1:0] = {2{op[14]}};
            d_mc_ADRR[15][1:0] = {2{op[15]}};
            d_mc_ADRR[16][1:0] = {2{op[16]}};
            for (bn = 0; bn < BABITS; bn++)
               d_mc_BAR[bn][1:0] = {2{sel_bnk0[bn]}};
            for (bn = 0; bn < BGBITS; bn++)
               d_mc_BGR[bn][1:0] = {2{sel_bg0[bn]}};
            for (bn = 0; bn < LR_WIDTH; bn++) 
               d_mc_CR[bn][1:0] = {2{sel_lrnk0[bn]}};
            d_mc_RAS_n[1:0] = {2{op[16]}};
            d_mc_CAS_n[1:0] = {2{op[15]}};
            d_mc_WE_n[1:0] = {2{op[14]}};
            d_mc_CS_nR[sel_rnk0][1:0] = 2'b00;
         end
         `ACT : begin // op = 3'b011;
         op = ACT;
         for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][1:0] = {2{sel_row0[bn]}};
         for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][1:0] = {2{sel_bnk0[bn]}};
         for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][1:0] = {2{sel_bg0[bn]}};
         for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][1:0] = {2{sel_lrnk0[bn]}};
         d_mc_ACT_n[1:0] = 2'b00;
         d_mc_RAS_n[1:0] = {2{op[16]}};
         d_mc_CAS_n[1:0] = {2{op[15]}};
         d_mc_WE_n[1:0] = {2{op[14]}};
         d_mc_CS_nR[sel_rnk0][1:0] = 2'b00;
         end
         `CASRD, `CASRDA, `CASWR, `CASWRA: begin
            if (tranSentC) begin // spyglass disable STARC-2.7.1.3a     // else statement not needed due to defaults above
               op = winRead ? RD : WR;
               for (bn = 0; bn < ABITS; bn = bn + 1) d_mc_ADRR[bn][1:0] = 2'b00;
               for (bn = 0; bn < COLBITS; bn++) begin
                  if      ( bn <=  9 ) d_mc_ADRR[bn]  [1:0] = {2{sel_col0[bn]}}; // Column bits A9 to A0
                  else if ( bn == 10 ) d_mc_ADRR[bn+1][1:0] = {2{sel_col0[bn]}}; // Column bit A11
                  else                 d_mc_ADRR[bn+2][1:0] = {2{sel_col0[bn]}}; // Column bit A13
               end
               d_mc_ADRR[10][1:0] = {2{ap0}};
               d_mc_ADRR[14][1:0] = 2'b11;
               d_mc_ADRR[15][1:0] = 2'b11;
               d_mc_ADRR[16][1:0] = 2'b11;
               d_mc_ADRR[14][1:0] = {2{op[14]}};
               d_mc_ADRR[15][1:0] = {2{op[15]}};
               d_mc_ADRR[16][1:0] = {2{op[16]}};
               d_mc_RAS_n[1:0] = {2{op[16]}};
               d_mc_CAS_n[1:0] = {2{op[15]}};
               d_mc_WE_n[1:0] = {2{op[14]}};
               for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][1:0] = {2{sel_bnk0[bn]}};
               for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][1:0] = {2{sel_bg0[bn]}};
               for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][1:0] = {2{sel_rnk0[bn]}};
               d_mc_CS_nR[sel_rnk0][1:0] = 2'b00;

            end
         end
      endcase
end
endgenerate

// second slot
generate
always @(*) begin
   reg [16:14] op;
   d_mc_ACT_n[3:2] = 2'b11;
   d_mc_RAS_n[3:2] = 2'b11;
   d_mc_CAS_n[3:2] = 2'b11;
   d_mc_WE_n[3:2] = 2'b11; 
   d_mc_ADRR[17][3:2]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 14; i < 17; i++)     d_mc_ADRR[i][3:2]  = 2'b11;
   for (i =  0; i < 14; i++)     d_mc_ADRR[i][3:2]  = NOP_ADD_LOW ? '0 : (tranSentC ? 2'b00 : 2'b11);
   for (i =  0; i < BABITS; i++) d_mc_BAR[i][3:2]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < BGBITS; i++) d_mc_BGR[i][3:2]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < LR_WIDTH; i++) d_mc_CR[i][3:2]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 0; i < CKEBITS; i++) d_mc_CKER[i][3:2]  = int_sreIss && (refRank[RRI:0] == (i%RR)) ? 2'b11 :
	                                         int_sreCkeDis[i] ? 2'b00 : 
	                                         int_srxIss       ? 2'b00 :
  	                                                            2'b11; 
   for (i =  0; i < CSBITS; i++) d_mc_CS_nR[i][3:2] = 2'b11;
      case(sel_cmd1)
         `PRE : begin
            op = PRE; // op = 3'b010
            for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][3:2] = {2{1'b0}};         
            d_mc_ADRR[14][3:2] = {2{op[14]}};
            d_mc_ADRR[15][3:2] = {2{op[15]}};
            d_mc_ADRR[16][3:2] = {2{op[16]}};
            for (bn = 0; bn < BABITS; bn++)
               d_mc_BAR[bn][3:2] = {2{sel_bnk1[bn]}};
            for (bn = 0; bn < BGBITS; bn++)
               d_mc_BGR[bn][3:2] = {2{sel_bg1[bn]}};
            for (bn = 0; bn < LR_WIDTH; bn++) 
               d_mc_CR[bn][3:2] = {2{sel_lrnk1[bn]}};
            d_mc_RAS_n[3:2] = {2{op[16]}};
            d_mc_CAS_n[3:2] = {2{op[15]}};
            d_mc_WE_n[3:2] = {2{op[14]}};
            d_mc_CS_nR[sel_rnk1][3:2] = 2'b00;
         end
         `ACT : begin // op = 3'b011;
         op = ACT;
         for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][3:2] = {2{sel_row1[bn]}};
         for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][3:2] = {2{sel_bnk1[bn]}};
         for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][3:2] = {2{sel_bg1[bn]}};
         for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][3:2] = {2{sel_lrnk1[bn]}};
         d_mc_ACT_n[3:2] = 2'b00;
         d_mc_RAS_n[3:2] = {2{op[16]}};
         d_mc_CAS_n[3:2] = {2{op[15]}};
         d_mc_WE_n[3:2] = {2{op[14]}};
         d_mc_CS_nR[sel_rnk1][3:2] = 2'b00;
         end
      endcase
end
endgenerate

// third Slot
generate
always @(*) begin
   reg [16:14] op;
   d_mc_ACT_n[5:4] = 2'b11;
   d_mc_RAS_n[5:4] = 2'b11;
   d_mc_CAS_n[5:4] = 2'b11;
   d_mc_WE_n[5:4] = 2'b11; 
   d_mc_ADRR[17][5:4]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 14; i < 17; i++)     d_mc_ADRR[i][5:4]  = 2'b11;
   for (i =  0; i < 14; i++)     d_mc_ADRR[i][5:4]  = NOP_ADD_LOW ? '0 : (tranSentC ? 2'b00 : 2'b11);
   for (i =  0; i < BABITS; i++) d_mc_BAR[i][5:4]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < BGBITS; i++) d_mc_BGR[i][5:4]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < LR_WIDTH; i++) d_mc_CR[i][5:4]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 0; i < CKEBITS; i++) d_mc_CKER[i][5:4]  = int_sreIss && (refRank[RRI:0] == (i%RR)) ? 2'b11 :
	                                         int_sreCkeDis[i] ? 2'b00 : 
	                                         int_srxIss       ? 2'b00 :
  	                                                            2'b11; 
   for (i =  0; i < CSBITS; i++) d_mc_CS_nR[i][5:4] = 2'b11;
      case(sel_cmd2)
         `PRE : begin
            op = PRE; // op = 3'b010
            for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][5:4] = {2{1'b0}};         
            d_mc_ADRR[14][5:4] = {2{op[14]}};
            d_mc_ADRR[15][5:4] = {2{op[15]}};
            d_mc_ADRR[16][5:4] = {2{op[16]}};
            for (bn = 0; bn < BABITS; bn++)
               d_mc_BAR[bn][5:4] = {2{sel_bnk2[bn]}};
            for (bn = 0; bn < BGBITS; bn++)
               d_mc_BGR[bn][5:4] = {2{sel_bg2[bn]}};
            for (bn = 0; bn < LR_WIDTH; bn++) 
               d_mc_CR[bn][5:4] = {2{sel_lrnk2[bn]}};
            d_mc_RAS_n[5:4] = {2{op[16]}};
            d_mc_CAS_n[5:4] = {2{op[15]}};
            d_mc_WE_n[5:4] = {2{op[14]}};
            d_mc_CS_nR[sel_rnk2][5:4] = 2'b00;
         end
         `ACT : begin // op = 3'b011;
         op = ACT;
         for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][5:4] = {2{sel_row2[bn]}};
         for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][5:4] = {2{sel_bnk2[bn]}};
         for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][5:4] = {2{sel_bg2[bn]}};
         for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][5:4] = {2{sel_lrnk2[bn]}};
         d_mc_ACT_n[5:4] = 2'b00;
         d_mc_RAS_n[5:4] = {2{op[16]}};
         d_mc_CAS_n[5:4] = {2{op[15]}};
         d_mc_WE_n[5:4] = {2{op[14]}};
         d_mc_CS_nR[sel_rnk2][5:4] = 2'b00;
         end
         `CASRD, `CASRDA, `CASWR, `CASWRA: begin
            if (tranSentC) begin // spyglass disable STARC-2.7.1.3a     // else statement not needed due to defaults above
               op = winRead ? RD : WR;
               for (bn = 0; bn < ABITS; bn = bn + 1) d_mc_ADRR[bn][5:4] = 2'b00;
               for (bn = 0; bn < COLBITS; bn++) begin
                  if      ( bn <=  9 ) d_mc_ADRR[bn]  [5:4] = {2{sel_col2[bn]}}; // Column bits A9 to A0
                  else if ( bn == 10 ) d_mc_ADRR[bn+1][5:4] = {2{sel_col2[bn]}}; // Column bit A11
                  else                 d_mc_ADRR[bn+2][5:4] = {2{sel_col2[bn]}}; // Column bit A13
               end
               d_mc_ADRR[10][5:4] = {2{ap2}};
               d_mc_ADRR[14][5:4] = 2'b11;
               d_mc_ADRR[15][5:4] = 2'b11;
               d_mc_ADRR[16][5:4] = 2'b11;
               d_mc_ADRR[14][5:4] = {2{op[14]}};
               d_mc_ADRR[15][5:4] = {2{op[15]}};
               d_mc_ADRR[16][5:4] = {2{op[16]}};
               d_mc_RAS_n[5:4] = {2{op[16]}};
               d_mc_CAS_n[5:4] = {2{op[15]}};
               d_mc_WE_n[5:4] = {2{op[14]}};
               for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][5:4] = {2{sel_bnk2[bn]}};
               for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][5:4] = {2{sel_bg2[bn]}};
               for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][5:4] = {2{sel_rnk2[bn]}};
               d_mc_CS_nR[sel_rnk2][5:4] = 2'b00;
            end
         end
      endcase
end
endgenerate

// fourth slot
generate
always @(*) begin
   reg [16:14] op;
   d_mc_ACT_n[7:6] = 2'b11;
   d_mc_RAS_n[7:6] = 2'b11;
   d_mc_CAS_n[7:6] = 2'b11;
   d_mc_WE_n[7:6] = 2'b11; 
   d_mc_ADRR[17][7:6]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 14; i < 17; i++)     d_mc_ADRR[i][7:6]  = 2'b11;
   for (i =  0; i < 14; i++)     d_mc_ADRR[i][7:6]  = NOP_ADD_LOW ? '0 : (tranSentC ? 2'b00 : 2'b11);
   for (i =  0; i < BABITS; i++) d_mc_BAR[i][7:6]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < BGBITS; i++) d_mc_BGR[i][7:6]   = NOP_ADD_LOW ? '0 : 2'b11;
   for (i =  0; i < LR_WIDTH; i++) d_mc_CR[i][7:6]  = NOP_ADD_LOW ? '0 : 2'b11;
   for (i = 0; i < CKEBITS; i++) d_mc_CKER[i][7:6]  = int_sreIss && (refRank[RRI:0] == (i%RR)) ? 2'b11 :
	                                         int_sreCkeDis[i] ? 2'b00 : 
	                                         int_srxIss       ? 2'b00 :
  	                                                            2'b11; 
   for (i =  0; i < CSBITS; i++) d_mc_CS_nR[i][7:6] = 2'b11;
      case(sel_cmd3)
         `PRE : begin
            op = PRE; // op = 3'b010
            for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][7:6] = {2{1'b0}};         
            d_mc_ADRR[14][7:6] = {2{op[14]}};
            d_mc_ADRR[15][7:6] = {2{op[15]}};
            d_mc_ADRR[16][7:6] = {2{op[16]}};
            for (bn = 0; bn < BABITS; bn++)
               d_mc_BAR[bn][7:6] = {2{sel_bnk3[bn]}};
            for (bn = 0; bn < BGBITS; bn++)
               d_mc_BGR[bn][7:6] = {2{sel_bg3[bn]}};
            for (bn = 0; bn < LR_WIDTH; bn++) 
               d_mc_CR[bn][7:6] = {2{sel_lrnk3[bn]}};
            d_mc_RAS_n[7:6] = {2{op[16]}};
            d_mc_CAS_n[7:6] = {2{op[15]}};
            d_mc_WE_n[7:6] = {2{op[14]}};
            d_mc_CS_nR[sel_rnk3][7:6] = 2'b00;
         end
         `ACT : begin // op = 3'b011;
         op = ACT;
         for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][7:6] = {2{sel_row3[bn]}};
         for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][7:6] = {2{sel_bnk3[bn]}};
         for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][7:6] = {2{sel_bg3[bn]}};
         for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][7:6] = {2{sel_lrnk3[bn]}};
         d_mc_ACT_n[7:6] = 2'b00;
         d_mc_RAS_n[7:6] = {2{op[16]}};
         d_mc_CAS_n[7:6] = {2{op[15]}};
         d_mc_WE_n[7:6] = {2{op[14]}};
         d_mc_CS_nR[sel_rnk3][7:6] = 2'b00;
         end
      endcase

// refresh, zq
      casez (1'b1)
         preIss: begin
            op = PRE;
            for (bn = 0; bn < ABITS; bn++) d_mc_ADRR[bn][7:6] = {2{1'b1}};
            if (MEM == "DDR4") begin
               d_mc_ADRR[14][7:6] = {2{op[14]}};
               d_mc_ADRR[15][7:6] = {2{op[15]}};
               d_mc_ADRR[16][7:6] = {2{op[16]}};
            end
            d_mc_RAS_n[7:6] = {2{op[16]}};
            d_mc_CAS_n[7:6] = {2{op[15]}};
            d_mc_WE_n[7:6] = {2{op[14]}};
            for (bn = 0; bn < BABITS; bn++) d_mc_BAR[bn][7:6] = 2'b00;
            for (bn = 0; bn < BGBITS; bn++) d_mc_BGR[bn][7:6] = 2'b00;
            for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][7:6] = {2{refLRank[bn]}};
            d_mc_CS_nR[refRank][7:6] = 2'b00;
         end
         refIss,int_sreIss: begin
            op = REF;
            if (MEM == "DDR4") begin
              d_mc_ADRR[14][7:6] = {2{op[14]}};
              d_mc_ADRR[15][7:6] = {2{op[15]}};
              d_mc_ADRR[16][7:6] = {2{op[16]}};
            end
            d_mc_RAS_n[7:6] = {2{op[16]}};
            d_mc_CAS_n[7:6] = {2{op[15]}};
            d_mc_WE_n[7:6] = {2{op[14]}};
            for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][7:6] = {2{refLRank[bn]}};
	    if (!int_srxIss) begin // No CS activity for SRX
	      if (int_sreIss) begin
                for (i =  0; i < CSBITS; i++) begin
	          if (refRank[RRI:0] == (i%RR))
	            d_mc_CS_nR[i][7:6] = 2'b00;
                end
	      end else begin
	        d_mc_CS_nR[refRank][7:6] = 2'b00;
	      end
	    end
         end
         zqIss: begin
            op = ZQC;
            if (MEM == "DDR4") begin
              d_mc_ADRR[14][7:6] = {2{op[14]}};
              d_mc_ADRR[15][7:6] = {2{op[15]}};
              d_mc_ADRR[16][7:6] = {2{op[16]}};
            end
            d_mc_ADRR[10][7:6] = 2'b0;
            d_mc_RAS_n[7:6] = {2{op[16]}};
            d_mc_CAS_n[7:6] = {2{op[15]}};
            d_mc_WE_n[7:6] = {2{op[14]}};
            for (bn = 0; bn < LR_WIDTH; bn++) d_mc_CR[bn][7:6] = {2{refLRank[bn]}};
            for (rank_index = 0; rank_index < CSBITS; rank_index++) d_mc_CS_nR[rank_index][7:6] = ~{ 2 { zqIssAll } };
            d_mc_CS_nR[refRank][7:6] = 2'b00;
         end
      endcase
end

endgenerate
ddr4_v2_2_14_cal_mc_odt #( // MAN - name change
    .ODTWR     (ODTWR)
   ,.ODTWRDEL  (ODTWRDEL)
   ,.ODTWRDUR  (ODTWRDUR)
   ,.ODTWRODEL (ODTWRODEL)
   ,.ODTWRODUR (ODTWRODUR)

   ,.ODTRD     (ODTRD)
   ,.ODTRDDEL  (ODTRDDEL)
   ,.ODTRDDUR  (ODTRDDUR)
   ,.ODTRDODEL (ODTRDODEL)
   ,.ODTRDODUR (ODTRDODUR)

   ,.RANKS     (RANKS)
   ,.RNK_BITS  (RKBITS)
   ,.ODTNOP    (ODTNOP)
   ,.ODTBITS   (ODTBITS)
   ,.TCQ       (TCQ)
)u_ddr_mc_odt(
    .clk (clk)
   ,.rst (rst)

   ,.mc_ODT (mc_ODT)

   ,.casSlot2  (casSlot2)
   ,.rank      (rank_cas)
   ,.winRead   (winRead)
   ,.winWrite  (winWrite)
   ,.tranSentC (tranSentC)
);


endmodule


