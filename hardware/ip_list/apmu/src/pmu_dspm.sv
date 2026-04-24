// The following must be kept in mind when designing the DSPM FSM to respond to the LSU of the PMU core (Ibex):
//      1. The `core_gnt_o` signal must be set one clock cycle before the `core_rvalid_i` is set. This is different from what the fetch stage of the core expects.
//         The `if_stage` can send accept a valid `core_rdata_i` in the same cycle as when the `core_gnt_o` is set unlike the LSU. 
//      2. Load-store instructions must take atleast 2 clock cycles. This is because the `id_stage` checks for `core_rvalid_i = 1` only from the 2nd cycle onwards.
//      3. If the store instruction is misaligned, it is split into two aligned store instructions. After the data memory responds with a `core_gnt_i` = 1 signals, the LSU 
//         switches to next instruction (in the misaligned instruction section). (The LUS does not wait for a valid `core_rvalid_i`.) The `core_wdata_o` signal is held 
//         steady by the `core_be_o` (strobe bits) are changed immediately. 
//

`include "axi/typedef.svh"

module pmu_dspm #(
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
    input  addr_t       pmc_data_addr_i,
    input  logic        pmc_data_req_i,
    input  strb_t       pmc_data_be_i,
    output data_t       pmc_data_rdata_o,
    input  logic        pmc_data_we_i,
    output logic        pmc_data_gnt_o,
    input  data_t       pmc_data_wdata_i,
    output logic        pmc_data_rvalid_o,
    output logic        pmc_data_err_o,
    // Signals from AXI4-Lite PMU Xbar
    input  req_lite_t   axi_req_i,
    output resp_lite_t  axi_resp_o
);

    // Channel definitions for spill register
    `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_lite_t)
    `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_lite_t, data_t)
    
    // A read data is only valid after ReadLatency clock cycles.
    typedef enum {
        IDLE,       // No request, write request are serviced in one clock cycle
                    // and do not need a separate state
        READ,       // Servicing read request
        PMU_WRITE   // Servicing write request from PMU core (need it for when ReadLatency != 0)
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
    
    // Indicates that read address (`ar_arr` or `pmc_data_addr_i`) was not valid.
    logic invalid_addr_d;
    logic invalid_addr_q;


    // Read requestor.
    typedef enum {
        AXI4, PMU_CORE
    } requestor_t;
    requestor_t read_requestor_d;
    requestor_t read_requestor_q;

    // Signals whether the `pmc_data_addr_i` is a valid address or not.
    logic  pmc_dec_valid;
    logic  pmc_data_err;
    addr_t pmc_data_rdata;
    logic  pmc_data_rvalid;

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

    localparam DSPM_AddrWidth = (NumBytes > 32'd1) ? $clog2(NumBytes) : 32'd1;

    // Check whether the address is valid or not.
    always_comb begin
        ar_dec_valid  = 1'b0;
        aw_dec_valid  = 1'b0;
        pmc_dec_valid = 1'b0;
    
        addr     = '0;
        pmc_addr = pmc_data_addr_i - START_ADDR;
        r_addr   = axi_req_i.ar.addr - START_ADDR;
        w_addr   = axi_req_i.aw.addr - START_ADDR;

        // Reads are prioritized over writes.
        if (r_addr < NumBytes && axi_req_i.ar_valid) begin
            addr          = addr_t'(r_addr);
            ar_dec_valid  = 1'b1;
        end else if (w_addr < NumBytes && axi_req_i.aw_valid) begin
            addr          = addr_t'(w_addr);
            aw_dec_valid  = 1'b1;
        end else if (pmc_addr < NumBytes && pmc_data_req_i) begin
            addr          = addr_t'(pmc_addr);
            pmc_dec_valid = 1'b1;
        end
    end

    // FSM
    // BOth read and write responses are stored in spill registers to cut the combinatorial paths.

    // The SPM only starts a write when the aw_addr, w_data are valid;
    // and when the spill registers have space to store another write response.
    assign start_axi4_write  = axi_req_i.aw_valid && axi_req_i.w_valid && b_ready;
    assign w_data            = (start_axi4_write) ? axi_req_i.w.data : pmc_data_wdata_i;

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
            pmc_data_gnt_o    = 1'b1;
            pmc_data_rdata    = '0;
            pmc_data_rvalid   = 1'b0;
            pmc_data_err      = 1'b0;
            
            // Reads are prioritized over writes.
            // Reads can start even before the Master is ready to claim them.
            if (axi_req_i.ar_valid && r_ready) begin
                r_valid = 1'b1;
                axi_resp_o.ar_ready = 1'b1;
                pmc_data_gnt_o     = 1'b0;
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
                pmc_data_gnt_o = 1'b0;
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
            // Read-Write data SPM request from PMU core.
            end else if (pmc_data_req_i) begin
                req = pmc_dec_valid;
                we  = pmc_data_we_i;
                be  = pmc_data_be_i;

                pmc_data_rvalid = pmc_data_req_i;
                pmc_data_err    = !pmc_dec_valid;
                if (pmc_dec_valid) begin
                    pmc_data_rdata = r_data_sout;
                end  
            end
        end

        // Need to add a clock cycle delay when responding to requests from the LSU of the PMU core.
        always_ff @ (posedge clk_i) begin
            if (!rst_ni) begin
                pmc_data_err_o      <= 1'b0;
                pmc_data_rvalid_o   <= 1'b0;
                pmc_data_rdata_o    <= '0;
            end else begin
                pmc_data_err_o      <= pmc_data_err;
                pmc_data_rvalid_o   <= pmc_data_rvalid;
                pmc_data_rdata_o    <= pmc_data_rdata;
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
            pmc_data_gnt_o    = 1'b1;
            pmc_data_rdata_o  = '0;
            pmc_data_rvalid_o = 1'b0;
            pmc_data_err_o    = 1'b0;

            // Indicates failed read-write due to invalid address.
            invalid_addr_d    = invalid_addr_q;

            // This variable is only important during a read.
            read_requestor_d = read_requestor_q;

            unique case(axi_fsm_cs)
                // There is no read request in progress.
                // Can start the next read or write request.
                IDLE: begin
                    // Reads are prioritized over writes.
                    // Reads can start even before the Master is ready to claim them.
                    // Wait until the previous `axi_resp_o.r_valid` is claimed before starting a new read.
                    // `axi_resp_o.r_valid` is allowed to be a condition as it comes from a pipelined register.
                    if (axi_req_i.ar_valid && !axi_resp_o.r_valid) begin
                        axi_fsm_ns       = READ;
                        read_fsm_ns      = LAT_PLUS_ONE;
                        read_requestor_d = AXI4;
                        
                        pmc_data_gnt_o   = 1'b0;
                        invalid_addr_d   = !ar_dec_valid;
                        req              = ar_dec_valid;
                        latency[0]       = 1'b1;
                    end
                    // Handle load from AXI write.
                    // `b_ready_q` is allowed to be a condition as it comes from a pipelined register.
                    else if (start_axi4_write) begin
                        pmc_data_gnt_o = 1'b0;
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
                    end
                    // Handle read-write from PMU core.
                    // The `core_data_gnt_i` signal must be set in this clock cycle,
                    // so that the response in the next (or later) cycles is accepted.
                    else if (pmc_data_req_i) begin
                        req = pmc_dec_valid;
                        we  = pmc_data_we_i;
                        be  = pmc_data_be_i;

                        axi_fsm_ns       = (pmc_data_we_i) ? PMU_WRITE : READ;
                        invalid_addr_d   = !pmc_dec_valid;
                        // The following signals are only important for PMU Read.
                        read_fsm_ns      = LAT_PLUS_ONE;
                        read_requestor_d = PMU_CORE;
                        // Only start latency counter if there is a read request.
                        latency[0]       = !pmc_data_we_i;
                    end    
                end

                READ: begin
                    pmc_data_gnt_o = 1'b0;
                    // We can have two situations:
                    //  1. The r_chan spill_register is not full and the read response can be passed to it.
                    //  2. The r_chan spill_register is full and we need to wait before responding.
                    //     In this case, the module busy waits in the READ - AWAIT_MRDY state.                
                    unique case (read_fsm_ns)     
                        LAT_PLUS_ONE: begin
                            // Check if read is over. If the read request is completed, then the tc_sram ouptut is valid.
                            if (latency[ReadLatency]) begin                                
                                // If read is over and requestor is AXI4, check if the i_r_spill_register (`r_ready`) is not full.
                                if ((read_requestor_q == AXI4) && r_ready) begin
                                    if (!invalid_addr_q) begin
                                        r_chan = r_chan_lite_t'{
                                            data: data_t'(r_data_sout),
                                            resp: axi_pkg::RESP_OKAY,
                                            default: '0
                                        };
                                    end
                                    axi_fsm_ns  = IDLE;
                                    r_valid     = 1'b1;
                                    axi_resp_o.ar_ready = 1'b1;                                
                                // If `r_ready` not set then wait master to be ready.
                                end else if ((read_requestor_q == AXI4) && !r_ready) begin
                                    read_fsm_ns = AWAIT_MRDY;
                                // If requestor is PMU core.
                                end else if (read_requestor_q == PMU_CORE) begin                                    
                                    axi_fsm_ns        = IDLE;
                                    pmc_data_gnt_o    = 1'b0;
                                    pmc_data_rvalid_o = 1'b1;
                                    pmc_data_err_o    = invalid_addr_q;
                                    if (!invalid_addr_q) begin
                                        pmc_data_rdata_o = r_data_sout;
                                    end
                                end
                            end
                        end

                        AWAIT_MRDY: begin
                            if (r_ready) begin
                                axi_fsm_ns  = IDLE;
                                r_valid     = 1'b1;
                                axi_resp_o.ar_ready = 1'b1;
                                
                                if (!invalid_addr_q) begin
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
                
                PMU_WRITE: begin
                    axi_fsm_ns        = IDLE;
                    // Need to reset `core_gnt_i` so that in case of misaligned stores, the next one does not start right away.
                    // A more efficient solution would be to add another FSM state to account for that.
                    // pmc_data_gnt_o    = 1'b0;
                    pmc_data_rvalid_o = 1'b1;
                    pmc_data_err_o    = invalid_addr_q;

                    // Check if there is another store request from PMU core (signifies a misaligned store).
                    if (pmc_data_req_i && pmc_data_we_i) begin
                        req = pmc_dec_valid;
                        we  = pmc_data_we_i;
                        be  = pmc_data_be_i;

                        axi_fsm_ns      = PMU_WRITE;
                        invalid_addr_d  = !pmc_dec_valid;
                    end
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
                invalid_addr_q <= 1'b0;                
            end else begin
                invalid_addr_q <= invalid_addr_d;
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
    ) i_data_spm (
        .clk_i      ( clk_i                    ),
        .rst_ni     ( rst_ni                   ),
        .req_i      ( req                      ),
        .we_i       ( we                       ),
        .addr_i     ( addr[DSPM_AddrWidth-1:0] ),
        .wdata_i    ( w_data                   ),
        .be_i       ( be                       ),
        .rdata_o    ( r_data_sout              )
    );

endmodule
