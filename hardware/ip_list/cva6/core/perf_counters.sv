// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 06.10.2017
// Description: Performance counters


module perf_counters import ariane_pkg::*; #(
  parameter int unsigned                NumPorts      = 3    // number of miss ports
) (
  input  logic                                    clk_i,
  input  logic                                    rst_ni,
  input  logic                                    debug_mode_i, // debug mode
  input  logic [31:0]                             mcountinhibit_i,
  input  riscv::priv_lvl_t                        priv_lvl_i,
  input  logic                                    v_i,
  output logic [31:0]                             overflow_o,
  output logic                                    overflow_irq_o,
  // SRAM like interface
  input  logic [11:0]                             addr_i,   // read/write address (up to 6 counters possible)
  input  logic                                    we_i,     // write enable
  input  riscv::xlen_t                            data_i,   // data to write
  output riscv::xlen_t                            data_o,   // data to read
  // from commit stage
  input  scoreboard_entry_t [NR_COMMIT_PORTS-1:0] commit_instr_i,     // the instruction we want to commit
  input  logic [NR_COMMIT_PORTS-1:0]              commit_ack_i,       // acknowledge that we are indeed committing
  // from L1 caches
  input  logic                                    l1_icache_miss_i,
  input  logic                                    l1_dcache_miss_i,
  // from MMU
  input  logic                                    itlb_miss_i,
  input  logic                                    dtlb_miss_i,
  // from issue stage
  input  logic                                    sb_full_i,
  // from frontend
  input  logic                                    if_empty_i,
  // from PC Gen
  input  exception_t                              ex_i,
  input  logic                                    eret_i,
  input  bp_resolve_t                             resolved_branch_i,
  // for newly added events
  input  exception_t                              branch_exceptions_i,  //Branch exceptions->execute unit-> branch_exception_o
  input  icache_dreq_i_t                          l1_icache_access_i,
  input  dcache_req_i_t[2:0]                      l1_dcache_access_i,
  input  logic [NumPorts-1:0][DCACHE_SET_ASSOC-1:0]miss_vld_bits_i,  //For Cache eviction (3ports-LOAD,STORE,PTW)
  input  logic                                    i_tlb_flush_i,
  input  logic                                    stall_issue_i,  //stall-read operands
  input logic [(ariane_pkg::NumPerfEvents * ariane_pkg::EventIDBits)-1:0] perfc_evu_req,   //PerfCounters EVENTID Request.
  input  logic [(ariane_pkg::NumPCMilesRegs * riscv::VLEN)-1:0]            pcmiles_evu_req, //PC Milestones to Track.
  output [ariane_pkg::NumPerfEvents-1:0]                                   perfc_evu_resp,  //Status of each Performance Counter Event Represented by its ID.
  output [ariane_pkg::NumPCMilesRegs-1:0]                                  pcmiles_evu_resp //Status of whether any of the PC Milestones were hit by the core.
);

  logic [63:0] generic_counter_d[6:1];
  logic [63:0] generic_counter_q[6:1];

  //internal signal to keep track of exception
  logic read_access_exception,update_access_exception;

  localparam int unsigned EventIncrWidth = $clog2(NR_COMMIT_PORTS + 1);
  typedef logic [EventIncrWidth-1:0] event_incr_t;
  event_incr_t event_incr[6:1];
  //internal signal for  MUX select line input
  // RV64 Sscofpmf: OF and five mode inhibit bits; low five bits select events.
  localparam logic [63:0] EventWriteMask = RVH ? 64'hfc00_0000_0000_001f : 64'hf000_0000_0000_001f;
  logic [63:0] mhpmevent_d[6:1];
  logic [63:0] mhpmevent_q[6:1];
  logic mode_inhibit[6:1];
  logic [64:0] counter_sum[6:1];

  logic [NR_COMMIT_PORTS-1:0] load_event;
  logic [NR_COMMIT_PORTS-1:0] store_event;
  logic [NR_COMMIT_PORTS-1:0] branch_event;
  logic [NR_COMMIT_PORTS-1:0] call_event;
  logic [NR_COMMIT_PORTS-1:0] return_event;
  logic [NR_COMMIT_PORTS-1:0] int_event;
  logic [NR_COMMIT_PORTS-1:0] fp_event;
  logic [NR_COMMIT_PORTS-1:0] retired_event;

  function automatic event_incr_t count_commit_events(
    input logic [NR_COMMIT_PORTS-1:0] commit_events
  );
    event_incr_t count;
    count = '0;
    for (int unsigned i = 0; i < NR_COMMIT_PORTS; i++) begin
      count = count + commit_events[i];
    end
    return count;
  endfunction

  //Multiplexer
   always_comb begin : Mux
      event_incr[6:1]='{default:0};
      load_event = '0;
      store_event = '0;
      branch_event = '0;
      call_event = '0;
      return_event = '0;
      int_event = '0;
      fp_event = '0;
      retired_event = '0;

      for (int unsigned j = 0; j < NR_COMMIT_PORTS; j++) begin
         load_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == LOAD);
         store_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == STORE);
         branch_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == CTRL_FLOW);
         call_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == CTRL_FLOW && (commit_instr_i[j].op == ADD || commit_instr_i[j].op == JALR) && (commit_instr_i[j].rd == 'd1 || commit_instr_i[j].rd == 'd5));
         return_event[j] = commit_ack_i[j] & (commit_instr_i[j].op == JALR && commit_instr_i[j].rd == 'd0);
         int_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == ALU || commit_instr_i[j].fu == MULT);
         fp_event[j] = commit_ack_i[j] & (commit_instr_i[j].fu == FPU || commit_instr_i[j].fu == FPU_VEC);
         retired_event[j] = commit_ack_i[j] & !ex_i.valid;
      end

      for(int unsigned i = 1; i <= 6; i++) begin
        case (priv_lvl_i)
          riscv::PRIV_LVL_M: mode_inhibit[i] = mhpmevent_q[i][62];
          riscv::PRIV_LVL_S: mode_inhibit[i] = v_i ? mhpmevent_q[i][59] : mhpmevent_q[i][61];
          riscv::PRIV_LVL_U: mode_inhibit[i] = v_i ? mhpmevent_q[i][58] : mhpmevent_q[i][60];
          default: mode_inhibit[i] = 1'b1;
        endcase
        case(mhpmevent_q[i][4:0])
           5'b00000 : event_incr[i] = '0;
           5'b00001 : event_incr[i] = event_incr_t'(l1_icache_miss_i);//L1 I-Cache misses
           5'b00010 : event_incr[i] = event_incr_t'(l1_dcache_miss_i);//L1 D-Cache misses
           5'b00011 : event_incr[i] = event_incr_t'(itlb_miss_i);//ITLB misses
           5'b00100 : event_incr[i] = event_incr_t'(dtlb_miss_i);//DTLB misses
           5'b00101 : event_incr[i] = count_commit_events(load_event);
           5'b00110 : event_incr[i] = count_commit_events(store_event);
           5'b00111 : event_incr[i] = event_incr_t'(ex_i.valid);//Exceptions
           5'b01000 : event_incr[i] = event_incr_t'(eret_i);//Exception handler returns
           5'b01001 : event_incr[i] = count_commit_events(branch_event);
           5'b01010 : event_incr[i] = event_incr_t'(resolved_branch_i.valid && resolved_branch_i.is_mispredict);//Branch mispredicts
           5'b01011 : event_incr[i] = event_incr_t'(branch_exceptions_i.valid);//Branch exceptions
                   // The standard software calling convention uses register x1 to hold the return address on a call
                   // the unconditional jump is decoded as ADD op
           5'b01100 : event_incr[i] = count_commit_events(call_event);
           5'b01101 : event_incr[i] = count_commit_events(return_event);
           5'b01110 : event_incr[i] = event_incr_t'(sb_full_i);//MSB Full
           5'b01111 : event_incr[i] = event_incr_t'(if_empty_i);//Instruction fetch Empty
           5'b10000 : event_incr[i] = event_incr_t'(l1_icache_access_i.req);//L1 I-Cache accesses
           5'b10001 : event_incr[i] = event_incr_t'(l1_dcache_access_i[0].data_req || l1_dcache_access_i[1].data_req || l1_dcache_access_i[2].data_req);//L1 D-Cache accesses
           5'b10010 : event_incr[i] = event_incr_t'((l1_dcache_miss_i && miss_vld_bits_i[0] == 8'hFF) || (l1_dcache_miss_i && miss_vld_bits_i[1] == 8'hFF) || (l1_dcache_miss_i && miss_vld_bits_i[2] == 8'hFF));//eviction
           5'b10011 : event_incr[i] = event_incr_t'(i_tlb_flush_i);//I-TLB flush
           5'b10100 : event_incr[i] = count_commit_events(int_event);
           5'b10101 : event_incr[i] = count_commit_events(fp_event);
           5'b10110 : event_incr[i] = event_incr_t'(stall_issue_i);//Pipeline bubbles
           5'b10111 : event_incr[i] = event_incr_t'(1'b1);//Cycles
           5'b11000 : event_incr[i] = count_commit_events(retired_event);//Instructions retired
           default:   event_incr[i] = '0;
         endcase
       end

    end

    always_comb begin : generic_counter
        riscv::xlen_t read_data;
        logic [31:0] overflow_status;
        logic overflow_request;
        generic_counter_d = generic_counter_q;
        read_data = 'b0;
        mhpmevent_d = mhpmevent_q;
	    overflow_status = '0;
	    overflow_request = 1'b0;
	    read_access_exception =  1'b0;
	    update_access_exception =  1'b0;

      for(int unsigned i = 1; i <= 6; i++) begin
         overflow_status[i+2] = mhpmevent_q[i][63];
         counter_sum[i] = {1'b0, generic_counter_q[i]} + 65'(event_incr[i]);
         // A counter write wins over the same cycle's increment/overflow.
         if ((!debug_mode_i) && (!mcountinhibit_i[i+2]) && (!mode_inhibit[i]) &&
             !(we_i && addr_i == (12'hb02 + i))) begin
             if (event_incr[i] != '0) begin
                generic_counter_d[i] = counter_sum[i][63:0];
                // A selector write wins over its OF update and request, but
                // does not discard an otherwise valid old-selector increment.
                if (counter_sum[i][64] && !mhpmevent_q[i][63] &&
                    !(we_i && addr_i == (12'h322 + i))) begin
                  mhpmevent_d[i][63] = 1'b1;
                  overflow_request = 1'b1;
                end
             end
        end
      end

     //Read
         unique case (addr_i)
            riscv::CSR_MHPM_COUNTER_3,
            riscv::CSR_MHPM_COUNTER_4,
            riscv::CSR_MHPM_COUNTER_5,
            riscv::CSR_MHPM_COUNTER_6,
            riscv::CSR_MHPM_COUNTER_7,
            riscv::CSR_MHPM_COUNTER_8  :begin if (riscv::XLEN == 32) read_data = generic_counter_q[addr_i-riscv::CSR_MHPM_COUNTER_3 + 1][31:0]; else read_data = generic_counter_q[addr_i-riscv::CSR_MHPM_COUNTER_3 + 1];end
            riscv::CSR_L1_ICACHE_MISS,
            riscv::CSR_L1_DCACHE_MISS,
            riscv::CSR_ITLB_MISS,
            riscv::CSR_DTLB_MISS,
            riscv::CSR_LOAD,
            riscv::CSR_STORE : begin
              if (riscv::XLEN == 32) read_data = generic_counter_q[addr_i-riscv::CSR_L1_ICACHE_MISS + 1][31:0];
              else read_data = generic_counter_q[addr_i-riscv::CSR_L1_ICACHE_MISS + 1];
            end
            riscv::CSR_MHPM_COUNTER_3H,
            riscv::CSR_MHPM_COUNTER_4H,
            riscv::CSR_MHPM_COUNTER_5H,
            riscv::CSR_MHPM_COUNTER_6H,
            riscv::CSR_MHPM_COUNTER_7H,
            riscv::CSR_MHPM_COUNTER_8H :begin if (riscv::XLEN == 32) read_data = generic_counter_q[addr_i-riscv::CSR_MHPM_COUNTER_3H + 1][63:32]; else read_access_exception = 1'b1;end
            riscv::CSR_MHPM_EVENT_3,
            riscv::CSR_MHPM_EVENT_4,
            riscv::CSR_MHPM_EVENT_5,
            riscv::CSR_MHPM_EVENT_6,
            riscv::CSR_MHPM_EVENT_7,
            riscv::CSR_MHPM_EVENT_8   : read_data = mhpmevent_q[addr_i-riscv::CSR_MHPM_EVENT_3 + 1] ;
            default: read_data = 'b0;
        endcase

     //Write
     if(we_i) begin
        unique case(addr_i)
            riscv::CSR_MHPM_COUNTER_3,
            riscv::CSR_MHPM_COUNTER_4,
            riscv::CSR_MHPM_COUNTER_5,
            riscv::CSR_MHPM_COUNTER_6,
            riscv::CSR_MHPM_COUNTER_7,
            riscv::CSR_MHPM_COUNTER_8  :begin if (riscv::XLEN == 32) generic_counter_d[addr_i-riscv::CSR_MHPM_COUNTER_3 + 1][31:0] = data_i; else generic_counter_d[addr_i-riscv::CSR_MHPM_COUNTER_3 + 1] = data_i; end
            riscv::CSR_MHPM_COUNTER_3H,
            riscv::CSR_MHPM_COUNTER_4H,
            riscv::CSR_MHPM_COUNTER_5H,
            riscv::CSR_MHPM_COUNTER_6H,
            riscv::CSR_MHPM_COUNTER_7H,
            riscv::CSR_MHPM_COUNTER_8H :begin if (riscv::XLEN == 32) generic_counter_d[addr_i-riscv::CSR_MHPM_COUNTER_3H + 1][63:32] = data_i; else update_access_exception = 1'b1;end
            riscv::CSR_MHPM_EVENT_3,
            riscv::CSR_MHPM_EVENT_4,
            riscv::CSR_MHPM_EVENT_5,
            riscv::CSR_MHPM_EVENT_6,
            riscv::CSR_MHPM_EVENT_7,
            riscv::CSR_MHPM_EVENT_8   : mhpmevent_d[addr_i-riscv::CSR_MHPM_EVENT_3 + 1] = data_i & EventWriteMask;
            default: update_access_exception =  1'b1;
        endcase
      end
      // Publish each cross-module output once, avoiding xsim delta-cycle
      // rings caused by transient default-then-override assignments.
      data_o = read_data;
      overflow_o = overflow_status;
      overflow_irq_o = overflow_request;
    end

//Registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            generic_counter_q <= '{default:0};
            mhpmevent_q       <= '{default:0};
        end else begin
            generic_counter_q <= generic_counter_d;
            mhpmevent_q       <= mhpmevent_d;
       end
   end


  perf_counters_evu
    #(
    //.CVA6Cfg(  CVA6Cfg )
  .NrCommitPorts( NR_COMMIT_PORTS )
    ) perf_evu_inst(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .l1_icache_miss_en(l1_icache_miss_i),    
        .l1_dcache_miss_en(l1_dcache_miss_i),    
        .itlb_miss_en(itlb_miss_i),         
        .dtlb_miss_en(dtlb_miss_i),         
        .load_event_en(|load_event),        
        .store_event_en(|store_event),       
        .ex_valid_en(ex_i.valid),          
        .exception_handle_en(eret_i),  
        .branch_event_en(|branch_event),      
        .branch_mispredicts_en(resolved_branch_i.valid && resolved_branch_i.is_mispredict),
        .branch_exceptions_en(branch_exceptions_i.valid), 
        .call_event_en(|call_event),        
        .return_event_en(|return_event),      
        .msb_full_en(sb_full_i),          
        .inst_fetch_empty_en(if_empty_i),  
        .l1_icache_access_en(l1_icache_access_i.req),  
        .l1_dcache_access_en(l1_dcache_access_i[0].data_req || l1_dcache_access_i[1].data_req || l1_dcache_access_i[2].data_req), 
        .cache_eviction_en((l1_dcache_miss_i && miss_vld_bits_i[0] == 8'hFF) || (l1_dcache_miss_i && miss_vld_bits_i[1] == 8'hFF) || (l1_dcache_miss_i && miss_vld_bits_i[2] == 8'hFF)),
        .tlb_flush_en(i_tlb_flush_i),
        .int_event_en(|int_event),
        .fp_event_en(|fp_event),
        .stall_issue_en(stall_issue_i),
        .perfc_req(perfc_evu_req),           
        .pcmiles_req(pcmiles_evu_req),
        .commit_pc(commit_instr_i),
        .commit_ack(commit_ack_i),
        .perfc_resp(perfc_evu_resp),
        .pcmiles_resp(pcmiles_evu_resp)
    );  

endmodule
