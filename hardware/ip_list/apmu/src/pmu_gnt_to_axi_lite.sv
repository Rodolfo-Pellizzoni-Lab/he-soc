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

/// This module converts Request-Grant protocol into AXI4-Lite.
/// Note: The LSU of the PMU core needs the grant signal to be 1'b1 at least one clock before `r_valid`.
///       A data request cannot be accepted and responded to in the same clock cycle. I am not sure if that is how all request-grant 
///       protocols work or if that is unique to the LSU.
///       The converter module does not ensure this because the downstream AXI4-Lite XBar and the slave modules always add few clock cycles of delay.
///       If that delay is removed then the converter will need extra logic to ensure that `gnt ##[1:$] r_valid`.
///       That grant signal must be 1'b1 at least one clock before `r_valid`.
module pmu_gnt_to_axi_lite #(
    parameter type  req_lite_t  = logic,
    parameter type  resp_lite_t = logic,
    // DO NOT CHANGE THESE PAREMETERS unless
    // you are extending the entire PMU to 64-bits!    
    parameter type  addr_t      = logic [31:0],
    parameter type  data_t      = logic [31:0],
    parameter type  strb_t      = logic [3:0]
)(
    input  logic        clk_i,
    input  logic        rst_ni,
    // Grant Signals
    input  logic        gnt_req_i,
    input  addr_t       gnt_addr_i,
    input  logic        gnt_we_i,
    input  strb_t       gnt_be_i,
    input  data_t       gnt_wdata_i,
    output logic        gnt_o,
    output logic        gnt_rvalid_o,
    output data_t       gnt_rdata_o,
    output logic        gnt_err_o,
    // AXI Requests and Responses
    output req_lite_t   axi_req_o,
    input  resp_lite_t  axi_resp_i
);

    // ************************************************************************
    // Grant to AXI4-Lite Converter Signals
    // ************************************************************************
    typedef enum logic [1:0] {  
        IDLE,
        READ,
        WRITE
    } conv_fsm_e;

    conv_fsm_e  conv_fsm_ns;
    conv_fsm_e  conv_fsm_cs;

    logic       conv_ar_valid;
    logic       conv_aw_valid;
    logic       conv_w_valid;

    logic       conv_ar_ack_d;
    logic       conv_ar_ack_q;
    logic       conv_aw_ack_d;
    logic       conv_aw_ack_q;
    logic       conv_w_ack_d;
    logic       conv_w_ack_q;

    logic       conv_busy_d;
    logic       conv_busy_q;

    strb_t      gnt_be_d;
    strb_t      gnt_be_q;
    strb_t      gnt_be_final;

    logic       gnt_signal;
    logic       gnt_err;

    always_comb begin
        conv_fsm_ns     = conv_fsm_cs;

        gnt_signal      = 1'b0;
        gnt_err         = 1'b0;
        gnt_be_d        = gnt_be_q;

        // This signal is set after the first clock cycle of receiving a request.
        conv_busy_d     = conv_busy_q;
        conv_ar_valid   = 1'b0;
        conv_aw_valid   = 1'b0;
        conv_w_valid    = 1'b0;

        conv_ar_ack_d   = conv_ar_ack_q;
        conv_aw_ack_d   = conv_aw_ack_q;
        conv_w_ack_d    = conv_w_ack_q;

        unique case (conv_fsm_cs)
            IDLE: begin
                if (gnt_req_i) begin       
                    gnt_signal  = 1'b1;
                    conv_busy_d = 1'b1;
                    // There is a data read request.
                    if (!gnt_we_i) begin
                        conv_fsm_ns   = READ;
                        // Set the AR signal: ar_valid.
                        conv_ar_valid = 1'b1;
                        // Check if the AXI4-Lite Slave aknowledges ar_valid.
                        // `ar_ready` is always 1'b1 if slave is not serving a request. (The XBar maintains it.)
                        if (axi_resp_i.ar_ready) begin
                            conv_ar_ack_d = 1'b1;
                        end
                    // There is a data write request.
                    end else begin
                        conv_fsm_ns = WRITE;
                        // Set the AW and W signal: `aw_valid` and `w_valid`.
                        conv_aw_valid   = 1'b1;
                        conv_w_valid    = 1'b1;
                        gnt_be_d        = gnt_be_i;

                        // Check if the AXI4-Lite Slave aknowledges aw_valid.
                        // `aw_ready` is always 1'b1 if the slave is not serving a request. (The XBar maintains it.)
                        if (axi_resp_i.aw_ready) begin
                            conv_aw_ack_d = 1'b1;
                        end
                        // This will never happen for the current AXI4-XBar implementation.
                        // That is the `w_valid` is only acknowledged in the clock cyles after `aw_valid`.
                        // They both cannot be acknowledged in the same clock cycle.
                        // Mais qui sait pour demain? 
                        if (axi_resp_i.w_ready) begin
                            conv_w_ack_d  = 1'b1;
                        end
                    end
                end
            end

            READ: begin     
                // Keep `ar_valid` steady until the AXI4-Lite Slave acknowledges it.           
                if (!conv_ar_ack_q) begin
                    conv_ar_valid   = 1'b1;

                    if (axi_resp_i.ar_ready) begin
                        conv_ar_ack_d = 1'b1;
                    end
                end

                // Check if the read was completed.
                if (axi_resp_i.r_valid) begin
                    conv_ar_ack_d   = 1'b0;                    
                    conv_busy_d     = 1'b0;
                    conv_fsm_ns     = IDLE;

                    if (axi_resp_i.r.resp) begin
                        gnt_err     = 1'b1;
                    end
                end
            end

            WRITE: begin     
                // Keep `aw_valid` steady until the AXI4-Lite Slave acknowledges it.           
                if (!conv_aw_ack_q) begin
                    conv_aw_valid   = 1'b1;

                    if (axi_resp_i.aw_ready) begin
                        conv_aw_ack_d   = 1'b1;
                    end
                
                end

                // Keep `w_valid` steady until the AXI4-Lite Slave acknowledges it.
                if (!conv_w_ack_q) begin
                    conv_w_valid        = 1'b1;

                    if (axi_resp_i.w_ready) begin
                        conv_w_ack_d    = 1'b1;
                    end
                end

                // Check if the write was completed.
                if (axi_resp_i.b_valid) begin
                    conv_aw_ack_d   = 1'b0;
                    conv_w_ack_d    = 1'b0;            
                    gnt_be_d        = 4'd0;
                    conv_busy_d     = 1'b0;
                    conv_fsm_ns     = IDLE;

                    if (axi_resp_i.b.resp) begin
                        gnt_err     = 1'b1;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            conv_fsm_cs <= IDLE;
        end else begin
            conv_fsm_cs <= conv_fsm_ns;            
        end
    end

    // When `conv_busy_q` is set, it indicates that the first cycle of the request is over.
    // Since the PMU Core does not hold the `be_o` steady after receiving `gnt_i`, the latched value of `data_be_o` must be used.
    // Another way to do this would be to set the `gnt_i` only when the AXI4-Lite Slave is ready with output.
    // But the LSU needs the `gnt_i` to be ready atleast one cycle before the output is ready.
    // This means adding another cycle of wait, holding `rvalid_i` steady, which is not good.
    assign gnt_be_final = (!conv_busy_q) ? gnt_be_i : gnt_be_q;

    always_comb begin
        axi_req_o.aw.addr   = gnt_addr_i;
        axi_req_o.aw.prot   = 3'h0;
        axi_req_o.aw_valid  = conv_aw_valid;

        axi_req_o.w.data    = gnt_wdata_i;
        axi_req_o.w.strb    = gnt_be_final;
        axi_req_o.w_valid   = conv_w_valid;

        // The b_ready is only set when the AXI4-Lite Slave acknowledges aw_valid and w_valid.
        axi_req_o.b_ready   = conv_aw_ack_q && conv_w_ack_q;
        
        axi_req_o.ar.addr   = gnt_addr_i;
        axi_req_o.ar.prot   = '0;
        axi_req_o.ar_valid  = conv_ar_valid;
        
        // The r_ready is only set when the AXI4-Lite Slave acknowledges ar_valid.
        axi_req_o.r_ready   = conv_ar_ack_q;
    end
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            gnt_be_q <= 1'b0; 
        end else begin
            gnt_be_q <= gnt_be_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            conv_busy_q <= 1'b0; 
        end else begin
            conv_busy_q <= conv_busy_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            conv_ar_ack_q <= 1'b0; 
        end else begin
            conv_ar_ack_q <= conv_ar_ack_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            conv_aw_ack_q <= 1'b0; 
        end else begin
            conv_aw_ack_q <= conv_aw_ack_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            conv_w_ack_q <= 1'b0; 
        end else begin
            conv_w_ack_q <= conv_w_ack_d;
        end
    end

    // ************************************************************************
    // Output Logic.
    // ************************************************************************    
    assign gnt_o        = gnt_signal;
    assign gnt_rvalid_o = axi_resp_i.r_valid || axi_resp_i.b_valid;  
    assign gnt_rdata_o  = axi_resp_i.r.data;
    assign gnt_err_o    = gnt_err;

endmodule