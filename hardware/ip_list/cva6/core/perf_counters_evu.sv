
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

// Description: Performance Counters EVU

//This module is responsible for routing the CVA6 PERFORMANCE COUNTER EVENT STATUS
//For the EventIDs mentioned by the user software, to the PMU.
//Additionally, this module is responsible for keeping track of PC Milestones as well.

import ariane_pkg::*;

module perf_counters_evu
  #(
    // parameter config_pkg::cva6_cfg_t CVA6Cfg  = config_pkg::cva6_cfg_empty
    parameter int unsigned NrCommitPorts = ariane_pkg::NR_COMMIT_PORTS
  )(
    input logic clk_i,
    input logic rst_ni,
    input l1_icache_miss_en,    //L1 I-Cache misses
    input l1_dcache_miss_en,    //L1 D-Cache misses
    input itlb_miss_en,         //ITLB misses
    input dtlb_miss_en,         //DTLB misses
    input load_event_en,        //Load accesses
    input store_event_en,       //Store accesses
    input ex_valid_en,          //Exceptions
    input exception_handle_en,  //Exception handler returns
    input branch_event_en,      // Branch instructions
    input branch_mispredicts_en,//Branch Mispredicts
    input branch_exceptions_en, //Branch exceptions
    input call_event_en,        //Call
    input return_event_en,      //Return
    input msb_full_en,          //MSB Full
    input inst_fetch_empty_en,  //Instruction fetch Empty
    input l1_icache_access_en,  //L1 I-Cache accesses
    input l1_dcache_access_en,  //L1 D-Cache accesses
    input cache_eviction_en,    //eviction
    input tlb_flush_en,         //I-TLB flush
    input int_event_en,         //Integer instruction
    input fp_event_en,          //Floating Point Instructions
    input stall_issue_en,        //Pipeline bubbles

    input logic [(ariane_pkg::NumPerfEvents * ariane_pkg::EventIDBits)-1:0] perfc_req,  //PerfCounters EVENTID Request.
    input logic [(ariane_pkg::NumPCMilesRegs * riscv::VLEN)-1:0]            pcmiles_req,   //PC Milestones to Track.

    input  scoreboard_entry_t [NrCommitPorts-1:0]                   commit_pc,                //The instruction we want to commit
    input  logic [NrCommitPorts-1:0]                                commit_ack,               //Acknowledge that we are indeed committing
    output logic [ariane_pkg::NumPerfEvents-1:0]                            perfc_resp,               //Status of each Performance Counter Event Represented by its ID.
    output logic [ariane_pkg::NumPCMilesRegs-1:0]                           pcmiles_resp              //Status of whether any of the PC Milestones were hit by the Core.
);

// This block is used to assign event statuses.
// Each wire is dedicated to sending the status of the 
// Event whose request to track is obtained from perfc_req.

logic [ariane_pkg::NumPerfEvents-1:0] pc_track_enable;
logic [ariane_pkg::NumPCMilesRegs-1:0]  pcmiles_resp_en;

always_ff@(posedge clk_i) begin
 if(!rst_ni) begin
    perfc_resp  <= '0;
    pc_track_enable <= '0;
 end
 else begin
  for(int i=0; i<ariane_pkg::NumPerfEvents; i++) begin
    pc_track_enable[i] <= 0;
    case(perfc_req[i * ariane_pkg::EventIDBits +: ariane_pkg::EventIDBits])
        5'b00000: perfc_resp[i] <= 0;
        5'b00001: perfc_resp[i] <= l1_icache_miss_en;    //L1 I-Cache misses
        5'b00010: perfc_resp[i] <= l1_dcache_miss_en;    //L1 D-Cache misses
        5'b00011: perfc_resp[i] <= itlb_miss_en;         //ITLB misses
        5'b00100: perfc_resp[i] <= dtlb_miss_en;         //DTLB misses
        5'b00101: perfc_resp[i] <= load_event_en;        //Load accesses
        5'b00110: perfc_resp[i] <= store_event_en;       //Store accesses
        5'b00111: perfc_resp[i] <= ex_valid_en;          //Exceptions
        5'b01000: perfc_resp[i] <= exception_handle_en;  //Exception handler returns
        5'b01001: perfc_resp[i] <= branch_event_en;      // Branch instructions
        5'b01010: perfc_resp[i] <= branch_mispredicts_en;//Branch mispredicts
        5'b01011: perfc_resp[i] <= branch_exceptions_en; //Branch exceptions
        5'b01100: perfc_resp[i] <= call_event_en;        //Call
        5'b01101: perfc_resp[i] <= return_event_en;      //Return
        5'b01110: perfc_resp[i] <= msb_full_en;          //MSB Full
        5'b01111: perfc_resp[i] <= inst_fetch_empty_en;  //Instruction fetch Empty
        5'b10000: perfc_resp[i] <= l1_icache_access_en;  //L1 I-Cache accesses
        5'b10001: perfc_resp[i] <= l1_dcache_access_en;  //L1 D-Cache accesses
        5'b10010: perfc_resp[i] <= cache_eviction_en;    //eviction
        5'b10011: perfc_resp[i] <= tlb_flush_en;         //I-TLB flush
        5'b10100: perfc_resp[i] <= int_event_en;         //Integer instructions
        5'b10101: perfc_resp[i] <= fp_event_en;          //Floating Point Instructions
        5'b10110: perfc_resp[i] <= stall_issue_en;       //Pipeline bubbles
        5'b10111: begin perfc_resp[i] <= (|pcmiles_resp); pc_track_enable[i]<= 1; end //Event ID = 23 Indicates that PC_Milestones must be tracked.
        default:  perfc_resp[i] <= 0;
    endcase
  end
 end
end

//This block is used for comparing the commit_pc with the pc_milestones from software
//If any of the PCs match what we have from the test, A Milestone is Hit!
//Commit PCs are only compared when the commit_ack for it goes high.

logic [NrCommitPorts-1:0] [ariane_pkg::NumPCMilesRegs-1:0] combined_tracker;
logic [NrCommitPorts-1:0] [ariane_pkg::NumPCMilesRegs-1:0] match_prev; // Match previous that holds the previous match.
logic [NrCommitPorts-1:0] [ariane_pkg::NumPCMilesRegs-1:0] match;      //Match seen for the first time. More like an edge trigger.
logic not_repeat;

//Registering the inputs.
logic [NrCommitPorts-1:0][riscv::VLEN-1:0]   commit_pc_reg;
logic [NrCommitPorts-1:0]                    commit_ack_reg;

always_ff@(posedge clk_i) begin
  if(!rst_ni) begin
    commit_pc_reg      <= '0;
    commit_ack_reg     <= '0;
  end else begin
    for(int i=0; i<NrCommitPorts; i++) begin
      commit_pc_reg[i] <= commit_pc[i].pc;
      commit_ack_reg[i] <= commit_ack[i];
    end
  end
end


always_ff@(posedge clk_i) begin
  if(!rst_ni) begin
      combined_tracker <= '0;
  end else begin
    for(int i=0; i<NrCommitPorts;i++) begin
      for(int j=0; j<ariane_pkg::NumPCMilesRegs; j++) begin
          //If the PC Value Matches when the Acknowledge goes high. We hit a probable milestone.
          combined_tracker[i][j]  <= (commit_ack_reg[i] && (commit_pc_reg[i] == pcmiles_req[(j*riscv::VLEN) +: riscv::VLEN]));
      end
    end
  end
end


assign pcmiles_resp = (rst_ni & |pc_track_enable) ? {combined_tracker[0] | combined_tracker[1]} : 0;

endmodule
