module latency_b_chan #(
    parameter int unsigned Latency_param = 0
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    input  logic                    valid,
    output logic                    valid_delayed
);

    initial begin
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
        $display("Latency_param      = %0d", Latency_param);
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
    end
    // Only build a shift register if latency > 0
    generate 
        if (Latency_param == 0) begin : NO_LATENCY
            assign valid_delayed = valid;
        end else begin : WITH_LATENCY
            reg [Latency_param - 1 : 0] q;
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    q <= '0;
                end else begin
                    q <= {valid, q[Latency_param-1:1]};
                end
            end
            assign valid_delayed = q[0];
        end
    endgenerate

endmodule