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

module axi_spu_top #(
    /// Static configuration parameters of the cache.
    parameter int unsigned SetAssociativity = 8,
    parameter int unsigned NumLines         = 256,
    parameter int unsigned NumBlocks        = 8,

    /// Source ID Specifications
    // Assume, we have 10 bits for AXI ID, and bits 7-9 are used for ID,
    // then set SourceIDStart = 7, SourceIDEnd = 9. (Both inclusive.)
    parameter int unsigned SourceIDStart    = 0,
    parameter int unsigned SourceIDEnd      = 0,

    /// AXI4 Specifications
    parameter int unsigned IdWidth          = 8,
    parameter int unsigned AddrWidth        = 64,
    parameter int unsigned DataWidth        = 64,

    // Set to 0 for size in number of cachelines.
    // Set to 1 for size in bytes.
    parameter bit          SizeInBytes      = 1,

    /// Address Indexing.
    // These must be provided.
    parameter int unsigned N_ADDR_RULES     = 1,
    parameter type         addr_rule_t      = logic,

    /// FIFO Details.
    parameter int unsigned CAM_DEPTH        = 17,
    parameter int unsigned FIFO_DEPTH       = 8,

    // These are autofilled.
    // Assuming we have 10 bits for AXI ID, and bits 7-9 are used for ID,
    // then set SourceIDStart = 7, SourceIDEnd = 9. (Both inclusive.)
    // SOURCE_ID_BITS = SourceIDEnd - SourceIDStart + 1 = 3.
    parameter int unsigned SOURCE_ID_BITS   = SourceIDEnd - SourceIDStart + 1,

    parameter type         id_t             = logic [IdWidth-1:0],
    parameter type         addr_t           = logic [AddrWidth-1:0],
    parameter type         data_t           = logic [DataWidth-1:0],
    parameter type         strb_t           = logic [DataWidth/8-1:0],
    parameter type         source_id_t      = logic [SOURCE_ID_BITS-1:0],

    parameter type         addr_map_t       = addr_rule_t [N_ADDR_RULES-1:0],
    parameter int unsigned ADDR_IDX_BITS    = (N_ADDR_RULES == 1) ? 1 : $clog2(N_ADDR_RULES),
    // `addr_map_t` is an array of N_ADDR_RULES `addr_rule_t`.
    parameter type         addr_idx_t       = logic [ADDR_IDX_BITS-1:0],

    // Note: `SIZE_BITS + 1` must be equal to `LATENCY_BITS`.
    parameter int unsigned SIZE_BITS        = pmu_pkg::EVENT_INFO_BITS - (ADDR_IDX_BITS+1),
    parameter int unsigned LATENCY_BITS     = pmu_pkg::EVENT_INFO_BITS - ADDR_IDX_BITS,

  `ifndef TARGET_SYNTHESIS
    parameter string       SPU_NAME         = "spu_top",
  `endif
    parameter bit          LogData          = 0
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    input  addr_map_t               addr_map_i,
    AXI_BUS.Slave                   spu_slv,
    AXI_BUS.Master                  spu_mst,
    output pmu_pkg::pmu_event_t     e_out
);
    import spu_pkg::*;
    localparam N_BUF = 1;

    // Ax Buffer
    typedef struct packed {
        id_t                id;
        addr_t              addr;
        axi_pkg::burst_t    burst;
        axi_pkg::len_t      len;
        axi_pkg::size_t     size;
        logic               valid;
    } ax_chan_t;

    // W Buffer
    typedef struct packed {
        data_t      data;
        logic       last;
        strb_t      strb;
        logic       valid;
    } w_chan_t;

    // R Buffer
    typedef struct packed {
        id_t            id;
        data_t          data;
        logic           last;
        axi_pkg::resp_t resp;
        logic           valid;
    } r_chan_t;

    // B Buffer
    typedef struct packed {
        id_t            id;
        axi_pkg::resp_t resp;
        logic           valid;
    } b_chan_t;

    ax_chan_t   aw_chan;
    ax_chan_t   ar_chan;
    // w_chan_t    w_chan;
    r_chan_t    r_chan;
    b_chan_t    b_chan;

    logic       new_aw_req_q;
    logic       new_aw_req_d;
    logic       new_ar_req_q;
    logic       new_ar_req_d;
    logic       new_r_resp_q;
    logic       new_r_resp_d;
    logic       new_b_resp_q;
    logic       new_b_resp_d;   

    // Line offset is the index where we are interested in, or where the line index starts.
    localparam int unsigned IndexLength         = unsigned'($clog2(NumLines));
    localparam int unsigned BlockOffsetLength   = unsigned'($clog2(NumBlocks));
    localparam int unsigned ByteOffsetLength    = unsigned'($clog2(DataWidth / 32'd8));
    localparam int unsigned LineOffset          = ByteOffsetLength + BlockOffsetLength;
    // How many bytes are present in one cache line?
    localparam int unsigned BytesPerLine        = 1 << LineOffset;

    // Maximum beat size is 64-bit, 8B.
    // In Bytes (1), the largest burst size can be is (2^8-1 + 1) * 8.
    // In Cachelines (0), number of cachelines affected = Max_Burst_Size / Cacheline_Size + 1 (for unaligned transfer)
    //                                                  = (2^8 * 8) / (8 * 8) + 1
    //                                                  = 2^5 + 1.
    // localparam int unsigned MinSizeWidth = (SizeInBytes) ? 11 : 6;
    
    // localparam int unsigned LATENCY_BITS = (MinLatencyBits < MinSizeWidth+1) ? 
    //                                         MinSizeWidth+1 : MinLatencyBits;
    
    // localparam int unsigned SIZE_BITS   = (MinSizeWidth+1 < MinLatencyBits) ? 
    //                                         MinLatencyBits-1 : MinSizeWidth;
    // Note: This parameter must come from PMU package.
    localparam int unsigned FIFO_WIDTH          = pmu_pkg::EVENT_INFO_BITS + SOURCE_ID_BITS;                                            

    typedef struct packed {
        source_id_t                 source_id;
        logic                       unaligned_transfer;
        logic [SIZE_BITS-1:0]       size_of_burst;
        addr_idx_t                  addr_idx;
    } req_info_t;
    
    typedef struct packed {
        source_id_t                 source_id;
        logic [LATENCY_BITS-1:0]    resp_latency;
        addr_idx_t                  addr_idx;
    } resp_info_t;

    // Source ID bits
    source_id_t ar_source_id;
    source_id_t aw_source_id;
    source_id_t r_source_id;
    source_id_t w_source_id;

    // Address Mapping Indices
    addr_idx_t ar_addr_idx;
    addr_idx_t aw_addr_idx;    
    addr_idx_t r_addr_idx;
    addr_idx_t w_addr_idx;
        
    // Valid signal for `spu_ax_chan` and `spu_cam` modules.
    logic ar_info_valid;
    logic r_info_valid;

    // Answers one of the following two questions:
    //      0. How many cachelines are affected by this transfer?
    //      1. How many bytes are in this AXI burst? 
    logic [SIZE_BITS-1:0] ar_size_of_burst;  
    logic [SIZE_BITS-1:0] aw_size_of_burst;  

    // Is the transfer aligned or unaligned?
    logic ar_unaligned_transfer;
    logic aw_unaligned_transfer;

    // What is the read response latency?
    logic [LATENCY_BITS-1:0]    r_latency;
    logic [LATENCY_BITS-1:0]    w_latency;

    // EventInfo associated with read requests, sent to / recevied from FIFO.
    req_info_t  ar_fifo_info_i;
    req_info_t  ar_fifo_info_o;

    // EventInfo associated with read responses, sent to / recevied from FIFO.
    resp_info_t r_fifo_info_i;
    resp_info_t r_fifo_info_o;

    // EventInfo associated with write requests, sent to / recevied from FIFO.
    req_info_t  aw_fifo_info_i;
    req_info_t  aw_fifo_info_o;

    // EventInfo associated with write responses, sent to / recevied from FIFO.
    resp_info_t w_fifo_info_i;
    resp_info_t w_fifo_info_o;

    // *************************************************************************
    // FIFO Signals
    // *************************************************************************
    logic ar_fifo_flush;
    logic ar_fifo_testmode;
    logic ar_fifo_full;
    logic ar_fifo_empty;
    logic ar_fifo_push;
    logic ar_fifo_pop;

    logic r_fifo_flush;
    logic r_fifo_testmode;
    logic r_fifo_full;
    logic r_fifo_empty;
    logic r_fifo_push;
    logic r_fifo_pop;

    logic aw_fifo_flush;
    logic aw_fifo_testmode;
    logic aw_fifo_full;
    logic aw_fifo_empty;
    logic aw_fifo_push;
    logic aw_fifo_pop;

    logic w_fifo_flush;
    logic w_fifo_testmode;
    logic w_fifo_full;
    logic w_fifo_empty;
    logic w_fifo_push;
    logic w_fifo_pop;

    // *************************************************************************
    // Arbiter Signals
    // *************************************************************************
    logic [3:0] requests;
    logic [3:0] grant;

    // Unused FIFO signals.
    assign ar_fifo_flush    = 1'b0;
    assign ar_fifo_testmode = 1'b0;
    assign r_fifo_flush     = 1'b0;
    assign r_fifo_testmode  = 1'b0;
    assign aw_fifo_flush    = 1'b0;
    assign aw_fifo_testmode = 1'b0;
    assign w_fifo_flush     = 1'b0;
    assign w_fifo_testmode  = 1'b0;
        
    // External-Master <==> [[ SlvPort ]  SPU  [ MstPort ]] <==> External-Slave 
    // OP of E-Mst => IP of I-Slv => OP of I-Mst => IP of E-Slv
    // IP of E-Mst <= OP of I-Slv <= IP of I-Mst <= OP of E-Slv
    // AW Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.aw_id     = spu_slv.aw_id;
    assign spu_mst.aw_addr   = spu_slv.aw_addr;
    assign spu_mst.aw_len    = spu_slv.aw_len;
    assign spu_mst.aw_size   = spu_slv.aw_size;
    assign spu_mst.aw_burst  = spu_slv.aw_burst;
    assign spu_mst.aw_lock   = spu_slv.aw_lock;
    assign spu_mst.aw_cache  = spu_slv.aw_cache;
    assign spu_mst.aw_prot   = spu_slv.aw_prot;
    assign spu_mst.aw_qos    = spu_slv.aw_qos;
    assign spu_mst.aw_region = spu_slv.aw_region;
    assign spu_mst.aw_atop   = spu_slv.aw_atop;
    assign spu_mst.aw_user   = spu_slv.aw_user;
    assign spu_mst.aw_valid  = spu_slv.aw_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.aw_ready  = spu_mst.aw_ready;

    // W Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.w_data  = spu_slv.w_data;
    assign spu_mst.w_strb  = spu_slv.w_strb;
    assign spu_mst.w_last  = spu_slv.w_last;
    assign spu_mst.w_user  = spu_slv.w_user;
    assign spu_mst.w_valid = spu_slv.w_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.w_ready = spu_mst.w_ready;

    // B Channel
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.b_id    = spu_mst.b_id;
    assign spu_slv.b_resp  = spu_mst.b_resp;
    assign spu_slv.b_user  = spu_mst.b_user;
    assign spu_slv.b_valid = spu_mst.b_valid;
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.b_ready = spu_slv.b_ready;

    // AR Channel
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.ar_id     = spu_slv.ar_id;
    assign spu_mst.ar_addr   = spu_slv.ar_addr;
    assign spu_mst.ar_len    = spu_slv.ar_len;
    assign spu_mst.ar_size   = spu_slv.ar_size;
    assign spu_mst.ar_burst  = spu_slv.ar_burst;
    assign spu_mst.ar_lock   = spu_slv.ar_lock;
    assign spu_mst.ar_cache  = spu_slv.ar_cache;
    assign spu_mst.ar_prot   = spu_slv.ar_prot;
    assign spu_mst.ar_qos    = spu_slv.ar_qos;
    assign spu_mst.ar_region = spu_slv.ar_region;
    assign spu_mst.ar_user   = spu_slv.ar_user;
    assign spu_mst.ar_valid  = spu_slv.ar_valid;
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.ar_ready  = spu_mst.ar_ready;

    // R CHannel
    // IP of E-Mst <= OP of E-Slv
    assign spu_slv.r_id    = spu_mst.r_id;
    assign spu_slv.r_data  = spu_mst.r_data;
    assign spu_slv.r_resp  = spu_mst.r_resp;
    assign spu_slv.r_last  = spu_mst.r_last;
    assign spu_slv.r_user  = spu_mst.r_user;
    assign spu_slv.r_valid = spu_mst.r_valid;
    // IP of E-Slv <= OP of E-Mst
    assign spu_mst.r_ready = spu_slv.r_ready;

    // Register the input request / response before processing.
    // Write Address channel
    // If a new request (valid) arrives, de-assert `new_x_req_d` and only re-assert
    // when a corresponding ready arrives. This prevents the same request from being 
    // counted multiple times.
    always_comb begin
        new_aw_req_d = new_aw_req_q;
        if (spu_slv.aw_valid) begin
            new_aw_req_d = 1'b0;
        end
        if (spu_mst.aw_ready) begin
            new_aw_req_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            new_aw_req_q <= 1'b1;
        end else begin
            new_aw_req_q <= new_aw_req_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            aw_chan.id    <= 0;
            aw_chan.addr  <= 0;
            aw_chan.len   <= 0;
            aw_chan.size  <= 0; 
            aw_chan.burst <= 0;
            aw_chan.valid <= 0;
        end else begin
            aw_chan.id    <= spu_slv.aw_id;
            aw_chan.addr  <= spu_slv.aw_addr;
            aw_chan.len   <= spu_slv.aw_len;
            aw_chan.size  <= spu_slv.aw_size;
            aw_chan.burst <= spu_slv.aw_burst;
            aw_chan.valid <= spu_slv.aw_valid && new_aw_req_q;
        end
    end

    // Write Response channel
    always_comb begin
        new_b_resp_d = new_b_resp_q;
        if (spu_mst.b_valid) begin
            new_b_resp_d = 1'b0;
        end
        if (spu_slv.b_ready) begin
            new_b_resp_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            new_b_resp_q <= 1'b1;
        end else begin
            new_b_resp_q <= new_b_resp_q;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            b_chan.id    <= 0;
            b_chan.resp  <= 0;
            b_chan.valid <= 0;
        end else begin
            b_chan.id    <= spu_mst.b_id;
            b_chan.resp  <= spu_mst.b_resp;
            b_chan.valid <= spu_mst.b_valid && new_b_resp_q;
        end
    end

    // Read Address channel
    always_comb begin
        new_ar_req_d = new_ar_req_q;
        if (spu_slv.ar_valid) begin
            new_ar_req_d = 1'b0;
        end
        if (spu_mst.ar_ready) begin
            new_ar_req_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            new_ar_req_q <= 1'b1;
        end else begin
            new_ar_req_q <= new_ar_req_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ar_chan.id    <= 0;
            ar_chan.addr  <= 0;
            ar_chan.len   <= 0;
            ar_chan.size  <= 0; 
            ar_chan.burst <= 0;
            ar_chan.valid <= 0;
        end else begin
            ar_chan.id    <= spu_slv.ar_id;
            ar_chan.addr  <= spu_slv.ar_addr;
            ar_chan.len   <= spu_slv.ar_len;
            ar_chan.size  <= spu_slv.ar_size;
            ar_chan.valid <= spu_slv.ar_valid && new_ar_req_q;
        end
    end

    // Read Data channel
    always_comb begin
        new_r_resp_d = new_r_resp_q;
        if (spu_mst.r_valid) begin
            new_r_resp_d = 1'b0;
        end
        if (spu_slv.r_ready) begin
            new_r_resp_d = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            new_r_resp_q <= 1'b1;
        end else begin
            new_r_resp_q <= new_r_resp_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            r_chan.id    <= 0;
            r_chan.data  <= 0;
            r_chan.last  <= 0;
            r_chan.resp  <= 0;
            r_chan.valid <= 0;
        end else begin
            r_chan.id    <= spu_mst.r_id;
            r_chan.data  <= spu_mst.r_data;
            r_chan.last  <= spu_mst.r_last;
            r_chan.resp  <= spu_mst.r_resp;
            r_chan.valid <= spu_mst.r_valid && new_r_resp_q;
        end
    end

    // *************************************************************************
    // AR Channel-related Modules
    // *************************************************************************
    spu_ax_chan #(
        // Static configuration parameters of the cache.
        .SetAssociativity       ( SetAssociativity      ),
        .NumLines               ( NumLines              ),
        .NumBlocks              ( NumBlocks             ),
        // AXI4 Specifications
        .IdWidth                ( IdWidth               ),
        .AddrWidth              ( AddrWidth             ),
        .DataWidth              ( DataWidth             ),
        // Source ID Specifications.
        .SourceIDStart          ( SourceIDStart         ),
        .SourceIDEnd            ( SourceIDEnd           ),
        // `spu_ax_chan` parameters.
        .ax_chan_t              ( ax_chan_t             ),
        // SPU Event Specifications.
        .SizeInBytes            ( SizeInBytes           ),
        .SIZE_BITS              ( SIZE_BITS             ),
        // Address Indexing
        .addr_rule_t            ( addr_rule_t           ),
        .N_ADDR_RULES           ( N_ADDR_RULES          )
    ) i_spu_ar_chan (
        .ax_chan_i              ( ar_chan               ),
        .addr_map_i             ( addr_map_i            ),
        .valid_o                ( ar_info_valid         ),
        .source_id_o            ( ar_source_id          ),
        .unaligned_transfer_o   ( ar_unaligned_transfer ),
        .size_of_burst_o        ( ar_size_of_burst      ),
        .addr_idx_o             ( ar_addr_idx           )
    );

    assign ar_fifo_info_i.unaligned_transfer = ar_unaligned_transfer;
    assign ar_fifo_info_i.size_of_burst      = ar_size_of_burst;
    assign ar_fifo_info_i.source_id          = ar_source_id;
    assign ar_fifo_info_i.addr_idx           = ar_addr_idx;

    always_comb begin
        ar_fifo_push    = 1'b0;
        if (ar_info_valid && !ar_fifo_full) begin
            ar_fifo_push = 1'b1;
        end
    end

    always_comb begin
        ar_fifo_pop    = 1'b0;
        if (grant[R_REQ]) begin
            ar_fifo_pop = 1'b1;
        end
    end

    fifo_v3 # (
        .DATA_WIDTH     ( FIFO_WIDTH        ),
        .DEPTH          ( FIFO_DEPTH        )
    ) i_ar_fifo (
        .clk_i          ( clk_i             ),
        .rst_ni         ( rst_ni            ),
        .flush_i        ( ar_fifo_flush     ),
        .testmode_i     ( ar_fifo_testmode  ),
        .full_o         ( ar_fifo_full      ),
        .usage_o        ( /* Not used */    ), 
        .empty_o        ( ar_fifo_empty     ),
        .data_i         ( ar_fifo_info_i    ),
        .push_i         ( ar_fifo_push      ),
        .data_o         ( ar_fifo_info_o    ),
        .pop_i          ( ar_fifo_pop       )
    );

    // *************************************************************************
    // R Channel-related Modules
    // *************************************************************************
    spu_r_chan #(
        // CAM Depth.
        .DEPTH          ( CAM_DEPTH                 ),
        // AXI4 Specifications.
        .IdWidth        ( IdWidth                   ),
        .AddrWidth      ( AddrWidth                 ),
        .DataWidth      ( DataWidth                 ),
        // `spu_ax_chan` parameters
        .ar_chan_t      ( ax_chan_t                 ),
        .r_chan_t       ( r_chan_t                  ),
        .latency_t      ( logic [LATENCY_BITS-1:0]  ),
        // Source ID Specifications.
        .SourceIDStart  ( SourceIDStart             ),
        .SourceIDEnd    ( SourceIDEnd               ),
        // Address Indexing
        .addr_rule_t    ( addr_rule_t               ),
        .N_ADDR_RULES   ( N_ADDR_RULES              )
    ) i_spu_r_chan (
        .clk_i          ( clk_i                     ),
        .rst_ni         ( rst_ni                    ),
        .ar_chan_i      ( ar_chan                   ),
        .r_chan_i       ( r_chan                    ),
        .addr_map_i     ( addr_map_i                ),
        .valid_o        ( r_info_valid              ),
        .source_id_o    ( r_source_id               ),
        .addr_idx_o     ( r_addr_idx                ),
        .latency_o      ( r_latency                 )
    );

    assign r_fifo_info_i.resp_latency = r_latency;
    assign r_fifo_info_i.source_id    = r_source_id;
    assign r_fifo_info_i.addr_idx     = r_addr_idx;

    always_comb begin
        r_fifo_push    = 1'b0;
        if (r_info_valid && !r_fifo_full) begin
            r_fifo_push = 1'b1;
        end
    end

    always_comb begin
        r_fifo_pop    = 1'b0;
        if (grant[R_RESP]) begin
            r_fifo_pop = 1'b1;
        end
    end

    fifo_v3 # (
        .DATA_WIDTH     ( FIFO_WIDTH        ),
        .DEPTH          ( FIFO_DEPTH        )
    ) i_r_fifo (
        .clk_i          ( clk_i             ),
        .rst_ni         ( rst_ni            ),
        .flush_i        ( r_fifo_flush      ),
        .testmode_i     ( r_fifo_testmode   ),
        .full_o         ( r_fifo_full       ),
        .usage_o        ( /* Not used */    ), 
        .empty_o        ( r_fifo_empty      ),
        .data_i         ( r_fifo_info_i     ),
        .push_i         ( r_fifo_push       ),
        .data_o         ( r_fifo_info_o     ),
        .pop_i          ( r_fifo_pop        )
    );

    // *************************************************************************
    // AW Channel-related Modules
    // *************************************************************************
    spu_ax_chan #(
        // Static configuration parameters of the cache.
        .SetAssociativity       ( SetAssociativity      ),
        .NumLines               ( NumLines              ),
        .NumBlocks              ( NumBlocks             ),
        // AXI4 Specifications
        .IdWidth                ( IdWidth               ),
        .AddrWidth              ( AddrWidth             ),
        .DataWidth              ( DataWidth             ),
        // Source ID Specifications.
        .SourceIDStart          ( SourceIDStart         ),
        .SourceIDEnd            ( SourceIDEnd           ),
        // `spu_ax_chan` parameters.
        .ax_chan_t              ( ax_chan_t             ),
        // SPU Event Specifications.
        .SizeInBytes            ( SizeInBytes           ),
        .SIZE_BITS              ( SIZE_BITS             ),
        // Address Indexing
        .addr_rule_t            ( addr_rule_t           ),
        .N_ADDR_RULES           ( N_ADDR_RULES          )
    ) i_spu_aw_chan (
        .ax_chan_i              ( aw_chan               ),
        .addr_map_i             ( addr_map_i            ),
        .valid_o                ( aw_info_valid         ),
        .source_id_o            ( aw_source_id          ),
        .unaligned_transfer_o   ( aw_unaligned_transfer ),
        .size_of_burst_o        ( aw_size_of_burst      ),
        .addr_idx_o             ( aw_addr_idx           )
    );

    assign aw_fifo_info_i.unaligned_transfer = aw_unaligned_transfer;
    assign aw_fifo_info_i.size_of_burst      = aw_size_of_burst; 
    assign aw_fifo_info_i.source_id          = aw_source_id;
    assign aw_fifo_info_i.addr_idx           = aw_addr_idx;

    always_comb begin
        aw_fifo_push    = 1'b0;
        if (aw_info_valid && !aw_fifo_full) begin
            aw_fifo_push = 1'b1;
        end
    end

    always_comb begin
        aw_fifo_pop    = 1'b0;
        if (grant[W_REQ]) begin
            aw_fifo_pop = 1'b1;
        end
    end

    fifo_v3 # (
        .DATA_WIDTH     ( FIFO_WIDTH        ),
        .DEPTH          ( FIFO_DEPTH        )
    ) i_aw_fifo (
        .clk_i          ( clk_i             ),
        .rst_ni         ( rst_ni            ),
        .flush_i        ( aw_fifo_flush     ),
        .testmode_i     ( aw_fifo_testmode  ),
        .full_o         ( aw_fifo_full      ),
        .usage_o        ( /* Not used */    ), 
        .empty_o        ( aw_fifo_empty     ),
        .data_i         ( aw_fifo_info_i    ),
        .push_i         ( aw_fifo_push      ),
        .data_o         ( aw_fifo_info_o    ),
        .pop_i          ( aw_fifo_pop       )
    );

    // *************************************************************************
    // B (W) Channel-related Modules
    // *************************************************************************
    spu_w_chan #(
        // CAM Depth.
        .DEPTH          ( CAM_DEPTH                 ),
        // AXI4 Specifications.
        .IdWidth        ( IdWidth                   ),
        .AddrWidth      ( AddrWidth                 ),
        .DataWidth      ( DataWidth                 ),
        // `spu_ax_chan` parameters
        .aw_chan_t      ( ax_chan_t                 ),
        .b_chan_t       ( b_chan_t                  ),
        .latency_t      ( logic [LATENCY_BITS-1:0]  ),
        // Source ID Specifications.
        .SourceIDStart  ( SourceIDStart             ),
        .SourceIDEnd    ( SourceIDEnd               ),
        // Address Indexing
        .addr_rule_t    ( addr_rule_t               ),
        .N_ADDR_RULES   ( N_ADDR_RULES              )
    ) i_spu_w_chan (
        .clk_i          ( clk_i                     ),
        .rst_ni         ( rst_ni                    ),
        .aw_chan_i      ( aw_chan                   ),
        .b_chan_i       ( b_chan                    ),
        .addr_map_i     ( addr_map_i                ),
        .valid_o        ( w_info_valid              ),
        .source_id_o    ( w_source_id               ),
        .addr_idx_o     ( w_addr_idx                ),
        .latency_o      ( w_latency                 )
    );

    assign w_fifo_info_i.resp_latency = w_latency;
    assign w_fifo_info_i.source_id    = w_source_id;
    assign w_fifo_info_i.addr_idx     = w_addr_idx;

    always_comb begin
        w_fifo_push    = 1'b0;
        if (w_info_valid && !w_fifo_full) begin
            w_fifo_push = 1'b1;
        end
    end

    always_comb begin
        w_fifo_pop    = 1'b0;
        if (grant[W_RESP]) begin
            w_fifo_pop = 1'b1;
        end
    end

    fifo_v3 # (
        .DATA_WIDTH     ( FIFO_WIDTH        ),
        .DEPTH          ( FIFO_DEPTH        )
    ) i_w_fifo (
        .clk_i          ( clk_i             ),
        .rst_ni         ( rst_ni            ),
        .flush_i        ( w_fifo_flush      ),
        .testmode_i     ( w_fifo_testmode   ),
        .full_o         ( w_fifo_full       ),
        .usage_o        ( /* Not used */    ), 
        .empty_o        ( w_fifo_empty      ),
        .data_i         ( w_fifo_info_i     ),
        .push_i         ( w_fifo_push       ),
        .data_o         ( w_fifo_info_o     ),
        .pop_i          ( w_fifo_pop        )
    );

    // *************************************************************************
    // EventOut Arbiter
    // *************************************************************************
    // Lower-significant bits are higher priority.
    assign requests[R_REQ]  = !ar_fifo_empty;
    assign requests[W_REQ]  = !aw_fifo_empty;
    assign requests[R_RESP] = !r_fifo_empty;
    assign requests[W_RESP] = !w_fifo_empty;

    spu_arbiter i_spu_arbiter (
        .clk_i      ( clk_i     ),
        .rst_ni     ( rst_ni    ),
        .requests_i ( requests  ),
        .grant_o    ( grant     )
    );

    always_comb begin
        e_out.e_id = 0;
        e_out.s_id = 0;
        e_out.e_info = 0;

        if (grant[R_REQ] && (ar_fifo_info_o.addr_idx==1)) begin
            e_out.e_id   = R_REQ + 1;
            e_out.s_id   = {SOURCE_ID_BITS'(ar_fifo_info_o.source_id)};
            e_out.e_info = {{(pmu_pkg::EVENT_INFO_BITS - (SIZE_BITS+1+ADDR_IDX_BITS)){1'b0}},
                             ADDR_IDX_BITS'(ar_fifo_info_o.addr_idx),
                             1'(ar_fifo_info_o.unaligned_transfer), 
                             SIZE_BITS'(ar_fifo_info_o.size_of_burst) };
        end else if (grant[W_REQ] && (aw_fifo_info_o.addr_idx!=0)) begin
            e_out.e_id   = W_REQ + 1;
            e_out.s_id   = {SOURCE_ID_BITS'(aw_fifo_info_o.source_id)};
            e_out.e_info = {{(pmu_pkg::EVENT_INFO_BITS - (SIZE_BITS+1+ADDR_IDX_BITS)){1'b0}},
                             ADDR_IDX_BITS'(aw_fifo_info_o.addr_idx),
                             1'(aw_fifo_info_o.unaligned_transfer), 
                             SIZE_BITS'(aw_fifo_info_o.size_of_burst) };
        end else if (grant[R_RESP] && (r_fifo_info_o.addr_idx==1)) begin
            e_out.e_id   = R_RESP + 1;
            e_out.s_id   = {SOURCE_ID_BITS'(r_fifo_info_o.source_id)};
            e_out.e_info = {{(pmu_pkg::EVENT_INFO_BITS - (LATENCY_BITS+ADDR_IDX_BITS)){1'b0}},
                             ADDR_IDX_BITS'(r_fifo_info_o.addr_idx),
                             LATENCY_BITS'(r_fifo_info_o.resp_latency) };
        end else if (grant[W_RESP] && (w_fifo_info_o.addr_idx==1)) begin
            e_out.e_id   = W_RESP + 1;
            e_out.s_id   = {SOURCE_ID_BITS'(w_fifo_info_o.source_id)};
            e_out.e_info = {{(pmu_pkg::EVENT_INFO_BITS - (LATENCY_BITS+ADDR_IDX_BITS)){1'b0}},
                             ADDR_IDX_BITS'(w_fifo_info_o.addr_idx),
                             LATENCY_BITS'(w_fifo_info_o.resp_latency) };
        end
    end

    // *************************************************************************
    // EventOut Logger - Controlled by parameter `LogData`.
    // *************************************************************************
    // pragma translate_off
  `ifndef TARGET_SYNTHESIS
    `ifndef VERILATOR
    initial begin: proc_assert
        if (pmu_pkg::EVENT_INFO_BITS < SIZE_BITS + 1 + ADDR_IDX_BITS) begin
            $display("Request event packets need more bits for event info.");
            $error("Some event info bits will be truncated.");
        end if (pmu_pkg::EVENT_INFO_BITS != LATENCY_BITS + ADDR_IDX_BITS) begin
            $display("Response event packets need more bits for event info.");
            $error("Some event info bits will be truncated.");
        end
    end

    initial begin: proc_spu_hello
        $display("#################################################################################");
        $display("AXI Snooping Unit (%s) initialized with the following configuration:", SPU_NAME);
        $display("Number of events: %0d",                    4);
        $display("Size of source info bits: %0d",            SOURCE_ID_BITS);
        $display("SourceIDEnd: %0d",                         SourceIDEnd);
        $display("SourceIDStart: %0d",                       SourceIDStart);
        $display("Size of event info bits: %0d",             pmu_pkg::EVENT_INFO_BITS);
        $display("Size of resp_info.addr index: %0d",        ADDR_IDX_BITS);
        $display("Size of req_info.unaligned_transfer: %0d", 1);
        $display("Size of req_info.size of burst: %0d",      SIZE_BITS);
        $display("Size of resp_info.response latency: %0d",  LATENCY_BITS);
        $display("#################################################################################");
    end
    
// SPU Logger.
if (LogData) begin
    initial begin
        automatic string       log_name;
        automatic int          fd;

        // make the log dirs
        log_name = $sformatf("mkdir -p ./pmu_log/%s", SPU_NAME);
        $system(log_name);

        // open log files
        log_name = $sformatf("./pmu_log/%s/read_req.log", SPU_NAME);
        fd = $fopen(log_name, "w");
        if (!fd) begin            
            $display("File was NOT opened successfully : %0d", fd);
            $display("time,read_req,source_id,addr_idx,unaligned_transfer,size_of_burst");
        end

        log_name = $sformatf("./pmu_log/%s/read_resp.log", SPU_NAME);
        fd = $fopen(log_name, "w");
        if (!fd) begin            
            $display("File was NOT opened successfully : %0d", fd);
            $display("time,read_req,source_id,addr_idx,unaligned_transfer,size_of_burst");
        end

        log_name = $sformatf("./pmu_log/%s/write_req.log", SPU_NAME);
        fd = $fopen(log_name, "w");
        if (!fd) begin            
            $display("File was NOT opened successfully : %0d", fd);
            $display("time,read_req,source_id,addr_idx,resp_latency");
        end

        log_name = $sformatf("./pmu_log/%s/write_resp.log", SPU_NAME);
        fd = $fopen(log_name, "w");
        if (!fd) begin            
            $display("File was NOT opened successfully : %0d", fd);
            $display("time,read_req,source_id,addr_idx,resp_latency");
        end
    end

    always @ (posedge clk_i) begin
        automatic string       log_name;
        automatic int          fd;

        if (rst_ni) begin
            if (grant[R_REQ]) begin
                log_name = $sformatf("./pmu_log/%s/read_req.log", SPU_NAME);
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d",
                                $time,
                                R_REQ+1,
                                ar_fifo_info_o.source_id,
                                ar_fifo_info_o.addr_idx,
                                ar_fifo_info_o.unaligned_transfer,
                                ar_fifo_info_o.size_of_burst
                         );
                $fclose(fd);
            end

            if (grant[R_RESP]) begin
                log_name = $sformatf("./pmu_log/%s/read_resp.log", SPU_NAME);
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d",
                                $time,                
                                R_RESP+1,
                                r_fifo_info_o.source_id,
                                r_fifo_info_o.addr_idx,
                                r_fifo_info_o.resp_latency
                         );
                $fclose(fd);
            end

            if (grant[W_REQ]) begin
                log_name = $sformatf("./pmu_log/%s/write_req.log", SPU_NAME);
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d",
                                $time,
                                W_REQ+1,
                                aw_fifo_info_o.source_id,
                                aw_fifo_info_o.addr_idx,
                                aw_fifo_info_o.unaligned_transfer,
                                aw_fifo_info_o.size_of_burst
                         );
                $fclose(fd);
            end

            if (grant[W_RESP]) begin
                log_name = $sformatf("./pmu_log/%s/write_resp.log", SPU_NAME);
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d",
                                $time,
                                W_RESP+1,
                                w_fifo_info_o.source_id,
                                w_fifo_info_o.addr_idx,
                                w_fifo_info_o.resp_latency
                         );
                $fclose(fd);
            end
        end
    end
end    
    `endif
   `endif
    // pragma translate_on

endmodule
