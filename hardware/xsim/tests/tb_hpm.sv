`timescale 1ns/1ps

module tb_hpm;
  import ariane_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0, debug_mode = 0, we = 0;
  logic [31:0] inhibit = '1;
  logic [11:0] addr = 0;
  riscv::xlen_t wdata = 0, rdata;
  scoreboard_entry_t [NR_COMMIT_PORTS-1:0] instr;
  logic [NR_COMMIT_PORTS-1:0] ack;
  logic ic_miss, dc_miss, itlb_miss, dtlb_miss, sb_full, if_empty;
  exception_t exception, branch_exception;
  logic eret, tlb_flush, stall;
  bp_resolve_t branch;
  icache_dreq_i_t ic_access;
  dcache_req_i_t [2:0] dc_access;
  logic [2:0][DCACHE_SET_ASSOC-1:0] miss_bits;
  int checks = 0;
  int irq_requests = 0;
  logic overflow_irq;
  logic [31:0] overflow;
  riscv::priv_lvl_t mode = riscv::PRIV_LVL_M;
  logic virtual_mode = 0;

  always @(posedge clk) if (rst_n && overflow_irq) irq_requests++;

  perf_counters dut (
    .clk_i(clk), .rst_ni(rst_n), .debug_mode_i(debug_mode),
    .mcountinhibit_i(inhibit), .addr_i(addr), .we_i(we),
    .priv_lvl_i(mode), .v_i(virtual_mode), .overflow_o(overflow), .overflow_irq_o(overflow_irq),
    .data_i(wdata), .data_o(rdata), .commit_instr_i(instr), .commit_ack_i(ack),
    .l1_icache_miss_i(ic_miss), .l1_dcache_miss_i(dc_miss),
    .itlb_miss_i(itlb_miss), .dtlb_miss_i(dtlb_miss),
    .sb_full_i(sb_full), .if_empty_i(if_empty), .ex_i(exception), .eret_i(eret),
    .resolved_branch_i(branch), .branch_exceptions_i(branch_exception),
    .l1_icache_access_i(ic_access), .l1_dcache_access_i(dc_access),
    .miss_vld_bits_i(miss_bits), .i_tlb_flush_i(tlb_flush), .stall_issue_i(stall),
    .perfc_evu_req('0), .pcmiles_evu_req('0), .perfc_evu_resp(), .pcmiles_evu_resp()
  );

  task automatic step;
    @(posedge clk); #1;
    @(negedge clk); #1;
  endtask

  task automatic write_csr(input logic [11:0] csr, input riscv::xlen_t value);
    addr = csr; wdata = value; we = 1;
    step();
    we = 0;
  endtask

  task automatic check_csr(input logic [11:0] csr, input riscv::xlen_t expected);
    addr = csr; #1;
    checks++;
    if (rdata !== expected)
      $fatal(1, "CSR %h: got %h expected %h (check %0d)", csr, rdata, expected, checks);
  endtask

  task automatic clear_events;
    instr = '0; ack = '0;
    ic_miss = 0; dc_miss = 0; itlb_miss = 0; dtlb_miss = 0;
    sb_full = 0; if_empty = 0; exception = '0; eret = 0;
    branch = '0; branch_exception = '0; ic_access = '0; dc_access = '0;
    miss_bits = '0; tlb_flush = 0; stall = 0;
  endtask

  task automatic set_mode(input int index);
    virtual_mode = index >= 3;
    case (index)
      0: mode = riscv::PRIV_LVL_M;
      1, 3: mode = riscv::PRIV_LVL_S;
      2, 4: mode = riscv::PRIV_LVL_U;
      default: $fatal(1, "Invalid mode index");
    endcase
  endtask

  task automatic check_overflow(input logic [31:0] status, input int requests);
    #1; checks++;
    if (overflow !== status || irq_requests != requests)
      $fatal(1, "Overflow status %h expected %h; IRQ requests %0d expected %0d",
             overflow, status, irq_requests, requests);
  endtask

  initial begin
    int expected;
    int requests;
    clear_events();
    repeat (2) step();
    rst_n = 1;

    // All six writable 64-bit counters and their architectural read-only aliases.
    for (int i = 3; i <= 8; i++) begin
      write_csr(12'hb00 + i, 64'h1234_5678_9000_0000 + i);
      check_csr(12'hb00 + i, 64'h1234_5678_9000_0000 + i);
      check_csr(12'hc00 + i, 64'h1234_5678_9000_0000 + i);
    end
    for (int i = 9; i <= 31; i++) begin
      check_csr(12'hb00 + i, 0);
      check_csr(12'hc00 + i, 0);
    end

    // Each selector gets one active clock. Retire events exercise two lanes.
    for (int event_id = 0; event_id < 32; event_id++) begin
      inhibit = '1;
      clear_events();
      write_csr(12'h323, event_id);
      write_csr(12'hb03, 0);
      expected = event_id > 0 && event_id <= 24 ? 1 : 0;
      case (event_id)
        1: ic_miss = 1;
        2: dc_miss = 1;
        3: itlb_miss = 1;
        4: dtlb_miss = 1;
        5, 6, 9, 12, 13, 20, 21, 24: begin
          ack = '1;
          for (int lane = 0; lane < NR_COMMIT_PORTS; lane++) begin
            instr[lane].fu = ALU;
            instr[lane].op = ADD;
            case (event_id)
              5: instr[lane].fu = LOAD;
              6: instr[lane].fu = STORE;
              9, 12, 13: instr[lane].fu = CTRL_FLOW;
              21: instr[lane].fu = FPU;
              default: ;
            endcase
            if (event_id == 12) instr[lane].rd = 1;
            if (event_id == 13) instr[lane].op = JALR;
          end
          expected = NR_COMMIT_PORTS;
        end
        7: exception.valid = 1;
        8: eret = 1;
        10: begin branch.valid = 1; branch.is_mispredict = 1; end
        11: branch_exception.valid = 1;
        14: sb_full = 1;
        15: if_empty = 1;
        16: ic_access.req = 1;
        17: dc_access[0].data_req = 1;
        18: begin dc_miss = 1; miss_bits[0] = '1; end
        19: tlb_flush = 1;
        22: stall = 1;
        default: ;
      endcase
      inhibit[3] = 0;
      step();
      inhibit[3] = 1;
      check_csr(12'hb03, expected);
    end

    // Every inhibit bit is independent; debug mode stops all six counters.
    clear_events();
    for (int i = 3; i <= 8; i++) begin
      write_csr(12'h320 + i, 23);
      write_csr(12'hb00 + i, 0);
    end
    for (int selected = 3; selected <= 8; selected++) begin
      inhibit = '1;
      inhibit[selected] = 0;
      step();
      inhibit = '1;
    end
    for (int i = 3; i <= 8; i++) check_csr(12'hb00 + i, 1);
    debug_mode = 1;
    inhibit = 0;
    step();
    inhibit = '1;
    for (int i = 3; i <= 8; i++) check_csr(12'hb00 + i, 1);
    debug_mode = 0;

    // A write to one selector/counter must not discard events in other counters.
    inhibit = 0;
    write_csr(12'h323, 23);
    inhibit = '1;
    for (int i = 3; i <= 8; i++) check_csr(12'hb00 + i, 2);
    inhibit = 0;
    write_csr(12'hb03, 100);
    inhibit = '1;
    check_csr(12'hb03, 100);
    for (int i = 4; i <= 8; i++) check_csr(12'hb00 + i, 3);

    // Full-width modulo wrap, including a two-retire increment across bit 63.
    write_csr(12'h323, 24);
    write_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    ack = '1;
    inhibit[3] = 0;
    step();
    inhibit[3] = 1;
    check_csr(12'hb03, riscv::xlen_t'(NR_COMMIT_PORTS - 2));

    // WARL: only OF, five privilege filters, and five selector bits stick.
    requests = irq_requests;
    write_csr(12'h323, '1);
    check_csr(12'h323, 64'hfc00_0000_0000_001f);
    check_overflow(32'h8, requests);
    write_csr(12'h323, 0);

    // Every filter acts only in its own execution mode, for cycles and retirements.
    for (int event_id = 23; event_id <= 24; event_id++) begin
      for (int filter = 0; filter < 5; filter++) begin
        for (int current = 0; current < 5; current++) begin
          inhibit = '1;
          set_mode(current);
          write_csr(12'h323, (64'h1 << (62-filter)) | 64'(event_id));
          write_csr(12'hb03, 0);
          inhibit[3] = 0;
          step();
          inhibit[3] = 1;
          expected = current == filter ? 0 : (event_id == 24 ? NR_COMMIT_PORTS : 1);
          check_csr(12'hb03, expected);
        end
      end
    end
    for (int current = 0; current < 5; current++) begin
      set_mode(current);
      write_csr(12'h323, 64'h7c00_0000_0000_0017);
      write_csr(12'hb03, 0);
      inhibit[3] = 0; step(); inhibit[3] = 1;
      check_csr(12'hb03, 0);
    end
    set_mode(0);

    // A write does not overflow. OF=1 suppresses requests, not counting.
    write_csr(12'h323, 24);
    write_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    check_overflow(0, requests);
    inhibit[3] = 0; step(); inhibit[3] = 1;
    requests++;
    check_csr(12'hb03, 0);
    check_csr(12'h323, 64'h8000_0000_0000_0018);
    check_overflow(8, requests);
    write_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    inhibit[3] = 0; step(); inhibit[3] = 1;
    check_csr(12'hb03, 0);
    check_overflow(8, requests);

    // Simultaneous wraps aggregate into one request with both status bits.
    write_csr(12'h323, 24); write_csr(12'h324, 24);
    write_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    write_csr(12'hb04, 64'hffff_ffff_ffff_fffe);
    inhibit[3] = 0; inhibit[4] = 0; step(); inhibit = '1;
    requests++;
    check_overflow(32'h18, requests);
    check_csr(12'hb03, 0); check_csr(12'hb04, 0);

    // Inhibit and debug stop overflow as well as counting.
    write_csr(12'h323, 24); write_csr(12'h324, 0);
    write_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    step();
    check_overflow(0, requests);
    debug_mode = 1; inhibit[3] = 0; step(); inhibit[3] = 1; debug_mode = 0;
    check_csr(12'hb03, 64'hffff_ffff_ffff_fffe);
    check_overflow(0, requests);

    // A counter write wins while a different counter can still overflow.
    write_csr(12'h323, 23); write_csr(12'h324, 23);
    write_csr(12'hb03, '1); write_csr(12'hb04, '1);
    inhibit[3] = 0; inhibit[4] = 0;
    write_csr(12'hb03, 100);
    inhibit = '1;
    requests++;
    check_csr(12'hb03, 100);
    check_overflow(32'h10, requests);

    // Selector-write priority controls OF/request while old-selector counting continues.
    write_csr(12'h324, 0); write_csr(12'h323, 23);
    write_csr(12'hb03, '1);
    inhibit[3] = 0;
    write_csr(12'h323, 64'h8000_0000_0000_0017);
    inhibit = '1;
    check_csr(12'hb03, 0);
    check_overflow(8, requests);
    $display("HPM UNIT PASS %0d checks", checks);
    $finish;
  end
endmodule
