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

module spu_ax_chan #(
    // Static configuration parameters of the cache.
    parameter int unsigned SetAssociativity = 8,
    parameter int unsigned NumLines         = 256,
    parameter int unsigned NumBlocks        = 8,

    /// AXI4 Specifications
    parameter int unsigned IdWidth          = 8,
    parameter int unsigned AddrWidth        = 64,
    parameter int unsigned DataWidth        = 64,

    /// Source ID Specifications
    // Assume, we have 10 bits for AXI ID, and bits 7-9 are used for ID,
    // then set SourceIDStart = 7, SourceIDEnd = 9. (Both inclusive.)
    parameter int unsigned SourceIDStart    = 0,
    parameter int unsigned SourceIDEnd      = 0,

    // `spu_ax_chan` parameters.
    parameter type         ax_chan_t        = logic,

    // Set to 0 for size in number of cachelines.
    // Set to 1 for size in bytes.
    parameter bit          SizeInBytes      = 1,
    parameter int unsigned SIZE_BITS        = 32,   // Varies depending on whether the size is
                                                    // measured in cachelines or bytes.

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
    input  addr_map_t               addr_map_i,
    input  ax_chan_t                ax_chan_i,
    output logic                    valid_o,
    output source_id_t              source_id_o,
    output logic                    unaligned_transfer_o,
    output logic [SIZE_BITS-1:0]    size_of_burst_o,
    output addr_idx_t               addr_idx_o
);

    // Line offset is the index where we are interested in, or where the line index starts.
    localparam int unsigned IndexLength         = unsigned'($clog2(NumLines));
    localparam int unsigned BlockOffsetLength   = unsigned'($clog2(NumBlocks));
    localparam int unsigned ByteOffsetLength    = unsigned'($clog2(AddrWidth / 32'd8));
    localparam int unsigned LineOffset          = ByteOffsetLength + BlockOffsetLength;
    // How many bytes are present in one cache line?
    localparam int unsigned BytesPerLine        = 1 << LineOffset;

    // How many bytes are on this cache line?
    // Worst-case: Transfer is aligned and you have `1 << LineOffset` number of bytes.
    logic [LineOffset:0]  bytes_on_line;
    logic [SIZE_BITS-1:0] bytes_in_burst;
    logic [SIZE_BITS-1:0] cachelines_affected;

    // Signals for number of cachelines accessed.
    addr_t  this_line_address; // address of this line (tag included)
    addr_t  next_line_address; // address of the next line (tag included)

    addr_idx_t default_idx;
    assign default_idx  = N_ADDR_RULES'(0);     
    addr_decode #(
      .NoIndices        ( N_ADDR_RULES     ),
      .NoRules          ( N_ADDR_RULES     ),
      .addr_t           ( addr_t           ),
      .rule_t           ( addr_rule_t      )
    ) i_ax_chan_decode (
      .addr_i           ( ax_chan_i.addr   ),
      .addr_map_i       ( addr_map_i       ),
      .idx_o            ( addr_idx_o       ),
      .dec_valid_o      (                  ),
      .dec_error_o      (                  ),
      .en_default_idx_i ( 1'b1             ),
      // Default is DSPM.
      .default_idx_i    ( default_idx      )  
    );

    assign valid_o     = ax_chan_i.valid;
    assign source_id_o = ax_chan_i.id[ SourceIDStart +: SOURCE_ID_BITS ];

    // The transfer does not happen at the start of a new cache line.
    assign unaligned_transfer_o = |(ax_chan_i.addr[0+:LineOffset]);

    // Size in cachelines.
    if (SizeInBytes == 0) begin
        always_comb begin: gen_cacheline_count
            this_line_address = addr_t'(ax_chan_i.addr[LineOffset+:(AddrWidth-LineOffset)]
                                        << LineOffset);
            next_line_address = this_line_address + (addr_t'(1) << LineOffset);

            // How many bytes are on the line from curr addr to the end?
            bytes_on_line       = next_line_address - ax_chan_i.addr;
            // How many bytes are sent in one burst?
            bytes_in_burst      = (ax_chan_i.len+1) << ax_chan_i.size;

            cachelines_affected  = 1;

            if (bytes_on_line < bytes_in_burst) begin
                cachelines_affected += ((bytes_in_burst - bytes_on_line) >> LineOffset) + 1;
            end
        end
        assign size_of_burst_o = cachelines_affected;
    // Size in bytes.
    end else begin
        always_comb begin: gen_byte_count
            this_line_address = addr_t'(ax_chan_i.addr[LineOffset+:(AddrWidth-LineOffset)]
                                        << LineOffset);
            next_line_address = this_line_address + (addr_t'(1) << LineOffset);
            // How many bytes are sent in one burst?
            bytes_in_burst      = (ax_chan_i.len+1) << ax_chan_i.size;
        end
        assign size_of_burst_o = bytes_in_burst;
    end

endmodule
