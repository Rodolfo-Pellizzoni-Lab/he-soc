// Hyperbus AXI

// this code is unstable and most likely buggy
// it should not be used by anyone

// Author: Thomas Benz <paulsc@iis.ee.ethz.ch>
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Contributor: Luca Valente <luca.valente@unibo.it>

module hyperbus_async_macro #(
    parameter int unsigned  NumChips        = -1,
    parameter int unsigned  NumPhys         = 2,
    parameter int unsigned  IsClockODelayed = 0,
    parameter int unsigned  L2_AWIDTH_NOAL  = 12,
    parameter int unsigned  TRANS_SIZE      = 16,
    parameter int unsigned  NB_CH           = 1,
    parameter int unsigned  AxiAddrWidth    = -1,
    parameter int unsigned  AxiDataWidth    = -1,
    parameter int unsigned  AxiIdWidth      = -1,
    parameter int unsigned  AxiUserWidth    = -1,
    parameter type          axi_req_t       = logic,
    parameter type          axi_rsp_t       = logic,
    parameter type          axi_w_chan_t    = logic,
    parameter type          axi_b_chan_t    = logic,
    parameter type          axi_ar_chan_t   = logic,
    parameter type          axi_r_chan_t    = logic,
    parameter type          axi_aw_chan_t   = logic,
    parameter int unsigned  RegAddrWidth    = -1,
    parameter int unsigned  RegDataWidth    = -1,
    parameter type          reg_req_t       = logic,
    parameter type          reg_rsp_t       = logic,
    parameter type          udma_reg_req_t  = logic,
    parameter type          udma_reg_rsp_t  = logic,
    parameter type          axi_rule_t      = logic,
    // The below have sensible defaults, but should be set on integration!
    parameter int unsigned  RxFifoLogDepth  = 2,
    parameter int unsigned  TxFifoLogDepth  = 2,
    parameter logic [RegDataWidth-1:0] RstChipBase  = 'h0,      // Base address for all chips
    parameter logic [RegDataWidth-1:0] RstChipSpace = 'h1_0000, // 64 KiB: Current maximum HyperBus device size
    parameter int unsigned  PhyStartupCycles = 300 * 200, /* us*MHz */ // Conservative maximum frequency estimate
    parameter int unsigned  AxiLogDepth = 3,
    parameter int unsigned  SyncStages  = 2
) (
    input  logic                        clk_phy_i,
    input  logic                        rst_phy_ni,
    input  logic                        clk_sys_i,
    input  logic                        rst_sys_ni,
    input  logic                        test_mode_i,
    // AXI bus
    input  axi_aw_chan_t [2**AxiLogDepth-1:0] async_data_slave_aw_data_i,
    input  logic              [AxiLogDepth:0] async_data_slave_aw_wptr_i,
    output logic              [AxiLogDepth:0] async_data_slave_aw_rptr_o,
    input  axi_w_chan_t  [2**AxiLogDepth-1:0] async_data_slave_w_data_i,
    input  logic              [AxiLogDepth:0] async_data_slave_w_wptr_i,
    output logic              [AxiLogDepth:0] async_data_slave_w_rptr_o,
    output axi_b_chan_t  [2**AxiLogDepth-1:0] async_data_slave_b_data_o,
    output logic              [AxiLogDepth:0] async_data_slave_b_wptr_o,
    input  logic              [AxiLogDepth:0] async_data_slave_b_rptr_i,
    input  axi_ar_chan_t [2**AxiLogDepth-1:0] async_data_slave_ar_data_i,
    input  logic              [AxiLogDepth:0] async_data_slave_ar_wptr_i,
    output logic              [AxiLogDepth:0] async_data_slave_ar_rptr_o,
    output axi_r_chan_t  [2**AxiLogDepth-1:0] async_data_slave_r_data_o,
    output logic              [AxiLogDepth:0] async_data_slave_r_wptr_o,
    input  logic              [AxiLogDepth:0] async_data_slave_r_rptr_i,
    // Reg bus
    input  logic                  async_reg_req_req_i,
    output logic                  async_reg_req_ack_o,
    input  reg_req_t              async_reg_req_data_i,

    output logic                  async_reg_rsp_req_o,
    input  logic                  async_reg_rsp_ack_i,
    output reg_rsp_t              async_reg_rsp_data_o,

    // UDMA interface
    input  logic           [NB_CH:0] async_udma_reg_req_req_i,
    output logic           [NB_CH:0] async_udma_reg_req_ack_o,
    input  udma_reg_req_t  [NB_CH:0] async_udma_reg_req_data_i,

    output logic           [NB_CH:0] async_udma_reg_rsp_req_o,
    input  logic           [NB_CH:0] async_udma_reg_rsp_ack_i,
    output udma_reg_rsp_t  [NB_CH:0] async_udma_reg_rsp_data_o,

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
    output logic [31:0][7:0]            async_rx_data_o,

    input logic [3:0]                   async_tx_wptr_i,
    output logic [3:0]                  async_tx_rptr_o,
    input logic [31:0][7:0]             async_tx_data_i,

    // Physical interace: facing HyperBus
    inout  [NumPhys-1:0][NumChips-1:0]  pad_hyper_csn,
    inout  [NumPhys-1:0]                pad_hyper_ck,
    inout  [NumPhys-1:0]                pad_hyper_ckn,
    inout  [NumPhys-1:0]                pad_hyper_rwds,
    inout  [NumPhys-1:0]                pad_hyper_reset,
    inout  [NumPhys-1:0][7:0]           pad_hyper_dq
);

  axi_req_t                    axi_req_i;
  axi_rsp_t                    axi_rsp_o;

  import hyper_pad_reg_pkg::hyper_pad_reg2hw_t;

  hyper_pad_reg_pkg::hyper_pad_reg2hw_t s_pad_cfg;

  axi_cdc_dst #(
    .aw_chan_t  ( axi_aw_chan_t ),
    .w_chan_t   ( axi_w_chan_t  ),
    .b_chan_t   ( axi_b_chan_t  ),
    .ar_chan_t  ( axi_ar_chan_t ),
    .r_chan_t   ( axi_r_chan_t  ),
    .axi_req_t  ( axi_req_t     ),
    .axi_resp_t ( axi_rsp_t     ),
    .LogDepth   ( AxiLogDepth   ),
    .SyncStages ( SyncStages    )
  ) i_axi_cdc_dst (
    .async_data_slave_aw_data_i ( async_data_slave_aw_data_i ),
    .async_data_slave_aw_wptr_i ( async_data_slave_aw_wptr_i ),
    .async_data_slave_aw_rptr_o ( async_data_slave_aw_rptr_o ),
    .async_data_slave_w_data_i  ( async_data_slave_w_data_i  ),
    .async_data_slave_w_wptr_i  ( async_data_slave_w_wptr_i  ),
    .async_data_slave_w_rptr_o  ( async_data_slave_w_rptr_o  ),
    .async_data_slave_b_data_o  ( async_data_slave_b_data_o  ),
    .async_data_slave_b_wptr_o  ( async_data_slave_b_wptr_o  ),
    .async_data_slave_b_rptr_i  ( async_data_slave_b_rptr_i  ),
    .async_data_slave_ar_data_i ( async_data_slave_ar_data_i ),
    .async_data_slave_ar_wptr_i ( async_data_slave_ar_wptr_i ),
    .async_data_slave_ar_rptr_o ( async_data_slave_ar_rptr_o ),
    .async_data_slave_r_data_o  ( async_data_slave_r_data_o  ),
    .async_data_slave_r_wptr_o  ( async_data_slave_r_wptr_o  ),
    .async_data_slave_r_rptr_i  ( async_data_slave_r_rptr_i  ),
    .dst_clk_i                  ( clk_sys_i                  ),
    .dst_rst_ni                 ( rst_sys_ni                 ),
    .dst_req_o                  ( axi_req_i                  ),
    .dst_resp_i                 ( axi_rsp_o                  )
  );

    reg_req_t                    reg_req_i, pad_reg_req_i, cfg_reg_req_i;
    reg_rsp_t                    reg_rsp_o, pad_reg_rsp_o, cfg_reg_rsp_o;

    reg_cdc_dst #(
    .req_t(reg_req_t),
    .rsp_t(reg_rsp_t)
    )i_reg_master_cdc_intf (
      .dst_clk_i(clk_sys_i),
      .dst_rst_ni(rst_sys_ni),
      .dst_req_o(reg_req_i),
      .dst_rsp_i(reg_rsp_o),

      .async_req_i(async_reg_req_req_i),
      .async_ack_o(async_reg_req_ack_o),
      .async_data_i(async_reg_req_data_i),

      .async_req_o(async_reg_rsp_req_o),
      .async_ack_i(async_reg_rsp_ack_i),
      .async_data_o(async_reg_rsp_data_o)
   );

   reg_demux #(
    .NoPorts ( 2         ),
    .req_t   ( reg_req_t ),
    .rsp_t   ( reg_rsp_t )
   ) i_reg_demux (
       .clk_i       ( clk_sys_i                      ),
       .rst_ni      ( rst_sys_ni                     ),
       .in_select_i ( reg_req_i.addr[8]              ),
       .in_req_i    ( reg_req_i                      ),
       .in_rsp_o    ( reg_rsp_o                      ),
       .out_req_o   ( {pad_reg_req_i, cfg_reg_req_i} ),
       .out_rsp_i   ( {pad_reg_rsp_o, cfg_reg_rsp_o} )
   );

    logic [31:0]                 cfg_data_i;
    logic [4:0]                  cfg_addr_i;
    logic [NB_CH:0]              cfg_valid_i;
    logic                        cfg_rwn_i;
    logic [NB_CH:0]              cfg_ready_o;
    logic [31:0][NB_CH:0]        cfg_data_o;

    udma_reg_req_t [NB_CH:0] s_udma_cfg_reqs;
    udma_reg_rsp_t [NB_CH:0] s_udma_cfg_rsps;

    logic [2:0]                            whichvalid;

    onehot_to_bin #(
                    .ONEHOT_WIDTH(NB_CH+1),
                    .BIN_WIDTH(3)
                    ) i_onehot_to_bin (
                       .onehot(cfg_valid_i),
                       .bin(whichvalid)
                    );


    assign  cfg_addr_i = s_udma_cfg_reqs[whichvalid].addr ;
    assign  cfg_data_i = s_udma_cfg_reqs[whichvalid].wdata;
    assign  cfg_rwn_i = s_udma_cfg_reqs[whichvalid].write;

    generate
       for(genvar i=0; i<NB_CH+1;i++) begin: udma_channel_bind
         assign  cfg_valid_i[i] = s_udma_cfg_reqs[i].valid;
         assign  s_udma_cfg_rsps[i].rdata = cfg_data_o[i];
         assign  s_udma_cfg_rsps[i].ready = cfg_ready_o[i];
         assign  s_udma_cfg_rsps[i].error = 1'b0;

         reg_cdc_dst #(
          .req_t(udma_reg_req_t),
          .rsp_t(udma_reg_rsp_t)
         )i_reg_cdc_master_intf (
           .dst_clk_i    ( clk_sys_i                    ),
           .dst_rst_ni   ( rst_sys_ni                   ),
           .dst_req_o    ( s_udma_cfg_reqs[i]           ),
           .dst_rsp_i    ( s_udma_cfg_rsps[i]           ),

           .async_req_o  ( async_udma_reg_rsp_req_o[i]  ),
           .async_ack_i  ( async_udma_reg_rsp_ack_i[i]  ),
           .async_data_o ( async_udma_reg_rsp_data_o[i] ),

           .async_req_i  ( async_udma_reg_req_req_i[i]  ),
           .async_ack_o  ( async_udma_reg_req_ack_o[i]  ),
           .async_data_i ( async_udma_reg_req_data_i[i] )
         );
    end
   endgenerate

   typedef struct packed {
        logic [(16*NumPhys)-1:0]    data;
        logic                       last;
        logic [(2*NumPhys)-1:0]     strb;   // mask data
    } hyper_tx_t;

    typedef struct packed {
        logic [(16*NumPhys)-1:0]    data;
        logic                       last;
        logic                       error;
    } hyper_rx_t;

    // Combined transfer type for CDC
    typedef struct packed {
        hyperbus_pkg::hyper_tf_t    trans;
        logic [NumChips-1:0]        cs;
    } tf_cdc_t;


    logic                       clk_phy_i_0, clk_phy_i_90, rst_phy;

    // Register file
    hyperbus_pkg::hyper_cfg_t   cfg;
    axi_rule_t [NumChips-1:0]   chip_rules;
    logic                       trans_active;

    // AXI slave
    hyper_rx_t                  axi_rx;
    logic                       axi_rx_valid;
    logic                       axi_rx_ready;
    hyper_tx_t                  axi_tx;
    logic                       axi_tx_valid;
    logic                       axi_tx_ready;
    logic                       axi_b_error;
    logic                       axi_b_valid;
    logic                       axi_b_ready;
    tf_cdc_t                    axi_tf_cdc;
    logic                       axi_trans_valid;
    logic                       axi_trans_ready;

    // PHY
    hyper_rx_t                  axi_phy_rx;
    logic                       axi_phy_rx_valid;
    logic                       axi_phy_rx_ready;
    hyper_tx_t                  axi_phy_tx;
    logic                       axi_phy_tx_valid;
    logic                       axi_phy_tx_ready;
    logic                       axi_phy_b_error;
    logic                       axi_phy_b_valid;
    logic                       axi_phy_b_ready;
    tf_cdc_t                    axi_phy_tf_cdc;
    logic                       axi_phy_trans_valid;
    logic                       axi_phy_trans_ready;

    // PHY
    hyper_rx_t                  phy_rx;
    logic                       phy_rx_valid;
    logic                       phy_rx_ready;
    hyper_tx_t                  phy_tx;
    logic                       phy_tx_valid;
    logic                       phy_tx_ready;
    logic                       phy_b_error;
    logic                       phy_b_valid;
    logic                       phy_b_ready;
    tf_cdc_t                    phy_tf_cdc;
    logic                       phy_trans_valid;
    logic                       phy_trans_ready;

    logic [NumPhys-1:0][NumChips-1:0] hyper_cs_n_wire;
    logic [NumPhys-1:0]               hyper_ck_wire;
    logic [NumPhys-1:0]               hyper_ck_n_wire;
    logic [NumPhys-1:0]               hyper_rwds_o;
    logic [NumPhys-1:0]               hyper_rwds_i;
    logic [NumPhys-1:0]               hyper_rwds_oe;
    logic [NumPhys-1:0][7:0]          hyper_dq_i;
    logic [NumPhys-1:0][7:0]          hyper_dq_o;
    logic [NumPhys-1:0]               hyper_dq_oe;
    logic [NumPhys-1:0]               hyper_reset_n_wire;

    // Config register File
    hyperbus_cfg_regs #(
        .NumChips       ( NumChips      ),
        .NumPhys        ( NumPhys       ),
        .RegAddrWidth   ( RegAddrWidth  ),
        .RegDataWidth   ( RegDataWidth  ),
        .reg_req_t      ( reg_req_t     ),
        .reg_rsp_t      ( reg_rsp_t     ),
        .rule_t         ( axi_rule_t    ),
        .RstChipBase    ( RstChipBase   ),
        .RstChipSpace   ( RstChipSpace  )
    ) i_cfg_regs (
        .clk_i          ( clk_sys_i     ),
        .rst_ni         ( rst_sys_ni    ),
        .reg_req_i      ( cfg_reg_req_i ),
        .reg_rsp_o      ( cfg_reg_rsp_o ),
        .cfg_o          ( cfg           ),
        .chip_rules_o   ( chip_rules    ),
        .trans_active_i ( trans_active  )
    );

   hyper_pad_reg_top #(
     .reg_req_t      ( reg_req_t     ),
     .reg_rsp_t      ( reg_rsp_t     ),
     .AW             ( 5             )
   ) i_hyper_pad_reg_top (
       .clk_i          ( clk_sys_i     ),
       .rst_ni         ( rst_sys_ni    ),
       .reg_req_i      ( pad_reg_req_i ),
       .reg_rsp_o      ( pad_reg_rsp_o ),
       .reg2hw         ( s_pad_cfg     ),
       .devmode_i      ( 1'b0          )
   );

    // AXI slave interfacing PHY
    hyperbus_axi #(
        .AxiDataWidth   ( AxiDataWidth      ),
        .AxiAddrWidth   ( AxiAddrWidth      ),
        .AxiIdWidth     ( AxiIdWidth        ),
        .AxiUserWidth   ( AxiUserWidth      ),
        .axi_req_t      ( axi_req_t         ),
        .axi_rsp_t      ( axi_rsp_t         ),
        .NumChips       ( NumChips          ),
        .NumPhys        ( NumPhys           ),
        .hyper_rx_t     ( hyper_rx_t        ),
        .hyper_tx_t     ( hyper_tx_t        ),
        .rule_t         ( axi_rule_t        )
    ) i_axi_slave (
        .clk_i          ( clk_sys_i         ),
        .rst_ni         ( rst_sys_ni        ),

        .axi_req_i      ( axi_req_i         ),
        .axi_rsp_o      ( axi_rsp_o         ),

        .rx_i           ( axi_rx            ),
        .rx_valid_i     ( axi_rx_valid      ),
        .rx_ready_o     ( axi_rx_ready      ),
        .tx_o           ( axi_tx            ),
        .tx_valid_o     ( axi_tx_valid      ),
        .tx_ready_i     ( axi_tx_ready      ),
        .b_error_i      ( axi_b_error       ),
        .b_valid_i      ( axi_b_valid       ),
        .b_ready_o      ( axi_b_ready       ),
        .trans_o        ( axi_tf_cdc.trans  ),
        .trans_cs_o     ( axi_tf_cdc.cs     ),
        .trans_valid_o  ( axi_trans_valid   ),
        .trans_ready_i  ( axi_trans_ready   ),

        .chip_rules_i       ( chip_rules            ),
        .which_phy_i        ( cfg.which_phy         ),
        .phys_in_use_i      ( cfg.phys_in_use       ),
        .addr_mask_msb_i    ( cfg.address_mask_msb  ),
        .addr_space_i       ( cfg.address_space     ),
        .trans_active_o     ( trans_active          )
    );

    hyperbus_phy_if #(
        .IsClockODelayed( IsClockODelayed   ),
        .NumChips       ( NumChips          ),
        .StartupCycles  ( PhyStartupCycles  ),
        .NumPhys        ( NumPhys           ),
        .hyper_rx_t     ( hyper_rx_t        ),
        .hyper_tx_t     ( hyper_tx_t        ),
        .SyncStages     ( SyncStages        )
    ) i_phy (
        .clk_i          ( clk_phy_i_0       ),
        .clk_i_90       ( clk_phy_i_90      ),
        .rst_ni         ( rst_phy           ),
        .test_mode_i    ( test_mode_i       ),

        .cfg_i          ( cfg               ),

        .rx_o           ( phy_rx            ),
        .rx_valid_o     ( phy_rx_valid      ),
        .rx_ready_i     ( phy_rx_ready      ),
        .tx_i           ( phy_tx            ),
        .tx_valid_i     ( phy_tx_valid      ),
        .tx_ready_o     ( phy_tx_ready      ),
        .b_error_o      ( phy_b_error       ),
        .b_valid_o      ( phy_b_valid       ),
        .b_ready_i      ( phy_b_ready       ),
        .trans_i        ( phy_tf_cdc.trans  ),
        .trans_cs_i     ( phy_tf_cdc.cs     ),
        .trans_valid_i  ( phy_trans_valid   ),
        .trans_ready_o  ( phy_trans_ready   ),

        .hyper_cs_no    ( hyper_cs_n_wire       ),
        .hyper_ck_o     ( hyper_ck_wire         ),
        .hyper_ck_no    ( hyper_ck_n_wire       ),
        .hyper_rwds_o   ( hyper_rwds_o          ),
        .hyper_rwds_i   ( hyper_rwds_i          ),
        .hyper_rwds_oe_o( hyper_rwds_oe         ),
        .hyper_dq_i     ( hyper_dq_i            ),
        .hyper_dq_o     ( hyper_dq_o            ),
        .hyper_dq_oe_o  ( hyper_dq_oe           ),
        .hyper_reset_no ( hyper_reset_n_wire    )
    );

    cdc_2phase #(
        .T  ( tf_cdc_t  )
    ) i_cdc_2phase_trans (
        .src_rst_ni     ( rst_sys_ni        ),
        .src_clk_i      ( clk_sys_i         ),
        .src_data_i     ( axi_tf_cdc        ),
        .src_valid_i    ( axi_trans_valid   ),
        .src_ready_o    ( axi_trans_ready   ),

        .dst_rst_ni     ( rst_phy           ),
        .dst_clk_i      ( clk_phy_i_0       ),
        .dst_data_o     ( axi_phy_tf_cdc        ),
        .dst_valid_o    ( axi_phy_trans_valid   ),
        .dst_ready_i    ( axi_phy_trans_ready   )
    );

    cdc_2phase #(
        .T  ( logic )
    ) i_cdc_2phase_b (
        .src_rst_ni     ( rst_phy       ),
        .src_clk_i      ( clk_phy_i_0   ),
        .src_data_i     ( axi_phy_b_error   ),
        .src_valid_i    ( axi_phy_b_valid   ),
        .src_ready_o    ( axi_phy_b_ready   ),

        .dst_rst_ni     ( rst_sys_ni    ),
        .dst_clk_i      ( clk_sys_i     ),
        .dst_data_o     ( axi_b_error   ),
        .dst_valid_o    ( axi_b_valid   ),
        .dst_ready_i    ( axi_b_ready   )
    );

    // Write data, TX CDC FIFO
    cdc_fifo_gray  #(
        .T          ( hyper_tx_t     ),
        .LOG_DEPTH  ( TxFifoLogDepth ),
        .SYNC_STAGES( SyncStages     )
    ) i_cdc_fifo_tx (
        .src_rst_ni     ( rst_sys_ni    ),
        .src_clk_i      ( clk_sys_i     ),
        .src_data_i     ( axi_tx        ),
        .src_valid_i    ( axi_tx_valid  ),
        .src_ready_o    ( axi_tx_ready  ),

        .dst_rst_ni     ( rst_phy       ),
        .dst_clk_i      ( clk_phy_i_0   ),
        .dst_data_o     ( axi_phy_tx       ),
        .dst_valid_o    ( axi_phy_tx_valid ),
        .dst_ready_i    ( axi_phy_tx_ready )
    );

    // Read data, RX CDC FIFO
    cdc_fifo_gray  #(
        .T          ( hyper_rx_t     ),
        .LOG_DEPTH  ( RxFifoLogDepth ),
        .SYNC_STAGES( SyncStages     )
    ) i_cdc_fifo_rx (
        .src_rst_ni     ( rst_phy       ),
        .src_clk_i      ( clk_phy_i_0   ),
        .src_data_i     ( axi_phy_rx       ),
        .src_valid_i    ( axi_phy_rx_valid ),
        .src_ready_o    ( axi_phy_rx_ready ),

        .dst_rst_ni     ( rst_sys_ni    ),
        .dst_clk_i      ( clk_sys_i     ),
        .dst_data_o     ( axi_rx        ),
        .dst_valid_o    ( axi_rx_valid  ),
        .dst_ready_i    ( axi_rx_ready  )
    );


    logic                   s_sel;

    // PHY
    hyper_rx_t                  udma_phy_rx;
    logic                       udma_phy_rx_valid;
    logic                       udma_phy_rx_ready;
    hyper_tx_t                  udma_phy_tx;
    logic                       udma_phy_tx_valid;
    logic                       udma_phy_tx_ready;
    tf_cdc_t                    udma_phy_tf_cdc;
    logic                       udma_phy_trans_valid;
    logic                       udma_phy_trans_ready;

    logic [3:0]                 s_async_udma_tx_wptr;
    logic [3:0]                 s_async_udma_tx_rptr;
    logic [31:0][7:0]           s_async_udma_tx_data;

    logic [31:0]                s_data_tx;
    logic                       s_data_tx_valid;
    logic                       s_data_tx_ready;

    logic [3:0]                 s_async_udma_rx_wptr;
    logic [3:0]                 s_async_udma_rx_rptr;
    logic [31:0][7:0]           s_async_udma_rx_data;

  udma_hyperbus #(
    .L2_AWIDTH_NOAL  (L2_AWIDTH_NOAL),
    .TRANS_SIZE      (TRANS_SIZE),
    .SYNC_STAGES     ( SyncStages ),
    .DELAY_BIT_WIDTH (4),
    .NumChips        (NumChips),
    .NB_CH           (NB_CH),
    .NumPhys         (NumPhys),
    .hyper_rx_t      (hyper_rx_t),
    .hyper_tx_t      (hyper_tx_t)
   ) udma_hyper (
        .sys_clk_i               ( clk_sys_i                    ),
        .clk_phy_i               ( clk_phy_i_0                  ),
        .rst_ni                  ( rst_sys_ni                   ),
        .phy_rst_ni              ( rst_phy                      ),

        .cfg_data_i              ( cfg_data_i                   ),
        .cfg_addr_i              ( cfg_addr_i                   ),
        .cfg_valid_i             ( cfg_valid_i                  ),
        .cfg_rwn_i               ( cfg_rwn_i                    ),
        .cfg_ready_o             ( cfg_ready_o                  ),
        .cfg_data_o              ( cfg_data_o                   ),

        .async_tx_wptr_i         ( async_tx_wptr_i              ),
        .async_tx_rptr_o         ( async_tx_rptr_o              ),
        .async_tx_data_i         ( async_tx_data_i              ),

        .async_rx_wptr_o         ( async_rx_wptr_o              ),
        .async_rx_rptr_i         ( async_rx_rptr_i              ),
        .async_rx_data_o         ( async_rx_data_o              ),

        .udma_rx_startaddr_o     ( cfg_rx_startaddr_o           ),
        .udma_rx_size_o          ( cfg_rx_size_o                ),
        .cfg_rx_datasize_o       ( data_rx_datasize_o           ),
        .cfg_rx_continuous_o     ( cfg_rx_continuous_o          ),
        .udma_rx_en_o            ( cfg_rx_en_o                  ),
        .cfg_rx_clr_o            ( cfg_rx_clr_o                 ),
        .cfg_rx_en_i             ( cfg_rx_en_i                  ),
        .cfg_rx_pending_i        ( cfg_rx_pending_i             ),
        .cfg_rx_curr_addr_i      ( cfg_rx_curr_addr_i           ),
        .cfg_rx_bytes_left_i     ( cfg_rx_bytes_left_i          ),

        .udma_tx_startaddr_o     ( cfg_tx_startaddr_o           ),
        .udma_tx_size_o          ( cfg_tx_size_o                ),
        .cfg_tx_datasize_o       ( data_tx_datasize_o           ),
        .cfg_tx_continuous_o     ( cfg_tx_continuous_o          ),
        .udma_tx_en_o            ( cfg_tx_en_o                  ),
        .cfg_tx_clr_o            ( cfg_tx_clr_o                 ),
        .cfg_tx_en_i             ( cfg_tx_en_i                  ),
        .cfg_tx_pending_i        ( cfg_tx_pending_i             ),
        .cfg_tx_curr_addr_i      ( cfg_tx_curr_addr_i           ),
        .cfg_tx_bytes_left_i     ( cfg_tx_bytes_left_i          ),
        .evt_eot_hyper_o         ( evt_eot_hyper_o              ),
        // phy interface
        // we keep configuring the phy with the config regs
        .config_t_latency_access(),
        .config_en_latency_additional(),
        .config_t_cs_max(),
        .config_t_read_write_recovery(),
        .config_t_variable_latency_check(),
        .config_t_rwds_delay_line(),

        .trans_valid_o(udma_phy_trans_valid),
        .trans_ready_i(udma_phy_trans_ready),
        .udma_phy_tf(udma_phy_tf_cdc.trans),
        .trans_cs_o(udma_phy_tf_cdc.cs),        // chipselect

        .tx_valid_o(udma_phy_tx_valid),
        .tx_ready_i(udma_phy_tx_ready),
        .udma_phy_tx(udma_phy_tx),

        .rx_valid_i(udma_phy_rx_valid),
        .rx_ready_o(udma_phy_rx_ready),
        .udma_phy_rx(udma_phy_rx),

        .mem_sel_o(),
        .busy_o()
        );

 hyperbus_arbiter i_hyperbus_arbiter
   (
   .clk_i          ( clk_phy_i_0       ),
   .rst_ni         ( rst_phy           ),
   .udma_phy_trans_valid(udma_phy_trans_valid),
   .udma_phy_trans_ready(udma_phy_trans_ready),
   .axi_phy_trans_valid(axi_phy_trans_valid),
   .axi_phy_trans_ready(axi_phy_trans_ready),
   .phy_rx_valid(phy_rx_valid),
   .phy_rx_ready(phy_rx_ready),
   .phy_rx_last(phy_rx.last),
   .phy_tx_valid(phy_tx_valid),
   .phy_tx_ready(phy_tx_ready),
   .phy_tx_last(phy_tx.last),
   .sel_o(s_sel)
   );

 stream_mux #(
  .DATA_T(hyper_tx_t),
  .N_INP(2)
 )tx_mux(
  .inp_data_i({udma_phy_tx,axi_phy_tx}),
  .inp_valid_i({udma_phy_tx_valid,axi_phy_tx_valid}),
  .inp_ready_o({udma_phy_tx_ready,axi_phy_tx_ready}),

  .inp_sel_i(s_sel),

  .oup_data_o(phy_tx),
  .oup_valid_o(phy_tx_valid),
  .oup_ready_i(phy_tx_ready)
  );

 stream_mux #(
  .DATA_T(tf_cdc_t),
  .N_INP(2)
 )trans_mux(
  .inp_data_i({udma_phy_tf_cdc,axi_phy_tf_cdc}),
  .inp_valid_i({udma_phy_trans_valid,axi_phy_trans_valid}),
  .inp_ready_o({udma_phy_trans_ready,axi_phy_trans_ready}),

  .inp_sel_i(s_sel),

  .oup_data_o(phy_tf_cdc),
  .oup_valid_o(phy_trans_valid),
  .oup_ready_i(phy_trans_ready)
  );

 stream_demux #(
  .N_OUP(2)
 )rx_demux(
  .inp_valid_i(phy_rx_valid),
  .inp_ready_o(phy_rx_ready),

  .oup_sel_i(s_sel),

  .oup_valid_o({udma_phy_rx_valid,axi_phy_rx_valid}),
  .oup_ready_i({udma_phy_rx_ready,axi_phy_rx_ready})
  );

   assign udma_phy_rx = phy_rx;
   assign axi_phy_rx = phy_rx;


   assign axi_phy_b_error = s_sel ? '0 : phy_b_error;
   assign axi_phy_b_valid = s_sel ? '0 : phy_b_valid;
   assign phy_b_ready     = s_sel ? 1'b1 : axi_phy_b_ready;

    // Shift clock by 90 degrees
   generate
    if(IsClockODelayed==0) begin : clock_generator
     hyperbus_clk_gen ddr_clk (
         .clk_i    ( clk_phy_i                       ),
         .rst_ni   ( rst_phy_ni                      ),
         .clk0_o   ( clk_phy_i_0                     ),
         .clk90_o  ( clk_phy_i_90                    ),
         .clk180_o (                                 ),
         .clk270_o (                                 ),
         .rst_no   ( rst_phy                         )
     );
     end else if (IsClockODelayed==1) begin
     assign clk_phy_i_0 = clk_phy_i;
     assign rst_phy = rst_phy_ni;
     hyperbus_delay i_delay_tx_clk_90 (
         .in_i       ( clk_phy_i_0        ),
         .delay_i    ( cfg.t_tx_clk_delay ),
         .out_o      ( clk_phy_i_90       )
         );
       end
    endgenerate

   wire PWROK_S, IOPWROK_S, BIAS_S, RETC_S;

   for (genvar i = 0 ; i<NumPhys; i++) begin: pad_gen
    for (genvar j = 0; j<NumChips; j++) begin
      pad_alsaqr_pd padinst_hyper_csno   (.OEN( 1'b0            ), .I( hyper_cs_n_wire[i][j] ), .O(                  ), .PAD( pad_hyper_csn[i][j] ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[j+i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[j+i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[j+i*(12+NumChips)].smt.q) );
    end
    pad_alsaqr_pd padinst_hyper_ck     (.OEN( 1'b0            ), .I( hyper_ck_wire[i]      ), .O(                  ), .PAD( pad_hyper_ck[i]     ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  0 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  0 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  0 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_ckno   (.OEN( 1'b0            ), .I( hyper_ck_n_wire[i]    ), .O(                  ), .PAD( pad_hyper_ckn[i]    ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  1 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  1 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  1 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_rwds0  (.OEN(~hyper_rwds_oe[i]), .I( hyper_rwds_o[i]       ), .O( hyper_rwds_i[i]  ), .PAD( pad_hyper_rwds[i]   ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  2 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  2 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  2 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_resetn (.OEN( 1'b0            ), .I( hyper_reset_n_wire[i] ), .O(                  ), .PAD( pad_hyper_reset[i]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  3 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  3 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  3 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio0  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][0]      ), .O( hyper_dq_i[i][0] ), .PAD( pad_hyper_dq[i][0]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  4 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  4 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  4 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio1  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][1]      ), .O( hyper_dq_i[i][1] ), .PAD( pad_hyper_dq[i][1]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  5 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  5 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  5 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio2  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][2]      ), .O( hyper_dq_i[i][2] ), .PAD( pad_hyper_dq[i][2]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  6 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  6 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  6 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio3  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][3]      ), .O( hyper_dq_i[i][3] ), .PAD( pad_hyper_dq[i][3]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  7 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  7 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  7 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio4  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][4]      ), .O( hyper_dq_i[i][4] ), .PAD( pad_hyper_dq[i][4]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  8 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  8 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  8 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio5  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][5]      ), .O( hyper_dq_i[i][5] ), .PAD( pad_hyper_dq[i][5]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips +  9 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips +  9 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips +  9 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio6  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][6]      ), .O( hyper_dq_i[i][6] ), .PAD( pad_hyper_dq[i][6]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips + 10 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips + 10 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips + 10 + i*(12+NumChips)].smt.q) );
    pad_alsaqr_pd padinst_hyper_dqio7  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][7]      ), .O( hyper_dq_i[i][7] ), .PAD( pad_hyper_dq[i][7]  ), .PWROK(PWROK_S), .IOPWROK(IOPWROK_S), .BIAS(BIAS_S), .RETC(RETC_S), .DRV(s_pad_cfg.pads[NumChips + 11 + i*(12+NumChips)].drv.q), .SLW(s_pad_cfg.pads[NumChips + 11 + i*(12+NumChips)].slw.q), .SMT(s_pad_cfg.pads[NumChips + 11 + i*(12+NumChips)].smt.q) );
   end

   `ifdef TARGET_ASIC
      IN22FDX_GPIO18_10M19S40PI_PWRDET_TIE_H PWRDET_PAD (
        .RETCOUT    ( RETC_S    ),
        .PWROKOUT   ( PWROK_S   ),
        .IOPWROKOUT ( IOPWROK_S ),
        .RETCIN     ( 1'b0      ),
        .BIAS       ( BIAS_S    )
      );
    `endif

endmodule : hyperbus_async_macro
