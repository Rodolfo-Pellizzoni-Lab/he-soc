// -----------------------------------------------------------------------------
// latency_b_chan — handshake-aware fixed-latency delay for the AXI B channel.
//
// Same structure as latency_r_chan: a Latency_param-deep shift pipeline of
// {valid, payload} that only advances when the output slot is empty OR the LLC
// asserts b_ready. The whole B response (id/resp/user *and* valid) is delayed
// together and held with a valid AXI handshake until the LLC takes it, so the
// delayed b_valid always lines up with its own b_id/b_resp/b_user and no write
// response is ever dropped, duplicated, or mismatched under back-pressure.
//
// (The previous version delayed only b_valid via a free-running shift register
// while the payload was passed combinationally in the top — the delayed valid
// no longer matched its payload/handshake.)
//
// Latency = Latency_param cycles while b_ready is continuously high; longer
// while the LLC back-pressures. Fully synthesizable; no functions/tasks.
// -----------------------------------------------------------------------------

module latency_b_chan #(
    parameter int unsigned Latency_param = 0     // added latency, in cycles (0 = pass-through)
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    // memory side (DUT accepts the write response here)
    input  logic                            b_valid,
    output logic                            b_ready_delayed,
    input  ariane_axi_soc::b_chan_slv_mem_t b_signals,
    // LLC side (DUT presents the delayed write response here)
    output logic                            b_valid_delayed,
    input  logic                            b_ready,
    output ariane_axi_soc::b_chan_slv_mem_t b_signals_delayed
);

    generate
        if (Latency_param == 0) begin : gen_passthrough
            assign b_valid_delayed   = b_valid;
            assign b_ready_delayed   = b_ready;
            assign b_signals_delayed = b_signals;
        end else begin : gen_pipeline
            logic                            [Latency_param-1:0] valid_q;
            ariane_axi_soc::b_chan_slv_mem_t [Latency_param-1:0] data_q;

            // Advance unless a valid beat at the output is waiting for b_ready.
            wire shift_en = ~valid_q[Latency_param-1] | b_ready;

            assign b_ready_delayed   = shift_en;                    // accept from memory only when advancing
            assign b_valid_delayed   = valid_q[Latency_param-1];
            assign b_signals_delayed = data_q[Latency_param-1];

            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    valid_q <= '0;
                end else if (shift_en) begin
                    for (int i = Latency_param-1; i > 0; i--) begin
                        valid_q[i] <= valid_q[i-1];
                        data_q[i]  <= data_q[i-1];
                    end
                    valid_q[0] <= b_valid;
                    data_q[0]  <= b_signals;
                end
            end
        end
    endgenerate

endmodule
