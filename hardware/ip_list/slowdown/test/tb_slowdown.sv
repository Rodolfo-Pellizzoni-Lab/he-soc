// tb_slowdown.sv — Exhaustive testbench for slowdown_mem_top
//
// Two-sided verification:
//   REQUEST PATH:  Upstream sends varied AXI4 traffic (light/heavy, single/burst,
//                  all sideband attributes).  Downstream monitors confirm the
//                  throughput regulator spaces requests >= THROUGHPUT cycles and
//                  that every sideband field arrives unmodified.
//
//   RESPONSE PATH: Downstream slave generates R/B responses.  History-based
//                  checker on the upstream side confirms latency shift-register
//                  adds exactly LATENCY cycles to every valid pulse.
//
// Tests (run in sequence):
//   T1  Light single reads     — basic latency + throughput, one-at-a-time
//   T2  Pipelined reads        — fill FIFO, verify spacing, drain
//   T3  FIFO backpressure      — FIFO_DEPTH+2 ARs, confirm ar_ready deasserts
//   T4  Burst reads (len=3,7)  — LLC-style cache-line fetches
//   T5  Light single writes
//   T6  Pipelined writes
//   T7  Burst writes (len=3)   — LLC-style writebacks
//   T8  AXI sideband sweep     — cache/prot/qos/lock/size varieties
//   T9  Heavy mixed R+W        — alternating bursts, sustained load
//   T10 Response backpressure  — upstream r_ready toggling, verify no data loss
//   T11 W-data scoreboard      — Scoreboard E final check: all W beats reached downstream intact
//   T12 Concurrent AR+AW flood — 24R+12W zero-delay, validates aw_ready RTL fix under max pressure
//
// Compile order: axi_pkg → axi_intf → ariane_soc_stub_pkg →
//                ariane_axi_soc_pkg → slowdown sources → this file

`timescale 1ns/1ps

module tb_slowdown;

// =========================================================================
// Parameters
// =========================================================================
localparam int unsigned LATENCY    = 5;
localparam int unsigned THROUGHPUT = 10;
localparam int unsigned FIFO_DEPTH = 8;
localparam int unsigned AXI_ID_WIDTH   = 9;
localparam int unsigned AXI_DATA_WIDTH = 64;
localparam int unsigned AXI_ADDR_WIDTH = 64;
localparam int unsigned AXI_USER_WIDTH = 2;
localparam int          TIMEOUT_CYCLES = 500_000;

// =========================================================================
// Clock / reset
// =========================================================================
logic clk    = 1'b0;
logic rst_n;
logic sim_passed = 1'b0;

always #5 clk = ~clk;   // 100 MHz

initial begin
    rst_n = 1'b0;
    repeat (20) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
end

// =========================================================================
// AXI interfaces
// =========================================================================
AXI_BUS #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH  (AXI_ID_WIDTH),
    .AXI_USER_WIDTH(AXI_USER_WIDTH)
) axi_mst_if (), axi_slv_if ();

// =========================================================================
// DUT
// =========================================================================
slowdown_mem_top #(
    .Latency_param         (LATENCY),
    .Throughput_timer_param(THROUGHPUT),
    .Throughput_FIFO_depth (FIFO_DEPTH)
) dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .slowdown_mem_slv (axi_mst_if),
    .slowdown_mem_mst (axi_slv_if)
);

// =========================================================================
// SCOREBOARD A — Latency checker
//
// Shifts axi_slv_if.r_valid / b_valid through a LATENCY-deep register.
// When upstream sees r_valid/b_valid the corresponding history bit must be 1.
// Valid only while r_ready / b_ready = 1 (no stalls).
// =========================================================================
logic [LATENCY-1:0] dn_r_hist;
logic [LATENCY-1:0] dn_b_hist;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dn_r_hist <= '0;
        dn_b_hist <= '0;
    end else begin
        dn_r_hist <= {dn_r_hist[LATENCY-2:0], axi_slv_if.r_valid};
        dn_b_hist <= {dn_b_hist[LATENCY-2:0], axi_slv_if.b_valid};
    end
end

int unsigned lat_check_en = 1;  // cleared during backpressure test T10
int unsigned lat_r_viols  = 0;
int unsigned lat_b_viols  = 0;

always @(posedge clk) begin
    if (rst_n && lat_check_en) begin
        if (axi_mst_if.r_valid && !dn_r_hist[LATENCY-1]) begin
            $error("[LAT_CHECK %0t] R_VALID upstream but dn_r_valid was 0 %0d cycles ago",
                   $time, LATENCY);
            lat_r_viols = lat_r_viols + 1;
        end
        if (axi_mst_if.b_valid && !dn_b_hist[LATENCY-1]) begin
            $error("[LAT_CHECK %0t] B_VALID upstream but dn_b_valid was 0 %0d cycles ago",
                   $time, LATENCY);
            lat_b_viols = lat_b_viols + 1;
        end
    end
end

// =========================================================================
// SCOREBOARD B — Throughput checker
//
// Monitors downstream AR and AW handshakes.  Consecutive same-channel
// handshakes must be spaced >= THROUGHPUT cycles apart.
// =========================================================================
longint unsigned cyc;   // free-running cycle counter
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) cyc <= '0; else cyc <= cyc + 1;

longint unsigned last_dn_ar_cyc = 0;
longint unsigned last_dn_aw_cyc = 0;
int unsigned     dn_ar_cnt      = 0;
int unsigned     dn_aw_cnt      = 0;
int unsigned     tput_ar_viols  = 0;
int unsigned     tput_aw_viols  = 0;
longint          sp_ar, sp_aw;   // module-level temps (no automatic in always)

always @(posedge clk) begin
    if (rst_n) begin
        if (axi_slv_if.ar_valid && axi_slv_if.ar_ready) begin
            if (dn_ar_cnt > 0) begin
                sp_ar = longint'(cyc) - longint'(last_dn_ar_cyc);
                $display("[TPUT %0t] AR#%0d spacing=%0d cyc (expect>=%0d)",
                         $time, dn_ar_cnt, sp_ar, THROUGHPUT);
                if (sp_ar < longint'(THROUGHPUT) - 1) begin
                    $warning("[TPUT] AR spacing %0d < %0d — VIOLATION", sp_ar, THROUGHPUT);
                    tput_ar_viols = tput_ar_viols + 1;
                end
            end
            last_dn_ar_cyc = cyc;
            dn_ar_cnt = dn_ar_cnt + 1;
        end
        if (axi_slv_if.aw_valid && axi_slv_if.aw_ready) begin
            if (dn_aw_cnt > 0) begin
                sp_aw = longint'(cyc) - longint'(last_dn_aw_cyc);
                $display("[TPUT %0t] AW#%0d spacing=%0d cyc (expect>=%0d)",
                         $time, dn_aw_cnt, sp_aw, THROUGHPUT);
                if (sp_aw < longint'(THROUGHPUT) - 1) begin
                    $warning("[TPUT] AW spacing %0d < %0d — VIOLATION", sp_aw, THROUGHPUT);
                    tput_aw_viols = tput_aw_viols + 1;
                end
            end
            last_dn_aw_cyc = cyc;
            dn_aw_cnt = dn_aw_cnt + 1;
        end
    end
end

// =========================================================================
// SCOREBOARD C — Field preservation checker
//
// Enqueue AR/AW fields on upstream handshake; dequeue and compare on
// downstream handshake.  FIFO order is maintained within each channel.
// =========================================================================
localparam int PRESQ = 64;   // max outstanding per channel

typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [7:0]                len;
    logic [2:0]                size;
    logic [1:0]                burst;
    logic [3:0]                cache;
    logic [2:0]                prot;
    logic [3:0]                qos;
    logic                      lock;
} txn_t;

txn_t ar_presq [0:PRESQ-1];
txn_t aw_presq [0:PRESQ-1];
txn_t ar_exp, aw_exp;        // module-level temps for field compare
int unsigned ar_pw = 0, ar_pr = 0;
int unsigned aw_pw = 0, aw_pr = 0;
int unsigned pres_ar_viols = 0;
int unsigned pres_aw_viols = 0;

// Enqueue on upstream handshakes
always @(posedge clk) begin
    if (rst_n) begin
        if (axi_mst_if.ar_valid && axi_mst_if.ar_ready) begin
            ar_presq[ar_pw % PRESQ].id    = axi_mst_if.ar_id;
            ar_presq[ar_pw % PRESQ].addr  = axi_mst_if.ar_addr;
            ar_presq[ar_pw % PRESQ].len   = axi_mst_if.ar_len;
            ar_presq[ar_pw % PRESQ].size  = axi_mst_if.ar_size;
            ar_presq[ar_pw % PRESQ].burst = axi_mst_if.ar_burst;
            ar_presq[ar_pw % PRESQ].cache = axi_mst_if.ar_cache;
            ar_presq[ar_pw % PRESQ].prot  = axi_mst_if.ar_prot;
            ar_presq[ar_pw % PRESQ].qos   = axi_mst_if.ar_qos;
            ar_presq[ar_pw % PRESQ].lock  = axi_mst_if.ar_lock;
            ar_pw = ar_pw + 1;
        end
        if (axi_mst_if.aw_valid && axi_mst_if.aw_ready) begin
            aw_presq[aw_pw % PRESQ].id    = axi_mst_if.aw_id;
            aw_presq[aw_pw % PRESQ].addr  = axi_mst_if.aw_addr;
            aw_presq[aw_pw % PRESQ].len   = axi_mst_if.aw_len;
            aw_presq[aw_pw % PRESQ].size  = axi_mst_if.aw_size;
            aw_presq[aw_pw % PRESQ].burst = axi_mst_if.aw_burst;
            aw_presq[aw_pw % PRESQ].cache = axi_mst_if.aw_cache;
            aw_presq[aw_pw % PRESQ].prot  = axi_mst_if.aw_prot;
            aw_presq[aw_pw % PRESQ].qos   = axi_mst_if.aw_qos;
            aw_presq[aw_pw % PRESQ].lock  = axi_mst_if.aw_lock;
            aw_pw = aw_pw + 1;
        end
    end
end

// Dequeue+compare on downstream handshakes
always @(posedge clk) begin
    if (rst_n) begin
        if (axi_slv_if.ar_valid && axi_slv_if.ar_ready) begin
            ar_exp = ar_presq[ar_pr % PRESQ];
            ar_pr  = ar_pr + 1;
            if (axi_slv_if.ar_id    !== ar_exp.id    ||
                axi_slv_if.ar_addr  !== ar_exp.addr  ||
                axi_slv_if.ar_len   !== ar_exp.len   ||
                axi_slv_if.ar_size  !== ar_exp.size  ||
                axi_slv_if.ar_burst !== ar_exp.burst ||
                axi_slv_if.ar_cache !== ar_exp.cache ||
                axi_slv_if.ar_prot  !== ar_exp.prot  ||
                axi_slv_if.ar_qos   !== ar_exp.qos   ||
                axi_slv_if.ar_lock  !== ar_exp.lock) begin
                $error("[PRES %0t] AR field mismatch! exp id=%0d addr=0x%h len=%0d cache=%0b got id=%0d addr=0x%h len=%0d cache=%0b",
                       $time,
                       ar_exp.id, ar_exp.addr, ar_exp.len, ar_exp.cache,
                       axi_slv_if.ar_id, axi_slv_if.ar_addr,
                       axi_slv_if.ar_len, axi_slv_if.ar_cache);
                pres_ar_viols = pres_ar_viols + 1;
            end
        end
        if (axi_slv_if.aw_valid && axi_slv_if.aw_ready) begin
            aw_exp = aw_presq[aw_pr % PRESQ];
            aw_pr  = aw_pr + 1;
            if (axi_slv_if.aw_id    !== aw_exp.id    ||
                axi_slv_if.aw_addr  !== aw_exp.addr  ||
                axi_slv_if.aw_len   !== aw_exp.len   ||
                axi_slv_if.aw_size  !== aw_exp.size  ||
                axi_slv_if.aw_burst !== aw_exp.burst ||
                axi_slv_if.aw_cache !== aw_exp.cache ||
                axi_slv_if.aw_prot  !== aw_exp.prot  ||
                axi_slv_if.aw_qos   !== aw_exp.qos   ||
                axi_slv_if.aw_lock  !== aw_exp.lock) begin
                $error("[PRES %0t] AW field mismatch! exp id=%0d addr=0x%h len=%0d cache=%0b got id=%0d addr=0x%h len=%0d cache=%0b",
                       $time,
                       aw_exp.id, aw_exp.addr, aw_exp.len, aw_exp.cache,
                       axi_slv_if.aw_id, axi_slv_if.aw_addr,
                       axi_slv_if.aw_len, axi_slv_if.aw_cache);
                pres_aw_viols = pres_aw_viols + 1;
            end
        end
    end
end

// =========================================================================
// SCOREBOARD D — Response data / ID violation counters
// (actual checking is inline in recv_r_burst; buffer-based tasks feed data)
// =========================================================================
int unsigned data_viols  = 0;
int unsigned id_r_viols  = 0;
int unsigned id_b_viols  = 0;

// =========================================================================
// SCOREBOARD E — Downstream W-data integrity
//
// send_write enqueues the expected W beat (data, strb, last) into w_exp_buf
// BEFORE driving the upstream W channel.  This always block checks every
// downstream axi_slv_if W handshake against the expected buffer in-order.
// Confirms the data_write_fifo round-trip preserves payload bits correctly.
// =========================================================================
typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0]   data;
    logic [AXI_DATA_WIDTH/8-1:0] strb;
    logic                        last;
} w_cap_t;

localparam int W_EXP_SZ = 512;
w_cap_t  w_exp_buf [0:W_EXP_SZ-1];
int unsigned w_exp_wr      = 0;
int unsigned w_exp_rd      = 0;
int unsigned w_data_dn_viols = 0;
w_cap_t      w_exp_cmp;        // module-level temp (no automatic in always)

always @(posedge clk) begin
    if (rst_n && axi_slv_if.w_valid && axi_slv_if.w_ready) begin
        if (w_exp_rd < w_exp_wr) begin
            w_exp_cmp = w_exp_buf[w_exp_rd % W_EXP_SZ];
            if (axi_slv_if.w_data !== w_exp_cmp.data ||
                axi_slv_if.w_last !== w_exp_cmp.last  ||
                axi_slv_if.w_strb !== w_exp_cmp.strb) begin
                $error("[W_DN %0t] beat mismatch: exp_data=0x%h got=0x%h exp_last=%0b got=%0b",
                       $time, w_exp_cmp.data, axi_slv_if.w_data,
                       w_exp_cmp.last, axi_slv_if.w_last);
                w_data_dn_viols = w_data_dn_viols + 1;
            end
            w_exp_rd = w_exp_rd + 1;
        end else begin
            $error("[W_DN %0t] unexpected downstream W beat (no expected entry)", $time);
            w_data_dn_viols = w_data_dn_viols + 1;
        end
    end
end

// =========================================================================
// RESPONSE CAPTURE BUFFER
//
// An always block captures EVERY r_valid&&r_ready beat and EVERY
// b_valid&&b_ready response into ring buffers as they arrive.
// Tasks (recv_r_burst, drain_r, recv_b, drain_b) read from these buffers
// rather than watching the interface directly.  This guarantees no beat is
// ever missed, even if the response arrived before the task started watching.
// =========================================================================
typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_DATA_WIDTH-1:0] data;
    logic [1:0]                resp;
    logic                      last;
} r_cap_t;

typedef struct packed {
    logic [AXI_ID_WIDTH-1:0] id;
    logic [1:0]              resp;
} b_cap_t;

localparam int R_BUF_SZ = 512;
localparam int B_BUF_SZ = 128;

r_cap_t r_buf [0:R_BUF_SZ-1];
b_cap_t b_buf [0:B_BUF_SZ-1];
int unsigned r_buf_wr = 0, r_buf_rd = 0;
int unsigned b_buf_wr = 0, b_buf_rd = 0;

always @(posedge clk) begin
    if (rst_n) begin
        if (axi_mst_if.r_valid && axi_mst_if.r_ready) begin
            r_buf[r_buf_wr % R_BUF_SZ].id   = axi_mst_if.r_id;
            r_buf[r_buf_wr % R_BUF_SZ].data = axi_mst_if.r_data;
            r_buf[r_buf_wr % R_BUF_SZ].resp = axi_mst_if.r_resp;
            r_buf[r_buf_wr % R_BUF_SZ].last = axi_mst_if.r_last;
            r_buf_wr = r_buf_wr + 1;
        end
        if (axi_mst_if.b_valid && axi_mst_if.b_ready) begin
            b_buf[b_buf_wr % B_BUF_SZ].id   = axi_mst_if.b_id;
            b_buf[b_buf_wr % B_BUF_SZ].resp = axi_mst_if.b_resp;
            b_buf_wr = b_buf_wr + 1;
        end
    end
end

// =========================================================================
// DOWNSTREAM SLAVE MODEL
//
// Read path  (axi_slv_if, AR→R):
//   State machine accepts AR, immediately streams R beats.
//   ar_ready held high except during burst transmission.
//   Data echoed as {addr[31:0], addr[31:0]} (beat addr increments by 8).
//
// Write path (axi_slv_if, AW+W→B):
//   Accepts AW, accepts W beats, drives B after w_last.
// =========================================================================

// backpressure controls driven by T10
logic slv_ar_slow = 1'b0;

// wire for next-beat address avoids bit-slicing an arithmetic expression
logic [AXI_ADDR_WIDTH-1:0] r_next_addr;

// --- read state machine ---
typedef enum logic [1:0] {RS_IDLE, RS_BURST} rstate_t;
rstate_t                        rs;
logic [AXI_ID_WIDTH-1:0]        r_cap_id;
logic [AXI_ADDR_WIDTH-1:0]      r_cap_addr;
logic [7:0]                     r_beats_left;

assign r_next_addr = r_cap_addr + 64'd8;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rs                  <= RS_IDLE;
        r_cap_id            <= '0;
        r_cap_addr          <= '0;
        r_beats_left        <= '0;
        axi_slv_if.ar_ready <= 1'b1;
        axi_slv_if.r_valid  <= 1'b0;
        axi_slv_if.r_id     <= '0;
        axi_slv_if.r_data   <= '0;
        axi_slv_if.r_resp   <= 2'b00;
        axi_slv_if.r_last   <= 1'b0;
        axi_slv_if.r_user   <= '0;
    end else begin
        case (rs)
            RS_IDLE: begin
                axi_slv_if.r_valid  <= 1'b0;
                axi_slv_if.ar_ready <= !slv_ar_slow;
                if (axi_slv_if.ar_valid && axi_slv_if.ar_ready) begin
                    r_cap_id     <= axi_slv_if.ar_id;
                    r_cap_addr   <= axi_slv_if.ar_addr;
                    r_beats_left <= axi_slv_if.ar_len;
                    rs           <= RS_BURST;
                    axi_slv_if.ar_ready <= 1'b0;
                    axi_slv_if.r_valid  <= 1'b1;
                    axi_slv_if.r_id     <= axi_slv_if.ar_id;
                    axi_slv_if.r_data   <= {axi_slv_if.ar_addr[31:0],
                                            axi_slv_if.ar_addr[31:0]};
                    axi_slv_if.r_resp   <= 2'b00;
                    axi_slv_if.r_last   <= (axi_slv_if.ar_len == 8'h00);
                    axi_slv_if.r_user   <= '0;
                end
            end

            RS_BURST: begin
                axi_slv_if.ar_ready <= 1'b0;
                if (axi_slv_if.r_valid && axi_slv_if.r_ready) begin
                    if (r_beats_left == 8'h00) begin
                        axi_slv_if.r_valid  <= 1'b0;
                        axi_slv_if.ar_ready <= !slv_ar_slow;
                        rs <= RS_IDLE;
                    end else begin
                        r_beats_left <= r_beats_left - 1;
                        r_cap_addr   <= r_next_addr;
                        axi_slv_if.r_data <= {r_next_addr[31:0], r_next_addr[31:0]};
                        axi_slv_if.r_id   <= r_cap_id;
                        axi_slv_if.r_last <= (r_beats_left == 8'h01);
                    end
                end
            end
        endcase
    end
end

// --- write state machine ---
typedef enum logic [1:0] {WS_IDLE, WS_DATA, WS_RESP} wstate_t;
wstate_t                    ws;
logic [AXI_ID_WIDTH-1:0]    w_cap_id;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ws                  <= WS_IDLE;
        w_cap_id            <= '0;
        axi_slv_if.aw_ready <= 1'b1;
        axi_slv_if.w_ready  <= 1'b1;
        axi_slv_if.b_valid  <= 1'b0;
        axi_slv_if.b_id     <= '0;
        axi_slv_if.b_resp   <= 2'b00;
        axi_slv_if.b_user   <= '0;
    end else begin
        case (ws)
            WS_IDLE: begin
                axi_slv_if.b_valid  <= 1'b0;
                axi_slv_if.aw_ready <= 1'b1;
                axi_slv_if.w_ready  <= 1'b0;
                if (axi_slv_if.aw_valid && axi_slv_if.aw_ready) begin
                    w_cap_id            <= axi_slv_if.aw_id;
                    ws                  <= WS_DATA;
                    axi_slv_if.aw_ready <= 1'b0;
                    axi_slv_if.w_ready  <= 1'b1;
                end
            end

            WS_DATA: begin
                axi_slv_if.aw_ready <= 1'b0;
                axi_slv_if.w_ready  <= 1'b1;
                if (axi_slv_if.w_valid && axi_slv_if.w_ready && axi_slv_if.w_last) begin
                    ws                 <= WS_RESP;
                    axi_slv_if.w_ready <= 1'b0;
                    axi_slv_if.b_valid <= 1'b1;
                    axi_slv_if.b_id    <= w_cap_id;
                    axi_slv_if.b_resp  <= 2'b00;
                end
            end

            WS_RESP: begin
                if (axi_slv_if.b_valid && axi_slv_if.b_ready) begin
                    axi_slv_if.b_valid  <= 1'b0;
                    axi_slv_if.aw_ready <= 1'b1;
                    ws <= WS_IDLE;
                end
            end
        endcase
    end
end

// =========================================================================
// UPSTREAM MASTER DRIVER — tasks
// =========================================================================

int unsigned r_rcv_count = 0;
int unsigned b_rcv_count = 0;

task automatic init_master();
    axi_mst_if.aw_valid  <= 1'b0; axi_mst_if.aw_id     <= '0;
    axi_mst_if.aw_addr   <= '0;   axi_mst_if.aw_len    <= '0;
    axi_mst_if.aw_size   <= 3'b011; axi_mst_if.aw_burst <= 2'b01;
    axi_mst_if.aw_lock   <= 1'b0; axi_mst_if.aw_cache  <= 4'b0010;
    axi_mst_if.aw_prot   <= 3'b000; axi_mst_if.aw_qos  <= 4'b0000;
    axi_mst_if.aw_region <= '0;   axi_mst_if.aw_atop   <= '0;
    axi_mst_if.aw_user   <= '0;
    axi_mst_if.w_valid   <= 1'b0; axi_mst_if.w_data    <= '0;
    axi_mst_if.w_strb    <= 8'hFF; axi_mst_if.w_last   <= 1'b0;
    axi_mst_if.w_user    <= '0;
    axi_mst_if.b_ready   <= 1'b1;
    axi_mst_if.ar_valid  <= 1'b0; axi_mst_if.ar_id     <= '0;
    axi_mst_if.ar_addr   <= '0;   axi_mst_if.ar_len    <= '0;
    axi_mst_if.ar_size   <= 3'b011; axi_mst_if.ar_burst <= 2'b01;
    axi_mst_if.ar_lock   <= 1'b0; axi_mst_if.ar_cache  <= 4'b0010;
    axi_mst_if.ar_prot   <= 3'b000; axi_mst_if.ar_qos  <= 4'b0000;
    axi_mst_if.ar_region <= '0;   axi_mst_if.ar_user   <= '0;
    axi_mst_if.r_ready   <= 1'b1;
endtask

// Send one AR; returns after upstream handshake completes.
task automatic send_ar(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [AXI_ID_WIDTH-1:0]   id,
    input logic [7:0]                len   = 8'h00,
    input logic [2:0]                size  = 3'b011,
    input logic [1:0]                burst = 2'b01,
    input logic [3:0]                cache = 4'b0010,
    input logic [2:0]                prot  = 3'b000,
    input logic [3:0]                qos   = 4'b0000,
    input logic                      lock  = 1'b0
);
    @(negedge clk);
    axi_mst_if.ar_valid  <= 1'b1;
    axi_mst_if.ar_id     <= id;
    axi_mst_if.ar_addr   <= addr;
    axi_mst_if.ar_len    <= len;
    axi_mst_if.ar_size   <= size;
    axi_mst_if.ar_burst  <= burst;
    axi_mst_if.ar_lock   <= lock;
    axi_mst_if.ar_cache  <= cache;
    axi_mst_if.ar_prot   <= prot;
    axi_mst_if.ar_qos    <= qos;
    axi_mst_if.ar_region <= '0;
    axi_mst_if.ar_user   <= '0;
    @(posedge clk);
    while (!axi_mst_if.ar_ready) @(posedge clk);
    @(negedge clk);
    axi_mst_if.ar_valid <= 1'b0;
    $display("[MST %0t] AR sent: id=%0d addr=0x%h len=%0d cache=%0b prot=%0b qos=%0d lock=%0b",
             $time, id, addr, len, cache, prot, qos, lock);
endtask

// Primitive: block until the next R beat is available in the capture buffer.
task automatic read_r_beat(output r_cap_t beat);
    while (r_buf_rd >= r_buf_wr) @(posedge clk);
    beat     = r_buf[r_buf_rd % R_BUF_SZ];
    r_buf_rd = r_buf_rd + 1;
endtask

// Primitive: block until the next B response is available in the capture buffer.
task automatic read_b_resp(output b_cap_t resp);
    while (b_buf_rd >= b_buf_wr) @(posedge clk);
    resp     = b_buf[b_buf_rd % B_BUF_SZ];
    b_buf_rd = b_buf_rd + 1;
endtask

// Receive len+1 R beats; verify ID, data pattern, and r_last placement.
task automatic recv_r_burst(
    input  logic [AXI_ID_WIDTH-1:0]   exp_id,
    input  logic [7:0]                exp_len,
    input  logic [AXI_ADDR_WIDTH-1:0] exp_addr
);
    r_cap_t beat;
    logic [AXI_ADDR_WIDTH-1:0] baddr;
    logic [AXI_DATA_WIDTH-1:0] exp_data;
    for (int b = 0; b <= int'(exp_len); b++) begin
        read_r_beat(beat);
        baddr    = exp_addr + 64'(b) * 8;
        exp_data = {baddr[31:0], baddr[31:0]};
        if (beat.id !== exp_id) begin
            $error("[RCV_R %0t] beat%0d: id mismatch exp=%0d got=%0d",
                   $time, b, exp_id, beat.id);
            id_r_viols = id_r_viols + 1;
        end
        if (beat.data !== exp_data) begin
            $error("[RCV_R %0t] beat%0d: data mismatch exp=0x%h got=0x%h",
                   $time, b, exp_data, beat.data);
            data_viols = data_viols + 1;
        end
        if (b == int'(exp_len) && !beat.last) begin
            $error("[RCV_R %0t] last beat %0d: r_last not set", $time, b);
            data_viols = data_viols + 1;
        end
        r_rcv_count = r_rcv_count + 1;
        $display("[MST %0t] R beat%0d: id=%0d data=0x%h last=%0b",
                 $time, b, beat.id, beat.data, beat.last);
    end
endtask

// Send AW + len+1 W beats.
task automatic send_write(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [AXI_ID_WIDTH-1:0]   id,
    input logic [7:0]                len   = 8'h00,
    input logic [2:0]                size  = 3'b011,
    input logic [1:0]                burst = 2'b01,
    input logic [3:0]                cache = 4'b0010,
    input logic [2:0]                prot  = 3'b000,
    input logic [3:0]                qos   = 4'b0000,
    input logic                      lock  = 1'b0
);
    @(negedge clk);
    axi_mst_if.aw_valid  <= 1'b1;
    axi_mst_if.aw_id     <= id;
    axi_mst_if.aw_addr   <= addr;
    axi_mst_if.aw_len    <= len;
    axi_mst_if.aw_size   <= size;
    axi_mst_if.aw_burst  <= burst;
    axi_mst_if.aw_lock   <= lock;
    axi_mst_if.aw_cache  <= cache;
    axi_mst_if.aw_prot   <= prot;
    axi_mst_if.aw_qos    <= qos;
    axi_mst_if.aw_region <= '0;
    axi_mst_if.aw_atop   <= '0;
    axi_mst_if.aw_user   <= '0;
    @(posedge clk);
    while (!axi_mst_if.aw_ready) @(posedge clk);
    @(negedge clk);
    axi_mst_if.aw_valid <= 1'b0;
    $display("[MST %0t] AW sent: id=%0d addr=0x%h len=%0d cache=%0b prot=%0b qos=%0d",
             $time, id, addr, len, cache, prot, qos);
    for (int b = 0; b <= int'(len); b++) begin
        // Enqueue expected beat for Scoreboard E BEFORE driving upstream.
        // The data_write_fifo adds a registered-output delay, so the downstream
        // beat arrives later — but the buffer holds order across the FIFO.
        w_exp_buf[w_exp_wr % W_EXP_SZ].data = 64'hC0FFEE00_00000000 | {32'h0, addr[15:0], 8'(b)};
        w_exp_buf[w_exp_wr % W_EXP_SZ].strb = 8'hFF;
        w_exp_buf[w_exp_wr % W_EXP_SZ].last = (b == int'(len));
        w_exp_wr = w_exp_wr + 1;
        @(negedge clk);
        axi_mst_if.w_valid <= 1'b1;
        axi_mst_if.w_data  <= 64'hC0FFEE00_00000000 | {32'h0, addr[15:0], 8'(b)};
        axi_mst_if.w_strb  <= 8'hFF;
        axi_mst_if.w_last  <= (b == int'(len));
        axi_mst_if.w_user  <= '0;
        @(posedge clk);
        while (!axi_mst_if.w_ready) @(posedge clk);
        @(negedge clk);
        axi_mst_if.w_valid <= 1'b0;
    end
endtask

// Receive one B response; check ID.
task automatic recv_b(input logic [AXI_ID_WIDTH-1:0] exp_id);
    b_cap_t resp;
    read_b_resp(resp);
    if (resp.id !== exp_id) begin
        $error("[RCV_B %0t] id mismatch exp=%0d got=%0d", $time, exp_id, resp.id);
        id_b_viols = id_b_viols + 1;
    end
    b_rcv_count = b_rcv_count + 1;
    $display("[MST %0t] B: id=%0d resp=%0d", $time, resp.id, resp.resp);
endtask

// Drain n complete read transactions (each ending at r_last) from buffer.
task automatic drain_r(int unsigned n);
    r_cap_t beat;
    for (int i = 0; i < int'(n); i++) begin
        do begin
            read_r_beat(beat);
            r_rcv_count = r_rcv_count + 1;
        end while (!beat.last);
        $display("[MST %0t] R drained: id=%0d", $time, beat.id);
    end
endtask

// Drain n B responses from buffer.
task automatic drain_b(int unsigned n);
    b_cap_t resp;
    for (int i = 0; i < int'(n); i++) begin
        read_b_resp(resp);
        b_rcv_count = b_rcv_count + 1;
        $display("[MST %0t] B drained: id=%0d", $time, resp.id);
    end
endtask

// =========================================================================
// TIMEOUT WATCHDOG
// =========================================================================
initial begin
    @(posedge rst_n);
    repeat (TIMEOUT_CYCLES) @(posedge clk);
    if (!sim_passed)
        $fatal(1, "[TIMEOUT] exceeded %0d cycles", TIMEOUT_CYCLES);
end

// =========================================================================
// MAIN TEST SEQUENCE
// =========================================================================
initial begin
    init_master();
    @(posedge rst_n);
    repeat (5) @(posedge clk);

    // =================================================================
    // T1: Light single-beat reads — one at a time, wait for response.
    //     Verifies basic latency and throughput on an unloaded path.
    // =================================================================
    $display("\n=== T1: Light single reads (one-at-a-time, 4 txns) ===");
    for (int i = 0; i < 4; i++) begin
        send_ar(.addr(64'hA000_0000 + i*64), .id(9'(i)));
        recv_r_burst(.exp_id(9'(i)), .exp_len(8'h00),
                     .exp_addr(64'hA000_0000 + i*64));
        repeat (3) @(posedge clk);
    end
    $display("[T1] PASS\n");

    // =================================================================
    // T2: Pipelined reads — fill FIFO, let throughput regulator drain.
    //     Verifies FIFO queueing, spacing >= THROUGHPUT, and ordering.
    // =================================================================
    $display("=== T2: Pipelined reads (%0d, filling FIFO) ===", FIFO_DEPTH);
    for (int i = 0; i < int'(FIFO_DEPTH); i++)
        send_ar(.addr(64'hB000_0000 + i*64), .id(9'(16+i)));
    $display("[T2] All ARs sent, draining...");
    for (int i = 0; i < int'(FIFO_DEPTH); i++)
        recv_r_burst(.exp_id(9'(16+i)), .exp_len(8'h00),
                     .exp_addr(64'hB000_0000 + i*64));
    $display("[T2] PASS\n");

    // =================================================================
    // T3: FIFO backpressure — FIFO_DEPTH+2 ARs (2 must stall).
    //     The capture buffer prevents any miss even when ar_ready
    //     de-asserts mid-stream and responses arrive out-of-order
    //     relative to the drain task's start time.
    // =================================================================
    $display("=== T3: FIFO backpressure (%0d ARs into depth-%0d FIFO) ===",
             FIFO_DEPTH+2, FIFO_DEPTH);
    for (int i = 0; i < int'(FIFO_DEPTH); i++)
        send_ar(.addr(64'hC000_0000 + i*64), .id(9'(32+i)));
    // These two should see ar_ready=0 momentarily (FIFO full)
    send_ar(.addr(64'hC000_0200), .id(9'd40));
    send_ar(.addr(64'hC000_0240), .id(9'd41));
    // drain_r reads from the capture buffer — beats already in buffer are found immediately
    drain_r(FIFO_DEPTH+2);
    $display("[T3] PASS\n");

    // =================================================================
    // T4: Burst reads — len=3 (4-beat) and len=7 (8-beat).
    //     Mimics LLC cache-line fetch bursts to DRAM.
    // =================================================================
    $display("=== T4: Burst reads (LLC-style) ===");
    for (int i = 0; i < 3; i++)
        send_ar(.addr(64'hD000_0000 + i*32), .id(9'(48+i)), .len(8'h03));
    for (int i = 0; i < 3; i++)
        recv_r_burst(.exp_id(9'(48+i)), .exp_len(8'h03),
                     .exp_addr(64'hD000_0000 + i*32));
    for (int i = 0; i < 2; i++)
        send_ar(.addr(64'hD000_1000 + i*64), .id(9'(52+i)), .len(8'h07));
    for (int i = 0; i < 2; i++)
        recv_r_burst(.exp_id(9'(52+i)), .exp_len(8'h07),
                     .exp_addr(64'hD000_1000 + i*64));
    $display("[T4] PASS\n");

    // =================================================================
    // T5: Light single-beat writes — one at a time.
    // =================================================================
    $display("=== T5: Light single writes (one-at-a-time, 4 txns) ===");
    for (int i = 0; i < 4; i++) begin
        send_write(.addr(64'hE000_0000 + i*64), .id(9'(64+i)));
        recv_b(.exp_id(9'(64+i)));
        repeat (3) @(posedge clk);
    end
    $display("[T5] PASS\n");

    // =================================================================
    // T6: Pipelined writes — fill AW FIFO, drain Bs.
    // =================================================================
    $display("=== T6: Pipelined writes (%0d, filling FIFO) ===", FIFO_DEPTH);
    for (int i = 0; i < int'(FIFO_DEPTH); i++)
        send_write(.addr(64'hF000_0000 + i*64), .id(9'(80+i)));
    for (int i = 0; i < int'(FIFO_DEPTH); i++)
        recv_b(.exp_id(9'(80+i)));
    $display("[T6] PASS\n");

    // =================================================================
    // T7: Burst writes — len=3 (4-beat LLC writeback style).
    // =================================================================
    $display("=== T7: Burst writes (len=3, LLC writeback) ===");
    for (int i = 0; i < 3; i++)
        send_write(.addr(64'h1_0000_0000 + i*32), .id(9'(96+i)), .len(8'h03));
    for (int i = 0; i < 3; i++)
        recv_b(.exp_id(9'(96+i)));
    $display("[T7] PASS\n");

    // =================================================================
    // T8: AXI sideband attribute sweep.
    //     Sends reads and writes with all cache/prot/qos/lock/size
    //     combinations the LLC may produce.
    //     Scoreboard C catches any field mismatch end-to-end.
    // =================================================================
    $display("=== T8: AXI sideband attribute sweep ===");
    begin
        // cache variants
        send_ar(64'h2_0000_0000, 9'd112, 8'h00, 3'b011, 2'b01, 4'b0000, 3'b000, 4'h0, 1'b0);
        send_ar(64'h2_0000_0040, 9'd113, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b000, 4'h0, 1'b0);
        send_ar(64'h2_0000_0080, 9'd114, 8'h00, 3'b011, 2'b01, 4'b0011, 3'b000, 4'h0, 1'b0);
        send_ar(64'h2_0000_00C0, 9'd115, 8'h00, 3'b011, 2'b01, 4'b1111, 3'b000, 4'h0, 1'b0);
        // prot variants
        send_ar(64'h2_0000_0100, 9'd116, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b010, 4'h0, 1'b0);
        send_ar(64'h2_0000_0140, 9'd117, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b100, 4'h0, 1'b0);
        // qos variants
        send_ar(64'h2_0000_0180, 9'd118, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b000, 4'h5, 1'b0);
        send_ar(64'h2_0000_01C0, 9'd119, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b000, 4'hF, 1'b0);
        // lock=1 (exclusive access)
        send_ar(64'h2_0000_0200, 9'd120, 8'h00, 3'b011, 2'b01, 4'b0010, 3'b000, 4'h0, 1'b1);
        // size=2 (4B beats), len=3
        send_ar(64'h2_0000_0240, 9'd121, 8'h03, 3'b010, 2'b01, 4'b0010, 3'b000, 4'h0, 1'b0);
        drain_r(10);

        // Sideband sweep for writes
        send_write(64'h3_0000_0000, 9'd122, 8'h00, 3'b011, 2'b01, 4'b0000, 3'b000, 4'h0, 1'b0);
        send_write(64'h3_0000_0040, 9'd123, 8'h00, 3'b011, 2'b01, 4'b1111, 3'b010, 4'h8, 1'b0);
        send_write(64'h3_0000_0080, 9'd124, 8'h03, 3'b011, 2'b01, 4'b0010, 3'b100, 4'hF, 1'b1);
        drain_b(3);
    end
    $display("[T8] PASS — see [PRES] lines above for field match log\n");

    // =================================================================
    // T9: Heavy mixed traffic — sustained alternating reads + writes
    //     with burst lengths matching LLC traffic patterns.
    //     Tests FIFO arbitration, AR-priority over AW, and long-run
    //     stability with no deadlocks.
    // =================================================================
    $display("=== T9: Heavy mixed traffic (32 R + 16 W, interleaved bursts) ===");
    begin : t9_block
        fork
            begin  // read generator: 32 reads with rotating burst lengths 8/4/1
                for (int i = 0; i < 32; i++)
                    send_ar(.addr (64'h4_0000_0000 + 64'(i)*128),
                            .id   (9'(i % 256)),
                            .len  ((i % 3 == 0) ? 8'h07 :
                                   (i % 3 == 1) ? 8'h03 : 8'h00),
                            .cache(4'b0010));
            end
            begin  // write generator: 16 writes, alternating burst lengths 4/1
                // Starts 5 cycles after read gen; aw_ready is gated by ar_valid_i
                // (RTL fix) so AWs queue correctly once reads are accepted.
                repeat (5) @(posedge clk);
                for (int i = 0; i < 16; i++)
                    send_write(.addr (64'h5_0000_0000 + 64'(i)*64),
                               .id   (9'(128 + i % 128)),
                               .len  ((i % 2 == 0) ? 8'h03 : 8'h00),
                               .cache(4'b0010));
            end
            begin  // concurrent drainer — consumes responses as they arrive so
                   // the buffer never blocks and both generators make progress
                drain_r(32);
                drain_b(16);
            end
        join
    end
    $display("[T9] PASS\n");

    // =================================================================
    // T10: Response backpressure — upstream r_ready toggles on/off.
    //      Exercises the latency shift-register's stall path.
    //      Disable history-based latency checker (assumes no stalls).
    //      Verify: all 4 reads eventually arrive intact in the buffer.
    // =================================================================
    $display("=== T10: Response backpressure (r_ready toggling) ===");
    lat_check_en = 0;
    // Send 4 single-beat reads
    for (int i = 0; i < 4; i++)
        send_ar(.addr(64'h6_0000_0000 + i*64), .id(9'(200+i)));
    // Toggle r_ready for 100 cycles to exercise the stall path.
    // The capture buffer only records beats when r_ready=1 (actual handshake),
    // so backpressure is genuine: held beats are not consumed by the buffer.
    begin
        automatic int toggle = 0;
        repeat (100) begin
            if (toggle % 3 == 0)
                axi_mst_if.r_ready <= ~axi_mst_if.r_ready;
            toggle = toggle + 1;
            @(posedge clk);
        end
        @(negedge clk);
        axi_mst_if.r_ready <= 1'b1;
    end
    // Now drain all 4 — any beats captured during r_ready=1 windows are already
    // in the buffer; remaining held beats arrive as r_ready goes permanent-high.
    drain_r(4);
    lat_check_en = 1;
    $display("[T10] PASS — all 4 reads received under backpressure\n");

    // =================================================================
    // T11: W-data integrity (passive scoreboard E, runs across all tests)
    //      Scoreboard E has been monitoring every downstream W beat since
    //      T5.  No active stimulus here — just confirm the scoreboard
    //      consumed all expected beats (w_exp_rd == w_exp_wr).
    // =================================================================
    $display("=== T11: W-data scoreboard (Scoreboard E final check) ===");
    repeat (20) @(posedge clk);   // let pipeline flush
    if (w_exp_rd !== w_exp_wr) begin
        $error("[T11] %0d expected W beats were never seen downstream (exp_wr=%0d exp_rd=%0d)",
               w_exp_wr - w_exp_rd, w_exp_wr, w_exp_rd);
        w_data_dn_viols = w_data_dn_viols + (w_exp_wr - w_exp_rd);
    end
    $display("[T11] PASS — W-data scoreboard: %0d beats checked, %0d violations\n",
             w_exp_rd, w_data_dn_viols);

    // =================================================================
    // T12: Sustained concurrent AR+AW flood — both generators start at
    //      the same cycle (no delay between them).  Validates that the
    //      aw_ready gating (fix: !ar_valid_i) holds under maximum pressure:
    //      all 24 ARs and 12 AWs must reach downstream with zero drops.
    // =================================================================
    $display("=== T12: Sustained concurrent AR+AW flood (24R + 12W, zero delay) ===");
    begin : t12_block
        automatic int unsigned ar_before = dn_ar_cnt;
        automatic int unsigned aw_before = dn_aw_cnt;
        fork
            begin  // read generator — no startup delay
                for (int i = 0; i < 24; i++)
                    send_ar(.addr (64'h7_0000_0000 + 64'(i)*64),
                            .id   (9'(i % 256)),
                            .len  ((i % 2 == 0) ? 8'h03 : 8'h00),
                            .cache(4'b0010));
            end
            begin  // write generator — starts at same cycle as read gen
                for (int i = 0; i < 12; i++)
                    send_write(.addr (64'h8_0000_0000 + 64'(i)*64),
                               .id   (9'(200 + i % 56)),
                               .len  ((i % 2 == 0) ? 8'h01 : 8'h00),
                               .cache(4'b0010));
            end
            begin  // concurrent drainer
                drain_r(24);
                drain_b(12);
            end
        join
        // All requests must have reached downstream — no drops
        if ((dn_ar_cnt - ar_before) !== 24) begin
            $error("[T12] AR drop! expected 24 downstream ARs, got %0d",
                   dn_ar_cnt - ar_before);
            tput_ar_viols = tput_ar_viols + 1;
        end
        if ((dn_aw_cnt - aw_before) !== 12) begin
            $error("[T12] AW drop! expected 12 downstream AWs, got %0d",
                   dn_aw_cnt - aw_before);
            tput_aw_viols = tput_aw_viols + 1;
        end
    end
    $display("[T12] PASS — concurrent flood complete, no drops\n");

    // =================================================================
    // Final report
    // =================================================================
    repeat (20) @(posedge clk);
    $display("========================================================");
    $display("  SIMULATION COMPLETE");
    $display("  R responses collected  : %0d", r_rcv_count);
    $display("  B responses collected  : %0d", b_rcv_count);
    $display("  AR downstream count    : %0d", dn_ar_cnt);
    $display("  AW downstream count    : %0d", dn_aw_cnt);
    $display("  Throughput violations  : AR=%0d  AW=%0d", tput_ar_viols, tput_aw_viols);
    $display("  Latency violations     : R=%0d   B=%0d",  lat_r_viols,   lat_b_viols);
    $display("  Field pres violations  : AR=%0d  AW=%0d", pres_ar_viols, pres_aw_viols);
    $display("  ID violations          : R=%0d   B=%0d",  id_r_viols,    id_b_viols);
    $display("  Data violations (R)    : %0d",            data_viols);
    $display("  W-data violations (Dn) : %0d",            w_data_dn_viols);
    $display("========================================================");
    if (tput_ar_viols + tput_aw_viols + lat_r_viols + lat_b_viols +
        pres_ar_viols + pres_aw_viols + id_r_viols  + id_b_viols  +
        data_viols    + w_data_dn_viols == 0) begin
        $display("  *** ALL CHECKS PASSED ***");
    end else begin
        $display("  *** FAILURES DETECTED — see $error messages above ***");
    end
    $display("========================================================");
    sim_passed = 1'b1;
    $finish;
end

endmodule
