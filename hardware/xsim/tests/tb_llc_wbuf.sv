// LLC write-data buffer test (ip_list/axi_llc/src/axi_llc_w_buffer.sv in axi_llc_top): data integrity and
// progress when writes reach the write unit out of AW order.
//
// A small LLC (4 ways x 32 sets, 64-byte lines, 64-bit data) with the CBQRI bandwidth controller and the write-data
// buffer (WBUF slots). NT threads share its AXI slave port; thread t uses AXI ID t, RCID = MCID = t % 4, and its own
// 4 KB region (regions 64 KB apart: every thread's lines fall into the same 32 sets, so they evict each other). Each
// thread issues NOPS operations one at a time (the next after the previous one's B or last R), so a per-thread
// reference memory predicts every read exactly; across threads they run concurrently. Operations:
//   full-width writes and reads (size 3, 1..8 beats, may cross a line: buffered, one slot per line part)
//   narrow writes and reads (size 0..2, 1..16 beats: a line part of more than 8 beats is unbuffered)
// with random strobes. The W beats of a write follow its AW in AW order, with random gaps (and AWs run ahead of their
// W beats). The memory answers each request after a random delay and applies write beats as they arrive.
// Phase 1: regulation off. Phase 2: the controller on, RCID 1 hard-limited (Rbwb 1, Mweight 0, 40 lines per 400-cycle
// period): its misses park for up to a period while the others' writes overtake them in the write unit.
// Checks: every read beat against the reference, every response OKAY, everything done within a deadline (no
// deadlock), and the buffer saw both buffered and unbuffered writes.
`include "axi/typedef.svh"

module tb_llc_wbuf #(
  parameter int unsigned WBUF = 8,
  parameter int unsigned PEND = 0,   // EvictPendDepth: write-backs that may wait for their response (tb_llc_wbpend)
  parameter int unsigned NT   = 8,
  parameter int unsigned NOPS = 400
);
  localparam time CYC = 10ns, TA = 2ns, TT = 8ns;
  localparam int unsigned AW = 32, DW = 64, IW = 4, UW = 5, LAW = 32, LDW = 32;
  localparam logic [AW-1:0] CACHED = 32'h8000_0000;

  typedef logic [AW-1:0]    addr_t;
  typedef logic [DW-1:0]    data_t;
  typedef logic [DW/8-1:0]  strb_t;
  typedef logic [IW-1:0]    id_t;
  typedef logic [IW:0]      mid_t;
  typedef logic [UW-1:0]    user_t;
  `AXI_TYPEDEF_ALL(slv, addr_t, id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(mst, addr_t, mid_t, data_t, strb_t, user_t)
  `AXI_LITE_TYPEDEF_ALL(lite, logic [LAW-1:0], logic [LDW-1:0], logic [LDW/8-1:0])
  typedef struct packed {
    int unsigned idx;
    addr_t       start_addr;
    addr_t       end_addr;
  } rule_t;

  logic clk = 1'b0, rst_n = 1'b0;
  always #(CYC / 2) clk = ~clk;
  initial begin repeat (5) @(posedge clk); #TA rst_n = 1'b1; end

  slv_req_t  sreq;  slv_resp_t sresp;
  mst_req_t  mreq;  mst_resp_t mresp;
  lite_req_t lreq;  lite_resp_t lresp;
  axi_llc_pkg::events_t events;

  axi_llc_top #(
    .SetAssociativity ( 4            ),
    .NumLines         ( 32           ),
    .NumBlocks        ( 8            ),
    .AxiIdWidth       ( IW           ),
    .AxiAddrWidth     ( AW           ),
    .AxiDataWidth     ( DW           ),
    .AxiUserWidth     ( UW           ),
    .AxiLiteAddrWidth ( LAW          ),
    .AxiLiteDataWidth ( LDW          ),
    .slv_req_t        ( slv_req_t    ),
    .slv_resp_t       ( slv_resp_t   ),
    .mst_req_t        ( mst_req_t    ),
    .mst_resp_t       ( mst_resp_t   ),
    .lite_req_t       ( lite_req_t   ),
    .lite_resp_t      ( lite_resp_t  ),
    .rule_full_t      ( rule_t       ),
    .QosRcidWidth     ( 2            ),
    .QosRcidLsb       ( 0            ),
    .QosAtBit         ( 4            ),
    .QosBc            ( 1'b1         ),
    .QosBcPoolDepth   ( 16           ),
    .QosWBufSlots     ( WBUF         ),
    .EvictPendDepth   ( PEND         ),
    .QosCcOffset      ( 32'h800      )
  ) i_dut (
    .clk_i               ( clk         ),
    .rst_ni              ( rst_n       ),
    .test_i              ( 1'b0        ),
    .slv_req_i           ( sreq        ),
    .slv_resp_o          ( sresp       ),
    .mst_req_o           ( mreq        ),
    .mst_resp_i          ( mresp       ),
    .conf_req_i          ( lreq        ),
    .conf_resp_o         ( lresp       ),
    .cached_start_addr_i ( CACHED      ),
    .cached_end_addr_i   ( CACHED + 32'h0100_0000 ),
    .spm_start_addr_i    ( 32'h0       ),
    .axi_llc_events_o    ( events      ),
    .qos_gate_req_i        ( '0 ),
    .qos_gate_rcid_i       ( '0 ),
    .qos_gate_bytes_i      ( '0 ),
    .qos_gate_gnt_o        (    ),
    .qos_gate_done_i       ( '0 ),
    .qos_gate_done_rcid_i  ( '0 ),
    .qos_gate_done_bytes_i ( '0 )
  );

  int unsigned fails = 0;
  function automatic void fail(string s);
    fails++;
    if (fails <= 20) $display("[%0t] FAIL %s", $time, s);
  endfunction

  // ------------------------------------------------------------------------------------------- memory (slave)
  byte unsigned mem [addr_t];
  function automatic byte unsigned mem_rd(addr_t a);
    return mem.exists(a) ? mem[a] : 8'(a ^ (a >> 8) ^ 8'h5A);   // untouched memory: a fixed pattern
  endfunction

  // Every process drives at TA after the clock edge and samples at TT, before the next edge: a handshake seen at TT
  // happens at that next edge.
  typedef struct { mst_aw_chan_t aw; int unsigned delay; } m_w_t;
  typedef struct { mst_ar_chan_t ar; int unsigned delay; } m_r_t;
  m_w_t mw_q[$];  mid_t mb_q[$];  m_r_t mr_q[$];
  initial begin                                    // memory: AW and AR
    mresp = '0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      mresp.aw_ready = $urandom_range(0, 3) != 0;
      mresp.ar_ready = $urandom_range(0, 3) != 0;
      #(TT - TA);
      if (mreq.aw_valid && mresp.aw_ready) begin m_w_t e; e.aw = mreq.aw; e.delay = 0; mw_q.push_back(e); end
      if (mreq.ar_valid && mresp.ar_ready) begin
        m_r_t e; e.ar = mreq.ar; e.delay = $urandom_range(5, 60); mr_q.push_back(e);
      end
    end
  end
  initial begin                                    // memory: W beats of the oldest AW, applied as they arrive
    int unsigned beat = 0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      mresp.w_ready = (mw_q.size() != 0) && ($urandom_range(0, 3) != 0);
      #(TT - TA);
      if (mreq.w_valid && mresp.w_ready) begin
        m_w_t t = mw_q[0];
        addr_t a = axi_pkg::beat_addr(t.aw.addr, t.aw.size, t.aw.len, t.aw.burst, beat);
        addr_t al = a & ~addr_t'(DW / 8 - 1);
        for (int b = 0; b < DW / 8; b++) if (mreq.w.strb[b]) mem[al + b] = mreq.w.data[8*b +: 8];
        if (beat == t.aw.len) begin
          if (!mreq.w.last) fail("memory: W last missing");
          mb_q.push_back(t.aw.id);
          void'(mw_q.pop_front());
          beat = 0;
        end else beat++;
      end
    end
  end
  initial begin                                    // memory: B
    logic hs = 1'b0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs) begin mresp.b_valid = 1'b0; void'(mb_q.pop_front()); hs = 1'b0; end
      if (!mresp.b_valid && mb_q.size() != 0 && $urandom_range(0, 2) == 0) begin
        mresp.b = '{id: mb_q[0], resp: axi_pkg::RESP_OKAY, default: '0};
        mresp.b_valid = 1'b1;
      end
      #(TT - TA);
      hs = mresp.b_valid && mreq.b_ready;
    end
  end
  initial begin                                    // memory: R beats of the oldest AR after its delay
    int unsigned beat = 0;
    logic hs = 1'b0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs) begin
        mresp.r_valid = 1'b0; hs = 1'b0;
        if (beat == mr_q[0].ar.len) begin void'(mr_q.pop_front()); beat = 0; end
        else beat++;
      end
      if (mr_q.size() != 0 && mr_q[0].delay != 0) mr_q[0].delay--;
      if (!mresp.r_valid && mr_q.size() != 0 && mr_q[0].delay == 0) begin
        addr_t a  = axi_pkg::beat_addr(mr_q[0].ar.addr, mr_q[0].ar.size, mr_q[0].ar.len, mr_q[0].ar.burst, beat);
        addr_t al = a & ~addr_t'(DW / 8 - 1);
        data_t d;
        for (int b = 0; b < DW / 8; b++) d[8*b +: 8] = mem_rd(al + b);
        mresp.r = '{id: mr_q[0].ar.id, data: d, resp: axi_pkg::RESP_OKAY, last: beat == mr_q[0].ar.len, default: '0};
        mresp.r_valid = 1'b1;
      end
      #(TT - TA);
      hs = mresp.r_valid && mreq.r_ready;
    end
  end

  // ------------------------------------------------------------------------------------------- config port
  task automatic lite_wr(logic [31:0] a, logic [31:0] d);
    logic aw_done = 1'b0, w_done = 1'b0;
    @(posedge clk); #TA;
    lreq.aw = '{addr: a, default: '0}; lreq.aw_valid = 1'b1;
    lreq.w  = '{data: d, strb: '1};    lreq.w_valid  = 1'b1;
    lreq.b_ready = 1'b1;
    forever begin
      #(TT - TA);
      if (lreq.aw_valid && lresp.aw_ready) aw_done = 1'b1;
      if (lreq.w_valid  && lresp.w_ready)  w_done  = 1'b1;
      if (lresp.b_valid) break;
      @(posedge clk); #TA;
      if (aw_done) lreq.aw_valid = 1'b0;
      if (w_done)  lreq.w_valid  = 1'b0;
    end
    @(posedge clk); #TA;
    lreq.aw_valid = 1'b0; lreq.w_valid = 1'b0; lreq.b_ready = 1'b0;
  endtask
  task automatic set_limit(int rcid, int rbwb, int mw);
    lite_wr(32'hC24, 32'h0);                       // bc_bw_alloc high word
    lite_wr(32'hC20, (32'(mw) << 20) | 32'(rbwb));
    lite_wr(32'hC1C, 32'h0);
    lite_wr(32'hC18, (32'(rcid) << 8) | 32'd1);    // CONFIG_LIMIT
  endtask

  // ------------------------------------------------------------------------------------------- threads
  // requests from the threads, the issuing processes, responses back by ID
  typedef struct { slv_aw_chan_t aw; data_t data[$]; strb_t strb[$]; } wreq_t;
  wreq_t        aw_q[$], w_q[$];
  slv_ar_chan_t ar_q[$];
  int unsigned  b_got[NT];
  data_t        r_data[NT][$];
  logic         r_last_seen[NT];
  int unsigned  n_buf = 0, n_unbuf = 0, done_threads = 0;
  logic         phase2 = 1'b0;

  initial begin                                    // slave port: AW in request order, then W in AW order, AR
    logic aw_hs = 1'b0, ar_hs = 1'b0, w_hs = 1'b0;
    int unsigned wk = 0;
    sreq = '0;
    sreq.b_ready = 1'b1; sreq.r_ready = 1'b1;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (aw_hs) begin sreq.aw_valid = 1'b0; w_q.push_back(aw_q.pop_front()); aw_hs = 1'b0; end
      if (ar_hs) begin sreq.ar_valid = 1'b0; void'(ar_q.pop_front()); ar_hs = 1'b0; end
      if (w_hs) begin
        sreq.w_valid = 1'b0; w_hs = 1'b0;
        if (wk == w_q[0].data.size() - 1) begin void'(w_q.pop_front()); wk = 0; end else wk++;
      end
      if (!sreq.aw_valid && aw_q.size() != 0 && $urandom_range(0, 2) != 0) begin
        sreq.aw = aw_q[0].aw; sreq.aw_valid = 1'b1;
      end
      if (!sreq.ar_valid && ar_q.size() != 0 && $urandom_range(0, 2) != 0) begin
        sreq.ar = ar_q[0]; sreq.ar_valid = 1'b1;
      end
      if (!sreq.w_valid && w_q.size() != 0 && $urandom_range(0, 3) != 0) begin
        sreq.w = '{data: w_q[0].data[wk], strb: w_q[0].strb[wk], last: wk == w_q[0].data.size() - 1, default: '0};
        sreq.w_valid = 1'b1;
      end
      #(TT - TA);
      aw_hs = sreq.aw_valid && sresp.aw_ready;
      ar_hs = sreq.ar_valid && sresp.ar_ready;
      w_hs  = sreq.w_valid  && sresp.w_ready;
      if (sresp.b_valid) begin
        if (sresp.b.id >= NT) fail($sformatf("B with ID %0d", sresp.b.id));
        else begin
          b_got[sresp.b.id]++;
          if (sresp.b.resp != axi_pkg::RESP_OKAY) fail($sformatf("B ID %0d resp %0d", sresp.b.id, sresp.b.resp));
        end
      end
      if (sresp.r_valid) begin
        if (sresp.r.id >= NT) fail($sformatf("R with ID %0d", sresp.r.id));
        else begin
          r_data[sresp.r.id].push_back(sresp.r.data);
          if (sresp.r.last) r_last_seen[sresp.r.id] = 1'b1;
          if (sresp.r.resp != axi_pkg::RESP_OKAY) fail($sformatf("R ID %0d resp %0d", sresp.r.id, sresp.r.resp));
        end
      end
    end
  end

  // beats of a burst that land on its first line (the LLC's first descriptor) and the most on any line
  function automatic int unsigned max_beats_on_line(addr_t a, int unsigned size, int unsigned len);
    int unsigned best, cur, k;
    addr_t line, ak;
    best = 0; cur = 0; line = '1;
    for (k = 0; k <= len; k++) begin
      ak = a + addr_t'(k << size);
      if ((ak >> 6) != line) begin line = ak >> 6; cur = 0; end
      cur++;
      if (cur > best) best = cur;
    end
    return best;
  endfunction

  byte unsigned ref_mem [NT][addr_t];              // what each thread wrote (both phases)
  // the address of beat k of an INCR burst (aligned bursts: start aligned to the beat size)
  function automatic addr_t incr_addr(addr_t a, int unsigned size, int unsigned k);
    return a + addr_t'(k << size);
  endfunction
  task automatic thread(int t);
    addr_t        base, a, ak, ab;
    bit           wr, narrow;
    int unsigned  size, len, nb, lo, b0, op, k, b;
    data_t        d;
    strb_t        sm;
    byte unsigned exp;
    wreq_t        w;
    slv_ar_chan_t ar;
    base = CACHED + addr_t'(t) * 32'h1_0000;
    for (op = 0; op < NOPS; op++) begin
      wr     = $urandom_range(0, 1);
      narrow = $urandom_range(0, 2) == 0;
      size   = narrow ? $urandom_range(0, 2) : 3;
      len    = narrow ? $urandom_range(0, 15) : $urandom_range(0, 7);
      nb     = 1 << size;
      a      = base + addr_t'($urandom_range(0, 4095 - (len + 1) * nb));
      a      = a & ~addr_t'(nb - 1);               // aligned to the beat size
      if (wr) begin
        b0 = b_got[t];
        w.data.delete(); w.strb.delete();
        w.aw = '0;
        w.aw.id = id_t'(t); w.aw.addr = a; w.aw.len = axi_pkg::len_t'(len); w.aw.size = axi_pkg::size_t'(size);
        w.aw.burst = axi_pkg::BURST_INCR; w.aw.cache = axi_pkg::CACHE_MODIFIABLE | axi_pkg::CACHE_BUFFERABLE;
        w.aw.user = user_t'({1'b0, 2'(t % 4), 2'(t % 4)});
        for (k = 0; k <= len; k++) begin
          ak = incr_addr(a, size, k);
          lo = ak % (DW / 8);
          d  = {$urandom, $urandom};
          sm = '0;
          for (b = lo; b < lo + nb; b++) sm[b] = $urandom_range(0, 3) != 0;
          w.data.push_back(d); w.strb.push_back(sm);
          for (b = 0; b < DW / 8; b++)
            if (sm[b]) ref_mem[t][(ak & ~addr_t'(DW / 8 - 1)) + addr_t'(b)] = d[8*b +: 8];
        end
        if (max_beats_on_line(a, size, len) > 8) n_unbuf++; else n_buf++;
        aw_q.push_back(w);
        while (b_got[t] == b0) @(posedge clk);
      end else begin
        ar = '0;
        ar.id = id_t'(t); ar.addr = a; ar.len = axi_pkg::len_t'(len); ar.size = axi_pkg::size_t'(size);
        ar.burst = axi_pkg::BURST_INCR; ar.cache = axi_pkg::CACHE_MODIFIABLE | axi_pkg::CACHE_BUFFERABLE;
        ar.user = user_t'({1'b0, 2'(t % 4), 2'(t % 4)});
        r_data[t].delete();
        r_last_seen[t] = 1'b0;
        ar_q.push_back(ar);
        while (!r_last_seen[t]) @(posedge clk);
        if (r_data[t].size() != len + 1) fail($sformatf("thread %0d: %0d R beats for len %0d", t, r_data[t].size(), len));
        for (k = 0; k <= len && k < r_data[t].size(); k++) begin
          ak = incr_addr(a, size, k);
          lo = ak % (DW / 8);
          for (b = lo; b < lo + nb; b++) begin
            ab  = (ak & ~addr_t'(DW / 8 - 1)) + addr_t'(b);
            exp = ref_mem[t].exists(ab) ? ref_mem[t][ab] : mem_rd(ab);
            if (r_data[t][k][8*b +: 8] !== exp)
              fail($sformatf("thread %0d op %0d: read %h (beat %0d of %0d, size %0d): %h, expected %h", t, op, ab, k,
                             len + 1, size, r_data[t][k][8*b +: 8], exp));
          end
        end
      end
    end
    done_threads++;
  endtask

  initial begin
    lreq = '0;
    for (int t = 0; t < NT; t++) begin b_got[t] = 0; r_last_seen[t] = 1'b0; end
    wait (rst_n);
    repeat (10) @(posedge clk);
    // phase 1: regulation off
    for (int t = 0; t < NT; t++) fork automatic int tt = t; thread(tt); join_none
    wait (done_threads == NT);
    $display("  phase 1 (regulation off): %0d threads x %0d operations done at %0t", NT, NOPS, $time);
    // phase 2: RCID 1 hard-limited
    lite_wr(32'hC88, 400);                          // BC_PERIOD
    lite_wr(32'hC90, 40 * 64);                      // BC_CAPACITY
    set_limit(0, 1, 255); set_limit(1, 1, 0); set_limit(2, 200, 64); set_limit(3, 1, 64);
    lite_wr(32'hC80, 3);                            // regulation and pacing
    phase2 = 1'b1;
    done_threads = 0;
    for (int t = 0; t < NT; t++) fork automatic int tt = t; thread(tt); join_none
    wait (done_threads == NT);
    $display("  phase 2 (RCID 1 hard-limited): done at %0t", $time);
    $display("  writes: %0d buffered (<= 8 beats per line), %0d with a line part of more than 8 beats (unbuffered)",
             n_buf, n_unbuf);
    if (WBUF != 0 && (n_buf == 0 || n_unbuf == 0)) fail("both kinds of writes expected");
    if (fails == 0) $display("LLC WBUF PASS (WBUF=%0d)", WBUF);
    else            $display("LLC WBUF FAIL: %0d failures (WBUF=%0d)", fails, WBUF);
    $finish;
  end
  initial begin                                    // deadline: a deadlock fails here
    #(CYC * 25000 * NOPS);
    $display("LLC WBUF FAIL: deadline, %0d threads done (phase %0d)", done_threads, phase2 + 1);
    $finish;
  end
endmodule
