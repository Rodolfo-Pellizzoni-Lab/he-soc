// Accelerator socket: takes the place of the PULP cluster when EXCLUDE_CLUSTER is set.
//
//   CPU  --AXI4 (cluster window 0x1000_0000..0x103F_FFFF)--> slave FSM --reg port--> accel_slots
//   accel_slots --mem ports--> round-robin arbiter --> axi_from_mem --AXI4--> host xbar (DRAM, L2 SPM, ...)
//   accel_slots --irq--> PLIC source 8 (interrupt ID 9, the cluster end-of-computation line)
//
// Slot i owns the 64 KB window 0x1000_0000 + i * 0x1_0000. Accesses to an empty slot or past the last slot get
// DECERR (read data 0xdeadbeef); an accelerator that does not acknowledge a register access within TimeoutCycles
// gets SLVERR and 0xdeadbeef, so a broken accelerator cannot hang the simulation. (CVA6 takes no exception on AXI
// error responses: software sees the 0xdeadbeef data.)
// Register accesses are 32-bit: a 64-bit access becomes two (low word first), a narrower one reads/writes the
// containing word with byte strobes. Bursts are walked beat by beat. Atomic (ATOP) writes are refused (SLVERR).
//
// Register port protocol (see accel_slots.sv): reg_req is a one-cycle strobe; the slot answers with exactly one
// reg_ack pulse in the same or a later cycle, with reg_rdata valid in the ack cycle.

module accel_socket #(
  parameter type         axi_req_t     = ariane_axi_soc::req_slv_t,
  parameter type         axi_resp_t    = ariane_axi_soc::resp_slv_t,
  parameter int unsigned NumSlots      = 8,
  parameter int unsigned TimeoutCycles = 4096
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  // CPU side: accelerator registers
  input  axi_req_t  slv_req_i,
  output axi_resp_t slv_resp_o,
  // accelerator memory traffic into the SoC
  output axi_req_t  mst_req_o,
  input  axi_resp_t mst_resp_i,
  output logic      irq_o
);

  localparam int unsigned SlotW = (NumSlots > 1) ? $clog2(NumSlots) : 1;
  localparam int unsigned TW    = $clog2(TimeoutCycles + 1);

  // ------------------------------------------------------------------ register side
  logic             reg_req_q;
  logic [SlotW-1:0] reg_slot_q;
  logic [15:0]      reg_addr_q;
  logic             reg_we_q;
  logic [31:0]      reg_wdata_q;
  logic [3:0]       reg_wstrb_q;
  logic             reg_ack, reg_err;
  logic [31:0]      reg_rdata;

  // memory side, per slot
  logic [NumSlots-1:0]       m_req, m_gnt, m_we, m_rvalid, m_err, irqs;
  logic [NumSlots-1:0][63:0] m_addr, m_wdata;
  logic [NumSlots-1:0][7:0]  m_strb;
  logic [63:0]               m_rdata;

  accel_slots #(.NumSlots(NumSlots)) i_slots (
    .clk_i, .rst_ni,
    .reg_req_i    ( reg_req_q   ),
    .reg_slot_i   ( reg_slot_q  ),
    .reg_addr_i   ( reg_addr_q  ),
    .reg_we_i     ( reg_we_q    ),
    .reg_wdata_i  ( reg_wdata_q ),
    .reg_wstrb_i  ( reg_wstrb_q ),
    .reg_ack_o    ( reg_ack     ),
    .reg_err_o    ( reg_err     ),
    .reg_rdata_o  ( reg_rdata   ),
    .mem_req_o    ( m_req       ),
    .mem_gnt_i    ( m_gnt       ),
    .mem_we_o     ( m_we        ),
    .mem_addr_o   ( m_addr      ),
    .mem_wdata_o  ( m_wdata     ),
    .mem_strb_o   ( m_strb      ),
    .mem_rvalid_i ( m_rvalid    ),
    .mem_rdata_i  ( m_rdata     ),
    .mem_err_i    ( m_err       ),
    .irq_o        ( irqs        )
  );

  // ------------------------------------------------------------------ AXI slave FSM (one transaction at a time)
  typedef enum logic [2:0] { S_IDLE, S_WDATA, S_ACCESS, S_BRESP, S_RDATA } state_e;
  state_e state_q;
  logic                              is_write_q, atop_q, hi_q, need_hi_q;
  logic [$bits(slv_req_i.aw.id)-1:0] id_q;
  logic [63:0]                       addr_q, wdata_q, rdata_q;
  logic [7:0]                        beats_q, wstrb_q;
  logic [2:0]                        size_q;
  logic [1:0]                        burst_q, resp_q;
  logic [TW-1:0]                     wait_q;

  // which 32-bit halves of the 64-bit lane a beat touches
  function automatic logic needs_lo(logic wr, logic [7:0] strb, logic [2:0] size, logic [63:0] a);
    return wr ? |strb[3:0] : (size == 3'd3 || !a[2]);
  endfunction
  function automatic logic needs_hi(logic wr, logic [7:0] strb, logic [2:0] size, logic [63:0] a);
    return wr ? |strb[7:4] : (size == 3'd3 || a[2]);
  endfunction
  function automatic logic slot_ok(logic [63:0] a);
    return a[21:16] < NumSlots;
  endfunction
  function automatic logic [63:0] next_addr(logic [63:0] a, logic [2:0] size, logic [1:0] burst);
    return (burst == axi_pkg::BURST_FIXED) ? a : ((a >> size) + 64'd1) << size;
  endfunction

  wire aw_take  = (state_q == S_IDLE) && slv_req_i.aw_valid;
  wire ar_take  = (state_q == S_IDLE) && !slv_req_i.aw_valid && slv_req_i.ar_valid;
  wire w_take   = (state_q == S_WDATA) && slv_req_i.w_valid;
  wire timeout  = (wait_q == TW'(TimeoutCycles));
  wire acc_done = (state_q == S_ACCESS) && (reg_ack || timeout);
  wire [31:0] acc_val = timeout ? 32'hdeadbeef : reg_rdata;

  function automatic axi_resp_t mk_resp(state_e st, logic awt, logic art, logic wt,
                                        logic [$bits(slv_req_i.aw.id)-1:0] id, logic [1:0] resp,
                                        logic [63:0] rdata, logic last);
    axi_resp_t r;
    r          = '0;
    r.aw_ready = awt;
    r.ar_ready = art;
    r.w_ready  = wt;
    r.b_valid  = (st == S_BRESP);
    r.b.id     = id;
    r.b.resp   = resp;
    r.r_valid  = (st == S_RDATA);
    r.r.id     = id;
    r.r.data   = rdata;
    r.r.resp   = resp;
    r.r.last   = last;
    return r;
  endfunction
  assign slv_resp_o = mk_resp(state_q, aw_take, ar_take, w_take, id_q, resp_q, rdata_q, beats_q == 8'd0);

  // start the register access of one 32-bit half
  task automatic issue(input logic wr, input logic hi, input logic [63:0] a, input logic [63:0] wd,
                       input logic [7:0] ws);
    reg_req_q   <= 1'b1;
    reg_slot_q  <= a[16 +: SlotW];
    reg_addr_q  <= {a[15:3], hi, 2'b00};
    reg_we_q    <= wr;
    reg_wdata_q <= hi ? wd[63:32] : wd[31:0];
    reg_wstrb_q <= wr ? (hi ? ws[7:4] : ws[3:0]) : 4'h0;
    hi_q        <= hi;
    wait_q      <= '0;
  endtask

  // start a read beat at address a (or answer DECERR without an access)
  task automatic start_read(input logic [63:0] a, input logic [2:0] size);
    rdata_q <= '0;
    if (!slot_ok(a)) begin
      resp_q <= axi_pkg::RESP_DECERR; rdata_q <= 64'hdeadbeef_deadbeef; state_q <= S_RDATA;
    end else begin
      need_hi_q <= needs_hi(1'b0, '0, size, a);
      issue(1'b0, !needs_lo(1'b0, '0, size, a), a, '0, '0);
      state_q <= S_ACCESS;
    end
  endtask

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= S_IDLE; is_write_q <= 1'b0; atop_q <= 1'b0; hi_q <= 1'b0; need_hi_q <= 1'b0;
      id_q <= '0; addr_q <= '0; beats_q <= '0; size_q <= '0; burst_q <= '0;
      wdata_q <= '0; rdata_q <= '0; wstrb_q <= '0; resp_q <= '0; wait_q <= '0;
      reg_req_q <= 1'b0; reg_slot_q <= '0; reg_addr_q <= '0; reg_we_q <= 1'b0; reg_wdata_q <= '0; reg_wstrb_q <= '0;
    end else begin
      reg_req_q <= 1'b0;   // one-cycle strobe; issue() overrides
      case (state_q)
        S_IDLE: begin
          resp_q <= axi_pkg::RESP_OKAY;
          if (aw_take) begin
            is_write_q <= 1'b1; id_q <= slv_req_i.aw.id; addr_q <= slv_req_i.aw.addr; beats_q <= slv_req_i.aw.len;
            size_q <= slv_req_i.aw.size; burst_q <= slv_req_i.aw.burst; atop_q <= (slv_req_i.aw.atop != '0);
            state_q <= S_WDATA;
          end else if (ar_take) begin
            is_write_q <= 1'b0; id_q <= slv_req_i.ar.id; addr_q <= slv_req_i.ar.addr; beats_q <= slv_req_i.ar.len;
            size_q <= slv_req_i.ar.size; burst_q <= slv_req_i.ar.burst; atop_q <= 1'b0;
            start_read(slv_req_i.ar.addr, slv_req_i.ar.size);
          end
        end
        S_WDATA: if (w_take) begin
          wdata_q <= slv_req_i.w.data; wstrb_q <= slv_req_i.w.strb;
          if (atop_q || !slot_ok(addr_q) || slv_req_i.w.strb == '0) begin
            // refused or empty beat: no register access
            if (atop_q)               resp_q <= axi_pkg::RESP_SLVERR;
            else if (!slot_ok(addr_q)) resp_q <= axi_pkg::RESP_DECERR;
            if (beats_q == 8'd0) state_q <= S_BRESP;
            else begin beats_q <= beats_q - 8'd1; addr_q <= next_addr(addr_q, size_q, burst_q); end
          end else begin
            need_hi_q <= needs_hi(1'b1, slv_req_i.w.strb, size_q, addr_q);
            issue(1'b1, !needs_lo(1'b1, slv_req_i.w.strb, size_q, addr_q), addr_q, slv_req_i.w.data, slv_req_i.w.strb);
            state_q <= S_ACCESS;
          end
        end
        S_ACCESS: begin
          if (!acc_done) wait_q <= wait_q + 1'b1;
          else begin
            if (timeout)                                       resp_q <= axi_pkg::RESP_SLVERR;
            else if (reg_err && resp_q == axi_pkg::RESP_OKAY) resp_q <= axi_pkg::RESP_DECERR;
            if (!is_write_q) begin
              // a 32-bit read is returned on both lanes; the core picks the lane its address selects
              if (hi_q) rdata_q <= (size_q == 3'd3) ? {acc_val, rdata_q[31:0]} : {acc_val, acc_val};
              else      rdata_q <= {acc_val, acc_val};
            end
            if (!hi_q && need_hi_q) begin
              issue(is_write_q, 1'b1, addr_q, wdata_q, wstrb_q);
            end else if (is_write_q) begin
              if (beats_q == 8'd0) state_q <= S_BRESP;
              else begin beats_q <= beats_q - 8'd1; addr_q <= next_addr(addr_q, size_q, burst_q); state_q <= S_WDATA; end
            end else begin
              state_q <= S_RDATA;
            end
          end
        end
        S_BRESP: if (slv_req_i.b_ready) state_q <= S_IDLE;
        S_RDATA: if (slv_req_i.r_ready) begin
          if (beats_q == 8'd0) state_q <= S_IDLE;
          else begin
            beats_q <= beats_q - 8'd1;
            addr_q  <= next_addr(addr_q, size_q, burst_q);
            start_read(next_addr(addr_q, size_q, burst_q), size_q);
          end
        end
        default: state_q <= S_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------------ memory side: round-robin over the slots
  localparam int unsigned MaxReq = 4;
  logic [SlotW-1:0] rr_q, sel;
  logic             dn_req, dn_gnt, dn_rvalid, dn_err;
  logic [63:0]      dn_rdata;

  // first requesting slot at or after `start`
  function automatic logic [SlotW-1:0] pick(logic [NumSlots-1:0] r, logic [SlotW-1:0] start);
    logic [SlotW-1:0] p, k;
    p = start;
    for (int unsigned i = NumSlots; i > 0; i--) begin
      k = SlotW'((start + i - 1) % NumSlots);
      if (r[k]) p = k;
    end
    return p;
  endfunction

  // in-order response routing: which slot issued each outstanding request
  logic [MaxReq-1:0][SlotW-1:0] ord_q;
  logic [$clog2(MaxReq):0]      cnt_q;
  logic [$clog2(MaxReq)-1:0]    wp_q, rp_q;

  assign sel    = pick(m_req, rr_q);
  assign dn_req = (|m_req) && (cnt_q != MaxReq);
  for (genvar i = 0; i < NumSlots; i++) begin : gen_route
    assign m_gnt[i]    = dn_req && dn_gnt && (sel == i);
    assign m_rvalid[i] = dn_rvalid && (ord_q[rp_q] == i);
    assign m_err[i]    = dn_err && (ord_q[rp_q] == i);
  end
  assign m_rdata = dn_rdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rr_q <= '0; ord_q <= '0; cnt_q <= '0; wp_q <= '0; rp_q <= '0;
    end else begin
      if (dn_req && dn_gnt) begin
        ord_q[wp_q] <= sel; wp_q <= wp_q + 1'b1;
        rr_q <= SlotW'((sel + 1) % NumSlots);
      end
      if (dn_rvalid) rp_q <= rp_q + 1'b1;
      cnt_q <= cnt_q + (dn_req && dn_gnt) - dn_rvalid;
    end
  end

  axi_from_mem #(
    .MemAddrWidth ( 64         ),
    .AxiAddrWidth ( 64         ),
    .DataWidth    ( 64         ),
    .MaxRequests  ( MaxReq     ),
    .AxiProt      ( 3'b000     ),
    .axi_req_t    ( axi_req_t  ),
    .axi_rsp_t    ( axi_resp_t )
  ) i_axi_from_mem (
    .clk_i, .rst_ni,
    .mem_req_i       ( dn_req       ),
    .mem_addr_i      ( m_addr[sel]  ),
    .mem_we_i        ( m_we[sel]    ),
    .mem_wdata_i     ( m_wdata[sel] ),
    .mem_be_i        ( m_strb[sel]  ),
    .mem_gnt_o       ( dn_gnt       ),
    .mem_rsp_valid_o ( dn_rvalid    ),
    .mem_rsp_rdata_o ( dn_rdata     ),
    .mem_rsp_error_o ( dn_err       ),
    .slv_aw_cache_i  ( axi_pkg::CACHE_MODIFIABLE ),
    .slv_ar_cache_i  ( axi_pkg::CACHE_MODIFIABLE ),
    .axi_req_o       ( mst_req_o    ),
    .axi_rsp_i       ( mst_resp_i   )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) irq_o <= 1'b0;
    else         irq_o <= |irqs;
  end

endmodule
