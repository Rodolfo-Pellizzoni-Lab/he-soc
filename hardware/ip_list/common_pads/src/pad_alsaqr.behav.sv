// Behavioural pad models without gate primitives (bufif0/rpmos) for open-source simulators.
// Same ports as ip_list/opentitan/hw/vendor/common_pads/src/pad_alsaqr.sv.
module pad_alsaqr_pd (input logic OEN, input logic I, output logic O, inout wire PAD,
  input wire [1:0] DRV, input wire SLW, input wire SMT, inout wire PWROK, inout wire IOPWROK, inout wire BIAS, inout wire RETC);
  assign PAD = OEN ? 1'bz : I;
  assign O   = PAD;
  pulldown (PAD);
endmodule
module pad_alsaqr_pu (input logic OEN, input logic I, output logic O, inout wire PAD,
  input wire [1:0] DRV, input wire SLW, input wire SMT, inout wire PWROK, inout wire IOPWROK, inout wire BIAS, inout wire RETC);
  assign PAD = OEN ? 1'bz : I;
  assign O   = PAD;
  pullup (PAD);
endmodule
module pad_alsaqr (input logic OEN, input logic I, output logic O, inout wire PAD, input wire PUEN,
  input wire DRV, input wire SLW, input wire SMT, inout wire PWROK, inout wire IOPWROK, inout wire BIAS, inout wire RETC);
  assign PAD = OEN ? 1'bz : I;
  assign O   = PAD;
  pullup (PAD);
endmodule
