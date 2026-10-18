// Simulation stand-in for the Xilinx AXI 1G Ethernet Subsystem (eth_sgmii, hardware/fpga/alsaqr/tcl/ips/eth):
// the same ports as the generated IP, so xilinx_eth_subsys.sv is identical in xsim and on the FPGA.
//
// What it does: an AXI4-Lite register file with the registers the drivers touch (reset bits self-clear, MDIO
// emulation of the DP83867 at address 3 and of the internal PCS/PMA at address 1, both reporting link up at 1G),
// and a MAC that loops every transmitted frame back to the receive side: the TX data stream is collected (the
// control stream is accepted and ignored), padded to 60 bytes, and replayed as the 6-word RX status stream (tag + app0-4,
// the length in the last word, which the DMA uses to size its write) followed by the RX data, which is what the AXI DMA writes into the descriptor and the
// axienet driver reads. One frame in flight; the TX stream is back-pressured while a frame is being replayed.
// The SGMII, LVDS clock and MDIO pins are ignored.
module eth_sgmii (
  input  logic        s_axi_lite_resetn,
  input  logic        s_axi_lite_clk,
  output logic        mac_irq,
  input  logic        axis_clk,
  input  logic        axi_txd_arstn,
  input  logic        axi_txc_arstn,
  input  logic        axi_rxd_arstn,
  input  logic        axi_rxs_arstn,
  output logic        interrupt,
  input  logic        signal_detect,
  output logic        clk125_out,
  output logic        clk312_out,
  output logic        rst_125_out,
  input  logic        riu_valid_3, riu_valid_2, riu_valid_1,
  input  logic        riu_prsnt_3, riu_prsnt_2, riu_prsnt_1,
  input  logic [15:0] riu_rddata_3, riu_rddata_2, riu_rddata_1,
  input  logic        tx_dly_rdy_1, rx_dly_rdy_1, tx_vtc_rdy_1, rx_vtc_rdy_1,
  input  logic        tx_dly_rdy_2, rx_dly_rdy_2, tx_vtc_rdy_2, rx_vtc_rdy_2,
  input  logic        tx_dly_rdy_3, rx_dly_rdy_3, tx_vtc_rdy_3, rx_vtc_rdy_3,
  output logic        tx_logic_reset, rx_logic_reset, rx_locked, tx_locked,
  output logic        tx_bsc_rst_out, rx_bsc_rst_out, tx_bs_rst_out, rx_bs_rst_out,
  output logic        tx_rst_dly_out, rx_rst_dly_out,
  output logic        tx_bsc_en_vtc_out, tx_bs_en_vtc_out, rx_bsc_en_vtc_out, rx_bs_en_vtc_out,
  output logic        riu_clk_out, riu_wr_en_out, tx_pll_clk_out, rx_pll_clk_out, tx_rdclk_out,
  output logic [5:0]  riu_addr_out,
  output logic [15:0] riu_wr_data_out,
  output logic [1:0]  riu_nibble_sel_out,
  output logic [8:0]  rx_btval_1, rx_btval_2, rx_btval_3,
  output logic [0:0]  phy_rst_n,
  input  logic [17:0] s_axi_araddr,
  output logic        s_axi_arready,
  input  logic        s_axi_arvalid,
  input  logic [17:0] s_axi_awaddr,
  output logic        s_axi_awready,
  input  logic        s_axi_awvalid,
  input  logic        s_axi_bready,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  output logic [31:0] s_axi_rdata,
  input  logic        s_axi_rready,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic [31:0] s_axi_wdata,
  output logic        s_axi_wready,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  input  logic [31:0] s_axis_txc_tdata,
  input  logic [3:0]  s_axis_txc_tkeep,
  input  logic        s_axis_txc_tlast,
  output logic        s_axis_txc_tready,
  input  logic        s_axis_txc_tvalid,
  input  logic [31:0] s_axis_txd_tdata,
  input  logic [3:0]  s_axis_txd_tkeep,
  input  logic        s_axis_txd_tlast,
  output logic        s_axis_txd_tready,
  input  logic        s_axis_txd_tvalid,
  output logic [31:0] m_axis_rxd_tdata,
  output logic [3:0]  m_axis_rxd_tkeep,
  output logic        m_axis_rxd_tlast,
  input  logic        m_axis_rxd_tready,
  output logic        m_axis_rxd_tvalid,
  output logic [31:0] m_axis_rxs_tdata,
  output logic [3:0]  m_axis_rxs_tkeep,
  output logic        m_axis_rxs_tlast,
  input  logic        m_axis_rxs_tready,
  output logic        m_axis_rxs_tvalid,
  input  logic        sgmii_rxn,
  input  logic        sgmii_rxp,
  output logic        sgmii_txn,
  output logic        sgmii_txp,
  output logic        mdio_mdc,
  input  logic        mdio_mdio_i,
  output logic        mdio_mdio_o,
  output logic        mdio_mdio_t,
  input  logic        lvds_clk_clk_n,
  input  logic        lvds_clk_clk_p
);

  // the physical side idles
  assign clk125_out = 1'b0; assign clk312_out = 1'b0; assign rst_125_out = 1'b0;
  assign tx_logic_reset = 1'b0; assign rx_logic_reset = 1'b0; assign rx_locked = 1'b1; assign tx_locked = 1'b1;
  assign tx_bsc_rst_out = 1'b0; assign rx_bsc_rst_out = 1'b0; assign tx_bs_rst_out = 1'b0; assign rx_bs_rst_out = 1'b0;
  assign tx_rst_dly_out = 1'b0; assign rx_rst_dly_out = 1'b0;
  assign tx_bsc_en_vtc_out = 1'b0; assign tx_bs_en_vtc_out = 1'b0; assign rx_bsc_en_vtc_out = 1'b0; assign rx_bs_en_vtc_out = 1'b0;
  assign riu_clk_out = 1'b0; assign riu_wr_en_out = 1'b0; assign tx_pll_clk_out = 1'b0; assign rx_pll_clk_out = 1'b0;
  assign tx_rdclk_out = 1'b0; assign riu_addr_out = '0; assign riu_wr_data_out = '0; assign riu_nibble_sel_out = '0;
  assign rx_btval_1 = '0; assign rx_btval_2 = '0; assign rx_btval_3 = '0;
  assign phy_rst_n = 1'b1;
  assign sgmii_txn = 1'b0; assign sgmii_txp = 1'b0;
  assign mdio_mdc = 1'b0; assign mdio_mdio_o = 1'b0; assign mdio_mdio_t = 1'b1;
  assign mac_irq = 1'b0;

  // ------------------------------------------------------------------------------------------------
  // registers (xilinx_axienet.h names)
  // ------------------------------------------------------------------------------------------------
  localparam logic [17:0] RAF = 18'h000, IS = 18'h00C, IP = 18'h010, IE = 18'h014;
  localparam logic [17:0] RCW0 = 18'h400, RCW1 = 18'h404, TC = 18'h408, FCC = 18'h40C, EMMC = 18'h410, PHYC = 18'h414;
  localparam logic [17:0] ID = 18'h4F8, MDIO_MC = 18'h500, MDIO_MCR = 18'h504, MDIO_MWD = 18'h508, MDIO_MRD = 18'h50C;
  localparam logic [31:0] INT_RXCMPIT = 32'h4, INT_TXCMPIT = 32'h20;

  logic [31:0] regs [logic [17:0]];      // everything else: plain storage
  logic [31:0] r_is, r_ie, r_rcw1, r_tc, r_emmc, r_mdio_mc, r_mdio_mcr, r_mdio_mwd, r_mdio_mrd;
  logic [15:0] phy3 [0:31];              // DP83867
  logic [15:0] phy1 [0:31];              // internal PCS/PMA
  logic [15:0] phy3_ext [logic [15:0]];  // DP83867 extended registers (REGCR/ADDAR)
  logic        rx_frame_done, tx_frame_done;

  function automatic logic [15:0] mdio_read(input logic [4:0] phyad, input logic [4:0] regad);
    if (phyad == 5'd3) begin
      if (regad == 5'h0E && phy3[5'h0D][15:14] == 2'b01) return phy3_ext.exists(phy3[5'h1F]) ? phy3_ext[phy3[5'h1F]] : 16'h0;
      return phy3[regad];
    end
    if (phyad == 5'd1) return phy1[regad];
    return 16'hFFFF;   // nobody there
  endfunction

  task automatic mdio_write(input logic [4:0] phyad, input logic [4:0] regad, input logic [15:0] data);
    if (phyad == 5'd3) begin
      if (regad == 5'h00)      phy3[0] = data & 16'h7FFF;                // reset bit self-clears
      else if (regad == 5'h0D) phy3[5'h0D] = data;                       // REGCR: function + device address
      else if (regad == 5'h0E) begin                                     // ADDAR: address or data
        if (phy3[5'h0D][15:14] == 2'b00) phy3[5'h1F] = data;             // the extended address, kept in a spare slot
        else                             phy3_ext[phy3[5'h1F]] = data;
      end
      else phy3[regad] = data;
    end else if (phyad == 5'd1) begin
      if (regad == 5'h00) phy1[0] = data & 16'h7FFF; else phy1[regad] = data;
    end
  endtask

  function automatic logic [31:0] reg_read(input logic [17:0] a);
    case (a)
      IS:       return r_is;
      IP:       return r_is & r_ie;
      IE:       return r_ie;
      RCW1:     return r_rcw1;
      TC:       return r_tc;
      EMMC:     return r_emmc;
      ID:       return 32'h0900_0000;   // what the 7.2 IP reads on the board
      MDIO_MC:  return r_mdio_mc;
      MDIO_MCR: return r_mdio_mcr | 32'h80;      // always ready
      MDIO_MWD: return r_mdio_mwd;
      MDIO_MRD: return r_mdio_mrd | 32'h1_0000;  // MIIM ready
      default:  return regs.exists(a) ? regs[a] : 32'h0;
    endcase
  endfunction

  // AXI-Lite: one write and one read at a time, responses a cycle later
  logic        aw_got, w_got;
  logic [17:0] aw_addr_q;
  logic [31:0] w_data_q;
  assign s_axi_awready = !aw_got;
  assign s_axi_wready  = !w_got;
  assign s_axi_bresp   = 2'b00;
  assign s_axi_rresp   = 2'b00;

  always_ff @(posedge s_axi_lite_clk or negedge s_axi_lite_resetn) begin
    if (!s_axi_lite_resetn) begin
      aw_got <= 1'b0; w_got <= 1'b0; s_axi_bvalid <= 1'b0;
      s_axi_arready <= 1'b0; s_axi_rvalid <= 1'b0; s_axi_rdata <= '0;
      r_is <= '0; r_ie <= '0; r_rcw1 <= 32'h0; r_tc <= 32'h0; r_emmc <= 32'h4000_0000;
      r_mdio_mc <= '0; r_mdio_mcr <= '0; r_mdio_mwd <= '0; r_mdio_mrd <= '0;
      regs.delete();
      phy3_ext.delete();
      for (int i = 0; i < 32; i++) begin phy3[i] = 16'h0; phy1[i] = 16'h0; end
      phy3[0] = 16'h1140; phy3[1] = 16'h796D; phy3[2] = 16'h2000; phy3[3] = 16'hA231; phy3[4] = 16'h01E1;
      phy3[5] = 16'hCDE1; phy3[6] = 16'h006D; phy3[9] = 16'h0200; phy3[5'h0A] = 16'h3800; phy3[5'h11] = 16'hAC00;
      phy1[0] = 16'h1140; phy1[1] = 16'h01EC; phy1[2] = 16'h0174; phy1[3] = 16'h0C00; phy1[4] = 16'h0001;   // IDs/BMSR as the board reads them phy1[5] = 16'h4001; phy1[6] = 16'h0004; phy1[5'h0F] = 16'h8000;
    end else begin
      // write address / data
      if (s_axi_awvalid && s_axi_awready) begin aw_got <= 1'b1; aw_addr_q <= s_axi_awaddr; end
      if (s_axi_wvalid  && s_axi_wready)  begin w_got  <= 1'b1; w_data_q  <= s_axi_wdata;  end
      if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
      if (aw_got && w_got && !s_axi_bvalid) begin
        aw_got <= 1'b0; w_got <= 1'b0; s_axi_bvalid <= 1'b1;
        case (aw_addr_q)
          IS:       r_is   <= r_is & ~w_data_q;              // write 1 to clear
          IE:       r_ie   <= w_data_q;
          RCW1:     r_rcw1 <= w_data_q & 32'h7FFF_FFFF;      // reset bit self-clears
          TC:       r_tc   <= w_data_q & 32'h7FFF_FFFF;
          EMMC:     r_emmc <= w_data_q;
          MDIO_MC:  r_mdio_mc  <= w_data_q;
          MDIO_MWD: r_mdio_mwd <= w_data_q;
          MDIO_MCR: begin
            r_mdio_mcr <= w_data_q & ~32'h800;
            if (w_data_q[11] && r_mdio_mc[6]) begin
              if (w_data_q[15:14] == 2'b10)      r_mdio_mrd <= {16'h0, mdio_read(w_data_q[28:24], w_data_q[20:16])};
              else if (w_data_q[15:14] == 2'b01) mdio_write(w_data_q[28:24], w_data_q[20:16], r_mdio_mwd[15:0]);
            end
          end
          default:  regs[aw_addr_q] = w_data_q;   // associative array: blocking (xsim)
        endcase
      end
      // read
      s_axi_arready <= !s_axi_rvalid && !s_axi_arready;
      if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1'b1;
        s_axi_rdata  <= reg_read(s_axi_araddr);
      end
      if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
      // events
      if (rx_frame_done) r_is <= r_is | INT_RXCMPIT;
      if (tx_frame_done) r_is <= r_is | INT_TXCMPIT;
    end
  end
  assign interrupt = |(r_is & r_ie);

  // ------------------------------------------------------------------------------------------------
  // MAC loopback: TX data stream -> frame buffer -> RX data stream + RX status stream
  // ------------------------------------------------------------------------------------------------
  logic [7:0]  frame [0:2047];
  int unsigned tx_len, rx_len, rx_pos, sts_pos;
  logic        frame_full;        // a frame waits for / is in replay
  logic        rx_data_phase, rx_sts_phase;

  assign s_axis_txc_tready = 1'b1;                 // control words: accepted and ignored
  assign s_axis_txd_tready = !frame_full && axi_txd_arstn;

  always_ff @(posedge axis_clk or negedge axi_txd_arstn) begin
    if (!axi_txd_arstn) begin
      tx_len <= 0; frame_full <= 1'b0; rx_len <= 0; rx_pos <= 0; sts_pos <= 0;
      rx_data_phase <= 1'b0; rx_sts_phase <= 1'b0; rx_frame_done <= 1'b0; tx_frame_done <= 1'b0;
    end else begin
      rx_frame_done <= 1'b0; tx_frame_done <= 1'b0;
      // collect
      if (s_axis_txd_tvalid && s_axis_txd_tready) begin
        for (int b = 0; b < 4; b++) if (s_axis_txd_tkeep[b] && tx_len + b < 2048) frame[tx_len + b] <= s_axis_txd_tdata[8*b +: 8];
        if (s_axis_txd_tlast) begin
          automatic int unsigned n = tx_len + $countones(s_axis_txd_tkeep);
          for (int i = n; i < 60; i++) frame[i] <= 8'h0;            // the MAC pads short frames
          if (n < 60) n = 60;
          tx_len <= 0;
          tx_frame_done <= 1'b1;
          if (r_tc[28] && r_rcw1[28]) begin                           // TX and RX enabled: loop it back
            frame_full <= 1'b1; rx_len <= n; rx_pos <= 0; sts_pos <= 0; rx_sts_phase <= 1'b1;
          end
        end else begin
          tx_len <= tx_len + $countones(s_axis_txd_tkeep);
        end
      end
      // replay: the status first (the DMA sizes its write with the length in it), then the data
      if (rx_sts_phase && m_axis_rxs_tvalid && m_axis_rxs_tready) begin
        sts_pos <= sts_pos + 1;
        if (m_axis_rxs_tlast) begin rx_sts_phase <= 1'b0; rx_data_phase <= 1'b1; end
      end
      if (rx_data_phase && m_axis_rxd_tvalid && m_axis_rxd_tready) begin
        rx_pos <= rx_pos + 4;
        if (m_axis_rxd_tlast) begin rx_data_phase <= 1'b0; frame_full <= 1'b0; rx_frame_done <= 1'b1; end
      end
    end
  end

  always_comb begin
    m_axis_rxd_tvalid = rx_data_phase && axi_rxd_arstn;
    m_axis_rxd_tdata  = {frame[rx_pos+3], frame[rx_pos+2], frame[rx_pos+1], frame[rx_pos]};
    m_axis_rxd_tlast  = (rx_pos + 4 >= rx_len);
    m_axis_rxd_tkeep  = m_axis_rxd_tlast ? ((rx_len - rx_pos == 1) ? 4'b0001 : (rx_len - rx_pos == 2) ? 4'b0011 :
                                            (rx_len - rx_pos == 3) ? 4'b0111 : 4'b1111) : 4'b1111;
    m_axis_rxs_tvalid = rx_sts_phase && axi_rxs_arstn;
    m_axis_rxs_tkeep  = 4'b1111;
    m_axis_rxs_tlast  = (sts_pos == 5);
    case (sts_pos)
      0:       m_axis_rxs_tdata = 32'h5000_0000;             // the tag word, which the DMA strips
      5:       m_axis_rxs_tdata = {16'h0, rx_len[15:0]};     // app4: receive length (the DMA takes the last word's)
      default: m_axis_rxs_tdata = 32'h0;                     // app0-app3
    endcase
  end

endmodule
