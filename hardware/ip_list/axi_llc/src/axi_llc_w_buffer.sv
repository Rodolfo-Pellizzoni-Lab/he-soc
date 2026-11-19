// Write-data buffer of the LLC: lets write descriptors reach the write unit in any order.
//
// AXI W beats carry no ID, so they arrive in the order of the writes' AW handshakes, and the LLC's write unit used to
// pop them in that order: every write had to reach the write unit in AW order, the LLC kept all writes in order, and
// the CBQRI bandwidth controller's pool had to too, so one throttled (parked) write held every later write of every
// RCID (hardware/docs/qos.md, "Memory bandwidth controller": the write-ordering stall). With this buffer a write's
// beats are captured as they arrive into a slot of its own, and the write unit reads its descriptor's slot: writes
// then need only the LLC's per-ID order, like reads.
//
// It sits on the AW descriptor stream between the burst cutter and the lookup. Each descriptor whose beats fit a slot
// (a_x_len < MaxBeats: one line at full width, e.g. CVA6 write-backs and DMA words) gets a free slot (`wbuf` = 1,
// `w_slot`); one with more beats (a narrow or FIXED burst) gets none (`wbuf` = 0): its beats go to the write unit
// straight from the W channel when it is at the head of the W order, and the LLC keeps it in order with every other
// write as before (the bandwidth controller's dependence rule, the miss counters' write counter). A descriptor waits
// when no slot is free (NumSlots should cover the writes that can be outstanding at once: the AW channel stalls
// otherwise, for everyone).
//   Fill order: a FIFO of {wbuf, slot, beats} in AW order tells where the next W beats go.
//   Read port: the write unit names its descriptor's `wbuf` and `w_slot`; the buffer answers with the next beat of
//   that slot once it has been captured (or, unbuffered, the W channel's beat once that descriptor is at the head),
//   and frees the slot with its last beat.
module axi_llc_w_buffer #(
  parameter int unsigned NumSlots  = 32'd8,
  parameter int unsigned MaxBeats  = 32'd8,      // beats one slot holds (one line at the full data width)
  parameter int unsigned FillDepth = 32'd16,     // descriptors whose beats may be outstanding at once
  parameter type         desc_t    = logic,      // the LLC descriptor: a_x_len, wbuf, w_slot
  parameter type         w_chan_t  = logic
) (
  input  logic    clk_i,
  input  logic    rst_ni,
  input  logic    test_i,
  // AW descriptors, in AW order
  input  desc_t   desc_i,
  input  logic    desc_valid_i,
  output logic    desc_ready_o,
  output desc_t   desc_o,
  output logic    desc_valid_o,
  input  logic    desc_ready_i,
  // the slave port's W channel
  input  w_chan_t w_i,
  input  logic    w_valid_i,
  output logic    w_ready_o,
  // the write unit
  input  logic                                              rd_wbuf_i,
  input  logic [((NumSlots > 1) ? $clog2(NumSlots) : 1)-1:0] rd_slot_i,
  output w_chan_t                                           rd_w_o,
  output logic                                              rd_valid_o,
  input  logic                                              rd_ready_i
);
  `include "common_cells/registers.svh"

  localparam int unsigned SlotW = (NumSlots > 1) ? $clog2(NumSlots) : 1;
  localparam int unsigned BeatW = (MaxBeats > 1) ? $clog2(MaxBeats) : 1;
  typedef logic [SlotW-1:0] slot_t;
  typedef logic [BeatW:0]   cnt_t;                 // 0 .. MaxBeats

  typedef struct packed {
    logic          wbuf;
    slot_t         slot;
    axi_pkg::len_t len;                            // beats - 1
  } fill_t;

  // ---------------------------------------------------------------------------------------------- slots
  logic  [NumSlots-1:0] busy_q;
  cnt_t  [NumSlots-1:0] cap_q, rd_q;               // beats captured / read
  logic  [NumSlots-1:0][BeatW-1:0] last_q;         // beats - 1
  w_chan_t mem_q [NumSlots * MaxBeats];

  slot_t free_idx;
  logic  free_any;
  always_comb begin
    free_any = !(&busy_q);
    free_idx = '0;
    for (int i = NumSlots - 1; i >= 0; i--) if (!busy_q[i]) free_idx = slot_t'(i);
  end

  // ---------------------------------------------------------------------------------------------- descriptors
  fill_t fill_in, fill_head;
  logic  fill_full, fill_empty, fill_pop;
  desc_t out_q;
  logic  out_valid_q;

  wire fits   = 32'(desc_i.a_x_len) < MaxBeats;
  wire can    = !fill_full && (!fits || free_any) && (!out_valid_q || desc_ready_i);
  wire accept = desc_valid_i && can;
  assign desc_ready_o = can;
  assign desc_o       = out_q;
  assign desc_valid_o = out_valid_q;
  assign fill_in      = '{wbuf: fits, slot: fits ? free_idx : slot_t'(0), len: desc_i.a_x_len};

  fifo_v3 #(
    .FALL_THROUGH ( 1'b0      ),
    .DEPTH        ( FillDepth ),
    .dtype        ( fill_t    )
  ) i_fill_order (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0       ),
    .testmode_i ( test_i     ),
    .full_o     ( fill_full  ),
    .empty_o    ( fill_empty ),
    .usage_o    ( /* unused */ ),
    .data_i     ( fill_in    ),
    .push_i     ( accept     ),
    .data_o     ( fill_head  ),
    .pop_i      ( fill_pop   )
  );

  // ---------------------------------------------------------------------------------------------- W beats
  axi_pkg::len_t fcnt_q;                           // beats of the head descriptor taken so far
  wire head_buf   = !fill_empty &&  fill_head.wbuf;
  wire head_unbuf = !fill_empty && !fill_head.wbuf;
  // buffered head: capture; unbuffered head: to the write unit when it works on an unbuffered descriptor
  wire unbuf_rd   = head_unbuf && !rd_wbuf_i;
  assign w_ready_o = head_buf || (unbuf_rd && rd_ready_i);
  wire take       = w_valid_i && w_ready_o;
  assign fill_pop = take && (fcnt_q == fill_head.len);

  // ---------------------------------------------------------------------------------------------- read port
  cnt_t rd_cnt;
  assign rd_cnt = rd_q[rd_slot_i];
  assign rd_valid_o = rd_wbuf_i ? (cap_q[rd_slot_i] > rd_cnt) : (unbuf_rd && w_valid_i);
  assign rd_w_o     = rd_wbuf_i ? mem_q[32'(rd_slot_i) * MaxBeats + 32'(rd_cnt[BeatW-1:0])] : w_i;
  wire rd_take      = rd_wbuf_i && rd_valid_o && rd_ready_i;

  // ---------------------------------------------------------------------------------------------- state
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q      <= '0;
      cap_q       <= '0;
      rd_q        <= '0;
      last_q      <= '0;
      out_q       <= '0;
      out_valid_q <= 1'b0;
      fcnt_q      <= '0;
    end else begin
      // output register
      if (out_valid_q && desc_ready_i) out_valid_q <= 1'b0;
      if (accept) begin
        out_q        <= desc_i;
        out_q.wbuf   <= fits;
        out_q.w_slot <= fill_in.slot;
        out_valid_q  <= 1'b1;
      end
      // the write unit reads a beat; its last frees the slot
      if (rd_take) begin
        if (rd_cnt[BeatW-1:0] == last_q[rd_slot_i]) busy_q[rd_slot_i] <= 1'b0;
        else                                         rd_q[rd_slot_i]   <= rd_cnt + cnt_t'(1);
      end
      // capture a beat of the buffered head
      if (take && head_buf) cap_q[fill_head.slot] <= cap_q[fill_head.slot] + cnt_t'(1);
      if (take) fcnt_q <= fill_pop ? axi_pkg::len_t'(0) : fcnt_q + axi_pkg::len_t'(1);
      // a new descriptor takes a free slot (never the head's or the read one's: those are busy)
      if (accept && fits) begin
        busy_q[free_idx] <= 1'b1;
        cap_q[free_idx]  <= '0;
        rd_q[free_idx]   <= '0;
        last_q[free_idx] <= desc_i.a_x_len[BeatW-1:0];
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (take && head_buf) mem_q[32'(fill_head.slot) * MaxBeats + 32'(fcnt_q[BeatW-1:0])] <= w_i;
  end

  // pragma translate_off
  `ifndef VERILATOR
  initial assert (MaxBeats >= 1 && NumSlots >= 1) else $fatal(1, "axi_llc_w_buffer: NumSlots and MaxBeats >= 1");
  // a beat is never read from a slot before it was captured, nor from a free slot
  rd_from_busy : assert property (@(posedge clk_i) disable iff (!rst_ni) rd_take |-> busy_q[rd_slot_i])
    else $fatal(1, "axi_llc_w_buffer: the write unit read slot %0d, which is free", rd_slot_i);
  `endif
  // pragma translate_on
endmodule
