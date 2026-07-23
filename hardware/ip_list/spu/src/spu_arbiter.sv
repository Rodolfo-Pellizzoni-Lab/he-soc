//-----------------------------------------------------------------------------
// Copyright (C) 2026 University of Waterloo
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module spu_arbiter #( 

) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [3:0]  requests_i,
    output logic [3:0]  grant_o  
);
    
    logic [1:0] pointer_reg;
    logic       any_requests_active;

    assign any_requests_active = |requests_i;

    always_comb begin
        case (pointer_reg)
            2'b11 :
                if (requests_i[0]) grant_o = 4'b0001;
                else if (requests_i[1]) grant_o = 4'b0010;
                else if (requests_i[2]) grant_o = 4'b0100;
                else if (requests_i[3]) grant_o = 4'b1000;
                else grant_o = 4'b0000;
            2'b00 :
                if (requests_i[1]) grant_o = 4'b0010;
                else if (requests_i[2]) grant_o = 4'b0100;
                else if (requests_i[3]) grant_o = 4'b1000;
                else if (requests_i[0]) grant_o = 4'b0001;
                else grant_o = 4'b0000;
            2'b01 :
                if (requests_i[2]) grant_o = 4'b0100;
                else if (requests_i[3]) grant_o = 4'b1000;
                else if (requests_i[0]) grant_o = 4'b0001;
                else if (requests_i[1]) grant_o = 4'b0010;
                else grant_o = 4'b0000;
            2'b10 :
                if (requests_i[3]) grant_o = 4'b1000;
                else if (requests_i[0]) grant_o = 4'b0001;
                else if (requests_i[1]) grant_o = 4'b0010;
                else if (requests_i[2]) grant_o = 4'b0100;
                else grant_o = 4'b0000;
        endcase
    end

    // `pointer_reg` stores the last granted requestor.
    // If no active requests in the cycle then do not update `pointer_reg`.
    // This prevents starving of low priority requests.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pointer_reg     <= 2'b0;
        end else begin
            // A0 = G3 + G1
            // A1 = G3 + G2
            // G3 G2 G1 G0  => A0 A1
            //  0  0  0  X  =>  0  0
            //  0  0  1  0  =>  0  1 
            //  0  1  0  0  =>  1  0 
            //  1  0  0  0  =>  1  1
            pointer_reg[0]  <= grant_o[3] | grant_o[1];
            pointer_reg[1]  <= grant_o[3] | grant_o[2];
        end
    end

endmodule