// Copyright 2022 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//

module tlul2mem
  import tlul_ot_pkg::*;
  #( parameter int unsigned SramAw = 16,
     parameter int unsigned SramDw = 32,
     parameter type tl_h2d_t = tlul_ot_pkg::tl_h2d_t,
     parameter type tl_d2h_t = tlul_ot_pkg::tl_d2h_t
   )(
     input  logic                clk_i,
     input  logic                rst_ni,
     // TL-UL host
     input  tl_h2d_t             tl_i,
     output tl_d2h_t             tl_o,
     // simple memory
     output logic                req_o,
     input  logic                gnt_i,
     output logic                we_o,
     output logic [SramAw-1:0]   addr_o,
     output logic [SramDw-1:0]   wdata_o,
     output logic [SramDw/8-1:0] wmask_o,
     input  logic [SramDw-1:0]   rdata_i,
     input  logic                rvalid_i,
     input  logic [1:0]          rerror_i
   );

  typedef enum logic [1:0] {IDLE, WAIT_GNT, WAIT_WDONE, WAIT_RVALID} state_e;
  state_e state_q, state_d;

  logic [$bits(tl_i.a_source)-1:0] source_q;
  logic [$bits(tl_i.a_user  )-1:0] user_q;
  logic [2:0]                      size_q;
  logic                            is_read_q;

  // integrity wrapper
  tl_d2h_t tl_o_int;

  tlul_rsp_intg_gen #(
    .EnableRspIntgGen(1),
    .EnableDataIntgGen(1)
  ) i_intg (
    .tl_i(tl_o_int),
    .tl_o(tl_o)
  );

  always_comb begin
    // ------------------------------------------------------------------------
    // Defaults
    // ------------------------------------------------------------------------
    req_o               = 1'b0;
    we_o                = 1'b0;
    addr_o              = '0;
    wdata_o             = '0;
    wmask_o             = '0;

    tl_o_int            = '0;
    tl_o_int.d_size     = size_q;
    tl_o_int.d_user     = user_q;
    tl_o_int.d_source   = source_q;
    tl_o_int.d_param    = '0;
    tl_o_int.d_sink     = '0;
    tl_o_int.d_error    = 1'b0;

    state_d = state_q;

    // ------------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------------
    unique case (state_q)
      IDLE: begin
        if (tl_i.a_valid) begin
          // Drive request
          req_o  = 1'b1;
          addr_o = tl_i.a_address[SramAw-1:0];

          if (tl_i.a_opcode == Get) begin
            we_o = 1'b0;
          end else begin
            we_o    = 1'b1;
            wdata_o = tl_i.a_data;
            wmask_o = tl_i.a_mask;
          end

          if (gnt_i) begin                 // handshake succeeds
            tl_o_int.a_ready = 1'b1;
            // next-state depends on opcode
            state_d = (tl_i.a_opcode == Get) ? WAIT_RVALID : WAIT_WDONE;
          end else begin                   // wait for grant
            state_d = WAIT_GNT;
          end
        end
      end

      // ======================================================================
      WAIT_GNT: begin
        // Re-drive until gnt_i
        req_o  = 1'b1;   addr_o = tl_i.a_address[SramAw-1:0];
        if (tl_i.a_opcode == Get) begin
          we_o = 1'b0;
        end else begin
          we_o    = 1'b1;
          wdata_o = tl_i.a_data;
          wmask_o = tl_i.a_mask;
        end

        if (gnt_i) begin
          tl_o_int.a_ready = 1'b1;
          state_d = (tl_i.a_opcode == Get) ? WAIT_RVALID : WAIT_WDONE;
        end
      end

      // ======================================================================
      WAIT_WDONE: begin
        // One-cycle delay after write grant
        tl_o_int.d_valid  = 1'b1;
        tl_o_int.d_opcode = AccessAck;
        // d_error already 0
        state_d = IDLE;
      end

      // ======================================================================
      WAIT_RVALID: begin
        if (rvalid_i) begin
          tl_o_int.d_valid  = 1'b1;
          tl_o_int.d_opcode = AccessAckData;
          tl_o_int.d_data   = rdata_i;
          tl_o_int.d_error  = rerror_i[1];
          state_d = IDLE;
        end
      end

      // ----------------------------------------------------------------------
      default: state_d = IDLE;
    endcase
  end // always_comb

  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q  <= IDLE;
      source_q <= '0;  user_q <= '0;  size_q <= '0;  is_read_q <= 1'b0;
    end else begin
      state_q <= state_d;
      // Capture meta data when handshake completes
      if ( (state_q == IDLE || state_q == WAIT_GNT) && tl_i.a_valid && gnt_i ) begin
        source_q  <= tl_i.a_source;
        user_q    <= tl_i.a_user;
        size_q    <= tl_i.a_size;
        is_read_q <= (tl_i.a_opcode == Get);
      end
    end
  end

endmodule
