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
// QoS probe: the 8 bytes at 0x103F_0000 (the rest of that 64 KB answers DECERR), for checking the QoS tag the cores put on AXI requests
// (ariane_axi_soc user layout): a 32-bit read of +0x0 returns the AR user field of that read itself, +0x4 the AW
// user field of the last write to the probe (a 64-bit read of +0x0 returns both). Writes are only recorded.
//
// QoS tags of the accelerators' DMA ("I/O on behalf of an RCID"): every register strobe hands the slot the SoC user
// field of the access (reg_user_i: source port, RCID, MCID, AT of the requesting hart), and every memory request
// of a slot carries the user field the slot asks for (mem_user_o; the template latches reg_user_i at START, so its
// DMA is tagged with the hart that started the work). The socket is the trusted tagging point: per slot, the
// policy register at 0x103F_0100 + 8*s can FORCE a tag the OS chose instead (the IOMMU device-context model):
//   +0  TAG_POLICY  RW  bit 31 FORCE; [11:0] the user field to stamp on the slot's DMA while FORCE is set
//   +4  LAST_USER   R   the user field of the slot's most recent DMA request, after the policy
// The CCU writes its port index into the low QosUserLsb bits of the user field, so those bits are cleared here.
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
  logic [15:0]      reg_user_q;

  // memory side, per slot
  logic [NumSlots-1:0]       m_req, m_gnt, m_we, m_rvalid, m_err, irqs;
  logic [NumSlots-1:0][63:0] m_addr, m_wdata;
  logic [NumSlots-1:0][7:0]  m_strb;
  logic [NumSlots-1:0][15:0] m_user;
  logic [63:0]               m_rdata;

  // per-slot QoS tag policy (0x103F_0100 + 8*slot) and the user field of the slot's last DMA request
  logic [NumSlots-1:0][31:0] pol_q;
  logic [NumSlots-1:0][15:0] last_user_q;
  localparam logic [15:0] PortBitsMask = 16'((1 << ariane_axi_soc::QosUserLsb) - 1);

  accel_slots #(.NumSlots(NumSlots)) i_slots (
    .clk_i, .rst_ni,
    .reg_req_i    ( reg_req_q   ),
    .reg_slot_i   ( reg_slot_q  ),
    .reg_addr_i   ( reg_addr_q  ),
    .reg_we_i     ( reg_we_q    ),
    .reg_wdata_i  ( reg_wdata_q ),
    .reg_wstrb_i  ( reg_wstrb_q ),
    .reg_user_i   ( reg_user_q  ),
    .reg_ack_o    ( reg_ack     ),
    .reg_err_o    ( reg_err     ),
    .reg_rdata_o  ( reg_rdata   ),
    .mem_req_o    ( m_req       ),
    .mem_gnt_i    ( m_gnt       ),
    .mem_we_o     ( m_we        ),
    .mem_addr_o   ( m_addr      ),
    .mem_wdata_o  ( m_wdata     ),
    .mem_strb_o   ( m_strb      ),
    .mem_user_o   ( m_user      ),
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
  logic [31:0]                       user_q, probe_aw_user_q;

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
  function automatic logic is_probe(logic [63:0] a);
    return a[21:3] == {6'h3F, 13'h0};
  endfunction
  // per-slot tag policy registers: 0x103F_0100 + 8*slot (+0 TAG_POLICY, +4 LAST_USER)
  function automatic logic is_policy(logic [63:0] a);
    return a[21:16] == 6'h3F && a[15:8] == 8'h01 && a[7:3] < NumSlots;
  endfunction
  function automatic logic [SlotW-1:0] policy_slot(logic [63:0] a);
    return a[3 +: SlotW];
  endfunction
  function automatic logic [31:0] policy_write(logic [31:0] old, logic [31:0] wd, logic [3:0] be);
    logic [31:0] v = old;
    for (int b = 0; b < 4; b++) if (be[b]) v[8*b +: 8] = wd[8*b +: 8];
    return {v[31], 19'b0, v[11:0]};   // bit 31 FORCE, [11:0] the user field; the rest reads as 0
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
    reg_user_q  <= user_q[15:0];   // who is accessing the slot (SoC user layout)
    hi_q        <= hi;
    wait_q      <= '0;
  endtask

  // start a read beat at address a (or answer the probe / policy registers / DECERR without an access)
  task automatic start_read(input logic [63:0] a, input logic [2:0] size, input logic [31:0] user);
    rdata_q <= '0;
    if (is_probe(a)) begin
      rdata_q <= {probe_aw_user_q, user}; state_q <= S_RDATA;
    end else if (is_policy(a)) begin
      rdata_q <= {16'b0, last_user_q[policy_slot(a)], pol_q[policy_slot(a)]}; state_q <= S_RDATA;
    end else if (!slot_ok(a)) begin
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
      user_q <= '0; probe_aw_user_q <= '0; pol_q <= '0;
      reg_req_q <= 1'b0; reg_slot_q <= '0; reg_addr_q <= '0; reg_we_q <= 1'b0; reg_wdata_q <= '0; reg_wstrb_q <= '0;
      reg_user_q <= '0;
    end else begin
      reg_req_q <= 1'b0;   // one-cycle strobe; issue() overrides
      case (state_q)
        S_IDLE: begin
          resp_q <= axi_pkg::RESP_OKAY;
          if (aw_take) begin
            is_write_q <= 1'b1; id_q <= slv_req_i.aw.id; addr_q <= slv_req_i.aw.addr; beats_q <= slv_req_i.aw.len;
            size_q <= slv_req_i.aw.size; burst_q <= slv_req_i.aw.burst; atop_q <= (slv_req_i.aw.atop != '0);
            user_q <= 32'(slv_req_i.aw.user);
            state_q <= S_WDATA;
          end else if (ar_take) begin
            is_write_q <= 1'b0; id_q <= slv_req_i.ar.id; addr_q <= slv_req_i.ar.addr; beats_q <= slv_req_i.ar.len;
            size_q <= slv_req_i.ar.size; burst_q <= slv_req_i.ar.burst; atop_q <= 1'b0;
            user_q <= 32'(slv_req_i.ar.user);
            start_read(slv_req_i.ar.addr, slv_req_i.ar.size, 32'(slv_req_i.ar.user));
          end
        end
        S_WDATA: if (w_take) begin
          wdata_q <= slv_req_i.w.data; wstrb_q <= slv_req_i.w.strb;
          if (atop_q || !slot_ok(addr_q) || slv_req_i.w.strb == '0) begin
            // refused, probe or empty beat: no register access
            if (atop_q)                resp_q <= axi_pkg::RESP_SLVERR;
            else if (is_probe(addr_q)) probe_aw_user_q <= user_q;
            else if (is_policy(addr_q)) begin
              // TAG_POLICY is the low word; LAST_USER (high word) is read-only
              if (!addr_q[2] || size_q == 3'd3)
                pol_q[policy_slot(addr_q)] <= policy_write(pol_q[policy_slot(addr_q)], slv_req_i.w.data[31:0], slv_req_i.w.strb[3:0]);
            end
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
            start_read(next_addr(addr_q, size_q, burst_q), size_q, user_q);
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

  // the user field of the request being granted: the slot's own tag, or the one the policy register forces;
  // the port bits are the CCU's to write
  logic [15:0] sel_user;
  assign sel_user = (pol_q[sel][31] ? {4'b0, pol_q[sel][11:0]} : m_user[sel]) & ~PortBitsMask;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rr_q <= '0; ord_q <= '0; cnt_q <= '0; wp_q <= '0; rp_q <= '0; last_user_q <= '0;
    end else begin
      if (dn_req && dn_gnt) begin
        ord_q[wp_q] <= sel; wp_q <= wp_q + 1'b1;
        rr_q <= SlotW'((sel + 1) % NumSlots);
        last_user_q[sel] <= sel_user;
      end
      if (dn_rvalid) rp_q <= rp_q + 1'b1;
      cnt_q <= cnt_q + (dn_req && dn_gnt) - dn_rvalid;
    end
  end

  // axi_from_mem ties the AXI user fields to 0: carry the granted requests' user fields alongside it, in per-channel
  // FIFOs (it issues one AW+W or one AR per granted request, in grant order on each channel), and put them on the
  // channels at their handshakes. Fall-through, so a request issued in its grant cycle sees its own user field.
  axi_req_t    afm_req;
  logic [15:0] u_aw, u_w, u_ar;
  logic        push_w, push_r;
  assign push_w = dn_req && dn_gnt &&  m_we[sel];
  assign push_r = dn_req && dn_gnt && !m_we[sel];
  fifo_v3 #(.FALL_THROUGH(1'b1), .DEPTH(MaxReq + 1), .dtype(logic [15:0])) i_ufifo_aw (
    .clk_i, .rst_ni, .flush_i(1'b0), .testmode_i(1'b0), .full_o(), .empty_o(), .usage_o(),
    .data_i(sel_user), .push_i(push_w), .data_o(u_aw), .pop_i(afm_req.aw_valid && mst_resp_i.aw_ready));
  fifo_v3 #(.FALL_THROUGH(1'b1), .DEPTH(MaxReq + 1), .dtype(logic [15:0])) i_ufifo_w (
    .clk_i, .rst_ni, .flush_i(1'b0), .testmode_i(1'b0), .full_o(), .empty_o(), .usage_o(),
    .data_i(sel_user), .push_i(push_w), .data_o(u_w), .pop_i(afm_req.w_valid && mst_resp_i.w_ready));
  fifo_v3 #(.FALL_THROUGH(1'b1), .DEPTH(MaxReq + 1), .dtype(logic [15:0])) i_ufifo_ar (
    .clk_i, .rst_ni, .flush_i(1'b0), .testmode_i(1'b0), .full_o(), .empty_o(), .usage_o(),
    .data_i(sel_user), .push_i(push_r), .data_o(u_ar), .pop_i(afm_req.ar_valid && mst_resp_i.ar_ready));

  always_comb begin
    mst_req_o         = afm_req;
    mst_req_o.aw.user = $bits(mst_req_o.aw.user)'(u_aw);
    mst_req_o.w.user  = $bits(mst_req_o.w.user)'(u_w);
    mst_req_o.ar.user = $bits(mst_req_o.ar.user)'(u_ar);
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
    .axi_req_o       ( afm_req      ),
    .axi_rsp_i       ( mst_resp_i   )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) irq_o <= 1'b0;
    else         irq_o <= |irqs;
  end

endmodule
