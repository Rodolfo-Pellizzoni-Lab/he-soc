`include "axi/typedef.svh"
`include "axi/assign.svh"

module tb_pmu #(
    /// Number of counters in the PMU
    parameter int unsigned TbNumCounters       = 32'd5,
    /// Number of AXI masters connected to the xbar. (Number of slave ports)
    parameter int unsigned TbNumMasters        = 32'd1,
    /// Number of AXI slaves connected to the xbar. (Number of master ports)
    parameter int unsigned TbNumSlaves         = 32'd1,
    /// Number of write transactions per master.
    parameter int unsigned TbNumWrites         = 32'd101,
    /// Number of read transactions per master.
    parameter int unsigned TbNumReads          = 32'd101,
    /// AXI4+ATOP ID width of the masters connected to the slave ports of the DUT.
    /// The ID width of the slaves is calculated depending on the xbar configuration.
    parameter int unsigned TbAxiIdWidthMasters = 32'd5,
    /// The used ID width of the DUT.
    /// Has to be `TbAxiIdWidthMasters >= TbAxiIdUsed`.
    parameter int unsigned TbAxiIdUsed         = 32'd3,
    /// Data width of the AXI channels.
    parameter int unsigned TbAxiDataWidth      = 32'd64,
    /// Pipeline stages in the xbar itself (between demux and mux).
    parameter int unsigned TbPipeline          = 32'd1,
    /// Enable ATOP generation
    parameter bit          TbEnAtop            = 1'b0,
    /// Enable exclusive accesses
    parameter bit TbEnExcl                     = 1'b0,   
    /// Restrict to only unique IDs         
    parameter bit TbUniqueIds                  = 1'b0
);
    import pmu_pkg::*;
    import tb_pmu_pkg::*;

    // TB timing parameters
    localparam time CyclTime = 10ns;
    localparam time ApplTime =  2ns;
    localparam time TestTime =  8ns;

    // PMU configuration parameters.
    // Current PMU Memory Map: 
    //      Timer
    //      Period Register
    //      Initial Budget
    //      Event Info Register
    //      Event Selection Register
    //      Counter
    
    localparam int unsigned XLEN                    = 32'd32;   // Counter Width
    localparam int unsigned XLEN_STRB               = XLEN/8;
    localparam int unsigned PMU_BASE_ADDR           = 32'h1040_4000;
    
    // Event Sel and Event Info are 32-bits.
    localparam int unsigned COUNTER_BUNDLE_SIZE     = XLEN_STRB*2 + 
                                                      (EVENT_SEL_CFG_WIDTH/8) +
                                                      (EVENT_INFO_CFG_WIDTH/8); 
    localparam int unsigned COUNTER_BASE_ADDR       = PMU_BASE_ADDR + 2*8;  // Timer and Periods are 64-bits.
    localparam int unsigned EVENT_SEL_BASE_ADDR     = COUNTER_BASE_ADDR + XLEN_STRB;
    localparam int unsigned EVENT_INFO_BASE_ADDR    = EVENT_SEL_BASE_ADDR + XLEN_STRB;
    localparam int unsigned INIT_BUDGET_BASE_ADDR   = EVENT_INFO_BASE_ADDR + XLEN_STRB;

    // AXI configuration which is automatically derived.
    localparam int unsigned TbAxiIdWidthSlaves =  TbAxiIdWidthMasters + $clog2(TbNumMasters);
    localparam int unsigned TbAxiAddrWidth     =  32'd32;
    localparam int unsigned TbAxiStrbWidth     =  TbAxiDataWidth / 8;
    localparam int unsigned TbAxiUserWidth     =  5;

    localparam int unsigned NoAddrRules        =  TbNumSlaves;    

    typedef logic [TbAxiIdWidthMasters-1:0] id_mst_t;
    typedef logic [TbAxiIdWidthSlaves-1:0]  id_slv_t;
    typedef logic [TbAxiAddrWidth-1:0]      addr_t;
    typedef axi_pkg::xbar_rule_32_t         rule_t; // Has to be the same width as axi addr
    typedef logic [TbAxiDataWidth-1:0]      data_t;
    typedef logic [TbAxiStrbWidth-1:0]      strb_t;
    typedef logic [TbAxiUserWidth-1:0]      user_t;

    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_mst_t, id_mst_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_slv_t, id_slv_t, user_t)

    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_mst_t, data_t, id_mst_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_slv_t, data_t, id_slv_t, user_t)

    `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_mst_t, w_chan_t, ar_chan_mst_t)
    `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_mst_t, r_chan_mst_t)
    `AXI_TYPEDEF_REQ_T(slv_req_t, aw_chan_slv_t, w_chan_t, ar_chan_slv_t)
    `AXI_TYPEDEF_RESP_T(slv_resp_t, b_chan_slv_t, r_chan_slv_t)    

    // Each slave has its own address range:
    localparam rule_t [NoAddrRules-1:0] AddrMap = addr_map_gen();

    localparam spu_pkg::axi_cfg_t AXICfg = spu_pkg::axi_cfg_t'{
        AddrWidth: TbAxiAddrWidth,
        DataWidth: TbAxiAddrWidth,
        IdWidth: TbAxiIdWidthSlaves,
        UserWidth: TbAxiUserWidth
    };

    localparam spu_pkg::cache_cfg_t CacheCfg = spu_pkg::cache_cfg_t'{
        SetAssociativity: 32'd8,
        NumLines: 32'd256,
        NumBlocks: 32'd8
    };

    function rule_t [NoAddrRules-1:0] addr_map_gen ();
    for (int unsigned i = 0; i < NoAddrRules; i++) begin
        addr_map_gen[i] = rule_t'{
        idx:        unsigned'(i),
        start_addr:  i    * 32'h0000_2000,
        end_addr:   (i+1) * 32'h0000_2000,
        default:    '0
        };
    end
    endfunction

    typedef  axi_test::axi_rand_master #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth          ),
        .DW ( TbAxiDataWidth          ),
        .IW ( TbAxiIdWidthMasters     ),
        .UW ( TbAxiUserWidth          ),
        // Stimuli application and test time
        .TA ( ApplTime                ),
        .TT ( TestTime                ),
        // Maximum number of read and write transactions in flight
        .MAX_READ_TXNS  ( 20          ),
        .MAX_WRITE_TXNS ( 20          ),
        .AXI_EXCLS      ( TbEnExcl    ),
        .AXI_ATOPS      ( TbEnAtop    ),
        .UNIQUE_IDS     ( TbUniqueIds )
    ) axi_rand_master_t;

    typedef  axi_test::axi_rand_slave #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth     ),
        .DW ( TbAxiDataWidth     ),
        .IW ( TbAxiIdWidthSlaves ),
        .UW ( TbAxiUserWidth     ),
        // Stimuli application and test time
        .TA ( ApplTime           ),
        .TT ( TestTime           )
    ) axi_rand_slave_t;

    // -------------
    // DUT signals
    // -------------
    logic clk;
    logic rst_n;
    logic start_axi_test;
    logic end_of_sim;

    logic [63:0] n_count_cs;
    logic [63:0] n_count_ns;

    typedef enum {TEST_0, TEST_1, RESET, DONE} test_e;  
    
    typedef enum {
        SEND_WRITE,
        SEND_AW,
        SEND_W, 
        SEND_READ,         
        WAIT_BRESP,
        WAIT_RRESP,
        IDLE
    } state_e;

    typedef enum {
        COUNTER,
        EVENT_SEL,
        EVENT_INFO,
        INIT_BUDGET,
        TIMER,
        PERIOD,
        NULL
    } pmu_reg_e; 

    // -----------
    // FSM Signals
    // -----------
    test_e      prev_test_case;

    test_e      test_case_cs;
    test_e      test_case_ns;

    state_e     test_state_cs;
    state_e     test_state_ns;

    pmu_reg_e   pmu_reg_cs;
    pmu_reg_e   pmu_reg_ns;

    // pmu cfg request and response structs
    tb_pmu_pkg::req_lite_t  pmu_cfg_req;
    tb_pmu_pkg::resp_lite_t pmu_cfg_resp;

    // Write AXI4-Lite Signals
    addr_t  aw_addr;
    logic   aw_valid;

    data_t  w_data;
    strb_t  w_strb;
    logic   w_valid;
    
    logic   b_ready;

    // Read AXI4-Lite Signals
    addr_t  ar_addr;
    logic   ar_valid;

    data_t  r_data;

    logic   r_ready;

    // master structs
    mst_req_t  masters_req;
    mst_resp_t masters_resp;

    // slave structs
    slv_req_t  slaves_req;
    slv_resp_t slaves_resp;

    // -------------------------------
    // AXI Interfaces
    // -------------------------------
    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master ();
    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master_dv (clk);

    `AXI_ASSIGN (master, master_dv)
    `AXI_ASSIGN_TO_REQ(masters_req, master)
    `AXI_ASSIGN_TO_RESP(masters_resp, master)

    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave ();

    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave_dv (clk);

    `AXI_ASSIGN(slave_dv, slave)
    `AXI_ASSIGN_TO_REQ(slaves_req, slave)
    `AXI_ASSIGN_TO_RESP(slaves_resp, slave)

    // -------------------------------
    // AXI Rand Masters and Slaves
    // -------------------------------
    // Masters control simulation run time
    axi_rand_master_t axi_rand_master;
    axi_rand_slave_t axi_rand_slave;

    // -------------------------------
    // Snooping Unit Interface
    // -------------------------------

    // The output of the SPU EVU.
    SPU_INTF #(
        .NUM_EVENT        ( 5 ),
        .EVENT_INFO_BITS  ( 8 ),
        .NUM_SOURCE       ( 1 )
    ) spu_o ();

    // This interface is controlled by the testbench (Not synthesizable).
    SPU_INTF #(
        .NUM_EVENT        ( 5 ),
        .EVENT_INFO_BITS  ( 8 ),
        .NUM_SOURCE       ( 1 )
    ) test_o ();

    // Suspend the main thread until start_axi_test is set.
    // start_axi_test is set after all PMU tests are done.
    task automatic wait_pmu_tests();
        fork
            begin
                wait (start_axi_test!=0);
            end
        join
    endtask

    // --------------
    // Testbench FSM. 
    // --------------
    task automatic display_axi_response; 
            input test_e    test_case;

            input           we;
            input addr_t    addr;

            input [1:0]     expected_output;
            input [1:0]     actual_output;

            begin
                if (test_case != RESET) begin
                    if (expected_output == actual_output) 
                        if (we)
                            $display("Test %0d:: Write @ %x:: Expected Response", 
                                    test_case,
                                    addr);
                        else
                            $display("Test %0d:: Read @ %x:: Expected Response", 
                                    test_case,
                                    addr);
                    else 
                        if (we)
                            $fatal("Test %0d:: Write @ %x:: Unexpected Response", 
                                    test_case,
                                    addr);
                        else
                            $fatal("Test %0d:: Read @ %x:: Unexpected Response", 
                                    test_case,
                                    addr);
                end else begin
                    if (expected_output == actual_output) 
                        if (we)
                            $display("Reset:: Write @ %x:: Expected Response", 
                                    addr);
                        else
                            $display("Reset:: Read @ %x:: Expected Response", 
                                    addr);
                    else 
                        if (we)
                            $fatal("Reset:: Write @ %x:: Unexpected Response", 
                                    addr);
                        else
                            $fatal("Reset:: Read @ %x:: Unexpected Response", 
                                    addr);
                end
            end

    endtask

    /// 1st clock cycle: The combinational signals are set.
    /// 2nd clock cycle: The signals are sent to axi_lite_regs.
    /// 3rd clock cycle: The write is registered.
    /// 2 clock cycle per Write.
    always_comb begin
        test_state_ns               = test_state_cs;
        test_case_ns                = test_case_cs;
        pmu_reg_ns                  = pmu_reg_cs;

        aw_addr                     = '0;
        aw_valid                    = '0;
        w_data                      = '0;
        w_strb                      = '0;
        w_valid                     = '0;        
        b_ready                     = '0;

        ar_addr                     = '0;
        ar_valid                    = '0;
        r_data                      = '0;
        r_ready                     = '0;

        n_count_ns                  = n_count_cs;       
        test_o.e_id                 = 'b0;              

        unique case (test_case_cs) 
            // This test writes to all the registers in the PMU.
            TEST_0: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        // w_strb          = 4'b1111;
                        // w_valid         = 1'b1;
                    
                        // Write to all the counters.
                        if (pmu_reg_cs == COUNTER) begin
                            aw_addr     = COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;
                            // w_data      = 32'h3765_4321 + 32'h1 * n_count_cs;                        
                        end

                        // Write to all the event selection registers.
                        if (pmu_reg_cs == EVENT_SEL) begin
                            aw_addr     = EVENT_SEL_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;  
                            // w_data      = 32'hA000_0000 + 32'h1_000 * n_count_cs;
                        end

                        // Write to all the event info configuration registers.
                        if (pmu_reg_cs == EVENT_INFO) begin
                            aw_addr     = EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;
                            // w_data      = 32'hB000_9876 + 32'h4_000 * n_count_cs;                          
                        end

                        // Write to all the event info configuration registers.
                        if (pmu_reg_cs == INIT_BUDGET) begin
                            aw_addr     = INIT_BUDGET_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;
                            // w_data      = 32'hDEAD_0000 + 32'h100 * n_count_cs;
                        end

                        if (pmu_cfg_resp.aw_ready) begin
                            test_state_ns   = SEND_W;
                        end
                    end                    

                    SEND_W: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;                    
                    
                        // Write to all the counters.
                        if (pmu_reg_cs == COUNTER) begin                            
                            w_data      = 32'h3765_4321 + 32'h1 * n_count_cs;                        
                        end

                        // Write to all the event selection registers.
                        if (pmu_reg_cs == EVENT_SEL) begin                            
                            w_data      = 32'hA000_0000 + 32'h1_000 * n_count_cs;
                        end

                        // Write to all the event info configuration registers.
                        if (pmu_reg_cs == EVENT_INFO) begin                            
                            w_data      = 32'hB000_9876 + 32'h4_000 * n_count_cs;                          
                        end

                        // Write to all the event info configuration registers.
                        if (pmu_reg_cs == INIT_BUDGET) begin                            
                            w_data      = 32'h5EAD_0000 + 32'h100 * n_count_cs;
                        end

                        if (pmu_cfg_resp.w_ready) begin
                            test_state_ns   = WAIT_BRESP;
                        end                    
                    end
                
                    WAIT_BRESP: begin   
                        b_ready         = 1'b1;                     
                        if (pmu_cfg_resp.b_valid) begin
                            $display("Write-Test %0d [%0s #%0d]", 
                                    test_case_cs, 
                                    pmu_reg_cs.name(),
                                    n_count_cs);

                            if (pmu_cfg_resp.b.resp == axi_pkg::RESP_OKAY) begin
                                $display("Response OKAY.");
                            end else if (pmu_cfg_resp.b.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (pmu_cfg_resp.b.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                            
                            test_state_ns   = SEND_AW;                            
                            n_count_ns      = n_count_cs + 1;

                            if (n_count_cs == TbNumCounters-1) begin                                
                                n_count_ns      = '0;                                
                                pmu_reg_ns      = pmu_reg_cs.next();
                                if (pmu_reg_cs == INIT_BUDGET) begin
                                    pmu_reg_ns      = COUNTER;
                                    test_state_ns   = SEND_READ;
                                end                             
                            end
                        end
                    end

                    SEND_READ: begin
                        // Read to all the counters.
                        if (pmu_reg_cs == COUNTER) begin
                            ar_addr     = COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;                            
                        end

                        // Read to all the event selection registers.
                        if (pmu_reg_cs == EVENT_SEL) begin
                            ar_addr     = EVENT_SEL_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;                            
                        end

                        // Read to all the event info configuration registers.
                        if (pmu_reg_cs == EVENT_INFO) begin
                            ar_addr     = EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;                            
                        end

                        // Read to all the event info configuration registers.
                        if (pmu_reg_cs == INIT_BUDGET) begin
                            ar_addr     = INIT_BUDGET_BASE_ADDR + COUNTER_BUNDLE_SIZE * n_count_cs;                            
                        end
                        ar_valid        = 1'b1;

                        if (pmu_cfg_resp.ar_ready) begin
                            test_state_ns   = WAIT_RRESP;
                        end
                    end

                    WAIT_RRESP: begin
                        r_ready     = 1'b1;
                        if (pmu_cfg_resp.r_valid) begin
                            r_ready         = 1'b0;

                            if (pmu_reg_cs == COUNTER) begin                                
                                w_data      = 32'h3765_4321 + 32'h1 * n_count_cs;
                            end

                            // Write to all the event selection registers.
                            if (pmu_reg_cs == EVENT_SEL) begin                                
                                w_data      = 32'hA000_0000 + 32'h1_000 * n_count_cs;
                            end

                            // Write to all the event info configuration registers.
                            if (pmu_reg_cs == EVENT_INFO) begin                                
                                w_data      = 32'hB000_9876 + 32'h4_000 * n_count_cs;
                            end

                            // Write to all the event info configuration registers.
                            if (pmu_reg_cs == INIT_BUDGET) begin                                
                                w_data      = 31'hDEAD_0000 + 31'h100 * 31'(n_count_cs);
                            end

                            $display("Read-Test %0d [%0s #%0d]", 
                                    test_case_cs, 
                                    pmu_reg_cs.name(),
                                    n_count_cs);

                            if (pmu_cfg_resp.r.resp == axi_pkg::RESP_OKAY) begin
                                if (pmu_cfg_resp.r.data == w_data) begin
                                    $display("Correct value was read.");
                                end else begin
                                    $fatal("Incorrect value was read.");
                                end
                            end else if (pmu_cfg_resp.r.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (pmu_cfg_resp.r.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end

                            test_state_ns   = SEND_READ;
                            n_count_ns      = n_count_cs + 1;

                            if (n_count_cs == TbNumCounters-1) begin
                                n_count_ns      = '0;                        
                                pmu_reg_ns      = pmu_reg_cs.next();
                                if (pmu_reg_cs == INIT_BUDGET) begin
                                    pmu_reg_ns      = COUNTER;
                                    test_case_ns    = DONE;
                                end                             
                            end
                        end
                    end
                endcase

            end
            
            // This test case sends a AXI4-Lite write request and an event increment signal in the same clock cycle.
            // The AXI4-Lite write should be go through.
            TEST_1: begin
                unique case (test_state_cs) 
                    SEND_WRITE: begin                        
                        aw_valid        = 1'b1;
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;

                        // Setup the first counter by writing to its Event Selection Register.
                        if (n_count_cs == '0) begin
                            aw_addr     = EVENT_SEL_BASE_ADDR;                    
                            w_data      = 32'h002f_001f;
                        end
                                        
                        if (n_count_cs == 1) begin
                            // Write to the first counter.
                            aw_addr     = COUNTER_BASE_ADDR;                    
                            w_data      = 32'h3765_4321;                        
                        
                            // Send Hardware Event
                            test_o.e_id = 'b1;
                        end

                        test_state_ns   = WAIT_BRESP;
                    end

                    SEND_READ: begin
                        ar_addr         = COUNTER_BASE_ADDR;
                        ar_valid        = 1'b1;

                        test_state_ns   = WAIT_RRESP;
                    end

                    WAIT_BRESP: begin
                        aw_addr         = addr_t'(pmu_cfg_req.aw.addr);
                        w_data          = data_t'(pmu_cfg_req.w.data);
                        b_ready     = 1'b1;
                        if (pmu_cfg_resp.b_valid) begin
                            b_ready         = 1'b0;
                            display_axi_response (test_case_cs, 
                                                  1'b1,
                                                  pmu_cfg_req.aw.addr,
                                                  axi_pkg::RESP_OKAY, 
                                                  pmu_cfg_resp.b.resp);                                                   
                            
                            test_state_ns   = SEND_WRITE;                            
                            n_count_ns      = n_count_cs + 1;                            

                            if (n_count_cs == 1) begin
                                test_state_ns   = SEND_READ;
                                n_count_ns      = '0;
                            end
                        end
                    end

                    WAIT_RRESP: begin
                        ar_addr         = addr_t'(pmu_cfg_req.ar.addr);
                        r_ready     = 1'b1;
                        if (pmu_cfg_resp.r_valid) begin
                            r_ready         = 1'b0;
                            display_axi_response (test_case_cs, 
                                                  1'b0,
                                                  pmu_cfg_req.ar.addr,
                                                  32'h3765_4321, 
                                                  pmu_cfg_resp.r.data);
                            test_case_ns    = RESET;
                            prev_test_case  = TEST_0;
                            test_state_ns   = SEND_WRITE;
                            n_count_ns      = '0;
                        end
                    end
                endcase
            end

            // // This test case configures the Event Selection Register to count AXI requests.
            // TEST_1: begin
            //     unique case (test_state_cs)
            //         SEND_WRITE: begin
            //             aw_addr         = addr_t'(pmu_cfg_req.aw.addr + XLEN_STRB);
            //             aw_valid        = 1'b1;

            //             w_data          = data_t'(pmu_cfg_req.w.data + 32'h10);
            //             w_strb          = 4'b1111;
            //             w_valid         = 1'b1;

            //             if (n_count_cs == '0) begin
            //                 w_data      = 32'h001F_001F;
            //                 aw_addr     = EVENT_SEL_BASE_ADDR;
            //             end

            //             test_state_ns   = WAIT_BRESP;                    
            //         end

            //         WAIT_BRESP: begin
            //             // Do not update address and data until a response is received.
            //             aw_addr         = addr_t'(pmu_cfg_req.aw.addr);
            //             w_data          = data_t'(pmu_cfg_req.w.data);
            //             b_ready         = 1'b1;

            //             if (pmu_cfg_resp.b_valid) begin
            //                 b_ready         = 1'b0;
            //                 display_axi_response (test_case_cs, 
            //                                       1'b1,
            //                                       pmu_cfg_req.aw.addr,
            //                                       axi_pkg::RESP_OKAY, 
            //                                       pmu_cfg_resp.b.resp);
                            
            //                 test_state_ns   = SEND_WRITE;                            
            //                 n_count_ns      = n_count_cs + 1;

            //                 if (n_count_cs == TbNumCounters-1) begin
            //                     test_case_ns    = DONE;
            //                     test_state_ns   = IDLE;
            //                     n_count_ns      = '0;
            //                 end
            //             end
            //         end

            //         default: ;
            //     endcase
            // end

            // RESET: begin
            //     unique case (test_state_cs)
            //         SEND_WRITE: begin
            //             aw_addr         = addr_t'(pmu_cfg_req.aw.addr + XLEN_STRB);
            //             aw_valid        = 1'b1;

            //             w_strb          = 4'b1111;
            //             w_valid         = 1'b1;

            //             if (n_count_cs == '0) begin
            //                 aw_addr     = COUNTER_BASE_ADDR;
            //             end

            //             test_state_ns   = WAIT_BRESP;                    
            //         end

            //         WAIT_BRESP: begin
            //             // Do not update address and data until a response is received.
            //             aw_addr         = addr_t'(pmu_cfg_req.aw.addr);
            //             w_data          = data_t'(pmu_cfg_req.w.data);
            //             b_ready         = 1'b1;

            //             if (pmu_cfg_resp.b_valid) begin
            //                 b_ready         = 1'b0;
            //                 display_axi_response (test_case_cs, 
            //                                       1'b1,
            //                                       pmu_cfg_req.aw.addr,
            //                                       axi_pkg::RESP_OKAY, 
            //                                       pmu_cfg_resp.b.resp);
                            
            //                 test_state_ns   = SEND_WRITE;                            
            //                 n_count_ns      = n_count_cs + 1;

            //                 if (aw_addr == PERIOD_BASE_ADDR) begin
            //                     test_case_ns    = prev_test_case.next();
            //                     test_state_ns   = SEND_WRITE;
            //                     n_count_ns      = '0;
            //                 end
            //             end
            //         end

            //         default: ;
            //     endcase
            // end

            DONE: begin
                start_axi_test = 1'b1;
            end

            default: ;
        endcase
    end

    // -------------
    // FSM Flip-Flop
    // -------------
    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            test_state_cs   <= SEND_AW;
            test_case_cs    <= TEST_0;
            n_count_cs      <= '0;
            pmu_reg_cs      <= COUNTER;
        end else begin
            test_case_cs    <= test_case_ns;
            test_state_cs   <= test_state_ns;
            n_count_cs      <= n_count_ns;
            pmu_reg_cs      <= pmu_reg_ns;
        end
    end

    always @ (posedge clk) begin
        // Active-low reset
        if (!rst_n) begin
            pmu_cfg_req.aw.addr     <= 32'h0000_0000;
            pmu_cfg_req.aw.prot     <= 3'h0;
            pmu_cfg_req.aw_valid    <= 1'b0;
            
            pmu_cfg_req.w.data      <= 32'h0000_0000;
            pmu_cfg_req.w.strb      <= 4'h0;
            pmu_cfg_req.w_valid     <= 1'b0;

            pmu_cfg_req.b_ready     <= 1'b0;

            pmu_cfg_req.ar.addr     <= 32'h0000_0000;
            pmu_cfg_req.ar.prot     <= 3'h0;
            pmu_cfg_req.ar_valid    <= 1'b0;

            pmu_cfg_req.r_ready     <= 1'b0;
        end else begin   
            pmu_cfg_req.aw.addr     <= aw_addr;
            pmu_cfg_req.aw.prot     <= 3'h0;
            pmu_cfg_req.aw_valid    <= aw_valid;
            
            pmu_cfg_req.w.data      <= w_data;
            pmu_cfg_req.w.strb      <= w_strb;
            pmu_cfg_req.w_valid     <= w_valid;

            pmu_cfg_req.b_ready     <= b_ready;

            pmu_cfg_req.ar.addr     <= ar_addr;
            pmu_cfg_req.ar.prot     <= 3'h0;
            pmu_cfg_req.ar_valid    <= ar_valid;

            pmu_cfg_req.r_ready     <= r_ready;
        end
    end

    // The AXI Random Master and Slave will generates TbNumWrites and TbNumReads.
    // Can confirm the output of PMU counters against the AXI log to verify functionality of the counters
    // and the Snooping Unit.
    initial begin
        axi_rand_master = new( master_dv );
        axi_rand_master.add_memory_region(AddrMap[0].start_addr,
                                        AddrMap[NoAddrRules-1].end_addr,
                                        axi_pkg::DEVICE_NONBUFFERABLE);
        axi_rand_master.reset();
        wait_pmu_tests();        
        axi_rand_master.run(TbNumReads, TbNumWrites);       
        end_of_sim <= 1'b1;
    end

    initial begin
        axi_rand_slave = new( slave_dv );
        axi_rand_slave.reset();
        wait_pmu_tests();
        axi_rand_slave.run();
    end

    always @ (posedge clk) begin
        if (end_of_sim) begin
            $finish();
        end
    end

    //-----------------------------------
    // Device Under Test (DUT)
    //-----------------------------------

    spu_top #(
        .CacheCfg           ( CacheCfg              ),
        .AXICfg             ( AXICfg                )
    ) spu_i (
        .clk_i              ( clk                  ),
        .rst_ni             ( rst_n                ),
        .spu_slv            ( master               ),
        .spu_mst            ( slave                ),
        .e_out              ( spu_o                )
    );

    pmu_top #(
        .NUM_COUNTER        ( TbNumCounters             )
        // .lite_req_t         ( tb_pmu_pkg::req_lite_t    ),
        // .lite_resp_t        ( tb_pmu_pkg::resp_lite_t   )
    ) dut_pmu (
        .clk_i              ( clk                       ),
        .rst_ni             ( rst_n                     ),
        .spu1_i             ( spu_o                     ),
        .spu2_i             ( test_o                    ),
        .conf_req_i         ( pmu_cfg_req               ),   
        .conf_resp_o        ( pmu_cfg_resp              ),
        .intr_o             (  )
    );

    //-----------------------------------
    // Clock generator
    //-----------------------------------
    clk_rst_gen #(
        .ClkPeriod    ( CyclTime ),
        .RstClkCycles ( 5        )
    ) i_clk_gen (
        .clk_o (clk),
        .rst_no(rst_n)
    );

    // logger for master modules
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_master_0")),
        .aw_chan_t ( aw_chan_mst_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_mst_t ), // axi  B type
        .ar_chan_t ( ar_chan_mst_t ), // axi AR type
        .r_chan_t  (  r_chan_mst_t )  // axi  R type
    ) i_mst_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( masters_req.aw        ),
        .aw_valid_i ( masters_req.aw_valid  ),
        .aw_ready_i ( masters_resp.aw_ready ),
        //  W channel
        .w_chan_i   ( masters_req.w         ),
        .w_valid_i  ( masters_req.w_valid   ),
        .w_ready_i  ( masters_resp.w_ready  ),
        //  B channel
        .b_chan_i   ( masters_resp.b        ),
        .b_valid_i  ( masters_resp.b_valid  ),
        .b_ready_i  ( masters_req.b_ready   ),
        // AR channel
        .ar_chan_i  ( masters_req.ar        ),
        .ar_valid_i ( masters_req.ar_valid  ),
        .ar_ready_i ( masters_resp.ar_ready ),
        //  R channel
        .r_chan_i   ( masters_resp.r        ),
        .r_valid_i  ( masters_resp.r_valid  ),
        .r_ready_i  ( masters_req.r_ready   )
    );

    // logger for slave modules
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_slave_0")),
        .aw_chan_t ( aw_chan_slv_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_slv_t ), // axi  B type
        .ar_chan_t ( ar_chan_slv_t ), // axi AR type
        .r_chan_t  (  r_chan_slv_t )  // axi  R type
    ) i_slv_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( slaves_req.aw        ),
        .aw_valid_i ( slaves_req.aw_valid  ),
        .aw_ready_i ( slaves_resp.aw_ready ),
        //  W channel
        .w_chan_i   ( slaves_req.w         ),
        .w_valid_i  ( slaves_req.w_valid   ),
        .w_ready_i  ( slaves_resp.w_ready  ),
        //  B channel
        .b_chan_i   ( slaves_resp.b        ),
        .b_valid_i  ( slaves_resp.b_valid  ),
        .b_ready_i  ( slaves_req.b_ready   ),
        // AR channel
        .ar_chan_i  ( slaves_req.ar        ),
        .ar_valid_i ( slaves_req.ar_valid  ),
        .ar_ready_i ( slaves_resp.ar_ready ),
        //  R channel
        .r_chan_i   ( slaves_resp.r        ),
        .r_valid_i  ( slaves_resp.r_valid  ),
        .r_ready_i  ( slaves_req.r_ready   )
    );


endmodule