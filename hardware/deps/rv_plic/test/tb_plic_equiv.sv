// Equivalence testbench for the PLIC changes of the more-cores branch. Three comparisons run side by side,
// every output compared each cycle against the previous logic:
//  (A) plic_top (TREE finder + parameterised register map) against plic_top_ref (MATRIX finder + the map
//      generated for 255 sources x 8 targets): random interrupt sources and random register traffic
//      (priorities, pending, enables, thresholds, claims and completes, unaligned and out-of-range addresses);
//  (B) plic_regs at 255 x 16 against the map generated for 16 targets, random inputs and traffic;
//  (C) rv_plic_target TREE against MATRIX at 255, 30 and 1 sources, random stimulus plus directed corners
//      (all sources tied, threshold at the maximum, a single source, enables only on the last source).
// Run with run_xsim.sh. Prints "PLIC EQUIV PASS" or "PLIC EQUIV FAIL <mismatches>".
module tb_plic_equiv;
  localparam int unsigned NS = 255, NT = 8, NT16 = 16, MP = 7, PW = 3, SW = 8;
  localparam logic [31:0] BASE = 32'h0C00_0000;
  localparam int unsigned CYCLES = 40000;

  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;
  int unsigned errors = 0, errors_a = 0, errors_b = 0, errors_c = 0;

  function automatic logic [31:0] rand_addr(input int unsigned ntgt);
    case ($urandom_range(0, 10))
      0, 1:    return BASE + 4 * $urandom_range(0, NS + 5);                                          // priorities, a few past the end
      2:       return BASE + 32'h1000 + 4 * $urandom_range(0, 9);                                    // pending words, two past the end
      3, 4:    return BASE + 32'h2000 + 32'h80 * $urandom_range(0, ntgt + 1) + 4 * $urandom_range(0, 31); // enables
      5:       return BASE + 32'h20_0000 + 32'h1000 * $urandom_range(0, ntgt + 1);                   // thresholds
      6, 7:    return BASE + 32'h20_0004 + 32'h1000 * $urandom_range(0, ntgt + 1);                   // claim / complete
      8:       return BASE + 32'h20_0000 + 32'h1000 * $urandom_range(0, ntgt - 1) + $urandom_range(0, 32'hFFF);
      9:       return BASE + $urandom_range(0, 32'h3F_FFFF);                                          // anywhere in the window
      default: return $urandom();
    endcase
  endfunction

  function automatic reg_intf::reg_intf_req_a32_d32 rand_req(input int unsigned ntgt);
    reg_intf::reg_intf_req_a32_d32 r;
    r.valid = ($urandom_range(0, 9) < 7);
    r.write = $urandom_range(0, 1);
    r.addr  = rand_addr(ntgt);
    r.wdata = $urandom();
    r.wstrb = 4'hF;
    return r;
  endfunction

  // ---------------- (A) the whole PLIC, new against reference ----------------
  reg_intf::reg_intf_req_a32_d32 req_a;
  reg_intf::reg_intf_resp_d32    resp_a_new, resp_a_ref;
  logic [NS-1:0] src_a;
  logic [NT-1:0] eip_a_new, eip_a_ref;

  plic_top #(.N_SOURCE(NS), .N_TARGET(NT), .MAX_PRIO(MP)) i_a_new (
    .clk_i(clk), .rst_ni(rst_n), .req_i(req_a), .resp_o(resp_a_new), .le_i('0),
    .irq_sources_i(src_a), .eip_targets_o(eip_a_new));
  plic_top_ref #(.N_SOURCE(NS), .N_TARGET(NT), .MAX_PRIO(MP)) i_a_ref (
    .clk_i(clk), .rst_ni(rst_n), .req_i(req_a), .resp_o(resp_a_ref), .le_i('0),
    .irq_sources_i(src_a), .eip_targets_o(eip_a_ref));

  // ---------------- (B) the register map at 16 targets ----------------
  reg_intf::reg_intf_req_a32_d32 req_b;
  reg_intf::reg_intf_resp_d32    resp_b_new, resp_b_ref;
  logic [NS:0][PW-1:0]        b_prio_i, b_prio_o_new, b_prio_o_ref;
  logic [NS:0]                b_prio_we_new, b_prio_we_ref, b_prio_re_new, b_prio_re_ref;
  logic [0:0][NS:0]           b_ip_i;
  logic [0:0]                 b_ip_re_new, b_ip_re_ref;
  logic [NT16-1:0][NS:0]      b_ie_i, b_ie_o_new, b_ie_o_ref;
  logic [NT16-1:0]            b_ie_we_new, b_ie_we_ref, b_ie_re_new, b_ie_re_ref;
  logic [NT16-1:0][PW-1:0]    b_thr_i, b_thr_o_new, b_thr_o_ref;
  logic [NT16-1:0]            b_thr_we_new, b_thr_we_ref, b_thr_re_new, b_thr_re_ref;
  logic [NT16-1:0][SW-1:0]    b_cc_i, b_cc_o_new, b_cc_o_ref;
  logic [NT16-1:0]            b_cc_we_new, b_cc_we_ref, b_cc_re_new, b_cc_re_ref;

  plic_regs #(.N_SOURCE(NS), .N_TARGET(NT16), .MAX_PRIO(MP)) i_b_new (
    .prio_i(b_prio_i), .prio_o(b_prio_o_new), .prio_we_o(b_prio_we_new), .prio_re_o(b_prio_re_new),
    .ip_i(b_ip_i), .ip_re_o(b_ip_re_new),
    .ie_i(b_ie_i), .ie_o(b_ie_o_new), .ie_we_o(b_ie_we_new), .ie_re_o(b_ie_re_new),
    .threshold_i(b_thr_i), .threshold_o(b_thr_o_new), .threshold_we_o(b_thr_we_new), .threshold_re_o(b_thr_re_new),
    .cc_i(b_cc_i), .cc_o(b_cc_o_new), .cc_we_o(b_cc_we_new), .cc_re_o(b_cc_re_new),
    .req_i(req_b), .resp_o(resp_b_new));
  plic_regs_gen256x16 i_b_ref (
    .prio_i(b_prio_i), .prio_o(b_prio_o_ref), .prio_we_o(b_prio_we_ref), .prio_re_o(b_prio_re_ref),
    .ip_i(b_ip_i), .ip_re_o(b_ip_re_ref),
    .ie_i(b_ie_i), .ie_o(b_ie_o_ref), .ie_we_o(b_ie_we_ref), .ie_re_o(b_ie_re_ref),
    .threshold_i(b_thr_i), .threshold_o(b_thr_o_ref), .threshold_we_o(b_thr_we_ref), .threshold_re_o(b_thr_re_ref),
    .cc_i(b_cc_i), .cc_o(b_cc_o_ref), .cc_we_o(b_cc_we_ref), .cc_re_o(b_cc_re_ref),
    .req_i(req_b), .resp_o(resp_b_ref));

  // ---------------- (C) the finder alone, TREE against MATRIX ----------------
  logic [NS-1:0]         c_ip, c_ie;
  logic [NS-1:0][PW-1:0] c_prio;
  logic [PW-1:0]         c_thr;
  logic                  c_irq_new255, c_irq_ref255, c_irq_new30, c_irq_ref30, c_irq_new1, c_irq_ref1;
  logic [SW-1:0]         c_id_new255, c_id_ref255;
  logic [4:0]            c_id_new30, c_id_ref30;
  logic [0:0]            c_id_new1, c_id_ref1;

  rv_plic_target #(.N_SOURCE(NS), .MAX_PRIO(MP), .ALGORITHM("TREE"))   i_c_new255 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip), .ie(c_ie), .prio(c_prio), .threshold(c_thr), .irq(c_irq_new255), .irq_id(c_id_new255));
  rv_plic_target #(.N_SOURCE(NS), .MAX_PRIO(MP), .ALGORITHM("MATRIX")) i_c_ref255 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip), .ie(c_ie), .prio(c_prio), .threshold(c_thr), .irq(c_irq_ref255), .irq_id(c_id_ref255));
  rv_plic_target #(.N_SOURCE(30), .MAX_PRIO(MP), .ALGORITHM("TREE"))   i_c_new30 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip[29:0]), .ie(c_ie[29:0]), .prio(c_prio[29:0]), .threshold(c_thr), .irq(c_irq_new30), .irq_id(c_id_new30));
  rv_plic_target #(.N_SOURCE(30), .MAX_PRIO(MP), .ALGORITHM("MATRIX")) i_c_ref30 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip[29:0]), .ie(c_ie[29:0]), .prio(c_prio[29:0]), .threshold(c_thr), .irq(c_irq_ref30), .irq_id(c_id_ref30));
  rv_plic_target #(.N_SOURCE(1), .MAX_PRIO(MP), .ALGORITHM("TREE"))    i_c_new1 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip[0]), .ie(c_ie[0]), .prio(c_prio[0]), .threshold(c_thr), .irq(c_irq_new1), .irq_id(c_id_new1));
  rv_plic_target #(.N_SOURCE(1), .MAX_PRIO(MP), .ALGORITHM("MATRIX"))  i_c_ref1 (.clk_i(clk), .rst_ni(rst_n),
    .ip(c_ip[0]), .ie(c_ie[0]), .prio(c_prio[0]), .threshold(c_thr), .irq(c_irq_ref1), .irq_id(c_id_ref1));

  // ---------------- stimulus ----------------
  task automatic stim_c(input int unsigned cyc);
    int unsigned k;
    case (cyc % 997)
      1: begin   // every source pending and enabled at one priority: the lowest index must win
        c_ip = '1; c_ie = '1; c_thr = $urandom_range(0, 6);
        for (int i = 0; i < NS; i++) c_prio[i] = c_thr + 1;
      end
      2: begin   // threshold at the maximum: nothing may pass
        c_ip = '1; c_ie = '1; c_thr = MP;
        for (int i = 0; i < NS; i++) c_prio[i] = $urandom_range(0, MP);
      end
      3: begin   // a single source
        k = $urandom_range(0, NS - 1);
        c_ip = '0; c_ie = '0; c_ip[k] = 1'b1; c_ie[k] = 1'b1; c_thr = 0;
        for (int i = 0; i < NS; i++) c_prio[i] = $urandom_range(0, MP);
        c_prio[k] = $urandom_range(1, MP);
      end
      4: begin   // everything pending, only the last sources enabled
        c_ip = '1; c_ie = '0; c_ie[NS-1] = 1'b1; c_ie[29] = 1'b1; c_ie[0] = 1'b1; c_thr = 0;
        for (int i = 0; i < NS; i++) c_prio[i] = $urandom_range(0, MP);
      end
      default: begin
        if (cyc % 3 == 0) begin
          for (int i = 0; i < NS; i++) c_prio[i] = $urandom_range(0, MP);
        end
        if ($urandom_range(0, 3) == 0) begin   // dense
          c_ip = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
          c_ie = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
        end else begin                           // sparse
          c_ip = '0; c_ie = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
          for (int n = 0; n < 4; n++) c_ip[$urandom_range(0, NS - 1)] = 1'b1;
        end
        c_thr = $urandom_range(0, MP);
      end
    endcase
  endtask

  task automatic stim_b();
    req_b = rand_req(NT16);
    for (int i = 0; i <= NS; i++) b_prio_i[i] = $urandom_range(0, MP);
    b_ip_i[0] = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
    for (int t = 0; t < NT16; t++) begin
      b_ie_i[t] = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
      b_thr_i[t] = $urandom_range(0, MP);
      b_cc_i[t]  = $urandom_range(0, NS);
    end
  endtask

  task automatic stim_a();
    req_a = rand_req(NT);
    if ($urandom_range(0, 1)) begin
      for (int n = 0; n < 3; n++) src_a[$urandom_range(0, NS - 1)] = ~src_a[$urandom_range(0, NS - 1)];
    end
    if ($urandom_range(0, 99) == 0) src_a = {$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom(), $urandom()};
    if ($urandom_range(0, 199) == 0) src_a = '0;
  endtask

  // ---------------- checks ----------------
  task automatic check_a(input int unsigned cyc);
    if (resp_a_new !== resp_a_ref || eip_a_new !== eip_a_ref) begin
      errors_a++;
      if (errors_a <= 10)
        $display("A mismatch @%0d: req valid=%0b write=%0b addr=%h wdata=%h | new rdata=%h err=%0b eip=%h | ref rdata=%h err=%0b eip=%h",
                 cyc, req_a.valid, req_a.write, req_a.addr, req_a.wdata, resp_a_new.rdata, resp_a_new.error, eip_a_new,
                 resp_a_ref.rdata, resp_a_ref.error, eip_a_ref);
    end
  endtask

  task automatic check_b(input int unsigned cyc);
    if (resp_b_new !== resp_b_ref || b_prio_o_new !== b_prio_o_ref || b_prio_we_new !== b_prio_we_ref ||
        b_prio_re_new !== b_prio_re_ref || b_ip_re_new !== b_ip_re_ref || b_ie_o_new !== b_ie_o_ref ||
        b_ie_we_new !== b_ie_we_ref || b_ie_re_new !== b_ie_re_ref || b_thr_o_new !== b_thr_o_ref ||
        b_thr_we_new !== b_thr_we_ref || b_thr_re_new !== b_thr_re_ref || b_cc_o_new !== b_cc_o_ref ||
        b_cc_we_new !== b_cc_we_ref || b_cc_re_new !== b_cc_re_ref) begin
      errors_b++;
      if (errors_b <= 10)
        $display("B mismatch @%0d: req valid=%0b write=%0b addr=%h wdata=%h | new rdata=%h err=%0b | ref rdata=%h err=%0b",
                 cyc, req_b.valid, req_b.write, req_b.addr, req_b.wdata, resp_b_new.rdata, resp_b_new.error,
                 resp_b_ref.rdata, resp_b_ref.error);
    end
  endtask

  task automatic check_c(input int unsigned cyc);
    if (c_irq_new255 !== c_irq_ref255 || c_id_new255 !== c_id_ref255 || c_irq_new30 !== c_irq_ref30 ||
        c_id_new30 !== c_id_ref30 || c_irq_new1 !== c_irq_ref1 || c_id_new1 !== c_id_ref1) begin
      errors_c++;
      if (errors_c <= 10)
        $display("C mismatch @%0d: 255: new %0b/%0d ref %0b/%0d | 30: new %0b/%0d ref %0b/%0d | 1: new %0b/%0d ref %0b/%0d (thr %0d)",
                 cyc, c_irq_new255, c_id_new255, c_irq_ref255, c_id_ref255, c_irq_new30, c_id_new30, c_irq_ref30, c_id_ref30,
                 c_irq_new1, c_id_new1, c_irq_ref1, c_id_ref1, c_thr);
    end
  endtask

  initial begin
    req_a = '0; req_b = '0; src_a = '0; c_ip = '0; c_ie = '0; c_prio = '0; c_thr = '0;
    b_prio_i = '0; b_ip_i = '0; b_ie_i = '0; b_thr_i = '0; b_cc_i = '0;
    repeat (5) @(posedge clk);
    #1 rst_n = 1'b1;
    for (int unsigned cyc = 0; cyc < CYCLES; cyc++) begin
      @(posedge clk); #1;
      stim_a(); stim_b(); stim_c(cyc);
      @(negedge clk);
      check_a(cyc); check_b(cyc); check_c(cyc);
      if (cyc % 5000 == 4999)
        $display("[%0d cycles] mismatches so far: A %0d, B %0d, C %0d", cyc + 1, errors_a, errors_b, errors_c);
    end
    errors = errors_a + errors_b + errors_c;
    if (errors == 0) $display("PLIC EQUIV PASS (%0d cycles: whole PLIC 255x8, register map 255x16, finder 255/30/1)", CYCLES);
    else             $display("PLIC EQUIV FAIL %0d mismatches (A %0d, B %0d, C %0d)", errors, errors_a, errors_b, errors_c);
    $finish;
  end
endmodule
