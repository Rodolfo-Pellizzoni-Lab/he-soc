// Unit test of accel/accel_socket.sv's memory side. A stand-in for accel/accel_slots.sv lets up to 8 slots issue DMA
// requests back to back (as many in flight as the socket allows, 4), and an AXI slave stands in for the socket's
// port of the CCU. AXI orders the responses of one ID within a channel only, and the CCU does answer out of request
// order (a later read before an earlier write, e.g. while that write waits for a core's refill of the same line, and
// the reverse), while a refused response stays on the CCU's response path that all its ports share: the slave here
// can make a write (or a read) take longer, and hold a B until it has handed over every R it has (R_FIRST), or an R
// until every B (B_FIRST), the worst case of that.
// Checks: each request reaches the AXI side once, in grant order, with its address, data and strobes, and an AR
// with its slot's tag; AW, W and AR stay valid and unchanged until accepted (user fields aside, see below); each
// response reaches its slot in that slot's order, with its data and error; the socket takes every R and B in the
// cycle it is offered; nothing hangs (no response for 2000 cycles with requests open); after each phase nothing is
// left open, in the socket or in the models.
// Reported only (failures with +TAGS): AW and W user fields that are not their own request's tag, and AW, W or AR
// user fields that change while the request waits.
// usage: tests/run_accel_socket.sh [xsim options], XSIM_WORK = a built work dir (its core count sets the user layout)
`timescale 1ns/1ps

package tb_accel_socket_pkg;
  // a slot's memory request
  typedef struct {
    int unsigned s;
    logic        we;
    logic [63:0] addr, data;
    logic [7:0]  strb;
    logic [15:0] user;
  } rq_t;
  // the slave's answers depend on the address alone, so the slots can check them
  function automatic logic [63:0] rdata(logic [63:0] a);
    return {a[31:0] ^ 32'h5a5a_a5a5, ~a[31:0]};
  endfunction
  function automatic logic is_err(logic [63:0] a);
    return a[15:12] == 4'hf;
  endfunction
endpackage

// Stand-in for accel/accel_slots.sv (same ports, no registers): slot s issues the requests queued with add(), each
// held until granted (the port contract), the next one in the cycle after the grant or up to gap_max cycles later,
// and checks its responses in issue order.
module accel_slots
  import tb_accel_socket_pkg::*;
#(
  parameter int unsigned NumSlots = 8
) (
  input  logic                                       clk_i,
  input  logic                                       rst_ni,
  input  logic                                       reg_req_i,
  input  logic [(NumSlots > 1 ? $clog2(NumSlots) : 1)-1:0] reg_slot_i,
  input  logic [15:0]                                reg_addr_i,
  input  logic                                       reg_we_i,
  input  logic [31:0]                                reg_wdata_i,
  input  logic [3:0]                                 reg_wstrb_i,
  input  logic [15:0]                                reg_user_i,
  output logic                                       reg_ack_o,
  output logic                                       reg_err_o,
  output logic [31:0]                                reg_rdata_o,
  output logic [NumSlots-1:0]                        mem_req_o,
  input  logic [NumSlots-1:0]                        mem_gnt_i,
  output logic [NumSlots-1:0]                        mem_we_o,
  output logic [NumSlots-1:0][63:0]                  mem_addr_o,
  output logic [NumSlots-1:0][63:0]                  mem_wdata_o,
  output logic [NumSlots-1:0][7:0]                   mem_strb_o,
  output logic [NumSlots-1:0][15:0]                  mem_user_o,
  input  logic [NumSlots-1:0]                        mem_rvalid_i,
  input  logic [63:0]                                mem_rdata_i,
  input  logic [NumSlots-1:0]                        mem_err_i,
  output logic [NumSlots-1:0]                        irq_o
);
  assign reg_ack_o   = 1'b0;
  assign reg_err_o   = 1'b0;
  assign reg_rdata_o = '0;
  assign irq_o       = '0;

  rq_t         todo [NumSlots][$];        // still to issue (the head is the one presented)
  rq_t         pend [NumSlots][$];        // granted, response outstanding
  rq_t         granted_r [$], granted_w [$]; // every grant in grant order: the tb checks the AXI side against them
  int unsigned gap [NumSlots];
  int unsigned gap_max = 0, n_rsp = 0, fails = 0;

  function automatic void add(rq_t r);
    todo[r.s].push_back(r);
  endfunction
  // requests not answered yet
  function automatic int unsigned open_reqs();
    int unsigned n = 0;
    for (int unsigned s = 0; s < NumSlots; s++) n += todo[s].size() + pend[s].size();
    return n;
  endfunction

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned s = 0; s < NumSlots; s++) begin
        todo[s].delete();
        pend[s].delete();
        gap[s] = 0;
      end
      granted_r.delete();
      granted_w.delete();
      mem_req_o <= '0; mem_we_o <= '0; mem_addr_o <= '0; mem_wdata_o <= '0; mem_strb_o <= '0; mem_user_o <= '0;
    end else begin
      if ($countones(mem_rvalid_i) > 1) begin
        fails++;
        $display("FAIL %0t: responses for several slots in one cycle: %b", $time, mem_rvalid_i);
      end
      for (int unsigned s = 0; s < NumSlots; s++) begin
        rq_t r;
        if (mem_req_o[s] && mem_gnt_i[s]) begin
          r = todo[s].pop_front();
          pend[s].push_back(r);
          if (r.we) granted_w.push_back(r);
          else      granted_r.push_back(r);
          gap[s] = gap_max ? $urandom_range(gap_max) : 0;
        end
        if (mem_rvalid_i[s]) begin
          if (!pend[s].size()) begin
            fails++;
            $display("FAIL %0t: slot %0d got a response with no request outstanding", $time, s);
          end else begin
            r = pend[s].pop_front();
            n_rsp++;
            if (mem_err_i[s] !== is_err(r.addr) || (!r.we && !is_err(r.addr) && mem_rdata_i !== rdata(r.addr))) begin
              fails++;
              $display("FAIL %0t: slot %0d %s 0x%0h answered err %0d data 0x%016h, expected err %0d data 0x%016h",
                       $time, s, r.we ? "write" : "read", r.addr, mem_err_i[s], mem_rdata_i, is_err(r.addr),
                       rdata(r.addr));
            end
          end
        end
        // the next request; a waiting one stays as it is
        if (!(mem_req_o[s] && !mem_gnt_i[s])) begin
          if (gap[s] > 0 || !todo[s].size()) begin
            mem_req_o[s] <= 1'b0;
            if (gap[s] > 0) gap[s]--;
          end else begin
            mem_req_o[s]   <= 1'b1;
            mem_we_o[s]    <= todo[s][0].we;
            mem_addr_o[s]  <= todo[s][0].addr;
            mem_wdata_o[s] <= todo[s][0].data;
            mem_strb_o[s]  <= todo[s][0].strb;
            mem_user_o[s]  <= todo[s][0].user;
          end
        end
      end
    end
  end
endmodule

module tb_accel_socket;
  import tb_accel_socket_pkg::*;
  import ariane_axi_soc::*;
  localparam int unsigned NumSlots = 8;
  localparam logic [15:0] PortBits = 16'((1 << QosUserLsb) - 1);

  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;
  longint unsigned cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  req_slv_t  slv_req = '0, mst_req;
  resp_slv_t slv_resp, mst_resp;
  logic      irq;

  accel_socket #(.NumSlots (NumSlots)) dut (
    .clk_i (clk), .rst_ni (rst_n), .slv_req_i (slv_req), .slv_resp_o (slv_resp),
    .mst_req_o (mst_req), .mst_resp_i (mst_resp), .irq_o (irq)
  );

  int unsigned fails = 0, n_rd = 0, n_wr = 0, tag_bad = 0, tag_moved = 0;
  string       tag_first = "";
  function automatic void fail(string msg);
    fails++;
    if (fails <= 20) $display("FAIL %0t: %s", $time, msg);
  endfunction
  // the tag a granted request must carry: its slot's user field without the CCU's port bits
  function automatic user_t tag_of(rq_t g);
    return user_t'(g.user & ~PortBits);
  endfunction

  // ---------------------------------------------------------------- the CCU stand-in
  typedef enum int { FREE, R_FIRST, B_FIRST } order_e;
  typedef struct { axi_pkg::resp_t resp; logic [63:0] data; longint unsigned due; } rsp_t;
  order_e         order = FREE;
  bit             order_rand = 1'b0;     // switch the order at random
  // % of cycles AW, W and AR are ready; response delay: random up to dly_max, plus r_extra (an R) or b_extra (a B)
  int unsigned    rdy_pct = 100, dly_max = 0, r_extra = 0, b_extra = 0;
  aw_chan_slv_t   awq [$], chk_aw [$];   // awq/wq: accepted, not paired yet; chk_*: not compared with the grants yet
  w_chan_t        wq [$], chk_w [$];
  ar_chan_slv_t   chk_ar [$];
  rsp_t           rq [$], bq [$];        // responses not offered yet, in channel order
  logic           aw_rdy, w_rdy, ar_rdy, r_vld, b_vld;
  logic [63:0]    r_data;
  axi_pkg::resp_t r_resp, b_resp;

  function automatic rsp_t answer(logic [63:0] a, int unsigned extra);
    rsp_t x;
    x.resp = is_err(a) ? axi_pkg::RESP_SLVERR : axi_pkg::RESP_OKAY;
    x.data = rdata(a);
    x.due  = cyc + extra + (dly_max ? $urandom_range(dly_max) : 0);
    return x;
  endfunction
  function automatic logic rdy();
    return $urandom_range(99) < rdy_pct;
  endfunction

  resp_slv_t mst_resp_xc; // xsim: shadow of mst_resp
  always_comb begin
    mst_resp_xc          = '0;
    mst_resp_xc.aw_ready = aw_rdy;
    mst_resp_xc.w_ready  = w_rdy;
    mst_resp_xc.ar_ready = ar_rdy;
    mst_resp_xc.r_valid  = r_vld;
    mst_resp_xc.r.data   = r_data;
    mst_resp_xc.r.resp   = r_resp;
    mst_resp_xc.r.last   = 1'b1;
    mst_resp_xc.b_valid  = b_vld;
    mst_resp_xc.b.resp   = b_resp;
    mst_resp             = mst_resp_xc; // xsim: assigned once
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      awq.delete(); wq.delete(); chk_aw.delete(); chk_w.delete(); chk_ar.delete(); rq.delete(); bq.delete();
      aw_rdy <= 1'b0; w_rdy <= 1'b0; ar_rdy <= 1'b0; r_vld <= 1'b0; b_vld <= 1'b0;
      r_data <= '0; r_resp <= '0; b_resp <= '0;
    end else begin
      aw_chan_slv_t aw;
      rsp_t         x;
      logic         r_busy, b_busy;
      if (mst_req.aw_valid && aw_rdy) begin awq.push_back(mst_req.aw); chk_aw.push_back(mst_req.aw); end
      if (mst_req.w_valid  && w_rdy)  begin wq.push_back(mst_req.w);   chk_w.push_back(mst_req.w);   end
      if (mst_req.ar_valid && ar_rdy) begin chk_ar.push_back(mst_req.ar); rq.push_back(answer(mst_req.ar.addr, r_extra)); end
      while (awq.size() && wq.size()) begin
        aw = awq.pop_front();
        void'(wq.pop_front());
        bq.push_back(answer(aw.addr, b_extra));
      end
      // a response stays offered until taken; the next one once due, under R_FIRST a B only while no R waits, under
      // B_FIRST an R only while no B waits
      r_busy = r_vld && !mst_req.r_ready;
      b_busy = b_vld && !mst_req.b_ready;
      if (!r_busy) begin
        r_vld <= 1'b0;
        if (rq.size() && rq[0].due <= cyc && !(order == B_FIRST && (b_busy || bq.size()))) begin
          x = rq.pop_front();
          r_vld <= 1'b1; r_data <= x.data; r_resp <= x.resp;
          r_busy = 1'b1;
        end
      end
      if (!b_busy) begin
        b_vld <= 1'b0;
        if (bq.size() && bq[0].due <= cyc && !(order == R_FIRST && (r_busy || rq.size()))) begin
          x = bq.pop_front();
          b_vld <= 1'b1; b_resp <= x.resp;
        end
      end
      aw_rdy <= rdy();
      w_rdy  <= rdy();
      ar_rdy <= rdy();
      if (order_rand && $urandom_range(127) == 0) order <= order_e'($urandom_range(2));
    end
  end

  // ---------------------------------------------------------------- checks of the socket's AXI master side
  // AW, W and AR stay valid and unchanged until accepted (the user fields are counted apart, as tag_moved)
  function automatic aw_chan_slv_t aw_nouser(aw_chan_slv_t x); x.user = '0; return x; endfunction
  function automatic w_chan_t      w_nouser(w_chan_t x);       x.user = '0; return x; endfunction
  function automatic ar_chan_slv_t ar_nouser(ar_chan_slv_t x); x.user = '0; return x; endfunction
  // cycles in which the slave offered an R or a B that the socket did not take
  int unsigned  r_refused = 0, b_refused = 0;
  always @(posedge clk) if (rst_n) begin
    if (r_vld && mst_req.r_ready !== 1'b1) r_refused++;
    if (b_vld && mst_req.b_ready !== 1'b1) b_refused++;
  end
  logic         aw_wait = 1'b0, w_wait = 1'b0, ar_wait = 1'b0;
  aw_chan_slv_t aw_held;
  w_chan_t      w_held;
  ar_chan_slv_t ar_held;
  always @(posedge clk) begin
    if (rst_n) begin
      if (aw_wait && (!mst_req.aw_valid || aw_nouser(mst_req.aw) !== aw_nouser(aw_held)))
        fail("the socket withdrew or changed an AW before its handshake");
      if (w_wait && (!mst_req.w_valid || w_nouser(mst_req.w) !== w_nouser(w_held)))
        fail("the socket withdrew or changed a W before its handshake");
      if (ar_wait && (!mst_req.ar_valid || ar_nouser(mst_req.ar) !== ar_nouser(ar_held)))
        fail("the socket withdrew or changed an AR before its handshake");
      if ((aw_wait && mst_req.aw_valid && mst_req.aw.user !== aw_held.user) ||
          (w_wait && mst_req.w_valid && mst_req.w.user !== w_held.user) ||
          (ar_wait && mst_req.ar_valid && mst_req.ar.user !== ar_held.user)) tag_moved++;
    end
    aw_wait <= rst_n && mst_req.aw_valid && !aw_rdy;
    w_wait  <= rst_n && mst_req.w_valid && !w_rdy;
    ar_wait <= rst_n && mst_req.ar_valid && !ar_rdy;
    aw_held <= mst_req.aw;
    w_held  <= mst_req.w;
    ar_held <= mst_req.ar;
  end

  // every AR, AW and W against the grants, in order (at the negedge, when the slots have logged this cycle's grants)
  always @(negedge clk) begin
    if (rst_n) begin
      rq_t          g;
      ar_chan_slv_t ar;
      aw_chan_slv_t aw;
      w_chan_t      w;
      while (chk_ar.size() && dut.i_slots.granted_r.size()) begin
        ar = chk_ar.pop_front();
        g  = dut.i_slots.granted_r.pop_front();
        n_rd++;
        if (ar.addr !== g.addr || ar.len !== 8'd0 || ar.size !== 3'd3)
          fail($sformatf("AR 0x%0h len %0d size %0d, but the granted read (slot %0d) is 0x%0h", ar.addr, ar.len,
                         ar.size, g.s, g.addr));
        if (ar.user !== tag_of(g))
          fail($sformatf("AR 0x%0h of slot %0d carried user 0x%0h, its tag is 0x%0h", ar.addr, g.s, ar.user,
                         tag_of(g)));
      end
      while (chk_aw.size() && chk_w.size() && dut.i_slots.granted_w.size()) begin
        aw = chk_aw.pop_front();
        w  = chk_w.pop_front();
        g  = dut.i_slots.granted_w.pop_front();
        n_wr++;
        if (aw.addr !== g.addr || aw.len !== 8'd0 || !w.last || w.data !== g.data || w.strb !== g.strb)
          fail($sformatf("AW 0x%0h len %0d / W 0x%016h strb %02h last %0d, but the granted write (slot %0d) is 0x%0h 0x%016h strb %02h",
                         aw.addr, aw.len, w.data, w.strb, w.last, g.s, g.addr, g.data, g.strb));
        if (aw.user !== tag_of(g) || w.user !== tag_of(g)) begin
          if (!tag_bad)
            tag_first = $sformatf("first: write %0d (slot %0d, 0x%0h) went out with AW user 0x%0h and W user 0x%0h, its tag is 0x%0h",
                                  n_wr, g.s, g.addr, aw.user, w.user, tag_of(g));
          tag_bad++;
        end
      end
    end
  end

  // ---------------------------------------------------------------- phases
  function automatic rq_t mk(int unsigned s, logic we, logic [63:0] addr);
    rq_t r;
    r.s    = s;
    r.we   = we;
    r.addr = addr;
    r.data = {$urandom, $urandom};
    r.strb = we ? 8'($urandom_range(255, 1)) : 8'hff;
    // each slot its own RCID (s + 1) and a random MCID, plus port bits the socket must clear
    r.user = 16'((((s + 1) | ($urandom_range(15) << 4)) << QosUserLsb) | $urandom_range(PortBits));
    return r;
  endfunction
  function automatic rq_t mk_rand(int unsigned s);
    return mk(s, $urandom_range(1), 64'h8000_0000 + 64'($urandom_range(16'hffff) & ~32'h7));
  endfunction

  int unsigned n_phases = 0, n_reqs = 0;
  // reset the socket and both models, queue the requests, run until all are answered or nothing moves for 2000
  // cycles; then nothing may be left on either side
  task automatic run(string name, rq_t reqs [$], order_e ord, bit ord_rand, int unsigned rdy, int unsigned dly,
                     int unsigned r_x, int unsigned b_x, int unsigned gap);
    int unsigned f0, idle, last, rr0, br0;
    longint unsigned c0;
    bit hung = 1'b0;
    @(negedge clk);
    rst_n = 1'b0;
    repeat (3) @(negedge clk);
    order = ord; order_rand = ord_rand; rdy_pct = rdy; dly_max = dly; r_extra = r_x; b_extra = b_x;
    dut.i_slots.gap_max = gap;
    rst_n = 1'b1;
    f0 = fails + dut.i_slots.fails;
    c0 = cyc;
    rr0 = r_refused;
    br0 = b_refused;
    foreach (reqs[i]) dut.i_slots.add(reqs[i]);
    idle = 0;
    last = dut.i_slots.n_rsp;
    while (dut.i_slots.open_reqs()) begin
      @(negedge clk);
      if (dut.i_slots.n_rsp != last) begin
        last = dut.i_slots.n_rsp;
        idle = 0;
      end else if (++idle == 2000) begin
        fail($sformatf("%s: DEADLOCK, nothing answered for 2000 cycles, %0d requests open (the socket: %0d in flight, r_ready %0d, b_ready %0d; the slave: offers an R %0d, a B %0d, has %0d R and %0d B queued)",
                       name, dut.i_slots.open_reqs(), dut.cnt_q, mst_req.r_ready, mst_req.b_ready, r_vld, b_vld,
                       rq.size(), bq.size()));
        hung = 1'b1;
        break;
      end
    end
    repeat (2) @(negedge clk);
    if (!hung && (chk_ar.size() || chk_aw.size() || chk_w.size() || dut.i_slots.granted_r.size() ||
                  dut.i_slots.granted_w.size() || rq.size() || bq.size() || r_vld || b_vld))
      fail($sformatf("%s: left over: %0d AR %0d AW %0d W not granted, %0d reads %0d writes granted but not issued, %0d R %0d B not answered",
                     name, chk_ar.size(), chk_aw.size(), chk_w.size(), dut.i_slots.granted_r.size(),
                     dut.i_slots.granted_w.size(), rq.size() + r_vld, bq.size() + b_vld));
    if (!hung && dut.cnt_q !== '0)
      fail($sformatf("%s: the socket still counts %0d requests open after all were answered", name, dut.cnt_q));
    if (r_refused != rr0 || b_refused != br0)
      fail($sformatf("%s: the socket refused an offered R for %0d cycles and a B for %0d cycles", name,
                     r_refused - rr0, b_refused - br0));
    n_phases++;
    n_reqs += reqs.size();
    $display("%s %s: %0d requests, %0d cycles", (fails + dut.i_slots.fails == f0) ? "ok  " : "FAIL", name,
             reqs.size(), cyc - c0);
  endtask

  initial begin
    rq_t q [$];
    // 1: the CCU's case: a write that takes 20 cycles (it waits for a core's refill), then three reads whose R come
    // first, and the B only once every R is taken
    q = {mk(0, 1, 64'h8000_0040), mk(0, 0, 64'h8000_0100), mk(0, 0, 64'h8000_0108), mk(0, 0, 64'h8000_0110)};
    run("1 W R R R, the W slow, R before B", q, R_FIRST, 0, 100, 0, 0, 20, 0);
    // 2: the mirror: a slow read, then three writes whose B come first
    q = {mk(0, 0, 64'h8000_0040), mk(0, 1, 64'h8000_0100), mk(0, 1, 64'h8000_0108), mk(0, 1, 64'h8000_0110)};
    run("2 R W W W, the R slow, B before R", q, B_FIRST, 0, 100, 0, 20, 0, 0);
    // 3, 4: two slots interleaved, both orders
    q = {mk(2, 1, 64'h8000_0200), mk(5, 0, 64'h8000_0300), mk(2, 0, 64'h8000_0208), mk(5, 1, 64'h8000_0308),
         mk(2, 1, 64'h8000_0210), mk(5, 0, 64'h8000_0310), mk(2, 0, 64'h8000_0218), mk(5, 1, 64'h8000_0318)};
    run("3 slots 2 and 5, W slow, R before B", q, R_FIRST, 0, 100, 0, 0, 20, 0);
    run("4 slots 2 and 5, R slow, B before R", q, B_FIRST, 0, 100, 0, 20, 0, 0);
    // 5..8: random requests from all slots (phase 7: slots 3 and 4 only), 1 in 16 answered SLVERR, random delays,
    // AW/W/AR always or randomly ready
    q = {};
    for (int i = 0; i < 64; i++) for (int unsigned s = 0; s < NumSlots; s++) q.push_back(mk_rand(s));
    run("5 random, always ready, W slow, R before B", q, R_FIRST, 0, 100, 4, 0, 10, 2);
    q = {};
    for (int i = 0; i < 64; i++) for (int unsigned s = 0; s < NumSlots; s++) q.push_back(mk_rand(s));
    run("6 random, ready 50%, R slow, B before R", q, B_FIRST, 0, 50, 16, 10, 0, 0);
    q = {};
    for (int i = 0; i < 200; i++) for (int unsigned s = 3; s < 5; s++) q.push_back(mk_rand(s));
    run("7 random, two slots, ready 70%, any order", q, FREE, 0, 70, 8, 0, 0, 0);
    q = {};
    for (int i = 0; i < 64; i++) for (int unsigned s = 0; s < NumSlots; s++) q.push_back(mk_rand(s));
    run("8 random, ready 30%, order switching, gaps", q, FREE, 1, 30, 30, 0, 0, 4);

    $display("checked %0d reads and %0d writes on the AXI side, %0d responses at the slots", n_rd, n_wr,
             dut.i_slots.n_rsp);
    $display("tags (known socket issue, reported only; +TAGS fails on it): %0d of %0d writes carried another request's AW/W user field, %0d cycles a waiting AW/W/AR changed it%s%s",
             tag_bad, n_wr, tag_moved, tag_first == "" ? "" : "; ", tag_first);
    if ($test$plusargs("TAGS")) fails += tag_bad + tag_moved;
    if (fails + dut.i_slots.fails == 0)
      $display("ACCEL SOCKET UNIT PASS: %0d phases, %0d requests", n_phases, n_reqs);
    else
      $display("ACCEL SOCKET UNIT FAIL: %0d failures", fails + dut.i_slots.fails);
    $finish;
  end
endmodule
