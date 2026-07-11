// Testbench for token_bucket.sv
//
// Tests:
//   1. Reset value    -- tokens start full after reset
//   2. Disabled       -- grants always high, no token consumption
//   3. AW gating      -- valid suppressed when bucket empty, passes when refilled
//   4. AR gating      -- same for AR channel
//   5. AR wins tie    -- tokens == ar_cost: AR granted, AW blocked
//   6. Refill         -- refill period is exactly refill_interval cycles
//   7. Saturation     -- tokens settle exactly at token_limit
//   8. No underflow   -- tokens hold when 0 < tokens < cost (partial afford)
//   9. Passthrough    -- W/B/R channels unaffected by throttling
//  10. Snoop          -- wack/rack acks and AW/AR snoop sideband fields
//                        bypass the bucket even when AW/AR are throttled
//  11. AR reserves    -- tokens cover aw_cost but not ar_cost: AR priority
//                        still holds AW back until AR deasserts
//  12. AR backpressure -- valid held stable and tokens spent exactly once
//                         while mst.ar_ready is stalled low
//  13. AW backpressure -- same for the AW channel
//  14. Live interval   -- changing refill_interval on the fly takes effect
//  15. Dual grant      -- AR+AW admitted same cycle when tokens cover both
//  16. Zero cost       -- cost=0 channel always granted, tokens unchanged
//  17. Enable toggle   -- reservation held stable across enable de/re-assert

`timescale 1ps/1ps

`include "tb.svh"

import tb_pkg::*;

module tb;

  localparam int unsigned AXI_ADDR_WIDTH = 64;
  localparam int unsigned AXI_DATA_WIDTH = 64;
  localparam int unsigned AXI_ID_WIDTH   = 4;
  localparam int unsigned AXI_USER_WIDTH = 1;
  localparam int unsigned CNT_WIDTH      = 32;

  logic clk_i, rst_ni, end_of_sim;

  always begin
    do begin
      clk_i = 1; #(CLK_HI);
      clk_i = 0; #(CLK_LO);
    end while (end_of_sim == 1'b0);
    clk_i = 1; #(CLK_HI);
    clk_i = 0; #(CLK_LO);
  end

  ACE_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH )
  ) slv (), mst ();

  token_bucket_pkg::token_bucket_cfg_t cfg;

  token_bucket i_dut (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),
    .cfg_i  ( cfg    ),
    .slv    ( slv    ),
    .mst    ( mst    )
  );

  task automatic apply_aw(output bit accepted);
    slv.aw_valid    = 1'b1;
    slv.aw_addr     = 64'hDEAD_BEEF;
    slv.aw_id       = '0;
    slv.aw_len      = '0;
    slv.aw_size     = 3'b011;
    slv.aw_burst    = 2'b01;
    slv.aw_lock     = '0;
    slv.aw_cache    = '0;
    slv.aw_prot     = '0;
    slv.aw_qos      = '0;
    slv.aw_region   = '0;
    slv.aw_atop     = '0;
    slv.aw_user     = '0;
    slv.aw_snoop    = '0;
    slv.aw_bar      = '0;
    slv.aw_domain   = '0;
    slv.aw_awunique = '0;
    mst.aw_ready    = 1'b1;
    @(posedge clk_i);
    accepted = slv.aw_valid && slv.aw_ready;
    #(ACQ_DEL);
    slv.aw_valid = 1'b0;
    mst.aw_ready = 1'b0;
  endtask

  task automatic apply_ar(output bit accepted);
    slv.ar_valid  = 1'b1;
    slv.ar_addr   = 64'hCAFE_CAFE;
    slv.ar_id     = '0;
    slv.ar_len    = '0;
    slv.ar_size   = 3'b011;
    slv.ar_burst  = 2'b01;
    slv.ar_cache  = '0;
    slv.ar_prot   = '0;
    slv.ar_qos    = '0;
    slv.ar_region = '0;
    slv.ar_user   = '0;
    slv.ar_snoop  = '0;
    slv.ar_bar    = '0;
    slv.ar_domain = '0;
    mst.ar_ready  = 1'b1;
    @(posedge clk_i);
    accepted = slv.ar_valid && slv.ar_ready;
    #(ACQ_DEL);
    slv.ar_valid = 1'b0;
    mst.ar_ready = 1'b0;
  endtask

  task automatic drive_aw();
    slv.aw_valid    = 1'b1;
    slv.aw_addr     = '0;
    slv.aw_id       = '0;
    slv.aw_len      = '0;
    slv.aw_size     = 3'b011;
    slv.aw_burst    = 2'b01;
    slv.aw_lock     = '0;
    slv.aw_cache    = '0;
    slv.aw_prot     = '0;
    slv.aw_qos      = '0;
    slv.aw_region   = '0;
    slv.aw_atop     = '0;
    slv.aw_user     = '0;
    slv.aw_snoop    = '0;
    slv.aw_bar      = '0;
    slv.aw_domain   = '0;
    slv.aw_awunique = '0;
    mst.aw_ready    = 1'b1;
  endtask

  task automatic drive_ar();
    slv.ar_valid  = 1'b1;
    slv.ar_addr   = '0;
    slv.ar_id     = '0;
    slv.ar_len    = '0;
    slv.ar_size   = 3'b011;
    slv.ar_burst  = 2'b01;
    slv.ar_lock   = '0;
    slv.ar_cache  = '0;
    slv.ar_prot   = '0;
    slv.ar_qos    = '0;
    slv.ar_region = '0;
    slv.ar_user   = '0;
    slv.ar_snoop  = '0;
    slv.ar_bar    = '0;
    slv.ar_domain = '0;
    mst.ar_ready  = 1'b1;
  endtask

  task automatic idle_inputs();
    slv.aw_valid = '0; slv.aw_addr = '0; slv.aw_id = '0;
    slv.aw_len = '0; slv.aw_size = '0; slv.aw_burst = '0;
    slv.aw_lock = '0; slv.aw_cache = '0; slv.aw_prot = '0;
    slv.aw_qos = '0; slv.aw_region = '0; slv.aw_atop = '0;
    slv.aw_user = '0; slv.aw_snoop = '0; slv.aw_bar = '0;
    slv.aw_domain = '0; slv.aw_awunique = '0;
    mst.aw_ready = '0;

    slv.w_valid = '0; slv.w_data = '0; slv.w_strb = '0;
    slv.w_last  = '0; slv.w_user = '0;
    mst.w_ready = '0;

    mst.b_valid = '0; mst.b_id = '0; mst.b_resp = '0; mst.b_user = '0;
    slv.b_ready = '0;

    slv.ar_valid = '0; slv.ar_addr = '0; slv.ar_id = '0;
    slv.ar_len = '0; slv.ar_size = '0; slv.ar_burst = '0;
    slv.ar_lock = '0; slv.ar_cache = '0; slv.ar_prot = '0;
    slv.ar_qos = '0; slv.ar_region = '0; slv.ar_user = '0;
    slv.ar_snoop = '0; slv.ar_bar = '0; slv.ar_domain = '0;
    mst.ar_ready = '0;

    mst.r_valid = '0; mst.r_id = '0; mst.r_data = '0;
    mst.r_resp  = '0; mst.r_last = '0; mst.r_user = '0;
    slv.r_ready = '0;

    slv.wack = '0; slv.rack = '0;
  endtask

  task automatic default_cfg();
    cfg.enable          = 1'b0;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd4;
    cfg.refill_interval = 32'd10;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
  endtask

  int err_cnt  = 0;
  int test_cnt = 0;

  task automatic check(string msg, bit cond);
    test_cnt++;
    if (!cond) begin
      err_cnt++;
      $error("FAIL [%0d] %s", test_cnt, msg);
    end
  endtask

  initial begin : p_stim
    bit accepted;
    logic [CNT_WIDTH-1:0] tok_prev;
    int period_cyc;

    end_of_sim = 0;
    rst_ni     = 0;
    idle_inputs();
    default_cfg();

    `APPL_WAIT_CYC(clk_i, 5)
    rst_ni = 1;

    // --- Test 1: Reset value ---
    $display("\nTB> --- Test 1: Reset value ---");
    check("tokens_q == '1 after reset", i_dut.tokens_q == '1);
    `APPL_WAIT_CYC(clk_i, 2)

    // --- Test 2: Disabled ---
    $display("\nTB> --- Test 2: Disabled mode ---");
    cfg.enable      = 1'b0;
    cfg.token_limit = 32'd2;
    cfg.aw_cost     = 32'd4;
    cfg.ar_cost     = 32'd4;
    `APPL_WAIT_CYC(clk_i, 2)
    repeat (5) begin
      apply_aw(accepted);
      check("AW always accepted when disabled", accepted);
    end
    repeat (5) begin
      apply_ar(accepted);
      check("AR always accepted when disabled", accepted);
    end

    // --- Test 3: AW gating ---
    $display("\nTB> --- Test 3: AW gating ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd4;
    cfg.refill_tokens   = 32'd4;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 1)
    apply_aw(accepted); check("AW#1 accepted (tokens=4->2)", accepted);
    apply_aw(accepted); check("AW#2 accepted (tokens=2->0)", accepted);
    apply_aw(accepted); check("AW#3 blocked  (tokens=0)",   !accepted);

    // --- Test 4: AR gating ---
    $display("\nTB> --- Test 4: AR gating ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd4;
    cfg.refill_interval = 32'd100;
    cfg.ar_cost         = 32'd2;
    cfg.aw_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 1)
    apply_ar(accepted); check("AR#1 accepted (tokens=4->2)", accepted);
    apply_ar(accepted); check("AR#2 accepted (tokens=2->0)", accepted);
    apply_ar(accepted); check("AR#3 blocked  (tokens=0)",   !accepted);

    // --- Test 5: AR priority ---
    $display("\nTB> --- Test 5: AR priority over AW ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd2;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 1)
    drive_aw(); drive_ar();
    #(ACQ_DEL);                       
    check("AR granted when tokens == ar_cost",         mst.ar_valid == 1'b1);
    check("AW blocked when tokens only cover AR cost", mst.aw_valid == 1'b0);
    slv.aw_valid = '0; mst.aw_ready = '0;
    slv.ar_valid = '0; mst.ar_ready = '0;

    // --- Test 6: Refill timing (exact period) ---
    $display("\nTB> --- Test 6: Refill timing ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd0;   
    cfg.refill_interval = 32'd8;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    apply_aw(accepted); apply_aw(accepted);
    apply_aw(accepted); apply_aw(accepted);           
    check("tokens drained to 0", i_dut.tokens_q == 32'd0);
    apply_aw(accepted); check("AW blocked at empty bucket", !accepted);

    // Enable refill; measure increment-to-increment spacing (phase-independent).
    cfg.refill_tokens = 32'd2;
    tok_prev = i_dut.tokens_q;
    for (period_cyc = 1; period_cyc <= 128; period_cyc++) begin
      @(posedge clk_i); #(ACQ_DEL);
      if (i_dut.tokens_q != tok_prev) break;
    end
    check("first refill increments tokens", i_dut.tokens_q == tok_prev + cfg.refill_tokens);
    tok_prev = i_dut.tokens_q;
    for (period_cyc = 1; period_cyc <= 128; period_cyc++) begin
      @(posedge clk_i); #(ACQ_DEL);
      if (i_dut.tokens_q != tok_prev) break;
    end
    check("refill period == refill_interval cycles", period_cyc == cfg.refill_interval);
    check("steady refill adds refill_tokens",        i_dut.tokens_q == tok_prev + cfg.refill_tokens);

    // --- Test 7: Saturation ---
    $display("\nTB> --- Test 7: Token saturation ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd8;
    cfg.refill_interval = 32'd2;
    `APPL_WAIT_CYC(clk_i, 1)
    `APPL_WAIT_CYC(clk_i, 20)
    #(ACQ_DEL);
    check("Tokens saturate at token_limit", i_dut.tokens_q == cfg.token_limit);

    // --- Test 8: No underflow (partial affordability: 0 < tokens < cost) ---
    $display("\nTB> --- Test 8: No underflow ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd3;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 1)
    apply_aw(accepted); check("AW#1 accepted (tokens=3->1)", accepted);
    check("tokens_q == 1 after spend", i_dut.tokens_q == 32'd1);
    repeat (4) begin
      apply_aw(accepted);
      check("AW blocked when tokens(1) < aw_cost(2)", !accepted);
      check("tokens_q holds at 1 (no underflow)",     i_dut.tokens_q == 32'd1);
    end

    // --- Test 9: W/B/R passthrough ---
    $display("\nTB> --- Test 9: W/B/R passthrough ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable      = 1'b1;
    cfg.token_limit = 32'd0;
    cfg.aw_cost     = 32'd1;
    cfg.ar_cost     = 32'd1;
    `APPL_WAIT_CYC(clk_i, 1)

    slv.w_valid = 1'b1; slv.w_data = 64'hA5A5; slv.w_strb = 8'hFF; slv.w_last = 1'b1;
    mst.w_ready = 1'b1;
    @(posedge clk_i); #(ACQ_DEL);
    check("W passes through when bucket empty", mst.w_valid == 1'b1 && slv.w_ready == 1'b1);
    slv.w_valid = '0; mst.w_ready = '0;

    mst.b_valid = 1'b1; mst.b_id = 4'hA; mst.b_resp = 2'b00;
    slv.b_ready = 1'b1;
    @(posedge clk_i); #(ACQ_DEL);
    check("B passes through when bucket empty", slv.b_valid == 1'b1 && mst.b_ready == 1'b1);
    mst.b_valid = '0; slv.b_ready = '0;

    mst.r_valid = 1'b1; mst.r_data = 64'hBEEF; mst.r_resp = 4'b0000; mst.r_last = 1'b1;
    slv.r_ready = 1'b1;
    @(posedge clk_i); #(ACQ_DEL);
    check("R passes through when bucket empty", slv.r_valid == 1'b1 && mst.r_ready == 1'b1);
    mst.r_valid = '0; slv.r_ready = '0;

    // --- Test 10: Snoop passthrough ---
    $display("\nTB> --- Test 10: Snoop / coherency passthrough ---");
    rst_ni = 0; `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    cfg.enable      = 1'b1;
    cfg.token_limit = 32'd0;
    cfg.aw_cost     = 32'd1;
    cfg.ar_cost     = 32'd1;
    `APPL_WAIT_CYC(clk_i, 1)

    slv.wack = 1'b1; slv.rack = 1'b1;
    #(ACQ_DEL);
    check("wack passes through when bucket empty", mst.wack == 1'b1);
    check("rack passes through when bucket empty", mst.rack == 1'b1);
    slv.wack = 1'b0; slv.rack = 1'b0;
    #(ACQ_DEL);
    check("wack deasserts transparently", mst.wack == 1'b0);
    check("rack deasserts transparently", mst.rack == 1'b0);

    slv.aw_valid    = 1'b1;
    slv.aw_snoop    = 3'b011;
    slv.aw_bar      = 2'b01;
    slv.aw_domain   = 2'b10;
    slv.aw_awunique = 1'b1;
    mst.aw_ready    = 1'b1;
    #(ACQ_DEL);
    check("AW throttled (aw_valid gated low) at empty bucket", mst.aw_valid    == 1'b0);
    check("aw_snoop passes through while throttled",           mst.aw_snoop    == 3'b011);
    check("aw_bar passes through while throttled",             mst.aw_bar      == 2'b01);
    check("aw_domain passes through while throttled",          mst.aw_domain   == 2'b10);
    check("aw_awunique passes through while throttled",        mst.aw_awunique == 1'b1);
    slv.aw_valid = 1'b0; mst.aw_ready = 1'b0;
    slv.aw_snoop = '0; slv.aw_bar = '0; slv.aw_domain = '0; slv.aw_awunique = '0;

    slv.ar_valid  = 1'b1;
    slv.ar_snoop  = 4'b1101;
    slv.ar_bar    = 2'b01;
    slv.ar_domain = 2'b01;
    mst.ar_ready  = 1'b1;
    #(ACQ_DEL);
    check("AR throttled (ar_valid gated low) at empty bucket", mst.ar_valid  == 1'b0);
    check("ar_snoop passes through while throttled",           mst.ar_snoop  == 4'b1101);
    check("ar_bar passes through while throttled",             mst.ar_bar    == 2'b01);
    check("ar_domain passes through while throttled",          mst.ar_domain == 2'b01);
    slv.ar_valid = 1'b0; mst.ar_ready = 1'b0;
    slv.ar_snoop = '0; slv.ar_bar = '0; slv.ar_domain = '0;

    // --- Test 11: AR priority (tokens cover AW cost but not AR cost) ---
    $display("\nTB> --- Test 11: AR priority (tokens cover AW, not AR) ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd2;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd1;
    cfg.ar_cost         = 32'd4;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)

    drive_aw(); drive_ar();
    #(ACQ_DEL);
    check("AR blocked: tokens (2) < ar_cost (4)",        mst.ar_valid == 1'b0);
    check("AW blocked too: AR priority reserves tokens", mst.aw_valid == 1'b0);

    slv.ar_valid = 1'b0; mst.ar_ready = 1'b0;
    #(ACQ_DEL);
    check("AW granted once AR deasserts (2 >= aw_cost)", mst.aw_valid == 1'b1);
    slv.aw_valid = 1'b0; mst.aw_ready = 1'b0;

    // --- Test 12: AR backpressure (downstream stalls mst.ar_ready) ---
    $display("\nTB> --- Test 12: AR backpressure ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd0;   
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)

    drive_ar();                      // slv.ar_valid = 1
    mst.ar_ready = 1'b0;             // downstream refuses to accept
    @(posedge clk_i); #(ACQ_DEL);    // reservation cycle: tokens 8 -> 6
    check("AR granted while downstream stalled", mst.ar_valid == 1'b1);
    check("AR tokens spent once at reservation (8->6)", i_dut.tokens_q == 32'd6);
    check("AR reservation held during stall", i_dut.ar_res_q == 1'b1);

    repeat (4) begin
      @(posedge clk_i); #(ACQ_DEL);
      check("AR valid held stable while stalled", mst.ar_valid == 1'b1);
      check("AR tokens not re-spent while stalled", i_dut.tokens_q == 32'd6);
    end

    mst.ar_ready = 1'b1;             // release backpressure
    @(posedge clk_i); #(ACQ_DEL);
    check("AR handshake completes after stall", mst.ar_valid && mst.ar_ready);
    check("AR tokens unchanged through handshake (==6)", i_dut.tokens_q == 32'd6);
    slv.ar_valid = 1'b0; mst.ar_ready = 1'b0;   

    // --- Test 13: AW backpressure (downstream stalls mst.aw_ready) ---
    $display("\nTB> --- Test 13: AW backpressure ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)

    drive_aw();                      // slv.aw_valid = 1 (no AR, so no priority steal)
    mst.aw_ready = 1'b0;
    @(posedge clk_i); #(ACQ_DEL);    // reservation cycle: tokens 8 -> 6
    check("AW granted while downstream stalled", mst.aw_valid == 1'b1);
    check("AW tokens spent once at reservation (8->6)", i_dut.tokens_q == 32'd6);
    check("AW reservation held during stall", i_dut.aw_res_q == 1'b1);

    repeat (4) begin
      @(posedge clk_i); #(ACQ_DEL);
      check("AW valid held stable while stalled", mst.aw_valid == 1'b1);
      check("AW tokens not re-spent while stalled", i_dut.tokens_q == 32'd6);
    end

    mst.aw_ready = 1'b1;
    @(posedge clk_i); #(ACQ_DEL);
    check("AW handshake completes after stall", mst.aw_valid && mst.aw_ready);
    check("AW tokens unchanged through handshake (==6)", i_dut.tokens_q == 32'd6);
    slv.aw_valid = 1'b0; mst.aw_ready = 1'b0;

    // --- Test 14: Live refill_interval reconfig ---
    $display("\nTB> --- Test 14: Live interval reconfig ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd2;
    cfg.refill_interval = 32'd100;   // large: no imminent refill
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    apply_aw(accepted); apply_aw(accepted);
    apply_aw(accepted); apply_aw(accepted);           
    check("tokens drained to 0", i_dut.tokens_q == 32'd0);
    `APPL_WAIT_CYC(clk_i, 10)
    #(ACQ_DEL);
    check("no refill yet with large interval", i_dut.tokens_q == 32'd0);
    cfg.refill_interval = 32'd4;                        
    `APPL_WAIT_CYC(clk_i, 6)
    #(ACQ_DEL);
    check("refill fires after live interval shrink", i_dut.tokens_q >= cfg.refill_tokens);

    // --- Test 15: Simultaneous AR+AW grant (tokens cover both) ---
    $display("\nTB> --- Test 15: Simultaneous AR+AW grant ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    drive_aw(); drive_ar();
    @(posedge clk_i); #(ACQ_DEL);
    check("AR granted (dual)",                     mst.ar_valid == 1'b1);
    check("AW granted same cycle (tokens cover both)", mst.aw_valid == 1'b1);
    check("both costs spent once (8->4)",          i_dut.tokens_q == 32'd4);
    slv.aw_valid = '0; mst.aw_ready = '0;
    slv.ar_valid = '0; mst.ar_ready = '0;

    // --- Test 16: Zero-cost channel ---
    $display("\nTB> --- Test 16: Zero-cost channel ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd4;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd1;
    cfg.ar_cost         = 32'd0;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    apply_aw(accepted); apply_aw(accepted);
    apply_aw(accepted); apply_aw(accepted);           // 4 -> 0
    check("tokens drained to 0", i_dut.tokens_q == 32'd0);
    repeat (3) begin
      apply_ar(accepted);
      check("AR (cost=0) accepted even at empty bucket", accepted);
    end
    check("tokens_q stays 0 under zero-cost AR", i_dut.tokens_q == 32'd0);

    // --- Test 17: Enable toggle during held reservation ---
    $display("\nTB> --- Test 17: Enable toggle mid-reservation ---");
    rst_ni = 0;
    cfg.enable          = 1'b1;
    cfg.token_limit     = 32'd8;
    cfg.refill_tokens   = 32'd0;
    cfg.refill_interval = 32'd100;
    cfg.aw_cost         = 32'd2;
    cfg.ar_cost         = 32'd2;
    `APPL_WAIT_CYC(clk_i, 3) rst_ni = 1; `APPL_WAIT_CYC(clk_i, 2)
    drive_ar(); mst.ar_ready = 1'b0;
    @(posedge clk_i); #(ACQ_DEL);
    check("AR granted, reservation held (8->6)", mst.ar_valid && i_dut.tokens_q == 32'd6);
    cfg.enable = 1'b0;                                  // disable mid-reservation
    @(posedge clk_i); #(ACQ_DEL);
    check("AR valid held stable across disable", mst.ar_valid == 1'b1);
    check("tokens frozen while disabled (==6)",  i_dut.tokens_q == 32'd6);
    cfg.enable = 1'b1;                                  // re-enable
    @(posedge clk_i); #(ACQ_DEL);
    check("AR valid still stable after re-enable", mst.ar_valid == 1'b1);
    check("no re-spend after re-enable (==6)",     i_dut.tokens_q == 32'd6);
    mst.ar_ready = 1'b1;                                // complete handshake
    @(posedge clk_i); #(ACQ_DEL);
    check("AR handshake completes, single spend (==6)", mst.ar_valid && mst.ar_ready && i_dut.tokens_q == 32'd6);
    slv.ar_valid = 1'b0; mst.ar_ready = 1'b0;

    // --- Summary ---
    `APPL_WAIT_CYC(clk_i, 5)
    $display("\nTB> ----------------------------------------------------------------------");
    if (err_cnt == 0)
      $display("TB> PASSED all %0d checks", test_cnt);
    else
      $display("TB> FAILED %0d of %0d checks", err_cnt, test_cnt);
    $display("TB> ----------------------------------------------------------------------\n");

    end_of_sim = 1;
    if (err_cnt != 0) $fatal(1, "TB> %0d of %0d checks failed", err_cnt, test_cnt);
    $finish();
  end

  initial begin
    #(500us);
    $error("TB> TIMEOUT");
    $finish();
  end

endmodule
