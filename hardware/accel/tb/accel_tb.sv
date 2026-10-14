// Generic unit testbench for one accelerator (no SoC, compiles and runs in seconds).
//
//   xvlog -sv -d ACCEL_DUT=<module> -i <dir holding accel_test.svh> <accelerator sources> accel_tb.sv
//
// The test body is `accel_test.svh` from the accelerator's directory; it runs inside an initial block after reset
// and may use these helpers (addresses are byte offsets inside the accelerator's 64 KB window):
//
//   wr(off, data)                 register write (32-bit)
//   rd(off, data)                 register read  -> data
//   rd_check(off, exp, "what")    register read compared with exp
//   mem_write(addr, data64)       backdoor write of the 64-bit word holding addr (DRAM model, sparse)
//   mem_read(addr) -> data64      backdoor read (unwritten words read as 0)
//   mem_fill(addr, n, seed)       n words of pseudo-random data from addr (deterministic for a seed)
//   check(cond, "what")           count a check; a failing one is printed with the cycle number
//   wait_irq(max_cycles)          wait for irq_o (fails the check on timeout)
//   wait_reg(off, mask, val, max_cycles)  poll until (reg & mask) == val (fails on timeout)
//   cycles(n)                     wait n clock cycles
//   mem_stall(pct)                % of cycles the memory model withholds gnt / delays rvalid (default 30)
//   max_cycles = N;               global timeout (default 200000 cycles); reg_timeout = N; ack timeout (4096)
//
// Every check(), rd_check(), wait_reg() and wait_irq() call counts as one check; port-protocol checks only count
// when they fail. $display output of the test is returned by accel_unit_test.
// Declarations that cannot live inside an initial block (functions, tasks for a reference model, ...) go into
// accel_test_decls.svh next to accel_test.svh: it is included at module scope, before the test body.
//
// The memory model checks the port contract: request fields stable until gnt, 8-byte aligned addresses,
// strobes non-zero on writes, no rvalid without an outstanding request. Reads and writes are logged to
// accel_mem.log. Elaborated with -O0: in this testbench, xsim 2024.2 at -O1/-O2 evaluated calls of automatic
// functions inside for-loop bodies of the initial block as if the loop variable were invariant. (Seen only in
// testbench code; not observed in synthesizable RTL, which the SoC elaborates with default optimisation.) The bench ends with one line `ACCEL-UNIT PASS <n> checks` or `ACCEL-UNIT FAIL <k>/<n> ...`.

`timescale 1ns/1ps

module accel_tb;
  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // register port
  logic        reg_req = 1'b0, reg_we = 1'b0, reg_ack;
  logic [15:0] reg_addr = '0;
  logic [31:0] reg_wdata = '0, reg_rdata;
  logic [3:0]  reg_wstrb = '0;
  // memory port
  logic        mem_req, mem_gnt, mem_we, mem_rvalid, mem_err;
  logic [63:0] mem_addr, mem_wdata, mem_rdata;
  logic [7:0]  mem_strb;
  logic        irq;

  `ACCEL_DUT dut (
    .clk_i        ( clk        ),
    .rst_ni       ( rst_n      ),
    .reg_req_i    ( reg_req    ),
    .reg_we_i     ( reg_we     ),
    .reg_addr_i   ( reg_addr   ),
    .reg_wdata_i  ( reg_wdata  ),
    .reg_wstrb_i  ( reg_wstrb  ),
    .reg_ack_o    ( reg_ack    ),
    .reg_rdata_o  ( reg_rdata  ),
    .mem_req_o    ( mem_req    ),
    .mem_gnt_i    ( mem_gnt    ),
    .mem_we_o     ( mem_we     ),
    .mem_addr_o   ( mem_addr   ),
    .mem_wdata_o  ( mem_wdata  ),
    .mem_strb_o   ( mem_strb   ),
    .mem_rvalid_i ( mem_rvalid ),
    .mem_rdata_i  ( mem_rdata  ),
    .mem_err_i    ( mem_err    ),
    .irq_o        ( irq        )
  );

  int unsigned cyc = 0;
  always @(posedge clk) cyc++;

  // ------------------------------------------------------------------ checks
  int n_checks = 0, n_fail = 0;
  task automatic check(input bit cond, input string what);
    n_checks++;
    if (!cond) begin
      n_fail++;
      if (n_fail <= 20) $display("[ACCEL-UNIT] FAIL cycle %0d: %s", cyc, what);
    end
  endtask

  // port-protocol checks: only failures are counted
  task automatic proto(input bit cond, input string what);
    if (!cond) begin
      n_checks++; n_fail++;
      if (n_fail <= 20) $display("[ACCEL-UNIT] FAIL cycle %0d: protocol: %s", cyc, what);
    end
  endtask

  task automatic cycles(int n); repeat (n) @(posedge clk); endtask

  // ------------------------------------------------------------------ register driver (strobe / ack)
  // acks are sampled at every rising edge; an ack while no access is outstanding is a protocol error
  int unsigned reg_timeout = 4096;
  int unsigned acks = 0;
  bit          outstanding = 0;
  logic [31:0] ack_data;
  always @(posedge clk) if (rst_n && reg_ack === 1'b1) begin
    proto(outstanding, $sformatf("reg_ack_o without an outstanding access (addr 0x%0h)", reg_addr));
    acks++; ack_data = reg_rdata; outstanding = 0;
  end

  task automatic reg_access(input bit we, input logic [15:0] off, input logic [31:0] wd, output logic [31:0] rdat);
    int unsigned a0 = acks, n = 0;
    @(negedge clk);
    reg_req = 1'b1; reg_we = we; reg_addr = off; reg_wdata = wd; reg_wstrb = we ? 4'hf : 4'h0; outstanding = 1;
    @(negedge clk);
    reg_req = 1'b0; reg_we = 1'b0; reg_wdata = '0; reg_wstrb = '0;
    while (acks == a0 && n < reg_timeout) begin @(negedge clk); n++; end
    rdat = ack_data;
    check(acks != a0, $sformatf("register %s at 0x%0h not acknowledged within %0d cycles",
                                we ? "write" : "read", off, reg_timeout));
    outstanding = 0;
  endtask

  task automatic wr(input logic [15:0] off, input logic [31:0] data);
    logic [31:0] dummy;
    reg_access(1'b1, off, data, dummy);
  endtask
  task automatic rd(input logic [15:0] off, output logic [31:0] data);
    reg_access(1'b0, off, '0, data);
  endtask
  task automatic rd_check(input logic [15:0] off, input logic [31:0] exp, input string what);
    logic [31:0] v;
    rd(off, v);
    check(v === exp, $sformatf("%s: reg 0x%0h = 0x%08h, expected 0x%08h", what, off, v, exp));
  endtask

  task automatic wait_irq(input int unsigned max_cycles);
    int unsigned n = 0;
    while (!irq && n < max_cycles) begin @(posedge clk); n++; end
    check(irq === 1'b1, $sformatf("irq_o not raised within %0d cycles", max_cycles));
  endtask

  task automatic wait_reg(input logic [15:0] off, input logic [31:0] mask, input logic [31:0] val,
                          input int unsigned max_cycles);
    logic [31:0] v;
    int unsigned start = cyc;
    do begin rd(off, v); end while (((v & mask) !== val) && (cyc - start) < max_cycles);
    check((v & mask) === val, $sformatf("reg 0x%0h & 0x%0h = 0x%0h, expected 0x%0h within %0d cycles",
                                        off, mask, v & mask, val, max_cycles));
  endtask

  // ------------------------------------------------------------------ memory model
  logic [63:0] mem [logic [63:0]];
  int unsigned stall_pct = 30;
  int          mlog;
  int unsigned n_rd = 0, n_wr = 0;

  function automatic void mem_write(logic [63:0] addr, logic [63:0] data); mem[addr >> 3] = data; endfunction
  function automatic logic [63:0] mem_read(logic [63:0] addr);
    return mem.exists(addr >> 3) ? mem[addr >> 3] : 64'h0;
  endfunction
  function automatic void mem_fill(logic [63:0] addr, int unsigned n, int unsigned seed);
    int unsigned s = seed;
    for (int unsigned i = 0; i < n; i++) begin
      logic [63:0] v;
      v[31:0]  = $urandom(s + 2 * i);
      v[63:32] = $urandom(s + 2 * i + 1);
      mem[(addr >> 3) + i] = v;
    end
  endfunction
  function automatic void mem_stall(int unsigned pct); stall_pct = pct; endfunction

  // gnt: random stalls; responses: queued, returned in order after a random delay
  typedef struct { logic [63:0] rdata; int unsigned due; } rsp_t;
  rsp_t rsp_q [$];
  logic        pend = 1'b0;
  logic [63:0] p_addr, p_wdata;
  logic [7:0]  p_strb;
  logic        p_we;

  always @(negedge clk) begin
    mem_gnt <= rst_n && mem_req && ($urandom_range(99) >= stall_pct);
  end

  always @(posedge clk) begin
    mem_rvalid <= 1'b0;
    mem_err    <= 1'b0;
    if (rst_n) begin
      if (mem_req) begin
        if (pend) begin
          proto(mem_addr === p_addr && mem_we === p_we && (!p_we || (mem_wdata === p_wdata && mem_strb === p_strb)),
                $sformatf("mem request changed before gnt (addr 0x%0h -> 0x%0h)", p_addr, mem_addr));
        end
        pend = !mem_gnt; p_addr = mem_addr; p_we = mem_we; p_wdata = mem_wdata; p_strb = mem_strb;
      end else begin
        proto(!pend, $sformatf("mem_req dropped before gnt (addr 0x%0h)", p_addr));
        pend = 1'b0;
      end
      if (mem_req && mem_gnt) begin
        rsp_t r;
        proto(mem_addr[2:0] == 3'b0, $sformatf("unaligned mem address 0x%0h", mem_addr));
        proto(!mem_we || mem_strb != '0, $sformatf("mem write with zero strobes at 0x%0h", mem_addr));
        if (mem_we) begin
          logic [63:0] o = mem_read(mem_addr);
          for (int b = 0; b < 8; b++) if (mem_strb[b]) o[8*b +: 8] = mem_wdata[8*b +: 8];
          mem[mem_addr >> 3] = o;
          n_wr++;
          $fdisplay(mlog, "%0t W %h %h strb %b", $time, mem_addr, mem_wdata, mem_strb);
        end else begin
          n_rd++;
          $fdisplay(mlog, "%0t R %h -> %h", $time, mem_addr, mem_read(mem_addr));
        end
        r.rdata = mem_we ? 64'h0 : mem_read(mem_addr);
        r.due   = cyc + 1 + (($urandom_range(99) < stall_pct) ? $urandom_range(6) : 0);
        if (rsp_q.size() > 0 && r.due < rsp_q[$].due) r.due = rsp_q[$].due;
        rsp_q.push_back(r);
      end
      if (rsp_q.size() > 0 && cyc >= rsp_q[0].due) begin
        rsp_t r = rsp_q.pop_front();
        mem_rvalid <= 1'b1;
        mem_rdata  <= r.rdata;
      end
    end
  end

  // ------------------------------------------------------------------ test
  int unsigned max_cycles = 200000;
  `include "accel_test_decls.svh"
  initial begin
    mlog = $fopen("accel_mem.log", "w");
    mem_rvalid = 1'b0; mem_err = 1'b0; mem_rdata = '0; mem_gnt = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    begin : test_body
      `include "accel_test.svh"
    end
    cycles(5);
    proto(!pend, "test ended with a memory request waiting for gnt");
    if (n_fail == 0) $display("ACCEL-UNIT PASS %0d checks, %0d cycles, mem reads %0d writes %0d",
                              n_checks, cyc, n_rd, n_wr);
    else $display("ACCEL-UNIT FAIL %0d/%0d checks failed, %0d cycles", n_fail, n_checks, cyc);
    $fclose(mlog);
    $finish;
  end

  initial begin
    #1;
    wait (cyc >= max_cycles);
    $display("[ACCEL-UNIT] FAIL t=%0t: global timeout after %0d cycles (raise max_cycles in the test)", $time, max_cycles);
    $display("ACCEL-UNIT FAIL timeout, %0d/%0d checks failed so far", n_fail, n_checks);
    $finish;
  end
endmodule
