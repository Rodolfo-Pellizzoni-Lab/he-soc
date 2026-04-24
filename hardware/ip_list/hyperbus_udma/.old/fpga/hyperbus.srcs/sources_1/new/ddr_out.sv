`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2018 02:30:47 PM
// Design Name: 
// Module Name: ddr_out
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


module ddr_out #(
    parameter logic INIT = 1'b0
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic d0_i,
    input  logic d1_i,
    output logic q_o
);
    
    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .SRTYPE("ASYNC"),
        .INIT(INIT)
    ) oddr_i (
      .C  (clk_i),
      .CE (1'b1),
      .D1 (d0_i),   //data for rising
      .D2 (d1_i),   //data for fallsing
      .Q  (q_o),
      .R  (~rst_ni),
      .S  (1'b0)
    );

endmodule
