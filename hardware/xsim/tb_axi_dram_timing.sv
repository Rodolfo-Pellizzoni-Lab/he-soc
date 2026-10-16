// Unit test of host/axi_dram_timing.sv: an AXI master issues line reads and writes, a memory answers after a
// fixed delay, and the test checks the cycle at which every beat and response comes out of the model.
//   cd hardware/xsim/work && xvlog -sv -work work ../tb_axi_dram_timing.sv && xelab -s tb_dm tb_axi_dram_timing && xsim tb_dm -R
`timescale 1ns/1ps
module tb_axi_dram_timing;
  import ariane_axi_soc::*;
  localparam int unsigned IdW = ariane_soc::IdWidthSlave + 1;
  localparam int unsigned MemLat = 10;   // memory cycles from AR / last W to the first beat / B

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

  // ---------------- memory: in-order, MemLat cycles, beats back to back
  typedef struct { logic [IdW-1:0] id; int len; } rq_t;
  rq_t rdq[$], wrq[$];
  int unsigned rd_due[$], wr_due[$];
  int fails = 0;
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
    if (mst_req.ar_valid && mst_resp.ar_ready) begin rdq.push_back('{mst_req.ar.id, mst_req.ar.len}); rd_due.push_back(cyc + MemLat); end
    if (mst_req.aw_valid && mst_resp.aw_ready) begin wrq.push_back('{mst_req.aw.id, mst_req.aw.len}); wr_due.push_back(cyc + MemLat); end
    // read data
    if (r_valid_q && mst_req.r_ready) begin
      if (r_q.last) begin r_valid_q <= 0; beat_q <= 0; end
      else begin r_q.data <= r_q.data + 1; r_q.last <= (beat_q + 1 == rdq[0].len); beat_q <= beat_q + 1; end
      if (r_q.last) begin void'(rdq.pop_front()); void'(rd_due.pop_front()); end
    end
    if (!r_valid_q && rdq.size() > 0 && cyc >= rd_due[0]) begin
      r_valid_q <= 1; r_q <= '0; r_q.id <= rdq[0].id; r_q.data <= 64'h1000 * (cyc); r_q.last <= (rdq[0].len == 0); beat_q <= 0;
    end
    if (b_valid_q && mst_req.b_ready) begin b_valid_q <= 0; void'(wrq.pop_front()); void'(wr_due.pop_front()); end
    if (!b_valid_q && wrq.size() > 0 && cyc >= wr_due[0]) begin b_valid_q <= 1; b_q <= '0; b_q.id <= wrq[0].id; end
  end

  // ---------------- master side: record the cycle of every beat / response
  int unsigned r_cycles[$], b_cycles[$];
  always @(posedge clk) begin
    if (slv_resp.r_valid && slv_req.r_ready) r_cycles.push_back(cyc);
    if (slv_resp.b_valid && slv_req.b_ready) b_cycles.push_back(cyc);
  end

  task automatic send_ar(input logic [IdW-1:0] id, input int len);
    @(posedge clk); slv_req.ar <= '0; slv_req.ar.id <= id; slv_req.ar.len <= len; slv_req.ar.size <= 3; slv_req.ar_valid <= 1;
    @(posedge clk); while (!slv_resp.ar_ready) @(posedge clk);
    slv_req.ar_valid <= 0;
  endtask
  task automatic send_aw_w(input logic [IdW-1:0] id, input int len);
    @(posedge clk); slv_req.aw <= '0; slv_req.aw.id <= id; slv_req.aw.len <= len; slv_req.aw.size <= 3; slv_req.aw_valid <= 1;
    @(posedge clk); while (!slv_resp.aw_ready) @(posedge clk);
    slv_req.aw_valid <= 0;
    for (int i = 0; i <= len; i++) begin
      slv_req.w <= '0; slv_req.w.last <= (i == len); slv_req.w_valid <= 1;
      @(posedge clk); while (!slv_resp.w_ready) @(posedge clk);
    end
    slv_req.w_valid <= 0;
  endtask
  task automatic check(input bit ok, input string what);
    if (!ok) begin fails++; $display("FAIL %s", what); end else $display("ok   %s", what);
  endtask

  int unsigned t0;
  initial begin
    slv_req.r_ready = 1; slv_req.b_ready = 1;
    repeat (3) @(posedge clk); rst_n = 1; repeat (3) @(posedge clk);

    // 1. disabled: a wire. 8 beats, the first MemLat + 1 after the AR
    r_cycles.delete(); t0 = cyc; send_ar(5, 7);
    repeat (40) @(posedge clk);
    check(r_cycles.size() == 8, $sformatf("off: %0d beats", r_cycles.size()));
    check(r_cycles[0] - t0 <= MemLat + 3 && r_cycles[7] == r_cycles[0] + 7, $sformatf("off: beats at +%0d..+%0d", r_cycles[0] - t0, r_cycles[7] - t0));

    // 2. latency 100, no bandwidth limit: first beat >= 100 after the AR, beats back to back
    cfg.enable = 1; cfg.lat_rd = 100; cfg.lat_wr = 0; cfg.occ16 = 0; @(posedge clk);
    r_cycles.delete(); t0 = cyc; send_ar(5, 7);
    repeat (140) @(posedge clk);
    check(r_cycles.size() == 8, $sformatf("lat 100: %0d beats", r_cycles.size()));
    check(r_cycles[0] - t0 >= 100 && r_cycles[0] - t0 <= 103, $sformatf("lat 100: first beat at +%0d", r_cycles[0] - t0));
    check(r_cycles[7] - r_cycles[0] == 7, $sformatf("lat 100: last beat %0d after the first", r_cycles[7] - r_cycles[0]));
    check(cnt.rd_count == 1 && cnt.rd_beats == 8 && cnt.rd_late == 0 && cnt.hold_cycles >= 85,
          $sformatf("lat 100: counters rd %0d beats %0d late %0d hold %0d", cnt.rd_count, cnt.rd_beats, cnt.rd_late, cnt.hold_cycles));

    // 3. bandwidth: 32 cycles per beat (occ16 512), no latency: beats 32 apart, a second burst after the first's bus time
    cfg.enable = 0; @(posedge clk); cfg.lat_rd = 0; cfg.occ16 = 512; cfg.clear = 1; cfg.enable = 1; @(posedge clk); cfg.clear = 0;
    r_cycles.delete(); t0 = cyc; send_ar(5, 7); send_ar(6, 7);
    repeat (600) @(posedge clk);
    check(r_cycles.size() == 16, $sformatf("occ 32: %0d beats", r_cycles.size()));
    // the first beat is late (the memory's MemLat against lat_rd 0) and comes out at arrival; the others are paced
    // 32 cycles after the burst's modelled start (the AR, 2 cycles after t0)
    check(r_cycles[0] - t0 <= MemLat + 4 && r_cycles[2] - r_cycles[1] == 32 && r_cycles[7] - r_cycles[1] == 192,
          $sformatf("occ 32: beats of burst 1 at +%0d +%0d .. +%0d", r_cycles[0] - t0, r_cycles[1] - t0, r_cycles[7] - t0));
    check(r_cycles[8] - r_cycles[1] == 224 && r_cycles[15] - r_cycles[8] == 224, $sformatf("occ 32: burst 2 at +%0d .. +%0d", r_cycles[8] - t0, r_cycles[15] - t0));
    check(cnt.rd_count == 2 && cnt.rd_beats == 16, $sformatf("occ 32: rd %0d beats %0d", cnt.rd_count, cnt.rd_beats));

    // 4. late: the memory (MemLat) is slower than lat_rd = 1
    cfg.enable = 0; @(posedge clk); cfg.lat_rd = 1; cfg.occ16 = 0; cfg.clear = 1; cfg.enable = 1; @(posedge clk); cfg.clear = 0;
    r_cycles.delete(); t0 = cyc; send_ar(5, 3);
    repeat (40) @(posedge clk);
    check(r_cycles.size() == 4 && cnt.rd_late == 1 && cnt.late_cycles >= MemLat - 2, $sformatf("late: %0d beats, late %0d cycles %0d", r_cycles.size(), cnt.rd_late, cnt.late_cycles));

    // 5. write: B at lat_wr + bus time (8 beats x 2 cycles = 16)
    cfg.enable = 0; @(posedge clk); cfg.lat_rd = 0; cfg.lat_wr = 50; cfg.occ16 = 32; cfg.clear = 1; cfg.enable = 1; @(posedge clk); cfg.clear = 0;
    b_cycles.delete(); t0 = cyc; send_aw_w(2, 7);
    repeat (120) @(posedge clk);
    check(b_cycles.size() == 1 && b_cycles[0] - t0 >= 66 && b_cycles[0] - t0 <= 70, $sformatf("write: %0d responses, B at +%0d", b_cycles.size(), b_cycles.size() ? b_cycles[0] - t0 : 0));
    check(cnt.wr_count == 1, $sformatf("write: wr_count %0d", cnt.wr_count));

    // 6. enable while a read is in flight: its beats are tracked and delivered, the counters stay consistent
    cfg.enable = 0; cfg.lat_rd = 100; cfg.occ16 = 0; cfg.clear = 1; @(posedge clk); cfg.clear = 0;
    r_cycles.delete(); t0 = cyc; send_ar(7, 7);
    repeat (3) @(posedge clk); cfg.enable = 1;           // the memory answers MemLat cycles after the AR
    send_ar(7, 7);
    repeat (160) @(posedge clk);
    check(r_cycles.size() == 16 && r_cycles[7] - t0 <= MemLat + 12 && r_cycles[8] - t0 >= 100,
          $sformatf("enable in flight: %0d beats, burst 1 done at +%0d, burst 2 at +%0d", r_cycles.size(), r_cycles[7] - t0, r_cycles[8] - t0));
    // rd_count counts bursts accepted while enabled (the second), rd_beats every beat delivered while enabled
    check(cnt.rd_count == 1 && cnt.rd_beats == 16 && dut.rd_cnt_q == 0, $sformatf("enable in flight: rd %0d beats %0d outstanding %0d", cnt.rd_count, cnt.rd_beats, dut.rd_cnt_q));
    // 7. disable while beats are held: they still come out, in order, before anything passes through
    cfg.lat_rd = 60; @(posedge clk);
    r_cycles.delete(); t0 = cyc; send_ar(3, 7);
    repeat (20) @(posedge clk); cfg.enable = 0;           // the data is in the buffer, due at +60
    send_ar(4, 7);
    repeat (120) @(posedge clk);
    check(r_cycles.size() == 16 && r_cycles[0] - t0 >= 60 && r_cycles[8] > r_cycles[7] && dut.rb_cnt_q == 0,
          $sformatf("disable with data held: %0d beats, first at +%0d, second burst at +%0d, buffered %0d", r_cycles.size(), r_cycles[0] - t0, r_cycles[8] - t0, dut.rb_cnt_q));
    if (fails == 0) $display("UNIT PASS tb_axi_dram_timing"); else $display("UNIT FAIL tb_axi_dram_timing: %0d", fails);
    $finish;
  end
endmodule
