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
localparam int unsigned LATENCY    = 20;   // match platform host_domain Latency_param
localparam int unsigned THROUGHPUT = 10;
localparam int unsigned FIFO_DEPTH = 8;
localparam int unsigned AXI_ID_WIDTH   = 9;
localparam int unsigned AXI_DATA_WIDTH = 64;
localparam int unsigned AXI_ADDR_WIDTH = 64;
localparam int unsigned AXI_USER_WIDTH = 2;
localparam int          TIMEOUT_CYCLES = 200_000_000; // absolute backstop (huge, for +RUN_QC_MIRROR)
localparam int          STALL_CYCLES   = 500_000;     // no-response watchdog: hang detector during soaks
localparam int unsigned SOAK_RD        = 2000;   // T16 random-soak read count
localparam int unsigned SOAK_WR        = 2000;   // T16 random-soak write count
logic                   quiet          = 1'b0;   // suppress per-transaction $display (set during T17)

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
                if (!quiet) $display("[TPUT %0t] AR#%0d spacing=%0d cyc (expect>=%0d)",
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
                if (!quiet) $display("[TPUT %0t] AW#%0d spacing=%0d cyc (expect>=%0d)",
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
localparam int PRESQ = 256;  // max outstanding per channel

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

localparam int W_EXP_SZ = 4096;
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

localparam int R_BUF_SZ = 4096;
localparam int B_BUF_SZ = 1024;

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

// Downstream (memory-side) backpressure injection — driven by T14.
// When a bp_* enable is high, that slave READY follows slv_bp_ph, a free-running
// 1-cycle toggle, so the memory accepts on alternate cycles. This is where the
// regulator's REG_AR/REG_AW/REG_W must hold VALID + payload stable until
// accepted — the realistic DDR condition the board actually sees.
logic slv_bp_ar = 1'b0;
logic slv_bp_aw = 1'b0;
logic slv_bp_w  = 1'b0;
logic slv_bp_ph = 1'b0;
// T19: store-and-forward slave — when high, the memory withholds AWREADY until
// it also sees WVALID (a spec-legal AXI slave dependency). Exposes any master
// that waits for AWREADY before driving WVALID.
logic slv_aw_needs_w = 1'b0;
logic bp_random   = 1'b0;   // T16: downstream ready pattern becomes random, not alternating
logic soak_active = 1'b0;   // T16: keeps the background upstream ready-togglers alive
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) slv_bp_ph <= 1'b0;
    else        slv_bp_ph <= bp_random ? (($urandom % 2) == 1) : ~slv_bp_ph;

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
                axi_slv_if.ar_ready <= (slv_bp_ar ? slv_bp_ph : 1'b1);
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
                        axi_slv_if.ar_ready <= (slv_bp_ar ? slv_bp_ph : 1'b1);
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
                axi_slv_if.w_ready  <= 1'b0;
                // Store-and-forward (T19): accept AW only once WVALID is also
                // present. Otherwise accept AW independent of W (normal DDR shim).
                if (slv_aw_needs_w)
                    axi_slv_if.aw_ready <= axi_slv_if.aw_valid && axi_slv_if.w_valid;
                else
                    axi_slv_if.aw_ready <= (slv_bp_aw ? slv_bp_ph : 1'b1);
                if (axi_slv_if.aw_valid && axi_slv_if.aw_ready) begin
                    w_cap_id            <= axi_slv_if.aw_id;
                    ws                  <= WS_DATA;
                    axi_slv_if.aw_ready <= 1'b0;
                    axi_slv_if.w_ready  <= (slv_bp_w ? slv_bp_ph : 1'b1);
                end
            end

            WS_DATA: begin
                axi_slv_if.aw_ready <= 1'b0;
                axi_slv_if.w_ready  <= (slv_bp_w ? slv_bp_ph : 1'b1);
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
                    // In store-and-forward mode leave AWREADY low; WS_IDLE recomputes
                    // it from WVALID next cycle. Otherwise re-arm as usual.
                    axi_slv_if.aw_ready <= slv_aw_needs_w ? 1'b0
                                                          : (slv_bp_aw ? slv_bp_ph : 1'b1);
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

// Random burst length weighted toward realistic cache-line sizes, with a tail
// beyond FIFO_DEPTH so the streaming path is exercised. (used by T16)
function automatic logic [7:0] rand_len();
    int unsigned r = $urandom % 100;
    if      (r < 40) rand_len = 8'h00;   // 40%  1-beat
    else if (r < 70) rand_len = 8'h03;   // 30%  4-beat
    else if (r < 90) rand_len = 8'h07;   // 20%  8-beat (cache line)
    else if (r < 97) rand_len = 8'h0F;   //  7% 16-beat (> FIFO depth)
    else             rand_len = 8'h1F;   //  3% 32-beat (> FIFO depth)
endfunction

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
    if (!quiet)
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
    if (!quiet)
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
        if (!quiet) $display("[MST %0t] R drained: id=%0d", $time, beat.id);
    end
endtask

// Drain n B responses from buffer.
task automatic drain_b(int unsigned n);
    b_cap_t resp;
    for (int i = 0; i < int'(n); i++) begin
        read_b_resp(resp);
        b_rcv_count = b_rcv_count + 1;
        if (!quiet) $display("[MST %0t] B drained: id=%0d", $time, resp.id);
    end
endtask

// Send a write with the W beats driven BEFORE the AW (AXI-legal: write data
// may precede its address). Exercises the regulator's independent W buffering:
// beats sit in the W FIFO with no AW present, then bind to the AW when it lands.
// Keep len+1 <= FIFO_DEPTH so all beats can pre-buffer before the AW.
task automatic send_write_wfirst(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [AXI_ID_WIDTH-1:0]   id,
    input logic [7:0]                len = 8'h00
);
    // 1) drive all W beats first — DUT must buffer them with no AW yet
    for (int b = 0; b <= int'(len); b++) begin
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
    // 2) now drive the AW
    @(negedge clk);
    axi_mst_if.aw_valid  <= 1'b1;
    axi_mst_if.aw_id     <= id;
    axi_mst_if.aw_addr   <= addr;
    axi_mst_if.aw_len    <= len;
    axi_mst_if.aw_size   <= 3'b011;
    axi_mst_if.aw_burst  <= 2'b01;
    axi_mst_if.aw_lock   <= 1'b0;
    axi_mst_if.aw_cache  <= 4'b0010;
    axi_mst_if.aw_prot   <= 3'b000;
    axi_mst_if.aw_qos    <= 4'b0000;
    axi_mst_if.aw_region <= '0;
    axi_mst_if.aw_atop   <= '0;
    axi_mst_if.aw_user   <= '0;
    @(posedge clk);
    while (!axi_mst_if.aw_ready) @(posedge clk);
    @(negedge clk);
    axi_mst_if.aw_valid <= 1'b0;
    $display("[MST %0t] (W-first) AW sent: id=%0d addr=0x%h len=%0d", $time, id, addr, len);
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

// No-progress watchdog — during a soak, if no R/B response is drained for
// STALL_CYCLES the memory path has wedged. Fire with the current counts; the
// $fatal runs the in-DUT `final` balance summary, which names the stuck channel.
initial begin : stall_watchdog
    int unsigned last_prog;
    int unsigned idle;
    last_prog = 0;
    idle      = 0;
    @(posedge rst_n);
    forever begin
        @(posedge clk);
        if (!soak_active) begin
            idle      = 0;
            last_prog = r_rcv_count + b_rcv_count;
        end else if ((r_rcv_count + b_rcv_count) != last_prog) begin
            last_prog = r_rcv_count + b_rcv_count;
            idle      = 0;
        end else begin
            idle = idle + 1;
            if (idle > STALL_CYCLES)
                $fatal(1, "[STALL] no response progress for %0d cycles - MEMORY PATH WEDGED (r_rcv=%0d b_rcv=%0d dn_ar=%0d dn_aw=%0d) - see in-DUT balance below",
                       STALL_CYCLES, r_rcv_count, b_rcv_count, dn_ar_cnt, dn_aw_cnt);
        end
    end
end

// =========================================================================
// MAIN TEST SEQUENCE
// =========================================================================
initial begin
    init_master();
    @(posedge rst_n);
    repeat (5) @(posedge clk);

    // =================================================================
    // T18 (opt-in: +RUN_T18): read/write channel INDEPENDENCE.
    //   Reduction of the platform-hang hypothesis to its core. Drive AW0 and
    //   WITHHOLD its W data, then issue a read AR1. Per AXI, reads and writes
    //   are independent channels — AR1 MUST be able to complete while W0 is
    //   still outstanding. If the regulator parks AW0 in REG_W (waiting for W)
    //   in the SHARED AR/AW FIFO and thereby blocks AR1 behind it, the read
    //   never completes -> deadlock (== the on-chip hang: slowdown drained,
    //   LLC stalled). A correct/decoupled design lets AR1 through.
    // =================================================================
    if ($test$plusargs("RUN_T18")) begin : t18
        automatic logic  got_r1 = 1'b0;
        automatic r_cap_t bt;
        $display("\n=== T18: read-behind-delayed-write independence (platform-hang repro) ===");
        // AW0 — drive the write address; deliberately do NOT send its W beat.
        @(negedge clk);
        axi_mst_if.aw_valid <= 1'b1; axi_mst_if.aw_id    <= 9'h50;
        axi_mst_if.aw_addr  <= 64'hD000_0000; axi_mst_if.aw_len <= 8'h00;
        axi_mst_if.aw_size  <= 3'b011; axi_mst_if.aw_burst <= 2'b01;
        axi_mst_if.aw_cache <= 4'b0010; axi_mst_if.aw_prot  <= 3'b000;
        axi_mst_if.aw_qos   <= 4'h0;   axi_mst_if.aw_lock   <= 1'b0;
        axi_mst_if.aw_region<= '0; axi_mst_if.aw_atop <= '0; axi_mst_if.aw_user <= '0;
        @(posedge clk); while (!axi_mst_if.aw_ready) @(posedge clk);
        @(negedge clk); axi_mst_if.aw_valid <= 1'b0;
        $display("[T18] AW0 accepted by the slowdown; its W beat is withheld on purpose");
        // AR1 — a read that must complete while W0 is outstanding (bounded wait).
        fork
            begin
                send_ar(.addr(64'hE000_0000), .id(9'h51));
                read_r_beat(bt);
                got_r1 = 1'b1;
            end
            begin
                repeat (3000) @(posedge clk);
            end
        join_any
        disable fork;
        axi_mst_if.ar_valid <= 1'b0;
        $display("========================================================");
        if (got_r1)
            $display("  [T18] PASS - read completed with the write still outstanding (R/W independent)");
        else
            $display("  [T18] *** RW-DEADLOCK *** read AR1 never completed - blocked behind AW0 parked in REG_W (shared AR/AW FIFO couples reads to writes) == platform hang root cause");
        $display("========================================================");
        sim_passed = 1'b1;
        $finish;
    end

    // =================================================================
    // T19 (opt-in: +RUN_T19): store-and-forward slave — AWREADY gated on
    //   WVALID. AXI4 A3.3.1 forbids a master waiting for AWREADY before
    //   asserting WVALID, precisely because a legal slave may wait for WVALID
    //   before AWREADY. The OLD regulator drove WVALID only in WR_SEND_W (after
    //   its AW was accepted) -> against this slave both sides wait forever
    //   (total deadlock; reads starve too). The concurrent-AW/W regulator
    //   asserts WVALID from cycle one, so every write completes.
    // =================================================================
    if ($test$plusargs("RUN_T19")) begin : t19
        automatic int    got_b = 0;
        automatic int    n_wr  = 6;
        automatic b_cap_t bb;
        $display("\n=== T19: store-and-forward slave (AWREADY waits for WVALID) ===");
        slv_aw_needs_w = 1'b1;                 // memory now needs W before it takes AW
        fork
            begin : drv    // single-beat + burst writes, W fully buffered per AW
                send_write(.addr(64'hF000_0000), .id(9'h60), .len(8'h00));
                $display("[T19 drv] wrote id=96 upstream");
                send_write(.addr(64'hF000_0040), .id(9'h61), .len(8'h03));
                $display("[T19 drv] wrote id=97 upstream");
                send_write(.addr(64'hF000_0100), .id(9'h62), .len(8'h00));
                $display("[T19 drv] wrote id=98 upstream");
                send_write(.addr(64'hF000_0140), .id(9'h63), .len(8'h07));
                $display("[T19 drv] wrote id=99 upstream");
                send_write(.addr(64'hF000_0200), .id(9'h64), .len(8'h00));
                $display("[T19 drv] wrote id=100 upstream");
                send_write(.addr(64'hF000_0240), .id(9'h65), .len(8'h01));
                $display("[T19 drv] wrote id=101 upstream (ALL sent)");
                forever @(posedge clk);        // do NOT let drv end the join_any race
            end
            begin : rcv
                for (int i = 0; i < n_wr; i++) begin
                    read_b_resp(bb);
                    got_b++;
                    $display("[T19 rcv] B #%0d id=%0d @%0t", got_b, bb.id, $time);
                end
            end
            begin : wd     // bounded: the OLD RTL never reaches here (deadlock)
                repeat (200_000) @(posedge clk);
                $display("[T19 wd] watchdog expired at 200k cycles");
            end
        join_any
        disable fork;
        slv_aw_needs_w = 1'b0;
        repeat (2*LATENCY + 4) @(posedge clk);   // let the last B drain the latency pipe
        $display("========================================================");
        if (got_b == n_wr)
            $display("  [T19] PASS - all %0d writes completed against a slave gating AWREADY on WVALID (WVALID never waits on AWREADY)", n_wr);
        else
            $display("  [T19] *** WVALID/AWREADY DEADLOCK *** only %0d/%0d B received - regulator withheld WVALID until AWREADY (AXI4 A3.3.1 violation)", got_b, n_wr);
        $display("========================================================");
        sim_passed = (got_b == n_wr);
        $finish;
    end

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
    // T13: Bursts LONGER than the FIFO depth — must STREAM, not buffer.
    //      A 16- and 32-beat write cannot be fully held (depth is %0d): the
    //      FSM drains from the head while the master refills as space frees.
    //      Proves the len-counter tracks the burst boundary regardless of how
    //      few beats are buffered at once, with no deadlock (watchdog guards).
    // =================================================================
    $display("=== T13: Bursts longer than FIFO depth (%0d) — streaming ===", FIFO_DEPTH);
    send_write(.addr(64'h9_0000_0000), .id(9'd220), .len(8'h0F));   // 16-beat write
    recv_b(.exp_id(9'd220));
    send_write(.addr(64'h9_0002_0000), .id(9'd221), .len(8'h1F));   // 32-beat write
    recv_b(.exp_id(9'd221));
    send_ar(.addr(64'h9_0004_0000), .id(9'd222), .len(8'h0F));      // 16-beat read
    recv_r_burst(.exp_id(9'd222), .exp_len(8'h0F), .exp_addr(64'h9_0004_0000));
    $display("[T13] PASS — long bursts streamed through depth-%0d FIFO, no deadlock\n", FIFO_DEPTH);

    // =================================================================
    // T14: Downstream (memory) backpressure — the slave accepts AR/AW/W on
    //      alternate cycles. This is the realistic DDR condition: REG_AR/
    //      REG_AW/REG_W must hold VALID + payload stable until accepted.
    //      Scoreboards C/E catch any field/W-beat corruption; the in-DUT
    //      checker catches any drop or duplication.
    // =================================================================
    $display("=== T14: Downstream backpressure (memory ready toggles on AR/AW/W) ===");
    slv_bp_ar = 1'b1; slv_bp_aw = 1'b1; slv_bp_w = 1'b1;
    fork
        begin
            for (int i = 0; i < 8; i++)
                send_write(.addr(64'hA_0000_0000 + 64'(i)*64), .id(9'(224 + i)),
                           .len((i % 2 == 0) ? 8'h03 : 8'h00));
        end
        begin
            for (int i = 0; i < 8; i++)
                send_ar(.addr(64'hB_0000_0000 + 64'(i)*64), .id(9'(1 + i)),
                        .len((i % 2 == 0) ? 8'h07 : 8'h00));
        end
        begin
            drain_b(8);
            drain_r(8);
        end
    join
    slv_bp_ar = 1'b0; slv_bp_aw = 1'b0; slv_bp_w = 1'b0;
    $display("[T14] PASS — traffic intact under downstream backpressure\n");

    // =================================================================
    // T15: W-before-AW ordering — the write DATA is driven before its
    //      address (AXI-legal). The regulator buffers W independently and
    //      must still bind the burst to the AW when it arrives.
    // =================================================================
    $display("=== T15: W-before-AW ordering ===");
    send_write_wfirst(.addr(64'hC_0000_0000), .id(9'd240), .len(8'h01));
    recv_b(.exp_id(9'd240));
    send_write_wfirst(.addr(64'hC_0001_0000), .id(9'd241), .len(8'h03));
    recv_b(.exp_id(9'd241));
    $display("[T15] PASS — W-before-AW handled\n");

    // =================================================================
    // T16: CONSTRAINED-RANDOM SOAK — the catch-all.
    //      Random R/W mix, random burst lengths (incl. > FIFO depth),
    //      random sideband, random inter-request gaps, and random ready
    //      backpressure on ALL FIVE channels at once (upstream r/b_ready
    //      toggled here; downstream ar/aw/w randomized in the slave).
    //      Latency checker is off (stalls expected). Correctness is proven
    //      by the in-DUT balance checker (0 drop/dup, 0 in-flight at end),
    //      the field/ID/data/W-integrity scoreboards, and deadlock-freedom
    //      (the watchdog $fatals if anything wedges). Reproducible via the
    //      Makefile SEED (vsim -sv_seed).
    // =================================================================
    $display("=== T16: Constrained-random soak (%0d reads + %0d writes, all-channel random BP) ===",
             SOAK_RD, SOAK_WR);
    begin : t16
        automatic int unsigned r_before  = r_rcv_count;
        automatic int unsigned b_before  = b_rcv_count;
        automatic int unsigned ar_before = dn_ar_cnt;
        automatic int unsigned aw_before = dn_aw_cnt;

        lat_check_en = 0;                       // response stalls expected under BP
        bp_random    = 1'b1;                    // downstream backpressure = random
        slv_bp_ar = 1'b1; slv_bp_aw = 1'b1; slv_bp_w = 1'b1;
        soak_active  = 1'b1;

        // Background upstream ready togglers — persist until soak_active drops,
        // then raise ready so the pipeline can fully flush.
        fork
            begin : r_tog
                while (soak_active) begin
                    @(posedge clk);
                    if (($urandom % 3) == 0) axi_mst_if.r_ready <= ($urandom % 2);
                end
                @(negedge clk); axi_mst_if.r_ready <= 1'b1;
            end
            begin : b_tog
                while (soak_active) begin
                    @(posedge clk);
                    if (($urandom % 3) == 0) axi_mst_if.b_ready <= ($urandom % 2);
                end
                @(negedge clk); axi_mst_if.b_ready <= 1'b1;
            end
        join_none

        // Generators + independent drainers (independent so neither blocks).
        fork
            begin : rd_gen
                for (int i = 0; i < int'(SOAK_RD); i++) begin
                    send_ar(.addr (64'h1_0000_0000 + ((64'($urandom) % 64'h10000) << 6)),
                            .id   (9'($urandom)), .len(rand_len()),
                            .size (3'b011), .burst(2'b01),
                            .cache(4'($urandom)), .prot(3'($urandom)),
                            .qos  (4'($urandom)), .lock(1'($urandom)));
                    repeat ($urandom % 4) @(posedge clk);
                end
            end
            begin : wr_gen
                for (int i = 0; i < int'(SOAK_WR); i++) begin
                    send_write(.addr (64'h2_0000_0000 + ((64'($urandom) % 64'h10000) << 6)),
                               .id   (9'($urandom)), .len(rand_len()),
                               .size (3'b011), .burst(2'b01),
                               .cache(4'($urandom)), .prot(3'($urandom)),
                               .qos  (4'($urandom)), .lock(1'($urandom)));
                    repeat ($urandom % 4) @(posedge clk);
                end
            end
            begin : rd_drain drain_r(SOAK_RD); end
            begin : wr_drain drain_b(SOAK_WR); end
        join

        soak_active = 1'b0;                     // stop togglers -> they raise ready & exit
        repeat (60) @(posedge clk);             // flush pipeline
        bp_random = 1'b0;
        slv_bp_ar = 1'b0; slv_bp_aw = 1'b0; slv_bp_w = 1'b0;
        lat_check_en = 1;

        // Every issued request must have reached downstream — no drops.
        if ((dn_ar_cnt - ar_before) !== int'(SOAK_RD)) begin
            $error("[T16] AR DROP: issued %0d, downstream %0d", SOAK_RD, dn_ar_cnt - ar_before);
            tput_ar_viols = tput_ar_viols + 1;
        end
        if ((dn_aw_cnt - aw_before) !== int'(SOAK_WR)) begin
            $error("[T16] AW DROP: issued %0d, downstream %0d", SOAK_WR, dn_aw_cnt - aw_before);
            tput_aw_viols = tput_aw_viols + 1;
        end
        $display("[T16] drained %0d R beats + %0d B resp (see balance summary for 0 in-flight)",
                 r_rcv_count - r_before, b_rcv_count - b_before);
    end
    $display("[T16] PASS — random soak complete\n");

    // =================================================================
    // T17: QUAD-CORE LLC-MIRROR SOAK  (opt-in: +RUN_QC_MIRROR, size +QC_LINES)
    //      Mirrors the slowdown_qc SW workload as the LLC presents it to the
    //      slowdown's memory port: ONE merged AR stream (cache-line refills for
    //      the 2 reader regions + allocate-reads for the 2 writer regions) and
    //      ONE merged AW+W stream (writebacks for the 2 writer regions). All are
    //      full cache-line bursts (len=7 = 8 beats) at sequential addresses over
    //      4 disjoint 16 MB-apart regions, under random all-channel backpressure.
    //      Huge volume to surface an accumulation / rare-pattern wedge that the
    //      short random soak missed. If the memory path wedges, the stall
    //      watchdog fires and the in-DUT balance summary names the stuck channel.
    // =================================================================
    if ($test$plusargs("RUN_QC_MIRROR")) begin : t17
        int unsigned qc_lines;
        qc_lines = 200000;
        void'($value$plusargs("QC_LINES=%d", qc_lines));
        $display("=== T17: quad-core LLC-mirror soak (%0d lines/stream, len=7 bursts) ===", qc_lines);
        quiet        = 1'b1;                       // silence per-transaction logging
        lat_check_en = 0;
        bp_random    = 1'b1; slv_bp_ar = 1'b1; slv_bp_aw = 1'b1; slv_bp_w = 1'b1;
        soak_active  = 1'b1;
        fork
            begin : qc_rtog
                while (soak_active) begin @(posedge clk); if (($urandom%3)==0) axi_mst_if.r_ready <= ($urandom%2); end
                @(negedge clk); axi_mst_if.r_ready <= 1'b1;
            end
            begin : qc_btog
                while (soak_active) begin @(posedge clk); if (($urandom%3)==0) axi_mst_if.b_ready <= ($urandom%2); end
                @(negedge clk); axi_mst_if.b_ready <= 1'b1;
            end
        join_none
        fork
            // Merged AR stream: refills (regions 0,1 reads) + allocate-reads (regions 2,3 writes)
            begin : qc_ar
                for (int i = 0; i < int'(qc_lines); i++) begin
                    send_ar(.addr(64'h8200_0000 + 64'(i)*64), .id(9'(i)),          .len(8'h07));
                    send_ar(.addr(64'h8300_0000 + 64'(i)*64), .id(9'(64  + i%64)), .len(8'h07));
                    send_ar(.addr(64'h8400_0000 + 64'(i)*64), .id(9'(128 + i%64)), .len(8'h07));
                    send_ar(.addr(64'h8500_0000 + 64'(i)*64), .id(9'(200 + i%56)), .len(8'h07));
                end
            end
            // Merged AW+W stream: writebacks (regions 2,3)
            begin : qc_aw
                for (int i = 0; i < int'(qc_lines); i++) begin
                    send_write(.addr(64'h8400_0000 + 64'(i)*64), .id(9'(128 + i%64)), .len(8'h07));
                    send_write(.addr(64'h8500_0000 + 64'(i)*64), .id(9'(200 + i%56)), .len(8'h07));
                end
            end
            begin : qc_dr drain_r(qc_lines * 4); end   // 4 AR/line
            begin : qc_db drain_b(qc_lines * 2); end   // 2 AW/line
        join
        soak_active = 1'b0;
        repeat (200) @(posedge clk);
        bp_random = 1'b0; slv_bp_ar = 1'b0; slv_bp_aw = 1'b0; slv_bp_w = 1'b0;
        quiet = 1'b0;
        $display("[T17] PASS — quad-core mirror soak complete (%0d reads + %0d writes)",
                 qc_lines*4, qc_lines*2);
    end

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
