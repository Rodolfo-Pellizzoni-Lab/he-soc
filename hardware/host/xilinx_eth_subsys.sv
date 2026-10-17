// Xilinx AXI 1G Ethernet Subsystem + AXI DMA behind the host xbar's Ethernet port.
//
// Register window (ariane_soc::EthernetBase, 1 MB):
//   +0x0_0000  AXI Ethernet subsystem (axi_ethernet 7.2: TEMAC + SGMII-over-LVDS PCS/PMA, 256 KB)
//   +0x4_0000  AXI DMA (axi_dma 7.1, scatter-gather with the Ethernet control/status streams, 64 KB)
// The DMA's three AXI masters (descriptors, TX reads, RX writes) are muxed and split into single beats, which
// is what the coherence unit's DMA port takes (cva6_synth_wrap.sv): received frames and descriptor
// updates are snooped against the cores' L1 data caches, as Linux 5.10 (no non-coherent DMA on RISC-V) needs.
// Both IPs run on the SoC clock. Interrupts: the subsystem's, the DMA's TX (MM2S) and RX (S2MM) channels.
//
// On the FPGA, eth_sgmii and eth_dma are the generated IPs (hardware/fpga/alsaqr/tcl/ips/{eth,eth_dma}); in
// simulation eth_dma is the IP's own VHDL and eth_sgmii is tb/eth_sgmii_model.sv (a loopback MAC).
`include "axi/assign.svh"
`include "axi/typedef.svh"

module xilinx_eth_subsys
  import ariane_soc::*;
#(
  parameter int unsigned AxiAddrWidth = 64,
  parameter int unsigned AxiDataWidth = 64,
  parameter int unsigned AxiIdWidth   = 4,
  parameter int unsigned AxiUserWidth = 1,
  parameter type         dma_req_t    = logic,
  parameter type         dma_resp_t   = logic
) (
  input  logic          clk_i,
  input  logic          rst_ni,
  AXI_BUS.Slave         slv,          // the xbar's Ethernet port
  output dma_req_t      dma_req_o,    // single-beat, IDs 0/2/4: for the CCU's DMA port
  input  dma_resp_t     dma_resp_i,
  output logic          mac_irq_o,
  output logic          tx_irq_o,
  output logic          rx_irq_o,
  output xeth_to_pad_t  xeth_to_pad,
  input  pad_to_xeth_t  pad_to_xeth
);

  // ------------------------------------------------------------------------------------------------
  // Register path: 64-bit AXI -> 32-bit AXI -> AXI-Lite -> demux on address bit 18 (0: MAC, 1: DMA)
  // ------------------------------------------------------------------------------------------------
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ), .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH   ( AxiIdWidth   ), .AXI_USER_WIDTH ( AxiUserWidth )
  ) slv_cut();
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ), .AXI_DATA_WIDTH ( 32           ),
    .AXI_ID_WIDTH   ( AxiIdWidth   ), .AXI_USER_WIDTH ( AxiUserWidth )
  ) slv_cut32();
  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ), .AXI_DATA_WIDTH ( 32 )
  ) lite();

  axi_cut_intf #(
    .ADDR_WIDTH ( AxiAddrWidth ), .DATA_WIDTH ( AxiDataWidth ),
    .ID_WIDTH   ( AxiIdWidth   ), .USER_WIDTH ( AxiUserWidth )
  ) i_cut (
    .clk_i, .rst_ni, .in ( slv ), .out ( slv_cut )
  );

  axi_dw_converter_intf #(
    .AXI_ADDR_WIDTH          ( AxiAddrWidth ),
    .AXI_ID_WIDTH            ( AxiIdWidth   ),
    .AXI_USER_WIDTH          ( AxiUserWidth ),
    .AXI_MAX_READS           ( 1            ),
    .AXI_SLV_PORT_DATA_WIDTH ( AxiDataWidth ),
    .AXI_MST_PORT_DATA_WIDTH ( 32           )
  ) i_dw (
    .clk_i, .rst_ni, .slv ( slv_cut ), .mst ( slv_cut32 )
  );

  axi_to_axi_lite_intf #(
    .AXI_ADDR_WIDTH     ( AxiAddrWidth ),
    .AXI_DATA_WIDTH     ( 32           ),
    .AXI_ID_WIDTH       ( AxiIdWidth   ),
    .AXI_USER_WIDTH     ( AxiUserWidth ),
    .AXI_MAX_READ_TXNS  ( 1            ),
    .AXI_MAX_WRITE_TXNS ( 1            )
  ) i_to_lite (
    .clk_i, .rst_ni, .testmode_i ( 1'b0 ), .slv ( slv_cut32 ), .mst ( lite )
  );

  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [31:0]             data32_t;
  typedef logic [3:0]              strb32_t;
  `AXI_LITE_TYPEDEF_ALL(lite, addr_t, data32_t, strb32_t)

  lite_req_t        lite_req;
  lite_resp_t       lite_resp;
  lite_req_t  [1:0] ip_req;
  lite_resp_t [1:0] ip_resp;
  `AXI_LITE_ASSIGN_TO_REQ(lite_req, lite)
  `AXI_LITE_ASSIGN_FROM_RESP(lite, lite_resp)

  axi_lite_demux #(
    .aw_chan_t  ( lite_aw_chan_t ), .w_chan_t ( lite_w_chan_t ), .b_chan_t ( lite_b_chan_t ),
    .ar_chan_t  ( lite_ar_chan_t ), .r_chan_t ( lite_r_chan_t ),
    .axi_req_t  ( lite_req_t     ), .axi_resp_t ( lite_resp_t ),
    .NoMstPorts ( 2 ), .MaxTrans ( 2 ), .FallThrough ( 1'b0 ),
    .SpillAw ( 1'b1 ), .SpillW ( 1'b0 ), .SpillB ( 1'b0 ), .SpillAr ( 1'b1 ), .SpillR ( 1'b0 )
  ) i_lite_demux (
    .clk_i, .rst_ni, .test_i ( 1'b0 ),
    .slv_req_i       ( lite_req                 ),
    .slv_aw_select_i ( lite_req.aw.addr[18]     ),
    .slv_ar_select_i ( lite_req.ar.addr[18]     ),
    .slv_resp_o      ( lite_resp                ),
    .mst_reqs_o      ( ip_req                   ),
    .mst_resps_i     ( ip_resp                  )
  );

  // ------------------------------------------------------------------------------------------------
  // DMA masters: SG (32-bit) upsized to 64, then mux(3) -> burst splitter -> the port's ID width
  // ------------------------------------------------------------------------------------------------
  typedef logic [0:0]              mid_t;      // the IP masters carry no ID
  typedef logic [2:0]              muxid_t;    // + 2 bits of mux select
  typedef logic [63:0]             data64_t;
  typedef logic [7:0]              strb64_t;
  typedef logic [AxiUserWidth-1:0] user_t;
  `AXI_TYPEDEF_ALL(m32, addr_t, mid_t,   data32_t, strb32_t, user_t)
  `AXI_TYPEDEF_ALL(m64, addr_t, mid_t,   data64_t, strb64_t, user_t)
  `AXI_TYPEDEF_ALL(mux, addr_t, muxid_t, data64_t, strb64_t, user_t)

  m32_req_t         sg32_req;
  m32_resp_t        sg32_resp;
  m64_req_t  [2:0]  m64_req;     // 0: SG, 1: MM2S (reads), 2: S2MM (writes)
  m64_resp_t [2:0]  m64_resp;
  mux_req_t         mux_req, split_req;
  mux_resp_t        mux_resp, split_resp;

  axi_dw_converter #(
    .AxiMaxReads         ( 2            ),
    .AxiSlvPortDataWidth ( 32           ),
    .AxiMstPortDataWidth ( 64           ),
    .AxiAddrWidth        ( AxiAddrWidth ),
    .AxiIdWidth          ( 1            ),
    .aw_chan_t           ( m64_aw_chan_t ),
    .mst_w_chan_t        ( m64_w_chan_t  ),
    .slv_w_chan_t        ( m32_w_chan_t  ),
    .b_chan_t            ( m64_b_chan_t  ),
    .ar_chan_t           ( m64_ar_chan_t ),
    .mst_r_chan_t        ( m64_r_chan_t  ),
    .slv_r_chan_t        ( m32_r_chan_t  ),
    .axi_mst_req_t       ( m64_req_t     ),
    .axi_mst_resp_t      ( m64_resp_t    ),
    .axi_slv_req_t       ( m32_req_t     ),
    .axi_slv_resp_t      ( m32_resp_t    )
  ) i_sg_up (
    .clk_i, .rst_ni,
    .slv_req_i  ( sg32_req    ), .slv_resp_o ( sg32_resp   ),
    .mst_req_o  ( m64_req[0]  ), .mst_resp_i ( m64_resp[0] )
  );

  axi_mux #(
    .SlvAxiIDWidth ( 1             ),
    .slv_aw_chan_t ( m64_aw_chan_t ), .mst_aw_chan_t ( mux_aw_chan_t ),
    .w_chan_t      ( m64_w_chan_t  ),
    .slv_b_chan_t  ( m64_b_chan_t  ), .mst_b_chan_t  ( mux_b_chan_t  ),
    .slv_ar_chan_t ( m64_ar_chan_t ), .mst_ar_chan_t ( mux_ar_chan_t ),
    .slv_r_chan_t  ( m64_r_chan_t  ), .mst_r_chan_t  ( mux_r_chan_t  ),
    .slv_req_t     ( m64_req_t     ), .slv_resp_t    ( m64_resp_t    ),
    .mst_req_t     ( mux_req_t     ), .mst_resp_t    ( mux_resp_t    ),
    .NoSlvPorts    ( 3 ), .MaxWTrans ( 4 ), .FallThrough ( 1'b0 ),
    .SpillAw ( 1'b1 ), .SpillW ( 1'b0 ), .SpillB ( 1'b0 ), .SpillAr ( 1'b1 ), .SpillR ( 1'b0 )
  ) i_mux (
    .clk_i, .rst_ni, .test_i ( 1'b0 ),
    .slv_reqs_i  ( m64_req  ), .slv_resps_o ( m64_resp ),
    .mst_req_o   ( mux_req  ), .mst_resp_i  ( mux_resp )
  );

  axi_burst_splitter #(
    .MaxReadTxns  ( 4            ),
    .MaxWriteTxns ( 4            ),
    .FullBW       ( 1            ),
    .AddrWidth    ( AxiAddrWidth ),
    .DataWidth    ( 64           ),
    .IdWidth      ( 3            ),
    .UserWidth    ( AxiUserWidth ),
    .axi_req_t    ( mux_req_t    ),
    .axi_resp_t   ( mux_resp_t   )
  ) i_split (
    .clk_i, .rst_ni,
    .slv_req_i ( mux_req   ), .slv_resp_o ( mux_resp   ),
    .mst_req_o ( split_req ), .mst_resp_i ( split_resp )
  );

  // The port's ID is wider: zero-extend. The three masters keep distinct IDs (0, 2, 4 after the mux) that fit the
  // coherence unit's 4-bit ID, so no serialisation is needed.
  axi_id_width_adapt #(
    .slv_req_t ( mux_req_t ), .slv_resp_t ( mux_resp_t ), .mst_req_t ( dma_req_t ), .mst_resp_t ( dma_resp_t )
  ) i_port_id (
    .slv_req_i ( split_req ), .slv_resp_o ( split_resp ), .mst_req_o ( dma_req_o ), .mst_resp_i ( dma_resp_i )
  );
`ifndef SYNTHESIS
  axi_x_monitor #(.req_t(dma_req_t), .resp_t(dma_resp_t), .NAME("eth_dma")) i_xmon (.clk_i(clk_i), .req_i(dma_req_o), .resp_i(dma_resp_i));
`endif

  // ------------------------------------------------------------------------------------------------
  // The IPs
  // ------------------------------------------------------------------------------------------------
  logic [31:0] txd_tdata, txc_tdata, rxd_tdata, rxs_tdata;
  logic [3:0]  txd_tkeep, txc_tkeep, rxd_tkeep, rxs_tkeep;
  logic        txd_tvalid, txd_tready, txd_tlast, txc_tvalid, txc_tready, txc_tlast;
  logic        rxd_tvalid, rxd_tready, rxd_tlast, rxs_tvalid, rxs_tready, rxs_tlast;
  logic        txd_arstn, txc_arstn, rxd_arstn, rxs_arstn;

  // the IP masters: 32-bit addresses, no ID, no user, no lock/qos/region
  logic [31:0] sg_awaddr, sg_araddr, mm2s_araddr, s2mm_awaddr;
  logic [7:0]  sg_awlen, sg_arlen, mm2s_arlen, s2mm_awlen;
  logic [2:0]  sg_awsize, sg_arsize, mm2s_arsize, s2mm_awsize, sg_awprot, sg_arprot, mm2s_arprot, s2mm_awprot;
  logic [1:0]  sg_awburst, sg_arburst, mm2s_arburst, s2mm_awburst;
  logic [3:0]  sg_awcache, sg_arcache, mm2s_arcache, s2mm_awcache;
  logic        sg_awvalid, sg_arvalid, mm2s_arvalid, s2mm_awvalid;
  logic [31:0] sg_wdata;
  logic [3:0]  sg_wstrb;
  logic        sg_wlast, sg_wvalid, sg_bready, sg_rready;
  logic [63:0] s2mm_wdata;
  logic [7:0]  s2mm_wstrb;
  logic        s2mm_wlast, s2mm_wvalid, s2mm_bready, mm2s_rready;

  always_comb begin
    sg32_req = '0;
    sg32_req.aw.addr  = addr_t'(sg_awaddr);
    sg32_req.aw.len   = sg_awlen;
    sg32_req.aw.size  = sg_awsize;
    sg32_req.aw.burst = sg_awburst;
    sg32_req.aw.prot  = sg_awprot;
    sg32_req.aw.cache = sg_awcache;
    sg32_req.aw_valid = sg_awvalid;
    sg32_req.w.data   = sg_wdata;
    sg32_req.w.strb   = sg_wstrb;
    sg32_req.w.last   = sg_wlast;
    sg32_req.w_valid  = sg_wvalid;
    sg32_req.b_ready  = sg_bready;
    sg32_req.ar.addr  = addr_t'(sg_araddr);
    sg32_req.ar.len   = sg_arlen;
    sg32_req.ar.size  = sg_arsize;
    sg32_req.ar.burst = sg_arburst;
    sg32_req.ar.prot  = sg_arprot;
    sg32_req.ar.cache = sg_arcache;
    sg32_req.ar_valid = sg_arvalid;
    sg32_req.r_ready  = sg_rready;

    m64_req[1] = '0;                            // MM2S: reads only
    m64_req[1].ar.addr  = addr_t'(mm2s_araddr);
    m64_req[1].ar.len   = mm2s_arlen;
    m64_req[1].ar.size  = mm2s_arsize;
    m64_req[1].ar.burst = mm2s_arburst;
    m64_req[1].ar.prot  = mm2s_arprot;
    m64_req[1].ar.cache = mm2s_arcache;
    m64_req[1].ar_valid = mm2s_arvalid;
    m64_req[1].r_ready  = mm2s_rready;

    m64_req[2] = '0;                            // S2MM: writes only
    m64_req[2].aw.addr  = addr_t'(s2mm_awaddr);
    m64_req[2].aw.len   = s2mm_awlen;
    m64_req[2].aw.size  = s2mm_awsize;
    m64_req[2].aw.burst = s2mm_awburst;
    m64_req[2].aw.prot  = s2mm_awprot;
    m64_req[2].aw.cache = s2mm_awcache;
    m64_req[2].aw_valid = s2mm_awvalid;
    m64_req[2].w.data   = s2mm_wdata;
    m64_req[2].w.strb   = s2mm_wstrb;
    m64_req[2].w.last   = s2mm_wlast;
    m64_req[2].w_valid  = s2mm_wvalid;
    m64_req[2].b_ready  = s2mm_bready;
  end

  // The DMA's interrupt outputs are only taken once its own reset sequence is over: its reset-out lines must have
  // been high for 8 cycles. (On the IP's start-up they go high for one cycle and drop again, and during that cycle
  // its interrupt registers are recomputed from not-yet-initialised state, which the PLIC gateway would latch.)
  logic        mm2s_introut, s2mm_introut, dma_up;
  logic [3:0]  dma_up_cnt;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)                        dma_up_cnt <= '0;
    else if (!(txd_arstn && rxd_arstn)) dma_up_cnt <= '0;
    else if (!dma_up)                   dma_up_cnt <= dma_up_cnt + 1;
  end
  assign dma_up   = dma_up_cnt[3];
  assign tx_irq_o = dma_up & mm2s_introut;
  assign rx_irq_o = dma_up & s2mm_introut;

  eth_dma i_dma (
    .s_axi_lite_aclk          ( clk_i                 ),
    .m_axi_sg_aclk            ( clk_i                 ),
    .m_axi_mm2s_aclk          ( clk_i                 ),
    .m_axi_s2mm_aclk          ( clk_i                 ),
    .axi_resetn               ( rst_ni                ),
    .s_axi_lite_awvalid       ( ip_req[1].aw_valid    ),
    .s_axi_lite_awready       ( ip_resp[1].aw_ready   ),
    .s_axi_lite_awaddr        ( ip_req[1].aw.addr[9:0]),
    .s_axi_lite_wvalid        ( ip_req[1].w_valid     ),
    .s_axi_lite_wready        ( ip_resp[1].w_ready    ),
    .s_axi_lite_wdata         ( ip_req[1].w.data      ),
    .s_axi_lite_bresp         ( ip_resp[1].b.resp     ),
    .s_axi_lite_bvalid        ( ip_resp[1].b_valid    ),
    .s_axi_lite_bready        ( ip_req[1].b_ready     ),
    .s_axi_lite_arvalid       ( ip_req[1].ar_valid    ),
    .s_axi_lite_arready       ( ip_resp[1].ar_ready   ),
    .s_axi_lite_araddr        ( ip_req[1].ar.addr[9:0]),
    .s_axi_lite_rvalid        ( ip_resp[1].r_valid    ),
    .s_axi_lite_rready        ( ip_req[1].r_ready     ),
    .s_axi_lite_rdata         ( ip_resp[1].r.data     ),
    .s_axi_lite_rresp         ( ip_resp[1].r.resp     ),
    // descriptors (32-bit)
    .m_axi_sg_awaddr          ( sg_awaddr             ),
    .m_axi_sg_awlen           ( sg_awlen              ),
    .m_axi_sg_awsize          ( sg_awsize             ),
    .m_axi_sg_awburst         ( sg_awburst            ),
    .m_axi_sg_awprot          ( sg_awprot             ),
    .m_axi_sg_awcache         ( sg_awcache            ),
    .m_axi_sg_awvalid         ( sg_awvalid            ),
    .m_axi_sg_awready         ( sg32_resp.aw_ready    ),
    .m_axi_sg_wdata           ( sg_wdata              ),
    .m_axi_sg_wstrb           ( sg_wstrb              ),
    .m_axi_sg_wlast           ( sg_wlast              ),
    .m_axi_sg_wvalid          ( sg_wvalid             ),
    .m_axi_sg_wready          ( sg32_resp.w_ready     ),
    .m_axi_sg_bresp           ( sg32_resp.b.resp      ),
    .m_axi_sg_bvalid          ( sg32_resp.b_valid     ),
    .m_axi_sg_bready          ( sg_bready             ),
    .m_axi_sg_araddr          ( sg_araddr             ),
    .m_axi_sg_arlen           ( sg_arlen              ),
    .m_axi_sg_arsize          ( sg_arsize             ),
    .m_axi_sg_arburst         ( sg_arburst            ),
    .m_axi_sg_arprot          ( sg_arprot             ),
    .m_axi_sg_arcache         ( sg_arcache            ),
    .m_axi_sg_arvalid         ( sg_arvalid            ),
    .m_axi_sg_arready         ( sg32_resp.ar_ready    ),
    .m_axi_sg_rdata           ( sg32_resp.r.data      ),
    .m_axi_sg_rresp           ( sg32_resp.r.resp      ),
    .m_axi_sg_rlast           ( sg32_resp.r.last      ),
    .m_axi_sg_rvalid          ( sg32_resp.r_valid     ),
    .m_axi_sg_rready          ( sg_rready             ),
    // TX: memory to stream
    .m_axi_mm2s_araddr        ( mm2s_araddr           ),
    .m_axi_mm2s_arlen         ( mm2s_arlen            ),
    .m_axi_mm2s_arsize        ( mm2s_arsize           ),
    .m_axi_mm2s_arburst       ( mm2s_arburst          ),
    .m_axi_mm2s_arprot        ( mm2s_arprot           ),
    .m_axi_mm2s_arcache       ( mm2s_arcache          ),
    .m_axi_mm2s_arvalid       ( mm2s_arvalid          ),
    .m_axi_mm2s_arready       ( m64_resp[1].ar_ready  ),
    .m_axi_mm2s_rdata         ( m64_resp[1].r.data    ),
    .m_axi_mm2s_rresp         ( m64_resp[1].r.resp    ),
    .m_axi_mm2s_rlast         ( m64_resp[1].r.last    ),
    .m_axi_mm2s_rvalid        ( m64_resp[1].r_valid   ),
    .m_axi_mm2s_rready        ( mm2s_rready           ),
    .mm2s_prmry_reset_out_n   ( txd_arstn             ),
    .m_axis_mm2s_tdata        ( txd_tdata             ),
    .m_axis_mm2s_tkeep        ( txd_tkeep             ),
    .m_axis_mm2s_tvalid       ( txd_tvalid            ),
    .m_axis_mm2s_tready       ( txd_tready            ),
    .m_axis_mm2s_tlast        ( txd_tlast             ),
    .mm2s_cntrl_reset_out_n   ( txc_arstn             ),
    .m_axis_mm2s_cntrl_tdata  ( txc_tdata             ),
    .m_axis_mm2s_cntrl_tkeep  ( txc_tkeep             ),
    .m_axis_mm2s_cntrl_tvalid ( txc_tvalid            ),
    .m_axis_mm2s_cntrl_tready ( txc_tready            ),
    .m_axis_mm2s_cntrl_tlast  ( txc_tlast             ),
    // RX: stream to memory
    .m_axi_s2mm_awaddr        ( s2mm_awaddr           ),
    .m_axi_s2mm_awlen         ( s2mm_awlen            ),
    .m_axi_s2mm_awsize        ( s2mm_awsize           ),
    .m_axi_s2mm_awburst       ( s2mm_awburst          ),
    .m_axi_s2mm_awprot        ( s2mm_awprot           ),
    .m_axi_s2mm_awcache       ( s2mm_awcache          ),
    .m_axi_s2mm_awvalid       ( s2mm_awvalid          ),
    .m_axi_s2mm_awready       ( m64_resp[2].aw_ready  ),
    .m_axi_s2mm_wdata         ( s2mm_wdata            ),
    .m_axi_s2mm_wstrb         ( s2mm_wstrb            ),
    .m_axi_s2mm_wlast         ( s2mm_wlast            ),
    .m_axi_s2mm_wvalid        ( s2mm_wvalid           ),
    .m_axi_s2mm_wready        ( m64_resp[2].w_ready   ),
    .m_axi_s2mm_bresp         ( m64_resp[2].b.resp    ),
    .m_axi_s2mm_bvalid        ( m64_resp[2].b_valid   ),
    .m_axi_s2mm_bready        ( s2mm_bready           ),
    .s2mm_prmry_reset_out_n   ( rxd_arstn             ),
    .s_axis_s2mm_tdata        ( rxd_tdata             ),
    .s_axis_s2mm_tkeep        ( rxd_tkeep             ),
    .s_axis_s2mm_tvalid       ( rxd_tvalid            ),
    .s_axis_s2mm_tready       ( rxd_tready            ),
    .s_axis_s2mm_tlast        ( rxd_tlast             ),
    .s2mm_sts_reset_out_n     ( rxs_arstn             ),
    .s_axis_s2mm_sts_tdata    ( rxs_tdata             ),
    .s_axis_s2mm_sts_tkeep    ( rxs_tkeep             ),
    .s_axis_s2mm_sts_tvalid   ( rxs_tvalid            ),
    .s_axis_s2mm_sts_tready   ( rxs_tready            ),
    .s_axis_s2mm_sts_tlast    ( rxs_tlast             ),
    .mm2s_introut             ( mm2s_introut          ),
    .s2mm_introut             ( s2mm_introut          ),
    .axi_dma_tstvec           (                       )
  );

  eth_sgmii i_mac (
    .s_axi_lite_resetn   ( rst_ni                   ),
    .s_axi_lite_clk      ( clk_i                    ),
    .mac_irq             (                          ),
    .axis_clk            ( clk_i                    ),
    .axi_txd_arstn       ( txd_arstn                ),
    .axi_txc_arstn       ( txc_arstn                ),
    .axi_rxd_arstn       ( rxd_arstn                ),
    .axi_rxs_arstn       ( rxs_arstn                ),
    .interrupt           ( mac_irq_o                ),
    .signal_detect       ( 1'b1                     ),
    .clk125_out          (                          ),
    .clk312_out          (                          ),
    .rst_125_out         (                          ),
    // single LVDS lane: the shared-logic ports of the other lanes idle
    .riu_valid_3         ( 1'b0                     ),
    .riu_valid_2         ( 1'b0                     ),
    .riu_valid_1         ( 1'b0                     ),
    .riu_prsnt_3         ( 1'b0                     ),
    .riu_prsnt_2         ( 1'b0                     ),
    .riu_prsnt_1         ( 1'b0                     ),
    .riu_rddata_3        ( 16'h0                    ),
    .riu_rddata_2        ( 16'h0                    ),
    .riu_rddata_1        ( 16'h0                    ),
    .tx_dly_rdy_1        ( 1'b1                     ),
    .rx_dly_rdy_1        ( 1'b1                     ),
    .tx_vtc_rdy_1        ( 1'b1                     ),
    .rx_vtc_rdy_1        ( 1'b1                     ),
    .tx_dly_rdy_2        ( 1'b1                     ),
    .rx_dly_rdy_2        ( 1'b1                     ),
    .tx_vtc_rdy_2        ( 1'b1                     ),
    .rx_vtc_rdy_2        ( 1'b1                     ),
    .tx_dly_rdy_3        ( 1'b1                     ),
    .rx_dly_rdy_3        ( 1'b1                     ),
    .tx_vtc_rdy_3        ( 1'b1                     ),
    .rx_vtc_rdy_3        ( 1'b1                     ),
    .tx_logic_reset      (                          ),
    .rx_logic_reset      (                          ),
    .rx_locked           (                          ),
    .tx_locked           (                          ),
    .tx_bsc_rst_out      (                          ),
    .rx_bsc_rst_out      (                          ),
    .tx_bs_rst_out       (                          ),
    .rx_bs_rst_out       (                          ),
    .tx_rst_dly_out      (                          ),
    .rx_rst_dly_out      (                          ),
    .tx_bsc_en_vtc_out   (                          ),
    .tx_bs_en_vtc_out    (                          ),
    .rx_bsc_en_vtc_out   (                          ),
    .rx_bs_en_vtc_out    (                          ),
    .riu_clk_out         (                          ),
    .riu_wr_en_out       (                          ),
    .tx_pll_clk_out      (                          ),
    .rx_pll_clk_out      (                          ),
    .tx_rdclk_out        (                          ),
    .riu_addr_out        (                          ),
    .riu_wr_data_out     (                          ),
    .riu_nibble_sel_out  (                          ),
    .rx_btval_1          (                          ),
    .rx_btval_2          (                          ),
    .rx_btval_3          (                          ),
    .phy_rst_n           ( xeth_to_pad.phy_rst_n    ),
    .s_axi_araddr        ( ip_req[0].ar.addr[17:0]  ),
    .s_axi_arready       ( ip_resp[0].ar_ready      ),
    .s_axi_arvalid       ( ip_req[0].ar_valid       ),
    .s_axi_awaddr        ( ip_req[0].aw.addr[17:0]  ),
    .s_axi_awready       ( ip_resp[0].aw_ready      ),
    .s_axi_awvalid       ( ip_req[0].aw_valid       ),
    .s_axi_bready        ( ip_req[0].b_ready        ),
    .s_axi_bresp         ( ip_resp[0].b.resp        ),
    .s_axi_bvalid        ( ip_resp[0].b_valid       ),
    .s_axi_rdata         ( ip_resp[0].r.data        ),
    .s_axi_rready        ( ip_req[0].r_ready        ),
    .s_axi_rresp         ( ip_resp[0].r.resp        ),
    .s_axi_rvalid        ( ip_resp[0].r_valid       ),
    .s_axi_wdata         ( ip_req[0].w.data         ),
    .s_axi_wready        ( ip_resp[0].w_ready       ),
    .s_axi_wstrb         ( ip_req[0].w.strb         ),
    .s_axi_wvalid        ( ip_req[0].w_valid        ),
    .s_axis_txc_tdata    ( txc_tdata                ),
    .s_axis_txc_tkeep    ( txc_tkeep                ),
    .s_axis_txc_tlast    ( txc_tlast                ),
    .s_axis_txc_tready   ( txc_tready               ),
    .s_axis_txc_tvalid   ( txc_tvalid               ),
    .s_axis_txd_tdata    ( txd_tdata                ),
    .s_axis_txd_tkeep    ( txd_tkeep                ),
    .s_axis_txd_tlast    ( txd_tlast                ),
    .s_axis_txd_tready   ( txd_tready               ),
    .s_axis_txd_tvalid   ( txd_tvalid               ),
    .m_axis_rxd_tdata    ( rxd_tdata                ),
    .m_axis_rxd_tkeep    ( rxd_tkeep                ),
    .m_axis_rxd_tlast    ( rxd_tlast                ),
    .m_axis_rxd_tready   ( rxd_tready               ),
    .m_axis_rxd_tvalid   ( rxd_tvalid               ),
    .m_axis_rxs_tdata    ( rxs_tdata                ),
    .m_axis_rxs_tkeep    ( rxs_tkeep                ),
    .m_axis_rxs_tlast    ( rxs_tlast                ),
    .m_axis_rxs_tready   ( rxs_tready               ),
    .m_axis_rxs_tvalid   ( rxs_tvalid               ),
    .sgmii_rxn           ( pad_to_xeth.sgmii_rxn    ),
    .sgmii_rxp           ( pad_to_xeth.sgmii_rxp    ),
    .sgmii_txn           ( xeth_to_pad.sgmii_txn    ),
    .sgmii_txp           ( xeth_to_pad.sgmii_txp    ),
    .mdio_mdc            ( xeth_to_pad.mdc          ),
    .mdio_mdio_i         ( pad_to_xeth.mdio_i       ),
    .mdio_mdio_o         ( xeth_to_pad.mdio_o       ),
    .mdio_mdio_t         ( xeth_to_pad.mdio_t       ),
    .lvds_clk_clk_n      ( pad_to_xeth.lvds_clk_n   ),
    .lvds_clk_clk_p      ( pad_to_xeth.lvds_clk_p   )
  );

endmodule
