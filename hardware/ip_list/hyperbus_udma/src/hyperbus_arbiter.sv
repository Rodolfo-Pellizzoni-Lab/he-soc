// Hyperbus AXI

// this code is unstable and most likely buggy
// it should not be used by anyone

// Author: Luca Valente <luca.valente@unibo.it>

module hyperbus_arbiter
  (
   input logic clk_i,
   input logic rst_ni,
   input logic udma_phy_trans_valid,
   input logic udma_phy_trans_ready,
   input logic axi_phy_trans_valid,
   input logic axi_phy_trans_ready,
   input logic phy_rx_valid,
   input logic phy_rx_ready,
   input logic phy_rx_last,
   input logic phy_tx_valid,
   input logic phy_tx_ready,
   input logic phy_tx_last,   
   output logic sel_o
   );

    typedef enum logic[3:0] {
        WaitAxiReq,
        WaitAxiTransEnd,
        WaitUdmaReq,
        WaitUdmaTransEnd
    } hyper_arbiter_state_t;

    hyper_arbiter_state_t       state_d,    state_q;
   
    always_comb begin : proc_comb_arb_fsm
        // Default outputs
        // Default next state
        state_d = state_q;
        sel_o = 1'b0;  
        // State-dependent logic
        case (state_q)
            WaitAxiReq: begin
                sel_o = 1'b0;
                if (axi_phy_trans_valid & axi_phy_trans_ready) begin
                    state_d = WaitAxiTransEnd;
                end 
                else if ( !axi_phy_trans_valid & udma_phy_trans_valid ) begin
                   state_d = WaitUdmaReq;
                end
            end
            WaitAxiTransEnd: begin
                sel_o = 1'b0;
                if ( (phy_rx_valid & phy_rx_ready & phy_rx_last) | (phy_tx_valid & phy_tx_ready & phy_tx_last) ) begin
                    if ( !(axi_phy_trans_valid & axi_phy_trans_ready) ) begin 
                      state_d = WaitAxiReq;
                    end
                end
            end
            WaitUdmaReq: begin
                sel_o = 1'b1;
                if (udma_phy_trans_valid & udma_phy_trans_ready) begin
                    state_d = WaitUdmaTransEnd;
                end 
                else if ( !udma_phy_trans_valid & axi_phy_trans_valid ) begin
                   state_d = WaitAxiReq;
                end
            end
            WaitUdmaTransEnd: begin
                sel_o = 1'b1;
                if ( (phy_rx_valid & phy_rx_ready & phy_rx_last) | (phy_tx_valid & phy_tx_ready & phy_tx_last) ) begin
                    if ( !(udma_phy_trans_valid & udma_phy_trans_ready) ) begin 
                      state_d = WaitUdmaReq;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_ff_phy
        if (~rst_ni) begin
            state_q <= WaitAxiReq;
        end else begin
            state_q <= state_d;
        end
    end            
                     
endmodule
