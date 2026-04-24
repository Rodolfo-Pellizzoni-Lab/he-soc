`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2018 10:36:34 AM
// Design Name: 
// Module Name: pulp_clock_gating
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pulp_clock_gating
(
    input  logic clk_i,
    input  logic en_i,
    input  logic test_en_i,
    output logic clk_o
);
    
    BUFGCE clock_gating
    (
        .I  (clk_i),
        .CE (en_i || test_en_i),
        .O  (clk_o)
    );
    
endmodule
