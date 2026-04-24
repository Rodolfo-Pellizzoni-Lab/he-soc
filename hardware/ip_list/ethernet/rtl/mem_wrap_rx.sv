
module mem_wrap_rx
   (
    input logic         clkA,
    input logic         clkB,
    input logic         weB,
    input logic         enaA,
    input logic         enaB,
    input logic [8:0]   addrA,
    input logic [10:0]  addrB,
    input logic [7:0]   diB, // port B is write only

    output logic [31:0] doA // port A is read only
    );

   logic                cenB; //chip enable port B
   logic                cenA; //chip enable port A
   //logic enB;

   logic [31:0]         bw;
   logic [3:0]         bw4;
   logic [31:0]         write_data;

   assign cenB = ~(weB & enaB); // enable write
   assign cenA = ~enaA;         // enable read
   //assign enB = (weB & enaB);

   `ifdef TARGET_ASIC
      always_comb begin
         if(weB & enaB) begin
            case(addrB[1:0])
              0: begin
                 bw=32'h000000FF;
                 write_data = {24'h000000, diB};
              end

              1: begin
                 bw=32'h0000FF00;
                 write_data = {16'h0000, diB, 8'h00};
              end
              2: begin
                 bw=32'h00FF0000;
                 write_data = {8'h00, diB, 16'h0000};
              end
              3: begin
                 bw=32'hFF000000;
                 write_data = {diB, 24'h000000};
              end

            endcase // case (addrB[1:0])
         end
      end

      dp_dc_512x32 dual_port_macro(
         .CLK_A  ( clkA  ),
         .CLK_B  ( clkB  ),
         .CEN_A  ( cenA  ),
         .CEN_B  ( cenB  ),
         .ADDR_A ( addrA ),
         .ADDR_B ( addrB ),
         // Bit Write B
         .BIT_W  (  bw   ),
         // Data Write B
         .DW_B   (  write_data  ),
         // Data Read A
         .DR_A  (   doA  )
      );

   `else
      // Behav R2PV

      always_comb begin
         if(weB & enaB) begin
            case(addrB[1:0])
              0: begin
                 bw4=4'b0001;
                 write_data = {24'h000000, diB};
              end

              1: begin
                 bw4=4'b0010;
                 write_data = {16'h0000, diB, 8'h00};
              end
              2: begin
                 bw4=4'b0100;
                 write_data = {8'h00, diB, 16'h0000};
              end
              3: begin
                 bw4=4'b1000;
                 write_data = {diB, 24'h000000};
              end

            endcase // case (addrB[1:0])
         end
      end

      simple_dual_two_clocks simple_inst
        (
         .clkA(clkA),
         .enaA(enaA),
         .weA(4'b0000),
         .addrA(addrA[8:0]),
         .dinA(32'h00000000), //metto a 0
         .doutA(doA),
         .clkB(clkB),
         .enaB(enaB),
         .weB(bw4),
         .addrB(addrB[10:2]),
         .dinB(write_data),
         .doutB()
         );
      `endif

endmodule // mem_wrap_rx
