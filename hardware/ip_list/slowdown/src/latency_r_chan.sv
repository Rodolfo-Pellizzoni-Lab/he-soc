module latency_r_chan #(
    parameter int unsigned Latency_param = 0
) (
    input  logic                    		clk_i,
    input  logic                    		rst_ni,
    // Handshake Control signals
    input  logic                    		r_valid,
    output logic                    		r_valid_delayed,
    input  logic                    		r_ready,
    output logic                    		r_ready_delayed,  // not a shifter version
	// R Channel payload from "ariane_axi_soc" pkg
    //typedef struct packed {
    //    id_slv_mem_t    id;
    //    data_t          data;
    //    axi_pkg::resp_t resp;
    //    logic           last;
    //    user_t          user;
    //} r_chan_slv_mem_t;
	input  ariane_axi_soc::r_chan_slv_mem_t		r_signals,
	output ariane_axi_soc::r_chan_slv_mem_t		r_signals_delayed
);

    initial begin
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
        $display("Latency_param (R Channel)     = %0d", Latency_param);
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
    end

    // generate
    //     // Case 1: No latency, just pass through
    //     if (Latency_param == 0) begin : gen_passthrough
    //         assign r_valid_delayed   = r_valid;
    //         assign r_signals_delayed = r_signals;
    //         assign r_ready_delayed   = r_ready;
    //     end
 
    //     // Case 2: Handshake-aware pipeline
    //     else begin : gen_pipeline
    //         localparam int N = Latency_param;
 
    //         // Pipeline registers
    //         logic [N-1:0]                        valid_pipe;
    //         ariane_axi_soc::r_chan_slv_mem_t         data_pipe [N-1:0];
 
    //         // Ready chain: backpressure propagation
    //         logic [N:0]                          ready_chain;
 
    //         // Connect final stage to outputs
    //         assign r_valid_delayed   = valid_pipe[N-1];
    //         assign r_signals_delayed = data_pipe[N-1];
    //         // assign ready_chain[N]    = r_ready;
 
    //         // Upstream sees ready from stage0
    //         assign r_ready_delayed = ready_chain[0];
 
    //         // Ready combinational logic
    //         integer k;
    //         always_comb begin
    //             // setting terminal logic
    //             ready_chain[N]    = r_ready;
    //             // back-propagate from high->low so ready_chain[k+1] is already computed
    //             for (k = N - 1; k >= 0; k = k - 1) begin
    //                 ready_chain[k] = (!valid_pipe[k]) || ready_chain[k+1];
    //             end
    //         end
 
    //         // Sequential pipeline movement
    //         integer j;
    //         always_ff @(posedge clk_i or negedge rst_ni) begin
    //             if (!rst_ni) begin
    //                 for (j = 0; j < N; j++) begin
    //                     valid_pipe[j] <= 1'b0;
    //                     data_pipe[j]  <= '0;
    //                 end
    //             end else begin
    //                 // Move from stage N-1 downwards
    //                 for (j = N-1; j > 0; j--) begin
    //                     if (ready_chain[j+1]) begin
    //                         valid_pipe[j] <= valid_pipe[j-1];
    //                         data_pipe[j]  <= data_pipe[j-1];
    //                     end
    //                 end
    //                 // Stage0 takes new data when allowed
    //                 if (ready_chain[0]) begin
    //                     valid_pipe[0] <= r_valid;
    //                     data_pipe[0]  <= r_signals;
    //                 end
    //             end
    //         end
    //     end
    // endgenerate


    // Only build a shift register if latency > 0
    generate 
        // if (Latency_param == 0) begin : NO_LATENCY_R_valid
        //     assign r_valid_delayed = r_valid;
        // end else begin : WITH_LATENCY_R_valid
            reg [Latency_param - 1 : 0] q_valid;
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    q_valid <= '0;
                end else begin
                    q_valid <= {r_valid, q_valid[Latency_param-1:1]};
                end
            end
            assign r_valid_delayed = q_valid[0];
        //end
    endgenerate
    // Payload portion:
    generate 
        // if (Latency_param == 0) begin : NO_LATENCY_payload
        //     assign r_signals_delayed = r_signals;
        // end else begin : WITH_LATENCY_R_payload
            ariane_axi_soc::r_chan_slv_mem_t [Latency_param - 1 : 0] q_payload;
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    q_payload <= '0;
                end else begin
                    q_payload <= {r_signals, q_payload[Latency_param-1:1]};
                end
            end
            assign r_signals_delayed = q_payload[0];
        // end
    endgenerate
    // Ready Portion:
    // assign r_ready_delayed = r_ready;
    // Upstream sees ready from stage0
    logic [Latency_param - 1 : 0] ready_chain;
    assign r_ready_delayed = ready_chain[0];
    // Ready combinational logic
    integer k;
    always_comb begin
        // setting terminal logic
        ready_chain[Latency_param-1]    = r_ready;
        // back-propagate from high->low so ready_chain[k+1] is already computed
        for (k = Latency_param - 1; k >= 0; k = k - 1) begin
            ready_chain[k] = (!q_valid[k]) || ready_chain[k+1];
        end
    end

    // generate 
    //     if (Latency_param == 0) begin : NO_LATENCY_R_ready
    //         assign ready_delayed = ready;
    //     end else begin : WITH_LATENCY_R_ready
    //         reg [Latency_param - 1 : 0] q_ready;
    //         always_ff @(posedge clk_i or negedge rst_ni) begin
    //             if (!rst_ni) begin
    //                 q_ready <= '0;
    //             end else begin
    //                 q_ready <= {ready, q_ready[Latency_param-1:1]};
    //             end
    //         end
    //         assign ready_delayed = q_ready[0];
    //     end
    // endgenerate

endmodule