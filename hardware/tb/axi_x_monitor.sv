// Simulation only: reports the first handshakes on an AXI request/response pair that carry X or Z (an address,
// ID or control field, a strobed write byte, read data, a valid itself). Used along the DMA path to the
// coherence unit and in front of the simulated DRAM to locate the origin of an X seen by a core.
module axi_x_monitor #(
  parameter type   req_t  = logic,
  parameter type   resp_t = logic,
  parameter string NAME   = "axi",
  parameter int    MaxReports = 10
) (
  input logic  clk_i,
  input req_t  req_i,
  input resp_t resp_i
);
  int n = 0;
  function automatic bit bad_w(input logic [$bits(req_i.w.data)-1:0] d, input logic [$bits(req_i.w.strb)-1:0] s);
    if ($isunknown(s)) return 1'b1;
    for (int i = 0; i < $bits(s); i++) if (s[i] && $isunknown(d[8*i +: 8])) return 1'b1;
    return 1'b0;
  endfunction
  always @(posedge clk_i) if (n < MaxReports) begin
    if ($isunknown({req_i.aw_valid, req_i.w_valid, req_i.ar_valid, resp_i.r_valid, resp_i.b_valid, req_i.b_ready, req_i.r_ready, resp_i.aw_ready, resp_i.w_ready, resp_i.ar_ready})) begin
      n++; $display("[XMON %s] t=%0t X on a valid/ready: aw %b w %b ar %b r %b b %b", NAME, $time, req_i.aw_valid, req_i.w_valid, req_i.ar_valid, resp_i.r_valid, resp_i.b_valid);
    end
    if (req_i.aw_valid === 1'b1 && $isunknown({req_i.aw.addr, req_i.aw.id, req_i.aw.len, req_i.aw.size, req_i.aw.burst})) begin
      n++; $display("[XMON %s] t=%0t AW with X: addr %h id %h len %h size %h burst %h", NAME, $time, req_i.aw.addr, req_i.aw.id, req_i.aw.len, req_i.aw.size, req_i.aw.burst);
    end
    if (req_i.w_valid === 1'b1 && bad_w(req_i.w.data, req_i.w.strb)) begin
      n++; $display("[XMON %s] t=%0t W with X: data %h strb %b last %b", NAME, $time, req_i.w.data, req_i.w.strb, req_i.w.last);
    end
    if (req_i.ar_valid === 1'b1 && $isunknown({req_i.ar.addr, req_i.ar.id, req_i.ar.len, req_i.ar.size, req_i.ar.burst})) begin
      n++; $display("[XMON %s] t=%0t AR with X: addr %h id %h len %h size %h burst %h", NAME, $time, req_i.ar.addr, req_i.ar.id, req_i.ar.len, req_i.ar.size, req_i.ar.burst);
    end
    if (resp_i.r_valid === 1'b1 && $isunknown({resp_i.r.data, resp_i.r.id, resp_i.r.resp, resp_i.r.last})) begin
      n++; $display("[XMON %s] t=%0t R with X: data %h id %h resp %h last %b", NAME, $time, resp_i.r.data, resp_i.r.id, resp_i.r.resp, resp_i.r.last);
    end
    if (resp_i.b_valid === 1'b1 && $isunknown({resp_i.b.id, resp_i.b.resp})) begin
      n++; $display("[XMON %s] t=%0t B with X: id %h resp %h", NAME, $time, resp_i.b.id, resp_i.b.resp);
    end
  end
endmodule
