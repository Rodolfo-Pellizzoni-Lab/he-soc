// The `pmc_instr_gnt_o` logic is not tight enough. Even failed AXI4 read or writes can delay read requests from the PMU core.
// To Do: Optimize the logic around `pmc_instr_gnt_o`.
`include "axi/typedef.svh"

module pmu_ispm #(
    parameter int unsigned NumBytes     = 32'h1000,
    parameter int unsigned ReadLatency  = 1,
    parameter int unsigned START_ADDR   = 32'h1040_5000,
    parameter int unsigned AddrWidth    = (NumBytes > 32'd1) ? $clog2(NumBytes) : 32'd1,
    /// Request struct of the AXI4-Lite port.
    parameter type req_lite_t  = logic,
    /// Response struct of the AXI4-Lite port.
    parameter type resp_lite_t = logic,
    // DO NOT CHANGE THESE PAREMETERS unless
    // you are extending the entire PMU to 64-bits!
    parameter type  addr_t     = logic [31:0],
    parameter type  data_t     = logic [31:0],
    parameter type  strb_t     = logic [3:0]
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    // Signals from PMU Core
    input  addr_t       pmc_instr_addr_i,
    input  logic        pmc_instr_req_i,
    output data_t       pmc_instr_rdata_o,
    output logic        pmc_instr_gnt_o,
    output logic        pmc_instr_rvalid_o,
    output logic        pmc_instr_err_o,
    // Signals from AXI4-Lite PMU Xbar
    input  req_lite_t   axi_req_i,
    output resp_lite_t  axi_resp_o
);

    // Channel definitions for spill register
    `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_lite_t)
    `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_lite_t, data_t)
    
    // A read data is only valid after ReadLatency clock cycles.
    typedef enum {
        IDLE,   // No request, write request are serviced in one clock cycle
                // and do not need a separate state
        READ    // Servicing read request
    } axi_fsm_e;

    typedef enum {
        LAT_PLUS_ONE,       // Read data is not yet valid
        AWAIT_MRDY          // Waiting for master to be ready (r_ready)
    } read_fsm_e;

    // FSM Signals
    axi_fsm_e   axi_fsm_ns;
    axi_fsm_e   axi_fsm_cs;

    read_fsm_e  read_fsm_ns;
    read_fsm_e  read_fsm_cs;

    // Write signals
    b_chan_lite_t   b_chan;
    logic           b_valid;
    logic           b_ready;

    logic           start_axi4_write;

    // Signals whether the aw_addr is valid or not.
    logic           aw_dec_valid;

    // Read signals
    r_chan_lite_t   r_chan;
    logic           r_valid;
    logic           r_ready;

    // Signals whether the `ar_addr` is valid or not.
    logic           ar_dec_valid;
    
    logic [ReadLatency:0]   latency;
    
    // Indicates that read address (`ar_arr` or `pmc_instr_addr_i`) was not valid
    logic  read_failed_d;
    logic  read_failed_q;

    // Read requestor.
    typedef enum {
        AXI4, PMU_CORE
    } requestor_t;
    requestor_t read_requestor_d;
    requestor_t read_requestor_q;

    // Signals whether the `pmc_instr_addr_i` is valid or not.
    logic  pmc_dec_valid;

    // tc_sram signals
    logic  req;
    logic  we;
    addr_t addr;        // valid tc_sram address
    addr_t r_addr;
    addr_t w_addr;
    addr_t pmc_addr;
    data_t w_data;
    strb_t be;
    data_t r_data_sout; // output of tc_sram

    localparam ISPM_AddrWidth = (NumBytes > 32'd1) ? $clog2(NumBytes) : 32'd1;

    // Check whether the address is valid or not.
    always_comb begin
        ar_dec_valid  = 1'b0;
        aw_dec_valid  = 1'b0;
        pmc_dec_valid = 1'b0;
    
        addr     = '0;
        pmc_addr = pmc_instr_addr_i - START_ADDR;
        r_addr   = axi_req_i.ar.addr - START_ADDR;
        w_addr   = axi_req_i.aw.addr - START_ADDR;

        // Reads are prioritized over writes.
        if (r_addr < NumBytes && axi_req_i.ar_valid) begin
            addr          = addr_t'(r_addr);
            ar_dec_valid  = 1'b1;
        end else if (w_addr < NumBytes && axi_req_i.aw_valid) begin
            addr          = addr_t'(w_addr);
            aw_dec_valid  = 1'b1;
        end else if (pmc_addr < NumBytes && pmc_instr_req_i) begin
            addr          = addr_t'(pmc_addr);
            pmc_dec_valid = 1'b1;
        end
    end
    
    assign w_data = axi_req_i.w.data;

    // FSM
    // Both read and write responses are stored in spill registers to cut the combinatorial paths.

    // The SPM only starts a write when the aw_addr, w_data are valid;
    // and when the spill registers have space to store another write response.
    assign start_axi4_write = axi_req_i.aw_valid && axi_req_i.w_valid && b_ready;

    // ReadLatency = 32'd0;
    if (ReadLatency == 32'd0) begin
        always_comb begin
            // tc_sram Signals
            req = 1'b0;
            we  = 1'b0;
            be  = 1'b0;

            // Write Channel handshake
            axi_resp_o.aw_ready = 1'b0;
            axi_resp_o.w_ready  = 1'b0;

            // Write Response
            b_chan  = b_chan_lite_t'{resp: axi_pkg::RESP_SLVERR, default: '0};
            b_valid = 1'b0;

            // Read Channel handshake
            axi_resp_o.ar_ready = 1'b0;

            // Default R channel throws an error.
            r_valid = 1'b0;
            
            r_chan = r_chan_lite_t'{
                data: data_t'(32'hBA5E1E55),
                resp: axi_pkg::RESP_SLVERR,
                default: '0
            };

            // PMU core signals
            pmc_instr_gnt_o    = 1'b1;
            pmc_instr_rdata_o  = '0;
            pmc_instr_rvalid_o = 1'b0;
            pmc_instr_err_o    = 1'b0;
            
            // Reads are prioritized over writes.
            // Reads can start even before the Master is ready to claim them.
            if (axi_req_i.ar_valid && r_ready) begin
                r_valid = 1'b1;
                axi_resp_o.ar_ready = 1'b1;
                pmc_instr_gnt_o     = 1'b0;
                if (ar_dec_valid) begin
                    req = 1'b1;

                    r_chan = r_chan_lite_t'{
                        data: data_t'(r_data_sout),
                        resp: axi_pkg::RESP_OKAY,
                        default: '0
                    };
                end
            end
            // Handle load from AXI write.
            // `b_ready_q` is allowed to be a condition as it comes from a pipelined register.
            else if (start_axi4_write) begin
                pmc_instr_gnt_o = 1'b0;
                if (aw_dec_valid) begin
                    req = 1'b1;
                    we  = 1'b1;
                    be  = axi_req_i.w.strb;                    
                    // The write can be performed when these conditions are true:
                    // - AW decode is valid.
                    // - `axi_req_i.aw.prot` has the right value.
                    b_chan.resp         = axi_pkg::RESP_OKAY;
                    b_valid             = 1'b1;
                    axi_resp_o.aw_ready = 1'b1;
                    axi_resp_o.w_ready  = 1'b1;
                end else begin
                    // Send default B error response on each not allowed write transaction.
                    b_valid             = 1'b1;
                    axi_resp_o.aw_ready = 1'b1;
                    axi_resp_o.w_ready  = 1'b1;
                end
            end else if (pmc_instr_req_i) begin
                req                = pmc_dec_valid;
                pmc_instr_rvalid_o = pmc_instr_req_i;
                pmc_instr_err_o    = !pmc_dec_valid;
                pmc_instr_rdata_o  = r_data_sout;
            end
        end
    end
    // ReadLatency != 32'd0;
    else begin
        always_comb begin
            axi_fsm_ns  = axi_fsm_cs;
            read_fsm_ns = read_fsm_cs;

            // tc_sram Signals
            req         = 1'b0;
            we          = 1'b0;
            be          = 4'd0;

            // Write Channel handshake
            axi_resp_o.aw_ready = 1'b0;
            axi_resp_o.w_ready  = 1'b0;

            // Write Response
            b_chan      = b_chan_lite_t'{resp: axi_pkg::RESP_SLVERR, default: '0};
            b_valid     = 1'b0;

            // Read Channel handshake
            axi_resp_o.ar_ready = 1'b0;

            // Default R channel throws an error.
            r_valid     = 1'b0;
            latency[0]  = 1'b0;
            r_chan = r_chan_lite_t'{
                data: data_t'(32'hBA5E1E55),
                resp: axi_pkg::RESP_SLVERR,
                default: '0
            };

            // PMU core signals
            pmc_instr_gnt_o    = 1'b1;
            pmc_instr_rdata_o  = '0;
            pmc_instr_rvalid_o = 1'b0;
            pmc_instr_err_o    = 1'b0;

            // Indicates failed read.
            read_failed_d = read_failed_q;

            // This variable is only important during a read.
            read_requestor_d = read_requestor_q;

            unique case(axi_fsm_cs)
                // There is no read request in progress.
                // Can start the next read or write request.
                IDLE: begin
                    // Reads are prioritized over writes.
                    // Reads can start even before the Master is ready to claim them. Do not need to check for r_ready.
                    // Wait until the previous `axi_resp_o.r_valid` is claimed before starting a new read.
                    // `axi_resp_o.r_valid` is allowed to be a condition as it comes from a pipelined register.
                    if (axi_req_i.ar_valid && !axi_resp_o.r_valid) begin
                        axi_fsm_ns       = READ;
                        read_fsm_ns      = LAT_PLUS_ONE;
                        read_requestor_d = AXI4;
                        
                        pmc_instr_gnt_o  = 1'b0;
                        read_failed_d    = !ar_dec_valid;
                        req              = ar_dec_valid;
                        latency[0]       = 1'b1;
                    end
                    // Handle load from AXI write.
                    // `b_ready_q` is allowed to be a condition as it comes from a pipelined register.
                    else if (start_axi4_write) begin
                        pmc_instr_gnt_o = 1'b0;
                        if (aw_dec_valid) begin
                            req = 1'b1;
                            we  = 1'b1;
                            be  = axi_req_i.w.strb;                                                
                            // The write can be performed when these conditions are true:
                            // - AW decode is valid.
                            // - `axi_req_i.aw.prot` has the right value.   To Do: aw.prot
                            b_chan.resp         = axi_pkg::RESP_OKAY;
                            b_valid             = 1'b1;
                            axi_resp_o.aw_ready = 1'b1;
                            axi_resp_o.w_ready  = 1'b1; 
                        end else begin
                            // Send default B error response on each not allowed write transaction.
                            b_valid             = 1'b1;
                            axi_resp_o.aw_ready = 1'b1;
                            axi_resp_o.w_ready  = 1'b1;
                        end
                    end else if (pmc_instr_req_i) begin
                        axi_fsm_ns       = READ;
                        read_fsm_ns      = LAT_PLUS_ONE;
                        read_requestor_d = PMU_CORE;
                        read_failed_d    = !pmc_dec_valid;
                        req              = pmc_dec_valid;
                        latency[0]       = 1'b1;
                    end    
                end

                READ: begin
                    pmc_instr_gnt_o = 1'b0;
                    // If the read request is completed,
                    // then the tc_sram ouptut is valid.

                    // We can have two situations:
                    //  1. The r_chan spill_register is not full and the read response can be passed to it.
                    //  2. The r_chan spill_register is full and we need to wait before responding.
                    //     In this case, the module busy waits in the READ - AWAIT_MRDY state.             
                    unique case (read_fsm_ns)     
                        LAT_PLUS_ONE: begin
                            // Check if read is over.
                            if (latency[ReadLatency]) begin
                                // If read is over and requestor is AXI4, check if the i_r_spill_register (`r_ready`) is not full.
                                if ((read_requestor_q == AXI4) && r_ready) begin
                                    if (!read_failed_q) begin
                                        r_chan = r_chan_lite_t'{
                                            data: data_t'(r_data_sout),
                                            resp: axi_pkg::RESP_OKAY,
                                            default: '0
                                        };
                                    end
                                    r_valid     = 1'b1;
                                    axi_fsm_ns  = IDLE;
                                    axi_resp_o.ar_ready = 1'b1;                                
                                // If `r_ready` not set then wait master to be ready.
                                end else if ((read_requestor_q == AXI4) && !r_ready) begin
                                    read_fsm_ns = AWAIT_MRDY;
                                // If requestor is PMU core.
                                end else if (read_requestor_q == PMU_CORE) begin                                    
                                    // To Do: Try and understand why this even matters?
                                    pmc_instr_gnt_o    = 1'b1;          // Set `core_gnt_i` so that the new request is available in the next clock cycle.
                                    pmc_instr_rvalid_o = 1'b1;
                                    pmc_instr_err_o    = read_failed_q;
                                    axi_fsm_ns         = IDLE;
                                    if (!read_failed_q) begin
                                        pmc_instr_rdata_o = r_data_sout;
                                    end
                                end
                            end
                        end

                        AWAIT_MRDY: begin
                            if (r_ready) begin
                                r_valid     = 1'b1;
                                axi_fsm_ns  = IDLE;
                                axi_resp_o.ar_ready = 1'b1;
                                
                                if (!read_failed_q) begin
                                    r_chan = r_chan_lite_t'{
                                        data: data_t'(r_data_sout),
                                        resp: axi_pkg::RESP_OKAY,
                                        default: '0
                                    };
                                end
                            end
                        end

                    endcase
                end
            endcase
        end

        always_ff @ (posedge clk_i) begin
            if (!rst_ni) begin
                read_requestor_q <= AXI4;                
            end else begin
                read_requestor_q <= read_requestor_d;
            end
        end

        always_ff @ (posedge clk_i) begin
            if (!rst_ni) begin
                read_failed_q <= 1'b0;                
            end else begin
                read_failed_q <= read_failed_d;
            end
        end

        always_ff @ (posedge clk_i) begin
            if (!rst_ni) begin
                axi_fsm_cs  <= IDLE;
                read_fsm_cs <= LAT_PLUS_ONE;
            end else begin
                axi_fsm_cs  <= axi_fsm_ns;
                read_fsm_cs <= read_fsm_ns;
            end
        end

        // Latency shift-register.
        genvar i;
        for (i = 1; i <= ReadLatency; i++) begin
            always_ff @ (posedge clk_i) begin
                if (!rst_ni) begin
                    latency[i]      <= 1'b0;
                end else begin
                    latency[i]      <= latency[i-1];
                end
            end
        end
    end

    // Add a cycle delay on AXI response, cut all comb paths between slave port inputs and outputs.
    spill_register #(
        .T      ( b_chan_lite_t ),
        .Bypass ( 1'b0          )
    ) i_b_spill_register (
        .clk_i,
        .rst_ni,
        .valid_i ( b_valid            ),
        .ready_o ( b_ready            ),
        .data_i  ( b_chan             ),
        .valid_o ( axi_resp_o.b_valid ),
        .ready_i ( axi_req_i.b_ready  ),
        .data_o  ( axi_resp_o.b       )
    );

    // Add a cycle delay on AXI response, cut all comb paths between slave port inputs and outputs.
    spill_register #(
        .T      ( r_chan_lite_t ),
        .Bypass ( 1'b0          )
    ) i_r_spill_register (
        .clk_i,
        .rst_ni,
        .valid_i ( r_valid            ),
        .ready_o ( r_ready            ),
        .data_i  ( r_chan             ),
        .valid_o ( axi_resp_o.r_valid ),
        .ready_i ( axi_req_i.r_ready  ),
        .data_o  ( axi_resp_o.r       )
    );

    // The tc_sram module can have some cycles of latency for read requests.
    tc_sram #(
        .NumWords   ( NumBytes      ),
        .DataWidth  ( $bits(data_t) ),
        .ByteWidth  ( 32'd8         ),
        .NumPorts   ( 32'd1         ),
        .Latency    ( ReadLatency   ),
        .SimInit    ( "zeros"       ),
        .PrintSimCfg( 1'b1          )
    ) i_instr_spm (
        .clk_i      ( clk_i                    ),
        .rst_ni     ( rst_ni                   ),
        .req_i      ( req                      ),
        .we_i       ( we                       ),
        .addr_i     ( addr[ISPM_AddrWidth-1:0] ),
        .wdata_i    ( w_data                   ),
        .be_i       ( be                       ),
        .rdata_o    ( r_data_sout              )
    );

endmodule
