// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// RISC-V Platform-Level Interrupt Generator for Target
//
// This module basically doing IE & IP based on priority and threshold.
// Keep in mind that increasing MAX_PRIO affects logic size a lot.

module rv_plic_target #(
  parameter int N_SOURCE = 32,
  parameter int MAX_PRIO = 7,
  parameter     ALGORITHM = "SEQUENTIAL", // SEQUENTIAL | MATRIX

  // Local param (Do not change this through parameter
  parameter int unsigned SRCW  = $clog2(N_SOURCE+1),
  parameter int unsigned PRIOW = $clog2(MAX_PRIO+1) // Bits to represent MAX_PRIO
) (
  input clk_i,
  input rst_ni,

  input [N_SOURCE-1:0] ip,
  input [N_SOURCE-1:0] ie,

  input [N_SOURCE-1:0][PRIOW-1:0] prio,
  input [PRIOW-1:0] threshold,

  output logic            irq,
  output logic [SRCW-1:0] irq_id
);


//always_ff @(posedge clk_i, negedge rst_ni) begin
//  if (!rst_ni) begin
//    gt_th <= '0;
//  end else begin
//    for (int i = 0 ; i < N_SOURCE ; i++) begin
//      gt_th[i] = (prio[i] > threshold) ? 1'b1 : 1'b0 ;
//    end
//  end
//end


if (ALGORITHM == "SEQUENTIAL") begin : gen_sequential
  // Let first implementation be brute-force
  // As N_SOURCE increasing logic depth increases O(logN)
  // This approach slows down the simulation.
  logic [PRIOW-1:0] max_prio;
  logic irq_next;
  logic [SRCW-1:0] irq_id_next;
  always_comb begin
    max_prio = threshold + 1'b1; // Priority strictly greater than threshold
    irq_id_next = '0; // default: No Interrupt
    irq_next = 1'b0;
    for (int i = N_SOURCE-1 ; i >= 0 ; i--) begin
      if ((ip[i] & ie[i]) == 1'b1 && prio[i] >= max_prio) begin
        max_prio = prio[i];
        irq_id_next = SRCW'(i+1);
        irq_next = 1'b1;
      end
    end // for i
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      irq <= 1'b0;
      irq_id <= '0;
    end else begin
      irq <= irq_next;
      irq_id <= irq_id_next;
    end
  end
end else if (ALGORITHM == "MATRIX") begin : gen_mat
  // Second trial : N X N matrix
  // Set mat[i][j] to 1 if prio[i] >= prio[j] and ip[i] & ie[i] & ip[j] & ie[j]
  // Comparator depth is just 1 then logN AND gate then Leading One detector
  // It is to find the max value of priority
  //
  // This uses a lot of comparators: (N x (N-1))/2.
  // So if above approach(ALGORITHM 1) meets timing, don't use this algorithm.
  logic [N_SOURCE-1:0] is;

  logic [N_SOURCE-1:0][N_SOURCE-1:0] mat;
  logic [N_SOURCE-1:0] merged_row;

  assign is = ip & ie;
  always_comb begin
    merged_row[N_SOURCE-1] = is[N_SOURCE-1] & (prio[N_SOURCE-1] > threshold);
    for (int i = 0 ; i < N_SOURCE-1 ; i++) begin
      merged_row[i] = 1'b1;
      for (int j = i+1 ; j < N_SOURCE ; j++) begin
        mat[i][j] = (prio[i] <= threshold) ? 1'b0 :         // No compare if less than TH
                    (is[i] & is[j]) ? prio[i] >= prio[j] :
                    (is[i]) ? 1'b 1 : 1'b 0 ;
        merged_row[i] = merged_row[i] & mat[i][j]; // all should be 1
      end // for j
    end // for i
  end // always_comb

  // Leading One detector
  logic [N_SOURCE-1:0] lod;
  assign lod = merged_row & (~merged_row + 1'b1);
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      irq <= 1'b0;
      irq_id <= '0; // No interrupt
    end else if (|lod) begin
      // as $onehot0(lod), at most one bit set.
      // so, safely run for loop
      for (int i = N_SOURCE-1 ; i >= 0 ; i--) begin
        if (lod[i] == 1'b1) begin
          irq <= 1'b 1;
          irq_id <= SRCW'(i + 1);
        end
      end // for
    end else begin
      // No pending interrupt
      irq <= 1'b0;
      irq_id <= '0;
    end
  end // always_ff
end else if (ALGORITHM == "TREE") begin : gen_tree
  // Third implementation: a balanced binary reduction over the sources.
  // Each node keeps the candidate with the higher priority and, on a tie, the lower source index, which is
  // the choice the MATRIX implementation makes (its leading-one detector). The cost is N_SOURCE-1 compare
  // and select nodes per target, $clog2(N_SOURCE) levels deep, instead of the (N x (N-1))/2 comparators of
  // MATRIX: at 255 sources and 8 targets the matrix was 218k LUTs of a VU9P, as much as four CVA6 cores.
  // Like MATRIX, a source takes part only when its priority is strictly above the threshold (the SEQUENTIAL
  // implementation computes threshold + 1 in PRIOW bits, which wraps at MAX_PRIO).
  localparam int unsigned LVL = (N_SOURCE > 1) ? $clog2(N_SOURCE) : 1;
  localparam int unsigned NP  = 2 ** LVL;
  typedef struct packed {
    logic             valid;
    logic [PRIOW-1:0] prio;
    logic [SRCW-1:0]  id;     // source index + 1, as in the other implementations
  } cand_t;
  cand_t [NP-1:0] lvl [LVL+1];   // lvl[0]: the sources, lvl[LVL][0]: the winner

  always_comb begin
    for (int i = 0; i < NP; i++) begin
      if (i < N_SOURCE) begin
        lvl[0][i].valid = ip[i] & ie[i] & (prio[i] > threshold);
        lvl[0][i].prio  = prio[i];
        lvl[0][i].id    = SRCW'(i + 1);
      end else begin
        lvl[0][i] = '0;
      end
    end
    for (int l = 0; l < LVL; l++) begin
      for (int i = 0; i < NP; i++) begin
        if (i < (NP >> (l + 1))) begin
          // the left child holds the lower source indices and wins a tie
          if (lvl[l][2*i].valid && (!lvl[l][2*i+1].valid || lvl[l][2*i].prio >= lvl[l][2*i+1].prio))
            lvl[l+1][i] = lvl[l][2*i];
          else
            lvl[l+1][i] = lvl[l][2*i+1];
        end else begin
          lvl[l+1][i] = '0;
        end
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      irq    <= 1'b0;
      irq_id <= '0;
    end else begin
      irq    <= lvl[LVL][0].valid;
      irq_id <= lvl[LVL][0].valid ? lvl[LVL][0].id : '0;
    end
  end
end // ALGORITHM

endmodule

