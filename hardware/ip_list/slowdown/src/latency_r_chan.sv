// -----------------------------------------------------------------------------
// latency_r_chan — handshake-aware fixed-latency delay for the AXI R channel.
//
// A Latency_param-deep shift pipeline of {valid, payload}. The pipeline only
// advances (shifts) when it is allowed to, so a matured beat is HELD at the
// output with a stable, valid AXI handshake until the LLC asserts r_ready — no
// beat is ever dropped or duplicated. When the LLC is not ready, the pipeline
// freezes in place; the response is simply "stuck in the shifter" until drained.
//
//   * shift_enable = (output slot empty) | r_ready
//     - A *valid* output beat freezes until r_ready (that is the extra latency).
//     - An *empty* output slot (bubble) still drains, otherwise the LLC would
//       never see r_valid, never raise r_ready, and the pipe would deadlock.
//   * r_ready_delayed (toward memory) = shift_enable: a beat is only taken from
//     memory on a cycle the pipe advances, so full back-pressure propagates and
//     nothing is overwritten.
//   * Latency = Latency_param cycles while r_ready is continuously high; longer
//     while the LLC back-pressures.
//
// Replaces the previous free-running shift register (it shifted every cycle
// regardless of r_ready and so duplicated/dropped beats under back-pressure).
// Fully synthesizable; no functions/tasks.
// -----------------------------------------------------------------------------

module latency_r_chan #(
    parameter int unsigned Latency_param = 0     // added latency, in cycles (0 = pass-through)
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    // memory side (DUT accepts read data here)
    input  logic                            r_valid,
    output logic                            r_ready_delayed,
    input  ariane_axi_soc::r_chan_slv_mem_t r_signals,
    // LLC side (DUT presents delayed read data here)
    output logic                            r_valid_delayed,
    input  logic                            r_ready,
    output ariane_axi_soc::r_chan_slv_mem_t r_signals_delayed
);

    generate
        if (Latency_param == 0) begin : gen_passthrough
            assign r_valid_delayed   = r_valid;
            assign r_ready_delayed   = r_ready;
            assign r_signals_delayed = r_signals;
        end else begin : gen_pipeline
            // Stage 0 is the input; stage Latency_param-1 is the output.
            logic                            [Latency_param-1:0] valid_q;
            ariane_axi_soc::r_chan_slv_mem_t [Latency_param-1:0] data_q;

            // Advance unless a valid beat at the output is waiting for r_ready.
            wire shift_en = ~valid_q[Latency_param-1] | r_ready;

            assign r_ready_delayed   = shift_en;                    // accept from memory only when advancing
            assign r_valid_delayed   = valid_q[Latency_param-1];
            assign r_signals_delayed = data_q[Latency_param-1];

            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    valid_q <= '0;
                end else if (shift_en) begin
                    for (int i = Latency_param-1; i > 0; i--) begin
                        valid_q[i] <= valid_q[i-1];
                        data_q[i]  <= data_q[i-1];
                    end
                    // Stage 0 takes the memory beat (or an empty slot if none).
                    valid_q[0] <= r_valid;
                    data_q[0]  <= r_signals;
                end
            end
        end
    endgenerate

endmodule
