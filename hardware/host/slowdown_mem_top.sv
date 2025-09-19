module slowdown_mem_top #(
    parameter int unsigned Latency_param = 0, // needs to >= 2
    parameter int unsigned Throughput_timer_param = 10,
    parameter int unsigned Throughput_FIFO_depth = 8,
    parameter int unsigned Throughput_COUNTER_WIDTH = 4
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    AXI_BUS.Slave                   slowdown_mem_slv,
    AXI_BUS.Master                  slowdown_mem_mst
);

    // // AW Channel
    // // IP of E-Slv <= OP of E-Mst
    // assign slowdown_mem_mst.aw_id     = slowdown_mem_slv.aw_id;
    // assign slowdown_mem_mst.aw_addr   = slowdown_mem_slv.aw_addr;
    // assign slowdown_mem_mst.aw_len    = slowdown_mem_slv.aw_len;
    // assign slowdown_mem_mst.aw_size   = slowdown_mem_slv.aw_size;
    // assign slowdown_mem_mst.aw_burst  = slowdown_mem_slv.aw_burst;
    // assign slowdown_mem_mst.aw_lock   = slowdown_mem_slv.aw_lock;
    // assign slowdown_mem_mst.aw_cache  = slowdown_mem_slv.aw_cache;
    // assign slowdown_mem_mst.aw_prot   = slowdown_mem_slv.aw_prot;
    // assign slowdown_mem_mst.aw_qos    = slowdown_mem_slv.aw_qos;
    // assign slowdown_mem_mst.aw_region = slowdown_mem_slv.aw_region;
    // assign slowdown_mem_mst.aw_atop   = slowdown_mem_slv.aw_atop;
    // assign slowdown_mem_mst.aw_user   = slowdown_mem_slv.aw_user;
    // assign slowdown_mem_mst.aw_valid  = slowdown_mem_slv.aw_valid;
    // // IP of E-Mst <= OP of E-Slv
    // assign slowdown_mem_slv.aw_ready  = slowdown_mem_mst.aw_ready;

    // // W Channel
    // // IP of E-Slv <= OP of E-Mst
    // assign slowdown_mem_mst.w_data  = slowdown_mem_slv.w_data;
    // assign slowdown_mem_mst.w_strb  = slowdown_mem_slv.w_strb;
    // assign slowdown_mem_mst.w_last  = slowdown_mem_slv.w_last;
    // assign slowdown_mem_mst.w_user  = slowdown_mem_slv.w_user;
    // assign slowdown_mem_mst.w_valid = slowdown_mem_slv.w_valid;
    // // IP of E-Mst <= OP of E-Slv
    // assign slowdown_mem_slv.w_ready = slowdown_mem_mst.w_ready;

    // B Channel
    // IP of E-Mst <= OP of E-Slv
    assign slowdown_mem_slv.b_id    = slowdown_mem_mst.b_id;
    assign slowdown_mem_slv.b_resp  = slowdown_mem_mst.b_resp;
    assign slowdown_mem_slv.b_user  = slowdown_mem_mst.b_user;
    // assign slowdown_mem_slv.b_valid = slowdown_mem_mst.b_valid;      // b_valid is in the latency module
    // IP of E-Slv <= OP of E-Mst
    assign slowdown_mem_mst.b_ready = slowdown_mem_slv.b_ready;

    // AR Channel
    // IP of E-Slv <= OP of E-Mst
    // assign slowdown_mem_mst.ar_id     = slowdown_mem_slv.ar_id;
    // assign slowdown_mem_mst.ar_addr   = slowdown_mem_slv.ar_addr;
    // assign slowdown_mem_mst.ar_len    = slowdown_mem_slv.ar_len;
    // assign slowdown_mem_mst.ar_size   = slowdown_mem_slv.ar_size;
    // assign slowdown_mem_mst.ar_burst  = slowdown_mem_slv.ar_burst;
    // assign slowdown_mem_mst.ar_lock   = slowdown_mem_slv.ar_lock;
    // assign slowdown_mem_mst.ar_cache  = slowdown_mem_slv.ar_cache;
    // assign slowdown_mem_mst.ar_prot   = slowdown_mem_slv.ar_prot;
    // assign slowdown_mem_mst.ar_qos    = slowdown_mem_slv.ar_qos;
    // assign slowdown_mem_mst.ar_region = slowdown_mem_slv.ar_region;
    // assign slowdown_mem_mst.ar_user   = slowdown_mem_slv.ar_user;
    // assign slowdown_mem_mst.ar_valid  = slowdown_mem_slv.ar_valid;
    // IP of E-Mst <= OP of E-Slv
    // assign slowdown_mem_slv.ar_ready  = slowdown_mem_mst.ar_ready;

    // // R CHannel
    // // IP of E-Mst <= OP of E-Slv
    // assign slowdown_mem_slv.r_id    = slowdown_mem_mst.r_id;
    // assign slowdown_mem_slv.r_data  = slowdown_mem_mst.r_data;
    // assign slowdown_mem_slv.r_resp  = slowdown_mem_mst.r_resp;
    // assign slowdown_mem_slv.r_last  = slowdown_mem_mst.r_last;
    // assign slowdown_mem_slv.r_user  = slowdown_mem_mst.r_user;
    // //assign slowdown_mem_slv.r_valid = slowdown_mem_mst.r_valid;      // r_valid is in the latency module
    // // IP of E-Slv <= OP of E-Mst
    // //assign slowdown_mem_mst.r_ready = slowdown_mem_slv.r_ready;

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
        .valid(slowdown_mem_mst.b_valid),
        .valid_delayed(slowdown_mem_slv.b_valid)
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
    assign aw_signals_in.addr = slowdown_mem_slv.aw_addr;;
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
    Throughput_COUNTER_WIDTH(Throughput_COUNTER_WIDTH)
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

endmodule