// tb_lock_bloom: how often the LLC's lock box (hit_miss_detect/axi_llc_lock_box_bloom, a counting bloom filter over
// {set index, way one-hot} with the hashes of common_cells sub_per_hash) reports a line as locked that is not.
// A descriptor parked in the bandwidth controller keeps its line locked for up to several accounting periods, so a
// false positive holds a lookup, and with it every request behind it, for that long (soc_tests/t_bchol).
// Per configuration (hash width, rounds): the (set, way) pairs that read as locked while only {set 2, way 0} is
// locked, and the share of all pairs that read as locked for 1 .. 16 random locked lines.
module tb_lock_bloom;
  localparam int unsigned Idx = 10, Ways = 16, W = Idx + Ways, N = 2**Idx * Ways;
  localparam int unsigned PermSeed [3] = '{32'd299034753, 32'd19921030, 32'd294388};
  localparam int unsigned XorSeed  [3] = '{32'd4094834,   32'd995713,   32'd65146511};
  logic [W-1:0] data;

  for (genvar c = 0; c < 6; c++) begin : gen_cfg
    localparam int unsigned HW = (c < 2) ? 8 : (c < 4) ? 10 : 12;
    localparam int unsigned R  = (c % 2) + 1;
    logic [2:0][HW-1:0] h;
    for (genvar k = 0; k < 3; k++) begin : gen_h
      sub_per_hash #(.InpWidth(W), .HashWidth(HW), .NoRounds(R), .PermuteKey(PermSeed[k]), .XorKey(XorSeed[k]))
        i_h (.data_i(data), .hash_o(h[k]), .hash_onehot_o());
    end
    int unsigned tab [3][N];
    bit occ [3][2**HW];
    task automatic fill();
      for (int unsigned s = 0; s < 2**Idx; s++) for (int unsigned w = 0; w < Ways; w++) begin
        data = {Idx'(s), Ways'(1) << w};
        #1;
        for (int k = 0; k < 3; k++) tab[k][s * Ways + w] = h[k];
      end
    endtask
    function automatic int unsigned count(input int unsigned lk [], input bit show);
      int unsigned n = 0;
      for (int k = 0; k < 3; k++) for (int b = 0; b < 2**HW; b++) occ[k][b] = 0;
      foreach (lk[i]) for (int k = 0; k < 3; k++) occ[k][tab[k][lk[i]]] = 1;
      for (int unsigned p = 0; p < N; p++) if (occ[0][tab[0][p]] && occ[1][tab[1][p]] && occ[2][tab[2][p]]) begin
        bit is_l = 0;
        foreach (lk[i]) if (lk[i] == p) is_l = 1;
        if (!is_l) begin
          n++;
          if (show && n <= 12) $write(" {set %0h, way %0d}", p / Ways, p % Ways);
        end
      end
      return n;
    endfunction
    task automatic run();
      int unsigned lk1 [] = '{2 * Ways + 0};
      int unsigned m_list [6] = '{1, 2, 3, 4, 8, 16};
      int unsigned n;
      fill();
      $write("  hash width %0d, %0d round(s): with only {set 2, way 0} locked, also read as locked:", HW, R);
      n = count(lk1, 1);
      $display(" (%0d pairs)", n);
      $write("    false-locked share of all %0d pairs, random locked lines:", N);
      foreach (m_list[mi]) begin
        longint unsigned tot = 0;
        for (int t = 0; t < 400; t++) begin
          int unsigned lk [] = new[m_list[mi]];
          foreach (lk[i]) lk[i] = $urandom_range(N - 1);
          tot += count(lk, 0);
        end
        $write("  %0d locked: %0.3f %%", m_list[mi], 100.0 * real'(tot) / 400.0 / real'(N));
      end
      $display("");
    endtask
  end

  initial begin
    $display("LOCK BLOOM: 3 hashes over {set index (10 bits), way one-hot (16 bits)}");
    gen_cfg[0].run(); gen_cfg[1].run(); gen_cfg[2].run(); gen_cfg[3].run(); gen_cfg[4].run(); gen_cfg[5].run();
    $display("LOCK BLOOM DONE");
    $finish;
  end
endmodule
