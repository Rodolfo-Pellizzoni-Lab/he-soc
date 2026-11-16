// ----------------------------------------------------------------------------
// token_bucket_cfg_regs: SHARED token bucket configuration register file
//
// One axi_lite_regs block for all cores. Per-core window of CoreBytes bytes:
//   +0x00  TOKEN_LIMIT      bucket depth (max tokens)
//   +0x04  REFILL_TOKENS    tokens added per refill interval
//   +0x08  REFILL_INTERVAL  refill period in cycles
//   +0x0C  AW_COST          tokens consumed per AW transaction
//   +0x10  AR_COST          tokens consumed per AR transaction
//   +0x14  CTRL             CTRL[0] = enable; CTRL[31:8] and the reserved words are read-only 0
//   +0x18, +0x1C  reserved  read-only 0
// The layout lives in token_bucket_regs_t below (software view: inc/pmu/tb_defines.h).
// ----------------------------------------------------------------------------
module token_bucket_cfg_regs #(
  parameter int unsigned NumCores  = 4,
  // Must equal $bits(token_bucket_regs_t)/8; kept as a parameter for the existing instantiation.
  parameter int unsigned CoreBytes = 32
) (
  input  logic clk_i,
  input  logic rst_ni,

  // AXI4-Lite slave port
  input  ariane_axi_soc::req_lite_t   token_bucket_cfg_req_i,
  output ariane_axi_soc::resp_lite_t  token_bucket_cfg_resp_o,

  // Per-core decoded configuration outputs
  output token_bucket_pkg::token_bucket_cfg_t [NumCores-1:0] token_bucket_cfg_o
);

  // Register layout of one core. axi_lite_regs byte 0 is the least significant byte of a packed
  // vector, so the fields are listed from the highest offset (first) down to +0x00 (last).
  typedef struct packed {
    logic [31:0] rsv1;             // +0x1C
    logic [31:0] rsv0;             // +0x18
    logic [31:0] ctrl;             // +0x14
    logic [31:0] ar_cost;          // +0x10
    logic [31:0] aw_cost;          // +0x0C
    logic [31:0] refill_interval;  // +0x08
    logic [31:0] refill_tokens;    // +0x04
    logic [31:0] token_limit;      // +0x00
  } token_bucket_regs_t;

  localparam int unsigned RegNumBytes = NumCores * CoreBytes;

  if (CoreBytes != $bits(token_bucket_regs_t) / 8) begin : gen_core_bytes_check
    $fatal(1, "token_bucket_cfg_regs: CoreBytes=%0d but token_bucket_regs_t is %0d bytes",
           CoreBytes, $bits(token_bucket_regs_t) / 8);
  end

  typedef logic [7:0] byte_t;

  localparam token_bucket_regs_t CORE_RST = '{
    token_limit:     32'd256,
    refill_tokens:   32'd1,
    refill_interval: 32'd100,
    aw_cost:         32'd1,
    ar_cost:         32'd1,
    ctrl:            32'd0,
    rsv0:            32'd0,
    rsv1:            32'd0
  };

  // Bits set here cannot be written over AXI: they read their reset value (0) and synthesis drops the flops.
  localparam token_bucket_regs_t CORE_RO = '{
    token_limit:     32'h0000_0000,
    refill_tokens:   32'h0000_0000,
    refill_interval: 32'h0000_0000,
    aw_cost:         32'h0000_0000,
    ar_cost:         32'h0000_0000,
    ctrl:            32'hFFFF_FF00,
    rsv0:            32'hFFFF_FFFF,
    rsv1:            32'hFFFF_FFFF
  };

  // axi_lite_regs takes one read-only bit per byte; a byte is read-only if its whole mask byte is set.
  function automatic logic [CoreBytes-1:0] ro_bytes(token_bucket_regs_t mask);
    for (int b = 0; b < CoreBytes; b++) ro_bytes[b] = &mask[8*b +: 8];
  endfunction

  localparam byte_t [RegNumBytes-1:0] REG_RST_VAL   = {NumCores{CORE_RST}};
  localparam logic  [RegNumBytes-1:0] AXI_READ_ONLY = {NumCores{ro_bytes(CORE_RO)}};

  token_bucket_regs_t [NumCores-1:0] regs_q;
  logic [RegNumBytes-1:0] wr_active, rd_active;

  axi_lite_regs #(
    .RegNumBytes  ( RegNumBytes                  ),
    .AxiAddrWidth ( ariane_axi_soc::LiteAddrWidth ),
    .AxiDataWidth ( ariane_axi_soc::LiteDataWidth ),
    .PrivProtOnly ( 1'b0                         ),
    .SecuProtOnly ( 1'b0                         ),
    .AxiReadOnly  ( AXI_READ_ONLY                ),
    .byte_t       ( byte_t                       ),
    .RegRstVal    ( REG_RST_VAL                  ),
    .req_lite_t   ( ariane_axi_soc::req_lite_t   ),
    .resp_lite_t  ( ariane_axi_soc::resp_lite_t  )
  ) u_axi_lite_regs (
    .clk_i       ( clk_i                   ),
    .rst_ni      ( rst_ni                  ),
    .axi_req_i   ( token_bucket_cfg_req_i  ),
    .axi_resp_o  ( token_bucket_cfg_resp_o ),
    .wr_active_o ( wr_active               ),
    .rd_active_o ( rd_active               ),
    .reg_d_i     ( '0                      ),
    .reg_load_i  ( '0                      ),
    .reg_q_o     ( regs_q                  )
  );

  for (genvar c = 0; c < NumCores; c++) begin : gen_core_fields
    assign token_bucket_cfg_o[c] = '{
      token_limit:     regs_q[c].token_limit,
      refill_tokens:   regs_q[c].refill_tokens,
      refill_interval: regs_q[c].refill_interval,
      aw_cost:         regs_q[c].aw_cost,
      ar_cost:         regs_q[c].ar_cost,
      enable:          regs_q[c].ctrl[0]
    };
  end

endmodule
