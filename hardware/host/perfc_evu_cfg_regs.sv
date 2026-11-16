// ----------------------------------------------------------------------------
// perfc_evu_cfg_regs: SHARED EVU configuration register file of the CVA6 cores
//
// One axi_lite_regs block for all cores, at ariane_soc::PerfcEvuBase. Per-core window of CoreBytes bytes:
//   +0x00  EVENT_ID slot 3   bits [4:0] = event code; bits [31:8] read-only 0
//   +0x04  EVENT_ID slot 2
//   +0x08  EVENT_ID slot 1
//   +0x0C  EVENT_ID slot 0
//   +0x10  PC_TRACK0         64-bit PC of milestone 0
//   +0x18  PC_TRACK1
//   +0x20  PC_TRACK2
//   +0x28  PC_TRACK3
//   (CoreBytes = 48; +0x30 starts next core's window)
// The EVENT_ID registers are in reverse slot order (slot 3 at +0x00).
// The layout lives in evu_regs_t below (software view: inc/pmu/evu_defines.h).
// ----------------------------------------------------------------------------
module perfc_evu_cfg_regs #(
  parameter int unsigned NumCores = ariane_soc::NumCVA6
) (
  input  logic clk_i,
  input  logic rst_ni,

  // AXI4-Lite slave port
  input  ariane_axi_soc::req_lite_t   perfc_cfg_req_i,
  output ariane_axi_soc::resp_lite_t  perfc_cfg_resp_o,

  // Per-core decoded configuration outputs, to CVA6's perfc_evu_req_i (slot s in bits [5s +: 5])
  // and pcmiles_evu_req_i (milestone m in bits [64m +: 64])
  output logic [NumCores-1:0][ariane_pkg::NumPerfEvents*ariane_pkg::EventIDBits-1:0] perfc_evu_req_o,
  output logic [NumCores-1:0][ariane_pkg::NumPCMilesRegs*riscv::VLEN-1:0]           pcmiles_evu_req_o
);

  // Register layout of one core. axi_lite_regs byte 0 is the least significant byte of a packed
  // vector, so the fields are listed from the highest offset (first) down to +0x00 (last).
  typedef struct packed {
    logic [63:0] pc_track3;  // +0x28
    logic [63:0] pc_track2;  // +0x20
    logic [63:0] pc_track1;  // +0x18
    logic [63:0] pc_track0;  // +0x10
    logic [31:0] event_id0;  // +0x0C
    logic [31:0] event_id1;  // +0x08
    logic [31:0] event_id2;  // +0x04
    logic [31:0] event_id3;  // +0x00
  } evu_regs_t;

  localparam int unsigned CoreBytes   = $bits(evu_regs_t) / 8;
  localparam int unsigned RegNumBytes = NumCores * CoreBytes;
  localparam int unsigned IdW         = ariane_pkg::EventIDBits;

  // The CPUs and the APMU reach these registers through one window of PerfcEvuLength bytes at PerfcEvuBase.
  if (CoreBytes != ariane_soc::PerfcEvuBytesPerCore || RegNumBytes > ariane_soc::PerfcEvuLength)
  begin : gen_core_bytes_check
    $fatal(1, "perfc_evu_cfg_regs: %0d cores x %0d bytes (ariane_soc stride %0d) behind a window of %0d bytes",
           NumCores, CoreBytes, ariane_soc::PerfcEvuBytesPerCore, ariane_soc::PerfcEvuLength);
  end

  typedef logic [7:0] byte_t;

  // Bits set here cannot be written over AXI: they read their reset value (0) and synthesis drops the flops.
  localparam evu_regs_t CORE_RO = '{
    pc_track3:       64'h0000_0000_0000_0000,
    pc_track2:       64'h0000_0000_0000_0000,
    pc_track1:       64'h0000_0000_0000_0000,
    pc_track0:       64'h0000_0000_0000_0000,
    event_id0:       32'hFFFF_FF00,
    event_id1:       32'hFFFF_FF00,
    event_id2:       32'hFFFF_FF00,
    event_id3:       32'hFFFF_FF00
  };

  // axi_lite_regs takes one read-only bit per byte; a byte is read-only if its whole mask byte is set.
  function automatic logic [CoreBytes-1:0] ro_bytes(evu_regs_t mask);
    for (int b = 0; b < CoreBytes; b++) ro_bytes[b] = &mask[8*b +: 8];
  endfunction

  localparam logic [RegNumBytes-1:0] AXI_READ_ONLY = {NumCores{ro_bytes(CORE_RO)}};

  evu_regs_t [NumCores-1:0] regs_q;
  logic [RegNumBytes-1:0] wr_active, rd_active;

  axi_lite_regs #(
    .RegNumBytes  ( RegNumBytes                  ),
    .AxiAddrWidth ( ariane_axi_soc::LiteAddrWidth ),
    .AxiDataWidth ( ariane_axi_soc::LiteDataWidth ),
    .PrivProtOnly ( 1'b0                         ),
    .SecuProtOnly ( 1'b0                         ),
    .AxiReadOnly  ( AXI_READ_ONLY                ),
    .byte_t       ( byte_t                       ),
    .RegRstVal    ( '0                           ),
    .req_lite_t   ( ariane_axi_soc::req_lite_t   ),
    .resp_lite_t  ( ariane_axi_soc::resp_lite_t  )
  ) u_axi_lite_regs (
    .clk_i       ( clk_i            ),
    .rst_ni      ( rst_ni           ),
    .axi_req_i   ( perfc_cfg_req_i  ),
    .axi_resp_o  ( perfc_cfg_resp_o ),
    .wr_active_o ( wr_active        ),
    .rd_active_o ( rd_active        ),
    .reg_d_i     ( '0               ),
    .reg_load_i  ( '0               ),
    .reg_q_o     ( regs_q           )
  );

  for (genvar c = 0; c < NumCores; c++) begin : gen_core_fields
    assign perfc_evu_req_o[c] = {
      regs_q[c].event_id3[IdW-1:0],
      regs_q[c].event_id2[IdW-1:0],
      regs_q[c].event_id1[IdW-1:0],
      regs_q[c].event_id0[IdW-1:0]
    };
    assign pcmiles_evu_req_o[c] = {
      regs_q[c].pc_track3,
      regs_q[c].pc_track2,
      regs_q[c].pc_track1,
      regs_q[c].pc_track0
    };
  end

endmodule
