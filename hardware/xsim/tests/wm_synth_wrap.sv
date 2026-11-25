// axi_llc_w_master with the types of tb_llc_wmaster.sv and flat ports: the top of an out-of-context synthesis whose
// netlist the same testbench then simulates (run_llc_wmaster_netlist.sh).
`include "axi/typedef.svh"
module wm_synth_wrap #(
  parameter int unsigned PEND = 4
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [95:0] desc_i,
  input  logic        desc_valid_i,
  output logic        desc_ready_o,
  output logic [95:0] desc_o,
  output logic        desc_valid_o,
  input  logic        desc_ready_i,
  output logic [73:0] w_o,
  output logic        w_valid_o,
  input  logic        w_ready_i,
  input  logic [6:0]  b_i,
  input  logic        b_valid_i,
  output logic        b_ready_o,
  output logic [86:0] way_inp_o,
  output logic        way_inp_valid_o,
  input  logic        way_inp_ready_i,
  input  logic [65:0] way_out_i,
  input  logic        way_out_valid_i,
  output logic        way_out_ready_o,
  output logic        flush_desc_recv_o
);
  localparam axi_llc_pkg::llc_axi_cfg_t AxiCfg = '{SlvPortIdWidth: 4, AddrWidthFull: 32, DataWidthFull: 64,
                                                   LitePortAddrWidth: 32, LitePortDataWidth: 32};
  localparam axi_llc_pkg::llc_cfg_t Cfg = '{SetAssociativity: 4, NumLines: 32, NumBlocks: 8, BlockSize: 64,
                                            TagLength: 21, IndexLength: 5, BlockOffsetLength: 3, ByteOffsetLength: 3,
                                            SPMLength: 4 * 32 * 8 * 8};
  typedef logic [3:0]  id_t;
  typedef logic [31:0] addr_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0]  strb_t;
  typedef logic [0:0]  user_t;
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  typedef struct packed {
    logic [31:0] seq;
    id_t         a_x_id;
    addr_t       a_x_addr;
    logic [3:0]  way_ind;
    logic        evict;
    logic [20:0] evict_tag;
    logic        refill;
    logic        flush;
  } desc_t;
  typedef struct packed {
    axi_llc_pkg::cache_unit_e cache_unit;
    logic [3:0]               way_ind;
    logic [4:0]               line_addr;
    logic [2:0]               blk_offset;
    logic                     we;
    data_t                    data;
    strb_t                    strb;
  } way_inp_t;
  typedef struct packed {
    axi_llc_pkg::cache_unit_e cache_unit;
    data_t                    data;
  } way_oup_t;
  desc_t    d_i, d_o;
  w_chan_t  w;
  b_chan_t  b;
  way_inp_t wi;
  way_oup_t wo;
  assign d_i = desc_t'(desc_i);
  assign desc_o = d_o;
  assign w_o = w;
  assign b = b_chan_t'(b_i);
  assign way_inp_o = wi;
  assign wo = way_oup_t'(way_out_i);
  axi_llc_w_master #(
    .Cfg ( Cfg ), .AxiCfg ( AxiCfg ), .desc_t ( desc_t ), .way_inp_t ( way_inp_t ), .way_oup_t ( way_oup_t ),
    .w_chan_t ( w_chan_t ), .b_chan_t ( b_chan_t ), .PendDepth ( PEND )
  ) i_w_master (
    .clk_i, .rst_ni, .test_i ( 1'b0 ),
    .desc_i ( d_i ), .desc_valid_i, .desc_ready_o, .desc_o ( d_o ), .desc_valid_o, .desc_ready_i,
    .w_chan_mst_o ( w ), .w_chan_valid_o ( w_valid_o ), .w_chan_ready_i ( w_ready_i ),
    .b_chan_mst_i ( b ), .b_chan_valid_i ( b_valid_i ), .b_chan_ready_o ( b_ready_o ),
    .way_inp_o ( wi ), .way_inp_valid_o, .way_inp_ready_i,
    .way_out_i ( wo ), .way_out_valid_i, .way_out_ready_o,
    .flush_desc_recv_o
  );
endmodule
