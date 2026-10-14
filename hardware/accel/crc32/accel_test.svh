// Unit test of crc32 (body of an initial block in hardware/accel/tb/accel_tb.sv; helpers listed there).
// Runs in seconds: accel_unit_test(name='crc32').
logic [31:0] v, ref_crc;
logic [63:0] w;
logic [7:0]  b;
int unsigned lens[9] = '{0, 1, 7, 8, 9, 15, 16, 255, 1001};
logic [63:0] src;

max_cycles = 400000;
rd_check(16'h20, 32'hC3C32001, "ID register");

// check vector "123456789" -> 0xCBF43926 (with interrupt)
src = 64'h8000_0100;
mem_write(src,     64'h3837363534333231);
mem_write(src + 8, 64'hAAAAAAAAAAAAAA39);      // garbage past the end must be ignored
wr(16'h08, src[31:0]); wr(16'h0C, src[63:32]);
wr(16'h10, 32'd9);
wr(16'h00, 32'h3);                             // START + IRQ_EN
wait_irq(20000);
rd_check(16'h04, 32'h2, "STATUS = DONE after 123456789");
rd_check(16'h14, 32'hCBF43926, "CRC(\"123456789\") = 0xCBF43926");
wr(16'h04, 32'h2);                             // clear DONE
cycles(2);
check(irq == 1'b0, "irq cleared with DONE");
rd_check(16'h04, 32'h0, "STATUS idle after clear");

// random buffers of several lengths, reference CRC computed here (polling, IRQ disabled)
wr(16'h00, 32'h0);
for (int t = 0; t < 9; t++) begin
  src = 64'h8001_0000 + 64'(t) * 64'h1000 + 64'(8 * t);
  mem_fill(src, (lens[t] + 7) / 8 + 1, t + 11);  // one extra word of junk past the end
  ref_crc = 32'hFFFFFFFF;
  for (int i = 0; i < lens[t]; i++) begin
    w = mem_read(src + 64'(i));
    b = w[8 * (i % 8) +: 8];
    ref_crc = ref_crc ^ {24'h0, b};
    for (int k = 0; k < 8; k++)
      ref_crc = ref_crc[0] ? ((ref_crc >> 1) ^ 32'hEDB88320) : (ref_crc >> 1);
  end
  ref_crc = ~ref_crc;
  wr(16'h08, src[31:0]); wr(16'h0C, src[63:32]);
  wr(16'h10, lens[t]);
  wr(16'h00, 32'h1);                           // START
  wait_reg(16'h04, 32'h3, 32'h2, 50000);
  rd(16'h14, v);
  check(v == ref_crc, $sformatf("len %0d: CRC = %08h, expected %08h", lens[t], v, ref_crc));
  check(irq == 1'b0, $sformatf("len %0d: no irq with IRQ_EN = 0", lens[t]));
  rd(16'h24, v);
  $display("[crc32] len %4d  crc %08h  cycles %0d", lens[t], ref_crc, v);
  wr(16'h04, 32'h2);
end
