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
  // Detects: dropped / duplicated transactions, AXI valid-stability
  // violations, and the suspected simultaneous-AR+AW request-path hazard.
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
  localparam int unsigned CK_ADDR_MAX = Throughput_FIFO_depth + 8; // shared AR/AW FIFO + out regs
  localparam int unsigned CK_W_MAX    = Throughput_FIFO_depth + 8; // write-data FIFO
  localparam int unsigned CK_RESP_MAX = Latency_param        + 8;  // latency shift depth

  // --- no duplication / spurious output: leaves must never exceed arrivals ---
  ck_ar_nodup: assert property (@(posedge clk_i) disable iff(!rst_ni) ck_ar_o <= ck_ar_i)
    else $error("[slowdown] AR duplicated/spurious: out=%0d > in=%0d", ck_ar_o, ck_ar_i);
  ck_aw_nodup: assert property (@(posedge clk_i) disable iff(!rst_ni) ck_aw_o <= ck_aw_i)
    else $error("[slowdown] AW duplicated/spurious: out=%0d > in=%0d", ck_aw_o, ck_aw_i);
  ck_w_nodup:  assert property (@(posedge clk_i) disable iff(!rst_ni) ck_w_o  <= ck_w_i)
    else $error("[slowdown] W duplicated/spurious: out=%0d > in=%0d",  ck_w_o,  ck_w_i);
  ck_r_nodup:  assert property (@(posedge clk_i) disable iff(!rst_ni) ck_r_o  <= ck_r_i)
    else $error("[slowdown] R duplicated/spurious: out=%0d > in=%0d",  ck_r_o,  ck_r_i);
  ck_b_nodup:  assert property (@(posedge clk_i) disable iff(!rst_ni) ck_b_o  <= ck_b_i)
    else $error("[slowdown] B duplicated/spurious: out=%0d > in=%0d",  ck_b_o,  ck_b_i);

  // --- no drop: in-flight cannot exceed internal buffering ---
  ck_addr_inflight: assert property (@(posedge clk_i) disable iff(!rst_ni)
      ((ck_ar_i-ck_ar_o)+(ck_aw_i-ck_aw_o)) <= CK_ADDR_MAX)
    else $error("[slowdown] address in-flight=%0d > %0d => DROPPED request(s). AR in/out=%0d/%0d AW in/out=%0d/%0d",
      (ck_ar_i-ck_ar_o)+(ck_aw_i-ck_aw_o), CK_ADDR_MAX, ck_ar_i, ck_ar_o, ck_aw_i, ck_aw_o);
  ck_w_inflight: assert property (@(posedge clk_i) disable iff(!rst_ni) (ck_w_i-ck_w_o) <= CK_W_MAX)
    else $error("[slowdown] W in-flight=%0d > %0d => DROPPED write beat(s). in/out=%0d/%0d", (ck_w_i-ck_w_o), CK_W_MAX, ck_w_i, ck_w_o);
  ck_r_inflight: assert property (@(posedge clk_i) disable iff(!rst_ni) (ck_r_i-ck_r_o) <= CK_RESP_MAX)
    else $error("[slowdown] R in-flight=%0d > %0d => DROPPED read-data beat(s). in/out=%0d/%0d", (ck_r_i-ck_r_o), CK_RESP_MAX, ck_r_i, ck_r_o);
  ck_b_inflight: assert property (@(posedge clk_i) disable iff(!rst_ni) (ck_b_i-ck_b_o) <= CK_RESP_MAX)
    else $error("[slowdown] B in-flight=%0d > %0d => DROPPED write response(s). in/out=%0d/%0d", (ck_b_i-ck_b_o), CK_RESP_MAX, ck_b_i, ck_b_o);

  // --- targeted: simultaneous AR+AW accepted at slave (AR-priority mux enqueues only one) ---
  always_ff @(posedge clk_i) if (rst_ni && ck_ar_in && ck_aw_in)
    $display("[slowdown][%0t] HAZARD: AR & AW both handshaked at slave in one cycle -> AR-priority mux enqueues only one -> the other is likely DROPPED", $time);

  // --- AXI valid-stability: once VALID & !READY, VALID must hold next cycle ---
  property ck_vstable(v, r); @(posedge clk_i) disable iff(!rst_ni) (v && !r) |=> v; endproperty
  ck_slv_ar_vs: assert property (ck_vstable(slowdown_mem_slv.ar_valid, slowdown_mem_slv.ar_ready)) else $error("[slowdown] slave AR valid dropped before ready");
  ck_slv_aw_vs: assert property (ck_vstable(slowdown_mem_slv.aw_valid, slowdown_mem_slv.aw_ready)) else $error("[slowdown] slave AW valid dropped before ready");
  ck_slv_w_vs:  assert property (ck_vstable(slowdown_mem_slv.w_valid,  slowdown_mem_slv.w_ready))  else $error("[slowdown] slave W valid dropped before ready");
  ck_mst_ar_vs: assert property (ck_vstable(slowdown_mem_mst.ar_valid, slowdown_mem_mst.ar_ready)) else $error("[slowdown] master AR valid dropped before ready");
  ck_mst_aw_vs: assert property (ck_vstable(slowdown_mem_mst.aw_valid, slowdown_mem_mst.aw_ready)) else $error("[slowdown] master AW valid dropped before ready");
  ck_mst_w_vs:  assert property (ck_vstable(slowdown_mem_mst.w_valid,  slowdown_mem_mst.w_ready))  else $error("[slowdown] master W valid dropped before ready");
  ck_mst_r_vs:  assert property (ck_vstable(slowdown_mem_mst.r_valid,  slowdown_mem_mst.r_ready))  else $error("[slowdown] master R valid dropped before ready");
  ck_slv_r_vs:  assert property (ck_vstable(slowdown_mem_slv.r_valid,  slowdown_mem_slv.r_ready))  else $error("[slowdown] slave R valid dropped before ready (latency path)");
  ck_mst_b_vs:  assert property (ck_vstable(slowdown_mem_mst.b_valid,  slowdown_mem_mst.b_ready))  else $error("[slowdown] master B valid dropped before ready");
  ck_slv_b_vs:  assert property (ck_vstable(slowdown_mem_slv.b_valid,  slowdown_mem_slv.b_ready))  else $error("[slowdown] slave B valid dropped before ready (latency path)");

  // --- end-of-sim transaction summary ---
  final begin
    $display("================ slowdown IP transaction summary ================");
    $display("  AR  in/out = %0d / %0d   (in-flight %0d)", ck_ar_i, ck_ar_o, ck_ar_i-ck_ar_o);
    $display("  AW  in/out = %0d / %0d   (in-flight %0d)", ck_aw_i, ck_aw_o, ck_aw_i-ck_aw_o);
    $display("  W   in/out = %0d / %0d   (in-flight %0d)", ck_w_i,  ck_w_o,  ck_w_i-ck_w_o);
    $display("  R   in/out = %0d / %0d   (in-flight %0d)", ck_r_i,  ck_r_o,  ck_r_i-ck_r_o);
    $display("  B   in/out = %0d / %0d   (in-flight %0d)", ck_b_i,  ck_b_o,  ck_b_i-ck_b_o);
    if (ck_ar_i!=ck_ar_o) $display("  *** AR imbalance: %0d read request(s) never left the IP (DROPPED)",  ck_ar_i-ck_ar_o);
    if (ck_aw_i!=ck_aw_o) $display("  *** AW imbalance: %0d write request(s) never left the IP (DROPPED)", ck_aw_i-ck_aw_o);
    if (ck_w_i !=ck_w_o ) $display("  *** W  imbalance: %0d write beat(s) never left the IP",  ck_w_i-ck_w_o);
    if (ck_r_i !=ck_r_o ) $display("  *** R  imbalance: %0d read-data beat(s) never delivered", ck_r_i-ck_r_o);
    if (ck_b_i !=ck_b_o ) $display("  *** B  imbalance: %0d write response(s) never delivered", ck_b_i-ck_b_o);
    $display("=================================================================");
  end
// pragma translate_on

endmodule