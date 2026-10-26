`include "ace/assign.svh"
`include "ace/typedef.svh"

// Coherency control unit state machine: one shareable transaction at a time through the snoop round, with
// (DecoupledReads) the memory read of a transaction handed to the memory side so the next transaction can start
// while the LLC answers; the responses of those reads return to their initiators by AXI id through the R channel
// and are tracked in a small in-flight table that blocks a new transaction to a line still in flight.
// hardware/docs/ccu_model.md has the measurements and the model behind this.
module ccu_fsm
#(
    parameter int unsigned DcacheLineWidth = 0,
    parameter int unsigned AxiDataWidth = 0,
    parameter int unsigned NoMstPorts = 4,
    parameter int unsigned SlvAxiIDWidth = 0,
    parameter type mst_req_t    = logic,
    parameter type mst_resp_t   = logic,
    parameter type snoop_req_t  = logic,
    parameter type snoop_resp_t = logic,
    // a read that needs memory leaves the state machine as soon as its AR is accepted (its R comes back by id);
    // 0 restores the original behaviour (the state machine waits in READ_MEM for the last beat)
    parameter bit          DecoupledReads = 1'b1,
    // reads in flight at once (one per CCU port is enough for the blocking CVA6 miss handler; the DMA port may
    // have more); when the table is full the read waits in READ_MEM as before
    parameter int unsigned NumInflight = 8
) (
    //clock and reset
    input                               clk_i,
    input                               rst_ni,
    // CCU Request In and response out
    input  mst_req_t                    ccu_req_i,
    output mst_resp_t                   ccu_resp_o,
    //CCU Request Out and response in
    output mst_req_t                    ccu_req_o,
    input  mst_resp_t                   ccu_resp_i,
    // Snoop channel resuest and response
    output snoop_req_t  [NoMstPorts-1:0] s2m_req_o,
    input  snoop_resp_t [NoMstPorts-1:0] m2s_resp_i
);

    localparam int unsigned DcacheLineWords = DcacheLineWidth / AxiDataWidth;
    localparam int unsigned MstIdxBits      = $clog2(NoMstPorts);
    localparam int unsigned LineOffsetBits  = $clog2(DcacheLineWidth / 8);

    enum logic [5:0] {
      IDLE,                      // 0
      DECODE_R,                  // 1
      SEND_INVALID_R,            // 2
      WAIT_INVALID_R,            // 3
      SEND_AXI_REQ_WRITE_BACK_R, // 4
      WRITE_BACK_MEM_R,          // 5
      SEND_READ,                 // 6
      WAIT_RESP_R,               // 7
      READ_SNP_DATA,             // 8
      SEND_AXI_REQ_R,            // 9
      READ_MEM,                  // 10
      DECODE_W,                  // 11
      SEND_INVALID_W,            // 12
      WAIT_INVALID_W,            // 13
      SEND_AXI_REQ_WRITE_BACK_W, // 14
      WRITE_BACK_MEM_W,          // 15
      SEND_AXI_REQ_W,            // 16
      WRITE_MEM                  // 17
    } state_d, state_q;


    // snoop resoponse valid
    logic [NoMstPorts-1:0]          cr_valid;
    // snoop channel ac valid
    logic [NoMstPorts-1:0]          ac_valid;
    // snoop channel ac ready
    logic [NoMstPorts-1:0]          ac_ready;
    // snoop channel cd last
    logic [NoMstPorts-1:0]          cd_last;
    // check for availablilty of data
    logic [NoMstPorts-1:0]          data_available;
    // check for response error
    logic [NoMstPorts-1:0]          response_error;
    // check for data received
    logic [NoMstPorts-1:0]          data_received;
    // check for shared in cr_resp
    logic [NoMstPorts-1:0]          shared;
    // check for dirty in cr_resp
    logic [NoMstPorts-1:0]          dirty;
    // request holder
    mst_req_t                       ccu_req_holder;
    // response holder
    mst_resp_t                      ccu_resp_holder;
    // snoop response holder
    snoop_resp_t [NoMstPorts-1:0]   m2s_resp_holder;
    // initiating master port
    logic [NoMstPorts-1:0]          initiator_d, initiator_q;
    logic [MstIdxBits-1:0]          first_responder;

    logic [DcacheLineWords-1:0][AxiDataWidth-1:0] cd_data;
    logic [$clog2(DcacheLineWords+1)-1:0]         stored_cd_data;

    logic r_last;
    logic w_last;
    logic r_eot;
    logic w_eot;

    typedef struct packed {
      logic waiting_w;
      logic waiting_r;
    } prio_t;

    prio_t prio_d, prio_q;

    // ----------------------
    // Reads in flight (DecoupledReads): line address and id of every memory read handed over and not yet
    // answered with its last beat. A new request to one of those lines waits in IDLE until the read returns.
    // ----------------------
    localparam int unsigned AddrW = $bits(ccu_req_holder.ar.addr);
    localparam int unsigned IdW   = $bits(ccu_req_holder.ar.id);
    localparam int unsigned LineW = AddrW - LineOffsetBits;

    logic [NumInflight-1:0]              inflight_valid_q;
    logic [NumInflight-1:0][LineW-1:0]   inflight_lo_q, inflight_hi_q;   // first and last line of the burst
    logic [NumInflight-1:0][IdW-1:0]     inflight_id_q;
    logic                                inflight_free;
    logic [$clog2(NumInflight)-1:0]      inflight_free_idx;
    logic                                conflict_ar, conflict_aw;
    logic                                ar_take, aw_take;       // a request that may leave IDLE now
    logic                                hand_over;              // this cycle's AR to memory is decoupled
    logic                                own_r;                  // the state machine drives its own R beats
    logic                                mem_r_pop;              // last beat of a decoupled read passes through
    logic [IdW-1:0]                      read_mem_id_q;          // id of the read READ_MEM waits for
    logic [LineW-1:0]                    ar_lo, ar_hi, aw_lo, aw_hi, hold_lo, hold_hi;

    // the lines a burst touches: INCR from its address, WRAP its aligned window, FIXED one line
    function automatic void burst_lines(input logic [AddrW-1:0] addr, input axi_pkg::len_t len,
                                        input axi_pkg::size_t size, input axi_pkg::burst_t burst,
                                        output logic [LineW-1:0] lo, output logic [LineW-1:0] hi);
        logic [AddrW-1:0] bytes, first, last;
        bytes = (AddrW'(len) + AddrW'(1)) << size;
        if (burst == axi_pkg::BURST_WRAP) first = addr & ~(bytes - AddrW'(1));
        else                              first = addr;
        if (burst == axi_pkg::BURST_FIXED) last = addr;
        else                               last = first + bytes - AddrW'(1);
        lo = first[AddrW-1:LineOffsetBits];
        hi = last[AddrW-1:LineOffsetBits];
    endfunction

    always_comb begin
        inflight_free     = 1'b0;
        inflight_free_idx = '0;
        for (int i = NumInflight-1; i >= 0; i--) begin
            if (!inflight_valid_q[i]) begin
                inflight_free     = 1'b1;
                inflight_free_idx = i[$clog2(NumInflight)-1:0];
            end
        end
        burst_lines(ccu_req_i.ar.addr, ccu_req_i.ar.len, ccu_req_i.ar.size, ccu_req_i.ar.burst, ar_lo, ar_hi);
        burst_lines(ccu_req_i.aw.addr, ccu_req_i.aw.len, ccu_req_i.aw.size, ccu_req_i.aw.burst, aw_lo, aw_hi);
        burst_lines(ccu_req_holder.ar.addr, ccu_req_holder.ar.len, ccu_req_holder.ar.size, ccu_req_holder.ar.burst,
                    hold_lo, hold_hi);
        conflict_ar = 1'b0;
        conflict_aw = 1'b0;
        for (int i = 0; i < NumInflight; i++) begin
            if (inflight_valid_q[i] && ar_lo <= inflight_hi_q[i] && ar_hi >= inflight_lo_q[i]) conflict_ar = 1'b1;
            if (inflight_valid_q[i] && aw_lo <= inflight_hi_q[i] && aw_hi >= inflight_lo_q[i]) conflict_aw = 1'b1;
            // AXI returns same-id read data in order: a read with the id of one in flight waits, so that an
            // answer from a snooped L1 cannot overtake memory data still on its way (the DMA port's reads)
            if (inflight_valid_q[i] && inflight_id_q[i] == ccu_req_i.ar.id) conflict_ar = 1'b1;
        end
        ar_take = ccu_req_i.ar_valid & !conflict_ar;
        aw_take = ccu_req_i.aw_valid & !conflict_aw;
    end

    // a decoupled memory read leaves now
    assign hand_over = DecoupledReads && (state_q == SEND_AXI_REQ_R) && ccu_resp_i.ar_ready &&
                       !ccu_req_holder.ar.lock && inflight_free;
    // the state machine answers from the snoop data or with the CleanUnique response: memory R beats wait
    assign own_r     = (state_q == WAIT_INVALID_R) || (state_q == READ_SNP_DATA);
    assign mem_r_pop = ccu_resp_i.r_valid && ccu_req_o.r_ready && ccu_resp_i.r.last;

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            inflight_valid_q <= '0;
            inflight_lo_q    <= '0;
            inflight_hi_q    <= '0;
            inflight_id_q    <= '0;
            read_mem_id_q    <= '0;
        end else begin
            // the last beat of a read in flight retires its entry (the oldest with that id: AXI keeps same-id order)
            if (mem_r_pop) begin
                for (int i = 0; i < NumInflight; i++) begin
                    if (inflight_valid_q[i] && inflight_id_q[i] == ccu_resp_i.r.id) begin
                        inflight_valid_q[i] <= 1'b0;
                        break;
                    end
                end
            end
            if (hand_over) begin
                inflight_valid_q[inflight_free_idx] <= 1'b1;
                inflight_lo_q[inflight_free_idx]    <= hold_lo;
                inflight_hi_q[inflight_free_idx]    <= hold_hi;
                inflight_id_q[inflight_free_idx]    <= ccu_req_holder.ar.id;
            end
            if (state_q == SEND_AXI_REQ_R) read_mem_id_q <= ccu_req_holder.ar.id;
            else if (state_q == WRITE_MEM) read_mem_id_q <= ccu_req_holder.aw.id;
        end
    end

    // ----------------------
    // Current State Block
    // ----------------------
    always_ff @(posedge clk_i, negedge rst_ni) begin : ccu_present_state
        if(!rst_ni) begin
            state_q <= IDLE;
            initiator_q <= '0;
            prio_q <= '0;
        end else begin
            state_q <= state_d;
            initiator_q <= initiator_d;
            prio_q <= prio_d;
        end
    end

    // ----------------------
    // Next State Block
    // ----------------------
    always_comb begin : ccu_state_ctrl

        state_d = state_q;
        initiator_d = initiator_q;
        prio_d = prio_q;

        case(state_q)

        IDLE: begin
            initiator_d = '0;
            prio_d = '0;
            //  wait for incoming valid request from master (one to a line with a read in flight waits)
            if((ar_take & !aw_take) |
               (ar_take & prio_q.waiting_r) |
               (ar_take & !prio_q.waiting_w)) begin
                state_d = DECODE_R;
                initiator_d[ccu_req_i.ar.id[SlvAxiIDWidth+:MstIdxBits]] = 1'b1;
                prio_d.waiting_w = aw_take;
            end else if((aw_take & !ar_take) |
                        (aw_take & prio_q.waiting_w)) begin
                state_d = DECODE_W;
                initiator_d[ccu_req_i.aw.id[SlvAxiIDWidth+:MstIdxBits]] = 1'b1;
                prio_d.waiting_r = ar_take;
            end else begin
                state_d = IDLE;
            end
        end

        //---------------------
        //---- Read Branch ----
        //---------------------
        DECODE_R: begin
            //check read transaction type
            if (ccu_req_holder.ar.snoop == snoop_pkg::CLEAN_UNIQUE) begin   // check if CleanUnique then send Invalidate
                state_d = SEND_INVALID_R;
            end else if (ccu_req_holder.ar.lock) begin   // AMO LR, invalidate
                state_d = SEND_INVALID_R;
            end else begin
                state_d = SEND_READ;
            end
        end

        SEND_INVALID_R: begin
            // wait for all snoop masters to assert AC ready
            if (ac_ready != '1) begin
                state_d = SEND_INVALID_R;
            end else begin
                state_d = WAIT_INVALID_R;
            end
        end

        WAIT_INVALID_R: begin
            // wait for all snoop masters to assert CR valid
            if ((cr_valid == '1) && (ccu_req_i.r_ready || ccu_req_holder.ar.lock)) begin
                if(|(data_available & ~response_error)) begin
                    state_d = SEND_AXI_REQ_WRITE_BACK_R;
                end else begin
                    if (ccu_req_holder.ar.lock) begin   // AMO LR, read memory
                        state_d = SEND_AXI_REQ_R;
                    end else begin
                        state_d = IDLE;
                    end
                end
            end else begin
                state_d = WAIT_INVALID_R;
            end
        end

        SEND_AXI_REQ_WRITE_BACK_R: begin
            // wait for responding slave to assert aw_ready
            if(ccu_resp_i.aw_ready !='b1) begin
                state_d = SEND_AXI_REQ_WRITE_BACK_R;
            end else begin
                state_d = WRITE_BACK_MEM_R;
            end
        end

        WRITE_BACK_MEM_R: begin
            // wait for responding slave to send b_valid
            if((ccu_resp_i.b_valid && ccu_req_o.b_ready)) begin
                if (ccu_req_holder.ar.lock) begin   // AMO LR, read memory
                    state_d = SEND_AXI_REQ_R;
                end else begin
                    state_d = IDLE;
                end
            end else begin
                state_d = WRITE_BACK_MEM_R;
            end
        end

        SEND_READ: begin
            // wait for all snoop masters to de-assert AC ready
            if (ac_ready != '1) begin
                state_d = SEND_READ;
            end else begin
                state_d = WAIT_RESP_R;
            end
        end

        WAIT_RESP_R: begin
            // wait for all snoop masters to assert CR valid
            if (cr_valid != '1) begin
                state_d = WAIT_RESP_R;
            end else if(|(data_available & ~response_error)) begin
                state_d = READ_SNP_DATA;
            end else begin
                state_d = SEND_AXI_REQ_R;
            end
        end

        READ_SNP_DATA: begin
          if(cd_last == data_available && (r_eot == 1'b1 || (ccu_req_i.r_ready == 1'b1 && r_last == 1'b1))) begin
            state_d = IDLE;
          end else begin
            state_d = READ_SNP_DATA;
          end
        end

        SEND_AXI_REQ_R: begin
            // wait for responding slave to assert ar_ready; a decoupled read then leaves the state machine
            if(ccu_resp_i.ar_ready !='b1) begin
                state_d = SEND_AXI_REQ_R;
            end else if (hand_over) begin
                state_d = IDLE;
            end else begin
                state_d = READ_MEM;
            end
        end

        READ_MEM: begin
            // wait for responding slave to send the last beat of this read (other reads' beats pass meanwhile)
            if(ccu_resp_i.r_valid && ccu_req_i.r_ready && ccu_resp_i.r.id == read_mem_id_q) begin
                if(ccu_resp_i.r.last) begin
                    state_d = IDLE;
                end else begin
                    state_d = READ_MEM;
                end
            end else begin
                state_d = READ_MEM;
            end
        end


        //---------------------
        //---- Write Branch ---
        //---------------------

        DECODE_W: begin
            state_d = SEND_INVALID_W;
        end

        SEND_INVALID_W: begin
            // wait for all snoop masters to assert AC ready
            if (ac_ready != '1) begin
                state_d = SEND_INVALID_W;
            end else begin
                state_d = WAIT_INVALID_W;
            end
        end

        WAIT_INVALID_W: begin
            // wait for all snoop masters to assert CR valid
            if (cr_valid != '1) begin
                state_d = WAIT_INVALID_W;
            end else if(|(data_available & ~response_error)) begin
                state_d = SEND_AXI_REQ_WRITE_BACK_W;
            end else begin
                state_d = SEND_AXI_REQ_W;
            end
        end

        SEND_AXI_REQ_WRITE_BACK_W: begin
            // wait for responding slave to assert aw_ready
            if(ccu_resp_i.aw_ready !='b1) begin
                state_d = SEND_AXI_REQ_WRITE_BACK_W;
            end else begin
                state_d = WRITE_BACK_MEM_W;
            end
        end

        WRITE_BACK_MEM_W: begin
            // wait for responding slave to send b_valid
            if((ccu_resp_i.b_valid && ccu_req_o.b_ready)) begin
                state_d = SEND_AXI_REQ_W;
            end else begin
                state_d = WRITE_BACK_MEM_W;
            end
        end

        SEND_AXI_REQ_W: begin
            // wait for responding slave to assert aw_ready
            if(ccu_resp_i.aw_ready !='b1) begin
                state_d = SEND_AXI_REQ_W;
            end else begin
                state_d = WRITE_MEM;
            end
        end

        WRITE_MEM: begin
            // wait for responding slave to send b_valid. The read response of an atomic (aw.atop[5]) passes
            // through to the initiator by id whenever it comes, before or after B (with DecoupledReads the R
            // pass-through is on in every state but the two that send the state machine's own R beats), so
            // the state machine does not wait for it; without DecoupledReads it waits in READ_MEM as before.
            if((ccu_resp_i.b_valid && ccu_req_i.b_ready)) begin
                  if(ccu_req_holder.aw.atop [5] && !DecoupledReads) begin
                    state_d = READ_MEM;
                  end else begin
                    state_d = IDLE;
                  end
            end else begin
                state_d = WRITE_MEM;
            end
        end

        default: state_d = IDLE;


    endcase
    end

    // ----------------------
    // Output Block
    // ----------------------
    always_comb begin : ccu_output_block
        logic ar_addr_offset;

        ar_addr_offset = ccu_req_holder.ar.addr[3];

        // Default Assignments
        ccu_req_o  = '0;
        ccu_resp_o = '0;
        s2m_req_o  = '0;

        // memory R beats go to their initiator (by id, through the mux) whenever the state machine is not
        // sending R beats of its own: the reads in flight, and the read READ_MEM waits for
        if (!own_r) begin
            ccu_req_o.r_ready   =   ccu_req_i.r_ready;
            ccu_resp_o.r        =   ccu_resp_i.r;
            ccu_resp_o.r_valid  =   ccu_resp_i.r_valid;
        end

        case(state_q)
        IDLE: begin

        end

        //---------------------
        //---- Read Branch ----
        //---------------------
        DECODE_R:begin
            ccu_resp_o.ar_ready =   'b1;
        end
        SEND_READ: begin
            // send request to snooping masters
            for (int unsigned n = 0; n < NoMstPorts; n = n + 1) begin
                s2m_req_o[n].ac.addr   =   ccu_req_holder.ar.addr;
                s2m_req_o[n].ac.prot   =   ccu_req_holder.ar.prot;
                s2m_req_o[n].ac.snoop  =   ccu_req_holder.ar.snoop;
                s2m_req_o[n].ac_valid  =   !ac_ready[n];
            end
        end

        SEND_INVALID_R:begin
            for (int unsigned n = 0; n < NoMstPorts; n = n + 1) begin
                s2m_req_o[n].ac.addr   =   ccu_req_holder.ar.addr;
                s2m_req_o[n].ac.prot   =   ccu_req_holder.ar.prot;
                s2m_req_o[n].ac.snoop  =   snoop_pkg::CLEAN_INVALID;
                s2m_req_o[n].ac_valid  =   !ac_ready[n];
            end
        end

        WAIT_RESP_R, WAIT_INVALID_W: begin
            for (int unsigned n = 0; n < NoMstPorts; n = n + 1)
              s2m_req_o[n].cr_ready  =   !cr_valid[n]; //'b1;
        end

        WAIT_INVALID_R: begin
            for (int unsigned n = 0; n < NoMstPorts; n = n + 1)
                s2m_req_o[n].cr_ready  =   !cr_valid[n]; //'b1;

            if ((cr_valid == '1) && (!ccu_req_holder.ar.lock)) begin
                ccu_resp_o.r        =   '0;
                ccu_resp_o.r.id     =   ccu_req_holder.ar.id;
                ccu_resp_o.r.last   =   'b1;
                ccu_resp_o.r_valid  =   'b1;
            end
        end

        READ_SNP_DATA: begin
          for (int unsigned n = 0; n < NoMstPorts; n = n + 1)
            s2m_req_o[n].cd_ready  = !cd_last[n] & data_available[n];
          // response to intiating master
          if (!r_eot) begin
            if (ccu_req_holder.ar.len == 0) begin
                // single data request
                logic critical_word_valid;
                critical_word_valid = (stored_cd_data == ar_addr_offset + 1);
                ccu_resp_o.r.data   = cd_data[ar_addr_offset];
                ccu_resp_o.r.last   = critical_word_valid;
                ccu_resp_o.r_valid  = critical_word_valid;
            end else begin
                // cache line request
                ccu_resp_o.r.data  = cd_data[r_last];
                ccu_resp_o.r.last  = r_last;
                ccu_resp_o.r_valid = |stored_cd_data;
            end
            ccu_resp_o.r.id      = ccu_req_holder.ar.id;
            ccu_resp_o.r.resp[3] = |shared;                // update if shared
            ccu_resp_o.r.resp[2] = |dirty;                 // update if any line dirty
          end
        end

        SEND_AXI_REQ_WRITE_BACK_R: begin
            // send writeback request
            ccu_req_o.aw_valid     = 'b1;
            ccu_req_o.aw           = '0; //default
            ccu_req_o.aw.addr      = ccu_req_holder.ar.addr;
            ccu_req_o.aw.addr[3:0] = 4'b0; // writeback is always full cache line
            ccu_req_o.aw.size      = 2'b11;
            ccu_req_o.aw.burst     = axi_pkg::BURST_INCR; // Use BURST_INCR for AXI regular transaction
            ccu_req_o.aw.id        = {first_responder, ccu_req_holder.ar.id[SlvAxiIDWidth-1:0]}; // It should be visible this data originates from the responder, important e.g. for AMO operations
            ccu_req_o.aw.user      = ccu_req_holder.ar.user; // QoS tag of the request that caused the write-back
            ccu_req_o.aw.len       = DcacheLineWords-1;
            // WRITEBACK
            ccu_req_o.aw.domain    = 2'b00;
            ccu_req_o.aw.snoop     = 3'b011;
        end

        WRITE_BACK_MEM_R: begin
          for (int unsigned n = 0; n < NoMstPorts; n = n + 1)
            s2m_req_o[n].cd_ready  = !cd_last[n] & data_available[n];
            // write data to slave (RAM)
            ccu_req_o.w_valid =  |stored_cd_data;
            ccu_req_o.w.strb  =  '1;
            ccu_req_o.w.data  =   cd_data[w_last];
            ccu_req_o.w.last  =   w_last;
            ccu_req_o.b_ready = 'b1;
        end

        SEND_AXI_REQ_R: begin
            // forward request to slave (RAM)
            ccu_req_o.ar_valid  =   'b1;
            ccu_req_o.ar        =   ccu_req_holder.ar;
        end

        READ_MEM: begin
            // the R beats pass through (above)
        end

        //---------------------
        //---- Write Branch ---
        //---------------------
        DECODE_W: begin
            ccu_resp_o.aw_ready =   'b1;
        end

        SEND_INVALID_W:begin
            for (int unsigned n = 0; n < NoMstPorts; n = n + 1) begin
                s2m_req_o[n].ac.addr  = ccu_req_holder.aw.addr;
                s2m_req_o[n].ac.prot  = ccu_req_holder.aw.prot;
                s2m_req_o[n].ac.snoop = snoop_pkg::CLEAN_INVALID;
                s2m_req_o[n].ac_valid = !ac_ready[n];
            end
        end

        SEND_AXI_REQ_WRITE_BACK_W: begin
            // send writeback request
            ccu_req_o.aw_valid     = 'b1;
            ccu_req_o.aw           = '0; //default
            ccu_req_o.aw.addr      = ccu_req_holder.aw.addr;
            ccu_req_o.aw.addr[3:0] = 4'b0; // writeback is always full cache line
            ccu_req_o.aw.size      = 2'b11;
            ccu_req_o.aw.burst     = axi_pkg::BURST_INCR; // Use BURST_INCR for AXI regular transaction
            ccu_req_o.aw.id        = {first_responder, ccu_req_holder.aw.id[SlvAxiIDWidth-1:0]}; // It should be visible this data originates from the responder, important e.g. for AMO operations
            ccu_req_o.aw.user      = ccu_req_holder.aw.user; // QoS tag of the request that caused the write-back
            ccu_req_o.aw.len       = DcacheLineWords-1;
            // WRITEBACK
            ccu_req_o.aw.domain    = 2'b00;
            ccu_req_o.aw.snoop     = 3'b011;
        end

        WRITE_BACK_MEM_W: begin
          for (int unsigned n = 0; n < NoMstPorts; n = n + 1)
            s2m_req_o[n].cd_ready  = !cd_last[n] & data_available[n];
          // response to intiating master
          if (!r_eot) begin
            ccu_req_o.w_valid =  |stored_cd_data;
            ccu_req_o.w.strb  =  '1;
            ccu_req_o.w.data  =   cd_data[w_last];
            ccu_req_o.w.last  =   w_last;
            ccu_req_o.b_ready = 'b1;
          end
        end

        SEND_AXI_REQ_W: begin
            // forward request to slave (RAM)
            ccu_req_o.aw_valid  =    'b1;
            ccu_req_o.aw        =    ccu_req_holder.aw;
        end

        WRITE_MEM: begin
            ccu_req_o.w         =  ccu_req_i.w;
            ccu_req_o.w_valid   =  ccu_req_i.w_valid;
            ccu_req_o.b_ready   =  ccu_req_i.b_ready;

            ccu_resp_o.b        =  ccu_resp_i.b;
            ccu_resp_o.b_valid  =  ccu_resp_i.b_valid;
            ccu_resp_o.w_ready  =  ccu_resp_i.w_ready;
        end

        endcase
    end // end output block

    // Hold incoming ACE request
    always_ff @(posedge clk_i , negedge rst_ni) begin
        if(!rst_ni) begin
            ccu_req_holder <= '0;
        end else if(state_q == IDLE &&
                    ((ar_take & !aw_take) |
                     (ar_take & prio_q.waiting_r) |
                     (ar_take & !prio_q.waiting_w))) begin
            ccu_req_holder.ar       <=  ccu_req_i.ar;
            ccu_req_holder.ar_valid <=  ccu_req_i.ar_valid;
            ccu_req_holder.r_ready  <=  ccu_req_i.r_ready;

        end  else if(state_q == IDLE &&
                    ((aw_take & !ar_take) |
                     (aw_take & prio_q.waiting_w))) begin
            ccu_req_holder.aw       <=  ccu_req_i.aw;
            ccu_req_holder.aw_valid <=  ccu_req_i.aw_valid;
        end
    end

    // Hold snoop AC_ready
    always_ff @ (posedge clk_i, negedge rst_ni) begin
      if(!rst_ni) begin
        ac_ready         <= '0;
        ac_valid         <= '0;
      end else if(state_q == DECODE_R || state_q == DECODE_W) begin
        ac_ready <= initiator_q;
      end else if(state_q == SEND_READ || state_q == SEND_INVALID_R || state_q == SEND_INVALID_W) begin
        for (int i = 0; i < NoMstPorts; i = i + 1) begin
          ac_ready[i] <= ac_ready[i] | (m2s_resp_i[i].ac_ready & s2m_req_o[i].ac_valid);
          ac_valid[i] <= ac_valid[i] | (m2s_resp_i[i].ac_ready & s2m_req_o[i].ac_valid);
        end
      end else begin
        ac_ready         <= '0;
        ac_valid         <= '0;
      end
    end

    // Hold snoop CR
    always_ff @ (posedge clk_i, negedge rst_ni) begin
      logic snoop_resp_found;
      if(!rst_ni) begin
        cr_valid         <= '0;
        data_available   <= '0;
        shared           <= '0;
        dirty            <= '0;
        response_error   <= '0;
        first_responder  <= '0;
        snoop_resp_found <= 1'b0;
      end else if(state_q == IDLE) begin
        cr_valid         <= '0;
        data_available   <= '0;
        shared           <= '0;
        dirty            <= '0;
        response_error   <= '0;
        first_responder  <= '0;
        snoop_resp_found <= 1'b0;
      end else if(state_q == SEND_READ || state_q == SEND_INVALID_R || state_q == SEND_INVALID_W) begin
        cr_valid <= initiator_q;
      end else begin
        for (int i = 0; i < NoMstPorts; i = i + 1) begin
          if(m2s_resp_i[i].cr_valid & s2m_req_o[i].cr_ready) begin
            cr_valid[i]         <=   cr_valid[i] | 1'b1;
            data_available[i]   <=   m2s_resp_i[i].cr_resp.dataTransfer;
            shared[i]           <=   m2s_resp_i[i].cr_resp.isShared;
            dirty[i]            <=   m2s_resp_i[i].cr_resp.passDirty;
            response_error[i]   <=   m2s_resp_i[i].cr_resp.error;
          end
        end
        if (!snoop_resp_found) begin
          for (int i = 0; i < NoMstPorts; i = i + 1) begin
            if(m2s_resp_i[i].cr_valid & s2m_req_o[i].cr_ready & m2s_resp_i[i].cr_resp.dataTransfer & !m2s_resp_i[i].cr_resp.error) begin
              first_responder <= i[MstIdxBits-1:0];
              snoop_resp_found <= 1'b1;
              break;
            end
          end
        end
      end
    end

    // Hold snoop CD
    always_ff @ (posedge clk_i, negedge rst_ni) begin
      if(!rst_ni) begin
        data_received    <= '0;
        cd_last          <= '0;
        m2s_resp_holder  <= '0;
        cd_data <= '0;
        stored_cd_data <= '0;
      end else begin
        if(state_q == IDLE) begin
          data_received    <= '0;
          m2s_resp_holder  <= '0;
          cd_last          <= '0;
          cd_data <= '0;
          stored_cd_data <= '0;
        end
        else begin
          for (int i = 0; i < NoMstPorts; i = i + 1) begin
            if (state_q == READ_SNP_DATA) begin
              if(m2s_resp_i[i].cd_valid) begin
                data_received[i]    <= m2s_resp_i[i].cd_valid;
                cd_last[i]          <= cd_last[i] | (m2s_resp_i[i].cd.last & data_available[i]);
                m2s_resp_holder[i]  <= m2s_resp_i[i];
              end
              if (data_received[i] & ccu_resp_o.r_valid) begin
                data_received[i] <= '0;
                m2s_resp_holder  <= '0;
              end
              if (m2s_resp_i[first_responder].cd_valid & s2m_req_o[first_responder].cd_ready) begin
                cd_data[m2s_resp_i[first_responder].cd.last] <= m2s_resp_i[first_responder].cd.data;
              end
              if (s2m_req_o[first_responder].cd_ready & m2s_resp_i[first_responder].cd_valid & !(ccu_resp_o.r_valid & ccu_req_i.r_ready)) begin
                stored_cd_data <= stored_cd_data + 1;
              end else if(ccu_resp_o.r_valid & ccu_req_i.r_ready & !(s2m_req_o[first_responder].cd_ready & m2s_resp_i[first_responder].cd_valid)) begin
                stored_cd_data <= stored_cd_data - 1;
              end
            end else if (state_q == WRITE_BACK_MEM_R || state_q == WRITE_BACK_MEM_W) begin
              if(m2s_resp_i[i].cd_valid) begin
                data_received[i]    <= m2s_resp_i[i].cd_valid;
                cd_last[i]          <= cd_last[i] | (m2s_resp_i[i].cd.last & data_available[i]);
                m2s_resp_holder[i]  <= m2s_resp_i[i];
              end
              if (data_received[i] & ccu_req_o.w_valid) begin
                data_received[i] <= '0;
                m2s_resp_holder  <= '0;
              end
              if (m2s_resp_i[first_responder].cd_valid & s2m_req_o[first_responder].cd_ready) begin
                cd_data[m2s_resp_i[first_responder].cd.last] <= m2s_resp_i[first_responder].cd.data;
              end
              if (s2m_req_o[first_responder].cd_ready & m2s_resp_i[first_responder].cd_valid & !(ccu_req_o.w_valid & ccu_resp_i.w_ready)) begin
                stored_cd_data <= stored_cd_data + 1;
              end else if(ccu_req_o.w_valid & ccu_resp_i.w_ready & !(s2m_req_o[first_responder].cd_ready & m2s_resp_i[first_responder].cd_valid)) begin
                stored_cd_data <= stored_cd_data - 1;
              end
            end
          end
        end
      end
    end

  // beats of the state machine's own R response (snoop data, CleanUnique done); memory beats passing through
  // belong to other transactions and do not count
  always_ff @ (posedge clk_i, negedge rst_ni) begin
    if(!rst_ni) begin
      r_last <= 1'b0;
      r_eot  <= 1'b0;
    end else begin
      if(state_q == IDLE) begin
        r_last <= 1'b0;
        r_eot  <= 1'b0;
      end else if (own_r & ccu_req_i.r_ready & ccu_resp_o.r_valid) begin
        r_last <= !r_last;
        if (ccu_resp_o.r.last)
          r_eot <= 1'b1;
      end
    end
  end

  always_ff @ (posedge clk_i, negedge rst_ni) begin
    if(!rst_ni) begin
      w_last <= 1'b0;
      w_eot  <= 1'b0;
    end else begin
      if(state_q == IDLE) begin
        w_last <= 1'b0;
        w_eot  <= 1'b0;
      end else if (ccu_resp_i.w_ready & ccu_req_o.w_valid) begin
        w_last <= !w_last;
        if (w_last)
          w_eot <= 1'b1;
      end
    end
  end

  `ifndef VERILATOR
  // pragma translate_off
  initial begin
    a_dcache_line_words : assert (DcacheLineWords == 2) else
        $error("The ccu_fsm module is currently hardcoded to only support DcacheLineWidth = 2 * AxiDataWidth");
  end
  // pragma translate_on
  `endif



endmodule
