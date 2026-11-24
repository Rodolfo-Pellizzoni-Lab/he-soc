// Exact lock box for the LLC's lookup (axi_llc_hit_miss): the lines ({set index, way}) that a descriptor between the
// lookup and its read or write unit is using. Same ports as axi_llc_lock_box_bloom, which it replaces.
//
// The bloom filter answered "locked" for some lines that were not (3 hashes of 8 bits; for two lines of one set
// two of the three hashes often agree, each ignores several way bits). The lookup holds a descriptor whose line
// reads as locked, and every request behind it, until the lock goes away. That was a few cycles while a lock lasted
// as long as one miss; a descriptor parked in the bandwidth controller (axi_llc_cbqri_bc) keeps its line locked for
// up to several accounting periods, and one false answer then stopped every core for that long (soc_tests/t_bchol).
// The lookup never locks a line that is locked, so each line is in the table at most once; the lines in use are
// bounded by the descriptors in flight (the controller's pool, the miss pipeline, the read and write units).
// If the table is full the lookup waits (locked_o), as it does for a locked line.
module axi_llc_lock_box_exact #(
  /// Static LLC parameter configuration struct.
  parameter axi_llc_pkg::llc_cfg_t Cfg = axi_llc_pkg::llc_cfg_t'{default: '0},
  /// typedef struct packed { logic [Cfg.IndexLength-1:0] index; logic [Cfg.SetAssociativity-1:0] way_ind; } lock_t;
  parameter type lock_t = logic,
  /// Lines that can be locked at once.
  parameter int unsigned NumEntries = 32'd48
) (
  input  logic  clk_i,
  input  logic  rst_ni,
  input  logic  test_i,
  /// The line looked up, and locked with `lock_req_i`.
  input  lock_t lock_i,
  input  logic  lock_req_i,
  /// `lock_i` is locked (or the table is full): do not assert `lock_req_i`.
  output logic  locked_o,
  /// Unlock from the write unit.
  input  lock_t w_unlock_i,
  input  logic  w_unlock_req_i,
  output logic  w_unlock_gnt_o,
  /// Unlock from the read unit.
  input  lock_t r_unlock_i,
  input  logic  r_unlock_req_i,
  output logic  r_unlock_gnt_o
);
  localparam int unsigned DataWidth = Cfg.SetAssociativity + Cfg.IndexLength;
  typedef logic [DataWidth-1:0] key_t;

  key_t [NumEntries-1:0] key_q;
  logic [NumEntries-1:0] vld_q, vld_d, hit_look, hit_w, hit_r, free_oh;
  key_t                  look_key, w_key, r_key;

  assign look_key = {lock_i.index,     lock_i.way_ind};
  assign w_key    = {w_unlock_i.index, w_unlock_i.way_ind};
  assign r_key    = {r_unlock_i.index, r_unlock_i.way_ind};

  always_comb begin
    for (int unsigned i = 0; i < NumEntries; i++) begin
      hit_look[i] = vld_q[i] && (key_q[i] == look_key);
      hit_w[i]    = vld_q[i] && (key_q[i] == w_key) && w_unlock_req_i;
      hit_r[i]    = vld_q[i] && (key_q[i] == r_key) && r_unlock_req_i;
    end
    // the lowest free entry
    free_oh = '0;
    for (int i = NumEntries - 1; i >= 0; i--) if (!vld_q[i]) begin
      free_oh    = '0;
      free_oh[i] = 1'b1;
    end
    vld_d = (vld_q & ~hit_w & ~hit_r) | (lock_req_i ? free_oh : '0);
  end

  assign locked_o       = (|hit_look) | (&vld_q);
  assign w_unlock_gnt_o = 1'b1;                    // an unlock takes effect at once, both units in the same cycle
  assign r_unlock_gnt_o = 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vld_q <= '0;
      key_q <= '0;
    end else begin
      vld_q <= vld_d;
      for (int unsigned i = 0; i < NumEntries; i++) if (lock_req_i && free_oh[i]) key_q[i] <= look_key;
    end
  end

  // pragma translate_off
  `ifndef SYNTHESIS
  // Simulation: the most lines locked at once, cycles the table was full, and unlocks of a line that was not locked
  int unsigned lb_max, lb_full, lb_bad_unlock, lb_double;
  always @(posedge clk_i) begin
    if (rst_ni) begin
      if ($countones(vld_q) > lb_max) lb_max = $countones(vld_q);
      if (&vld_q) lb_full = lb_full + 1;
      if (w_unlock_req_i && !(|hit_w)) lb_bad_unlock = lb_bad_unlock + 1;
      if (r_unlock_req_i && !(|hit_r)) lb_bad_unlock = lb_bad_unlock + 1;
      if (lock_req_i && (|hit_look))   lb_double = lb_double + 1;
    end
  end
  final $display("[LLC-LOCK] exact lock box: %0d entries, most locked at once %0d, full for %0d cycles, %0d unlocks of a line not locked, %0d locks of a locked line",
                 NumEntries, lb_max, lb_full, lb_bad_unlock, lb_double);
  `endif
  // pragma translate_on
endmodule
