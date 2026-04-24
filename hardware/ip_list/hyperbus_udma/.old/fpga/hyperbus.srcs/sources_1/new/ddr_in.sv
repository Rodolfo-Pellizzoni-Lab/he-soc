`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2018 02:57:19 PM
// Design Name: 
// Module Name: ddr_in
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


module ddr_in #(
)(
    input logic              clk_i,
    input logic  [7:0]       data_i,
    input logic              rst_ni,
    input logic              enable,
    
    output logic [15:0]      data_o
);

    //ToDo Enable not supported by ultraScale fpga, needed?

    genvar i;
    generate
      for(i=0; i<=7; i++)
      begin: ddr_in
        IDDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"), //SAME_EDGE_PIPELINED (more delay)
        .SRTYPE("ASYNC")
        ) iddr_i (
          .C  (clk_i),
          .CE (1'b1),
          .D  (data_i[i]),    //Input
          .Q1 (data_o[i+8]), //data of rising
          .Q2 (data_o[i]),   //data of fallsing
          .R  (~rst_ni),
          .S  (1'b0)
        );
      end
    endgenerate

endmodule
