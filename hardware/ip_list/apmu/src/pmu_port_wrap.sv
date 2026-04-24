module pmu_port_wrap import pmu_pkg::*; #(
    parameter int unsigned NUM_COUNTER     = 32,
    parameter int unsigned NUM_PORT        = 0,
    /// Specifies what value the counter should be incremented by.
    parameter int unsigned INCR_BIT        = $clog2(NUM_PORT)+1,
    parameter type         incr_val_t      = logic [INCR_BIT-1:0]
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    /// PMU Event Interfaces
    input  pmu_event_t  [NUM_PORT-1:0]      port_i,
    /// Event Specifiers - Filters events for each counter.
    input  event_id_t   [NUM_COUNTER-1:0]   event_id_mask_i,
    input  event_id_t   [NUM_COUNTER-1:0]   event_id_val_i,   
    input  source_id_t  [NUM_COUNTER-1:0]   source_id_mask_i,
    input  source_id_t  [NUM_COUNTER-1:0]   source_id_val_i,   
    input  port_id_t    [NUM_COUNTER-1:0]   port_id_mask_i,
    input  port_id_t    [NUM_COUNTER-1:0]   port_id_val_i,
    input  logic        [NUM_COUNTER-1:0]   event_info_en_i,
    /// This signal is only considered if `event_info_cfg.event_info_en` is 0.
    /// Signifies whether the counter should be incremented in this clock cycle.
    output incr_val_t   [NUM_COUNTER-1:0]   incr_val_o,
    /// This signal is only considered if `event_info_cfg.event_info_en` is 1.
    /// Signifies that the counter is configured to operate on event_info.
    output logic        [NUM_COUNTER-1:0]   event_info_ctrl_o,
    output pmu_pkg::event_info_t [NUM_COUNTER-1:0]   event_info_val_o
);

    genvar i;
    logic                 [NUM_PORT-1:0][NUM_COUNTER-1:0] incr_en_d;
    logic                 [NUM_PORT-1:0][NUM_COUNTER-1:0] incr_en_q;
    logic                 [NUM_PORT-1:0][NUM_COUNTER-1:0] event_info_port_ctrl_d;
    logic                 [NUM_PORT-1:0][NUM_COUNTER-1:0] event_info_port_ctrl_q;
    pmu_pkg::event_info_t [NUM_PORT-1:0][NUM_COUNTER-1:0] event_info_port_val_d;
    pmu_pkg::event_info_t [NUM_PORT-1:0][NUM_COUNTER-1:0] event_info_port_val_q;

    for (i=0; i<NUM_PORT; i=i+1) begin
        pmu_port #(
            .NUM_COUNTER        ( NUM_COUNTER               ),
            .PORT_ID            ( i+1                       ),
            .EVENT_INFO_BITS    ( EVENT_INFO_BITS           )
        ) i_pmu_port_1 (
            .clk_i              ( clk_i                     ),
            .rst_ni             ( rst_ni                    ),
            .port_i             ( port_i[i]                 ),
            // Event Specifiers - Filters events for each counter.
            .event_id_mask_i    ( event_id_mask_i           ),
            .event_id_val_i     ( event_id_val_i            ),
            .source_id_mask_i   ( source_id_mask_i          ),
            .source_id_val_i    ( source_id_val_i           ),
            .port_id_mask_i     ( port_id_mask_i            ),
            .port_id_val_i      ( port_id_val_i             ),
            // `eventInfo_en` signal.
            .event_info_en_i    ( event_info_en_i           ),
            // Counter Update signals.
            .incr_en_o          ( incr_en_d[i]              ),  // Indices are `PORT_ID-1`.
            .event_info_ctrl_o  ( event_info_port_ctrl_d[i] ),
            .event_info_val_o   ( event_info_port_val_d[i]  )
        );
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            incr_en_q               <= 0;
            event_info_port_ctrl_q  <= 0;
            event_info_port_val_q   <= 0;
        end else begin
            incr_en_q               <= incr_en_d;
            event_info_port_ctrl_q  <= event_info_port_ctrl_d;
            event_info_port_val_q   <= event_info_port_val_d;
        end
    end



    // pmu_port #(
    //     .NUM_COUNTER        ( NUM_COUNTER               ),
    //     .PORT_ID            ( 1                         ),
    //     .EVENT_INFO_BITS    ( EVENT_INFO_BITS           )
    // ) i_pmu_port_1 (
    //     .clk_i              ( clk_i                     ),
    //     .rst_ni             ( rst_ni                    ),
    //     .port_i             ( port_1_i                  ),
    //     // Event Specifiers - Filters events for each counter.
    //     .event_id_mask_i    ( event_id_mask_i           ),
    //     .event_id_val_i     ( event_id_val_i            ),
    //     .source_id_mask_i   ( source_id_mask_i          ),
    //     .source_id_val_i    ( source_id_val_i           ),
    //     .port_id_mask_i     ( port_id_mask_i            ),
    //     .port_id_val_i      ( port_id_val_i             ),
    //     // `eventInfo_en` signal.
    //     .event_info_en_i    ( event_info_en_i           ),
    //     // Counter Update signals.
    //     .incr_en_o          ( incr_en[0]                ),  // Indices are `PORT_ID-1`.
    //     .event_info_ctrl_o  ( event_info_port_ctrl[0]   ),
    //     .event_info_val_o   ( event_info_port_val[0]    )
    // );

    // pmu_port #(
    //     .NUM_COUNTER        ( NUM_COUNTER               ),
    //     .PORT_ID            ( 2                         ),
    //     .EVENT_INFO_BITS    ( EVENT_INFO_BITS           )
    // ) i_pmu_port_2 (
    //     .clk_i              ( clk_i                     ),
    //     .rst_ni             ( rst_ni                    ),
    //     .port_i             ( port_2_i                  ),
    //     // Event Specifiers - Filters events for each counter.
    //     .event_id_mask_i    ( event_id_mask_i           ),
    //     .event_id_val_i     ( event_id_val_i            ),
    //     .source_id_mask_i   ( source_id_mask_i          ),
    //     .source_id_val_i    ( source_id_val_i           ),
    //     .port_id_mask_i     ( port_id_mask_i            ),
    //     .port_id_val_i      ( port_id_val_i             ),
    //     // `eventInfo_en` signal.
    //     .event_info_en_i    ( event_info_en_i           ),
    //     // Counter Update signals.
    //     .incr_en_o          ( incr_en[1]                ),  // Indices are `PORT_ID-1`.
    //     .event_info_ctrl_o  ( event_info_port_ctrl[1]   ),
    //     .event_info_val_o   ( event_info_port_val[1]    )
    // );

    // `incr_en_o` from every port is added here to generate the final increment value.
    for(i=0; i<NUM_COUNTER; i=i+1) begin     
        always_comb begin    
            incr_val_o[i] = 0;
            for (integer j=0; j<NUM_PORT; j=j+1) begin
                incr_val_o[i] += incr_en_q[j][i];
            end
        end
    end

    // Logic to select the `eventInfo` from the correct port. 
    for(i=0; i<NUM_COUNTER; i=i+1) begin     
        always_comb begin    
            event_info_val_o[i]  = 0;
            event_info_ctrl_o[i] = 1'b0;
            for (integer j=0; j<NUM_PORT; j=j+1) begin
                // If `event_info_port_ctrl` of counter `i` is set for port `j`,
                // then `event_info_val_o` for counter `i` <= `event_info` from port `j`.

                // If `event_info_port_ctrl` of counter `i` is set for multiple ports then
                // based on the logic the port with higher ID is given higher priority. But
                // specification-wise, the behaviour is undefined.
                if (event_info_port_ctrl_q[j][i]) begin
                    event_info_val_o[i]  = event_info_port_val_q[j];
                    event_info_ctrl_o[i] = 1'b1;
                end
            end
        end
    end

endmodule
