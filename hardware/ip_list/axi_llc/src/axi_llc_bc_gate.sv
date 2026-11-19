// Admission gate for a DMA master in front of the coherence unit (CCU): each AR and AW waits here until the LLC's
// CBQRI bandwidth controller (axi_llc_cbqri_bc, gate_* ports) admits it.
//
// Why: the CCU has one state machine for all shareable requests and it waits for the write response of a coherent
// write (and the response of a write-back it issues for a request). A DMA write whose RCID is hard-limited and out
// of budget would park in the controller until the next period, and the CCU, and with it every core's L1 miss, would
// wait with it. Asking before the CCU moves that wait to the DMA's own port: the request is admitted only while its
// RCID may still spend (bytes used + worst-case bytes of its admitted, unfinished requests below its reservation),
// and once admitted the controller never parks it (descriptors from a gated source count as inside the
// reservation). A refused request holds up only this port.
//
// Cost of a request (gate_bytes): the LLC lines it touches times CostLines lines of memory traffic, LineBytes each.
// The worst case for one line of a coherent request is 4 lines: the CCU's write-back of a dirty L1 copy (an LLC
// refill and a dirty victim eviction) and then the request itself (again a refill and an eviction). The controller
// charges the real traffic as it releases it; the admission only keeps the requests in flight within the budget.
//
// One request at a time is held (AW and AR alternate when both wait); W beats pass only behind an AW already sent
// on; up to MaxTrans requests are in flight, each finished by its B (writes) or its last R beat (reads), matched by
// AXI ID in order. An AW with an atomic operation (atop[5], it also returns R) is finished by its B; its R beats are
// not matched to reads (a DMA master does not issue atomics; one that does should not share their ID with reads).
module axi_llc_bc_gate #(
  parameter bit          Enable     = 1'b1,
  parameter int unsigned IdWidth    = 32'd4,
  parameter int unsigned AddrWidth  = 32'd64,
  parameter int unsigned RcidWidth  = 32'd4,
  parameter int unsigned RcidLsb    = 32'd3,   // position of the RCID in aw.user / ar.user
  parameter int unsigned LineBytes  = 32'd64,
  parameter int unsigned CostLines  = 32'd4,
  parameter int unsigned MaxTrans   = 32'd4,
  parameter type         aw_chan_t  = logic,
  parameter type         ar_chan_t  = logic,
  parameter type         req_t      = logic,
  parameter type         resp_t     = logic,
  // derived (do not set)
  parameter int unsigned RcidW      = (RcidWidth > 0) ? RcidWidth : 1
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  req_t              slv_req_i,
  output resp_t             slv_resp_o,
  output req_t              mst_req_o,
  input  resp_t             mst_resp_i,
  // to the bandwidth controller
  output logic              adm_req_o,
  output logic [RcidW-1:0]  adm_rcid_o,
  output logic [15:0]       adm_bytes_o,
  input  logic              adm_gnt_i,
  output logic              done_o,
  output logic [RcidW-1:0]  done_rcid_o,
  output logic [15:0]       done_bytes_o
);

  if (!Enable) begin : gen_bypass
    assign mst_req_o    = slv_req_i;
    assign slv_resp_o   = mst_resp_i;
    assign adm_req_o    = 1'b0;
    assign adm_rcid_o   = '0;
    assign adm_bytes_o  = '0;
    assign done_o       = 1'b0;
    assign done_rcid_o  = '0;
    assign done_bytes_o = '0;
  end else begin : gen_gate

    localparam int unsigned LineOff = $clog2(LineBytes);
    localparam int unsigned TW      = (MaxTrans > 1) ? $clog2(MaxTrans) : 1;

    // lines a burst touches: INCR from its address, WRAP its aligned window, FIXED one line
    function automatic logic [15:0] burst_cost(logic [AddrWidth-1:0] addr, axi_pkg::len_t len,
                                               axi_pkg::size_t size, axi_pkg::burst_t burst);
      logic [AddrWidth-1:0] bytes, first, last, lines;
      logic [31:0]          cost;
      bytes = (AddrWidth'(len) + AddrWidth'(1)) << size;
      if (burst == axi_pkg::BURST_WRAP) first = addr & ~(bytes - AddrWidth'(1));
      else                              first = addr;
      if (burst == axi_pkg::BURST_FIXED) last = addr;
      else                               last = first + bytes - AddrWidth'(1);
      lines = (last >> LineOff) - (first >> LineOff) + AddrWidth'(1);
      cost  = 32'(lines) * CostLines * LineBytes;
      return (cost > 32'hFFFF) ? 16'hFFFF : cost[15:0];
    endfunction

    // ---- the held request
    logic              hv_q, hw_q, hadm_q;      // held, is an AW, admitted
    aw_chan_t          aw_q;
    ar_chan_t          ar_q;
    logic [RcidW-1:0]  hrcid_q;
    logic [15:0]       hbytes_q;
    logic              pref_w_q;                // AW first next time both wait

    // ---- requests in flight
    logic [MaxTrans-1:0]                 tv_q, tfin_q, tw_q;
    logic [MaxTrans-1:0][IdWidth-1:0]    tid_q;
    logic [MaxTrans-1:0][RcidW-1:0]      trcid_q;
    logic [MaxTrans-1:0][15:0]           tbytes_q;
    logic [MaxTrans-1:0][MaxTrans-1:0]   told_q;   // told_q[i][j]: entry j is older than entry i
    logic                                tfree;
    logic [TW-1:0]                       tfree_idx;

    always_comb begin
      tfree     = 1'b0;
      tfree_idx = '0;
      for (int i = MaxTrans - 1; i >= 0; i--) if (!tv_q[i]) begin tfree = 1'b1; tfree_idx = TW'(i); end
    end

    // capture: one request when nothing is held and an entry is free for it
    logic take_aw, take_ar;
    assign take_aw = !hv_q && tfree && slv_req_i.aw_valid && (pref_w_q || !slv_req_i.ar_valid);
    assign take_ar = !hv_q && tfree && slv_req_i.ar_valid && !take_aw;

    // admission
    assign adm_req_o   = hv_q && !hadm_q;
    assign adm_rcid_o  = hrcid_q;
    assign adm_bytes_o = hbytes_q;
    wire   admit       = adm_req_o && adm_gnt_i;

    // forwarding
    logic send_aw, send_ar;
    assign send_aw = hv_q && hadm_q && hw_q  && mst_resp_i.aw_ready;
    assign send_ar = hv_q && hadm_q && !hw_q && mst_resp_i.ar_ready;

    // W beats pass behind AWs already sent on
    logic [7:0] w_open_q;
    wire        w_pass = (w_open_q != 8'd0);
    wire        w_last = slv_req_i.w_valid && mst_resp_i.w_ready && w_pass && slv_req_i.w.last;

    always_comb begin
      mst_req_o            = slv_req_i;
      mst_req_o.aw         = aw_q;
      mst_req_o.aw_valid   = hv_q && hadm_q && hw_q;
      mst_req_o.ar         = ar_q;
      mst_req_o.ar_valid   = hv_q && hadm_q && !hw_q;
      mst_req_o.w_valid    = slv_req_i.w_valid && w_pass;
      slv_resp_o           = mst_resp_i;
      slv_resp_o.aw_ready  = take_aw;
      slv_resp_o.ar_ready  = take_ar;
      slv_resp_o.w_ready   = mst_resp_i.w_ready && w_pass;
    end

    // completions: the oldest unfinished entry of the direction and ID
    wire b_fire = mst_resp_i.b_valid && slv_req_i.b_ready;
    wire r_fire = mst_resp_i.r_valid && slv_req_i.r_ready && mst_resp_i.r.last;
    logic [MaxTrans-1:0] b_cand, r_cand, b_hit, r_hit;
    always_comb begin
      for (int unsigned i = 0; i < MaxTrans; i++) begin
        b_cand[i] = tv_q[i] && !tfin_q[i] &&  tw_q[i] && tid_q[i] == IdWidth'(mst_resp_i.b.id);
        r_cand[i] = tv_q[i] && !tfin_q[i] && !tw_q[i] && tid_q[i] == IdWidth'(mst_resp_i.r.id);
      end
      for (int unsigned i = 0; i < MaxTrans; i++) begin
        b_hit[i] = b_fire && b_cand[i] && !(|(b_cand & told_q[i]));
        r_hit[i] = r_fire && r_cand[i] && !(|(r_cand & told_q[i]));
      end
    end

    // retire one finished entry per cycle: done to the controller
    logic          ret_v;
    logic [TW-1:0] ret_idx;
    always_comb begin
      ret_v   = 1'b0;
      ret_idx = '0;
      for (int i = MaxTrans - 1; i >= 0; i--) if (tv_q[i] && tfin_q[i]) begin ret_v = 1'b1; ret_idx = TW'(i); end
    end
    assign done_o       = ret_v;
    assign done_rcid_o  = trcid_q[ret_idx];
    assign done_bytes_o = tbytes_q[ret_idx];

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        hv_q     <= 1'b0;
        hw_q     <= 1'b0;
        hadm_q   <= 1'b0;
        aw_q     <= '0;
        ar_q     <= '0;
        hrcid_q  <= '0;
        hbytes_q <= '0;
        pref_w_q <= 1'b1;
        tv_q     <= '0;
        tfin_q   <= '0;
        tw_q     <= '0;
        tid_q    <= '0;
        trcid_q  <= '0;
        tbytes_q <= '0;
        told_q   <= '0;
        w_open_q <= '0;
      end else begin
        // capture
        if (take_aw) begin
          hv_q     <= 1'b1;
          hw_q     <= 1'b1;
          hadm_q   <= 1'b0;
          aw_q     <= slv_req_i.aw;
          hrcid_q  <= RcidW'(slv_req_i.aw.user >> RcidLsb);
          hbytes_q <= burst_cost(AddrWidth'(slv_req_i.aw.addr), slv_req_i.aw.len, slv_req_i.aw.size,
                                 slv_req_i.aw.burst);
          pref_w_q <= 1'b0;
        end else if (take_ar) begin
          hv_q     <= 1'b1;
          hw_q     <= 1'b0;
          hadm_q   <= 1'b0;
          ar_q     <= slv_req_i.ar;
          hrcid_q  <= RcidW'(slv_req_i.ar.user >> RcidLsb);
          hbytes_q <= burst_cost(AddrWidth'(slv_req_i.ar.addr), slv_req_i.ar.len, slv_req_i.ar.size,
                                 slv_req_i.ar.burst);
          pref_w_q <= 1'b1;
        end
        // admitted: the request takes the free entry (capture waits for a free one, so it is still free)
        if (admit) begin
          hadm_q              <= 1'b1;
          tv_q[tfree_idx]     <= 1'b1;
          tfin_q[tfree_idx]   <= 1'b0;
          tw_q[tfree_idx]     <= hw_q;
          tid_q[tfree_idx]    <= hw_q ? IdWidth'(aw_q.id) : IdWidth'(ar_q.id);
          trcid_q[tfree_idx]  <= hrcid_q;
          tbytes_q[tfree_idx] <= hbytes_q;
          for (int unsigned i = 0; i < MaxTrans; i++) begin
            told_q[i][tfree_idx] <= 1'b0;                                       // the newcomer is the youngest
            told_q[tfree_idx][i] <= tv_q[i] && !(ret_v && ret_idx == TW'(i)) && (TW'(i) != tfree_idx);
          end
        end
        // sent on
        if (send_aw || send_ar) hv_q <= 1'b0;
        // W beats owed
        w_open_q <= w_open_q + 8'(send_aw) - 8'(w_last);
        // finished, retired
        for (int unsigned i = 0; i < MaxTrans; i++) if (b_hit[i] || r_hit[i]) tfin_q[i] <= 1'b1;
        if (ret_v) begin
          tv_q[ret_idx]   <= 1'b0;
          tfin_q[ret_idx] <= 1'b0;
        end
      end
    end

    // pragma translate_off
    `ifndef VERILATOR
    assert property (@(posedge clk_i) disable iff (!rst_ni) !(admit && !tfree))
      else $error("axi_llc_bc_gate: admitted without a free entry");
    assert property (@(posedge clk_i) disable iff (!rst_ni) !(b_fire && !(|b_cand)))
      else $error("axi_llc_bc_gate: B without a write in flight");
    `endif
    // pragma translate_on
  end

endmodule
