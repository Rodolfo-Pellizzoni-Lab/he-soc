//-----------------------------------------------------------------------------
// Copyright (C) 2026 University of Waterloo
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

/// This testbench tests the pmu_spm module separately.
/// The DUT only responds to a read or write request when all the required signals are set i.e.,
///     1. aw_valid, w_valid and b_ready for Write.
///     2. ar_valid, r_valid for Read.
/// The Xbar is written such that once the ax_addr or w_data signal is not set, it does not reset until the slave acknowledges it with ax_ready.
/// This implies that eventually all the above signals will be set until the slave acknowledges all of them.
/// This is why in the tb_pmu, the testbench needs to set the ax_addr, w_data signal only for one clock cycle, the Xbar latches onto it until the slave responds.
/// In this testbench, there is no Xbar so the testbench needs to latch onto the signal externally.

/// Note: The ReadLatency can be varied when running the tests.
///     TEST_0: Does TbWrites and then TbReads to the `pmu_spm`.
///     TEST_1: Does one write and one read TbWrites number of times to the `pmu_spm`.
///     TEST_2: Does TbWrites and then TbReads to the `pmu_spm` but the Master Ready signal is asserted after ReadLatency.
`include "axi/typedef.svh"
`include "axi/assign.svh"

module tb_pmu_spm #(
    /// Number of lines in tc_sram.
    parameter int unsigned NumLines             = 100,
    /// Read latency, the read data is available this many cycles after a request.
    parameter int unsigned TbReadLatency        = 0,
    /// Number of write transactions per master.
    parameter int unsigned TbNumWrites          = 32'd100,
    /// Number of read transactions per master.
    parameter int unsigned TbNumReads           = 32'd100,
    /// AXI4+ATOP ID width of the masters connected to the slave ports of the DUT.
    /// The ID width of the slaves is calculated depending on the xbar configuration.
    parameter int unsigned TbAxiIdWidthMasters  = 32'd5,
    /// Data width of the AXI channels.
    parameter int unsigned TbAxiDataWidth       = 32'd32
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
    localparam int unsigned START_ADDR   = 32'h1040_5000;
    localparam int unsigned SPM_LENGTH   = 32'h1000;

    typedef logic [XLEN-1:0]        data_t;
    typedef logic [XLEN-1:0]        addr_t;
    typedef logic [XLEN_STRB-1:0]   strb_t;

    data_t [TbNumWrites-1:0]        rand_wdata_1;
    data_t [TbNumWrites-1:0]        rand_wdata_2;

    // -------------
    // DUT signals
    // -------------
    logic clk;
    logic rst_n;
    logic start_axi_test;
    logic end_of_sim;

    logic [63:0] n_count_cs;
    logic [63:0] n_count_ns;

    typedef enum {
        RESET,
        INIT,
        TEST_0,
        TEST_1,
        TEST_2,    
        TEST_3,
        TEST_3_DENOUEMENT,
        DONE
    } test_e;  
    
    typedef enum {
        SEND_WRITE,
        SEND_AW,
        SEND_W,
        SEND_AR,
        SEND_W_PLUS_AR,
        WAIT_BRESP,
        WAIT_RRESP,
        WAIT_BRESP_PLUS_RRESP,
        IDLE
    } state_e;

    // -----------
    // FSM Signals
    // -----------
    test_e      prev_test_case;

    test_e      test_case_cs;
    test_e      test_case_ns;

    state_e     test_state_cs;
    state_e     test_state_ns;

    // pmu cfg request and response structs
    tb_pmu_pkg::req_lite_t  spm_req;
    tb_pmu_pkg::resp_lite_t spm_resp;

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

    // Acknowledgement signals (See comment at top)
    logic   aw_resp_d;
    logic   aw_resp_q;

    logic   w_resp_d;
    logic   w_resp_q;

    logic   ar_resp_d;
    logic   ar_resp_q;

    // Latency counter
    logic [32:0]    lat_target_cs;
    logic [32:0]    lat_target_ns;
    logic [32:0]    lat_count_cs;
    logic [32:0]    lat_count_ns;

    // -----------------------
    // FSM Combinatorial Block
    // -----------------------
    always_comb begin
        test_state_ns   = test_state_cs;
        test_case_ns    = test_case_cs;

        aw_addr         = '0;
        aw_valid        = '0;
        w_data          = '0;
        w_strb          = '0;
        w_valid         = '0;        
        b_ready         = '0;

        ar_addr         = '0;
        ar_valid        = '0;
        r_data          = '0;
        r_ready         = '0;

        aw_resp_d       = aw_resp_q;
        w_resp_d        = w_resp_q;
        ar_resp_d       = ar_resp_q;

        n_count_ns      = n_count_cs;
        lat_count_ns    = lat_count_cs;
        lat_target_ns   = lat_target_cs;

        // In all testcases, the testbench keep the valid signal (aw_valid, ar_valid, w_valid) until the SPM acknowledges it.
        // The SPM acknowledges a valid signal by setting the corresponding ready (aw_ready, ar_ready, w_ready respectively).
        unique case (test_case_cs) 
            INIT: begin
                for (int i=0; i < TbNumWrites; i++) begin
                    rand_wdata_1[i] = $urandom();
                    rand_wdata_2[i] = $urandom();
                end

                prev_test_case  = test_case_cs;
                test_case_ns    = RESET;
                test_state_ns   = SEND_AW;
            end
            
            // This test makes TbNumWrites to the SPM.
            // After all writes are over, it makes TbNumReads reads.
            //  Writes:
            //      1st cycle: Master sets the address (AW).
            //      2nd cycle: Master sets the data (W).
            //      3rd cycle: Master asserts ready (B).
            // 
            //  Read:
            //      1st cycle: Master sets the address (AR).
            //      2nd cycle: Master asserts ready (R).
            TEST_0: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        aw_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = SEND_W;
                        
                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d       = 1'b1;
                        end
                    end                    

                    SEND_W: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;
                        w_data          = rand_wdata_1[n_count_cs];
                        test_state_ns   = WAIT_BRESP;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d    = 1'b1;
                        end                    
                    end
                
                    WAIT_BRESP: begin
                        b_ready         = 1'b1;    

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = 32'h1024 * n_count_cs*3;
                        end

                        if (spm_resp.b_valid) begin
                            test_state_ns   = SEND_AW;
                            n_count_ns      = n_count_cs + 1;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                test_state_ns   = SEND_AR;                            
                            end
                        end
                    end

                    SEND_AR: begin                
                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_RRESP;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    WAIT_RRESP: begin
                        r_ready     = 1'b1;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;            
                        end

                        if (spm_resp.r_valid) begin
                            r_ready         = 1'b0;
                            w_data          = rand_wdata_1[n_count_cs];

                            test_state_ns   = SEND_AR;
                            n_count_ns      = n_count_cs + 1;
                            ar_resp_d       = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                prev_test_case  = test_case_cs;
                                test_case_ns    = RESET;
                                test_state_ns   = SEND_AW;
                            end
                        end
                    end
                endcase
            end

            // This test makes a write to the SPM. 
            // After the write, it makes a read to the same address.
            // This is repeated TbNumWrites times.
            // Writes:
            //      1st cycle: Master sets the address (AW).
            //      2nd cycle: Master sets the data (W).
            //      3rd cycle: Master asserts ready (B).
            // 
            // Read:
            //      1st cycle: Master sets the address (AR).
            //      2nd cycle: Master asserts ready (R).
            TEST_1: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        aw_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = SEND_W;
                        
                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d       = 1'b1;
                        end
                    end                    

                    SEND_W: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;
                        w_data          = rand_wdata_1[n_count_cs];
                        test_state_ns   = WAIT_BRESP;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d    = 1'b1;
                        end                    
                    end
                
                    WAIT_BRESP: begin   
                        b_ready         = 1'b1;    

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = rand_wdata_1[n_count_cs];
                        end

                        if (spm_resp.b_valid) begin
                            test_state_ns   = SEND_AR;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;
                        end
                    end

                    SEND_AR: begin                
                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_RRESP;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    WAIT_RRESP: begin
                        r_ready     = 1'b1;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;            
                        end

                        if (spm_resp.r_valid) begin
                            r_ready         = 1'b0;
                            w_data          = rand_wdata_1[n_count_cs];

                            test_state_ns   = SEND_AW;
                            n_count_ns      = n_count_cs + 1;
                            ar_resp_d       = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                prev_test_case  = test_case_cs;                   
                                test_case_ns    = TEST_2;
                                test_state_ns   = SEND_AW;
                                lat_target_ns   = $urandom_range(TbReadLatency+5,30);
                                lat_count_ns    = '0;
                            end
                        end
                    end
                endcase
            end

            // This test makes TbNumWrites to the SPM.
            // After all writes are over, it makes TbNumReads reads.
            // The Master does not set the Response Ready signal until after ReadLatency.
            // This test makes TbNumWrites to the SPM.
            // After all writes are over, it makes TbNumReads reads.
            //  Writes:
            //      1st cycle: Master sets the address (AW).
            //      2nd cycle: Master sets the data (W).
            //      3+  cycle: Master waits until `ReadLatency+` cycles are over.
            //      3 + ReadLatency+ cycle: Master asserts ready (B).
            //  
            //  Read:
            //      1st cycle: Master sets the address (AR).            
            //      2+  cycle: Master waits until `ReadLatency+` cycles are over.
            //      2 + ReadLatency+ cycle: Master asserts ready (R).
            // Before running `TEST_2` run `TEST_1` to set up `lat_target_cs` correctly.
            TEST_2: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        aw_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = SEND_W;
                        
                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d       = 1'b1;
                        end
                    end

                    SEND_W: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;
                        w_data          = rand_wdata_1[n_count_cs];
                        test_state_ns   = WAIT_BRESP;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d    = 1'b1;
                        end
                    end
                
                    WAIT_BRESP: begin
                        lat_count_ns    = lat_count_cs + 1;
                        if (lat_count_cs >= lat_target_cs) begin
                            b_ready         = 1'b1;

                            if (spm_resp.b_valid) begin
                                test_state_ns   = SEND_AR;
                                aw_resp_d       = 1'b0;
                                w_resp_d        = 1'b0;

                                lat_target_ns   = $urandom_range(TbReadLatency+5,30);
                                lat_count_ns    = '0;
                            end
                        end

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = rand_wdata_1[n_count_cs];
                        end                        
                    end

                    SEND_AR: begin                
                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_RRESP;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    WAIT_RRESP: begin
                        lat_count_ns    = lat_count_cs + 1;
                        if (lat_count_cs >= lat_target_cs) begin
                            r_ready         = 1'b1;

                            if (spm_resp.r_valid) begin                                
                                w_data          = rand_wdata_1[n_count_cs];

                                test_state_ns   = SEND_AW;
                                n_count_ns      = n_count_cs + 1;
                                ar_resp_d       = 1'b0;

                                lat_target_ns   = $urandom_range(TbReadLatency+5,30);
                                lat_count_ns    = '0;

                                if (n_count_cs == TbNumWrites-1) begin
                                    n_count_ns      = '0;
                                    prev_test_case  = test_case_cs;
                                    test_case_ns    = TEST_3;
                                    test_state_ns   = SEND_AW;
                                end
                            end
                        end
                
                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;
                        end
                    end
                endcase
            end

            // This test makes reads and writes in close interval.
            //      1st cycle: Master sets the address (AW).
            //      2nd cycle: Master sets the address (AR).
            //                 Master sets the data (W).          
            //      3rd cycle: Master asserts ready (B).
            //                 Master asserts ready (R).
            // 
            // Note: Since from the POV of the SPM both read and write request are sent in the same clock cycle, 
            //       the SPM can serve either before the other. (It priortizes reads over writes.)
            //       The SPM only considers a write request when both write address and write data are valid.
            //       Based on whether the slave finishes the write or the read, it checks for the old or new value.
            //      
            // Before running `TEST_3` run `TEST_2` to set up the SPM correctly. After `TEST_3` run `TEST_3_DENOUEMENT` 
            // because to verify whether `rand_wdata_2` was written correctly to the SPM or not.
            TEST_3: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        aw_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = SEND_W_PLUS_AR;
                        
                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d       = 1'b1;
                        end
                    end

                    SEND_W_PLUS_AR: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;
                        w_data          = rand_wdata_2[n_count_cs];

                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_BRESP_PLUS_RRESP;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d    = 1'b1;
                        end

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    // Read response received, awaiting write response.
                    WAIT_BRESP: begin
                        b_ready         = 1'b1;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = rand_wdata_2[n_count_cs];
                        end

                        if (spm_resp.b_valid) begin
                            test_state_ns   = SEND_AW;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;
                            n_count_ns      = n_count_cs + 1;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                prev_test_case  = test_case_cs;
                                test_case_ns    = TEST_3_DENOUEMENT;
                                test_state_ns   = SEND_AR;
                            end
                        end
                    end

                    // Write response received, awaiting read response.
                    WAIT_RRESP: begin
                        r_ready         = 1'b1;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;
                        end

                        if (spm_resp.r_valid) begin
                            w_data          = rand_wdata_2[n_count_cs];
                            test_state_ns   = SEND_AW;
                            ar_resp_d       = 1'b0;
                            n_count_ns      = n_count_cs + 1;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                prev_test_case  = test_case_cs;
                                test_case_ns    = TEST_3_DENOUEMENT;
                                test_state_ns   = SEND_AR;
                            end
                        end
                    end
                
                    // Awaiting both read and write response.
                    WAIT_BRESP_PLUS_RRESP: begin
                        b_ready         = 1'b1;
                        r_ready         = 1'b1;

                        if (spm_resp.b_valid) begin
                            test_state_ns   = WAIT_RRESP;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;
                        end

                        if (spm_resp.r_valid) begin
                            w_data          = rand_wdata_1[n_count_cs];
                            test_state_ns   = WAIT_BRESP;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;
                        end                 

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = rand_wdata_2[n_count_cs];
                        end

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;
                        end
                    end                    
                endcase
            end

            TEST_3_DENOUEMENT: begin
                unique case (test_state_cs)
                    SEND_AR: begin                
                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_RRESP;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    WAIT_RRESP: begin
                        r_ready     = 1'b1;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;            
                        end

                        if (spm_resp.r_valid) begin
                            r_ready         = 1'b0;
                            w_data          = rand_wdata_2[n_count_cs];

                            test_state_ns   = SEND_AR;
                            n_count_ns      = n_count_cs + 1;
                            ar_resp_d       = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                prev_test_case  = test_case_cs;                   
                                test_case_ns    = RESET;
                                test_state_ns   = SEND_AW;
                            end
                        end
                    end
                endcase
            end

            RESET: begin
                unique case (test_state_cs) 
                    SEND_AW: begin
                        aw_valid        = 1'b1;
                        aw_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = SEND_W;
                        
                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d       = 1'b1;
                        end
                    end                    

                    SEND_W: begin                
                        w_strb          = 4'b1111;
                        w_valid         = 1'b1;
                        w_data          = 32'd0;
                        test_state_ns   = WAIT_BRESP;

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d    = 1'b1;
                        end                    
                    end
                
                    WAIT_BRESP: begin
                        b_ready         = 1'b1;    

                        // Slave acknowledged valid aw_addr.
                        if (spm_resp.aw_ready) begin
                            aw_resp_d   = 1'b1;
                        end else if (!aw_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            aw_addr     = START_ADDR + n_count_cs*4;
                            aw_valid    = 1'b1;            
                        end

                        // Slave acknowledged valid w_data.
                        if (spm_resp.w_ready) begin
                            w_resp_d   = 1'b1;
                        end else if (!w_resp_q) begin
                        // Slave has not acknowledged aw_addr, keep it set.
                            w_strb          = 4'b1111;
                            w_valid         = 1'b1;
                            w_data          = 32'h1024 * n_count_cs*3;
                        end

                        if (spm_resp.b_valid) begin                            
                            test_state_ns   = SEND_AW;
                            n_count_ns      = n_count_cs + 1;
                            aw_resp_d       = 1'b0;
                            w_resp_d        = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                test_state_ns   = SEND_AR;                                
                            end
                        end
                    end

                    SEND_AR: begin                
                        ar_valid        = 1'b1;
                        ar_addr         = START_ADDR + n_count_cs*4;
                        test_state_ns   = WAIT_RRESP;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d       = 1'b1;
                        end
                    end

                    WAIT_RRESP: begin
                        r_ready     = 1'b1;

                        // Slave acknowledged valid ar_addr.
                        if (spm_resp.ar_ready) begin
                            ar_resp_d   = 1'b1;
                        end else if (!ar_resp_q) begin
                        // Slave has not acknowledged ar_addr, keep it set.
                            ar_addr     = START_ADDR + n_count_cs*4;
                            ar_valid    = 1'b1;            
                        end

                        if (spm_resp.r_valid) begin
                            r_ready         = 1'b0;
                            w_data          = 32'd0;

                            test_state_ns   = SEND_AR;
                            n_count_ns      = n_count_cs + 1;
                            ar_resp_d       = 1'b0;

                            if (n_count_cs == TbNumWrites-1) begin
                                n_count_ns      = '0;
                                test_case_ns    = prev_test_case.next();                                
                                test_state_ns   = SEND_AW;
                            end
                        end
                    end
                endcase
            end

            DONE: begin
                $finish();
            end

            default: ;
        endcase
    end

    // -------
    // Display
    // -------
    // Because $display was being printed twice if executed in the FSM combinatorial block. 
    // The combinatorial block was running twice in the same timestep.
    always_ff @ (posedge clk) begin
        unique case (test_case_cs)
            RESET, TEST_0, TEST_1: begin
                unique case (test_state_cs)
                    SEND_AW: begin
                        if ((n_count_cs == 0)) begin
                            $display("\n\n");
                        end
                    end

                    WAIT_BRESP: begin
                        if (spm_resp.b_valid) begin
                            $display("Write-Test %s [#%0d]", 
                                test_case_cs.name(),
                                n_count_cs);

                            // Slave acknowledged aw_addr multiple times.
                            if (spm_resp.aw_ready && aw_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            // Slave acknowledged w_data multiple times.
                            if (spm_resp.w_ready && w_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.b.resp == axi_pkg::RESP_OKAY) begin
                                $display("Response OKAY.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    // w_data is set in the FSM combinatorial block.
                    WAIT_RRESP: begin
                        if (spm_resp.r_valid) begin
                            $display("Read-Test %s [#%0d]", 
                                    test_case_cs.name(),                                    
                                    n_count_cs);

                            // Slave acknowledged ar_addr multiple times.
                            if (spm_resp.ar_ready && ar_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.r.resp == axi_pkg::RESP_OKAY) begin
                                if (spm_resp.r.data == w_data) begin
                                    $display("Correct value (%x) was read.", spm_resp.r.data);
                                end else begin
                                    $display("Incorrect value was read.\n");
                                    $fatal("Expected vs Read: %x vs %x\n", w_data, spm_resp.r.data);
                                end
                            end else if (spm_resp.r.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.r.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    default: ;
                endcase
            end

            TEST_2: begin
                unique case (test_state_cs)
                    SEND_AW: begin
                        if ((n_count_cs == 0)) begin
                            $display("\n\n");
                        end
                    end

                    WAIT_BRESP: begin
                        if (spm_resp.b_valid && (lat_count_cs >= lat_target_cs)) begin
                            $display("Write-Test %s [#%0d]", 
                                test_case_cs.name(),
                                n_count_cs);

                            // Slave acknowledged aw_addr multiple times.
                            if (spm_resp.aw_ready && aw_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            // Slave acknowledged w_data multiple times.
                            if (spm_resp.w_ready && w_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.b.resp == axi_pkg::RESP_OKAY) begin
                                $display("Response OKAY.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    // w_data is set in the FSM combinatorial block.
                    WAIT_RRESP: begin
                        if (spm_resp.r_valid && (lat_count_cs >= lat_target_cs)) begin
                            $display("Read-Test %s [#%0d]", 
                                    test_case_cs.name(),                                    
                                    n_count_cs);

                            // Slave acknowledged ar_addr multiple times.
                            if (spm_resp.ar_ready && ar_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.r.resp == axi_pkg::RESP_OKAY) begin
                                if (spm_resp.r.data == w_data) begin
                                    $display("Correct value (%x) was read.", spm_resp.r.data);
                                    $display("\n");
                                end else begin
                                    $display("Incorrect value was read.\n");
                                    $fatal("Expected vs Read: %x vs %x\n", w_data, spm_resp.r.data);
                                end
                            end else if (spm_resp.r.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.r.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    default: ;
                endcase
            end

            TEST_3, TEST_3_DENOUEMENT: begin
                unique case (test_state_cs)
                    SEND_AW: begin
                        if ((n_count_cs == 0)) begin
                            $display("\n\n");
                        end
                    end

                    WAIT_BRESP: begin
                        if (spm_resp.b_valid) begin
                            $display("Write-Test %s [#%0d]", 
                                test_case_cs.name(),
                                n_count_cs);

                            // Slave acknowledged aw_addr multiple times.
                            if (spm_resp.aw_ready && aw_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            // Slave acknowledged w_data multiple times.
                            if (spm_resp.w_ready && w_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.b.resp == axi_pkg::RESP_OKAY) begin
                                $display("Response OKAY.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    // w_data is set in the FSM combinatorial block.
                    WAIT_RRESP: begin
                        if (spm_resp.r_valid) begin
                            $display("Read-Test %s [#%0d]", 
                                    test_case_cs.name(),                                    
                                    n_count_cs);

                            // Slave acknowledged ar_addr multiple times.
                            if (spm_resp.ar_ready && ar_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.r.resp == axi_pkg::RESP_OKAY) begin
                                if (spm_resp.r.data == w_data) begin
                                    $display("Correct value (%x) was read.", spm_resp.r.data);
                                end else begin
                                    $display("Incorrect value was read.\n");
                                    $fatal("Expected vs Read: %x vs %x\n", w_data, spm_resp.r.data);
                                end
                            end else if (spm_resp.r.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.r.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    WAIT_BRESP_PLUS_RRESP: begin
                        if (spm_resp.b_valid) begin
                            $display("Write-Test %s [#%0d]", 
                                test_case_cs.name(),
                                n_count_cs);

                            // Slave acknowledged aw_addr multiple times.
                            if (spm_resp.aw_ready && aw_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            // Slave acknowledged w_data multiple times.
                            if (spm_resp.w_ready && w_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.b.resp == axi_pkg::RESP_OKAY) begin
                                $display("Response OKAY.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.b.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end

                        if (spm_resp.r_valid) begin
                            $display("Read-Test %s [#%0d]", 
                                    test_case_cs.name(),                                    
                                    n_count_cs);

                            // Slave acknowledged ar_addr multiple times.
                            if (spm_resp.ar_ready && ar_resp_q) begin
                                $fatal("Ar_addr acknowledged twice!");
                            end

                            if (spm_resp.r.resp == axi_pkg::RESP_OKAY) begin
                                if (spm_resp.r.data == w_data) begin
                                    $display("Correct value (%x) was read.", spm_resp.r.data);
                                end else begin
                                    $display("Incorrect value was read.\n");
                                    $fatal("Expected vs Read: %x vs %x\n", w_data, spm_resp.r.data);
                                end
                            end else if (spm_resp.r.resp == axi_pkg::RESP_SLVERR) begin
                                $fatal("Errored Response SLVERR.");
                            end else if (spm_resp.r.resp == axi_pkg::RESP_DECERR) begin
                                $fatal("Errored Response DECERR.");
                            end
                        end
                    end

                    default: ;
                endcase
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
            test_case_cs    <= INIT;
            n_count_cs      <= '0;
            lat_count_cs    <= '0;
            lat_target_cs   <= '0;
        end else begin
            test_state_cs   <= test_state_ns;
            test_case_cs    <= test_case_ns;
            n_count_cs      <= n_count_ns;
            lat_count_cs    <= lat_count_ns;
            lat_target_cs   <= lat_target_ns;
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            aw_resp_q       <= 1'b0;
            w_resp_q        <= 1'b0;
            ar_resp_q       <= 1'b0;
        end else begin
            aw_resp_q       <= aw_resp_d;
            w_resp_q        <= w_resp_d;
            ar_resp_q       <= ar_resp_d;
        end
    end

    always @ (posedge clk) begin
        // Active-low reset
        if (!rst_n) begin
            spm_req.aw.addr     <= 32'h0000_0000;
            spm_req.aw.prot     <= 3'h0;
            spm_req.aw_valid    <= 1'b0;
            
            spm_req.w.data      <= 32'h0000_0000;
            spm_req.w.strb      <= 4'h0;
            spm_req.w_valid     <= 1'b0;

            spm_req.b_ready     <= 1'b0;

            spm_req.ar.addr     <= 32'h0000_0000;
            spm_req.ar.prot     <= 3'h0;
            spm_req.ar_valid    <= 1'b0;

            spm_req.r_ready     <= 1'b0;
        end else begin   
            spm_req.aw.addr     <= aw_addr;
            spm_req.aw.prot     <= 3'h0;
            spm_req.aw_valid    <= aw_valid;
            
            spm_req.w.data      <= w_data;
            spm_req.w.strb      <= w_strb;
            spm_req.w_valid     <= w_valid;

            spm_req.b_ready     <= b_ready;

            spm_req.ar.addr     <= ar_addr;
            spm_req.ar.prot     <= 3'h0;
            spm_req.ar_valid    <= ar_valid;

            spm_req.r_ready     <= r_ready;
        end
    end

    //-----------------------------------
    // Device Under Test (DUT)
    //-----------------------------------

    pmu_spm #(
        .NumLines    ( NumLines                 ),
        .ReadLatency ( TbReadLatency            ),
        .START_ADDR  ( START_ADDR               ),
        .SPM_LENGTH  ( SPM_LENGTH               ),
        .req_lite_t  ( tb_pmu_pkg::req_lite_t   ),
        .resp_lite_t ( tb_pmu_pkg::resp_lite_t  )
    ) dut (
        .clk_i      ( clk       ),
        .rst_ni     ( rst_n     ),
        .axi_req_i  ( spm_req   ),
        .axi_resp_o ( spm_resp  )
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

endmodule