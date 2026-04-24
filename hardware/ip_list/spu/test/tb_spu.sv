`include "axi/typedef.svh"
`include "axi/assign.svh"

module tb_spu #(
    /// Number of AXI masters connected to the xbar. (Number of slave ports)
    parameter int unsigned TbNumMasters        = 32'd1,
    /// Number of AXI slaves connected to the xbar. (Number of master ports)
    parameter int unsigned TbNumSlaves         = 32'd1,
    /// Number of write transactions per master.
    parameter int unsigned TbNumWrites         = 32'd500,
    /// Number of read transactions per master.
    parameter int unsigned TbNumReads          = 32'd500,
    /// AXI4+ATOP ID width of the masters connected to the slave ports of the DUT.
    /// The ID width of the slaves is calculated depending on the xbar configuration.
    parameter int unsigned TbAxiIdWidthMasters = 32'd5,
    /// The used ID width of the DUT.
    /// Has to be `TbAxiIdWidthMasters >= TbAxiIdUsed`.
    parameter int unsigned TbAxiIdUsed         = 32'd3,
    /// Data width of the AXI channels.
    parameter int unsigned TbAxiDataWidth      = 32'd64,
    /// Pipeline stages in the xbar itself (between demux and mux).
    parameter int unsigned TbPipeline          = 32'd1,
    /// Enable ATOP generation
    parameter bit          TbEnAtop            = 1'b0,
    /// Enable exclusive accesses
    parameter bit TbEnExcl                     = 1'b0,   
    /// Restrict to only unique IDs         
    parameter bit TbUniqueIds                  = 1'b0,
    // Set to 0 for size in number of cachelines.
    // Set to 1 for size in bytes.
    parameter bit SizeInBytes                  = 1'b0
    ,
    // Minimum bits that should be used for latency.
    parameter int unsigned TbLatencyBits       = 64    
);

    // This slows down the testbench for large number of reads and writes.
    // You can reduce the CAM depth but then some responses might not be captured.
    let max(a,b) = (a > b) ? a : b;
    localparam int unsigned CAM_DEPTH  = max(TbNumReads,TbNumWrites);
    localparam int unsigned FIFO_DEPTH = 500;

    // TB timing parameters
    localparam time CyclTime = 10ns;
    localparam time ApplTime =  2ns;
    localparam time TestTime =  8ns;

    // AXI configuration which is automatically derived.
    localparam int unsigned Master_Bits        = (TbNumMasters==1) ? 1 : $clog2(TbNumMasters);
    localparam int unsigned TbAxiIdWidthSlaves =  TbAxiIdWidthMasters + Master_Bits;
    localparam int unsigned TbAxiAddrWidth     =  32'd64;
    localparam int unsigned TbAxiStrbWidth     =  TbAxiDataWidth / 8;
    localparam int unsigned TbAxiUserWidth     =  5;

    localparam int unsigned NoAddrRules        =  TbNumSlaves;

    typedef logic [TbAxiIdWidthMasters-1:0] id_mst_t;
    typedef logic [TbAxiIdWidthSlaves-1:0]  id_slv_t;
    typedef logic [TbAxiAddrWidth-1:0]      addr_t;
    typedef axi_pkg::xbar_rule_32_t         rule_t; // Has to be the same width as axi addr
    typedef logic [TbAxiDataWidth-1:0]      data_t;
    typedef logic [TbAxiStrbWidth-1:0]      strb_t;
    typedef logic [TbAxiUserWidth-1:0]      user_t;

    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AW_CHAN_T(aw_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_mst_t, id_mst_t, user_t)
    `AXI_TYPEDEF_B_CHAN_T(b_chan_slv_t, id_slv_t, user_t)

    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_mst_t, addr_t, id_mst_t, user_t)
    `AXI_TYPEDEF_AR_CHAN_T(ar_chan_slv_t, addr_t, id_slv_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_mst_t, data_t, id_mst_t, user_t)
    `AXI_TYPEDEF_R_CHAN_T(r_chan_slv_t, data_t, id_slv_t, user_t)

    `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_mst_t, w_chan_t, ar_chan_mst_t)
    `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_mst_t, r_chan_mst_t)
    `AXI_TYPEDEF_REQ_T(slv_req_t, aw_chan_slv_t, w_chan_t, ar_chan_slv_t)
    `AXI_TYPEDEF_RESP_T(slv_resp_t, b_chan_slv_t, r_chan_slv_t)    

    // Each slave has its own address range:
    localparam rule_t [NoAddrRules-1:0] AddrMap = addr_map_gen();
    
    localparam int unsigned AddrWidth = TbAxiAddrWidth;
    localparam int unsigned DataWidth = TbAxiAddrWidth;
    localparam int unsigned UserWidth = TbAxiUserWidth;

    localparam int unsigned SetAssociativity = 32'd8;
    localparam int unsigned NumLines         = 32'd256;
    localparam int unsigned NumBlocks        = 32'd8;

    function rule_t [NoAddrRules-1:0] addr_map_gen ();
    for (int unsigned i = 0; i < NoAddrRules; i++) begin
        addr_map_gen[i] = rule_t'{
        idx:        unsigned'(i),
        start_addr:  i    * 32'h0000_2000,
        end_addr:   (i+1) * 32'h0000_2000,
        default:    '0
        };
    end
    endfunction

    typedef  axi_test::axi_rand_master #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth          ),
        .DW ( TbAxiDataWidth          ),
        .IW ( TbAxiIdWidthMasters     ),
        .UW ( TbAxiUserWidth          ),
        // Stimuli application and test time
        .TA ( ApplTime                ),
        .TT ( TestTime                ),
        // Maximum number of read and write transactions in flight
        .MAX_READ_TXNS  ( 20          ),
        .MAX_WRITE_TXNS ( 20          ),
        .AXI_EXCLS      ( TbEnExcl    ),
        .AXI_ATOPS      ( TbEnAtop    ),
        .UNIQUE_IDS     ( TbUniqueIds )
    ) axi_rand_master_t;

    typedef  axi_test::axi_rand_slave #(
        // AXI interface parameters
        .AW ( TbAxiAddrWidth     ),
        .DW ( TbAxiDataWidth     ),
        .IW ( TbAxiIdWidthSlaves ),
        .UW ( TbAxiUserWidth     ),
        // Stimuli application and test time
        .TA ( ApplTime           ),
        .TT ( TestTime           )
    ) axi_rand_slave_t;

    // -------------
    // DUT signals
    // -------------
    logic clk;
    // DUT signals
    logic rst_n;
    logic end_of_sim;

    // master structs
    mst_req_t  masters_req;
    mst_resp_t masters_resp;

    // slave structs
    slv_req_t  slaves_req;
    slv_resp_t slaves_resp;

    // -------------------------------
    // AXI Interfaces
    // -------------------------------
    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master ();
    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
    ) master_dv (clk);

    `AXI_ASSIGN (master, master_dv)
    `AXI_ASSIGN_TO_REQ(masters_req, master)
    `AXI_ASSIGN_TO_RESP(masters_resp, master)

    AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave ();

    AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
    ) slave_dv (clk);

    `AXI_ASSIGN(slave_dv, slave)
    `AXI_ASSIGN_TO_REQ(slaves_req, slave)
    `AXI_ASSIGN_TO_RESP(slaves_resp, slave)

    // -------------------------------
    // AXI Rand Masters and Slaves
    // -------------------------------
    // Masters control simulation run time
    axi_rand_master_t axi_rand_master;

    initial begin
        axi_rand_master = new( master_dv );
        end_of_sim <= 1'b0;
        axi_rand_master.add_memory_region(AddrMap[0].start_addr,
                                        AddrMap[NoAddrRules-1].end_addr,
                                        axi_pkg::DEVICE_NONBUFFERABLE);
        axi_rand_master.reset();
        @(posedge rst_n);
        axi_rand_master.run(TbNumReads, TbNumWrites);
        end_of_sim <= 1'b1;
    end

    axi_rand_slave_t axi_rand_slave;
    initial begin
        axi_rand_slave = new( slave_dv );
        axi_rand_slave.reset();
        @(posedge rst_n);
        axi_rand_slave.run();
    end

    initial begin
        automatic string       log_name;
        automatic int          fd;

        // make the log dirs
        log_name = $sformatf("mkdir -p ./spu_log/");
        $system(log_name);

        // open log files
        log_name = $sformatf("./spu_log/read_req.log");
        fd = $fopen(log_name, "w");
        if (fd) begin
            $display("File was opened successfully : %0d", fd);
            $fdisplay(fd, "event_id,source_id,unaligned_transfer,size_of_burst(%0d)", SizeInBytes);
            $fclose(fd);
        end else begin
            $display("File was NOT opened successfully : %0d", fd);
        end

        log_name = $sformatf("./spu_log/read_resp.log");
        fd = $fopen(log_name, "w");
        if (fd) begin
            $display("File was opened successfully : %0d", fd);
            $fdisplay(fd, "event_id,source_id,resp_latency");
            $fclose(fd);
        end else begin
            $display("File was NOT opened successfully : %0d", fd);
        end

        log_name = $sformatf("./spu_log/write_req.log");
        fd = $fopen(log_name, "w");
        if (fd) begin
            $display("File was opened successfully : %0d", fd);
            $fdisplay(fd, "event_id,source_id,unaligned_transfer,size_of_burst(%0d)", SizeInBytes);
            $fclose(fd);
        end else begin
            $display("File was NOT opened successfully : %0d", fd);
        end

        log_name = $sformatf("./spu_log/write_resp.log");
        fd = $fopen(log_name, "w");
        if (fd) begin
            $display("File was opened successfully : %0d", fd);
            $fdisplay(fd, "event_id,source_id,resp_latency");
            $fclose(fd);
        end else begin
            $display("File was NOT opened successfully : %0d", fd);
        end
    end

    always @ (posedge clk) begin
        automatic string       log_name;
        automatic int          fd;

        if (rst_n) begin
            if (spu_out.e_id == 1) begin
                log_name = $sformatf("./spu_log/read_req.log");
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d",
                                1,
                                spu_out.s_id,
                                spu_out.e_info[15],
                                spu_out.e_info[14:0]
                         );
                $fclose(fd);
            end

            if (spu_out.e_id == 3) begin
                log_name = $sformatf("./spu_log/read_resp.log");
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d",
                                3,
                                spu_out.s_id,
                                spu_out.e_info[15:0]
                         );
                $fclose(fd);
            end

            if (spu_out.e_id == 2) begin
                log_name = $sformatf("./spu_log/write_req.log");
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d,%0d",
                                2,
                                spu_out.s_id,
                                spu_out.e_info[15],
                                spu_out.e_info[14:0]
                         );
                $fclose(fd);
            end

            if (spu_out.e_id == 4) begin
                log_name = $sformatf("./spu_log/write_resp.log");
                fd = $fopen(log_name, "a");
                $fdisplay(fd, "%0d,%0d,%0d",
                                4,
                                spu_out.s_id,
                                spu_out.e_info[15:0]
                         );
                $fclose(fd);
            end
        end
    end

    logic [490:0]    end_wait;
    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            end_wait[0] <= 1'b0;
        end else if (end_of_sim) begin
            end_wait[0] <= 1'b1;
        end
    end

    for (genvar i=1; i<=490; i=i+1) begin
        always_ff @ (posedge clk) begin
            end_wait[i] <= end_wait[i-1];
        end
    end

    always_ff @ (posedge clk) begin
        if (end_wait[490]) begin
            $finish();
        end
    end

    //-----------------------------------
    // Device Under Test (DUT)
    //-----------------------------------

    typedef struct packed {
      logic [31:0] idx;
      logic [63:0] start_addr;
      logic [63:0] end_addr;
   } addr_map_rule_t;

    localparam N_ADDR_RULES = 2;
    addr_map_rule_t [N_ADDR_RULES-1:0] dut_addr_map;
    assign dut_addr_map[0] = '{
            idx: 0,
            start_addr: 32'h0,
            end_addr:   32'h8000_0000
    };

    assign dut_addr_map[1] = '{
            idx: 1,
            start_addr: 32'h8000_0000,
            end_addr:   32'h8000_0000 + 32'h4000_0000
    };

    pmu_pkg::pmu_event_t spu_out;

    spu_top #(
        // Static configuration parameters of the cache.
        .SetAssociativity   ( SetAssociativity  ),
        .NumLines           ( NumLines          ),
        .NumBlocks          ( NumBlocks         ),
        // AXI4 Specifications
        .IdWidthMasters     ( TbAxiIdWidthMasters ),
        .IdWidthSlaves      ( TbAxiIdWidthSlaves  ),
        .AddrWidth          ( AddrWidth         ),
        .DataWidth          ( DataWidth         ),
        // Size of burst in cachelines (0) or bytes (1)?
        .SizeInBytes        ( SizeInBytes       ),
        .addr_rule_t        ( addr_map_rule_t   ),
        .N_ADDR_RULES       ( N_ADDR_RULES      ),
        // FIFO and CAM Parameters
        .CAM_DEPTH          ( CAM_DEPTH         ),
        .FIFO_DEPTH         ( FIFO_DEPTH        )
    ) dut_spu (
        .clk_i               ( clk              ),
        .rst_ni              ( rst_n            ),
        .addr_map_i          ( dut_addr_map     ), 
        .spu_slv             ( master           ),
        .spu_mst             ( slave            ),
        .e_out               ( spu_out          )
    );

    //-----------------------------------
    // Clock generator
    //-----------------------------------
    clk_rst_gen #(
        .ClkPeriod    ( CyclTime ),
        .RstClkCycles ( 5        )
    ) i_clk_gen (
        .clk_o (clk),
        .rst_no(rst_n)
    );

    // logger for master modules
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_master_0")),
        .aw_chan_t ( aw_chan_mst_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_mst_t ), // axi  B type
        .ar_chan_t ( ar_chan_mst_t ), // axi AR type
        .r_chan_t  (  r_chan_mst_t )  // axi  R type
    ) i_mst_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( masters_req.aw        ),
        .aw_valid_i ( masters_req.aw_valid  ),
        .aw_ready_i ( masters_resp.aw_ready ),
        //  W channel
        .w_chan_i   ( masters_req.w         ),
        .w_valid_i  ( masters_req.w_valid   ),
        .w_ready_i  ( masters_resp.w_ready  ),
        //  B channel
        .b_chan_i   ( masters_resp.b        ),
        .b_valid_i  ( masters_resp.b_valid  ),
        .b_ready_i  ( masters_req.b_ready   ),
        // AR channel
        .ar_chan_i  ( masters_req.ar        ),
        .ar_valid_i ( masters_req.ar_valid  ),
        .ar_ready_i ( masters_resp.ar_ready ),
        //  R channel
        .r_chan_i   ( masters_resp.r        ),
        .r_valid_i  ( masters_resp.r_valid  ),
        .r_ready_i  ( masters_req.r_ready   )
    );

    // logger for slave modules
    axi_chan_logger #(
        .TestTime  ( TestTime      ), // Time after clock, where sampling happens
        .LoggerName( $sformatf("axi_logger_slave_0")),
        .aw_chan_t ( aw_chan_slv_t ), // axi AW type
        .w_chan_t  (  w_chan_t     ), // axi  W type
        .b_chan_t  (  b_chan_slv_t ), // axi  B type
        .ar_chan_t ( ar_chan_slv_t ), // axi AR type
        .r_chan_t  (  r_chan_slv_t )  // axi  R type
    ) i_slv_channel_logger (
        .clk_i      ( clk         ),    // Clock
        .rst_ni     ( rst_n       ),    // Asynchronous reset active low, when `1'b0` no sampling
        .end_sim_i  ( &end_of_sim ),
        // AW channel
        .aw_chan_i  ( slaves_req.aw        ),
        .aw_valid_i ( slaves_req.aw_valid  ),
        .aw_ready_i ( slaves_resp.aw_ready ),
        //  W channel
        .w_chan_i   ( slaves_req.w         ),
        .w_valid_i  ( slaves_req.w_valid   ),
        .w_ready_i  ( slaves_resp.w_ready  ),
        //  B channel
        .b_chan_i   ( slaves_resp.b        ),
        .b_valid_i  ( slaves_resp.b_valid  ),
        .b_ready_i  ( slaves_req.b_ready   ),
        // AR channel
        .ar_chan_i  ( slaves_req.ar        ),
        .ar_valid_i ( slaves_req.ar_valid  ),
        .ar_ready_i ( slaves_resp.ar_ready ),
        //  R channel
        .r_chan_i   ( slaves_resp.r        ),
        .r_valid_i  ( slaves_resp.r_valid  ),
        .r_ready_i  ( slaves_req.r_ready   )
    );

endmodule : tb_spu