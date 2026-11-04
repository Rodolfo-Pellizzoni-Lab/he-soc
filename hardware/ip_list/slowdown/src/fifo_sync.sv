// -----------------------------------------------------------------------------
// fifo_sync — synchronous address queue for the throughput regulator.
//
// First-word fall-through (FWFT): the head of the queue is visible on data_out
// (and its AR/AW tag on AR_AW_tag_o) *combinationally*, without a pop. Asserting
// rd_en advances the read pointer on the following clock. This lets the release
// FSM peek the head and pop it in the very cycle its handshake completes, so a
// held VALID never has its payload move underneath it.
// -----------------------------------------------------------------------------

module fifo_sync
    #( parameter int FIFO_DEPTH = 8
    )
    (
        input  logic                                 clk_i,
        input  logic                                 rst_ni,
        input  logic                                 cs,           // chip select
        input  logic                                 wr_en,
        input  logic                                 rd_en,
        input  ariane_axi_soc::address_queue_entry_t data_in,
        output ariane_axi_soc::address_queue_entry_t data_out,
        output logic                                 empty,
        output logic                                 full,         // when full, writes are ignored
        output logic                                 AR_AW_tag_o,
        // Only to be used for debugging:
        output ariane_axi_soc::address_queue_entry_t fifo [0:FIFO_DEPTH-1],
        output reg [$clog2(FIFO_DEPTH):0]            write_pointer,
        output reg [$clog2(FIFO_DEPTH):0]            read_pointer
    );

    localparam int FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH);

    // ------------------------------------------------------------------
    // Write
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            write_pointer <= '0;
        else if (cs && wr_en && !full) begin
            fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
            write_pointer <= write_pointer + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Read pointer (FWFT: data_out is the combinational head below)
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            read_pointer <= '0;
        else if (cs && rd_en && !empty)
            read_pointer <= read_pointer + 1'b1;
    end

    assign data_out    = fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
    assign AR_AW_tag_o = fifo[read_pointer[FIFO_DEPTH_LOG-1:0]].AR_AW_tag;

    // ------------------------------------------------------------------
    // Status
    // ------------------------------------------------------------------
    assign empty = (read_pointer == write_pointer);
    assign full  = (read_pointer == {~write_pointer[FIFO_DEPTH_LOG], write_pointer[FIFO_DEPTH_LOG-1:0]});

endmodule
