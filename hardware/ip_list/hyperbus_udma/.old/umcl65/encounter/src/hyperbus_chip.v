// Created automatically by prepare_chip.pl
// 

module hyperbus_chip ( clk_i, rst_ni, axi_i_aw_id, axi_i_aw_addr, axi_i_aw_len, 
        axi_i_aw_size, axi_i_aw_burst, axi_i_aw_lock, axi_i_aw_cache, 
        axi_i_aw_prot, axi_i_aw_qos, axi_i_aw_region, axi_i_aw_user, 
        axi_i_aw_valid, axi_i_aw_ready, axi_i_w_data, axi_i_w_strb, 
        axi_i_w_last, axi_i_w_user, axi_i_w_valid, axi_i_w_ready, axi_i_b_id, 
        axi_i_b_resp, axi_i_b_user, axi_i_b_valid, axi_i_b_ready, axi_i_ar_id, 
        axi_i_ar_addr, axi_i_ar_len, axi_i_ar_size, axi_i_ar_burst, 
        axi_i_ar_lock, axi_i_ar_cache, axi_i_ar_prot, axi_i_ar_qos, 
        axi_i_ar_region, axi_i_ar_user, axi_i_ar_valid, axi_i_ar_ready, 
        axi_i_r_id, axi_i_r_data, axi_i_r_resp, axi_i_r_last, axi_i_r_user, 
        axi_i_r_valid, axi_i_r_ready, hyper_cs_no, hyper_ck_o, hyper_ck_no, 
        hyper_rwds_o, hyper_rwds_i, hyper_rwds_oe_o, hyper_dq_i, hyper_dq_o, 
        hyper_dq_oe_o, hyper_reset_no );

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
  input clk_i, rst_ni, axi_i_aw_lock, axi_i_aw_valid, axi_i_w_last,
         axi_i_w_valid, axi_i_b_ready, axi_i_ar_lock, axi_i_ar_valid,
         axi_i_r_ready, hyper_rwds_i;
  output axi_i_aw_ready, axi_i_w_ready, axi_i_b_valid, axi_i_ar_ready,
         axi_i_r_last, axi_i_r_valid, hyper_ck_o, hyper_ck_no, hyper_rwds_o,
         hyper_rwds_oe_o, hyper_dq_oe_o, hyper_reset_no;
  wire [9:0] axi_i_aw_id;
  wire [31:0] axi_i_aw_addr;
  wire [7:0] axi_i_aw_len;
  wire [2:0] axi_i_aw_size;
  wire [1:0] axi_i_aw_burst;
  wire [3:0] axi_i_aw_cache;
  wire [2:0] axi_i_aw_prot;
  wire [3:0] axi_i_aw_qos;
  wire [3:0] axi_i_aw_region;
  wire [0:0] axi_i_aw_user;
  wire [15:0] axi_i_w_data;
  wire [1:0] axi_i_w_strb;
  wire [0:0] axi_i_w_user;
  wire [9:0] axi_i_b_id;
  wire [1:0] axi_i_b_resp;
  wire [0:0] axi_i_b_user;
  wire [9:0] axi_i_ar_id;
  wire [31:0] axi_i_ar_addr;
  wire [7:0] axi_i_ar_len;
  wire [2:0] axi_i_ar_size;
  wire [1:0] axi_i_ar_burst;
  wire [3:0] axi_i_ar_cache;
  wire [2:0] axi_i_ar_prot;
  wire [3:0] axi_i_ar_qos;
  wire [3:0] axi_i_ar_region;
  wire [0:0] axi_i_ar_user;
  wire [9:0] axi_i_r_id;
  wire [15:0] axi_i_r_data;
  wire [1:0] axi_i_r_resp;
  wire [0:0] axi_i_r_user;
  wire [1:0] hyper_cs_no;
  wire [7:0] hyper_dq_i;
  wire [7:0] hyper_dq_o;
  wire clk_i, rst_ni, axi_i_aw_lock, axi_i_aw_valid, axi_i_w_last,
         axi_i_w_valid, axi_i_b_ready, axi_i_ar_lock, axi_i_ar_valid,
         axi_i_r_ready, hyper_rwds_i;
  wire axi_i_aw_ready, axi_i_w_ready, axi_i_b_valid, axi_i_ar_ready,
         axi_i_r_last, axi_i_r_valid, hyper_ck_o, hyper_ck_no, hyper_rwds_o,
         hyper_rwds_oe_o, hyper_dq_oe_o, hyper_reset_no;

  IUMB pad_axi_i_aw_id_9 ( .DO(1'b0), .DI(axi_i_aw_id[9]), .PAD(axi_i_aw_id[9]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_8 ( .DO(1'b0), .DI(axi_i_aw_id[8]), .PAD(axi_i_aw_id[8]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_7 ( .DO(1'b0), .DI(axi_i_aw_id[7]), .PAD(axi_i_aw_id[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_6 ( .DO(1'b0), .DI(axi_i_aw_id[6]), .PAD(axi_i_aw_id[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_5 ( .DO(1'b0), .DI(axi_i_aw_id[5]), .PAD(axi_i_aw_id[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_4 ( .DO(1'b0), .DI(axi_i_aw_id[4]), .PAD(axi_i_aw_id[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_3 ( .DO(1'b0), .DI(axi_i_aw_id[3]), .PAD(axi_i_aw_id[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_2 ( .DO(1'b0), .DI(axi_i_aw_id[2]), .PAD(axi_i_aw_id[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_1 ( .DO(1'b0), .DI(axi_i_aw_id[1]), .PAD(axi_i_aw_id[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_id_0 ( .DO(1'b0), .DI(axi_i_aw_id[0]), .PAD(axi_i_aw_id[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_31 ( .DO(1'b0), .DI(axi_i_aw_addr[31]), .PAD(axi_i_aw_addr[31]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_30 ( .DO(1'b0), .DI(axi_i_aw_addr[30]), .PAD(axi_i_aw_addr[30]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_29 ( .DO(1'b0), .DI(axi_i_aw_addr[29]), .PAD(axi_i_aw_addr[29]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_28 ( .DO(1'b0), .DI(axi_i_aw_addr[28]), .PAD(axi_i_aw_addr[28]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_27 ( .DO(1'b0), .DI(axi_i_aw_addr[27]), .PAD(axi_i_aw_addr[27]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_26 ( .DO(1'b0), .DI(axi_i_aw_addr[26]), .PAD(axi_i_aw_addr[26]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_25 ( .DO(1'b0), .DI(axi_i_aw_addr[25]), .PAD(axi_i_aw_addr[25]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_24 ( .DO(1'b0), .DI(axi_i_aw_addr[24]), .PAD(axi_i_aw_addr[24]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_23 ( .DO(1'b0), .DI(axi_i_aw_addr[23]), .PAD(axi_i_aw_addr[23]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_22 ( .DO(1'b0), .DI(axi_i_aw_addr[22]), .PAD(axi_i_aw_addr[22]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_21 ( .DO(1'b0), .DI(axi_i_aw_addr[21]), .PAD(axi_i_aw_addr[21]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_20 ( .DO(1'b0), .DI(axi_i_aw_addr[20]), .PAD(axi_i_aw_addr[20]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_19 ( .DO(1'b0), .DI(axi_i_aw_addr[19]), .PAD(axi_i_aw_addr[19]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_18 ( .DO(1'b0), .DI(axi_i_aw_addr[18]), .PAD(axi_i_aw_addr[18]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_17 ( .DO(1'b0), .DI(axi_i_aw_addr[17]), .PAD(axi_i_aw_addr[17]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_16 ( .DO(1'b0), .DI(axi_i_aw_addr[16]), .PAD(axi_i_aw_addr[16]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_15 ( .DO(1'b0), .DI(axi_i_aw_addr[15]), .PAD(axi_i_aw_addr[15]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_14 ( .DO(1'b0), .DI(axi_i_aw_addr[14]), .PAD(axi_i_aw_addr[14]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_13 ( .DO(1'b0), .DI(axi_i_aw_addr[13]), .PAD(axi_i_aw_addr[13]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_12 ( .DO(1'b0), .DI(axi_i_aw_addr[12]), .PAD(axi_i_aw_addr[12]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_11 ( .DO(1'b0), .DI(axi_i_aw_addr[11]), .PAD(axi_i_aw_addr[11]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_10 ( .DO(1'b0), .DI(axi_i_aw_addr[10]), .PAD(axi_i_aw_addr[10]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_9 ( .DO(1'b0), .DI(axi_i_aw_addr[9]), .PAD(axi_i_aw_addr[9]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_8 ( .DO(1'b0), .DI(axi_i_aw_addr[8]), .PAD(axi_i_aw_addr[8]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_7 ( .DO(1'b0), .DI(axi_i_aw_addr[7]), .PAD(axi_i_aw_addr[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_6 ( .DO(1'b0), .DI(axi_i_aw_addr[6]), .PAD(axi_i_aw_addr[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_5 ( .DO(1'b0), .DI(axi_i_aw_addr[5]), .PAD(axi_i_aw_addr[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_4 ( .DO(1'b0), .DI(axi_i_aw_addr[4]), .PAD(axi_i_aw_addr[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_3 ( .DO(1'b0), .DI(axi_i_aw_addr[3]), .PAD(axi_i_aw_addr[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_2 ( .DO(1'b0), .DI(axi_i_aw_addr[2]), .PAD(axi_i_aw_addr[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_1 ( .DO(1'b0), .DI(axi_i_aw_addr[1]), .PAD(axi_i_aw_addr[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_addr_0 ( .DO(1'b0), .DI(axi_i_aw_addr[0]), .PAD(axi_i_aw_addr[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_7 ( .DO(1'b0), .DI(axi_i_aw_len[7]), .PAD(axi_i_aw_len[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_6 ( .DO(1'b0), .DI(axi_i_aw_len[6]), .PAD(axi_i_aw_len[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_5 ( .DO(1'b0), .DI(axi_i_aw_len[5]), .PAD(axi_i_aw_len[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_4 ( .DO(1'b0), .DI(axi_i_aw_len[4]), .PAD(axi_i_aw_len[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_3 ( .DO(1'b0), .DI(axi_i_aw_len[3]), .PAD(axi_i_aw_len[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_2 ( .DO(1'b0), .DI(axi_i_aw_len[2]), .PAD(axi_i_aw_len[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_1 ( .DO(1'b0), .DI(axi_i_aw_len[1]), .PAD(axi_i_aw_len[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_len_0 ( .DO(1'b0), .DI(axi_i_aw_len[0]), .PAD(axi_i_aw_len[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_size_2 ( .DO(1'b0), .DI(axi_i_aw_size[2]), .PAD(axi_i_aw_size[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_size_1 ( .DO(1'b0), .DI(axi_i_aw_size[1]), .PAD(axi_i_aw_size[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_size_0 ( .DO(1'b0), .DI(axi_i_aw_size[0]), .PAD(axi_i_aw_size[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_burst_1 ( .DO(1'b0), .DI(axi_i_aw_burst[1]), .PAD(axi_i_aw_burst[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_burst_0 ( .DO(1'b0), .DI(axi_i_aw_burst[0]), .PAD(axi_i_aw_burst[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_cache_3 ( .DO(1'b0), .DI(axi_i_aw_cache[3]), .PAD(axi_i_aw_cache[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_cache_2 ( .DO(1'b0), .DI(axi_i_aw_cache[2]), .PAD(axi_i_aw_cache[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_cache_1 ( .DO(1'b0), .DI(axi_i_aw_cache[1]), .PAD(axi_i_aw_cache[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_cache_0 ( .DO(1'b0), .DI(axi_i_aw_cache[0]), .PAD(axi_i_aw_cache[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_prot_2 ( .DO(1'b0), .DI(axi_i_aw_prot[2]), .PAD(axi_i_aw_prot[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_prot_1 ( .DO(1'b0), .DI(axi_i_aw_prot[1]), .PAD(axi_i_aw_prot[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_prot_0 ( .DO(1'b0), .DI(axi_i_aw_prot[0]), .PAD(axi_i_aw_prot[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_qos_3 ( .DO(1'b0), .DI(axi_i_aw_qos[3]), .PAD(axi_i_aw_qos[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_qos_2 ( .DO(1'b0), .DI(axi_i_aw_qos[2]), .PAD(axi_i_aw_qos[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_qos_1 ( .DO(1'b0), .DI(axi_i_aw_qos[1]), .PAD(axi_i_aw_qos[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_qos_0 ( .DO(1'b0), .DI(axi_i_aw_qos[0]), .PAD(axi_i_aw_qos[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_region_3 ( .DO(1'b0), .DI(axi_i_aw_region[3]), .PAD(axi_i_aw_region[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_region_2 ( .DO(1'b0), .DI(axi_i_aw_region[2]), .PAD(axi_i_aw_region[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_region_1 ( .DO(1'b0), .DI(axi_i_aw_region[1]), .PAD(axi_i_aw_region[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_region_0 ( .DO(1'b0), .DI(axi_i_aw_region[0]), .PAD(axi_i_aw_region[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_user ( .DO(1'b0), .DI(axi_i_aw_user), .PAD(axi_i_aw_user),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_15 ( .DO(1'b0), .DI(axi_i_w_data[15]), .PAD(axi_i_w_data[15]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_14 ( .DO(1'b0), .DI(axi_i_w_data[14]), .PAD(axi_i_w_data[14]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_13 ( .DO(1'b0), .DI(axi_i_w_data[13]), .PAD(axi_i_w_data[13]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_12 ( .DO(1'b0), .DI(axi_i_w_data[12]), .PAD(axi_i_w_data[12]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_11 ( .DO(1'b0), .DI(axi_i_w_data[11]), .PAD(axi_i_w_data[11]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_10 ( .DO(1'b0), .DI(axi_i_w_data[10]), .PAD(axi_i_w_data[10]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_9 ( .DO(1'b0), .DI(axi_i_w_data[9]), .PAD(axi_i_w_data[9]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_8 ( .DO(1'b0), .DI(axi_i_w_data[8]), .PAD(axi_i_w_data[8]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_7 ( .DO(1'b0), .DI(axi_i_w_data[7]), .PAD(axi_i_w_data[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_6 ( .DO(1'b0), .DI(axi_i_w_data[6]), .PAD(axi_i_w_data[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_5 ( .DO(1'b0), .DI(axi_i_w_data[5]), .PAD(axi_i_w_data[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_4 ( .DO(1'b0), .DI(axi_i_w_data[4]), .PAD(axi_i_w_data[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_3 ( .DO(1'b0), .DI(axi_i_w_data[3]), .PAD(axi_i_w_data[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_2 ( .DO(1'b0), .DI(axi_i_w_data[2]), .PAD(axi_i_w_data[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_1 ( .DO(1'b0), .DI(axi_i_w_data[1]), .PAD(axi_i_w_data[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_data_0 ( .DO(1'b0), .DI(axi_i_w_data[0]), .PAD(axi_i_w_data[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_strb_1 ( .DO(1'b0), .DI(axi_i_w_strb[1]), .PAD(axi_i_w_strb[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_strb_0 ( .DO(1'b0), .DI(axi_i_w_strb[0]), .PAD(axi_i_w_strb[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_user ( .DO(1'b0), .DI(axi_i_w_user), .PAD(axi_i_w_user),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_9 ( .DO(axi_i_b_id[9]), .DI(), .PAD(axi_i_b_id[9]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_8 ( .DO(axi_i_b_id[8]), .DI(), .PAD(axi_i_b_id[8]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_7 ( .DO(axi_i_b_id[7]), .DI(), .PAD(axi_i_b_id[7]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_6 ( .DO(axi_i_b_id[6]), .DI(), .PAD(axi_i_b_id[6]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_5 ( .DO(axi_i_b_id[5]), .DI(), .PAD(axi_i_b_id[5]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_4 ( .DO(axi_i_b_id[4]), .DI(), .PAD(axi_i_b_id[4]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_3 ( .DO(axi_i_b_id[3]), .DI(), .PAD(axi_i_b_id[3]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_2 ( .DO(axi_i_b_id[2]), .DI(), .PAD(axi_i_b_id[2]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_1 ( .DO(axi_i_b_id[1]), .DI(), .PAD(axi_i_b_id[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_id_0 ( .DO(axi_i_b_id[0]), .DI(), .PAD(axi_i_b_id[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_resp_1 ( .DO(axi_i_b_resp[1]), .DI(), .PAD(axi_i_b_resp[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_resp_0 ( .DO(axi_i_b_resp[0]), .DI(), .PAD(axi_i_b_resp[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_user ( .DO(axi_i_b_user), .DI(), .PAD(axi_i_b_user),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_9 ( .DO(1'b0), .DI(axi_i_ar_id[9]), .PAD(axi_i_ar_id[9]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_8 ( .DO(1'b0), .DI(axi_i_ar_id[8]), .PAD(axi_i_ar_id[8]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_7 ( .DO(1'b0), .DI(axi_i_ar_id[7]), .PAD(axi_i_ar_id[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_6 ( .DO(1'b0), .DI(axi_i_ar_id[6]), .PAD(axi_i_ar_id[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_5 ( .DO(1'b0), .DI(axi_i_ar_id[5]), .PAD(axi_i_ar_id[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_4 ( .DO(1'b0), .DI(axi_i_ar_id[4]), .PAD(axi_i_ar_id[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_3 ( .DO(1'b0), .DI(axi_i_ar_id[3]), .PAD(axi_i_ar_id[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_2 ( .DO(1'b0), .DI(axi_i_ar_id[2]), .PAD(axi_i_ar_id[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_1 ( .DO(1'b0), .DI(axi_i_ar_id[1]), .PAD(axi_i_ar_id[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_id_0 ( .DO(1'b0), .DI(axi_i_ar_id[0]), .PAD(axi_i_ar_id[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_31 ( .DO(1'b0), .DI(axi_i_ar_addr[31]), .PAD(axi_i_ar_addr[31]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_30 ( .DO(1'b0), .DI(axi_i_ar_addr[30]), .PAD(axi_i_ar_addr[30]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_29 ( .DO(1'b0), .DI(axi_i_ar_addr[29]), .PAD(axi_i_ar_addr[29]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_28 ( .DO(1'b0), .DI(axi_i_ar_addr[28]), .PAD(axi_i_ar_addr[28]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_27 ( .DO(1'b0), .DI(axi_i_ar_addr[27]), .PAD(axi_i_ar_addr[27]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_26 ( .DO(1'b0), .DI(axi_i_ar_addr[26]), .PAD(axi_i_ar_addr[26]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_25 ( .DO(1'b0), .DI(axi_i_ar_addr[25]), .PAD(axi_i_ar_addr[25]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_24 ( .DO(1'b0), .DI(axi_i_ar_addr[24]), .PAD(axi_i_ar_addr[24]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_23 ( .DO(1'b0), .DI(axi_i_ar_addr[23]), .PAD(axi_i_ar_addr[23]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_22 ( .DO(1'b0), .DI(axi_i_ar_addr[22]), .PAD(axi_i_ar_addr[22]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_21 ( .DO(1'b0), .DI(axi_i_ar_addr[21]), .PAD(axi_i_ar_addr[21]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_20 ( .DO(1'b0), .DI(axi_i_ar_addr[20]), .PAD(axi_i_ar_addr[20]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_19 ( .DO(1'b0), .DI(axi_i_ar_addr[19]), .PAD(axi_i_ar_addr[19]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_18 ( .DO(1'b0), .DI(axi_i_ar_addr[18]), .PAD(axi_i_ar_addr[18]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_17 ( .DO(1'b0), .DI(axi_i_ar_addr[17]), .PAD(axi_i_ar_addr[17]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_16 ( .DO(1'b0), .DI(axi_i_ar_addr[16]), .PAD(axi_i_ar_addr[16]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_15 ( .DO(1'b0), .DI(axi_i_ar_addr[15]), .PAD(axi_i_ar_addr[15]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_14 ( .DO(1'b0), .DI(axi_i_ar_addr[14]), .PAD(axi_i_ar_addr[14]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_13 ( .DO(1'b0), .DI(axi_i_ar_addr[13]), .PAD(axi_i_ar_addr[13]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_12 ( .DO(1'b0), .DI(axi_i_ar_addr[12]), .PAD(axi_i_ar_addr[12]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_11 ( .DO(1'b0), .DI(axi_i_ar_addr[11]), .PAD(axi_i_ar_addr[11]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_10 ( .DO(1'b0), .DI(axi_i_ar_addr[10]), .PAD(axi_i_ar_addr[10]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_9 ( .DO(1'b0), .DI(axi_i_ar_addr[9]), .PAD(axi_i_ar_addr[9]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_8 ( .DO(1'b0), .DI(axi_i_ar_addr[8]), .PAD(axi_i_ar_addr[8]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_7 ( .DO(1'b0), .DI(axi_i_ar_addr[7]), .PAD(axi_i_ar_addr[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_6 ( .DO(1'b0), .DI(axi_i_ar_addr[6]), .PAD(axi_i_ar_addr[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_5 ( .DO(1'b0), .DI(axi_i_ar_addr[5]), .PAD(axi_i_ar_addr[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_4 ( .DO(1'b0), .DI(axi_i_ar_addr[4]), .PAD(axi_i_ar_addr[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_3 ( .DO(1'b0), .DI(axi_i_ar_addr[3]), .PAD(axi_i_ar_addr[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_2 ( .DO(1'b0), .DI(axi_i_ar_addr[2]), .PAD(axi_i_ar_addr[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_1 ( .DO(1'b0), .DI(axi_i_ar_addr[1]), .PAD(axi_i_ar_addr[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_addr_0 ( .DO(1'b0), .DI(axi_i_ar_addr[0]), .PAD(axi_i_ar_addr[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_7 ( .DO(1'b0), .DI(axi_i_ar_len[7]), .PAD(axi_i_ar_len[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_6 ( .DO(1'b0), .DI(axi_i_ar_len[6]), .PAD(axi_i_ar_len[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_5 ( .DO(1'b0), .DI(axi_i_ar_len[5]), .PAD(axi_i_ar_len[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_4 ( .DO(1'b0), .DI(axi_i_ar_len[4]), .PAD(axi_i_ar_len[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_3 ( .DO(1'b0), .DI(axi_i_ar_len[3]), .PAD(axi_i_ar_len[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_2 ( .DO(1'b0), .DI(axi_i_ar_len[2]), .PAD(axi_i_ar_len[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_1 ( .DO(1'b0), .DI(axi_i_ar_len[1]), .PAD(axi_i_ar_len[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_len_0 ( .DO(1'b0), .DI(axi_i_ar_len[0]), .PAD(axi_i_ar_len[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_size_2 ( .DO(1'b0), .DI(axi_i_ar_size[2]), .PAD(axi_i_ar_size[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_size_1 ( .DO(1'b0), .DI(axi_i_ar_size[1]), .PAD(axi_i_ar_size[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_size_0 ( .DO(1'b0), .DI(axi_i_ar_size[0]), .PAD(axi_i_ar_size[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_burst_1 ( .DO(1'b0), .DI(axi_i_ar_burst[1]), .PAD(axi_i_ar_burst[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_burst_0 ( .DO(1'b0), .DI(axi_i_ar_burst[0]), .PAD(axi_i_ar_burst[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_cache_3 ( .DO(1'b0), .DI(axi_i_ar_cache[3]), .PAD(axi_i_ar_cache[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_cache_2 ( .DO(1'b0), .DI(axi_i_ar_cache[2]), .PAD(axi_i_ar_cache[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_cache_1 ( .DO(1'b0), .DI(axi_i_ar_cache[1]), .PAD(axi_i_ar_cache[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_cache_0 ( .DO(1'b0), .DI(axi_i_ar_cache[0]), .PAD(axi_i_ar_cache[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_prot_2 ( .DO(1'b0), .DI(axi_i_ar_prot[2]), .PAD(axi_i_ar_prot[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_prot_1 ( .DO(1'b0), .DI(axi_i_ar_prot[1]), .PAD(axi_i_ar_prot[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_prot_0 ( .DO(1'b0), .DI(axi_i_ar_prot[0]), .PAD(axi_i_ar_prot[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_qos_3 ( .DO(1'b0), .DI(axi_i_ar_qos[3]), .PAD(axi_i_ar_qos[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_qos_2 ( .DO(1'b0), .DI(axi_i_ar_qos[2]), .PAD(axi_i_ar_qos[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_qos_1 ( .DO(1'b0), .DI(axi_i_ar_qos[1]), .PAD(axi_i_ar_qos[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_qos_0 ( .DO(1'b0), .DI(axi_i_ar_qos[0]), .PAD(axi_i_ar_qos[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_region_3 ( .DO(1'b0), .DI(axi_i_ar_region[3]), .PAD(axi_i_ar_region[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_region_2 ( .DO(1'b0), .DI(axi_i_ar_region[2]), .PAD(axi_i_ar_region[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_region_1 ( .DO(1'b0), .DI(axi_i_ar_region[1]), .PAD(axi_i_ar_region[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_region_0 ( .DO(1'b0), .DI(axi_i_ar_region[0]), .PAD(axi_i_ar_region[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_user ( .DO(1'b0), .DI(axi_i_ar_user), .PAD(axi_i_ar_user),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_9 ( .DO(axi_i_r_id[9]), .DI(), .PAD(axi_i_r_id[9]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_8 ( .DO(axi_i_r_id[8]), .DI(), .PAD(axi_i_r_id[8]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_7 ( .DO(axi_i_r_id[7]), .DI(), .PAD(axi_i_r_id[7]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_6 ( .DO(axi_i_r_id[6]), .DI(), .PAD(axi_i_r_id[6]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_5 ( .DO(axi_i_r_id[5]), .DI(), .PAD(axi_i_r_id[5]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_4 ( .DO(axi_i_r_id[4]), .DI(), .PAD(axi_i_r_id[4]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_3 ( .DO(axi_i_r_id[3]), .DI(), .PAD(axi_i_r_id[3]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_2 ( .DO(axi_i_r_id[2]), .DI(), .PAD(axi_i_r_id[2]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_1 ( .DO(axi_i_r_id[1]), .DI(), .PAD(axi_i_r_id[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_id_0 ( .DO(axi_i_r_id[0]), .DI(), .PAD(axi_i_r_id[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_15 ( .DO(axi_i_r_data[15]), .DI(), .PAD(axi_i_r_data[15]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_14 ( .DO(axi_i_r_data[14]), .DI(), .PAD(axi_i_r_data[14]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_13 ( .DO(axi_i_r_data[13]), .DI(), .PAD(axi_i_r_data[13]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_12 ( .DO(axi_i_r_data[12]), .DI(), .PAD(axi_i_r_data[12]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_11 ( .DO(axi_i_r_data[11]), .DI(), .PAD(axi_i_r_data[11]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_10 ( .DO(axi_i_r_data[10]), .DI(), .PAD(axi_i_r_data[10]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_9 ( .DO(axi_i_r_data[9]), .DI(), .PAD(axi_i_r_data[9]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_8 ( .DO(axi_i_r_data[8]), .DI(), .PAD(axi_i_r_data[8]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_7 ( .DO(axi_i_r_data[7]), .DI(), .PAD(axi_i_r_data[7]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_6 ( .DO(axi_i_r_data[6]), .DI(), .PAD(axi_i_r_data[6]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_5 ( .DO(axi_i_r_data[5]), .DI(), .PAD(axi_i_r_data[5]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_4 ( .DO(axi_i_r_data[4]), .DI(), .PAD(axi_i_r_data[4]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_3 ( .DO(axi_i_r_data[3]), .DI(), .PAD(axi_i_r_data[3]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_2 ( .DO(axi_i_r_data[2]), .DI(), .PAD(axi_i_r_data[2]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_1 ( .DO(axi_i_r_data[1]), .DI(), .PAD(axi_i_r_data[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_data_0 ( .DO(axi_i_r_data[0]), .DI(), .PAD(axi_i_r_data[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_resp_1 ( .DO(axi_i_r_resp[1]), .DI(), .PAD(axi_i_r_resp[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_resp_0 ( .DO(axi_i_r_resp[0]), .DI(), .PAD(axi_i_r_resp[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_user ( .DO(axi_i_r_user), .DI(), .PAD(axi_i_r_user),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_cs_no_1 ( .DO(hyper_cs_no[1]), .DI(), .PAD(hyper_cs_no[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_cs_no_0 ( .DO(hyper_cs_no[0]), .DI(), .PAD(hyper_cs_no[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_7 ( .DO(1'b0), .DI(hyper_dq_i[7]), .PAD(hyper_dq_i[7]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_6 ( .DO(1'b0), .DI(hyper_dq_i[6]), .PAD(hyper_dq_i[6]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_5 ( .DO(1'b0), .DI(hyper_dq_i[5]), .PAD(hyper_dq_i[5]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_4 ( .DO(1'b0), .DI(hyper_dq_i[4]), .PAD(hyper_dq_i[4]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_3 ( .DO(1'b0), .DI(hyper_dq_i[3]), .PAD(hyper_dq_i[3]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_2 ( .DO(1'b0), .DI(hyper_dq_i[2]), .PAD(hyper_dq_i[2]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_1 ( .DO(1'b0), .DI(hyper_dq_i[1]), .PAD(hyper_dq_i[1]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_i_0 ( .DO(1'b0), .DI(hyper_dq_i[0]), .PAD(hyper_dq_i[0]),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_7 ( .DO(hyper_dq_o[7]), .DI(), .PAD(hyper_dq_o[7]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_6 ( .DO(hyper_dq_o[6]), .DI(), .PAD(hyper_dq_o[6]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_5 ( .DO(hyper_dq_o[5]), .DI(), .PAD(hyper_dq_o[5]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_4 ( .DO(hyper_dq_o[4]), .DI(), .PAD(hyper_dq_o[4]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_3 ( .DO(hyper_dq_o[3]), .DI(), .PAD(hyper_dq_o[3]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_2 ( .DO(hyper_dq_o[2]), .DI(), .PAD(hyper_dq_o[2]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_1 ( .DO(hyper_dq_o[1]), .DI(), .PAD(hyper_dq_o[1]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_o_0 ( .DO(hyper_dq_o[0]), .DI(), .PAD(hyper_dq_o[0]),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_clk_i ( .DO(1'b0), .DI(clk_i), .PAD(clk_i),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_rst_ni ( .DO(1'b0), .DI(rst_ni), .PAD(rst_ni),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_lock ( .DO(1'b0), .DI(axi_i_aw_lock), .PAD(axi_i_aw_lock),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_valid ( .DO(1'b0), .DI(axi_i_aw_valid), .PAD(axi_i_aw_valid),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_last ( .DO(1'b0), .DI(axi_i_w_last), .PAD(axi_i_w_last),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_valid ( .DO(1'b0), .DI(axi_i_w_valid), .PAD(axi_i_w_valid),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_ready ( .DO(1'b0), .DI(axi_i_b_ready), .PAD(axi_i_b_ready),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_lock ( .DO(1'b0), .DI(axi_i_ar_lock), .PAD(axi_i_ar_lock),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_valid ( .DO(1'b0), .DI(axi_i_ar_valid), .PAD(axi_i_ar_valid),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_ready ( .DO(1'b0), .DI(axi_i_r_ready), .PAD(axi_i_r_ready),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_rwds_i ( .DO(1'b0), .DI(hyper_rwds_i), .PAD(hyper_rwds_i),.OE(1'b0),
         .IDDQ(1'b0), .PIN2(1'b0), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_aw_ready ( .DO(axi_i_aw_ready), .DI(), .PAD(axi_i_aw_ready),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_w_ready ( .DO(axi_i_w_ready), .DI(), .PAD(axi_i_w_ready),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_b_valid ( .DO(axi_i_b_valid), .DI(), .PAD(axi_i_b_valid),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_ar_ready ( .DO(axi_i_ar_ready), .DI(), .PAD(axi_i_ar_ready),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_last ( .DO(axi_i_r_last), .DI(), .PAD(axi_i_r_last),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_axi_i_r_valid ( .DO(axi_i_r_valid), .DI(), .PAD(axi_i_r_valid),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_ck_o ( .DO(hyper_ck_o), .DI(), .PAD(hyper_ck_o),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_ck_no ( .DO(hyper_ck_no), .DI(), .PAD(hyper_ck_no),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_rwds_o ( .DO(hyper_rwds_o), .DI(), .PAD(hyper_rwds_o),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_rwds_oe_o ( .DO(hyper_rwds_oe_o), .DI(), .PAD(hyper_rwds_oe_o),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_dq_oe_o ( .DO(hyper_dq_oe_o), .DI(), .PAD(hyper_dq_oe_o),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  IUMB pad_hyper_reset_no ( .DO(hyper_reset_no), .DI(), .PAD(hyper_reset_no),.OE(1'b1),
         .IDDQ(1'b0), .PIN2(1'b1), .PIN1(1'b0), .SMT(1'b0),
         .PD(1'b0), .PU(1'b0), .SR(1'b0) );
  hyperbus i_hyperbus (.axi_i_aw_id(axi_i_aw_id), .axi_i_aw_addr(axi_i_aw_addr), .axi_i_aw_len(axi_i_aw_len), .axi_i_aw_size(axi_i_aw_size), .axi_i_aw_burst(axi_i_aw_burst), .axi_i_aw_cache(axi_i_aw_cache), .axi_i_aw_prot(axi_i_aw_prot), .axi_i_aw_qos(axi_i_aw_qos), .axi_i_aw_region(axi_i_aw_region), .axi_i_aw_user(axi_i_aw_user), .axi_i_w_data(axi_i_w_data), .axi_i_w_strb(axi_i_w_strb), .axi_i_w_user(axi_i_w_user), .axi_i_b_id(axi_i_b_id), .axi_i_b_resp(axi_i_b_resp), .axi_i_b_user(axi_i_b_user), .axi_i_ar_id(axi_i_ar_id), .axi_i_ar_addr(axi_i_ar_addr), .axi_i_ar_len(axi_i_ar_len), .axi_i_ar_size(axi_i_ar_size), .axi_i_ar_burst(axi_i_ar_burst), .axi_i_ar_cache(axi_i_ar_cache), .axi_i_ar_prot(axi_i_ar_prot), .axi_i_ar_qos(axi_i_ar_qos), .axi_i_ar_region(axi_i_ar_region), .axi_i_ar_user(axi_i_ar_user), .axi_i_r_id(axi_i_r_id), .axi_i_r_data(axi_i_r_data), .axi_i_r_resp(axi_i_r_resp), .axi_i_r_user(axi_i_r_user), .hyper_cs_no(hyper_cs_no), .hyper_dq_i(hyper_dq_i), .hyper_dq_o(hyper_dq_o), .clk_i(clk_i), .rst_ni(rst_ni), .axi_i_aw_lock(axi_i_aw_lock), .axi_i_aw_valid(axi_i_aw_valid), .axi_i_w_last(axi_i_w_last), .axi_i_w_valid(axi_i_w_valid), .axi_i_b_ready(axi_i_b_ready), .axi_i_ar_lock(axi_i_ar_lock), .axi_i_ar_valid(axi_i_ar_valid), .axi_i_r_ready(axi_i_r_ready), .hyper_rwds_i(hyper_rwds_i), .axi_i_aw_ready(axi_i_aw_ready), .axi_i_w_ready(axi_i_w_ready), .axi_i_b_valid(axi_i_b_valid), .axi_i_ar_ready(axi_i_ar_ready), .axi_i_r_last(axi_i_r_last), .axi_i_r_valid(axi_i_r_valid), .hyper_ck_o(hyper_ck_o), .hyper_ck_no(hyper_ck_no), .hyper_rwds_o(hyper_rwds_o), .hyper_rwds_oe_o(hyper_rwds_oe_o), .hyper_dq_oe_o(hyper_dq_oe_o), .hyper_reset_no(hyper_reset_no));

  ICORNER  pad_corner4 ( );
  ICORNER  pad_corner3 ( );
  ICORNER  pad_corner2 ( );
  ICORNER  pad_corner1 ( );

  IVSSIO  pad_vss_p2 ( );
  IVSSIO  pad_vss_p1 ( ); 

  IVSS  pad_vss_c2 ( );
  IVSS  pad_vss_c1 ( );

  IVDDIO  pad_vdd_p2 ( );
  IVDDIO  pad_vdd_p1 ( );

  IVDD  pad_vdd_c2 ( );
  IVDD  pad_vdd_c1 ( );

endmodule
