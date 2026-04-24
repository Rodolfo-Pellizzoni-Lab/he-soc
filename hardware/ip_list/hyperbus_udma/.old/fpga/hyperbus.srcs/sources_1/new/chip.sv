`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2018 03:33:46 PM
// Design Name: 
// Module Name: chip
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module chip #(
    parameter BURST_WIDTH = 12,
    parameter NR_CS = 2
)(
    input  logic                   user_si570_sysclk_clk_p,    // Clock
    input  logic                   user_si570_sysclk_clk_n,    // Clock
    
    input  logic                   reset,   // Asynchronous reset active low

    // physical interface
    output logic [NR_CS-1:0]       hyper_cs_no,
    output logic                   hyper_ck_o,
    output logic                   hyper_ck_no,
    inout  logic                   hyper_rwds_io,
    inout  logic [7:0]             hyper_dq_io,
    output logic [9:0]             debug
);

    logic clk_phy_0;
    logic clk_phy_90;
    logic clk_sys;

    logic rst_ni;
    assign rst_ni = ~ reset;

    (* keep = "true" *) logic hyper_rwds_o;
    (* keep = "true" *) logic hyper_rwds_i;
    (* keep = "true" *) logic hyper_rwds_oe_o;
    (* keep = "true" *) logic [7:0] hyper_dq_i;
    (* keep = "true" *) logic [7:0] hyper_dq_o;
    (* keep = "true" *) logic hyper_dq_oe_o;

    assign debug[0] = clk_phy_90;
    assign debug[1] = hyper_rwds_i;
    assign debug[9:2] = hyper_dq_i[7:0];

    clk_generation_slow clk_generation_i (
        .clk_phy_0  ( clk_phy_0               ),
        .clk_phy_90 ( clk_phy_90              ),
        .clk_sys    ( clk_sys                 ),
        .reset      ( reset                   ),
        .locked     (                         ),
        .clk_in1_p  ( user_si570_sysclk_clk_p ),
        .clk_in1_n  ( user_si570_sysclk_clk_n )
    );

    //instantiate AXI
    AXI_BUS #(
      .AXI_ADDR_WIDTH ( 32 ),
      .AXI_DATA_WIDTH ( 32 ),
      .AXI_ID_WIDTH   ( 4  ),
      .AXI_USER_WIDTH ( 0  )
    ) axi_i(clk_phy_0);


    hyperbus #(.NR_CS(NR_CS), .BURST_WIDTH(BURST_WIDTH), .AXI_IW(4)) hyperbus_i (
        .clk0            ( clk_phy_0       ),
        .clk90           ( clk_phy_90      ),
        .rst_ni          ( rst_ni          ),
        //.cfg_i           ( cfg_i           ),
        .axi_i           ( axi_i           ),
        .hyper_cs_no     ( hyper_cs_no     ),
        .hyper_ck_o      ( hyper_ck_o      ),
        .hyper_ck_no     ( hyper_ck_no     ),
        .hyper_rwds_o    ( hyper_rwds_o    ),
        .hyper_rwds_i    ( hyper_rwds_i    ),
        .hyper_rwds_oe_o ( hyper_rwds_oe_o ),
        .hyper_dq_i      ( hyper_dq_i      ),
        .hyper_dq_o      ( hyper_dq_o      ),
        .hyper_dq_oe_o   ( hyper_dq_oe_o   ),
        .hyper_reset_no  (                 )
    );

    

    pad_io pad_sim (
        .data_i   (hyper_rwds_o),   
        .oe_i     (hyper_rwds_oe_o),
        .data_o   (hyper_rwds_i),  
        .pad_io   (hyper_rwds_io) 
    );

    pad_io #(8) pad_sim_data (
        .data_i   (hyper_dq_o),   
        .oe_i     (hyper_dq_oe_o),
        .data_o   (hyper_dq_i),  
        .pad_io   (hyper_dq_io) 
    );

    

    jtag_axi_0 jtag_axi_i (
        .aclk          ( clk_phy_0      ),
        .aresetn       ( rst_ni         ),
        .m_axi_awid    ( axi_i.aw_id    ),
        .m_axi_awaddr  ( axi_i.aw_addr  ),
        .m_axi_awlen   ( axi_i.aw_len   ),
        .m_axi_awsize  ( axi_i.aw_size  ),
        .m_axi_awburst ( axi_i.aw_burst ),
        .m_axi_awlock  ( axi_i.aw_lock  ),
        .m_axi_awcache ( axi_i.aw_cache ),
        .m_axi_awprot  ( axi_i.aw_prot  ),
        .m_axi_awqos   ( axi_i.aw_qos   ),
        .m_axi_awvalid ( axi_i.aw_valid ),
        .m_axi_awready ( axi_i.aw_ready ),
        .m_axi_wdata   ( axi_i.w_data   ),
        .m_axi_wstrb   ( axi_i.w_strb   ),
        .m_axi_wlast   ( axi_i.w_last   ),
        .m_axi_wvalid  ( axi_i.w_valid  ),
        .m_axi_wready  ( axi_i.w_ready  ),
        .m_axi_bid     ( axi_i.b_id     ),
        .m_axi_bresp   ( axi_i.b_resp   ),
        .m_axi_bvalid  ( axi_i.b_valid  ),
        .m_axi_bready  ( axi_i.b_ready  ),
        .m_axi_arid    ( axi_i.ar_id    ),
        .m_axi_araddr  ( axi_i.ar_addr  ),
        .m_axi_arlen   ( axi_i.ar_len   ),
        .m_axi_arsize  ( axi_i.ar_size  ),
        .m_axi_arburst ( axi_i.ar_burst ),
        .m_axi_arlock  ( axi_i.ar_lock  ),
        .m_axi_arcache ( axi_i.ar_cache ),
        .m_axi_arprot  ( axi_i.ar_prot  ),
        .m_axi_arqos   ( axi_i.ar_qos   ),
        .m_axi_arvalid ( axi_i.ar_valid ),
        .m_axi_arready ( axi_i.ar_ready ),
        .m_axi_rid     ( axi_i.r_id     ),
        .m_axi_rdata   ( axi_i.r_data   ),
        .m_axi_rresp   ( axi_i.r_resp   ),
        .m_axi_rlast   ( axi_i.r_last   ),
        .m_axi_rvalid  ( axi_i.r_valid  ),
        .m_axi_rready  ( axi_i.r_ready  ) 
    );

endmodule
