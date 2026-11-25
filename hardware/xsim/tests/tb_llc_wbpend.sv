// LLC write-back test (ip_list/axi_llc/src/eviction_refill/axi_llc_w_master.sv, PendDepth): data integrity when the
// miss pipeline no longer waits for the write response of every write-back.
//
// The LLC and the traffic of tb_llc_wbuf.sv (4 ways x 32 sets, eight threads with an AXI ID and a region each, a
// reference memory per thread that predicts every read), in front of a memory that does everything AXI allows it to
// and that hurts:
//   * a write-back is applied only when its write response is handed over, and the response comes BMIN..BMAX cycles
//     after the last W beat;
//   * responses of different IDs come in any order (BREORDER; per ID in order);
//   * a read returns what the memory held when its AR was accepted, so a refill sent before the response of the
//     line's write-back reads the stale line. The threads' regions are small (REGION bytes), so a line is often
//     missed again while its write-back is unanswered.
// Harder cases (parameters):
//   HOT       the first HOT threads walk HOTL lines of one of HOTS sets (HOTL > the 4 ways): every access misses,
//             evicts a dirty line and soon asks again for a line it has just pushed out
//   BYP       a ninth thread outside the cached window: its traffic takes the LLC's bypass to the same memory port
//             (W beats of both kinds share the port in AW order)
//   AWLIM     the memory takes a new AW only while fewer than AWLIM writes are unanswered
//   BBURST    the memory holds every write response for a while, then answers one per cycle
//   FLUSHMID  flushes of random ways fired while the threads run; at the end of each one no write-back may be
//             unanswered
// Phase 1: regulation off. Phase 2: RCID 1 hard-limited (parked misses). Phase 3: the LLC is flushed; when it reports
// the flush done, every write response must be in and the memory must hold what the threads wrote. Phase 4: traffic
// again.
// Checks: every read beat against the reference; every response OKAY; the memory never holds more unanswered,
// complete write-backs than PEND allows (one with PEND = 0); the flush check; with PEND > 0, that refills did wait
// for the write-back of their own line (the case is covered) and that write-backs did overlap; a deadline.
// Mutants (run_llc_wbpend.sh MUTANT=...): the unit without the wait of such a refill, and without the wait of the
// flush, must fail here.
`include "axi/typedef.svh"

module tb_llc_wbpend #(
  parameter int unsigned PEND     = 4,
  parameter int unsigned WBUF     = 8,
  parameter int unsigned NT       = 8,
  parameter int unsigned NOPS     = 400,
  parameter int unsigned REGION   = 1024,   // bytes per thread (a power of two, at most 4096)
  parameter int unsigned BMIN     = 20,
  parameter int unsigned BMAX     = 250,
  parameter bit          BREORDER = 1'b1,
  parameter int unsigned RMIN     = 2,      // cycles from the AR to the first R beat
  parameter int unsigned RMAX     = 40,
  parameter int unsigned HOT      = 0,
  parameter int unsigned HOTL     = 6,
  parameter int unsigned HOTS     = 2,
  parameter bit          BYP      = 1'b0,
  parameter int unsigned AWLIM    = 0,
  parameter bit          BBURST   = 1'b0,
  parameter int unsigned FLUSHMID = 0,
  parameter bit          COVER    = 1'b1    // fail when the run did not reach the cases it is meant for
);
  localparam int unsigned NTT = NT + 1;     // thread NT is the bypass thread (BYP)
  localparam logic [31:0] BYPASS = 32'h9000_0000;
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
  // The LLC's own requests (memory-port ID with the top bit clear) are whole lines: 8 beats of 8 bytes, every strobe
  // set. Bypassed requests (top bit set) are whatever the thread sent.
  typedef struct { mst_aw_chan_t aw; int unsigned seq; } m_w_t;
  typedef struct { mst_ar_chan_t ar; int unsigned delay; data_t d [16]; } m_r_t;
  typedef struct { mid_t id; int unsigned seq; int unsigned delay; bit llc; } m_b_t;   // complete, unanswered
  m_w_t mw_q[$];  m_b_t mb_q[$];  m_r_t mr_q[$];
  addr_t        pb_a[$];                           // the bytes of the unanswered writes, in arrival order
  byte unsigned pb_d[$];
  int unsigned  pb_s[$];
  int unsigned  wseq = 0, n_wb = 0, max_unanswered = 0, n_b_ooo = 0, n_byp_w = 0, n_byp_r = 0, n_awlim = 0;
  bit           b_gate = 1'b1;
  function automatic int unsigned llc_unanswered();
    int unsigned n = 0;
    foreach (mb_q[i]) if (mb_q[i].llc) n++;
    return n;
  endfunction
  initial begin                                    // memory: AW and AR; a read is sampled when its AR is accepted
    bit lim;
    mresp = '0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      lim = (AWLIM != 0) && (mw_q.size() + mb_q.size() >= AWLIM);
      mresp.aw_ready = ($urandom_range(0, 3) != 0) && !lim;
      mresp.ar_ready = $urandom_range(0, 3) != 0;
      #(TT - TA);
      if (mreq.aw_valid && lim) n_awlim++;
      if (mreq.aw_valid && mresp.aw_ready) begin
        m_w_t e; e.aw = mreq.aw; e.seq = wseq++; mw_q.push_back(e);
        if (!mreq.aw.id[IW] && (mreq.aw.len != 7 || mreq.aw.size != 3 || mreq.aw.addr[5:0] != '0))
          fail("memory: AW of the LLC is not a whole line");
      end
      if (mreq.ar_valid && mresp.ar_ready) begin
        m_r_t e; e.ar = mreq.ar; e.delay = $urandom_range(RMIN, RMAX);
        if (!mreq.ar.id[IW] && (mreq.ar.len != 7 || mreq.ar.size != 3 || mreq.ar.addr[5:0] != '0))
          fail("memory: AR of the LLC is not a whole line");
        if (mreq.ar.len > 15) fail("memory: AR of more than 16 beats");
        for (int k = 0; k <= mreq.ar.len && k < 16; k++) begin
          addr_t a  = axi_pkg::beat_addr(mreq.ar.addr, mreq.ar.size, mreq.ar.len, mreq.ar.burst, k);
          addr_t al = a & ~addr_t'(DW / 8 - 1);
          for (int b = 0; b < DW / 8; b++) e.d[k][8*b +: 8] = mem_rd(al + b);
        end
        if (mreq.ar.id[IW]) n_byp_r++;
        mr_q.push_back(e);
      end
    end
  end
  initial begin                                    // memory: W beats of the oldest AW, kept until the response
    int unsigned beat = 0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      mresp.w_ready = (mw_q.size() != 0) && ($urandom_range(0, 3) != 0);
      #(TT - TA);
      if (mreq.w_valid && mresp.w_ready) begin
        m_w_t t = mw_q[0];
        addr_t a  = axi_pkg::beat_addr(t.aw.addr, t.aw.size, t.aw.len, t.aw.burst, beat);
        addr_t al = a & ~addr_t'(DW / 8 - 1);
        if (!t.aw.id[IW] && mreq.w.strb != '1) fail("memory: W strobe of the LLC not full");
        for (int b = 0; b < DW / 8; b++) if (mreq.w.strb[b]) begin
          pb_a.push_back(al + b); pb_d.push_back(mreq.w.data[8*b +: 8]); pb_s.push_back(t.seq);
        end
        if (beat == t.aw.len) begin
          m_b_t e;
          if (!mreq.w.last) fail("memory: W last missing");
          e.id = t.aw.id; e.seq = t.seq; e.delay = $urandom_range(BMIN, BMAX); e.llc = !t.aw.id[IW];
          mb_q.push_back(e);
          if (e.llc) n_wb++; else n_byp_w++;
          if (llc_unanswered() > max_unanswered) max_unanswered = llc_unanswered();
          void'(mw_q.pop_front());
          beat = 0;
        end else beat++;
      end
    end
  end
  initial begin                                    // memory: B, and with it the write
    logic hs = 1'b0;
    int   sel = 0, cand[$];
    int unsigned sq;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs) begin                                // the response was handed over at this edge: the write is in
        sq = mb_q[sel].seq;
        for (int i = 0; i < pb_a.size(); ) begin
          if (pb_s[i] == sq) begin mem[pb_a[i]] = pb_d[i]; pb_a.delete(i); pb_d.delete(i); pb_s.delete(i); end
          else i++;
        end
        mresp.b_valid = 1'b0; mb_q.delete(sel); hs = 1'b0;
      end
      foreach (mb_q[i]) if (mb_q[i].delay != 0) mb_q[i].delay--;
      if (BBURST && $urandom_range(0, 149) == 0) b_gate = ~b_gate;   // hold everything for a while, then answer in a row
      if (!mresp.b_valid && mb_q.size() != 0 && b_gate && (BBURST || $urandom_range(0, 2) != 0)) begin
        // due responses that have no older write of their ID before them (AXI: per ID in order)
        cand.delete();
        foreach (mb_q[i]) if (mb_q[i].delay == 0) begin
          bit older = 1'b0;
          for (int j = 0; j < i; j++) if (mb_q[j].id == mb_q[i].id) older = 1'b1;
          if (!older && (BREORDER || i == 0)) cand.push_back(i);
        end
        if (cand.size() != 0) begin
          sel = cand[$urandom_range(0, cand.size() - 1)];
          if (sel != 0) n_b_ooo++;
          mresp.b = '{id: mb_q[sel].id, resp: axi_pkg::RESP_OKAY, default: '0};
          mresp.b_valid = 1'b1;
        end
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
        mresp.r = '{id: mr_q[0].ar.id, data: mr_q[0].d[beat], resp: axi_pkg::RESP_OKAY, last: beat == mr_q[0].ar.len,
                    default: '0};
        mresp.r_valid = 1'b1;
      end
      #(TT - TA);
      hs = mresp.r_valid && mreq.r_ready;
    end
  end
  // complete write-backs of the LLC without a response: at most PEND of them, one in the original unit
  always @(posedge clk) if (rst_n && llc_unanswered() > (PEND == 0 ? 1 : PEND))
    fail($sformatf("memory: %0d complete write-backs unanswered, PEND %0d", llc_unanswered(), PEND));
  // the end of a flush (the LLC lets its slave port go again): every write-back answered
  logic iso_q = 1'b0;
  int unsigned n_flush_end = 0;
  always @(posedge clk) begin
    if (rst_n && iso_q && !i_dut.llc_isolate) begin
      n_flush_end++;
      if (llc_unanswered() != 0)
        fail($sformatf("a flush ended with %0d write-backs unanswered", llc_unanswered()));
    end
    iso_q <= i_dut.llc_isolate;
  end

  // ------------------------------------------------------------------------------------------- config port
  semaphore lite_sem = new(1);
  task automatic lite_wr(logic [31:0] a, logic [31:0] d);
    logic aw_done = 1'b0, w_done = 1'b0;
    lite_sem.get();
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
    lite_sem.put();
  endtask
  task automatic lite_rd(logic [31:0] a, output logic [31:0] d);
    logic ar_done = 1'b0;
    lite_sem.get();
    @(posedge clk); #TA;
    lreq.ar = '{addr: a, default: '0}; lreq.ar_valid = 1'b1; lreq.r_ready = 1'b1;
    forever begin
      #(TT - TA);
      if (lreq.ar_valid && lresp.ar_ready) ar_done = 1'b1;
      if (lresp.r_valid) begin d = lresp.r.data; break; end
      @(posedge clk); #TA;
      if (ar_done) lreq.ar_valid = 1'b0;
    end
    @(posedge clk); #TA;
    lreq.ar_valid = 1'b0; lreq.r_ready = 1'b0;
    lite_sem.put();
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
  int unsigned  b_got[NTT];
  data_t        r_data[NTT][$];
  logic         r_last_seen[NTT];
  int unsigned  n_buf = 0, n_unbuf = 0, done_threads = 0;
  int unsigned  phase = 1;

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
        if (sresp.b.id >= NTT) fail($sformatf("B with ID %0d", sresp.b.id));
        else begin
          b_got[sresp.b.id]++;
          if (sresp.b.resp != axi_pkg::RESP_OKAY) fail($sformatf("B ID %0d resp %0d", sresp.b.id, sresp.b.resp));
        end
      end
      if (sresp.r_valid) begin
        if (sresp.r.id >= NTT) fail($sformatf("R with ID %0d", sresp.r.id));
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

  byte unsigned ref_mem [NTT][addr_t];             // what each thread wrote (all phases)
  // the address of beat k of an INCR burst (aligned bursts: start aligned to the beat size)
  function automatic addr_t incr_addr(addr_t a, int unsigned size, int unsigned k);
    return a + addr_t'(k << size);
  endfunction
  task automatic thread(int t, int unsigned nops);
    addr_t        base, a, ak, ab;
    bit           wr, narrow;
    int unsigned  size, len, nb, lo, b0, op, k, b;
    data_t        d;
    strb_t        sm;
    byte unsigned exp;
    wreq_t        w;
    slv_ar_chan_t ar;
    base = (t == NT) ? BYPASS : CACHED + addr_t'(t) * 32'h1_0000;
    for (op = 0; op < nops; op++) begin
      wr     = $urandom_range(0, 1);
      if (t < HOT) begin
        // one of HOTL lines of one of HOTS sets (2 KB apart: same set, another tag), a part of that line
        lo     = $urandom_range(0, 7);
        size   = 3;
        len    = $urandom_range(0, 7 - lo);
        nb     = 8;
        narrow = 1'b0;
        a      = base + addr_t'($urandom_range(0, HOTS - 1) * 64 + $urandom_range(0, HOTL - 1) * 2048 + lo * 8);
        wr     = $urandom_range(0, 2) != 0;        // mostly writes: the lines pushed out are dirty
      end else begin
        narrow = $urandom_range(0, 2) == 0;
        size   = narrow ? $urandom_range(0, 2) : 3;
        len    = narrow ? $urandom_range(0, 15) : $urandom_range(0, 7);
        nb     = 1 << size;
        a      = base + addr_t'($urandom_range(0, REGION - 1 - (len + 1) * nb));
        a      = a & ~addr_t'(nb - 1);             // aligned to the beat size
      end
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
        if (t != NT) begin if (max_beats_on_line(a, size, len) > 8) n_unbuf++; else n_buf++; end
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

  // the write unit's counters (simulation monitor in axi_llc_w_master)
  `define WM i_dut.i_evict_unit.i_w_master
  int unsigned n_run = NT + (BYP ? 1 : 0);
  bit          traffic = 1'b0;
  int unsigned n_midflush = 0;
  task automatic run_threads(int unsigned nops);
    done_threads = 0;
    traffic = 1'b1;
    for (int t = 0; t < NTT; t++) if (t < NT || BYP) fork automatic int tt = t; thread(tt, nops); join_none
    wait (done_threads == n_run);
    traffic = 1'b0;
  endtask
  initial begin                                    // flushes of random ways while the threads run
    logic [31:0] v;
    wait (rst_n);
    forever begin
      repeat ($urandom_range(3000, 30000)) @(posedge clk);
      if (traffic && n_midflush < FLUSHMID && phase <= 2) begin
        n_midflush++;
        lite_wr(32'h08, 32'($urandom_range(1, 15)));
        do lite_rd(32'h08, v); while (v[3:0] != 4'h0);
      end
    end
  end
  initial begin
    logic [31:0] v;
    int unsigned n_chk, n_bad;
    lreq = '0;
    for (int t = 0; t < NTT; t++) begin b_got[t] = 0; r_last_seen[t] = 1'b0; end
    wait (rst_n);
    repeat (10) @(posedge clk);
    // phase 1: regulation off
    run_threads(NOPS);
    $display("  phase 1 (regulation off): %0d threads x %0d operations done at %0t", n_run, NOPS, $time);
    // phase 2: RCID 1 hard-limited
    lite_wr(32'hC88, 400);                          // BC_PERIOD
    lite_wr(32'hC90, 40 * 64);                      // BC_CAPACITY
    set_limit(0, 1, 255); set_limit(1, 1, 0); set_limit(2, 200, 64); set_limit(3, 1, 64);
    lite_wr(32'hC80, 3);                            // regulation and pacing
    phase = 2;
    run_threads(NOPS);
    $display("  phase 2 (RCID 1 hard-limited): done at %0t", $time);
    lite_wr(32'hC80, 2);                            // regulation off again
    // phase 3: flush every way. Done (CfgFlush reads 0) means: every write-back answered, the memory up to date.
    phase = 3;
    lite_wr(32'h08, 32'hF);
    do lite_rd(32'h08, v); while (v[3:0] != 4'h0);
    if (llc_unanswered() != 0 || mw_q.size() != 0)
      fail($sformatf("flush reported done with %0d write responses and %0d writes outstanding", llc_unanswered(), mw_q.size()));
    n_chk = 0; n_bad = 0;
    for (int t = 0; t < NT; t++) begin
      addr_t ab;
      if (ref_mem[t].first(ab)) do begin
        n_chk++;
        if (mem_rd(ab) !== ref_mem[t][ab]) begin
          n_bad++;
          if (n_bad <= 4) fail($sformatf("after the flush the memory holds %h at %h, thread %0d wrote %h", mem_rd(ab), ab, t, ref_mem[t][ab]));
        end
      end while (ref_mem[t].next(ab));
    end
    if (n_bad > 4) fail($sformatf("after the flush %0d of %0d bytes differ from what the threads wrote", n_bad, n_chk));
    $display("  phase 3 (flush): done at %0t, %0d bytes of the memory checked against the threads' writes", $time, n_chk);
    // phase 4: traffic after the flush
    phase = 4;
    run_threads(NOPS / 4);
    $display("  phase 4 (after the flush): done at %0t", $time);
    $display("  memory: %0d write-backs, at most %0d complete ones unanswered at a time, %0d responses out of order; bypass %0d writes, %0d reads; %0d flushes ended (%0d fired mid-traffic); AW held by the limit in %0d cycles",
             n_wb, max_unanswered, n_b_ooo, n_byp_w, n_byp_r, n_flush_end, n_midflush, n_awlim);
    $display("  write unit: %0d write-backs; %0d refills waited for the write-back of their own line (%0d cycles); descriptors stood %0d cycles behind a write-back waiting for its response and %0d cycles for a free entry",
             `WM.wb_n, `WM.wb_line_wait_n, `WM.wb_line_wait, `WM.wb_behind, `WM.wb_full_wait);
    if (COVER) begin
      if (WBUF != 0 && (n_buf == 0 || n_unbuf == 0) && HOT < NT) fail("both kinds of writes expected");
      if (PEND > 0 && `WM.wb_line_wait_n == 0) fail("no refill ever waited for the write-back of its own line: the case is not covered");
      // (a response within a few cycles comes before the next write-back has sent its eight beats)
      if (PEND > 1 && BMIN >= 16 && AWLIM != 1 && max_unanswered < 2) fail("write-backs never overlapped");
      if (PEND == 0 && `WM.wb_behind == 0) fail("PEND = 0: no descriptor ever stood behind a write-back");
      if (BYP && (n_byp_w == 0 || n_byp_r == 0)) fail("no bypass traffic reached the memory");
      if (FLUSHMID != 0 && n_midflush == 0) fail("no flush was fired during the traffic");
    end
    if (fails == 0) $display("LLC WBPEND PASS (PEND=%0d WBUF=%0d)", PEND, WBUF);
    else            $display("LLC WBPEND FAIL: %0d failures (PEND=%0d WBUF=%0d)", fails, PEND, WBUF);
    $finish;
  end
  initial begin                                    // deadline: a deadlock fails here
    #(CYC * 60000 * NOPS);
    $display("LLC WBPEND FAIL: deadline, %0d threads done (phase %0d)", done_threads, phase);
    $finish;
  end
endmodule
