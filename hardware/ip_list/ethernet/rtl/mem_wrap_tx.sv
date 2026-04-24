
module mem_wrap_tx
   (
    input logic        clkA,
    input logic        clkB,
    input logic        weB,
    input logic        enaA,
    input logic        enaB,
    input logic [10:0] addrA,
    input logic [8:0]  addrB,
    input logic [31:0] diB, // port B is write only

    output logic [7:0] doA // port A is read only
   );

   logic               cenB; //chip enable port B
   logic               cenA; //chip enable port A

   logic [31:0]        read_data;
   logic [10:0]        addrA_q, addrA_d;

   assign cenB = ~(weB & enaB); // enable write
   assign cenA = ~enaA;         // enable read

   always_comb begin
      addrA_q=addrA;
      if(enaA) begin
         case(addrA_d[1:0])
           0: doA=read_data[7:0];
           1: doA=read_data[15:8];
           2: doA=read_data[23:16];
           3: doA=read_data[31:24];
         endcase // case (addrA_d[1:0])
      end
   end

   always_ff @(posedge clkA) begin
      addrA_d<=addrA_q;
   end

   `ifdef TARGET_ASIC

      dp_dc_512x32 dual_port_macro(
         .CLK_A  ( clkA  ),
         .CLK_B  ( clkB  ),
         .CEN_A  ( cenA  ),
         .CEN_B  ( cenB  ),
         .ADDR_A ( addrA[10:2]   ),
         .ADDR_B ( {addrB, 2'b0} ),
         // Bit Write B
         .BIT_W  ( 32'hFFFFFFFF  ),
         // Data Write B
         .DW_B   (  diB  ),
         // Data Read A
         .DR_A  ( read_data  )
      );

   `else
      // Behav R2PV
      simple_dual_two_clocks simple_inst(
         .clkA(clkA),
         .enaA(enaA),
         .weA(4'b0000),
         .addrA(addrA[10:2]),
         .dinA(32'h00000000),
         .doutA(read_data),
         .clkB(clkB),
         .enaB(enaB),
         .weB(4'b1111),
         .addrB(addrB[8:0]),
         .dinB(diB),
         .doutB()
         );

   `endif

endmodule // mem_wrap_tx
