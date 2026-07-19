// -----------------------------------------------------------------------------
// data_write_fifo — synchronous W-beat queue for the throughput regulator.
//
// First-word fall-through (FWFT), same as fifo_sync: the head W beat is on
// write_data_out combinationally; rd_en advances to the next beat. The release
// FSM presents the head with a stable AXI handshake and pops exactly one beat
// per accepted dw_ready, draining an AW's burst (AWLEN+1 beats) in order.
// -----------------------------------------------------------------------------

module data_write_fifo #(
    parameter int FIFO_DEPTH = 8
) (
    input  logic                               clk_i,
    input  logic                               rst_ni,
    input  logic                               cs,
    input  logic                               wr_en,
    input  logic                               rd_en,
    input  ariane_axi_soc::w_data_fifo_entry_t write_data_in,
    output ariane_axi_soc::w_data_fifo_entry_t write_data_out,
    output logic                               empty,
    output logic                               full,
    // Only to be used for debugging:
    output ariane_axi_soc::w_data_fifo_entry_t fifo [0:FIFO_DEPTH-1],
    output reg [$clog2(FIFO_DEPTH):0]          write_pointer,
    output reg [$clog2(FIFO_DEPTH):0]          read_pointer
);

    localparam int FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH);

    // Write
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            write_pointer <= '0;
        else if (cs && wr_en && !full) begin
            fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= write_data_in;
            write_pointer <= write_pointer + 1'b1;
        end
    end

    // Read pointer (FWFT: write_data_out is the combinational head below)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            read_pointer <= '0;
        else if (cs && rd_en && !empty)
            read_pointer <= read_pointer + 1'b1;
    end

    assign write_data_out = fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];

    // Status
    assign empty = (read_pointer == write_pointer);
    assign full  = (read_pointer == {~write_pointer[FIFO_DEPTH_LOG], write_pointer[FIFO_DEPTH_LOG-1:0]});

endmodule
