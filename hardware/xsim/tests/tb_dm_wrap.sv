// tb_dm_wrap.sv: the DRAM timing model's time base across the point where its old 48-bit counter wrapped
// (host/axi_dram_timing.sv; run by tests/run_dm_wrap.sh). The time base counts 1/16 cycles; with TW = 48 it wrapped
// 2^44 cycles (4.07 days at 50 MHz) after a reset, and its compares are not wrap-safe, so a response stamped before
// the wrap but due after it was held until a reset. The test runs a read (8 beats) and a write (8 beats) at the start
// (A), then forces the time base to 300 cycles before 2^48 sixteenths and runs the same pair about 200 cycles before
// that point (B), accepted 10 cycles before it and answered after it (C), and after it (D). Each pair must come out
// at the same cycle offsets as A. With TW = 64 all four do; with TW = 48 (CONTROL=1) C and D never come out.
// Memory: in order, MemLat cycles from AR to the first beat and from the last W to B, beats back to back.
`timescale 1ns/1ps
module tb_dm_wrap;
  import ariane_axi_soc::*;
  localparam int unsigned IdW = ariane_soc::IdWidthSlave + 1;
  localparam int unsigned MemLat = 10;
  localparam int unsigned Wait = 2000;   // cycles a pair may take before it counts as stuck

  logic clk = 1'b0, rst_n = 1'b0;
  always #10 clk = ~clk;
  int unsigned cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  dram_model_pkg::cfg_t cfg = '0;
  dram_model_pkg::cnt_t cnt;
  req_slv_mem_t  slv_req = '0, mst_req;
  resp_slv_mem_t slv_resp, mst_resp;

  axi_dram_timing #(
    .axi_req_t (req_slv_mem_t), .axi_resp_t (resp_slv_mem_t), .r_chan_t (r_chan_slv_mem_t), .b_chan_t (b_chan_slv_mem_t),
    .IdWidth (IdW)
  ) dut (.clk_i (clk), .rst_ni (rst_n), .cfg_i (cfg), .cnt_o (cnt),
         .slv_req_i (slv_req), .slv_resp_o (slv_resp), .mst_req_o (mst_req), .mst_resp_i (mst_resp));

  // ---------------- memory
  typedef struct { logic [IdW-1:0] id; int len; } rq_t;
  rq_t rdq[$];
  int unsigned rd_due[$];
  logic [IdW-1:0] awq[$];
  logic [IdW-1:0] bq[$];
  int unsigned b_due[$];
  logic r_valid_q = 0, b_valid_q = 0;
  r_chan_slv_mem_t r_q = '0;
  b_chan_slv_mem_t b_q = '0;
  int beat_q = 0;
  always_comb begin
    mst_resp = '0;
    mst_resp.ar_ready = 1'b1;
    mst_resp.aw_ready = 1'b1;
    mst_resp.w_ready  = 1'b1;
    mst_resp.r_valid  = r_valid_q;
    mst_resp.r        = r_q;
    mst_resp.b_valid  = b_valid_q;
    mst_resp.b        = b_q;
  end
  always @(posedge clk) begin
    if (mst_req.ar_valid && mst_resp.ar_ready) begin
      rdq.push_back('{mst_req.ar.id, mst_req.ar.len}); rd_due.push_back(cyc + MemLat);
    end
    if (r_valid_q && mst_req.r_ready) begin
      if (r_q.last) begin
        r_valid_q <= 0; beat_q <= 0; void'(rdq.pop_front()); void'(rd_due.pop_front());
      end else begin
        r_q.data <= r_q.data + 1; r_q.last <= (beat_q + 1 == rdq[0].len); beat_q <= beat_q + 1;
      end
    end
    if (!r_valid_q && rdq.size() > 0 && cyc >= rd_due[0]) begin
      r_valid_q <= 1; r_q <= '0; r_q.id <= rdq[0].id; r_q.last <= (rdq[0].len == 0); beat_q <= 0;
    end
    if (mst_req.aw_valid && mst_resp.aw_ready) awq.push_back(mst_req.aw.id);
    if (mst_req.w_valid && mst_resp.w_ready && mst_req.w.last) begin
      bq.push_back(awq.pop_front()); b_due.push_back(cyc + MemLat);
    end
    if (b_valid_q && mst_req.b_ready) begin
      b_valid_q <= 0; void'(bq.pop_front()); void'(b_due.pop_front());
    end else if (!b_valid_q && bq.size() > 0 && cyc >= b_due[0]) begin
      b_valid_q <= 1; b_q <= '0; b_q.id <= bq[0];
    end
  end

  // ---------------- master: one read and one write per step, recording the cycle of every beat and of B
  int unsigned r_cy[$], b_cy[$];
  always @(posedge clk) begin
    if (slv_resp.r_valid && slv_req.r_ready) r_cy.push_back(cyc);
    if (slv_resp.b_valid && slv_req.b_ready) b_cy.push_back(cyc);
  end

  task automatic send_ar(input logic [IdW-1:0] id);
    @(posedge clk); slv_req.ar <= '0; slv_req.ar.id <= id; slv_req.ar.len <= 7; slv_req.ar.size <= 3;
    slv_req.ar_valid <= 1;
    @(posedge clk); while (!slv_resp.ar_ready) @(posedge clk);
    slv_req.ar_valid <= 0;
  endtask

  task automatic send_write(input logic [IdW-1:0] id);
    @(posedge clk); slv_req.aw <= '0; slv_req.aw.id <= id; slv_req.aw.len <= 7; slv_req.aw.size <= 3;
    slv_req.aw_valid <= 1;
    @(posedge clk); while (!slv_resp.aw_ready) @(posedge clk);
    slv_req.aw_valid <= 0;
    for (int b = 0; b < 8; b++) begin
      slv_req.w <= '0; slv_req.w.strb <= '1; slv_req.w.last <= (b == 7); slv_req.w_valid <= 1;
      @(posedge clk); while (!slv_resp.w_ready) @(posedge clk);
    end
    slv_req.w_valid <= 0;
  endtask

  int fails = 0;
  int unsigned ref_r0, ref_r7, ref_b;   // step A's offsets
  task automatic step(input string what, input logic [IdW-1:0] id, input bit is_ref);
    int unsigned t0;
    r_cy.delete(); b_cy.delete(); t0 = cyc;
    fork send_ar(id); send_write(id); join
    for (int c = 0; c < Wait && !(r_cy.size() == 8 && b_cy.size() == 1); c++) @(posedge clk);
    if (r_cy.size() != 8 || b_cy.size() != 1) begin
      fails++;
      $display("FAIL %s: %0d of 8 read beats and %0d of 1 write responses in %0d cycles (t16 %h, bus_free %h)",
               what, r_cy.size(), b_cy.size(), Wait, dut.t16_q, dut.bus_free_q);
    end else if (is_ref) begin
      ref_r0 = r_cy[0] - t0; ref_r7 = r_cy[7] - t0; ref_b = b_cy[0] - t0;
      $display("ok   %s: read beats at +%0d..+%0d, B at +%0d (the reference)", what, ref_r0, ref_r7, ref_b);
    end else if (r_cy[0] - t0 != ref_r0 || r_cy[7] - t0 != ref_r7 || b_cy[0] - t0 != ref_b) begin
      fails++;
      $display("FAIL %s: read beats at +%0d..+%0d, B at +%0d, not +%0d..+%0d, +%0d", what, r_cy[0] - t0,
               r_cy[7] - t0, b_cy[0] - t0, ref_r0, ref_r7, ref_b);
    end else
      $display("ok   %s: read beats at +%0d..+%0d, B at +%0d", what, r_cy[0] - t0, r_cy[7] - t0, b_cy[0] - t0);
    repeat (100) @(posedge clk);
  endtask

  initial begin
    slv_req.r_ready = 1; slv_req.b_ready = 1;
    repeat (3) @(posedge clk); rst_n = 1; repeat (3) @(posedge clk);
    cfg.enable = 1; cfg.lat_rd = 20; cfg.lat_wr = 20; cfg.occ16 = 16; @(posedge clk);   // 20 cycles, 1 cycle a beat
    $display("     time base %0d bits", $bits(dut.t16_q));
    step("A, at the start", 1, 1);

    // the time base to 300 cycles before 2^48 sixteenths (truncated to its width; the always_ff counts on from it)
    @(negedge clk); force dut.t16_q = (64'd1 << 48) - 64'd4800; @(negedge clk); release dut.t16_q;
    repeat (100) @(posedge clk);
    step("B, about 200 cycles before the old wrap", 2, 0);

    // C: accepted about 10 cycles before 2^48 sixteenths, answered after it
    while (64'(dut.t16_q) < (64'd1 << 48) - 64'd16 * 12 && 64'(dut.t16_q) >= 64'd4800) @(posedge clk);
    step("C, accepted just before the old wrap", 3, 0);
    step("D, after the old wrap", 4, 0);

    if (fails == 0) $display("DM WRAP UNIT PASS");
    else $display("DM WRAP UNIT FAIL: %0d of 3 steps after the reference", fails);
    $finish;
  end
endmodule
