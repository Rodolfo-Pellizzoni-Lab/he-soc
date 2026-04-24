/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Ultra(TM) in wire load mode
// Version   : L-2016.03
// Date      : Fri May 25 10:23:43 2018
/////////////////////////////////////////////////////////////


module clk_gen ( clk_i, rst_ni, clk0_o, clk90_o, clk180_o, clk270_o );
  input clk_i, rst_ni;
  output clk0_o, clk90_o, clk180_o, clk270_o;
  wire   n1;

  INVM1S U3 ( .A(clk0_o), .Z(n1) );
  DFQRM4SA r_clk0_o_reg ( .D(n1), .CK(clk_i), .RB(rst_ni), .Q(clk0_o) );
  DFCQRM1SA r_clk90_o_reg ( .D(clk0_o), .CKB(clk_i), .RB(rst_ni), .Q(clk90_o)
         );
endmodule



    module reg_uniform_ADDR_WIDTH32_DATA_WIDTH32_NUM_REG9_REG_WIDTH32_I_reg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32 ( 
        clk_i, rst_ni, init_val_i, rd_val_i, wr_val_o, wr_evt_o, reg_i_addr, 
        reg_i_write, reg_i_wdata, reg_i_wstrb, reg_i_valid, reg_i_rdata, 
        reg_i_error, reg_i_ready );
  input [287:0] init_val_i;
  input [287:0] rd_val_i;
  output [287:0] wr_val_o;
  output [8:0] wr_evt_o;
  input [31:0] reg_i_addr;
  input [31:0] reg_i_wdata;
  input [3:0] reg_i_wstrb;
  output [31:0] reg_i_rdata;
  input clk_i, rst_ni, reg_i_write, reg_i_valid;
  output reg_i_error, reg_i_ready;
  wire   n868, n869, n870, n871, n70, n80, n234, n47, n48, n49, n57, n58, n59,
         n60, n61, n63, n64, n316, n317, n318, n319, n320, n321, n322, n331,
         n348, n349, n350, n351, n352, n353, n354, n355, n356, n357, n358,
         n359, n360, n361, n363, n364, n365, n366, n367, n368, n369, n370,
         n371, n372, n373, n374, n375, n376, n377, n378, n379, n380, n381,
         n382, n383, n384, n385, n386, n387, n394, n395, n412, n413, n414,
         n415, n416, n417, n418, n419, n420, n421, n422, n423, n424, n425,
         n426, n427, n428, n429, n430, n431, n432, n433, n434, n435, n436,
         n437, n438, n439, n440, n441, n443, n444, n445, n603, n604, n605,
         n606, n607, n608, n609, n610, n611, n612, n613, n614, n615, n616,
         n617, n618, n619, n620, n621, n622, n623, n624, n625, n626, n627,
         n628, n629, n630, n631, n632, n633, n634, n635, n636, n637, n638,
         n639, n640, n641, n642, n643, n644, n645, n646, n647, n648, n649,
         n650, n651, n652, n653, n654, n655, n656, n657, n658, n659, n660,
         n661, n662, n663, n664, n665, n666, n667, n668, n669, n670, n671,
         n672, n673, n674, n675, n676, n677, n678, n679, n680, n681, n682,
         n683, n684, n685, n686, n687, n688, n689, n690, n691, n692, n693,
         n694, n695, n696, n697, n698, n699, n700, n701, n702, n703, n704,
         n705, n706, n707, n708, n709, n710, n711, n712, n713, n714, n715,
         n716, n717, n718, n719, n720, n721, n722, n723, n724, n725, n726,
         n727, n728, n729, n730, n731, n732, n733, n734, n735, n736, n737,
         n738, n739, n740, n741, n742, n743, n744, n745, n746, n747, n748,
         n749, n750, n751, n752, n753, n754, n755, n756, n757, n758, n759,
         n760, n761, n762, n763, n764, n765, n766, n767, n768, n769, n770,
         n771, n772, n773, n774, n775, n776, n777, n778, n779, n780, n781,
         n782, n783, n784, n785, n786, n787, n788, n789, n790, n791, n792,
         n793, n794, n795, n796, n797, n798, n799, n800, n801, n802, n803,
         n804, n805, n806, n807, n808, n809, n810, n811, n812, n813, n814,
         n815, n816, n817, n818, n819, n820, n821, n822, n823, n824, n825,
         n826, n827, n828, n829, n830, n831, n832, n833, n834, n835, n836,
         n837, n838, n839, n840, n841, n842, n843, n844, n845, n846, n847,
         n848, n849, n850, n851, n852, n853, n854, n855, n856, n857, n858,
         n859, n860, n861, n862, n863, n864, n865, n866, n867,
         SYNOPSYS_UNCONNECTED_1, SYNOPSYS_UNCONNECTED_2,
         SYNOPSYS_UNCONNECTED_3, SYNOPSYS_UNCONNECTED_4,
         SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6,
         SYNOPSYS_UNCONNECTED_7, SYNOPSYS_UNCONNECTED_8,
         SYNOPSYS_UNCONNECTED_9, SYNOPSYS_UNCONNECTED_10,
         SYNOPSYS_UNCONNECTED_11, SYNOPSYS_UNCONNECTED_12,
         SYNOPSYS_UNCONNECTED_13, SYNOPSYS_UNCONNECTED_14,
         SYNOPSYS_UNCONNECTED_15, SYNOPSYS_UNCONNECTED_16,
         SYNOPSYS_UNCONNECTED_17, SYNOPSYS_UNCONNECTED_18,
         SYNOPSYS_UNCONNECTED_19, SYNOPSYS_UNCONNECTED_20,
         SYNOPSYS_UNCONNECTED_21, SYNOPSYS_UNCONNECTED_22,
         SYNOPSYS_UNCONNECTED_23, SYNOPSYS_UNCONNECTED_24,
         SYNOPSYS_UNCONNECTED_25, SYNOPSYS_UNCONNECTED_26,
         SYNOPSYS_UNCONNECTED_27, SYNOPSYS_UNCONNECTED_28,
         SYNOPSYS_UNCONNECTED_29, SYNOPSYS_UNCONNECTED_30,
         SYNOPSYS_UNCONNECTED_31, SYNOPSYS_UNCONNECTED_32,
         SYNOPSYS_UNCONNECTED_33, SYNOPSYS_UNCONNECTED_34,
         SYNOPSYS_UNCONNECTED_35, SYNOPSYS_UNCONNECTED_36,
         SYNOPSYS_UNCONNECTED_37, SYNOPSYS_UNCONNECTED_38,
         SYNOPSYS_UNCONNECTED_39, SYNOPSYS_UNCONNECTED_40,
         SYNOPSYS_UNCONNECTED_41;
  wire   [19:0] reg_wr;

  DFQRM1SA reg_q_reg_5__13_ ( .D(n433), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[173]) );
  DFQRM1SA reg_q_reg_5__30_ ( .D(n418), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[190]) );
  DFQRM1SA reg_q_reg_6__25_ ( .D(n381), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[217]) );
  DFQRM1SA reg_q_reg_7__10_ ( .D(n366), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[234]) );
  DFQRM1SA reg_q_reg_7__26_ ( .D(n350), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[250]) );
  DFEQRM1SA reg_q_reg_0__3_ ( .D(reg_i_wdata[3]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[3]) );
  DFEQRM1SA reg_q_reg_0__20_ ( .D(reg_i_wdata[20]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[20]) );
  DFEQRM1SA reg_q_reg_1__5_ ( .D(reg_i_wdata[5]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[37]) );
  DFEQRM1SA reg_q_reg_1__22_ ( .D(reg_i_wdata[22]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[54]) );
  DFERM1SA reg_q_reg_2__7_ ( .D(n64), .E(reg_wr[8]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_1), .QB(wr_val_o[71]) );
  DFEQRM1SA reg_q_reg_2__8_ ( .D(reg_i_wdata[8]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[72]) );
  DFEQRM1SA reg_q_reg_2__25_ ( .D(reg_i_wdata[25]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[89]) );
  DFEQRM1SA reg_q_reg_3__10_ ( .D(reg_i_wdata[10]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[106]) );
  DFEQRM1SA reg_q_reg_3__27_ ( .D(reg_i_wdata[27]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[123]) );
  DFEQRM1SA reg_q_reg_4__12_ ( .D(reg_i_wdata[12]), .E(reg_wr[17]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[140]) );
  DFEQRM1SA reg_q_reg_4__29_ ( .D(reg_i_wdata[29]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[157]) );
  DFERM1SA reg_q_reg_8__15_ ( .D(n853), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_2), .QB(wr_val_o[271]) );
  DFERM1SA reg_q_reg_8__0_ ( .D(n57), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_3), .QB(wr_val_o[256]) );
  DFERM1SA reg_q_reg_6__8_ ( .D(n47), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n837), .QB(wr_val_o[200]) );
  AO22M1SA U501 ( .A1(reg_i_valid), .A2(n234), .B1(n445), .B2(1'b0), .Z(
        reg_i_rdata[31]) );
  DFQRM1SA reg_q_reg_5__7_ ( .D(n443), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[167]) );
  DFQRM1SA reg_q_reg_5__5_ ( .D(n441), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[165]) );
  DFQRM1SA reg_q_reg_5__4_ ( .D(n440), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[164]) );
  DFQRM1SA reg_q_reg_5__3_ ( .D(n439), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[163]) );
  DFQRM1SA reg_q_reg_5__2_ ( .D(n438), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[162]) );
  DFQRM1SA reg_q_reg_5__1_ ( .D(n437), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[161]) );
  DFQRM1SA reg_q_reg_5__0_ ( .D(n436), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[160]) );
  DFQRM1SA reg_q_reg_5__15_ ( .D(n435), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[175]) );
  DFQRM1SA reg_q_reg_5__14_ ( .D(n434), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[174]) );
  DFQRM1SA reg_q_reg_5__12_ ( .D(n432), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[172]) );
  DFQRM1SA reg_q_reg_5__11_ ( .D(n431), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[171]) );
  DFQRM1SA reg_q_reg_5__10_ ( .D(n430), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[170]) );
  DFQRM1SA reg_q_reg_5__9_ ( .D(n429), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[169]) );
  DFQRM1SA reg_q_reg_5__8_ ( .D(n428), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[168]) );
  DFQRM1SA reg_q_reg_5__23_ ( .D(n427), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[183]) );
  DFQRM1SA reg_q_reg_5__22_ ( .D(n426), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[182]) );
  DFQRM1SA reg_q_reg_5__21_ ( .D(n425), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[181]) );
  DFQRM1SA reg_q_reg_5__20_ ( .D(n424), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[180]) );
  DFQRM1SA reg_q_reg_5__19_ ( .D(n423), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[179]) );
  DFQRM1SA reg_q_reg_5__18_ ( .D(n422), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[178]) );
  DFQRM1SA reg_q_reg_5__17_ ( .D(n421), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[177]) );
  DFQRM1SA reg_q_reg_5__16_ ( .D(n420), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[176]) );
  DFQRM1SA reg_q_reg_5__31_ ( .D(n419), .CK(clk_i), .RB(rst_ni), .Q(n871) );
  DFQRM1SA reg_q_reg_5__29_ ( .D(n417), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[189]) );
  DFQRM1SA reg_q_reg_5__28_ ( .D(n416), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[188]) );
  DFQRM1SA reg_q_reg_5__27_ ( .D(n415), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[187]) );
  DFQRM1SA reg_q_reg_5__26_ ( .D(n414), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[186]) );
  DFQRM1SA reg_q_reg_5__25_ ( .D(n413), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[185]) );
  DFQRM1SA reg_q_reg_5__24_ ( .D(n412), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[184]) );
  DFQRM1SA reg_q_reg_6__23_ ( .D(n395), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[215]) );
  DFQRM1SA reg_q_reg_6__22_ ( .D(n394), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[214]) );
  DFQRM1SA reg_q_reg_6__31_ ( .D(n387), .CK(clk_i), .RB(rst_ni), .Q(n870) );
  DFQRM1SA reg_q_reg_6__30_ ( .D(n386), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[222]) );
  DFQRM1SA reg_q_reg_6__29_ ( .D(n385), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[221]) );
  DFQRM1SA reg_q_reg_6__28_ ( .D(n384), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[220]) );
  DFQRM1SA reg_q_reg_6__27_ ( .D(n383), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[219]) );
  DFQRM1SA reg_q_reg_6__26_ ( .D(n382), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[218]) );
  DFQRM1SA reg_q_reg_6__24_ ( .D(n380), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[216]) );
  DFQRM1SA reg_q_reg_7__7_ ( .D(n379), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[231]) );
  DFQRM1SA reg_q_reg_7__6_ ( .D(n378), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[230]) );
  DFQRM1SA reg_q_reg_7__5_ ( .D(n377), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[229]) );
  DFQRM1SA reg_q_reg_7__4_ ( .D(n376), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[228]) );
  DFQRM1SA reg_q_reg_7__3_ ( .D(n375), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[227]) );
  DFQRM1SA reg_q_reg_7__2_ ( .D(n374), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[226]) );
  DFQRM1SA reg_q_reg_7__1_ ( .D(n373), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[225]) );
  DFQRM1SA reg_q_reg_7__0_ ( .D(n372), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[224]) );
  DFQRM1SA reg_q_reg_7__15_ ( .D(n371), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[239]) );
  DFQRM1SA reg_q_reg_7__14_ ( .D(n370), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[238]) );
  DFQRM1SA reg_q_reg_7__13_ ( .D(n369), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[237]) );
  DFQRM1SA reg_q_reg_7__12_ ( .D(n368), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[236]) );
  DFQRM1SA reg_q_reg_7__11_ ( .D(n367), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[235]) );
  DFQRM1SA reg_q_reg_7__9_ ( .D(n365), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[233]) );
  DFQRM1SA reg_q_reg_7__8_ ( .D(n364), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[232]) );
  DFQRM1SA reg_q_reg_7__23_ ( .D(n363), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[247]) );
  DFQRM1SA reg_q_reg_7__21_ ( .D(n361), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[245]) );
  DFQRM1SA reg_q_reg_7__20_ ( .D(n360), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[244]) );
  DFQRM1SA reg_q_reg_7__19_ ( .D(n359), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[243]) );
  DFQRM1SA reg_q_reg_7__18_ ( .D(n358), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[242]) );
  DFQRM1SA reg_q_reg_7__17_ ( .D(n357), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[241]) );
  DFQRM1SA reg_q_reg_7__16_ ( .D(n356), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[240]) );
  DFQRM1SA reg_q_reg_7__31_ ( .D(n355), .CK(clk_i), .RB(rst_ni), .Q(n869) );
  DFQRM1SA reg_q_reg_7__30_ ( .D(n354), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[254]) );
  DFQRM1SA reg_q_reg_7__29_ ( .D(n353), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[253]) );
  DFQRM1SA reg_q_reg_7__28_ ( .D(n352), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[252]) );
  DFQRM1SA reg_q_reg_7__27_ ( .D(n351), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[251]) );
  DFQRM1SA reg_q_reg_7__25_ ( .D(n349), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[249]) );
  DFQRM1SA reg_q_reg_7__24_ ( .D(n348), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[248]) );
  DFQRM1SA reg_q_reg_8__23_ ( .D(n331), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[279]) );
  DFQRM1SA reg_q_reg_8__30_ ( .D(n322), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[286]) );
  DFQRM1SA reg_q_reg_8__29_ ( .D(n321), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[285]) );
  DFQRM1SA reg_q_reg_8__28_ ( .D(n320), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[284]) );
  DFQRM1SA reg_q_reg_8__27_ ( .D(n319), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[283]) );
  DFQRM1SA reg_q_reg_8__26_ ( .D(n318), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[282]) );
  DFQRM1SA reg_q_reg_8__25_ ( .D(n317), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[281]) );
  DFQRM1SA reg_q_reg_8__24_ ( .D(n316), .CK(clk_i), .RB(rst_ni), .Q(
        wr_val_o[280]) );
  DFEQRM1SA reg_q_reg_0__7_ ( .D(reg_i_wdata[7]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[7]) );
  DFEQRM1SA reg_q_reg_0__6_ ( .D(reg_i_wdata[6]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[6]) );
  DFEQRM1SA reg_q_reg_0__5_ ( .D(reg_i_wdata[5]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[5]) );
  DFEQRM1SA reg_q_reg_0__4_ ( .D(reg_i_wdata[4]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[4]) );
  DFERM1SA reg_q_reg_0__2_ ( .D(n59), .E(reg_wr[0]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_4), .QB(wr_val_o[2]) );
  DFERM1SA reg_q_reg_0__1_ ( .D(n58), .E(reg_wr[0]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_5), .QB(wr_val_o[1]) );
  DFEQRM1SA reg_q_reg_0__0_ ( .D(reg_i_wdata[0]), .E(reg_wr[0]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[0]) );
  DFEQRM1SA reg_q_reg_0__15_ ( .D(reg_i_wdata[15]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[15]) );
  DFEQRM1SA reg_q_reg_0__14_ ( .D(reg_i_wdata[14]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[14]) );
  DFEQRM1SA reg_q_reg_0__13_ ( .D(reg_i_wdata[13]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[13]) );
  DFEQRM1SA reg_q_reg_0__12_ ( .D(reg_i_wdata[12]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[12]) );
  DFEQRM1SA reg_q_reg_0__11_ ( .D(reg_i_wdata[11]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[11]) );
  DFEQRM1SA reg_q_reg_0__10_ ( .D(reg_i_wdata[10]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[10]) );
  DFEQRM1SA reg_q_reg_0__9_ ( .D(reg_i_wdata[9]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[9]) );
  DFEQRM1SA reg_q_reg_0__8_ ( .D(reg_i_wdata[8]), .E(reg_wr[1]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[8]) );
  DFEQRM1SA reg_q_reg_0__23_ ( .D(reg_i_wdata[23]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[23]) );
  DFEQRM1SA reg_q_reg_0__22_ ( .D(reg_i_wdata[22]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[22]) );
  DFEQRM1SA reg_q_reg_0__21_ ( .D(reg_i_wdata[21]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[21]) );
  DFEQRM1SA reg_q_reg_0__19_ ( .D(reg_i_wdata[19]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[19]) );
  DFEQRM1SA reg_q_reg_0__18_ ( .D(reg_i_wdata[18]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[18]) );
  DFEQRM1SA reg_q_reg_0__17_ ( .D(reg_i_wdata[17]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[17]) );
  DFEQRM1SA reg_q_reg_0__16_ ( .D(reg_i_wdata[16]), .E(reg_wr[2]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[16]) );
  DFEQRM1SA reg_q_reg_0__31_ ( .D(reg_i_wdata[31]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[31]) );
  DFEQRM1SA reg_q_reg_0__30_ ( .D(reg_i_wdata[30]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[30]) );
  DFEQRM1SA reg_q_reg_0__29_ ( .D(reg_i_wdata[29]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[29]) );
  DFEQRM1SA reg_q_reg_0__28_ ( .D(reg_i_wdata[28]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[28]) );
  DFEQRM1SA reg_q_reg_0__27_ ( .D(reg_i_wdata[27]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[27]) );
  DFEQRM1SA reg_q_reg_0__26_ ( .D(reg_i_wdata[26]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[26]) );
  DFEQRM1SA reg_q_reg_0__25_ ( .D(reg_i_wdata[25]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[25]) );
  DFEQRM1SA reg_q_reg_0__24_ ( .D(reg_i_wdata[24]), .E(reg_wr[3]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[24]) );
  DFEQRM1SA reg_q_reg_1__7_ ( .D(reg_i_wdata[7]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[39]) );
  DFEQRM1SA reg_q_reg_1__6_ ( .D(reg_i_wdata[6]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[38]) );
  DFEQRM1SA reg_q_reg_1__4_ ( .D(reg_i_wdata[4]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[36]) );
  DFEQRM1SA reg_q_reg_1__3_ ( .D(reg_i_wdata[3]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[35]) );
  DFERM1SA reg_q_reg_1__2_ ( .D(n59), .E(reg_wr[4]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_6), .QB(wr_val_o[34]) );
  DFERM1SA reg_q_reg_1__1_ ( .D(n58), .E(reg_wr[4]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_7), .QB(wr_val_o[33]) );
  DFEQRM1SA reg_q_reg_1__0_ ( .D(reg_i_wdata[0]), .E(reg_wr[4]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[32]) );
  DFEQRM1SA reg_q_reg_1__15_ ( .D(reg_i_wdata[15]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[47]) );
  DFEQRM1SA reg_q_reg_1__14_ ( .D(reg_i_wdata[14]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[46]) );
  DFEQRM1SA reg_q_reg_1__13_ ( .D(reg_i_wdata[13]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[45]) );
  DFEQRM1SA reg_q_reg_1__12_ ( .D(reg_i_wdata[12]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[44]) );
  DFEQRM1SA reg_q_reg_1__11_ ( .D(reg_i_wdata[11]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[43]) );
  DFEQRM1SA reg_q_reg_1__10_ ( .D(reg_i_wdata[10]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[42]) );
  DFEQRM1SA reg_q_reg_1__9_ ( .D(reg_i_wdata[9]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[41]) );
  DFEQRM1SA reg_q_reg_1__8_ ( .D(reg_i_wdata[8]), .E(reg_wr[5]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[40]) );
  DFEQRM1SA reg_q_reg_1__23_ ( .D(reg_i_wdata[23]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[55]) );
  DFEQRM1SA reg_q_reg_1__21_ ( .D(reg_i_wdata[21]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[53]) );
  DFEQRM1SA reg_q_reg_1__20_ ( .D(reg_i_wdata[20]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[52]) );
  DFEQRM1SA reg_q_reg_1__19_ ( .D(reg_i_wdata[19]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[51]) );
  DFEQRM1SA reg_q_reg_1__18_ ( .D(reg_i_wdata[18]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[50]) );
  DFEQRM1SA reg_q_reg_1__17_ ( .D(reg_i_wdata[17]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[49]) );
  DFEQRM1SA reg_q_reg_1__16_ ( .D(reg_i_wdata[16]), .E(reg_wr[6]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[48]) );
  DFEQRM1SA reg_q_reg_1__31_ ( .D(reg_i_wdata[31]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[63]) );
  DFEQRM1SA reg_q_reg_1__30_ ( .D(reg_i_wdata[30]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[62]) );
  DFEQRM1SA reg_q_reg_1__29_ ( .D(reg_i_wdata[29]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[61]) );
  DFEQRM1SA reg_q_reg_1__28_ ( .D(reg_i_wdata[28]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[60]) );
  DFEQRM1SA reg_q_reg_1__27_ ( .D(reg_i_wdata[27]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[59]) );
  DFEQRM1SA reg_q_reg_1__26_ ( .D(reg_i_wdata[26]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[58]) );
  DFEQRM1SA reg_q_reg_1__25_ ( .D(reg_i_wdata[25]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[57]) );
  DFEQRM1SA reg_q_reg_1__24_ ( .D(reg_i_wdata[24]), .E(reg_wr[7]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[56]) );
  DFEQRM1SA reg_q_reg_2__6_ ( .D(reg_i_wdata[6]), .E(reg_wr[8]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[70]) );
  DFEQRM1SA reg_q_reg_2__5_ ( .D(reg_i_wdata[5]), .E(reg_wr[8]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[69]) );
  DFERM1SA reg_q_reg_2__4_ ( .D(n61), .E(reg_wr[8]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_8), .QB(wr_val_o[68]) );
  DFERM1SA reg_q_reg_2__3_ ( .D(n60), .E(reg_wr[8]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_9), .QB(wr_val_o[67]) );
  DFEQRM1SA reg_q_reg_2__2_ ( .D(reg_i_wdata[2]), .E(reg_wr[8]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[66]) );
  DFEQRM1SA reg_q_reg_2__1_ ( .D(reg_i_wdata[1]), .E(reg_wr[8]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[65]) );
  DFERM1SA reg_q_reg_2__0_ ( .D(n57), .E(reg_wr[8]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_10), .QB(wr_val_o[64]) );
  DFEQRM1SA reg_q_reg_2__15_ ( .D(reg_i_wdata[15]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[79]) );
  DFEQRM1SA reg_q_reg_2__14_ ( .D(reg_i_wdata[14]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[78]) );
  DFEQRM1SA reg_q_reg_2__13_ ( .D(reg_i_wdata[13]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[77]) );
  DFEQRM1SA reg_q_reg_2__12_ ( .D(reg_i_wdata[12]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[76]) );
  DFEQRM1SA reg_q_reg_2__11_ ( .D(reg_i_wdata[11]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[75]) );
  DFEQRM1SA reg_q_reg_2__10_ ( .D(reg_i_wdata[10]), .E(reg_wr[9]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[74]) );
  DFERM1SA reg_q_reg_2__9_ ( .D(n48), .E(reg_wr[9]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_11), .QB(wr_val_o[73]) );
  DFEQRM1SA reg_q_reg_2__23_ ( .D(reg_i_wdata[23]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[87]) );
  DFEQRM1SA reg_q_reg_2__22_ ( .D(reg_i_wdata[22]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[86]) );
  DFEQRM1SA reg_q_reg_2__21_ ( .D(reg_i_wdata[21]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[85]) );
  DFEQRM1SA reg_q_reg_2__20_ ( .D(reg_i_wdata[20]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[84]) );
  DFEQRM1SA reg_q_reg_2__19_ ( .D(reg_i_wdata[19]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[83]) );
  DFEQRM1SA reg_q_reg_2__18_ ( .D(reg_i_wdata[18]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[82]) );
  DFEQRM1SA reg_q_reg_2__17_ ( .D(reg_i_wdata[17]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[81]) );
  DFEQRM1SA reg_q_reg_2__16_ ( .D(reg_i_wdata[16]), .E(reg_wr[10]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[80]) );
  DFEQRM1SA reg_q_reg_2__31_ ( .D(reg_i_wdata[31]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[95]) );
  DFEQRM1SA reg_q_reg_2__30_ ( .D(reg_i_wdata[30]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[94]) );
  DFEQRM1SA reg_q_reg_2__29_ ( .D(reg_i_wdata[29]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[93]) );
  DFEQRM1SA reg_q_reg_2__28_ ( .D(reg_i_wdata[28]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[92]) );
  DFEQRM1SA reg_q_reg_2__27_ ( .D(reg_i_wdata[27]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[91]) );
  DFEQRM1SA reg_q_reg_2__26_ ( .D(reg_i_wdata[26]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[90]) );
  DFEQRM1SA reg_q_reg_2__24_ ( .D(reg_i_wdata[24]), .E(reg_wr[11]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[88]) );
  DFEQRM1SA reg_q_reg_3__7_ ( .D(reg_i_wdata[7]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[103]) );
  DFEQRM1SA reg_q_reg_3__6_ ( .D(reg_i_wdata[6]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[102]) );
  DFEQRM1SA reg_q_reg_3__5_ ( .D(reg_i_wdata[5]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[101]) );
  DFEQRM1SA reg_q_reg_3__4_ ( .D(reg_i_wdata[4]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[100]) );
  DFEQRM1SA reg_q_reg_3__3_ ( .D(reg_i_wdata[3]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[99]) );
  DFERM1SA reg_q_reg_3__2_ ( .D(n59), .E(reg_wr[12]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_12), .QB(wr_val_o[98]) );
  DFERM1SA reg_q_reg_3__1_ ( .D(n58), .E(reg_wr[12]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_13), .QB(wr_val_o[97]) );
  DFEQRM1SA reg_q_reg_3__0_ ( .D(reg_i_wdata[0]), .E(reg_wr[12]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[96]) );
  DFEQRM1SA reg_q_reg_3__15_ ( .D(reg_i_wdata[15]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[111]) );
  DFEQRM1SA reg_q_reg_3__14_ ( .D(reg_i_wdata[14]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[110]) );
  DFEQRM1SA reg_q_reg_3__13_ ( .D(reg_i_wdata[13]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[109]) );
  DFEQRM1SA reg_q_reg_3__12_ ( .D(reg_i_wdata[12]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[108]) );
  DFEQRM1SA reg_q_reg_3__11_ ( .D(reg_i_wdata[11]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[107]) );
  DFEQRM1SA reg_q_reg_3__9_ ( .D(reg_i_wdata[9]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[105]) );
  DFEQRM1SA reg_q_reg_3__8_ ( .D(reg_i_wdata[8]), .E(reg_wr[13]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[104]) );
  DFEQRM1SA reg_q_reg_3__23_ ( .D(reg_i_wdata[23]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[119]) );
  DFEQRM1SA reg_q_reg_3__22_ ( .D(reg_i_wdata[22]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[118]) );
  DFEQRM1SA reg_q_reg_3__21_ ( .D(reg_i_wdata[21]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[117]) );
  DFEQRM1SA reg_q_reg_3__20_ ( .D(reg_i_wdata[20]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[116]) );
  DFEQRM1SA reg_q_reg_3__19_ ( .D(reg_i_wdata[19]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[115]) );
  DFEQRM1SA reg_q_reg_3__18_ ( .D(reg_i_wdata[18]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[114]) );
  DFEQRM1SA reg_q_reg_3__17_ ( .D(reg_i_wdata[17]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[113]) );
  DFEQRM1SA reg_q_reg_3__16_ ( .D(reg_i_wdata[16]), .E(reg_wr[14]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[112]) );
  DFEQRM1SA reg_q_reg_3__31_ ( .D(reg_i_wdata[31]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[127]) );
  DFEQRM1SA reg_q_reg_3__30_ ( .D(reg_i_wdata[30]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[126]) );
  DFEQRM1SA reg_q_reg_3__29_ ( .D(reg_i_wdata[29]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[125]) );
  DFEQRM1SA reg_q_reg_3__28_ ( .D(reg_i_wdata[28]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[124]) );
  DFEQRM1SA reg_q_reg_3__26_ ( .D(reg_i_wdata[26]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[122]) );
  DFEQRM1SA reg_q_reg_3__25_ ( .D(reg_i_wdata[25]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[121]) );
  DFEQRM1SA reg_q_reg_3__24_ ( .D(reg_i_wdata[24]), .E(reg_wr[15]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[120]) );
  DFERM1SA reg_q_reg_4__7_ ( .D(n64), .E(reg_wr[16]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_14), .QB(wr_val_o[135]) );
  DFERM1SA reg_q_reg_4__6_ ( .D(n63), .E(reg_wr[16]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_15), .QB(wr_val_o[134]) );
  DFEQRM1SA reg_q_reg_4__5_ ( .D(reg_i_wdata[5]), .E(reg_wr[16]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[133]) );
  DFERM1SA reg_q_reg_4__4_ ( .D(n61), .E(reg_wr[16]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_16), .QB(wr_val_o[132]) );
  DFEQRM1SA reg_q_reg_4__3_ ( .D(reg_i_wdata[3]), .E(reg_wr[16]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[131]) );
  DFEQRM1SA reg_q_reg_4__2_ ( .D(reg_i_wdata[2]), .E(reg_wr[16]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[130]) );
  DFEQRM1SA reg_q_reg_4__1_ ( .D(reg_i_wdata[1]), .E(reg_wr[16]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[129]) );
  DFEQRM1SA reg_q_reg_4__0_ ( .D(reg_i_wdata[0]), .E(reg_wr[16]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[128]) );
  DFEQRM1SA reg_q_reg_4__15_ ( .D(reg_i_wdata[15]), .E(reg_wr[17]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[143]) );
  DFEQRM1SA reg_q_reg_4__14_ ( .D(reg_i_wdata[14]), .E(reg_wr[17]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[142]) );
  DFEQRM1SA reg_q_reg_4__13_ ( .D(reg_i_wdata[13]), .E(reg_wr[17]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[141]) );
  DFEQRM1SA reg_q_reg_4__11_ ( .D(reg_i_wdata[11]), .E(reg_wr[17]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[139]) );
  DFERM1SA reg_q_reg_4__10_ ( .D(n49), .E(reg_wr[17]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_17), .QB(wr_val_o[138]) );
  DFERM1SA reg_q_reg_4__9_ ( .D(n48), .E(reg_wr[17]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_18), .QB(wr_val_o[137]) );
  DFERM1SA reg_q_reg_4__8_ ( .D(n47), .E(reg_wr[17]), .CK(clk_i), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_19), .QB(wr_val_o[136]) );
  DFEQRM1SA reg_q_reg_4__23_ ( .D(reg_i_wdata[23]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[151]) );
  DFEQRM1SA reg_q_reg_4__22_ ( .D(reg_i_wdata[22]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[150]) );
  DFEQRM1SA reg_q_reg_4__21_ ( .D(reg_i_wdata[21]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[149]) );
  DFEQRM1SA reg_q_reg_4__20_ ( .D(reg_i_wdata[20]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[148]) );
  DFEQRM1SA reg_q_reg_4__19_ ( .D(reg_i_wdata[19]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[147]) );
  DFEQRM1SA reg_q_reg_4__18_ ( .D(reg_i_wdata[18]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[146]) );
  DFEQRM1SA reg_q_reg_4__17_ ( .D(reg_i_wdata[17]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[145]) );
  DFEQRM1SA reg_q_reg_4__16_ ( .D(reg_i_wdata[16]), .E(reg_wr[18]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[144]) );
  DFEQRM1SA reg_q_reg_4__31_ ( .D(reg_i_wdata[31]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[159]) );
  DFEQRM1SA reg_q_reg_4__30_ ( .D(reg_i_wdata[30]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[158]) );
  DFEQRM1SA reg_q_reg_4__28_ ( .D(reg_i_wdata[28]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[156]) );
  DFEQRM1SA reg_q_reg_4__27_ ( .D(reg_i_wdata[27]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[155]) );
  DFEQRM1SA reg_q_reg_4__26_ ( .D(reg_i_wdata[26]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[154]) );
  DFEQRM1SA reg_q_reg_4__25_ ( .D(reg_i_wdata[25]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[153]) );
  DFEQRM1SA reg_q_reg_4__24_ ( .D(reg_i_wdata[24]), .E(reg_wr[19]), .CK(clk_i), 
        .RB(rst_ni), .Q(wr_val_o[152]) );
  DFEQRM1SA reg_q_reg_8__31_ ( .D(reg_i_wdata[31]), .E(n867), .CK(clk_i), .RB(
        rst_ni), .Q(n868) );
  DFEQRM1SA reg_q_reg_5__6_ ( .D(reg_i_wdata[6]), .E(n846), .CK(clk_i), .RB(
        rst_ni), .Q(wr_val_o[166]) );
  DFERM1SA reg_q_reg_8__22_ ( .D(n859), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_20), .QB(wr_val_o[278]) );
  DFERM1SA reg_q_reg_8__21_ ( .D(n860), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_21), .QB(wr_val_o[277]) );
  DFERM1SA reg_q_reg_8__20_ ( .D(n861), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_22), .QB(wr_val_o[276]) );
  DFERM1SA reg_q_reg_8__19_ ( .D(n862), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_23), .QB(wr_val_o[275]) );
  DFERM1SA reg_q_reg_8__18_ ( .D(n863), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_24), .QB(wr_val_o[274]) );
  DFERM1SA reg_q_reg_8__17_ ( .D(n864), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_25), .QB(wr_val_o[273]) );
  DFERM1SA reg_q_reg_8__16_ ( .D(n865), .E(n866), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_26), .QB(wr_val_o[272]) );
  DFERM1SA reg_q_reg_8__14_ ( .D(n854), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_27), .QB(wr_val_o[270]) );
  DFERM1SA reg_q_reg_8__13_ ( .D(n855), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_28), .QB(wr_val_o[269]) );
  DFERM1SA reg_q_reg_8__12_ ( .D(n856), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_29), .QB(wr_val_o[268]) );
  DFERM1SA reg_q_reg_8__11_ ( .D(n857), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_30), .QB(wr_val_o[267]) );
  DFERM1SA reg_q_reg_8__10_ ( .D(n49), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_31), .QB(wr_val_o[266]) );
  DFERM1SA reg_q_reg_8__9_ ( .D(n48), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_32), .QB(wr_val_o[265]) );
  DFERM1SA reg_q_reg_8__8_ ( .D(n47), .E(n858), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_33), .QB(wr_val_o[264]) );
  DFERM1SA reg_q_reg_8__7_ ( .D(n64), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_34), .QB(wr_val_o[263]) );
  DFERM1SA reg_q_reg_8__6_ ( .D(n63), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_35), .QB(wr_val_o[262]) );
  DFERM1SA reg_q_reg_8__5_ ( .D(n851), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_36), .QB(wr_val_o[261]) );
  DFERM1SA reg_q_reg_8__4_ ( .D(n61), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_37), .QB(wr_val_o[260]) );
  DFERM1SA reg_q_reg_8__3_ ( .D(n60), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_38), .QB(wr_val_o[259]) );
  DFERM1SA reg_q_reg_8__2_ ( .D(n59), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_39), .QB(wr_val_o[258]) );
  DFERM1SA reg_q_reg_8__1_ ( .D(n58), .E(n852), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_40), .QB(wr_val_o[257]) );
  DFERM1SA reg_q_reg_7__22_ ( .D(n859), .E(n850), .CK(clk_i), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_41), .QB(wr_val_o[246]) );
  DFERM1SA reg_q_reg_6__21_ ( .D(n860), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n824), .QB(wr_val_o[213]) );
  DFERM1SA reg_q_reg_6__20_ ( .D(n861), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n825), .QB(wr_val_o[212]) );
  DFERM1SA reg_q_reg_6__19_ ( .D(n862), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n826), .QB(wr_val_o[211]) );
  DFERM1SA reg_q_reg_6__18_ ( .D(n863), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n827), .QB(wr_val_o[210]) );
  DFERM1SA reg_q_reg_6__17_ ( .D(n864), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n828), .QB(wr_val_o[209]) );
  DFERM1SA reg_q_reg_6__16_ ( .D(n865), .E(n849), .CK(clk_i), .RB(rst_ni), .Q(
        n829), .QB(wr_val_o[208]) );
  DFERM1SA reg_q_reg_6__15_ ( .D(n853), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n830), .QB(wr_val_o[207]) );
  DFERM1SA reg_q_reg_6__14_ ( .D(n854), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n831), .QB(wr_val_o[206]) );
  DFERM1SA reg_q_reg_6__13_ ( .D(n855), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n832), .QB(wr_val_o[205]) );
  DFERM1SA reg_q_reg_6__12_ ( .D(n856), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n833), .QB(wr_val_o[204]) );
  DFERM1SA reg_q_reg_6__11_ ( .D(n857), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n834), .QB(wr_val_o[203]) );
  DFERM1SA reg_q_reg_6__10_ ( .D(n49), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n835), .QB(wr_val_o[202]) );
  DFERM1SA reg_q_reg_6__9_ ( .D(n48), .E(n848), .CK(clk_i), .RB(rst_ni), .Q(
        n836), .QB(wr_val_o[201]) );
  DFERM1SA reg_q_reg_6__7_ ( .D(n64), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n838), .QB(wr_val_o[199]) );
  DFERM1SA reg_q_reg_6__6_ ( .D(n63), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n839), .QB(wr_val_o[198]) );
  DFERM1SA reg_q_reg_6__5_ ( .D(n851), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n840), .QB(wr_val_o[197]) );
  DFERM1SA reg_q_reg_6__4_ ( .D(n61), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n841), .QB(wr_val_o[196]) );
  DFERM1SA reg_q_reg_6__3_ ( .D(n60), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n842), .QB(wr_val_o[195]) );
  DFERM1SA reg_q_reg_6__2_ ( .D(n59), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n843), .QB(wr_val_o[194]) );
  DFERM1SA reg_q_reg_6__1_ ( .D(n58), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n844), .QB(wr_val_o[193]) );
  DFERM1SA reg_q_reg_6__0_ ( .D(n57), .E(n847), .CK(clk_i), .RB(rst_ni), .Q(
        n845), .QB(wr_val_o[192]) );
  AO22M1SA U469 ( .A1(n70), .A2(n80), .B1(n444), .B2(1'b0), .Z(n234) );
  NR2M2R U3 ( .A(n635), .B(n643), .Z(reg_wr[8]) );
  NR2M2R U4 ( .A(n637), .B(n640), .Z(reg_wr[2]) );
  OA211M1SA U5 ( .A1(n817), .A2(n844), .B(n756), .C(n755), .Z(n757) );
  OA211M1SA U6 ( .A1(n817), .A2(n839), .B(n781), .C(n780), .Z(n782) );
  OA211M1SA U7 ( .A1(n817), .A2(n834), .B(n721), .C(n720), .Z(n722) );
  OA211M1SA U8 ( .A1(n817), .A2(n829), .B(n647), .C(n646), .Z(n648) );
  OA211M1SA U9 ( .A1(n817), .A2(n824), .B(n746), .C(n745), .Z(n747) );
  OA211M1SA U10 ( .A1(n817), .A2(n681), .B(n680), .C(n679), .Z(n682) );
  ND2M2R U11 ( .A(n611), .B(reg_i_wstrb[3]), .Z(n638) );
  ND2M2R U12 ( .A(n611), .B(reg_i_wstrb[2]), .Z(n637) );
  ND2M2R U13 ( .A(n611), .B(reg_i_wstrb[0]), .Z(n635) );
  ND2M2R U14 ( .A(n611), .B(reg_i_wstrb[1]), .Z(n636) );
  NR2B1M2R U15 ( .NA(reg_i_write), .B(n807), .Z(n611) );
  ND2M4R U16 ( .A(reg_i_valid), .B(n70), .Z(n807) );
  AO22B10M1S U17 ( .B1(reg_i_addr[5]), .B2(n868), .A1(n870), .NA2(n817), .Z(
        n818) );
  ND2M2W U18 ( .A(reg_i_addr[4]), .B(n629), .Z(n817) );
  ND2M2R U19 ( .A(n632), .B(n631), .Z(n644) );
  ND2M2R U20 ( .A(n629), .B(n631), .Z(n643) );
  OR3M2R U21 ( .A(reg_i_addr[4]), .B(reg_i_addr[3]), .C(n630), .Z(n645) );
  ND2M2R U22 ( .A(reg_i_addr[4]), .B(n632), .Z(n639) );
  OR4M2R U23 ( .A(reg_i_addr[2]), .B(n631), .C(reg_i_addr[3]), .D(
        reg_i_addr[5]), .Z(n642) );
  OR4M1S U24 ( .A(reg_i_addr[6]), .B(reg_i_addr[30]), .C(reg_i_addr[31]), .D(
        reg_i_addr[16]), .Z(n610) );
  NR3M2R U25 ( .A(reg_i_addr[2]), .B(reg_i_addr[5]), .C(n612), .Z(n629) );
  AN4M1S U26 ( .A(n606), .B(n605), .C(n604), .D(n603), .Z(n607) );
  ND2M1R U27 ( .A(reg_i_addr[2]), .B(n633), .Z(n630) );
  NR4M1S U28 ( .A(reg_i_addr[28]), .B(reg_i_addr[8]), .C(reg_i_addr[12]), .D(
        reg_i_addr[7]), .Z(n604) );
  NR2M2W U29 ( .A(n612), .B(n630), .Z(n632) );
  NR2M2R U30 ( .A(n636), .B(n640), .Z(reg_wr[1]) );
  NR2M2S U31 ( .A(n635), .B(n639), .Z(n613) );
  NR2M2S U32 ( .A(n635), .B(n641), .Z(n846) );
  NR2M2S U33 ( .A(n636), .B(n817), .Z(n848) );
  NR2M2S U34 ( .A(n635), .B(n817), .Z(n847) );
  NR2M2S U35 ( .A(n641), .B(n638), .Z(n625) );
  NR2M2S U36 ( .A(n636), .B(n639), .Z(n621) );
  NR2M2S U37 ( .A(n633), .B(n636), .Z(n858) );
  NR2M2S U38 ( .A(n633), .B(n635), .Z(n852) );
  NR2M2S U39 ( .A(n638), .B(n639), .Z(n620) );
  NR2M2S U40 ( .A(n637), .B(n639), .Z(n850) );
  NR2M2S U41 ( .A(n638), .B(n817), .Z(n628) );
  NR2M2S U42 ( .A(n641), .B(n636), .Z(n623) );
  NR2M2S U43 ( .A(n633), .B(n638), .Z(n867) );
  NR2M2S U44 ( .A(n637), .B(n817), .Z(n849) );
  NR2M2S U45 ( .A(n641), .B(n637), .Z(n614) );
  NR2M2S U46 ( .A(n636), .B(n642), .Z(reg_wr[17]) );
  NR2M2S U47 ( .A(n633), .B(n637), .Z(n866) );
  NR2M2S U48 ( .A(n635), .B(n642), .Z(reg_wr[16]) );
  NR2M2S U49 ( .A(n636), .B(n645), .Z(reg_wr[5]) );
  NR2M2S U50 ( .A(n638), .B(n640), .Z(reg_wr[3]) );
  NR2M2S U51 ( .A(n637), .B(n642), .Z(reg_wr[18]) );
  NR2M2S U52 ( .A(n636), .B(n643), .Z(reg_wr[9]) );
  NR2M2S U53 ( .A(n635), .B(n645), .Z(reg_wr[4]) );
  NR2M2S U54 ( .A(n637), .B(n644), .Z(reg_wr[14]) );
  NR2M2S U55 ( .A(n635), .B(n644), .Z(reg_wr[12]) );
  NR2M2S U56 ( .A(n637), .B(n645), .Z(reg_wr[6]) );
  NR2M2S U57 ( .A(n637), .B(n643), .Z(reg_wr[10]) );
  NR2M2S U58 ( .A(n635), .B(n640), .Z(reg_wr[0]) );
  NR2M2S U59 ( .A(n638), .B(n643), .Z(reg_wr[11]) );
  NR2M2S U60 ( .A(n638), .B(n644), .Z(reg_wr[15]) );
  NR2M2S U61 ( .A(n636), .B(n644), .Z(reg_wr[13]) );
  NR2M2S U62 ( .A(n638), .B(n642), .Z(reg_wr[19]) );
  NR2M2S U63 ( .A(n638), .B(n645), .Z(reg_wr[7]) );
  OA211M2WA U64 ( .A1(n817), .A2(n830), .B(n716), .C(n715), .Z(n717) );
  OA211M2WA U65 ( .A1(n817), .A2(n699), .B(n698), .C(n697), .Z(n700) );
  OA211M2WA U66 ( .A1(n817), .A2(n835), .B(n801), .C(n800), .Z(n802) );
  OA211M2WA U67 ( .A1(n817), .A2(n693), .B(n692), .C(n691), .Z(n694) );
  OA211M2WA U68 ( .A1(n817), .A2(n836), .B(n796), .C(n795), .Z(n797) );
  OA211M2WA U69 ( .A1(n817), .A2(n687), .B(n686), .C(n685), .Z(n688) );
  OA211M2WA U70 ( .A1(n817), .A2(n837), .B(n791), .C(n790), .Z(n792) );
  OA211M2WA U71 ( .A1(n817), .A2(n828), .B(n726), .C(n725), .Z(n727) );
  OA211M2WA U72 ( .A1(n817), .A2(n838), .B(n786), .C(n785), .Z(n787) );
  OA211M2WA U73 ( .A1(n817), .A2(n827), .B(n731), .C(n730), .Z(n732) );
  OA211M2WA U74 ( .A1(n817), .A2(n840), .B(n776), .C(n775), .Z(n777) );
  OA211M2WA U75 ( .A1(n817), .A2(n675), .B(n674), .C(n673), .Z(n676) );
  OA211M2WA U76 ( .A1(n817), .A2(n841), .B(n771), .C(n770), .Z(n772) );
  OA211M2WA U77 ( .A1(n817), .A2(n842), .B(n766), .C(n765), .Z(n767) );
  OA211M2WA U78 ( .A1(n817), .A2(n826), .B(n652), .C(n651), .Z(n653) );
  OA211M2WA U79 ( .A1(n817), .A2(n711), .B(n710), .C(n709), .Z(n712) );
  OA211M2WA U80 ( .A1(n817), .A2(n825), .B(n741), .C(n740), .Z(n742) );
  OA211M2WA U81 ( .A1(n817), .A2(n843), .B(n761), .C(n760), .Z(n762) );
  OA211M2WA U82 ( .A1(n817), .A2(n845), .B(n751), .C(n750), .Z(n752) );
  OA211M2WA U83 ( .A1(n817), .A2(n663), .B(n662), .C(n661), .Z(n664) );
  OA211M2WA U84 ( .A1(n817), .A2(n669), .B(n668), .C(n667), .Z(n670) );
  OA211M2WA U85 ( .A1(n817), .A2(n831), .B(n736), .C(n735), .Z(n737) );
  OA211M2WA U86 ( .A1(n817), .A2(n832), .B(n657), .C(n656), .Z(n658) );
  ND4M2W U87 ( .A(n823), .B(n822), .C(n821), .D(n820), .Z(n80) );
  OA211M2WA U88 ( .A1(n817), .A2(n833), .B(n806), .C(n805), .Z(n808) );
  OA211M2WA U89 ( .A1(n817), .A2(n705), .B(n704), .C(n703), .Z(n706) );
  AOI22M1R U90 ( .A1(n814), .A2(wr_val_o[245]), .B1(n813), .B2(rd_val_i[21]), 
        .Z(n749) );
  AOI22M1R U91 ( .A1(n814), .A2(wr_val_o[230]), .B1(n813), .B2(rd_val_i[6]), 
        .Z(n784) );
  AOI22M1R U92 ( .A1(n814), .A2(wr_val_o[225]), .B1(n813), .B2(rd_val_i[1]), 
        .Z(n759) );
  AOI22M1R U93 ( .A1(n814), .A2(wr_val_o[246]), .B1(n813), .B2(rd_val_i[22]), 
        .Z(n666) );
  AOI22M1R U94 ( .A1(n814), .A2(wr_val_o[243]), .B1(n813), .B2(rd_val_i[19]), 
        .Z(n655) );
  AOI22M1R U95 ( .A1(n814), .A2(wr_val_o[234]), .B1(n813), .B2(rd_val_i[10]), 
        .Z(n804) );
  AOI22M1R U96 ( .A1(n814), .A2(wr_val_o[228]), .B1(n813), .B2(rd_val_i[4]), 
        .Z(n774) );
  AOI22M1R U97 ( .A1(n816), .A2(rd_val_i[79]), .B1(n815), .B2(rd_val_i[111]), 
        .Z(n716) );
  AOI22M1R U98 ( .A1(n816), .A2(rd_val_i[73]), .B1(n815), .B2(rd_val_i[105]), 
        .Z(n796) );
  AOI22M1R U99 ( .A1(n816), .A2(rd_val_i[69]), .B1(n815), .B2(rd_val_i[101]), 
        .Z(n776) );
  AOI22M1R U100 ( .A1(n814), .A2(wr_val_o[237]), .B1(n813), .B2(rd_val_i[13]), 
        .Z(n660) );
  AOI22M1R U101 ( .A1(n814), .A2(wr_val_o[239]), .B1(n813), .B2(rd_val_i[15]), 
        .Z(n719) );
  AOI22M1R U102 ( .A1(n816), .A2(rd_val_i[74]), .B1(n815), .B2(rd_val_i[106]), 
        .Z(n801) );
  AOI22M1R U103 ( .A1(n816), .A2(rd_val_i[86]), .B1(n815), .B2(rd_val_i[118]), 
        .Z(n662) );
  AOI22M1R U104 ( .A1(n814), .A2(wr_val_o[240]), .B1(n813), .B2(rd_val_i[16]), 
        .Z(n650) );
  AOI22M1R U105 ( .A1(n816), .A2(rd_val_i[68]), .B1(n815), .B2(rd_val_i[100]), 
        .Z(n771) );
  AOI22M1R U106 ( .A1(n814), .A2(wr_val_o[247]), .B1(n813), .B2(rd_val_i[23]), 
        .Z(n672) );
  AOI22M1R U107 ( .A1(n816), .A2(rd_val_i[75]), .B1(n815), .B2(rd_val_i[107]), 
        .Z(n721) );
  AOI22M1R U108 ( .A1(n814), .A2(wr_val_o[236]), .B1(n813), .B2(rd_val_i[12]), 
        .Z(n810) );
  AOI22M1R U109 ( .A1(n816), .A2(rd_val_i[82]), .B1(n815), .B2(rd_val_i[114]), 
        .Z(n731) );
  AOI22M1R U110 ( .A1(n814), .A2(wr_val_o[229]), .B1(n813), .B2(rd_val_i[5]), 
        .Z(n779) );
  AOI22M1R U111 ( .A1(n814), .A2(wr_val_o[232]), .B1(n813), .B2(rd_val_i[8]), 
        .Z(n794) );
  AOI22M1R U112 ( .A1(n814), .A2(wr_val_o[235]), .B1(n813), .B2(rd_val_i[11]), 
        .Z(n724) );
  AOI22M1R U113 ( .A1(n816), .A2(rd_val_i[65]), .B1(n815), .B2(rd_val_i[97]), 
        .Z(n756) );
  AOI22M1R U114 ( .A1(n816), .A2(rd_val_i[67]), .B1(n815), .B2(rd_val_i[99]), 
        .Z(n766) );
  AOI22M1R U115 ( .A1(n816), .A2(rd_val_i[64]), .B1(n815), .B2(rd_val_i[96]), 
        .Z(n751) );
  AOI22M1R U116 ( .A1(n814), .A2(wr_val_o[238]), .B1(n813), .B2(rd_val_i[14]), 
        .Z(n739) );
  AOI22M1R U117 ( .A1(n814), .A2(wr_val_o[226]), .B1(n813), .B2(rd_val_i[2]), 
        .Z(n764) );
  AOI22M1R U118 ( .A1(n814), .A2(wr_val_o[242]), .B1(n813), .B2(rd_val_i[18]), 
        .Z(n734) );
  AOI22M1R U119 ( .A1(n814), .A2(wr_val_o[241]), .B1(n813), .B2(rd_val_i[17]), 
        .Z(n729) );
  AOI22M1R U120 ( .A1(n816), .A2(rd_val_i[84]), .B1(n815), .B2(rd_val_i[116]), 
        .Z(n741) );
  AOI22M1R U121 ( .A1(n816), .A2(rd_val_i[70]), .B1(n815), .B2(rd_val_i[102]), 
        .Z(n781) );
  AOI22M1R U122 ( .A1(n816), .A2(rd_val_i[80]), .B1(n815), .B2(rd_val_i[112]), 
        .Z(n647) );
  AOI22M1R U123 ( .A1(n816), .A2(rd_val_i[83]), .B1(n815), .B2(rd_val_i[115]), 
        .Z(n652) );
  AOI22M1R U124 ( .A1(n814), .A2(wr_val_o[233]), .B1(n813), .B2(rd_val_i[9]), 
        .Z(n799) );
  AOI22M1R U125 ( .A1(n814), .A2(wr_val_o[244]), .B1(n813), .B2(rd_val_i[20]), 
        .Z(n744) );
  AOI22M1R U126 ( .A1(n814), .A2(wr_val_o[231]), .B1(n813), .B2(rd_val_i[7]), 
        .Z(n789) );
  AOI22M1R U127 ( .A1(n816), .A2(rd_val_i[78]), .B1(n815), .B2(rd_val_i[110]), 
        .Z(n736) );
  AOI22M1R U128 ( .A1(n814), .A2(wr_val_o[227]), .B1(n813), .B2(rd_val_i[3]), 
        .Z(n769) );
  AOI22M1R U129 ( .A1(n816), .A2(rd_val_i[76]), .B1(n815), .B2(rd_val_i[108]), 
        .Z(n806) );
  AOI22M1R U130 ( .A1(n816), .A2(rd_val_i[85]), .B1(n815), .B2(rd_val_i[117]), 
        .Z(n746) );
  AOI22M1R U131 ( .A1(n816), .A2(rd_val_i[77]), .B1(n815), .B2(rd_val_i[109]), 
        .Z(n657) );
  AOI22M1R U132 ( .A1(n816), .A2(rd_val_i[81]), .B1(n815), .B2(rd_val_i[113]), 
        .Z(n726) );
  AOI22M1R U133 ( .A1(n814), .A2(wr_val_o[224]), .B1(n813), .B2(rd_val_i[0]), 
        .Z(n754) );
  AOI22M1R U134 ( .A1(n816), .A2(rd_val_i[72]), .B1(n815), .B2(rd_val_i[104]), 
        .Z(n791) );
  AOI22M1R U135 ( .A1(n816), .A2(rd_val_i[71]), .B1(n815), .B2(rd_val_i[103]), 
        .Z(n786) );
  AOI22M1R U136 ( .A1(n816), .A2(rd_val_i[66]), .B1(n815), .B2(rd_val_i[98]), 
        .Z(n761) );
  AOI22M1R U137 ( .A1(n816), .A2(rd_val_i[87]), .B1(n815), .B2(rd_val_i[119]), 
        .Z(n668) );
  AOI22M1R U138 ( .A1(n814), .A2(wr_val_o[254]), .B1(n813), .B2(rd_val_i[30]), 
        .Z(n708) );
  AOI22M1R U139 ( .A1(n814), .A2(wr_val_o[248]), .B1(n813), .B2(rd_val_i[24]), 
        .Z(n714) );
  AOI22M1R U140 ( .A1(n816), .A2(rd_val_i[93]), .B1(n815), .B2(rd_val_i[125]), 
        .Z(n698) );
  AOI22M1R U141 ( .A1(n816), .A2(rd_val_i[88]), .B1(n815), .B2(rd_val_i[120]), 
        .Z(n710) );
  AOI22M1R U142 ( .A1(n814), .A2(wr_val_o[253]), .B1(n813), .B2(rd_val_i[29]), 
        .Z(n702) );
  AOI22M1R U143 ( .A1(n814), .A2(wr_val_o[249]), .B1(n813), .B2(rd_val_i[25]), 
        .Z(n678) );
  AOI22M1R U144 ( .A1(n816), .A2(rd_val_i[92]), .B1(n815), .B2(rd_val_i[124]), 
        .Z(n692) );
  AOI22M1R U145 ( .A1(n816), .A2(rd_val_i[89]), .B1(n815), .B2(rd_val_i[121]), 
        .Z(n674) );
  AOI22M1R U146 ( .A1(n814), .A2(wr_val_o[252]), .B1(n813), .B2(rd_val_i[28]), 
        .Z(n696) );
  AOI22M1R U147 ( .A1(n814), .A2(wr_val_o[250]), .B1(n813), .B2(rd_val_i[26]), 
        .Z(n684) );
  AOI22M1R U148 ( .A1(n816), .A2(rd_val_i[90]), .B1(n815), .B2(rd_val_i[122]), 
        .Z(n680) );
  AOI22M1R U149 ( .A1(n816), .A2(rd_val_i[91]), .B1(n815), .B2(rd_val_i[123]), 
        .Z(n686) );
  AOI22M1R U150 ( .A1(n814), .A2(wr_val_o[251]), .B1(n813), .B2(rd_val_i[27]), 
        .Z(n690) );
  AOI22M2R U151 ( .A1(n816), .A2(rd_val_i[95]), .B1(n815), .B2(rd_val_i[127]), 
        .Z(n821) );
  AOI22M2W U152 ( .A1(n814), .A2(n869), .B1(n813), .B2(rd_val_i[31]), .Z(n822)
         );
  AOI22M1R U153 ( .A1(n816), .A2(rd_val_i[94]), .B1(n815), .B2(rd_val_i[126]), 
        .Z(n704) );
  AOI22M1R U154 ( .A1(reg_i_addr[5]), .A2(wr_val_o[280]), .B1(n819), .B2(
        rd_val_i[56]), .Z(n709) );
  AOI22M1R U155 ( .A1(reg_i_addr[5]), .A2(wr_val_o[281]), .B1(n819), .B2(
        rd_val_i[57]), .Z(n673) );
  AOI21M1R U156 ( .A1(n819), .A2(rd_val_i[63]), .B(n818), .Z(n820) );
  INVM2W U157 ( .A(n644), .Z(n815) );
  AOI22M1R U158 ( .A1(reg_i_addr[5]), .A2(wr_val_o[285]), .B1(n819), .B2(
        rd_val_i[61]), .Z(n697) );
  AOI22M1R U159 ( .A1(reg_i_addr[5]), .A2(wr_val_o[284]), .B1(n819), .B2(
        rd_val_i[60]), .Z(n691) );
  AOI22M1R U160 ( .A1(reg_i_addr[5]), .A2(wr_val_o[283]), .B1(n819), .B2(
        rd_val_i[59]), .Z(n685) );
  AOI22M1R U161 ( .A1(reg_i_addr[5]), .A2(wr_val_o[286]), .B1(n819), .B2(
        rd_val_i[62]), .Z(n703) );
  AOI22M1R U162 ( .A1(reg_i_addr[5]), .A2(wr_val_o[282]), .B1(n819), .B2(
        rd_val_i[58]), .Z(n679) );
  INVM2W U163 ( .A(n639), .Z(n814) );
  AOI22M1R U164 ( .A1(reg_i_addr[5]), .A2(wr_val_o[269]), .B1(n819), .B2(
        rd_val_i[45]), .Z(n656) );
  AOI22M1R U165 ( .A1(reg_i_addr[5]), .A2(wr_val_o[278]), .B1(n819), .B2(
        rd_val_i[54]), .Z(n661) );
  AOI22M1R U166 ( .A1(reg_i_addr[5]), .A2(wr_val_o[277]), .B1(n819), .B2(
        rd_val_i[53]), .Z(n745) );
  AOI22M1R U167 ( .A1(reg_i_addr[5]), .A2(wr_val_o[256]), .B1(n819), .B2(
        rd_val_i[32]), .Z(n750) );
  AOI22M1R U168 ( .A1(reg_i_addr[5]), .A2(wr_val_o[276]), .B1(n819), .B2(
        rd_val_i[52]), .Z(n740) );
  AOI22M1R U169 ( .A1(reg_i_addr[5]), .A2(wr_val_o[257]), .B1(n819), .B2(
        rd_val_i[33]), .Z(n755) );
  AOI22M1R U170 ( .A1(reg_i_addr[5]), .A2(wr_val_o[258]), .B1(n819), .B2(
        rd_val_i[34]), .Z(n760) );
  AOI22M1R U171 ( .A1(reg_i_addr[5]), .A2(wr_val_o[275]), .B1(n819), .B2(
        rd_val_i[51]), .Z(n651) );
  AOI22M1R U172 ( .A1(reg_i_addr[5]), .A2(wr_val_o[259]), .B1(n819), .B2(
        rd_val_i[35]), .Z(n765) );
  AOI22M1R U173 ( .A1(reg_i_addr[5]), .A2(wr_val_o[274]), .B1(n819), .B2(
        rd_val_i[50]), .Z(n730) );
  AOI22M1R U174 ( .A1(reg_i_addr[5]), .A2(wr_val_o[260]), .B1(n819), .B2(
        rd_val_i[36]), .Z(n770) );
  AOI22M1R U175 ( .A1(reg_i_addr[5]), .A2(wr_val_o[261]), .B1(n819), .B2(
        rd_val_i[37]), .Z(n775) );
  AOI22M1R U176 ( .A1(reg_i_addr[5]), .A2(wr_val_o[262]), .B1(n819), .B2(
        rd_val_i[38]), .Z(n780) );
  AOI22M1R U177 ( .A1(reg_i_addr[5]), .A2(wr_val_o[273]), .B1(n819), .B2(
        rd_val_i[49]), .Z(n725) );
  AOI22M1R U178 ( .A1(reg_i_addr[5]), .A2(wr_val_o[263]), .B1(n819), .B2(
        rd_val_i[39]), .Z(n785) );
  AOI22M1R U179 ( .A1(reg_i_addr[5]), .A2(wr_val_o[264]), .B1(n819), .B2(
        rd_val_i[40]), .Z(n790) );
  AOI22M1R U180 ( .A1(reg_i_addr[5]), .A2(wr_val_o[272]), .B1(n819), .B2(
        rd_val_i[48]), .Z(n646) );
  AOI22M1R U181 ( .A1(reg_i_addr[5]), .A2(wr_val_o[265]), .B1(n819), .B2(
        rd_val_i[41]), .Z(n795) );
  AOI22M1R U182 ( .A1(reg_i_addr[5]), .A2(wr_val_o[266]), .B1(n819), .B2(
        rd_val_i[42]), .Z(n800) );
  AOI22M1R U183 ( .A1(reg_i_addr[5]), .A2(wr_val_o[271]), .B1(n819), .B2(
        rd_val_i[47]), .Z(n715) );
  AOI22M1R U184 ( .A1(reg_i_addr[5]), .A2(wr_val_o[267]), .B1(n819), .B2(
        rd_val_i[43]), .Z(n720) );
  AOI22M1R U185 ( .A1(reg_i_addr[5]), .A2(wr_val_o[270]), .B1(n819), .B2(
        rd_val_i[46]), .Z(n735) );
  AOI22M1R U186 ( .A1(reg_i_addr[5]), .A2(wr_val_o[268]), .B1(n819), .B2(
        rd_val_i[44]), .Z(n805) );
  AOI22M1R U187 ( .A1(reg_i_addr[5]), .A2(wr_val_o[279]), .B1(n819), .B2(
        rd_val_i[55]), .Z(n667) );
  AOI22M2W U188 ( .A1(n812), .A2(n871), .B1(n811), .B2(rd_val_i[159]), .Z(n823) );
  NR4M1W U189 ( .A(reg_i_addr[13]), .B(reg_i_addr[15]), .C(n610), .D(n609), 
        .Z(n70) );
  AOI22M1R U190 ( .A1(n812), .A2(wr_val_o[190]), .B1(n811), .B2(rd_val_i[158]), 
        .Z(n707) );
  AOI22M1R U191 ( .A1(n812), .A2(wr_val_o[189]), .B1(n811), .B2(rd_val_i[157]), 
        .Z(n701) );
  AOI22M1R U192 ( .A1(n812), .A2(wr_val_o[188]), .B1(n811), .B2(rd_val_i[156]), 
        .Z(n695) );
  AOI22M1R U193 ( .A1(n812), .A2(wr_val_o[187]), .B1(n811), .B2(rd_val_i[155]), 
        .Z(n689) );
  AOI22M1R U194 ( .A1(n812), .A2(wr_val_o[186]), .B1(n811), .B2(rd_val_i[154]), 
        .Z(n683) );
  AOI22M1R U195 ( .A1(n812), .A2(wr_val_o[185]), .B1(n811), .B2(rd_val_i[153]), 
        .Z(n677) );
  AOI22M1R U196 ( .A1(n812), .A2(wr_val_o[184]), .B1(n811), .B2(rd_val_i[152]), 
        .Z(n713) );
  INVM2W U197 ( .A(n645), .Z(n819) );
  AOI22M1R U198 ( .A1(n812), .A2(wr_val_o[183]), .B1(n811), .B2(rd_val_i[151]), 
        .Z(n671) );
  AOI22M1R U199 ( .A1(n812), .A2(wr_val_o[182]), .B1(n811), .B2(rd_val_i[150]), 
        .Z(n665) );
  AOI22M1R U200 ( .A1(n812), .A2(wr_val_o[181]), .B1(n811), .B2(rd_val_i[149]), 
        .Z(n748) );
  AOI22M1R U201 ( .A1(n812), .A2(wr_val_o[180]), .B1(n811), .B2(rd_val_i[148]), 
        .Z(n743) );
  AOI22M1R U202 ( .A1(n812), .A2(wr_val_o[179]), .B1(n811), .B2(rd_val_i[147]), 
        .Z(n654) );
  AOI22M1R U203 ( .A1(n812), .A2(wr_val_o[178]), .B1(n811), .B2(rd_val_i[146]), 
        .Z(n733) );
  AOI22M1R U204 ( .A1(n812), .A2(wr_val_o[177]), .B1(n811), .B2(rd_val_i[145]), 
        .Z(n728) );
  AOI22M1R U205 ( .A1(n812), .A2(wr_val_o[176]), .B1(n811), .B2(rd_val_i[144]), 
        .Z(n649) );
  AOI22M1R U206 ( .A1(n812), .A2(wr_val_o[175]), .B1(n811), .B2(rd_val_i[143]), 
        .Z(n718) );
  AOI22M1R U207 ( .A1(n812), .A2(wr_val_o[174]), .B1(n811), .B2(rd_val_i[142]), 
        .Z(n738) );
  AOI22M1R U208 ( .A1(n812), .A2(wr_val_o[173]), .B1(n811), .B2(rd_val_i[141]), 
        .Z(n659) );
  AOI22M1R U209 ( .A1(n812), .A2(wr_val_o[172]), .B1(n811), .B2(rd_val_i[140]), 
        .Z(n809) );
  AOI22M1R U210 ( .A1(n812), .A2(wr_val_o[171]), .B1(n811), .B2(rd_val_i[139]), 
        .Z(n723) );
  AOI22M1R U211 ( .A1(n812), .A2(wr_val_o[170]), .B1(n811), .B2(rd_val_i[138]), 
        .Z(n803) );
  AOI22M1R U212 ( .A1(n812), .A2(wr_val_o[169]), .B1(n811), .B2(rd_val_i[137]), 
        .Z(n798) );
  AOI22M1R U213 ( .A1(n812), .A2(wr_val_o[168]), .B1(n811), .B2(rd_val_i[136]), 
        .Z(n793) );
  AOI22M1R U214 ( .A1(n812), .A2(wr_val_o[167]), .B1(n811), .B2(rd_val_i[135]), 
        .Z(n788) );
  AOI22M1R U215 ( .A1(n812), .A2(wr_val_o[166]), .B1(n811), .B2(rd_val_i[134]), 
        .Z(n783) );
  AOI22M1R U216 ( .A1(n812), .A2(wr_val_o[165]), .B1(n811), .B2(rd_val_i[133]), 
        .Z(n778) );
  AOI22M1R U217 ( .A1(n812), .A2(wr_val_o[164]), .B1(n811), .B2(rd_val_i[132]), 
        .Z(n773) );
  AOI22M1R U218 ( .A1(n812), .A2(wr_val_o[163]), .B1(n811), .B2(rd_val_i[131]), 
        .Z(n768) );
  AOI22M1R U219 ( .A1(n812), .A2(wr_val_o[162]), .B1(n811), .B2(rd_val_i[130]), 
        .Z(n763) );
  AOI22M1R U220 ( .A1(n812), .A2(wr_val_o[161]), .B1(n811), .B2(rd_val_i[129]), 
        .Z(n758) );
  AOI22M1R U221 ( .A1(n812), .A2(wr_val_o[160]), .B1(n811), .B2(rd_val_i[128]), 
        .Z(n753) );
  OAI211M2W U222 ( .A1(n634), .A2(n633), .B(n608), .C(n607), .Z(n609) );
  INVM2W U223 ( .A(n641), .Z(n812) );
  INVM2W U224 ( .A(n642), .Z(n811) );
  INVM2W U225 ( .A(n640), .Z(n813) );
  ND4M2W U226 ( .A(reg_i_addr[2]), .B(reg_i_addr[4]), .C(n612), .D(n633), .Z(
        n641) );
  ND2M2W U227 ( .A(n634), .B(n633), .Z(n640) );
  INVM1S U228 ( .A(reg_i_valid), .Z(n445) );
  NR3M2S U229 ( .A(reg_i_addr[4]), .B(reg_i_addr[2]), .C(reg_i_addr[3]), .Z(
        n634) );
  NR4M1S U230 ( .A(reg_i_addr[23]), .B(reg_i_addr[22]), .C(reg_i_addr[20]), 
        .D(reg_i_addr[29]), .Z(n603) );
  NR4M1W U231 ( .A(reg_i_addr[18]), .B(reg_i_addr[9]), .C(reg_i_addr[19]), .D(
        reg_i_addr[27]), .Z(n605) );
  NR4M1S U232 ( .A(reg_i_addr[24]), .B(reg_i_addr[26]), .C(reg_i_addr[25]), 
        .D(reg_i_addr[21]), .Z(n606) );
  NR4M1W U233 ( .A(reg_i_addr[11]), .B(reg_i_addr[10]), .C(reg_i_addr[17]), 
        .D(reg_i_addr[14]), .Z(n608) );
  INVM1S U234 ( .A(reg_i_addr[5]), .Z(n633) );
  INVM1S U235 ( .A(reg_i_addr[4]), .Z(n631) );
  INVM1S U236 ( .A(reg_i_addr[3]), .Z(n612) );
  INVM2S U237 ( .A(n643), .Z(n816) );
  INVM1S U238 ( .A(reg_i_wdata[30]), .Z(n622) );
  INVM1S U239 ( .A(reg_i_wdata[24]), .Z(n618) );
  INVM1S U240 ( .A(reg_i_wdata[25]), .Z(n616) );
  INVM1S U241 ( .A(reg_i_wdata[26]), .Z(n624) );
  INVM1S U242 ( .A(reg_i_wdata[27]), .Z(n627) );
  INVM1S U243 ( .A(reg_i_wdata[28]), .Z(n619) );
  INVM1S U244 ( .A(reg_i_wdata[29]), .Z(n626) );
  INVM1S U245 ( .A(reg_i_wdata[23]), .Z(n617) );
  MAOI22M1SA U246 ( .A1(n620), .A2(n624), .B1(n620), .B2(wr_val_o[250]), .Z(
        n350) );
  MAOI22M1SA U247 ( .A1(n621), .A2(n49), .B1(n621), .B2(wr_val_o[234]), .Z(
        n366) );
  MAOI22M1SA U248 ( .A1(n628), .A2(n616), .B1(n628), .B2(wr_val_o[217]), .Z(
        n381) );
  MAOI22M1SA U249 ( .A1(n625), .A2(n622), .B1(n625), .B2(wr_val_o[190]), .Z(
        n418) );
  MAOI22M1SA U250 ( .A1(n623), .A2(n855), .B1(n623), .B2(wr_val_o[173]), .Z(
        n433) );
  INVM1S U251 ( .A(reg_i_wdata[15]), .Z(n853) );
  INVM1S U252 ( .A(reg_i_wdata[5]), .Z(n851) );
  INVM1S U253 ( .A(reg_i_wdata[11]), .Z(n857) );
  INVM1S U254 ( .A(reg_i_wdata[12]), .Z(n856) );
  INVM1S U255 ( .A(reg_i_wdata[13]), .Z(n855) );
  INVM1S U256 ( .A(reg_i_wdata[14]), .Z(n854) );
  INVM1S U257 ( .A(reg_i_wdata[17]), .Z(n864) );
  INVM1S U258 ( .A(reg_i_wdata[18]), .Z(n863) );
  INVM1S U259 ( .A(reg_i_wdata[19]), .Z(n862) );
  INVM1S U260 ( .A(reg_i_wdata[20]), .Z(n861) );
  INVM1S U261 ( .A(reg_i_wdata[21]), .Z(n860) );
  INVM1S U262 ( .A(reg_i_wdata[22]), .Z(n859) );
  INVM1S U263 ( .A(reg_i_wdata[8]), .Z(n47) );
  INVM1S U264 ( .A(reg_i_wdata[10]), .Z(n49) );
  INVM1S U265 ( .A(reg_i_wdata[7]), .Z(n64) );
  INVM1S U266 ( .A(reg_i_wdata[9]), .Z(n48) );
  INVM1S U267 ( .A(reg_i_wdata[0]), .Z(n57) );
  INVM1S U268 ( .A(reg_i_wdata[3]), .Z(n60) );
  INVM1S U269 ( .A(reg_i_wdata[4]), .Z(n61) );
  INVM1S U270 ( .A(reg_i_wdata[1]), .Z(n58) );
  INVM1S U271 ( .A(reg_i_wdata[2]), .Z(n59) );
  MAOI22M1SA U272 ( .A1(n867), .A2(n618), .B1(n867), .B2(wr_val_o[280]), .Z(
        n316) );
  MAOI22M1SA U273 ( .A1(n867), .A2(n616), .B1(n867), .B2(wr_val_o[281]), .Z(
        n317) );
  MAOI22M1SA U274 ( .A1(n867), .A2(n624), .B1(n867), .B2(wr_val_o[282]), .Z(
        n318) );
  MAOI22M1SA U275 ( .A1(n867), .A2(n627), .B1(n867), .B2(wr_val_o[283]), .Z(
        n319) );
  MAOI22M1SA U276 ( .A1(n867), .A2(n619), .B1(n867), .B2(wr_val_o[284]), .Z(
        n320) );
  MAOI22M1SA U277 ( .A1(n867), .A2(n626), .B1(n867), .B2(wr_val_o[285]), .Z(
        n321) );
  MAOI22M1SA U278 ( .A1(n867), .A2(n622), .B1(n867), .B2(wr_val_o[286]), .Z(
        n322) );
  MAOI22M1SA U279 ( .A1(n866), .A2(n617), .B1(n866), .B2(wr_val_o[279]), .Z(
        n331) );
  MAOI22M1SA U280 ( .A1(n620), .A2(n618), .B1(n620), .B2(wr_val_o[248]), .Z(
        n348) );
  MAOI22M1SA U281 ( .A1(n620), .A2(n616), .B1(n620), .B2(wr_val_o[249]), .Z(
        n349) );
  MAOI22M1SA U282 ( .A1(n620), .A2(n627), .B1(n620), .B2(wr_val_o[251]), .Z(
        n351) );
  MAOI22M1SA U283 ( .A1(n620), .A2(n619), .B1(n620), .B2(wr_val_o[252]), .Z(
        n352) );
  MAOI22M1SA U284 ( .A1(n620), .A2(n626), .B1(n620), .B2(wr_val_o[253]), .Z(
        n353) );
  MAOI22M1SA U285 ( .A1(n620), .A2(n622), .B1(n620), .B2(wr_val_o[254]), .Z(
        n354) );
  MAOI22M1SA U286 ( .A1(n620), .A2(n615), .B1(n620), .B2(n869), .Z(n355) );
  MAOI22M1SA U287 ( .A1(n850), .A2(n865), .B1(n850), .B2(wr_val_o[240]), .Z(
        n356) );
  MAOI22M1SA U288 ( .A1(n850), .A2(n864), .B1(n850), .B2(wr_val_o[241]), .Z(
        n357) );
  MAOI22M1SA U289 ( .A1(n850), .A2(n863), .B1(n850), .B2(wr_val_o[242]), .Z(
        n358) );
  MAOI22M1SA U290 ( .A1(n850), .A2(n862), .B1(n850), .B2(wr_val_o[243]), .Z(
        n359) );
  MAOI22M1SA U291 ( .A1(n850), .A2(n861), .B1(n850), .B2(wr_val_o[244]), .Z(
        n360) );
  MAOI22M1SA U292 ( .A1(n850), .A2(n860), .B1(n850), .B2(wr_val_o[245]), .Z(
        n361) );
  MAOI22M1SA U293 ( .A1(n850), .A2(n617), .B1(n850), .B2(wr_val_o[247]), .Z(
        n363) );
  MAOI22M1SA U294 ( .A1(n621), .A2(n47), .B1(n621), .B2(wr_val_o[232]), .Z(
        n364) );
  MAOI22M1SA U295 ( .A1(n621), .A2(n48), .B1(n621), .B2(wr_val_o[233]), .Z(
        n365) );
  MAOI22M1SA U296 ( .A1(n621), .A2(n857), .B1(n621), .B2(wr_val_o[235]), .Z(
        n367) );
  MAOI22M1SA U297 ( .A1(n621), .A2(n856), .B1(n621), .B2(wr_val_o[236]), .Z(
        n368) );
  MAOI22M1SA U298 ( .A1(n621), .A2(n855), .B1(n621), .B2(wr_val_o[237]), .Z(
        n369) );
  MAOI22M1SA U299 ( .A1(n621), .A2(n854), .B1(n621), .B2(wr_val_o[238]), .Z(
        n370) );
  MAOI22M1SA U300 ( .A1(n621), .A2(n853), .B1(n621), .B2(wr_val_o[239]), .Z(
        n371) );
  MAOI22M1SA U301 ( .A1(n613), .A2(n57), .B1(n613), .B2(wr_val_o[224]), .Z(
        n372) );
  MAOI22M1SA U302 ( .A1(n613), .A2(n58), .B1(n613), .B2(wr_val_o[225]), .Z(
        n373) );
  MAOI22M1SA U303 ( .A1(n613), .A2(n59), .B1(n613), .B2(wr_val_o[226]), .Z(
        n374) );
  MAOI22M1SA U304 ( .A1(n613), .A2(n60), .B1(n613), .B2(wr_val_o[227]), .Z(
        n375) );
  MAOI22M1SA U305 ( .A1(n613), .A2(n61), .B1(n613), .B2(wr_val_o[228]), .Z(
        n376) );
  MAOI22M1SA U306 ( .A1(n613), .A2(n851), .B1(n613), .B2(wr_val_o[229]), .Z(
        n377) );
  MAOI22M1SA U307 ( .A1(n613), .A2(n63), .B1(n613), .B2(wr_val_o[230]), .Z(
        n378) );
  MAOI22M1SA U308 ( .A1(n613), .A2(n64), .B1(n613), .B2(wr_val_o[231]), .Z(
        n379) );
  MAOI22M1SA U309 ( .A1(n628), .A2(n618), .B1(n628), .B2(wr_val_o[216]), .Z(
        n380) );
  MAOI22M1SA U310 ( .A1(n628), .A2(n624), .B1(n628), .B2(wr_val_o[218]), .Z(
        n382) );
  MAOI22M1SA U311 ( .A1(n628), .A2(n627), .B1(n628), .B2(wr_val_o[219]), .Z(
        n383) );
  MAOI22M1SA U312 ( .A1(n628), .A2(n619), .B1(n628), .B2(wr_val_o[220]), .Z(
        n384) );
  MAOI22M1SA U313 ( .A1(n628), .A2(n626), .B1(n628), .B2(wr_val_o[221]), .Z(
        n385) );
  MAOI22M1SA U314 ( .A1(n628), .A2(n622), .B1(n628), .B2(wr_val_o[222]), .Z(
        n386) );
  MAOI22M1SA U315 ( .A1(n628), .A2(n615), .B1(n628), .B2(n870), .Z(n387) );
  MAOI22M1SA U316 ( .A1(n849), .A2(n859), .B1(n849), .B2(wr_val_o[214]), .Z(
        n394) );
  MAOI22M1SA U317 ( .A1(n849), .A2(n617), .B1(n849), .B2(wr_val_o[215]), .Z(
        n395) );
  MAOI22M1SA U318 ( .A1(n625), .A2(n618), .B1(n625), .B2(wr_val_o[184]), .Z(
        n412) );
  MAOI22M1SA U319 ( .A1(n625), .A2(n616), .B1(n625), .B2(wr_val_o[185]), .Z(
        n413) );
  MAOI22M1SA U320 ( .A1(n625), .A2(n624), .B1(n625), .B2(wr_val_o[186]), .Z(
        n414) );
  MAOI22M1SA U321 ( .A1(n625), .A2(n627), .B1(n625), .B2(wr_val_o[187]), .Z(
        n415) );
  MAOI22M1SA U322 ( .A1(n625), .A2(n619), .B1(n625), .B2(wr_val_o[188]), .Z(
        n416) );
  MAOI22M1SA U323 ( .A1(n625), .A2(n626), .B1(n625), .B2(wr_val_o[189]), .Z(
        n417) );
  MAOI22M1SA U324 ( .A1(n625), .A2(n615), .B1(n625), .B2(n871), .Z(n419) );
  MAOI22M1SA U325 ( .A1(n614), .A2(n865), .B1(n614), .B2(wr_val_o[176]), .Z(
        n420) );
  MAOI22M1SA U326 ( .A1(n614), .A2(n864), .B1(n614), .B2(wr_val_o[177]), .Z(
        n421) );
  MAOI22M1SA U327 ( .A1(n614), .A2(n863), .B1(n614), .B2(wr_val_o[178]), .Z(
        n422) );
  MAOI22M1SA U328 ( .A1(n614), .A2(n862), .B1(n614), .B2(wr_val_o[179]), .Z(
        n423) );
  MAOI22M1SA U329 ( .A1(n614), .A2(n861), .B1(n614), .B2(wr_val_o[180]), .Z(
        n424) );
  MAOI22M1SA U330 ( .A1(n614), .A2(n860), .B1(n614), .B2(wr_val_o[181]), .Z(
        n425) );
  MAOI22M1SA U331 ( .A1(n614), .A2(n859), .B1(n614), .B2(wr_val_o[182]), .Z(
        n426) );
  MAOI22M1SA U332 ( .A1(n614), .A2(n617), .B1(n614), .B2(wr_val_o[183]), .Z(
        n427) );
  MAOI22M1SA U333 ( .A1(n623), .A2(n47), .B1(n623), .B2(wr_val_o[168]), .Z(
        n428) );
  MAOI22M1SA U334 ( .A1(n623), .A2(n48), .B1(n623), .B2(wr_val_o[169]), .Z(
        n429) );
  MAOI22M1SA U335 ( .A1(n623), .A2(n49), .B1(n623), .B2(wr_val_o[170]), .Z(
        n430) );
  MAOI22M1SA U336 ( .A1(n623), .A2(n857), .B1(n623), .B2(wr_val_o[171]), .Z(
        n431) );
  MAOI22M1SA U337 ( .A1(n623), .A2(n856), .B1(n623), .B2(wr_val_o[172]), .Z(
        n432) );
  MAOI22M1SA U338 ( .A1(n623), .A2(n854), .B1(n623), .B2(wr_val_o[174]), .Z(
        n434) );
  MAOI22M1SA U339 ( .A1(n623), .A2(n853), .B1(n623), .B2(wr_val_o[175]), .Z(
        n435) );
  MAOI22M1SA U340 ( .A1(n846), .A2(n57), .B1(n846), .B2(wr_val_o[160]), .Z(
        n436) );
  MAOI22M1SA U341 ( .A1(n846), .A2(n58), .B1(n846), .B2(wr_val_o[161]), .Z(
        n437) );
  MAOI22M1SA U342 ( .A1(n846), .A2(n59), .B1(n846), .B2(wr_val_o[162]), .Z(
        n438) );
  MAOI22M1SA U343 ( .A1(n846), .A2(n60), .B1(n846), .B2(wr_val_o[163]), .Z(
        n439) );
  MAOI22M1SA U344 ( .A1(n846), .A2(n61), .B1(n846), .B2(wr_val_o[164]), .Z(
        n440) );
  MAOI22M1SA U345 ( .A1(n846), .A2(n851), .B1(n846), .B2(wr_val_o[165]), .Z(
        n441) );
  MAOI22M1SA U346 ( .A1(n846), .A2(n64), .B1(n846), .B2(wr_val_o[167]), .Z(
        n443) );
  INVM1S U347 ( .A(reg_i_wdata[31]), .Z(n615) );
  INVM1S U348 ( .A(reg_i_wdata[16]), .Z(n865) );
  INVM1S U349 ( .A(reg_i_wdata[6]), .Z(n63) );
  AOI31M1S U350 ( .A1(n764), .A2(n763), .A3(n762), .B(n807), .Z(reg_i_rdata[2]) );
  AOI31M1S U351 ( .A1(n729), .A2(n728), .A3(n727), .B(n807), .Z(
        reg_i_rdata[17]) );
  INVM1S U352 ( .A(n70), .Z(n444) );
  NR2M1S U353 ( .A(n70), .B(n445), .Z(reg_i_error) );
  AOI31M1S U354 ( .A1(n650), .A2(n649), .A3(n648), .B(n807), .Z(
        reg_i_rdata[16]) );
  AOI31M1S U355 ( .A1(n655), .A2(n654), .A3(n653), .B(n807), .Z(
        reg_i_rdata[19]) );
  AOI31M1S U356 ( .A1(n660), .A2(n659), .A3(n658), .B(n807), .Z(
        reg_i_rdata[13]) );
  INVM1S U357 ( .A(wr_val_o[214]), .Z(n663) );
  AOI31M1S U358 ( .A1(n666), .A2(n665), .A3(n664), .B(n807), .Z(
        reg_i_rdata[22]) );
  INVM1S U359 ( .A(wr_val_o[215]), .Z(n669) );
  AOI31M1S U360 ( .A1(n672), .A2(n671), .A3(n670), .B(n807), .Z(
        reg_i_rdata[23]) );
  INVM1S U361 ( .A(wr_val_o[217]), .Z(n675) );
  AOI31M1S U362 ( .A1(n678), .A2(n677), .A3(n676), .B(n807), .Z(
        reg_i_rdata[25]) );
  INVM1S U363 ( .A(wr_val_o[218]), .Z(n681) );
  AOI31M1S U364 ( .A1(n684), .A2(n683), .A3(n682), .B(n807), .Z(
        reg_i_rdata[26]) );
  INVM1S U365 ( .A(wr_val_o[219]), .Z(n687) );
  AOI31M1S U366 ( .A1(n690), .A2(n689), .A3(n688), .B(n807), .Z(
        reg_i_rdata[27]) );
  INVM1S U367 ( .A(wr_val_o[220]), .Z(n693) );
  AOI31M1S U368 ( .A1(n696), .A2(n695), .A3(n694), .B(n807), .Z(
        reg_i_rdata[28]) );
  INVM1S U369 ( .A(wr_val_o[221]), .Z(n699) );
  AOI31M1S U370 ( .A1(n702), .A2(n701), .A3(n700), .B(n807), .Z(
        reg_i_rdata[29]) );
  INVM1S U371 ( .A(wr_val_o[222]), .Z(n705) );
  AOI31M1S U372 ( .A1(n708), .A2(n707), .A3(n706), .B(n807), .Z(
        reg_i_rdata[30]) );
  INVM1S U373 ( .A(wr_val_o[216]), .Z(n711) );
  AOI31M1S U374 ( .A1(n714), .A2(n713), .A3(n712), .B(n807), .Z(
        reg_i_rdata[24]) );
  AOI31M1S U375 ( .A1(n719), .A2(n718), .A3(n717), .B(n807), .Z(
        reg_i_rdata[15]) );
  AOI31M1S U376 ( .A1(n724), .A2(n723), .A3(n722), .B(n807), .Z(
        reg_i_rdata[11]) );
  AOI31M1S U377 ( .A1(n734), .A2(n733), .A3(n732), .B(n807), .Z(
        reg_i_rdata[18]) );
  AOI31M1S U378 ( .A1(n739), .A2(n738), .A3(n737), .B(n807), .Z(
        reg_i_rdata[14]) );
  AOI31M1S U379 ( .A1(n744), .A2(n743), .A3(n742), .B(n807), .Z(
        reg_i_rdata[20]) );
  AOI31M1S U380 ( .A1(n749), .A2(n748), .A3(n747), .B(n807), .Z(
        reg_i_rdata[21]) );
  AOI31M1S U381 ( .A1(n754), .A2(n753), .A3(n752), .B(n807), .Z(reg_i_rdata[0]) );
  AOI31M1S U382 ( .A1(n759), .A2(n758), .A3(n757), .B(n807), .Z(reg_i_rdata[1]) );
  AOI31M1S U383 ( .A1(n769), .A2(n768), .A3(n767), .B(n807), .Z(reg_i_rdata[3]) );
  AOI31M1S U384 ( .A1(n774), .A2(n773), .A3(n772), .B(n807), .Z(reg_i_rdata[4]) );
  AOI31M1S U385 ( .A1(n779), .A2(n778), .A3(n777), .B(n807), .Z(reg_i_rdata[5]) );
  AOI31M1S U386 ( .A1(n784), .A2(n783), .A3(n782), .B(n807), .Z(reg_i_rdata[6]) );
  AOI31M1S U387 ( .A1(n789), .A2(n788), .A3(n787), .B(n807), .Z(reg_i_rdata[7]) );
  AOI31M1S U388 ( .A1(n794), .A2(n793), .A3(n792), .B(n807), .Z(reg_i_rdata[8]) );
  AOI31M1S U389 ( .A1(n799), .A2(n798), .A3(n797), .B(n807), .Z(reg_i_rdata[9]) );
  AOI31M1S U390 ( .A1(n804), .A2(n803), .A3(n802), .B(n807), .Z(
        reg_i_rdata[10]) );
  AOI31M1S U391 ( .A1(n810), .A2(n809), .A3(n808), .B(n807), .Z(
        reg_i_rdata[12]) );
endmodule


module config_registers_I_cfg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32 ( clk_i, 
        rst_ni, cfg_i_addr, cfg_i_write, cfg_i_wdata, cfg_i_wstrb, cfg_i_valid, 
        cfg_i_rdata, cfg_i_error, cfg_i_ready, config_t_latency_access, 
        config_t_latency_additional, config_t_cs_max, 
        config_t_read_write_recovery, config_t_rwds_delay_line, 
        config_addr_mapping );
  input [31:0] cfg_i_addr;
  input [31:0] cfg_i_wdata;
  input [3:0] cfg_i_wstrb;
  output [31:0] cfg_i_rdata;
  output [31:0] config_t_latency_access;
  output [31:0] config_t_latency_additional;
  output [31:0] config_t_cs_max;
  output [31:0] config_t_read_write_recovery;
  output [31:0] config_t_rwds_delay_line;
  output [127:0] config_addr_mapping;
  input clk_i, rst_ni, cfg_i_write, cfg_i_valid;
  output cfg_i_error, cfg_i_ready;
  wire   n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17,
         n18, n19, n20, n21, n22, n23, n24, n25, n26, n27, n28, n29, n30, n31,
         n32, n33, n34, n35, n36, n37, n38, n39, n40, n41, n42, n43, n44, n45,
         n46, n47, n48, n49, n50, n51, n52, n53, n54, n55, n56, n57, n58, n59,
         n60, n61, n62, n63, n64, n65, n66, n67, n68, n69, n70, n71, n72, n73,
         n74, SYNOPSYS_UNCONNECTED_1, SYNOPSYS_UNCONNECTED_2,
         SYNOPSYS_UNCONNECTED_3, SYNOPSYS_UNCONNECTED_4,
         SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6,
         SYNOPSYS_UNCONNECTED_7, SYNOPSYS_UNCONNECTED_8,
         SYNOPSYS_UNCONNECTED_9, SYNOPSYS_UNCONNECTED_10,
         SYNOPSYS_UNCONNECTED_11, SYNOPSYS_UNCONNECTED_12,
         SYNOPSYS_UNCONNECTED_13, SYNOPSYS_UNCONNECTED_14;
  wire   [75:106] n;

  reg_uniform_ADDR_WIDTH32_DATA_WIDTH32_NUM_REG9_REG_WIDTH32_I_reg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32 registers ( 
        .clk_i(clk_i), .rst_ni(rst_ni), .init_val_i({1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 
        1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 
        1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 
        1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 
        1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 
        1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0}), .rd_val_i({1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, n, n47, n48, n49, n50, n51, 
        n52, n53, n54, n55, n56, n57, n58, n59, n60, n61, n62, n63, n64, n65, 
        n66, n67, n68, n69, n70, n71, n72, n73, n74, 
        config_t_read_write_recovery[3:0], n31, n32, n33, n34, n35, n36, n37, 
        n38, n39, n40, n41, n42, n43, n44, n45, n46, config_t_cs_max[15:0], n3, 
        n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18, 
        n19, n20, n21, n22, n23, n24, n25, n26, n27, n28, n29, n30, 
        config_t_latency_additional[3:0], config_t_latency_access}), 
        .wr_val_o({SYNOPSYS_UNCONNECTED_1, config_addr_mapping[126:96], 
        SYNOPSYS_UNCONNECTED_2, config_addr_mapping[94:64], 
        SYNOPSYS_UNCONNECTED_3, config_addr_mapping[62:32], 
        SYNOPSYS_UNCONNECTED_4, config_addr_mapping[30:0], n, n47, n48, n49, 
        n50, n51, n52, n53, n54, n55, n56, n57, n58, n59, n60, n61, n62, n63, 
        n64, n65, n66, n67, n68, n69, n70, n71, n72, n73, n74, 
        config_t_read_write_recovery[3:0], n31, n32, n33, n34, n35, n36, n37, 
        n38, n39, n40, n41, n42, n43, n44, n45, n46, config_t_cs_max[15:0], n3, 
        n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18, 
        n19, n20, n21, n22, n23, n24, n25, n26, n27, n28, n29, n30, 
        config_t_latency_additional[3:0], config_t_latency_access}), 
        .wr_evt_o({SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6, 
        SYNOPSYS_UNCONNECTED_7, SYNOPSYS_UNCONNECTED_8, SYNOPSYS_UNCONNECTED_9, 
        SYNOPSYS_UNCONNECTED_10, SYNOPSYS_UNCONNECTED_11, 
        SYNOPSYS_UNCONNECTED_12, SYNOPSYS_UNCONNECTED_13}), .reg_i_addr({
        cfg_i_addr[31:2], 1'b0, 1'b0}), .reg_i_write(cfg_i_write), 
        .reg_i_wdata(cfg_i_wdata), .reg_i_wstrb(cfg_i_wstrb), .reg_i_valid(
        cfg_i_valid), .reg_i_rdata(cfg_i_rdata), .reg_i_error(cfg_i_error), 
        .reg_i_ready(SYNOPSYS_UNCONNECTED_14) );
endmodule



    module hyperbus_axi_BURST_WIDTH9_NR_CS2_AXI_IW10_I_axi_i_AXI_BUS_in_AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 ( 
        clk_i, rst_ni, config_addr_mapping, axi_i_aw_id, axi_i_aw_addr, 
        axi_i_aw_len, axi_i_aw_size, axi_i_aw_burst, axi_i_aw_lock, 
        axi_i_aw_cache, axi_i_aw_prot, axi_i_aw_qos, axi_i_aw_region, 
        axi_i_aw_user, axi_i_aw_valid, axi_i_aw_ready, axi_i_w_data, 
        axi_i_w_strb, axi_i_w_last, axi_i_w_user, axi_i_w_valid, axi_i_w_ready, 
        axi_i_b_id, axi_i_b_resp, axi_i_b_user, axi_i_b_valid, axi_i_b_ready, 
        axi_i_ar_id, axi_i_ar_addr, axi_i_ar_len, axi_i_ar_size, 
        axi_i_ar_burst, axi_i_ar_lock, axi_i_ar_cache, axi_i_ar_prot, 
        axi_i_ar_qos, axi_i_ar_region, axi_i_ar_user, axi_i_ar_valid, 
        axi_i_ar_ready, axi_i_r_id, axi_i_r_data, axi_i_r_resp, axi_i_r_last, 
        axi_i_r_user, axi_i_r_valid, axi_i_r_ready, rx_data_i, rx_last_i, 
        rx_error_i, rx_valid_i, rx_ready_o, tx_data_o, tx_strb_o, tx_valid_o, 
        tx_ready_i, b_valid_i, b_ready_o, b_last_i, b_error_i, trans_valid_o, 
        trans_ready_i, trans_address_o, trans_cs_o, trans_write_o, 
        trans_burst_o, trans_burst_type_o, trans_address_space_o );
  input [127:0] config_addr_mapping;
  input [9:0] axi_i_aw_id;
  input [31:0] axi_i_aw_addr;
  input [7:0] axi_i_aw_len;
  input [2:0] axi_i_aw_size;
  input [1:0] axi_i_aw_burst;
  input [3:0] axi_i_aw_cache;
  input [2:0] axi_i_aw_prot;
  input [3:0] axi_i_aw_qos;
  input [3:0] axi_i_aw_region;
  input [0:0] axi_i_aw_user;
  input [15:0] axi_i_w_data;
  input [1:0] axi_i_w_strb;
  input [0:0] axi_i_w_user;
  output [9:0] axi_i_b_id;
  output [1:0] axi_i_b_resp;
  output [0:0] axi_i_b_user;
  input [9:0] axi_i_ar_id;
  input [31:0] axi_i_ar_addr;
  input [7:0] axi_i_ar_len;
  input [2:0] axi_i_ar_size;
  input [1:0] axi_i_ar_burst;
  input [3:0] axi_i_ar_cache;
  input [2:0] axi_i_ar_prot;
  input [3:0] axi_i_ar_qos;
  input [3:0] axi_i_ar_region;
  input [0:0] axi_i_ar_user;
  output [9:0] axi_i_r_id;
  output [15:0] axi_i_r_data;
  output [1:0] axi_i_r_resp;
  output [0:0] axi_i_r_user;
  input [15:0] rx_data_i;
  output [15:0] tx_data_o;
  output [1:0] tx_strb_o;
  output [31:0] trans_address_o;
  output [1:0] trans_cs_o;
  output [8:0] trans_burst_o;
  input clk_i, rst_ni, axi_i_aw_lock, axi_i_aw_valid, axi_i_w_last,
         axi_i_w_valid, axi_i_b_ready, axi_i_ar_lock, axi_i_ar_valid,
         axi_i_r_ready, rx_last_i, rx_error_i, rx_valid_i, tx_ready_i,
         b_valid_i, b_last_i, b_error_i, trans_ready_i;
  output axi_i_aw_ready, axi_i_w_ready, axi_i_b_valid, axi_i_ar_ready,
         axi_i_r_last, axi_i_r_valid, rx_ready_o, tx_valid_o, b_ready_o,
         trans_valid_o, trans_write_o, trans_burst_type_o,
         trans_address_space_o;
  wire   n7, n12, rx_last_i, rx_valid_i, axi_i_r_ready, tx_ready_i,
         axi_i_b_ready, decode_error, n36, n56, n61, n62, n63, n65, n67, n68,
         n69, n70, n71, n72, n73, n83, n84, n88, n89, n90, n91, n93, n96, n98,
         n122, n125, n158, n92, n82, n18, n20, n21, n22, n23, n24, n25, n26,
         n27, n28, n29, n30, n35, n37, n38, n47, n48, n49, n1, n2, n3, n4, n5,
         n6, n8, n9, n10, n11, n13, n14, n15, n16, n17, n31, n32, n33, n34,
         n39, n40, n41, n42, n43, n44, n45, n46, n50, n51, n52, n53, n54, n55,
         n57, n58, n59, n60, n64, n66, n74, n75, n76, n77, n78, n79, n80, n81,
         n85, n86, n87, n94, n95, n97, n99, n100, n101, n102, n103, n104, n105,
         n106, n107, n108, n109, n110, n111, n112, n113, n114, n115, n116,
         n117, n118, n119, n120, n121, n123, n124, n126, n127, n128, n129,
         n130, n131, n132, n133, n134, n135, n136, n137, n138, n139, n140,
         n141, n142, n143, n144, n145, n146, n147, n148, n149, n150, n151,
         n152, n153, n154, n155, n156, n157, n159, n160, n161, n162, n163,
         n164, n165, n166, n167, n168, n169, n170, n171, n172, n173, n174,
         n175, n176, n177, n178, n179, n180, n181, n182, n183, n184, n185,
         n186, n187, n188, n189, n190, n191, n192, n193, n194, n195, n196,
         n197, n198, n199, n200, n201, n202, n203, n204, n205, n206, n207,
         n208, n209, n210, n211, n212, n213, n214, n215, n216, n217, n218,
         n219, n220, n221, n222, n223, n224, n225, n226, n227, n228, n229,
         n230, n231, n232, n233, n234, n235, n236, n237, n238, n239, n240,
         n241, n242, n243, n244, n245, n246, n247, n248, n249, n250, n251,
         n252, n253, n254, n255, n256, n257, n258, n259, n260, n261, n262,
         n263, n264, n265, n266, n267, n268, n269, n270, n271, n272, n273,
         n274, n275, n276, n277, n278, n279, n280, n281, n282, n283, n284,
         n285, n286, n287, n288, n289, n290, n291, n292, n293, n294, n295,
         n296, n297, n298, n299, n300, n301, n302, n303, n304, n305, n306,
         n307, n308, n309, n310, n311, n312, n313, n314, n315, n316, n317,
         n318, n319, n320, n321, n322, n323, n324, n325, n326, n327, n328,
         n329, n330, n331, n332, n333, n334, n335, n336, n337, n338, n339,
         n340, n341, n342, n343, n344, n345, n346, n347, n348, n349, n350,
         n351, n352, n353, n354, n355, n356, n357, n358, n359, n360, n361,
         n362, n363, n364, n365, n366, n367, n368, n369, n370, n371, n372,
         n373, n374, n375, n376, n377;
  wire   [2:0] write_state;
  wire   [1:0] read_state;
  wire   [2:0] trans_state;
  assign axi_i_r_id[8] = axi_i_b_id[8];
  assign axi_i_r_id[7] = axi_i_b_id[7];
  assign axi_i_r_id[6] = axi_i_b_id[6];
  assign axi_i_r_id[5] = axi_i_b_id[5];
  assign axi_i_r_id[4] = axi_i_b_id[4];
  assign axi_i_r_id[3] = axi_i_b_id[3];
  assign axi_i_r_id[2] = axi_i_b_id[2];
  assign axi_i_r_id[1] = axi_i_b_id[1];
  assign axi_i_r_id[0] = axi_i_b_id[0];
  assign axi_i_r_id[9] = axi_i_b_id[9];
  assign axi_i_r_data[15] = rx_data_i[15];
  assign axi_i_r_data[14] = rx_data_i[14];
  assign axi_i_r_data[13] = rx_data_i[13];
  assign axi_i_r_data[12] = rx_data_i[12];
  assign axi_i_r_data[11] = rx_data_i[11];
  assign axi_i_r_data[10] = rx_data_i[10];
  assign axi_i_r_data[9] = rx_data_i[9];
  assign axi_i_r_data[8] = rx_data_i[8];
  assign axi_i_r_data[7] = rx_data_i[7];
  assign axi_i_r_data[6] = rx_data_i[6];
  assign axi_i_r_data[5] = rx_data_i[5];
  assign axi_i_r_data[4] = rx_data_i[4];
  assign axi_i_r_data[3] = rx_data_i[3];
  assign axi_i_r_data[2] = rx_data_i[2];
  assign axi_i_r_data[1] = rx_data_i[1];
  assign axi_i_r_data[0] = rx_data_i[0];
  assign axi_i_r_last = rx_last_i;
  assign axi_i_r_valid = rx_valid_i;
  assign rx_ready_o = axi_i_r_ready;
  assign tx_data_o[14] = axi_i_w_data[14];
  assign tx_data_o[13] = axi_i_w_data[13];
  assign tx_data_o[12] = axi_i_w_data[12];
  assign tx_data_o[11] = axi_i_w_data[11];
  assign tx_data_o[10] = axi_i_w_data[10];
  assign tx_data_o[9] = axi_i_w_data[9];
  assign tx_data_o[8] = axi_i_w_data[8];
  assign tx_data_o[7] = axi_i_w_data[7];
  assign tx_data_o[6] = axi_i_w_data[6];
  assign tx_data_o[5] = axi_i_w_data[5];
  assign tx_data_o[4] = axi_i_w_data[4];
  assign tx_data_o[3] = axi_i_w_data[3];
  assign tx_data_o[2] = axi_i_w_data[2];
  assign tx_data_o[1] = axi_i_w_data[1];
  assign tx_data_o[0] = axi_i_w_data[0];
  assign tx_data_o[15] = axi_i_w_data[15];
  assign axi_i_w_ready = tx_ready_i;
  assign b_ready_o = axi_i_b_ready;
  assign trans_address_space_o = trans_address_o[31];

  OR2M1S C583 ( .A(n73), .B(rx_error_i), .Z(n82) );
  INVM1S I_18 ( .A(n82), .Z(n83) );
  INVM1S I_20 ( .A(rx_error_i), .Z(n92) );
  DFEQRM1SA trans_state_reg_2_ ( .D(n125), .E(n122), .CK(clk_i), .RB(rst_ni), 
        .Q(trans_state[2]) );
  AO22M1SA U108 ( .A1(read_state[0]), .A2(n96), .B1(n47), .B2(1'b0), .Z(
        axi_i_r_resp[1]) );
  AO22M1SA U101 ( .A1(n37), .A2(n72), .B1(n65), .B2(1'b0), .Z(axi_i_b_resp[1])
         );
  DFQRM1SA trans_state_reg_1_ ( .D(n29), .CK(clk_i), .RB(rst_ni), .Q(
        trans_state[1]) );
  DFQRM1SA axi_trans_id_reg_9_ ( .D(n28), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[9]) );
  DFQRM1SA axi_trans_id_reg_8_ ( .D(n27), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[8]) );
  DFQRM1SA axi_trans_id_reg_7_ ( .D(n26), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[7]) );
  DFQRM1SA axi_trans_id_reg_6_ ( .D(n25), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[6]) );
  DFQRM1SA axi_trans_id_reg_5_ ( .D(n24), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[5]) );
  DFQRM1SA axi_trans_id_reg_4_ ( .D(n23), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[4]) );
  DFQRM1SA axi_trans_id_reg_3_ ( .D(n22), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[3]) );
  DFQRM1SA axi_trans_id_reg_2_ ( .D(n21), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[2]) );
  DFQRM1SA axi_trans_id_reg_1_ ( .D(n20), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[1]) );
  DFQRM1SA axi_trans_id_reg_0_ ( .D(n18), .CK(clk_i), .RB(rst_ni), .Q(
        axi_i_b_id[0]) );
  DFEQRM1SA trans_state_reg_0_ ( .D(n48), .E(n122), .CK(clk_i), .RB(rst_ni), 
        .Q(trans_state[0]) );
  DFEQRM1SA decode_error_reg ( .D(n49), .E(n36), .CK(clk_i), .RB(rst_ni), .Q(
        decode_error) );
  DFEQRM1SA read_state_reg_0_ ( .D(n89), .E(n91), .CK(clk_i), .RB(rst_ni), .Q(
        read_state[0]) );
  DFEQRM1SA write_state_reg_0_ ( .D(n61), .E(n63), .CK(clk_i), .RB(rst_ni), 
        .Q(write_state[0]) );
  DFEQRM1SA write_state_reg_1_ ( .D(n62), .E(n63), .CK(clk_i), .RB(rst_ni), 
        .Q(write_state[1]) );
  DFEQRM1SA read_state_reg_1_ ( .D(n90), .E(n91), .CK(clk_i), .RB(rst_ni), .Q(
        read_state[1]) );
  INVM1S I_22 ( .A(trans_ready_i), .Z(n98) );
  CKAN2M2S C517 ( .A(trans_valid_o), .B(trans_ready_i), .Z(n36) );
  INVM1S I_13 ( .A(n68), .Z(n69) );
  CKBUFM1S B_12 ( .A(rx_error_i), .Z(n12) );
  AN2M2W C560 ( .A(b_valid_i), .B(b_last_i), .Z(n67) );
  AO22M2W U96 ( .A1(n30), .A2(1'b1), .B1(1'b0), .B2(1'b0), .Z(n63) );
  AN2M2R C562 ( .A(b_error_i), .B(b_valid_i), .Z(n68) );
  BUFM2S B_7 ( .A(n68), .Z(n7) );
  AO22M1SA U97 ( .A1(1'b1), .A2(n7), .B1(n67), .B2(n69), .Z(n70) );
  AN2M1R C570 ( .A(rx_last_i), .B(axi_i_r_ready), .Z(n158) );
  AN2M2R C569 ( .A(n158), .B(rx_valid_i), .Z(n73) );
  AO22M1SA U98 ( .A1(1'b1), .A2(decode_error), .B1(n70), .B2(n35), .Z(n71) );
  AO22M1SA U102 ( .A1(n71), .A2(n37), .B1(1'b0), .B2(n65), .Z(axi_i_b_valid)
         );
  CKAN2M2S C590 ( .A(n73), .B(n92), .Z(n93) );
  CKAN2M2S C551 ( .A(axi_i_b_valid), .B(axi_i_b_ready), .Z(n56) );
  AO222M1SA U103 ( .A1(1'b0), .A2(n83), .B1(1'b1), .B2(n12), .C1(1'b1), .C2(
        n93), .Z(n84) );
  AO22M1SA U106 ( .A1(n38), .A2(rx_error_i), .B1(read_state[1]), .B2(1'b1), 
        .Z(n96) );
  AO22M1SA U99 ( .A1(1'b1), .A2(decode_error), .B1(n68), .B2(n35), .Z(n72) );
  AO22M1RA U104 ( .A1(n88), .A2(1'b1), .B1(1'b0), .B2(1'b0), .Z(n91) );
  MAOI22M2RA U3 ( .A1(n209), .A2(n208), .B1(n207), .B2(n206), .Z(trans_cs_o[0]) );
  AO31M1SA U4 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_ready), .A3(n61), .B(n375), 
        .Z(n30) );
  MAOI22M2SA U5 ( .A1(n371), .A2(n370), .B1(n369), .B2(n368), .Z(trans_cs_o[1]) );
  AO22M1SA U6 ( .A1(n37), .A2(n56), .B1(n62), .B2(axi_i_w_last), .Z(n375) );
  ND2M2R U7 ( .A(n374), .B(write_state[1]), .Z(n65) );
  OA211M1SA U8 ( .A1(n323), .A2(n322), .B(n321), .C(n320), .Z(n324) );
  INVM2R U9 ( .A(trans_write_o), .Z(n43) );
  MAOI222M2SA U10 ( .A(n162), .B(n301), .C(config_addr_mapping[6]), .Z(n164)
         );
  MAOI222M2SA U11 ( .A(n175), .B(config_addr_mapping[15]), .C(n326), .Z(n183)
         );
  MAOI222M2SA U12 ( .A(n327), .B(config_addr_mapping[79]), .C(n326), .Z(n338)
         );
  NR2M2R U13 ( .A(n39), .B(trans_state[2]), .Z(n34) );
  NR2M1R U14 ( .A(trans_cs_o[0]), .B(trans_cs_o[1]), .Z(n49) );
  AOI211M2S U15 ( .A1(config_addr_mapping[88]), .A2(n351), .B(n350), .C(n349), 
        .Z(n369) );
  AOI211M2S U16 ( .A1(config_addr_mapping[24]), .A2(n351), .B(n194), .C(n193), 
        .Z(n207) );
  ND4M1R U17 ( .A(n348), .B(n365), .C(n347), .D(n346), .Z(n349) );
  OAI211M1R U18 ( .A1(config_addr_mapping[56]), .A2(n351), .B(n136), .C(n135), 
        .Z(n208) );
  OAI211M1R U19 ( .A1(n344), .A2(n343), .B(n342), .C(n341), .Z(n347) );
  ND4M1R U20 ( .A(n192), .B(n204), .C(n191), .D(n190), .Z(n193) );
  OAI211M1R U21 ( .A1(n189), .A2(n188), .B(n187), .C(n186), .Z(n191) );
  AOI211M2S U22 ( .A1(n130), .A2(n129), .B(n128), .C(n127), .Z(n134) );
  AOI32M1R U23 ( .A1(n340), .A2(n339), .A3(n338), .B1(n337), .B2(n339), .Z(
        n341) );
  OAI31M2S U24 ( .A1(n273), .A2(n272), .A3(n271), .B(n270), .Z(n370) );
  AOI32M1R U25 ( .A1(n185), .A2(n184), .A3(n183), .B1(n182), .B2(n184), .Z(
        n186) );
  AOI31M1R U26 ( .A1(n126), .A2(n124), .A3(n123), .B(n121), .Z(n127) );
  OAI211M1R U27 ( .A1(config_addr_mapping[48]), .A2(n328), .B(n118), .C(n117), 
        .Z(n124) );
  NR2M2S U28 ( .A(n325), .B(n324), .Z(n327) );
  NR2M1R U29 ( .A(n174), .B(n173), .Z(n175) );
  OAI32M1R U30 ( .A1(n172), .A2(n316), .A3(config_addr_mapping[11]), .B1(n171), 
        .B2(n172), .Z(n173) );
  AOI31M1R U31 ( .A1(n113), .A2(n112), .A3(n111), .B(n110), .Z(n114) );
  OAI31M2S U32 ( .A1(n170), .A2(n169), .A3(n168), .B(n167), .Z(n171) );
  OAI32M1R U33 ( .A1(n166), .A2(n306), .A3(config_addr_mapping[7]), .B1(n165), 
        .B2(n166), .Z(n168) );
  ND2M1R U34 ( .A(n164), .B(n163), .Z(n165) );
  ND2M1R U35 ( .A(n160), .B(n159), .Z(n161) );
  OAI32M2W U36 ( .A1(read_state[0]), .A2(read_state[1]), .A3(n377), .B1(n376), 
        .B2(n47), .Z(n88) );
  AOI22M2W U37 ( .A1(read_state[1]), .A2(n73), .B1(n84), .B2(n38), .Z(n376) );
  ND2M1R U38 ( .A(n155), .B(n154), .Z(n156) );
  AOI211M1R U39 ( .A1(n282), .A2(config_addr_mapping[20]), .B(n143), .C(n188), 
        .Z(n184) );
  OAI211B100M1R U40 ( .NA2(config_addr_mapping[12]), .A1(trans_address_o[12]), 
        .B(n148), .C(n147), .Z(n172) );
  OAI22M1S U41 ( .A1(trans_state[2]), .A2(n42), .B1(n41), .B2(n43), .Z(n48) );
  AOI22M1R U42 ( .A1(n316), .A2(config_addr_mapping[11]), .B1(n310), .B2(
        config_addr_mapping[10]), .Z(n167) );
  NR3M1R U43 ( .A(trans_state[1]), .B(n41), .C(n372), .Z(n125) );
  NR2M1W U44 ( .A(n373), .B(n372), .Z(axi_i_aw_ready) );
  OAI221M1R U45 ( .A1(trans_state[0]), .A2(n40), .B1(n39), .B2(n98), .C(n373), 
        .Z(n42) );
  INVM1S U46 ( .A(trans_ready_i), .Z(n41) );
  ND3M1R U47 ( .A(n39), .B(n373), .C(trans_state[2]), .Z(n10) );
  NR3M2S U48 ( .A(trans_state[2]), .B(trans_state[0]), .C(n373), .Z(
        trans_write_o) );
  INVM2R U49 ( .A(read_state[1]), .Z(n38) );
  INVM1R U50 ( .A(read_state[0]), .Z(n47) );
  NR2B1M1S U51 ( .NA(axi_i_w_valid), .B(decode_error), .Z(tx_valid_o) );
  MAOI222M1SA U52 ( .A(n301), .B(config_addr_mapping[38]), .C(n97), .Z(n100)
         );
  MAOI222M1SA U53 ( .A(n95), .B(trans_address_o[5]), .C(n94), .Z(n97) );
  MAOI222M1SA U54 ( .A(n295), .B(config_addr_mapping[36]), .C(n87), .Z(n95) );
  OAI211M1S U55 ( .A1(n317), .A2(config_addr_mapping[108]), .B(n248), .C(n247), 
        .Z(n250) );
  AO211M1SA U56 ( .A1(config_addr_mapping[107]), .A2(n316), .B(n246), .C(n245), 
        .Z(n247) );
  OAI211M1S U57 ( .A1(config_addr_mapping[44]), .A2(n317), .B(n109), .C(n108), 
        .Z(n111) );
  AOI32M1S U58 ( .A1(n107), .A2(n106), .A3(n105), .B1(n104), .B2(n106), .Z(
        n109) );
  OAI22M1S U59 ( .A1(config_addr_mapping[43]), .A2(n316), .B1(
        config_addr_mapping[42]), .B2(n310), .Z(n104) );
  OAI211M1S U60 ( .A1(n328), .A2(config_addr_mapping[112]), .B(n257), .C(n256), 
        .Z(n264) );
  NR2M1S U61 ( .A(n255), .B(n254), .Z(n256) );
  MAOI222M1SA U62 ( .A(config_addr_mapping[111]), .B(n326), .C(n253), .Z(n254)
         );
  NR2M1S U63 ( .A(n116), .B(n115), .Z(n117) );
  MAOI222M1SA U64 ( .A(config_addr_mapping[47]), .B(n326), .C(n114), .Z(n115)
         );
  OAI32M1S U65 ( .A1(n258), .A2(trans_address_o[21]), .A3(n259), .B1(n222), 
        .B2(n258), .Z(n273) );
  NR4M1S U66 ( .A(n269), .B(n268), .C(n267), .D(n266), .Z(n270) );
  ND2B1M1S U67 ( .NA(config_addr_mapping[62]), .B(trans_address_o[30]), .Z(
        n135) );
  NR4M1S U68 ( .A(n134), .B(n133), .C(n132), .D(n131), .Z(n136) );
  NR2M1S U69 ( .A(config_addr_mapping[57]), .B(n345), .Z(n133) );
  MAOI222M1SA U70 ( .A(n290), .B(n153), .C(config_addr_mapping[2]), .Z(n155)
         );
  MAOI222M1SA U71 ( .A(n152), .B(n151), .C(trans_address_o[1]), .Z(n153) );
  ND2M1S U72 ( .A(config_addr_mapping[0]), .B(n286), .Z(n151) );
  MAOI222M1SA U73 ( .A(n86), .B(trans_address_o[3]), .C(n85), .Z(n87) );
  MAOI222M1SA U74 ( .A(n290), .B(config_addr_mapping[34]), .C(n81), .Z(n86) );
  MAOI222M1SA U75 ( .A(n296), .B(n295), .C(config_addr_mapping[68]), .Z(n298)
         );
  OA21M1SA U76 ( .A1(n294), .A2(config_addr_mapping[67]), .B(n293), .Z(n296)
         );
  ND2M1S U77 ( .A(n292), .B(n291), .Z(n293) );
  MAOI222M1SA U78 ( .A(n157), .B(n295), .C(config_addr_mapping[4]), .Z(n160)
         );
  ND2M1S U79 ( .A(n294), .B(config_addr_mapping[3]), .Z(n154) );
  NR2M1S U80 ( .A(config_addr_mapping[41]), .B(n309), .Z(n101) );
  MAOI222M1SA U81 ( .A(n302), .B(n301), .C(config_addr_mapping[70]), .Z(n304)
         );
  OA21M1SA U82 ( .A1(n300), .A2(config_addr_mapping[69]), .B(n299), .Z(n302)
         );
  ND2M1S U83 ( .A(n298), .B(n297), .Z(n299) );
  OAI32M1S U84 ( .A1(n244), .A2(n243), .A3(n242), .B1(n241), .B2(n244), .Z(
        n245) );
  OAI22M1S U85 ( .A1(n316), .A2(config_addr_mapping[107]), .B1(n310), .B2(
        config_addr_mapping[106]), .Z(n244) );
  ND2M1S U86 ( .A(n300), .B(config_addr_mapping[5]), .Z(n159) );
  OAI211M1S U87 ( .A1(config_addr_mapping[40]), .A2(n308), .B(n103), .C(n102), 
        .Z(n105) );
  MAOI222M1SA U88 ( .A(n100), .B(trans_address_o[7]), .C(n99), .Z(n103) );
  AOI22M1S U89 ( .A1(config_addr_mapping[43]), .A2(n316), .B1(
        config_addr_mapping[42]), .B2(n78), .Z(n106) );
  NR2M1S U90 ( .A(n77), .B(trans_address_o[10]), .Z(n78) );
  AOI22M1S U91 ( .A1(config_addr_mapping[41]), .A2(n309), .B1(
        config_addr_mapping[40]), .B2(n76), .Z(n107) );
  OAI32M1S U92 ( .A1(n307), .A2(n306), .A3(config_addr_mapping[71]), .B1(n305), 
        .B2(n307), .Z(n314) );
  ND2M1S U93 ( .A(n304), .B(n303), .Z(n305) );
  AOI211M1S U94 ( .A1(n309), .A2(config_addr_mapping[73]), .B(n308), .C(
        config_addr_mapping[72]), .Z(n313) );
  ND2M1S U95 ( .A(trans_address_o[8]), .B(n149), .Z(n150) );
  ND2M1S U100 ( .A(n309), .B(config_addr_mapping[9]), .Z(n149) );
  ND2M1S U105 ( .A(n306), .B(config_addr_mapping[7]), .Z(n163) );
  OAI21M1S U107 ( .A1(n316), .A2(config_addr_mapping[75]), .B(n315), .Z(n322)
         );
  OAI31M1S U109 ( .A1(n314), .A2(n313), .A3(n312), .B(n311), .Z(n315) );
  AOI22M1S U110 ( .A1(n316), .A2(config_addr_mapping[75]), .B1(n310), .B2(
        config_addr_mapping[74]), .Z(n311) );
  AOI211M1S U111 ( .A1(n316), .A2(config_addr_mapping[75]), .B(n310), .C(
        config_addr_mapping[74]), .Z(n323) );
  AOI22M1S U112 ( .A1(n318), .A2(config_addr_mapping[77]), .B1(n317), .B2(
        config_addr_mapping[76]), .Z(n321) );
  ND2M1S U113 ( .A(n319), .B(config_addr_mapping[78]), .Z(n320) );
  MAOI222M1SA U114 ( .A(n284), .B(trans_address_o[13]), .C(n283), .Z(n285) );
  AOI31M1S U115 ( .A1(n252), .A2(n251), .A3(n250), .B(n249), .Z(n253) );
  NR2M1S U116 ( .A(n319), .B(config_addr_mapping[110]), .Z(n249) );
  NR2M1S U117 ( .A(n226), .B(config_addr_mapping[113]), .Z(n255) );
  NR2M1S U118 ( .A(config_addr_mapping[16]), .B(n328), .Z(n177) );
  OAI22M1S U119 ( .A1(config_addr_mapping[8]), .A2(n150), .B1(n309), .B2(
        config_addr_mapping[9]), .Z(n170) );
  ND2M1S U120 ( .A(n318), .B(config_addr_mapping[13]), .Z(n148) );
  ND2M1S U121 ( .A(n319), .B(config_addr_mapping[14]), .Z(n147) );
  MAOI222M1SA U122 ( .A(n145), .B(trans_address_o[13]), .C(n144), .Z(n146) );
  NR2M1S U123 ( .A(config_addr_mapping[12]), .B(n317), .Z(n145) );
  NR2M1S U124 ( .A(config_addr_mapping[46]), .B(n319), .Z(n110) );
  AOI22M1S U125 ( .A1(config_addr_mapping[46]), .A2(n319), .B1(
        config_addr_mapping[45]), .B2(n318), .Z(n113) );
  OAI211M1S U126 ( .A1(config_addr_mapping[45]), .A2(n318), .B(
        config_addr_mapping[44]), .C(n317), .Z(n112) );
  NR2M1S U127 ( .A(config_addr_mapping[49]), .B(n226), .Z(n116) );
  OAI22M1S U128 ( .A1(config_addr_mapping[51]), .A2(n336), .B1(
        config_addr_mapping[50]), .B2(n332), .Z(n75) );
  ND2M1S U129 ( .A(n334), .B(n333), .Z(n335) );
  ND2M1S U130 ( .A(n336), .B(config_addr_mapping[83]), .Z(n333) );
  MAOI222M1SA U131 ( .A(config_addr_mapping[82]), .B(n332), .C(n331), .Z(n334)
         );
  MAOI222M1SA U132 ( .A(n330), .B(trans_address_o[17]), .C(n329), .Z(n331) );
  NR2M1S U133 ( .A(trans_address_o[21]), .B(n280), .Z(n281) );
  MAOI222M1SA U134 ( .A(n319), .B(config_addr_mapping[78]), .C(n285), .Z(n325)
         );
  OAI22M1S U135 ( .A1(n336), .A2(config_addr_mapping[115]), .B1(n332), .B2(
        config_addr_mapping[114]), .Z(n228) );
  ND2M1S U136 ( .A(trans_address_o[21]), .B(n259), .Z(n260) );
  ND2M1S U137 ( .A(n180), .B(n179), .Z(n181) );
  ND2M1S U138 ( .A(n336), .B(config_addr_mapping[19]), .Z(n179) );
  MAOI222M1SA U139 ( .A(config_addr_mapping[18]), .B(n332), .C(n178), .Z(n180)
         );
  MAOI222M1SA U140 ( .A(n177), .B(trans_address_o[17]), .C(n176), .Z(n178) );
  NR2M1S U141 ( .A(trans_address_o[17]), .B(n176), .Z(n141) );
  NR2M1S U142 ( .A(trans_address_o[21]), .B(n142), .Z(n143) );
  MAOI222M1SA U143 ( .A(n319), .B(config_addr_mapping[14]), .C(n146), .Z(n174)
         );
  AOI21B20M1S U144 ( .NA1(config_addr_mapping[54]), .NA2(n275), .B(n58), .Z(
        n130) );
  NR2M1S U145 ( .A(config_addr_mapping[55]), .B(n220), .Z(n58) );
  MAOI22M1SA U146 ( .A1(config_addr_mapping[51]), .A2(n336), .B1(n74), .B2(n75), .Z(n126) );
  OAI211M1S U147 ( .A1(config_addr_mapping[51]), .A2(n336), .B(
        config_addr_mapping[50]), .C(n332), .Z(n123) );
  OAI211M1S U148 ( .A1(config_addr_mapping[52]), .A2(n282), .B(n130), .C(n120), 
        .Z(n121) );
  ND2M1S U149 ( .A(n119), .B(trans_address_o[21]), .Z(n120) );
  AOI211M1S U150 ( .A1(n282), .A2(config_addr_mapping[84]), .B(n281), .C(n343), 
        .Z(n339) );
  AOI211M1S U151 ( .A1(n328), .A2(config_addr_mapping[80]), .B(n279), .C(n278), 
        .Z(n340) );
  OAI21M1S U152 ( .A1(n336), .A2(config_addr_mapping[83]), .B(n335), .Z(n337)
         );
  MOAI22M1SA U153 ( .A1(trans_address_o[23]), .A2(n276), .B1(n275), .B2(
        config_addr_mapping[86]), .Z(n343) );
  MAOI222M1SA U154 ( .A(n277), .B(trans_address_o[23]), .C(n276), .Z(n342) );
  AOI22M1S U155 ( .A1(n361), .A2(config_addr_mapping[93]), .B1(n360), .B2(
        config_addr_mapping[92]), .Z(n365) );
  OAI22M1S U156 ( .A1(n359), .A2(config_addr_mapping[123]), .B1(n355), .B2(
        config_addr_mapping[122]), .Z(n267) );
  OAI22M1S U157 ( .A1(n351), .A2(config_addr_mapping[120]), .B1(n367), .B2(
        config_addr_mapping[126]), .Z(n268) );
  OAI22M1S U158 ( .A1(n220), .A2(config_addr_mapping[119]), .B1(n275), .B2(
        config_addr_mapping[118]), .Z(n258) );
  OAI22M1S U159 ( .A1(n361), .A2(config_addr_mapping[125]), .B1(n360), .B2(
        config_addr_mapping[124]), .Z(n266) );
  AOI31M1S U160 ( .A1(n265), .A2(n264), .A3(n263), .B(n262), .Z(n271) );
  OAI211M1S U161 ( .A1(n282), .A2(config_addr_mapping[116]), .B(n261), .C(n260), .Z(n262) );
  AOI211M1S U162 ( .A1(n328), .A2(config_addr_mapping[16]), .B(n141), .C(n140), 
        .Z(n185) );
  OAI21M1S U163 ( .A1(n336), .A2(config_addr_mapping[19]), .B(n181), .Z(n182)
         );
  MAOI222M1SA U164 ( .A(n137), .B(trans_address_o[21]), .C(n142), .Z(n189) );
  MOAI22M1SA U165 ( .A1(trans_address_o[23]), .A2(n138), .B1(n275), .B2(
        config_addr_mapping[22]), .Z(n188) );
  MAOI222M1SA U166 ( .A(n139), .B(trans_address_o[23]), .C(n138), .Z(n187) );
  NR2M1S U167 ( .A(config_addr_mapping[22]), .B(n275), .Z(n139) );
  AOI22M1S U168 ( .A1(n361), .A2(config_addr_mapping[29]), .B1(n360), .B2(
        config_addr_mapping[28]), .Z(n204) );
  MAOI222M1SA U169 ( .A(trans_address_o[23]), .B(n64), .C(n60), .Z(n128) );
  OAI22M1S U170 ( .A1(config_addr_mapping[59]), .A2(n359), .B1(
        config_addr_mapping[58]), .B2(n355), .Z(n132) );
  OAI22M1S U171 ( .A1(config_addr_mapping[61]), .A2(n361), .B1(
        config_addr_mapping[60]), .B2(n360), .Z(n131) );
  INVM1S U172 ( .A(decode_error), .Z(n35) );
  MXB2M1SA U173 ( .A(axi_i_aw_addr[15]), .B(axi_i_ar_addr[15]), .S(n43), .Z(
        n326) );
  ND2M1S U174 ( .A(n345), .B(config_addr_mapping[89]), .Z(n346) );
  AOI22M1S U175 ( .A1(n359), .A2(config_addr_mapping[91]), .B1(n355), .B2(
        config_addr_mapping[90]), .Z(n348) );
  AOI22M1S U176 ( .A1(n365), .A2(n364), .B1(n363), .B2(n362), .Z(n366) );
  OAI22M1S U177 ( .A1(n218), .A2(n217), .B1(n216), .B2(n266), .Z(n219) );
  MXB2M1SA U178 ( .A(axi_i_aw_addr[2]), .B(axi_i_ar_addr[2]), .S(n43), .Z(n290) );
  MXB2M1SA U179 ( .A(axi_i_aw_addr[3]), .B(axi_i_ar_addr[3]), .S(n43), .Z(n294) );
  MXB2M1SA U180 ( .A(axi_i_aw_addr[4]), .B(axi_i_ar_addr[4]), .S(n43), .Z(n295) );
  MXB2M1SA U181 ( .A(axi_i_aw_addr[5]), .B(axi_i_ar_addr[5]), .S(n43), .Z(n300) );
  MXB2M1SA U182 ( .A(axi_i_aw_addr[6]), .B(axi_i_ar_addr[6]), .S(n43), .Z(n301) );
  MXB2M1SA U183 ( .A(axi_i_aw_addr[7]), .B(axi_i_ar_addr[7]), .S(n43), .Z(n306) );
  MXB2M1SA U184 ( .A(axi_i_aw_addr[9]), .B(axi_i_ar_addr[9]), .S(n43), .Z(n309) );
  MXB2M1SA U185 ( .A(axi_i_aw_addr[10]), .B(axi_i_ar_addr[10]), .S(n43), .Z(
        n310) );
  MXB2M1SA U186 ( .A(axi_i_aw_addr[11]), .B(axi_i_ar_addr[11]), .S(n43), .Z(
        n316) );
  MXB2M1SA U187 ( .A(axi_i_aw_addr[13]), .B(axi_i_ar_addr[13]), .S(n43), .Z(
        n318) );
  MXB2M1SA U188 ( .A(axi_i_aw_addr[14]), .B(axi_i_ar_addr[14]), .S(n43), .Z(
        n319) );
  MXB2M1SA U189 ( .A(axi_i_aw_addr[17]), .B(axi_i_ar_addr[17]), .S(n43), .Z(
        n226) );
  MXB2M1SA U190 ( .A(axi_i_aw_addr[18]), .B(axi_i_ar_addr[18]), .S(n43), .Z(
        n332) );
  MXB2M1SA U191 ( .A(axi_i_aw_addr[19]), .B(axi_i_ar_addr[19]), .S(n43), .Z(
        n336) );
  MXB2M1SA U192 ( .A(axi_i_aw_addr[21]), .B(axi_i_ar_addr[21]), .S(n43), .Z(
        n221) );
  MXB2M1SA U193 ( .A(axi_i_aw_addr[22]), .B(axi_i_ar_addr[22]), .S(n43), .Z(
        n275) );
  MXB2M1SA U194 ( .A(axi_i_aw_addr[23]), .B(axi_i_ar_addr[23]), .S(n43), .Z(
        n220) );
  MXB2M1SA U195 ( .A(axi_i_aw_addr[28]), .B(axi_i_ar_addr[28]), .S(n43), .Z(
        n360) );
  MXB2M1SA U196 ( .A(axi_i_aw_addr[29]), .B(axi_i_ar_addr[29]), .S(n43), .Z(
        n361) );
  NR2M1S U197 ( .A(trans_burst_o[0]), .B(n8), .Z(n6) );
  ND2M1S U198 ( .A(n6), .B(n1), .Z(n14) );
  NR2M1S U199 ( .A(n15), .B(n14), .Z(n13) );
  ND2M1S U200 ( .A(n13), .B(n2), .Z(n17) );
  NR2M1S U201 ( .A(n31), .B(n17), .Z(n16) );
  ND2M1S U202 ( .A(n16), .B(n3), .Z(n32) );
  ND2M1S U203 ( .A(n345), .B(config_addr_mapping[25]), .Z(n190) );
  AOI22M1S U204 ( .A1(n359), .A2(config_addr_mapping[27]), .B1(n355), .B2(
        config_addr_mapping[26]), .Z(n192) );
  MXB2M1SA U205 ( .A(axi_i_aw_addr[24]), .B(axi_i_ar_addr[24]), .S(n43), .Z(
        n351) );
  CKAN2M2S U206 ( .A(config_addr_mapping[30]), .B(n367), .Z(n194) );
  OAI22M1S U207 ( .A1(n55), .A2(n54), .B1(n53), .B2(n131), .Z(n57) );
  AOI22M1S U208 ( .A1(n204), .A2(n203), .B1(n202), .B2(n201), .Z(n205) );
  OAI21M1S U209 ( .A1(n359), .A2(config_addr_mapping[27]), .B(n200), .Z(n203)
         );
  MXB2M1SA U210 ( .A(axi_i_aw_addr[30]), .B(axi_i_ar_addr[30]), .S(n43), .Z(
        n367) );
  INVM1S U211 ( .A(n34), .Z(n372) );
  INVM1S U212 ( .A(write_state[0]), .Z(n374) );
  INVM1S U213 ( .A(n65), .Z(n37) );
  OAI21M1S U214 ( .A1(trans_state[1]), .A2(n372), .B(n43), .Z(trans_valid_o)
         );
  INVM1S U215 ( .A(trans_state[0]), .Z(n39) );
  NR2M1S U216 ( .A(axi_i_ar_valid), .B(axi_i_aw_valid), .Z(n9) );
  CKAN2M2S U217 ( .A(axi_i_ar_valid), .B(n5), .Z(n40) );
  INVM1S U218 ( .A(trans_state[1]), .Z(n373) );
  INVM1S U219 ( .A(n10), .Z(axi_i_ar_ready) );
  MAOI222M1SA U220 ( .A(n367), .B(config_addr_mapping[126]), .C(n219), .Z(n371) );
  MAOI222M1SA U221 ( .A(n367), .B(config_addr_mapping[94]), .C(n366), .Z(n368)
         );
  INVM1S U222 ( .A(n229), .Z(trans_address_o[1]) );
  INVM1S U223 ( .A(n300), .Z(trans_address_o[5]) );
  INVM1S U224 ( .A(n306), .Z(trans_address_o[7]) );
  INVM1S U225 ( .A(n308), .Z(trans_address_o[8]) );
  INVM1S U226 ( .A(n318), .Z(trans_address_o[13]) );
  INVM1S U227 ( .A(n226), .Z(trans_address_o[17]) );
  INVM1S U228 ( .A(n221), .Z(trans_address_o[21]) );
  INVM1S U229 ( .A(n220), .Z(trans_address_o[23]) );
  INVM1S U230 ( .A(n345), .Z(trans_address_o[25]) );
  AOI22M1S U231 ( .A1(trans_write_o), .A2(axi_i_aw_len[0]), .B1(
        axi_i_ar_len[0]), .B2(n43), .Z(trans_burst_o[0]) );
  AOI21M1S U232 ( .A1(n31), .A2(n17), .B(n16), .Z(trans_burst_o[5]) );
  AOI21M1S U233 ( .A1(n33), .A2(n32), .B(trans_burst_o[8]), .Z(
        trans_burst_o[7]) );
  NR2M1S U234 ( .A(n33), .B(n32), .Z(trans_burst_o[8]) );
  MAOI222M1SA U235 ( .A(n367), .B(config_addr_mapping[30]), .C(n205), .Z(n206)
         );
  MAOI222M1SA U236 ( .A(config_addr_mapping[62]), .B(n367), .C(n57), .Z(n209)
         );
  INVM1S U237 ( .A(axi_i_w_strb[1]), .Z(tx_strb_o[1]) );
  INVM1S U238 ( .A(axi_i_w_strb[0]), .Z(tx_strb_o[0]) );
  AOI32M1S U239 ( .A1(n11), .A2(n10), .A3(n9), .B1(trans_state[2]), .B2(n10), 
        .Z(n122) );
  INVM1S U240 ( .A(rx_error_i), .Z(n4) );
  ND2M1S U241 ( .A(config_addr_mapping[64]), .B(n286), .Z(n287) );
  OA21M1SA U242 ( .A1(n294), .A2(config_addr_mapping[3]), .B(n156), .Z(n157)
         );
  OA21M1SA U243 ( .A1(n300), .A2(config_addr_mapping[5]), .B(n161), .Z(n162)
         );
  ND2B1M1S U244 ( .NA(config_addr_mapping[45]), .B(trans_address_o[13]), .Z(
        n108) );
  INVM1S U245 ( .A(config_addr_mapping[25]), .Z(n195) );
  NR2M1S U246 ( .A(config_addr_mapping[88]), .B(n351), .Z(n353) );
  MAOI222M1SA U247 ( .A(n196), .B(trans_address_o[25]), .C(n195), .Z(n197) );
  INVM1S U248 ( .A(config_addr_mapping[55]), .Z(n60) );
  INVM1S U249 ( .A(config_addr_mapping[85]), .Z(n280) );
  INVM1S U250 ( .A(n228), .Z(n257) );
  INVM1S U251 ( .A(n294), .Z(trans_address_o[3]) );
  INVM1S U252 ( .A(n332), .Z(trans_address_o[18]) );
  AO222M1SA U253 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[0]), .B1(n9), .B2(
        axi_i_b_id[0]), .C1(axi_i_ar_id[0]), .C2(n40), .Z(n18) );
  INVM1S U254 ( .A(axi_i_aw_valid), .Z(n5) );
  AO222M1SA U255 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[2]), .B1(n9), .B2(
        axi_i_b_id[2]), .C1(axi_i_ar_id[2]), .C2(n40), .Z(n21) );
  AO222M1SA U256 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[4]), .B1(n9), .B2(
        axi_i_b_id[4]), .C1(axi_i_ar_id[4]), .C2(n40), .Z(n23) );
  AO222M1SA U257 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[3]), .B1(n9), .B2(
        axi_i_b_id[3]), .C1(axi_i_ar_id[3]), .C2(n40), .Z(n22) );
  AO222M1SA U258 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[9]), .B1(n9), .B2(
        axi_i_b_id[9]), .C1(axi_i_ar_id[9]), .C2(n40), .Z(n28) );
  AO222M1SA U259 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[7]), .B1(n9), .B2(
        axi_i_b_id[7]), .C1(axi_i_ar_id[7]), .C2(n40), .Z(n26) );
  AO222M1SA U260 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[8]), .B1(n9), .B2(
        axi_i_b_id[8]), .C1(axi_i_ar_id[8]), .C2(n40), .Z(n27) );
  AO222M1SA U261 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[5]), .B1(n9), .B2(
        axi_i_b_id[5]), .C1(axi_i_ar_id[5]), .C2(n40), .Z(n24) );
  AO222M1SA U262 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[6]), .B1(n9), .B2(
        axi_i_b_id[6]), .C1(axi_i_ar_id[6]), .C2(n40), .Z(n25) );
  AO222M1SA U263 ( .A1(axi_i_aw_valid), .A2(axi_i_aw_id[1]), .B1(n9), .B2(
        axi_i_b_id[1]), .C1(axi_i_ar_id[1]), .C2(n40), .Z(n20) );
  MXB2M1SA U264 ( .A(axi_i_aw_addr[0]), .B(axi_i_ar_addr[0]), .S(n43), .Z(n286) );
  INVM1S U265 ( .A(n286), .Z(trans_address_o[0]) );
  INVM1S U266 ( .A(n275), .Z(trans_address_o[22]) );
  INVM1S U267 ( .A(n326), .Z(trans_address_o[15]) );
  MXB2M1SA U268 ( .A(axi_i_aw_addr[20]), .B(axi_i_ar_addr[20]), .S(n43), .Z(
        n282) );
  INVM1S U269 ( .A(n282), .Z(trans_address_o[20]) );
  INVM1S U270 ( .A(n351), .Z(trans_address_o[24]) );
  INVM1S U271 ( .A(n360), .Z(trans_address_o[28]) );
  INVM1S U272 ( .A(n290), .Z(trans_address_o[2]) );
  INVM1S U273 ( .A(n319), .Z(trans_address_o[14]) );
  INVM1S U274 ( .A(n309), .Z(trans_address_o[9]) );
  MXB2M1SA U275 ( .A(axi_i_aw_addr[26]), .B(axi_i_ar_addr[26]), .S(n43), .Z(
        n355) );
  INVM1S U276 ( .A(n355), .Z(trans_address_o[26]) );
  INVM1S U277 ( .A(n316), .Z(trans_address_o[11]) );
  INVM1S U278 ( .A(n336), .Z(trans_address_o[19]) );
  MXB2M1SA U279 ( .A(axi_i_aw_addr[27]), .B(axi_i_ar_addr[27]), .S(n43), .Z(
        n359) );
  INVM1S U280 ( .A(n359), .Z(trans_address_o[27]) );
  INVM1S U281 ( .A(n361), .Z(trans_address_o[29]) );
  AOI22M1S U282 ( .A1(trans_write_o), .A2(axi_i_aw_len[1]), .B1(
        axi_i_ar_len[1]), .B2(n43), .Z(n8) );
  MUX2M1SA U283 ( .A(axi_i_aw_len[2]), .B(axi_i_ar_len[2]), .S(n43), .Z(n1) );
  OA21M1SA U284 ( .A1(n6), .A2(n1), .B(n14), .Z(trans_burst_o[2]) );
  AOI22M1S U285 ( .A1(trans_write_o), .A2(axi_i_aw_len[3]), .B1(
        axi_i_ar_len[3]), .B2(n43), .Z(n15) );
  MUX2M1SA U286 ( .A(axi_i_aw_len[4]), .B(axi_i_ar_len[4]), .S(n43), .Z(n2) );
  OA21M1SA U287 ( .A1(n13), .A2(n2), .B(n17), .Z(trans_burst_o[4]) );
  AOI22M1S U288 ( .A1(trans_write_o), .A2(axi_i_aw_len[5]), .B1(
        axi_i_ar_len[5]), .B2(n43), .Z(n31) );
  MUX2M1SA U289 ( .A(axi_i_aw_len[6]), .B(axi_i_ar_len[6]), .S(n43), .Z(n3) );
  OA21M1SA U290 ( .A1(n16), .A2(n3), .B(n32), .Z(trans_burst_o[6]) );
  INVM1S U291 ( .A(n301), .Z(trans_address_o[6]) );
  INVM1S U292 ( .A(n295), .Z(trans_address_o[4]) );
  MXB2M1SA U293 ( .A(axi_i_aw_addr[12]), .B(axi_i_ar_addr[12]), .S(n43), .Z(
        n317) );
  INVM1S U294 ( .A(n317), .Z(trans_address_o[12]) );
  INVM1S U295 ( .A(n367), .Z(trans_address_o[30]) );
  MXB2M1SA U296 ( .A(axi_i_aw_addr[1]), .B(axi_i_ar_addr[1]), .S(n43), .Z(n229) );
  INVM1S U297 ( .A(n310), .Z(trans_address_o[10]) );
  MXB2M1SA U298 ( .A(axi_i_aw_addr[8]), .B(axi_i_ar_addr[8]), .S(n43), .Z(n308) );
  MXB2M1SA U299 ( .A(axi_i_aw_addr[16]), .B(axi_i_ar_addr[16]), .S(n43), .Z(
        n328) );
  INVM1S U300 ( .A(n328), .Z(trans_address_o[16]) );
  MXB2M1SA U301 ( .A(axi_i_aw_addr[25]), .B(axi_i_ar_addr[25]), .S(n43), .Z(
        n345) );
  NR3M1S U302 ( .A(read_state[1]), .B(n47), .C(n4), .Z(n90) );
  AOI21M1S U303 ( .A1(read_state[0]), .A2(n4), .B(read_state[1]), .Z(n89) );
  OAI32M1S U304 ( .A1(n34), .A2(trans_state[2]), .A3(n5), .B1(n373), .B2(n34), 
        .Z(n29) );
  MUX2M1SA U305 ( .A(axi_i_aw_burst[0]), .B(axi_i_ar_burst[0]), .S(n43), .Z(
        trans_burst_type_o) );
  MUX2M1SA U306 ( .A(axi_i_aw_addr[31]), .B(axi_i_ar_addr[31]), .S(n43), .Z(
        trans_address_o[31]) );
  AOI21M1S U307 ( .A1(n8), .A2(trans_burst_o[0]), .B(n6), .Z(trans_burst_o[1])
         );
  NR2M1S U308 ( .A(trans_state[0]), .B(trans_state[1]), .Z(n11) );
  AOI21M1S U309 ( .A1(n15), .A2(n14), .B(n13), .Z(trans_burst_o[3]) );
  AOI22M1S U310 ( .A1(trans_write_o), .A2(axi_i_aw_len[7]), .B1(
        axi_i_ar_len[7]), .B2(n43), .Z(n33) );
  NR2M1S U311 ( .A(n65), .B(n35), .Z(axi_i_b_resp[0]) );
  NR2M1S U312 ( .A(config_addr_mapping[61]), .B(n361), .Z(n55) );
  AOI22M1S U313 ( .A1(config_addr_mapping[61]), .A2(n361), .B1(
        config_addr_mapping[60]), .B2(n360), .Z(n54) );
  NR2M1S U314 ( .A(config_addr_mapping[59]), .B(n359), .Z(n51) );
  ND2M1S U315 ( .A(config_addr_mapping[56]), .B(n351), .Z(n45) );
  INVM1S U316 ( .A(config_addr_mapping[57]), .Z(n44) );
  MAOI222M1SA U317 ( .A(trans_address_o[25]), .B(n45), .C(n44), .Z(n46) );
  MAOI222M1SA U318 ( .A(n355), .B(config_addr_mapping[58]), .C(n46), .Z(n50)
         );
  NR2M1S U319 ( .A(n51), .B(n50), .Z(n52) );
  AOI21M1S U320 ( .A1(config_addr_mapping[59]), .A2(n359), .B(n52), .Z(n53) );
  ND2M1S U321 ( .A(n282), .B(config_addr_mapping[52]), .Z(n59) );
  INVM1S U322 ( .A(config_addr_mapping[53]), .Z(n119) );
  MAOI222M1SA U323 ( .A(trans_address_o[21]), .B(n59), .C(n119), .Z(n129) );
  ND2M1S U324 ( .A(n275), .B(config_addr_mapping[54]), .Z(n64) );
  NR2M1S U325 ( .A(n116), .B(trans_address_o[16]), .Z(n66) );
  AOI22M1S U326 ( .A1(config_addr_mapping[49]), .A2(n226), .B1(
        config_addr_mapping[48]), .B2(n66), .Z(n74) );
  INVM1S U327 ( .A(n75), .Z(n118) );
  NR2M1S U328 ( .A(n101), .B(trans_address_o[8]), .Z(n76) );
  NR2M1S U329 ( .A(config_addr_mapping[43]), .B(n316), .Z(n77) );
  NR2M1S U330 ( .A(n286), .B(config_addr_mapping[32]), .Z(n80) );
  INVM1S U331 ( .A(config_addr_mapping[33]), .Z(n79) );
  MAOI222M1SA U332 ( .A(n80), .B(n79), .C(trans_address_o[1]), .Z(n81) );
  INVM1S U333 ( .A(config_addr_mapping[35]), .Z(n85) );
  INVM1S U334 ( .A(config_addr_mapping[37]), .Z(n94) );
  INVM1S U335 ( .A(config_addr_mapping[39]), .Z(n99) );
  INVM1S U336 ( .A(n101), .Z(n102) );
  NR2M1S U337 ( .A(config_addr_mapping[20]), .B(n282), .Z(n137) );
  INVM1S U338 ( .A(config_addr_mapping[21]), .Z(n142) );
  INVM1S U339 ( .A(config_addr_mapping[23]), .Z(n138) );
  INVM1S U340 ( .A(config_addr_mapping[17]), .Z(n176) );
  AO22M1SA U341 ( .A1(n336), .A2(config_addr_mapping[19]), .B1(n332), .B2(
        config_addr_mapping[18]), .Z(n140) );
  INVM1S U342 ( .A(config_addr_mapping[13]), .Z(n144) );
  NR2M1S U343 ( .A(n310), .B(config_addr_mapping[10]), .Z(n169) );
  AO22M1SA U344 ( .A1(n309), .A2(config_addr_mapping[9]), .B1(n308), .B2(
        config_addr_mapping[8]), .Z(n166) );
  INVM1S U345 ( .A(config_addr_mapping[1]), .Z(n152) );
  NR2M1S U346 ( .A(config_addr_mapping[24]), .B(n351), .Z(n196) );
  MAOI222M1SA U347 ( .A(config_addr_mapping[26]), .B(n355), .C(n197), .Z(n199)
         );
  ND2M1S U348 ( .A(n359), .B(config_addr_mapping[27]), .Z(n198) );
  ND2M1S U349 ( .A(n199), .B(n198), .Z(n200) );
  ND2M1S U350 ( .A(n361), .B(config_addr_mapping[29]), .Z(n202) );
  OAI22M1S U351 ( .A1(n361), .A2(config_addr_mapping[29]), .B1(n360), .B2(
        config_addr_mapping[28]), .Z(n201) );
  NR2M1S U352 ( .A(n361), .B(config_addr_mapping[125]), .Z(n218) );
  AOI22M1S U353 ( .A1(n361), .A2(config_addr_mapping[125]), .B1(n360), .B2(
        config_addr_mapping[124]), .Z(n217) );
  NR2M1S U354 ( .A(n359), .B(config_addr_mapping[123]), .Z(n214) );
  INVM1S U355 ( .A(config_addr_mapping[121]), .Z(n211) );
  ND2M1S U356 ( .A(config_addr_mapping[120]), .B(n351), .Z(n210) );
  MAOI222M1SA U357 ( .A(n211), .B(n210), .C(trans_address_o[25]), .Z(n212) );
  MAOI222M1SA U358 ( .A(n355), .B(config_addr_mapping[122]), .C(n212), .Z(n213) );
  NR2M1S U359 ( .A(n214), .B(n213), .Z(n215) );
  AOI21M1S U360 ( .A1(n359), .A2(config_addr_mapping[123]), .B(n215), .Z(n216)
         );
  INVM1S U361 ( .A(config_addr_mapping[117]), .Z(n259) );
  OAI211M1S U362 ( .A1(n221), .A2(config_addr_mapping[117]), .B(n282), .C(
        config_addr_mapping[116]), .Z(n222) );
  INVM1S U363 ( .A(config_addr_mapping[119]), .Z(n224) );
  ND2M1S U364 ( .A(config_addr_mapping[118]), .B(n275), .Z(n223) );
  MAOI222M1SA U365 ( .A(n224), .B(n223), .C(trans_address_o[23]), .Z(n272) );
  NR2M1S U366 ( .A(n255), .B(trans_address_o[16]), .Z(n225) );
  AOI22M1S U367 ( .A1(n226), .A2(config_addr_mapping[113]), .B1(
        config_addr_mapping[112]), .B2(n225), .Z(n227) );
  MAOI22M1SA U368 ( .A1(n336), .A2(config_addr_mapping[115]), .B1(n227), .B2(
        n228), .Z(n265) );
  AOI22M1S U369 ( .A1(n319), .A2(config_addr_mapping[110]), .B1(n318), .B2(
        config_addr_mapping[109]), .Z(n252) );
  OAI211M1S U370 ( .A1(n318), .A2(config_addr_mapping[109]), .B(n317), .C(
        config_addr_mapping[108]), .Z(n251) );
  ND2B1M1S U371 ( .NA(config_addr_mapping[109]), .B(trans_address_o[13]), .Z(
        n248) );
  OA211M1SA U372 ( .A1(n316), .A2(config_addr_mapping[107]), .B(n310), .C(
        config_addr_mapping[106]), .Z(n246) );
  AOI211M1S U373 ( .A1(n229), .A2(config_addr_mapping[97]), .B(n286), .C(
        config_addr_mapping[96]), .Z(n231) );
  OAI22M1S U374 ( .A1(n290), .A2(config_addr_mapping[98]), .B1(n229), .B2(
        config_addr_mapping[97]), .Z(n230) );
  MOAI22M1SA U375 ( .A1(n231), .A2(n230), .B1(n290), .B2(
        config_addr_mapping[98]), .Z(n232) );
  MAOI222M1SA U376 ( .A(n294), .B(config_addr_mapping[99]), .C(n232), .Z(n234)
         );
  INVM1S U377 ( .A(config_addr_mapping[100]), .Z(n233) );
  MAOI222M1SA U378 ( .A(n234), .B(trans_address_o[4]), .C(n233), .Z(n235) );
  MAOI222M1SA U379 ( .A(n300), .B(config_addr_mapping[101]), .C(n235), .Z(n237) );
  INVM1S U380 ( .A(config_addr_mapping[102]), .Z(n236) );
  MAOI222M1SA U381 ( .A(n237), .B(trans_address_o[6]), .C(n236), .Z(n238) );
  MAOI222M1SA U382 ( .A(n306), .B(config_addr_mapping[103]), .C(n238), .Z(n243) );
  OAI22M1S U383 ( .A1(n309), .A2(config_addr_mapping[105]), .B1(n308), .B2(
        config_addr_mapping[104]), .Z(n242) );
  NR2M1S U384 ( .A(n309), .B(config_addr_mapping[105]), .Z(n239) );
  NR2M1S U385 ( .A(n239), .B(trans_address_o[8]), .Z(n240) );
  AOI22M1S U386 ( .A1(n309), .A2(config_addr_mapping[105]), .B1(
        config_addr_mapping[104]), .B2(n240), .Z(n241) );
  OAI211M1S U387 ( .A1(n336), .A2(config_addr_mapping[115]), .B(n332), .C(
        config_addr_mapping[114]), .Z(n263) );
  INVM1S U388 ( .A(n258), .Z(n261) );
  NR2M1S U389 ( .A(n345), .B(config_addr_mapping[121]), .Z(n269) );
  CKAN2M2S U390 ( .A(config_addr_mapping[94]), .B(n367), .Z(n350) );
  NR2M1S U391 ( .A(config_addr_mapping[84]), .B(n282), .Z(n274) );
  MAOI222M1SA U392 ( .A(n274), .B(trans_address_o[21]), .C(n280), .Z(n344) );
  INVM1S U393 ( .A(config_addr_mapping[87]), .Z(n276) );
  NR2M1S U394 ( .A(config_addr_mapping[86]), .B(n275), .Z(n277) );
  INVM1S U395 ( .A(config_addr_mapping[81]), .Z(n329) );
  NR2M1S U396 ( .A(trans_address_o[17]), .B(n329), .Z(n279) );
  AO22M1SA U397 ( .A1(n336), .A2(config_addr_mapping[83]), .B1(n332), .B2(
        config_addr_mapping[82]), .Z(n278) );
  NR2M1S U398 ( .A(config_addr_mapping[76]), .B(n317), .Z(n284) );
  INVM1S U399 ( .A(config_addr_mapping[77]), .Z(n283) );
  AO22M1SA U400 ( .A1(n309), .A2(config_addr_mapping[73]), .B1(n308), .B2(
        config_addr_mapping[72]), .Z(n307) );
  INVM1S U401 ( .A(config_addr_mapping[65]), .Z(n288) );
  MAOI222M1SA U402 ( .A(n288), .B(n287), .C(trans_address_o[1]), .Z(n289) );
  MAOI222M1SA U403 ( .A(n290), .B(n289), .C(config_addr_mapping[66]), .Z(n292)
         );
  ND2M1S U404 ( .A(n294), .B(config_addr_mapping[67]), .Z(n291) );
  ND2M1S U405 ( .A(n300), .B(config_addr_mapping[69]), .Z(n297) );
  ND2M1S U406 ( .A(n306), .B(config_addr_mapping[71]), .Z(n303) );
  NR2M1S U407 ( .A(n309), .B(config_addr_mapping[73]), .Z(n312) );
  NR2M1S U408 ( .A(config_addr_mapping[80]), .B(n328), .Z(n330) );
  INVM1S U409 ( .A(config_addr_mapping[89]), .Z(n352) );
  MAOI222M1SA U410 ( .A(n353), .B(trans_address_o[25]), .C(n352), .Z(n354) );
  MAOI222M1SA U411 ( .A(config_addr_mapping[90]), .B(n355), .C(n354), .Z(n357)
         );
  ND2M1S U412 ( .A(n359), .B(config_addr_mapping[91]), .Z(n356) );
  ND2M1S U413 ( .A(n357), .B(n356), .Z(n358) );
  OAI21M1S U414 ( .A1(n359), .A2(config_addr_mapping[91]), .B(n358), .Z(n364)
         );
  ND2M1S U415 ( .A(n361), .B(config_addr_mapping[93]), .Z(n363) );
  OAI22M1S U416 ( .A1(n361), .A2(config_addr_mapping[93]), .B1(n360), .B2(
        config_addr_mapping[92]), .Z(n362) );
  NR3M1S U417 ( .A(n47), .B(n38), .C(n35), .Z(axi_i_r_resp[0]) );
  NR2M1S U418 ( .A(write_state[0]), .B(write_state[1]), .Z(n61) );
  NR2M1S U419 ( .A(write_state[1]), .B(n374), .Z(n62) );
  ND2M1S U420 ( .A(axi_i_ar_valid), .B(axi_i_ar_ready), .Z(n377) );
endmodule


module pulp_clock_gating_1 ( clk_i, en_i, test_en_i, clk_o );
  input clk_i, en_i, test_en_i;
  output clk_o;


  LAGCEPM12R clk_gate_i ( .CK(clk_i), .E(en_i), .SE(1'b0), .GCK(clk_o) );
endmodule


module pulp_clock_inverter ( clk_i, clk_o );
  input clk_i;
  output clk_o;


  INVM1S U1 ( .A(clk_i), .Z(clk_o) );
endmodule


module clock_diff_out ( in_i, en_i, out_o, out_no );
  input in_i, en_i;
  output out_o, out_no;


  pulp_clock_gating_1 hyper_ck_gating ( .clk_i(in_i), .en_i(en_i), .test_en_i(
        1'b0), .clk_o(out_o) );
  pulp_clock_inverter hyper_ck_no_inv ( .clk_i(out_o), .clk_o(out_no) );
endmodule


module pulp_clock_mux2_8 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1SA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_8 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_8 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module cmd_addr_gen ( rw_i, address_space_i, burst_type_i, address_i, 
        cmd_addr_o );
  input [31:0] address_i;
  output [47:0] cmd_addr_o;
  input rw_i, address_space_i, burst_type_i;
  wire   burst_type_i;
  assign cmd_addr_o[45] = burst_type_i;
  assign cmd_addr_o[44] = address_i[31];
  assign cmd_addr_o[43] = address_i[30];
  assign cmd_addr_o[42] = address_i[29];
  assign cmd_addr_o[41] = address_i[28];
  assign cmd_addr_o[40] = address_i[27];
  assign cmd_addr_o[39] = address_i[26];
  assign cmd_addr_o[38] = address_i[25];
  assign cmd_addr_o[37] = address_i[24];
  assign cmd_addr_o[36] = address_i[23];
  assign cmd_addr_o[35] = address_i[22];
  assign cmd_addr_o[34] = address_i[21];
  assign cmd_addr_o[33] = address_i[20];
  assign cmd_addr_o[32] = address_i[19];
  assign cmd_addr_o[31] = address_i[18];
  assign cmd_addr_o[30] = address_i[17];
  assign cmd_addr_o[29] = address_i[16];
  assign cmd_addr_o[28] = address_i[15];
  assign cmd_addr_o[27] = address_i[14];
  assign cmd_addr_o[26] = address_i[13];
  assign cmd_addr_o[25] = address_i[12];
  assign cmd_addr_o[24] = address_i[11];
  assign cmd_addr_o[23] = address_i[10];
  assign cmd_addr_o[22] = address_i[9];
  assign cmd_addr_o[21] = address_i[8];
  assign cmd_addr_o[20] = address_i[7];
  assign cmd_addr_o[19] = address_i[6];
  assign cmd_addr_o[18] = address_i[5];
  assign cmd_addr_o[17] = address_i[4];
  assign cmd_addr_o[16] = address_i[3];
  assign cmd_addr_o[2] = address_i[2];
  assign cmd_addr_o[1] = address_i[1];
  assign cmd_addr_o[0] = address_i[0];

endmodule


module hyperbus_delay_line ( in, out, delay );
  input [31:0] delay;
  input in;
  output out;
  wire   in;
  assign out = in;

endmodule


module binary_to_gray_N4_1 ( A, Z );
  input [3:0] A;
  output [3:0] Z;

  assign Z[3] = A[3];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
  MAOI22M1SA U2 ( .A1(A[2]), .A2(A[3]), .B1(A[2]), .B2(A[3]), .Z(Z[2]) );
  MAOI22M1SA U3 ( .A1(A[2]), .A2(A[1]), .B1(A[2]), .B2(A[1]), .Z(Z[1]) );
endmodule


module gray_to_binary_N4_1 ( A, Z );
  input [3:0] A;
  output [3:0] Z;
  wire   n0, n1, n2;
  assign Z[3] = A[3];

  XOR2M1SA C11 ( .A(A[3]), .B(A[2]), .Z(n0) );
  XOR2M1SA C10 ( .A(n0), .B(A[1]), .Z(n1) );
  XOR2M1SA C9 ( .A(n1), .B(A[0]), .Z(Z[0]) );
  XOR2M1SA C13 ( .A(A[3]), .B(A[2]), .Z(n2) );
  XOR2M1SA C12 ( .A(n2), .B(A[1]), .Z(Z[1]) );
  XOR2M1SA C14 ( .A(A[3]), .B(A[2]), .Z(Z[2]) );
endmodule


module binary_to_gray_N4_0 ( A, Z );
  input [3:0] A;
  output [3:0] Z;

  assign Z[3] = A[3];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
  MAOI22M1SA U2 ( .A1(A[2]), .A2(A[1]), .B1(A[2]), .B2(A[1]), .Z(Z[1]) );
  MAOI22M1SA U3 ( .A1(A[2]), .A2(A[3]), .B1(A[2]), .B2(A[3]), .Z(Z[2]) );
endmodule


module gray_to_binary_N4_0 ( A, Z );
  input [3:0] A;
  output [3:0] Z;
  wire   n0, n1, n2;
  assign Z[3] = A[3];

  XOR2M1SA C10 ( .A(n0), .B(A[1]), .Z(n1) );
  XOR2M1SA C9 ( .A(n1), .B(A[0]), .Z(Z[0]) );
  XOR2M1SA C13 ( .A(A[3]), .B(A[2]), .Z(n2) );
  XOR2M1SA C12 ( .A(n2), .B(A[1]), .Z(Z[1]) );
  XOR2M1SA C14 ( .A(A[3]), .B(A[2]), .Z(Z[2]) );
  XOR2M1SA C11 ( .A(A[3]), .B(A[2]), .Z(n0) );
endmodule


module cdc_fifo_gray_LOG_DEPTH3 ( src_rst_ni, src_clk_i, src_data_i, 
        src_valid_i, src_ready_o, dst_rst_ni, dst_clk_i, dst_data_o, 
        dst_valid_o, dst_ready_i );
  input [15:0] src_data_i;
  output [15:0] dst_data_o;
  input src_rst_ni, src_clk_i, src_valid_i, dst_rst_ni, dst_clk_i, dst_ready_i;
  output src_ready_o, dst_valid_o;
  wire   fifo_write, n4, n5, n6, n7, n8, n9, n10, n11, n12, n14, n15, n16, n17,
         n18, n19, n20, n21, n22, n48, n49, n50, n52, n53, n54, n55, n3, n13,
         n127, n128, n129, n130, n131, n132, n133, n134, n135, n1, n2, n23,
         n24, n25, n26, n27, n28, n29, n30, n31, n32, n33, n34, n35, n36, n37,
         n38, n39, n40, n41, n42, n43, n44, n45, n46, n47, n56, n57, n58, n59,
         n60, n61, n62, n63, n64, n65, n66, n67, n68, n69, n70, n71, n72, n73,
         n74, n75, n76, n77, n78, n79, n80, n81, n82, n83, n84, n85, n86, n87,
         n88, n89, n90, n91, n92, n93, n94, n95, n96, n97, n98, n99, n100,
         n101, n102, n103, n104, n105, n106, n107, n108;
  wire   [127:0] fifo_data_q;
  wire   [3:0] src_wptr_bin_q;
  wire   [3:1] src_wptr_bin_d;
  wire   [3:0] dst_rptr_bin_q;
  wire   [3:1] dst_rptr_bin_d;
  wire   [3:0] src_wptr_gray_d;
  wire   [3:0] dst_rptr_gray_d;
  wire   [3:0] src_wptr_gray_q;
  wire   [3:0] dst_rptr_gray_q;
  wire   [3:0] src_rptr_gray_q;
  wire   [3:0] src_rptr_gray_q2;
  wire   [3:0] dst_wptr_gray_q;
  wire   [3:0] dst_wptr_gray_q2;
  wire   [3:0] src_rptr_bin;
  wire   [3:0] dst_wptr_bin;

  binary_to_gray_N4_1 i_src_b2g ( .A({src_wptr_bin_d, n134}), .Z(
        src_wptr_gray_d) );
  binary_to_gray_N4_0 i_dst_b2g ( .A({dst_rptr_bin_d, n135}), .Z(
        dst_rptr_gray_d) );
  gray_to_binary_N4_1 i_src_g2b ( .A(src_rptr_gray_q2), .Z(src_rptr_bin) );
  gray_to_binary_N4_0 i_dst_g2b ( .A(dst_wptr_gray_q2), .Z(dst_wptr_bin) );
  OR2M1S C776 ( .A(n21), .B(n49), .Z(n50) );
  OR2M1S C775 ( .A(n20), .B(n19), .Z(n49) );
  XOR2M1SA C819 ( .A(dst_rptr_bin_q[0]), .B(dst_wptr_bin[0]), .Z(n22) );
  XOR2M1SA C818 ( .A(dst_rptr_bin_q[1]), .B(dst_wptr_bin[1]), .Z(n21) );
  XOR2M1SA C817 ( .A(dst_rptr_bin_q[2]), .B(dst_wptr_bin[2]), .Z(n20) );
  XOR2M1SA C816 ( .A(dst_rptr_bin_q[3]), .B(dst_wptr_bin[3]), .Z(n19) );
  XOR2M1SA C815 ( .A(src_wptr_bin_q[0]), .B(src_rptr_bin[0]), .Z(n18) );
  XOR2M1SA C814 ( .A(src_wptr_bin_q[1]), .B(src_rptr_bin[1]), .Z(n17) );
  XOR2M1SA C813 ( .A(src_wptr_bin_q[2]), .B(src_rptr_bin[2]), .Z(n16) );
  OR2M1S C781 ( .A(n16), .B(n52), .Z(n53) );
  OR2M1S C782 ( .A(n17), .B(n53), .Z(n54) );
  CKAN2M2S C807 ( .A(src_valid_i), .B(n55), .Z(n12) );
  OR2M1S C777 ( .A(n22), .B(n50), .Z(dst_valid_o) );
  CKAN2M2S C810 ( .A(dst_valid_o), .B(dst_ready_i), .Z(n14) );
  OR2M1S C783 ( .A(n18), .B(n54), .Z(n55) );
  CKAN2M2S C820 ( .A(src_valid_i), .B(n55), .Z(fifo_write) );
  CKAN2M2S C799 ( .A(fifo_write), .B(n127), .Z(n8) );
  CKAN2M2S C801 ( .A(fifo_write), .B(n128), .Z(n9) );
  CKAN2M2S C793 ( .A(fifo_write), .B(n132), .Z(n5) );
  CKAN2M2S C803 ( .A(fifo_write), .B(n129), .Z(n10) );
  CKAN2M2S C795 ( .A(fifo_write), .B(n131), .Z(n6) );
  CKAN2M2S C805 ( .A(fifo_write), .B(n48), .Z(n11) );
  CKAN2M2S C790 ( .A(fifo_write), .B(n133), .Z(n4) );
  CKAN2M2S C797 ( .A(fifo_write), .B(n130), .Z(n7) );
  DFEQRM1SA dst_rptr_bin_q_reg_3_ ( .D(dst_rptr_bin_d[3]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[3]) );
  DFEQRM1SA fifo_data_q_reg_3__12_ ( .D(src_data_i[12]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[76]) );
  DFEQRM1SA fifo_data_q_reg_0__14_ ( .D(src_data_i[14]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[126]) );
  DFEQRM1SA fifo_data_q_reg_7__15_ ( .D(src_data_i[15]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[15]) );
  DFEQRM1SA src_wptr_bin_q_reg_3_ ( .D(src_wptr_bin_d[3]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[3]) );
  DFEQRM1SA fifo_data_q_reg_2__2_ ( .D(src_data_i[2]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[82]) );
  DFEQRM1SA fifo_data_q_reg_6__3_ ( .D(src_data_i[3]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[19]) );
  DFEQRM1SA fifo_data_q_reg_1__11_ ( .D(src_data_i[11]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[107]) );
  DFEQRM1SA fifo_data_q_reg_5__12_ ( .D(src_data_i[12]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[44]) );
  DFEQRM1SA fifo_data_q_reg_4__13_ ( .D(src_data_i[13]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[61]) );
  INVM1S I_10 ( .A(n15), .Z(n52) );
  XOR2M1SA C812 ( .A(src_wptr_bin_q[3]), .B(src_rptr_bin[3]), .Z(n15) );
  DFQRM1SA dst_rptr_bin_q_reg_0_ ( .D(n13), .CK(dst_clk_i), .RB(dst_rst_ni), 
        .Q(dst_rptr_bin_q[0]) );
  DFEQRM1SA dst_rptr_bin_q_reg_1_ ( .D(dst_rptr_bin_d[1]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[1]) );
  DFEQRM1SA dst_rptr_bin_q_reg_2_ ( .D(dst_rptr_bin_d[2]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[2]) );
  DFEQRM1SA dst_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_d[0]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[0]) );
  DFEQRM1SA dst_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_d[1]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[1]) );
  DFEQRM1SA dst_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_d[2]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[2]) );
  DFEQRM1SA dst_rptr_gray_q_reg_3_ ( .D(dst_rptr_gray_d[3]), .E(n14), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[3]) );
  DFQRM1SA src_wptr_bin_q_reg_0_ ( .D(n3), .CK(src_clk_i), .RB(src_rst_ni), 
        .Q(src_wptr_bin_q[0]) );
  DFEQRM1SA src_wptr_bin_q_reg_1_ ( .D(src_wptr_bin_d[1]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[1]) );
  DFEQRM1SA fifo_data_q_reg_3__0_ ( .D(src_data_i[0]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[64]) );
  DFEQRM1SA fifo_data_q_reg_3__15_ ( .D(src_data_i[15]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[79]) );
  DFEQRM1SA fifo_data_q_reg_3__14_ ( .D(src_data_i[14]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[78]) );
  DFEQRM1SA fifo_data_q_reg_3__13_ ( .D(src_data_i[13]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[77]) );
  DFEQRM1SA fifo_data_q_reg_3__11_ ( .D(src_data_i[11]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[75]) );
  DFEQRM1SA fifo_data_q_reg_3__10_ ( .D(src_data_i[10]), .E(n7), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[74]) );
  DFEQRM1SA fifo_data_q_reg_3__9_ ( .D(src_data_i[9]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[73]) );
  DFEQRM1SA fifo_data_q_reg_3__8_ ( .D(src_data_i[8]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[72]) );
  DFEQRM1SA fifo_data_q_reg_3__7_ ( .D(src_data_i[7]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[71]) );
  DFEQRM1SA fifo_data_q_reg_3__6_ ( .D(src_data_i[6]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[70]) );
  DFEQRM1SA fifo_data_q_reg_3__5_ ( .D(src_data_i[5]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[69]) );
  DFEQRM1SA fifo_data_q_reg_3__4_ ( .D(src_data_i[4]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[68]) );
  DFEQRM1SA fifo_data_q_reg_3__3_ ( .D(src_data_i[3]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[67]) );
  DFEQRM1SA fifo_data_q_reg_3__2_ ( .D(src_data_i[2]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[66]) );
  DFEQRM1SA fifo_data_q_reg_3__1_ ( .D(src_data_i[1]), .E(n7), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[65]) );
  DFEQRM1SA src_wptr_bin_q_reg_2_ ( .D(src_wptr_bin_d[2]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[2]) );
  DFEQRM1SA fifo_data_q_reg_0__0_ ( .D(src_data_i[0]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[112]) );
  DFEQRM1SA fifo_data_q_reg_0__15_ ( .D(src_data_i[15]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[127]) );
  DFEQRM1SA fifo_data_q_reg_0__13_ ( .D(src_data_i[13]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[125]) );
  DFEQRM1SA fifo_data_q_reg_0__12_ ( .D(src_data_i[12]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[124]) );
  DFEQRM1SA fifo_data_q_reg_0__11_ ( .D(src_data_i[11]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[123]) );
  DFEQRM1SA fifo_data_q_reg_0__10_ ( .D(src_data_i[10]), .E(n4), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[122]) );
  DFEQRM1SA fifo_data_q_reg_0__9_ ( .D(src_data_i[9]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[121]) );
  DFEQRM1SA fifo_data_q_reg_0__8_ ( .D(src_data_i[8]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[120]) );
  DFEQRM1SA fifo_data_q_reg_0__7_ ( .D(src_data_i[7]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[119]) );
  DFEQRM1SA fifo_data_q_reg_0__6_ ( .D(src_data_i[6]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[118]) );
  DFEQRM1SA fifo_data_q_reg_0__5_ ( .D(src_data_i[5]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[117]) );
  DFEQRM1SA fifo_data_q_reg_0__4_ ( .D(src_data_i[4]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[116]) );
  DFEQRM1SA fifo_data_q_reg_0__3_ ( .D(src_data_i[3]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[115]) );
  DFEQRM1SA fifo_data_q_reg_0__2_ ( .D(src_data_i[2]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[114]) );
  DFEQRM1SA fifo_data_q_reg_0__1_ ( .D(src_data_i[1]), .E(n4), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[113]) );
  DFEQRM1SA fifo_data_q_reg_7__0_ ( .D(src_data_i[0]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[0]) );
  DFEQRM1SA fifo_data_q_reg_7__14_ ( .D(src_data_i[14]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[14]) );
  DFEQRM1SA fifo_data_q_reg_7__13_ ( .D(src_data_i[13]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[13]) );
  DFEQRM1SA fifo_data_q_reg_7__12_ ( .D(src_data_i[12]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[12]) );
  DFEQRM1SA fifo_data_q_reg_7__11_ ( .D(src_data_i[11]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[11]) );
  DFEQRM1SA fifo_data_q_reg_7__10_ ( .D(src_data_i[10]), .E(n11), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[10]) );
  DFEQRM1SA fifo_data_q_reg_7__9_ ( .D(src_data_i[9]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[9]) );
  DFEQRM1SA fifo_data_q_reg_7__8_ ( .D(src_data_i[8]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[8]) );
  DFEQRM1SA fifo_data_q_reg_7__7_ ( .D(src_data_i[7]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[7]) );
  DFEQRM1SA fifo_data_q_reg_7__6_ ( .D(src_data_i[6]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[6]) );
  DFEQRM1SA fifo_data_q_reg_7__5_ ( .D(src_data_i[5]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[5]) );
  DFEQRM1SA fifo_data_q_reg_7__4_ ( .D(src_data_i[4]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[4]) );
  DFEQRM1SA fifo_data_q_reg_7__3_ ( .D(src_data_i[3]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[3]) );
  DFEQRM1SA fifo_data_q_reg_7__2_ ( .D(src_data_i[2]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[2]) );
  DFEQRM1SA fifo_data_q_reg_7__1_ ( .D(src_data_i[1]), .E(n11), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[1]) );
  DFEQRM1SA fifo_data_q_reg_2__0_ ( .D(src_data_i[0]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[80]) );
  DFEQRM1SA fifo_data_q_reg_2__15_ ( .D(src_data_i[15]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[95]) );
  DFEQRM1SA fifo_data_q_reg_2__14_ ( .D(src_data_i[14]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[94]) );
  DFEQRM1SA fifo_data_q_reg_2__13_ ( .D(src_data_i[13]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[93]) );
  DFEQRM1SA fifo_data_q_reg_2__12_ ( .D(src_data_i[12]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[92]) );
  DFEQRM1SA fifo_data_q_reg_2__11_ ( .D(src_data_i[11]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[91]) );
  DFEQRM1SA fifo_data_q_reg_2__10_ ( .D(src_data_i[10]), .E(n6), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[90]) );
  DFEQRM1SA fifo_data_q_reg_2__9_ ( .D(src_data_i[9]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[89]) );
  DFEQRM1SA fifo_data_q_reg_2__8_ ( .D(src_data_i[8]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[88]) );
  DFEQRM1SA fifo_data_q_reg_2__7_ ( .D(src_data_i[7]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[87]) );
  DFEQRM1SA fifo_data_q_reg_2__6_ ( .D(src_data_i[6]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[86]) );
  DFEQRM1SA fifo_data_q_reg_2__5_ ( .D(src_data_i[5]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[85]) );
  DFEQRM1SA fifo_data_q_reg_2__4_ ( .D(src_data_i[4]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[84]) );
  DFEQRM1SA fifo_data_q_reg_2__3_ ( .D(src_data_i[3]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[83]) );
  DFEQRM1SA fifo_data_q_reg_2__1_ ( .D(src_data_i[1]), .E(n6), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[81]) );
  DFEQRM1SA fifo_data_q_reg_6__0_ ( .D(src_data_i[0]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[16]) );
  DFEQRM1SA fifo_data_q_reg_6__15_ ( .D(src_data_i[15]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[31]) );
  DFEQRM1SA fifo_data_q_reg_6__14_ ( .D(src_data_i[14]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[30]) );
  DFEQRM1SA fifo_data_q_reg_6__13_ ( .D(src_data_i[13]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[29]) );
  DFEQRM1SA fifo_data_q_reg_6__12_ ( .D(src_data_i[12]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[28]) );
  DFEQRM1SA fifo_data_q_reg_6__11_ ( .D(src_data_i[11]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[27]) );
  DFEQRM1SA fifo_data_q_reg_6__10_ ( .D(src_data_i[10]), .E(n10), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[26]) );
  DFEQRM1SA fifo_data_q_reg_6__9_ ( .D(src_data_i[9]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[25]) );
  DFEQRM1SA fifo_data_q_reg_6__8_ ( .D(src_data_i[8]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[24]) );
  DFEQRM1SA fifo_data_q_reg_6__7_ ( .D(src_data_i[7]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[23]) );
  DFEQRM1SA fifo_data_q_reg_6__6_ ( .D(src_data_i[6]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[22]) );
  DFEQRM1SA fifo_data_q_reg_6__5_ ( .D(src_data_i[5]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[21]) );
  DFEQRM1SA fifo_data_q_reg_6__4_ ( .D(src_data_i[4]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[20]) );
  DFEQRM1SA fifo_data_q_reg_6__2_ ( .D(src_data_i[2]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[18]) );
  DFEQRM1SA fifo_data_q_reg_6__1_ ( .D(src_data_i[1]), .E(n10), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[17]) );
  DFEQRM1SA src_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_d[0]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[0]) );
  DFEQRM1SA src_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_d[1]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[1]) );
  DFEQRM1SA src_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_d[2]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[2]) );
  DFEQRM1SA src_wptr_gray_q_reg_3_ ( .D(src_wptr_gray_d[3]), .E(n12), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[3]) );
  DFEQRM1SA fifo_data_q_reg_1__0_ ( .D(src_data_i[0]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[96]) );
  DFEQRM1SA fifo_data_q_reg_1__15_ ( .D(src_data_i[15]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[111]) );
  DFEQRM1SA fifo_data_q_reg_1__14_ ( .D(src_data_i[14]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[110]) );
  DFEQRM1SA fifo_data_q_reg_1__13_ ( .D(src_data_i[13]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[109]) );
  DFEQRM1SA fifo_data_q_reg_1__12_ ( .D(src_data_i[12]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[108]) );
  DFEQRM1SA fifo_data_q_reg_1__10_ ( .D(src_data_i[10]), .E(n5), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[106]) );
  DFEQRM1SA fifo_data_q_reg_1__9_ ( .D(src_data_i[9]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[105]) );
  DFEQRM1SA fifo_data_q_reg_1__8_ ( .D(src_data_i[8]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[104]) );
  DFEQRM1SA fifo_data_q_reg_1__7_ ( .D(src_data_i[7]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[103]) );
  DFEQRM1SA fifo_data_q_reg_1__6_ ( .D(src_data_i[6]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[102]) );
  DFEQRM1SA fifo_data_q_reg_1__5_ ( .D(src_data_i[5]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[101]) );
  DFEQRM1SA fifo_data_q_reg_1__4_ ( .D(src_data_i[4]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[100]) );
  DFEQRM1SA fifo_data_q_reg_1__3_ ( .D(src_data_i[3]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[99]) );
  DFEQRM1SA fifo_data_q_reg_1__2_ ( .D(src_data_i[2]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[98]) );
  DFEQRM1SA fifo_data_q_reg_1__1_ ( .D(src_data_i[1]), .E(n5), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[97]) );
  DFEQRM1SA fifo_data_q_reg_5__0_ ( .D(src_data_i[0]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[32]) );
  DFEQRM1SA fifo_data_q_reg_5__15_ ( .D(src_data_i[15]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[47]) );
  DFEQRM1SA fifo_data_q_reg_5__14_ ( .D(src_data_i[14]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[46]) );
  DFEQRM1SA fifo_data_q_reg_5__13_ ( .D(src_data_i[13]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[45]) );
  DFEQRM1SA fifo_data_q_reg_5__11_ ( .D(src_data_i[11]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[43]) );
  DFEQRM1SA fifo_data_q_reg_5__10_ ( .D(src_data_i[10]), .E(n9), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[42]) );
  DFEQRM1SA fifo_data_q_reg_5__9_ ( .D(src_data_i[9]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[41]) );
  DFEQRM1SA fifo_data_q_reg_5__8_ ( .D(src_data_i[8]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[40]) );
  DFEQRM1SA fifo_data_q_reg_5__7_ ( .D(src_data_i[7]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[39]) );
  DFEQRM1SA fifo_data_q_reg_5__6_ ( .D(src_data_i[6]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[38]) );
  DFEQRM1SA fifo_data_q_reg_5__5_ ( .D(src_data_i[5]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[37]) );
  DFEQRM1SA fifo_data_q_reg_5__4_ ( .D(src_data_i[4]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[36]) );
  DFEQRM1SA fifo_data_q_reg_5__3_ ( .D(src_data_i[3]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[35]) );
  DFEQRM1SA fifo_data_q_reg_5__2_ ( .D(src_data_i[2]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[34]) );
  DFEQRM1SA fifo_data_q_reg_5__1_ ( .D(src_data_i[1]), .E(n9), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[33]) );
  DFEQRM1SA fifo_data_q_reg_4__0_ ( .D(src_data_i[0]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[48]) );
  DFEQRM1SA fifo_data_q_reg_4__15_ ( .D(src_data_i[15]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[63]) );
  DFEQRM1SA fifo_data_q_reg_4__14_ ( .D(src_data_i[14]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[62]) );
  DFEQRM1SA fifo_data_q_reg_4__12_ ( .D(src_data_i[12]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[60]) );
  DFEQRM1SA fifo_data_q_reg_4__11_ ( .D(src_data_i[11]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[59]) );
  DFEQRM1SA fifo_data_q_reg_4__10_ ( .D(src_data_i[10]), .E(n8), .CK(src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[58]) );
  DFEQRM1SA fifo_data_q_reg_4__9_ ( .D(src_data_i[9]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[57]) );
  DFEQRM1SA fifo_data_q_reg_4__8_ ( .D(src_data_i[8]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[56]) );
  DFEQRM1SA fifo_data_q_reg_4__7_ ( .D(src_data_i[7]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[55]) );
  DFEQRM1SA fifo_data_q_reg_4__6_ ( .D(src_data_i[6]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[54]) );
  DFEQRM1SA fifo_data_q_reg_4__5_ ( .D(src_data_i[5]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[53]) );
  DFEQRM1SA fifo_data_q_reg_4__4_ ( .D(src_data_i[4]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[52]) );
  DFEQRM1SA fifo_data_q_reg_4__3_ ( .D(src_data_i[3]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[51]) );
  DFEQRM1SA fifo_data_q_reg_4__2_ ( .D(src_data_i[2]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[50]) );
  DFEQRM1SA fifo_data_q_reg_4__1_ ( .D(src_data_i[1]), .E(n8), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(fifo_data_q[49]) );
  DFQRM1SA dst_wptr_gray_q2_reg_1_ ( .D(dst_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[1]) );
  DFQRM1SA dst_wptr_gray_q2_reg_3_ ( .D(dst_wptr_gray_q[3]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[3]) );
  DFQRM1SA dst_wptr_gray_q2_reg_2_ ( .D(dst_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[2]) );
  DFQRM1SA dst_wptr_gray_q2_reg_0_ ( .D(dst_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[0]) );
  DFQRM1SA src_rptr_gray_q2_reg_1_ ( .D(src_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[1]) );
  DFQRM1SA src_rptr_gray_q2_reg_3_ ( .D(src_rptr_gray_q[3]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[3]) );
  DFQRM1SA src_rptr_gray_q2_reg_2_ ( .D(src_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[2]) );
  DFQRM1SA src_rptr_gray_q2_reg_0_ ( .D(src_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[0]) );
  DFQRM1SA src_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[0]) );
  DFQRM1SA src_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[1]) );
  DFQRM1SA src_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[2]) );
  DFQRM1SA src_rptr_gray_q_reg_3_ ( .D(dst_rptr_gray_q[3]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[3]) );
  DFQRM1SA dst_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[0]) );
  DFQRM1SA dst_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[1]) );
  DFQRM1SA dst_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[2]) );
  DFQRM1SA dst_wptr_gray_q_reg_3_ ( .D(src_wptr_gray_q[3]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[3]) );
  NR2M1S U3 ( .A(src_wptr_bin_q[2]), .B(n25), .Z(n132) );
  ND2M1S U4 ( .A(dst_rptr_bin_q[0]), .B(dst_rptr_bin_q[1]), .Z(n2) );
  AOI22M1S U5 ( .A1(n100), .A2(fifo_data_q[18]), .B1(n99), .B2(fifo_data_q[34]), .Z(n92) );
  AOI22M1S U6 ( .A1(n102), .A2(fifo_data_q[6]), .B1(n101), .B2(fifo_data_q[70]), .Z(n79) );
  AOI22M1S U7 ( .A1(n96), .A2(fifo_data_q[121]), .B1(n95), .B2(fifo_data_q[89]), .Z(n30) );
  AOI22M1S U8 ( .A1(n98), .A2(fifo_data_q[109]), .B1(n97), .B2(fifo_data_q[61]), .Z(n65) );
  AOI22M1S U9 ( .A1(n96), .A2(fifo_data_q[112]), .B1(n95), .B2(fifo_data_q[80]), .Z(n78) );
  MAOI22M1SA U10 ( .A1(src_wptr_bin_q[3]), .A2(n48), .B1(src_wptr_bin_q[3]), 
        .B2(n48), .Z(src_wptr_bin_d[3]) );
  MAOI22M1SA U11 ( .A1(dst_rptr_bin_q[0]), .A2(n14), .B1(n14), .B2(
        dst_rptr_bin_q[0]), .Z(n13) );
  ND4M1S U12 ( .A(n82), .B(n81), .C(n80), .D(n79), .Z(dst_data_o[6]) );
  INVM1S U13 ( .A(src_wptr_bin_q[2]), .Z(n23) );
  ND2M1S U14 ( .A(src_wptr_bin_q[0]), .B(src_wptr_bin_q[1]), .Z(n1) );
  NR2M1S U15 ( .A(n23), .B(n1), .Z(n48) );
  MAOI22M1SA U16 ( .A1(src_wptr_bin_q[0]), .A2(n12), .B1(n12), .B2(
        src_wptr_bin_q[0]), .Z(n3) );
  INVM1S U17 ( .A(dst_rptr_bin_q[2]), .Z(n26) );
  NR2M2S U18 ( .A(n26), .B(n2), .Z(n102) );
  MAOI22M1SA U19 ( .A1(n102), .A2(dst_rptr_bin_q[3]), .B1(n102), .B2(
        dst_rptr_bin_q[3]), .Z(dst_rptr_bin_d[3]) );
  NR2M1S U20 ( .A(src_wptr_bin_q[2]), .B(n1), .Z(n130) );
  AO21M1SA U21 ( .A1(src_wptr_bin_q[2]), .A2(n1), .B(n130), .Z(
        src_wptr_bin_d[2]) );
  NR2M1S U22 ( .A(dst_rptr_bin_q[2]), .B(n2), .Z(n101) );
  AO21M1SA U23 ( .A1(dst_rptr_bin_q[2]), .A2(n2), .B(n101), .Z(
        dst_rptr_bin_d[2]) );
  NR3M1S U24 ( .A(src_wptr_bin_q[2]), .B(src_wptr_bin_q[0]), .C(
        src_wptr_bin_q[1]), .Z(n133) );
  INVM1S U25 ( .A(src_wptr_bin_q[0]), .Z(n134) );
  ND2M1S U26 ( .A(src_wptr_bin_q[1]), .B(n134), .Z(n24) );
  NR2M1S U27 ( .A(src_wptr_bin_q[2]), .B(n24), .Z(n131) );
  NR2M1S U28 ( .A(n23), .B(n24), .Z(n129) );
  ND2B1M1S U29 ( .NA(src_wptr_bin_q[1]), .B(src_wptr_bin_q[0]), .Z(n25) );
  NR2M1S U30 ( .A(n23), .B(n25), .Z(n128) );
  NR3M1S U31 ( .A(src_wptr_bin_q[0]), .B(src_wptr_bin_q[1]), .C(n23), .Z(n127)
         );
  ND2M1S U32 ( .A(n25), .B(n24), .Z(src_wptr_bin_d[1]) );
  INVM1S U33 ( .A(dst_rptr_bin_q[0]), .Z(n135) );
  NR3M2R U34 ( .A(dst_rptr_bin_q[2]), .B(dst_rptr_bin_q[0]), .C(
        dst_rptr_bin_q[1]), .Z(n96) );
  ND2M1S U35 ( .A(dst_rptr_bin_q[1]), .B(n135), .Z(n108) );
  NR2M1S U36 ( .A(dst_rptr_bin_q[2]), .B(n108), .Z(n95) );
  ND2B1M1S U37 ( .NA(dst_rptr_bin_q[1]), .B(dst_rptr_bin_q[0]), .Z(n107) );
  NR2M1S U38 ( .A(dst_rptr_bin_q[2]), .B(n107), .Z(n98) );
  NR3M1R U39 ( .A(dst_rptr_bin_q[0]), .B(dst_rptr_bin_q[1]), .C(n26), .Z(n97)
         );
  AOI22M1S U40 ( .A1(n98), .A2(fifo_data_q[105]), .B1(n97), .B2(
        fifo_data_q[57]), .Z(n29) );
  NR2M1S U41 ( .A(n26), .B(n108), .Z(n100) );
  NR2M1S U42 ( .A(n26), .B(n107), .Z(n99) );
  AOI22M1S U43 ( .A1(n100), .A2(fifo_data_q[25]), .B1(n99), .B2(
        fifo_data_q[41]), .Z(n28) );
  AOI22M1S U44 ( .A1(n102), .A2(fifo_data_q[9]), .B1(n101), .B2(
        fifo_data_q[73]), .Z(n27) );
  ND4M1S U45 ( .A(n30), .B(n29), .C(n28), .D(n27), .Z(dst_data_o[9]) );
  AOI22M1S U46 ( .A1(n96), .A2(fifo_data_q[122]), .B1(n95), .B2(
        fifo_data_q[90]), .Z(n34) );
  AOI22M1S U47 ( .A1(n98), .A2(fifo_data_q[106]), .B1(n97), .B2(
        fifo_data_q[58]), .Z(n33) );
  AOI22M1S U48 ( .A1(n100), .A2(fifo_data_q[26]), .B1(n99), .B2(
        fifo_data_q[42]), .Z(n32) );
  AOI22M1S U49 ( .A1(n102), .A2(fifo_data_q[10]), .B1(n101), .B2(
        fifo_data_q[74]), .Z(n31) );
  ND4M1S U50 ( .A(n34), .B(n33), .C(n32), .D(n31), .Z(dst_data_o[10]) );
  AOI22M1S U51 ( .A1(n96), .A2(fifo_data_q[116]), .B1(n95), .B2(
        fifo_data_q[84]), .Z(n38) );
  AOI22M1S U52 ( .A1(n98), .A2(fifo_data_q[100]), .B1(n97), .B2(
        fifo_data_q[52]), .Z(n37) );
  AOI22M1S U53 ( .A1(n100), .A2(fifo_data_q[20]), .B1(n99), .B2(
        fifo_data_q[36]), .Z(n36) );
  AOI22M1S U54 ( .A1(n102), .A2(fifo_data_q[4]), .B1(n101), .B2(
        fifo_data_q[68]), .Z(n35) );
  ND4M1S U55 ( .A(n38), .B(n37), .C(n36), .D(n35), .Z(dst_data_o[4]) );
  AOI22M1S U56 ( .A1(n96), .A2(fifo_data_q[119]), .B1(n95), .B2(
        fifo_data_q[87]), .Z(n42) );
  AOI22M1S U57 ( .A1(n98), .A2(fifo_data_q[103]), .B1(n97), .B2(
        fifo_data_q[55]), .Z(n41) );
  AOI22M1S U58 ( .A1(n100), .A2(fifo_data_q[23]), .B1(n99), .B2(
        fifo_data_q[39]), .Z(n40) );
  AOI22M1S U59 ( .A1(n102), .A2(fifo_data_q[7]), .B1(n101), .B2(
        fifo_data_q[71]), .Z(n39) );
  ND4M1S U60 ( .A(n42), .B(n41), .C(n40), .D(n39), .Z(dst_data_o[7]) );
  AOI22M1S U61 ( .A1(n96), .A2(fifo_data_q[124]), .B1(n95), .B2(
        fifo_data_q[92]), .Z(n46) );
  AOI22M1S U62 ( .A1(n98), .A2(fifo_data_q[108]), .B1(n97), .B2(
        fifo_data_q[60]), .Z(n45) );
  AOI22M1S U63 ( .A1(n100), .A2(fifo_data_q[28]), .B1(n99), .B2(
        fifo_data_q[44]), .Z(n44) );
  AOI22M1S U64 ( .A1(n102), .A2(fifo_data_q[12]), .B1(n101), .B2(
        fifo_data_q[76]), .Z(n43) );
  ND4M1S U65 ( .A(n46), .B(n45), .C(n44), .D(n43), .Z(dst_data_o[12]) );
  AOI22M1S U66 ( .A1(n96), .A2(fifo_data_q[126]), .B1(n95), .B2(
        fifo_data_q[94]), .Z(n58) );
  AOI22M1S U67 ( .A1(n98), .A2(fifo_data_q[110]), .B1(n97), .B2(
        fifo_data_q[62]), .Z(n57) );
  AOI22M1S U68 ( .A1(n100), .A2(fifo_data_q[30]), .B1(n99), .B2(
        fifo_data_q[46]), .Z(n56) );
  AOI22M1S U69 ( .A1(n102), .A2(fifo_data_q[14]), .B1(n101), .B2(
        fifo_data_q[78]), .Z(n47) );
  ND4M1S U70 ( .A(n58), .B(n57), .C(n56), .D(n47), .Z(dst_data_o[14]) );
  AOI22M1S U71 ( .A1(n96), .A2(fifo_data_q[117]), .B1(n95), .B2(
        fifo_data_q[85]), .Z(n62) );
  AOI22M1S U72 ( .A1(n98), .A2(fifo_data_q[101]), .B1(n97), .B2(
        fifo_data_q[53]), .Z(n61) );
  AOI22M1S U73 ( .A1(n100), .A2(fifo_data_q[21]), .B1(n99), .B2(
        fifo_data_q[37]), .Z(n60) );
  AOI22M1S U74 ( .A1(n102), .A2(fifo_data_q[5]), .B1(n101), .B2(
        fifo_data_q[69]), .Z(n59) );
  ND4M1S U75 ( .A(n62), .B(n61), .C(n60), .D(n59), .Z(dst_data_o[5]) );
  AOI22M1S U76 ( .A1(n96), .A2(fifo_data_q[125]), .B1(n95), .B2(
        fifo_data_q[93]), .Z(n66) );
  AOI22M1S U77 ( .A1(n100), .A2(fifo_data_q[29]), .B1(n99), .B2(
        fifo_data_q[45]), .Z(n64) );
  AOI22M1S U78 ( .A1(n102), .A2(fifo_data_q[13]), .B1(n101), .B2(
        fifo_data_q[77]), .Z(n63) );
  ND4M1S U79 ( .A(n66), .B(n65), .C(n64), .D(n63), .Z(dst_data_o[13]) );
  AOI22M1S U80 ( .A1(n96), .A2(fifo_data_q[113]), .B1(n95), .B2(
        fifo_data_q[81]), .Z(n70) );
  AOI22M1S U81 ( .A1(n98), .A2(fifo_data_q[97]), .B1(n97), .B2(fifo_data_q[49]), .Z(n69) );
  AOI22M1S U82 ( .A1(n100), .A2(fifo_data_q[17]), .B1(n99), .B2(
        fifo_data_q[33]), .Z(n68) );
  AOI22M1S U83 ( .A1(n102), .A2(fifo_data_q[1]), .B1(n101), .B2(
        fifo_data_q[65]), .Z(n67) );
  ND4M1S U84 ( .A(n70), .B(n69), .C(n68), .D(n67), .Z(dst_data_o[1]) );
  AOI22M1S U85 ( .A1(n96), .A2(fifo_data_q[123]), .B1(n95), .B2(
        fifo_data_q[91]), .Z(n74) );
  AOI22M1S U86 ( .A1(n98), .A2(fifo_data_q[107]), .B1(n97), .B2(
        fifo_data_q[59]), .Z(n73) );
  AOI22M1S U87 ( .A1(n100), .A2(fifo_data_q[27]), .B1(n99), .B2(
        fifo_data_q[43]), .Z(n72) );
  AOI22M1S U88 ( .A1(n102), .A2(fifo_data_q[11]), .B1(n101), .B2(
        fifo_data_q[75]), .Z(n71) );
  ND4M1S U89 ( .A(n74), .B(n73), .C(n72), .D(n71), .Z(dst_data_o[11]) );
  AOI22M1S U90 ( .A1(n98), .A2(fifo_data_q[96]), .B1(n97), .B2(fifo_data_q[48]), .Z(n77) );
  AOI22M1S U91 ( .A1(n100), .A2(fifo_data_q[16]), .B1(n99), .B2(
        fifo_data_q[32]), .Z(n76) );
  AOI22M1S U92 ( .A1(n102), .A2(fifo_data_q[0]), .B1(n101), .B2(
        fifo_data_q[64]), .Z(n75) );
  ND4M1S U93 ( .A(n78), .B(n77), .C(n76), .D(n75), .Z(dst_data_o[0]) );
  AOI22M1S U94 ( .A1(n96), .A2(fifo_data_q[118]), .B1(n95), .B2(
        fifo_data_q[86]), .Z(n82) );
  AOI22M1S U95 ( .A1(n98), .A2(fifo_data_q[102]), .B1(n97), .B2(
        fifo_data_q[54]), .Z(n81) );
  AOI22M1S U96 ( .A1(n100), .A2(fifo_data_q[22]), .B1(n99), .B2(
        fifo_data_q[38]), .Z(n80) );
  AOI22M1S U97 ( .A1(n96), .A2(fifo_data_q[127]), .B1(n95), .B2(
        fifo_data_q[95]), .Z(n86) );
  AOI22M1S U98 ( .A1(n98), .A2(fifo_data_q[111]), .B1(n97), .B2(
        fifo_data_q[63]), .Z(n85) );
  AOI22M1S U99 ( .A1(n100), .A2(fifo_data_q[31]), .B1(n99), .B2(
        fifo_data_q[47]), .Z(n84) );
  AOI22M1S U100 ( .A1(n102), .A2(fifo_data_q[15]), .B1(n101), .B2(
        fifo_data_q[79]), .Z(n83) );
  ND4M1S U101 ( .A(n86), .B(n85), .C(n84), .D(n83), .Z(dst_data_o[15]) );
  AOI22M1S U102 ( .A1(n96), .A2(fifo_data_q[120]), .B1(n95), .B2(
        fifo_data_q[88]), .Z(n90) );
  AOI22M1S U103 ( .A1(n98), .A2(fifo_data_q[104]), .B1(n97), .B2(
        fifo_data_q[56]), .Z(n89) );
  AOI22M1S U104 ( .A1(n100), .A2(fifo_data_q[24]), .B1(n99), .B2(
        fifo_data_q[40]), .Z(n88) );
  AOI22M1S U105 ( .A1(n102), .A2(fifo_data_q[8]), .B1(n101), .B2(
        fifo_data_q[72]), .Z(n87) );
  ND4M1S U106 ( .A(n90), .B(n89), .C(n88), .D(n87), .Z(dst_data_o[8]) );
  AOI22M1S U107 ( .A1(n96), .A2(fifo_data_q[114]), .B1(n95), .B2(
        fifo_data_q[82]), .Z(n94) );
  AOI22M1S U108 ( .A1(n98), .A2(fifo_data_q[98]), .B1(n97), .B2(
        fifo_data_q[50]), .Z(n93) );
  AOI22M1S U109 ( .A1(n102), .A2(fifo_data_q[2]), .B1(n101), .B2(
        fifo_data_q[66]), .Z(n91) );
  ND4M1S U110 ( .A(n94), .B(n93), .C(n92), .D(n91), .Z(dst_data_o[2]) );
  AOI22M1S U111 ( .A1(n96), .A2(fifo_data_q[115]), .B1(n95), .B2(
        fifo_data_q[83]), .Z(n106) );
  AOI22M1S U112 ( .A1(n98), .A2(fifo_data_q[99]), .B1(n97), .B2(
        fifo_data_q[51]), .Z(n105) );
  AOI22M1S U113 ( .A1(n100), .A2(fifo_data_q[19]), .B1(n99), .B2(
        fifo_data_q[35]), .Z(n104) );
  AOI22M1S U114 ( .A1(n102), .A2(fifo_data_q[3]), .B1(n101), .B2(
        fifo_data_q[67]), .Z(n103) );
  ND4M1S U115 ( .A(n106), .B(n105), .C(n104), .D(n103), .Z(dst_data_o[3]) );
  ND2M1S U116 ( .A(n108), .B(n107), .Z(dst_rptr_bin_d[1]) );
endmodule


module ddr_in_7 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_0 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_1 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_2 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_3 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_4 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_5 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
endmodule


module ddr_in_6 ( clk_i, data_i, rst_ni, enable, data_o );
  output [1:0] data_o;
  input clk_i, data_i, rst_ni, enable;


  DFCQRM1SA ddr_neg_reg ( .D(data_i), .CKB(clk_i), .RB(rst_ni), .Q(data_o[0])
         );
  DFQRM1SA ddr_pos_reg ( .D(data_i), .CK(clk_i), .RB(rst_ni), .Q(data_o[1]) );
endmodule


module pulp_clock_gating_0 ( clk_i, en_i, test_en_i, clk_o );
  input clk_i, en_i, test_en_i;
  output clk_o;


  LAGCEPM12R clk_gate_i ( .CK(clk_i), .E(en_i), .SE(1'b0), .GCK(clk_o) );
endmodule


module read_clk_rwds ( clk0, rst_ni, config_t_rwds_delay_line, hyper_rwds_i, 
        hyper_dq_i, read_clk_en_i, en_ddr_in_i, ready_i, valid_o, data_o );
  input [31:0] config_t_rwds_delay_line;
  input [7:0] hyper_dq_i;
  output [15:0] data_o;
  input clk0, rst_ni, hyper_rwds_i, read_clk_en_i, en_ddr_in_i, ready_i;
  output valid_o;
  wire   hyper_rwds_i_d, clk_rwds, read_in_valid, resetReadModule, n1, n2, n3,
         SYNOPSYS_UNCONNECTED_1;
  wire   [15:0] src_data;

  hyperbus_delay_line hyperbus_delay_line_i ( .in(hyper_rwds_i), .out(
        hyper_rwds_i_d), .delay({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0}) );
  cdc_fifo_gray_LOG_DEPTH3 i_cdc_fifo_hyper ( .src_rst_ni(rst_ni), .src_clk_i(
        clk_rwds), .src_data_i(src_data), .src_valid_i(read_in_valid), 
        .src_ready_o(SYNOPSYS_UNCONNECTED_1), .dst_rst_ni(rst_ni), .dst_clk_i(
        clk0), .dst_data_o(data_o), .dst_valid_o(valid_o), .dst_ready_i(
        ready_i) );
  ddr_in_7 ddr_out_bus_0__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[0]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[8], src_data[0]}) );
  ddr_in_6 ddr_out_bus_1__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[1]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[9], src_data[1]}) );
  ddr_in_5 ddr_out_bus_2__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[2]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[10], src_data[2]})
         );
  ddr_in_4 ddr_out_bus_3__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[3]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[11], src_data[3]})
         );
  ddr_in_3 ddr_out_bus_4__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[4]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[12], src_data[4]})
         );
  ddr_in_2 ddr_out_bus_5__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[5]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[13], src_data[5]})
         );
  ddr_in_1 ddr_out_bus_6__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[6]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[14], src_data[6]})
         );
  ddr_in_0 ddr_out_bus_7__i_ddr_in ( .clk_i(clk_rwds), .data_i(hyper_dq_i[7]), 
        .rst_ni(rst_ni), .enable(1'b1), .data_o({src_data[15], src_data[7]})
         );
  pulp_clock_gating_0 cdc_read_ck_gating ( .clk_i(hyper_rwds_i_d), .en_i(
        read_clk_en_i), .test_en_i(1'b0), .clk_o(clk_rwds) );
  INVM1S I_1 ( .A(read_clk_en_i), .Z(n1) );
  INVM1S U3 ( .A(resetReadModule), .Z(n2) );
  OR2M1S C15 ( .A(n3), .B(n1), .Z(resetReadModule) );
  DFQRM1SA read_in_valid_reg ( .D(1'b1), .CK(clk_rwds), .RB(n2), .Q(
        read_in_valid) );
  INVM1S U4 ( .A(rst_ni), .Z(n3) );
endmodule


module pulp_clock_mux2_0 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1RA U1 ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_0 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_0 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_1 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1RA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_1 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_1 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_2 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1RA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_2 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_2 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_3 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M2SA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_3 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_3 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_4 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1SA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_4 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_4 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_5 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1RA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_5 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_5 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_6 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M1RA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_6 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_6 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
endmodule


module pulp_clock_mux2_7 ( clk0_i, clk1_i, clk_sel_i, clk_o );
  input clk0_i, clk1_i, clk_sel_i;
  output clk_o;


  MUX2M2SA clk_mux_i ( .A(clk0_i), .B(clk1_i), .S(clk_sel_i), .Z(clk_o) );
endmodule


module ddr_out_7 ( clk_i, rst_ni, d0_i, d1_i, q_o );
  input clk_i, rst_ni, d0_i, d1_i;
  output q_o;
  wire   q1, q0;

  pulp_clock_mux2_7 ddrmux ( .clk0_i(q1), .clk1_i(q0), .clk_sel_i(clk_i), 
        .clk_o(q_o) );
  DFQRM1SA q0_reg ( .D(d0_i), .CK(clk_i), .RB(rst_ni), .Q(q0) );
  DFQRM1SA q1_reg ( .D(d1_i), .CK(clk_i), .RB(rst_ni), .Q(q1) );
endmodule


module hyperbus_phy_BURST_WIDTH9_NR_CS2 ( clk0, clk90, rst_ni, 
        config_t_latency_access, config_t_latency_additional, config_t_cs_max, 
        config_t_read_write_recovery, config_t_rwds_delay_line, trans_valid_i, 
        trans_ready_o, trans_address_i, trans_cs_i, trans_write_i, 
        trans_burst_i, trans_burst_type_i, trans_address_space_i, tx_valid_i, 
        tx_ready_o, tx_data_i, tx_strb_i, rx_valid_o, rx_ready_i, rx_data_o, 
        rx_last_o, rx_error_o, b_valid_o, b_last_o, b_error_o, hyper_cs_no, 
        hyper_ck_o, hyper_ck_no, hyper_rwds_o, hyper_rwds_i, hyper_rwds_oe_o, 
        hyper_dq_i, hyper_dq_o, hyper_dq_oe_o, hyper_reset_no );
  input [31:0] config_t_latency_access;
  input [31:0] config_t_latency_additional;
  input [31:0] config_t_cs_max;
  input [31:0] config_t_read_write_recovery;
  input [31:0] config_t_rwds_delay_line;
  input [31:0] trans_address_i;
  input [1:0] trans_cs_i;
  input [8:0] trans_burst_i;
  input [15:0] tx_data_i;
  input [1:0] tx_strb_i;
  output [15:0] rx_data_o;
  output [1:0] hyper_cs_no;
  input [7:0] hyper_dq_i;
  output [7:0] hyper_dq_o;
  input clk0, clk90, rst_ni, trans_valid_i, trans_write_i, trans_burst_type_i,
         trans_address_space_i, tx_valid_i, rx_ready_i, hyper_rwds_i;
  output trans_ready_o, tx_ready_o, rx_valid_o, rx_last_o, rx_error_o,
         b_valid_o, b_last_o, b_error_o, hyper_ck_o, hyper_ck_no, hyper_rwds_o,
         hyper_rwds_oe_o, hyper_dq_oe_o, hyper_reset_no;
  wire   n13, n17, n19, clock_enable_270, en_cs, hyper_rwds_oe_n, n54,
         write_valid, local_address_space, local_burst_type, local_write,
         read_clk_en, n_1_net_, read_fifo_valid, read_fifo_rst, en_rwds,
         hyper_rwds_i_syn, n_cse_25, n127, n131, n137, n145, n150, n154, n158,
         n167, n171, n204, n205, n207, n208, n235, n258, n260, n265, n266,
         n277, n278, n297, n307, n315, n316, n322, n323, n331, n332, n333,
         n334, n335, n336, n337, n338, n339, n340, n341, n342, n343, n344,
         n345, read_clk_en_n, n425, n426, n427, n428, n429, n430, n431, n432,
         n433, n434, n435, n436, n437, n438, n439, n440, n441, n467, n491,
         n503, n527, n545, n561, n298, n283, n282, n279, n267, n259, n231,
         n228, n1, n2, n3, n129, n139, n140, n141, n146, n147, n160, n161,
         n162, n163, n164, n172, n173, n174, n175, n177, n179, n180, n181,
         n182, n596, n597, n598, n599, n600, n601, n602, n603, n604, n605,
         n606, n607, n608, n609, n610, n611, n612, n613, n614, n615, n616,
         n617, n618, n619, n620, n621, n622, n623, n624, n625, n626, n627,
         n628, n629, n630, n631, n632, n633, n634, n635, n636, n637, n638,
         n639, n640, n641, n642, n643, n644, n645, n646, n647, n648, n649,
         n650, n651, n652, n653, n654, n655, n656, n657, n658, n659, n660,
         n661, n662, n663, n664, n665, n666, n667, n668, n669, n670, n671,
         n672, n673, n674, n675, n676, n677, n678, n679, n680, n681, n682,
         n683, n684, n685, n686, n687, n688, n689, n690, n691, n692, n693,
         n694, n695, n696, n697, n698, n699, n700, n701, n702, n703, n704,
         n705, n706, n707, n708, n709, n710, n711, n712, n713, n714, n715,
         n716, n717, n718, n719, n720, n721, n722, n723, n724, n725, n726,
         n727, n728, n729, n730, n731, n732, n733, n734, n735, n736, n737,
         n738, n739, n740, n741, n742, n743, n744, n745, n746, n747, n748,
         n749, n750, n751, n752, n753, n754, n755, n756, n757, n758, n759,
         n760, n761, n762, n763, n764, n765, n766, n767, n768, n769, n770,
         n771, n772, n773, n774, n775, n776, n777, n778, n779, n780, n781,
         n782, n783, n784, n785, n786, n787, n788, n789, n790, n791, n792,
         n793, n794, n795, n796, n797, n798, n799, n800, n801, n802, n803,
         n804, n805, n806, n807, n808, n809, n810, n811, n812, n813, n814,
         n815, n818, SYNOPSYS_UNCONNECTED_1, SYNOPSYS_UNCONNECTED_2,
         SYNOPSYS_UNCONNECTED_3, SYNOPSYS_UNCONNECTED_4,
         SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6,
         SYNOPSYS_UNCONNECTED_7, SYNOPSYS_UNCONNECTED_8,
         SYNOPSYS_UNCONNECTED_9, SYNOPSYS_UNCONNECTED_10,
         SYNOPSYS_UNCONNECTED_11, SYNOPSYS_UNCONNECTED_12,
         SYNOPSYS_UNCONNECTED_13, SYNOPSYS_UNCONNECTED_14,
         SYNOPSYS_UNCONNECTED_15, SYNOPSYS_UNCONNECTED_16,
         SYNOPSYS_UNCONNECTED_17, SYNOPSYS_UNCONNECTED_18,
         SYNOPSYS_UNCONNECTED_19, SYNOPSYS_UNCONNECTED_20,
         SYNOPSYS_UNCONNECTED_21, SYNOPSYS_UNCONNECTED_22,
         SYNOPSYS_UNCONNECTED_23;
  wire   [1:0] local_cs;
  wire   [15:0] data_out;
  wire   [15:0] write_data;
  wire   [1:0] write_strb;
  wire   [1:0] data_rwds_out;
  wire   [31:0] local_address;
  wire   [45:0] cmd_addr;
  wire   [1:0] cmd_addr_sel;
  wire   [3:0] hyper_trans_state;
  wire   [3:0] wait_cnt;
  wire   [8:0] burst_cnt;
  wire   [8:0] local_burst;
  wire   [15:0] cs_max;

  clock_diff_out clock_diff_out_i ( .in_i(clk90), .en_i(clock_enable_270), 
        .out_o(hyper_ck_o), .out_no(hyper_ck_no) );
  ddr_out_8 ddr_out_bus_0__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[8]), .d1_i(data_out[0]), .q_o(hyper_dq_o[0]) );
  ddr_out_7 ddr_out_bus_1__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[9]), .d1_i(data_out[1]), .q_o(hyper_dq_o[1]) );
  ddr_out_6 ddr_out_bus_2__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[10]), .d1_i(data_out[2]), .q_o(hyper_dq_o[2]) );
  ddr_out_5 ddr_out_bus_3__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[11]), .d1_i(data_out[3]), .q_o(hyper_dq_o[3]) );
  ddr_out_4 ddr_out_bus_4__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[12]), .d1_i(data_out[4]), .q_o(hyper_dq_o[4]) );
  ddr_out_3 ddr_out_bus_5__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[13]), .d1_i(data_out[5]), .q_o(hyper_dq_o[5]) );
  ddr_out_2 ddr_out_bus_6__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[14]), .d1_i(data_out[6]), .q_o(hyper_dq_o[6]) );
  ddr_out_1 ddr_out_bus_7__ddr_data ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_out[15]), .d1_i(data_out[7]), .q_o(hyper_dq_o[7]) );
  ddr_out_0 ddr_data_strb ( .clk_i(clk0), .rst_ni(rst_ni), .d0_i(
        data_rwds_out[1]), .d1_i(data_rwds_out[0]), .q_o(hyper_rwds_o) );
  cmd_addr_gen cmd_addr_gen ( .rw_i(1'b0), .address_space_i(1'b0), 
        .burst_type_i(local_burst_type), .address_i(local_address), 
        .cmd_addr_o({SYNOPSYS_UNCONNECTED_1, SYNOPSYS_UNCONNECTED_2, 
        cmd_addr[45:16], SYNOPSYS_UNCONNECTED_3, SYNOPSYS_UNCONNECTED_4, 
        SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6, SYNOPSYS_UNCONNECTED_7, 
        SYNOPSYS_UNCONNECTED_8, SYNOPSYS_UNCONNECTED_9, 
        SYNOPSYS_UNCONNECTED_10, SYNOPSYS_UNCONNECTED_11, 
        SYNOPSYS_UNCONNECTED_12, SYNOPSYS_UNCONNECTED_13, 
        SYNOPSYS_UNCONNECTED_14, SYNOPSYS_UNCONNECTED_15, cmd_addr[2:0]}) );
  read_clk_rwds i_read_clk_rwds ( .clk0(clk0), .rst_ni(rst_ni), 
        .config_t_rwds_delay_line({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0}), .hyper_rwds_i(hyper_rwds_i), .hyper_dq_i(hyper_dq_i), 
        .read_clk_en_i(read_clk_en), .en_ddr_in_i(1'b0), .ready_i(n_1_net_), 
        .valid_o(read_fifo_valid), .data_o(rx_data_o) );
  CKAN2M2S C1640 ( .A(n298), .B(local_write), .Z(SYNOPSYS_UNCONNECTED_16) );
  CKAN2M2S C1628 ( .A(n283), .B(n179), .Z(SYNOPSYS_UNCONNECTED_17) );
  CKAN2M2S C1613 ( .A(n267), .B(n_cse_25), .Z(SYNOPSYS_UNCONNECTED_18) );
  CKAN2M2S C1604 ( .A(n231), .B(n545), .Z(SYNOPSYS_UNCONNECTED_19) );
  CKAN2M2S C1603 ( .A(n231), .B(n179), .Z(SYNOPSYS_UNCONNECTED_20) );
  OR2M1S C1495 ( .A(rx_ready_i), .B(read_fifo_rst), .Z(n_1_net_) );
  DFQSM1SA hyper_cs_no_reg_0_ ( .D(n172), .CK(clk90), .SB(rst_ni), .Q(
        hyper_cs_no[0]) );
  DFQSM1SA hyper_cs_no_reg_1_ ( .D(n164), .CK(clk90), .SB(rst_ni), .Q(
        hyper_cs_no[1]) );
  CKAN2M2S C1606 ( .A(n278), .B(n527), .Z(n258) );
  OR2M1S C1609 ( .A(n258), .B(n179), .Z(n259) );
  CKAN2M2S C1637 ( .A(n258), .B(n545), .Z(n344) );
  CKBUFM1S B_13 ( .A(n204), .Z(n13) );
  CKBUFM1S B_19 ( .A(rx_ready_i), .Z(n19) );
  CKBUFM1S B_17 ( .A(n277), .Z(n17) );
  AO22M1SA U224 ( .A1(n161), .A2(n137), .B1(n491), .B2(n127), .Z(n145) );
  AO22M1SA U232 ( .A1(n177), .A2(n167), .B1(n503), .B2(n150), .Z(n171) );
  AO22M1SA U228 ( .A1(n177), .A2(n154), .B1(n503), .B2(n150), .Z(n158) );
  CKAN2M2S C1629 ( .A(n279), .B(n345), .Z(n298) );
  INVM1S I_58 ( .A(tx_valid_i), .Z(n278) );
  INVM1S I_56 ( .A(n259), .Z(n260) );
  INVM1S I_51 ( .A(n204), .Z(n205) );
  CKAN2M2S C1497 ( .A(read_fifo_valid), .B(n174), .Z(n561) );
  INVM1S I_57 ( .A(rx_ready_i), .Z(n277) );
  CKAN2M2S C1511 ( .A(rx_valid_o), .B(rx_ready_i), .Z(n_cse_25) );
  CKAN2M2S C1639 ( .A(n278), .B(local_write), .Z(n345) );
  CKAN2M2S C1626 ( .A(n282), .B(rx_ready_i), .Z(n283) );
  CKAN2M2S C1600 ( .A(n228), .B(n_cse_25), .Z(n231) );
  OR2M1S C1496 ( .A(n561), .B(rx_error_o), .Z(rx_valid_o) );
  AO22M1SA U262 ( .A1(en_cs), .A2(n425), .B1(n163), .B2(config_t_cs_max[15]), 
        .Z(n441) );
  CKAN2M2S C1485 ( .A(tx_valid_i), .B(tx_ready_o), .Z(n54) );
  DFEQRM1SA burst_cnt_reg_8_ ( .D(n338), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[8]) );
  DFQRM1SA cs_max_reg_8_ ( .D(n434), .CK(clk0), .RB(rst_ni), .Q(cs_max[8]) );
  DFEQRM1SA local_address_reg_30_ ( .D(trans_address_i[30]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[30]) );
  DFEQRM1SA local_address_reg_15_ ( .D(trans_address_i[15]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[15]) );
  DFEQRM1SA cmd_addr_sel_reg_1_ ( .D(n323), .E(n162), .CK(clk0), .RB(rst_ni), 
        .Q(cmd_addr_sel[1]) );
  DFEQRM1SA write_data_reg_9_ ( .D(tx_data_i[9]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[9]) );
  DFEQRM1SA local_burst_reg_2_ ( .D(trans_burst_i[2]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[2]) );
  AO22M1SA U241 ( .A1(n182), .A2(n235), .B1(n345), .B2(n235), .Z(n307) );
  AO22M1SA U246 ( .A1(n180), .A2(1'b1), .B1(n467), .B2(n129), .Z(n343) );
  AO22M1SA U220 ( .A1(n131), .A2(1'b0), .B1(n181), .B2(n127), .Z(n137) );
  AO222M1SA U236 ( .A1(1'b0), .A2(n260), .B1(1'b1), .B2(n179), .C1(1'b1), .C2(
        n344), .Z(n266) );
  AO22M1SA U237 ( .A1(n179), .A2(n19), .B1(1'b0), .B2(n17), .Z(n297) );
  AO22M1SA U234 ( .A1(n146), .A2(n13), .B1(1'b1), .B2(n205), .Z(n208) );
  AO22M1SA U233 ( .A1(1'b1), .A2(n13), .B1(n177), .B2(n205), .Z(n207) );
  DFQRM1SA clock_enable_270_reg ( .D(n175), .CK(clk0), .RB(rst_ni), .Q(
        clock_enable_270) );
  DFEQRM1SA local_write_reg ( .D(trans_write_i), .E(n814), .CK(clk0), .RB(
        rst_ni), .Q(local_write) );
  DFEQRM1SA hyper_trans_state_reg_3_ ( .D(n343), .E(n339), .CK(clk0), .RB(
        rst_ni), .Q(hyper_trans_state[3]) );
  DFEQRM1SA hyper_trans_state_reg_2_ ( .D(n342), .E(n339), .CK(clk0), .RB(
        rst_ni), .Q(hyper_trans_state[2]) );
  DFERM1SA wait_cnt_reg_1_ ( .D(n3), .E(n140), .CK(clk0), .RB(rst_ni), .Q(
        SYNOPSYS_UNCONNECTED_21), .QB(wait_cnt[1]) );
  DFQRM1SA read_clk_en_reg ( .D(read_clk_en_n), .CK(clk0), .RB(rst_ni), .Q(
        read_clk_en) );
  DFEQRM1SA burst_cnt_reg_0_ ( .D(n818), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[0]) );
  DFEQRM1SA burst_cnt_reg_7_ ( .D(n337), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[7]) );
  DFEQRM1SA burst_cnt_reg_6_ ( .D(n336), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[6]) );
  DFEQRM1SA burst_cnt_reg_5_ ( .D(n335), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[5]) );
  DFEQRM1SA burst_cnt_reg_4_ ( .D(n334), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[4]) );
  DFEQRM1SA burst_cnt_reg_3_ ( .D(n333), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[3]) );
  DFEQRM1SA burst_cnt_reg_2_ ( .D(n332), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[2]) );
  DFEQRM1SA burst_cnt_reg_1_ ( .D(n331), .E(n141), .CK(clk0), .RB(rst_ni), .Q(
        burst_cnt[1]) );
  DFQRM1SA cs_max_reg_15_ ( .D(n441), .CK(clk0), .RB(rst_ni), .Q(cs_max[15])
         );
  DFQRM1SA cs_max_reg_14_ ( .D(n440), .CK(clk0), .RB(rst_ni), .Q(cs_max[14])
         );
  DFQRM1SA cs_max_reg_13_ ( .D(n439), .CK(clk0), .RB(rst_ni), .Q(cs_max[13])
         );
  DFQRM1SA cs_max_reg_12_ ( .D(n438), .CK(clk0), .RB(rst_ni), .Q(cs_max[12])
         );
  DFQRM1SA cs_max_reg_11_ ( .D(n437), .CK(clk0), .RB(rst_ni), .Q(cs_max[11])
         );
  DFQRM1SA cs_max_reg_10_ ( .D(n436), .CK(clk0), .RB(rst_ni), .Q(cs_max[10])
         );
  DFQRM1SA cs_max_reg_9_ ( .D(n435), .CK(clk0), .RB(rst_ni), .Q(cs_max[9]) );
  DFQRM1SA cs_max_reg_7_ ( .D(n433), .CK(clk0), .RB(rst_ni), .Q(cs_max[7]) );
  DFQRM1SA cs_max_reg_6_ ( .D(n432), .CK(clk0), .RB(rst_ni), .Q(cs_max[6]) );
  DFQRM1SA cs_max_reg_5_ ( .D(n431), .CK(clk0), .RB(rst_ni), .Q(cs_max[5]) );
  DFQRM1SA cs_max_reg_4_ ( .D(n430), .CK(clk0), .RB(rst_ni), .Q(cs_max[4]) );
  DFQRM1SA cs_max_reg_3_ ( .D(n429), .CK(clk0), .RB(rst_ni), .Q(cs_max[3]) );
  DFQRM1SA cs_max_reg_2_ ( .D(n428), .CK(clk0), .RB(rst_ni), .Q(cs_max[2]) );
  DFQRM1SA cs_max_reg_1_ ( .D(n427), .CK(clk0), .RB(rst_ni), .Q(cs_max[1]) );
  DFQRM1SA cs_max_reg_0_ ( .D(n426), .CK(clk0), .RB(rst_ni), .Q(cs_max[0]) );
  DFEQRM1SA local_address_reg_0_ ( .D(trans_address_i[0]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[0]) );
  DFEQRM1SA local_address_space_reg ( .D(trans_address_space_i), .E(n814), 
        .CK(clk0), .RB(rst_ni), .Q(local_address_space) );
  DFERM1SA local_burst_type_reg ( .D(n2), .E(n814), .CK(clk0), .RB(rst_ni), 
        .Q(SYNOPSYS_UNCONNECTED_22), .QB(local_burst_type) );
  DFEQRM1SA local_cs_reg_1_ ( .D(trans_cs_i[1]), .E(n814), .CK(clk0), .RB(
        rst_ni), .Q(local_cs[1]) );
  DFEQRM1SA local_cs_reg_0_ ( .D(trans_cs_i[0]), .E(n814), .CK(clk0), .RB(
        rst_ni), .Q(local_cs[0]) );
  DFEQRM1SA local_address_reg_31_ ( .D(trans_address_i[31]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[31]) );
  DFEQRM1SA local_address_reg_29_ ( .D(trans_address_i[29]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[29]) );
  DFEQRM1SA local_address_reg_28_ ( .D(trans_address_i[28]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[28]) );
  DFEQRM1SA local_address_reg_27_ ( .D(trans_address_i[27]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[27]) );
  DFEQRM1SA local_address_reg_26_ ( .D(trans_address_i[26]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[26]) );
  DFEQRM1SA local_address_reg_25_ ( .D(trans_address_i[25]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[25]) );
  DFEQRM1SA local_address_reg_24_ ( .D(trans_address_i[24]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[24]) );
  DFEQRM1SA local_address_reg_23_ ( .D(trans_address_i[23]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[23]) );
  DFEQRM1SA local_address_reg_22_ ( .D(trans_address_i[22]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[22]) );
  DFEQRM1SA local_address_reg_21_ ( .D(trans_address_i[21]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[21]) );
  DFEQRM1SA local_address_reg_20_ ( .D(trans_address_i[20]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[20]) );
  DFEQRM1SA local_address_reg_19_ ( .D(trans_address_i[19]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[19]) );
  DFEQRM1SA local_address_reg_18_ ( .D(trans_address_i[18]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[18]) );
  DFEQRM1SA local_address_reg_17_ ( .D(trans_address_i[17]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[17]) );
  DFEQRM1SA local_address_reg_16_ ( .D(trans_address_i[16]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[16]) );
  DFEQRM1SA local_address_reg_13_ ( .D(trans_address_i[13]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[13]) );
  DFEQRM1SA local_address_reg_12_ ( .D(trans_address_i[12]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[12]) );
  DFEQRM1SA local_address_reg_11_ ( .D(trans_address_i[11]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[11]) );
  DFEQRM1SA local_address_reg_10_ ( .D(trans_address_i[10]), .E(n814), .CK(
        clk0), .RB(rst_ni), .Q(local_address[10]) );
  DFEQRM1SA local_address_reg_9_ ( .D(trans_address_i[9]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[9]) );
  DFEQRM1SA local_address_reg_8_ ( .D(trans_address_i[8]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[8]) );
  DFEQRM1SA local_address_reg_7_ ( .D(trans_address_i[7]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[7]) );
  DFEQRM1SA local_address_reg_6_ ( .D(trans_address_i[6]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[6]) );
  DFEQRM1SA local_address_reg_5_ ( .D(trans_address_i[5]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[5]) );
  DFEQRM1SA local_address_reg_4_ ( .D(trans_address_i[4]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[4]) );
  DFEQRM1SA local_address_reg_3_ ( .D(trans_address_i[3]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[3]) );
  DFEQRM1SA local_address_reg_2_ ( .D(trans_address_i[2]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[2]) );
  DFEQRM1SA local_address_reg_1_ ( .D(trans_address_i[1]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_address[1]) );
  DFEQRM1SA cmd_addr_sel_reg_0_ ( .D(n322), .E(n162), .CK(clk0), .RB(rst_ni), 
        .Q(cmd_addr_sel[0]) );
  DFEQRM1SA wait_cnt_reg_0_ ( .D(n160), .E(n140), .CK(clk0), .RB(rst_ni), .Q(
        wait_cnt[0]) );
  DFERM1SA wait_cnt_reg_2_ ( .D(n1), .E(n140), .CK(clk0), .RB(rst_ni), .Q(n815), .QB(wait_cnt[2]) );
  DFEQRM1SA wait_cnt_reg_3_ ( .D(n147), .E(n140), .CK(clk0), .RB(rst_ni), .Q(
        wait_cnt[3]) );
  DFEQRM1SA hyper_rwds_i_syn_reg ( .D(hyper_rwds_i), .E(en_rwds), .CK(clk0), 
        .RB(rst_ni), .Q(hyper_rwds_i_syn) );
  DFQRM1SA write_valid_reg ( .D(n54), .CK(clk0), .RB(rst_ni), .Q(write_valid)
         );
  DFEQRM1SA write_data_reg_0_ ( .D(tx_data_i[0]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[0]) );
  DFEQRM1SA write_strb_reg_1_ ( .D(tx_strb_i[1]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_strb[1]) );
  DFEQRM1SA write_strb_reg_0_ ( .D(tx_strb_i[0]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_strb[0]) );
  DFEQRM1SA write_data_reg_15_ ( .D(tx_data_i[15]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[15]) );
  DFEQRM1SA write_data_reg_14_ ( .D(tx_data_i[14]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[14]) );
  DFEQRM1SA write_data_reg_13_ ( .D(tx_data_i[13]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[13]) );
  DFEQRM1SA write_data_reg_12_ ( .D(tx_data_i[12]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[12]) );
  DFEQRM1SA write_data_reg_11_ ( .D(tx_data_i[11]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[11]) );
  DFEQRM1SA write_data_reg_10_ ( .D(tx_data_i[10]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[10]) );
  DFEQRM1SA write_data_reg_8_ ( .D(tx_data_i[8]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[8]) );
  DFEQRM1SA write_data_reg_7_ ( .D(tx_data_i[7]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[7]) );
  DFEQRM1SA write_data_reg_6_ ( .D(tx_data_i[6]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[6]) );
  DFEQRM1SA write_data_reg_5_ ( .D(tx_data_i[5]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[5]) );
  DFEQRM1SA write_data_reg_4_ ( .D(tx_data_i[4]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[4]) );
  DFEQRM1SA write_data_reg_3_ ( .D(tx_data_i[3]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[3]) );
  DFEQRM1SA write_data_reg_2_ ( .D(tx_data_i[2]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[2]) );
  DFEQRM1SA write_data_reg_1_ ( .D(tx_data_i[1]), .E(n54), .CK(clk0), .RB(
        rst_ni), .Q(write_data[1]) );
  DFEQRM1SA local_burst_reg_8_ ( .D(trans_burst_i[8]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[8]) );
  DFEQRM1SA local_burst_reg_7_ ( .D(trans_burst_i[7]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[7]) );
  DFEQRM1SA local_burst_reg_6_ ( .D(trans_burst_i[6]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[6]) );
  DFEQRM1SA local_burst_reg_5_ ( .D(trans_burst_i[5]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[5]) );
  DFEQRM1SA local_burst_reg_4_ ( .D(trans_burst_i[4]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[4]) );
  DFEQRM1SA local_burst_reg_3_ ( .D(trans_burst_i[3]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[3]) );
  DFEQRM1SA local_burst_reg_1_ ( .D(trans_burst_i[1]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[1]) );
  DFEQRM1SA local_burst_reg_0_ ( .D(trans_burst_i[0]), .E(n814), .CK(clk0), 
        .RB(rst_ni), .Q(local_burst[0]) );
  DFEQRM1SA hyper_trans_state_reg_0_ ( .D(n340), .E(n339), .CK(clk0), .RB(
        rst_ni), .Q(hyper_trans_state[0]) );
  DFEQRM1SA hyper_trans_state_reg_1_ ( .D(n341), .E(n339), .CK(clk0), .RB(
        rst_ni), .Q(hyper_trans_state[1]) );
  DFEQRM1SA en_cs_reg ( .D(n315), .E(n173), .CK(clk0), .RB(rst_ni), .Q(en_cs)
         );
  DFQRM1SA hyper_rwds_oe_o_reg ( .D(hyper_rwds_oe_n), .CK(clk0), .RB(rst_ni), 
        .Q(hyper_rwds_oe_o) );
  DFQRM2SA hyper_dq_oe_o_reg ( .D(n139), .CK(clk0), .RB(rst_ni), .Q(
        hyper_dq_oe_o) );
  DFERM1SA local_address_reg_14_ ( .D(trans_address_i[14]), .E(n814), .CK(clk0), .RB(rst_ni), .Q(local_address[14]), .QB(SYNOPSYS_UNCONNECTED_23) );
  AO222M1SA U235 ( .A1(1'b0), .A2(n260), .B1(1'b1), .B2(n179), .C1(1'b0), .C2(
        n344), .Z(n265) );
  AO22M4RA U242 ( .A1(1'b1), .A2(n180), .B1(n316), .B2(n467), .Z(n339) );
  ND2M2R U3 ( .A(en_cs), .B(local_cs[0]), .Z(n172) );
  OAI211M1S U4 ( .A1(n791), .A2(n790), .B(n789), .C(n788), .Z(n316) );
  NR2B1M2R U5 ( .NA(n771), .B(n770), .Z(en_rwds) );
  OAI211M1S U6 ( .A1(n785), .A2(n784), .B(n783), .C(n782), .Z(n786) );
  OAI211M1R U7 ( .A1(hyper_trans_state[0]), .A2(trans_valid_i), .B(n779), .C(
        n769), .Z(n783) );
  AOI211M2W U8 ( .A1(hyper_trans_state[0]), .A2(n787), .B(en_rwds), .C(n786), 
        .Z(n788) );
  ND2M2S U9 ( .A(n768), .B(n174), .Z(n173) );
  AOI22M1R U10 ( .A1(trans_valid_i), .A2(n315), .B1(n767), .B2(n265), .Z(n768)
         );
  OAI21B20M2R U11 ( .NA1(n771), .NA2(n770), .B(n783), .Z(n162) );
  ND2M4S U12 ( .A(n596), .B(n720), .Z(n814) );
  ND2M2R U13 ( .A(en_cs), .B(local_cs[1]), .Z(n164) );
  NR2M1S U14 ( .A(hyper_trans_state[3]), .B(hyper_trans_state[2]), .Z(n779) );
  ND2M1S U15 ( .A(n753), .B(n771), .Z(n782) );
  NR2M1S U16 ( .A(hyper_trans_state[1]), .B(hyper_trans_state[0]), .Z(n772) );
  INVM1S U17 ( .A(rst_ni), .Z(n640) );
  ND2M1S U18 ( .A(hyper_trans_state[1]), .B(n697), .Z(n174) );
  NR2M1S U19 ( .A(hyper_trans_state[2]), .B(n643), .Z(n697) );
  ND2M1S U20 ( .A(n754), .B(hyper_trans_state[1]), .Z(n756) );
  NR2M1S U21 ( .A(n491), .B(n181), .Z(n753) );
  NR2M1S U22 ( .A(n652), .B(n763), .Z(n771) );
  INVM1S U23 ( .A(rx_ready_i), .Z(n785) );
  NR2M1S U24 ( .A(hyper_trans_state[0]), .B(n756), .Z(n767) );
  ND2M1S U25 ( .A(n697), .B(n772), .Z(n784) );
  INVM1S U26 ( .A(hyper_trans_state[1]), .Z(n769) );
  ND2M1S U27 ( .A(cmd_addr_sel[0]), .B(cmd_addr_sel[1]), .Z(n770) );
  OAI31M1S U28 ( .A1(hyper_trans_state[1]), .A2(hyper_trans_state[2]), .A3(
        n781), .B(n780), .Z(n787) );
  ND2M1S U29 ( .A(n778), .B(n697), .Z(n717) );
  INVM1S U30 ( .A(n467), .Z(n180) );
  NR2M1S U31 ( .A(n182), .B(n717), .Z(b_error_o) );
  NR2M1S U32 ( .A(local_write), .B(n717), .Z(rx_error_o) );
  NR2M1S U33 ( .A(n651), .B(n763), .Z(n315) );
  MAOI22M1SA U34 ( .A1(en_cs), .A2(n601), .B1(en_cs), .B2(config_t_cs_max[2]), 
        .Z(n428) );
  AOI211M1S U35 ( .A1(n778), .A2(n266), .B(hyper_trans_state[3]), .C(n777), 
        .Z(n791) );
  NR2B1M1S U36 ( .NA(n750), .B(config_t_latency_additional[2]), .Z(n751) );
  NR2M1S U37 ( .A(config_t_read_write_recovery[1]), .B(
        config_t_read_write_recovery[2]), .Z(n740) );
  NR2M1S U38 ( .A(config_t_latency_additional[0]), .B(
        config_t_latency_additional[1]), .Z(n750) );
  NR2M1S U39 ( .A(n491), .B(n683), .Z(n669) );
  NR2M1S U40 ( .A(cs_max[3]), .B(n619), .Z(n618) );
  NR2B1M1S U41 ( .NA(local_burst[4]), .B(n752), .Z(n672) );
  OAI31M1S U42 ( .A1(n775), .A2(n708), .A3(n785), .B(hyper_trans_state[1]), 
        .Z(n707) );
  NR2M1S U43 ( .A(n764), .B(n763), .Z(trans_ready_o) );
  OAI211M1S U44 ( .A1(n790), .A2(n678), .B(n782), .C(n677), .Z(tx_ready_o) );
  MAOI22M1SA U45 ( .A1(n716), .A2(cs_max[15]), .B1(n716), .B2(cs_max[15]), .Z(
        n425) );
  AOI21M1S U46 ( .A1(n693), .A2(burst_cnt[5]), .B(n679), .Z(n681) );
  INVM1S U47 ( .A(n700), .Z(n662) );
  ND4M1S U48 ( .A(cs_max[0]), .B(n639), .C(n638), .D(n637), .Z(n467) );
  AO222M1SA U49 ( .A1(n683), .A2(write_data[5]), .B1(n682), .B2(cmd_addr[21]), 
        .C1(cmd_addr[37]), .C2(n684), .Z(data_out[5]) );
  AO222M1SA U50 ( .A1(n683), .A2(write_data[8]), .B1(n682), .B2(cmd_addr[24]), 
        .C1(cmd_addr[40]), .C2(n684), .Z(data_out[8]) );
  OAI32M1S U51 ( .A1(n180), .A2(n763), .A3(n762), .B1(n761), .B2(n180), .Z(
        n340) );
  OAI21M1S U52 ( .A1(n658), .A2(n657), .B(n656), .Z(n332) );
  INVM1S U53 ( .A(local_write), .Z(n182) );
  INVM1S U54 ( .A(n772), .Z(n651) );
  INVM1S U55 ( .A(n779), .Z(n763) );
  INVM1S U56 ( .A(n315), .Z(n596) );
  ND2M1S U57 ( .A(hyper_trans_state[1]), .B(hyper_trans_state[0]), .Z(n774) );
  NR2M1S U58 ( .A(hyper_trans_state[2]), .B(n774), .Z(n711) );
  ND2M1S U59 ( .A(hyper_trans_state[3]), .B(n711), .Z(n720) );
  INVM1S U60 ( .A(en_cs), .Z(n163) );
  NR2M1S U61 ( .A(cs_max[1]), .B(cs_max[0]), .Z(n600) );
  AOI21M1S U62 ( .A1(cs_max[0]), .A2(cs_max[1]), .B(n600), .Z(n597) );
  MAOI22M1SA U63 ( .A1(en_cs), .A2(n597), .B1(en_cs), .B2(config_t_cs_max[1]), 
        .Z(n427) );
  NR2M1S U64 ( .A(cs_max[5]), .B(cs_max[4]), .Z(n631) );
  INVM1S U65 ( .A(cs_max[2]), .Z(n637) );
  ND2M1S U66 ( .A(n600), .B(n637), .Z(n619) );
  ND2M1S U67 ( .A(n631), .B(n618), .Z(n615) );
  MAOI22M1SA U68 ( .A1(cs_max[6]), .A2(n615), .B1(cs_max[6]), .B2(n615), .Z(
        n598) );
  MAOI22M1SA U69 ( .A1(en_cs), .A2(n598), .B1(en_cs), .B2(config_t_cs_max[6]), 
        .Z(n432) );
  NR2M1S U70 ( .A(cs_max[9]), .B(cs_max[8]), .Z(n633) );
  NR3M1S U71 ( .A(cs_max[7]), .B(cs_max[6]), .C(n615), .Z(n616) );
  ND2M1S U72 ( .A(n633), .B(n616), .Z(n621) );
  NR3M1S U73 ( .A(cs_max[11]), .B(cs_max[10]), .C(n621), .Z(n606) );
  OAI32M1S U74 ( .A1(n606), .A2(cs_max[10]), .A3(n621), .B1(cs_max[11]), .B2(
        n606), .Z(n599) );
  MAOI22M1SA U75 ( .A1(en_cs), .A2(n599), .B1(en_cs), .B2(config_t_cs_max[11]), 
        .Z(n437) );
  OA21M1SA U76 ( .A1(n600), .A2(n637), .B(n619), .Z(n601) );
  MAOI22M1SA U77 ( .A1(cs_max[10]), .A2(n621), .B1(cs_max[10]), .B2(n621), .Z(
        n602) );
  MAOI22M1SA U78 ( .A1(en_cs), .A2(n602), .B1(en_cs), .B2(config_t_cs_max[10]), 
        .Z(n436) );
  INVM1S U79 ( .A(cs_max[12]), .Z(n603) );
  ND2M1S U80 ( .A(n606), .B(n603), .Z(n607) );
  OA21M1SA U81 ( .A1(n606), .A2(n603), .B(n607), .Z(n604) );
  MAOI22M1SA U82 ( .A1(en_cs), .A2(n604), .B1(en_cs), .B2(config_t_cs_max[12]), 
        .Z(n438) );
  INVM1S U83 ( .A(cs_max[4]), .Z(n613) );
  ND2M1S U84 ( .A(n618), .B(n613), .Z(n612) );
  AOI21B01M1S U85 ( .A1(cs_max[5]), .A2(n612), .NB(n615), .Z(n605) );
  MAOI22M1SA U86 ( .A1(en_cs), .A2(n605), .B1(en_cs), .B2(config_t_cs_max[5]), 
        .Z(n431) );
  NR2M1S U87 ( .A(cs_max[13]), .B(cs_max[12]), .Z(n636) );
  ND2M1S U88 ( .A(n636), .B(n606), .Z(n715) );
  AOI21B01M1S U89 ( .A1(cs_max[13]), .A2(n607), .NB(n715), .Z(n608) );
  MAOI22M1SA U90 ( .A1(en_cs), .A2(n608), .B1(en_cs), .B2(config_t_cs_max[13]), 
        .Z(n439) );
  MAOI22M1SA U91 ( .A1(cs_max[14]), .A2(n715), .B1(cs_max[14]), .B2(n715), .Z(
        n609) );
  MAOI22M1SA U92 ( .A1(en_cs), .A2(n609), .B1(en_cs), .B2(config_t_cs_max[14]), 
        .Z(n440) );
  INVM1S U93 ( .A(cs_max[8]), .Z(n610) );
  ND2M1S U94 ( .A(n616), .B(n610), .Z(n622) );
  OA21M1SA U95 ( .A1(n616), .A2(n610), .B(n622), .Z(n611) );
  MAOI22M1SA U96 ( .A1(en_cs), .A2(n611), .B1(en_cs), .B2(config_t_cs_max[8]), 
        .Z(n434) );
  OA21M1SA U97 ( .A1(n618), .A2(n613), .B(n612), .Z(n614) );
  MAOI22M1SA U98 ( .A1(en_cs), .A2(n614), .B1(en_cs), .B2(config_t_cs_max[4]), 
        .Z(n430) );
  OAI32M1S U99 ( .A1(n616), .A2(cs_max[6]), .A3(n615), .B1(cs_max[7]), .B2(
        n616), .Z(n617) );
  MAOI22M1SA U100 ( .A1(en_cs), .A2(n617), .B1(en_cs), .B2(config_t_cs_max[7]), 
        .Z(n433) );
  AOI21M1S U101 ( .A1(cs_max[3]), .A2(n619), .B(n618), .Z(n620) );
  MAOI22M1SA U102 ( .A1(en_cs), .A2(n620), .B1(en_cs), .B2(config_t_cs_max[3]), 
        .Z(n429) );
  AOI21B01M1S U103 ( .A1(cs_max[9]), .A2(n622), .NB(n621), .Z(n623) );
  MAOI22M1SA U104 ( .A1(en_cs), .A2(n623), .B1(en_cs), .B2(config_t_cs_max[9]), 
        .Z(n435) );
  NR2M1S U105 ( .A(wait_cnt[1]), .B(wait_cnt[0]), .Z(n730) );
  ND2M1S U106 ( .A(n730), .B(n815), .Z(n729) );
  NR2M1S U107 ( .A(wait_cnt[3]), .B(n729), .Z(n177) );
  INVM1S U108 ( .A(trans_burst_type_i), .Z(n2) );
  NR2B1M1S U109 ( .NA(hyper_trans_state[2]), .B(hyper_trans_state[3]), .Z(n754) );
  NR2B1M1S U110 ( .NA(hyper_trans_state[0]), .B(hyper_trans_state[1]), .Z(n773) );
  ND2M1S U111 ( .A(n754), .B(n773), .Z(n752) );
  INVM1S U112 ( .A(n752), .Z(n692) );
  ND2M1S U113 ( .A(n177), .B(n692), .Z(n704) );
  INVM1S U114 ( .A(hyper_trans_state[3]), .Z(n643) );
  AOI21M1S U115 ( .A1(n773), .A2(n697), .B(n767), .Z(n642) );
  ND2M1S U116 ( .A(n711), .B(n643), .Z(n766) );
  OAI211M2S U117 ( .A1(n182), .A2(n704), .B(n642), .C(n766), .Z(n683) );
  CKAN2M2S U118 ( .A(write_strb[1]), .B(n683), .Z(data_rwds_out[1]) );
  CKAN2M2S U119 ( .A(write_strb[0]), .B(n683), .Z(data_rwds_out[0]) );
  NR2M1S U120 ( .A(hyper_trans_state[0]), .B(n769), .Z(n778) );
  AO21M1SA U121 ( .A1(wait_cnt[3]), .A2(n729), .B(n177), .Z(n150) );
  INVM1S U122 ( .A(n177), .Z(n503) );
  ND2M1S U123 ( .A(local_write), .B(local_address_space), .Z(n181) );
  INVM1S U124 ( .A(n181), .Z(n131) );
  INVM1S U125 ( .A(hyper_rwds_i_syn), .Z(n146) );
  INVM1S U126 ( .A(cmd_addr_sel[1]), .Z(n645) );
  NR2M1S U127 ( .A(cmd_addr_sel[0]), .B(n645), .Z(n161) );
  INVM1S U128 ( .A(n161), .Z(n491) );
  INVM1S U129 ( .A(n174), .Z(read_fifo_rst) );
  NR2M1S U130 ( .A(burst_cnt[2]), .B(burst_cnt[1]), .Z(n625) );
  NR2M1S U131 ( .A(burst_cnt[4]), .B(burst_cnt[3]), .Z(n624) );
  ND2M1S U132 ( .A(n625), .B(n624), .Z(n629) );
  NR2M1S U133 ( .A(burst_cnt[6]), .B(burst_cnt[5]), .Z(n627) );
  NR2M1S U134 ( .A(burst_cnt[7]), .B(burst_cnt[8]), .Z(n626) );
  ND2M1S U135 ( .A(n627), .B(n626), .Z(n628) );
  NR2M1S U136 ( .A(n629), .B(n628), .Z(n813) );
  INVM1S U137 ( .A(burst_cnt[0]), .Z(n630) );
  ND2M1S U138 ( .A(n813), .B(n630), .Z(n545) );
  INVM1S U139 ( .A(n545), .Z(n179) );
  NR2M1S U140 ( .A(cs_max[14]), .B(cs_max[3]), .Z(n639) );
  NR2M1S U141 ( .A(cs_max[11]), .B(cs_max[10]), .Z(n634) );
  NR2M1S U142 ( .A(cs_max[7]), .B(cs_max[6]), .Z(n632) );
  ND4M1S U143 ( .A(n634), .B(n633), .C(n632), .D(n631), .Z(n635) );
  NR4B1M1S U144 ( .NA(n636), .B(cs_max[15]), .C(cs_max[1]), .D(n635), .Z(n638)
         );
  NR2M1S U145 ( .A(n717), .B(n640), .Z(n279) );
  NR2M1S U146 ( .A(n784), .B(n640), .Z(n267) );
  INVM1S U147 ( .A(hyper_trans_state[0]), .Z(n708) );
  NR2M1S U148 ( .A(n708), .B(n756), .Z(n700) );
  NR2M1S U149 ( .A(n662), .B(n640), .Z(n228) );
  INVM1S U150 ( .A(rx_error_o), .Z(n663) );
  NR2M1S U151 ( .A(n663), .B(n640), .Z(n282) );
  ND2M1S U152 ( .A(n651), .B(n779), .Z(n696) );
  INVM1S U153 ( .A(n778), .Z(n652) );
  INVM1S U154 ( .A(n773), .Z(n764) );
  ND2M1S U155 ( .A(n652), .B(n764), .Z(n762) );
  ND2M1S U156 ( .A(n779), .B(n762), .Z(n646) );
  OAI31M1S U157 ( .A1(hyper_trans_state[3]), .A2(n652), .A3(n545), .B(
        hyper_trans_state[2]), .Z(n641) );
  OAI211M1S U158 ( .A1(n177), .A2(n696), .B(n646), .C(n641), .Z(n175) );
  NR4M1S U159 ( .A(wait_cnt[2]), .B(wait_cnt[3]), .C(wait_cnt[1]), .D(n182), 
        .Z(n644) );
  OAI21B20M1S U160 ( .NA1(n692), .NA2(n644), .B(n642), .Z(hyper_rwds_oe_n) );
  INVM1S U161 ( .A(n697), .Z(n755) );
  OAI211M1S U162 ( .A1(n778), .A2(n644), .B(n762), .C(n643), .Z(n678) );
  OAI211M1S U163 ( .A1(n764), .A2(n755), .B(n696), .C(n678), .Z(n139) );
  OAI211M1S U164 ( .A1(local_write), .A2(n752), .B(n662), .C(n784), .Z(
        read_clk_en_n) );
  NR2M1S U165 ( .A(cmd_addr_sel[0]), .B(n646), .Z(n322) );
  ND2M1S U166 ( .A(cmd_addr_sel[0]), .B(n645), .Z(n664) );
  AOI21M1S U167 ( .A1(n491), .A2(n664), .B(n646), .Z(n323) );
  ND2B1M1S U168 ( .NA(hyper_trans_state[0]), .B(n697), .Z(n701) );
  ND2M1S U169 ( .A(n756), .B(n701), .Z(n693) );
  NR2B1M1S U170 ( .NA(local_burst[0]), .B(n752), .Z(n647) );
  AOI21M1S U171 ( .A1(n693), .A2(burst_cnt[0]), .B(n647), .Z(n818) );
  NR2B1M1S U172 ( .NA(local_burst[1]), .B(n752), .Z(n648) );
  AOI21M1S U173 ( .A1(n693), .A2(burst_cnt[1]), .B(n648), .Z(n649) );
  ND2M1S U174 ( .A(n818), .B(n649), .Z(n655) );
  OAI21M1S U175 ( .A1(n649), .A2(n818), .B(n655), .Z(n331) );
  NR2M1S U176 ( .A(write_valid), .B(n182), .Z(n698) );
  INVM1S U177 ( .A(n756), .Z(n760) );
  AOI31M1S U178 ( .A1(n754), .A2(n698), .A3(n651), .B(n760), .Z(n650) );
  ND3M1S U179 ( .A(n650), .B(n717), .C(n766), .Z(n129) );
  INVM1S U180 ( .A(n754), .Z(n713) );
  OA32M1SA U181 ( .A1(n713), .A2(hyper_trans_state[1]), .A3(n698), .B1(n755), 
        .B2(hyper_trans_state[1]), .Z(n653) );
  NR2M1S U182 ( .A(n651), .B(n713), .Z(n741) );
  INVM1S U183 ( .A(n741), .Z(n724) );
  INVM1S U184 ( .A(n753), .Z(n709) );
  ND2M1S U185 ( .A(n771), .B(n709), .Z(n735) );
  AOI31M1S U186 ( .A1(n653), .A2(n724), .A3(n735), .B(n180), .Z(n342) );
  NR2B1M1S U187 ( .NA(local_burst[2]), .B(n752), .Z(n654) );
  AOI21M1S U188 ( .A1(n693), .A2(burst_cnt[2]), .B(n654), .Z(n658) );
  INVM1S U189 ( .A(n655), .Z(n657) );
  NR2B1M1S U190 ( .NA(n658), .B(n655), .Z(n660) );
  INVM1S U191 ( .A(n660), .Z(n656) );
  NR2B1M1S U192 ( .NA(local_burst[3]), .B(n752), .Z(n659) );
  AOI21M1S U193 ( .A1(n693), .A2(burst_cnt[3]), .B(n659), .Z(n661) );
  ND2M1S U194 ( .A(n660), .B(n661), .Z(n673) );
  OAI21M1S U195 ( .A1(n661), .A2(n660), .B(n673), .Z(n333) );
  AOI21M1S U196 ( .A1(n663), .A2(n662), .B(n545), .Z(rx_last_o) );
  NR2M1S U197 ( .A(n683), .B(n664), .Z(n682) );
  AOI22M1S U198 ( .A1(cmd_addr[16]), .A2(n682), .B1(write_data[0]), .B2(n683), 
        .Z(n666) );
  NR3M2S U199 ( .A(cmd_addr_sel[0]), .B(cmd_addr_sel[1]), .C(n683), .Z(n684)
         );
  AOI22M1S U200 ( .A1(n669), .A2(cmd_addr[0]), .B1(n684), .B2(cmd_addr[32]), 
        .Z(n665) );
  ND2M1S U201 ( .A(n666), .B(n665), .Z(data_out[0]) );
  AOI22M1S U202 ( .A1(cmd_addr[17]), .A2(n682), .B1(write_data[1]), .B2(n683), 
        .Z(n668) );
  AOI22M1S U203 ( .A1(n669), .A2(cmd_addr[1]), .B1(n684), .B2(cmd_addr[33]), 
        .Z(n667) );
  ND2M1S U204 ( .A(n668), .B(n667), .Z(data_out[1]) );
  AOI22M1S U205 ( .A1(cmd_addr[18]), .A2(n682), .B1(write_data[2]), .B2(n683), 
        .Z(n671) );
  AOI22M1S U206 ( .A1(n669), .A2(cmd_addr[2]), .B1(n684), .B2(cmd_addr[34]), 
        .Z(n670) );
  ND2M1S U207 ( .A(n671), .B(n670), .Z(data_out[2]) );
  AOI21M1S U208 ( .A1(n693), .A2(burst_cnt[4]), .B(n672), .Z(n676) );
  INVM1S U209 ( .A(n673), .Z(n675) );
  NR2B1M1S U210 ( .NA(n676), .B(n673), .Z(n680) );
  INVM1S U211 ( .A(n680), .Z(n674) );
  OAI21M1S U212 ( .A1(n676), .A2(n675), .B(n674), .Z(n334) );
  INVM1S U213 ( .A(hyper_trans_state[2]), .Z(n790) );
  ND2M1S U214 ( .A(n697), .B(n762), .Z(n677) );
  NR2B1M1S U215 ( .NA(local_burst[5]), .B(n752), .Z(n679) );
  ND2M1S U216 ( .A(n680), .B(n681), .Z(n686) );
  OAI21M1S U217 ( .A1(n681), .A2(n680), .B(n686), .Z(n335) );
  AO222M1SA U218 ( .A1(n683), .A2(write_data[9]), .B1(n682), .B2(cmd_addr[25]), 
        .C1(cmd_addr[41]), .C2(n684), .Z(data_out[9]) );
  AO222M1SA U219 ( .A1(n683), .A2(write_data[13]), .B1(n682), .B2(cmd_addr[29]), .C1(cmd_addr[45]), .C2(n684), .Z(data_out[13]) );
  AO222M1SA U221 ( .A1(n683), .A2(write_data[7]), .B1(n682), .B2(cmd_addr[23]), 
        .C1(cmd_addr[39]), .C2(n684), .Z(data_out[7]) );
  AO222M1SA U222 ( .A1(n683), .A2(write_data[4]), .B1(n682), .B2(cmd_addr[20]), 
        .C1(cmd_addr[36]), .C2(n684), .Z(data_out[4]) );
  AO222M1SA U223 ( .A1(n683), .A2(write_data[3]), .B1(n682), .B2(cmd_addr[19]), 
        .C1(cmd_addr[35]), .C2(n684), .Z(data_out[3]) );
  AO222M1SA U225 ( .A1(n683), .A2(write_data[12]), .B1(n682), .B2(cmd_addr[28]), .C1(cmd_addr[44]), .C2(n684), .Z(data_out[12]) );
  AO222M1SA U226 ( .A1(n683), .A2(write_data[14]), .B1(n682), .B2(cmd_addr[30]), .C1(local_address_space), .C2(n684), .Z(data_out[14]) );
  AO222M1SA U227 ( .A1(n683), .A2(write_data[11]), .B1(n682), .B2(cmd_addr[27]), .C1(cmd_addr[43]), .C2(n684), .Z(data_out[11]) );
  AO222M1SA U229 ( .A1(n683), .A2(write_data[6]), .B1(n682), .B2(cmd_addr[22]), 
        .C1(cmd_addr[38]), .C2(n684), .Z(data_out[6]) );
  AO222M1SA U230 ( .A1(n683), .A2(write_data[10]), .B1(n682), .B2(cmd_addr[26]), .C1(cmd_addr[42]), .C2(n684), .Z(data_out[10]) );
  AO222M1SA U231 ( .A1(n182), .A2(n684), .B1(n683), .B2(write_data[15]), .C1(
        n682), .C2(cmd_addr[31]), .Z(data_out[15]) );
  NR2B1M1S U238 ( .NA(local_burst[6]), .B(n752), .Z(n685) );
  AOI21M1S U239 ( .A1(n693), .A2(burst_cnt[6]), .B(n685), .Z(n689) );
  INVM1S U240 ( .A(n686), .Z(n688) );
  NR2B1M1S U243 ( .NA(n689), .B(n686), .Z(n690) );
  INVM1S U244 ( .A(n690), .Z(n687) );
  OAI21M1S U245 ( .A1(n689), .A2(n688), .B(n687), .Z(n336) );
  AOI22M1S U247 ( .A1(n693), .A2(burst_cnt[7]), .B1(n692), .B2(local_burst[7]), 
        .Z(n691) );
  ND2M1S U248 ( .A(n690), .B(n691), .Z(n695) );
  OAI21M1S U249 ( .A1(n691), .A2(n690), .B(n695), .Z(n337) );
  AOI22M1S U250 ( .A1(n693), .A2(burst_cnt[8]), .B1(n692), .B2(local_burst[8]), 
        .Z(n694) );
  XOR2M1SA U251 ( .A(n695), .B(n694), .Z(n338) );
  MAOI22M1SA U252 ( .A1(n697), .A2(n769), .B1(n696), .B2(n709), .Z(n703) );
  OAI22M1S U253 ( .A1(n698), .A2(n752), .B1(n708), .B2(n763), .Z(n699) );
  AOI211M1S U254 ( .A1(n_cse_25), .A2(n700), .B(n180), .C(n699), .Z(n702) );
  ND2M1S U255 ( .A(n179), .B(n767), .Z(n765) );
  ND4M1S U256 ( .A(n703), .B(n702), .C(n701), .D(n765), .Z(n341) );
  AOI31M1S U257 ( .A1(rx_valid_o), .A2(n760), .A3(n545), .B(rx_error_o), .Z(
        n706) );
  AOI21B10M1S U258 ( .NA2(n784), .A1(n_cse_25), .B(n767), .Z(n705) );
  OAI211M1S U259 ( .A1(n706), .A2(n785), .B(n705), .C(n704), .Z(n141) );
  ND2M1S U260 ( .A(n179), .B(rx_valid_o), .Z(n775) );
  AOI21M1S U261 ( .A1(n265), .A2(n708), .B(n707), .Z(n714) );
  INVM1S U263 ( .A(tx_valid_i), .Z(n781) );
  AOI22M1S U264 ( .A1(n297), .A2(rx_error_o), .B1(b_error_o), .B2(n781), .Z(
        n789) );
  AOI211M1S U265 ( .A1(n709), .A2(n770), .B(n763), .C(n769), .Z(n710) );
  INVM1S U266 ( .A(n766), .Z(n744) );
  AOI211M1S U267 ( .A1(n711), .A2(n503), .B(n710), .C(n744), .Z(n712) );
  OAI211M1S U268 ( .A1(n714), .A2(n713), .B(n789), .C(n712), .Z(n140) );
  NR2M1S U269 ( .A(cs_max[14]), .B(n715), .Z(n716) );
  MAOI22M1SA U270 ( .A1(en_cs), .A2(cs_max[0]), .B1(en_cs), .B2(
        config_t_cs_max[0]), .Z(n426) );
  INVM1S U271 ( .A(n717), .Z(n742) );
  AO211M1SA U272 ( .A1(n742), .A2(n345), .B(n760), .C(rx_error_o), .Z(n739) );
  INVM1S U273 ( .A(config_t_read_write_recovery[1]), .Z(n728) );
  NR2M1S U274 ( .A(config_t_read_write_recovery[0]), .B(
        config_t_read_write_recovery[1]), .Z(n748) );
  AOI32M1S U275 ( .A1(config_t_read_write_recovery[1]), .A2(n744), .A3(
        config_t_read_write_recovery[0]), .B1(n748), .B2(n744), .Z(n719) );
  AOI32M1S U276 ( .A1(config_t_latency_additional[1]), .A2(n741), .A3(
        config_t_latency_additional[0]), .B1(n750), .B2(n741), .Z(n718) );
  AOI21M1S U277 ( .A1(n719), .A2(n718), .B(n503), .Z(n723) );
  ND2M1S U278 ( .A(n752), .B(n720), .Z(n743) );
  OAI32M1S U279 ( .A1(n743), .A2(n744), .A3(n741), .B1(n503), .B2(n743), .Z(
        n731) );
  AOI21M1S U280 ( .A1(wait_cnt[0]), .A2(wait_cnt[1]), .B(n730), .Z(n721) );
  OAI22M1S U281 ( .A1(config_t_latency_access[1]), .A2(n735), .B1(n731), .B2(
        n721), .Z(n722) );
  AOI211M1S U282 ( .A1(n739), .A2(n728), .B(n723), .C(n722), .Z(n3) );
  OAI21M1S U283 ( .A1(n753), .A2(config_t_latency_access[0]), .B(n771), .Z(
        n727) );
  OAI22M1S U284 ( .A1(config_t_read_write_recovery[0]), .A2(n766), .B1(
        config_t_latency_additional[0]), .B2(n724), .Z(n725) );
  AOI22M1S U285 ( .A1(n177), .A2(n725), .B1(config_t_read_write_recovery[0]), 
        .B2(n739), .Z(n726) );
  OAI211M1S U286 ( .A1(wait_cnt[0]), .A2(n731), .B(n727), .C(n726), .Z(n160)
         );
  MAOI22M1SA U287 ( .A1(config_t_read_write_recovery[2]), .A2(n728), .B1(n728), 
        .B2(config_t_read_write_recovery[2]), .Z(n738) );
  OAI32M1S U288 ( .A1(n731), .A2(n730), .A3(n815), .B1(n729), .B2(n731), .Z(
        n737) );
  NR2M1S U289 ( .A(config_t_latency_access[1]), .B(config_t_latency_access[2]), 
        .Z(n797) );
  AOI21M1S U290 ( .A1(config_t_latency_access[2]), .A2(
        config_t_latency_access[1]), .B(n797), .Z(n794) );
  MAOI22M1SA U291 ( .A1(n748), .A2(config_t_read_write_recovery[2]), .B1(n748), 
        .B2(config_t_read_write_recovery[2]), .Z(n733) );
  MAOI22M1SA U292 ( .A1(n750), .A2(config_t_latency_additional[2]), .B1(n750), 
        .B2(config_t_latency_additional[2]), .Z(n732) );
  AOI22M1S U293 ( .A1(n744), .A2(n733), .B1(n741), .B2(n732), .Z(n734) );
  OAI22M1S U294 ( .A1(n794), .A2(n735), .B1(n734), .B2(n503), .Z(n736) );
  AOI211M1S U295 ( .A1(n739), .A2(n738), .B(n737), .C(n736), .Z(n1) );
  MAOI22M1SA U296 ( .A1(n740), .A2(config_t_read_write_recovery[3]), .B1(n740), 
        .B2(config_t_read_write_recovery[3]), .Z(n235) );
  AOI22M1S U297 ( .A1(n771), .A2(n145), .B1(n741), .B2(n171), .Z(n747) );
  AOI22M1S U298 ( .A1(n742), .A2(n307), .B1(n760), .B2(n235), .Z(n746) );
  AOI22M1S U299 ( .A1(n744), .A2(n158), .B1(n743), .B2(n150), .Z(n745) );
  ND3M1S U300 ( .A(n747), .B(n746), .C(n745), .Z(n147) );
  NR2B1M1S U301 ( .NA(n748), .B(config_t_read_write_recovery[2]), .Z(n749) );
  MAOI22M1SA U302 ( .A1(n749), .A2(config_t_read_write_recovery[3]), .B1(n749), 
        .B2(config_t_read_write_recovery[3]), .Z(n154) );
  MAOI22M1SA U303 ( .A1(n751), .A2(config_t_latency_additional[3]), .B1(n751), 
        .B2(config_t_latency_additional[3]), .Z(n167) );
  AOI21M1S U304 ( .A1(local_write), .A2(write_valid), .B(n752), .Z(n759) );
  AOI22M1S U305 ( .A1(n208), .A2(n754), .B1(n753), .B2(n790), .Z(n757) );
  AOI31M1S U306 ( .A1(n757), .A2(n756), .A3(n755), .B(hyper_trans_state[0]), 
        .Z(n758) );
  AOI211M1S U307 ( .A1(n760), .A2(n_cse_25), .B(n759), .C(n758), .Z(n761) );
  ND2M1S U308 ( .A(n766), .B(n765), .Z(b_last_o) );
  OR2M1S U309 ( .A(b_error_o), .B(b_last_o), .Z(b_valid_o) );
  AOI22M1S U310 ( .A1(n177), .A2(n773), .B1(n772), .B2(n207), .Z(n776) );
  AOI32M1S U311 ( .A1(rx_ready_i), .A2(n776), .A3(n775), .B1(n774), .B2(n776), 
        .Z(n777) );
  OAI21M1S U312 ( .A1(n779), .A2(read_fifo_rst), .B(n177), .Z(n780) );
  INVM1S U313 ( .A(n797), .Z(n792) );
  INVM1S U314 ( .A(config_t_latency_access[3]), .Z(n796) );
  AOI22M1S U315 ( .A1(n797), .A2(config_t_latency_access[3]), .B1(n792), .B2(
        n796), .Z(n127) );
  AOI21M1S U316 ( .A1(n792), .A2(config_t_latency_access[3]), .B(
        config_t_latency_access[4]), .Z(n812) );
  INVM1S U317 ( .A(wait_cnt[3]), .Z(n811) );
  MAOI22M1SA U318 ( .A1(wait_cnt[1]), .A2(config_t_latency_access[1]), .B1(
        wait_cnt[1]), .B2(config_t_latency_access[1]), .Z(n809) );
  NR4M1S U319 ( .A(config_t_latency_access[13]), .B(
        config_t_latency_access[16]), .C(config_t_latency_access[14]), .D(
        config_t_latency_access[15]), .Z(n808) );
  INVM1S U320 ( .A(wait_cnt[0]), .Z(n795) );
  OAI22M1S U321 ( .A1(n795), .A2(config_t_latency_access[0]), .B1(wait_cnt[2]), 
        .B2(n794), .Z(n793) );
  AOI221M1S U322 ( .A1(n795), .A2(config_t_latency_access[0]), .B1(n794), .B2(
        wait_cnt[2]), .C(n793), .Z(n807) );
  ND2M1S U323 ( .A(n797), .B(n796), .Z(n805) );
  OR4M1S U324 ( .A(config_t_latency_access[19]), .B(
        config_t_latency_access[21]), .C(config_t_latency_access[22]), .D(
        config_t_latency_access[23]), .Z(n798) );
  OR4M1S U325 ( .A(config_t_latency_access[20]), .B(
        config_t_latency_access[18]), .C(config_t_latency_access[17]), .D(n798), .Z(n804) );
  NR4M1S U326 ( .A(config_t_latency_access[24]), .B(
        config_t_latency_access[25]), .C(config_t_latency_access[26]), .D(
        config_t_latency_access[27]), .Z(n802) );
  NR4M1S U327 ( .A(config_t_latency_access[28]), .B(
        config_t_latency_access[29]), .C(config_t_latency_access[30]), .D(
        config_t_latency_access[31]), .Z(n801) );
  NR4M1S U328 ( .A(config_t_latency_access[6]), .B(config_t_latency_access[7]), 
        .C(config_t_latency_access[5]), .D(config_t_latency_access[8]), .Z(
        n800) );
  NR4M1S U329 ( .A(config_t_latency_access[9]), .B(config_t_latency_access[10]), .C(config_t_latency_access[11]), .D(config_t_latency_access[12]), .Z(n799)
         );
  ND4M1S U330 ( .A(n802), .B(n801), .C(n800), .D(n799), .Z(n803) );
  AOI211M1S U331 ( .A1(config_t_latency_access[4]), .A2(n805), .B(n804), .C(
        n803), .Z(n806) );
  ND4M1S U332 ( .A(n809), .B(n808), .C(n807), .D(n806), .Z(n810) );
  AOI221M1S U333 ( .A1(n812), .A2(wait_cnt[3]), .B1(n127), .B2(n811), .C(n810), 
        .Z(n204) );
  ND2M1S U334 ( .A(n813), .B(burst_cnt[0]), .Z(n527) );
endmodule


module cdc_2phase_src_645242 ( rst_ni, clk_i, data_i, valid_i, ready_o, 
        async_req_o, async_ack_i, async_data_o );
  input [45:0] data_i;
  output [45:0] async_data_o;
  input rst_ni, clk_i, valid_i, async_ack_i;
  output ready_o, async_req_o;
  wire   n0, n2, n3, ack_src_q, ack_q;

  DFEQRM1SA data_src_q_reg_cs__1_ ( .D(data_i[45]), .E(n2), .CK(clk_i), .RB(
        rst_ni), .Q(async_data_o[45]) );
  DFEQRM1SA data_src_q_reg_address__30_ ( .D(data_i[30]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[30]) );
  DFEQRM1SA data_src_q_reg_address__15_ ( .D(data_i[15]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[15]) );
  DFEQRM1SA data_src_q_reg_address__0_ ( .D(data_i[0]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[0]) );
  DFEQRM1SA req_src_q_reg ( .D(n3), .E(n2), .CK(clk_i), .RB(rst_ni), .Q(
        async_req_o) );
  DFEQRM1SA data_src_q_reg_cs__0_ ( .D(data_i[44]), .E(n2), .CK(clk_i), .RB(
        rst_ni), .Q(async_data_o[44]) );
  DFEQRM1SA data_src_q_reg_write_ ( .D(data_i[43]), .E(n2), .CK(clk_i), .RB(
        rst_ni), .Q(async_data_o[43]) );
  DFEQRM1SA data_src_q_reg_burst__8_ ( .D(data_i[42]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[42]) );
  DFEQRM1SA data_src_q_reg_burst__7_ ( .D(data_i[41]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[41]) );
  DFEQRM1SA data_src_q_reg_burst__6_ ( .D(data_i[40]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[40]) );
  DFEQRM1SA data_src_q_reg_burst__5_ ( .D(data_i[39]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[39]) );
  DFEQRM1SA data_src_q_reg_burst__4_ ( .D(data_i[38]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[38]) );
  DFEQRM1SA data_src_q_reg_burst__3_ ( .D(data_i[37]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[37]) );
  DFEQRM1SA data_src_q_reg_burst__2_ ( .D(data_i[36]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[36]) );
  DFEQRM1SA data_src_q_reg_burst__1_ ( .D(data_i[35]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[35]) );
  DFEQRM1SA data_src_q_reg_burst__0_ ( .D(data_i[34]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[34]) );
  DFEQRM1SA data_src_q_reg_burst_type_ ( .D(data_i[33]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[33]) );
  DFEQRM1SA data_src_q_reg_address_space_ ( .D(data_i[32]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[32]) );
  DFEQRM1SA data_src_q_reg_address__31_ ( .D(data_i[31]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[31]) );
  DFEQRM1SA data_src_q_reg_address__29_ ( .D(data_i[29]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[29]) );
  DFEQRM1SA data_src_q_reg_address__28_ ( .D(data_i[28]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[28]) );
  DFEQRM1SA data_src_q_reg_address__27_ ( .D(data_i[27]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[27]) );
  DFEQRM1SA data_src_q_reg_address__26_ ( .D(data_i[26]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[26]) );
  DFEQRM1SA data_src_q_reg_address__25_ ( .D(data_i[25]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[25]) );
  DFEQRM1SA data_src_q_reg_address__24_ ( .D(data_i[24]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[24]) );
  DFEQRM1SA data_src_q_reg_address__23_ ( .D(data_i[23]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[23]) );
  DFEQRM1SA data_src_q_reg_address__22_ ( .D(data_i[22]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[22]) );
  DFEQRM1SA data_src_q_reg_address__21_ ( .D(data_i[21]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[21]) );
  DFEQRM1SA data_src_q_reg_address__20_ ( .D(data_i[20]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[20]) );
  DFEQRM1SA data_src_q_reg_address__19_ ( .D(data_i[19]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[19]) );
  DFEQRM1SA data_src_q_reg_address__18_ ( .D(data_i[18]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[18]) );
  DFEQRM1SA data_src_q_reg_address__17_ ( .D(data_i[17]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[17]) );
  DFEQRM1SA data_src_q_reg_address__16_ ( .D(data_i[16]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[16]) );
  DFEQRM1SA data_src_q_reg_address__14_ ( .D(data_i[14]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[14]) );
  DFEQRM1SA data_src_q_reg_address__13_ ( .D(data_i[13]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[13]) );
  DFEQRM1SA data_src_q_reg_address__12_ ( .D(data_i[12]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[12]) );
  DFEQRM1SA data_src_q_reg_address__11_ ( .D(data_i[11]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[11]) );
  DFEQRM1SA data_src_q_reg_address__10_ ( .D(data_i[10]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[10]) );
  DFEQRM1SA data_src_q_reg_address__9_ ( .D(data_i[9]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[9]) );
  DFEQRM1SA data_src_q_reg_address__8_ ( .D(data_i[8]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[8]) );
  DFEQRM1SA data_src_q_reg_address__7_ ( .D(data_i[7]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[7]) );
  DFEQRM1SA data_src_q_reg_address__6_ ( .D(data_i[6]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[6]) );
  DFEQRM1SA data_src_q_reg_address__5_ ( .D(data_i[5]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[5]) );
  DFEQRM1SA data_src_q_reg_address__4_ ( .D(data_i[4]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[4]) );
  DFEQRM1SA data_src_q_reg_address__3_ ( .D(data_i[3]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[3]) );
  DFEQRM1SA data_src_q_reg_address__2_ ( .D(data_i[2]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[2]) );
  DFEQRM1SA data_src_q_reg_address__1_ ( .D(data_i[1]), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o[1]) );
  INVM1S I_2 ( .A(async_req_o), .Z(n3) );
  INVM1S I_0 ( .A(n0), .Z(ready_o) );
  DFQRM1SA ack_q_reg ( .D(ack_src_q), .CK(clk_i), .RB(rst_ni), .Q(ack_q) );
  DFQRM1SA ack_src_q_reg ( .D(async_ack_i), .CK(clk_i), .RB(rst_ni), .Q(
        ack_src_q) );
  XOR2M2WA C213 ( .A(async_req_o), .B(ack_q), .Z(n0) );
  CKAN2M8RA C218 ( .A(valid_i), .B(ready_o), .Z(n2) );
endmodule


module cdc_2phase_dst_645242 ( rst_ni, clk_i, data_o, valid_o, ready_i, 
        async_req_i, async_ack_o, async_data_i );
  output [45:0] data_o;
  input [45:0] async_data_i;
  input rst_ni, clk_i, ready_i, async_req_i;
  output valid_o, async_ack_o;
  wire   n1, n2, req_q0, req_q1, n3, n4, req_dst_q, n5;

  DFEQRM1SA data_dst_q_reg_burst__2_ ( .D(async_data_i[36]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[36]) );
  DFEQRM1SA data_dst_q_reg_address__21_ ( .D(async_data_i[21]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[21]) );
  DFEQRM1SA data_dst_q_reg_address__6_ ( .D(async_data_i[6]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[6]) );
  DFEQRM1SA ack_dst_q_reg ( .D(n2), .E(n1), .CK(clk_i), .RB(rst_ni), .Q(
        async_ack_o) );
  DFEQRM1SA data_dst_q_reg_address__0_ ( .D(async_data_i[0]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[0]) );
  DFEQRM1SA data_dst_q_reg_cs__1_ ( .D(async_data_i[45]), .E(n4), .CK(clk_i), 
        .RB(rst_ni), .Q(data_o[45]) );
  DFEQRM1SA data_dst_q_reg_cs__0_ ( .D(async_data_i[44]), .E(n4), .CK(clk_i), 
        .RB(rst_ni), .Q(data_o[44]) );
  DFEQRM1SA data_dst_q_reg_write_ ( .D(async_data_i[43]), .E(n4), .CK(clk_i), 
        .RB(rst_ni), .Q(data_o[43]) );
  DFEQRM1SA data_dst_q_reg_burst__8_ ( .D(async_data_i[42]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[42]) );
  DFEQRM1SA data_dst_q_reg_burst__7_ ( .D(async_data_i[41]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[41]) );
  DFEQRM1SA data_dst_q_reg_burst__6_ ( .D(async_data_i[40]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[40]) );
  DFEQRM1SA data_dst_q_reg_burst__5_ ( .D(async_data_i[39]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[39]) );
  DFEQRM1SA data_dst_q_reg_burst__4_ ( .D(async_data_i[38]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[38]) );
  DFEQRM1SA data_dst_q_reg_burst__3_ ( .D(async_data_i[37]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[37]) );
  DFEQRM1SA data_dst_q_reg_burst__1_ ( .D(async_data_i[35]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[35]) );
  DFEQRM1SA data_dst_q_reg_burst__0_ ( .D(async_data_i[34]), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o[34]) );
  DFEQRM1SA data_dst_q_reg_burst_type_ ( .D(async_data_i[33]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[33]) );
  DFEQRM1SA data_dst_q_reg_address_space_ ( .D(async_data_i[32]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[32]) );
  DFEQRM1SA data_dst_q_reg_address__31_ ( .D(async_data_i[31]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[31]) );
  DFEQRM1SA data_dst_q_reg_address__30_ ( .D(async_data_i[30]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[30]) );
  DFEQRM1SA data_dst_q_reg_address__29_ ( .D(async_data_i[29]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[29]) );
  DFEQRM1SA data_dst_q_reg_address__28_ ( .D(async_data_i[28]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[28]) );
  DFEQRM1SA data_dst_q_reg_address__27_ ( .D(async_data_i[27]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[27]) );
  DFEQRM1SA data_dst_q_reg_address__26_ ( .D(async_data_i[26]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[26]) );
  DFEQRM1SA data_dst_q_reg_address__25_ ( .D(async_data_i[25]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[25]) );
  DFEQRM1SA data_dst_q_reg_address__24_ ( .D(async_data_i[24]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[24]) );
  DFEQRM1SA data_dst_q_reg_address__23_ ( .D(async_data_i[23]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[23]) );
  DFEQRM1SA data_dst_q_reg_address__22_ ( .D(async_data_i[22]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[22]) );
  DFEQRM1SA data_dst_q_reg_address__20_ ( .D(async_data_i[20]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[20]) );
  DFEQRM1SA data_dst_q_reg_address__19_ ( .D(async_data_i[19]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[19]) );
  DFEQRM1SA data_dst_q_reg_address__18_ ( .D(async_data_i[18]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[18]) );
  DFEQRM1SA data_dst_q_reg_address__17_ ( .D(async_data_i[17]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[17]) );
  DFEQRM1SA data_dst_q_reg_address__16_ ( .D(async_data_i[16]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[16]) );
  DFEQRM1SA data_dst_q_reg_address__15_ ( .D(async_data_i[15]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[15]) );
  DFEQRM1SA data_dst_q_reg_address__14_ ( .D(async_data_i[14]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[14]) );
  DFEQRM1SA data_dst_q_reg_address__13_ ( .D(async_data_i[13]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[13]) );
  DFEQRM1SA data_dst_q_reg_address__12_ ( .D(async_data_i[12]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[12]) );
  DFEQRM1SA data_dst_q_reg_address__11_ ( .D(async_data_i[11]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[11]) );
  DFEQRM1SA data_dst_q_reg_address__10_ ( .D(async_data_i[10]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[10]) );
  DFEQRM1SA data_dst_q_reg_address__9_ ( .D(async_data_i[9]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[9]) );
  DFEQRM1SA data_dst_q_reg_address__8_ ( .D(async_data_i[8]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[8]) );
  DFEQRM1SA data_dst_q_reg_address__7_ ( .D(async_data_i[7]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[7]) );
  DFEQRM1SA data_dst_q_reg_address__5_ ( .D(async_data_i[5]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[5]) );
  DFEQRM1SA data_dst_q_reg_address__4_ ( .D(async_data_i[4]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[4]) );
  DFEQRM1SA data_dst_q_reg_address__3_ ( .D(async_data_i[3]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[3]) );
  DFEQRM1SA data_dst_q_reg_address__2_ ( .D(async_data_i[2]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[2]) );
  DFEQRM1SA data_dst_q_reg_address__1_ ( .D(async_data_i[1]), .E(n4), .CK(
        clk_i), .RB(rst_ni), .Q(data_o[1]) );
  INVM1S I_1 ( .A(async_ack_o), .Z(n2) );
  INVM1S I_2 ( .A(valid_o), .Z(n5) );
  DFQRM1SA req_q1_reg ( .D(req_q0), .CK(clk_i), .RB(rst_ni), .Q(req_q1) );
  DFQRM1SA req_q0_reg ( .D(req_dst_q), .CK(clk_i), .RB(rst_ni), .Q(req_q0) );
  DFQRM1SA req_dst_q_reg ( .D(async_req_i), .CK(clk_i), .RB(rst_ni), .Q(
        req_dst_q) );
  AN2M1R C232 ( .A(valid_o), .B(ready_i), .Z(n1) );
  XOR2M2RA C227 ( .A(async_ack_o), .B(req_q1), .Z(valid_o) );
  CKAN2M8RA C235 ( .A(n3), .B(n5), .Z(n4) );
  MAOI22M1SA U3 ( .A1(req_q1), .A2(req_q0), .B1(req_q1), .B2(req_q0), .Z(n3)
         );
endmodule


module cdc_2phase_645242 ( src_rst_ni, src_clk_i, src_data_i, src_valid_i, 
        src_ready_o, dst_rst_ni, dst_clk_i, dst_data_o, dst_valid_o, 
        dst_ready_i );
  input [45:0] src_data_i;
  output [45:0] dst_data_o;
  input src_rst_ni, src_clk_i, src_valid_i, dst_rst_ni, dst_clk_i, dst_ready_i;
  output src_ready_o, dst_valid_o;
  wire   async_req, async_ack;
  wire   [45:0] async_data;

  cdc_2phase_src_645242 i_src ( .rst_ni(src_rst_ni), .clk_i(src_clk_i), 
        .data_i(src_data_i), .valid_i(src_valid_i), .ready_o(src_ready_o), 
        .async_req_o(async_req), .async_ack_i(async_ack), .async_data_o(
        async_data) );
  cdc_2phase_dst_645242 i_dst ( .rst_ni(dst_rst_ni), .clk_i(dst_clk_i), 
        .data_o(dst_data_o), .valid_o(dst_valid_o), .ready_i(dst_ready_i), 
        .async_req_i(async_req), .async_ack_o(async_ack), .async_data_i(
        async_data) );
endmodule


module cdc_2phase_src_121242 ( rst_ni, clk_i, valid_i, ready_o, async_req_o, 
        async_ack_i, data_i_last_, data_i_error_, async_data_o_last_, 
        async_data_o_error_ );
  input rst_ni, clk_i, valid_i, async_ack_i, data_i_last_, data_i_error_;
  output ready_o, async_req_o, async_data_o_last_, async_data_o_error_;
  wire   n0, n4, n2, n3, ack_src_q, ack_q;

  DFEQRM1SA req_src_q_reg ( .D(n3), .E(n2), .CK(clk_i), .RB(rst_ni), .Q(
        async_req_o) );
  DFEQRM1SA data_src_q_reg_last_ ( .D(data_i_last_), .E(n2), .CK(clk_i), .RB(
        rst_ni), .Q(async_data_o_last_) );
  DFEQRM1SA data_src_q_reg_error_ ( .D(data_i_error_), .E(n2), .CK(clk_i), 
        .RB(rst_ni), .Q(async_data_o_error_) );
  INVM1S I_2 ( .A(async_req_o), .Z(n3) );
  DFQRM1SA ack_q_reg ( .D(ack_src_q), .CK(clk_i), .RB(rst_ni), .Q(ack_q) );
  DFQRM1SA ack_src_q_reg ( .D(async_ack_i), .CK(clk_i), .RB(rst_ni), .Q(
        ack_src_q) );
  INVM2R I_0 ( .A(n0), .Z(n4) );
  CKAN2M2S C42 ( .A(valid_i), .B(n4), .Z(n2) );
  XOR2M2SA C37 ( .A(async_req_o), .B(ack_q), .Z(n0) );
endmodule


module cdc_2phase_dst_121242 ( rst_ni, clk_i, valid_o, ready_i, async_req_i, 
        async_ack_o, data_o_last_, data_o_error_, async_data_i_last_, 
        async_data_i_error_ );
  input rst_ni, clk_i, ready_i, async_req_i, async_data_i_last_,
         async_data_i_error_;
  output valid_o, async_ack_o, data_o_last_, data_o_error_;
  wire   n1, n2, req_q0, req_q1, n3, n4, req_dst_q, n5;

  DFEQRM1SA data_dst_q_reg_last_ ( .D(async_data_i_last_), .E(n4), .CK(clk_i), 
        .RB(rst_ni), .Q(data_o_last_) );
  DFEQRM1SA data_dst_q_reg_error_ ( .D(async_data_i_error_), .E(n4), .CK(clk_i), .RB(rst_ni), .Q(data_o_error_) );
  DFEQRM1SA ack_dst_q_reg ( .D(n2), .E(n1), .CK(clk_i), .RB(rst_ni), .Q(
        async_ack_o) );
  INVM1S I_2 ( .A(valid_o), .Z(n5) );
  INVM1S I_1 ( .A(async_ack_o), .Z(n2) );
  DFQRM1SA req_q0_reg ( .D(req_dst_q), .CK(clk_i), .RB(rst_ni), .Q(req_q0) );
  DFQRM1SA req_q1_reg ( .D(req_q0), .CK(clk_i), .RB(rst_ni), .Q(req_q1) );
  DFQRM1SA req_dst_q_reg ( .D(async_req_i), .CK(clk_i), .RB(rst_ni), .Q(
        req_dst_q) );
  XOR2M2WA C51 ( .A(async_ack_o), .B(req_q1), .Z(valid_o) );
  AN2M2R C59 ( .A(n3), .B(n5), .Z(n4) );
  AN2M2R C56 ( .A(valid_o), .B(ready_i), .Z(n1) );
  MAOI22M1SA U3 ( .A1(req_q1), .A2(req_q0), .B1(req_q1), .B2(req_q0), .Z(n3)
         );
endmodule


module cdc_2phase_121242 ( src_rst_ni, src_clk_i, src_valid_i, src_ready_o, 
        dst_rst_ni, dst_clk_i, dst_valid_o, dst_ready_i, src_data_i_last_, 
        src_data_i_error_, dst_data_o_last_, dst_data_o_error_ );
  input src_rst_ni, src_clk_i, src_valid_i, dst_rst_ni, dst_clk_i, dst_ready_i,
         src_data_i_last_, src_data_i_error_;
  output src_ready_o, dst_valid_o, dst_data_o_last_, dst_data_o_error_;
  wire   async_req, async_ack, async_data_last_, async_data_error_,
         SYNOPSYS_UNCONNECTED_1;

  cdc_2phase_src_121242 i_src ( .rst_ni(src_rst_ni), .clk_i(src_clk_i), 
        .valid_i(src_valid_i), .ready_o(SYNOPSYS_UNCONNECTED_1), .async_req_o(
        async_req), .async_ack_i(async_ack), .data_i_last_(src_data_i_last_), 
        .data_i_error_(src_data_i_error_), .async_data_o_last_(
        async_data_last_), .async_data_o_error_(async_data_error_) );
  cdc_2phase_dst_121242 i_dst ( .rst_ni(dst_rst_ni), .clk_i(dst_clk_i), 
        .valid_o(dst_valid_o), .ready_i(dst_ready_i), .async_req_i(async_req), 
        .async_ack_o(async_ack), .data_o_last_(dst_data_o_last_), 
        .data_o_error_(dst_data_o_error_), .async_data_i_last_(
        async_data_last_), .async_data_i_error_(async_data_error_) );
endmodule


module binary_to_gray_N3_3 ( A, Z );
  input [2:0] A;
  output [2:0] Z;

  assign Z[2] = A[2];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
  MAOI22M1SA U2 ( .A1(A[1]), .A2(A[2]), .B1(A[1]), .B2(A[2]), .Z(Z[1]) );
endmodule


module gray_to_binary_N3_3 ( A, Z );
  input [2:0] A;
  output [2:0] Z;
  wire   n0;
  assign Z[2] = A[2];

  XOR2M1SA C9 ( .A(A[2]), .B(A[1]), .Z(n0) );
  XOR2M1SA C8 ( .A(n0), .B(A[0]), .Z(Z[0]) );
  XOR2M1SA C10 ( .A(A[2]), .B(A[1]), .Z(Z[1]) );
endmodule


module binary_to_gray_N3_2 ( A, Z );
  input [2:0] A;
  output [2:0] Z;

  assign Z[2] = A[2];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
  MAOI22M1SA U2 ( .A1(A[1]), .A2(A[2]), .B1(A[1]), .B2(A[2]), .Z(Z[1]) );
endmodule


module gray_to_binary_N3_2 ( A, Z );
  input [2:0] A;
  output [2:0] Z;
  wire   n0;
  assign Z[2] = A[2];

  XOR2M1SA C9 ( .A(A[2]), .B(A[1]), .Z(n0) );
  XOR2M1SA C8 ( .A(n0), .B(A[0]), .Z(Z[0]) );
  XOR2M1SA C10 ( .A(A[2]), .B(A[1]), .Z(Z[1]) );
endmodule


module cdc_fifo_gray_LOG_DEPTH2 ( src_rst_ni, src_clk_i, src_data_i, 
        src_valid_i, src_ready_o, dst_rst_ni, dst_clk_i, dst_data_o, 
        dst_valid_o, dst_ready_i );
  input [17:0] src_data_i;
  output [17:0] dst_data_o;
  input src_rst_ni, src_clk_i, src_valid_i, dst_rst_ni, dst_clk_i, dst_ready_i;
  output src_ready_o, dst_valid_o;
  wire   fifo_write, n3, n4, n5, n6, n7, n9, n10, n11, n12, n13, n14, n15, n24,
         n25, n27, n28, n8, n16, n83, n84, n85, n86, n87, n1, n2, n17, n18,
         n19, n20, n21, n22, n23, n30, n31, n32, n33, n34, n35, n36, n37, n38,
         n39, n40, n41, n42, n43, n44, n45, n46, n47, n48, n49, n50, n51, n52,
         n53, n54, n55, n56, n57, n58, n59, n60, n61, n62;
  wire   [71:0] fifo_data_q;
  wire   [2:0] src_wptr_bin_q;
  wire   [2:1] src_wptr_bin_d;
  wire   [2:0] dst_rptr_bin_q;
  wire   [2:1] dst_rptr_bin_d;
  wire   [2:0] src_wptr_gray_d;
  wire   [2:0] dst_rptr_gray_d;
  wire   [2:0] src_wptr_gray_q;
  wire   [2:0] dst_rptr_gray_q;
  wire   [2:0] src_rptr_gray_q;
  wire   [2:0] src_rptr_gray_q2;
  wire   [2:0] dst_wptr_gray_q;
  wire   [2:0] dst_wptr_gray_q2;
  wire   [2:0] src_rptr_bin;
  wire   [2:0] dst_wptr_bin;

  binary_to_gray_N3_3 i_src_b2g ( .A({src_wptr_bin_d, n86}), .Z(
        src_wptr_gray_d) );
  binary_to_gray_N3_2 i_dst_b2g ( .A({dst_rptr_bin_d, n87}), .Z(
        dst_rptr_gray_d) );
  gray_to_binary_N3_3 i_src_g2b ( .A(src_rptr_gray_q2), .Z(src_rptr_bin) );
  gray_to_binary_N3_2 i_dst_g2b ( .A(dst_wptr_gray_q2), .Z(dst_wptr_bin) );
  OR2M1S C458 ( .A(n14), .B(n13), .Z(n25) );
  XOR2M1SA C489 ( .A(dst_rptr_bin_q[0]), .B(dst_wptr_bin[0]), .Z(n15) );
  XOR2M1SA C488 ( .A(dst_rptr_bin_q[1]), .B(dst_wptr_bin[1]), .Z(n14) );
  XOR2M1SA C487 ( .A(dst_rptr_bin_q[2]), .B(dst_wptr_bin[2]), .Z(n13) );
  CKAN2M2S C482 ( .A(dst_valid_o), .B(dst_ready_i), .Z(n9) );
  OR2M1S C459 ( .A(n15), .B(n25), .Z(dst_valid_o) );
  DFQRM1SA dst_wptr_gray_q2_reg_0_ ( .D(dst_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[0]) );
  DFEQRM1SA fifo_data_q_reg_0__data__11_ ( .D(src_data_i[13]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[67]) );
  DFEQRM1SA fifo_data_q_reg_1__data__14_ ( .D(src_data_i[16]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[52]) );
  DFEQRM1SA fifo_data_q_reg_1__strb__1_ ( .D(src_data_i[1]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[37]) );
  DFEQRM1SA fifo_data_q_reg_3__data__2_ ( .D(src_data_i[4]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[4]) );
  DFEQRM1SA fifo_data_q_reg_2__data__6_ ( .D(src_data_i[8]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[26]) );
  INVM1S I_5 ( .A(n10), .Z(n27) );
  DFQRM1SA dst_rptr_bin_q_reg_0_ ( .D(n16), .CK(dst_clk_i), .RB(dst_rst_ni), 
        .Q(dst_rptr_bin_q[0]) );
  DFEQRM1SA dst_rptr_bin_q_reg_2_ ( .D(dst_rptr_bin_d[2]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[2]) );
  DFEQRM1SA dst_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_d[0]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[0]) );
  DFEQRM1SA dst_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_d[1]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[1]) );
  DFEQRM1SA dst_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_d[2]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[2]) );
  DFQRM1SA src_wptr_bin_q_reg_0_ ( .D(n8), .CK(src_clk_i), .RB(src_rst_ni), 
        .Q(src_wptr_bin_q[0]) );
  DFEQRM1SA src_wptr_bin_q_reg_1_ ( .D(src_wptr_bin_d[1]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[1]) );
  DFEQRM1SA fifo_data_q_reg_0__strb__0_ ( .D(src_data_i[0]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[54]) );
  DFEQRM1SA fifo_data_q_reg_0__data__15_ ( .D(src_data_i[17]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[71]) );
  DFEQRM1SA fifo_data_q_reg_0__data__14_ ( .D(src_data_i[16]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[70]) );
  DFEQRM1SA fifo_data_q_reg_0__data__13_ ( .D(src_data_i[15]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[69]) );
  DFEQRM1SA fifo_data_q_reg_0__data__12_ ( .D(src_data_i[14]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[68]) );
  DFEQRM1SA fifo_data_q_reg_0__data__10_ ( .D(src_data_i[12]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[66]) );
  DFEQRM1SA fifo_data_q_reg_0__data__9_ ( .D(src_data_i[11]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[65]) );
  DFEQRM1SA fifo_data_q_reg_0__data__8_ ( .D(src_data_i[10]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[64]) );
  DFEQRM1SA fifo_data_q_reg_0__data__7_ ( .D(src_data_i[9]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[63]) );
  DFEQRM1SA fifo_data_q_reg_0__data__6_ ( .D(src_data_i[8]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[62]) );
  DFEQRM1SA fifo_data_q_reg_0__data__5_ ( .D(src_data_i[7]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[61]) );
  DFEQRM1SA fifo_data_q_reg_0__data__4_ ( .D(src_data_i[6]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[60]) );
  DFEQRM1SA fifo_data_q_reg_0__data__3_ ( .D(src_data_i[5]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[59]) );
  DFEQRM1SA fifo_data_q_reg_0__data__2_ ( .D(src_data_i[4]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[58]) );
  DFEQRM1SA fifo_data_q_reg_0__data__1_ ( .D(src_data_i[3]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[57]) );
  DFEQRM1SA fifo_data_q_reg_0__data__0_ ( .D(src_data_i[2]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[56]) );
  DFEQRM1SA fifo_data_q_reg_0__strb__1_ ( .D(src_data_i[1]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[55]) );
  DFEQRM1SA fifo_data_q_reg_1__strb__0_ ( .D(src_data_i[0]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[36]) );
  DFEQRM1SA fifo_data_q_reg_1__data__15_ ( .D(src_data_i[17]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[53]) );
  DFEQRM1SA fifo_data_q_reg_1__data__13_ ( .D(src_data_i[15]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[51]) );
  DFEQRM1SA fifo_data_q_reg_1__data__12_ ( .D(src_data_i[14]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[50]) );
  DFEQRM1SA fifo_data_q_reg_1__data__11_ ( .D(src_data_i[13]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[49]) );
  DFEQRM1SA fifo_data_q_reg_1__data__10_ ( .D(src_data_i[12]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[48]) );
  DFEQRM1SA fifo_data_q_reg_1__data__9_ ( .D(src_data_i[11]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[47]) );
  DFEQRM1SA fifo_data_q_reg_1__data__8_ ( .D(src_data_i[10]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[46]) );
  DFEQRM1SA fifo_data_q_reg_1__data__7_ ( .D(src_data_i[9]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[45]) );
  DFEQRM1SA fifo_data_q_reg_1__data__6_ ( .D(src_data_i[8]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[44]) );
  DFEQRM1SA fifo_data_q_reg_1__data__5_ ( .D(src_data_i[7]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[43]) );
  DFEQRM1SA fifo_data_q_reg_1__data__4_ ( .D(src_data_i[6]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[42]) );
  DFEQRM1SA fifo_data_q_reg_1__data__3_ ( .D(src_data_i[5]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[41]) );
  DFEQRM1SA fifo_data_q_reg_1__data__2_ ( .D(src_data_i[4]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[40]) );
  DFEQRM1SA fifo_data_q_reg_1__data__1_ ( .D(src_data_i[3]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[39]) );
  DFEQRM1SA fifo_data_q_reg_1__data__0_ ( .D(src_data_i[2]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[38]) );
  DFEQRM1SA fifo_data_q_reg_3__strb__0_ ( .D(src_data_i[0]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[0]) );
  DFEQRM1SA fifo_data_q_reg_3__data__15_ ( .D(src_data_i[17]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[17]) );
  DFEQRM1SA fifo_data_q_reg_3__data__14_ ( .D(src_data_i[16]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[16]) );
  DFEQRM1SA fifo_data_q_reg_3__data__13_ ( .D(src_data_i[15]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[15]) );
  DFEQRM1SA fifo_data_q_reg_3__data__12_ ( .D(src_data_i[14]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[14]) );
  DFEQRM1SA fifo_data_q_reg_3__data__11_ ( .D(src_data_i[13]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[13]) );
  DFEQRM1SA fifo_data_q_reg_3__data__10_ ( .D(src_data_i[12]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[12]) );
  DFEQRM1SA fifo_data_q_reg_3__data__9_ ( .D(src_data_i[11]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[11]) );
  DFEQRM1SA fifo_data_q_reg_3__data__8_ ( .D(src_data_i[10]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[10]) );
  DFEQRM1SA fifo_data_q_reg_3__data__7_ ( .D(src_data_i[9]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[9]) );
  DFEQRM1SA fifo_data_q_reg_3__data__6_ ( .D(src_data_i[8]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[8]) );
  DFEQRM1SA fifo_data_q_reg_3__data__5_ ( .D(src_data_i[7]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[7]) );
  DFEQRM1SA fifo_data_q_reg_3__data__4_ ( .D(src_data_i[6]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[6]) );
  DFEQRM1SA fifo_data_q_reg_3__data__3_ ( .D(src_data_i[5]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[5]) );
  DFEQRM1SA fifo_data_q_reg_3__data__1_ ( .D(src_data_i[3]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[3]) );
  DFEQRM1SA fifo_data_q_reg_3__data__0_ ( .D(src_data_i[2]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[2]) );
  DFEQRM1SA fifo_data_q_reg_3__strb__1_ ( .D(src_data_i[1]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[1]) );
  DFEQRM1SA src_wptr_bin_q_reg_2_ ( .D(src_wptr_bin_d[2]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[2]) );
  DFEQRM1SA fifo_data_q_reg_2__strb__0_ ( .D(src_data_i[0]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[18]) );
  DFEQRM1SA fifo_data_q_reg_2__data__15_ ( .D(src_data_i[17]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[35]) );
  DFEQRM1SA fifo_data_q_reg_2__data__14_ ( .D(src_data_i[16]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[34]) );
  DFEQRM1SA fifo_data_q_reg_2__data__13_ ( .D(src_data_i[15]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[33]) );
  DFEQRM1SA fifo_data_q_reg_2__data__12_ ( .D(src_data_i[14]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[32]) );
  DFEQRM1SA fifo_data_q_reg_2__data__11_ ( .D(src_data_i[13]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[31]) );
  DFEQRM1SA fifo_data_q_reg_2__data__10_ ( .D(src_data_i[12]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[30]) );
  DFEQRM1SA fifo_data_q_reg_2__data__9_ ( .D(src_data_i[11]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[29]) );
  DFEQRM1SA fifo_data_q_reg_2__data__8_ ( .D(src_data_i[10]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[28]) );
  DFEQRM1SA fifo_data_q_reg_2__data__7_ ( .D(src_data_i[9]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[27]) );
  DFEQRM1SA fifo_data_q_reg_2__data__5_ ( .D(src_data_i[7]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[25]) );
  DFEQRM1SA fifo_data_q_reg_2__data__4_ ( .D(src_data_i[6]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[24]) );
  DFEQRM1SA fifo_data_q_reg_2__data__3_ ( .D(src_data_i[5]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[23]) );
  DFEQRM1SA fifo_data_q_reg_2__data__2_ ( .D(src_data_i[4]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[22]) );
  DFEQRM1SA fifo_data_q_reg_2__data__1_ ( .D(src_data_i[3]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[21]) );
  DFEQRM1SA fifo_data_q_reg_2__data__0_ ( .D(src_data_i[2]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[20]) );
  DFEQRM1SA fifo_data_q_reg_2__strb__1_ ( .D(src_data_i[1]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[19]) );
  DFEQRM1SA src_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_d[0]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[0]) );
  DFEQRM1SA src_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_d[1]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[1]) );
  DFEQRM1SA src_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_d[2]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[2]) );
  DFERM1SA dst_rptr_bin_q_reg_1_ ( .D(dst_rptr_bin_d[1]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[1]), .QB(n62) );
  CKAN2M2S C479 ( .A(src_valid_i), .B(src_ready_o), .Z(n7) );
  DFQRM1SA dst_wptr_gray_q2_reg_2_ ( .D(dst_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[2]) );
  DFQRM1SA src_rptr_gray_q2_reg_2_ ( .D(src_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[2]) );
  DFQRM1SA src_rptr_gray_q2_reg_1_ ( .D(src_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[1]) );
  DFQRM1SA src_rptr_gray_q2_reg_0_ ( .D(src_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[0]) );
  DFQRM1SA dst_wptr_gray_q2_reg_1_ ( .D(dst_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[1]) );
  DFQRM1SA dst_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[0]) );
  DFQRM1SA dst_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[1]) );
  DFQRM1SA dst_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[2]) );
  DFQRM1SA src_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[0]) );
  DFQRM1SA src_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[1]) );
  DFQRM1SA src_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[2]) );
  XOR2M2WA C484 ( .A(src_wptr_bin_q[2]), .B(src_rptr_bin[2]), .Z(n10) );
  XOR2M2WA C486 ( .A(src_wptr_bin_q[0]), .B(src_rptr_bin[0]), .Z(n12) );
  AN2M2R C490 ( .A(src_valid_i), .B(src_ready_o), .Z(fifo_write) );
  CKAN2M2S C473 ( .A(fifo_write), .B(n84), .Z(n4) );
  CKAN2M2S C477 ( .A(fifo_write), .B(n24), .Z(n6) );
  CKAN2M2S C475 ( .A(fifo_write), .B(n83), .Z(n5) );
  AN2M4S C471 ( .A(fifo_write), .B(n85), .Z(n3) );
  XOR2M2SA C485 ( .A(src_wptr_bin_q[1]), .B(src_rptr_bin[1]), .Z(n11) );
  OR2M2R C463 ( .A(n11), .B(n27), .Z(n28) );
  OR2M4R C464 ( .A(n12), .B(n28), .Z(src_ready_o) );
  INVM1S U3 ( .A(src_wptr_bin_q[1]), .Z(n1) );
  NR2M1S U4 ( .A(src_wptr_bin_q[0]), .B(src_wptr_bin_q[1]), .Z(n85) );
  AOI22M1S U5 ( .A1(n59), .A2(fifo_data_q[60]), .B1(n58), .B2(fifo_data_q[6]), 
        .Z(n30) );
  AOI22M1S U6 ( .A1(n57), .A2(fifo_data_q[31]), .B1(n56), .B2(fifo_data_q[49]), 
        .Z(n19) );
  ND2M1S U7 ( .A(n37), .B(n36), .Z(dst_data_o[17]) );
  INVM1S U8 ( .A(dst_rptr_bin_q[0]), .Z(n87) );
  NR2M2S U9 ( .A(n87), .B(n62), .Z(n58) );
  MAOI22M1SA U10 ( .A1(n58), .A2(dst_rptr_bin_q[2]), .B1(n58), .B2(
        dst_rptr_bin_q[2]), .Z(dst_rptr_bin_d[2]) );
  NR2M2S U11 ( .A(dst_rptr_bin_q[0]), .B(n62), .Z(n57) );
  NR2M2S U12 ( .A(dst_rptr_bin_q[1]), .B(n87), .Z(n56) );
  OR2M1S U13 ( .A(n57), .B(n56), .Z(dst_rptr_bin_d[1]) );
  MAOI22M1SA U14 ( .A1(dst_rptr_bin_q[0]), .A2(n9), .B1(n9), .B2(
        dst_rptr_bin_q[0]), .Z(n16) );
  INVM1S U15 ( .A(src_wptr_bin_q[0]), .Z(n86) );
  NR2M1S U16 ( .A(n86), .B(n1), .Z(n24) );
  MAOI22M1SA U17 ( .A1(src_wptr_bin_q[2]), .A2(n24), .B1(src_wptr_bin_q[2]), 
        .B2(n24), .Z(src_wptr_bin_d[2]) );
  NR2M1S U18 ( .A(src_wptr_bin_q[0]), .B(n1), .Z(n83) );
  NR2M1S U19 ( .A(src_wptr_bin_q[1]), .B(n86), .Z(n84) );
  OR2M1S U20 ( .A(n83), .B(n84), .Z(src_wptr_bin_d[1]) );
  MAOI22M1SA U21 ( .A1(src_wptr_bin_q[0]), .A2(n7), .B1(n7), .B2(
        src_wptr_bin_q[0]), .Z(n8) );
  AOI22M1S U22 ( .A1(n57), .A2(fifo_data_q[25]), .B1(n56), .B2(fifo_data_q[43]), .Z(n17) );
  NR2M2S U23 ( .A(dst_rptr_bin_q[0]), .B(dst_rptr_bin_q[1]), .Z(n59) );
  AOI22M1S U24 ( .A1(n59), .A2(fifo_data_q[61]), .B1(n58), .B2(fifo_data_q[7]), 
        .Z(n2) );
  ND2M1S U25 ( .A(n17), .B(n2), .Z(dst_data_o[7]) );
  AOI22M1S U26 ( .A1(n59), .A2(fifo_data_q[67]), .B1(n58), .B2(fifo_data_q[13]), .Z(n18) );
  ND2M1S U27 ( .A(n19), .B(n18), .Z(dst_data_o[13]) );
  AOI22M1S U28 ( .A1(n57), .A2(fifo_data_q[30]), .B1(n56), .B2(fifo_data_q[48]), .Z(n21) );
  AOI22M1S U29 ( .A1(n59), .A2(fifo_data_q[66]), .B1(n58), .B2(fifo_data_q[12]), .Z(n20) );
  ND2M1S U30 ( .A(n21), .B(n20), .Z(dst_data_o[12]) );
  AOI22M1S U31 ( .A1(n57), .A2(fifo_data_q[28]), .B1(n56), .B2(fifo_data_q[46]), .Z(n23) );
  AOI22M1S U32 ( .A1(n59), .A2(fifo_data_q[64]), .B1(n58), .B2(fifo_data_q[10]), .Z(n22) );
  ND2M1S U33 ( .A(n23), .B(n22), .Z(dst_data_o[10]) );
  AOI22M1S U34 ( .A1(n57), .A2(fifo_data_q[24]), .B1(n56), .B2(fifo_data_q[42]), .Z(n31) );
  ND2M1S U35 ( .A(n31), .B(n30), .Z(dst_data_o[6]) );
  AOI22M1S U36 ( .A1(n57), .A2(fifo_data_q[19]), .B1(n56), .B2(fifo_data_q[37]), .Z(n33) );
  AOI22M1S U37 ( .A1(n59), .A2(fifo_data_q[55]), .B1(n58), .B2(fifo_data_q[1]), 
        .Z(n32) );
  ND2M1S U38 ( .A(n33), .B(n32), .Z(dst_data_o[1]) );
  AOI22M1S U39 ( .A1(n57), .A2(fifo_data_q[18]), .B1(n56), .B2(fifo_data_q[36]), .Z(n35) );
  AOI22M1S U40 ( .A1(n59), .A2(fifo_data_q[54]), .B1(n58), .B2(fifo_data_q[0]), 
        .Z(n34) );
  ND2M1S U41 ( .A(n35), .B(n34), .Z(dst_data_o[0]) );
  AOI22M1S U42 ( .A1(n57), .A2(fifo_data_q[35]), .B1(n56), .B2(fifo_data_q[53]), .Z(n37) );
  AOI22M1S U43 ( .A1(n59), .A2(fifo_data_q[71]), .B1(n58), .B2(fifo_data_q[17]), .Z(n36) );
  AOI22M1S U44 ( .A1(n57), .A2(fifo_data_q[34]), .B1(n56), .B2(fifo_data_q[52]), .Z(n39) );
  AOI22M1S U45 ( .A1(n59), .A2(fifo_data_q[70]), .B1(n58), .B2(fifo_data_q[16]), .Z(n38) );
  ND2M1S U46 ( .A(n39), .B(n38), .Z(dst_data_o[16]) );
  AOI22M1S U47 ( .A1(n57), .A2(fifo_data_q[33]), .B1(n56), .B2(fifo_data_q[51]), .Z(n41) );
  AOI22M1S U48 ( .A1(n59), .A2(fifo_data_q[69]), .B1(n58), .B2(fifo_data_q[15]), .Z(n40) );
  ND2M1S U49 ( .A(n41), .B(n40), .Z(dst_data_o[15]) );
  AOI22M1S U50 ( .A1(n57), .A2(fifo_data_q[32]), .B1(n56), .B2(fifo_data_q[50]), .Z(n43) );
  AOI22M1S U51 ( .A1(n59), .A2(fifo_data_q[68]), .B1(n58), .B2(fifo_data_q[14]), .Z(n42) );
  ND2M1S U52 ( .A(n43), .B(n42), .Z(dst_data_o[14]) );
  AOI22M1S U53 ( .A1(n57), .A2(fifo_data_q[23]), .B1(n56), .B2(fifo_data_q[41]), .Z(n45) );
  AOI22M1S U54 ( .A1(n59), .A2(fifo_data_q[59]), .B1(n58), .B2(fifo_data_q[5]), 
        .Z(n44) );
  ND2M1S U55 ( .A(n45), .B(n44), .Z(dst_data_o[5]) );
  AOI22M1S U56 ( .A1(n57), .A2(fifo_data_q[22]), .B1(n56), .B2(fifo_data_q[40]), .Z(n47) );
  AOI22M1S U57 ( .A1(n59), .A2(fifo_data_q[58]), .B1(n58), .B2(fifo_data_q[4]), 
        .Z(n46) );
  ND2M1S U58 ( .A(n47), .B(n46), .Z(dst_data_o[4]) );
  AOI22M1S U59 ( .A1(n57), .A2(fifo_data_q[20]), .B1(n56), .B2(fifo_data_q[38]), .Z(n49) );
  AOI22M1S U60 ( .A1(n59), .A2(fifo_data_q[56]), .B1(n58), .B2(fifo_data_q[2]), 
        .Z(n48) );
  ND2M1S U61 ( .A(n49), .B(n48), .Z(dst_data_o[2]) );
  AOI22M1S U62 ( .A1(n57), .A2(fifo_data_q[21]), .B1(n56), .B2(fifo_data_q[39]), .Z(n51) );
  AOI22M1S U63 ( .A1(n59), .A2(fifo_data_q[57]), .B1(n58), .B2(fifo_data_q[3]), 
        .Z(n50) );
  ND2M1S U64 ( .A(n51), .B(n50), .Z(dst_data_o[3]) );
  AOI22M1S U65 ( .A1(n57), .A2(fifo_data_q[27]), .B1(n56), .B2(fifo_data_q[45]), .Z(n53) );
  AOI22M1S U66 ( .A1(n59), .A2(fifo_data_q[63]), .B1(n58), .B2(fifo_data_q[9]), 
        .Z(n52) );
  ND2M1S U67 ( .A(n53), .B(n52), .Z(dst_data_o[9]) );
  AOI22M1S U68 ( .A1(n57), .A2(fifo_data_q[26]), .B1(n56), .B2(fifo_data_q[44]), .Z(n55) );
  AOI22M1S U69 ( .A1(n59), .A2(fifo_data_q[62]), .B1(n58), .B2(fifo_data_q[8]), 
        .Z(n54) );
  ND2M1S U70 ( .A(n55), .B(n54), .Z(dst_data_o[8]) );
  AOI22M1S U71 ( .A1(n57), .A2(fifo_data_q[29]), .B1(n56), .B2(fifo_data_q[47]), .Z(n61) );
  AOI22M1S U72 ( .A1(n59), .A2(fifo_data_q[65]), .B1(n58), .B2(fifo_data_q[11]), .Z(n60) );
  ND2M1S U73 ( .A(n61), .B(n60), .Z(dst_data_o[11]) );
endmodule


module binary_to_gray_N3_0 ( A, Z );
  input [2:0] A;
  output [2:0] Z;

  assign Z[2] = A[2];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[2]), .B1(A[1]), .B2(A[2]), .Z(Z[1]) );
  MAOI22M1SA U2 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
endmodule


module binary_to_gray_N3_1 ( A, Z );
  input [2:0] A;
  output [2:0] Z;

  assign Z[2] = A[2];

  MAOI22M1SA U1 ( .A1(A[1]), .A2(A[0]), .B1(A[1]), .B2(A[0]), .Z(Z[0]) );
  MAOI22M1SA U2 ( .A1(A[1]), .A2(A[2]), .B1(A[1]), .B2(A[2]), .Z(Z[1]) );
endmodule


module gray_to_binary_N3_0 ( A, Z );
  input [2:0] A;
  output [2:0] Z;
  wire   n0;
  assign Z[2] = A[2];

  XOR2M1SA C9 ( .A(A[2]), .B(A[1]), .Z(n0) );
  XOR2M1SA C10 ( .A(A[2]), .B(A[1]), .Z(Z[1]) );
  XOR2M2SA C8 ( .A(n0), .B(A[0]), .Z(Z[0]) );
endmodule


module gray_to_binary_N3_1 ( A, Z );
  input [2:0] A;
  output [2:0] Z;
  wire   n0;
  assign Z[2] = A[2];

  XOR2M1SA C9 ( .A(A[2]), .B(A[1]), .Z(n0) );
  XOR2M1SA C8 ( .A(n0), .B(A[0]), .Z(Z[0]) );
  XOR2M1SA C10 ( .A(A[2]), .B(A[1]), .Z(Z[1]) );
endmodule


module cdc_fifo_gray_LOG_DEPTH2_1 ( src_rst_ni, src_clk_i, src_data_i, 
        src_valid_i, src_ready_o, dst_rst_ni, dst_clk_i, dst_data_o, 
        dst_valid_o, dst_ready_i );
  input [17:0] src_data_i;
  output [17:0] dst_data_o;
  input src_rst_ni, src_clk_i, src_valid_i, dst_rst_ni, dst_clk_i, dst_ready_i;
  output src_ready_o, dst_valid_o;
  wire   fifo_write, n3, n4, n5, n6, n7, n9, n10, n11, n12, n13, n14, n15, n24,
         n25, n27, n28, n8, n16, n83, n84, n85, n86, n87, n1, n2, n17, n18,
         n19, n20, n21, n22, n23, n30, n31, n32, n33, n34, n35, n36, n37, n38,
         n39, n40, n41, n42, n43, n44, n45, n46, n47, n48, n49, n50, n51, n52,
         n53, n54, n55, n56, n57, n58, n59, n60, n61, n62, n63, n64;
  wire   [71:0] fifo_data_q;
  wire   [2:0] src_wptr_bin_q;
  wire   [2:1] src_wptr_bin_d;
  wire   [2:0] dst_rptr_bin_q;
  wire   [2:1] dst_rptr_bin_d;
  wire   [2:0] src_wptr_gray_d;
  wire   [2:0] dst_rptr_gray_d;
  wire   [2:0] src_wptr_gray_q;
  wire   [2:0] dst_rptr_gray_q;
  wire   [2:0] src_rptr_gray_q;
  wire   [2:0] src_rptr_gray_q2;
  wire   [2:0] dst_wptr_gray_q;
  wire   [2:0] dst_wptr_gray_q2;
  wire   [2:0] src_rptr_bin;
  wire   [2:0] dst_wptr_bin;

  binary_to_gray_N3_1 i_src_b2g ( .A({src_wptr_bin_d, n86}), .Z(
        src_wptr_gray_d) );
  binary_to_gray_N3_0 i_dst_b2g ( .A({dst_rptr_bin_d, n87}), .Z(
        dst_rptr_gray_d) );
  gray_to_binary_N3_1 i_src_g2b ( .A(src_rptr_gray_q2), .Z(src_rptr_bin) );
  gray_to_binary_N3_0 i_dst_g2b ( .A(dst_wptr_gray_q2), .Z(dst_wptr_bin) );
  XOR2M1SA C486 ( .A(src_wptr_bin_q[0]), .B(src_rptr_bin[0]), .Z(n12) );
  XOR2M1SA C485 ( .A(src_wptr_bin_q[1]), .B(src_rptr_bin[1]), .Z(n11) );
  XOR2M1SA C484 ( .A(src_wptr_bin_q[2]), .B(src_rptr_bin[2]), .Z(n10) );
  INVM1S I_5 ( .A(n10), .Z(n27) );
  CKAN2M2S C490 ( .A(src_valid_i), .B(src_ready_o), .Z(fifo_write) );
  CKAN2M2S C479 ( .A(src_valid_i), .B(src_ready_o), .Z(n7) );
  OR2M1S C463 ( .A(n11), .B(n27), .Z(n28) );
  CKAN2M2S C477 ( .A(fifo_write), .B(n24), .Z(n6) );
  CKAN2M2S C475 ( .A(fifo_write), .B(n83), .Z(n5) );
  CKAN2M2S C473 ( .A(fifo_write), .B(n84), .Z(n4) );
  CKAN2M2S C471 ( .A(fifo_write), .B(n85), .Z(n3) );
  DFQRM1SA dst_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[0]) );
  DFQRM1SA src_rptr_gray_q2_reg_2_ ( .D(src_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[2]) );
  DFEQRM1SA fifo_data_q_reg_0__data__4_ ( .D(src_data_i[4]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[58]) );
  DFEQRM1SA fifo_data_q_reg_1__data__5_ ( .D(src_data_i[5]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[41]) );
  DFEQRM1SA fifo_data_q_reg_3__data__7_ ( .D(src_data_i[7]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[7]) );
  DFEQRM1SA fifo_data_q_reg_2__data__10_ ( .D(src_data_i[10]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[28]) );
  DFEQRM1SA fifo_data_q_reg_1__error_ ( .D(src_data_i[16]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[52]) );
  DFQRM1SA dst_rptr_bin_q_reg_0_ ( .D(n16), .CK(dst_clk_i), .RB(dst_rst_ni), 
        .Q(dst_rptr_bin_q[0]) );
  DFEQRM1SA dst_rptr_bin_q_reg_1_ ( .D(dst_rptr_bin_d[1]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[1]) );
  DFEQRM1SA dst_rptr_bin_q_reg_2_ ( .D(dst_rptr_bin_d[2]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_bin_q[2]) );
  DFEQRM1SA dst_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_d[0]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[0]) );
  DFEQRM1SA dst_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_d[1]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[1]) );
  DFEQRM1SA dst_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_d[2]), .E(n9), .CK(
        dst_clk_i), .RB(dst_rst_ni), .Q(dst_rptr_gray_q[2]) );
  DFQRM1SA src_wptr_bin_q_reg_0_ ( .D(n8), .CK(src_clk_i), .RB(src_rst_ni), 
        .Q(src_wptr_bin_q[0]) );
  DFEQRM1SA src_wptr_bin_q_reg_1_ ( .D(src_wptr_bin_d[1]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[1]) );
  DFEQRM1SA fifo_data_q_reg_0__data__0_ ( .D(src_data_i[0]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[54]) );
  DFEQRM1SA fifo_data_q_reg_0__data__15_ ( .D(src_data_i[15]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[69]) );
  DFEQRM1SA fifo_data_q_reg_0__data__14_ ( .D(src_data_i[14]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[68]) );
  DFEQRM1SA fifo_data_q_reg_0__data__13_ ( .D(src_data_i[13]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[67]) );
  DFEQRM1SA fifo_data_q_reg_0__data__12_ ( .D(src_data_i[12]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[66]) );
  DFEQRM1SA fifo_data_q_reg_0__data__11_ ( .D(src_data_i[11]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[65]) );
  DFEQRM1SA fifo_data_q_reg_0__data__10_ ( .D(src_data_i[10]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[64]) );
  DFEQRM1SA fifo_data_q_reg_0__data__9_ ( .D(src_data_i[9]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[63]) );
  DFEQRM1SA fifo_data_q_reg_0__data__8_ ( .D(src_data_i[8]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[62]) );
  DFEQRM1SA fifo_data_q_reg_0__data__7_ ( .D(src_data_i[7]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[61]) );
  DFEQRM1SA fifo_data_q_reg_0__data__6_ ( .D(src_data_i[6]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[60]) );
  DFEQRM1SA fifo_data_q_reg_0__data__5_ ( .D(src_data_i[5]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[59]) );
  DFEQRM1SA fifo_data_q_reg_0__data__3_ ( .D(src_data_i[3]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[57]) );
  DFEQRM1SA fifo_data_q_reg_0__data__2_ ( .D(src_data_i[2]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[56]) );
  DFEQRM1SA fifo_data_q_reg_0__data__1_ ( .D(src_data_i[1]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[55]) );
  DFEQRM1SA fifo_data_q_reg_1__data__0_ ( .D(src_data_i[0]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[36]) );
  DFEQRM1SA fifo_data_q_reg_1__data__15_ ( .D(src_data_i[15]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[51]) );
  DFEQRM1SA fifo_data_q_reg_1__data__14_ ( .D(src_data_i[14]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[50]) );
  DFEQRM1SA fifo_data_q_reg_1__data__13_ ( .D(src_data_i[13]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[49]) );
  DFEQRM1SA fifo_data_q_reg_1__data__12_ ( .D(src_data_i[12]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[48]) );
  DFEQRM1SA fifo_data_q_reg_1__data__11_ ( .D(src_data_i[11]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[47]) );
  DFEQRM1SA fifo_data_q_reg_1__data__10_ ( .D(src_data_i[10]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[46]) );
  DFEQRM1SA fifo_data_q_reg_1__data__9_ ( .D(src_data_i[9]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[45]) );
  DFEQRM1SA fifo_data_q_reg_1__data__8_ ( .D(src_data_i[8]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[44]) );
  DFEQRM1SA fifo_data_q_reg_1__data__7_ ( .D(src_data_i[7]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[43]) );
  DFEQRM1SA fifo_data_q_reg_1__data__6_ ( .D(src_data_i[6]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[42]) );
  DFEQRM1SA fifo_data_q_reg_1__data__4_ ( .D(src_data_i[4]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[40]) );
  DFEQRM1SA fifo_data_q_reg_1__data__3_ ( .D(src_data_i[3]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[39]) );
  DFEQRM1SA fifo_data_q_reg_1__data__2_ ( .D(src_data_i[2]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[38]) );
  DFEQRM1SA fifo_data_q_reg_1__data__1_ ( .D(src_data_i[1]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[37]) );
  DFEQRM1SA fifo_data_q_reg_3__data__0_ ( .D(src_data_i[0]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[0]) );
  DFEQRM1SA fifo_data_q_reg_3__last_ ( .D(src_data_i[17]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[17]) );
  DFEQRM1SA fifo_data_q_reg_3__data__15_ ( .D(src_data_i[15]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[15]) );
  DFEQRM1SA fifo_data_q_reg_3__data__14_ ( .D(src_data_i[14]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[14]) );
  DFEQRM1SA fifo_data_q_reg_3__data__13_ ( .D(src_data_i[13]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[13]) );
  DFEQRM1SA fifo_data_q_reg_3__data__12_ ( .D(src_data_i[12]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[12]) );
  DFEQRM1SA fifo_data_q_reg_3__data__11_ ( .D(src_data_i[11]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[11]) );
  DFEQRM1SA fifo_data_q_reg_3__data__10_ ( .D(src_data_i[10]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[10]) );
  DFEQRM1SA fifo_data_q_reg_3__data__9_ ( .D(src_data_i[9]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[9]) );
  DFEQRM1SA fifo_data_q_reg_3__data__8_ ( .D(src_data_i[8]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[8]) );
  DFEQRM1SA fifo_data_q_reg_3__data__6_ ( .D(src_data_i[6]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[6]) );
  DFEQRM1SA fifo_data_q_reg_3__data__5_ ( .D(src_data_i[5]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[5]) );
  DFEQRM1SA fifo_data_q_reg_3__data__4_ ( .D(src_data_i[4]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[4]) );
  DFEQRM1SA fifo_data_q_reg_3__data__3_ ( .D(src_data_i[3]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[3]) );
  DFEQRM1SA fifo_data_q_reg_3__data__2_ ( .D(src_data_i[2]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[2]) );
  DFEQRM1SA fifo_data_q_reg_3__data__1_ ( .D(src_data_i[1]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[1]) );
  DFEQRM1SA src_wptr_bin_q_reg_2_ ( .D(src_wptr_bin_d[2]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_bin_q[2]) );
  DFEQRM1SA fifo_data_q_reg_2__data__0_ ( .D(src_data_i[0]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[18]) );
  DFEQRM1SA fifo_data_q_reg_2__last_ ( .D(src_data_i[17]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[35]) );
  DFEQRM1SA fifo_data_q_reg_2__data__15_ ( .D(src_data_i[15]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[33]) );
  DFEQRM1SA fifo_data_q_reg_2__data__14_ ( .D(src_data_i[14]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[32]) );
  DFEQRM1SA fifo_data_q_reg_2__data__13_ ( .D(src_data_i[13]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[31]) );
  DFEQRM1SA fifo_data_q_reg_2__data__12_ ( .D(src_data_i[12]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[30]) );
  DFEQRM1SA fifo_data_q_reg_2__data__11_ ( .D(src_data_i[11]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[29]) );
  DFEQRM1SA fifo_data_q_reg_2__data__9_ ( .D(src_data_i[9]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[27]) );
  DFEQRM1SA fifo_data_q_reg_2__data__8_ ( .D(src_data_i[8]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[26]) );
  DFEQRM1SA fifo_data_q_reg_2__data__7_ ( .D(src_data_i[7]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[25]) );
  DFEQRM1SA fifo_data_q_reg_2__data__6_ ( .D(src_data_i[6]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[24]) );
  DFEQRM1SA fifo_data_q_reg_2__data__5_ ( .D(src_data_i[5]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[23]) );
  DFEQRM1SA fifo_data_q_reg_2__data__4_ ( .D(src_data_i[4]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[22]) );
  DFEQRM1SA fifo_data_q_reg_2__data__3_ ( .D(src_data_i[3]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[21]) );
  DFEQRM1SA fifo_data_q_reg_2__data__2_ ( .D(src_data_i[2]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[20]) );
  DFEQRM1SA fifo_data_q_reg_2__data__1_ ( .D(src_data_i[1]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[19]) );
  DFEQRM1SA src_wptr_gray_q_reg_0_ ( .D(src_wptr_gray_d[0]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[0]) );
  DFEQRM1SA src_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_d[1]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[1]) );
  DFEQRM1SA src_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_d[2]), .E(n7), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(src_wptr_gray_q[2]) );
  DFEQRM1SA fifo_data_q_reg_0__error_ ( .D(src_data_i[16]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[70]) );
  DFEQRM1SA fifo_data_q_reg_3__error_ ( .D(src_data_i[16]), .E(n6), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[16]) );
  DFEQRM1SA fifo_data_q_reg_2__error_ ( .D(src_data_i[16]), .E(n5), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[34]) );
  DFEQRM1SA fifo_data_q_reg_0__last_ ( .D(src_data_i[17]), .E(n3), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[71]) );
  DFEQRM1SA fifo_data_q_reg_1__last_ ( .D(src_data_i[17]), .E(n4), .CK(
        src_clk_i), .RB(src_rst_ni), .Q(fifo_data_q[53]) );
  OR2M1S C464 ( .A(n12), .B(n28), .Z(src_ready_o) );
  DFQRM1SA dst_wptr_gray_q2_reg_2_ ( .D(dst_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[2]) );
  DFQRM1SA dst_wptr_gray_q2_reg_1_ ( .D(dst_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[1]) );
  DFQRM1SA dst_wptr_gray_q2_reg_0_ ( .D(dst_wptr_gray_q[0]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q2[0]) );
  DFQRM1SA src_rptr_gray_q2_reg_1_ ( .D(src_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[1]) );
  DFQRM1SA src_rptr_gray_q2_reg_0_ ( .D(src_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q2[0]) );
  DFQRM1SA src_rptr_gray_q_reg_0_ ( .D(dst_rptr_gray_q[0]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[0]) );
  DFQRM1SA src_rptr_gray_q_reg_1_ ( .D(dst_rptr_gray_q[1]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[1]) );
  DFQRM1SA src_rptr_gray_q_reg_2_ ( .D(dst_rptr_gray_q[2]), .CK(src_clk_i), 
        .RB(src_rst_ni), .Q(src_rptr_gray_q[2]) );
  DFQRM1SA dst_wptr_gray_q_reg_1_ ( .D(src_wptr_gray_q[1]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[1]) );
  DFQRM1SA dst_wptr_gray_q_reg_2_ ( .D(src_wptr_gray_q[2]), .CK(dst_clk_i), 
        .RB(dst_rst_ni), .Q(dst_wptr_gray_q[2]) );
  CKXOR2M1WA C488 ( .A(dst_rptr_bin_q[1]), .B(dst_wptr_bin[1]), .Z(n14) );
  CKXOR2M1WA C489 ( .A(dst_rptr_bin_q[0]), .B(dst_wptr_bin[0]), .Z(n15) );
  CKAN2M2S C482 ( .A(dst_valid_o), .B(dst_ready_i), .Z(n9) );
  XOR2M1SA C487 ( .A(dst_rptr_bin_q[2]), .B(dst_wptr_bin[2]), .Z(n13) );
  OR2M2S C458 ( .A(n14), .B(n13), .Z(n25) );
  OR2M4R C459 ( .A(n15), .B(n25), .Z(dst_valid_o) );
  ND2M2R U3 ( .A(n58), .B(n57), .Z(dst_data_o[16]) );
  AOI22M2S U4 ( .A1(fifo_data_q[34]), .A2(n61), .B1(n59), .B2(fifo_data_q[16]), 
        .Z(n58) );
  NR2B1M2R U5 ( .NA(dst_rptr_bin_q[1]), .B(dst_rptr_bin_q[0]), .Z(n61) );
  NR2B1M4R U6 ( .NA(dst_rptr_bin_q[0]), .B(n2), .Z(n59) );
  NR2M2R U7 ( .A(dst_rptr_bin_q[0]), .B(dst_rptr_bin_q[1]), .Z(n62) );
  NR2M2R U8 ( .A(n87), .B(dst_rptr_bin_q[1]), .Z(n60) );
  XOR2M2RA U9 ( .A(n9), .B(dst_rptr_bin_q[0]), .Z(n16) );
  AOI22M1R U10 ( .A1(n62), .A2(fifo_data_q[59]), .B1(n61), .B2(fifo_data_q[23]), .Z(n39) );
  AOI22M1R U11 ( .A1(n62), .A2(fifo_data_q[56]), .B1(n61), .B2(fifo_data_q[20]), .Z(n33) );
  AOI22M1R U12 ( .A1(n60), .A2(fifo_data_q[38]), .B1(n59), .B2(fifo_data_q[2]), 
        .Z(n34) );
  AOI22M1R U13 ( .A1(n60), .A2(fifo_data_q[41]), .B1(n59), .B2(fifo_data_q[5]), 
        .Z(n40) );
  AOI22M1R U14 ( .A1(n60), .A2(fifo_data_q[39]), .B1(n59), .B2(fifo_data_q[3]), 
        .Z(n36) );
  AOI22M1R U15 ( .A1(n62), .A2(fifo_data_q[57]), .B1(n61), .B2(fifo_data_q[21]), .Z(n35) );
  AOI22M1R U16 ( .A1(n62), .A2(fifo_data_q[58]), .B1(n61), .B2(fifo_data_q[22]), .Z(n37) );
  AOI22M1R U17 ( .A1(n60), .A2(fifo_data_q[40]), .B1(n59), .B2(fifo_data_q[4]), 
        .Z(n38) );
  AOI22M2W U18 ( .A1(n60), .A2(fifo_data_q[53]), .B1(n59), .B2(fifo_data_q[17]), .Z(n64) );
  AOI22M1W U19 ( .A1(n62), .A2(fifo_data_q[71]), .B1(n61), .B2(fifo_data_q[35]), .Z(n63) );
  AOI22M2W U20 ( .A1(fifo_data_q[52]), .A2(n60), .B1(n62), .B2(fifo_data_q[70]), .Z(n57) );
  AOI22M1R U21 ( .A1(n60), .A2(fifo_data_q[36]), .B1(n59), .B2(fifo_data_q[0]), 
        .Z(n30) );
  AOI22M1R U22 ( .A1(n62), .A2(fifo_data_q[54]), .B1(n61), .B2(fifo_data_q[18]), .Z(n23) );
  AOI22M1R U23 ( .A1(n60), .A2(fifo_data_q[37]), .B1(n59), .B2(fifo_data_q[1]), 
        .Z(n32) );
  AOI22M1R U24 ( .A1(n62), .A2(fifo_data_q[55]), .B1(n61), .B2(fifo_data_q[19]), .Z(n31) );
  AOI22M1R U25 ( .A1(n60), .A2(fifo_data_q[50]), .B1(n59), .B2(fifo_data_q[14]), .Z(n20) );
  AOI22M1R U26 ( .A1(n62), .A2(fifo_data_q[68]), .B1(n61), .B2(fifo_data_q[32]), .Z(n19) );
  AOI22M1R U27 ( .A1(n60), .A2(fifo_data_q[51]), .B1(n59), .B2(fifo_data_q[15]), .Z(n56) );
  AOI22M1R U28 ( .A1(n62), .A2(fifo_data_q[69]), .B1(n61), .B2(fifo_data_q[33]), .Z(n55) );
  AOI22M1R U29 ( .A1(n62), .A2(fifo_data_q[61]), .B1(n61), .B2(fifo_data_q[25]), .Z(n43) );
  AOI22M1R U30 ( .A1(n60), .A2(fifo_data_q[44]), .B1(n59), .B2(fifo_data_q[8]), 
        .Z(n46) );
  AOI22M1R U31 ( .A1(n62), .A2(fifo_data_q[62]), .B1(n61), .B2(fifo_data_q[26]), .Z(n45) );
  AOI22M1R U32 ( .A1(n60), .A2(fifo_data_q[43]), .B1(n59), .B2(fifo_data_q[7]), 
        .Z(n44) );
  AOI22M1R U33 ( .A1(n60), .A2(fifo_data_q[45]), .B1(n59), .B2(fifo_data_q[9]), 
        .Z(n48) );
  AOI22M1R U34 ( .A1(n60), .A2(fifo_data_q[46]), .B1(n59), .B2(fifo_data_q[10]), .Z(n50) );
  AOI22M1R U35 ( .A1(n62), .A2(fifo_data_q[64]), .B1(n61), .B2(fifo_data_q[28]), .Z(n49) );
  AOI22M1R U36 ( .A1(n60), .A2(fifo_data_q[47]), .B1(n59), .B2(fifo_data_q[11]), .Z(n52) );
  AOI22M1R U37 ( .A1(n62), .A2(fifo_data_q[65]), .B1(n61), .B2(fifo_data_q[29]), .Z(n51) );
  AOI22M1R U38 ( .A1(n62), .A2(fifo_data_q[60]), .B1(n61), .B2(fifo_data_q[24]), .Z(n21) );
  AOI22M1R U39 ( .A1(n62), .A2(fifo_data_q[63]), .B1(n61), .B2(fifo_data_q[27]), .Z(n47) );
  AOI22M1R U40 ( .A1(n60), .A2(fifo_data_q[42]), .B1(n59), .B2(fifo_data_q[6]), 
        .Z(n22) );
  AOI22M1R U41 ( .A1(n62), .A2(fifo_data_q[67]), .B1(n61), .B2(fifo_data_q[31]), .Z(n41) );
  AOI22M1R U42 ( .A1(n60), .A2(fifo_data_q[48]), .B1(n59), .B2(fifo_data_q[12]), .Z(n54) );
  AOI22M1R U43 ( .A1(n60), .A2(fifo_data_q[49]), .B1(n59), .B2(fifo_data_q[13]), .Z(n42) );
  AOI22M1W U44 ( .A1(n62), .A2(fifo_data_q[66]), .B1(n61), .B2(fifo_data_q[30]), .Z(n53) );
  INVM1S U45 ( .A(dst_rptr_bin_q[1]), .Z(n2) );
  INVM1S U46 ( .A(dst_rptr_bin_q[0]), .Z(n87) );
  ND2M1S U47 ( .A(n64), .B(n63), .Z(dst_data_o[17]) );
  ND2M1S U48 ( .A(n54), .B(n53), .Z(dst_data_o[12]) );
  INVM1S U49 ( .A(src_wptr_bin_q[0]), .Z(n86) );
  INVM1S U50 ( .A(src_wptr_bin_q[1]), .Z(n1) );
  NR2M1S U51 ( .A(n86), .B(n1), .Z(n24) );
  MAOI22M1SA U52 ( .A1(src_wptr_bin_q[2]), .A2(n24), .B1(src_wptr_bin_q[2]), 
        .B2(n24), .Z(src_wptr_bin_d[2]) );
  NR2M1S U53 ( .A(src_wptr_bin_q[0]), .B(n1), .Z(n83) );
  NR2M1S U54 ( .A(src_wptr_bin_q[1]), .B(n86), .Z(n84) );
  OR2M1S U55 ( .A(n83), .B(n84), .Z(src_wptr_bin_d[1]) );
  MAOI22M1SA U56 ( .A1(src_wptr_bin_q[0]), .A2(n7), .B1(n7), .B2(
        src_wptr_bin_q[0]), .Z(n8) );
  MAOI22M1SA U57 ( .A1(n59), .A2(dst_rptr_bin_q[2]), .B1(n59), .B2(
        dst_rptr_bin_q[2]), .Z(dst_rptr_bin_d[2]) );
  NR2M1S U58 ( .A(src_wptr_bin_q[0]), .B(src_wptr_bin_q[1]), .Z(n85) );
  INVM1S U59 ( .A(n61), .Z(n18) );
  INVM1S U60 ( .A(n60), .Z(n17) );
  ND2M1S U61 ( .A(n18), .B(n17), .Z(dst_rptr_bin_d[1]) );
  ND2M1S U62 ( .A(n20), .B(n19), .Z(dst_data_o[14]) );
  ND2M1S U63 ( .A(n22), .B(n21), .Z(dst_data_o[6]) );
  ND2M1S U64 ( .A(n30), .B(n23), .Z(dst_data_o[0]) );
  ND2M1S U65 ( .A(n32), .B(n31), .Z(dst_data_o[1]) );
  ND2M1S U66 ( .A(n34), .B(n33), .Z(dst_data_o[2]) );
  ND2M1S U67 ( .A(n36), .B(n35), .Z(dst_data_o[3]) );
  ND2M1S U68 ( .A(n38), .B(n37), .Z(dst_data_o[4]) );
  ND2M1S U69 ( .A(n40), .B(n39), .Z(dst_data_o[5]) );
  ND2M1S U70 ( .A(n42), .B(n41), .Z(dst_data_o[13]) );
  ND2M1S U71 ( .A(n44), .B(n43), .Z(dst_data_o[7]) );
  ND2M1S U72 ( .A(n46), .B(n45), .Z(dst_data_o[8]) );
  ND2M1S U73 ( .A(n48), .B(n47), .Z(dst_data_o[9]) );
  ND2M1S U74 ( .A(n50), .B(n49), .Z(dst_data_o[10]) );
  ND2M1S U75 ( .A(n52), .B(n51), .Z(dst_data_o[11]) );
  ND2M1S U76 ( .A(n56), .B(n55), .Z(dst_data_o[15]) );
endmodule



    module hyperbus_BURST_WIDTH9_NR_CS2_AXI_AW32_AXI_UW1_AXI_IW10_I_cfg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32I_axi_i_AXI_BUS_in_AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 ( 
        clk_phy_i, clk_sys_i, rst_ni, cfg_i_addr, cfg_i_write, cfg_i_wdata, 
        cfg_i_wstrb, cfg_i_valid, cfg_i_rdata, cfg_i_error, cfg_i_ready, 
        axi_i_aw_id, axi_i_aw_addr, axi_i_aw_len, axi_i_aw_size, 
        axi_i_aw_burst, axi_i_aw_lock, axi_i_aw_cache, axi_i_aw_prot, 
        axi_i_aw_qos, axi_i_aw_region, axi_i_aw_user, axi_i_aw_valid, 
        axi_i_aw_ready, axi_i_w_data, axi_i_w_strb, axi_i_w_last, axi_i_w_user, 
        axi_i_w_valid, axi_i_w_ready, axi_i_b_id, axi_i_b_resp, axi_i_b_user, 
        axi_i_b_valid, axi_i_b_ready, axi_i_ar_id, axi_i_ar_addr, axi_i_ar_len, 
        axi_i_ar_size, axi_i_ar_burst, axi_i_ar_lock, axi_i_ar_cache, 
        axi_i_ar_prot, axi_i_ar_qos, axi_i_ar_region, axi_i_ar_user, 
        axi_i_ar_valid, axi_i_ar_ready, axi_i_r_id, axi_i_r_data, axi_i_r_resp, 
        axi_i_r_last, axi_i_r_user, axi_i_r_valid, axi_i_r_ready, hyper_cs_no, 
        hyper_ck_o, hyper_ck_no, hyper_rwds_o, hyper_rwds_i, hyper_rwds_oe_o, 
        hyper_dq_i, hyper_dq_o, hyper_dq_oe_o, hyper_reset_no );
  input [31:0] cfg_i_addr;
  input [31:0] cfg_i_wdata;
  input [3:0] cfg_i_wstrb;
  output [31:0] cfg_i_rdata;
  input [9:0] axi_i_aw_id;
  input [31:0] axi_i_aw_addr;
  input [7:0] axi_i_aw_len;
  input [2:0] axi_i_aw_size;
  input [1:0] axi_i_aw_burst;
  input [3:0] axi_i_aw_cache;
  input [2:0] axi_i_aw_prot;
  input [3:0] axi_i_aw_qos;
  input [3:0] axi_i_aw_region;
  input [0:0] axi_i_aw_user;
  input [15:0] axi_i_w_data;
  input [1:0] axi_i_w_strb;
  input [0:0] axi_i_w_user;
  output [9:0] axi_i_b_id;
  output [1:0] axi_i_b_resp;
  output [0:0] axi_i_b_user;
  input [9:0] axi_i_ar_id;
  input [31:0] axi_i_ar_addr;
  input [7:0] axi_i_ar_len;
  input [2:0] axi_i_ar_size;
  input [1:0] axi_i_ar_burst;
  input [3:0] axi_i_ar_cache;
  input [2:0] axi_i_ar_prot;
  input [3:0] axi_i_ar_qos;
  input [3:0] axi_i_ar_region;
  input [0:0] axi_i_ar_user;
  output [9:0] axi_i_r_id;
  output [15:0] axi_i_r_data;
  output [1:0] axi_i_r_resp;
  output [0:0] axi_i_r_user;
  output [1:0] hyper_cs_no;
  input [7:0] hyper_dq_i;
  output [7:0] hyper_dq_o;
  input clk_phy_i, clk_sys_i, rst_ni, cfg_i_write, cfg_i_valid, axi_i_aw_lock,
         axi_i_aw_valid, axi_i_w_last, axi_i_w_valid, axi_i_b_ready,
         axi_i_ar_lock, axi_i_ar_valid, axi_i_r_ready, hyper_rwds_i;
  output cfg_i_error, cfg_i_ready, axi_i_aw_ready, axi_i_w_ready,
         axi_i_b_valid, axi_i_ar_ready, axi_i_r_last, axi_i_r_valid,
         hyper_ck_o, hyper_ck_no, hyper_rwds_o, hyper_rwds_oe_o, hyper_dq_oe_o,
         hyper_reset_no;
  wire   clk0, clk90, axi_rx_valid, axi_rx_ready, axi_tx_valid, axi_tx_ready,
         axi_b_valid, axi_b_ready, axi_trans_valid, axi_trans_ready,
         axi_b_resp_last_, axi_b_resp_error_, phy_trans_valid, phy_trans_ready,
         phy_tx_valid, phy_tx_ready, phy_rx_valid, phy_rx_ready, phy_b_valid,
         phy_b_resp_last_, phy_b_resp_error_, SYNOPSYS_UNCONNECTED_1,
         SYNOPSYS_UNCONNECTED_2, SYNOPSYS_UNCONNECTED_3,
         SYNOPSYS_UNCONNECTED_4, SYNOPSYS_UNCONNECTED_5,
         SYNOPSYS_UNCONNECTED_6, SYNOPSYS_UNCONNECTED_7,
         SYNOPSYS_UNCONNECTED_8, SYNOPSYS_UNCONNECTED_9,
         SYNOPSYS_UNCONNECTED_10, SYNOPSYS_UNCONNECTED_11,
         SYNOPSYS_UNCONNECTED_12, SYNOPSYS_UNCONNECTED_13,
         SYNOPSYS_UNCONNECTED_14, SYNOPSYS_UNCONNECTED_15,
         SYNOPSYS_UNCONNECTED_16, SYNOPSYS_UNCONNECTED_17,
         SYNOPSYS_UNCONNECTED_18, SYNOPSYS_UNCONNECTED_19,
         SYNOPSYS_UNCONNECTED_20, SYNOPSYS_UNCONNECTED_21,
         SYNOPSYS_UNCONNECTED_22, SYNOPSYS_UNCONNECTED_23,
         SYNOPSYS_UNCONNECTED_24, SYNOPSYS_UNCONNECTED_25,
         SYNOPSYS_UNCONNECTED_26, SYNOPSYS_UNCONNECTED_27,
         SYNOPSYS_UNCONNECTED_28, SYNOPSYS_UNCONNECTED_29,
         SYNOPSYS_UNCONNECTED_30, SYNOPSYS_UNCONNECTED_31,
         SYNOPSYS_UNCONNECTED_32, SYNOPSYS_UNCONNECTED_33,
         SYNOPSYS_UNCONNECTED_34, SYNOPSYS_UNCONNECTED_35,
         SYNOPSYS_UNCONNECTED_36, SYNOPSYS_UNCONNECTED_37,
         SYNOPSYS_UNCONNECTED_38, SYNOPSYS_UNCONNECTED_39,
         SYNOPSYS_UNCONNECTED_40, SYNOPSYS_UNCONNECTED_41,
         SYNOPSYS_UNCONNECTED_42, SYNOPSYS_UNCONNECTED_43,
         SYNOPSYS_UNCONNECTED_44, SYNOPSYS_UNCONNECTED_45,
         SYNOPSYS_UNCONNECTED_46, SYNOPSYS_UNCONNECTED_47,
         SYNOPSYS_UNCONNECTED_48, SYNOPSYS_UNCONNECTED_49,
         SYNOPSYS_UNCONNECTED_50, SYNOPSYS_UNCONNECTED_51,
         SYNOPSYS_UNCONNECTED_52, SYNOPSYS_UNCONNECTED_53,
         SYNOPSYS_UNCONNECTED_54, SYNOPSYS_UNCONNECTED_55,
         SYNOPSYS_UNCONNECTED_56, SYNOPSYS_UNCONNECTED_57,
         SYNOPSYS_UNCONNECTED_58, SYNOPSYS_UNCONNECTED_59,
         SYNOPSYS_UNCONNECTED_60, SYNOPSYS_UNCONNECTED_61,
         SYNOPSYS_UNCONNECTED_62, SYNOPSYS_UNCONNECTED_63,
         SYNOPSYS_UNCONNECTED_64, SYNOPSYS_UNCONNECTED_65,
         SYNOPSYS_UNCONNECTED_66, SYNOPSYS_UNCONNECTED_67,
         SYNOPSYS_UNCONNECTED_68, SYNOPSYS_UNCONNECTED_69,
         SYNOPSYS_UNCONNECTED_70, SYNOPSYS_UNCONNECTED_71,
         SYNOPSYS_UNCONNECTED_72, SYNOPSYS_UNCONNECTED_73,
         SYNOPSYS_UNCONNECTED_74, SYNOPSYS_UNCONNECTED_75,
         SYNOPSYS_UNCONNECTED_76, SYNOPSYS_UNCONNECTED_77,
         SYNOPSYS_UNCONNECTED_78, SYNOPSYS_UNCONNECTED_79,
         SYNOPSYS_UNCONNECTED_80, SYNOPSYS_UNCONNECTED_81,
         SYNOPSYS_UNCONNECTED_82, SYNOPSYS_UNCONNECTED_83,
         SYNOPSYS_UNCONNECTED_84, SYNOPSYS_UNCONNECTED_85,
         SYNOPSYS_UNCONNECTED_86, SYNOPSYS_UNCONNECTED_87,
         SYNOPSYS_UNCONNECTED_88, SYNOPSYS_UNCONNECTED_89,
         SYNOPSYS_UNCONNECTED_90, SYNOPSYS_UNCONNECTED_91,
         SYNOPSYS_UNCONNECTED_92, SYNOPSYS_UNCONNECTED_93,
         SYNOPSYS_UNCONNECTED_94, SYNOPSYS_UNCONNECTED_95,
         SYNOPSYS_UNCONNECTED_96, SYNOPSYS_UNCONNECTED_97,
         SYNOPSYS_UNCONNECTED_98, SYNOPSYS_UNCONNECTED_99,
         SYNOPSYS_UNCONNECTED_100, SYNOPSYS_UNCONNECTED_101,
         SYNOPSYS_UNCONNECTED_102, SYNOPSYS_UNCONNECTED_103,
         SYNOPSYS_UNCONNECTED_104, SYNOPSYS_UNCONNECTED_105,
         SYNOPSYS_UNCONNECTED_106, SYNOPSYS_UNCONNECTED_107,
         SYNOPSYS_UNCONNECTED_108, SYNOPSYS_UNCONNECTED_109,
         SYNOPSYS_UNCONNECTED_110, SYNOPSYS_UNCONNECTED_111,
         SYNOPSYS_UNCONNECTED_112, SYNOPSYS_UNCONNECTED_113,
         SYNOPSYS_UNCONNECTED_114, SYNOPSYS_UNCONNECTED_115;
  wire   [31:0] config_t_latency_access;
  wire   [3:0] config_t_latency_additional;
  wire   [15:0] config_t_cs_max;
  wire   [3:0] config_t_read_write_recovery;
  wire   [126:0] config_addr_mapping;
  wire   [45:0] axi_trans;
  wire   [17:0] axi_tx;
  wire   [17:0] axi_rx;
  wire   [17:0] phy_rx;
  wire   [17:0] phy_tx;
  wire   [45:0] phy_trans;

  clk_gen ddr_clk ( .clk_i(clk_phy_i), .rst_ni(rst_ni), .clk0_o(clk0), 
        .clk90_o(clk90), .clk180_o(SYNOPSYS_UNCONNECTED_1), .clk270_o(
        SYNOPSYS_UNCONNECTED_2) );
  config_registers_I_cfg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32 config_registers_i ( 
        .clk_i(clk_sys_i), .rst_ni(rst_ni), .cfg_i_addr({cfg_i_addr[31:2], 
        1'b0, 1'b0}), .cfg_i_write(cfg_i_write), .cfg_i_wdata(cfg_i_wdata), 
        .cfg_i_wstrb(cfg_i_wstrb), .cfg_i_valid(cfg_i_valid), .cfg_i_rdata(
        cfg_i_rdata), .cfg_i_error(cfg_i_error), .cfg_i_ready(
        SYNOPSYS_UNCONNECTED_3), .config_t_latency_access(
        config_t_latency_access), .config_t_latency_additional({
        SYNOPSYS_UNCONNECTED_4, SYNOPSYS_UNCONNECTED_5, SYNOPSYS_UNCONNECTED_6, 
        SYNOPSYS_UNCONNECTED_7, SYNOPSYS_UNCONNECTED_8, SYNOPSYS_UNCONNECTED_9, 
        SYNOPSYS_UNCONNECTED_10, SYNOPSYS_UNCONNECTED_11, 
        SYNOPSYS_UNCONNECTED_12, SYNOPSYS_UNCONNECTED_13, 
        SYNOPSYS_UNCONNECTED_14, SYNOPSYS_UNCONNECTED_15, 
        SYNOPSYS_UNCONNECTED_16, SYNOPSYS_UNCONNECTED_17, 
        SYNOPSYS_UNCONNECTED_18, SYNOPSYS_UNCONNECTED_19, 
        SYNOPSYS_UNCONNECTED_20, SYNOPSYS_UNCONNECTED_21, 
        SYNOPSYS_UNCONNECTED_22, SYNOPSYS_UNCONNECTED_23, 
        SYNOPSYS_UNCONNECTED_24, SYNOPSYS_UNCONNECTED_25, 
        SYNOPSYS_UNCONNECTED_26, SYNOPSYS_UNCONNECTED_27, 
        SYNOPSYS_UNCONNECTED_28, SYNOPSYS_UNCONNECTED_29, 
        SYNOPSYS_UNCONNECTED_30, SYNOPSYS_UNCONNECTED_31, 
        config_t_latency_additional}), .config_t_cs_max({
        SYNOPSYS_UNCONNECTED_32, SYNOPSYS_UNCONNECTED_33, 
        SYNOPSYS_UNCONNECTED_34, SYNOPSYS_UNCONNECTED_35, 
        SYNOPSYS_UNCONNECTED_36, SYNOPSYS_UNCONNECTED_37, 
        SYNOPSYS_UNCONNECTED_38, SYNOPSYS_UNCONNECTED_39, 
        SYNOPSYS_UNCONNECTED_40, SYNOPSYS_UNCONNECTED_41, 
        SYNOPSYS_UNCONNECTED_42, SYNOPSYS_UNCONNECTED_43, 
        SYNOPSYS_UNCONNECTED_44, SYNOPSYS_UNCONNECTED_45, 
        SYNOPSYS_UNCONNECTED_46, SYNOPSYS_UNCONNECTED_47, config_t_cs_max}), 
        .config_t_read_write_recovery({SYNOPSYS_UNCONNECTED_48, 
        SYNOPSYS_UNCONNECTED_49, SYNOPSYS_UNCONNECTED_50, 
        SYNOPSYS_UNCONNECTED_51, SYNOPSYS_UNCONNECTED_52, 
        SYNOPSYS_UNCONNECTED_53, SYNOPSYS_UNCONNECTED_54, 
        SYNOPSYS_UNCONNECTED_55, SYNOPSYS_UNCONNECTED_56, 
        SYNOPSYS_UNCONNECTED_57, SYNOPSYS_UNCONNECTED_58, 
        SYNOPSYS_UNCONNECTED_59, SYNOPSYS_UNCONNECTED_60, 
        SYNOPSYS_UNCONNECTED_61, SYNOPSYS_UNCONNECTED_62, 
        SYNOPSYS_UNCONNECTED_63, SYNOPSYS_UNCONNECTED_64, 
        SYNOPSYS_UNCONNECTED_65, SYNOPSYS_UNCONNECTED_66, 
        SYNOPSYS_UNCONNECTED_67, SYNOPSYS_UNCONNECTED_68, 
        SYNOPSYS_UNCONNECTED_69, SYNOPSYS_UNCONNECTED_70, 
        SYNOPSYS_UNCONNECTED_71, SYNOPSYS_UNCONNECTED_72, 
        SYNOPSYS_UNCONNECTED_73, SYNOPSYS_UNCONNECTED_74, 
        SYNOPSYS_UNCONNECTED_75, config_t_read_write_recovery}), 
        .config_t_rwds_delay_line({SYNOPSYS_UNCONNECTED_76, 
        SYNOPSYS_UNCONNECTED_77, SYNOPSYS_UNCONNECTED_78, 
        SYNOPSYS_UNCONNECTED_79, SYNOPSYS_UNCONNECTED_80, 
        SYNOPSYS_UNCONNECTED_81, SYNOPSYS_UNCONNECTED_82, 
        SYNOPSYS_UNCONNECTED_83, SYNOPSYS_UNCONNECTED_84, 
        SYNOPSYS_UNCONNECTED_85, SYNOPSYS_UNCONNECTED_86, 
        SYNOPSYS_UNCONNECTED_87, SYNOPSYS_UNCONNECTED_88, 
        SYNOPSYS_UNCONNECTED_89, SYNOPSYS_UNCONNECTED_90, 
        SYNOPSYS_UNCONNECTED_91, SYNOPSYS_UNCONNECTED_92, 
        SYNOPSYS_UNCONNECTED_93, SYNOPSYS_UNCONNECTED_94, 
        SYNOPSYS_UNCONNECTED_95, SYNOPSYS_UNCONNECTED_96, 
        SYNOPSYS_UNCONNECTED_97, SYNOPSYS_UNCONNECTED_98, 
        SYNOPSYS_UNCONNECTED_99, SYNOPSYS_UNCONNECTED_100, 
        SYNOPSYS_UNCONNECTED_101, SYNOPSYS_UNCONNECTED_102, 
        SYNOPSYS_UNCONNECTED_103, SYNOPSYS_UNCONNECTED_104, 
        SYNOPSYS_UNCONNECTED_105, SYNOPSYS_UNCONNECTED_106, 
        SYNOPSYS_UNCONNECTED_107}), .config_addr_mapping({
        SYNOPSYS_UNCONNECTED_108, config_addr_mapping[126:96], 
        SYNOPSYS_UNCONNECTED_109, config_addr_mapping[94:64], 
        SYNOPSYS_UNCONNECTED_110, config_addr_mapping[62:32], 
        SYNOPSYS_UNCONNECTED_111, config_addr_mapping[30:0]}) );
  hyperbus_axi_BURST_WIDTH9_NR_CS2_AXI_IW10_I_axi_i_AXI_BUS_in_AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 axi2phy_i ( 
        .clk_i(clk_sys_i), .rst_ni(rst_ni), .config_addr_mapping({1'b0, 
        config_addr_mapping[126:96], 1'b0, config_addr_mapping[94:64], 1'b0, 
        config_addr_mapping[62:32], 1'b0, config_addr_mapping[30:0]}), 
        .axi_i_aw_id(axi_i_aw_id), .axi_i_aw_addr(axi_i_aw_addr), 
        .axi_i_aw_len(axi_i_aw_len), .axi_i_aw_size({1'b0, 1'b0, 1'b0}), 
        .axi_i_aw_burst({1'b0, axi_i_aw_burst[0]}), .axi_i_aw_lock(1'b0), 
        .axi_i_aw_cache({1'b0, 1'b0, 1'b0, 1'b0}), .axi_i_aw_prot({1'b0, 1'b0, 
        1'b0}), .axi_i_aw_qos({1'b0, 1'b0, 1'b0, 1'b0}), .axi_i_aw_region({
        1'b0, 1'b0, 1'b0, 1'b0}), .axi_i_aw_user(1'b0), .axi_i_aw_valid(
        axi_i_aw_valid), .axi_i_aw_ready(axi_i_aw_ready), .axi_i_w_data(
        axi_i_w_data), .axi_i_w_strb(axi_i_w_strb), .axi_i_w_last(axi_i_w_last), .axi_i_w_user(1'b0), .axi_i_w_valid(axi_i_w_valid), .axi_i_w_ready(
        axi_i_w_ready), .axi_i_b_id(axi_i_b_id), .axi_i_b_resp(axi_i_b_resp), 
        .axi_i_b_user(SYNOPSYS_UNCONNECTED_112), .axi_i_b_valid(axi_i_b_valid), 
        .axi_i_b_ready(axi_i_b_ready), .axi_i_ar_id(axi_i_ar_id), 
        .axi_i_ar_addr(axi_i_ar_addr), .axi_i_ar_len(axi_i_ar_len), 
        .axi_i_ar_size({1'b0, 1'b0, 1'b0}), .axi_i_ar_burst({1'b0, 
        axi_i_ar_burst[0]}), .axi_i_ar_lock(1'b0), .axi_i_ar_cache({1'b0, 1'b0, 
        1'b0, 1'b0}), .axi_i_ar_prot({1'b0, 1'b0, 1'b0}), .axi_i_ar_qos({1'b0, 
        1'b0, 1'b0, 1'b0}), .axi_i_ar_region({1'b0, 1'b0, 1'b0, 1'b0}), 
        .axi_i_ar_user(1'b0), .axi_i_ar_valid(axi_i_ar_valid), 
        .axi_i_ar_ready(axi_i_ar_ready), .axi_i_r_id(axi_i_r_id), 
        .axi_i_r_data(axi_i_r_data), .axi_i_r_resp(axi_i_r_resp), 
        .axi_i_r_last(axi_i_r_last), .axi_i_r_user(SYNOPSYS_UNCONNECTED_113), 
        .axi_i_r_valid(axi_i_r_valid), .axi_i_r_ready(axi_i_r_ready), 
        .rx_data_i(axi_rx[15:0]), .rx_last_i(axi_rx[17]), .rx_error_i(
        axi_rx[16]), .rx_valid_i(axi_rx_valid), .rx_ready_o(axi_rx_ready), 
        .tx_data_o(axi_tx[17:2]), .tx_strb_o(axi_tx[1:0]), .tx_valid_o(
        axi_tx_valid), .tx_ready_i(axi_tx_ready), .b_valid_i(axi_b_valid), 
        .b_ready_o(axi_b_ready), .b_last_i(axi_b_resp_last_), .b_error_i(
        axi_b_resp_error_), .trans_valid_o(axi_trans_valid), .trans_ready_i(
        axi_trans_ready), .trans_address_o(axi_trans[31:0]), .trans_cs_o(
        axi_trans[45:44]), .trans_write_o(axi_trans[43]), .trans_burst_o(
        axi_trans[42:34]), .trans_burst_type_o(axi_trans[33]), 
        .trans_address_space_o(axi_trans[32]) );
  hyperbus_phy_BURST_WIDTH9_NR_CS2 phy_i ( .clk0(clk0), .clk90(clk90), 
        .rst_ni(rst_ni), .config_t_latency_access(config_t_latency_access), 
        .config_t_latency_additional({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        config_t_latency_additional}), .config_t_cs_max({1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, config_t_cs_max}), .config_t_read_write_recovery({1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, config_t_read_write_recovery}), .config_t_rwds_delay_line(
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}), 
        .trans_valid_i(phy_trans_valid), .trans_ready_o(phy_trans_ready), 
        .trans_address_i(phy_trans[31:0]), .trans_cs_i(phy_trans[45:44]), 
        .trans_write_i(phy_trans[43]), .trans_burst_i(phy_trans[42:34]), 
        .trans_burst_type_i(phy_trans[33]), .trans_address_space_i(
        phy_trans[32]), .tx_valid_i(phy_tx_valid), .tx_ready_o(phy_tx_ready), 
        .tx_data_i(phy_tx[17:2]), .tx_strb_i(phy_tx[1:0]), .rx_valid_o(
        phy_rx_valid), .rx_ready_i(phy_rx_ready), .rx_data_o(phy_rx[15:0]), 
        .rx_last_o(phy_rx[17]), .rx_error_o(phy_rx[16]), .b_valid_o(
        phy_b_valid), .b_last_o(phy_b_resp_last_), .b_error_o(
        phy_b_resp_error_), .hyper_cs_no(hyper_cs_no), .hyper_ck_o(hyper_ck_o), 
        .hyper_ck_no(hyper_ck_no), .hyper_rwds_o(hyper_rwds_o), .hyper_rwds_i(
        hyper_rwds_i), .hyper_rwds_oe_o(hyper_rwds_oe_o), .hyper_dq_i(
        hyper_dq_i), .hyper_dq_o(hyper_dq_o), .hyper_dq_oe_o(hyper_dq_oe_o), 
        .hyper_reset_no(SYNOPSYS_UNCONNECTED_114) );
  cdc_2phase_645242 i_cdc_2phase_trans_signals ( .src_rst_ni(rst_ni), 
        .src_clk_i(clk_sys_i), .src_data_i(axi_trans), .src_valid_i(
        axi_trans_valid), .src_ready_o(axi_trans_ready), .dst_rst_ni(rst_ni), 
        .dst_clk_i(clk0), .dst_data_o(phy_trans), .dst_valid_o(phy_trans_valid), .dst_ready_i(phy_trans_ready) );
  cdc_2phase_121242 i_cdc_2phase_b_resp ( .src_rst_ni(rst_ni), .src_clk_i(clk0), .src_valid_i(phy_b_valid), .src_ready_o(SYNOPSYS_UNCONNECTED_115), 
        .dst_rst_ni(rst_ni), .dst_clk_i(clk_sys_i), .dst_valid_o(axi_b_valid), 
        .dst_ready_i(axi_b_ready), .src_data_i_last_(phy_b_resp_last_), 
        .src_data_i_error_(phy_b_resp_error_), .dst_data_o_last_(
        axi_b_resp_last_), .dst_data_o_error_(axi_b_resp_error_) );
  cdc_fifo_gray_LOG_DEPTH2 i_cdc_TX_fifo ( .src_rst_ni(rst_ni), .src_clk_i(
        clk_sys_i), .src_data_i(axi_tx), .src_valid_i(axi_tx_valid), 
        .src_ready_o(axi_tx_ready), .dst_rst_ni(rst_ni), .dst_clk_i(clk0), 
        .dst_data_o(phy_tx), .dst_valid_o(phy_tx_valid), .dst_ready_i(
        phy_tx_ready) );
  cdc_fifo_gray_LOG_DEPTH2_1 i_cdc_RX_fifo ( .src_rst_ni(rst_ni), .src_clk_i(
        clk0), .src_data_i(phy_rx), .src_valid_i(phy_rx_valid), .src_ready_o(
        phy_rx_ready), .dst_rst_ni(rst_ni), .dst_clk_i(clk_sys_i), 
        .dst_data_o(axi_rx), .dst_valid_o(axi_rx_valid), .dst_ready_i(
        axi_rx_ready) );
endmodule



    module hyperbus_macro_BURST_WIDTH9_NR_CS2_AXI_AW32_AXI_UW1_AXI_IW10_I_cfg_i_REG_BUS__ADDR_WIDTH_32_DATA_WIDTH_32I_axi_i_AXI_BUS__AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 ( 
        clk_phy_i, clk_sys_i, rst_ni, cfg_i_clk_i, cfg_i_addr, cfg_i_write, 
        cfg_i_rdata, cfg_i_wdata, cfg_i_wstrb, cfg_i_error, cfg_i_valid, 
        cfg_i_ready, axi_i_clk_i, axi_i_aw_id, axi_i_aw_addr, axi_i_aw_len, 
        axi_i_aw_size, axi_i_aw_burst, axi_i_aw_lock, axi_i_aw_cache, 
        axi_i_aw_prot, axi_i_aw_qos, axi_i_aw_region, axi_i_aw_user, 
        axi_i_aw_valid, axi_i_aw_ready, axi_i_w_data, axi_i_w_strb, 
        axi_i_w_last, axi_i_w_user, axi_i_w_valid, axi_i_w_ready, axi_i_b_id, 
        axi_i_b_resp, axi_i_b_user, axi_i_b_valid, axi_i_b_ready, axi_i_ar_id, 
        axi_i_ar_addr, axi_i_ar_len, axi_i_ar_size, axi_i_ar_burst, 
        axi_i_ar_lock, axi_i_ar_cache, axi_i_ar_prot, axi_i_ar_qos, 
        axi_i_ar_region, axi_i_ar_user, axi_i_ar_valid, axi_i_ar_ready, 
        axi_i_r_id, axi_i_r_data, axi_i_r_resp, axi_i_r_last, axi_i_r_user, 
        axi_i_r_valid, axi_i_r_ready, hyper_reset_no, hyper_cs_no, hyper_ck_o, 
        hyper_ck_no, hyper_rwds_io, hyper_dq_io );
  input [31:0] cfg_i_addr;
  output [31:0] cfg_i_rdata;
  input [31:0] cfg_i_wdata;
  input [3:0] cfg_i_wstrb;
  input [9:0] axi_i_aw_id;
  input [31:0] axi_i_aw_addr;
  input [7:0] axi_i_aw_len;
  input [2:0] axi_i_aw_size;
  input [1:0] axi_i_aw_burst;
  input [3:0] axi_i_aw_cache;
  input [2:0] axi_i_aw_prot;
  input [3:0] axi_i_aw_qos;
  input [3:0] axi_i_aw_region;
  input [0:0] axi_i_aw_user;
  input [15:0] axi_i_w_data;
  input [1:0] axi_i_w_strb;
  input [0:0] axi_i_w_user;
  output [9:0] axi_i_b_id;
  output [1:0] axi_i_b_resp;
  output [0:0] axi_i_b_user;
  input [9:0] axi_i_ar_id;
  input [31:0] axi_i_ar_addr;
  input [7:0] axi_i_ar_len;
  input [2:0] axi_i_ar_size;
  input [1:0] axi_i_ar_burst;
  input [3:0] axi_i_ar_cache;
  input [2:0] axi_i_ar_prot;
  input [3:0] axi_i_ar_qos;
  input [3:0] axi_i_ar_region;
  input [0:0] axi_i_ar_user;
  output [9:0] axi_i_r_id;
  output [15:0] axi_i_r_data;
  output [1:0] axi_i_r_resp;
  output [0:0] axi_i_r_user;
  output [1:0] hyper_cs_no;
  inout [7:0] hyper_dq_io;
  input clk_phy_i, clk_sys_i, rst_ni, cfg_i_clk_i, cfg_i_write, cfg_i_valid,
         axi_i_clk_i, axi_i_aw_lock, axi_i_aw_valid, axi_i_w_last,
         axi_i_w_valid, axi_i_b_ready, axi_i_ar_lock, axi_i_ar_valid,
         axi_i_r_ready;
  output cfg_i_error, cfg_i_ready, axi_i_aw_ready, axi_i_w_ready,
         axi_i_b_valid, axi_i_ar_ready, axi_i_r_last, axi_i_r_valid,
         hyper_reset_no;
  inout hyper_ck_o,  hyper_ck_no,  hyper_rwds_io;
  wire   hyper_ck_no_inner, hyper_ck_o_inner, hyper_rwds_o, hyper_rwds_i,
         hyper_rwds_oe_o, hyper_dq_oe_o, SYNOPSYS_UNCONNECTED_1,
         SYNOPSYS_UNCONNECTED_2, SYNOPSYS_UNCONNECTED_3,
         SYNOPSYS_UNCONNECTED_4, SYNOPSYS_UNCONNECTED_5,
         SYNOPSYS_UNCONNECTED_6, SYNOPSYS_UNCONNECTED_7,
         SYNOPSYS_UNCONNECTED_8, SYNOPSYS_UNCONNECTED_9,
         SYNOPSYS_UNCONNECTED_10, SYNOPSYS_UNCONNECTED_11,
         SYNOPSYS_UNCONNECTED_12, SYNOPSYS_UNCONNECTED_13,
         SYNOPSYS_UNCONNECTED_14, SYNOPSYS_UNCONNECTED_15,
         SYNOPSYS_UNCONNECTED_16, SYNOPSYS_UNCONNECTED_17,
         SYNOPSYS_UNCONNECTED_18, SYNOPSYS_UNCONNECTED_19,
         SYNOPSYS_UNCONNECTED_20, SYNOPSYS_UNCONNECTED_21,
         SYNOPSYS_UNCONNECTED_22, SYNOPSYS_UNCONNECTED_23,
         SYNOPSYS_UNCONNECTED_24, SYNOPSYS_UNCONNECTED_25,
         SYNOPSYS_UNCONNECTED_26, SYNOPSYS_UNCONNECTED_27,
         SYNOPSYS_UNCONNECTED_28, SYNOPSYS_UNCONNECTED_29,
         SYNOPSYS_UNCONNECTED_30, SYNOPSYS_UNCONNECTED_31,
         SYNOPSYS_UNCONNECTED_32, SYNOPSYS_UNCONNECTED_33,
         SYNOPSYS_UNCONNECTED_34, SYNOPSYS_UNCONNECTED_35,
         SYNOPSYS_UNCONNECTED_36, SYNOPSYS_UNCONNECTED_37,
         SYNOPSYS_UNCONNECTED_38, SYNOPSYS_UNCONNECTED_39,
         SYNOPSYS_UNCONNECTED_40, SYNOPSYS_UNCONNECTED_41,
         SYNOPSYS_UNCONNECTED_42, SYNOPSYS_UNCONNECTED_43,
         SYNOPSYS_UNCONNECTED_44, SYNOPSYS_UNCONNECTED_45,
         SYNOPSYS_UNCONNECTED_46, SYNOPSYS_UNCONNECTED_47,
         SYNOPSYS_UNCONNECTED_48, SYNOPSYS_UNCONNECTED_49,
         SYNOPSYS_UNCONNECTED_50;
  wire   [7:0] hyper_dq_o;
  wire   [7:0] hyper_dq_i;

  IUMB pad_hyper_ck_no ( .DO(hyper_ck_no_inner), .OE(1'b1), .PAD(hyper_ck_no), 
        .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_1), .VDDIO(SYNOPSYS_UNCONNECTED_2), 
        .VSS(SYNOPSYS_UNCONNECTED_3), .VSSIO(SYNOPSYS_UNCONNECTED_4), .DI(
        SYNOPSYS_UNCONNECTED_5) );
  IUMB pad_hyper_ck_o ( .DO(hyper_ck_o_inner), .OE(1'b1), .PAD(hyper_ck_o), 
        .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_6), .VDDIO(SYNOPSYS_UNCONNECTED_7), 
        .VSS(SYNOPSYS_UNCONNECTED_8), .VSSIO(SYNOPSYS_UNCONNECTED_9), .DI(
        SYNOPSYS_UNCONNECTED_10) );
  IUMB pad_hyper_rwds_io ( .DO(hyper_rwds_o), .OE(hyper_rwds_oe_o), .PAD(
        hyper_rwds_io), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), .PU(
        1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_11), .VDDIO(
        SYNOPSYS_UNCONNECTED_12), .VSS(SYNOPSYS_UNCONNECTED_13), .VSSIO(
        SYNOPSYS_UNCONNECTED_14), .DI(hyper_rwds_i) );
  IUMB pad_hyper_dq_io_0 ( .DO(hyper_dq_o[0]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[0]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_15), 
        .VDDIO(SYNOPSYS_UNCONNECTED_16), .VSS(SYNOPSYS_UNCONNECTED_17), 
        .VSSIO(SYNOPSYS_UNCONNECTED_18), .DI(hyper_dq_i[0]) );
  IUMB pad_hyper_dq_io_1 ( .DO(hyper_dq_o[1]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[1]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_19), 
        .VDDIO(SYNOPSYS_UNCONNECTED_20), .VSS(SYNOPSYS_UNCONNECTED_21), 
        .VSSIO(SYNOPSYS_UNCONNECTED_22), .DI(hyper_dq_i[1]) );
  IUMB pad_hyper_dq_io_2 ( .DO(hyper_dq_o[2]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[2]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_23), 
        .VDDIO(SYNOPSYS_UNCONNECTED_24), .VSS(SYNOPSYS_UNCONNECTED_25), 
        .VSSIO(SYNOPSYS_UNCONNECTED_26), .DI(hyper_dq_i[2]) );
  IUMB pad_hyper_dq_io_3 ( .DO(hyper_dq_o[3]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[3]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_27), 
        .VDDIO(SYNOPSYS_UNCONNECTED_28), .VSS(SYNOPSYS_UNCONNECTED_29), 
        .VSSIO(SYNOPSYS_UNCONNECTED_30), .DI(hyper_dq_i[3]) );
  IUMB pad_hyper_dq_io_4 ( .DO(hyper_dq_o[4]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[4]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_31), 
        .VDDIO(SYNOPSYS_UNCONNECTED_32), .VSS(SYNOPSYS_UNCONNECTED_33), 
        .VSSIO(SYNOPSYS_UNCONNECTED_34), .DI(hyper_dq_i[4]) );
  IUMB pad_hyper_dq_io_5 ( .DO(hyper_dq_o[5]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[5]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_35), 
        .VDDIO(SYNOPSYS_UNCONNECTED_36), .VSS(SYNOPSYS_UNCONNECTED_37), 
        .VSSIO(SYNOPSYS_UNCONNECTED_38), .DI(hyper_dq_i[5]) );
  IUMB pad_hyper_dq_io_6 ( .DO(hyper_dq_o[6]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[6]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_39), 
        .VDDIO(SYNOPSYS_UNCONNECTED_40), .VSS(SYNOPSYS_UNCONNECTED_41), 
        .VSSIO(SYNOPSYS_UNCONNECTED_42), .DI(hyper_dq_i[6]) );
  IUMB pad_hyper_dq_io_7 ( .DO(hyper_dq_o[7]), .OE(hyper_dq_oe_o), .PAD(
        hyper_dq_io[7]), .IDDQ(1'b0), .PD(1'b0), .PIN1(1'b1), .PIN2(1'b1), 
        .PU(1'b0), .SMT(1'b0), .SR(1'b1), .VDD(SYNOPSYS_UNCONNECTED_43), 
        .VDDIO(SYNOPSYS_UNCONNECTED_44), .VSS(SYNOPSYS_UNCONNECTED_45), 
        .VSSIO(SYNOPSYS_UNCONNECTED_46), .DI(hyper_dq_i[7]) );
  hyperbus_BURST_WIDTH9_NR_CS2_AXI_AW32_AXI_UW1_AXI_IW10_I_cfg_i_REG_BUS_in_ADDR_WIDTH_32_DATA_WIDTH_32I_axi_i_AXI_BUS_in_AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 i_hyperbus ( 
        .clk_phy_i(clk_phy_i), .clk_sys_i(clk_sys_i), .rst_ni(rst_ni), 
        .cfg_i_addr({cfg_i_addr[31:2], 1'b0, 1'b0}), .cfg_i_write(cfg_i_write), 
        .cfg_i_wdata(cfg_i_wdata), .cfg_i_wstrb(cfg_i_wstrb), .cfg_i_valid(
        cfg_i_valid), .cfg_i_rdata(cfg_i_rdata), .cfg_i_error(cfg_i_error), 
        .cfg_i_ready(SYNOPSYS_UNCONNECTED_47), .axi_i_aw_id(axi_i_aw_id), 
        .axi_i_aw_addr(axi_i_aw_addr), .axi_i_aw_len(axi_i_aw_len), 
        .axi_i_aw_size({1'b0, 1'b0, 1'b0}), .axi_i_aw_burst({1'b0, 
        axi_i_aw_burst[0]}), .axi_i_aw_lock(1'b0), .axi_i_aw_cache({1'b0, 1'b0, 
        1'b0, 1'b0}), .axi_i_aw_prot({1'b0, 1'b0, 1'b0}), .axi_i_aw_qos({1'b0, 
        1'b0, 1'b0, 1'b0}), .axi_i_aw_region({1'b0, 1'b0, 1'b0, 1'b0}), 
        .axi_i_aw_user(1'b0), .axi_i_aw_valid(axi_i_aw_valid), 
        .axi_i_aw_ready(axi_i_aw_ready), .axi_i_w_data(axi_i_w_data), 
        .axi_i_w_strb(axi_i_w_strb), .axi_i_w_last(axi_i_w_last), 
        .axi_i_w_user(1'b0), .axi_i_w_valid(axi_i_w_valid), .axi_i_w_ready(
        axi_i_w_ready), .axi_i_b_id(axi_i_b_id), .axi_i_b_resp(axi_i_b_resp), 
        .axi_i_b_user(SYNOPSYS_UNCONNECTED_48), .axi_i_b_valid(axi_i_b_valid), 
        .axi_i_b_ready(axi_i_b_ready), .axi_i_ar_id(axi_i_ar_id), 
        .axi_i_ar_addr(axi_i_ar_addr), .axi_i_ar_len(axi_i_ar_len), 
        .axi_i_ar_size({1'b0, 1'b0, 1'b0}), .axi_i_ar_burst({1'b0, 
        axi_i_ar_burst[0]}), .axi_i_ar_lock(1'b0), .axi_i_ar_cache({1'b0, 1'b0, 
        1'b0, 1'b0}), .axi_i_ar_prot({1'b0, 1'b0, 1'b0}), .axi_i_ar_qos({1'b0, 
        1'b0, 1'b0, 1'b0}), .axi_i_ar_region({1'b0, 1'b0, 1'b0, 1'b0}), 
        .axi_i_ar_user(1'b0), .axi_i_ar_valid(axi_i_ar_valid), 
        .axi_i_ar_ready(axi_i_ar_ready), .axi_i_r_id(axi_i_r_id), 
        .axi_i_r_data(axi_i_r_data), .axi_i_r_resp(axi_i_r_resp), 
        .axi_i_r_last(axi_i_r_last), .axi_i_r_user(SYNOPSYS_UNCONNECTED_49), 
        .axi_i_r_valid(axi_i_r_valid), .axi_i_r_ready(axi_i_r_ready), 
        .hyper_cs_no(hyper_cs_no), .hyper_ck_o(hyper_ck_o_inner), 
        .hyper_ck_no(hyper_ck_no_inner), .hyper_rwds_o(hyper_rwds_o), 
        .hyper_rwds_i(hyper_rwds_i), .hyper_rwds_oe_o(hyper_rwds_oe_o), 
        .hyper_dq_i(hyper_dq_i), .hyper_dq_o(hyper_dq_o), .hyper_dq_oe_o(
        hyper_dq_oe_o), .hyper_reset_no(SYNOPSYS_UNCONNECTED_50) );
endmodule


module hyperbus_macro_inflate ( clk_phy_i, clk_sys_i, rst_ni, cfg_i_addr, 
        cfg_i_write, cfg_i_wdata, cfg_i_wstrb, cfg_i_valid, cfg_i_rdata, 
        cfg_i_error, cfg_i_ready, axi_i_aw_id, axi_i_aw_addr, axi_i_aw_len, 
        axi_i_aw_size, axi_i_aw_burst, axi_i_aw_lock, axi_i_aw_cache, 
        axi_i_aw_prot, axi_i_aw_qos, axi_i_aw_region, axi_i_aw_user, 
        axi_i_aw_valid, axi_i_aw_ready, axi_i_w_data, axi_i_w_strb, 
        axi_i_w_last, axi_i_w_user, axi_i_w_valid, axi_i_w_ready, axi_i_b_id, 
        axi_i_b_resp, axi_i_b_user, axi_i_b_valid, axi_i_b_ready, axi_i_ar_id, 
        axi_i_ar_addr, axi_i_ar_len, axi_i_ar_size, axi_i_ar_burst, 
        axi_i_ar_lock, axi_i_ar_cache, axi_i_ar_prot, axi_i_ar_qos, 
        axi_i_ar_region, axi_i_ar_user, axi_i_ar_valid, axi_i_ar_ready, 
        axi_i_r_id, axi_i_r_data, axi_i_r_resp, axi_i_r_last, axi_i_r_user, 
        axi_i_r_valid, axi_i_r_ready, hyper_reset_no, hyper_cs_no, hyper_ck_o, 
        hyper_ck_no, hyper_rwds_io, hyper_dq_io );
  input [31:0] cfg_i_addr;
  input [31:0] cfg_i_wdata;
  input [3:0] cfg_i_wstrb;
  output [31:0] cfg_i_rdata;
  input [9:0] axi_i_aw_id;
  input [31:0] axi_i_aw_addr;
  input [7:0] axi_i_aw_len;
  input [2:0] axi_i_aw_size;
  input [1:0] axi_i_aw_burst;
  input [3:0] axi_i_aw_cache;
  input [2:0] axi_i_aw_prot;
  input [3:0] axi_i_aw_qos;
  input [3:0] axi_i_aw_region;
  input [0:0] axi_i_aw_user;
  input [15:0] axi_i_w_data;
  input [1:0] axi_i_w_strb;
  input [0:0] axi_i_w_user;
  output [9:0] axi_i_b_id;
  output [1:0] axi_i_b_resp;
  output [0:0] axi_i_b_user;
  input [9:0] axi_i_ar_id;
  input [31:0] axi_i_ar_addr;
  input [7:0] axi_i_ar_len;
  input [2:0] axi_i_ar_size;
  input [1:0] axi_i_ar_burst;
  input [3:0] axi_i_ar_cache;
  input [2:0] axi_i_ar_prot;
  input [3:0] axi_i_ar_qos;
  input [3:0] axi_i_ar_region;
  input [0:0] axi_i_ar_user;
  output [9:0] axi_i_r_id;
  output [15:0] axi_i_r_data;
  output [1:0] axi_i_r_resp;
  output [0:0] axi_i_r_user;
  output [1:0] hyper_cs_no;
  inout [7:0] hyper_dq_io;
  input clk_phy_i, clk_sys_i, rst_ni, cfg_i_write, cfg_i_valid, axi_i_aw_lock,
         axi_i_aw_valid, axi_i_w_last, axi_i_w_valid, axi_i_b_ready,
         axi_i_ar_lock, axi_i_ar_valid, axi_i_r_ready;
  output cfg_i_error, cfg_i_ready, axi_i_aw_ready, axi_i_w_ready,
         axi_i_b_valid, axi_i_ar_ready, axi_i_r_last, axi_i_r_valid,
         hyper_reset_no;
  inout hyper_ck_o,  hyper_ck_no,  hyper_rwds_io;
  wire   SYNOPSYS_UNCONNECTED_1, SYNOPSYS_UNCONNECTED_2,
         SYNOPSYS_UNCONNECTED_3, SYNOPSYS_UNCONNECTED_4;
  assign hyper_reset_no = 1'b1;
  assign cfg_i_ready = 1'b1;
  assign axi_i_b_user[0] = 1'b0;
  assign axi_i_r_user[0] = 1'b0;

  hyperbus_macro_BURST_WIDTH9_NR_CS2_AXI_AW32_AXI_UW1_AXI_IW10_I_cfg_i_REG_BUS__ADDR_WIDTH_32_DATA_WIDTH_32I_axi_i_AXI_BUS__AXI_ADDR_WIDTH_32_AXI_DATA_WIDTH_16_AXI_ID_WIDTH_10_AXI_USER_WIDTH_1 i_deflate ( 
        .clk_phy_i(clk_phy_i), .clk_sys_i(clk_sys_i), .rst_ni(rst_ni), 
        .cfg_i_clk_i(1'b0), .cfg_i_addr({cfg_i_addr[31:2], 1'b0, 1'b0}), 
        .cfg_i_write(cfg_i_write), .cfg_i_rdata(cfg_i_rdata), .cfg_i_wdata(
        cfg_i_wdata), .cfg_i_wstrb(cfg_i_wstrb), .cfg_i_error(cfg_i_error), 
        .cfg_i_valid(cfg_i_valid), .cfg_i_ready(SYNOPSYS_UNCONNECTED_1), 
        .axi_i_clk_i(1'b0), .axi_i_aw_id(axi_i_aw_id), .axi_i_aw_addr(
        axi_i_aw_addr), .axi_i_aw_len(axi_i_aw_len), .axi_i_aw_size({1'b0, 
        1'b0, 1'b0}), .axi_i_aw_burst({1'b0, axi_i_aw_burst[0]}), 
        .axi_i_aw_lock(1'b0), .axi_i_aw_cache({1'b0, 1'b0, 1'b0, 1'b0}), 
        .axi_i_aw_prot({1'b0, 1'b0, 1'b0}), .axi_i_aw_qos({1'b0, 1'b0, 1'b0, 
        1'b0}), .axi_i_aw_region({1'b0, 1'b0, 1'b0, 1'b0}), .axi_i_aw_user(
        1'b0), .axi_i_aw_valid(axi_i_aw_valid), .axi_i_aw_ready(axi_i_aw_ready), .axi_i_w_data(axi_i_w_data), .axi_i_w_strb(axi_i_w_strb), .axi_i_w_last(
        axi_i_w_last), .axi_i_w_user(1'b0), .axi_i_w_valid(axi_i_w_valid), 
        .axi_i_w_ready(axi_i_w_ready), .axi_i_b_id(axi_i_b_id), .axi_i_b_resp(
        axi_i_b_resp), .axi_i_b_user(SYNOPSYS_UNCONNECTED_2), .axi_i_b_valid(
        axi_i_b_valid), .axi_i_b_ready(axi_i_b_ready), .axi_i_ar_id(
        axi_i_ar_id), .axi_i_ar_addr(axi_i_ar_addr), .axi_i_ar_len(
        axi_i_ar_len), .axi_i_ar_size({1'b0, 1'b0, 1'b0}), .axi_i_ar_burst({
        1'b0, axi_i_ar_burst[0]}), .axi_i_ar_lock(1'b0), .axi_i_ar_cache({1'b0, 
        1'b0, 1'b0, 1'b0}), .axi_i_ar_prot({1'b0, 1'b0, 1'b0}), .axi_i_ar_qos(
        {1'b0, 1'b0, 1'b0, 1'b0}), .axi_i_ar_region({1'b0, 1'b0, 1'b0, 1'b0}), 
        .axi_i_ar_user(1'b0), .axi_i_ar_valid(axi_i_ar_valid), 
        .axi_i_ar_ready(axi_i_ar_ready), .axi_i_r_id(axi_i_r_id), 
        .axi_i_r_data(axi_i_r_data), .axi_i_r_resp(axi_i_r_resp), 
        .axi_i_r_last(axi_i_r_last), .axi_i_r_user(SYNOPSYS_UNCONNECTED_3), 
        .axi_i_r_valid(axi_i_r_valid), .axi_i_r_ready(axi_i_r_ready), 
        .hyper_reset_no(SYNOPSYS_UNCONNECTED_4), .hyper_cs_no(hyper_cs_no), 
        .hyper_ck_o(hyper_ck_o), .hyper_ck_no(hyper_ck_no), .hyper_rwds_io(
        hyper_rwds_io), .hyper_dq_io(hyper_dq_io) );
endmodule

