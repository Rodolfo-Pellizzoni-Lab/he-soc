// Hyperbus AXI

// this code is unstable and most likely buggy
// it should not be used by anyone

// Author: Thomas Benz <paulsc@iis.ee.ethz.ch>
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

module hyperbus_synth_wrap
  import axi_pkg::*;
#(
    // HyperBus parameters
    parameter int unsigned  NumChips        = 4,
    parameter int unsigned  NumPhys         = 2,
    parameter int unsigned  IsClockODelayed = 0,
    // AXI parameters
    parameter int unsigned  AxiIdWidth      = 9,
    parameter int unsigned  AxiAddrWidth    = 64,
    parameter int unsigned  AxiDataWidth    = 64,
    parameter int unsigned  AxiUserWidth    = 1,
    // Regbus parameters
    parameter int unsigned  RegAddrWidth    = 32,
    parameter int unsigned  RegDataWidth    = 32,
    // Udma parameters
    parameter int unsigned  L2_AWIDTH_NOAL  = 32,
    parameter int unsigned  TRANS_SIZE      = 20,
    parameter int unsigned  NB_CH           = 1,
    parameter int unsigned  AxiLogDepth     = 3,
    parameter int unsigned  SyncStages      = 3,
    // Dependent parameters; do not override!
    parameter type axi_addr_t   = logic [AxiAddrWidth-1:0],
    parameter type axi_data_t   = logic [AxiDataWidth-1:0],
    parameter type axi_strb_t   = logic [AxiDataWidth/8-1:0],
    parameter type axi_id_t     = logic [AxiIdWidth-1:0],
    parameter type axi_user_t   = logic [AxiUserWidth-1:0],
    parameter type reg_addr_t   = logic [RegAddrWidth-1:0],
    parameter type reg_data_t   = logic [RegDataWidth-1:0],
    parameter type reg_strb_t   = logic [RegDataWidth/8-1:0],
    localparam AxiAwWidth = AxiIdWidth + AxiAddrWidth + $bits(axi_pkg::len_t) + $bits(axi_pkg::size_t) + $bits(axi_pkg::burst_t) + 1 + $bits(axi_pkg::cache_t) + $bits(axi_pkg::prot_t) + $bits(axi_pkg::qos_t) + $bits(axi_pkg::region_t) + $bits(axi_pkg::atop_t) + AxiUserWidth,
    localparam AxiWWidth  = AxiUserWidth + AxiDataWidth/8 + AxiDataWidth + 1,
    localparam AxiRWidth  = AxiIdWidth + AxiDataWidth + $bits(axi_pkg::resp_t) + 1 + AxiUserWidth,
    localparam AxiBWidth  = AxiIdWidth + AxiUserWidth + $bits(axi_pkg::resp_t),
    localparam AxiArWidth = AxiIdWidth + AxiAddrWidth + $bits(axi_pkg::len_t) + $bits(axi_pkg::size_t) + $bits(axi_pkg::burst_t) + 1 + $bits(axi_pkg::cache_t) + $bits(axi_pkg::prot_t) + $bits(axi_pkg::qos_t) + $bits(axi_pkg::region_t) + AxiUserWidth,
    localparam AxiAsyncAwWidth = AxiAwWidth*(2**AxiLogDepth),
    localparam AxiAsyncWWidth  = AxiWWidth *(2**AxiLogDepth),
    localparam AxiAsyncRWidth  = AxiRWidth *(2**AxiLogDepth),
    localparam AxiAsyncBWidth  = AxiBWidth *(2**AxiLogDepth),
    localparam AxiAsyncArWidth = AxiArWidth*(2**AxiLogDepth),
    localparam RegReqWidth     = RegAddrWidth + 1 + RegDataWidth + RegDataWidth/8 + 1,
    localparam RegRspWidth     = RegDataWidth + 1 + 1,
    localparam UdmaRegReqWidth = 5 + 1 + 32 + 1 + 1,
    localparam UdmaRegRspWidth = 32 + 1 + 1
) (
    // SoC
    input  logic                        clk_phy_i,
    input  logic                        rst_phy_ni,
    input  logic                        clk_sys_i,
    input  logic                        rst_sys_ni,
    input  logic                        test_mode_i,

    input  logic  [AxiAsyncAwWidth-1:0] async_data_slave_aw_data_i,
    input  logic  [AxiLogDepth:0]       async_data_slave_aw_wptr_i,
    output logic  [AxiLogDepth:0]       async_data_slave_aw_rptr_o,
    input  logic  [AxiAsyncWWidth-1:0]  async_data_slave_w_data_i,
    input  logic  [AxiLogDepth:0]       async_data_slave_w_wptr_i,
    output logic  [AxiLogDepth:0]       async_data_slave_w_rptr_o,
    output logic  [AxiAsyncBWidth-1:0]  async_data_slave_b_data_o,
    output logic  [AxiLogDepth:0]       async_data_slave_b_wptr_o,
    input  logic  [AxiLogDepth:0]       async_data_slave_b_rptr_i,
    input  logic  [AxiAsyncArWidth-1:0] async_data_slave_ar_data_i,
    input  logic  [AxiLogDepth:0]       async_data_slave_ar_wptr_i,
    output logic  [AxiLogDepth:0]       async_data_slave_ar_rptr_o,
    output logic  [AxiAsyncRWidth-1:0]  async_data_slave_r_data_o,
    output logic  [AxiLogDepth:0]       async_data_slave_r_wptr_o,
    input  logic  [AxiLogDepth:0]       async_data_slave_r_rptr_i,
    // Reg bus
    input  logic                        async_reg_req_req_i,
    output logic                        async_reg_req_ack_o,
    input  logic [RegReqWidth-1:0]      async_reg_req_data_i,

    output logic                        async_reg_rsp_req_o,
    input  logic                        async_reg_rsp_ack_i,
    output logic [RegRspWidth-1:0]      async_reg_rsp_data_o,

    // UDMA interface
    input  logic                       [NB_CH:0] async_udma_reg_req_req_i,
    output logic                       [NB_CH:0] async_udma_reg_req_ack_o,
    input  logic [UdmaRegReqWidth*(NB_CH+1)-1:0] async_udma_reg_req_data_i,

    output logic                       [NB_CH:0] async_udma_reg_rsp_req_o,
    input  logic                       [NB_CH:0] async_udma_reg_rsp_ack_i,
    output logic [UdmaRegRspWidth*(NB_CH+1)-1:0] async_udma_reg_rsp_data_o,

    output logic [L2_AWIDTH_NOAL-1:0]   cfg_rx_startaddr_o,
    output logic     [TRANS_SIZE-1:0]   cfg_rx_size_o,
    output logic                        cfg_rx_continuous_o,
    output logic                        cfg_rx_en_o,
    output logic                        cfg_rx_clr_o,
    input  logic                        cfg_rx_en_i,
    input  logic                        cfg_rx_pending_i,
    input  logic [L2_AWIDTH_NOAL-1:0]   cfg_rx_curr_addr_i,
    input  logic     [TRANS_SIZE-1:0]   cfg_rx_bytes_left_i,
    output logic                [1:0]   data_rx_datasize_o,

    output logic [L2_AWIDTH_NOAL-1:0]   cfg_tx_startaddr_o,
    output logic     [TRANS_SIZE-1:0]   cfg_tx_size_o,
    output logic                        cfg_tx_continuous_o,
    output logic                        cfg_tx_en_o,
    output logic                        cfg_tx_clr_o,
    input  logic                        cfg_tx_en_i,
    input  logic                        cfg_tx_pending_i,
    input  logic [L2_AWIDTH_NOAL-1:0]   cfg_tx_curr_addr_i,
    input  logic     [TRANS_SIZE-1:0]   cfg_tx_bytes_left_i,
    output logic                [1:0]   data_tx_datasize_o,

    output logic          [NB_CH-1:0]   evt_eot_hyper_o,

    output logic [3:0]                  async_rx_wptr_o,
    input  logic [3:0]                  async_rx_rptr_i,
    output logic [32*8-1:0]             async_rx_data_o,

    input logic [3:0]                   async_tx_wptr_i,
    output logic [3:0]                  async_tx_rptr_o,
    input logic [32*8-1:0]              async_tx_data_i,

    // Physical interace: facing HyperBus
    inout  [NumPhys*NumChips-1:0]       pad_hyper_csn,
    inout  [NumPhys-1:0]                pad_hyper_ck,
    inout  [NumPhys-1:0]                pad_hyper_ckn,
    inout  [NumPhys-1:0]                pad_hyper_rwds,
    inout  [NumPhys-1:0]                pad_hyper_reset,
    inout  [NumPhys*8-1:0]              pad_hyper_dq
);

    // Types
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, axi_addr_t, axi_id_t, axi_user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_t, axi_id_t, axi_user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, axi_addr_t, axi_id_t, axi_user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_t, axi_data_t, axi_id_t, axi_user_t)
    `AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
    `AXI_TYPEDEF_RESP_T(axi_rsp_t, b_chan_t, r_chan_t)

    axi_req_t   axi_req;
    axi_rsp_t  axi_rsp;

    `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)

    reg_req_t   reg_req;
    reg_rsp_t   reg_rsp;

    typedef axi_pkg::xbar_rule_32_t axi_rule_t;

   `REG_BUS_TYPEDEF_REQ(udma_cfg_reg_req_t,logic[4:0],logic[31:0],logic)
   `REG_BUS_TYPEDEF_RSP(udma_cfg_reg_rsp_t,logic[31:0])

    hyperbus_async_macro #(
        .NumChips         ( NumChips           ),
        .NumPhys          ( NumPhys            ),
        .IsClockODelayed  ( IsClockODelayed    ),
        .L2_AWIDTH_NOAL   ( L2_AWIDTH_NOAL     ),
        .TRANS_SIZE       ( TRANS_SIZE         ),
        .NB_CH            ( NB_CH              ),
        .AxiAddrWidth     ( AxiAddrWidth       ),
        .AxiDataWidth     ( AxiDataWidth       ),
        .AxiIdWidth       ( AxiIdWidth         ),
        .AxiUserWidth     ( AxiUserWidth       ),
        .axi_req_t        ( axi_req_t          ),
        .axi_rsp_t        ( axi_rsp_t          ),
        .axi_aw_chan_t    ( aw_chan_t          ),
        .axi_w_chan_t     ( w_chan_t           ),
        .axi_b_chan_t     ( b_chan_t           ),
        .axi_ar_chan_t    ( ar_chan_t          ),
        .axi_r_chan_t     ( r_chan_t           ),
        .RegAddrWidth     ( RegAddrWidth       ),
        .RegDataWidth     ( RegDataWidth       ),
        .reg_req_t        ( reg_req_t          ),
        .reg_rsp_t        ( reg_rsp_t          ),
        .udma_reg_req_t   ( udma_cfg_reg_req_t ),
        .udma_reg_rsp_t   ( udma_cfg_reg_rsp_t ),
        .axi_rule_t       ( axi_rule_t         ),
        .AxiLogDepth      ( AxiLogDepth        ),
        .SyncStages       ( SyncStages         ),
        .RstChipBase      ( 32'h80000000       ),
        .RstChipSpace     ( 32'h800000         )
    ) i_hyperbus_macro (
        .clk_phy_i              ( clk_phy_i             ),
        .rst_phy_ni             ( rst_phy_ni            ),
        .clk_sys_i              ( clk_sys_i             ),
        .rst_sys_ni             ( rst_sys_ni            ),
        .test_mode_i            ( test_mode_i           ),

        .async_data_slave_aw_data_i  ( async_data_slave_aw_data_i ),
        .async_data_slave_aw_wptr_i  ( async_data_slave_aw_wptr_i ),
        .async_data_slave_aw_rptr_o  ( async_data_slave_aw_rptr_o ),
        .async_data_slave_w_data_i   ( async_data_slave_w_data_i  ),
        .async_data_slave_w_wptr_i   ( async_data_slave_w_wptr_i  ),
        .async_data_slave_w_rptr_o   ( async_data_slave_w_rptr_o  ),
        .async_data_slave_b_data_o   ( async_data_slave_b_data_o  ),
        .async_data_slave_b_wptr_o   ( async_data_slave_b_wptr_o  ),
        .async_data_slave_b_rptr_i   ( async_data_slave_b_rptr_i  ),
        .async_data_slave_ar_data_i  ( async_data_slave_ar_data_i ),
        .async_data_slave_ar_wptr_i  ( async_data_slave_ar_wptr_i ),
        .async_data_slave_ar_rptr_o  ( async_data_slave_ar_rptr_o ),
        .async_data_slave_r_data_o   ( async_data_slave_r_data_o  ),
        .async_data_slave_r_wptr_o   ( async_data_slave_r_wptr_o  ),
        .async_data_slave_r_rptr_i   ( async_data_slave_r_rptr_i  ),

        .async_reg_req_req_i         ( async_reg_req_req_i   ),
        .async_reg_req_ack_o         ( async_reg_req_ack_o   ),
        .async_reg_req_data_i        ( async_reg_req_data_i  ),

        .async_reg_rsp_req_o         ( async_reg_rsp_req_o   ),
        .async_reg_rsp_ack_i         ( async_reg_rsp_ack_i   ),
        .async_reg_rsp_data_o        ( async_reg_rsp_data_o  ),

        .async_tx_wptr_i             ( async_tx_wptr_i  ),
        .async_tx_rptr_o             ( async_tx_rptr_o  ),
        .async_tx_data_i             ( async_tx_data_i  ),

        .async_rx_wptr_o             ( async_rx_wptr_o  ),
        .async_rx_rptr_i             ( async_rx_rptr_i  ),
        .async_rx_data_o             ( async_rx_data_o  ),

        .async_udma_reg_req_req_i    ( async_udma_reg_req_req_i  ),
        .async_udma_reg_req_ack_o    ( async_udma_reg_req_ack_o  ),
        .async_udma_reg_req_data_i   ( async_udma_reg_req_data_i ),

        .async_udma_reg_rsp_req_o    ( async_udma_reg_rsp_req_o  ),
        .async_udma_reg_rsp_ack_i    ( async_udma_reg_rsp_ack_i  ),
        .async_udma_reg_rsp_data_o   ( async_udma_reg_rsp_data_o ),

        .cfg_rx_startaddr_o     ( cfg_rx_startaddr_o   ),
        .cfg_rx_size_o          ( cfg_rx_size_o        ),
        .data_rx_datasize_o     ( data_rx_datasize_o   ),
        .cfg_rx_continuous_o    ( cfg_rx_continuous_o  ),
        .cfg_rx_en_o            ( cfg_rx_en_o          ),
        .cfg_rx_clr_o           ( cfg_rx_clr_o         ),
        .cfg_rx_en_i            ( cfg_rx_en_i          ),
        .cfg_rx_pending_i       ( cfg_rx_pending_i     ),
        .cfg_rx_curr_addr_i     ( cfg_rx_curr_addr_i   ),
        .cfg_rx_bytes_left_i    ( cfg_rx_bytes_left_i  ),

        .cfg_tx_startaddr_o     ( cfg_tx_startaddr_o   ),
        .cfg_tx_size_o          ( cfg_tx_size_o        ),
        .data_tx_datasize_o     ( data_tx_datasize_o   ),
        .cfg_tx_continuous_o    ( cfg_tx_continuous_o  ),
        .cfg_tx_en_o            ( cfg_tx_en_o          ),
        .cfg_tx_clr_o           ( cfg_tx_clr_o         ),
        .cfg_tx_en_i            ( cfg_tx_en_i          ),
        .cfg_tx_pending_i       ( cfg_tx_pending_i     ),
        .cfg_tx_curr_addr_i     ( cfg_tx_curr_addr_i   ),
        .cfg_tx_bytes_left_i    ( cfg_tx_bytes_left_i  ),

        .evt_eot_hyper_o        ( evt_eot_hyper_o      ),

        .pad_hyper_csn          ( pad_hyper_csn         ),
        .pad_hyper_ck           ( pad_hyper_ck          ),
        .pad_hyper_ckn          ( pad_hyper_ckn         ),
        .pad_hyper_rwds         ( pad_hyper_rwds        ),
        .pad_hyper_reset        ( pad_hyper_reset       ),
        .pad_hyper_dq           ( pad_hyper_dq          )

        );


endmodule : hyperbus_synth_wrap
