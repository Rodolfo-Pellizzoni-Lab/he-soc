module pmu_port import pmu_pkg::*; #(
    parameter int unsigned NUM_COUNTER      = 32,
    parameter int unsigned PORT_ID          = 0,
    /// Specifies how many bits are used for `event_info`.
    parameter int unsigned EVENT_INFO_BITS  = 16,
    parameter type         event_info_t     = logic [EVENT_INFO_BITS-1:0]
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    /// PMU Event Interface
    input pmu_event_t                       port_i,
    /// Event Specifiers - Filters events for each counter.
    input  event_id_t   [NUM_COUNTER-1:0]   event_id_mask_i,
    input  event_id_t   [NUM_COUNTER-1:0]   event_id_val_i,   
    input  source_id_t  [NUM_COUNTER-1:0]   source_id_mask_i,
    input  source_id_t  [NUM_COUNTER-1:0]   source_id_val_i,   
    input  port_id_t    [NUM_COUNTER-1:0]   port_id_mask_i,
    input  port_id_t    [NUM_COUNTER-1:0]   port_id_val_i,
    /// If this signal is set then the counter is updated according to
    /// operation selected in `event_info_cfg` register.
    input  logic        [NUM_COUNTER-1:0]   event_info_en_i,
    /// This signal is only considered if `event_info_cfg.event_info_en` is 0.
    /// Signifies whether the counter should be incremented in this clock cycle.
    output logic        [NUM_COUNTER-1:0]   incr_en_o,
    /// This signal is only considered if `event_info_cfg.event_info_en` is 1.
    /// Signifies that the counter is configured to operate on event_info.
    output logic        [NUM_COUNTER-1:0]   event_info_ctrl_o,
    output event_info_t [NUM_COUNTER-1:0]   event_info_val_o
);

    logic [NUM_COUNTER-1:0] event_id_sel;
    logic [NUM_COUNTER-1:0] source_id_sel;
    logic [NUM_COUNTER-1:0] port_id_sel;
    
    genvar i;

    // Combinational block to generate enable signals for counters.
    for(i=0; i<NUM_COUNTER; i=i+1) begin
        assign event_info_val_o[i] = port_i.e_info;

        always_comb begin
            event_id_sel[i] = 1'b0;
            if ((event_id_mask_i[i] & port_i.e_id) == event_id_val_i[i]) begin
                event_id_sel[i] = 1'b1;
            end
        end

        always_comb begin
            source_id_sel[i] = 1'b0;
            if ((source_id_mask_i[i] & port_i.s_id) == source_id_val_i[i]) begin
                source_id_sel[i] = 1'b1;
            end
        end

        always_comb begin
            port_id_sel[i] = 1'b0;
            if ((port_id_mask_i[i] & PORT_ID) == port_id_val_i[i]) begin
                port_id_sel[i] = 1'b1;
            end
        end

        always_comb begin
            incr_en_o[i]         = 1'b0;
            event_info_ctrl_o[i] = 1'b0;

            // If `event_id_val_i` is 0 then the counter is considered disabled.
            if (event_id_val_i[i] != '0) begin
                if (event_id_sel[i] && source_id_sel[i] && port_id_sel[i]) begin
                    incr_en_o[i]           = !event_info_en_i[i];
                    event_info_ctrl_o[i]   = event_info_en_i[i];
                end
            end    
        end
    end

endmodule
