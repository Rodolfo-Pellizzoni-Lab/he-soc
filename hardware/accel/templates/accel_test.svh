// Unit test of __NAME__ (body of an initial block in hardware/accel/tb/accel_tb.sv; helpers listed there).
// Runs in seconds: accel_unit_test(name='__NAME__').
logic [31:0] v;
localparam logic [63:0] SRC = 64'h8000_1000, DST = 64'h8000_2000;
localparam int N = 16;

rd_check(16'h20, 32'h__ID__, "ID register");
mem_fill(SRC, N, 1);
wr(16'h08, SRC[31:0]); wr(16'h0C, SRC[63:32]);
wr(16'h10, DST[31:0]); wr(16'h14, DST[63:32]);
wr(16'h18, N);
wr(16'h1C, 32'd5);
wr(16'h00, 32'h3);                       // START + IRQ_EN
wait_irq(20000);
rd_check(16'h04, 32'h2, "STATUS = DONE");
for (int i = 0; i < N; i++)
  check(mem_read(DST + 8 * i) == mem_read(SRC + 8 * i) + 5,
        $sformatf("dst[%0d] = %h, expected %h", i, mem_read(DST + 8 * i), mem_read(SRC + 8 * i) + 5));
wr(16'h04, 32'h2);                       // clear DONE
cycles(2);
check(irq == 1'b0, "irq cleared with DONE");

// QoS tag: the user field presented with the START write is latched (TAG register) and put on every DMA request
set_user(16'h1A8);                       // port 0, RCID 5, MCID 3 (SoC user layout)
wr(16'h00, 32'h1);                       // START again (same src/dst/len)
wait_reg(16'h04, 32'h3, 32'h2, 20000);
rd_check(16'h28, 32'h1A8, "TAG = the user field of the hart that wrote START");
check(last_mem_user == 16'h1A8, $sformatf("DMA requests carry the requester's tag (last mem_user 0x%0h)", last_mem_user));
wr(16'h04, 32'h2);
set_user(16'h0C9);                       // port 1, RCID 9, MCID 1: a different requester
wr(16'h00, 32'h1);
wait_reg(16'h04, 32'h3, 32'h2, 20000);
rd_check(16'h28, 32'h0C9, "TAG follows the new requester");
check(last_mem_user == 16'h0C9, $sformatf("DMA re-tagged with the new requester (last mem_user 0x%0h)", last_mem_user));
wr(16'h04, 32'h2);
set_user(16'h0);

// Job queue (Design 1, per-job tags): three descriptors submitted by three requesters; each job's DMA requests
// (descriptor reads, data, completion write) all carry the tag of the SUBMIT write that queued it
rd(16'h44, v);
if (v[15:8] >= 2) begin : job_queue
  localparam logic [63:0] DESC = 64'h8000_4000, QS = 64'h8000_5000, QD = 64'h8000_6000;
  logic [15:0] u [3];
  int unsigned qlen [3];
  logic [63:0] c;
  bit tags_ok;
  u[0] = 16'h1A8; u[1] = 16'h0C9; u[2] = 16'h2D3;
  qlen[0] = 12; qlen[1] = 3; qlen[2] = 5;
  for (int j = 0; j < 3; j++) begin
    mem_fill(QS + 256 * j, qlen[j], 10 + j);
    mem_write(DESC + 32 * j,      QS + 256 * j);
    mem_write(DESC + 32 * j + 8,  QD + 256 * j);
    mem_write(DESC + 32 * j + 16, {32'(j + 1), 32'(qlen[j])});   // ARG, LEN
    mem_write(DESC + 32 * j + 24, 64'h0);                         // completion
  end
  for (int j = 0; j < 3; j++) begin
    set_user(u[j]);
    wr(16'h40, 32'((DESC + 32 * j) >> 3));                         // SUBMIT
  end
  set_user(16'h0);
  for (int t = 0; t < 20000; t++) begin c = mem_read(DESC + 64 + 24); if (c[0]) break; cycles(1); end
  for (int j = 0; j < 3; j++) begin
    c = mem_read(DESC + 32 * j + 24);
    check(c[0] == 1'b1 && c[1] == 1'b0 && c[31:16] == u[j],
          $sformatf("job %0d completion %h (DONE, no ERR, tag %h)", j, c, u[j]));
    tags_ok = 1'b1;
    for (int i = 0; i < 4; i++) if (mem_user_of(DESC + 32 * j + 8 * i) != u[j]) tags_ok = 1'b0;
    for (int i = 0; i < qlen[j]; i++) begin
      if (mem_read(QD + 256 * j + 8 * i) != mem_read(QS + 256 * j + 8 * i) + j + 1) tags_ok = 1'b0;
      if (mem_user_of(QS + 256 * j + 8 * i) != u[j] || mem_user_of(QD + 256 * j + 8 * i) != u[j]) tags_ok = 1'b0;
    end
    check(tags_ok, $sformatf("job %0d: data, and every DMA request tagged %h", j, u[j]));
  end
  rd_check(16'h44, {16'h0, v[15:8], 8'h0}, "QSTAT: queue empty, no overflow");
  rd_check(16'h28, 32'(u[2]), "TAG = the last job's");
  wr(16'h04, 32'h2);
end
