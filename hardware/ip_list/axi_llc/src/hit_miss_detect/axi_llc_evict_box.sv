// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// Date:   06.06.2019

/// Determines from the valid and spm lock signals, on which way the eviction
/// operation should be performed on, also tells us if we should write back the
/// data located at the old tag to the memory. It uses a counter which
/// advances every clock cycle for pseudo randomness as eviction strategy.
module axi_llc_evict_box #(
  /// Static configuration parameters of the LLC.
  parameter axi_llc_pkg::llc_cfg_t Cfg = axi_llc_pkg::llc_cfg_t'{default: '0},
  /// Way indicator type. This segnal has the width equal to the set-associativity.
  parameter type way_ind_t = logic,
  /// Store res type. Signal is used to determine the hit, way_ind from tag_store unit
  parameter type store_res_t = logic
) (
  /// Clock, positive edge triggered.
  input  logic clk_i,
  /// Asynchronous reset, active low.
  input  logic rst_ni,
  /// Request to the eviction unit, has to be high so that valid is eventually set.
  input  logic evict_i,
  /// Request to Hit logic of PLRU Unit, has to be high to set the PLRU Bits in Hit.
  input logic hit_i,
  ///
  input logic bist_i,
  /// Res_indicator signal to determine the hit way inside the index
  input  way_ind_t   res_indicator,
  /// All valid tags as input. This indicates if there are still free ways for putting in data.
  input  way_ind_t tag_valid_i,
  /// All dirty flags as input. This indicates us if we have to write back the data.
  input  way_ind_t tag_dirty_i,
  /// All total_locked ways. So that the output indicator does not point to a Locked way.
  input  way_ind_t total_lock_i,
  /// Ram Index for the update in PLRU Unit
  input logic [Cfg.IndexLength-1:0] ram_index,
  /// Way indicator for action to be performed. Is a onehot signal.
  output way_ind_t way_ind_o,
  /// Evict the line.
  output logic evict_o,
  /// Output is valid. This signal will eventually go to high if `evict_i` is 1.
  output logic valid_o,
  /// Valid Hit after Updation
  output logic valid_o_plru,
  
  /// Inputs/OUTPUTS for MEMORY BIST
  /// BIST activation (from tag_store unit)
  input logic plru_gen_valid,
  /// BIST Ready for DATA
  output logic plru_gen_ready,
  /// BIST result (reg)output (For Memory fault test)
  output way_ind_t plru_bist_res_o,
  /// BIST End signal
  output logic plru_gen_eoc
);

  `include "common_cells/registers.svh"

  if (Cfg.SetAssociativity > 32'd1) begin : gen_plru	
 	
    axi_llc_plru #(
      .Cfg            ( Cfg           ),
      .way_ind_t      ( way_ind_t     ),
      .store_res_t    ( store_res_t   )
    )i_plru_gen (
      .clk_i,
      .rst_ni,
      .ram_index      ( ram_index     ),
      .total_lock     ( total_lock_i  ),
      .tag_valid_i    ( tag_valid_i   ),
      .tag_dirty_i    ( tag_dirty_i   ),
      .evict_i        ( evict_i       ),
      .hit_i          ( hit_i         ),
      .bist_i         ( bist_i        ),
      .res_indicator  ( res_indicator ), 
      .out_way_ind    ( way_ind_o     ),
      .valid_o	       ( valid_o       ),
      .evict_o        ( evict_o       ),
      .valid_o_plru   ( valid_o_plru  ),
      
      // INPUTS/OUTPUTS FOR BIST OPERATIONS
      .plru_gen_valid  ( plru_gen_valid  ),
      .plru_gen_ready  ( plru_gen_ready  ),
      .plru_bist_res_o ( plru_bist_res_o ),
      .plru_gen_eoc    ( plru_gen_eoc    )
    );
       
  end else begin : gen_no_plru

    always_comb begin    
      way_ind_o       = 0;
      valid_o         = 0;
      evict_o         = 0;
      valid_o_plru    = 0;
      plru_gen_ready  = 1;
      plru_gen_eoc    = 1;
      plru_bist_res_o = '0;

      if (evict_i) begin
        way_ind_o = 1'b1;
  	    valid_o = 1;
        if (tag_dirty_i)
          evict_o = 1'b1;
        else 
          evict_o = 1'b0;
      end
      if (hit_i)
        valid_o_plru = 1'b1;   
    end

  end
  

  // check if the output really is onehot
  // pragma translate_off
  `ifndef VERILATOR
  check_onehot_out_way: assert property ( @(posedge clk_i) disable iff (~rst_ni) $onehot0(way_ind_o)) else
      $fatal(1, "More than two bit set in the one-hot signal");
  check_onehot_Set_Asso: assert property ( @(posedge clk_i) disable iff (~rst_ni) $onehot0(Cfg.SetAssociativity)) else
      $fatal(1, "Set Associativity not compatible with PLRU replacement policy");    
  `endif
  // pragma translate_on
endmodule
