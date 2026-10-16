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
