// Copyright lowRISC contributors, ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// PLIC register map, parameterised in the number of sources and targets.
//
// It replaces the module gen_plic_regmap.py had generated for 255 sources and 8 targets, which pinned the
// SoC to four harts (two PLIC contexts each). The decode is the generated one, address for address and
// port for port, for any N_SOURCE and N_TARGET; test/tb_plic_equiv.sv compares it cycle by cycle with the
// generated maps for 8 and 16 targets. Kept on purpose: a write of one 32-bit enable word drives only that
// word on ie_o (plic_top then stores all of ie_o, so the other words of that target read back as zero).
//
// Offsets from PLIC_BASE, 32-bit registers at exactly these addresses, anything else answers error:
//   0x000000 + 4*s            priority of source s, s = 0 .. N_SOURCE (source 0 is reserved and reads 0)
//   0x001000 + 4*w            pending bits, word w, w < ceil((N_SOURCE+1)/32)   (read only)
//   0x002000 + 0x80*t + 4*w   enable bits of target t, word w
//   0x200000 + 0x1000*t       threshold of target t
//   0x200004 + 0x1000*t       claim (read) / complete (write) of target t
// N_SOURCE must stay below 1024, where the priority array would run into the pending bits.
module plic_regs #(
  parameter int unsigned N_SOURCE  = 255,
  parameter int unsigned N_TARGET  = 8,
  parameter int unsigned MAX_PRIO  = 7,
  parameter logic [31:0] PLIC_BASE = 32'h0C00_0000,
  // derived, not to be overridden
  parameter int unsigned NSRC  = N_SOURCE + 1,            // bits of a pending / enable vector, source 0 included
  parameter int unsigned PRIOW = $clog2(MAX_PRIO + 1),
  parameter int unsigned SRCW  = $clog2(NSRC),
  parameter int unsigned NWORD = (NSRC + 31) / 32          // 32-bit words of a pending / enable vector
) (
  input  logic [NSRC-1:0][PRIOW-1:0]     prio_i,
  output logic [NSRC-1:0][PRIOW-1:0]     prio_o,
  output logic [NSRC-1:0]                prio_we_o,
  output logic [NSRC-1:0]                prio_re_o,
  input  logic [0:0][NSRC-1:0]           ip_i,
  output logic [0:0]                     ip_re_o,
  input  logic [N_TARGET-1:0][NSRC-1:0]  ie_i,
  output logic [N_TARGET-1:0][NSRC-1:0]  ie_o,
  output logic [N_TARGET-1:0]            ie_we_o,
  output logic [N_TARGET-1:0]            ie_re_o,
  input  logic [N_TARGET-1:0][PRIOW-1:0] threshold_i,
  output logic [N_TARGET-1:0][PRIOW-1:0] threshold_o,
  output logic [N_TARGET-1:0]            threshold_we_o,
  output logic [N_TARGET-1:0]            threshold_re_o,
  input  logic [N_TARGET-1:0][SRCW-1:0]  cc_i,
  output logic [N_TARGET-1:0][SRCW-1:0]  cc_o,
  output logic [N_TARGET-1:0]            cc_we_o,
  output logic [N_TARGET-1:0]            cc_re_o,
  // Bus Interface
  input  reg_intf::reg_intf_req_a32_d32  req_i,
  output reg_intf::reg_intf_resp_d32     resp_o
);
  localparam logic [31:0] OFF_IP  = 32'h0000_1000;
  localparam logic [31:0] OFF_IE  = 32'h0000_2000;
  localparam logic [31:0] OFF_CTX = 32'h0020_0000;

  logic [31:0]         off;                       // byte offset of the request inside the PLIC
  logic                rd, wr;
  logic                hit_prio, hit_ip, hit_ie, hit_thr, hit_cc;
  logic [31:0]         idx_prio, idx_ipw, idx_iet, idx_iew, idx_ctx;
  logic [NSRC-1:0]     ie_sel;                    // enable vector of the addressed target
  logic [NWORD*32-1:0] ip_pad, ie_pad, ie_wpad;   // vectors padded to whole words
  logic [31:0]         rdata;

  assign off = req_i.addr - PLIC_BASE;
  assign rd  = req_i.valid & ~req_i.write;
  assign wr  = req_i.valid &  req_i.write;

  assign idx_prio = off >> 2;
  assign idx_ipw  = (off - OFF_IP) >> 2;
  assign idx_iet  = (off - OFF_IE) >> 7;
  assign idx_iew  = 32'(off[6:2]);
  assign idx_ctx  = (off - OFF_CTX) >> 12;

  assign hit_prio = (off[1:0] == 2'b00) && (off < 32'(4 * NSRC));
  assign hit_ip   = (off[1:0] == 2'b00) && (off >= OFF_IP)  && (off < OFF_IP + 32'(4 * NWORD));
  assign hit_ie   = (off[1:0] == 2'b00) && (off >= OFF_IE)  && (off < OFF_IE + 32'(32'h80 * N_TARGET))
                    && (idx_iew < NWORD);
  assign hit_thr  = (off >= OFF_CTX) && (off < OFF_CTX + 32'(32'h1000 * N_TARGET)) && (off[11:0] == 12'h000);
  assign hit_cc   = (off >= OFF_CTX) && (off < OFF_CTX + 32'(32'h1000 * N_TARGET)) && (off[11:0] == 12'h004);

  assign ie_sel = (idx_iet < N_TARGET) ? ie_i[idx_iet] : '0;

  // padded views: a partial last word reads as zeros above NSRC; the written word lands at its position
  always_comb begin
    for (int b = 0; b < NWORD * 32; b++) begin
      ip_pad[b]  = (b < NSRC) ? ip_i[0][b] : 1'b0;
      ie_pad[b]  = (b < NSRC) ? ie_sel[b]  : 1'b0;
      ie_wpad[b] = ((b >> 5) == idx_iew) ? req_i.wdata[b & 31] : 1'b0;
    end
  end

  always_comb begin
    if (rd && hit_prio)     rdata = 32'(prio_i[idx_prio]);
    else if (rd && hit_ip)  rdata = ip_pad[idx_ipw*32 +: 32];
    else if (rd && hit_ie)  rdata = ie_pad[idx_iew*32 +: 32];
    else if (rd && hit_thr) rdata = 32'(threshold_i[idx_ctx]);
    else if (rd && hit_cc)  rdata = 32'(cc_i[idx_ctx]);
    else                    rdata = '0;
  end

  assign resp_o.ready = 1'b1;
  assign resp_o.rdata = rdata;
  assign resp_o.error = req_i.valid & ~(req_i.write ? (hit_prio | hit_ie | hit_thr | hit_cc)
                                                    : (hit_prio | hit_ip | hit_ie | hit_thr | hit_cc));

  for (genvar s = 0; s < NSRC; s++) begin : gen_src
    assign prio_we_o[s] = wr & hit_prio & (idx_prio == s);
    assign prio_re_o[s] = rd & hit_prio & (idx_prio == s);
    assign prio_o[s]    = (wr & hit_prio & (idx_prio == s)) ? req_i.wdata[PRIOW-1:0] : '0;
  end

  assign ip_re_o[0] = rd & hit_ip;

  for (genvar t = 0; t < N_TARGET; t++) begin : gen_tgt
    assign ie_we_o[t]        = wr & hit_ie  & (idx_iet == t);
    assign ie_re_o[t]        = rd & hit_ie  & (idx_iet == t);
    assign ie_o[t]           = (wr & hit_ie  & (idx_iet == t)) ? ie_wpad[NSRC-1:0] : '0;
    assign threshold_we_o[t] = wr & hit_thr & (idx_ctx == t);
    assign threshold_re_o[t] = rd & hit_thr & (idx_ctx == t);
    assign threshold_o[t]    = (wr & hit_thr & (idx_ctx == t)) ? req_i.wdata[PRIOW-1:0] : '0;
    assign cc_we_o[t]        = wr & hit_cc  & (idx_ctx == t);
    assign cc_re_o[t]        = rd & hit_cc  & (idx_ctx == t);
    assign cc_o[t]           = (wr & hit_cc  & (idx_ctx == t)) ? req_i.wdata[SRCW-1:0] : '0;
  end
endmodule
