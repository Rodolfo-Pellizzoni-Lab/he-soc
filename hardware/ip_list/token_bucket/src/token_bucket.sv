// ----------------------------------------------------------------------------
// token_bucket:
//    1. Sits between a CVA6 core and ace_spu_top in cva6_synth_wrap.
//    2. All channels except AW and AR are passed through combinationally.
//    3. Adds no latency to the ACE_BUS path.
//    4. One bucket serves both channels. 
//    5. AR has priority over AW. No throttling when bucket is disabled.
//    6. Bucket's registers are in token_bucket_cfg_regs.sv  
// ----------------------------------------------------------------------------
module token_bucket (
  input  logic                clk_i,
  input  logic                rst_ni,

  //Decoded cfg struct
  input  token_bucket_pkg::token_bucket_cfg_t  cfg_i,

  //ACE bus ports
  ACE_BUS.Slave               slv,
  ACE_BUS.Master              mst
);
  localparam int unsigned CntWidth = 32;  // Counters' width

  logic                aw_grant, ar_grant;
  logic                aw_hs, ar_hs;
  logic                aw_reserve, ar_reserve;
  logic                aw_res_q, aw_res_d;
  logic                ar_res_q, ar_res_d;
  logic [CntWidth-1:0] tokens_q, tokens_d;
  logic [CntWidth-1:0] interval_cnt_q, interval_cnt_d;
  logic [CntWidth-1:0] interval_reload;
  logic [CntWidth-1:0] refill_interval_q;
  logic                interval_changed;
  logic                refill_tick;
  logic [CntWidth:0]   add_sum;
  logic [CntWidth-1:0] avail_after_ar;
  logic [CntWidth-1:0] tokens_avail;

  // AW channel
  assign mst.aw_id       = slv.aw_id;
  assign mst.aw_addr     = slv.aw_addr;
  assign mst.aw_len      = slv.aw_len;
  assign mst.aw_size     = slv.aw_size;
  assign mst.aw_burst    = slv.aw_burst;
  assign mst.aw_lock     = slv.aw_lock;
  assign mst.aw_cache    = slv.aw_cache;
  assign mst.aw_prot     = slv.aw_prot;
  assign mst.aw_qos      = slv.aw_qos;
  assign mst.aw_region   = slv.aw_region;
  assign mst.aw_atop     = slv.aw_atop;
  assign mst.aw_user     = slv.aw_user;
  assign mst.aw_snoop    = slv.aw_snoop;
  assign mst.aw_bar      = slv.aw_bar;
  assign mst.aw_domain   = slv.aw_domain;
  assign mst.aw_awunique = slv.aw_awunique;
  assign mst.aw_valid    = slv.aw_valid && aw_grant;
  assign slv.aw_ready    = mst.aw_ready && aw_grant;

  // W channel: pass through
  assign mst.w_data  = slv.w_data;
  assign mst.w_strb  = slv.w_strb;
  assign mst.w_last  = slv.w_last;
  assign mst.w_user  = slv.w_user;
  assign mst.w_valid = slv.w_valid;
  assign slv.w_ready = mst.w_ready;

  // B channel: pass through
  assign slv.b_id    = mst.b_id;
  assign slv.b_resp  = mst.b_resp;
  assign slv.b_user  = mst.b_user;
  assign slv.b_valid = mst.b_valid;
  assign mst.b_ready = slv.b_ready;

  // AR channel
  assign mst.ar_id     = slv.ar_id;
  assign mst.ar_addr   = slv.ar_addr;
  assign mst.ar_len    = slv.ar_len;
  assign mst.ar_size   = slv.ar_size;
  assign mst.ar_burst  = slv.ar_burst;
  assign mst.ar_lock   = slv.ar_lock;
  assign mst.ar_cache  = slv.ar_cache;
  assign mst.ar_prot   = slv.ar_prot;
  assign mst.ar_qos    = slv.ar_qos;
  assign mst.ar_region = slv.ar_region;
  assign mst.ar_user   = slv.ar_user;
  assign mst.ar_snoop  = slv.ar_snoop;
  assign mst.ar_bar    = slv.ar_bar;
  assign mst.ar_domain = slv.ar_domain;
  assign mst.ar_valid  = slv.ar_valid && ar_grant;
  assign slv.ar_ready  = mst.ar_ready && ar_grant;

  // R channel: pass through
  assign slv.r_id    = mst.r_id;
  assign slv.r_data  = mst.r_data;
  assign slv.r_resp  = mst.r_resp;
  assign slv.r_last  = mst.r_last;
  assign slv.r_user  = mst.r_user;
  assign slv.r_valid = mst.r_valid;
  assign mst.r_ready = slv.r_ready;

  // ACE: pass through
  assign mst.wack = slv.wack;
  assign mst.rack = slv.rack;

  // ---------------------------------------------------------------
  // Token bucket logic
  // ---------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tokens_q          <= '1;  //Start full so core can transact immediately
      interval_cnt_q    <= '0;
      refill_interval_q <= '0;
      //Reservation Regs
      aw_res_q          <= 1'b0;
      ar_res_q          <= 1'b0;
    end else begin
      tokens_q          <= tokens_d;
      interval_cnt_q    <= interval_cnt_d;
      refill_interval_q <= cfg_i.refill_interval;
      //Reservation regs
      aw_res_q          <= aw_res_d;
      ar_res_q          <= ar_res_d;
    end
  end
  //mst.aw_valid and mst.ar_valid are gated above. 
  assign aw_hs = mst.aw_valid && mst.aw_ready; //aw_handshake. 
  assign ar_hs = mst.ar_valid && mst.ar_ready; //ar_handshake. 

  // A new refill_interval takes effect immediately
  assign interval_changed = (cfg_i.refill_interval != refill_interval_q);

  // Reload N-1 so the period between refill ticks is exactly refill_interval
  // cycles and not refill_interval+1.
  assign interval_reload = (cfg_i.refill_interval == '0) ? '0
                                                         : (cfg_i.refill_interval - 1'b1);

  always_comb begin
    if (!cfg_i.enable || interval_cnt_q == '0 || interval_changed)
      interval_cnt_d = interval_reload; //If bucket is disabled, no throttling.
    else
      interval_cnt_d = interval_cnt_q - 1'b1; //Interval counter
  end

  assign refill_tick = cfg_i.enable && (interval_cnt_q == '0); //Refill condition
  assign add_sum = refill_tick ? (tokens_q + cfg_i.refill_tokens) : tokens_q; //Calculates required total token count after refill

  assign tokens_avail = (add_sum > cfg_i.token_limit) ? cfg_i.token_limit : add_sum[CntWidth-1:0]; 

  // Reservation Mechanism. Claim tokens at admission, held until handshake. AR has priority.
  always_comb begin
    ar_reserve     = 1'b0;
    aw_reserve     = 1'b0;
    avail_after_ar = tokens_avail;

    if (cfg_i.enable) begin
      if (slv.ar_valid && !ar_res_q) begin
        if (tokens_avail >= cfg_i.ar_cost) begin
          ar_reserve     = 1'b1;
          avail_after_ar = tokens_avail - cfg_i.ar_cost;
        end else begin
          avail_after_ar = '0; //not enough for AR; hold AW back to keep AR priority
        end
      end
      if (slv.aw_valid && !aw_res_q && (avail_after_ar >= cfg_i.aw_cost))
        aw_reserve = 1'b1;
    end
  end

  // A beat is admitted while it is reserving now or holding a reservation.
  assign ar_grant = !cfg_i.enable || ar_res_q || ar_reserve;
  assign aw_grant = !cfg_i.enable || aw_res_q || aw_reserve;

  // Hold from admission to handshake; tracks mst.*_valid so enable toggles are safe.
  assign ar_res_d = mst.ar_valid && !ar_hs;
  assign aw_res_d = mst.aw_valid && !aw_hs;

  // Tokens are spent once, at the cycle of reservation.
  always_comb begin
    if (!cfg_i.enable)
      tokens_d = tokens_q;
    else
      tokens_d = tokens_avail
                 - (ar_reserve ? cfg_i.ar_cost : '0)
                 - (aw_reserve ? cfg_i.aw_cost : '0);
  end

  // pragma translate_off
  `ifndef VERILATOR
  // valid-stability
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (mst.aw_valid && !mst.aw_ready |=> mst.aw_valid));
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (mst.ar_valid && !mst.ar_ready |=> mst.ar_valid));
  // reserve only when affordable
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (ar_reserve |-> tokens_avail   >= cfg_i.ar_cost));
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (aw_reserve |-> avail_after_ar >= cfg_i.aw_cost));
  // no underflow
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (cfg_i.enable |-> tokens_d <= tokens_avail));
  // no double-spend
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (ar_res_q |-> !ar_reserve));
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (aw_res_q |-> !aw_reserve));
  `endif
  // pragma translate_on

endmodule
