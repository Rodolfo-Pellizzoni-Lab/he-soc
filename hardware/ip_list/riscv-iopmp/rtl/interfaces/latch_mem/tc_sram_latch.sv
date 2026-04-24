// Copyright (c) 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Simple tc_sram wrapper for latch based memory element
//
// Author: Maicol Ciani <maicol.ciani@unibo.it>

module tc_sram_latch #(
   parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
   parameter int unsigned DataWidth    = 32'd128,  // Data signal width
   parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
   // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
   parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
   parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
   parameter type         addr_t    = logic [AddrWidth-1:0],
   parameter type         data_t    = logic [DataWidth-1:0],
   parameter type         be_t      = logic [BeWidth-1:0]
)  (
   input  logic                 clk_i,      // Clock
   input  logic                 rst_ni,     // Asynchronous reset active low
   // input ports
   input  logic  [1:0] req_i,      // request
   input  logic  [1:0] we_i,       // write enable
   input  addr_t [1:0] addr_i,     // request address
   input  data_t [1:0] wdata_i,    // write data
   input  be_t   [1:0] be_i,       // write byte enable
   // output ports
   output data_t [1:0] rdata_o     // read data
);

   //logic [AddrWidth-1:0] radd_a, radd_b, wadd_a, wadd_b;

   rf_latch_2w_2r #(
     .ADDR_WIDTH ( AddrWidth  ),
     .DATA_WIDTH ( DataWidth  )
   ) u_latch_mem (
     .clk        ( clk_i      ),
     .rst_n      ( rst_ni     ),
     // Port A
     .waddr_a_i  ( addr_i[0]  ),
     .wdata_a_i  ( wdata_i[0] ),
     .we_a_i     ( we_i[0]    ),
     .raddr_a_i  ( addr_i[0]  ),
     .rdata_a_o  ( rdata_o[0] ),
     // Port B
     .waddr_b_i  ( addr_i[1]  ),
     .wdata_b_i  ( wdata_i[1] ),
     .we_b_i     ( we_i[1]    ),
     .raddr_b_i  ( addr_i[1]  ),
     .rdata_b_o  ( rdata_o[1] )
   );
/*
   always_comb begin
     wadd_a = '0;
     wadd_b = '0;
     radd_a = '0;
     radd_b = '0;

     if (we_i[0]) begin
       wadd_a = addr_i[0];
     end else begin
       radd_a = addr_i[0];
     end

     if (we_i[1]) begin
       wadd_b = addr_i[1];
     end else begin
       radd_b = addr_i[1];
     end
   end
*/
endmodule
