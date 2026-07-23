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

module spu_r_chan #(
    // CAM Depth.
    parameter int unsigned DEPTH            = 8,

    /// AXI4 Specifications
    parameter int unsigned IdWidth          = 8,
    parameter int unsigned AddrWidth        = 64,
    parameter int unsigned DataWidth        = 64,

    // `spu_r_chan` parameters.
    parameter type         ar_chan_t        = logic,
    parameter type         r_chan_t         = logic,
    parameter type         latency_t        = logic,

    /// Source ID Specifications
    // Assume, we have 10 bits for AXI ID, and bits 7-9 are used for ID,
    // then set SourceIDStart = 7, SourceIDEnd = 9. (Both inclusive.) 
    parameter int unsigned SourceIDStart    = 0,
    parameter int unsigned SourceIDEnd      = 0,

    /// Address Indexing.
    // These must be provided.
    parameter int unsigned N_ADDR_RULES     = 1,
    parameter type         addr_rule_t      = logic,

    // These are autofilled.
    parameter int unsigned SOURCE_ID_BITS   = SourceIDEnd - SourceIDStart + 1,

    parameter type         id_t             = logic [IdWidth-1:0],
    parameter type         addr_t           = logic [AddrWidth-1:0],
    parameter type         data_t           = logic [DataWidth-1:0],
    parameter type         strb_t           = logic [DataWidth/8-1:0],
    parameter type         source_id_t      = logic [SOURCE_ID_BITS-1:0],

    parameter type         addr_map_t       = addr_rule_t [N_ADDR_RULES-1:0],
    parameter int unsigned ADDR_IDX_BITS    = (N_ADDR_RULES == 1) ? 1 : $clog2(N_ADDR_RULES),
    // `addr_map_t` is an array of N_ADDR_RULES `addr_rule_t`.
    parameter type         addr_idx_t       = logic [ADDR_IDX_BITS-1:0]
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  ar_chan_t    ar_chan_i,
    input  r_chan_t     r_chan_i,
    input  addr_map_t   addr_map_i,
    output logic        valid_o,         // Can omit this later?
    output source_id_t  source_id_o,
    output addr_idx_t   addr_idx_o,
    output latency_t    latency_o
);
genvar gen_i;
integer i_m;
integer i_y;
integer i_e;

typedef logic [63:0]     timer_t;
typedef logic [31:0]     timer_l_t;

localparam int unsigned INDEX_WIDTH = (DEPTH==1) ? 1 : $clog2(DEPTH);
typedef logic [INDEX_WIDTH-1:0]     idx_t;

// Internal SPU timer to count
logic [63:0]            spu_timer;

id_t        [DEPTH-1:0] id_d;           // ID of the request being monitored.
timer_l_t   [DEPTH-1:0] req_start_d;    // Stores the starting time (lower 32-bits) of the request.
logic       [DEPTH-1:0] valid_d;        // Indicates that the entry is valid.
logic       [DEPTH-1:0] oldest_d;       // Is this request the oldest among all requests with same ID?
logic       [DEPTH-1:0] youngest_d;     // Is this request the youngest among all requests with same ID?
idx_t       [DEPTH-1:0] ptr_d;          // Pointer to the next oldest request with the same ID.
addr_idx_t  [DEPTH-1:0] addr_idx_d;     // Stores the address index of the request.


id_t        [DEPTH-1:0] id_q;           // ID of the request being monitored.
timer_l_t   [DEPTH-1:0] req_start_q;    // Stores the starting time (lower 32-bits) of the request.
logic       [DEPTH-1:0] valid_q;        // Indicates that the entry is valid.
logic       [DEPTH-1:0] oldest_q;       // Is this request the oldest among all requests with same ID?
logic       [DEPTH-1:0] youngest_q;     // Is this request the youngest among all requests with same ID?
idx_t       [DEPTH-1:0] ptr_q;          // Pointer to the next oldest request with the same ID.
addr_idx_t  [DEPTH-1:0] addr_idx_q;     // Stores the address index of the request.

logic       ins_op;         // Indicates that a new request will be added to the CAM.
logic       del_op;         // Indicates that an old request will be removed from the CAM.

idx_t       mmatch;         // Points to the oldest request with the same ID.
logic       mmatch_valid;

idx_t       ematch;         // Points to an empty space in the CAM to populate with the new request.
logic       ematch_valid;

idx_t       ymatch;         // Points to the youngest entry with the same ID as the new request that is to be populated in the CAM.
logic       ymatch_valid;

// SPU Timer
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        spu_timer <= '0;
    end else begin
        spu_timer <= spu_timer + 1;
    end
end

// Logic to find address map index.
addr_idx_t dec_addr_idx;
addr_idx_t default_idx;
assign default_idx  = N_ADDR_RULES'(0);     
addr_decode #(
    .NoIndices        ( N_ADDR_RULES     ),
    .NoRules          ( N_ADDR_RULES     ),
    .addr_t           ( addr_t           ),
    .rule_t           ( addr_rule_t      )
) i_r_chan_decode (
    .addr_i           ( ar_chan_i.addr   ),
    .addr_map_i       ( addr_map_i       ),
    .idx_o            ( dec_addr_idx     ),
    .dec_valid_o      (                  ),
    .dec_error_o      (                  ),
    .en_default_idx_i ( 1'b1             ),
    // Default is DSPM.
    .default_idx_i    ( default_idx      )  
);

assign ins_op = ar_chan_i.valid;
assign del_op = r_chan_i.valid && r_chan_i.last;

// Find oldest matching key to delete.
always_comb begin
    mmatch       = '0;
    mmatch_valid = 1'b0;
    for(i_m=0; i_m<DEPTH; i_m=i_m+1) begin
        if (del_op && valid_q[i_m] && oldest_q[i_m] && (id_q[i_m] == r_chan_i.id)) begin
            mmatch       = i_m;
            mmatch_valid = 1'b1;
        end
    end
end

// Find youngest matching key to insert new request.
always_comb begin
    ymatch       = '0;
    ymatch_valid = 1'b0;
    
    for(i_y=0; i_y<DEPTH; i_y=i_y+1) begin
        if (ins_op && valid_q[i_y] && youngest_q[i_y] && (id_q[i_y] == ar_chan_i.id)) begin
            ymatch       = i_y;
            ymatch_valid = 1'b1;
        end
    end
end

// Find empty slot.
always_comb begin
    ematch       = '0;
    ematch_valid = 1'b0;
    for(i_e=0; i_e<DEPTH; i_e=i_e+1) begin
        if (ins_op && !valid_q[i_e]) begin
            ematch       = i_e;
            ematch_valid = 1'b1;
        end
    end
end

// Hardware to add or remove entries.
for(gen_i=0; gen_i<DEPTH; gen_i=gen_i+1) begin
    always_comb begin
        id_d[gen_i]        = id_q[gen_i];
        ptr_d[gen_i]       = ptr_q[gen_i];
        oldest_d[gen_i]    = oldest_q[gen_i];
        youngest_d[gen_i]  = youngest_q[gen_i];
        req_start_d[gen_i] = req_start_q[gen_i];
        valid_d[gen_i]     = valid_q[gen_i];
        addr_idx_d[gen_i]  = addr_idx_q[gen_i];

        if (ins_op) begin
            // See if another entry with same ID exists.
            // If yes, then `ptr` of that entry will point to this new entry.
            // And that entry is no longer youngest. 
            // Only do this if a new empty slot was found for the request.
            if (ymatch_valid && ematch_valid && (gen_i == ymatch)) begin
                youngest_d[gen_i]  = 1'b0;
                ptr_d[gen_i]       = ematch;
            end

            // Check if an empty slot was found.
            // If yes, make it the youngest for that ID group.
            // Every new request points to itself.
            if (ematch_valid && (gen_i == ematch)) begin
                id_d[gen_i]        = ar_chan_i.id;
                oldest_d[gen_i]    = 1'b0;
                youngest_d[gen_i]  = 1'b1;
                ptr_d[gen_i]       = ematch;
                req_start_d[gen_i] = spu_timer;
                valid_d[gen_i]     = 1'b1;
                addr_idx_d[gen_i]  = dec_addr_idx;

                // If no other request with same ID is present, then this is the first
                // request for that ID group, make it both the oldest and the youngest.
                if (!ymatch_valid) begin
                    oldest_d[gen_i] = 1'b1;
                end
            end
        end

        // Kill the current entry because it will be output this clock cycle.
        if (del_op && mmatch_valid && (gen_i == mmatch)) begin
            valid_d[gen_i]         = 1'b0;
        end

        // Update the oldest bit for the next entry (pointed to be `ptr_q[mmatch]`).
        // Don't need to check validity of the pointer because if this is the only request with that ID
        // then it will be pointing to itself.
        if (del_op && !ins_op && mmatch_valid && (gen_i == ptr_q[mmatch])) begin
            oldest_d[gen_i]  = 1'b1;
        end

        if (del_op && ins_op && mmatch_valid && (gen_i == ptr_d[mmatch])) begin
            oldest_d[gen_i]  = 1'b1;
        end
    end
end

// Hardware to store and output latency.
assign valid_o     = del_op && mmatch_valid;
assign source_id_o = r_chan_i.id[ SourceIDStart +: SOURCE_ID_BITS ];

// Output logic.
always_comb begin
    latency_o = '0;
    if (del_op) begin
        latency_o   = spu_timer - req_start_q[mmatch];
        addr_idx_o  = addr_idx_q[mmatch];
    end
end

// FF to store latency information.
for(gen_i=0; gen_i<DEPTH; gen_i=gen_i+1) begin
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            id_q[gen_i]        <= '0;
            req_start_q[gen_i] <= '0;
            oldest_q[gen_i]    <= 1'b0;
            youngest_q[gen_i]  <= 1'b0;
            ptr_q[gen_i]       <= '0;
            valid_q[gen_i]     <= 1'b0;
            addr_idx_q[gen_i]  <= '0;
        end else begin
            id_q[gen_i]        <= id_d[gen_i];
            req_start_q[gen_i] <= req_start_d[gen_i];
            oldest_q[gen_i]    <= oldest_d[gen_i];
            youngest_q[gen_i]  <= youngest_d[gen_i];
            ptr_q[gen_i]       <= ptr_d[gen_i];
            valid_q[gen_i]     <= valid_d[gen_i];
            addr_idx_q[gen_i]  <= addr_idx_d[gen_i];
        end
    end
end 
endmodule
