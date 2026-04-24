//// to do: fix pending bit ---- ibex reading counter should read pending bit too 596
/// writing to memguard causes pending to be set?
/// pmu core writing to counter causes pending?
module pmu_top import pmu_pkg::*; #(
    parameter int unsigned  NUM_PORT         = 5,
    parameter int unsigned  NUM_COUNTER      = 32,

    // APMU Addresses and SPM configuration
    parameter int unsigned APMU_BASE_ADDR    = 32'h1040_5000,
    parameter int unsigned ISPM_BASE_ADDR    = 32'h1042_7000,
    parameter int unsigned DSPM_BASE_ADDR    = 32'h1042_8000,
    parameter int unsigned ISPM_NUM_WORDS    = 1024,
    parameter int unsigned DSPM_NUM_WORDS    = 8192,

    // Address of Memory module
    parameter int unsigned  MEMORY_BASE_ADDR = 32'h8000_0000,
    parameter int unsigned  MEMORY_LENGTH    = 32'h400_0000,
    
    // DO NOT CHANGE THESE PAREMETERS unless
    // you are extending the entire PMU to 64-bits!
    parameter int unsigned  PMU_ADDR_WIDTH   = 32,
    parameter int unsigned  PMU_DATA_WIDTH   = 32,
    parameter int unsigned  PMU_STRB_WIDTH   = PMU_DATA_WIDTH/8,

    // Typedefs
    // AXI-Lite Structs
    parameter type req_lite_t       = pmu_pkg::req_lite_t,
    parameter type resp_lite_t      = pmu_pkg::resp_lite_t,
    parameter type aw_chan_lite_t   = pmu_pkg::aw_chan_lite_t,
    parameter type w_chan_lite_t    = pmu_pkg::w_chan_lite_t,
    parameter type b_chan_lite_t    = pmu_pkg::b_chan_lite_t,
    parameter type ar_chan_lite_t   = pmu_pkg::ar_chan_lite_t,
    parameter type r_chan_lite_t    = pmu_pkg::r_chan_lite_t,
    // Full AXI Structs
    parameter type req_axi_t        = logic,
    parameter type resp_axi_t       = logic
) (
    input logic                      clk_i,
    input logic                      rst_ni,
    input pmu_event_t [NUM_PORT-1:0] port_i,
    // AXI4 master port request, configuration
    output req_lite_t                master_req_o,
    // AXI4 master port response, configuration
    input  resp_lite_t               master_resp_i,
    // AXI4-Lite slave port response, configuration
    input  req_lite_t                conf_req_i,
    // AXI4-Lite slave port response, configuration
    output resp_lite_t               conf_resp_o,
    // Interrupts from PMU to the PLIC
    output logic [NUM_COUNTER-1:0]   intr_o
);
    `include "axi/typedef.svh"
    
    /// ************************************************************************
    /// Memory Map - Local Parameters and TypeDefs
    /// ************************************************************************
    /// 
    /// The memory map of the PMU is as follows:
    ///     /************************************\
    ///     | Initial Budget Register            |
    ///     | Event Info Configuration Register  |          Not yet 4kB aligned
    ///     | Event Selection Register           |              Counter Bundle
    ///     | Counter                            |
    ///     \************************************/
    ///                     .
    ///                     .                         ... x (NUM_COUNTER)
    ///                     .
    ///     /************************************\
    ///     | Initial Budget Register            |
    ///     | Event Info Configuration Register  |          Not yet 4kB aligned          
    ///     | Event Selection Register           |              Counter Bundle
    ///     | Counter                            |
    ///     \************************************/
    ///     /************************************\
    ///     | Initial Budget Register            |
    ///     | Event Info Configuration Register  |          Not yet 4kB aligned
    ///     | Event Selection Register           |              Counter Bundle
    ///     | Counter                            |
    ///     \************************************/
    ///     /************************************\
    ///     | Status Register                    |
    ///     | MemGuard Period Register           |          Not yet 4kB aligned
    ///     | PMU Timer                          |              PMU Bundle
    ///     \************************************/
    /// 
    /// Each block is a separate 4kB-aligned page.
    /// The PMU Bundle includes the PMU Timer and the MemGuard Period Register.
    /// A counter bundle includes:
    ///     1. Counter
    ///     2. Event Selection Register
    ///     3. Event Info Configuration Register
    ///     4. Initial Budget Register

    typedef logic [7:0]                 byte_t;
    typedef logic [PMU_ADDR_WIDTH-1:0]  addr_t;
    typedef logic [PMU_DATA_WIDTH-1:0]  data_t;

    localparam int unsigned INCR_BIT = $clog2(NUM_PORT) + 1;
    typedef logic [INCR_BIT-1:0]       incr_val_t;
    
    // APMU Bundle
    localparam int unsigned TIMER_WIDTH  = 64;
    localparam int unsigned STATUS_WIDTH = 32;

    localparam int unsigned PMU_B_Pad_NumBytes    = 8;
    localparam int unsigned PMU_B_Addr_NumBytes   = PMU_ADDR_WIDTH / 8;
    localparam int unsigned PMU_B_Timer_NumBytes  = TIMER_WIDTH / 8;
    localparam int unsigned PMU_B_Status_NumBytes = STATUS_WIDTH / 8;
    localparam int unsigned PMU_B_NumBytes        = 2*PMU_B_Timer_NumBytes +
                                                    PMU_B_Status_NumBytes +
                                                    PMU_B_Addr_NumBytes +
                                                    PMU_B_Pad_NumBytes;

    typedef logic [TIMER_WIDTH-1:0]           timer_t;
    typedef logic [PMU_B_Timer_NumBytes-1:0]  strb_timer_t;
    typedef logic [PMU_B_Status_NumBytes-1:0] strb_status_t;
    typedef logic [PMU_B_Addr_NumBytes-1:0]   strb_addr_t;

    // To Do: Add more here pmu register
    typedef struct packed {
        logic [STATUS_WIDTH-2:0] padded;
        logic                    stall;
    } status_t;

    // This struct is 32B. 
    typedef struct packed {
        byte_t [7:0]    pad;        // base_addr + 0x18
        addr_t          boot_addr;  // base_addr + 0x14
        status_t        status;     // base_addr + 0x10
        timer_t         period;     // base_addr + 0x08
        timer_t         timer;      // base_addr + 0x00
    } pmu_bundle_t;

    typedef struct packed {
        logic [7:0]     pad;
        strb_addr_t     boot_addr;
        strb_status_t   status;
        strb_timer_t    period;
        strb_timer_t    timer;
    } strb_pmu_bundle_t;

    // Counter Bundle
    localparam int unsigned COUNTER_WIDTH         = 32'd32;
    localparam int unsigned COUNTER_WIDTH_STRB    = COUNTER_WIDTH/8;
    localparam int unsigned Counter_NumBytes      = COUNTER_WIDTH / 8;
    localparam int unsigned EventSelCfg_NumBytes  = EVENT_SEL_CFG_WIDTH / 8;
    localparam int unsigned EventInfoCfg_NumBytes = EVENT_INFO_CFG_WIDTH / 8;

    localparam int unsigned CounterB_NumBytes     = 2*Counter_NumBytes +
                                                    EventSelCfg_NumBytes +
                                                    EventInfoCfg_NumBytes;

    // Assuming that COUNTER_WIDTH = 32. 
    // A counter is 32-bit where the 31st bit is reserved for pending and 30th is reserved for overflow.
    localparam int unsigned PadB_NumBytes = 80;

    typedef struct packed {
        logic                       pending;
        logic [COUNTER_WIDTH-2:0]   counter;
    } counter_t;

    typedef logic [Counter_NumBytes-1:0]         strb_counter_t;
    typedef logic [EventSelCfg_NumBytes-1:0]     strb_event_sel_cfg_t;
    typedef logic [EventInfoCfg_NumBytes-1:0]    strb_event_info_cfg_t;

    // This struct is 16B.
    typedef struct packed {
        counter_t           initBudgeReg;   // base_addr + 0xC
        event_info_cfg_t    eventInfoCfg;   // base_addr + 0x8
        event_sel_cfg_t     eventSelCfg;    // base_addr + 0x4
        counter_t           counter;        // base_addr + 0x0
    } counter_bundle_t;

    typedef struct packed {
        strb_counter_t          initBudgeReg;
        strb_event_info_cfg_t   eventInfoCfg;
        strb_event_sel_cfg_t    eventSelCfg;
        strb_counter_t          counter;
    } strb_counter_bundle_t;
    
    localparam int unsigned NumBytesCfgRegs = PadB_NumBytes +
                                              PMU_B_NumBytes +
                                              NUM_COUNTER * CounterB_NumBytes;

    typedef struct packed {
        // Counter bundle is replicated NUM_COUNTER times.
        counter_bundle_t [NUM_COUNTER-1:0]  counter_b;
        pmu_bundle_t                        pmu_b;
        byte_t [PadB_NumBytes-1:0]          pad_b;
    } reg_map_t;

    typedef struct packed {
        strb_counter_bundle_t [NUM_COUNTER-1:0] counter_b;  
        strb_pmu_bundle_t                       pmu_b;
        logic [PadB_NumBytes-1:0]               pad_b;
    } strb_map_t;

    typedef union packed {
        byte_t          [NumBytesCfgRegs-1:0]   ByteMap;
        reg_map_t                               StructMap;
    } union_reg_data_t;

    typedef union packed {
        logic           [NumBytesCfgRegs-1:0]   LogicMap;
        strb_map_t                              StrbMap;
    } union_strb_data_t;

    // SPMs
    localparam int unsigned PMU_REG_START_ADDR = APMU_BASE_ADDR;
    // 4 pages are used for padding, 2 are used for PMU bundle, and 1 is used for each counter bundle.
    localparam int unsigned PMU_REG_LENGTH     = (NUM_COUNTER + 2) * 32'h1000;

    // One word is 4B or 32-bits.
    localparam int unsigned ISPM_NumBytes   = ISPM_NUM_WORDS * (PMU_STRB_WIDTH);
    localparam int unsigned DSPM_NumBytes   = DSPM_NUM_WORDS * (PMU_STRB_WIDTH);

    initial begin
        $display("PMU %x to %x", PMU_REG_START_ADDR, PMU_REG_START_ADDR+PMU_REG_LENGTH);
    end
    
    // ************************************************************************
    // PMU Core Signals
    // ************************************************************************
    addr_t              core_counter_addr;
    apmu_ibex_pkg::pmc_op_e  core_counter_op;
    data_t              core_counter_rdata_d;
    data_t              core_counter_rdata_q;
    logic               core_counter_we;
    logic               core_counter_gnt_d;
    logic               core_counter_gnt_q;
    data_t              core_counter_wdata;
    logic               core_counter_rvalid_d;
    logic               core_counter_rvalid_q;
    logic               core_counter_err_d;
    logic               core_counter_err_q;

    // ************************************************************************
    // APMU AXI4-Lite Xbar
    // ************************************************************************
    req_lite_t     pmu_reg_req;
    req_lite_t     pmu_reg_req_remap;
    resp_lite_t    pmu_reg_resp;
    
    req_lite_t     pmc_req;
    resp_lite_t    pmc_resp;

    req_lite_t     ispm_req;
    resp_lite_t    ispm_resp;

    req_lite_t     dspm_req;
    resp_lite_t    dspm_resp;

    req_lite_t     master_req;
    resp_lite_t    master_resp;

    req_lite_t     conf_req;
    resp_lite_t    conf_resp;

    typedef axi_pkg::xbar_rule_32_t pmu_xbar_rule_t;

    localparam axi_pkg::xbar_cfg_t PMUXbarCfg = '{
        NoSlvPorts:  2,     // Number of Master devices
        NoMstPorts:  4,     // Number of Slave devices
        MaxMstTrans: 2,
        MaxSlvTrans: 4,     // Maximum number of outstanding transactions per write or read
        FallThrough: 0,
        LatencyMode: axi_pkg::CUT_SLV_AX,
        PipelineStages: 32'd0,   // To Do: WHY?
        AxiIdWidthSlvPorts: 1,
        AxiIdUsedSlvPorts: 1, 
        UniqueIds   : 0,
        AxiAddrWidth: PMU_ADDR_WIDTH,
        AxiDataWidth: PMU_DATA_WIDTH,
        NoAddrRules:  4     // For now: 1, min 3 for ispm, dspm and axilite_regs
    };

    // Ensure that the number of elements in `PMUXbarAddrMap` matches `PMUXbarCfg.NoAddrRules`.
    // Otherwise QuestaSIM will throw a `Fatal (SIGSEGV)`.    
    localparam pmu_xbar_rule_t [PMUXbarCfg.NoAddrRules-1:0]
        PMUXbarAddrMap = '{
            '{idx: 32'd3, start_addr: MEMORY_BASE_ADDR,   end_addr: (MEMORY_BASE_ADDR   + MEMORY_LENGTH)},  // System Memory
            '{idx: 32'd2, start_addr: DSPM_BASE_ADDR,     end_addr: (DSPM_BASE_ADDR     + DSPM_NumBytes)},  // Data SPM
            '{idx: 32'd1, start_addr: ISPM_BASE_ADDR,     end_addr: (ISPM_BASE_ADDR     + ISPM_NumBytes)},  // Instruction SPM
            '{idx: 32'd0, start_addr: PMU_REG_START_ADDR, end_addr: (PMU_REG_START_ADDR + PMU_REG_LENGTH)}  // AXI4-Lite Registers            
        };

    axi_lite_xbar #(
        .Cfg                   ( PMUXbarCfg         ),
        .aw_chan_t             ( aw_chan_lite_t     ),
        .w_chan_t              ( w_chan_lite_t      ),
        .b_chan_t              ( b_chan_lite_t      ),
        .ar_chan_t             ( ar_chan_lite_t     ),
        .r_chan_t              ( r_chan_lite_t      ),
        .axi_req_t             ( req_lite_t         ),
        .axi_resp_t            ( resp_lite_t        ),
        .rule_t                ( pmu_xbar_rule_t    )
    ) i_pmu_axi_lite_xbar (
        .clk_i                 ( clk_i           ),
        .rst_ni                ( rst_ni          ),
        .test_i                ( 1'b0            ),
        .slv_ports_req_i       ( { pmc_req, conf_req_i }    ), 
        .slv_ports_resp_o      ( { pmc_resp, conf_resp_o }  ), 
        .mst_ports_req_o       ( { master_req_o, dspm_req, ispm_req, pmu_reg_req }      ),
        .mst_ports_resp_i      ( { master_resp_i, dspm_resp, ispm_resp, pmu_reg_resp }  ),
        .addr_map_i            ( PMUXbarAddrMap  ),
        .en_default_mst_port_i ( { 1'b0, 1'b0 }  ),
        .default_mst_port_i    ( '0              )
    );

    // ************************************************************************
    // PMU Signals
    // ************************************************************************

    // Timer signals
    timer_t timer_d;
    timer_t timer_q;

    timer_t period_q;

    // Overflow signals
    logic [NUM_COUNTER-1:0] intr_d; 
    logic [NUM_COUNTER-1:0] intr_q;

    // Counter Increment Enable
    // If `event_info_en` is not enabled, the counter increments by `incr_val`.
    // If multiple selected events from different ports occur in the same clock cycle,
    // the counter will increment accordingly. At most, it can be `NUM_PORT`.
    incr_val_t   [NUM_COUNTER-1:0] incr_val;

    // If `event_info_en` is enabled then based on the chosen function the
    // counter is updated. Correct behaviour is guaranteed when only one port is selected
    // for a counter. If multiple ports are selected and `eventInfo_en` is 1 then
    // correct behaviour cannot be guaranteed.
    logic                   [NUM_COUNTER-1:0] event_info_ctrl;
    pmu_pkg::event_info_t   [NUM_COUNTER-1:0] event_info_val;

    // Signals the counter operation requested by the PMU core to each core.
    apmu_ibex_pkg::pmc_op_e [NUM_COUNTER-1:0]    per_counter_op;

    // Sets when a new MemGuard round starts. Is de-asserted in the next clock cycle.
    logic memguard_reset;

    addr_t pmc_boot_addr;
    logic  stall_core;

    // Aliases to shorten signal names.
    counter_t           [NUM_COUNTER-1:0]   counter_d;  // Output of `pmu_counter`.
    counter_t           [NUM_COUNTER-1:0]   counter_q;  // Input to `pmu_counter`.
    event_sel_cfg_t     [NUM_COUNTER-1:0]   event_sel_cfg;
    event_info_cfg_t    [NUM_COUNTER-1:0]   event_info_cfg;
    counter_t           [NUM_COUNTER-1:0]   init_budget_reg;

    event_id_t   [NUM_COUNTER-1:0] event_id_mask;
    event_id_t   [NUM_COUNTER-1:0] event_id_val;
    source_id_t  [NUM_COUNTER-1:0] source_id_mask;
    source_id_t  [NUM_COUNTER-1:0] source_id_val;
    port_id_t    [NUM_COUNTER-1:0] port_id_mask;
    port_id_t    [NUM_COUNTER-1:0] port_id_val;

    logic        [NUM_COUNTER-1:0] event_info_en;

    // `wr_active_o` is asserted on the clock cycle during
    // which the AXI4 write take places.
    strb_counter_t   [NUM_COUNTER-1:0]      axi_counter_wr_active;
    // reg_load_i is the load enable of each byte.
    strb_counter_t   [NUM_COUNTER-1:0]      axi_counter_reg_load;

    union_reg_data_t    reg_d, reg_q;
    union_strb_data_t   reg_wr_o;
    union_strb_data_t   reg_load_i;

    logic [NUM_COUNTER-1:0] pending;
    logic [NUM_COUNTER-1:0] overflow;

    genvar i;

    // ************************************************************************
    // AXI4-Lite Registers
    // ************************************************************************
    // This bit represent whether the PMU core is asked to stall.
    assign stall_core    = reg_q.StructMap.pmu_b.status.stall;
    // This is the boot address of the PMU core.
    assign pmc_boot_addr = reg_q.StructMap.pmu_b.boot_addr;

    // `reg_wr_o` signals that a byte is being written from the AXI4-Lite 
    // port in the current clock cycle.
    for (i=0; i<NUM_COUNTER; i=i+1) begin
        always_comb begin
            axi_counter_wr_active[i] = reg_wr_o.StrbMap.counter_b[i].counter;
        end
    end

    // Aliases to shorten signal names. They are the ouptut of `axi_lite_regs`.
    for (i=0; i<NUM_COUNTER; i=i+1) begin
        always_comb begin
            counter_q[i]        = reg_q.StructMap.counter_b[i].counter;
            event_sel_cfg[i]    = reg_q.StructMap.counter_b[i].eventSelCfg;
            event_info_cfg[i]   = reg_q.StructMap.counter_b[i].eventInfoCfg;
            init_budget_reg[i]  = reg_q.StructMap.counter_b[i].initBudgeReg;

            pending[i]          = reg_q.StructMap.counter_b[i].counter.pending;
            overflow[i]         = reg_q.StructMap.counter_b[i].counter.counter[30];            
        end
    end

    // `reg_load_i` allows non-AX4-Lite updates to the registers.
    // Inside the `axi_lite_regs` module, these non-AXI4-Lite updates 
    // take precedence over AXI4-Lite writes. If the `reg_load_i signal` 
    // is True for any register then any AXI4-Lite to that register in that 
    // clock cycle is rejected (SlaveErr).
    
    // In a counter bundle only the counter can be updated by a non-AXI4-Lite writes.
    // The `reg_load` signal for the rest of the registers is always 0.
    for (i=0; i<NUM_COUNTER; i=i+1) begin: reg_load_i_counter_b
        always_comb begin
            reg_load_i.StrbMap.counter_b[i].counter         = axi_counter_reg_load[i];
            reg_load_i.StrbMap.counter_b[i].eventSelCfg     = '0;
            reg_load_i.StrbMap.counter_b[i].eventInfoCfg    = '0;
            reg_load_i.StrbMap.counter_b[i].initBudgeReg    = '0;
        end
    end

    // The timer is updated (incremented) in every clock cycle.
    assign reg_load_i.StrbMap.pmu_b.timer     = {PMU_B_Timer_NumBytes{1'b1}};
    // The MemGuard Period register is only updated by AXI4-Lite writes.
    assign reg_load_i.StrbMap.pmu_b.period    = '0;
    // The boot_addr of the PMU Core is only updated by AXI4-Lite writes.
    assign reg_load_i.StrbMap.pmu_b.boot_addr = '0;
    // The Status register is only updated by AXI4-Lite writes.
    assign reg_load_i.StrbMap.pmu_b.status    = '0;
    // These registers are read-only.
    assign reg_load_i.StrbMap.pmu_b.pad       = '0;
    assign reg_load_i.StrbMap.pad_b           = '0;

    // reg_d is the input to the `axi_lite_reg` module.
    // The `axi_lite_reg` has internal FFs to store the registers and only latch to the 
    // new input bytes (i.e., reg_d) when their corresponding `reg_load_i` strobe bits are are.

    // Since only the timer and counters can be updated by the non-AXI4-Lite writes, their outptus are different.
    // For the rest, the output of `axi_lite_reg` is fed back to the input.
    assign reg_d.StructMap.pmu_b.boot_addr = reg_q.StructMap.pmu_b.boot_addr;
    assign reg_d.StructMap.pmu_b.status    = reg_q.StructMap.pmu_b.status;
    assign reg_d.StructMap.pmu_b.period    = reg_q.StructMap.pmu_b.period;
    assign reg_d.StructMap.pmu_b.timer     = timer_d;

    for (i=0; i<NUM_COUNTER; i=i+1) begin: reg_d_counter_b
        always_comb begin
            reg_d.StructMap.counter_b[i].counter        = counter_d[i];
            reg_d.StructMap.counter_b[i].eventSelCfg    = event_sel_cfg[i];
            reg_d.StructMap.counter_b[i].eventInfoCfg   = event_info_cfg[i];
            reg_d.StructMap.counter_b[i].initBudgeReg   = init_budget_reg[i];
        end
    end

    // Besides the timer all registers are writeable.
    localparam pmu_bundle_t strb_pad_ReadOnly = {64{1'b1}};
    localparam pmu_bundle_t strb_pmu_ReadOnly = pmu_bundle_t'{
        timer: {PMU_B_Timer_NumBytes{1'b1}},
        default: '0
    };

    localparam strb_map_t strb_ReadOnly = strb_map_t'{
        pmu_b: strb_pmu_ReadOnly,
        pad_b: strb_pad_ReadOnly,
        default: '0
    };

    localparam union_strb_data_t ReadOnly = strb_ReadOnly;    

    // Need to initialze eventInfoCfg separately because of the enum `opcode_e`.
    // QuestaSIM complains otherwise.
    localparam event_info_cfg_t event_info_RstVal = event_info_cfg_t'{
        opcode: ADD,
        default: '0
    };

    localparam counter_bundle_t counter_RstVal = counter_bundle_t'{
        eventInfoCfg: event_info_RstVal,
        default: '0
    };

    // PMU core starts stalled.
    localparam status_t status_RstVal = status_t'{
        stall: 1,
        padded: '0,
        default: '0
    };

    localparam pmu_bundle_t pmu_RstVal = pmu_bundle_t'{
        // PMU core boot address is from start of ISPM.
        boot_addr: addr_t'(ISPM_BASE_ADDR),
        status:    status_RstVal,
        default:   '0
    };

    localparam reg_map_t RstVal = reg_map_t'{
        pmu_b: pmu_RstVal,
        counter_b: '{NUM_COUNTER{counter_RstVal}},
        default: '0
    };

    // Address remapping.
    always_comb begin
        pmu_reg_req_remap = pmu_reg_req;

        // Bits 3-0 are still the same.
        pmu_reg_req_remap.aw.addr[3:0]   = pmu_reg_req_remap.aw.addr[3:0];
        pmu_reg_req_remap.aw.addr[11:4]  = pmu_reg_req_remap.aw.addr[19:12];
        // Bits 31-12  (31-12+1 = 20) are always 0x1040_5XXX,
        // if APMU Base Address = 0x1040_5000.
        pmu_reg_req_remap.aw.addr[31:12] = {20'(APMU_BASE_ADDR>>12)};

        // Bits 3-0 are still the same.
        pmu_reg_req_remap.ar.addr[3:0]   = pmu_reg_req.ar.addr[3:0];
        pmu_reg_req_remap.ar.addr[11:4]  = pmu_reg_req_remap.ar.addr[19:12];
        // Bits 31-12  (31-12+1 = 20) are always 0x1040_5XXX,
        // if APMU Base Address = 0x1040_5000.
        pmu_reg_req_remap.ar.addr[31:12] = {20'(APMU_BASE_ADDR>>12)};
    end


    axi_lite_regs#(
        .RegNumBytes  ( NumBytesCfgRegs     ),
        .AxiAddrWidth ( PMU_ADDR_WIDTH      ),
        .AxiDataWidth ( PMU_DATA_WIDTH      ),
        .PrivProtOnly ( 1'b0                ),
        .SecuProtOnly ( 1'b0                ),
        .AxiReadOnly  ( ReadOnly.StrbMap    ),
        .RegRstVal    ( RstVal              ),
        .req_lite_t   ( req_lite_t          ),
        .resp_lite_t  ( resp_lite_t         )
    ) i_axi_lite_regs (
        .clk_i,
        .rst_ni,
        .axi_req_i   ( pmu_reg_req_remap    ),
        .axi_resp_o  ( pmu_reg_resp         ),
        .wr_active_o ( reg_wr_o.LogicMap    ),
        .rd_active_o ( /*Not used*/         ),
        .reg_d_i     ( reg_d.ByteMap        ),
        .reg_load_i  ( reg_load_i.LogicMap  ),
        .reg_q_o     ( reg_q.ByteMap        )
    );

    // ************************************************************************
    // Ports.
    // ************************************************************************
    for(i=0; i<NUM_COUNTER; i=i+1) begin        
        assign event_id_mask[i]  = event_sel_cfg[i].event_id_mask;
        assign event_id_val[i]   = event_sel_cfg[i].event_id_val;
        assign source_id_mask[i] = event_sel_cfg[i].source_id_mask;
        assign source_id_val[i]  = event_sel_cfg[i].source_id_val;
        assign port_id_mask[i]   = event_sel_cfg[i].port_id_mask;
        assign port_id_val[i]    = event_sel_cfg[i].port_id_val;
        assign event_info_en[i]  = event_info_cfg[i].event_info_en;
    end

    pmu_port_wrap #(
        .NUM_COUNTER        ( NUM_COUNTER       ),
        .NUM_PORT           ( NUM_PORT          )
    ) i_pmu_port_wrap (
        .clk_i              ( clk_i             ),
        .rst_ni             ( rst_ni            ),
        // PMU Event Interfaces
        .port_i             ( port_i            ),
        // Event Specifiers - Filters events for each counter.
        .event_id_mask_i    ( event_id_mask     ),
        .event_id_val_i     ( event_id_val      ),
        .source_id_mask_i   ( source_id_mask    ),
        .source_id_val_i    ( source_id_val     ),
        .port_id_mask_i     ( port_id_mask      ),
        .port_id_val_i      ( port_id_val       ),
        // `event_info_en` signal.
        .event_info_en_i    ( event_info_en     ),
        // Counter Update signals.
        .incr_val_o         ( incr_val          ),
        .event_info_ctrl_o  ( event_info_ctrl   ),
        .event_info_val_o   ( event_info_val    )
    );

    // ************************************************************************
    // Counter Interface Output Logic
    // ************************************************************************
    always_comb begin
        core_counter_rdata_d    = '0;
        core_counter_err_d      = 1'b0;
        core_counter_rvalid_d   = 1'b0;
        core_counter_gnt_d      = 1'b1;

        unique case (core_counter_op)
            apmu_ibex_pkg::PMC_REQ: begin
                // PMU core operations on the counter are never be stalled,
                // and responded to in the next clock cycle.
                core_counter_rvalid_d   = 1'b1;
                if (core_counter_addr < NUM_COUNTER) begin
                    core_counter_rdata_d    = counter_q[core_counter_addr].counter;
                    core_counter_gnt_d      = 1'b0;
                end else begin
                    core_counter_err_d      = 1'b1;
                end
            end

            apmu_ibex_pkg::PMC_WFP: begin
                for (integer j=0; j < NUM_COUNTER; j++) begin
                    if ((pending[j] && core_counter_addr[j])) begin
                        core_counter_rdata_d[j] = (pending[j] && core_counter_addr[j]);
                    end
                end
                core_counter_rvalid_d   = (|core_counter_rdata_d);
            end

            apmu_ibex_pkg::PMC_WFO: begin
                for (integer j=0; j < NUM_COUNTER; j++) begin
                    if ((overflow[j] && core_counter_addr[j])) begin
                        core_counter_rdata_d[j] = (overflow[j] && core_counter_addr[j]);
                    end
                end
                core_counter_rvalid_d   = (|core_counter_rdata_d);
            end
            
            default: ;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            core_counter_rdata_q    <= '0;
            core_counter_rvalid_q   <= 1'b0;
            core_counter_err_q      <= 1'b0;
            core_counter_gnt_q      <= 1'b0;
        end else begin
            core_counter_rdata_q    <= core_counter_rdata_d;
            core_counter_rvalid_q   <= core_counter_rvalid_d;
            core_counter_err_q      <= core_counter_err_d;
            core_counter_gnt_q      <= core_counter_gnt_d;
        end
    end

    // ************************************************************************
    // Counter Update Logic
    // ************************************************************************
    for(i=0; i<NUM_COUNTER; i=i+1) begin
        always_comb begin: gen_counter_update
            // PMC_IDLE indicates no update request from PMU core.
            per_counter_op[i]   = apmu_ibex_pkg::PMC_IDLE;

            // Only requests (from PMU core) that can update a counter are sent to pmu_counter module of that counter.
            // WFP updates the Pending bit of a specified counter. But WFO does not, hence, it is not sent to `pmu_counter`.
            if ((core_counter_op == apmu_ibex_pkg::PMC_WFP && core_counter_addr[i]) ||
                (core_counter_addr == addr_t'(i) && core_counter_op == apmu_ibex_pkg::PMC_REQ && core_counter_we)) begin
                per_counter_op[i]   = core_counter_op;
            end
        end

        pmu_counter #(
            .NUM_PORT               ( NUM_PORT                  ),
            .counter_t              ( counter_t                 ),
            .strb_counter_t         ( strb_counter_t            )
        ) i_counter (
            .clk_i                  ( clk_i                     ),
            .rst_ni                 ( rst_ni                    ),
            .axi_wr_active_i        ( axi_counter_wr_active[i]  ),
            .core_counter_op_i      ( per_counter_op[i]         ),
            .core_counter_wdata_i   ( core_counter_wdata        ),
            .event_info_cfg_i       ( event_info_cfg[i]         ),
            .incr_val_i             ( incr_val[i]               ),
            .event_info_ctrl_i      ( event_info_ctrl[i]        ),
            .event_info_val_i       ( event_info_val[i]         ),
            .axi_reg_load_o         ( axi_counter_reg_load[i]   ),
            .memguard_reset_i       ( memguard_reset            ),
            .init_budget_i          ( init_budget_reg[i]        ),                
            .counter_q_i            ( counter_q[i]              ),
            .counter_d_o            ( counter_d[i]              )   
        );
    end

    // ************************************************************************
    // Overflow Interrupt Signaling
    // ************************************************************************
    for (i=0; i<NUM_COUNTER; i=i+1) begin
        always_comb begin
            intr_d[i] = intr_q[i];
            if (event_info_cfg[i].overflow_intr_en) begin
                intr_d[i] = overflow[i];
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            intr_q  <= 0;
        end else begin
            intr_q  <= intr_d;
        end
    end

    assign intr_o = intr_q;

    // ************************************************************************
    // PMU Timer
    // ************************************************************************
    assign timer_q  = reg_q.StructMap.pmu_b.timer;
    assign period_q = reg_d.StructMap.pmu_b.period;

    always_comb begin
        timer_d         = timer_q;
        memguard_reset  = 1'b0;
        if (period_q != 0) begin   
            if (timer_d < period_q-1) begin
                timer_d         = timer_q + 1'b1;     
            end else begin
                timer_d         = '0;
                memguard_reset  = 1'b1;
            end
        end
    end

    // ************************************************************************
    // PMU Core
    // ************************************************************************
    pmu_core #(
        // PMU_REG Configuration
        .PMU_REG_START_ADDR     ( PMU_REG_START_ADDR    ),
        .PMU_REG_LENGTH         ( PMU_REG_LENGTH        ),

        // System Memory Configuration
        .MEMORY_BASE_ADDR       ( MEMORY_BASE_ADDR       ),
        .MEMORY_LENGTH          ( MEMORY_LENGTH          ),

        // ISPM Configuration
        .ISPM_BASE_ADDR         ( ISPM_BASE_ADDR       ),
        .ISPM_NumBytes          ( ISPM_NumBytes         ),
        
        // DSPM Configuration
        .DSPM_BASE_ADDR         ( DSPM_BASE_ADDR       ),
        .DSPM_NumBytes          ( DSPM_NumBytes         ),
        
        // Typedefs
        .req_lite_t             ( req_lite_t            ),
        .resp_lite_t            ( resp_lite_t           ),
        .pmc_op_e               ( apmu_ibex_pkg::pmc_op_e    )
    ) i_pmu_core (
        .clk_i                  ( clk_i                 ),
        .rst_ni                 ( rst_ni                ),

        // Counter Interface Signals
        .core_counter_op_o      ( core_counter_op       ),
        .core_counter_we_o      ( core_counter_we       ),
        .core_counter_addr_o    ( core_counter_addr     ),
        .core_counter_wdata_o   ( core_counter_wdata    ),
        .core_counter_gnt_i     ( core_counter_gnt_q    ),
        .core_counter_err_i     ( core_counter_err_q    ),
        .core_counter_rvalid_i  ( core_counter_rvalid_q ),
        .core_counter_rdata_i   ( core_counter_rdata_q  ),

        // Boot address for PMU core
        .pmc_boot_addr_i        ( pmc_boot_addr         ),

        // Stall core
        .stall_core_i           ( stall_core            ),

        .ispm_req_i             ( ispm_req              ),
        .ispm_resp_o            ( ispm_resp             ),

        .dspm_req_i             ( dspm_req              ),
        .dspm_resp_o            ( dspm_resp             ),

        .pmc_req_o              ( pmc_req               ),
        .pmc_resp_i             ( pmc_resp              )
    );

endmodule
