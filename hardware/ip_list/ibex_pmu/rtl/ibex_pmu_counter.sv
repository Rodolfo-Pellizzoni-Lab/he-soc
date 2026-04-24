module apmu_ibex_pmu_counter (
    input   logic                   clk_i,
    input   logic                   rst_ni,

    // counter interface 
    output  apmu_ibex_pkg::pmc_op_e      counter_op_o,
    input   logic                   counter_gnt_i,
    input   logic                   counter_rvalid_i,
    input   logic                   counter_err_i,
    
    output  logic [31:0]            counter_addr_o,
    output  logic                   counter_we_o,
    output  logic [31:0]            counter_wdata_o,
    input   logic [31:0]            counter_rdata_i,

    // signals to/from ID/EX stage
    input   logic                   pmc_we_i,          // write enable
    input   logic [31:0]            pmc_wdata_i,       // data to write to counter

    output  logic [31:0]            pmc_rdata_o,       // requested data
    output  logic                   pmc_rdata_valid_o,
    input   logic                   pmc_req_i,         // counter request, is 0 if the core is stalled due to branch mispredictions, etc.
    input   apmu_ibex_pkg::pmc_op_e      pmc_op_i,          // counter operation
    input   logic [31:0]            adder_result_ex_i, // address computed in ALU

    output  logic                   pmc_resp_valid_o     // Counter Unit has response from transaction
);
    import apmu_ibex_pkg::*;

    typedef enum logic [2:0]  {
        FSM_IDLE, FSM_RW_REQ, FSM_WFX
    } pmc_fsm_e;

    pmc_fsm_e pmc_fsm_cs, pmc_fsm_ns;

    logic ctrl_update;
    logic counter_we_q;
    
    // Is the current data request a read or write?
    // Needed when the PMU responds in the next clock cycle
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            counter_we_q <= 1'b0;
        end else if (ctrl_update) begin
            counter_we_q <= pmc_we_i;
        end
    end


    /////////////
    // PMC FSM //
    /////////////

    always_comb begin
        pmc_fsm_ns      = pmc_fsm_cs;

        counter_op_o    = PMC_IDLE;
        ctrl_update     = 1'b0;

        unique case (pmc_fsm_cs)
            FSM_IDLE: begin
                // Only execute a new counter operation if the request is valid and
                // the counter interface is ready (grant signal).
                if (counter_gnt_i && pmc_req_i) begin
                    counter_op_o    = pmc_op_i;
                    unique case (pmc_op_i)
                        PMC_IDLE: ;
                        PMC_REQ: begin                    
                            ctrl_update     = 1'b1;
                            pmc_fsm_ns      = FSM_RW_REQ;
                        end

                        PMC_WFP, PMC_WFO: begin
                            pmc_fsm_ns      = FSM_WFX;
                        end
                    endcase
                end
            end

            FSM_RW_REQ: begin
                if (counter_rvalid_i) begin
                    pmc_fsm_ns              = FSM_IDLE;
                end
            end

            FSM_WFX: begin
                counter_op_o                = pmc_op_i;
                if (counter_rvalid_i) begin
                    pmc_fsm_ns              = FSM_IDLE;
                    counter_op_o            = PMC_IDLE;
                end
            end

            default: ;
        endcase
    end


    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pmc_fsm_cs <= FSM_IDLE;
        end else begin
            pmc_fsm_cs <= pmc_fsm_ns;
        end
    end

    /////////////
    // Outputs //
    /////////////

    // To the decoder stage, this signal un-stalls the core
    always_comb begin
        pmc_resp_valid_o    = 1'b0;
        unique case (pmc_fsm_cs)
            FSM_RW_REQ, FSM_WFX: begin
                if (counter_rvalid_i) begin
                    pmc_resp_valid_o    = 1'b1;
                end
            end
            default: ;
        endcase
    end

    always_comb begin
        pmc_rdata_valid_o    = 1'b0;
        unique case (pmc_fsm_cs)
            // WB to register file only on reads.
            FSM_RW_REQ: begin
                if (counter_rvalid_i & ~counter_we_q) begin
                    pmc_rdata_valid_o    = 1'b1;
                end
            end
            // WB to register file on WFP / WFO.
            FSM_WFX: begin
                if (counter_rvalid_i) begin
                    pmc_rdata_valid_o    = 1'b1;
                end
            end
            default: ;
        endcase
    end

    // output to register file
    assign pmc_rdata_o          = counter_rdata_i;

    // output to counter interface
    assign counter_addr_o       = adder_result_ex_i;
    assign counter_wdata_o      = pmc_wdata_i;
    assign counter_we_o = pmc_we_i;

endmodule