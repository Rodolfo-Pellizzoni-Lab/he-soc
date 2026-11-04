module slowdown_mem_top #(
    parameter int unsigned Latency_param = 0, // needs to >= 2
    parameter int unsigned Throughput_timer_param = 10,
    parameter int unsigned Throughput_FIFO_depth = 8
    // parameter int unsigned Throughput_COUNTER_WIDTH = 4
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    AXI_BUS.Slave                   slowdown_mem_slv,
    AXI_BUS.Master                  slowdown_mem_mst
);

    
    localparam int unsigned Throughput_COUNTER_WIDTH = $clog2(Throughput_timer_param + 1);
    

    // B Channel — the whole response (payload + valid + ready) is delayed by the
    // handshake-aware latency pipeline below, so the delayed b_valid stays aligned
    // with its b_id/b_resp/b_user and no response is dropped/duplicated/mismatched.
    ariane_axi_soc::b_chan_slv_mem_t b_in, b_out;
    assign b_in.id   = slowdown_mem_mst.b_id;
    assign b_in.resp = slowdown_mem_mst.b_resp;
    assign b_in.user = slowdown_mem_mst.b_user;
    assign slowdown_mem_slv.b_id   = b_out.id;
    assign slowdown_mem_slv.b_resp = b_out.resp;
    assign slowdown_mem_slv.b_user = b_out.user;

    
    ariane_axi_soc::r_chan_slv_mem_t r_in;
    assign r_in.id    = slowdown_mem_mst.r_id;
    assign r_in.data  = slowdown_mem_mst.r_data;
    assign r_in.resp  = slowdown_mem_mst.r_resp;
    assign r_in.last  = slowdown_mem_mst.r_last;
    assign r_in.user  = slowdown_mem_mst.r_user;

    ariane_axi_soc::r_chan_slv_mem_t r_out;
    assign slowdown_mem_slv.r_id   = r_out.id;
    assign slowdown_mem_slv.r_data = r_out.data;
    assign slowdown_mem_slv.r_resp = r_out.resp;
    assign slowdown_mem_slv.r_last = r_out.last;
    assign slowdown_mem_slv.r_user = r_out.user;


    latency_b_chan #(
        .Latency_param  (Latency_param)
    ) i_B_chan_valid_delayed (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .b_valid          (slowdown_mem_mst.b_valid),
        .b_ready_delayed  (slowdown_mem_mst.b_ready),
        .b_signals        (b_in),
        .b_valid_delayed  (slowdown_mem_slv.b_valid),
        .b_ready          (slowdown_mem_slv.b_ready),
        .b_signals_delayed(b_out)
    );

    latency_r_chan #(
        .Latency_param  (Latency_param)
    ) i_R_chan_valid_delayed (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .r_valid(slowdown_mem_mst.r_valid),
        .r_valid_delayed(slowdown_mem_slv.r_valid),
        .r_ready(slowdown_mem_slv.r_ready),
        .r_ready_delayed(slowdown_mem_mst.r_ready),
        .r_signals(r_in),
        .r_signals_delayed(r_out)
    );


    ariane_axi_soc::ar_chan_slv_mem_t ar_signals_in;
    assign ar_signals_in.id     = slowdown_mem_slv.ar_id;
    assign ar_signals_in.addr   = slowdown_mem_slv.ar_addr;
    assign ar_signals_in.len    = slowdown_mem_slv.ar_len;
    assign ar_signals_in.size   = slowdown_mem_slv.ar_size;
    assign ar_signals_in.burst  = slowdown_mem_slv.ar_burst;
    assign ar_signals_in.lock   = slowdown_mem_slv.ar_lock;
    assign ar_signals_in.cache  = slowdown_mem_slv.ar_cache;
    assign ar_signals_in.prot   = slowdown_mem_slv.ar_prot;
    assign ar_signals_in.qos    = slowdown_mem_slv.ar_qos;
    assign ar_signals_in.region = slowdown_mem_slv.ar_region;
    assign ar_signals_in.user   = slowdown_mem_slv.ar_user;

    ariane_axi_soc::ar_chan_slv_mem_t ar_signals_out;
    assign slowdown_mem_mst.ar_id     = ar_signals_out.id;
    assign slowdown_mem_mst.ar_addr   = ar_signals_out.addr;
    assign slowdown_mem_mst.ar_len    = ar_signals_out.len;
    assign slowdown_mem_mst.ar_size   = ar_signals_out.size;
    assign slowdown_mem_mst.ar_burst  = ar_signals_out.burst;
    assign slowdown_mem_mst.ar_lock   = ar_signals_out.lock;
    assign slowdown_mem_mst.ar_cache  = ar_signals_out.cache;
    assign slowdown_mem_mst.ar_prot   = ar_signals_out.prot;
    assign slowdown_mem_mst.ar_qos    = ar_signals_out.qos;
    assign slowdown_mem_mst.ar_region = ar_signals_out.region;
    assign slowdown_mem_mst.ar_user   = ar_signals_out.user;

    ariane_axi_soc::aw_chan_slv_mem_t aw_signals_in;
    assign aw_signals_in.id = slowdown_mem_slv.aw_id;
    assign aw_signals_in.addr = slowdown_mem_slv.aw_addr;
    assign aw_signals_in.len = slowdown_mem_slv.aw_len;
    assign aw_signals_in.size = slowdown_mem_slv.aw_size;
    assign aw_signals_in.burst = slowdown_mem_slv.aw_burst;
    assign aw_signals_in.lock = slowdown_mem_slv.aw_lock;
    assign aw_signals_in.cache = slowdown_mem_slv.aw_cache;
    assign aw_signals_in.prot = slowdown_mem_slv.aw_prot;
    assign aw_signals_in.qos = slowdown_mem_slv.aw_qos;
    assign aw_signals_in.region = slowdown_mem_slv.aw_region;
    assign aw_signals_in.atop = slowdown_mem_slv.aw_atop;
    assign aw_signals_in.user = slowdown_mem_slv.aw_user;

    ariane_axi_soc::aw_chan_slv_mem_t aw_signals_out;
    assign slowdown_mem_mst.aw_id     = aw_signals_out.id;
    assign slowdown_mem_mst.aw_addr   = aw_signals_out.addr;
    assign slowdown_mem_mst.aw_len    = aw_signals_out.len;
    assign slowdown_mem_mst.aw_size   = aw_signals_out.size;
    assign slowdown_mem_mst.aw_burst  = aw_signals_out.burst;
    assign slowdown_mem_mst.aw_lock   = aw_signals_out.lock;
    assign slowdown_mem_mst.aw_cache  = aw_signals_out.cache;
    assign slowdown_mem_mst.aw_prot   = aw_signals_out.prot;
    assign slowdown_mem_mst.aw_qos    = aw_signals_out.qos;
    assign slowdown_mem_mst.aw_region = aw_signals_out.region;
    assign slowdown_mem_mst.aw_atop   = aw_signals_out.atop;
    assign slowdown_mem_mst.aw_user   = aw_signals_out.user;

    ariane_axi_soc::w_chan_t dw_signals_in;
    assign dw_signals_in.data =  slowdown_mem_slv.w_data;
    assign dw_signals_in.strb =  slowdown_mem_slv.w_strb;
    assign dw_signals_in.last =  slowdown_mem_slv.w_last;
    assign dw_signals_in.user =  slowdown_mem_slv.w_user;

    ariane_axi_soc::w_chan_t dw_signals_out;
    assign slowdown_mem_mst.w_data  = dw_signals_out.data;
    assign slowdown_mem_mst.w_strb  = dw_signals_out.strb;
    assign slowdown_mem_mst.w_last  = dw_signals_out.last;
    assign slowdown_mem_mst.w_user  = dw_signals_out.user;

    throughput_regulator #(
    .Throughput_timer_param(Throughput_timer_param),
    .Throughput_FIFO_depth(Throughput_FIFO_depth),
    .Throughput_COUNTER_WIDTH(Throughput_COUNTER_WIDTH)
) i_throughput_regulator
 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    // AW channel signals:
    .aw_valid_i(slowdown_mem_slv.aw_valid),
    .aw_signals_i(aw_signals_in),
    .aw_ready_o(slowdown_mem_slv.aw_ready),
    .aw_valid_o(slowdown_mem_mst.aw_valid),
    .aw_signals_o(aw_signals_out),
    .aw_ready_i(slowdown_mem_mst.aw_ready),
    // AR channel signals
    .ar_valid_i(slowdown_mem_slv.ar_valid),
    .ar_signals_i(ar_signals_in),
    .ar_ready_o(slowdown_mem_slv.ar_ready),
    .ar_valid_o(slowdown_mem_mst.ar_valid),
    .ar_signals_o(ar_signals_out),
    .ar_ready_i(slowdown_mem_mst.ar_ready),
    // DW channel signals
    .dw_valid_i(slowdown_mem_slv.w_valid),
    .dw_signals_i(dw_signals_in),
    .dw_ready_o(slowdown_mem_slv.w_ready),
    .dw_valid_o(slowdown_mem_mst.w_valid),
    .dw_signals_o(dw_signals_out),
    .dw_ready_i(slowdown_mem_mst.w_ready),
    // debugging port
    .ar_valid_o_reg(),
    .aw_valid_o_reg(),
    .dw_valid_o_reg()
);

// pragma translate_off
  // ==========================================================================
  // Slowdown IP AXI protocol + drop/duplication checker  (SIMULATION ONLY)
  //   request  path (slave -> master): AR / AW / W   (throughput regulator)
  //   response path (master -> slave): R  / B        (latency injectors)
  // Detects: dropped / duplicated transactions, AXI valid/payload-stability
  // violations, and addresses released closer than the throttle allows.
  // Procedural checks reporting with $error, not concurrent assertions: the
  // xsim flow elaborates with --ignore_assertions, which would remove them.
  // "in"  = handshake where a beat ARRIVES at the IP boundary
  // "out" = handshake where a beat LEAVES the IP boundary
  // ==========================================================================
  wire ck_ar_in  = slowdown_mem_slv.ar_valid & slowdown_mem_slv.ar_ready;
  wire ck_ar_out = slowdown_mem_mst.ar_valid & slowdown_mem_mst.ar_ready;
  wire ck_aw_in  = slowdown_mem_slv.aw_valid & slowdown_mem_slv.aw_ready;
  wire ck_aw_out = slowdown_mem_mst.aw_valid & slowdown_mem_mst.aw_ready;
  wire ck_w_in   = slowdown_mem_slv.w_valid  & slowdown_mem_slv.w_ready;
  wire ck_w_out  = slowdown_mem_mst.w_valid  & slowdown_mem_mst.w_ready;
  wire ck_r_in   = slowdown_mem_mst.r_valid  & slowdown_mem_mst.r_ready;
  wire ck_r_out  = slowdown_mem_slv.r_valid  & slowdown_mem_slv.r_ready;
  wire ck_b_in   = slowdown_mem_mst.b_valid  & slowdown_mem_mst.b_ready;
  wire ck_b_out  = slowdown_mem_slv.b_valid  & slowdown_mem_slv.b_ready;

  longint unsigned ck_ar_i, ck_ar_o, ck_aw_i, ck_aw_o, ck_w_i, ck_w_o;
  longint unsigned ck_r_i,  ck_r_o,  ck_b_i,  ck_b_o;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ck_ar_i<=0; ck_ar_o<=0; ck_aw_i<=0; ck_aw_o<=0; ck_w_i<=0; ck_w_o<=0;
      ck_r_i <=0; ck_r_o <=0; ck_b_i <=0; ck_b_o <=0;
    end else begin
      ck_ar_i <= ck_ar_i + ck_ar_in;   ck_ar_o <= ck_ar_o + ck_ar_out;
      ck_aw_i <= ck_aw_i + ck_aw_in;   ck_aw_o <= ck_aw_o + ck_aw_out;
      ck_w_i  <= ck_w_i  + ck_w_in;    ck_w_o  <= ck_w_o  + ck_w_out;
      ck_r_i  <= ck_r_i  + ck_r_in;    ck_r_o  <= ck_r_o  + ck_r_out;
      ck_b_i  <= ck_b_i  + ck_b_in;    ck_b_o  <= ck_b_o  + ck_b_out;
    end
  end

  // Bounds on legal in-flight (internal buffering). Exceeding => beats are lost.
  localparam int unsigned CK_ADDR_MAX = 2 * Throughput_FIFO_depth;  // AR FIFO + AW FIFO
  localparam int unsigned CK_W_MAX    = Throughput_FIFO_depth + 8; // write-data FIFO
  localparam int unsigned CK_RESP_MAX = Latency_param        + 8;  // latency shift depth
  // Closest legal downstream address handshakes: the counter reloads to
  // Throughput_timer_param-1 on an accept, and the address granted when it
  // reaches 0 is offered one cycle later.
  localparam int unsigned CK_ADDR_GAP = Throughput_timer_param + 1;
  localparam int unsigned CK_ERR_SHOW = 20;   // violations printed; later ones are only counted

  int unsigned     ck_err_n  = 0;   // violations, for the end-of-sim summary
  longint unsigned ck_araw_n = 0;   // same-cycle AR+AW intakes: legal (separate AR/AW FIFOs), counted for the summary

  task automatic ck_fail(input string msg);
    ck_err_n++;
    if (ck_err_n <= CK_ERR_SHOW) $error("[slowdown] %s", msg);
  endtask

  // VALID without READY in the previous cycle, and the payload then (stability checks)
  logic ck_hold_slv_ar, ck_hold_slv_aw, ck_hold_slv_w, ck_hold_mst_ar, ck_hold_mst_aw, ck_hold_mst_w;
  logic ck_hold_mst_r, ck_hold_slv_r, ck_hold_mst_b, ck_hold_slv_b;
  ariane_axi_soc::ar_chan_slv_mem_t ck_ar_pl_q;
  ariane_axi_soc::aw_chan_slv_mem_t ck_aw_pl_q;
  ariane_axi_soc::w_chan_t          ck_w_pl_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ck_hold_slv_ar <= 1'b0; ck_hold_slv_aw <= 1'b0; ck_hold_slv_w <= 1'b0;
      ck_hold_mst_ar <= 1'b0; ck_hold_mst_aw <= 1'b0; ck_hold_mst_w <= 1'b0;
      ck_hold_mst_r  <= 1'b0; ck_hold_slv_r  <= 1'b0; ck_hold_mst_b <= 1'b0; ck_hold_slv_b <= 1'b0;
    end else begin
      ck_hold_slv_ar <= slowdown_mem_slv.ar_valid & ~slowdown_mem_slv.ar_ready;
      ck_hold_slv_aw <= slowdown_mem_slv.aw_valid & ~slowdown_mem_slv.aw_ready;
      ck_hold_slv_w  <= slowdown_mem_slv.w_valid  & ~slowdown_mem_slv.w_ready;
      ck_hold_mst_ar <= slowdown_mem_mst.ar_valid & ~slowdown_mem_mst.ar_ready;
      ck_hold_mst_aw <= slowdown_mem_mst.aw_valid & ~slowdown_mem_mst.aw_ready;
      ck_hold_mst_w  <= slowdown_mem_mst.w_valid  & ~slowdown_mem_mst.w_ready;
      ck_hold_mst_r  <= slowdown_mem_mst.r_valid  & ~slowdown_mem_mst.r_ready;
      ck_hold_slv_r  <= slowdown_mem_slv.r_valid  & ~slowdown_mem_slv.r_ready;
      ck_hold_mst_b  <= slowdown_mem_mst.b_valid  & ~slowdown_mem_mst.b_ready;
      ck_hold_slv_b  <= slowdown_mem_slv.b_valid  & ~slowdown_mem_slv.b_ready;
    end
  end
  always_ff @(posedge clk_i) begin
    ck_ar_pl_q <= ar_signals_out;
    ck_aw_pl_q <= aw_signals_out;
    ck_w_pl_q  <= dw_signals_out;
  end

  always @(posedge clk_i) if (rst_ni) begin
    // --- no duplication / spurious output: leaves must never exceed arrivals ---
    if (ck_ar_o > ck_ar_i) ck_fail($sformatf("AR duplicated/spurious: out=%0d > in=%0d", ck_ar_o, ck_ar_i));
    if (ck_aw_o > ck_aw_i) ck_fail($sformatf("AW duplicated/spurious: out=%0d > in=%0d", ck_aw_o, ck_aw_i));
    if (ck_w_o  > ck_w_i)  ck_fail($sformatf("W duplicated/spurious: out=%0d > in=%0d",  ck_w_o,  ck_w_i));
    if (ck_r_o  > ck_r_i)  ck_fail($sformatf("R duplicated/spurious: out=%0d > in=%0d",  ck_r_o,  ck_r_i));
    if (ck_b_o  > ck_b_i)  ck_fail($sformatf("B duplicated/spurious: out=%0d > in=%0d",  ck_b_o,  ck_b_i));

    // --- no drop: in-flight cannot exceed internal buffering ---
    if ((ck_ar_i-ck_ar_o)+(ck_aw_i-ck_aw_o) > CK_ADDR_MAX)
      ck_fail($sformatf("address in-flight=%0d > %0d => DROPPED request(s). AR in/out=%0d/%0d AW in/out=%0d/%0d",
        (ck_ar_i-ck_ar_o)+(ck_aw_i-ck_aw_o), CK_ADDR_MAX, ck_ar_i, ck_ar_o, ck_aw_i, ck_aw_o));
    if (ck_w_i-ck_w_o > CK_W_MAX)
      ck_fail($sformatf("W in-flight=%0d > %0d => DROPPED write beat(s). in/out=%0d/%0d", (ck_w_i-ck_w_o), CK_W_MAX, ck_w_i, ck_w_o));
    if (ck_r_i-ck_r_o > CK_RESP_MAX)
      ck_fail($sformatf("R in-flight=%0d > %0d => DROPPED read-data beat(s). in/out=%0d/%0d", (ck_r_i-ck_r_o), CK_RESP_MAX, ck_r_i, ck_r_o));
    if (ck_b_i-ck_b_o > CK_RESP_MAX)
      ck_fail($sformatf("B in-flight=%0d > %0d => DROPPED write response(s). in/out=%0d/%0d", (ck_b_i-ck_b_o), CK_RESP_MAX, ck_b_i, ck_b_o));

    // --- AXI valid-stability: once VALID & !READY, VALID must hold next cycle ---
    if (ck_hold_slv_ar && !slowdown_mem_slv.ar_valid) ck_fail("slave AR valid dropped before ready");
    if (ck_hold_slv_aw && !slowdown_mem_slv.aw_valid) ck_fail("slave AW valid dropped before ready");
    if (ck_hold_slv_w  && !slowdown_mem_slv.w_valid)  ck_fail("slave W valid dropped before ready");
    if (ck_hold_mst_ar && !slowdown_mem_mst.ar_valid) ck_fail("master AR valid dropped before ready");
    if (ck_hold_mst_aw && !slowdown_mem_mst.aw_valid) ck_fail("master AW valid dropped before ready");
    if (ck_hold_mst_w  && !slowdown_mem_mst.w_valid)  ck_fail("master W valid dropped before ready");
    if (ck_hold_mst_r  && !slowdown_mem_mst.r_valid)  ck_fail("master R valid dropped before ready");
    if (ck_hold_slv_r  && !slowdown_mem_slv.r_valid)  ck_fail("slave R valid dropped before ready (latency path)");
    if (ck_hold_mst_b  && !slowdown_mem_mst.b_valid)  ck_fail("master B valid dropped before ready");
    if (ck_hold_slv_b  && !slowdown_mem_slv.b_valid)  ck_fail("slave B valid dropped before ready (latency path)");

    // --- payload stability: while VALID held (not yet READY), payload must not change ---
    if (ck_hold_mst_ar && ar_signals_out != ck_ar_pl_q) ck_fail("mst AR payload changed while VALID held (payload instability)");
    if (ck_hold_mst_aw && aw_signals_out != ck_aw_pl_q) ck_fail("mst AW payload changed while VALID held (payload instability)");
    if (ck_hold_mst_w  && dw_signals_out != ck_w_pl_q)  ck_fail("mst W payload changed while VALID held (payload instability)");

    // --- a same-cycle AR+AW intake is legal: each lands in its own FIFO; counted for the summary ---
    if (ck_ar_in && ck_aw_in) ck_araw_n++;
  end

  // ==========================================================================
  // LIVE TRACER + HEARTBEAT + STALL WATCHDOG   (SIMULATION ONLY)
  //   Makes the regulator observable in the full-platform sim like a core trace.
  //   * +SLOWDOWN_TRACE=<file> : every downstream release + a periodic FULL-state
  //                          heartbeat (so progress/rate is visible while the
  //                          UART is silent during the traffic phase). Off by
  //                          default: runs share the xsim work directory, so a
  //                          fixed name was truncated and spliced by parallel runs.
  //   * transcript         : a rare liveness beat + a LOUD, self-diagnosing
  //                          STALL report naming exactly which side is stuck ->
  //                          tells SW-vs-HW at a glance.
  // ==========================================================================
  localparam int unsigned SD_HB_FILE   = 2000;    // file state-dump cadence (cyc)
  localparam int unsigned SD_HB_LOUD   = 200000;  // transcript liveness cadence
  localparam int unsigned SD_STALL_LIM = 20000;   // busy + no-handshake => shout

  integer          sd_fd = 0;         // trace file, 0 = no trace
  string           sd_trace_fn;
  longint unsigned sd_cycle;
  longint unsigned sd_last_hs;        // cycle of last ANY boundary handshake
  longint unsigned sd_last_addr_hs;   // cycle of last downstream AR/AW handshake

  wire sd_any_hs = ck_ar_in|ck_ar_out|ck_aw_in|ck_aw_out|ck_w_in|ck_w_out
                 | ck_r_in|ck_r_out|ck_b_in|ck_b_out;
  wire [31:0] sd_infl_addr = (ck_ar_i-ck_ar_o)+(ck_aw_i-ck_aw_o);
  // "busy" = the IP still owes work OR is being offered work at either boundary
  wire sd_busy = (sd_infl_addr!=0) | (ck_w_i!=ck_w_o) | (ck_r_i!=ck_r_o) | (ck_b_i!=ck_b_o)
               | slowdown_mem_slv.ar_valid | slowdown_mem_slv.aw_valid | slowdown_mem_slv.w_valid
               | slowdown_mem_mst.r_valid  | slowdown_mem_mst.b_valid;

  initial begin
    if ($value$plusargs("SLOWDOWN_TRACE=%s", sd_trace_fn)) begin
      sd_fd = $fopen(sd_trace_fn,"w");
      if (sd_fd == 0) $warning("[slowdown] cannot open the trace file %s", sd_trace_fn);
    end
    if (sd_fd != 0) begin
      $fwrite(sd_fd,"# slowdown tracer  Latency=%0d Throughput=%0d FIFO=%0d\n",
              Latency_param, Throughput_timer_param, Throughput_FIFO_depth);
      $fwrite(sd_fd,"# <time> <event> <detail>   (HB = periodic full-state heartbeat)\n");
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin sd_cycle<=0; sd_last_hs<=0; sd_last_addr_hs<=0; end
    else begin
      sd_cycle <= sd_cycle + 1;
      if (sd_any_hs)             sd_last_hs      <= sd_cycle;
      if (ck_ar_out | ck_aw_out) sd_last_addr_hs <= sd_cycle;
    end
  end

  // per-transaction trace: downstream releases + upstream completions
  always_ff @(posedge clk_i) if (rst_ni && sd_fd != 0) begin
    if (ck_ar_out) $fwrite(sd_fd,"%0t AR->mem id=%0d addr=%h len=%0d\n",$time,slowdown_mem_mst.ar_id,slowdown_mem_mst.ar_addr,slowdown_mem_mst.ar_len);
    if (ck_aw_out) $fwrite(sd_fd,"%0t AW->mem id=%0d addr=%h len=%0d\n",$time,slowdown_mem_mst.aw_id,slowdown_mem_mst.aw_addr,slowdown_mem_mst.aw_len);
    if (ck_w_out && slowdown_mem_mst.w_last) $fwrite(sd_fd,"%0t W ->mem (burst last)\n",$time);
    if (ck_r_out && slowdown_mem_slv.r_last) $fwrite(sd_fd,"%0t R ->llc id=%0d (burst last)\n",$time,slowdown_mem_slv.r_id);
    if (ck_b_out) $fwrite(sd_fd,"%0t B ->llc id=%0d\n",$time,slowdown_mem_slv.b_id);
  end

  // periodic FULL-state heartbeat to the file (progress + internal state visible)
  always_ff @(posedge clk_i) if (rst_ni && sd_fd != 0 && (sd_cycle % SD_HB_FILE == 0)) begin
    $fwrite(sd_fd,
      "%0t HB cyc=%0d ARio=%0d/%0d AWio=%0d/%0d Wio=%0d/%0d Rio=%0d/%0d Bio=%0d/%0d inflA=%0d | rd=%0d wr=%0d awsent=%0b wdone=%0b wbeats=%0d thr=%0d arFull=%0b awFull=%0b dwEmpty=%0b | slvV(ar%0b aw%0b w%0b) mstRdy(ar%0b aw%0b w%0b) rspV(r%0b b%0b)\n",
      $time, sd_cycle,
      ck_ar_i,ck_ar_o, ck_aw_i,ck_aw_o, ck_w_i,ck_w_o, ck_r_i,ck_r_o, ck_b_i,ck_b_o, sd_infl_addr,
      i_throughput_regulator.rd_q, i_throughput_regulator.wr_q,
      i_throughput_regulator.aw_sent_q, i_throughput_regulator.w_done_q,
      i_throughput_regulator.w_beats_left_q, i_throughput_regulator.period_cnt,
      i_throughput_regulator.ar_fifo_full, i_throughput_regulator.aw_fifo_full, i_throughput_regulator.dw_fifo_empty,
      slowdown_mem_slv.ar_valid, slowdown_mem_slv.aw_valid, slowdown_mem_slv.w_valid,
      slowdown_mem_mst.ar_ready, slowdown_mem_mst.aw_ready, slowdown_mem_mst.w_ready,
      slowdown_mem_mst.r_valid, slowdown_mem_mst.b_valid);
    $fflush(sd_fd);
  end

  // rare liveness beat to the transcript (main log shows the IP is progressing)
  always_ff @(posedge clk_i) if (rst_ni && sd_cycle!=0 && (sd_cycle % SD_HB_LOUD == 0))
    $display("[slowdown][%0t] alive: releases ARo=%0d AWo=%0d Wo=%0d | responses Ro=%0d Bo=%0d | inflight(addr=%0d W=%0d R=%0d B=%0d)",
      $time, ck_ar_o, ck_aw_o, ck_w_o, ck_r_o, ck_b_o,
      sd_infl_addr, ck_w_i-ck_w_o, ck_r_i-ck_r_o, ck_b_i-ck_b_o);

  // STALL WATCHDOG: busy but NO boundary handshake for SD_STALL_LIM cycles =>
  // shout (re-shouting every SD_STALL_LIM) with the exact state so the culprit
  // side (SW upstream idle / memory downstream stalled / regulator wedged) is named.
  always_ff @(posedge clk_i) if (rst_ni && sd_busy
        && (sd_cycle - sd_last_hs >= SD_STALL_LIM)
        && ((sd_cycle - sd_last_hs) % SD_STALL_LIM == 0)) begin
    $display("[slowdown][%0t] *** STALL *** no boundary handshake for %0d cyc while BUSY", $time, sd_cycle - sd_last_hs);
    $display("   inflight: addr=%0d W=%0d R=%0d B=%0d | rd_q=%0d wr_q=%0d aw_sent=%0b w_done=%0b wbeats=%0d thr_cnt=%0d",
      sd_infl_addr, ck_w_i-ck_w_o, ck_r_i-ck_r_o, ck_b_i-ck_b_o,
      i_throughput_regulator.rd_q, i_throughput_regulator.wr_q,
      i_throughput_regulator.aw_sent_q, i_throughput_regulator.w_done_q,
      i_throughput_regulator.w_beats_left_q, i_throughput_regulator.period_cnt);
    $display("   UPSTREAM(slv) ar(v%0b r%0b) aw(v%0b r%0b) w(v%0b r%0b last%0b) r(v%0b r%0b) b(v%0b r%0b)",
      slowdown_mem_slv.ar_valid,slowdown_mem_slv.ar_ready, slowdown_mem_slv.aw_valid,slowdown_mem_slv.aw_ready,
      slowdown_mem_slv.w_valid,slowdown_mem_slv.w_ready,slowdown_mem_slv.w_last,
      slowdown_mem_slv.r_valid,slowdown_mem_slv.r_ready, slowdown_mem_slv.b_valid,slowdown_mem_slv.b_ready);
    $display("   DOWNSTR(mst)  ar(v%0b r%0b) aw(v%0b r%0b) w(v%0b r%0b last%0b) r(v%0b r%0b) b(v%0b r%0b)",
      slowdown_mem_mst.ar_valid,slowdown_mem_mst.ar_ready, slowdown_mem_mst.aw_valid,slowdown_mem_mst.aw_ready,
      slowdown_mem_mst.w_valid,slowdown_mem_mst.w_ready,slowdown_mem_mst.w_last,
      slowdown_mem_mst.r_valid,slowdown_mem_mst.r_ready, slowdown_mem_mst.b_valid,slowdown_mem_mst.b_ready);
    if (sd_fd != 0) begin
      $fwrite(sd_fd,"%0t STALL: no hs for %0d cyc while busy (rd=%0d wr=%0d thr=%0d infA=%0d)\n",
        $time, sd_cycle - sd_last_hs, i_throughput_regulator.rd_q, i_throughput_regulator.wr_q,
        i_throughput_regulator.period_cnt, sd_infl_addr);
      $fflush(sd_fd);
    end
  end

  // throttle spacing: one downstream address handshake at a time, CK_ADDR_GAP cycles apart at the least
  always @(posedge clk_i) if (rst_ni) begin
    if (ck_ar_out && ck_aw_out)
      ck_fail("THROTTLE VIOLATION: AR and AW released downstream in the same cycle");
    else if ((ck_ar_out|ck_aw_out) && sd_last_addr_hs!=0 && (sd_cycle - sd_last_addr_hs) < CK_ADDR_GAP)
      ck_fail($sformatf("THROTTLE VIOLATION: address handshakes only %0d cyc apart (< %0d)",
        sd_cycle - sd_last_addr_hs, CK_ADDR_GAP));
  end

  // --- end-of-sim transaction summary ---
  final begin
    $display("================ slowdown IP transaction summary ================");
    $display("  AR  in/out = %0d / %0d   (in-flight %0d)", ck_ar_i, ck_ar_o, ck_ar_i-ck_ar_o);
    $display("  AW  in/out = %0d / %0d   (in-flight %0d)", ck_aw_i, ck_aw_o, ck_aw_i-ck_aw_o);
    $display("  W   in/out = %0d / %0d   (in-flight %0d)", ck_w_i,  ck_w_o,  ck_w_i-ck_w_o);
    $display("  R   in/out = %0d / %0d   (in-flight %0d)", ck_r_i,  ck_r_o,  ck_r_i-ck_r_o);
    $display("  B   in/out = %0d / %0d   (in-flight %0d)", ck_b_i,  ck_b_o,  ck_b_i-ck_b_o);
    $display("  AR+AW accepted in the same cycle: %0d (separate AR/AW FIFOs, not a conflict)", ck_araw_n);
    if (ck_ar_i!=ck_ar_o || ck_aw_i!=ck_aw_o || ck_w_i!=ck_w_o || ck_r_i!=ck_r_o || ck_b_i!=ck_b_o) begin
      // still inside after SD_STALL_LIM cycles without any handshake: lost or stuck, not in flight
      if (sd_cycle - sd_last_hs >= SD_STALL_LIM) begin
        ck_err_n++;
        $error("[slowdown] *** imbalance with no handshake for %0d cyc before the end: AR %0d, AW %0d, W %0d, R %0d, B %0d never left the IP",
          sd_cycle - sd_last_hs, ck_ar_i-ck_ar_o, ck_aw_i-ck_aw_o, ck_w_i-ck_w_o, ck_r_i-ck_r_o, ck_b_i-ck_b_o);
      end else
        $display("  in flight at the end (last handshake %0d cyc before): AR %0d, AW %0d, W %0d, R %0d, B %0d",
          sd_cycle - sd_last_hs, ck_ar_i-ck_ar_o, ck_aw_i-ck_aw_o, ck_w_i-ck_w_o, ck_r_i-ck_r_o, ck_b_i-ck_b_o);
    end
    if (ck_err_n == 0) $display("  checker: no violations");
    else $display("  *** checker: %0d violation(s), see the [slowdown] errors above (at most %0d printed during the run)",
                  ck_err_n, CK_ERR_SHOW);
    if (sd_fd != 0) $display("  (per-transaction + heartbeat trace in %s)", sd_trace_fn);
    else            $display("  (no per-transaction trace: +SLOWDOWN_TRACE=<file> writes one)");
    $display("=================================================================");
    if (sd_fd) $fclose(sd_fd);
  end
// pragma translate_on

endmodule