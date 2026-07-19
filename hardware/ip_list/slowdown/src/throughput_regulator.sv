// -----------------------------------------------------------------------------
// throughput_regulator — request-path bandwidth regulator for the slowdown IP.
//
// Releases at most ONE transaction every Throughput_timer_param cycles so the
// downstream memory bandwidth is capped, WITHOUT ever letting a write block a
// read (AXI reads and writes are independent channels).
//
//   Intake — DECOUPLED. AR goes into ar_fifo, AW into aw_fifo, W into dw_fifo.
//     Because reads and writes have separate queues, a same-cycle AR+AW is not
//     a conflict (both accepted, each into its own FIFO), and a queued write can
//     never sit in front of a queued read. READY is simply ~full per channel.
//
//   Release — two FSMs sharing one throttle:
//     * Read  FSM: RD_WAIT -> RD_SEND. Drives ar_valid; on ar_ready pops ar_fifo.
//     * Write FSM: WR_WAIT -> WR_SEND_AW -> WR_SEND_W. Drives aw_valid; on
//       aw_ready pops aw_fifo, then drains that AW's W burst (AWLEN+1 beats,
//       drain-until-count) from dw_fifo. AW is only offered once its W is
//       present (~dw_fifo_empty), so memory never gets an AW it must wait on.
//     The write FSM's W-drain state does NOT hold the throttle, so a write
//     stalled for its W can never block a read — that was the deadlock.
//
//   Throttle — one shared down-counter. Reloaded when a request is ACCEPTED
//     downstream (its AR/AW handshake), so consecutive accepted requests stay
//     >= Throughput_timer_param cycles apart under irregular back-pressure.
//     A 1-bit round-robin bit breaks ties when both a read and a write are
//     ready; when one side is stalled/idle the other simply takes the slot, so
//     AR and AW still "delay each other" (shared rate) but never block each
//     other (independent queues).
//
// Fully synthesizable; no functions/tasks.
// -----------------------------------------------------------------------------

module throughput_regulator #(
    parameter int unsigned Throughput_timer_param   = 16,
    parameter int unsigned Throughput_FIFO_depth    = 8,
    parameter int unsigned Throughput_COUNTER_WIDTH = 4
) (
    input logic clk_i,
    input logic rst_ni,
    // AW channel signals:
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input  logic                             aw_valid_i,
    input  ariane_axi_soc::aw_chan_slv_mem_t aw_signals_i,
    output logic                             aw_ready_o,    // backpressure to upstream
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                             aw_valid_o,
    output ariane_axi_soc::aw_chan_slv_mem_t aw_signals_o,
    input  logic                             aw_ready_i,    // from memory

    // AR channel signals
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input  logic                             ar_valid_i,
    input  ariane_axi_soc::ar_chan_slv_mem_t ar_signals_i,
    output logic                             ar_ready_o,    // backpressure to upstream
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                             ar_valid_o,
    output ariane_axi_soc::ar_chan_slv_mem_t ar_signals_o,
    input  logic                             ar_ready_i,    // from memory

    // W channel signals
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input  logic                             dw_valid_i,
    input  ariane_axi_soc::w_chan_t          dw_signals_i,
    output logic                             dw_ready_o,
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                             dw_valid_o,
    output ariane_axi_soc::w_chan_t          dw_signals_o,
    input  logic                             dw_ready_i,

    // debugging port
    output reg ar_valid_o_reg,
    output reg aw_valid_o_reg,
    output reg dw_valid_o_reg
);

    initial begin
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
        $display(">>> throughput_regulator: DECOUPLED AR/AW + CONCURRENT AW/W build (WVALID never waits on AWREADY) <<<");
        $display("Throughput_timer_param     = %0d", Throughput_timer_param);
        $display("Throughput_FIFO_depth      = %0d", Throughput_FIFO_depth);
        $display("Throughput_COUNTER_WIDTH    = %0d", Throughput_COUNTER_WIDTH);
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
    end

    // =========================================================================
    // Intake: independent AR / AW / W queues (reads decoupled from writes)
    // =========================================================================
    ariane_axi_soc::address_queue_entry_t ar_fifo_in, ar_fifo_out;
    ariane_axi_soc::address_queue_entry_t aw_fifo_in, aw_fifo_out;
    logic ar_fifo_wr, ar_fifo_rd, ar_fifo_empty, ar_fifo_full;
    logic aw_fifo_wr, aw_fifo_rd, aw_fifo_empty, aw_fifo_full;

    // AR intake — its own FIFO; READY = room. No arbitration with AW.
    always_comb begin
        ar_fifo_in = '0;
        ar_fifo_in.valid                = 1'b1;
        ar_fifo_in.AR_AW_signals.id     = ar_signals_i.id;
        ar_fifo_in.AR_AW_signals.addr   = ar_signals_i.addr;
        ar_fifo_in.AR_AW_signals.len    = ar_signals_i.len;
        ar_fifo_in.AR_AW_signals.size   = ar_signals_i.size;
        ar_fifo_in.AR_AW_signals.burst  = ar_signals_i.burst;
        ar_fifo_in.AR_AW_signals.lock   = ar_signals_i.lock;
        ar_fifo_in.AR_AW_signals.cache  = ar_signals_i.cache;
        ar_fifo_in.AR_AW_signals.prot   = ar_signals_i.prot;
        ar_fifo_in.AR_AW_signals.qos    = ar_signals_i.qos;
        ar_fifo_in.AR_AW_signals.region = ar_signals_i.region;
        ar_fifo_in.AR_AW_signals.atop   = '0;
        ar_fifo_in.AR_AW_signals.user   = ar_signals_i.user;
        ar_fifo_in.AR_AW_tag            = 1'b1;
    end
    assign ar_ready_o = ~ar_fifo_full;
    assign ar_fifo_wr = ar_valid_i & ~ar_fifo_full;

    // AW intake — its own FIFO.
    always_comb begin
        aw_fifo_in = '0;
        aw_fifo_in.valid                = 1'b1;
        aw_fifo_in.AR_AW_signals.id     = aw_signals_i.id;
        aw_fifo_in.AR_AW_signals.addr   = aw_signals_i.addr;
        aw_fifo_in.AR_AW_signals.len    = aw_signals_i.len;
        aw_fifo_in.AR_AW_signals.size   = aw_signals_i.size;
        aw_fifo_in.AR_AW_signals.burst  = aw_signals_i.burst;
        aw_fifo_in.AR_AW_signals.lock   = aw_signals_i.lock;
        aw_fifo_in.AR_AW_signals.cache  = aw_signals_i.cache;
        aw_fifo_in.AR_AW_signals.prot   = aw_signals_i.prot;
        aw_fifo_in.AR_AW_signals.qos    = aw_signals_i.qos;
        aw_fifo_in.AR_AW_signals.region = aw_signals_i.region;
        aw_fifo_in.AR_AW_signals.atop   = aw_signals_i.atop;
        aw_fifo_in.AR_AW_signals.user   = aw_signals_i.user;
        aw_fifo_in.AR_AW_tag            = 1'b0;
    end
    assign aw_ready_o = ~aw_fifo_full;
    assign aw_fifo_wr = aw_valid_i & ~aw_fifo_full;

    fifo_sync #(.FIFO_DEPTH(Throughput_FIFO_depth)) i_ar_fifo (
        .clk_i(clk_i), .rst_ni(rst_ni), .cs(1'b1),
        .wr_en(ar_fifo_wr), .rd_en(ar_fifo_rd),
        .data_in(ar_fifo_in), .data_out(ar_fifo_out),
        .empty(ar_fifo_empty), .full(ar_fifo_full),
        .AR_AW_tag_o(), .fifo(), .write_pointer(), .read_pointer()
    );

    fifo_sync #(.FIFO_DEPTH(Throughput_FIFO_depth)) i_aw_fifo (
        .clk_i(clk_i), .rst_ni(rst_ni), .cs(1'b1),
        .wr_en(aw_fifo_wr), .rd_en(aw_fifo_rd),
        .data_in(aw_fifo_in), .data_out(aw_fifo_out),
        .empty(aw_fifo_empty), .full(aw_fifo_full),
        .AR_AW_tag_o(), .fifo(), .write_pointer(), .read_pointer()
    );

    // W beats buffered in order.
    ariane_axi_soc::w_data_fifo_entry_t dw_data_in, dw_data_out;
    logic dw_fifo_wr, dw_fifo_rd, dw_fifo_empty, dw_fifo_full;
    assign dw_data_in.w_valid   = dw_valid_i;
    assign dw_data_in.w_signals = dw_signals_i;
    assign dw_ready_o           = ~dw_fifo_full;
    assign dw_fifo_wr           = dw_valid_i & ~dw_fifo_full;

    data_write_fifo #(.FIFO_DEPTH(Throughput_FIFO_depth)) i_dw_fifo (
        .clk_i(clk_i), .rst_ni(rst_ni), .cs(1'b1),
        .wr_en(dw_fifo_wr), .rd_en(dw_fifo_rd),
        .write_data_in(dw_data_in), .write_data_out(dw_data_out),
        .empty(dw_fifo_empty), .full(dw_fifo_full),
        .fifo(), .write_pointer(), .read_pointer()
    );

    // =========================================================================
    // Shared throttle — one release per period, reloaded on the ACCEPT.
    // =========================================================================
    localparam logic [Throughput_COUNTER_WIDTH-1:0] PERIOD_LOAD =
        Throughput_timer_param[Throughput_COUNTER_WIDTH-1:0] - 1'b1;

    logic [Throughput_COUNTER_WIDTH-1:0] period_cnt;
    logic                                period_reload;
    wire                                 period_elapsed = (period_cnt == '0);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)               period_cnt <= '0;             // start ready
        else if (period_reload)    period_cnt <= PERIOD_LOAD;
        else if (period_cnt != '0) period_cnt <= period_cnt - 1'b1;
    end

    // =========================================================================
    // Release FSMs (read + write) and the shared-throttle arbiter
    // =========================================================================
    typedef enum logic { RD_WAIT, RD_SEND } rd_state_e;
    typedef enum logic { WR_WAIT, WR_SEND } wr_state_e;

    rd_state_e  rd_q, rd_d;
    wr_state_e  wr_q, wr_d;
    logic       rr_q;                               // 0 favours read, 1 favours write
    logic [7:0] w_beats_left_q, w_beats_left_d;     // AXI AWLEN is 8 bits
    // In WR_SEND the AW and W channels are offered CONCURRENTLY (AXI4 forbids a
    // master waiting for AWREADY before asserting WVALID). These two flags record,
    // within one write, which of the two INDEPENDENT handshakes has completed.
    logic       aw_sent_q, aw_sent_d;               // this write's AW accepted
    logic       w_done_q,  w_done_d;                // this write's last W beat accepted

    // A release is "in progress" only while an ADDRESS is being offered but not
    // yet accepted (RD_SEND, or WR_SEND with its AW not yet handshaken). Once the
    // AW is accepted the write no longer holds the throttle even while its W burst
    // is still draining, so a write can never block a read — that was the deadlock.
    wire release_pending = (rd_q == RD_SEND) | (wr_q == WR_SEND & ~aw_sent_q);
    wire release_ok      = period_elapsed & ~release_pending;

    // A write is only "wanted" once its first W beat is present (~dw_fifo_empty):
    // we never start a write we cannot immediately begin feeding W to.
    wire rd_want  = (rd_q == RD_WAIT) & ~ar_fifo_empty;
    wire wr_want  = (wr_q == WR_WAIT) & ~aw_fifo_empty & ~dw_fifo_empty;

    wire grant_read  = release_ok & rd_want & (~wr_want | ~rr_q);
    wire grant_write = release_ok & wr_want & (~rd_want |  rr_q);

    wire w_beat_hs   = dw_valid_o & dw_ready_i;

    // ---- Read release FSM ----
    always_comb begin
        rd_d       = rd_q;
        ar_valid_o = 1'b0;
        ar_fifo_rd = 1'b0;
        case (rd_q)
            RD_WAIT: if (grant_read) rd_d = RD_SEND;
            RD_SEND: begin
                ar_valid_o = 1'b1;                       // payload = ar_fifo head
                if (ar_ready_i) begin
                    ar_fifo_rd = 1'b1;                   // consume the AR
                    rd_d       = RD_WAIT;
                end
            end
            default: rd_d = RD_WAIT;
        endcase
    end

    // ---- Write release FSM (AW and W offered CONCURRENTLY) ----
    //
    // On a grant we enter WR_SEND and immediately offer BOTH the AW (payload =
    // aw_fifo head) and the buffered W beats. The two handshakes are independent:
    // WVALID is asserted from cycle one and NEVER waits for AWREADY, so a slave
    // that gates AWREADY on WVALID cannot deadlock us. The write retires once its
    // AW has been accepted AND its whole W burst (AWLEN+1 beats) has drained.
    always_comb begin
        wr_d           = wr_q;
        aw_valid_o     = 1'b0;
        dw_valid_o     = 1'b0;
        aw_fifo_rd     = 1'b0;
        dw_fifo_rd     = 1'b0;
        w_beats_left_d = w_beats_left_q;
        aw_sent_d      = aw_sent_q;
        w_done_d       = w_done_q;
        case (wr_q)
            WR_WAIT: begin
                if (grant_write) begin
                    wr_d           = WR_SEND;
                    aw_sent_d      = 1'b0;
                    w_done_d       = 1'b0;
                    // AWLEN of the head AW (stable: the AW is not popped in WR_WAIT).
                    w_beats_left_d = aw_fifo_out.AR_AW_signals.len;
                end
            end
            WR_SEND: begin
                // AW channel: offer until its own handshake completes.
                aw_valid_o = ~aw_sent_q;
                if (aw_valid_o & aw_ready_i) begin
                    aw_fifo_rd = 1'b1;                   // consume the AW
                    aw_sent_d  = 1'b1;
                end
                // W channel: offer buffered beats until the last one is accepted,
                // completely independent of the AW handshake above.
                dw_valid_o = ~dw_fifo_empty & ~w_done_q;
                if (w_beat_hs) begin
                    dw_fifo_rd = 1'b1;                   // pop exactly this beat
                    if (w_beats_left_q == 8'd0) w_done_d       = 1'b1;              // last beat
                    else                        w_beats_left_d = w_beats_left_q - 8'd1;
                end
                // Retire the write once BOTH channels are finished (this cycle or earlier).
                if ((aw_sent_q | (aw_valid_o & aw_ready_i)) &&
                    (w_done_q  | (w_beat_hs & (w_beats_left_q == 8'd0)))) begin
                    wr_d      = WR_WAIT;
                    aw_sent_d = 1'b0;
                    w_done_d  = 1'b0;
                end
            end
            default: wr_d = WR_WAIT;
        endcase
    end

    // Throttle reloads when an ADDRESS is ACCEPTED downstream (AR, or the AW while
    // it is still being offered). W-beat handshakes do NOT reload the throttle.
    assign period_reload = (rd_q == RD_SEND && ar_ready_i) ||
                           (wr_q == WR_SEND  && aw_valid_o && aw_ready_i);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rd_q           <= RD_WAIT;
            wr_q           <= WR_WAIT;
            rr_q           <= 1'b0;
            w_beats_left_q <= 8'd0;
            aw_sent_q      <= 1'b0;
            w_done_q       <= 1'b0;
        end else begin
            rd_q           <= rd_d;
            wr_q           <= wr_d;
            w_beats_left_q <= w_beats_left_d;
            aw_sent_q      <= aw_sent_d;
            w_done_q       <= w_done_d;
            if (grant_read | grant_write) rr_q <= ~rr_q;   // alternate on each grant
        end
    end

    // =========================================================================
    // Output payload muxes (each straight from its own FIFO head)
    // =========================================================================
    always_comb begin
        ar_signals_o        = '0;
        ar_signals_o.id     = ar_fifo_out.AR_AW_signals.id;
        ar_signals_o.addr   = ar_fifo_out.AR_AW_signals.addr;
        ar_signals_o.len    = ar_fifo_out.AR_AW_signals.len;
        ar_signals_o.size   = ar_fifo_out.AR_AW_signals.size;
        ar_signals_o.burst  = ar_fifo_out.AR_AW_signals.burst;
        ar_signals_o.lock   = ar_fifo_out.AR_AW_signals.lock;
        ar_signals_o.cache  = ar_fifo_out.AR_AW_signals.cache;
        ar_signals_o.prot   = ar_fifo_out.AR_AW_signals.prot;
        ar_signals_o.qos    = ar_fifo_out.AR_AW_signals.qos;
        ar_signals_o.region = ar_fifo_out.AR_AW_signals.region;
        ar_signals_o.user   = ar_fifo_out.AR_AW_signals.user;

        aw_signals_o        = '0;
        aw_signals_o.id     = aw_fifo_out.AR_AW_signals.id;
        aw_signals_o.addr   = aw_fifo_out.AR_AW_signals.addr;
        aw_signals_o.len    = aw_fifo_out.AR_AW_signals.len;
        aw_signals_o.size   = aw_fifo_out.AR_AW_signals.size;
        aw_signals_o.burst  = aw_fifo_out.AR_AW_signals.burst;
        aw_signals_o.lock   = aw_fifo_out.AR_AW_signals.lock;
        aw_signals_o.cache  = aw_fifo_out.AR_AW_signals.cache;
        aw_signals_o.prot   = aw_fifo_out.AR_AW_signals.prot;
        aw_signals_o.qos    = aw_fifo_out.AR_AW_signals.qos;
        aw_signals_o.region = aw_fifo_out.AR_AW_signals.region;
        aw_signals_o.atop   = aw_fifo_out.AR_AW_signals.atop;
        aw_signals_o.user   = aw_fifo_out.AR_AW_signals.user;

        dw_signals_o        = '0;
        dw_signals_o.data   = dw_data_out.w_signals.data;
        dw_signals_o.strb   = dw_data_out.w_signals.strb;
        dw_signals_o.last   = dw_data_out.w_signals.last;
        dw_signals_o.user   = dw_data_out.w_signals.user;
    end

    // =========================================================================
    // Debug: registered mirrors of the output valids
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ar_valid_o_reg <= 1'b0;
            aw_valid_o_reg <= 1'b0;
            dw_valid_o_reg <= 1'b0;
        end else begin
            ar_valid_o_reg <= ar_valid_o;
            aw_valid_o_reg <= aw_valid_o;
            dw_valid_o_reg <= dw_valid_o;
        end
    end

    // =========================================================================
    // W/AW alignment check (sim only; stripped by vopt -check_synthesis)
    // =========================================================================
    // pragma translate_off
    always_ff @(posedge clk_i) begin
        if (rst_ni && wr_q == WR_SEND && w_beat_hs) begin
            if (w_beats_left_q == 8'd0 && !dw_data_out.w_signals.last)
                $display("[%0t] throughput_regulator: WARN AWLEN expired but W.last=0 (W burst LONGER than AWLEN)", $time);
            if (w_beats_left_q != 8'd0 && dw_data_out.w_signals.last)
                $display("[%0t] throughput_regulator: WARN W.last=1 with %0d beat(s) still expected (W burst SHORTER than AWLEN)", $time, w_beats_left_q);
        end
    end
    // pragma translate_on

endmodule
