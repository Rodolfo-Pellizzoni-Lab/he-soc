module throughput_regulator #(
    parameter int unsigned Throughput_timer_param = 16,
    parameter int unsigned Throughput_FIFO_depth = 8,
    parameter int unsigned Throughput_COUNTER_WIDTH = 4
) (
    input logic clk_i,
    input logic rst_ni,
    // AW channel signals:
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input logic                             aw_valid_i,
    input ariane_axi_soc::aw_chan_slv_mem_t aw_signals_i,
    output logic                            aw_ready_o, // backpressure to upstream
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                             aw_valid_o,
    output ariane_axi_soc::aw_chan_slv_mem_t aw_signals_o,
    input  logic                             aw_ready_i,    // from memory
    
    // AR channel signals
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input logic                              ar_valid_i,
    input ariane_axi_soc::ar_chan_slv_mem_t  ar_signals_i,
    output logic                             ar_ready_o, // backpressure to upstream
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                             ar_valid_o,
    output ariane_axi_soc::ar_chan_slv_mem_t ar_signals_o,
    input  logic                             ar_ready_i,    // from memory

    // W channel signals
    // -----------------------------
    // Upstream side (LLC/SPU => Regulator)
    // -----------------------------
    input logic                              dw_valid_i,
    input ariane_axi_soc::w_chan_t           dw_signals_i,
    output logic                             dw_ready_o,
    // -----------------------------
    // Downstream side (Regulator => Memory)
    // -----------------------------
    output logic                            dw_valid_o,
    output ariane_axi_soc::w_chan_t                         dw_signals_o,
    input logic                             dw_ready_i,                    


    // debugging port
    output reg ar_valid_o_reg,
    output reg aw_valid_o_reg,
    output reg dw_valid_o_reg
);

    initial begin
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
        $display("Throughput_timer_param     = %0d", Throughput_timer_param);
        $display("Throughput_FIFO_depth      = %0d", Throughput_FIFO_depth);
        $display("Throughput_COUNTER_WIDTH    = %0d", Throughput_COUNTER_WIDTH);
        $display("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$");
    end

    // -----------------------------

    // FIFO signals

    // -----------------------------

    // ariane_axi_soc::ar_fifo_entry_t ar_fifo_data_in, ar_fifo_data_out;
    logic fifo_empty, fifo_full;
    logic fifo_wr_en, fifo_rd_en;
    logic fifo_AR_AW_tag_wire;
 

    // ************************************************************
    // Prepare FIFO data input
    ariane_axi_soc::address_queue_entry_t address_queue_data_in, address_queue_data_out;
    always_comb begin
        if (ar_valid_i) begin
            address_queue_data_in.valid = ar_valid_i;
            address_queue_data_in.AR_AW_signals.id = ar_signals_i.id;
            address_queue_data_in.AR_AW_signals.addr = ar_signals_i.addr;
            address_queue_data_in.AR_AW_signals.len =  ar_signals_i.len;
            address_queue_data_in.AR_AW_signals.size =  ar_signals_i.size;
            address_queue_data_in.AR_AW_signals.burst =  ar_signals_i.burst;
            address_queue_data_in.AR_AW_signals.lock = ar_signals_i.lock;
            address_queue_data_in.AR_AW_signals.cache = ar_signals_i.cache;
            address_queue_data_in.AR_AW_signals.prot = ar_signals_i.prot;
            address_queue_data_in.AR_AW_signals.qos = ar_signals_i.qos;
            address_queue_data_in.AR_AW_signals.region = ar_signals_i.region;
            address_queue_data_in.AR_AW_signals.atop = '0;
            address_queue_data_in.AR_AW_signals.user = ar_signals_i.user;
            address_queue_data_in.AR_AW_tag = 1'b1;
        end
        else if (aw_valid_i) begin
            address_queue_data_in.valid = aw_valid_i;
            address_queue_data_in.AR_AW_signals.id = aw_signals_i.id;
            address_queue_data_in.AR_AW_signals.addr = aw_signals_i.addr;
            address_queue_data_in.AR_AW_signals.len =  aw_signals_i.len;
            address_queue_data_in.AR_AW_signals.size =  aw_signals_i.size;
            address_queue_data_in.AR_AW_signals.burst =  aw_signals_i.burst;
            address_queue_data_in.AR_AW_signals.lock = aw_signals_i.lock;
            address_queue_data_in.AR_AW_signals.cache = aw_signals_i.cache;
            address_queue_data_in.AR_AW_signals.prot = aw_signals_i.prot;
            address_queue_data_in.AR_AW_signals.qos = aw_signals_i.qos;
            address_queue_data_in.AR_AW_signals.region = aw_signals_i.region;
            address_queue_data_in.AR_AW_signals.atop = aw_signals_i.atop;
            address_queue_data_in.AR_AW_signals.user = aw_signals_i.user;
            address_queue_data_in.AR_AW_tag = 1'b0;
        end
        else begin
            address_queue_data_in.valid = '0;
            address_queue_data_in.AR_AW_signals.id = '0;
            address_queue_data_in.AR_AW_signals.addr = '0;
            address_queue_data_in.AR_AW_signals.len =  '0;
            address_queue_data_in.AR_AW_signals.size =  '0;
            address_queue_data_in.AR_AW_signals.burst =  '0;
            address_queue_data_in.AR_AW_signals.lock = '0;
            address_queue_data_in.AR_AW_signals.cache = '0;
            address_queue_data_in.AR_AW_signals.prot = '0;
            address_queue_data_in.AR_AW_signals.qos = '0;
            address_queue_data_in.AR_AW_signals.region = '0; 
            address_queue_data_in.AR_AW_signals.atop = '0;
            address_queue_data_in.AR_AW_signals.user = '0;
            address_queue_data_in.AR_AW_tag = 1'b0;
        end
    end
    ariane_axi_soc::w_data_fifo_entry_t  dw_data_in, dw_data_out;
    assign dw_data_in.w_valid = dw_valid_i;
    assign dw_data_in.w_signals = dw_signals_i;

    logic dw_fifo_wr_en, dw_fifo_empty, dw_fifo_full, dw_fifo_rd_en;
    assign dw_fifo_wr_en = dw_valid_i && !dw_fifo_full;
    // assign dw_fifo_rd_en = !address_queue_data_in.AR_AW_tag && !dw_fifo_empty;
    // assign dw_fifo_rd_en = aw_valid_o && !dw_fifo_empty;

    // Logic for DW FIFO RD Enable
    logic aw_valid_o_delayed;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(!rst_ni) begin
            aw_valid_o_delayed <= 1'b0;
        end
        else begin
            aw_valid_o_delayed <= aw_valid_o;
        end
    end
    assign dw_fifo_rd_en = (aw_valid_o || aw_valid_o_delayed) && !dw_fifo_empty;

    // ************************************************************
    // -----------------------------
    // FIFO instance
    // -----------------------------
    fifo_sync #(.FIFO_DEPTH(Throughput_FIFO_depth)) i_fifo_sync (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .cs(1'b1),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        // .data_in(ar_fifo_data_in),
        .data_in(address_queue_data_in),
        // .data_out(ar_fifo_data_out),
        .data_out(address_queue_data_out),
        .empty(fifo_empty),
        .full(fifo_full),
        .AR_AW_tag_o(fifo_AR_AW_tag_wire),
        // debugging port:
        .fifo(),
        .write_pointer(),
        .read_pointer()
    );

    logic counter_start, counter_zero_flag;
    logic [Throughput_COUNTER_WIDTH-1:0] counter_count_value;

    countdown_timer #(
    .COUNTER_WIDTH(Throughput_COUNTER_WIDTH),
    .Throughput_TIMER_PARAM(Throughput_timer_param)
) i_countdown_timer (
    .clk(clk_i),
    .rst_n(rst_ni),
    .start(counter_start),       // start countdown
    .zero_flag(counter_zero_flag),   // asserted when count == 0
    .count_value(counter_count_value)  // current counter value
);

    data_write_fifo #(
    .FIFO_DEPTH(Throughput_FIFO_depth)
) i_data_write_fifo (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .cs(1'b1),
    .wr_en(dw_fifo_wr_en),
    .rd_en(dw_fifo_rd_en),
    .write_data_in(dw_data_in),
    .write_data_out(dw_data_out),
    .empty(dw_fifo_empty),
    .full(dw_fifo_full),
    // Only to be used for debugging:
	.fifo(),// depth 8 => [0:7] 32 bit elements
	.write_pointer(),//3:0
  	.read_pointer()//3:0
);

    reg fifo_empty_d;
    reg fifo_empty_fall;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            fifo_empty_d <= 1'b0;
            fifo_empty_fall <= 1'b0;
        end
        else begin
            fifo_empty_fall <= fifo_empty_d && !fifo_empty;
            fifo_empty_d <= fifo_empty;
        end
    end 

    // assign fifo_wr_en = ar_valid_i && !fifo_full;
    // assign counter_start = fifo_empty_fall || (counter_zero_flag && !fifo_empty);
    assign fifo_rd_en = counter_zero_flag && !fifo_empty;
    assign ar_ready_o = !fifo_full;
    assign aw_ready_o = !fifo_full;
    assign dw_ready_o = !dw_fifo_full;

    assign ar_valid_o = ar_valid_o_reg;
    //assign ar_signals_o = ar_fifo_data_out.ar_signals;
    wire ar_handshake;
    assign ar_handshake = ar_valid_o_reg && ar_ready_i;

    logic address_queue_rd_enable_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
        address_queue_rd_enable_q <= 1'b0;
    else
        address_queue_rd_enable_q <= fifo_rd_en;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ar_valid_o_reg <= 1'b0;
        end
        else begin
            if (ar_handshake) begin
                ar_valid_o_reg <= 1'b0;
            end
            // if (!ar_valid_o_reg && fifo_rd_en && address_queue_data_out.AR_AW_tag) begin
            //     ar_valid_o_reg <= 1'b1;
            // end
            if (!ar_valid_o_reg && address_queue_rd_enable_q && address_queue_data_out.AR_AW_tag) begin
                ar_valid_o_reg <= 1'b1;
            end
            // if (!ar_valid_o_reg && address_queue_data_out.AR_AW_tag) begin
            //     ar_valid_o_reg <= 1'b1;
            // end
        end
    end

    // AW Valid-Ready Handshake
    assign aw_valid_o = aw_valid_o_reg;
    wire aw_handshake;
    assign aw_handshake = aw_valid_o_reg && aw_ready_i;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            aw_valid_o_reg <= 1'b0;
        end
        else begin
            if (aw_handshake) begin
                aw_valid_o_reg <= 1'b0;
            end
            if (!aw_valid_o_reg && address_queue_rd_enable_q && !address_queue_data_out.AR_AW_tag) begin
                aw_valid_o_reg <= 1'b1;
            end
        end
    end


    logic [1:0] hold_cnt;  // to enforce 2-cycle valid
    assign dw_valid_o = dw_valid_o_reg;
    wire dw_handshake = dw_valid_o_reg && dw_ready_i;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            dw_valid_o_reg <= 1'b0;
            hold_cnt       <= 2'd0;
        end else begin
            if (dw_fifo_rd_en && !dw_valid_o_reg) begin
                // launch a new transaction
                dw_valid_o_reg <= 1'b1;
                hold_cnt       <= 2'd2;   // enforce 2-cycle minimum
            end else if (dw_valid_o_reg) begin
                if (hold_cnt != 0)
                    hold_cnt <= hold_cnt - 1;
                // drop valid only if:
                // 1. handshake completed
                // 2. we already held VALID high for 2 cycles
                if (dw_handshake && (hold_cnt == 1)) begin
                    dw_valid_o_reg <= 1'b0;
                end
            end
        end
    end


    always_comb begin
        if (ar_valid_i) begin
            fifo_wr_en = ar_valid_i && !fifo_full;
        end
        else if (aw_valid_i) begin
            fifo_wr_en = aw_valid_i && !fifo_full;
        end
        else begin
            fifo_wr_en = 1'b0;
        end
    end

    always_comb begin
        if (fifo_AR_AW_tag_wire) begin
            counter_start = fifo_empty_fall || (counter_zero_flag && !fifo_empty && ar_ready_i);
        end
        else if (!fifo_AR_AW_tag_wire) begin
            counter_start = fifo_empty_fall || (counter_zero_flag && !fifo_empty && aw_ready_i);
        end
        else begin
            counter_start = 1'b0;
        end
    end


    // Driving the output ports
    always_comb begin
        if (address_queue_data_out.AR_AW_tag) begin     // AR tag = 1, AW tag = 0
            ar_signals_o.id = address_queue_data_out.AR_AW_signals.id;
            ar_signals_o.addr = address_queue_data_out.AR_AW_signals.addr;
            ar_signals_o.len = address_queue_data_out.AR_AW_signals.len;
            ar_signals_o.size = address_queue_data_out.AR_AW_signals.size;
            ar_signals_o.burst = address_queue_data_out.AR_AW_signals.burst;
            ar_signals_o.lock = address_queue_data_out.AR_AW_signals.lock;
            ar_signals_o.cache = address_queue_data_out.AR_AW_signals.cache;
            ar_signals_o.prot = address_queue_data_out.AR_AW_signals.prot;
            ar_signals_o.qos = address_queue_data_out.AR_AW_signals.qos;
            ar_signals_o.region = address_queue_data_out.AR_AW_signals.region;
            ar_signals_o.user = address_queue_data_out.AR_AW_signals.user;
        end
        else begin
            ar_signals_o.id = '0;
            ar_signals_o.addr = '0;
            ar_signals_o.len = '0;
            ar_signals_o.size = '0;
            ar_signals_o.burst = '0;
            ar_signals_o.lock = '0;
            ar_signals_o.cache = '0;
            ar_signals_o.prot = '0;
            ar_signals_o.qos = '0;
            ar_signals_o.region = '0;
            ar_signals_o.user = '0;
        end

        if (!address_queue_data_out.AR_AW_tag) begin
            aw_signals_o.id = address_queue_data_out.AR_AW_signals.id;
            aw_signals_o.addr = address_queue_data_out.AR_AW_signals.addr;
            aw_signals_o.len = address_queue_data_out.AR_AW_signals.len;
            aw_signals_o.size = address_queue_data_out.AR_AW_signals.size;
            aw_signals_o.burst = address_queue_data_out.AR_AW_signals.burst;
            aw_signals_o.lock = address_queue_data_out.AR_AW_signals.lock;
            aw_signals_o.cache = address_queue_data_out.AR_AW_signals.cache;
            aw_signals_o.prot = address_queue_data_out.AR_AW_signals.prot;
            aw_signals_o.qos = address_queue_data_out.AR_AW_signals.qos;
            aw_signals_o.region = address_queue_data_out.AR_AW_signals.region;
            aw_signals_o.atop = address_queue_data_out.AR_AW_signals.atop;
            aw_signals_o.user = address_queue_data_out.AR_AW_signals.user;
        end
        else begin
            aw_signals_o.id = '0;
            aw_signals_o.addr = '0;
            aw_signals_o.len = '0;
            aw_signals_o.size = '0;
            aw_signals_o.burst = '0;
            aw_signals_o.lock = '0;
            aw_signals_o.cache = '0;
            aw_signals_o.prot = '0;
            aw_signals_o.qos = '0;
            aw_signals_o.region = '0;
            aw_signals_o.atop = '0;
            aw_signals_o.user = '0;
        end

        dw_signals_o.data = dw_data_out.w_signals.data;
        dw_signals_o.strb = dw_data_out.w_signals.strb;
        dw_signals_o.last = dw_data_out.w_signals.last;
        dw_signals_o.user = dw_data_out.w_signals.user;
    end




 
 

endmodule