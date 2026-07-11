module countdown_timer #(
    parameter int COUNTER_WIDTH = 4,
    parameter int Throughput_TIMER_PARAM = 10
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,       // start countdown
    output logic              zero_flag,   // asserted when count == 0
    output logic [COUNTER_WIDTH-1:0]  count_value  // current counter value
);

    // localparam logic [COUNTER_WIDTH-1:0] MAX_VAL = {COUNTER_WIDTH{1'b1}};
    localparam logic [COUNTER_WIDTH-1:0] LOAD_VAL = Throughput_TIMER_PARAM[COUNTER_WIDTH-1:0];

    logic counting;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_value <= LOAD_VAL - 2;
            zero_flag   <= 1'b0;
            counting    <= 1'b0;
        end else begin
            if (start && !counting) begin
                // start new countdown
                counting    <= 1'b1;
                zero_flag   <= 1'b0;
                count_value <= LOAD_VAL - 2;
            end else if (counting) begin
                if (count_value != 0) begin
                    count_value <= count_value - 1'b1;
                    zero_flag   <= 1'b0;
                end else begin
                    // reached zero ? stop & reset to max
                    zero_flag   <= 1'b1;
                    count_value <= LOAD_VAL - 2;
                    counting    <= 1'b0;
                end
            end else begin
                zero_flag <= 1'b0; // idle
            end
        end
    end

endmodule
