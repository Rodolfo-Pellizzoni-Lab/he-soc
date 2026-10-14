// crc32: accelerator in slot 1 of the accelerator socket (registers at 0x10010000).
//
// Port contract (shared by every accelerator, see hardware/accel/README.md):
//   register port: reg_req_i is a one-cycle strobe with reg_addr_i (byte offset in the 64 KB window, word
//     aligned), reg_we_i, reg_wdata_i, reg_wstrb_i. Answer with exactly one reg_ack_o pulse in the same or a later
//     cycle; reg_rdata_o must be valid in the ack cycle.
//   memory port (64-bit, physical byte addresses, 8-byte aligned): hold mem_req_o and the request fields stable
//     until mem_gnt_i; every granted request (read or write) gets one mem_rvalid_i pulse, in order; mem_rdata_i
//     is valid with it for reads; mem_err_i flags a bus error. mem_req_o must not depend combinationally on
//     mem_gnt_i. Traffic is not coherent with the cores' data caches (see README).
//   irq_o: level, routed to PLIC interrupt ID 9 (shared by all slots).
//
// CRC-32/ISO-HDLC (zlib/Ethernet): reflected poly 0xEDB88320, init 0xFFFFFFFF, final XOR 0xFFFFFFFF.
// Reads LEN bytes from SRC (8-byte aligned; address bits [2:0] are ignored) through the memory port, one 64-bit
// word in flight, folding the valid bytes of each word (little-endian, byte 0 first) in one cycle.
// "123456789" -> 0xCBF43926; LEN = 0 -> 0x00000000.
// Register map (byte offsets):
//   0x00 CTRL    W  bit0 START (self-clearing, ignored while BUSY), bit1 IRQ_EN   R bit1 IRQ_EN
//   0x04 STATUS  R  bit0 BUSY, bit1 DONE, bit2 ERR   W  write 1 to bit1 to clear DONE/ERR (and the interrupt)
//   0x08 SRC_LO  0x0C SRC_HI   source address (8-byte aligned)
//   0x10 LEN     length in bytes (any value)
//   0x14 CRC     R  result (final XOR applied); valid when DONE
//   0x20 ID      R  0xC3C32001
//   0x24 CYCLES  R  clock cycles taken by the last run
// irq_o = IRQ_EN && DONE.

module crc32 (
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

  localparam logic [31:0] POLY = 32'hEDB88320;

  // fold the first nbytes (1..8) bytes of d (little-endian) into crc, LSB first
  function automatic logic [31:0] crc_word(logic [31:0] crc, logic [63:0] d, logic [3:0] nbytes);
    logic [31:0] c;
    c = crc;
    for (int i = 0; i < 64; i++) begin
      if (i < 8 * int'(nbytes)) begin
        if (c[0] ^ d[i]) c = (c >> 1) ^ POLY;
        else             c = (c >> 1);
      end
    end
    return c;
  endfunction

  // ------------------------------------------------------------------ registers
  logic [63:0] src_q, addr_q;
  logic [31:0] len_q, rem_q, crc_q, cycles_q;
  logic        irq_en_q, done_q, err_q;

  typedef enum logic [1:0] { IDLE, RD_REQ, RD_WAIT } state_e;
  state_e state_q;

  wire       busy   = (state_q != IDLE);
  wire       start  = reg_req_i && reg_we_i && reg_addr_i == 16'h00 && reg_wstrb_i[0] && reg_wdata_i[0] && !busy;
  wire [3:0] nbytes = (rem_q >= 32'd8) ? 4'd8 : {1'b0, rem_q[2:0]};

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
      16'h10:  reg_rdata_o = len_q;
      16'h14:  reg_rdata_o = ~crc_q;
      16'h20:  reg_rdata_o = 32'hC3C32001;
      16'h24:  reg_rdata_o = cycles_q;
      default: reg_rdata_o = 32'h0;
    endcase
  end

  // ------------------------------------------------------------------ engine
  assign mem_req_o   = (state_q == RD_REQ);
  assign mem_we_o    = 1'b0;
  assign mem_addr_o  = {addr_q[63:3], 3'b000};
  assign mem_wdata_o = 64'h0;
  assign mem_strb_o  = 8'hff;
  assign irq_o       = irq_en_q && done_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      src_q <= '0; addr_q <= '0; len_q <= '0; rem_q <= '0; crc_q <= '1; cycles_q <= '0;
      irq_en_q <= 1'b0; done_q <= 1'b0; err_q <= 1'b0;
      state_q <= IDLE;
    end else begin
      // register writes
      if (reg_req_i && reg_we_i) begin
        case (reg_addr_i)
          16'h00: irq_en_q <= reg_wstrb_i[0] ? reg_wdata_i[1] : irq_en_q;
          16'h04: if (reg_wstrb_i[0] && reg_wdata_i[1]) begin done_q <= 1'b0; err_q <= 1'b0; end
          16'h08: if (!busy) src_q[31:0]  <= wmask(src_q[31:0],  reg_wdata_i, reg_wstrb_i);
          16'h0C: if (!busy) src_q[63:32] <= wmask(src_q[63:32], reg_wdata_i, reg_wstrb_i);
          16'h10: if (!busy) len_q <= wmask(len_q, reg_wdata_i, reg_wstrb_i);
          default: ;
        endcase
      end
      if (busy) cycles_q <= cycles_q + 1;
      // engine
      case (state_q)
        IDLE: if (start) begin
          done_q <= (len_q == 0); err_q <= 1'b0; cycles_q <= '0;
          crc_q  <= 32'hFFFFFFFF;
          addr_q <= src_q; rem_q <= len_q;
          state_q <= (len_q == 0) ? IDLE : RD_REQ;
        end
        RD_REQ:  if (mem_gnt_i) state_q <= RD_WAIT;
        RD_WAIT: if (mem_rvalid_i) begin
          crc_q <= crc_word(crc_q, mem_rdata_i, nbytes);
          err_q <= err_q | mem_err_i;
          if (rem_q <= 32'd8) begin rem_q <= '0; state_q <= IDLE; done_q <= 1'b1; end
          else begin rem_q <= rem_q - 32'd8; addr_q <= addr_q + 64'd8; state_q <= RD_REQ; end
        end
        default: state_q <= IDLE;
      endcase
    end
  end

endmodule
