// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.


module pad_functional_pd (
  input  logic OEN,
  input  logic I,
  output logic O,
  input  logic PEN,
  inout  wire  PAD
);

          IN22FDX_GPIO18_10M19S40PI_IO_H pad (
            .PAD(PAD),
            .DATA(I),
            .Y(O),
            .TRIEN(OEN),
            .RXEN(OEN),
            .PUEN(1'b0),
            .PDEN(1'b0),
            .NDIN(1'b0),
            .NDOUT(),
            .DRV(2'b11),
            .SLW(1'b0),
            .SMT(1'b0),
            .PWROK(),
            .IOPWROK(),
            .BIAS(),
            .RETC()
          );
   
endmodule

module pad_functional_pu (
  input  logic OEN,
  input  logic I,
  output logic O,
  input  logic PEN,
  inout  wire  PAD
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
            .DRV(2'b11),
            .SLW(),
            .SMT(),
            .PWROK(),
            .IOPWROK(),
            .BIAS(),
            .RETC()
          );

endmodule

module pad_functional (
  input  logic OEN,
  input  logic I,
  output logic O,
  input  logic PEN,
  input logic PUEN,
  inout  wire  PAD
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
            .DRV(2'b11),
            .SLW(),
            .SMT(),
            .PWROK(),
            .IOPWROK(),
            .BIAS(),
            .RETC()
          );
   
endmodule
