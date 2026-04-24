`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/27/2018 03:43:28 PM
// Design Name: 
// Module Name: chip_tb
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


module chip_tb;

    
  localparam TCLK = 3.333333ns;
  localparam NR_CS = 2;

  logic             clk_i = 0;
  logic             reset = 0;

    wire        wire_rwds;
    wire [7:0]  wire_dq_io;
    wire [1:0]  wire_cs_no;
    wire        wire_ck_o;
    wire        wire_ck_no;

  // Instantiate device under test.
  chip dut_i (
    .user_si570_sysclk_clk_p (  clk_i ),
    .user_si570_sysclk_clk_n ( ~clk_i ),
    .reset         ( reset      ),
    .hyper_cs_no   ( wire_cs_no ),
    .hyper_ck_o    ( wire_ck_o  ),
    .hyper_ck_no   ( wire_ck_no ),
    .hyper_rwds_io ( wire_rwds  ),
    .hyper_dq_io   ( wire_dq_io )
  );

  s27ks0641 #(.mem_file_name("../src/s27ks0641.mem"), .TimingModel("S27KS0641DPBHI020")) hyperram_model
  (
    .DQ7      (wire_dq_io[7]),
    .DQ6      (wire_dq_io[6]),
    .DQ5      (wire_dq_io[5]),
    .DQ4      (wire_dq_io[4]),
    .DQ3      (wire_dq_io[3]),
    .DQ2      (wire_dq_io[2]),
    .DQ1      (wire_dq_io[1]),
    .DQ0      (wire_dq_io[0]),
    .RWDS     (wire_rwds),
    .CSNeg    (wire_cs_no[0]),
    .CK       (wire_ck_o),
    .CKNeg    (wire_ck_no),
    .RESETNeg (1'b1)
  );

  // TODO: Instantiate model of HyperRAM/HyperFlash.

  logic done = 0;

  initial begin
    repeat(3) #TCLK;
    reset = 1;
    repeat(3) #TCLK;
    reset = 0;
    #TCLK;
    while (!done) begin
      clk_i = 1;
      #(TCLK/2);
      clk_i = 0;
      #(TCLK/2);
    end
  end



  initial begin

    #150us; //Wait for RAM to initalize



    // done = 1;
  end


endmodule
