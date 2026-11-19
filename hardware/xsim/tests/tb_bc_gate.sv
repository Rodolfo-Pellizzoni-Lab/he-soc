// tb_bc_gate.sv: unit test of the DMA admission gate (ip_list/axi_llc/src/axi_llc_bc_gate.sv).
// A random AXI master (writes of 1-4 beats and reads of 1-4 beats, 4 IDs, random RCIDs in the user field) drives the
// gate; behind it a slave answers each ID in order but the IDs in any order, with random delays; the admission
// input grants at random. Checks: every transaction completes with its data; no W beat reaches the slave before its
// AW; a request reaches the slave only after an admission; the bytes the gate reports done per RCID equal the bytes
// admitted; the admission request stays stable while it waits; at most MaxTrans requests are in flight.
// Prints "BC GATE PASS" or "BC GATE FAIL: <n> failures".
`include "axi/typedef.svh"

module tb_bc_gate;
  localparam time CYC = 10ns, TA = 2ns, TT = 8ns;
  localparam int unsigned NOPS = 3000, MAXT = 4, RL = 3;   // RCID position in user

  typedef logic [3:0]  id_t;
  typedef logic [63:0] addr_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0]  strb_t;
  typedef logic [11:0] user_t;
  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)

  logic clk = 1'b0, rst_n = 1'b0;
  always #(CYC / 2) clk = ~clk;

  axi_req_t  m_req, s_req;
  axi_resp_t m_resp, s_resp;
  logic        adm_req, adm_gnt, done;
  logic [3:0]  adm_rcid, done_rcid;
  logic [15:0] adm_bytes, done_bytes;

  axi_llc_bc_gate #(
    .Enable ( 1'b1 ), .IdWidth ( 4 ), .AddrWidth ( 64 ), .RcidWidth ( 4 ), .RcidLsb ( RL ), .LineBytes ( 64 ),
    .CostLines ( 4 ), .MaxTrans ( MAXT ),
    .aw_chan_t ( axi_aw_chan_t ), .ar_chan_t ( axi_ar_chan_t ), .req_t ( axi_req_t ), .resp_t ( axi_resp_t )
  ) dut (
    .clk_i ( clk ), .rst_ni ( rst_n ),
    .slv_req_i ( m_req ), .slv_resp_o ( m_resp ), .mst_req_o ( s_req ), .mst_resp_i ( s_resp ),
    .adm_req_o ( adm_req ), .adm_rcid_o ( adm_rcid ), .adm_bytes_o ( adm_bytes ), .adm_gnt_i ( adm_gnt ),
    .done_o ( done ), .done_rcid_o ( done_rcid ), .done_bytes_o ( done_bytes )
  );

  int unsigned fails = 0;
  function automatic void fail(string m);
    fails++;
    if (fails <= 20) $display("FAIL: %s", m);
  endfunction

  // ---------------------------------------------------------------------------------------- admission model
  longint unsigned adm_sum[16], done_sum[16];
  int unsigned admitted = 0, at_slave = 0, inflight = 0, max_inflight = 0;
  logic        req_q = 1'b0;
  logic [3:0]  rcid_q;
  logic [15:0] bytes_q;
  always @(posedge clk) begin
    if (rst_n) begin
      if (req_q && !adm_gnt && adm_req && (adm_rcid != rcid_q || adm_bytes != bytes_q))
        fail("admission request changed while waiting");
      if (adm_req && adm_gnt) begin adm_sum[adm_rcid] += adm_bytes; admitted++; inflight++; end
      if (done) begin done_sum[done_rcid] += done_bytes; inflight--; end
      if (inflight > max_inflight) max_inflight = inflight;
      req_q <= adm_req && !adm_gnt; rcid_q <= adm_rcid; bytes_q <= adm_bytes;
    end
  end
  initial begin
    adm_gnt = 1'b0;
    forever begin @(posedge clk); #TA; adm_gnt = ($urandom_range(0, 99) < 40); end
  end

  // ---------------------------------------------------------------------------------------- master
  typedef struct { bit w; id_t id; addr_t a; int unsigned len; user_t u; int unsigned tag; } op_t;
  op_t  aw_q[$], w_q[$], ar_q[$];
  int unsigned rd_open[id_t][$], wr_open[id_t][$];   // per ID: tags in issue order
  int unsigned completed = 0, issued = 0;
  int unsigned op_rcid[int unsigned], op_cost[int unsigned];
  longint unsigned fin_sum[16];                       // worst-case bytes of the transactions complete at the master
  function automatic int unsigned cost_of(addr_t a, int unsigned len);
    return ((((a + (len + 1) * 8 - 1) >> 6) - (a >> 6)) + 1) * 4 * 64;
  endfunction
  function automatic data_t wdata(int unsigned tag, int unsigned beat); return {32'(tag), 32'(beat) ^ 32'hA5A5}; endfunction

  initial begin
    for (int unsigned t = 0; t < NOPS; t++) begin
      op_t o;
      o.w   = $urandom_range(0, 1);
      o.id  = id_t'($urandom_range(0, 3));
      o.len = $urandom_range(0, 3);
      o.a   = 64'h8000_0000 + 64'($urandom_range(0, 4095)) * 8;
      o.u   = user_t'(($urandom_range(0, 15) << RL) | $urandom_range(0, 7));
      o.tag = t;
      op_rcid[t] = (o.u >> RL) & 15;
      op_cost[t] = cost_of(o.a, o.len);
      if (o.w) aw_q.push_back(o); else ar_q.push_back(o);
    end
  end

  // AW, W and AR drivers (drive at TA, sample at TT)
  initial begin
    m_req = '0;
    m_req.b_ready = 1'b1;
    m_req.r_ready = 1'b1;
    wait (rst_n);
    fork
      forever begin                                          // AW
        @(posedge clk); #TA;
        if (!m_req.aw_valid && aw_q.size() != 0 && $urandom_range(0, 3) != 0) begin
          op_t o = aw_q.pop_front();
          m_req.aw = '0; m_req.aw.id = o.id; m_req.aw.addr = o.a; m_req.aw.len = 8'(o.len); m_req.aw.size = 3'd3;
          m_req.aw.burst = axi_pkg::BURST_INCR; m_req.aw.user = o.u;
          m_req.aw_valid = 1'b1;
          wr_open[o.id].push_back(o.tag);
          w_q.push_back(o);
          issued++;
        end
        #(TT - TA);
        if (m_req.aw_valid && m_resp.aw_ready) begin @(posedge clk); #TA; m_req.aw_valid = 1'b0; #(TT - TA); end
      end
      forever begin                                          // W: may run ahead of the AW handshake
        @(posedge clk);
        if (w_q.size() != 0) begin
          op_t o = w_q.pop_front();
          for (int unsigned b = 0; b <= o.len; b++) begin
            #TA; m_req.w.data = wdata(o.tag, b); m_req.w.strb = '1; m_req.w.last = (b == o.len); m_req.w_valid = 1'b1;
            #(TT - TA); while (!m_resp.w_ready) begin @(posedge clk); #(TT); end
            @(posedge clk);
          end
          #TA; m_req.w_valid = 1'b0;
        end
      end
      forever begin                                          // AR
        @(posedge clk); #TA;
        if (!m_req.ar_valid && ar_q.size() != 0 && $urandom_range(0, 3) != 0) begin
          op_t o = ar_q.pop_front();
          m_req.ar = '0; m_req.ar.id = o.id; m_req.ar.addr = o.a; m_req.ar.len = 8'(o.len); m_req.ar.size = 3'd3;
          m_req.ar.burst = axi_pkg::BURST_INCR; m_req.ar.user = o.u;
          m_req.ar_valid = 1'b1;
          rd_open[o.id].push_back(o.tag);
          issued++;
        end
        #(TT - TA);
        if (m_req.ar_valid && m_resp.ar_ready) begin @(posedge clk); #TA; m_req.ar_valid = 1'b0; #(TT - TA); end
      end
    join_none
  end
  // responses at the master: B and R in per-ID order, R data = what the slave makes of the read's tag
  int unsigned rbeat[id_t];
  always @(posedge clk) if (rst_n) begin
    if (m_resp.b_valid && m_req.b_ready) begin
      if (wr_open[m_resp.b.id].size() == 0) fail($sformatf("B for id %0d with no write open", m_resp.b.id));
      else begin
        int unsigned tg = wr_open[m_resp.b.id].pop_front();
        fin_sum[op_rcid[tg]] += op_cost[tg];
        completed++;
      end
    end
    if (m_resp.r_valid && m_req.r_ready) begin
      if (rd_open[m_resp.r.id].size() == 0) fail($sformatf("R for id %0d with no read open", m_resp.r.id));
      else begin
        int unsigned tag = rd_open[m_resp.r.id][0];
        if (m_resp.r.data != {32'(tag), 32'(rbeat[m_resp.r.id])})
          fail($sformatf("R data of read %0d beat %0d: %h", tag, rbeat[m_resp.r.id], m_resp.r.data));
        rbeat[m_resp.r.id]++;
        if (m_resp.r.last) begin
          fin_sum[op_rcid[tag]] += op_cost[tag];
          void'(rd_open[m_resp.r.id].pop_front()); rbeat[m_resp.r.id] = 0; completed++;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------------------- slave
  typedef struct { id_t id; int unsigned len; int unsigned beat; } sop_t;
  sop_t s_aw[$];                                     // AWs accepted, in order, waiting for their W beats
  sop_t s_b[4][$];                                    // per ID: writes whose W is complete, B owed
  sop_t s_r[4][$];                                    // per ID: reads, R owed
  int unsigned s_wbeat = 0;
  int          r_cur = -1;                            // ID of a read burst in progress (no interleaving)
  bit          b_fired = 0, r_fired = 0;
  initial begin
    s_resp = '0;
    wait (rst_n);
    forever begin
      @(posedge clk); #TA;
      if (b_fired) begin s_resp.b_valid = 1'b0; b_fired = 0; end
      if (r_fired) begin s_resp.r_valid = 1'b0; r_fired = 0; end
      // drive: readies at random, a B and an R beat when owed
      s_resp.aw_ready = ($urandom_range(0, 2) != 0);
      s_resp.ar_ready = ($urandom_range(0, 2) != 0);
      s_resp.w_ready  = ($urandom_range(0, 3) != 0);
      if (!s_resp.b_valid && $urandom_range(0, 2) == 0) begin
        int unsigned k = $urandom_range(0, 3);
        if (s_b[k].size() != 0) begin s_resp.b = '0; s_resp.b.id = id_t'(k); s_resp.b_valid = 1'b1; end
      end
      if (!s_resp.r_valid && $urandom_range(0, 2) == 0) begin
        int k = (r_cur >= 0) ? r_cur : $urandom_range(0, 3);
        if (s_r[k].size() != 0) begin
          s_resp.r = '0; s_resp.r.id = id_t'(k); s_resp.r.last = (s_r[k][0].beat == s_r[k][0].len);
          s_resp.r.data = {32'(rd_open[id_t'(k)][0]), 32'(s_r[k][0].beat)};
          s_resp.r_valid = 1'b1;
          r_cur = k;
        end
      end
      #(TT - TA);
      // sample the handshakes of this cycle
      if (s_req.aw_valid && s_resp.aw_ready) begin
        sop_t o;
        o.id = s_req.aw.id; o.len = s_req.aw.len; o.beat = 0;
        s_aw.push_back(o);
        at_slave++;
      end
      if (s_req.ar_valid && s_resp.ar_ready) begin
        sop_t o;
        int unsigned k;
        o.id = s_req.ar.id; o.len = s_req.ar.len; o.beat = 0;
        k = o.id;
        s_r[k].push_back(o);
        at_slave++;
      end
      if (s_req.w_valid && s_resp.w_ready) begin
        if (s_aw.size() == 0) fail("W beat at the slave before its AW");
        else begin
          if (s_req.w.data[31:0] != (32'(s_wbeat) ^ 32'hA5A5)) fail($sformatf("W beat %0d data %h", s_wbeat, s_req.w.data));
          if (s_req.w.last != (s_wbeat == s_aw[0].len)) fail("W last in the wrong beat");
          s_wbeat++;
          if (s_req.w.last) begin sop_t o = s_aw.pop_front(); s_b[o.id].push_back(o); s_wbeat = 0; end
        end
      end
      if (s_resp.b_valid && s_req.b_ready) begin void'(s_b[s_resp.b.id].pop_front()); b_fired = 1; end
      if (s_resp.r_valid && s_req.r_ready) begin
        s_r[s_resp.r.id][0].beat++;
        if (s_resp.r.last) begin void'(s_r[s_resp.r.id].pop_front()); r_cur = -1; end
        r_fired = 1;
      end
    end
  end

  // done never runs ahead of the transactions complete at the master (per RCID), and the admitted cost is the
  // request's worst case
  always @(posedge clk) if (rst_n) begin
    for (int k = 0; k < 16; k++)
      if (done_sum[k] > fin_sum[k]) fail($sformatf("RCID %0d: %0d bytes done, only %0d complete", k, done_sum[k], fin_sum[k]));
  end
  // a request reaches the slave only after an admission
  always @(posedge clk) if (rst_n && at_slave > admitted) fail($sformatf("%0d requests at the slave, %0d admitted", at_slave, admitted));

  initial begin
    for (int k = 0; k < 16; k++) begin adm_sum[k] = 0; done_sum[k] = 0; fin_sum[k] = 0; end
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    for (int unsigned c = 0; c < 400000 && completed < NOPS; c++) @(posedge clk);
    repeat (20) @(posedge clk);
    if (completed != NOPS) fail($sformatf("%0d of %0d transactions completed", completed, NOPS));
    for (int k = 0; k < 16; k++)
      if (adm_sum[k] != done_sum[k] || adm_sum[k] != fin_sum[k])
        fail($sformatf("RCID %0d: %0d bytes admitted, %0d done, %0d complete", k, adm_sum[k], done_sum[k], fin_sum[k]));
    if (max_inflight > MAXT) fail($sformatf("%0d requests in flight (MaxTrans %0d)", max_inflight, MAXT));
    $display("  %0d transactions (%0d admitted), at most %0d in flight", completed, admitted, max_inflight);
    if (fails == 0) $display("BC GATE PASS");
    else            $display("BC GATE FAIL: %0d failures", fails);
    $finish;
  end
endmodule
