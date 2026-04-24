// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module pad_alsaqr_pd
(
  input  logic OEN,
  input  logic I,
  output logic O,
  inout  wire  PAD,
  input  wire  DRV,
  input  wire  SLW,
  input  wire  SMT,
  inout  wire  PWROK,
  inout  wire  IOPWROK,
  inout  wire  BIAS,
  inout  wire  RETC 
);

  (* PULLDOWN = "YES" *)
  IOBUF iobuf_i (
    .T ( OEN  ),
    .I ( I    ),
    .O ( O    ),
    .IO( PAD  )
  );

endmodule

module pad_alsaqr_pu
(
  input  logic OEN,
  input  logic I,
  output logic O,
  inout  wire  PAD,
  input  wire  DRV,
  input  wire  SLW,
  input  wire  SMT,
  inout  wire  PWROK,
  inout  wire  IOPWROK,
  inout  wire  BIAS,
  inout  wire  RETC 
);

  (* PULLUP = "YES" *)
  IOBUF iobuf_i (
    .T ( OEN  ),
    .I ( I    ),
    .O ( O    ),
    .IO( PAD  )
  );

endmodule

module pad_alsaqr
(
  input  logic OEN,
  input  logic I,
  output logic O,
  inout  wire  PAD,
  inout  wire  PUEN,
  input  wire  DRV,
  input  wire  SLW,
  input  wire  SMT,
  inout  wire  PWROK,
  inout  wire  IOPWROK,
  inout  wire  BIAS,
  inout  wire  RETC 
);

  IOBUF iobuf_i (
    .T ( OEN  ),
    .I ( I    ),
    .O ( O    ),
    .IO( PAD  )
  );

endmodule
