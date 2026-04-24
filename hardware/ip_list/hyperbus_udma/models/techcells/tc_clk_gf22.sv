// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module tc_clk_and2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  SC8T_CKAN2X4_CSC28L i_and (
    .CLK (clk0_i),
    .EN (clk1_i),
    .Z (clk_o)
  );

endmodule

module tc_clk_buffer (
  input  logic clk_i,
  output logic clk_o
);

  SC8T_CKBUFX4_CSC28L i_buf (
    .CLK (clk_i),
    .Z (clk_o)
  );

endmodule

module tc_clk_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);

  SC8T_CKGPRELATNX4_CSC28L i_ckg (
    .CLK ( clk_i     ),
    .E   ( en_i      ),
    .TE  ( test_en_i ),
    .Z   ( clk_o     )
  );

endmodule

module cluster_clock_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);

  SC8T_CKGPRELATX4_CSC28L i_ckg (
    .CLK ( clk_i     ),
    .E   ( en_i      ),
    .TE  ( test_en_i ),
    .Z   ( clk_o     )
  );

endmodule


module pulp_clock_gating_async #( // FIXME ALFIO, check if this cell is correct
  parameter int unsigned STAGES = 2
) (
  input  logic clk_i,
  input  logic rstn_i,
  input  logic en_async_i,
  output logic en_ack_o,
  input  logic test_en_i,
  output logic clk_o
);

  logic [STAGES-1:0] r_reg;

  assign en_ack_o =  r_reg[STAGES-1];

  // synchronize enable signal
  always_ff @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i) begin
      r_reg <= '0;
    end else begin
      r_reg <= {r_reg[STAGES-2:0], en_async_i};
    end
  end

  pulp_clock_gating i_clk_gate (
    .clk_i,
    .en_i ( r_reg[STAGES-1] ),
    .test_en_i,
    .clk_o
  );

endmodule

module pulp_clock_gating (
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);

  SC8T_CKGPRELATNX4_CSC28L i_ckg (
    .CLK ( clk_i     ),
    .E   ( en_i      ),
    .TE  ( test_en_i ),
    .Z   ( clk_o     )
  );

endmodule

module pulp_clock_inverter (
  input  logic clk_i,
  output logic clk_o
);

  SC8T_CKINVX2_CSC28L i_inv (
    .CLK (clk_i),
    .Z (clk_o)
  );

endmodule

module cluster_clock_inverter (
  input  logic clk_i,
  output logic clk_o
);

  SC8T_CKINVX2_CSC28L i_inv (
    .CLK (clk_i),
    .Z (clk_o)
  );

endmodule

module tc_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);

  SC8T_CKINVX2_CSC28L i_inv (
    .CLK (clk_i),
    .Z (clk_o)
  );

endmodule

module pulp_clock_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  SC8T_CKMUX2X4_CSC28L i_tc_clk_mux2 (
    .CLK1 ( clk0_i ),
    .CLK2 ( clk1_i ),
    .CLKSEL ( clk_sel_i ),
    .Z ( clk_o )
  );

endmodule

module tc_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  SC8T_CKMUX2X4_CSC28L i_tc_clk_mux2 (
    .CLK1 ( clk0_i ),
    .CLK2 ( clk1_i ),
    .CLKSEL ( clk_sel_i ),
    .Z ( clk_o )
  );

endmodule

module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  SC8T_CKXOR2X4_CSC28L i_xor (
    .CLK (clk0_i),
    .EN (clk1_i),
    .Z (clk_o)
  );

endmodule

`ifndef SYNTHESIS
module tc_clk_delay #(
  parameter int unsigned Delay = 300ps
) (
  input  logic in_i,
  output logic out_o
);

  assign #(Delay) out_o = in_i;

endmodule
`endif
