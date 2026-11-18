// RISC-V CBQRI bandwidth controller (CBQRI v1.0, bandwidth allocation and monitoring) for the LLC's memory traffic.
//
// It sits between the hit/miss unit and the eviction unit, where a descriptor that needs the memory leaves the
// lookup (its victim way chosen and its line locked): every such descriptor enters a parking pool, and an arbiter
// releases the pool into the in-order eviction/refill pipeline. A descriptor with `refill` reads one line from
// memory and one with `evict` writes one (a dirty victim); each costs LineBytes against the RCID in its user field.
// The pool lets the lookup go on while an RCID waits for bandwidth, so one RCID's waiting misses do not hold up the
// hits and misses of the others (a throttle after the memory port would: the miss pipeline is in order and small).
//
// Bandwidth allocation (bc_bw_alloc per RCID): NBWBLKS = 1024 blocks stand for BC_CAPACITY bytes per accounting
// period of BC_PERIOD cycles (implementation-defined registers below), so an RCID's reservation is
// Rbwb * BC_CAPACITY / 1024 bytes per period. Release order, among descriptors the ordering rules allow:
//   1. descriptors that cost nothing (hits the LLC routes through the miss pipeline to keep AXI order, flushes) and
//      descriptors that a descriptor of an RCID still inside its reservation waits for (priority inheritance, two
//      levels), oldest first;
//   2. descriptors of RCIDs inside their reservation (used < reserved this period), oldest first;
//   3. descriptors of RCIDs past their reservation with Mweight > 0, sharing what is left in proportion to Mweight
//      (stride scheduling: each release adds 4096 / Mweight per line to the RCID's pass; lowest pass first);
//   RCIDs past their reservation with Mweight = 0 wait for the next period (a hard limit).
// The controller hands out BC_CAPACITY bytes per period: with BC_CTRL.PACE (the reset value) a token bucket paces all
// releases to BC_CAPACITY / BC_PERIOD bytes per cycle (bursts of up to two lines), so that when the memory is the
// bottleneck the waiting happens here, where the arbiter orders it, and not in the in-order pipeline and memory
// queues behind it (with one or two misses per core in flight the pool would otherwise never hold a choice). Set
// BC_CAPACITY at or a little below what the memory sustains. Within that rate the arbiter is work-conserving:
// whenever a release is allowed and a descriptor is eligible, one leaves. Without PACE it releases whenever the
// pipeline takes a descriptor.
// Ordering rules (the LLC's own): descriptors of one AXI ID leave in order, all writes leave in order (W beats
// carry no ID), and a flush leaves in order with everything. With regulation off (BC_CTRL.EN = 0, the reset state)
// every descriptor is class 1 and the pool is a FIFO.
//
// Registers (offsets in the block, 64-bit; a 32-bit bus accesses them as two words, low word first; a write of
// the byte that holds OP starts an operation, which completes in the cycle of the write, so BUSY is always 0):
//   0x00 bc_capabilities RO  VER = 0x10, NBWBLKS = 1024, RPFX = 0, P = 0, MRBWB = 819 (80 %)
//   0x08 bc_mon_ctl          OP[4:0] AT[7:5] (RO 0) MCID[19:8] EVT_ID[27:20] ATV[28] (RO 0) STATUS[38:32] BUSY[39]
//                            OP 1 CONFIG_EVENT (EVT_ID 0 none, 1 read+write bytes, 2 read bytes, 3 write bytes;
//                            resets the MCID's counter), 2 READ_COUNTER (snapshot into bc_mon_ctr_val)
//                            STATUS 1 ok, 2 bad OP, 3 MCID >= 2^McidWidth, 4 EVT_ID > 3
//   0x10 bc_mon_ctr_val  RO  CTR[61:0] (CtrWidth bits implemented), INV[62] (no event configured), OVF[63]
//   0x18 bc_alloc_ctl        OP[4:0] AT[7:5] (RO 0: no per-AT allocation) RCID[19:8] STATUS[38:32] BUSY[39]
//                            OP 1 CONFIG_LIMIT (the RCID's Rbwb/Mweight := bc_bw_alloc), 2 READ_LIMIT
//                            STATUS 1 ok, 2 bad OP, 3 RCID >= 2^RcidWidth, 5 Rbwb = 0, Rbwb > MRBWB or the sum of
//                            Rbwb over all RCIDs > MRBWB (the allocation is then unchanged)
//   0x20 bc_bw_alloc         Rbwb[15:0] Mweight[27:20] sharedAT[30:28] (RO 0) useShared[31] (RO 0)
//   0x80 BC_CTRL             [0] EN: regulation on (accounting, monitoring and the pool work either way);
//                            [1] PACE: pace releases to BC_CAPACITY / BC_PERIOD bytes per cycle (reset 1)
//   0x88 BC_PERIOD           accounting period in cycles (0 counts as 1)
//   0x90 BC_CAPACITY         bytes per period that NBWBLKS blocks stand for
//   0x98 BC_POOL         RO  [7:0] descriptors in the pool now, [15:8] most at once since the last write (a write
//                            clears it)
//   0xA0 BC_FULL             cycles in which a descriptor waited because the pool was full (a write clears it)
//   0xA8 BC_RATE         RO  the pacing rate, bytes per cycle in 16.16 fixed point (BC_CAPACITY * 2^16 / BC_PERIOD,
//                            recomputed in 48 cycles after a write of either)
// Reset: all RCIDs' Rbwb 0 and Mweight 1, except RCID 0: Rbwb = MRBWB and Mweight 255 (all bandwidth to RCID 0, as
// CBQRI requires); counters off; regulation off; period 10000 cycles; capacity 64000 bytes.
`include "common_cells/registers.svh"

module axi_llc_cbqri_bc #(
  parameter type         desc_t      = logic,   // the LLC descriptor: a_x_id, a_x_user, rw, refill, evict, flush
  parameter int unsigned RcidWidth   = 32'd4,
  parameter int unsigned RcidLsb     = 32'd0,   // position of the RCID in desc.a_x_user
  parameter int unsigned McidWidth   = 32'd4,
  parameter int unsigned McidLsb     = 32'd4,   // position of the MCID in desc.a_x_user
  parameter int unsigned LineBytes   = 32'd64,  // bytes one refill or one eviction moves
  parameter int unsigned PoolDepth   = 32'd16,
  parameter int unsigned CtrWidth    = 32'd48,  // monitoring counter bits
  parameter int unsigned DataWidth   = 32'd32,  // AXI4-Lite data width: 32 or 64
  parameter type         lite_req_t  = logic,
  parameter type         lite_resp_t = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  lite_req_t  req_i,
  output lite_resp_t resp_o,
  // descriptors from the hit/miss unit's miss output
  input  desc_t      desc_i,
  input  logic       valid_i,
  output logic       ready_o,
  // to the eviction unit
  output desc_t      desc_o,
  output logic       valid_o,
  input  logic       ready_i
);

  localparam int unsigned NumRcid  = 2**RcidWidth;
  localparam int unsigned NumMcid  = 2**McidWidth;
  localparam int unsigned IdxW     = (PoolDepth > 1) ? $clog2(PoolDepth) : 1;
  localparam int unsigned RcidIdxW = (RcidWidth > 0) ? RcidWidth : 1;
  localparam int unsigned NBWBLKS  = 32'd1024;
  localparam int unsigned MRBWB    = 32'd819;
  localparam int unsigned PassW    = 32;

  typedef logic [RcidIdxW-1:0] rcid_t;
  typedef logic [McidWidth-1:0] mcid_t;

  // stride per line for a weight: 4096 / Mweight (Mweight 0 never takes the shared class)
  function automatic logic [12:0] stride_of(logic [7:0] w);
    return (w == 8'd0) ? 13'd0 : 13'(32'd4096 / 32'(w));
  endfunction

  // ---------------------------------------------------------------------------------------------- registers
  logic                       en_q, pace_q;
  logic [31:0]                period_q, capacity_q;
  logic [31:0]                rate_q;              // 16.16 bytes per cycle
  logic [39:0]                tok_q;               // 24.16 bytes
  logic [5:0]                 div_cnt_q;           // rate divider: iterations left (0: idle)
  logic [47:0]                div_num_q, div_quo_q;
  logic [32:0]                div_rem_q;
  logic                       div_start_q;
  logic [NumRcid-1:0][15:0]   rbwb_q;
  logic [NumRcid-1:0][7:0]    mweight_q;
  logic [16:0]                rbwb_sum_q;
  logic [15:0]                bw_rbwb_q;           // bc_bw_alloc
  logic [7:0]                 bw_mweight_q;
  logic [4:0]                 a_op_q;              // bc_alloc_ctl
  logic [11:0]                a_rcid_q;
  logic [6:0]                 a_status_q;
  logic [4:0]                 m_op_q;              // bc_mon_ctl
  logic [11:0]                m_mcid_q;
  logic [7:0]                 m_evt_q;
  logic [6:0]                 m_status_q;
  logic [63:0]                m_val_q;             // bc_mon_ctr_val
  logic [NumMcid-1:0][1:0]    evt_q;               // per MCID: 0 off, 1 rd+wr, 2 rd, 3 wr
  logic [NumMcid-1:0][CtrWidth-1:0] ctr_q;
  logic [NumMcid-1:0]         ovf_q;
  logic [7:0]                 pool_max_q;
  logic [31:0]                full_q;
  logic                       b_valid_q, r_valid_q;
  logic [DataWidth-1:0]       r_data_q;

  // accounting
  logic [31:0]                per_cnt_q;
  logic [NumRcid-1:0][31:0]   used_q, resv_q;
  logic [NumRcid-1:0][PassW-1:0] pass_q;
  rcid_t                      rc_idx_q;            // reservation recompute pointer

  // pool
  desc_t [PoolDepth-1:0]                 pool_q;
  logic  [PoolDepth-1:0]                 pv_q;
  logic  [PoolDepth-1:0][PoolDepth-1:0]  older_q;  // older_q[i][j]: entry j is older than entry i

  // output register
  desc_t out_q;
  logic  out_valid_q;

  // ---------------------------------------------------------------------------------------------- pool decode
  rcid_t [PoolDepth-1:0] e_rcid;
  mcid_t [PoolDepth-1:0] e_mcid;
  logic  [PoolDepth-1:0] e_free, e_under, e_wgt;   // costs nothing / RCID inside its reservation / Mweight > 0
  logic  [PoolDepth-1:0][PoolDepth-1:0] dep;       // dep[i][j]: i must not leave before j if j is older
  logic  [PoolDepth-1:0] blocked, rdy, need1, need2;
  logic  [NumRcid-1:0]   under_r;

  always_comb begin
    for (int unsigned r = 0; r < NumRcid; r++) under_r[r] = used_q[r] < resv_q[r];
    for (int unsigned i = 0; i < PoolDepth; i++) begin
      e_rcid[i]  = rcid_t'(pool_q[i].a_x_user[RcidLsb +: RcidIdxW]);
      e_mcid[i]  = mcid_t'(pool_q[i].a_x_user[McidLsb +: McidWidth]);
      e_free[i]  = pool_q[i].flush | !(pool_q[i].refill | pool_q[i].evict);
      e_under[i] = under_r[e_rcid[i]];
      e_wgt[i]   = mweight_q[e_rcid[i]] != 8'd0;
    end
    for (int unsigned i = 0; i < PoolDepth; i++)
      for (int unsigned j = 0; j < PoolDepth; j++)
        dep[i][j] = (pool_q[i].a_x_id == pool_q[j].a_x_id) | (pool_q[i].rw & pool_q[j].rw) |
                    pool_q[i].flush | pool_q[j].flush;
    for (int unsigned i = 0; i < PoolDepth; i++) begin
      blocked[i] = |(pv_q & older_q[i] & dep[i]);
      rdy[i]     = pv_q[i] & !blocked[i];
    end
    // priority inheritance: j is needed when a younger dependent k of an RCID inside its reservation waits for it
    for (int unsigned j = 0; j < PoolDepth; j++) begin
      need1[j] = 1'b0;
      for (int unsigned k = 0; k < PoolDepth; k++)
        need1[j] |= pv_q[k] & older_q[k][j] & dep[k][j] & e_under[k];
    end
    for (int unsigned j = 0; j < PoolDepth; j++) begin
      need2[j] = 1'b0;
      for (int unsigned k = 0; k < PoolDepth; k++)
        need2[j] |= need1[k] & pv_q[k] & older_q[k][j] & dep[k][j];
    end
  end

  // ---------------------------------------------------------------------------------------------- arbiter
  logic [PoolDepth-1:0] c0, c1, c2, cand, sel;
  logic [NumRcid-1:0]   has2;
  rcid_t                rmin;
  logic [1:0]           mode;                      // class of the released descriptor: 0, 1 or 2
  logic [IdxW-1:0]      sel_idx;
  logic                 any_sel;

  // pacing: may a descriptor of 1 or 2 lines leave now
  localparam int unsigned BurstBytes = 2 * LineBytes;
  logic pace_on, tok1, tok2;
  logic [PoolDepth-1:0] e_tok;
  always_comb begin
    pace_on = en_q & pace_q;
    tok1    = !pace_on || tok_q >= 40'(LineBytes) << 16;
    tok2    = !pace_on || tok_q >= 40'(2 * LineBytes) << 16;
    for (int unsigned i = 0; i < PoolDepth; i++)
      e_tok[i] = (pool_q[i].refill & pool_q[i].evict) ? tok2 : tok1;
  end

  // the three classes and the RCIDs with a class-3 candidate (no input from the blocks below: no comb ring)
  always_comb begin
    for (int unsigned i = 0; i < PoolDepth; i++) begin
      c0[i] = rdy[i] & en_q & (e_free[i] | ((need1[i] | need2[i]) & e_tok[i]));
      c1[i] = rdy[i] & (!en_q | (e_under[i] & e_tok[i]));
      c2[i] = rdy[i] & en_q & e_wgt[i] & e_tok[i];
    end
    for (int unsigned r = 0; r < NumRcid; r++) begin
      has2[r] = 1'b0;
      for (int unsigned i = 0; i < PoolDepth; i++) has2[r] |= c2[i] & (e_rcid[i] == rcid_t'(r));
    end
  end

  // lowest pass among the RCIDs in has2 (ties: lowest RCID), as a tree of log2(NumRcid) levels
  localparam int unsigned Levels = RcidIdxW;
  always_comb begin
    logic  [NumRcid-1:0]            tv;
    rcid_t [NumRcid-1:0]            ti;
    logic  [NumRcid-1:0][PassW-1:0] tp;
    for (int unsigned r = 0; r < NumRcid; r++) begin
      tv[r] = has2[r];
      ti[r] = rcid_t'(r);
      tp[r] = pass_q[r];
    end
    for (int unsigned l = 0; l < Levels; l++)
      for (int unsigned k = 0; k < (NumRcid >> (l + 1)); k++)
        if (tv[2*k] && (!tv[2*k+1] || tp[2*k] <= tp[2*k+1])) begin
          tv[k] = tv[2*k];   ti[k] = ti[2*k];   tp[k] = tp[2*k];
        end else begin
          tv[k] = tv[2*k+1]; ti[k] = ti[2*k+1]; tp[k] = tp[2*k+1];
        end
    rmin = ti[0];
  end

  always_comb begin
    if (|c0)      begin cand = c0; mode = 2'd0; end
    else if (|c1) begin cand = c1; mode = 2'd1; end
    else begin
      mode = 2'd2;
      for (int unsigned i = 0; i < PoolDepth; i++) cand[i] = c2[i] & (e_rcid[i] == rmin);
    end
    // the oldest candidate
    for (int unsigned i = 0; i < PoolDepth; i++) sel[i] = cand[i] & !(|(cand & older_q[i]));
    any_sel = |sel;
    sel_idx = '0;
    for (int unsigned i = 0; i < PoolDepth; i++) if (sel[i]) sel_idx = IdxW'(i);
  end

  logic        load, rel_rd, rel_wr;
  logic [1:0]  rel_lines;
  logic [31:0] rel_bytes;
  rcid_t       rel_rcid;
  mcid_t       rel_mcid;
  assign load      = any_sel && (!out_valid_q || ready_i);
  assign rel_rd    = pool_q[sel_idx].refill & !pool_q[sel_idx].flush;
  assign rel_wr    = pool_q[sel_idx].evict  & !pool_q[sel_idx].flush;
  assign rel_lines = {1'b0, rel_rd} + {1'b0, rel_wr};
  assign rel_bytes = 32'(rel_lines) * LineBytes;
  assign rel_rcid  = e_rcid[sel_idx];
  assign rel_mcid  = e_mcid[sel_idx];

  // insertion slot: the lowest free entry
  logic [IdxW-1:0] free_idx;
  logic            has_free;
  always_comb begin
    has_free = !(&pv_q);
    free_idx = '0;
    for (int i = PoolDepth - 1; i >= 0; i--) if (!pv_q[i]) free_idx = IdxW'(i);
  end
  assign ready_o = has_free;
  wire   insert  = valid_i && has_free;

  assign desc_o  = out_q;
  assign valid_o = out_valid_q;

  logic [7:0] occ;
  always_comb begin
    occ = '0;
    for (int unsigned i = 0; i < PoolDepth; i++) occ += 8'(pv_q[i]);
  end

  // ---------------------------------------------------------------------------------------------- bus
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

  logic [63:0] reg_rd;
  always_comb begin
    case (req_i.ar.addr[7:3])
      5'd0:  reg_rd = {16'd0, 16'(MRBWB), 3'd0, 4'd0, 1'b0, 16'(NBWBLKS), 8'h10};
      5'd1:  reg_rd = {24'd0, 1'b0, m_status_q, 3'd0, 1'b0, m_evt_q, m_mcid_q, 3'd0, m_op_q};
      5'd2:  reg_rd = m_val_q;
      5'd3:  reg_rd = {24'd0, 1'b0, a_status_q, 12'd0, a_rcid_q, 3'd0, a_op_q};
      5'd4:  reg_rd = {32'd0, 1'b0, 3'd0, bw_mweight_q, 4'd0, bw_rbwb_q};
      5'd16: reg_rd = {62'd0, pace_q, en_q};
      5'd17: reg_rd = 64'(period_q);
      5'd18: reg_rd = 64'(capacity_q);
      5'd19: reg_rd = {48'd0, pool_max_q, occ};
      5'd20: reg_rd = 64'(full_q);
      5'd21: reg_rd = 64'(rate_q);
      default: reg_rd = 64'd0;
    endcase
  end

  wire         w_take = req_i.aw_valid && req_i.w_valid && !b_valid_q;
  wire [4:0]   w_idx  = req_i.aw.addr[7:3];
  wire         w_ours = req_i.aw.addr[9:8] == 2'b00;
  wire [63:0]  w_d    = lane_data(req_i.w.data, req_i.aw.addr[2]);
  wire [7:0]   w_s    = lane_strb(req_i.w.strb, req_i.aw.addr[2]);
  wire [63:0]  w_actl = merge({44'd0, a_rcid_q, 3'd0, a_op_q}, w_d, w_s);
  wire [63:0]  w_mctl = merge({36'd0, m_evt_q, m_mcid_q, 3'd0, m_op_q}, w_d, w_s);
  wire [63:0]  w_bw   = merge({36'd0, bw_mweight_q, 4'd0, bw_rbwb_q}, w_d, w_s);
  wire         r_take = req_i.ar_valid && !r_valid_q;

  // CONFIG_LIMIT checks (on the values in bc_bw_alloc)
  rcid_t       a_r;
  logic [16:0] sum_new;
  assign a_r     = rcid_t'(w_actl[8 +: RcidIdxW]);
  assign sum_new = rbwb_sum_q - 17'(rbwb_q[a_r]) + 17'(bw_rbwb_q);
  // monitoring: what a release adds to its MCID's counter, and a CONFIG_EVENT of that MCID in the same cycle
  logic [31:0]         mon_add;
  logic [CtrWidth:0]   mon_sum;
  logic                mon_cfg_same;
  always_comb begin
    case (evt_q[rel_mcid])
      2'd1:    mon_add = rel_bytes;
      2'd2:    mon_add = rel_rd ? 32'(LineBytes) : 32'd0;
      2'd3:    mon_add = rel_wr ? 32'(LineBytes) : 32'd0;
      default: mon_add = 32'd0;
    endcase
    mon_sum      = {1'b0, ctr_q[rel_mcid]} + (CtrWidth+1)'(mon_add);
    mon_cfg_same = w_take && w_ours && w_idx == 5'd1 && w_s[0] && w_mctl[4:0] == 5'd1 &&
                   w_mctl[19:8] == 12'(rel_mcid);
  end

  always_comb begin
    resp_o          = '0;
    resp_o.aw_ready = w_take;
    resp_o.w_ready  = w_take;
    resp_o.b_valid  = b_valid_q;
    resp_o.b.resp   = axi_pkg::RESP_OKAY;
    resp_o.ar_ready = r_take;
    resp_o.r_valid  = r_valid_q;
    resp_o.r.data   = r_data_q;
    resp_o.r.resp   = axi_pkg::RESP_OKAY;
  end

  // ---------------------------------------------------------------------------------------------- state
  wire period_end = en_q && (per_cnt_q + 32'd1 >= ((period_q == 32'd0) ? 32'd1 : period_q));

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      en_q         <= 1'b0;
      pace_q       <= 1'b1;
      period_q     <= 32'd10000;
      capacity_q   <= 32'd64000;
      rate_q       <= 32'((64'd64000 << 16) / 64'd10000);
      tok_q        <= '0;
      div_cnt_q    <= '0;
      div_num_q    <= '0;
      div_quo_q    <= '0;
      div_rem_q    <= '0;
      div_start_q  <= 1'b0;
      for (int unsigned r = 0; r < NumRcid; r++) begin
        rbwb_q[r]    <= (r == 0) ? 16'(MRBWB) : 16'd0;
        mweight_q[r] <= (r == 0) ? 8'd255 : 8'd1;
      end
      rbwb_sum_q   <= 17'(MRBWB);
      bw_rbwb_q    <= '0;
      bw_mweight_q <= '0;
      a_op_q       <= '0;
      a_rcid_q     <= '0;
      a_status_q   <= '0;
      m_op_q       <= '0;
      m_mcid_q     <= '0;
      m_evt_q      <= '0;
      m_status_q   <= '0;
      m_val_q      <= '0;
      evt_q        <= '0;
      ctr_q        <= '0;
      ovf_q        <= '0;
      pool_max_q   <= '0;
      full_q       <= '0;
      b_valid_q    <= 1'b0;
      r_valid_q    <= 1'b0;
      r_data_q     <= '0;
      per_cnt_q    <= '0;
      used_q       <= '0;
      resv_q       <= '0;
      pass_q       <= '0;
      rc_idx_q     <= '0;
      pool_q       <= '0;
      pv_q         <= '0;
      older_q      <= '0;
      out_q        <= '0;
      out_valid_q  <= 1'b0;
    end else begin
      // ---- bus
      if (b_valid_q && req_i.b_ready) b_valid_q <= 1'b0;
      if (r_valid_q && req_i.r_ready) r_valid_q <= 1'b0;
      if (r_take) begin
        r_valid_q <= 1'b1;
        r_data_q  <= read_lane(reg_rd, req_i.ar.addr[2]);
      end
      if (w_take) begin
        b_valid_q <= 1'b1;
        if (w_ours) begin
          case (w_idx)
            5'd1: begin
              m_op_q   <= w_mctl[4:0];
              m_mcid_q <= w_mctl[19:8];
              m_evt_q  <= w_mctl[27:20];
              if (w_s[0]) begin
                if (w_mctl[4:0] != 5'd1 && w_mctl[4:0] != 5'd2)              m_status_q <= 7'd2;
                else if (w_mctl[19:8] >= 12'(NumMcid))                       m_status_q <= 7'd3;
                else if (w_mctl[4:0] == 5'd1 && w_mctl[27:20] > 8'd3)        m_status_q <= 7'd4;
                else begin
                  m_status_q <= 7'd1;
                  if (w_mctl[4:0] == 5'd1) begin
                    evt_q[mcid_t'(w_mctl[19:8])] <= w_mctl[21:20];
                    ctr_q[mcid_t'(w_mctl[19:8])] <= '0;
                    ovf_q[mcid_t'(w_mctl[19:8])] <= 1'b0;
                  end else begin
                    m_val_q <= {ovf_q[mcid_t'(w_mctl[19:8])], evt_q[mcid_t'(w_mctl[19:8])] == 2'd0,
                                62'(ctr_q[mcid_t'(w_mctl[19:8])])};
                  end
                end
              end
            end
            5'd3: begin
              a_op_q   <= w_actl[4:0];
              a_rcid_q <= w_actl[19:8];
              if (w_s[0]) begin
                if (w_actl[4:0] != 5'd1 && w_actl[4:0] != 5'd2)              a_status_q <= 7'd2;
                else if (w_actl[19:8] >= 12'(NumRcid))                       a_status_q <= 7'd3;
                else if (w_actl[4:0] == 5'd1 &&
                         (bw_rbwb_q == 16'd0 || bw_rbwb_q > 16'(MRBWB) || sum_new > 17'(MRBWB)))
                                                                             a_status_q <= 7'd5;
                else begin
                  a_status_q <= 7'd1;
                  if (w_actl[4:0] == 5'd1) begin
                    rbwb_q[a_r]    <= bw_rbwb_q;
                    mweight_q[a_r] <= bw_mweight_q;
                    rbwb_sum_q     <= sum_new;
                  end else begin
                    bw_rbwb_q    <= rbwb_q[a_r];
                    bw_mweight_q <= mweight_q[a_r];
                  end
                end
              end
            end
            5'd4: begin
              bw_rbwb_q    <= w_bw[15:0];
              bw_mweight_q <= w_bw[27:20];
            end
            5'd16: if (w_s[0]) begin en_q <= w_d[0]; pace_q <= w_d[1]; end
            5'd17: period_q   <= merge(64'(period_q),   w_d, w_s) & 64'hFFFF_FFFF;
            5'd18: capacity_q <= merge(64'(capacity_q), w_d, w_s) & 64'hFFFF_FFFF;
            5'd19: pool_max_q <= '0;
            5'd20: full_q     <= '0;
            default: ;
          endcase
        end
      end

      // ---- pacing rate = capacity * 2^16 / period: restoring division, one quotient bit per cycle (48), started
      //      the cycle after a write of either register, on the written values
      if (div_start_q) begin
        div_start_q <= 1'b0;
        div_num_q   <= {capacity_q, 16'd0};
        div_rem_q   <= '0;
        div_quo_q   <= '0;
        div_cnt_q   <= 6'd48;
      end else if (div_cnt_q != 6'd0) begin
        logic [32:0] rem_n;
        logic [31:0] d;
        logic [47:0] quo_n;
        d     = (period_q == 32'd0) ? 32'd1 : period_q;
        rem_n = {div_rem_q[31:0], div_num_q[47]};
        quo_n = {div_quo_q[46:0], rem_n >= {1'b0, d}};
        div_num_q <= div_num_q << 1;
        div_rem_q <= (rem_n >= {1'b0, d}) ? rem_n - {1'b0, d} : rem_n;
        div_quo_q <= quo_n;
        div_cnt_q <= div_cnt_q - 6'd1;
        if (div_cnt_q == 6'd1) rate_q <= (|quo_n[47:32]) ? 32'hFFFF_FFFF : quo_n[31:0];
      end
      if (w_take && w_ours && (w_idx == 5'd17 || w_idx == 5'd18)) div_start_q <= 1'b1;   // wins over the clear
      // tokens: rate per cycle up to two lines; a release takes its bytes; full while pacing is off
      if (!pace_on) tok_q <= 40'(BurstBytes) << 16;
      else begin
        logic [40:0] t;
        t = {1'b0, tok_q} + 41'(rate_q);
        if (load && rel_lines != 2'd0) t = t - (41'(rel_bytes) << 16);
        tok_q <= (t > 41'(40'(BurstBytes) << 16)) ? 40'(BurstBytes) << 16 : t[39:0];
      end

      // ---- reservations in bytes per period, one RCID per cycle
      resv_q[rc_idx_q] <= 32'((64'(rbwb_q[rc_idx_q]) * 64'(capacity_q)) >> 10);
      rc_idx_q         <= (32'(rc_idx_q) == NumRcid - 1) ? rcid_t'(0) : rcid_t'(rc_idx_q + 1);

      // ---- statistics
      if (occ > pool_max_q) pool_max_q <= occ;
      if (valid_i && !has_free && full_q != '1) full_q <= full_q + 32'd1;

      // ---- output register
      if (out_valid_q && ready_i) out_valid_q <= 1'b0;
      if (load) begin
        out_q       <= pool_q[sel_idx];
        out_valid_q <= 1'b1;
      end

      // ---- accounting period (cleared while regulation is off, so it starts clean when it is turned on)
      if (period_end || !en_q) begin
        per_cnt_q <= '0;
        used_q    <= '0;
        pass_q    <= '0;
      end else begin
        per_cnt_q <= per_cnt_q + 32'd1;
      end
      if (load && rel_lines != 2'd0) begin
        if (en_q) begin
          if (period_end) used_q[rel_rcid] <= rel_bytes;
          else if (used_q[rel_rcid] <= 32'hFFFF_FFFF - rel_bytes) used_q[rel_rcid] <= used_q[rel_rcid] + rel_bytes;
          else used_q[rel_rcid] <= 32'hFFFF_FFFF;
          if (mode == 2'd2 && !period_end)
            pass_q[rel_rcid] <= pass_q[rel_rcid] + PassW'(stride_of(mweight_q[rel_rcid])) * PassW'(rel_lines);
        end
        // monitoring: bytes past this point, per MCID (regulation on or off)
        if (!mon_cfg_same && mon_add != 32'd0) begin
          ctr_q[rel_mcid] <= mon_sum[CtrWidth-1:0];
          if (mon_sum[CtrWidth]) ovf_q[rel_mcid] <= 1'b1;
        end
      end

      // ---- pool: release, then insertion (a slot freed this cycle is reused from the next one on)
      if (load) pv_q[sel_idx] <= 1'b0;
      if (insert) begin
        pool_q[free_idx] <= desc_i;
        pv_q[free_idx]   <= 1'b1;
        for (int unsigned i = 0; i < PoolDepth; i++) begin
          older_q[i][free_idx] <= 1'b0;                                    // the newcomer is the youngest
          older_q[free_idx][i] <= pv_q[i] && !(load && sel_idx == IdxW'(i)) && (IdxW'(i) != free_idx);
        end
      end
    end
  end

  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (DataWidth == 32 || DataWidth == 64) else $fatal(1, "axi_llc_cbqri_bc: DataWidth 32 or 64");
    assert (RcidWidth >= 1 && RcidWidth <= 12)  else $fatal(1, "axi_llc_cbqri_bc: RcidWidth 1..12");
    assert (McidWidth >= 1 && McidWidth <= 12)  else $fatal(1, "axi_llc_cbqri_bc: McidWidth 1..12");
    assert (PoolDepth >= 2 && PoolDepth <= 64)  else $fatal(1, "axi_llc_cbqri_bc: PoolDepth 2..64");
    assert (CtrWidth >= 8 && CtrWidth <= 62)    else $fatal(1, "axi_llc_cbqri_bc: CtrWidth 8..62");
  end
  `endif
  // pragma translate_on
endmodule
