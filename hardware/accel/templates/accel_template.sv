// __NAME__: accelerator in slot __SLOT__ of the accelerator socket (registers at __BASE__).
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
// Template behaviour: dst[i] = compute(src[i], ARG) for i < LEN (64-bit words), one word in flight.
// Register map (byte offsets):
//   0x00 CTRL    W  bit0 START (self-clearing), bit1 IRQ_EN
//   0x04 STATUS  R  bit0 BUSY, bit1 DONE, bit2 ERR   W  write 1 to bit1 to clear DONE/ERR (and the interrupt)
//   0x08 SRC_LO  0x0C SRC_HI   source address
//   0x10 DST_LO  0x14 DST_HI   destination address
//   0x18 LEN     number of 64-bit words
//   0x1C ARG     operand for compute()
//   0x20 ID      R  0x__ID__
//   0x24 CYCLES  R  clock cycles taken by the last run

module __NAME__ (
  input  logic        clk_i,
  input  logic        rst_ni,
  // register port
  input  logic        reg_req_i,
  input  logic        reg_we_i,
  input  logic [15:0] reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  input  logic [3:0]  reg_wstrb_i,
  output logic        reg_ack_o,
  output logic [31:0] reg_rdata_o,
  // memory port
  output logic        mem_req_o,
  input  logic        mem_gnt_i,
  output logic        mem_we_o,
  output logic [63:0] mem_addr_o,
  output logic [63:0] mem_wdata_o,
  output logic [7:0]  mem_strb_o,
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

  // ------------------------------------------------------------------ registers
  logic [63:0] src_q, dst_q;
  logic [31:0] len_q, arg_q, cycles_q;
  logic        irq_en_q, done_q, err_q;

  typedef enum logic [2:0] { IDLE, RD_REQ, RD_WAIT, WR_REQ, WR_WAIT } state_e;
  state_e      state_q;
  logic [31:0] idx_q;
  logic [63:0] data_q;

  wire busy  = (state_q != IDLE);
  wire start = reg_req_i && reg_we_i && reg_addr_i == 16'h00 && reg_wdata_i[0] && !busy;

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
      16'h20:  reg_rdata_o = 32'h__ID__;
      16'h24:  reg_rdata_o = cycles_q;
      default: reg_rdata_o = 32'h0;
    endcase
  end

  // ------------------------------------------------------------------ engine
  assign mem_req_o   = (state_q == RD_REQ) || (state_q == WR_REQ);
  assign mem_we_o    = (state_q == WR_REQ);
  assign mem_addr_o  = (state_q == WR_REQ) ? dst_q + {idx_q, 3'b000} : src_q + {idx_q, 3'b000};
  assign mem_wdata_o = data_q;
  assign mem_strb_o  = 8'hff;
  assign irq_o       = irq_en_q && done_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      src_q <= '0; dst_q <= '0; len_q <= '0; arg_q <= '0; cycles_q <= '0;
      irq_en_q <= 1'b0; done_q <= 1'b0; err_q <= 1'b0;
      state_q <= IDLE; idx_q <= '0; data_q <= '0;
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
          default: ;
        endcase
      end
      if (busy) cycles_q <= cycles_q + 1;
      // engine
      case (state_q)
        IDLE: if (start) begin
          done_q <= 1'b0; err_q <= 1'b0; idx_q <= '0; cycles_q <= '0;
          state_q <= (len_q == 0) ? IDLE : RD_REQ;
          if (len_q == 0) done_q <= 1'b1;
        end
        RD_REQ:  if (mem_gnt_i) state_q <= RD_WAIT;
        RD_WAIT: if (mem_rvalid_i) begin
          data_q  <= compute(mem_rdata_i, arg_q);
          err_q   <= err_q | mem_err_i;
          state_q <= WR_REQ;
        end
        WR_REQ:  if (mem_gnt_i) state_q <= WR_WAIT;
        WR_WAIT: if (mem_rvalid_i) begin
          err_q <= err_q | mem_err_i;
          if (idx_q + 1 == len_q) begin state_q <= IDLE; done_q <= 1'b1; end
          else begin idx_q <= idx_q + 1; state_q <= RD_REQ; end
        end
        default: state_q <= IDLE;
      endcase
    end
  end

endmodule
