/// Only four events that can update a counter. The word `event` here does not mean the events that the PMU is counting. 
/// They are in order of priority:
/// 1. A write from the PMU core,
/// 2. An AXI4-Lite write from one of the application core, !!!THIS EVENT CURRENTLY DOES NOT SET THE PENDING BIT!!!
/// 3. A new MemGuard round has started.
/// 4. A counter increment because a selected event for the counter was transmitted to the PMU by one of the specified ports.
///
/// In cases 1, 3 and 4, the axi_lite_regs is unaware of the update to the counter. The pmu_counter_unit module must inform
/// the axi_lite_regs by updating the axi_reg_load_i (register load enable) bits.
/// pmu_counter ignores the counter update from an event if a higher-priority event is observed in that clock cycle.
///
/// The Pending bit is treated separately in the module. All the counters are (XLEN-1)-bits.
///
/// NOTE: The comments above assume that XLEN = 32 here!
module pmu_counter import pmu_pkg::*; #(
    // Specifies what value the counter should be incremented by.
    parameter int unsigned NUM_PORT   = 0,
    parameter int unsigned INCR_BIT   = $clog2(NUM_PORT)+1,
    parameter type         incr_val_t = logic [INCR_BIT-1:0],
    // Counter-specific parameters.
    parameter type counter_t          = logic,
    parameter type strb_counter_t     = logic,
    parameter int unsigned XLEN       = 32,
    parameter int unsigned XLEN_STRB  = 8    // XLEN_STRB must always be XLEN/8
) (
    /// Rising-edge clock of all ports
    input  logic                    clk_i,
    /// Asynchronous reset, active low
    input  logic                    rst_ni,
    /// Signals that a byte is being written from the AXI4-Lite port in the current clock cycle. This
    /// signal is asserted regardless of the value of `AxiReadOnly`.
    input  strb_counter_t           axi_wr_active_i,
    /// Signals counter operation requested by the PMU core. 
    input  apmu_ibex_pkg::pmc_op_e       core_counter_op_i,
    /// Signals the write data from the PMU core that is to be written into the counter.
    input  logic [31:0]             core_counter_wdata_i,
    /// `event_info_cfg` register.
    input  event_info_cfg_t         event_info_cfg_i,
    /// Signals that a selected event was transmitted to the PMU and the counter should increment by a value.
    /// This signal is only considered if `event_info_cfg.event_info_en` is 0.
    input  incr_val_t               incr_val_i,
    /// Signals that a selected event was transmitted to the PMU and the counter should operate on event_info.
    /// This signal is only considered if `event_info_cfg.event_info_en` is 1.
    input  logic                    event_info_ctrl_i,
    input  pmu_pkg::event_info_t    event_info_val_i,
    /// Load enable of each byte.
    ///
    /// If `reg_load_i` is `1` for a byte defined as non-read-only in a clock cycle, an AXI4-Lite
    /// write transaction is stalled when it tries to write the same byte.  That is, a write
    /// transaction is stalled if all of the following conditions are true for the byte at index `i`:
    /// - `AxiReadOnly[i]` is `0`,
    /// - `reg_load_i[i]` is `1`,
    /// - the bit in `axi_req_i.w.strb` that affects the byte is `1`.
    ///
    /// If unused, set this input to `'0`.
    /// If these bits are set then counter_q_i will be written to the corresponding counter in the axi_lite_regs.
    output strb_counter_t           axi_reg_load_o,     
    /// Signals whether a new MemGuard round has started or not.
    input  logic                    memguard_reset_i,
    /// The counters are 31-bit wide. Therefore the initial budget register must also be 31-bit.
    /// Transmits the value of the initial budget register.
    input  counter_t                init_budget_i,
    /// The counters are 31-bit wide. The 31st bit is the Pending bit and cannot be written to by software.
    /// Output reg_q_o of the axi_lite_regs module.
    input  counter_t                counter_q_i,
    /// The counters are 31-bit wide. The 31st bit is the Pending bit and cannot be written to by software.
    /// Input reg_d_o of the axi_lite_regs module. 
    output counter_t                counter_d_o
);

    // counter[30] is the Overflow bit.
    // counter[31] is the Pending bit.
    // The pending bit needs additional logic to work but the overflow bit works with 
    // the standard addition operations of the counter.
    logic pending_i;
    logic pending_o;

    logic [XLEN-2:0]    counter_i;
    logic [XLEN-2:0]    counter_o;

    logic  event_info_ctrl_d;
    logic  event_info_ctrl_q;
    eisf_t eisf_start;
    eisf_t eisf_end;
    val_t  val_upper;
    val_t  val_lower;

    // After isolating the specified sub-field using EISF bits,
    // the result is stored in `event_info_isol`.
    pmu_pkg::event_info_t event_info_mask;
    pmu_pkg::event_info_t event_info_isol_d;
    pmu_pkg::event_info_t event_info_isol_q;

    // ************************************************************************
    // Inputs
    // ************************************************************************
    assign counter_i    = counter_q_i.counter;
    assign pending_i    = counter_q_i.pending;

    // ************************************************************************
    // Outputs
    // ************************************************************************
    assign counter_d_o.counter  = counter_o;
    assign counter_d_o.pending  = pending_o;

    // ************************************************************************
    // EventInfo Logic
    // ************************************************************************
    assign eisf_start = event_info_cfg_i.eisf_start;
    assign eisf_end   = event_info_cfg_i.eisf_end;
    assign val_upper  = event_info_cfg_i.val_u;
    assign val_lower  = event_info_cfg_i.val_l;
    
    assign event_info_ctrl_d = event_info_ctrl_i;

    // Stage 1 - Isolated sub-field from `event_info`.
    // Both `end` and `start` bits are included, considering 0th indexing.
    always_comb begin
        event_info_mask   = (1 << (eisf_end - eisf_start + 1)) - 1;
        event_info_mask   = event_info_mask << eisf_start;
        event_info_isol_d = (event_info_val_i & event_info_mask) >> eisf_start;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            event_info_isol_q <= '0;
        end else begin
            event_info_isol_q <= event_info_isol_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            event_info_ctrl_q <= '0;
        end else begin
            event_info_ctrl_q <= event_info_ctrl_d;
        end
    end

    // ************************************************************************
    // Counter Update FSM 
    // ************************************************************************
    always_comb begin
        pending_o           = pending_i;
        axi_reg_load_o      = 1'b0;

        counter_o           = counter_i;

        unique case (core_counter_op_i) 
            // If the core has no pending request then serve requests from other modules.
            apmu_ibex_pkg::PMC_IDLE, apmu_ibex_pkg::PMC_WFP: begin            
                // // Check if an AXI4-Lite write happening to the counter in the current clock cycle.
                // // If yes then do not update the counter on a MemGuard reset or counter increment.
                // // The output of the axi_lite_regs is fed back as input.
                // if (|axi_wr_active_i) begin
                //     // Let the AXI4-Lite write go through. 
                //     ;
                // Check if a new MemGuard round has started.
                // Update counter_q to initBudgetReg.
                // Update reg_load_i.StrbMap.counter to indicate a non-AXI write to counter.
                if (memguard_reset_i) begin
                    pending_o       = 1'b1;       
                    axi_reg_load_o  = {XLEN_STRB{1'b1}};
                    counter_o       = init_budget_i;
                // Check if a selected event for this counter was transmitted to the PMU in this clock cycle.
                // Increment the counter.
                end else if (event_info_ctrl_q) begin                           
                    axi_reg_load_o  = {XLEN_STRB{1'b1}};
                    
                    // Stage 2 - Apply operation specified by `event_info_cfg` register.
                    unique case (event_info_cfg_i.opcode)
                        ADD: begin 
                            counter_o = counter_i + event_info_isol_q;
                            pending_o = 1'b1;
                        end

                        KEEP_MAX: begin
                            if (counter_i < event_info_isol_q) begin
                                counter_o = event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        KEEP_MIN: begin
                            if (event_info_isol_q > counter_i) begin
                                counter_o = event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_EQ: begin
                            if (event_info_isol_q == val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_NEQ: begin
                            if (event_info_isol_q != val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_LT: begin
                            if (event_info_isol_q < val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_GT: begin
                            if (event_info_isol_q > val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_LTE: begin
                            if (event_info_isol_q <= val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_CMP_GTE: begin
                            if (event_info_isol_q >= val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_IN_RANGE: begin
                            if ((event_info_isol_q >= val_lower) && (event_info_isol_q <= val_upper)) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        INCR_NOT_IN_RANGE: begin
                            if ((event_info_isol_q < val_lower) || (event_info_isol_q > val_upper)) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_EQ: begin
                            if (event_info_isol_q == val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_NEQ: begin
                            if (event_info_isol_q != val_lower) begin
                                counter_o = counter_i + 1;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_LT: begin
                            if (event_info_isol_q < val_lower) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_GT: begin
                            if (event_info_isol_q > val_lower) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_LTE: begin
                            if (event_info_isol_q <= val_lower) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_CMP_GTE: begin
                            if (event_info_isol_q >= val_lower) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_IN_RANGE: begin
                            if ((event_info_isol_q >= val_lower) && (event_info_isol_q <= val_upper)) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end

                        ADD_NOT_IN_RANGE: begin
                            if ((event_info_isol_q < val_lower) || (event_info_isol_q > val_upper)) begin
                                counter_o = counter_i + event_info_isol_q;
                                pending_o = 1'b1;
                            end
                        end
                    endcase
                end else if (|incr_val_i) begin
                    pending_o       = 1'b1;       
                    axi_reg_load_o  = {XLEN_STRB{1'b1}};
                    counter_o       = counter_i + incr_val_i;
                end
                
                // Reset pending bit if WFP instruction is running.
                // `pending_i` is the registered value of the pending bit.
                if ((core_counter_op_i == apmu_ibex_pkg::PMC_WFP) && pending_i) begin
                    pending_o       = 1'b0;
                    axi_reg_load_o  = {XLEN_STRB{1'b1}};
                end
            end
            // Only writes are sent to the pmu_counter module.
            apmu_ibex_pkg::PMC_REQ: begin
                counter_o       = core_counter_wdata_i;
                // To do: should i just set the last strobe bit?
                axi_reg_load_o  = {XLEN_STRB{1'b1}};
            end
            default: ;
        endcase
    end

endmodule