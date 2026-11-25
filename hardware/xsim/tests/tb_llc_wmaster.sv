// The LLC's write unit on its own (ip_list/axi_llc/src/eviction_refill/axi_llc_w_master.sv, PendDepth): its contract,
// checked every cycle against a model, under a load much denser than the whole LLC can make.
//
// Descriptors as the hit/miss unit makes them, over NLINE lines of two sets with four ways each: a miss refills a
// line that is not in the set and pushes out one that is (written back when it is dirty), so a line is written back
// and asked for again within a few descriptors; some descriptors only pass (hits in miss order), some are flushes.
// LEGAL = 0 drops the rules of a real cache (a line written back again before its response, refills of lines that
// are in the set) and adds write responses nobody waits for (as after a reset): the unit must stay safe; its own
// simulation assertions then fire and are not counted.
// The memory side answers a write-back BMIN..BMAX cycles after its last W beat, responses of different IDs in any
// order (BREORDER). Every handshake has random back-pressure.
// Checked:
//   order      descriptors leave (to the refill unit, or destroyed as a flush) in the order they came, each once
//   data       eight W beats per write-back, the line's blocks in order, last on the eighth
//   refill     a descriptor that refills line X does not leave while a write-back of X is unanswered, or not sent
//   flush      a flush is reported only when no write-back is unanswered
//   bound      at most PEND (one with PEND = 0) complete write-backs unanswered
//   progress   something leaves within a deadline
`include "axi/typedef.svh"

module tb_llc_wmaster #(
  parameter int unsigned PEND     = 4,
  parameter int unsigned NDESC    = 30000,
  parameter int unsigned NLINE    = 6,      // lines per set (more than the 4 ways)
  parameter int unsigned NID      = 3,
  parameter int unsigned BMIN     = 0,
  parameter int unsigned BMAX     = 60,
  parameter bit          BREORDER = 1'b1,
  parameter bit          LEGAL    = 1'b1,
  parameter int unsigned PRDY     = 3       // back-pressure: a ready is low one cycle in PRDY + 1 (0: never)
);
  localparam time CYC = 10ns, TA = 2ns, TT = 8ns;
  localparam axi_llc_pkg::llc_axi_cfg_t AxiCfg = '{SlvPortIdWidth: 4, AddrWidthFull: 32, DataWidthFull: 64,
                                                   LitePortAddrWidth: 32, LitePortDataWidth: 32};
  localparam axi_llc_pkg::llc_cfg_t Cfg = '{SetAssociativity: 4, NumLines: 32, NumBlocks: 8, BlockSize: 64,
                                            TagLength: 21, IndexLength: 5, BlockOffsetLength: 3, ByteOffsetLength: 3,
                                            SPMLength: 4 * 32 * 8 * 8};
  typedef logic [3:0]  id_t;
  typedef logic [31:0] addr_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0]  strb_t;
  typedef logic [0:0]  user_t;
  typedef logic [25:0] line_t;                     // {tag, index}
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  typedef struct packed {
    logic [31:0] seq;                              // the testbench's own field
    id_t         a_x_id;
    addr_t       a_x_addr;
    logic [3:0]  way_ind;
    logic        evict;
    logic [20:0] evict_tag;
    logic        refill;
    logic        flush;
  } desc_t;
  typedef struct packed {
    axi_llc_pkg::cache_unit_e cache_unit;
    logic [3:0]               way_ind;
    logic [4:0]               line_addr;
    logic [2:0]               blk_offset;
    logic                     we;
    data_t                    data;
    strb_t                    strb;
  } way_inp_t;
  typedef struct packed {
    axi_llc_pkg::cache_unit_e cache_unit;
    data_t                    data;
  } way_oup_t;

  logic clk = 1'b0, rst_n = 1'b0;
  always #(CYC / 2) clk = ~clk;
  // (a synthesised netlist holds its flip-flops in the global set/reset for the first 100 ns)
  initial begin repeat (20) @(posedge clk); #TA rst_n = 1'b1; end

  desc_t    desc_i, desc_o;
  logic     desc_valid_i, desc_ready_o, desc_valid_o, desc_ready_i;
  w_chan_t  w;        logic w_valid, w_ready;
  b_chan_t  b;        logic b_valid, b_ready;
  way_inp_t way_inp;  logic way_inp_valid, way_inp_ready;
  way_oup_t way_out;  logic way_out_valid, way_out_ready;
  logic     flush_recv;

`ifdef WM_NETLIST
  // the unit as Vivado synthesised it (wm_synth_wrap, run_llc_wmaster_netlist.sh): same ports, as vectors
  wm_synth_wrap i_dut (
    .clk_i ( clk ), .rst_ni ( rst_n ),
    .desc_i, .desc_valid_i, .desc_ready_o, .desc_o, .desc_valid_o, .desc_ready_i,
    .w_o ( w ), .w_valid_o ( w_valid ), .w_ready_i ( w_ready ),
    .b_i ( b ), .b_valid_i ( b_valid ), .b_ready_o ( b_ready ),
    .way_inp_o ( way_inp ), .way_inp_valid_o ( way_inp_valid ), .way_inp_ready_i ( way_inp_ready ),
    .way_out_i ( way_out ), .way_out_valid_i ( way_out_valid ), .way_out_ready_o ( way_out_ready ),
    .flush_desc_recv_o ( flush_recv )
  );
`else
  axi_llc_w_master #(
    .Cfg ( Cfg ), .AxiCfg ( AxiCfg ), .desc_t ( desc_t ), .way_inp_t ( way_inp_t ), .way_oup_t ( way_oup_t ),
    .w_chan_t ( w_chan_t ), .b_chan_t ( b_chan_t ), .PendDepth ( PEND )
  ) i_dut (
    .clk_i ( clk ), .rst_ni ( rst_n ), .test_i ( 1'b0 ),
    .desc_i, .desc_valid_i, .desc_ready_o, .desc_o, .desc_valid_o, .desc_ready_i,
    .w_chan_mst_o ( w ), .w_chan_valid_o ( w_valid ), .w_chan_ready_i ( w_ready ),
    .b_chan_mst_i ( b ), .b_chan_valid_i ( b_valid ), .b_chan_ready_o ( b_ready ),
    .way_inp_o ( way_inp ), .way_inp_valid_o ( way_inp_valid ), .way_inp_ready_i ( way_inp_ready ),
    .way_out_i ( way_out ), .way_out_valid_i ( way_out_valid ), .way_out_ready_o ( way_out_ready ),
    .flush_desc_recv_o ( flush_recv )
  );

`endif

  int unsigned fails = 0;
  function automatic void fail(string s);
    fails++;
    if (fails <= 20) $display("[%0t] FAIL %s", $time, s);
  endfunction
  function automatic bit rdy();                    // a ready, with back-pressure
    return (PRDY == 0) || ($urandom_range(0, PRDY) != 0);
  endfunction
  function automatic line_t evict_line(desc_t d);  return {d.evict_tag, d.a_x_addr[10:6]}; endfunction
  function automatic line_t refill_line(desc_t d); return d.a_x_addr[31:6]; endfunction
  function automatic data_t blk_data(logic [4:0] idx, logic [3:0] way, logic [2:0] blk);
    return {32'hA5C3_0000 | 32'(idx) << 8 | 32'(way) << 4 | 32'(blk), ~(32'(idx) << 16 | 32'(way) << 8 | 32'(blk))};
  endfunction

  // ---------------------------------------------------------------- the descriptors (generation-time view of the sets)
  bit          in_set [2][16];                     // line (tag number) is in the set
  bit          dirty  [2][16];
  int unsigned way_of [2][16];
  int unsigned gen_seq = 0;
  function automatic desc_t gen();
    desc_t d;
    int unsigned idx, r, e, k, n;
    d = '0;
    d.seq    = gen_seq++;
    d.a_x_id = id_t'($urandom_range(0, NID - 1));
    idx      = $urandom_range(0, 1);
    k        = $urandom_range(0, 19);
    if (!LEGAL) begin                              // anything
      r = $urandom_range(0, NLINE - 1);
      do e = $urandom_range(0, NLINE - 1); while (e == r);
      d.a_x_addr = {21'(r + 1), 5'(idx), 6'h0};
      d.way_ind  = 4'b1 << $urandom_range(0, 3);
      if (k == 0) begin d.flush = 1'b1; d.evict = $urandom_range(0, 1); d.evict_tag = 21'(e + 1); end
      else if (k >= 3) begin d.refill = 1'b1; d.evict = $urandom_range(0, 3) != 0; d.evict_tag = 21'(e + 1); end
      return d;
    end
    // a line in the set (to push out or to flush) and one outside (to bring in)
    n = 0; e = 0; r = 0;
    for (int unsigned i = 0; i < NLINE; i++) if (in_set[idx][i]  && $urandom_range(0, n++) == 0) e = i;
    n = 0;
    for (int unsigned i = 0; i < NLINE; i++) if (!in_set[idx][i] && $urandom_range(0, n++) == 0) r = i;
    if (k == 0) begin                              // flush of line e
      d.flush = 1'b1; d.evict = dirty[idx][e]; d.evict_tag = 21'(e + 1);
      d.a_x_addr = {21'h0, 5'(idx), 6'h0}; d.way_ind = 4'b1 << way_of[idx][e];
      // a flushed way is filled again by the next miss; the model keeps it simple: the line comes straight back clean
      dirty[idx][e] = 1'b0;
      if (dirty[idx][e] == 1'b0 && d.evict) ;      // (written back; stays in the set, clean)
    end else if (k <= 2) begin                     // a hit that keeps its place in the miss order
      d.a_x_addr = {21'(e + 1), 5'(idx), 6'h0}; d.way_ind = 4'b1 << way_of[idx][e];
      if ($urandom_range(0, 1)) dirty[idx][e] = 1'b1;
    end else begin                                 // a miss: r comes in, e goes out
      d.refill = 1'b1; d.evict = dirty[idx][e]; d.evict_tag = 21'(e + 1);
      d.a_x_addr = {21'(r + 1), 5'(idx), 6'h0}; d.way_ind = 4'b1 << way_of[idx][e];
      in_set[idx][e] = 1'b0; in_set[idx][r] = 1'b1; way_of[idx][r] = way_of[idx][e];
      dirty[idx][r] = $urandom_range(0, 3) != 0;   // mostly written before it is pushed out again
    end
    return d;
  endfunction

  // ---------------------------------------------------------------- the model
  typedef struct { int unsigned seq; line_t line; id_t id; int unsigned delay; } unans_t;
  desc_t   all_q[$];                               // accepted, not yet gone (in order)
  desc_t   wr_q[$];                                // accepted write-backs whose W beats are not all sent
  unans_t  un_q[$];                                // write-backs with every W beat sent and no response yet
  int unsigned n_done = 0, n_wb = 0, n_out = 0, n_flush = 0, max_un = 0, n_stray = 0, n_ooo = 0, idle = 0;

  initial begin                                    // descriptor source
    logic hs = 1'b0;
    desc_valid_i = 1'b0; desc_i = '0;
    for (int s = 0; s < 2; s++) for (int i = 0; i < 16; i++) begin
      in_set[s][i] = i < 4; dirty[s][i] = i < 4; way_of[s][i] = i % 4;
    end
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs) begin desc_valid_i = 1'b0; hs = 1'b0; end
      if (!desc_valid_i && gen_seq < NDESC && $urandom_range(0, 3) != 0) begin desc_i = gen(); desc_valid_i = 1'b1; end
      #(TT - TA);
      hs = desc_valid_i && desc_ready_o;
      if (hs) begin
        all_q.push_back(desc_i);
        if (desc_i.evict) wr_q.push_back(desc_i);
      end
    end
  end
  initial begin                                    // the ways: a block per request, after a few cycles
    way_inp_t rq[$];
    int unsigned dl[$];
    logic hs_in = 1'b0, hs_out = 1'b0;
    way_inp_ready = 1'b0; way_out_valid = 1'b0; way_out = '0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs_out) begin way_out_valid = 1'b0; void'(rq.pop_front()); void'(dl.pop_front()); hs_out = 1'b0; end
      foreach (dl[i]) if (dl[i] != 0) dl[i]--;
      way_inp_ready = rdy();
      if (!way_out_valid && rq.size() != 0 && dl[0] == 0) begin
        way_out = '{cache_unit: axi_llc_pkg::EvictUnit, data: blk_data(rq[0].line_addr, rq[0].way_ind, rq[0].blk_offset)};
        way_out_valid = 1'b1;
      end
      #(TT - TA);
      if (way_inp_valid && way_inp_ready) begin
        rq.push_back(way_inp); dl.push_back($urandom_range(1, 3));
        if (way_inp.we) fail("the unit writes to the ways");
      end
      hs_out = way_out_valid && way_out_ready;
    end
  end
  initial begin                                    // W sink and its checks
    int unsigned beat = 0;
    w_ready = 1'b0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      w_ready = rdy();
      #(TT - TA);
      if (w_valid && w_ready) begin
        if (wr_q.size() == 0) fail("a W beat with no write-back accepted");
        else begin
          desc_t d = wr_q[0];
          if (w.data !== blk_data(d.a_x_addr[10:6], d.way_ind, 3'(beat)))
            fail($sformatf("descriptor %0d: W beat %0d is %h", d.seq, beat, w.data));
          if (w.last !== (beat == 7)) fail($sformatf("descriptor %0d: W last %b on beat %0d", d.seq, w.last, beat));
          if (w.strb !== '1) fail("W strobe not full");
          if (beat == 7) begin
            unans_t u;
            u.seq = d.seq; u.line = evict_line(d); u.id = d.a_x_id; u.delay = $urandom_range(BMIN, BMAX);
            un_q.push_back(u);
            void'(wr_q.pop_front());
            n_wb++;
            if (un_q.size() > max_un) max_un = un_q.size();
            if (un_q.size() > (PEND == 0 ? 1 : PEND)) fail($sformatf("%0d complete write-backs unanswered, PEND %0d", un_q.size(), PEND));
            beat = 0;
          end else beat++;
        end
      end
    end
  end
  initial begin                                    // B source
    logic hs = 1'b0, stray = 1'b0;
    int   sel = 0, cand[$];
    b_valid = 1'b0; b = '0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (hs) begin
        b_valid = 1'b0; hs = 1'b0;
        if (!stray) un_q.delete(sel);
        stray = 1'b0;
      end
      foreach (un_q[i]) if (un_q[i].delay != 0) un_q[i].delay--;
      if (!b_valid && un_q.size() != 0 && rdy()) begin
        cand.delete();
        foreach (un_q[i]) if (un_q[i].delay == 0) begin
          bit older = 1'b0;
          for (int j = 0; j < i; j++) if (un_q[j].id == un_q[i].id) older = 1'b1;
          if (!older && (BREORDER || i == 0)) cand.push_back(i);
        end
        if (cand.size() != 0) begin
          sel = cand[$urandom_range(0, cand.size() - 1)];
          if (sel != 0) n_ooo++;
          b = '{id: un_q[sel].id, resp: axi_pkg::RESP_OKAY, default: '0};
          b_valid = 1'b1;
        end
      end
      // a response nobody waits for: an ID with no write-back outstanding (only the unit with the table ignores it)
      if (!LEGAL && PEND > 0 && !b_valid && $urandom_range(0, 40) == 0) begin
        id_t sid = id_t'($urandom_range(0, 15));
        bit used = 1'b0;
        foreach (un_q[i]) if (un_q[i].id == sid) used = 1'b1;
        // (also none whose W beats are on their way: its response may not come before them)
        if (!used) begin b = '{id: sid, resp: axi_pkg::RESP_OKAY, default: '0}; b_valid = 1'b1; stray = 1'b1; n_stray++; end
      end
      #(TT - TA);
      hs = b_valid && b_ready;
    end
  end
  initial begin                                    // the outputs and their checks
    desc_ready_i = 1'b0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      desc_ready_i = rdy();
      #(TT - TA);
      idle++;
      if ((desc_valid_o && desc_ready_i) || flush_recv) begin
        idle = 0;
        if (desc_valid_o && desc_ready_i && flush_recv) fail("a descriptor and a flush leave in the same cycle");
        if (all_q.size() == 0) fail("something leaves and nothing was accepted");
        else begin
          desc_t d = all_q[0];
          if (flush_recv) begin
            if (!d.flush) fail($sformatf("a flush is reported, the oldest descriptor (%0d) is none", d.seq));
            if (un_q.size() != 0) fail($sformatf("flush %0d reported with %0d write-backs unanswered", d.seq, un_q.size()));
            n_flush++;
          end else begin
            if (desc_o !== d) fail($sformatf("descriptor %0d leaves, %0d is the oldest", desc_o.seq, d.seq));
            if (d.flush) fail($sformatf("flush descriptor %0d passed on", d.seq));
            if (d.refill)
              foreach (un_q[i]) if (un_q[i].line == refill_line(d))
                fail($sformatf("descriptor %0d refills line %h while its write-back (descriptor %0d) is unanswered",
                               d.seq, refill_line(d), un_q[i].seq));
            n_out++;
          end
          // every older write-back has sent its W beats
          if (wr_q.size() != 0 && wr_q[0].seq <= d.seq) fail($sformatf("descriptor %0d leaves before write-back %0d is sent", d.seq, wr_q[0].seq));
          void'(all_q.pop_front());
          n_done++;
        end
      end
      if (idle > 20000 && n_done < NDESC) begin fail("nothing left the unit for 20000 cycles"); idle = 0; n_done = NDESC; end
    end
  end

  initial begin
    wait (rst_n);
    wait (n_done >= NDESC);
    repeat (BMAX + 50) @(posedge clk);
    $display("  %0d descriptors: %0d passed on, %0d flushes, %0d write-backs, at most %0d unanswered at a time, %0d responses out of order, %0d responses nobody waited for",
             n_done, n_out, n_flush, n_wb, max_un, n_ooo, n_stray);
`ifndef WM_NETLIST
    $display("  the unit's counters: %0d refills waited for the write-back of their own line (%0d cycles); %0d cycles behind a write-back waiting for its response, %0d for a free entry",
             i_dut.wb_line_wait_n, i_dut.wb_line_wait, i_dut.wb_behind, i_dut.wb_full_wait);
    if (PEND > 0 && LEGAL && BMAX >= 20 && i_dut.wb_line_wait_n == 0) fail("no refill ever waited for the write-back of its own line");
`endif
    if (fails == 0) $display("LLC WMASTER PASS (PEND=%0d LEGAL=%0d)", PEND, LEGAL);
    else            $display("LLC WMASTER FAIL: %0d failures (PEND=%0d LEGAL=%0d)", fails, PEND, LEGAL);
    $finish;
  end
endmodule
