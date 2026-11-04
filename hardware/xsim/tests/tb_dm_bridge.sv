// tb_dm_bridge.sv: the debug module's AXI slave bridge (i_dm_axi2mem in host/cva6_subsystem.sv, an axi2mem) behind
// a crossbar configured as the SoC's (CUT_ALL_PORTS, FallThrough 0), with ndmreset asserted in the middle of the
// debug ROM's park-loop traffic. A single-beat write reaches the bridge with its W one cycle after its AW (the
// crossbar's mux forwards W from a non-fall-through FIFO), so an idle bridge spends that cycle in WAIT_WVALID with
// aw_ready = ar_ready = 0. Reset with the crossbar (BRIDGE_ON_NDMRESET = 1), it starts afresh with it; on the
// power-on reset (0, the wiring before 2026-11-01) an ndmreset in that cycle clears the W inside the crossbar but not
// the bridge, which then waits for it for ever: no hart can fetch the debug ROM, so none can halt again.
// For each of NOFS reset offsets: power-on reset, park-loop traffic from master 0 (12 fetches, 2 loads, 1 store to
// HALTED per pass, one transaction at a time, AW and W offered together), ndmreset of the crossbar and the master
// for 20 cycles at the offset, then the halt sequence: fetch at the boot address 0x10000 (a second bridge, on the
// crossbar's reset, as i_axi2rom), fetch at the debug ROM's halt address 0x800, store to HALTED (0x100); it must
// finish within 300 cycles. Pass with BRIDGE_ON_NDMRESET = 1: no offset wedges and some offsets hit WAIT_WVALID.
// With 0: the offsets that wedge are exactly those that hit WAIT_WVALID (at least one).
// Prints "DM BRIDGE UNIT PASS" or "DM BRIDGE UNIT FAIL: <n> failures".
`include "axi/assign.svh"

module tb_dm_bridge #(
  parameter bit BRIDGE_ON_NDMRESET = 1'b1
);
  localparam int unsigned IW = 4, AW = 64, DW = 64, UW = 1;
  localparam int unsigned NSLV = 2;                     // master 0 = the cores' port, master 1 idle (as the SBA)
  localparam int unsigned IWM = IW + $clog2(NSLV);      // ID width at the crossbar's master ports
  localparam time CYC = 10ns, TA = 2ns;
  localparam int unsigned NOFS = 360, WARM = 60, HOLD = 20, LIMIT = 300;   // NOFS: several park-loop passes
  localparam logic [2:0] WAIT_WVALID = 3'd4;            // axi2mem's state encoding: IDLE, READ, WRITE, SEND_B, WAIT_WVALID

  logic clk = 1'b0, por_n = 1'b0, ndm_n = 1'b1;
  always #(CYC / 2) clk = ~clk;
  wire xbar_rst_n   = por_n & ndm_n;                    // rstgen(rstn_glob_i & ~rst_dm_i), alsaqr_clk_rst_gen.sv
  wire bridge_rst_n = BRIDGE_ON_NDMRESET ? xbar_rst_n : por_n;

  AXI_BUS #(.AXI_ADDR_WIDTH(AW), .AXI_DATA_WIDTH(DW), .AXI_ID_WIDTH(IW),  .AXI_USER_WIDTH(UW)) slv [NSLV-1:0] ();
  AXI_BUS #(.AXI_ADDR_WIDTH(AW), .AXI_DATA_WIDTH(DW), .AXI_ID_WIDTH(IWM), .AXI_USER_WIDTH(UW)) mst [1:0] ();

  localparam axi_pkg::xbar_cfg_t Cfg = '{
    NoSlvPorts:         NSLV,
    NoMstPorts:         2,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b0,                           // as AXI_XBAR_CFG in cva6_subsystem.sv
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     32'd0,
    AxiIdWidthSlvPorts: IW,
    AxiIdUsedSlvPorts:  IW,
    UniqueIds:          1'b0,
    AxiAddrWidth:       AW,
    AxiDataWidth:       DW,
    NoAddrRules:        2
  };
  axi_pkg::xbar_rule_64_t [1:0] map;
  assign map[0] = '{idx: 32'd0, start_addr: 64'h0000_0000, end_addr: 64'h0000_1000};   // debug module
  assign map[1] = '{idx: 32'd1, start_addr: 64'h0001_0000, end_addr: 64'h0002_0000};   // boot ROM

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( UW                      ),
    .Cfg            ( Cfg                     ),
    .rule_t         ( axi_pkg::xbar_rule_64_t )
  ) i_xbar (
    .clk_i                 ( clk        ),
    .rst_ni                ( xbar_rst_n ),
    .test_i                ( 1'b0       ),
    .slv_ports             ( slv        ),
    .mst_ports             ( mst        ),
    .addr_map_i            ( map        ),
    .en_default_mst_port_i ( '0         ),
    .default_mst_port_i    ( '0         )
  );

  // ---- the debug module's bridge and memory (dm_mem answers a request in the next cycle) ----
  logic dm_req, dm_we;
  logic [AW-1:0] dm_addr;
  logic [DW/8-1:0] dm_be;
  logic [DW-1:0] dm_wdata, dm_rdata;
  logic [DW-1:0] dm_words [512];
  int unsigned halted_writes = 0;                       // writes to HALTED (0x100) since the last power-on reset

  axi2mem #(
    .AXI_ID_WIDTH   ( IWM ),
    .AXI_ADDR_WIDTH ( AW  ),
    .AXI_DATA_WIDTH ( DW  ),
    .AXI_USER_WIDTH ( UW  )
  ) i_dm_bridge (
    .clk_i  ( clk          ),
    .rst_ni ( bridge_rst_n ),
    .slave  ( mst[0]       ),
    .req_o  ( dm_req       ),
    .we_o   ( dm_we        ),
    .addr_o ( dm_addr      ),
    .be_o   ( dm_be        ),
    .data_o ( dm_wdata     ),
    .data_i ( dm_rdata     )
  );

  always @(posedge clk) begin
    if (!por_n) halted_writes <= 0;
    else if (dm_req && dm_we && dm_addr[11:3] == 9'h020) halted_writes <= halted_writes + 1;
    if (dm_req) begin
      if (dm_we) for (int b = 0; b < DW / 8; b++) if (dm_be[b]) dm_words[dm_addr[11:3]][8*b +: 8] <= dm_wdata[8*b +: 8];
      dm_rdata <= {32'h0000_0013, dm_addr[31:0]};        // nop + the address: any data does
    end
  end

  // ---- the boot ROM's bridge (i_axi2rom: reset with the crossbar) ----
  logic rom_req;
  logic [AW-1:0] rom_addr;
  logic [DW-1:0] rom_rdata;

  axi2mem #(
    .AXI_ID_WIDTH   ( IWM ),
    .AXI_ADDR_WIDTH ( AW  ),
    .AXI_DATA_WIDTH ( DW  ),
    .AXI_USER_WIDTH ( UW  )
  ) i_rom_bridge (
    .clk_i  ( clk        ),
    .rst_ni ( xbar_rst_n ),
    .slave  ( mst[1]     ),
    .req_o  ( rom_req    ),
    .we_o   (            ),
    .addr_o ( rom_addr   ),
    .be_o   (            ),
    .data_o (            ),
    .data_i ( rom_rdata  )
  );
  always @(posedge clk) if (rom_req) rom_rdata <= {32'h0000_0013, rom_addr[31:0]};

  // ---- master 1: idle ----
  assign slv[1].aw_valid = 1'b0;
  assign slv[1].w_valid  = 1'b0;
  assign slv[1].b_ready  = 1'b1;
  assign slv[1].ar_valid = 1'b0;
  assign slv[1].r_ready  = 1'b1;
  assign slv[1].aw_id = '0; assign slv[1].aw_addr = '0; assign slv[1].aw_len = '0; assign slv[1].aw_size = '0;
  assign slv[1].aw_burst = '0; assign slv[1].aw_lock = '0; assign slv[1].aw_cache = '0; assign slv[1].aw_prot = '0;
  assign slv[1].aw_qos = '0; assign slv[1].aw_region = '0; assign slv[1].aw_atop = '0; assign slv[1].aw_user = '0;
  assign slv[1].w_data = '0; assign slv[1].w_strb = '0; assign slv[1].w_last = '0; assign slv[1].w_user = '0;
  assign slv[1].ar_id = '0; assign slv[1].ar_addr = '0; assign slv[1].ar_len = '0; assign slv[1].ar_size = '0;
  assign slv[1].ar_burst = '0; assign slv[1].ar_lock = '0; assign slv[1].ar_cache = '0; assign slv[1].ar_prot = '0;
  assign slv[1].ar_qos = '0; assign slv[1].ar_region = '0; assign slv[1].ar_user = '0;

  // ---- master 0: a hart, reset by ndmreset like the cores; one transaction at a time ----
  // Park loop (debug_rom.S's entry loop: 12 instructions, each fetched with its own read in debug mode, a store of
  // the hart id to HALTED and two flag loads). After an ndmreset with halt_mode set: the halt sequence once.
  localparam int unsigned NPARK = 15, NHALT = 3;
  typedef enum logic [1:0] { OP_FETCH, OP_LOAD, OP_STORE } op_e;
  op_e           park_op   [NPARK] = '{OP_FETCH, OP_FETCH, OP_FETCH, OP_STORE, OP_FETCH, OP_LOAD, OP_FETCH, OP_FETCH,
                                       OP_FETCH, OP_FETCH, OP_LOAD, OP_FETCH, OP_FETCH, OP_FETCH, OP_FETCH};
  logic [AW-1:0] park_addr [NPARK] = '{64'h808, 64'h80c, 64'h810, 64'h100, 64'h814, 64'h400, 64'h818, 64'h81c,
                                       64'h820, 64'h824, 64'h400, 64'h828, 64'h82c, 64'h830, 64'h834};
  op_e           halt_op   [NHALT] = '{OP_FETCH, OP_FETCH, OP_STORE};
  logic [AW-1:0] halt_addr [NHALT] = '{64'h1_0000, 64'h800, 64'h100};

  typedef enum logic [2:0] { D_NEXT, D_AR, D_R, D_AW, D_B, D_DONE } d_state_e;
  d_state_e d_q;
  int unsigned pc_q;
  logic in_halt_q, aw_done_q, w_done_q;
  logic [AW-1:0] addr_q;
  logic halt_mode = 1'b0;                               // set by the sequencer before it releases ndmreset
  int unsigned halt_seqs = 0;                           // halt sequences finished (counted outside the reset)
  logic halt_fin;

  always_ff @(posedge clk or negedge xbar_rst_n) begin
    if (!xbar_rst_n) begin
      d_q <= D_NEXT; pc_q <= 0; in_halt_q <= 1'b0; aw_done_q <= 1'b0; w_done_q <= 1'b0; addr_q <= '0;
    end else begin
      unique case (d_q)
        D_NEXT: begin
          if (halt_mode && !in_halt_q) begin            // first op after an ndmreset in halt mode
            in_halt_q <= 1'b1; pc_q <= 0;
            addr_q <= halt_addr[0];
            d_q <= (halt_op[0] == OP_STORE) ? D_AW : D_AR;
          end else if (in_halt_q) begin
            if (pc_q == NHALT) d_q <= D_DONE;
            else begin addr_q <= halt_addr[pc_q]; d_q <= (halt_op[pc_q] == OP_STORE) ? D_AW : D_AR; end
          end else begin
            addr_q <= park_addr[pc_q]; d_q <= (park_op[pc_q] == OP_STORE) ? D_AW : D_AR;
          end
        end
        D_AR: if (slv[0].ar_ready) d_q <= D_R;
        D_R: if (slv[0].r_valid && slv[0].r_last) begin
          d_q <= D_NEXT;
          if (in_halt_q) pc_q <= pc_q + 1; else pc_q <= (pc_q + 1) % NPARK;
        end
        D_AW: begin
          if (slv[0].aw_ready) aw_done_q <= 1'b1;
          if (slv[0].w_ready)  w_done_q  <= 1'b1;
          if ((aw_done_q || slv[0].aw_ready) && (w_done_q || slv[0].w_ready)) begin
            d_q <= D_B; aw_done_q <= 1'b0; w_done_q <= 1'b0;
          end
        end
        D_B: if (slv[0].b_valid) begin
          d_q <= D_NEXT;
          if (in_halt_q) pc_q <= pc_q + 1; else pc_q <= (pc_q + 1) % NPARK;
        end
        D_DONE: ;
        default: d_q <= D_NEXT;
      endcase
    end
  end
  assign halt_fin = xbar_rst_n && d_q == D_NEXT && in_halt_q && pc_q == NHALT;
  always @(posedge clk) if (halt_fin) halt_seqs <= halt_seqs + 1;

  assign slv[0].ar_valid  = d_q == D_AR;
  assign slv[0].ar_addr   = addr_q;
  assign slv[0].ar_id     = '0;
  assign slv[0].ar_len    = '0;
  assign slv[0].ar_size   = 3'd2;                        // 32-bit, as an uncached fetch or flag load
  assign slv[0].ar_burst  = axi_pkg::BURST_INCR;
  assign slv[0].ar_lock = '0; assign slv[0].ar_cache = '0; assign slv[0].ar_prot = '0; assign slv[0].ar_qos = '0;
  assign slv[0].ar_region = '0; assign slv[0].ar_user = '0;
  assign slv[0].r_ready   = d_q == D_R;
  assign slv[0].aw_valid  = d_q == D_AW && !aw_done_q;
  assign slv[0].aw_addr   = addr_q;
  assign slv[0].aw_id     = '0;
  assign slv[0].aw_len    = '0;
  assign slv[0].aw_size   = 3'd2;
  assign slv[0].aw_burst  = axi_pkg::BURST_INCR;
  assign slv[0].aw_lock = '0; assign slv[0].aw_cache = '0; assign slv[0].aw_prot = '0; assign slv[0].aw_qos = '0;
  assign slv[0].aw_region = '0; assign slv[0].aw_atop = '0; assign slv[0].aw_user = '0;
  assign slv[0].w_valid   = d_q == D_AW && !w_done_q;    // offered together with its AW
  assign slv[0].w_data    = 64'h0;                       // hart id 0
  assign slv[0].w_strb    = 8'h0f;
  assign slv[0].w_last    = 1'b1;
  assign slv[0].w_user    = '0;
  assign slv[0].b_ready   = d_q == D_B;

  // ---- sequencer ----
  int unsigned failures = 0;
  initial begin
    automatic int unsigned hits = 0, wedges = 0, mismatches = 0, halted_after = 0;
    automatic int unsigned in_state [8] = '{default: 0};
    automatic logic [2:0] st;
    automatic bit wedged;
    automatic int unsigned seqs0, hw0;
    if (BRIDGE_ON_NDMRESET) $display("tb_dm_bridge: bridge reset with the crossbar (ndmreset), %0d reset offsets", NOFS);
    else $display("tb_dm_bridge: bridge reset at power-on only, %0d reset offsets", NOFS);
    for (int unsigned o = 0; o < NOFS; o++) begin
      halt_mode = 1'b0;
      por_n = 1'b0; ndm_n = 1'b1;
      repeat (5) @(posedge clk);
      #TA por_n = 1'b1;
      repeat (WARM + o) @(posedge clk);
      #TA;
      st = i_dm_bridge.state_q;                          // the bridge's state when the reset arrives
      in_state[st]++;
      ndm_n = 1'b0;                                      // asynchronous assertion, as rstgen's
      seqs0 = halt_seqs; hw0 = halted_writes;
      halt_mode = 1'b1;
      repeat (HOLD) @(posedge clk);
      #TA ndm_n = 1'b1;
      wedged = 1'b1;
      for (int unsigned c = 0; c < LIMIT && wedged; c++) begin
        @(posedge clk);
        if (halt_seqs != seqs0) wedged = 1'b0;
      end
      if (!wedged && halted_writes != hw0) halted_after++;
      if (st == WAIT_WVALID) hits++;
      if (wedged) wedges++;
      if (wedged != (st == WAIT_WVALID)) mismatches++;
      if (wedged && BRIDGE_ON_NDMRESET) $display("  offset %0d: wedged (bridge state %0d at the reset)", o, st);
    end
    $display("  reset found the bridge in IDLE %0d, READ %0d, WRITE %0d, SEND_B %0d, WAIT_WVALID %0d of %0d offsets",
             in_state[0], in_state[1], in_state[2], in_state[3], in_state[4], NOFS);
    $display("  wedged %0d, halt sequence done %0d (its HALTED write seen %0d)", wedges, NOFS - wedges, halted_after);
    if (hits == 0) begin
      failures++; $display("FAIL: no reset offset hit WAIT_WVALID: the test missed the window");
    end
    if (BRIDGE_ON_NDMRESET) begin
      if (wedges != 0) begin failures++; $display("FAIL: %0d offsets wedged with the bridge on ndmreset", wedges); end
      if (halted_after != NOFS) begin
        failures++; $display("FAIL: the HALTED write after the reset arrived %0d of %0d times", halted_after, NOFS);
      end
    end else begin
      if (mismatches != 0) begin
        failures++; $display("FAIL: %0d offsets wedged without WAIT_WVALID or the reverse", mismatches);
      end
      if (wedges == 0) begin failures++; $display("FAIL: the power-on wiring never wedged"); end
    end
    if (failures == 0) $display("DM BRIDGE UNIT PASS");
    else $display("DM BRIDGE UNIT FAIL: %0d failures", failures);
    $finish;
  end
endmodule
