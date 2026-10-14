// Unit test of example (body of an initial block in hardware/accel/tb/accel_tb.sv; helpers listed there).
// Runs in seconds: accel_unit_test(name='example').
logic [31:0] v;
localparam logic [63:0] SRC = 64'h8000_1000, DST = 64'h8000_2000;
localparam int N = 16;

rd_check(16'h20, 32'hAC0C9B9F, "ID register");
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
