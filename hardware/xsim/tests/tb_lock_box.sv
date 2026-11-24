// tb_lock_box: the LLC's exact lock box (hit_miss_detect/axi_llc_lock_box_exact) against a reference set.
// Random lookups, locks and unlocks (both unlock ports in one cycle) over a small universe of lines and an 8-entry
// table, so the table fills: locked_o must be 1 exactly for a locked line or a full table, never for another line.
module tb_lock_box;
  localparam int unsigned Idx = 10, Ways = 16, NE = 8, NKEYS = 24;
  localparam axi_llc_pkg::llc_cfg_t Cfg = '{SetAssociativity: Ways, IndexLength: Idx, default: '0};
  typedef struct packed { logic [Idx-1:0] index; logic [Ways-1:0] way_ind; } lock_t;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  lock_t lock, wul, rul;
  logic  lock_req, locked, wreq, rreq, wgnt, rgnt;

  axi_llc_lock_box_exact #(.Cfg(Cfg), .lock_t(lock_t), .NumEntries(NE)) dut (
    .clk_i(clk), .rst_ni(rst_n), .test_i(1'b0), .lock_i(lock), .lock_req_i(lock_req), .locked_o(locked),
    .w_unlock_i(wul), .w_unlock_req_i(wreq), .w_unlock_gnt_o(wgnt),
    .r_unlock_i(rul), .r_unlock_req_i(rreq), .r_unlock_gnt_o(rgnt));

  lock_t keys [NKEYS];
  bit    held [NKEYS];
  int    nheld = 0, fails = 0, n_lock = 0, n_unlock = 0, n_full = 0, n_look = 0;

  initial begin
    // the lines the bloom filter confused: one set in several ways, and sets that differ in one index bit
    for (int k = 0; k < NKEYS; k++) begin
      keys[k].index   = (k < 8) ? 10'h002 : (k < 12) ? 10'h202 : (k < 16) ? 10'h046 : Idx'($urandom_range(1023));
      keys[k].way_ind = Ways'(1) << ((k < 8) ? k : (k < 16) ? (k % 4) * 4 + 1 : $urandom_range(15));
      for (int j = 0; j < k; j++) if (keys[j] == keys[k]) keys[k].index = keys[k].index + 10'd7 + Idx'(k);
    end
    lock = '0; wul = '0; rul = '0; lock_req = 0; wreq = 0; rreq = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    @(negedge clk);
    for (int t = 0; t < 40000; t++) begin
      int k, a, b;
      // set the inputs for this cycle
      k = $urandom_range(NKEYS - 1);
      lock = keys[k];
      wreq = 0; rreq = 0; a = -1; b = -1;
      if ($urandom_range(3) == 0) begin              // unlock one or two held lines
        for (int j = 0; j < NKEYS; j++) if (held[(j + t) % NKEYS] && a < 0) a = (j + t) % NKEYS;
        if (a >= 0) begin wul = keys[a]; wreq = 1; end
        if ($urandom_range(1)) begin
          for (int j = 0; j < NKEYS; j++) if (held[(j + 3 * t) % NKEYS] && (j + 3 * t) % NKEYS != a && b < 0) b = (j + 3 * t) % NKEYS;
          if (b >= 0) begin rul = keys[b]; rreq = 1; end
        end
      end
      #1;
      n_look++;
      if (locked !== (held[k] || nheld == NE)) begin
        fails++;
        if (fails < 10) $display("FAIL t=%0d: line {set %0h, way %0h} locked_o %b, expected %b (%0d of %0d entries held)",
                                 t, keys[k].index, keys[k].way_ind, locked, held[k] || nheld == NE, nheld, NE);
      end
      if (nheld == NE) n_full++;
      if (!wgnt || !rgnt) begin fails++; $display("FAIL t=%0d: unlock not granted", t); end
      lock_req = !locked && ($urandom_range(2) != 0);
      @(posedge clk);
      #1;
      if (lock_req) begin held[k] = 1; nheld++; n_lock++; end
      if (a >= 0) begin held[a] = 0; nheld--; n_unlock++; end
      if (b >= 0) begin held[b] = 0; nheld--; n_unlock++; end
      lock_req = 0;
      @(negedge clk);
    end
    $display("  %0d lookups, %0d locks, %0d unlocks, table full in %0d cycles, %0d mismatches", n_look, n_lock, n_unlock, n_full, fails);
    if (fails == 0 && n_full > 0 && n_lock > 1000) $display("LOCK BOX UNIT PASS");
    else $display("LOCK BOX UNIT FAIL");
    $finish;
  end
endmodule
