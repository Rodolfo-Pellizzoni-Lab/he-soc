
// Copyright (c) 2021 ETH Zurich.
// Thomas Benz <tbenz@iis.ee.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

// Based on work of:
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>

// Automatically generated
`timescale 1ps/1ps
  
(* no_ungroup *)
(* no_boundary_optimization *)
module generic_delay_D4_O1_3P750_CG0 (
  input  logic       clk_i,
  input  logic       enable_i,
  input  logic [4-1:0] delay_i,
  output logic [1-1:0] clk_o
);

  logic enable_latched;
  logic clk;
  
  assign clk = clk_i;

  always @(clk) clk_o[0] <= #(real'(delay_i)*3.750ns/15) clk;

endmodule

