// (F1) Stability Rule: Once valid is high, valid and the payload must not change until the handshake occurs.
// (F2) Acyclicity Rule: The channel slave may depend on valid to be high before setting ready high, but the 
//      channel master may not depend on ready to be high before setting valid high.

module pmu_core 
    import pmu_pkg::*;
#(
    // PMU_REG Configuration
    parameter int unsigned  PMU_REG_START_ADDR = 0,
    parameter int unsigned  PMU_REG_LENGTH     = 0,

    // System Memory Configuration
    parameter int unsigned  MEMORY_BASE_ADDR   = 0,
    parameter int unsigned  MEMORY_LENGTH      = 0,

    // ISPM Configuration    
    parameter int unsigned  ISPM_BASE_ADDR     = 0,
    parameter int unsigned  ISPM_NumBytes      = 0,

    // DSPM Configuration
    parameter int unsigned  DSPM_BASE_ADDR     = 0,
    parameter int unsigned  DSPM_NumBytes      = 0,
    
    // Typedefs
    parameter type  req_t       = logic,
    parameter type  resp_t      = logic,
    parameter type  req_lite_t  = logic,
    parameter type  resp_lite_t = logic,
    parameter type  pmc_op_e    = logic,

    // DO NOT CHANGE THESE PAREMETERS unless
    // you are extending the entire PMU to 64-bits!
    parameter type  addr_t      = logic [31:0],
    parameter type  data_t      = logic [31:0],
    parameter type  strb_t      = logic [3:0]
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Counter Interface Signals
    output pmc_op_e     core_counter_op_o,
    output logic        core_counter_we_o,
    output addr_t       core_counter_addr_o,
    output data_t       core_counter_wdata_o,

    input  logic        core_counter_gnt_i,
    input  logic        core_counter_err_i,
    input  logic        core_counter_rvalid_i,
    input  data_t       core_counter_rdata_i,

    // Boot address for PMU core
    input  addr_t       pmc_boot_addr_i,

    // Stall PMU core
    input  logic        stall_core_i,

    input  req_lite_t   ispm_req_i,     // from AXI4-Lite XBar to ISPM
    output resp_lite_t  ispm_resp_o,    // from ISPM to AXI4-Lite XBar

    input  req_lite_t   dspm_req_i,     // from AXI4-Lite XBar to DSPM
    output resp_lite_t  dspm_resp_o,    // from DSPM to AXI4-Lite XBar

    output req_lite_t   pmc_req_o,      // from PMU Core to AXI4-Lite XBar
    input  resp_lite_t  pmc_resp_i      // from AXI4-Lite XBar to PMU Core
);

    // ************************************************************************
    // PMU Core Signals
    // ************************************************************************
    addr_t  core_instr_addr;
    logic   core_instr_req;
    data_t  core_instr_rdata;
    logic   core_instr_gnt;
    logic   core_instr_rvalid;
    logic   core_instr_err;

    logic   core_instr_ar_valid;
    logic   ispm_busy_d;
    logic   ispm_busy_q;

    data_t  core_counter_rdata_d;
    logic   core_counter_rvalid_d;
    logic   core_counter_err_d;
    logic   core_counter_gnt_d;

    addr_t  core_data_addr;
    logic   core_data_req;
    logic   dspm_busy_d;
    logic   dspm_busy_q;

    // In case the core changes `data_be_o`.
    strb_t  core_data_be;
    data_t  core_data_rdata;
    logic   core_data_we;
    logic   core_data_gnt;
    data_t  core_data_wdata;
    logic   core_data_rvalid;
    logic   core_data_err;

    logic   pmc_dspm_req;
    addr_t  pmc_dspm_addr;
    logic   pmc_dspm_we;
    strb_t  pmc_dspm_be;
    data_t  pmc_dspm_wdata;
    logic   pmc_dspm_gnt;
    logic   pmc_dspm_rvalid;
    data_t  pmc_dspm_rdata;
    logic   pmc_dspm_err;

    logic   pmc_axi_lite_req;
    addr_t  pmc_axi_lite_addr;
    logic   pmc_axi_lite_we;
    strb_t  pmc_axi_lite_be;
    data_t  pmc_axi_lite_wdata;
    logic   pmc_axi_lite_gnt;
    logic   pmc_axi_lite_rvalid;
    data_t  pmc_axi_lite_rdata;
    logic   pmc_axi_lite_err;

    // Index bits for PMC Data Target, the different modules that the PMU core can 
    // access using its data port (via Load/Store instructions).
    localparam int unsigned ADDR_DEC_IDX_BITS = (pmu_pkg::VALID_PMC_DATA_TARGET == 1) ? 
                                                1 : $clog2(pmu_pkg::VALID_PMC_DATA_TARGET);
    typedef logic [ADDR_DEC_IDX_BITS-1:0]   dec_idx_t;

    dec_idx_t           dec_pmc_data_idx;
    logic               dec_pmc_data_valid;
    logic               dec_pmc_data_error;
    dec_idx_t           dec_default_idx;

    // Stores the target of the current active PMU core data request.
    pmc_data_target_e   target_d;
    pmc_data_target_e   target_q;

    // Unused signals
    logic               test_en_i;
    logic [31:0]        hard_id;

    logic               irq_software_i;
    logic               irq_timer_i;
    logic               irq_external_i;
    logic [14:0]        irq_fast_i;
    logic               irq_nm_i;
    logic [31:0]        irq_x_i;
    logic               irq_x_ack_o;
    logic [4:0]         irq_x_ack_id_o;
    logic [15:0]        external_perf_i;
    logic               debug_req_i;

    logic               fetch_enable_i;
    logic               alert_minor_o;
    logic               alert_major_o;
    logic               core_sleep_o;

    // ************************************************************************
    // Instruction SPM
    // ************************************************************************
    
    pmu_ispm #(
        .NumBytes           ( ISPM_NumBytes     ),
        .ReadLatency        ( 1                 ),
        .START_ADDR         ( ISPM_BASE_ADDR    ),
        .req_lite_t         ( req_lite_t        ),
        .resp_lite_t        ( resp_lite_t       )
    ) i_pmu_ispm (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .pmc_instr_addr_i   ( core_instr_addr   ),
        .pmc_instr_req_i    ( core_instr_req    ),
        .pmc_instr_rdata_o  ( core_instr_rdata  ),
        .pmc_instr_gnt_o    ( core_instr_gnt    ),
        .pmc_instr_rvalid_o ( core_instr_rvalid ),
        .pmc_instr_err_o    ( core_instr_err    ),
        .axi_req_i          ( ispm_req_i        ),
        .axi_resp_o         ( ispm_resp_o       )
    );

    // ************************************************************************
    // Targets of the Data Port
    // ************************************************************************
    pmu_pkg::addr_map_rule_t [VALID_PMC_DATA_TARGET-1:0]   addr_map;

    assign addr_map[pmu_pkg::DSPM] = '{
        idx: pmu_pkg::DSPM,
        start_addr: DSPM_BASE_ADDR,
        end_addr:   DSPM_BASE_ADDR + DSPM_NumBytes
    };

    assign addr_map[pmu_pkg::PMU_REG] = '{
        idx: pmu_pkg::PMU_REG,
        start_addr: PMU_REG_START_ADDR,
        end_addr:   PMU_REG_START_ADDR + PMU_REG_LENGTH
    };

    assign addr_map[pmu_pkg::SYSTEM_MEMORY] = '{
        idx: pmu_pkg::SYSTEM_MEMORY,
        start_addr: MEMORY_BASE_ADDR,
        end_addr:   MEMORY_BASE_ADDR + MEMORY_LENGTH
    };

    assign dec_default_idx = dec_idx_t'(pmu_pkg::PMU_REG);
    addr_decode #(
      .NoIndices        ( 3                           ),
      .NoRules          ( 3                           ),
      .addr_t           ( addr_t                      ),
      .rule_t           ( pmu_pkg::addr_map_rule_t    )
    ) i_pmc_data_decode (
      .addr_i           ( core_data_addr              ),
      .addr_map_i       ( addr_map                    ),
      .idx_o            ( dec_pmc_data_idx            ),
      .dec_valid_o      ( dec_pmc_data_valid          ),
      .dec_error_o      ( dec_pmc_data_error          ),
      .en_default_idx_i ( 1'b1                        ),
      // Default is DSPM.
      .default_idx_i    ( dec_default_idx             )  
    );

    // These signals directly go to the PMU-DSPM module.
    assign pmc_dspm_addr      = core_data_addr;
    assign pmc_dspm_req       = core_data_req && dec_pmc_data_valid && (dec_pmc_data_idx == pmu_pkg::DSPM);
    assign pmc_dspm_we        = core_data_we;
    assign pmc_dspm_be        = core_data_be;
    assign pmc_dspm_wdata     = core_data_wdata;
    // This signals are sent to the `gnt_to_axi_lite` converter,
    // then forwarded to AXI4-Lite Internal XBar of the PMU.
    assign pmc_axi_lite_addr  = core_data_addr;
    assign pmc_axi_lite_req   = core_data_req && dec_pmc_data_valid && 
                               ((dec_pmc_data_idx == pmu_pkg::PMU_REG) || 
                                (dec_pmc_data_idx == pmu_pkg::SYSTEM_MEMORY));
    assign pmc_axi_lite_we    = core_data_we;
    assign pmc_axi_lite_be    = core_data_be;
    assign pmc_axi_lite_wdata = core_data_wdata;

    // Stores the target of the current active PMU core data request.
    // To Do: Do we need an IDLE?
    always_comb begin
        target_d = target_q;
        if (dec_pmc_data_valid && (dec_pmc_data_idx == pmu_pkg::DSPM)) begin
            target_d = pmu_pkg::DSPM;
        end else if (dec_pmc_data_valid && (dec_pmc_data_idx == pmu_pkg::PMU_REG)) begin
            target_d = pmu_pkg::PMU_REG;
        end else if (dec_pmc_data_valid && (dec_pmc_data_idx == pmu_pkg::SYSTEM_MEMORY)) begin
            target_d = pmu_pkg::SYSTEM_MEMORY;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            target_q <= pmu_pkg::IDLE; 
        end else begin
            target_q <= target_d;
        end
    end

    // Inputs to the data port of the PMU core.
    assign core_data_rvalid = pmc_dspm_rvalid || pmc_resp_i.r_valid || pmc_resp_i.b_valid || dec_pmc_data_error;
    always_comb begin
        core_data_rdata = '0;
        core_data_err   = dec_pmc_data_error;
        if (pmc_dspm_rvalid) begin
            core_data_rdata = pmc_dspm_rdata;
        end else if (pmc_resp_i.r_valid || pmc_resp_i.b_valid) begin
            core_data_rdata = pmc_resp_i.r.data;
            if ((pmc_resp_i.r.resp == axi_pkg::RESP_OKAY) || 
                (pmc_resp_i.r.resp == axi_pkg::RESP_EXOKAY)) begin
                core_data_err = 1'b0;
            end else begin
                core_data_err = 1'b1;
            end
        end
    end
    // Route core_data_gnt from whichever subsystem the current request was sent to.
    // Using pmc_dspm_req / pmc_axi_lite_req as selectors (both already gated by
    // core_data_req and dec_pmc_data_valid) prevents the DSPM's default gnt=1
    // from leaking through when no DSPM request is active — the root cause of the
    // spurious-grant / axi_lite_from_mem assertion failure seen with target_q routing.
    always_comb begin
        core_data_gnt = 1'b0;
        if (pmc_dspm_req) begin
            core_data_gnt = pmc_dspm_gnt;
        end else if (pmc_axi_lite_req) begin
            core_data_gnt = pmc_axi_lite_gnt;
        end
    end

    // Target: DSPM
    pmu_dspm #(
        .NumBytes           ( DSPM_NumBytes     ),
        .ReadLatency        ( 1                 ),
        .START_ADDR         ( DSPM_BASE_ADDR    ),
        .req_lite_t         ( req_lite_t        ),
        .resp_lite_t        ( resp_lite_t       )
    ) i_pmu_dspm (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        .pmc_data_req_i     ( pmc_dspm_req      ),
        .pmc_data_addr_i    ( pmc_dspm_addr     ),
        .pmc_data_we_i      ( pmc_dspm_we       ),
        .pmc_data_be_i      ( pmc_dspm_be       ),
        .pmc_data_wdata_i   ( pmc_dspm_wdata    ),
        .pmc_data_gnt_o     ( pmc_dspm_gnt      ),
        .pmc_data_rvalid_o  ( pmc_dspm_rvalid   ),
        .pmc_data_rdata_o   ( pmc_dspm_rdata    ),
        .pmc_data_err_o     ( pmc_dspm_err      ),
        .axi_req_i          ( dspm_req_i        ),
        .axi_resp_o         ( dspm_resp_o       )
    );

    // This module converts between AXI and Grant protocol.
    axi_lite_from_mem #(
        .MemAddrWidth           ( 32                    ),
        .AxiAddrWidth           ( 32                    ),
        .DataWidth              ( 32                    ),
        .MaxRequests            ( 2                     ),
        // Typedefs
        .axi_req_t              ( req_lite_t            ),
        .axi_rsp_t              ( resp_lite_t           )
    ) i_pmu_gnt_to_axi_lite (
        .clk_i                  ( clk_i                 ),
        .rst_ni                 ( rst_ni                ),
        // Grant-protocol related signals (from/to the PMU core)
        .mem_req_i              ( pmc_axi_lite_req      ),
        .mem_addr_i             ( pmc_axi_lite_addr     ),
        .mem_we_i               ( pmc_axi_lite_we       ),
        .mem_wdata_i            ( pmc_axi_lite_wdata    ),
        .mem_be_i               ( pmc_axi_lite_be       ),
        .mem_gnt_o              ( pmc_axi_lite_gnt      ),
        .mem_rsp_valid_o        ( pmc_axi_lite_rvalid   ),
        .mem_rsp_rdata_o        ( pmc_axi_lite_rdata    ),
        .mem_rsp_error_o        ( pmc_axi_lite_err      ),
        // AXI requests and responses (for the AXI4-Lite)
        .axi_req_o              ( pmc_req_o             ),
        .axi_rsp_i              ( pmc_resp_i            )
    );

    // ************************************************************************
    // PMU Core (Ibex by lowRISC)
    // ************************************************************************
    // Must be 1.
    assign fetch_enable_i = 1'b1;
    assign hard_id        = 32'd1;
    // Must be 0.
    assign test_en_i      = 1'b0;

    // Tie all unused signals.
    assign irq_software_i = 1'b0;
    assign irq_timer_i    = 1'b0;
    assign irq_external_i = 1'b0;
    assign irq_fast_i     = 15'd0;
    assign irq_nm_i       = 1'b0;
    assign irq_x_i        = 32'd0;

    // NO INPUT REGISTERING IN CORE -- DO NOT FORGET!
    ibex_pmu_core #(
        .PMPEnable        ( 1'b0                ),
        .PMPGranularity   ( 0                   ),
        .PMPNumRegions    ( 4                   ),
        .MHPMCounterNum   ( 10                  ),
        .MHPMCounterWidth ( 40                  ),
        .BranchTargetALU  ( 1'b0                ),
        .WritebackStage   ( 1'b0                ),
        .ICache           ( 1'b0                ),
        .ICacheECC        ( 1'b0                ),
        .BranchPredictor  ( 1'b0                ),
        .DbgTriggerEn     ( 1'b1                ),
        .DbgHwBreakNum    ( 1                   ),
        .SecureIbex       ( 1'b0                )
    ) i_ibex_pmu_core (
        .clk_i            ( clk_i                  ),
        .rst_ni           ( rst_ni                 ),

        .test_en_i        ( test_en_i              ),

        .hart_id_i        ( hard_id                ),
        .boot_addr_i      ( pmc_boot_addr_i        ),
        .stall_pmu_i      ( stall_core_i           ),

        // Instruction Memory Interface
        .instr_addr_o     ( core_instr_addr        ),
        .instr_req_o      ( core_instr_req         ),
        .instr_rdata_i    ( core_instr_rdata       ),
        .instr_gnt_i      ( core_instr_gnt         ),
        .instr_rvalid_i   ( core_instr_rvalid      ),
        .instr_err_i      ( core_instr_err         ),

        // Data Memory Interface
        .data_addr_o      ( core_data_addr         ),
        .data_req_o       ( core_data_req          ),
        .data_be_o        ( core_data_be           ),
        .data_rdata_i     ( core_data_rdata        ),
        .data_we_o        ( core_data_we           ),
        .data_gnt_i       ( core_data_gnt          ),
        .data_wdata_o     ( core_data_wdata        ),
        .data_rvalid_i    ( core_data_rvalid       ),
        .data_err_i       ( core_data_err          ),

        // Counter Memory Interface
        .counter_addr_o   ( core_counter_addr_o    ),
        .counter_op_o     ( core_counter_op_o      ),
        .counter_rdata_i  ( core_counter_rdata_i   ),
        .counter_we_o     ( core_counter_we_o      ),
        .counter_gnt_i    ( core_counter_gnt_i     ),
        .counter_wdata_o  ( core_counter_wdata_o   ),
        .counter_rvalid_i ( core_counter_rvalid_i  ),
        .counter_err_i    ( core_counter_err_i     ),

        .irq_software_i   ( irq_software_i         ),
        .irq_timer_i      ( irq_timer_i            ),
        .irq_external_i   ( irq_external_i         ),
        .irq_fast_i       ( irq_fast_i             ),
        .irq_nm_i         ( irq_nm_i               ),

        // Ibex supports 32 additional fast interrupts and 
        // reads the interrupt lines directly.
        .irq_x_i          ( irq_x_i                ),
        .irq_x_ack_o      ( irq_x_ack_o            ),
        .irq_x_ack_id_o   ( irq_x_ack_id_o         ),

        .external_perf_i  ( external_perf_i        ),

        .debug_req_i      ( debug_req_i            ),

        .fetch_enable_i   ( fetch_enable_i         ),
        .alert_minor_o    ( alert_minor_o          ),
        .alert_major_o    ( alert_major_o          ),
        .core_sleep_o     ( core_sleep_o           )
    );

endmodule
