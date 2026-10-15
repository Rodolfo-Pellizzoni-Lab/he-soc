// RISC-V CBQRI capacity controller register interface (CBQRI v1.0, capacity allocation only) for the LLC.
//
// Capacity blocks are the LLC ways (NCBLKS = NumWays). For every RCID and access type (AT 0 data, 1 code) the
// controller keeps a block mask; a request may only allocate (refill into) the ways of the mask of its
// (RCID, AT). Hits are not restricted. The masks go to the hit/miss unit on `mask_o`.
//
// Registers (offsets in the block, 64-bit; a 32-bit bus accesses them as two words, low word first):
//   0x00 cc_capabilities  RO  VER = 0x10, NCBLKS = NumWays, FRCID = 0, CUNITS = 0, RPFX = 0, P = 0
//   0x08 cc_mon_ctl       RO  zero (no capacity usage monitoring)
//   0x10 cc_mon_ctr_val   RO  zero
//   0x18 cc_alloc_ctl     OP[4:0] AT[7:5] RCID[19:8] STATUS[38:32] BUSY[39] (BUSY is always 0: operations complete
//                         in the cycle of the write). A write of the byte holding OP starts the operation.
//   0x20 cc_block_mask    bits NumWays-1:0 read-write, the rest read-only zero
//   0x28 cc_cunits        RO  zero (CUNITS = 0)
// OP: 1 CONFIG_LIMIT (mask of (RCID, AT) := cc_block_mask), 2 READ_LIMIT (cc_block_mask := mask of (RCID, AT)),
//     anything else (FLUSH_RCID included, FRCID = 0) -> STATUS 2.
// STATUS: 1 success, 2 invalid/unsupported OP, 3 invalid RCID (>= 2^RcidWidth), 4 invalid AT (> 1),
//         5 invalid block mask (CONFIG_LIMIT with an all-zero mask).
// Reset: every (RCID, AT) may use every way.
module axi_llc_cbqri_cc #(
  parameter int unsigned NumWays     = 32'd16,
  parameter int unsigned RcidWidth   = 32'd4,
  parameter int unsigned DataWidth   = 32'd32,   // AXI4-Lite data width: 32 or 64
  parameter type         lite_req_t  = logic,
  parameter type         lite_resp_t = logic,
  localparam int unsigned NumRcid    = 2**RcidWidth
) (
  input  logic                                   clk_i,
  input  logic                                   rst_ni,
  input  lite_req_t                              req_i,
  output lite_resp_t                             resp_o,
  output logic [NumRcid-1:0][1:0][NumWays-1:0]   mask_o
);

  typedef logic [NumWays-1:0] mask_t;

  mask_t [NumRcid-1:0][1:0] table_q;
  mask_t                    block_mask_q;
  logic  [4:0]              op_q;
  logic  [2:0]              at_q;
  logic  [11:0]             rcid_q;
  logic  [6:0]              status_q;
  logic                     b_valid_q, r_valid_q;
  logic  [DataWidth-1:0]    r_data_q;

  assign mask_o = table_q;

  // 64-bit register value at word index idx (addr[5:3])
  function automatic logic [63:0] reg_value(logic [2:0] idx);
    case (idx)
      3'd0:    return {33'd0, 4'd0, 1'b0, 1'b0, 1'b0, 16'(NumWays), 8'h10};
      3'd3:    return {24'd0, 1'b0, status_q, 12'd0, rcid_q, at_q, op_q};
      3'd4:    return 64'(block_mask_q);
      default: return 64'd0;
    endcase
  endfunction

  // 64-bit lane view of a bus access
  function automatic logic [63:0] lane_data(logic [DataWidth-1:0] d, logic hi);
    if (DataWidth == 32) return hi ? {d[31:0], 32'd0} : {32'd0, d[31:0]};
    else                 return 64'(d);
  endfunction
  function automatic logic [7:0] lane_strb(logic [DataWidth/8-1:0] s, logic hi);
    if (DataWidth == 32) return hi ? {s[3:0], 4'd0} : {4'd0, s[3:0]};
    else                 return 8'(s);
  endfunction
  function automatic logic [DataWidth-1:0] read_lane(logic [63:0] v, logic hi);
    if (DataWidth == 32) return hi ? v[63:32] : v[31:0];
    else                 return v[DataWidth-1:0];
  endfunction
  function automatic logic [63:0] merge(logic [63:0] old, logic [63:0] d, logic [7:0] s);
    logic [63:0] r;
    for (int b = 0; b < 8; b++) r[b*8 +: 8] = s[b] ? d[b*8 +: 8] : old[b*8 +: 8];
    return r;
  endfunction

  wire w_take = req_i.aw_valid && req_i.w_valid && !b_valid_q;
  wire [2:0]  w_idx = req_i.aw.addr[5:3];
  wire [63:0] w_d   = lane_data(req_i.w.data, req_i.aw.addr[2]);
  wire [7:0]  w_s   = lane_strb(req_i.w.strb, req_i.aw.addr[2]);
  // cc_alloc_ctl after the write: OP [4:0], AT [7:5], RCID [19:8]
  wire [63:0] w_ctl = merge({44'd0, rcid_q, at_q, op_q}, w_d, w_s);
  wire r_take = req_i.ar_valid && !r_valid_q;

  function automatic lite_resp_t mk_resp(logic wt, logic rt, logic bv, logic rv, logic [DataWidth-1:0] rd);
    lite_resp_t r;
    r          = '0;
    r.aw_ready = wt;
    r.w_ready  = wt;
    r.b_valid  = bv;
    r.b.resp   = axi_pkg::RESP_OKAY;
    r.ar_ready = rt;
    r.r_valid  = rv;
    r.r.data   = rd;
    r.r.resp   = axi_pkg::RESP_OKAY;
    return r;
  endfunction
  assign resp_o = mk_resp(w_take, r_take, b_valid_q, r_valid_q, r_data_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      table_q      <= '1;
      block_mask_q <= '0;
      op_q         <= '0;
      at_q         <= '0;
      rcid_q       <= '0;
      status_q     <= '0;
      b_valid_q    <= 1'b0;
      r_valid_q    <= 1'b0;
      r_data_q     <= '0;
    end else begin
      if (b_valid_q && req_i.b_ready) b_valid_q <= 1'b0;
      if (r_valid_q && req_i.r_ready) r_valid_q <= 1'b0;

      if (r_take) begin
        r_valid_q <= 1'b1;
        r_data_q  <= read_lane(reg_value(req_i.ar.addr[5:3]), req_i.ar.addr[2]);
      end

      if (w_take) begin
        b_valid_q <= 1'b1;
        if (req_i.aw.addr[10:6] == '0) begin
          case (w_idx)
            3'd3: begin
              op_q   <= w_ctl[4:0];
              at_q   <= w_ctl[7:5];
              rcid_q <= w_ctl[19:8];
              if (w_s[0]) begin
                // execute the operation
                if (w_ctl[4:0] != 5'd1 && w_ctl[4:0] != 5'd2)        status_q <= 7'd2;
                else if (w_ctl[19:8] >= 12'(NumRcid))            status_q <= 7'd3;
                else if (w_ctl[7:5] > 3'd1)                      status_q <= 7'd4;
                else if (w_ctl[4:0] == 5'd1 && block_mask_q == '0) status_q <= 7'd5;
                else begin
                  status_q <= 7'd1;
                  if (w_ctl[4:0] == 5'd1) table_q[w_ctl[8 +: RcidWidth]][w_ctl[5]] <= block_mask_q;
                  else                block_mask_q                     <= table_q[w_ctl[8 +: RcidWidth]][w_ctl[5]];
                end
              end
            end
            3'd4: block_mask_q <= mask_t'(merge(64'(block_mask_q), w_d, w_s));
            default: ;
          endcase
        end
      end
    end
  end

  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (NumWays <= 64 && NumWays > 0) else $fatal(1, "axi_llc_cbqri_cc: 1..64 ways supported");
    assert (DataWidth == 32 || DataWidth == 64) else $fatal(1, "axi_llc_cbqri_cc: DataWidth 32 or 64");
    assert (RcidWidth >= 1 && RcidWidth <= 12) else $fatal(1, "axi_llc_cbqri_cc: RcidWidth 1..12");
  end
  `endif
  // pragma translate_on
endmodule
