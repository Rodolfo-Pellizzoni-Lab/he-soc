package pmu_pkg;

    // Event Selection Config Register
    localparam EVENT_ID_BITS                = 4; // Previous Mohammed Set
    // localparam EVENT_ID_BITS                = 5; // Emon Set
    localparam SOURCE_ID_BITS               = 4;
    localparam PORT_ID_BITS                 = 4; 
    localparam EVENT_SEL_PAD_BITS           = 8;
    localparam int unsigned EVENT_INFO_BITS = 17;

    typedef logic [EVENT_ID_BITS-1:0]   event_id_t;
    typedef logic [EVENT_INFO_BITS-1:0] event_info_t;
    typedef logic [SOURCE_ID_BITS-1:0]  source_id_t;
    typedef logic [PORT_ID_BITS-1:0]    port_id_t;

    typedef struct packed {
        logic [EVENT_SEL_PAD_BITS-1:0]  pad_field;
        port_id_t                       port_id_val;
        port_id_t                       port_id_mask;
        source_id_t                     source_id_val;
        source_id_t                     source_id_mask;
        event_id_t                      event_id_val;
        event_id_t                      event_id_mask;
    } event_sel_cfg_t;

    // Must be a multiple of 8!
    // For AXI-lite interface to work!
    localparam EVENT_SEL_CFG_WIDTH = (
                                      EVENT_ID_BITS + 
                                      SOURCE_ID_BITS + 
                                      PORT_ID_BITS
                                     )*2 + EVENT_SEL_PAD_BITS;

    // Event Info Config Register
    localparam EISF_BITS           = 5;
    localparam OPCODE_BITS         = 5;
    localparam VAL_LIMIT_BITS      = 4;
    localparam EVENT_INFO_EN       = 1;
    localparam OVERFLOW_INTR_EN    = 1;
    localparam EVENT_INFO_PAD_BITS = 7;

    typedef enum logic [OPCODE_BITS-1:0] {
        ADD                 =  0,
        KEEP_MAX            =  1,
        KEEP_MIN            =  2,
        INCR_CMP_EQ         =  3,
        INCR_CMP_NEQ        =  4,
        INCR_CMP_LT         =  5,
        INCR_CMP_GT         =  6,
        INCR_CMP_LTE        =  7,
        INCR_CMP_GTE        =  8,
        INCR_IN_RANGE       =  9,
        INCR_NOT_IN_RANGE   = 10,
        ADD_CMP_EQ          = 11,
        ADD_CMP_NEQ         = 12,
        ADD_CMP_LT          = 13,
        ADD_CMP_GT          = 14,
        ADD_CMP_LTE         = 15,
        ADD_CMP_GTE         = 16,
        ADD_IN_RANGE        = 17,
        ADD_NOT_IN_RANGE    = 18
    } opcode_e;

    // These bits are used to specify sub-field in `event_info`.
    typedef logic [EISF_BITS-1:0]      eisf_t;
    typedef logic [VAL_LIMIT_BITS-1:0] val_t;

    typedef struct packed {
        logic [EVENT_INFO_PAD_BITS-1:0] pad_field;
        logic [OVERFLOW_INTR_EN-1:0]    overflow_intr_en;
        logic [EVENT_INFO_EN-1:0]       event_info_en;
        val_t                           val_u;
        val_t                           val_l;
        opcode_e                        opcode;
        eisf_t                          eisf_end;
        eisf_t                          eisf_start; 
    } event_info_cfg_t;  

    localparam EVENT_INFO_CFG_WIDTH = 2*EISF_BITS +                                       
                                      OPCODE_BITS + 
                                      2*VAL_LIMIT_BITS + 
                                      EVENT_INFO_EN + 
                                      OVERFLOW_INTR_EN +
                                      EVENT_INFO_PAD_BITS;

    // PMU_Event_Structure
    typedef struct packed {
      event_id_t      e_id;
      event_info_t    e_info;
      source_id_t     s_id;
    } pmu_event_t;

    // AXi4-Lite Typedefs (from ariane_axi_soc_pkg)
    // localparam LiteAddrWidth = 32;
    // localparam LiteDataWidth = 32;
    // localparam LiteStrbWidth = LiteDataWidth / 8;

    // typedef logic [LiteAddrWidth-1:0] lite_addr_t;
    // typedef logic [LiteDataWidth-1:0] lite_data_t;
    // typedef logic [LiteStrbWidth-1:0] lite_strb_t;

    // typedef struct packed {        
    //   lite_addr_t     addr;   
    //   axi_pkg::prot_t prot;        
    // } aw_chan_lite_t;
    
    // typedef struct packed {        
    //   lite_data_t   data;          
    //   lite_strb_t   strb;          
    // } w_chan_lite_t;
    
    // typedef struct packed {        
    //   axi_pkg::resp_t resp;        
    // } b_chan_lite_t;
    
    // typedef struct packed {        
    //   lite_addr_t     addr;   
    //   axi_pkg::prot_t prot;        
    // } ar_chan_lite_t;
    
    // typedef struct packed {        
    //   lite_data_t     data;   
    //   axi_pkg::resp_t resp;        
    // } r_chan_lite_t;
    
    // typedef struct packed {        
    //   aw_chan_lite_t aw;           
    //   logic          aw_valid;     
    //   w_chan_lite_t  w;            
    //   logic          w_valid;      
    //   logic          b_ready;      
    //   ar_chan_lite_t ar;           
    //   logic          ar_valid;     
    //   logic          r_ready;      
    // } req_lite_t;
    
    // typedef struct packed {        
    //   logic          aw_ready;     
    //   logic          w_ready;      
    //   b_chan_lite_t  b;            
    //   logic          b_valid;      
    //   logic          ar_ready;     
    //   r_chan_lite_t  r;            
    //   logic          r_valid;      
    // } resp_lite_t;          

  // ************************************************************************
  // PMU core data port-related defines
  // ************************************************************************
  // Data target implies the different modules that the PMU core can access using its
  // data port (via Load/Store instructions).
  typedef enum logic [1:0] {
    // Idle must be mapped to `N-1`, because the other enum labels are also 
    // used as indices to the `addr_decode` in `pmu_core`.
      IDLE          = 2'd3,
      SYSTEM_MEMORY = 2'd2,
      PMU_REG       = 2'd1,
      DSPM          = 2'd0
  } pmc_data_target_e;
  localparam int unsigned VALID_PMC_DATA_TARGET = 3; 

  typedef struct packed {
    logic [31:0] idx;
    logic [31:0] start_addr;
    logic [31:0] end_addr;
  } addr_map_rule_t;

  // #ifdef SYNTH_PARAM
    localparam LiteAddrWidth = 32;
    localparam LiteDataWidth = 32;
    localparam LiteStrbWidth = LiteDataWidth / 8;

    typedef logic [LiteAddrWidth-1:0] lite_addr_t;
    typedef logic [LiteDataWidth-1:0] lite_data_t;
    typedef logic [LiteStrbWidth-1:0] lite_strb_t;

    typedef struct packed {        
      lite_addr_t     addr;   
      axi_pkg::prot_t prot;        
    } aw_chan_lite_t;
    
    typedef struct packed {        
      lite_data_t   data;          
      lite_strb_t   strb;          
    } w_chan_lite_t;
    
    typedef struct packed {        
      axi_pkg::resp_t resp;        
    } b_chan_lite_t;
    
    typedef struct packed {        
      lite_addr_t     addr;   
      axi_pkg::prot_t prot;        
    } ar_chan_lite_t;
    
    typedef struct packed {        
      lite_data_t     data;   
      axi_pkg::resp_t resp;        
    } r_chan_lite_t;

    typedef struct packed {        
      aw_chan_lite_t aw;           
      logic          aw_valid;     
      w_chan_lite_t  w;            
      logic          w_valid;      
      logic          b_ready;      
      ar_chan_lite_t ar;           
      logic          ar_valid;     
      logic          r_ready;      
    } req_lite_t;
    
    typedef struct packed {        
      logic          aw_ready;     
      logic          w_ready;      
      b_chan_lite_t  b;            
      logic          b_valid;      
      logic          ar_ready;     
      r_chan_lite_t  r;            
      logic          r_valid;      
    } resp_lite_t;
  // #endif

endpackage


