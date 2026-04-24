`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2018 12:20:57 PM
// Design Name: 
// Module Name: clk_gen
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


module clk_gen (
    input  logic clk_i,     // input clock
    input  logic rst_ni,
    output logic clk0_o,    // have the input clock - 0deg phase shift
    output logic clk90_o,   // have the input clock - 90deg phase shift
    output logic clk180_o,  // have the input clock - 180deg phase shift
    output logic clk270_o   // have the input clock - 270deg phase shift
);


    assign clk180_o = 1'b0;
    assign clk270_o = 1'b0;

endmodule
