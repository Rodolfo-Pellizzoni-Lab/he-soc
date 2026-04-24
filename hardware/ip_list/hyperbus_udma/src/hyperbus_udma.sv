// Hyperbus AXI w/ uDMA

// this code is unstable and most likely buggy
// it should not be used by anyone

// Author: Thomas Benz <paulsc@iis.ee.ethz.ch>
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Contributor: Luca Valente <luca.valente@unibo.it>

`ifdef TARGET_POST_SYNTH_SIM
 `define INST_MACRO
`elsif TARGET_TOP_LEVEL
 `define INST_MACRO
`elsif TARGET_TOP_POST_SYNTH
 `define INST_MACRO
`endif

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "common_cells/registers.svh"

module hyperbus_udma #(
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
    parameter int unsigned  AxiLogDepth     = 3,
    parameter int unsigned  SyncStages      = 2,
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
    parameter type          axi_rule_t      = logic,
    // The below have sensible defaults, but should be set on integration!
    parameter int unsigned  RxFifoLogDepth  = 2,
    parameter int unsigned  TxFifoLogDepth  = 2,
    parameter logic [RegDataWidth-1:0] RstChipBase  = 'h0,      // Base address for all chips
    parameter logic [RegDataWidth-1:0] RstChipSpace = 'h1_0000, // 64 KiB: Current maximum HyperBus device size
    parameter int unsigned  PhyStartupCycles = 300 /*us*/ * 200 /*MHz*/ // Conservative maximum frequency estimate
) (
    input  logic                        clk_phy_i,
    input  logic                        rst_phy_ni,
    input  logic                        clk_sys_i,
    input  logic                        rst_sys_ni,
    input  logic                        test_mode_i,
    // AXI bus
    input  axi_req_t                    axi_req_i,
    output axi_rsp_t                    axi_rsp_o,
    // Reg bus
    input  reg_req_t                    reg_req_i,
    output reg_rsp_t                    reg_rsp_o,
    // UDMA interface
    input  logic [31:0]                 cfg_data_i,
    input  logic [4:0]                  cfg_addr_i,
    input  logic [NB_CH:0]              cfg_valid_i,
    input  logic                        cfg_rwn_i,
    output logic [NB_CH:0]              cfg_ready_o,
    output logic [NB_CH:0][31:0]        cfg_data_o,

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

    output logic                        data_tx_req_o,
    input  logic                        data_tx_gnt_i,
    input  logic               [31:0]   data_tx_i,
    input  logic                        data_tx_valid_i,
    output logic                        data_tx_ready_o,

    output logic               [31:0]   data_rx_o,
    output logic                        data_rx_valid_o,
    input  logic                        data_rx_ready_i,

    // Physical interace: facing HyperBus
    inout  [NumPhys-1:0][NumChips-1:0]  pad_hyper_csn,
    inout  [NumPhys-1:0]                pad_hyper_ck,
    inout  [NumPhys-1:0]                pad_hyper_ckn,
    inout  [NumPhys-1:0]                pad_hyper_rwds,
    inout  [NumPhys-1:0]                pad_hyper_reset,
    inout  [NumPhys-1:0][7:0]           pad_hyper_dq

);

  AXI_BUS_ASYNC_GRAY #(
     .AXI_ADDR_WIDTH ( AxiAddrWidth    ),
     .AXI_DATA_WIDTH ( AxiDataWidth    ),
     .AXI_ID_WIDTH   ( AxiIdWidth      ),
     .AXI_USER_WIDTH ( AxiUserWidth    ),
     .LOG_DEPTH      ( AxiLogDepth     )
  ) async_axi_dst();

  axi_cdc_src #(
    .aw_chan_t  ( axi_aw_chan_t  ),
    .w_chan_t   ( axi_w_chan_t   ),
    .b_chan_t   ( axi_b_chan_t   ),
    .ar_chan_t  ( axi_ar_chan_t  ),
    .r_chan_t   ( axi_r_chan_t   ),
    .axi_req_t  ( axi_req_t      ),
    .axi_resp_t ( axi_rsp_t      ),
    .LogDepth   ( AxiLogDepth    ),
    .SyncStages ( SyncStages     )
  ) i_axi_cdc_src (
    .src_clk_i                    ( clk_sys_i             ),
    .src_rst_ni                   ( rst_sys_ni            ),
    .src_req_i                    ( axi_req_i             ),
    .src_resp_o                   ( axi_rsp_o             ),
    .async_data_master_aw_data_o  ( async_axi_dst.aw_data ),
    .async_data_master_aw_wptr_o  ( async_axi_dst.aw_wptr ),
    .async_data_master_aw_rptr_i  ( async_axi_dst.aw_rptr ),
    .async_data_master_w_data_o   ( async_axi_dst.w_data  ),
    .async_data_master_w_wptr_o   ( async_axi_dst.w_wptr  ),
    .async_data_master_w_rptr_i   ( async_axi_dst.w_rptr  ),
    .async_data_master_b_data_i   ( async_axi_dst.b_data  ),
    .async_data_master_b_wptr_i   ( async_axi_dst.b_wptr  ),
    .async_data_master_b_rptr_o   ( async_axi_dst.b_rptr  ),
    .async_data_master_ar_data_o  ( async_axi_dst.ar_data ),
    .async_data_master_ar_wptr_o  ( async_axi_dst.ar_wptr ),
    .async_data_master_ar_rptr_i  ( async_axi_dst.ar_rptr ),
    .async_data_master_r_data_i   ( async_axi_dst.r_data  ),
    .async_data_master_r_wptr_i   ( async_axi_dst.r_wptr  ),
    .async_data_master_r_rptr_o   ( async_axi_dst.r_rptr  )
  );

    typedef struct packed {
       logic [L2_AWIDTH_NOAL-1:0]  s_startaddr;
       logic     [TRANS_SIZE-1:0]  s_size;
       logic                       s_continuous;
       logic                       s_en;
       logic                       s_clr;
       logic                [1:0]  s_datasize;
    } udma_cfg_o_t;

    typedef struct packed {
       logic                       s_en;
       logic                       s_pending;
       logic [L2_AWIDTH_NOAL-1:0]  s_curr_addr;
       logic     [TRANS_SIZE-1:0]  s_bytes_left;
    } udma_cfg_i_t;

    logic [3:0]                 s_async_udma_tx_wptr;
    logic [3:0]                 s_async_udma_tx_rptr;
    logic [31:0][7:0]           s_async_udma_tx_data;

    logic [31:0]                s_data_tx;
    logic                       s_data_tx_valid;
    logic                       s_data_tx_ready;

    logic [3:0]                 s_async_udma_rx_wptr;
    logic [3:0]                 s_async_udma_rx_rptr;
    logic [31:0][7:0]           s_async_udma_rx_data;

    udma_cfg_o_t         s_cfg_rx_o;
    udma_cfg_o_t         s_cfg_tx_o;
    udma_cfg_i_t         s_cfg_rx_i;
    udma_cfg_i_t         s_cfg_tx_i;

    udma_cfg_o_t         s_cfg_rx_o_sys;
    udma_cfg_o_t         s_cfg_tx_o_sys;
    udma_cfg_i_t         s_cfg_rx_i_sys;
    udma_cfg_i_t         s_cfg_tx_i_sys;

    logic          [NB_CH-1:0]  s_evt_eot_hyper;

    logic                        s_async_reg_req_req;
    logic                        s_async_reg_req_ack;
    reg_req_t                    s_async_reg_req_data;

    logic                        s_async_reg_rsp_req;
    logic                        s_async_reg_rsp_ack;
    reg_rsp_t                    s_async_reg_rsp_data;

    reg_cdc_src #(
     .req_t(reg_req_t),
     .rsp_t(reg_rsp_t)
    )i_reg_cdc_slave_intf (
      .src_clk_i    ( clk_sys_i            ),
      .src_rst_ni   ( rst_sys_ni           ),
      .src_req_i    ( reg_req_i            ),
      .src_rsp_o    ( reg_rsp_o            ),

      .async_req_o  ( s_async_reg_req_req  ),
      .async_ack_i  ( s_async_reg_req_ack  ),
      .async_data_o ( s_async_reg_req_data ),

      .async_req_i  ( s_async_reg_rsp_req  ),
      .async_ack_o  ( s_async_reg_rsp_ack  ),
      .async_data_i ( s_async_reg_rsp_data )
   );

   `REG_BUS_TYPEDEF_REQ(udma_cfg_reg_req_t,logic[4:0],logic[31:0],logic)
   `REG_BUS_TYPEDEF_RSP(udma_cfg_reg_rsp_t,logic[31:0])

    udma_cfg_reg_req_t [NB_CH:0] s_udma_cfg_reqs;
    udma_cfg_reg_req_t [NB_CH:0] s_udma_cfg_async_reqs;
    logic [NB_CH:0]              s_udma_cfg_async_reqs_req;
    logic [NB_CH:0]              s_udma_cfg_async_reqs_ack;

    udma_cfg_reg_rsp_t [NB_CH:0] s_udma_cfg_rsps;
    udma_cfg_reg_rsp_t [NB_CH:0] s_udma_cfg_async_rsps;
    logic [NB_CH:0]              s_udma_cfg_async_rsps_req;
    logic [NB_CH:0]              s_udma_cfg_async_rsps_ack;

    generate
       for(genvar i=0; i<NB_CH+1;i++) begin: udma_channel_bind
         assign  s_udma_cfg_reqs[i].addr  = cfg_addr_i;
         assign  s_udma_cfg_reqs[i].wdata = cfg_data_i;
         assign  s_udma_cfg_reqs[i].wstrb = '1;
         assign  s_udma_cfg_reqs[i].valid = cfg_valid_i[i];
         assign  s_udma_cfg_reqs[i].write = cfg_rwn_i;
         assign  cfg_data_o[i] = s_udma_cfg_rsps[i].rdata;
         assign  cfg_ready_o[i]= s_udma_cfg_rsps[i].ready;

         reg_cdc_src #(
          .req_t(udma_cfg_reg_req_t),
          .rsp_t(udma_cfg_reg_rsp_t)
         )i_reg_cdc_slave_intf (
           .src_clk_i    ( clk_sys_i                    ),
           .src_rst_ni   ( rst_sys_ni                   ),
           .src_req_i    ( s_udma_cfg_reqs[i]           ),
           .src_rsp_o    ( s_udma_cfg_rsps[i]           ),

           .async_req_o  ( s_udma_cfg_async_reqs_req[i] ),
           .async_ack_i  ( s_udma_cfg_async_reqs_ack[i] ),
           .async_data_o ( s_udma_cfg_async_reqs[i]     ),

           .async_req_i  ( s_udma_cfg_async_rsps_req[i] ),
           .async_ack_o  ( s_udma_cfg_async_rsps_ack[i] ),
           .async_data_i ( s_udma_cfg_async_rsps[i]     )
         );
    end
   endgenerate

   `ifndef INST_MACRO
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
        .axi_aw_chan_t    ( axi_aw_chan_t      ),
        .axi_w_chan_t     ( axi_w_chan_t       ),
        .axi_b_chan_t     ( axi_b_chan_t       ),
        .axi_ar_chan_t    ( axi_ar_chan_t      ),
        .axi_r_chan_t     ( axi_r_chan_t       ),
        .RegAddrWidth     ( RegAddrWidth       ),
        .RegDataWidth     ( RegDataWidth       ),
        .reg_req_t        ( reg_req_t          ),
        .reg_rsp_t        ( reg_rsp_t          ),
        .udma_reg_req_t   ( udma_cfg_reg_req_t ),
        .udma_reg_rsp_t   ( udma_cfg_reg_rsp_t ),
        .axi_rule_t       ( axi_rule_t         ),
        .AxiLogDepth      ( AxiLogDepth        ),
        .SyncStages       ( SyncStages         ),
        .RxFifoLogDepth   ( RxFifoLogDepth     ),
        .TxFifoLogDepth   ( TxFifoLogDepth     ),
        .RstChipBase      ( RstChipBase        ),
        .RstChipSpace     ( RstChipSpace       ),
        .PhyStartupCycles ( PhyStartupCycles   )
    ) i_hyperbus_macro (
      `else
     hyperbus_synth_wrap i_hyperbus_macro (
      `endif
        .clk_phy_i              ( clk_phy_i             ),
        .rst_phy_ni             ( rst_phy_ni            ),
        .clk_sys_i              ( clk_sys_i             ),
        .rst_sys_ni             ( rst_sys_ni            ),
        .test_mode_i            ( test_mode_i           ),

        .async_data_slave_aw_data_i  ( async_axi_dst.aw_data ),
        .async_data_slave_aw_wptr_i  ( async_axi_dst.aw_wptr ),
        .async_data_slave_aw_rptr_o  ( async_axi_dst.aw_rptr ),
        .async_data_slave_w_data_i   ( async_axi_dst.w_data  ),
        .async_data_slave_w_wptr_i   ( async_axi_dst.w_wptr  ),
        .async_data_slave_w_rptr_o   ( async_axi_dst.w_rptr  ),
        .async_data_slave_b_data_o   ( async_axi_dst.b_data  ),
        .async_data_slave_b_wptr_o   ( async_axi_dst.b_wptr  ),
        .async_data_slave_b_rptr_i   ( async_axi_dst.b_rptr  ),
        .async_data_slave_ar_data_i  ( async_axi_dst.ar_data ),
        .async_data_slave_ar_wptr_i  ( async_axi_dst.ar_wptr ),
        .async_data_slave_ar_rptr_o  ( async_axi_dst.ar_rptr ),
        .async_data_slave_r_data_o   ( async_axi_dst.r_data  ),
        .async_data_slave_r_wptr_o   ( async_axi_dst.r_wptr  ),
        .async_data_slave_r_rptr_i   ( async_axi_dst.r_rptr  ),

        .async_reg_req_req_i         ( s_async_reg_req_req   ),
        .async_reg_req_ack_o         ( s_async_reg_req_ack   ),
        .async_reg_req_data_i        ( s_async_reg_req_data  ),

        .async_reg_rsp_req_o         ( s_async_reg_rsp_req   ),
        .async_reg_rsp_ack_i         ( s_async_reg_rsp_ack   ),
        .async_reg_rsp_data_o        ( s_async_reg_rsp_data  ),

        .async_tx_wptr_i             ( s_async_udma_tx_wptr  ),
        .async_tx_rptr_o             ( s_async_udma_tx_rptr  ),
        .async_tx_data_i             ( s_async_udma_tx_data  ),

        .async_rx_wptr_o             ( s_async_udma_rx_wptr  ),
        .async_rx_rptr_i             ( s_async_udma_rx_rptr  ),
        .async_rx_data_o             ( s_async_udma_rx_data  ),

        .async_udma_reg_req_req_i    ( s_udma_cfg_async_reqs_req ),
        .async_udma_reg_req_ack_o    ( s_udma_cfg_async_reqs_ack ),
        .async_udma_reg_req_data_i   ( s_udma_cfg_async_reqs     ),

        .async_udma_reg_rsp_req_o    ( s_udma_cfg_async_rsps_req ),
        .async_udma_reg_rsp_ack_i    ( s_udma_cfg_async_rsps_ack ),
        .async_udma_reg_rsp_data_o   ( s_udma_cfg_async_rsps     ),

        .cfg_rx_startaddr_o     ( s_cfg_rx_o.s_startaddr    ),
        .cfg_rx_size_o          ( s_cfg_rx_o.s_size         ),
        .data_rx_datasize_o     ( s_cfg_rx_o.s_datasize     ),
        .cfg_rx_continuous_o    ( s_cfg_rx_o.s_continuous   ),
        .cfg_rx_en_o            ( s_cfg_rx_o.s_en           ),
        .cfg_rx_clr_o           ( s_cfg_rx_o.s_clr          ),
        .cfg_rx_en_i            ( s_cfg_rx_i.s_en           ),
        .cfg_rx_pending_i       ( s_cfg_rx_i.s_pending      ),
        .cfg_rx_curr_addr_i     ( s_cfg_rx_i.s_curr_addr    ),
        .cfg_rx_bytes_left_i    ( s_cfg_rx_i.s_bytes_left   ),

        .cfg_tx_startaddr_o     ( s_cfg_tx_o.s_startaddr    ),
        .cfg_tx_size_o          ( s_cfg_tx_o.s_size         ),
        .data_tx_datasize_o     ( s_cfg_tx_o.s_datasize     ),
        .cfg_tx_continuous_o    ( s_cfg_tx_o.s_continuous   ),
        .cfg_tx_en_o            ( s_cfg_tx_o.s_en           ),
        .cfg_tx_clr_o           ( s_cfg_tx_o.s_clr          ),
        .cfg_tx_en_i            ( s_cfg_tx_i.s_en           ),
        .cfg_tx_pending_i       ( s_cfg_tx_i.s_pending      ),
        .cfg_tx_curr_addr_i     ( s_cfg_tx_i.s_curr_addr    ),
        .cfg_tx_bytes_left_i    ( s_cfg_tx_i.s_bytes_left   ),

        .evt_eot_hyper_o        ( s_evt_eot_hyper       ),

        .pad_hyper_csn          ( pad_hyper_csn         ),
        .pad_hyper_ck           ( pad_hyper_ck          ),
        .pad_hyper_ckn          ( pad_hyper_ckn         ),
        .pad_hyper_rwds         ( pad_hyper_rwds        ),
        .pad_hyper_reset        ( pad_hyper_reset       ),
        .pad_hyper_dq           ( pad_hyper_dq          )

        );


    cdc_fifo_gray_src #(
       .T(logic[31:0]),
       .LOG_DEPTH   (     3      ),
       .SYNC_STAGES ( SyncStages )
       ) udma_tx_src_fifo (
         .async_data_o(s_async_udma_tx_data),
         .async_wptr_o(s_async_udma_tx_wptr),
         .async_rptr_i(s_async_udma_tx_rptr),
         .src_rst_ni(rst_sys_ni),
         .src_clk_i(clk_sys_i),
         .src_data_i(s_data_tx),
         .src_valid_i(s_data_tx_valid),
         .src_ready_o(s_data_tx_ready)
         );

    io_tx_fifo #(
      .DATA_WIDTH(32),
      .BUFFER_DEPTH(4)
      ) u_fifo (
        .clk_i   ( clk_sys_i       ),
        .rstn_i  ( rst_sys_ni      ),
        .clr_i   ( 1'b0            ),
        .data_o  ( s_data_tx       ),
        .valid_o ( s_data_tx_valid ),
        .ready_i ( s_data_tx_ready ),
        .req_o   ( data_tx_req_o   ),
        .gnt_i   ( data_tx_gnt_i   ),
        .valid_i ( data_tx_valid_i ),
        .data_i  ( data_tx_i       ),
        .ready_o ( data_tx_ready_o )
    );

   cdc_fifo_gray_dst #(
    .T(logic[31:0]),
    .LOG_DEPTH  (      3     ),
    .SYNC_STAGES( SyncStages )
    ) udma_rx_src_fifo (
      .dst_clk_i          ( clk_sys_i            ),
      .dst_rst_ni         ( rst_sys_ni           ),
      .dst_data_o         ( data_rx_o            ),
      .dst_valid_o        ( data_rx_valid_o      ),
      .dst_ready_i        ( data_rx_ready_i      ),
      .async_data_i       ( s_async_udma_rx_data ),
      .async_wptr_i       ( s_async_udma_rx_wptr ),
      .async_rptr_o       ( s_async_udma_rx_rptr )
      );

   `FFARN(s_cfg_rx_o_sys,s_cfg_rx_o,'0,clk_sys_i,rst_sys_ni);

   assign   cfg_rx_startaddr_o = s_cfg_rx_o_sys.s_startaddr;
   assign   cfg_rx_size_o = s_cfg_rx_o_sys.s_size;
   assign   cfg_rx_continuous_o = s_cfg_rx_o_sys.s_continuous;
   assign   cfg_rx_en_o  = s_cfg_rx_o_sys.s_en;
   assign   cfg_rx_clr_o = s_cfg_rx_o_sys.s_clr;
   assign   data_rx_datasize_o = s_cfg_rx_o_sys.s_datasize;

   `FFARN(s_cfg_tx_o_sys,s_cfg_tx_o,'0,clk_sys_i,rst_sys_ni);

   assign   cfg_tx_startaddr_o = s_cfg_tx_o_sys.s_startaddr;
   assign   cfg_tx_size_o = s_cfg_tx_o_sys.s_size;
   assign   cfg_tx_continuous_o = s_cfg_tx_o_sys.s_continuous;
   assign   cfg_tx_en_o  = s_cfg_tx_o_sys.s_en;
   assign   cfg_tx_clr_o = s_cfg_tx_o_sys.s_clr;
   assign   data_tx_datasize_o = s_cfg_tx_o_sys.s_datasize;

   `FFARN(s_cfg_rx_i,s_cfg_rx_i_sys,'0,clk_sys_i,rst_sys_ni);

   assign s_cfg_rx_i_sys.s_en         =   cfg_rx_en_i;
   assign s_cfg_rx_i_sys.s_pending    =   cfg_rx_pending_i;
   assign s_cfg_rx_i_sys.s_curr_addr  =   cfg_rx_curr_addr_i;
   assign s_cfg_rx_i_sys.s_bytes_left =   cfg_rx_bytes_left_i;

   `FFARN(s_cfg_tx_i,s_cfg_tx_i_sys,'0,clk_sys_i,rst_sys_ni);

   assign s_cfg_tx_i_sys.s_en         =   cfg_tx_en_i;
   assign s_cfg_tx_i_sys.s_pending    =   cfg_tx_pending_i;
   assign s_cfg_tx_i_sys.s_curr_addr  =   cfg_tx_curr_addr_i;
   assign s_cfg_tx_i_sys.s_bytes_left =   cfg_tx_bytes_left_i;

   `FFARN(evt_eot_hyper_o, s_evt_eot_hyper, '0, clk_sys_i, rst_sys_ni);

endmodule : hyperbus_udma
