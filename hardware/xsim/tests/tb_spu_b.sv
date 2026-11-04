// tb_spu_b.sv: directed check of the SPU's write-response events when the master holds B (b_valid without b_ready).
// 18196e8c fixed axi_spu_top / ace_spu_top: new_b_resp_q never left 1 (`new_b_resp_q <= new_b_resp_q`), so every
// cycle of a held B reached spu_w_chan as a response; it deletes the oldest CAM entry of that ID each time, so with
// two writes of one ID outstanding the second is answered by the first's B (a short latency) and its own B later
// finds no entry. No system run holds a B at an SPU, so only a unit test shows the fix.
//   A: one write, B held 9 cycles                           -> one W_RESP
//   B: two writes of ID 5 outstanding, the first B held 12  -> two W_RESP, each with its own B's latency and source
//   C: two writes of different IDs, both B held             -> two W_RESP, unaffected by each other
// Pass: per write one W_REQ and one W_RESP (e_id W_REQ+1 / W_RESP+1), the W_RESPs in B order, each with the source
// sampled with its AW and latency = (first cycle its B is valid) - (first cycle its AW is valid) + one constant.
// Prints "SPU B UNIT PASS" or "SPU B UNIT FAIL: <n> failures".
`include "axi/assign.svh"

module tb_spu_b;
  localparam int unsigned IW = 4, AW = 64, DW = 64, UW = 1, SRC_BITS = 2;
  localparam time CYC = 10ns, TA = 2ns;
  localparam int unsigned NW = 6;

  logic clk = 1'b0, rst_n = 1'b0;
  always #(CYC / 2) clk = ~clk;
  int unsigned cyc = 0;                              // cycle number of the next posedge
  always @(posedge clk) cyc <= cyc + 1;

  AXI_BUS #(.AXI_ADDR_WIDTH(AW), .AXI_DATA_WIDTH(DW), .AXI_ID_WIDTH(IW), .AXI_USER_WIDTH(UW)) up ();  // master side
  AXI_BUS #(.AXI_ADDR_WIDTH(AW), .AXI_DATA_WIDTH(DW), .AXI_ID_WIDTH(IW), .AXI_USER_WIDTH(UW)) dn ();  // slave side

  axi_pkg::xbar_rule_64_t [1:0] map;
  assign map[0] = '{idx: 32'd0, start_addr: 64'h0000_0000, end_addr: 64'h8000_0000};
  assign map[1] = '{idx: 32'd1, start_addr: 64'h8000_0000, end_addr: 64'hC000_0000};   // "DRAM": rule 1 is counted

  logic [SRC_BITS-1:0] aw_src = '0, ar_src = '0;
  pmu_pkg::pmu_event_t ev;

  axi_spu_top #(
    .SourceIDStart ( 0                       ),
    .SourceIDEnd   ( SRC_BITS - 1            ),
    .ExtSource     ( 1'b1                    ),   // as the memory and accelerator SPUs
    .IdWidth       ( IW                      ),
    .AddrWidth     ( AW                      ),
    .DataWidth     ( DW                      ),
    .N_ADDR_RULES  ( 2                       ),
    .addr_rule_t   ( axi_pkg::xbar_rule_64_t ),
    .CAM_DEPTH     ( 17                      ),
    .FIFO_DEPTH    ( 8                       )
  ) i_dut (
    .clk_i      ( clk    ),
    .rst_ni     ( rst_n  ),
    .addr_map_i ( map    ),
    .spu_slv    ( up     ),
    .spu_mst    ( dn     ),
    .ar_src_i   ( ar_src ),
    .aw_src_i   ( aw_src ),
    .e_out      ( ev     )
  );

  // ---- what the tb did: the first cycle each AW / B was valid, the source of each write, in issue / B order
  int unsigned aw_cyc [NW], aw_s [NW], b_cyc [NW], b_of [NW];   // b_of[k]: the write the k-th B answers
  int unsigned nb = 0;

  // ---- what the SPU reported
  int unsigned n_wreq = 0, n_wresp = 0, n_other = 0;
  int unsigned resp_lat [$], resp_src [$];
  always @(posedge clk) if (rst_n && ev.e_id != '0) begin
    if (ev.e_id == spu_pkg::W_REQ + 1) n_wreq++;
    else if (ev.e_id == spu_pkg::W_RESP + 1) begin
      n_wresp++;
      resp_lat.push_back(int'(ev.e_info[15:0]));
      resp_src.push_back(int'(ev.s_id));
    end else n_other++;
  end

  // ---- master: AW and W of write k (single beat, accepted at once by the slave below)
  task automatic write(input int k, input logic [IW-1:0] id, input logic [AW-1:0] addr, input int src);
    @(posedge clk); #TA;
    up.aw_valid = 1'b1; up.aw_id = id; up.aw_addr = addr; up.aw_len = '0; up.aw_size = 3'd3;
    up.aw_burst = axi_pkg::BURST_INCR; aw_src = src;
    up.w_valid = 1'b1; up.w_data = {32'hC0DE, 32'(k)}; up.w_strb = '1; up.w_last = 1'b1;
    aw_cyc[k] = cyc; aw_s[k] = src;
    do @(posedge clk); while (!(dn.aw_ready && dn.w_ready));
    #TA; up.aw_valid = 1'b0; up.w_valid = 1'b0;
  endtask

  // ---- slave: the B of write k, held `hold` cycles by the master before it takes it
  task automatic resp(input int k, input logic [IW-1:0] id, input int hold);
    @(posedge clk); #TA;
    dn.b_valid = 1'b1; dn.b_id = id; dn.b_resp = axi_pkg::RESP_OKAY;
    b_cyc[nb] = cyc; b_of[nb] = k; nb++;
    up.b_ready = 1'b0;
    repeat (hold) @(posedge clk);
    #TA; up.b_ready = 1'b1;
    do @(posedge clk); while (!(up.b_valid && up.b_ready));
    #TA; dn.b_valid = 1'b0; up.b_ready = 1'b0;
  endtask

  initial begin
    automatic int fails = 0, c0;
    // master outputs
    up.aw_valid = 0; up.aw_id = 0; up.aw_addr = 0; up.aw_len = 0; up.aw_size = 3; up.aw_burst = axi_pkg::BURST_INCR;
    up.aw_lock = 0; up.aw_cache = 0; up.aw_prot = 0; up.aw_qos = 0; up.aw_region = 0; up.aw_atop = 0; up.aw_user = 0;
    up.w_valid = 0; up.w_data = 0; up.w_strb = 0; up.w_last = 0; up.w_user = 0;
    up.b_ready = 0;
    up.ar_valid = 0; up.ar_id = 0; up.ar_addr = 0; up.ar_len = 0; up.ar_size = 3; up.ar_burst = axi_pkg::BURST_INCR;
    up.ar_lock = 0; up.ar_cache = 0; up.ar_prot = 0; up.ar_qos = 0; up.ar_region = 0; up.ar_user = 0;
    up.r_ready = 1;
    // slave outputs
    dn.aw_ready = 1; dn.w_ready = 1; dn.b_valid = 0; dn.b_id = 0; dn.b_resp = 0; dn.b_user = 0;
    dn.ar_ready = 1; dn.r_valid = 0; dn.r_id = 0; dn.r_data = 0; dn.r_resp = 0; dn.r_last = 0; dn.r_user = 0;
    repeat (5) @(posedge clk);
    #TA rst_n = 1'b1;
    repeat (5) @(posedge clk);
    // A: one write, its B held 9 cycles
    write(0, 4'd3, 64'h8000_0000, 1);
    repeat (6) @(posedge clk);
    resp(0, 4'd3, 9);
    repeat (10) @(posedge clk);
    // B: two writes of ID 5 outstanding; the first B held 12 cycles, the second B 25 cycles later, not held
    write(1, 4'd5, 64'h8000_0040, 2);
    repeat (3) @(posedge clk);
    write(2, 4'd5, 64'h8000_0080, 3);
    repeat (8) @(posedge clk);
    resp(1, 4'd5, 12);
    repeat (25) @(posedge clk);
    resp(2, 4'd5, 0);
    repeat (10) @(posedge clk);
    // C: two writes of different IDs, both outstanding, both B held
    write(3, 4'd6, 64'h8000_00C0, 1);
    write(4, 4'd7, 64'h8000_0100, 2);
    repeat (5) @(posedge clk);
    resp(3, 4'd6, 7);
    resp(4, 4'd7, 4);
    repeat (10) @(posedge clk);
    // one more write of ID 5, so a B of ID 5 that went missing in B would also be visible here
    write(5, 4'd5, 64'h8000_0140, 0);
    repeat (6) @(posedge clk);
    resp(5, 4'd5, 3);
    repeat (40) @(posedge clk);

    // ---- check
    if (n_wreq != NW) begin fails++; $display("FAIL: %0d W_REQ events for %0d writes", n_wreq, NW); end
    if (n_wresp != NW) begin fails++; $display("FAIL: %0d W_RESP events for %0d writes", n_wresp, NW); end
    if (n_other != 0) begin fails++; $display("FAIL: %0d events of other kinds (no reads were made)", n_other); end
    c0 = (resp_lat.size() > 0) ? int'(resp_lat[0]) - int'(b_cyc[0] - aw_cyc[b_of[0]]) : 0;
    for (int i = 0; i < nb; i++) begin
      automatic int k = b_of[i], want = int'(b_cyc[i] - aw_cyc[k]) + c0;
      if (i >= resp_lat.size()) begin
        fails++; $display("FAIL: B %0d (write %0d, ID-ordered) has no W_RESP event", i, k);
      end else begin
        $display("  B %0d -> write %0d: latency %0d (AW at %0d, B at %0d; expected %0d), source %0d (expected %0d)",
                 i, k, resp_lat[i], aw_cyc[k], b_cyc[i], want, resp_src[i], aw_s[k]);
        if (int'(resp_lat[i]) != want) begin fails++; $display("FAIL: write %0d latency %0d, expected %0d", k, resp_lat[i], want); end
        if (resp_src[i] != aw_s[k]) begin fails++; $display("FAIL: write %0d source %0d, expected %0d", k, resp_src[i], aw_s[k]); end
      end
    end
    if (c0 < 0 || c0 > 2) begin fails++; $display("FAIL: latency offset %0d (expected 0..2)", c0); end
    if (fails == 0) $display("SPU B UNIT PASS: %0d writes, %0d W_REQ, %0d W_RESP, latency offset %0d", NW, n_wreq, n_wresp, c0);
    else            $display("SPU B UNIT FAIL: %0d failures", fails);
    $finish;
  end

  initial begin
    #200us;
    $display("SPU B UNIT FAIL: watchdog (simulation did not finish)");
    $finish;
  end
endmodule
