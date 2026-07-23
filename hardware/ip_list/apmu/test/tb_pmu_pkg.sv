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

package tb_pmu_pkg;

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

endpackage
