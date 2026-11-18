// example: accelerator in slot 0 of the accelerator socket (registers at 0x10000000).
//
// Port contract (shared by every accelerator, see hardware/accel/README.md):
//   register port: reg_req_i is a one-cycle strobe with reg_addr_i (byte offset in the 64 KB window, word
//     aligned), reg_we_i, reg_wdata_i, reg_wstrb_i. Answer with exactly one reg_ack_o pulse in the same or a later
//     cycle; reg_rdata_o must be valid in the ack cycle.
//   memory port (64-bit, physical byte addresses, 8-byte aligned): hold mem_req_o and the request fields stable
//     until mem_gnt_i; every granted request (read or write) gets one mem_rvalid_i pulse, in order; mem_rdata_i
//     is valid with it for reads; mem_err_i flags a bus error. mem_req_o must not depend combinationally on
//     mem_gnt_i. Traffic goes through a port of the coherence unit: coherent with the cores' caches (see README).
//   irq_o: level, routed to PLIC interrupt ID 9 (shared by all slots).
//
// Template behaviour: dst[i] = compute(src[i], ARG) for i < LEN (64-bit words), one word in flight, one job at a time.
// A job is started either through the registers (START) or by submitting a descriptor to the job queue (SUBMIT).
// Every DMA request of a job carries the QoS tag of the register write that started or submitted it (reg_user_i of
// that write): per-job tags ("Design 1", hardware/docs/qos.md "Device DMA").
// Register map (byte offsets):
//   0x00 CTRL    W  bit0 START (self-clearing, ignored while BUSY), bit1 IRQ_EN
//   0x04 STATUS  R  bit0 BUSY, bit1 DONE, bit2 ERR   W  write 1 to bit1 to clear DONE/ERR (and the interrupt)
//   0x08 SRC_LO  0x0C SRC_HI   source address
//   0x10 DST_LO  0x14 DST_HI   destination address
//   0x18 LEN     number of 64-bit words
//   0x1C ARG     operand for compute()
//   0x20 ID      R  0xAC0C9B9F
//   0x24 CYCLES  R  clock cycles taken by the last job
//   0x28 TAG     R  the tag of the running (or last) job: the user field of the write that started or submitted it
//   0x40 SUBMIT  W  descriptor address >> 3 (32-bit write): queues {descriptor, tag of this write}; when the queue is
//                   full the job is dropped (QSTAT.OVF, DROPPED)
//   0x44 QSTAT   R  [7:0] jobs waiting (submitted, not started), [15:8] queue depth (0: no queue), [16] OVF
//                W  write 1 to bit 16 to clear OVF
//   0x48 DROPPED R  number of SUBMITs dropped because the queue was full
// Job descriptor (32 bytes, 8-byte aligned, read by the accelerator with the job's tag):
//   +0x00 SRC   +0x08 DST   +0x10 [31:0] LEN, [63:32] ARG
//   +0x18 completion, written by the accelerator when the job ends (with the job's tag):
//         [0] DONE, [1] ERR (bus error), [31:16] the job's tag, [63:32] cycles
// Queued jobs run in submission order, when the engine is idle; a START in the same cycle goes first. A queued job
// sets DONE when its completion is written (the interrupt, if IRQ_EN) and ORs its ERR into STATUS.ERR.

module example (
  input  logic        clk_i,
  input  logic        rst_ni,
  // register port
  input  logic        reg_req_i,
  input  logic        reg_we_i,
  input  logic [15:0] reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  input  logic [15:0] reg_user_i,   // who is accessing: SoC user field (port, RCID, MCID, AT)
  output logic        reg_ack_o,
  output logic [31:0] reg_rdata_o,
  // memory port
  output logic        mem_req_o,
  input  logic        mem_gnt_i,
  output logic        mem_we_o,
  output logic [63:0] mem_addr_o,
  output logic [63:0] mem_wdata_o,
  output logic [7:0]  mem_strb_o,
  output logic [15:0] mem_user_o,   // QoS tag of this request (SoC user layout)
  input  logic        mem_rvalid_i,
  input  logic [63:0] mem_rdata_i,
  input  logic        mem_err_i,
  // interrupt
  output logic        irq_o
);

  // ===== compute: the per-word function of this accelerator =====
  function automatic logic [63:0] compute(logic [63:0] x, logic [31:0] arg);
    return x + 64'(arg);
  endfunction

  // job-queue depth (build knob ACCEL_JOB_DEPTH, 0..255; 0 removes the queue: SUBMIT is ignored, QSTAT reads 0)
`ifdef ACCEL_JOB_DEPTH
  localparam int unsigned JobDepth = `ACCEL_JOB_DEPTH;
`else
  localparam int unsigned JobDepth = 4;
`endif
  localparam int unsigned JobDim = (JobDepth > 0) ? JobDepth : 1;
  localparam int unsigned JobW   = (JobDim > 1) ? $clog2(JobDim) : 1;

  // ------------------------------------------------------------------ registers
  logic [63:0] src_q, dst_q;
  logic [31:0] len_q, arg_q, cycles_q;
  logic        irq_en_q, done_q, err_q;
  logic [15:0] tag_q;   // the tag of the running job: user field of the write that started or submitted it

  // job queue: descriptor address >> 3 and the submitter's tag
  logic [JobDim-1:0][31:0] q_desc_q;
  logic [JobDim-1:0][15:0] q_tag_q;
  logic [JobW-1:0]         q_wp_q, q_rp_q;
  logic [7:0]              q_cnt_q;
  logic                    q_ovf_q;
  logic [31:0]             q_drop_q;

  typedef enum logic [3:0] { IDLE, DS_REQ, DS_WAIT, RD_REQ, RD_WAIT, WR_REQ, WR_WAIT, CP_REQ, CP_WAIT } state_e;
  state_e      state_q;
  logic [63:0] j_src_q, j_dst_q, j_desc_q;   // the running job
  logic [31:0] j_len_q, j_arg_q;
  logic        j_queued_q, j_err_q;
  logic [1:0]  d_idx_q;                      // descriptor word being read
  logic [31:0] idx_q;
  logic [63:0] data_q;

  wire busy   = (state_q != IDLE);
  wire start  = reg_req_i && reg_we_i && reg_addr_i == 16'h00 && reg_wstrb_i[0] && reg_wdata_i[0] && !busy;
  wire submit = reg_req_i && reg_we_i && reg_addr_i == 16'h40 && reg_wstrb_i == 4'hF;
  wire q_push = submit && (32'(q_cnt_q) < JobDepth);
  wire q_pop  = (state_q == IDLE) && !start && (q_cnt_q != 8'd0);

  // write strobes applied to a 32-bit register
  function automatic logic [31:0] wmask(logic [31:0] old, logic [31:0] wd, logic [3:0] be);
    for (int b = 0; b < 4; b++) if (be[b]) old[8*b +: 8] = wd[8*b +: 8];
    return old;
  endfunction

  // single-cycle (combinational) acknowledge
  assign reg_ack_o = reg_req_i;
  always_comb begin
    case (reg_addr_i)
      16'h00:  reg_rdata_o = {30'b0, irq_en_q, 1'b0};
      16'h04:  reg_rdata_o = {29'b0, err_q, done_q, busy};
      16'h08:  reg_rdata_o = src_q[31:0];
      16'h0C:  reg_rdata_o = src_q[63:32];
      16'h10:  reg_rdata_o = dst_q[31:0];
      16'h14:  reg_rdata_o = dst_q[63:32];
      16'h18:  reg_rdata_o = len_q;
      16'h1C:  reg_rdata_o = arg_q;
      16'h20:  reg_rdata_o = 32'hAC0C9B9F;
      16'h24:  reg_rdata_o = cycles_q;
      16'h28:  reg_rdata_o = {16'b0, tag_q};
      16'h44:  reg_rdata_o = {15'b0, q_ovf_q, 8'(JobDepth), q_cnt_q};
      16'h48:  reg_rdata_o = q_drop_q;
      default: reg_rdata_o = 32'h0;
    endcase
  end

  // ------------------------------------------------------------------ engine
  assign mem_req_o   = (state_q == DS_REQ) || (state_q == RD_REQ) || (state_q == WR_REQ) || (state_q == CP_REQ);
  assign mem_we_o    = (state_q == WR_REQ) || (state_q == CP_REQ);
  assign mem_addr_o  = (state_q == DS_REQ) ? j_desc_q + {59'b0, d_idx_q, 3'b000} :
                       (state_q == CP_REQ) ? j_desc_q + 64'h18 :
                       (state_q == WR_REQ) ? j_dst_q + {29'b0, idx_q, 3'b000} : j_src_q + {29'b0, idx_q, 3'b000};
  assign mem_wdata_o = data_q;
  assign mem_strb_o  = 8'hff;
  assign mem_user_o  = tag_q;
  assign irq_o       = irq_en_q && done_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      src_q <= '0; dst_q <= '0; len_q <= '0; arg_q <= '0; cycles_q <= '0;
      irq_en_q <= 1'b0; done_q <= 1'b0; err_q <= 1'b0; tag_q <= '0;
      q_desc_q <= '0; q_tag_q <= '0; q_wp_q <= '0; q_rp_q <= '0; q_cnt_q <= '0; q_ovf_q <= 1'b0; q_drop_q <= '0;
      state_q <= IDLE; j_src_q <= '0; j_dst_q <= '0; j_desc_q <= '0; j_len_q <= '0; j_arg_q <= '0;
      j_queued_q <= 1'b0; j_err_q <= 1'b0; d_idx_q <= '0; idx_q <= '0; data_q <= '0;
    end else begin
      // register writes
      if (reg_req_i && reg_we_i) begin
        case (reg_addr_i)
          16'h00: irq_en_q <= reg_wstrb_i[0] ? reg_wdata_i[1] : irq_en_q;
          16'h04: if (reg_wstrb_i[0] && reg_wdata_i[1]) begin done_q <= 1'b0; err_q <= 1'b0; end
          16'h08: if (!busy) src_q[31:0]  <= wmask(src_q[31:0],  reg_wdata_i, reg_wstrb_i);
          16'h0C: if (!busy) src_q[63:32] <= wmask(src_q[63:32], reg_wdata_i, reg_wstrb_i);
          16'h10: if (!busy) dst_q[31:0]  <= wmask(dst_q[31:0],  reg_wdata_i, reg_wstrb_i);
          16'h14: if (!busy) dst_q[63:32] <= wmask(dst_q[63:32], reg_wdata_i, reg_wstrb_i);
          16'h18: if (!busy) len_q <= wmask(len_q, reg_wdata_i, reg_wstrb_i);
          16'h1C: if (!busy) arg_q <= wmask(arg_q, reg_wdata_i, reg_wstrb_i);
          16'h44: if (reg_wstrb_i[2] && reg_wdata_i[16]) q_ovf_q <= 1'b0;
          default: ;
        endcase
      end
      // job queue: SUBMIT pushes {descriptor, the submitter's tag}, or counts a drop when full
      if (q_push) begin
        q_desc_q[q_wp_q] <= reg_wdata_i;
        q_tag_q[q_wp_q]  <= reg_user_i;
        q_wp_q           <= (32'(q_wp_q) == JobDim - 1) ? '0 : q_wp_q + 1'b1;
      end else if (submit && JobDepth > 0) begin
        q_ovf_q  <= 1'b1;
        q_drop_q <= q_drop_q + 1;
      end
      if (q_pop) q_rp_q <= (32'(q_rp_q) == JobDim - 1) ? '0 : q_rp_q + 1'b1;
      q_cnt_q <= q_cnt_q + {7'b0, q_push} - {7'b0, q_pop};
      if (busy) cycles_q <= cycles_q + 1;
      // engine
      case (state_q)
        IDLE: if (start) begin
          // job from the registers: DMA tagged with the hart that wrote START
          tag_q <= reg_user_i;
          j_src_q <= src_q; j_dst_q <= dst_q; j_len_q <= len_q; j_arg_q <= arg_q; j_queued_q <= 1'b0;
          done_q <= (len_q == 0); err_q <= 1'b0; idx_q <= '0; cycles_q <= '0;
          state_q <= (len_q == 0) ? IDLE : RD_REQ;
        end else if (q_pop) begin
          // queued job: DMA tagged with the hart that wrote its SUBMIT
          tag_q <= q_tag_q[q_rp_q];
          j_desc_q <= {29'b0, q_desc_q[q_rp_q], 3'b000}; j_queued_q <= 1'b1; j_err_q <= 1'b0;
          d_idx_q <= '0; idx_q <= '0; cycles_q <= '0;
          state_q <= DS_REQ;
        end
        DS_REQ:  if (mem_gnt_i) state_q <= DS_WAIT;
        DS_WAIT: if (mem_rvalid_i) begin
          j_err_q <= j_err_q | mem_err_i;
          case (d_idx_q)
            2'd0:    j_src_q <= mem_rdata_i;
            2'd1:    j_dst_q <= mem_rdata_i;
            default: begin j_len_q <= mem_rdata_i[31:0]; j_arg_q <= mem_rdata_i[63:32]; end
          endcase
          if (d_idx_q != 2'd2) begin d_idx_q <= d_idx_q + 2'd1; state_q <= DS_REQ; end
          else if (j_err_q || mem_err_i || mem_rdata_i[31:0] == 32'd0) begin
            // nothing to do (or the descriptor could not be read): just the completion
            data_q  <= {cycles_q, tag_q, 14'b0, j_err_q | mem_err_i, 1'b1};
            state_q <= CP_REQ;
          end else state_q <= RD_REQ;
        end
        RD_REQ:  if (mem_gnt_i) state_q <= RD_WAIT;
        RD_WAIT: if (mem_rvalid_i) begin
          data_q  <= compute(mem_rdata_i, j_arg_q);
          if (j_queued_q) j_err_q <= j_err_q | mem_err_i;
          else            err_q   <= err_q | mem_err_i;
          state_q <= WR_REQ;
        end
        WR_REQ:  if (mem_gnt_i) state_q <= WR_WAIT;
        WR_WAIT: if (mem_rvalid_i) begin
          if (!j_queued_q) err_q <= err_q | mem_err_i;
          if (idx_q + 1 != j_len_q) begin idx_q <= idx_q + 1; state_q <= RD_REQ; end
          else if (j_queued_q) begin
            data_q  <= {cycles_q, tag_q, 14'b0, j_err_q | mem_err_i, 1'b1};
            j_err_q <= j_err_q | mem_err_i;
            state_q <= CP_REQ;
          end else begin state_q <= IDLE; done_q <= 1'b1; end
        end
        CP_REQ:  if (mem_gnt_i) state_q <= CP_WAIT;
        CP_WAIT: if (mem_rvalid_i) begin
          done_q  <= 1'b1;
          err_q   <= err_q | j_err_q | mem_err_i;
          state_q <= IDLE;
        end
        default: state_q <= IDLE;
      endcase
    end
  end

endmodule
