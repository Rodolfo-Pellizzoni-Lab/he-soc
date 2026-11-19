// tb_llc_bc.sv: unit test of the LLC's CBQRI bandwidth controller (ip_list/axi_llc/src/axi_llc_cbqri_bc.sv).
// Descriptors from several RCIDs enter the parking pool; the consumer models a memory that needs SVC cycles per line
// (a refill or an eviction), so the controller's release order decides who gets the bandwidth.
//   A  regulation off: the pool is a FIFO
//   B  registers: capabilities, CONFIG_LIMIT / READ_LIMIT and every STATUS, the sum rule, read-only fields, monitor ops
//   C  reservations: RCID 1 Rbwb 50 % Mweight 0, RCID 2 20 % Mweight 0, RCID 3 1 block Mweight 16 -> 50 / 20 / ~30 %
//   D  sharing: Rbwb 1 block each, Mweight 32 / 64 / 128 -> 1/7, 2/7, 4/7
//   E  floor under contention: RCID 1 Rbwb 40 % Mweight 1, RCIDs 2 and 3 1 block Mweight 255 -> RCID 1 >= 40 %
//   F  ordered writes: RCID 1 writes at a hard 1-block limit, RCID 2 writes with 40 % -> RCID 2 still gets 40 %
//      (priority inheritance releases RCID 1's writes that RCID 2's wait for)
//   G  monitoring: per-MCID read+write / read / write byte counts equal the released traffic
//   H  random traffic and configurations, then a drain: nothing is lost or stuck
//   J  pacing with two-line descriptors: RCID 1 (Rbwb 40 %) misses always evict a dirty line (two lines each), RCID 2
//      (1 block, Mweight 64) costs one line each: RCID 1 still gets its 40 % (a lower class must not take the
//      tokens a higher one waits for; before the fix RCID 1 starved)
//   I  a memory with a queue in front (8 descriptors, like the refill path and the memory's own FIFOs) and one
//      descriptor in flight per RCID: with pacing (BC_CTRL.PACE) the waiting happens in the pool and Mweight
//      32 / 64 / 128 still gives 1/7, 2/7, 4/7; without pacing the queue serves in arrival order (logged only);
//      BC_RATE = BC_CAPACITY * 2^16 / BC_PERIOD
// Always: every descriptor leaves once, and none leaves before an older one of its AXI ID, an older write (if it is
// a write) or an older flush (and a flush before nothing older).
// Prints "LLC BC UNIT PASS" or "LLC BC UNIT FAIL: <n> failures".
`include "axi/typedef.svh"

module tb_llc_bc;
  localparam time CYC = 10ns, TA = 2ns, TT = 8ns;
  localparam int unsigned SVC = 4;                    // memory: cycles per line
  localparam int unsigned NR = 4;                     // RCIDs used (0..3)

  typedef struct packed {
    logic [3:0]  a_x_id;
    logic [31:0] a_x_addr;                            // sequence number (the scoreboard's key)
    logic [11:0] a_x_user;                            // [2:0] port, [6:3] RCID, [10:7] MCID, [11] AT
    logic        rw;
    logic        refill;
    logic        evict;
    logic        flush;
    logic        wbuf;                                // a write with buffered W beats (only per-ID order)
    logic [15:0] evict_tag;                           // all ones: never the tag of a sequence number (no line hazards
  } desc_t;                                           // here; tb_llc_wbuf covers them in the LLC)

  `AXI_LITE_TYPEDEF_ALL(lite, logic [31:0], logic [31:0], logic [3:0])

  logic clk = 1'b0, rst_n = 1'b0;
  always #(CYC / 2) clk = ~clk;

  lite_req_t  lreq;
  lite_resp_t lresp;
  desc_t      in_d, out_d;
  logic       in_v, in_r, out_v, out_r;

  axi_llc_cbqri_bc #(
    .desc_t      ( desc_t     ),
    .RcidWidth   ( 4          ),
    .RcidLsb     ( 3          ),
    .McidWidth   ( 4          ),
    .McidLsb     ( 7          ),
    .LineBytes   ( 64         ),
    .PoolDepth   ( 16         ),
    .CtrWidth    ( 48         ),
    .DataWidth   ( 32         ),
    .lite_req_t  ( lite_req_t ),
    .lite_resp_t ( lite_resp_t)
  ) dut (
    .clk_i   ( clk   ), .rst_ni  ( rst_n ),
    .req_i   ( lreq  ), .resp_o  ( lresp ),
    .desc_i  ( in_d  ), .valid_i ( in_v  ), .ready_o ( in_r ),
    .desc_o  ( out_d ), .valid_o ( out_v ), .ready_i ( out_r )
  );

  int unsigned fails = 0;
  function automatic void fail(string m);
    fails++;
    if (fails <= 25) $display("FAIL: %s", m);
  endfunction

  // ------------------------------------------------------------------------------------------- register access
  task automatic wr32(logic [31:0] a, logic [31:0] d);
    @(posedge clk); #TA;
    lreq.aw = '{addr: a, prot: '0}; lreq.aw_valid = 1'b1;
    lreq.w  = '{data: d, strb: 4'hF}; lreq.w_valid = 1'b1;
    lreq.b_ready = 1'b1;
    do @(posedge clk); while (!lresp.aw_ready);
    #TA; lreq.aw_valid = 1'b0; lreq.w_valid = 1'b0;
    while (!lresp.b_valid) @(posedge clk);
    @(posedge clk); #TA; lreq.b_ready = 1'b0;
  endtask
  task automatic rd32(logic [31:0] a, output logic [31:0] d);
    @(posedge clk); #TA;
    lreq.ar = '{addr: a, prot: '0}; lreq.ar_valid = 1'b1; lreq.r_ready = 1'b1;
    do @(posedge clk); while (!lresp.ar_ready);
    #TA; lreq.ar_valid = 1'b0;
    while (!lresp.r_valid) @(posedge clk);
    #(TT - TA); d = lresp.r.data;
    @(posedge clk); #TA; lreq.r_ready = 1'b0;
  endtask
  task automatic wr64(logic [11:0] off, logic [63:0] v);   // high word first, the low word (OP) starts it
    wr32(32'(off) + 4, v[63:32]);
    wr32(32'(off), v[31:0]);
  endtask
  task automatic rd64(logic [11:0] off, output logic [63:0] v);
    logic [31:0] lo, hi;
    rd32(32'(off), lo); rd32(32'(off) + 4, hi);
    v = {hi, lo};
  endtask
  // CONFIG_LIMIT / READ_LIMIT; returns STATUS
  task automatic limit(int op, int rcid, int rbwb, int mw, output int st, input int at = 0);
    logic [63:0] v;
    if (op == 1) wr64(12'h20, {32'd0, 1'b0, 3'd0, 8'(mw), 4'd0, 16'(rbwb)});
    wr64(12'h18, {44'd0, 12'(rcid), 3'(at), 5'(op)});
    rd64(12'h18, v);
    st = int'(v[38:32]);
  endtask
  task automatic set_limit(int rcid, int rbwb, int mw);
    int st;
    limit(1, rcid, rbwb, mw, st);
    if (st != 1) fail($sformatf("CONFIG_LIMIT RCID %0d Rbwb %0d Mweight %0d: STATUS %0d", rcid, rbwb, mw, st));
  endtask
  task automatic mon(int op, int mcid, int evt, output int st);
    logic [63:0] v;
    wr64(12'h08, {36'd0, 8'(evt), 12'(mcid), 3'd0, 5'(op)});
    rd64(12'h08, v);
    st = int'(v[38:32]);
  endtask

  // ------------------------------------------------------------------------------------------- traffic
  // generator: per RCID, a weight (0 = off) and the share of writes (percent); IDs: RCID r uses IDs 4r..4r+3
  int unsigned gen_on[NR], gen_wr_pct[NR], gen_flush_pct;
  int          gen_evict_pct[NR] = '{-1, -1, -1, -1};      // -1: one in three refills evicts
  logic        gen_rand_ids;                            // H: any ID for any RCID
  int unsigned gen_wbuf_pct = 0;                        // K, L: share of writes with buffered W beats
  int unsigned seq = 0;
  desc_t       inserted[$];
  bit          done[int unsigned];
  longint unsigned rel_bytes[NR];                       // released bytes per RCID (measurement window)
  longint unsigned mon_rd[16], mon_wr[16];              // per MCID since the counters were configured
  bit          measure = 1'b0;
  int unsigned rr = 0;

  function automatic desc_t make(int unsigned r);
    desc_t d;
    int unsigned mc;
    d = '0;
    d.a_x_addr = seq;
    d.evict_tag = '1;
    d.a_x_id   = gen_rand_ids ? 4'($urandom_range(0, 15)) : 4'(4 * r + $urandom_range(0, 3));
    mc         = r;                                     // MCID = RCID
    d.a_x_user = {1'b0, 4'(mc), 4'(r), 3'(r)};
    d.flush    = ($urandom_range(0, 99) < gen_flush_pct);
    d.rw       = ($urandom_range(0, 99) < gen_wr_pct[r]);
    d.wbuf     = d.rw && !d.flush && ($urandom_range(0, 99) < gen_wbuf_pct);
    if (d.flush) begin d.refill = 1'b0; d.evict = $urandom_range(0, 1); end
    else begin
      d.refill = ($urandom_range(0, 9) != 0);           // 10 % pass-through (a hit routed through the miss path)
      d.evict  = d.refill && ((gen_evict_pct[r] < 0) ? ($urandom_range(0, 2) == 0)
                                                     : ($urandom_range(0, 99) < gen_evict_pct[r]));
    end
    return d;
  endfunction

  // producer: offers one descriptor at a time, from an active RCID that has fewer than MLP descriptors in flight
  // (a core has only a few misses outstanding; MLP x active RCIDs <= the pool keeps the pool from filling)
  int unsigned mlp = 4;
  int unsigned inflight[NR];
  initial begin
    bit took;
    in_v = 1'b0; in_d = '0;
    for (int k = 0; k < NR; k++) inflight[k] = 0;
    wait (rst_n);
    forever begin
      @(posedge clk);
      took = in_v && in_r;
      if (took) begin
        inserted.push_back(in_d);
        inflight[in_d.a_x_user[6:3]]++;
        seq++;
      end
      #TA;
      if (took) in_v = 1'b0;
      if (!in_v) begin
        int unsigned tot = 0, pick, acc = 0, r;
        int unsigned w[NR];
        for (int k = 0; k < NR; k++) begin w[k] = (inflight[k] < mlp) ? gen_on[k] : 0; tot += w[k]; end
        if (tot != 0) begin
          pick = $urandom_range(0, tot - 1);
          r = 0;
          for (int k = 0; k < NR; k++) begin
            if (pick >= acc && pick < acc + w[k]) r = k;
            acc += w[k];
          end
          in_d = make(r);
          in_v = 1'b1;
        end
      end
    end
  end

  // consumer: the memory takes a descriptor when idle and is then busy SVC cycles per line it moves; with dq > 0 a
  // queue of dq descriptors in front of it takes descriptors while it is busy (served in arrival order)
  int unsigned busy = 0, dq = 0;
  int unsigned q_lines[$];
  assign out_r = (dq == 0) ? (busy == 0) : (q_lines.size() < dq);
  always @(posedge clk) begin
    int unsigned lines;
    if (!rst_n) busy <= 0;
    else begin
      if (out_v && out_r) begin
        lines = (out_d.flush ? 0 : (int'(out_d.refill) + int'(out_d.evict)));
        check_out(out_d);
        if (dq == 0) busy <= (lines == 0) ? 0 : SVC * lines - 1;
        else q_lines.push_back(lines);
      end else if (dq == 0 && busy != 0) busy <= busy - 1;
      if (dq != 0) begin
        if (busy != 0) busy <= busy - 1;
        else if (q_lines.size() != 0) begin
          lines = q_lines.pop_front();
          busy <= (lines == 0) ? 0 : SVC * lines - 1;
        end
      end
    end
  end

  // ordering and uniqueness
  int unsigned oldest_open = 0;                         // all seq below are done
  function automatic void check_out(desc_t d);
    int unsigned s = d.a_x_addr;
    desc_t o;
    if (done.exists(s)) begin fail($sformatf("descriptor %0d left twice", s)); return; end
    if (s >= inserted.size()) begin fail($sformatf("descriptor %0d left but was never inserted", s)); return; end
    for (int unsigned t = oldest_open; t < s; t++) if (!done.exists(t)) begin
      o = inserted[t];
      if (o.a_x_id == d.a_x_id || (o.rw && d.rw && !(o.wbuf && d.wbuf)) || o.flush || d.flush)
        fail($sformatf("descriptor %0d (id %0d rw %0d flush %0d) left before older %0d (id %0d rw %0d flush %0d)",
                       s, d.a_x_id, d.rw, d.flush, t, o.a_x_id, o.rw, o.flush));
    end
    done[s] = 1'b1;
    inflight[d.a_x_user[6:3]]--;
    while (done.exists(oldest_open)) oldest_open++;
    if (measure && !d.flush) rel_bytes[d.a_x_user[6:3]] += 64 * (int'(d.refill) + int'(d.evict));
    if (!d.flush) begin
      if (d.refill) mon_rd[d.a_x_user[10:7]] += 64;
      if (d.evict)  mon_wr[d.a_x_user[10:7]] += 64;
    end
  endfunction

  task automatic traffic(input int unsigned on[NR], input int unsigned wr[NR], int unsigned flush_pct);
    for (int k = 0; k < NR; k++) begin gen_on[k] = on[k]; gen_wr_pct[k] = wr[k]; end
    gen_flush_pct = flush_pct;
  endtask
  task automatic stop_and_drain(int unsigned max_cycles = 20000);
    for (int k = 0; k < NR; k++) gen_on[k] = 0;
    repeat (4) @(posedge clk);
    for (int unsigned c = 0; c < max_cycles && done.size() < inserted.size(); c++) @(posedge clk);
    if (done.size() != inserted.size())
      fail($sformatf("drain: %0d of %0d descriptors left", done.size(), inserted.size()));
  endtask
  // measure the shares of RCIDs 1..3 over n cycles
  task automatic shares(int unsigned n, output real sh[NR]);
    longint unsigned tot = 0;
    for (int k = 0; k < NR; k++) rel_bytes[k] = 0;
    measure = 1'b1;
    repeat (n) @(posedge clk);
    measure = 1'b0;
    for (int k = 0; k < NR; k++) tot += rel_bytes[k];
    for (int k = 0; k < NR; k++) sh[k] = (tot == 0) ? 0.0 : real'(rel_bytes[k]) / real'(tot);
  endtask
  task automatic expect_share(string t, int r, real got, real lo, real hi);
    $display("  %s RCID %0d: %5.1f %% (expected %4.1f..%4.1f)", t, r, 100.0 * got, 100.0 * lo, 100.0 * hi);
    if (got < lo || got > hi) fail($sformatf("%s: RCID %0d share %.3f outside %.3f..%.3f", t, r, got, lo, hi));
  endtask

  // FIFO check for A
  int unsigned fifo_next = 0;
  bit fifo_mode = 1'b0;
  always @(posedge clk) if (rst_n && fifo_mode && out_v && out_r) begin
    if (out_d.a_x_addr != fifo_next) fail($sformatf("A: descriptor %0d left, %0d expected (FIFO)", out_d.a_x_addr, fifo_next));
    fifo_next <= out_d.a_x_addr + 1;
  end

  // ------------------------------------------------------------------------------------------- tests
  localparam int unsigned PERIOD = 4000;                // cycles
  localparam int unsigned CAP    = PERIOD / SVC * 64;   // bytes the memory moves per period

  initial begin
    logic [63:0] v;
    int st;
    real sh[NR];
    lreq = '0;
    gen_rand_ids = 1'b0;
    for (int k = 0; k < NR; k++) begin gen_on[k] = 0; gen_wr_pct[k] = 0; end
    gen_flush_pct = 0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    // ---- A
    fifo_mode = 1'b1;
    traffic('{0, 1, 1, 1}, '{0, 30, 30, 30}, 2);
    repeat (3000) @(posedge clk);
    stop_and_drain();
    fifo_mode = 1'b0;
    $display("  A: %0d descriptors through the pool in order with regulation off", inserted.size());

    // ---- B
    rd64(12'h00, v);
    if (v !== {16'd0, 16'd819, 3'd0, 4'd0, 1'b0, 16'd1024, 8'h10}) fail($sformatf("B: bc_capabilities %h", v));
    limit(2, 0, 0, 0, st); rd64(12'h20, v);
    if (st != 1 || v[15:0] != 16'd819 || v[27:20] != 8'd255) fail($sformatf("B: reset RCID 0 %h STATUS %0d", v, st));
    limit(2, 5, 0, 0, st); rd64(12'h20, v);
    if (st != 1 || v[15:0] != 16'd0 || v[27:20] != 8'd1) fail($sformatf("B: reset RCID 5 %h", v));
    limit(1, 1, 1, 8, st);   if (st != 5) fail($sformatf("B: sum 820 > 819 gave STATUS %0d", st));
    limit(1, 0, 400, 255, st); if (st != 1) fail($sformatf("B: RCID 0 Rbwb 400: STATUS %0d", st));
    limit(1, 1, 0, 8, st);   if (st != 5) fail($sformatf("B: Rbwb 0 gave STATUS %0d", st));
    limit(1, 1, 820, 8, st); if (st != 5) fail($sformatf("B: Rbwb 820 > MRBWB gave STATUS %0d", st));
    limit(1, 1, 419, 8, st); if (st != 1) fail($sformatf("B: Rbwb 419 (sum 819) gave STATUS %0d", st));
    limit(1, 2, 1, 8, st);   if (st != 5) fail($sformatf("B: sum 820 (RCID 2) gave STATUS %0d", st));
    limit(2, 1, 0, 0, st); rd64(12'h20, v);
    if (st != 1 || v[15:0] != 16'd419 || v[27:20] != 8'd8) fail($sformatf("B: READ_LIMIT RCID 1 %h", v));
    limit(1, 1, 200, 3, st); if (st != 1) fail("B: lowering RCID 1 failed");
    limit(2, 1, 0, 0, st); rd64(12'h20, v);
    if (v[15:0] != 16'd200 || v[27:20] != 8'd3) fail($sformatf("B: READ_LIMIT after lowering %h", v));
    limit(3, 1, 0, 0, st);   if (st != 2) fail($sformatf("B: OP 3 gave STATUS %0d", st));
    limit(0, 1, 0, 0, st);   if (st != 2) fail($sformatf("B: OP 0 gave STATUS %0d", st));
    limit(2, 16, 0, 0, st);  if (st != 3) fail($sformatf("B: RCID 16 gave STATUS %0d", st));
    limit(2, 1, 0, 0, st, 1); rd64(12'h18, v);
    if (st != 1 || v[7:5] != 3'd0) fail($sformatf("B: AT is read-only zero (%h, STATUS %0d)", v, st));
    wr64(12'h20, 64'hFFFF_FFFF_FFFF_FFFF); rd64(12'h20, v);
    if (v[31:28] != 4'd0 || v[19:16] != 4'd0 || v[63:32] != 32'd0) fail($sformatf("B: bc_bw_alloc RO fields %h", v));
    mon(1, 16, 1, st);  if (st != 3) fail($sformatf("B: MCID 16 gave STATUS %0d", st));
    mon(1, 1, 4, st);   if (st != 4) fail($sformatf("B: EVT_ID 4 gave STATUS %0d", st));
    mon(5, 1, 1, st);   if (st != 2) fail($sformatf("B: mon OP 5 gave STATUS %0d", st));
    mon(2, 9, 0, st); rd64(12'h10, v);
    if (st != 1 || v[62] != 1'b1) fail($sformatf("B: unconfigured counter not INV (%h)", v));
    rd64(12'h80, v); if (v[0] != 1'b0) fail("B: regulation on at reset");
    $display("  B: registers checked");

    // configuration for C..F: period, capacity, regulation on
    wr32(32'h88, PERIOD);
    wr32(32'h90, CAP);
    set_limit(0, 1, 0); set_limit(1, 1, 1); set_limit(2, 1, 1); set_limit(3, 1, 1);

    // ---- C
    set_limit(1, 512, 0); set_limit(2, 205, 0); set_limit(3, 1, 16);
    wr32(32'h80, 3);                                      // regulation and pacing on
    traffic('{0, 1, 1, 1}, '{0, 0, 0, 0}, 0);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    expect_share("C", 1, sh[1], 0.47, 0.53);
    expect_share("C", 2, sh[2], 0.18, 0.22);
    expect_share("C", 3, sh[3], 0.25, 0.35);
    stop_and_drain();

    // ---- D
    set_limit(1, 1, 32); set_limit(2, 1, 64); set_limit(3, 1, 128);
    traffic('{0, 1, 1, 1}, '{0, 0, 0, 0}, 0);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    expect_share("D", 1, sh[1], 1.0/7 - 0.03, 1.0/7 + 0.03);
    expect_share("D", 2, sh[2], 2.0/7 - 0.03, 2.0/7 + 0.03);
    expect_share("D", 3, sh[3], 4.0/7 - 0.03, 4.0/7 + 0.03);
    stop_and_drain();

    // ---- E
    set_limit(1, 410, 1); set_limit(2, 1, 255); set_limit(3, 1, 255);
    traffic('{0, 1, 1, 1}, '{0, 0, 0, 0}, 0);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    expect_share("E", 1, sh[1], 0.39, 0.46);
    expect_share("E", 2, sh[2], 0.25, 0.32);
    expect_share("E", 3, sh[3], 0.25, 0.32);
    stop_and_drain();

    // ---- F
    set_limit(1, 1, 0); set_limit(2, 409, 0); set_limit(3, 1, 0);
    traffic('{0, 1, 1, 0}, '{0, 100, 100, 0}, 0);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    begin
      longint unsigned b2 = rel_bytes[2];
      real frac = real'(b2) / real'(10 * CAP);       // RCID 2's bytes against what the memory can move
      $display("  F RCID 2: %5.1f %% of the memory's bandwidth (reservation 40 %%), RCID 1 got %5.1f %% of the traffic",
               100.0 * frac, 100.0 * sh[1]);
      if (frac < 0.36) fail($sformatf("F: RCID 2 got %.3f of the bandwidth behind RCID 1's writes", frac));
    end
    stop_and_drain();

    // ---- G
    for (int m = 0; m < 16; m++) begin mon_rd[m] = 0; mon_wr[m] = 0; end
    mon(1, 1, 1, st); mon(1, 2, 2, st); mon(1, 3, 3, st);
    for (int m = 0; m < 16; m++) begin mon_rd[m] = 0; mon_wr[m] = 0; end
    set_limit(1, 300, 4); set_limit(2, 300, 4); set_limit(3, 100, 4);
    traffic('{0, 1, 1, 1}, '{0, 40, 40, 40}, 0);
    repeat (3 * PERIOD) @(posedge clk);
    stop_and_drain();
    for (int m = 1; m <= 3; m++) begin
      longint unsigned exp_b;
      mon(2, m, 0, st); rd64(12'h10, v);
      exp_b = (m == 1) ? mon_rd[1] + mon_wr[1] : (m == 2) ? mon_rd[2] : mon_wr[3];
      $display("  G MCID %0d (EVT %0d): counter %0d, released %0d bytes", m, m, v[61:0], exp_b);
      if (st != 1 || v[62] || v[63] || v[61:0] != exp_b) fail($sformatf("G: MCID %0d counter %h, expected %0d", m, v, exp_b));
    end

    // ---- H
    gen_rand_ids = 1'b1;
    mlp = 6;                                          // 4 RCIDs x 6 > 16: the pool fills at times
    for (int k = 0; k < 6; k++) begin
      set_limit(1, 1, 0); set_limit(2, 1, 0); set_limit(3, 1, 0);
      set_limit(1, $urandom_range(1, 300), $urandom_range(0, 3) == 0 ? 0 : $urandom_range(1, 255));
      set_limit(2, $urandom_range(1, 300), $urandom_range(0, 3) == 0 ? 0 : $urandom_range(1, 255));
      set_limit(3, $urandom_range(1, 200), $urandom_range(0, 3) == 0 ? 0 : $urandom_range(1, 255));
      wr32(32'h88, $urandom_range(200, 3000));
      wr32(32'h80, ($urandom_range(0, 3) != 0) | ($urandom_range(0, 1) << 1));
      traffic('{$urandom_range(0, 2), $urandom_range(0, 3), $urandom_range(0, 3), $urandom_range(1, 3)},
              '{$urandom_range(0, 100), $urandom_range(0, 100), $urandom_range(0, 100), $urandom_range(0, 100)},
              $urandom_range(0, 3));
      repeat (4000) @(posedge clk);
    end
    wr32(32'h88, 2000);
    stop_and_drain(200000);
    rd64(12'h98, v);
    $display("  H: %0d descriptors in all, pool high-water mark %0d", inserted.size(), v[15:8]);

    // ---- I
    gen_rand_ids = 1'b0;
    mlp = 1;
    dq  = 8;
    wr32(32'h88, PERIOD); wr32(32'h90, CAP * 9 / 10);    // hand out 90 % of what the memory moves
    repeat (60) @(posedge clk);
    rd32(32'hA8, v[31:0]);
    begin
      longint unsigned want = (longint'(CAP * 9 / 10) << 16) / PERIOD;
      $display("  I: BC_RATE %0d (16.16 bytes per cycle), expected %0d", v[31:0], want);
      if (v[31:0] != want) fail($sformatf("I: BC_RATE %0d, expected %0d", v[31:0], want));
    end
    set_limit(1, 1, 1); set_limit(2, 1, 1); set_limit(3, 1, 1);
    set_limit(1, 1, 32); set_limit(2, 1, 64); set_limit(3, 1, 128);
    wr32(32'h80, 1);                                      // regulation on, pacing off
    traffic('{0, 1, 1, 1}, '{0, 0, 0, 0}, 0);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    $display("  I without pacing: RCID 1/2/3 %5.1f / %5.1f / %5.1f %% (the memory's queue decides)",
             100.0 * sh[1], 100.0 * sh[2], 100.0 * sh[3]);
    wr32(32'h80, 3);                                      // pacing on
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    expect_share("I", 1, sh[1], 1.0/7 - 0.04, 1.0/7 + 0.04);
    expect_share("I", 2, sh[2], 2.0/7 - 0.04, 2.0/7 + 0.04);
    expect_share("I", 3, sh[3], 4.0/7 - 0.04, 4.0/7 + 0.04);
    stop_and_drain();

    // ---- J
    mlp = 4;
    dq  = 0;
    wr32(32'h88, PERIOD); wr32(32'h90, CAP);
    set_limit(1, 1, 1); set_limit(2, 1, 1); set_limit(3, 1, 1);
    set_limit(1, 410, 0); set_limit(2, 1, 64);
    gen_evict_pct[1] = 100; gen_evict_pct[2] = 0;
    wr32(32'h80, 3);
    traffic('{0, 1, 1, 0}, '{0, 0, 0, 0}, 0);
    repeat (60) @(posedge clk);
    repeat (2 * PERIOD) @(posedge clk);
    shares(10 * PERIOD, sh);
    begin
      real frac = real'(rel_bytes[1]) / real'(10 * CAP);
      $display("  J RCID 1 (two-line descriptors, Rbwb 40 %%): %5.1f %% of the bandwidth", 100.0 * frac);
      if (frac < 0.37) fail($sformatf("J: RCID 1 got %.3f of the bandwidth with two-line descriptors", frac));
    end
    stop_and_drain();
    gen_evict_pct[1] = -1; gen_evict_pct[2] = -1;

    // ---- K: writes next to a hard-limited writer (RCID 1: Rbwb 1, Mweight 0), the other writer (RCID 2) past its
    // reservation (Rbwb 1, Mweight 64): unbuffered, all writes in order and RCID 2 waits behind RCID 1's parked
    // writes; buffered (the LLC's write-data buffer), only per ID: RCID 2 takes what RCID 1 cannot
    set_limit(1, 1, 1); set_limit(2, 1, 1); set_limit(3, 1, 1);
    set_limit(1, 1, 0); set_limit(2, 1, 64);
    for (int b = 0; b < 2; b++) begin
      gen_wbuf_pct = b ? 100 : 0;
      traffic('{0, 1, 1, 0}, '{0, 100, 100, 0}, 0);
      repeat (2 * PERIOD) @(posedge clk);
      shares(10 * PERIOD, sh);
      begin
        real f2 = real'(rel_bytes[2]) / real'(10 * CAP), f1 = real'(rel_bytes[1]) / real'(10 * CAP);
        $display("  K %s writes: RCID 2 (best effort) %5.1f %% of the bandwidth, RCID 1 (hard limit) %5.1f %%",
                 b ? "buffered  " : "unbuffered", 100.0 * f2, 100.0 * f1);
        if (b && f2 < 0.80) fail($sformatf("K: buffered RCID 2 got %.3f next to a hard-limited writer", f2));
        // the hard limit: about one release per period (up to two lines each), no inheritance between buffered writes
        if (b && rel_bytes[1] > 10 * 2 * 64 + 256)
          fail($sformatf("K: hard-limited RCID 1 moved %0d bytes in 10 periods", rel_bytes[1]));
      end
      stop_and_drain();
    end

    // ---- L: random mix of buffered and unbuffered writes, reads and flushes, any ID for any RCID: the ordering
    // rules (checked on every release) and a full drain
    gen_rand_ids = 1'b1;
    gen_wbuf_pct = 50;
    set_limit(1, 100, 8); set_limit(2, 1, 0); set_limit(3, 50, 32);
    traffic('{0, 1, 1, 1}, '{0, 60, 60, 60}, 3);
    repeat (6 * PERIOD) @(posedge clk);
    stop_and_drain(20 * PERIOD);
    $display("  L: %0d descriptors (half the writes buffered) left in a legal order", inserted.size());
    gen_rand_ids = 1'b0;
    gen_wbuf_pct = 0;

    if (fails == 0) $display("LLC BC UNIT PASS");
    else            $display("LLC BC UNIT FAIL: %0d failures", fails);
    $finish;
  end
endmodule
