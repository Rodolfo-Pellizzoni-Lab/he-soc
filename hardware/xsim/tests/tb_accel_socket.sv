// Unit test of accel/accel_socket.sv's memory side and its tag policy. A stand-in for accel/accel_slots.sv lets up to
// 8 slots issue DMA requests back to back (as many in flight as the socket allows, 4), and an AXI slave stands in for
// the socket's port of the CCU. AXI orders the responses of one ID within a channel only, and the CCU does answer out
// of request order (a later read before an earlier write, e.g. while that write waits for a core's refill of the same
// line, and the reverse), while a refused response stays on the CCU's response path that all its ports share: the
// slave here can make a write (or a read) take longer, and hold a B until it has handed over every R it has
// (R_FIRST), or an R until every B (B_FIRST), the worst case of that.
// Checks: each request reaches the AXI side once, in grant order, with its address, data and strobes, and its AR, or
// its AW and its W, with its own tag (its slot's user field without the port bits, or the tag TAG_POLICY forces in
// the first cycle the socket offers the request); AW, W and AR stay valid and unchanged, user fields included, until
// accepted; each response reaches its slot in that slot's order, with its data and error; the socket takes every R
// and B in the cycle it is offered; nothing hangs (no response for 2000 cycles with requests open); after each phase
// nothing is left open, in the socket or in the models. Phases 9 to 11 write TAG_POLICY through the socket's register
// side: while a request waits for the slave (which holds its W, its AW or its AR), before the traffic of two slots
// (one of them forced), and while a request waits for its turn (behind another slot's held write, behind the 4
// requests the socket can have open), which then carries the new tag; LAST_USER must read back the tag the slot's
// last request carried.
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
    logic [15:0] tag;    // the tag its AR, or its AW and W, must carry
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

  int unsigned fails = 0, ph_msgs = 0, n_rd = 0, n_wr = 0;
  function automatic void fail(string msg);
    fails++;
    if (++ph_msgs <= 10) $display("FAIL %0t: %s", $time, msg);   // the first 10 of each phase
  endfunction
  // the tag a granted request must carry (mk: its slot's user field without the CCU's port bits)
  function automatic user_t tag_of(rq_t g);
    return user_t'(g.tag);
  endfunction
  // the tag a TAG_POLICY value stamps while its FORCE bit is set
  function automatic logic [15:0] forced(logic [31:0] pol);
    return 16'(pol[UserWidth-1:0]) & ~PortBits;
  endfunction

  // ---------------------------------------------------------------- the CCU stand-in
  typedef enum int { FREE, R_FIRST, B_FIRST } order_e;
  typedef struct { axi_pkg::resp_t resp; logic [63:0] data; longint unsigned due; } rsp_t;
  order_e         order = FREE;
  bit             order_rand = 1'b0;     // switch the order at random
  // % of cycles AW, W and AR are ready; response delay: random up to dly_max, plus r_extra (an R) or b_extra (a B)
  int unsigned    rdy_pct = 100, dly_max = 0, r_extra = 0, b_extra = 0;
  // while set, the slave is not ready for the AW, the W, the AR
  bit             hold_aw = 1'b0, hold_w = 1'b0, hold_ar = 1'b0;
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
      aw_rdy <= !hold_aw && rdy();
      w_rdy  <= !hold_w && rdy();
      ar_rdy <= !hold_ar && rdy();
      if (order_rand && $urandom_range(127) == 0) order <= order_e'($urandom_range(2));
    end
  end

  // ---------------------------------------------------------------- checks of the socket's AXI master side
  // cycles in which the slave offered an R or a B that the socket did not take
  int unsigned  r_refused = 0, b_refused = 0;
  always @(posedge clk) if (rst_n) begin
    if (r_vld && mst_req.r_ready !== 1'b1) r_refused++;
    if (b_vld && mst_req.b_ready !== 1'b1) b_refused++;
  end
  // AW, W and AR stay valid and unchanged, user fields included, until accepted
  logic         aw_wait = 1'b0, w_wait = 1'b0, ar_wait = 1'b0;
  aw_chan_slv_t aw_held;
  w_chan_t      w_held;
  ar_chan_slv_t ar_held;
  always @(posedge clk) begin
    if (rst_n) begin
      if (aw_wait && (!mst_req.aw_valid || mst_req.aw !== aw_held))
        fail($sformatf("the socket withdrew or changed an AW before its handshake (user 0x%0h, was 0x%0h)",
                       mst_req.aw.user, aw_held.user));
      if (w_wait && (!mst_req.w_valid || mst_req.w !== w_held))
        fail($sformatf("the socket withdrew or changed a W before its handshake (user 0x%0h, was 0x%0h)",
                       mst_req.w.user, w_held.user));
      if (ar_wait && (!mst_req.ar_valid || mst_req.ar !== ar_held))
        fail($sformatf("the socket withdrew or changed an AR before its handshake (user 0x%0h, was 0x%0h)",
                       mst_req.ar.user, ar_held.user));
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
        if (aw.user !== tag_of(g) || w.user !== tag_of(g))
          fail($sformatf("write %0d (slot %0d, 0x%0h) went out with AW user 0x%0h and W user 0x%0h, its tag is 0x%0h",
                         n_wr, g.s, g.addr, aw.user, w.user, tag_of(g)));
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
    r.tag  = r.user & ~PortBits;
    return r;
  endfunction
  function automatic rq_t mk_rand(int unsigned s);
    return mk(s, $urandom_range(1), 64'h8000_0000 + 64'($urandom_range(16'hffff) & ~32'h7));
  endfunction

  // ---------------------------------------------------------------- the socket's register side, as a core uses it
  localparam logic [63:0] PolBase = 64'h103F_0100;  // slot s: TAG_POLICY at PolBase + 8*s, LAST_USER 4 bytes up
  localparam logic [31:0] PolMask = 32'h8000_0000 | 32'((1 << UserWidth) - 1);
  // The socket takes one register transaction at a time: AW, then W, then B (or AR, then R). The tb drives valids and
  // readies at a negedge or 1 ns after a posedge; the socket's readies are combinational, so they are settled 1 ns
  // later. reg_wait waits (at most 5000 cycles, above the socket's 4096-cycle access timeout) for the handshake of the
  // AW (what 0), the W (1), the B (2), the AR (3) or the R (4), and returns 1 ns after the posedge it happened at, with
  // the response and read data it carried.
  task automatic reg_wait(logic [63:0] a, int unsigned what, output axi_pkg::resp_t resp, output logic [63:0] data);
    int unsigned n;
    bit          ok;
    n  = 0;
    ok = 1'b0;
    #1;
    while (!ok && n < 5000) begin
      if (what == 0)      ok = slv_resp.aw_ready;
      else if (what == 1) ok = slv_resp.w_ready;
      else if (what == 2) ok = slv_resp.b_valid;
      else if (what == 3) ok = slv_resp.ar_ready;
      else                ok = slv_resp.r_valid;
      if (!ok) begin
        @(negedge clk);
        #1;
        n++;
      end
    end
    resp = (what == 2) ? slv_resp.b.resp : slv_resp.r.resp;
    data = slv_resp.r.data;
    if (!ok) fail($sformatf("register access 0x%0h: no handshake on channel %0d in 5000 cycles", a, what));
    @(posedge clk);
    #1;
  endtask
  // a 32-bit write, AW and W raised together as a core does (the socket takes the W once it has the AW)
  task automatic reg_write(logic [63:0] a, logic [31:0] d);
    axi_pkg::resp_t resp;
    logic [63:0]    x;
    @(negedge clk);
    slv_req.aw       = '0;
    slv_req.aw.addr  = a;
    slv_req.aw.size  = 3'd2;
    slv_req.aw.burst = axi_pkg::BURST_INCR;
    slv_req.aw_valid = 1'b1;
    slv_req.w        = '0;
    slv_req.w.data   = a[2] ? {d, 32'h0} : {32'h0, d};
    slv_req.w.strb   = a[2] ? 8'hf0 : 8'h0f;
    slv_req.w.last   = 1'b1;
    slv_req.w_valid  = 1'b1;
    slv_req.b_ready  = 1'b1;
    reg_wait(a, 0, resp, x);
    slv_req.aw_valid = 1'b0;
    reg_wait(a, 1, resp, x);
    slv_req.w_valid  = 1'b0;
    reg_wait(a, 2, resp, x);
    slv_req.b_ready  = 1'b0;
    if (resp !== axi_pkg::RESP_OKAY) fail($sformatf("register write 0x%0h answered resp %0d", a, resp));
  endtask
  // a 64-bit read
  task automatic reg_read(logic [63:0] a, output logic [63:0] d);
    axi_pkg::resp_t resp;
    logic [63:0]    x;
    @(negedge clk);
    slv_req.ar       = '0;
    slv_req.ar.addr  = a;
    slv_req.ar.size  = 3'd3;
    slv_req.ar.burst = axi_pkg::BURST_INCR;
    slv_req.ar_valid = 1'b1;
    slv_req.r_ready  = 1'b1;
    reg_wait(a, 3, resp, x);
    slv_req.ar_valid = 1'b0;
    reg_wait(a, 4, resp, d);
    slv_req.r_ready  = 1'b0;
    if (resp !== axi_pkg::RESP_OKAY) fail($sformatf("register read 0x%0h answered resp %0d", a, resp));
  endtask
  // TAG_POLICY (+0) and LAST_USER (+4) of slot s
  task automatic check_policy(string name, int unsigned s, logic [31:0] pol, logic [15:0] last);
    logic [63:0] d;
    reg_read(PolBase + 8 * s, d);
    if (d[31:0] !== pol || d[47:32] !== last)
      fail($sformatf("%s: slot %0d reads TAG_POLICY 0x%0h LAST_USER 0x%0h, expected 0x%0h and 0x%0h", name, s,
                     d[31:0], d[47:32], pol, last));
  endtask
  // phase 9 tests something only if slot s's request still waits for its grant when TAG_POLICY has changed (it is
  // the slot's only request, so its mem_req is still up)
  task automatic still_waiting(string name, int unsigned s);
    if (dut.i_slots.mem_req_o[s] !== 1'b1)
      fail($sformatf("%s: the request was granted before TAG_POLICY changed", name));
  endtask

  int unsigned     n_phases = 0, n_reqs = 0;
  int unsigned     ph_f0, ph_rr0, ph_br0; // at the start of the phase: failures, refused R and B
  longint unsigned ph_c0;
  bit              ph_hung;
  // reset the socket and both models, and set the slave up
  task automatic begin_phase(order_e ord, bit ord_rand, int unsigned rdy, int unsigned dly, int unsigned r_x,
                             int unsigned b_x, int unsigned gap);
    @(negedge clk);
    rst_n = 1'b0;
    repeat (3) @(negedge clk);
    order = ord; order_rand = ord_rand; rdy_pct = rdy; dly_max = dly; r_extra = r_x; b_extra = b_x;
    hold_aw = 1'b0; hold_w = 1'b0; hold_ar = 1'b0;
    dut.i_slots.gap_max = gap;
    rst_n = 1'b1;
    ph_msgs = 0;
    ph_f0   = fails + dut.i_slots.fails;
    ph_c0   = cyc;
    ph_rr0  = r_refused;
    ph_br0  = b_refused;
    ph_hung = 1'b0;
  endtask
  // run until every queued request is answered, or nothing is answered for 2000 cycles (a deadlock, which ends the
  // phase)
  task automatic drain(string name);
    int unsigned idle, last;
    idle = 0;
    last = dut.i_slots.n_rsp;
    while (!ph_hung && dut.i_slots.open_reqs()) begin
      @(negedge clk);
      if (dut.i_slots.n_rsp != last) begin
        last = dut.i_slots.n_rsp;
        idle = 0;
      end else if (++idle == 2000) begin
        fail($sformatf("%s: DEADLOCK, nothing answered for 2000 cycles, %0d requests open (the socket: %0d in flight, r_ready %0d, b_ready %0d; the slave: offers an R %0d, a B %0d, has %0d R and %0d B queued)",
                       name, dut.i_slots.open_reqs(), dut.cnt_q, mst_req.r_ready, mst_req.b_ready, r_vld, b_vld,
                       rq.size(), bq.size()));
        ph_hung = 1'b1;
      end
    end
  endtask
  // wait (at most 1000 cycles) until the slave has taken the AW (what = 0), the W (1), or is offered the AR (2)
  task automatic wait_for(string name, int unsigned what);
    int unsigned n;
    bit          seen;
    n    = 0;
    seen = 1'b0;
    while (!seen && n < 1000) begin
      if (what == 0)      seen = (chk_aw.size() != 0);
      else if (what == 1) seen = (chk_w.size() != 0);
      else                seen = (mst_req.ar_valid === 1'b1);
      if (!seen) begin
        @(negedge clk);
        n++;
      end
    end
    if (!seen) fail($sformatf("%s: the socket did not offer the request", name));
  endtask
  // the end of a phase: every request answered, then nothing may be left on either side
  task automatic end_phase(string name, int unsigned n);
    drain(name);
    repeat (2) @(negedge clk);
    if (!ph_hung && (chk_ar.size() || chk_aw.size() || chk_w.size() || dut.i_slots.granted_r.size() ||
                     dut.i_slots.granted_w.size() || rq.size() || bq.size() || r_vld || b_vld))
      fail($sformatf("%s: left over: %0d AR %0d AW %0d W not granted, %0d reads %0d writes granted but not issued, %0d R %0d B not answered",
                     name, chk_ar.size(), chk_aw.size(), chk_w.size(), dut.i_slots.granted_r.size(),
                     dut.i_slots.granted_w.size(), rq.size() + r_vld, bq.size() + b_vld));
    if (!ph_hung && dut.cnt_q !== '0)
      fail($sformatf("%s: the socket still counts %0d requests open after all were answered", name, dut.cnt_q));
    if (r_refused != ph_rr0 || b_refused != ph_br0)
      fail($sformatf("%s: the socket refused an offered R for %0d cycles and a B for %0d cycles", name,
                     r_refused - ph_rr0, b_refused - ph_br0));
    n_phases++;
    n_reqs += n;
    $display("%s %s: %0d requests, %0d cycles", (fails + dut.i_slots.fails == ph_f0) ? "ok  " : "FAIL", name, n,
             cyc - ph_c0);
  endtask
  task automatic run(string name, rq_t reqs [$], order_e ord, bit ord_rand, int unsigned rdy, int unsigned dly,
                     int unsigned r_x, int unsigned b_x, int unsigned gap);
    begin_phase(ord, ord_rand, rdy, dly, r_x, b_x, gap);
    foreach (reqs[i]) dut.i_slots.add(reqs[i]);
    end_phase(name, reqs.size());
  endtask

  initial begin
    rq_t         q [$], r;
    rq_t         ra, rb;
    logic [31:0] t1, t2, t3, t4;
    logic [15:0] tag4;
    int unsigned n;
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
    // 9: TAG_POLICY written while a request of slot 1 waits: the request keeps the tag of the first cycle the socket
    // offered it, on all its channels and in LAST_USER; the next one carries the new tag. The forced tags have RCIDs
    // no slot uses (mk: slot s has RCID s + 1).
    begin_phase(FREE, 0, 100, 0, 0, 0, 0);
    t1 = 32'h8000_0000 | 32'(((12 | (9 << 4)) << QosUserLsb) | 1);   // FORCE, RCID 12, MCID 9 (and a port bit)
    t2 = 32'h8000_0000 | 32'((13 | (3 << 4)) << QosUserLsb);         // FORCE, RCID 13, MCID 3
    // 9a: a write whose W the slave holds: its AW goes out, then FORCE t1
    hold_w = 1'b1;
    r = mk(1, 1, 64'h8000_0400);
    dut.i_slots.add(r);
    wait_for("9a", 0);
    reg_write(PolBase + 8, t1);
    still_waiting("9a", 1);
    repeat (4) @(negedge clk);
    hold_w = 1'b0;
    drain("9a");
    check_policy("9a", 1, t1 & PolMask, r.tag);
    // 9b: the next write carries t1; its AW held (its W goes first), FORCE cleared meanwhile
    hold_aw = 1'b1;
    r = mk(1, 1, 64'h8000_0408);
    r.tag = forced(t1);
    dut.i_slots.add(r);
    wait_for("9b", 1);
    reg_write(PolBase + 8, 32'h0);
    still_waiting("9b", 1);
    repeat (4) @(negedge clk);
    hold_aw = 1'b0;
    drain("9b");
    check_policy("9b", 1, 32'h0, forced(t1));
    // 9c: a read with the slot's own tag again, its AR held, FORCE t2 meanwhile
    hold_ar = 1'b1;
    r = mk(1, 0, 64'h8000_0410);
    dut.i_slots.add(r);
    wait_for("9c", 2);
    repeat (2) @(negedge clk);
    reg_write(PolBase + 8, t2);
    still_waiting("9c", 1);
    repeat (4) @(negedge clk);
    hold_ar = 1'b0;
    drain("9c");
    check_policy("9c", 1, t2 & PolMask, r.tag);
    // 9d, 9e: the next read and write carry t2
    r = mk(1, 0, 64'h8000_0418);
    r.tag = forced(t2);
    dut.i_slots.add(r);
    r = mk(1, 1, 64'h8000_0420);
    r.tag = forced(t2);
    dut.i_slots.add(r);
    drain("9e");
    check_policy("9e", 1, t2 & PolMask, forced(t2));
    end_phase("9 TAG_POLICY written while a W, an AW, an AR waits", 5);
    // 10: slot 3 forced to t3 before its traffic, slot 4 with its own tags, back to back, ready 50%, any order
    begin_phase(FREE, 1, 50, 8, 0, 0, 1);
    t3 = 32'h8000_0000 | 32'((14 | (12 << 4)) << QosUserLsb);        // FORCE, RCID 14, MCID 12
    reg_write(PolBase + 8 * 3, t3);
    q = {};
    for (int i = 0; i < 150; i++) for (int unsigned s = 3; s < 5; s++) begin
      r = mk_rand(s);
      if (s == 3) r.tag = forced(t3);
      else        tag4  = r.tag;
      q.push_back(r);
    end
    foreach (q[i]) dut.i_slots.add(q[i]);
    drain("10");
    check_policy("10", 3, t3 & PolMask, forced(t3));
    check_policy("10", 4, 32'h0, tag4);
    end_phase("10 slot 3 forced, slots 3 and 4, ready 50%, any order", q.size());
    // 11: TAG_POLICY written while a request waits for its turn, before the socket offers it to axi_from_mem: the
    // request carries the new tag
    begin_phase(FREE, 0, 100, 0, 0, 0, 0);
    t4 = 32'h8000_0000 | 32'((15 | (5 << 4)) << QosUserLsb);         // FORCE, RCID 15, MCID 5
    // 11a: a read of slot 2 waits behind a write of slot 1 whose W the slave holds (the arbiter keeps slot 1); FORCE
    // t4 on slot 2 meanwhile
    hold_w = 1'b1;
    ra = mk(1, 1, 64'h8000_0500);
    dut.i_slots.add(ra);
    wait_for("11a", 0);
    rb = mk(2, 0, 64'h8000_0508);
    rb.tag = forced(t4);
    dut.i_slots.add(rb);
    repeat (2) @(negedge clk);
    reg_write(PolBase + 8 * 2, t4);
    still_waiting("11a", 1);
    still_waiting("11a", 2);
    repeat (4) @(negedge clk);
    hold_w = 1'b0;
    drain("11a");
    check_policy("11a", 1, 32'h0, ra.tag);
    check_policy("11a", 2, t4 & PolMask, forced(t4));
    // 11b: a write of slot 2 waits while 4 slow reads of slot 1 are open (dn_req is low); FORCE cleared meanwhile
    r_extra = 40;
    for (int i = 0; i < 4; i++) begin
      r = mk(1, 0, 64'h8000_0600 + 64'(8 * i));
      dut.i_slots.add(r);
    end
    n = 0;
    while (dut.cnt_q != 4 && n < 1000) begin
      @(negedge clk);
      n++;
    end
    if (dut.cnt_q != 4) fail("11b: the 4 reads did not open");
    rb = mk(2, 1, 64'h8000_0700);
    dut.i_slots.add(rb);
    repeat (2) @(negedge clk);
    reg_write(PolBase + 8 * 2, 32'h0);
    still_waiting("11b", 2);
    drain("11b");
    r_extra = 0;
    check_policy("11b", 2, 32'h0, rb.tag);
    end_phase("11 TAG_POLICY written while a request waits for its turn", 7);

    $display("checked %0d reads and %0d writes on the AXI side, %0d responses at the slots", n_rd, n_wr,
             dut.i_slots.n_rsp);
    if (fails + dut.i_slots.fails == 0)
      $display("ACCEL SOCKET UNIT PASS: %0d phases, %0d requests", n_phases, n_reqs);
    else
      $display("ACCEL SOCKET UNIT FAIL: %0d failures", fails + dut.i_slots.fails);
    $finish;
  end
endmodule
