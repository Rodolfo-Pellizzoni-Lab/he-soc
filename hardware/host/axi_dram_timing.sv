// DRAM timing model in front of the real memory (FASED-style, fixed latency and bandwidth).
//
// The SoC clock is read as the clock of the target being emulated (one SoC cycle = one target cycle, whatever the
// FPGA runs at). Requests go to the real memory at once; every response is held in the model until the DRAM of the
// target would have delivered it: the first read beat lat_rd target cycles after the accepted AR, the write response
// lat_wr after the accepted AW, and no earlier than the modelled data bus is free (occ16: 1/16 target cycles of bus
// time per 8-byte beat, so a 64-byte line costs 8 * occ16 / 16 cycles). Beats of one burst are paced at occ16.
//
// Sits between the LLC's memory port and the DRAM path in host_domain; configured and counted through the SoC
// control registers at 0x1A10_6100 (apb_soc_control.sv). Outstanding requests are tracked whether the model is
// enabled or not, so enable can change at any time: disabled, responses pass straight through once the buffers
// have drained; enabled, they go through the buffers and come out when due. Responses are assumed to come back in
// request order (the simulated DRAM and the DDR4 controller do); a different ID at the head of the queue is
// reported in simulation.
//
// When the real memory is slower than the model (data arrives after its modelled time) the beat is released at
// arrival and counted in rd_late / late_cycles: that is the case the second step (gating the target clock) will
// absorb; until then it is a measured error, not a hang.

package dram_model_pkg;
  typedef struct packed {
    logic        enable;   // 0: responses pass through as soon as the buffers are empty
    logic        clear;    // one-cycle pulse: zero the counters
    logic [15:0] lat_rd;   // target cycles from the accepted AR to the first R beat
    logic [15:0] lat_wr;   // target cycles from the accepted AW to B (plus the data-bus time of the burst)
    logic [15:0] occ16;    // data-bus time per 8-byte beat, 1/16 target cycles (0: unlimited bandwidth)
  } cfg_t;
  typedef struct packed {
    logic [31:0] rd_count;     // read bursts accepted while enabled
    logic [31:0] wr_count;     // write bursts accepted while enabled
    logic [31:0] rd_late;      // read bursts whose first beat came back after its modelled time
    logic [31:0] late_cycles;  // sum of that lateness, target cycles
    logic [31:0] hold_cycles;  // sum of the cycles first read beats were held back by the model
    logic [31:0] rd_beats;     // read beats (8 bytes each) delivered while enabled
  } cnt_t;
  localparam logic [31:0] ID = 32'hD2A3_0001;  // read at 0x1A10_6124: the model is present
endpackage

module axi_dram_timing #(
  parameter type         axi_req_t  = logic,
  parameter type         axi_resp_t = logic,
  parameter type         r_chan_t   = logic,
  parameter type         b_chan_t   = logic,
  parameter int unsigned IdWidth    = 8,
  parameter int unsigned RdDepth    = 16,  // outstanding read bursts
  parameter int unsigned WrDepth    = 8,   // outstanding write bursts
  parameter int unsigned RBufDepth  = 32,  // buffered read beats (4 lines)
  parameter int unsigned BBufDepth  = 8    // buffered write responses
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  dram_model_pkg::cfg_t cfg_i,
  output dram_model_pkg::cnt_t cnt_o,
  input  axi_req_t             slv_req_i,
  output axi_resp_t            slv_resp_o,
  output axi_req_t             mst_req_o,
  input  axi_resp_t            mst_resp_i
);
  localparam int unsigned TW = 48;                 // time in 1/16 target cycles: 2^44 cycles before wrap
  typedef logic [TW-1:0]      t16_t;
  typedef logic [IdWidth-1:0] id_t;
  localparam int unsigned RdPW = $clog2(RdDepth);
  localparam int unsigned WrPW = $clog2(WrDepth);
  localparam int unsigned RbPW = $clog2(RBufDepth);
  localparam int unsigned BbPW = $clog2(BBufDepth);

  typedef struct packed { logic first; id_t id; t16_t next16; } rd_entry_t;   // next16: release time of the next beat
  typedef struct packed { id_t id; t16_t rel16; }               wr_entry_t;
  typedef struct packed { r_chan_t beat; t16_t rel16; }         rbuf_entry_t;
  typedef struct packed { b_chan_t resp; t16_t rel16; }         bbuf_entry_t;

  t16_t                     t16_q, bus_free_q, bus_free_d;
  rd_entry_t [RdDepth-1:0]  rdq_q, rdq_d;
  wr_entry_t [WrDepth-1:0]  wrq_q, wrq_d;
  rbuf_entry_t [RBufDepth-1:0] rbuf_q, rbuf_d;
  bbuf_entry_t [BBufDepth-1:0] bbuf_q, bbuf_d;
  logic [RdPW-1:0] rd_head_q, rd_tail_q, rd_head_d, rd_tail_d;
  logic [RdPW:0]   rd_cnt_q, rd_cnt_d;
  logic [WrPW-1:0] wr_head_q, wr_tail_q, wr_head_d, wr_tail_d;
  logic [WrPW:0]   wr_cnt_q, wr_cnt_d;
  logic [RbPW-1:0] rb_rd_q, rb_wr_q, rb_rd_d, rb_wr_d;
  logic [RbPW:0]   rb_cnt_q, rb_cnt_d;
  logic [BbPW-1:0] bb_rd_q, bb_wr_q, bb_rd_d, bb_wr_d;
  logic [BbPW:0]   bb_cnt_q, bb_cnt_d;
  dram_model_pkg::cnt_t cnt_q, cnt_d;

  wire en       = cfg_i.enable;
  wire rdq_full = rd_cnt_q == RdDepth[RdPW:0];
  wire wrq_full = wr_cnt_q == WrDepth[WrPW:0];
  wire rb_full  = rb_cnt_q == RBufDepth[RbPW:0];
  wire bb_full  = bb_cnt_q == BBufDepth[BbPW:0];
  // responses take the buffered path while the model is enabled or something is still buffered (order is kept)
  wire r_buffered = en || (rb_cnt_q != '0);
  wire b_buffered = en || (bb_cnt_q != '0);
  wire r_due    = (rb_cnt_q != '0) && (t16_q >= rbuf_q[rb_rd_q].rel16);
  wire b_due    = (bb_cnt_q != '0) && (t16_q >= bbuf_q[bb_rd_q].rel16);

  // ------------------------------------------------------------------ channels
  // AW, W and AR pass through, held back only while a table is full; R and B pass through or come out of the
  // buffers when due.
  always_comb begin
    mst_req_o           = slv_req_i;
    mst_req_o.ar_valid  = slv_req_i.ar_valid && !rdq_full;
    mst_req_o.aw_valid  = slv_req_i.aw_valid && !wrq_full;
    mst_req_o.r_ready   = r_buffered ? !rb_full : slv_req_i.r_ready;
    mst_req_o.b_ready   = b_buffered ? !bb_full : slv_req_i.b_ready;
  end
  always_comb begin
    slv_resp_o          = mst_resp_i;
    slv_resp_o.ar_ready = mst_resp_i.ar_ready && !rdq_full;
    slv_resp_o.aw_ready = mst_resp_i.aw_ready && !wrq_full;
    slv_resp_o.r_valid  = r_buffered ? r_due : mst_resp_i.r_valid;
    slv_resp_o.r        = r_buffered ? rbuf_q[rb_rd_q].beat : mst_resp_i.r;
    slv_resp_o.b_valid  = b_buffered ? b_due : mst_resp_i.b_valid;
    slv_resp_o.b        = b_buffered ? bbuf_q[bb_rd_q].resp : mst_resp_i.b;
  end

  wire ar_hs = slv_req_i.ar_valid && slv_resp_o.ar_ready;
  wire aw_hs = slv_req_i.aw_valid && slv_resp_o.aw_ready;
  wire r_in  = mst_resp_i.r_valid && mst_req_o.r_ready;     // a beat from the real memory
  wire b_in  = mst_resp_i.b_valid && mst_req_o.b_ready;
  wire r_out = r_buffered && r_due && slv_req_i.r_ready;
  wire b_out = b_buffered && b_due && slv_req_i.b_ready;

  // ------------------------------------------------------------------ model
  always_comb begin
    t16_t dl, lat_rd16, lat_wr16, occ_ar, occ_aw, rel;
    bus_free_d = bus_free_q;
    rdq_d = rdq_q; wrq_d = wrq_q; rbuf_d = rbuf_q; bbuf_d = bbuf_q;
    rd_head_d = rd_head_q; rd_tail_d = rd_tail_q; rd_cnt_d = rd_cnt_q;
    wr_head_d = wr_head_q; wr_tail_d = wr_tail_q; wr_cnt_d = wr_cnt_q;
    rb_rd_d = rb_rd_q; rb_wr_d = rb_wr_q; rb_cnt_d = rb_cnt_q;
    bb_rd_d = bb_rd_q; bb_wr_d = bb_wr_q; bb_cnt_d = bb_cnt_q;
    cnt_d = cnt_q;
    lat_rd16 = t16_t'(cfg_i.lat_rd) << 4;
    lat_wr16 = t16_t'(cfg_i.lat_wr) << 4;
    occ_ar   = (t16_t'(slv_req_i.ar.len) + 48'd1) * t16_t'(cfg_i.occ16);
    occ_aw   = (t16_t'(slv_req_i.aw.len) + 48'd1) * t16_t'(cfg_i.occ16);
    dl = '0; rel = '0;

    // accepted read: first beat at max(now + lat_rd, bus free); the burst then occupies the bus. Disabled: due now.
    if (ar_hs) begin
      if (en) begin
        dl = (t16_q + lat_rd16 > bus_free_d) ? t16_q + lat_rd16 : bus_free_d;
        bus_free_d = dl + occ_ar;
        cnt_d.rd_count = cnt_q.rd_count + 1'b1;
      end else begin
        dl = t16_q;
      end
      rdq_d[rd_tail_q] = '{first: 1'b1, id: slv_req_i.ar.id, next16: dl};
      rd_tail_d = rd_tail_q + 1'b1;
      rd_cnt_d  = rd_cnt_d + 1'b1;
    end
    // accepted write: the response after max(now + lat_wr, bus free) plus the data-bus time of the burst
    if (aw_hs) begin
      if (en) begin
        dl = (t16_q + lat_wr16 > bus_free_d) ? t16_q + lat_wr16 : bus_free_d;
        bus_free_d = dl + occ_aw;
        cnt_d.wr_count = cnt_q.wr_count + 1'b1;
      end else begin
        bus_free_d = t16_q;
      end
      wrq_d[wr_tail_q] = '{id: slv_req_i.aw.id, rel16: bus_free_d};
      wr_tail_d = wr_tail_q + 1'b1;
      wr_cnt_d  = wr_cnt_d + 1'b1;
    end
    // a read beat from the memory: released at the time of the burst at the head of the queue (now, if the beat
    // has no entry: a read that was in flight through a reset of the tables)
    if (r_in) begin
      rel = (rd_cnt_q != '0) ? rdq_q[rd_head_q].next16 : t16_q;
      if (r_buffered) begin
        rbuf_d[rb_wr_q] = '{beat: mst_resp_i.r, rel16: rel};
        rb_wr_d  = rb_wr_q + 1'b1;
        rb_cnt_d = rb_cnt_d + 1'b1;
      end
      if (rd_cnt_q != '0) begin
        rdq_d[rd_head_q].next16 = rel + (en ? t16_t'(cfg_i.occ16) : '0);
        rdq_d[rd_head_q].first  = 1'b0;
        if (en) begin
          cnt_d.rd_beats = cnt_q.rd_beats + 1'b1;
          if (rdq_q[rd_head_q].first) begin
            if (t16_q > rel) begin
              cnt_d.rd_late     = cnt_q.rd_late + 1'b1;
              cnt_d.late_cycles = cnt_q.late_cycles + 32'((t16_q - rel) >> 4);
            end else begin
              cnt_d.hold_cycles = cnt_q.hold_cycles + 32'((rel - t16_q) >> 4);
            end
          end
        end
        if (mst_resp_i.r.last) begin
          rd_head_d = rd_head_q + 1'b1;
          rd_cnt_d  = rd_cnt_d - 1'b1;
        end
      end
    end
    if (r_out) begin
      rb_rd_d  = rb_rd_q + 1'b1;
      rb_cnt_d = rb_cnt_d - 1'b1;
    end
    // a write response from the memory
    if (b_in) begin
      rel = (wr_cnt_q != '0) ? wrq_q[wr_head_q].rel16 : t16_q;
      if (b_buffered) begin
        bbuf_d[bb_wr_q] = '{resp: mst_resp_i.b, rel16: rel};
        bb_wr_d  = bb_wr_q + 1'b1;
        bb_cnt_d = bb_cnt_d + 1'b1;
      end
      if (wr_cnt_q != '0) begin
        wr_head_d = wr_head_q + 1'b1;
        wr_cnt_d  = wr_cnt_d - 1'b1;
      end
    end
    if (b_out) begin
      bb_rd_d  = bb_rd_q + 1'b1;
      bb_cnt_d = bb_cnt_d - 1'b1;
    end
    if (cfg_i.clear) cnt_d = '0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      t16_q <= '0; bus_free_q <= '0;
      rdq_q <= '0; wrq_q <= '0; rbuf_q <= '0; bbuf_q <= '0;
      rd_head_q <= '0; rd_tail_q <= '0; rd_cnt_q <= '0;
      wr_head_q <= '0; wr_tail_q <= '0; wr_cnt_q <= '0;
      rb_rd_q <= '0; rb_wr_q <= '0; rb_cnt_q <= '0;
      bb_rd_q <= '0; bb_wr_q <= '0; bb_cnt_q <= '0;
      cnt_q <= '0;
    end else begin
      t16_q <= t16_q + 48'd16;
      bus_free_q <= bus_free_d;
      rdq_q <= rdq_d; wrq_q <= wrq_d; rbuf_q <= rbuf_d; bbuf_q <= bbuf_d;
      rd_head_q <= rd_head_d; rd_tail_q <= rd_tail_d; rd_cnt_q <= rd_cnt_d;
      wr_head_q <= wr_head_d; wr_tail_q <= wr_tail_d; wr_cnt_q <= wr_cnt_d;
      rb_rd_q <= rb_rd_d; rb_wr_q <= rb_wr_d; rb_cnt_q <= rb_cnt_d;
      bb_rd_q <= bb_rd_d; bb_wr_q <= bb_wr_d; bb_cnt_q <= bb_cnt_d;
      cnt_q <= cnt_d;
    end
  end
  assign cnt_o = cnt_q;

`ifndef SYNTHESIS
  // the model assumes responses in request order; every response must belong to a tracked request
  always_ff @(posedge clk_i) if (rst_ni) begin
    if (r_in && rd_cnt_q == '0)
      $error("[DRAM-MODEL] read beat (id %0h) with no read outstanding", mst_resp_i.r.id);
    if (r_in && rd_cnt_q != '0 && mst_resp_i.r.id != rdq_q[rd_head_q].id)
      $error("[DRAM-MODEL] read beat id %0h, head of the queue is id %0h: responses out of order", mst_resp_i.r.id, rdq_q[rd_head_q].id);
    if (b_in && wr_cnt_q == '0)
      $error("[DRAM-MODEL] write response (id %0h) with no write outstanding", mst_resp_i.b.id);
    if (b_in && wr_cnt_q != '0 && mst_resp_i.b.id != wrq_q[wr_head_q].id)
      $error("[DRAM-MODEL] write response id %0h, head of the queue is id %0h: responses out of order", mst_resp_i.b.id, wrq_q[wr_head_q].id);
  end
`endif
endmodule
