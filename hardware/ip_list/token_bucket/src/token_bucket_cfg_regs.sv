// ----------------------------------------------------------------------------
// token_bucket_cfg_regs: SHARED token bucket configuration register file
//
// One axi_lite_regs block for all cores.
//
// Per-core register map (byte offsets within each CoreBytes window):
//   +0x00  TOKEN_LIMIT      |  bucket depth (max tokens)
//   +0x04  REFILL_TOKENS    |  tokens added per refill interval
//   +0x08  REFILL_INTERVAL  |  refill period in cycles
//   +0x0C  AW_COST          |  tokens consumed per AW transaction
//   +0x10  AR_COST          |  tokens consumed per AR transaction
//   +0x14  CTRL             |  1-bit enable. CTRL[0]
//   +0x18  reserved
//   +0x1C  reserved
//   (CoreBytes = 32; +0x20 starts next core's window)
// ----------------------------------------------------------------------------
module token_bucket_cfg_regs #(
  parameter int unsigned NumCores  = 4,
  parameter int unsigned CoreBytes = 32
) (
  input  logic clk_i,
  input  logic rst_ni,

  //AXI4-Lite Slave Port
  input  ariane_axi_soc::req_lite_t   token_bucket_cfg_req_i,
  output ariane_axi_soc::resp_lite_t  token_bucket_cfg_resp_o,

  // Per-core decoded configuration outputs 
  output token_bucket_pkg::token_bucket_cfg_t [NumCores-1:0] token_bucket_cfg_o
);

  localparam int unsigned RegNumBytes  = NumCores * CoreBytes; //Total Bytes of a register file.
  localparam int unsigned CfgAddrWidth = ariane_axi_soc::LiteAddrWidth;
  localparam int unsigned CfgDataWidth = ariane_axi_soc::LiteDataWidth;

  typedef logic [7:0] byte_t;

  //defaults: limit=256, tokens=1, interval=100,
  // aw_cost=1, ar_cost=1, ctrl=0 (disabled).
  localparam byte_t [CoreBytes-1:0] CORE_RST_DEFAULTS = {
    8'h00, 8'h00, 8'h00, 8'h00,   // reserved        (+0x1C)
    8'h00, 8'h00, 8'h00, 8'h00,   // reserved        (+0x18)
    8'h00, 8'h00, 8'h00, 8'h00,   // CTRL            (+0x14)
    8'h00, 8'h00, 8'h00, 8'h01,   // AR_COST         (+0x10) = 1
    8'h00, 8'h00, 8'h00, 8'h01,   // AW_COST         (+0x0C) = 1
    8'h00, 8'h00, 8'h00, 8'h64,   // REFILL_INTERVAL (+0x08) = 100
    8'h00, 8'h00, 8'h00, 8'h01,   // REFILL_TOKENS   (+0x04) = 1
    8'h00, 8'h00, 8'h01, 8'h00    // TOKEN_LIMIT     (+0x00) = 256
  };

  localparam byte_t [RegNumBytes-1:0] REG_RST_VAL = {NumCores{CORE_RST_DEFAULTS}};
  localparam logic  [RegNumBytes-1:0] AXI_READ_ONLY = {RegNumBytes{1'b0}};

  byte_t [RegNumBytes-1:0] reg_q, reg_d;
  logic  [RegNumBytes-1:0] reg_load, wr_active, rd_active;

  assign reg_d    = '0;
  assign reg_load = '0;

  axi_lite_regs #(
    .RegNumBytes  ( RegNumBytes                  ),
    .AxiAddrWidth ( CfgAddrWidth                 ),
    .AxiDataWidth ( CfgDataWidth                 ),
    .PrivProtOnly ( 1'b0                         ),
    .SecuProtOnly ( 1'b0                         ),
    .AxiReadOnly  ( AXI_READ_ONLY                ),
    .byte_t       ( byte_t                       ),
    .RegRstVal    ( REG_RST_VAL                  ),
    .req_lite_t   ( ariane_axi_soc::req_lite_t   ),
    .resp_lite_t  ( ariane_axi_soc::resp_lite_t  )
  ) u_axi_lite_regs (
    .clk_i       ( clk_i          ),
    .rst_ni      ( rst_ni         ),
    .axi_req_i   ( token_bucket_cfg_req_i  ),
    .axi_resp_o  ( token_bucket_cfg_resp_o ),
    .wr_active_o ( wr_active      ),
    .rd_active_o ( rd_active      ),
    .reg_d_i     ( reg_d          ),
    .reg_load_i  ( reg_load       ),
    .reg_q_o     ( reg_q          )
  );

  //Decoder
  for (genvar c = 0; c < NumCores; c++) begin : gen_core_fields
    localparam int unsigned B = c * CoreBytes; //Byte Offset of Core's Registers in RegMap.
    assign token_bucket_cfg_o[c].token_limit     = {reg_q[B+3],  reg_q[B+2],  reg_q[B+1],  reg_q[B+0]};
    assign token_bucket_cfg_o[c].refill_tokens   = {reg_q[B+7],  reg_q[B+6],  reg_q[B+5],  reg_q[B+4]};
    assign token_bucket_cfg_o[c].refill_interval = {reg_q[B+11], reg_q[B+10], reg_q[B+9],  reg_q[B+8]};
    assign token_bucket_cfg_o[c].aw_cost         = {reg_q[B+15], reg_q[B+14], reg_q[B+13], reg_q[B+12]};
    assign token_bucket_cfg_o[c].ar_cost         = {reg_q[B+19], reg_q[B+18], reg_q[B+17], reg_q[B+16]};
    assign token_bucket_cfg_o[c].enable          =  reg_q[B+20][0];
  end

endmodule
