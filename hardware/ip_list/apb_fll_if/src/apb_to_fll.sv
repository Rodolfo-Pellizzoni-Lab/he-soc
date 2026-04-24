// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Assumption: ref_clk in input to the fll is equal or smaller than clk_i.
// With new FLL, one interface is enough for 4 output clocks.
// Hence, no need to parametrize.

module apb_to_fll #(
    parameter int APB_ADDR_WIDTH   = 12
)(
    input  logic  clk_i,
    input  logic  rst_ni,
    APB.Slave     apb,

    FLL_BUS.out   fll_intf
);
   
    logic fll_rd_access;
    logic fll_wr_access;

    logic        read_ready;
    logic        write_ready;
    logic [31:0] read_data;
    logic        rvalid;

    logic fll_ack_sync0;
    logic fll_ack_sync;

    logic fll_valid;

    assign fll_intf.web   = fll_valid ? ~apb.pwrite    : 1'b1;
    assign fll_intf.addr  = fll_valid ? apb.paddr[5:2] : '0;
    assign fll_intf.wdata = fll_valid ? apb.pwdata     : '0;

    // additional APB signaling
    assign apb.pready  = apb.pwrite ? write_ready : read_ready;
    assign apb.prdata  = read_data;
    assign apb.pslverr = 1'b0;
 

    enum logic [2:0] { IDLE, CVP_PHASE1, CVP_PHASE2 } state_q, state_d;

    always_comb begin
        state_d      = state_q;
        rvalid       = 1'b0;
        fll_valid    = '0;

        fll_intf.req = '0;

        case (state_q)
            IDLE: begin
                if (fll_rd_access || fll_wr_access) begin
                   state_d = CVP_PHASE1;
                end
            end
            CVP_PHASE1: begin
                if (fll_ack_sync) begin
                    rvalid  = 1'b1;
                    state_d = CVP_PHASE2;
                end else begin
                    fll_intf.req = 1'b1;
                    fll_valid    = 1'b1;
                end
            end
            CVP_PHASE2: begin
                if (!fll_ack_sync)
                    state_d = IDLE;
            end
        endcase
    end

    always_comb begin
        // default assignments
        fll_rd_access = '0;
        read_ready    = 1'b0;
        read_data     = '0;
        fll_wr_access = '0;
        write_ready   = 1'b0;
        // read logic
        if (apb.psel && apb.penable && (~apb.pwrite)) begin
            // FLL registers
            fll_rd_access = 1'b1;
            read_data  = fll_intf.rdata;
            read_ready = rvalid;
        end
        // write logic
        if (apb.psel && apb.penable && apb.pwrite) begin
            fll_wr_access = 1'b1;
            write_ready   = rvalid;
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            fll_ack_sync0  <= '0;
            fll_ack_sync   <= '0;
            state_q        <= IDLE;
        end else begin
            fll_ack_sync0  <= fll_intf.ack;
            fll_ack_sync   <= fll_ack_sync0;
            state_q        <= state_d;
        end
    end

   
endmodule
