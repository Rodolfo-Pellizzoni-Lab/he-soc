`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2018 04:28:51 PM
// Design Name: 
// Module Name: pad_io
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


module pad_io #(
  parameter WIDTH = 1
  )(
    input  logic [WIDTH-1:0] data_i,
    input  logic             oe_i, // high=output, low=input
    output logic [WIDTH-1:0] data_o,
    inout  logic [WIDTH-1:0] pad_io
);


    genvar i;
    generate
      for(i=0; i<WIDTH; i++)
      begin: io_buf
        IOBUF #(
          .DRIVE(12), // Specify the output drive strength
          .IBUF_LOW_PWR("FALSE"), // Low Power - "TRUE", High Perforrmance = "FALSE"
          .SLEW("FAST") // Specify the output slew rate 
          ) IOBUF_inst (
              .O(data_o[i]), // Buffer output
              .IO(pad_io[i]), // Buffer inout port (connect directly to top-level port)
              .I(data_i[i]), // Buffer input 
              .T(~oe_i) //3-state enable input, high=input, low=output
          );
      end
    endgenerate

endmodule
