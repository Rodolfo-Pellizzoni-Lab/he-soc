// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

              
module pad_alsaqr_pd (
  inout wire       PAD,
  input logic      I,
  output logic     O,
  input logic      OEN,
  input wire [1:0] DRV,
  input wire       SLW,
  input wire       SMT,
  inout wire       PWROK,
  inout wire       IOPWROK,
  inout wire       BIAS,
  inout wire       RETC 
);

   IN22FDX_GPIO18_10M19S40PI_IO_H pad (
            .PAD(PAD),
            .DATA(I),
            .Y(O),
            .TRIEN(OEN),
            .RXEN(OEN),
            .PUEN(1'b0),
            .PDEN(1'b1),
            .NDIN(1'b0),
            .NDOUT(),
            .DRV(DRV),
            .SLW(SLW),
            .SMT(SMT),
            .PWROK(PWROK),
            .IOPWROK(IOPWROK),
            .BIAS(BIAS),
            .RETC(RETC)
          );

endmodule

module pad_alsaqr_pu (
  inout wire       PAD,
  input logic      I,
  output logic     O,
  input logic      OEN,
  input wire [1:0] DRV,
  input wire       SLW,
  input wire       SMT,
  inout wire       PWROK,
  inout wire       IOPWROK,
  inout wire       BIAS,
  inout wire       RETC 
);

   IN22FDX_GPIO18_10M19S40PI_IO_H pad (
            .PAD(PAD),
            .DATA(I),
            .Y(O),
            .TRIEN(OEN),
            .RXEN(OEN),
            .PUEN(1'b1),
            .PDEN(1'b0),
            .NDIN(1'b0),
            .NDOUT(),
            .DRV(DRV),
            .SLW(SLW),
            .SMT(SMT),
            .PWROK(PWROK),
            .IOPWROK(IOPWROK),
            .BIAS(BIAS),
            .RETC(RETC)
          );

endmodule

module pad_alsaqr (
  inout wire       PAD,
  input logic      I,
  output logic     O,
  input logic      OEN,
  input logic      PUEN,
  input wire [1:0] DRV,
  input wire       SLW,
  input wire       SMT,
  inout wire       PWROK,
  inout wire       IOPWROK,
  inout wire       BIAS,
  inout wire       RETC 
);

   IN22FDX_GPIO18_10M19S40PI_IO_H pad (
            .PAD(PAD),
            .DATA(I),
            .Y(O),
            .TRIEN(OEN),
            .RXEN(OEN),
            .PUEN(PUEN),
            .PDEN(~PUEN),
            .NDIN(1'b0),
            .NDOUT(),
            .DRV(DRV),
            .SLW(SLW),
            .SMT(SMT),
            .PWROK(PWROK),
            .IOPWROK(IOPWROK),
            .BIAS(BIAS),
            .RETC(RETC)
          );

endmodule
