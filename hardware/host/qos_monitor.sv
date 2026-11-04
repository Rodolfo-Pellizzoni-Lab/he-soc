// Simulation-only QoS tag scoreboard (hardware/docs/qos.md). One instance per observation point:
//
//   Role "core"    at core i's AXI port (cva6_synth_wrap): every new AR/AW must carry RCID / MCID = the hart's srmcfg
//                  (csr_rcid_i / csr_mcid_i) and AT = 1 exactly for instruction fetches (AR ID 4'b0000); records,
//                  per 64-byte line, the tags core i put on its requests (the last 8 per line).
//   Role "llc_in"  at the LLC slave port: every AR/AW must carry the tag its source core (user[QosUserLsb-1:0]) used for that
//                  line. A tag that another core used for the line counts as "ccu" (a write-back the CCU issues for
//                  dirty data snooped from that core carries the requester's tag); a user field of 0 that matches
//                  no core request counts as "other" (masters other than the cores tag 0). Anything else is an error.
//   Role "llc_out" at the LLC memory port: a refill (AR) must carry the user field of a recent LLC request to the same
//                  line, an eviction (AW) that of a recent request to the same set (the request that caused it). A
//                  write-back of an LLC flush has no requester and carries user field 0. The LLC announces each one
//                  (llc_flush_evict_i, its evict_flush event: one pulse per line a flush writes back) and isolates its
//                  slave port while it flushes, so while announcements are left every AW is a flush write-back: it uses
//                  one up and must carry user field 0, and if it matches no recent request it counts as "flush".
//
// At the end every instance prints "[QOS] check <name>: <n> ok ... <k> errors" and, for llc_in / llc_out, one count
// line per user value "[QOS] <name> src=.. at=.. rcid=.. mcid=.. ar=.. aw=..". The first 10 errors are printed as
// "[QOS] ERROR <name> ...". Empty for synthesis.

// pragma translate_off
`ifndef SYNTHESIS
package qos_mon_pkg;
  // Histories are 128-bit words of 8 slots x 16 bits (value + 1, 0 = empty), most recent in the low slot.
  typedef bit [127:0] hist_t;
  // core tags per (core, line): key = core << 56 | line
  hist_t core_tags [longint unsigned];
  // user fields of recent LLC requests, per line and per LLC set
  hist_t llc_line  [longint unsigned];
  hist_t llc_set   [longint unsigned];

  function automatic bit has(hist_t h, int unsigned v);
    for (int k = 0; k < 8; k++) if (h[k*16 +: 16] == 16'(v + 1)) return 1;
    return 0;
  endfunction
  function automatic hist_t push(hist_t h, int unsigned v);
    if (has(h, v)) return h;
    return (h << 16) | hist_t'(16'(v + 1));
  endfunction
endpackage
`endif
// pragma translate_on

module qos_monitor #(
  parameter string       Name     = "axi",
  parameter string       Role     = "llc_in",   // "core", "llc_in" or "llc_out"
  parameter int unsigned Core     = 0,          // role "core": the core index
  parameter int unsigned LineBits = 6,          // 64-byte LLC lines
  parameter int unsigned SetBits  = 10,         // LLC sets (ariane_soc::LLC_NUM_LINES)
  parameter type         req_t    = logic,
  parameter type         resp_t   = logic
) (
  input logic  clk_i,
  input logic  rst_ni,
  input req_t  req_i,
  input resp_t resp_i,
  // role "core": the hart's srmcfg fields
  input logic [ariane_pkg::QOS_RCID_WIDTH-1:0] csr_rcid_i = '0,
  input logic [ariane_pkg::QOS_MCID_WIDTH-1:0] csr_mcid_i = '0,
  // role "llc_out": the LLC is writing a dirty line back for a flush (its evict_flush event)
  input logic                                  llc_flush_evict_i = 1'b0
);
  // pragma translate_off
`ifndef SYNTHESIS
  import qos_mon_pkg::*;
  localparam int unsigned SrcBits = ariane_axi_soc::QosUserLsb;
  localparam int unsigned UserW   = ariane_axi_soc::UserWidth;

  int unsigned ar_n [int unsigned];
  int unsigned aw_n [int unsigned];
  int unsigned n_ok, n_ccu, n_other, n_evict, n_err;
  int unsigned n_flush, flush_pend;       // llc_out: flush write-backs that matched no recent request; flush
                                          // write-backs announced, not seen yet
  int unsigned sock_tags[int unsigned];   // llc_in: user fields seen from the CCU's DMA ports (src >= NumCVA6)

  initial begin n_ok = 0; n_ccu = 0; n_other = 0; n_evict = 0; n_err = 0; n_flush = 0; flush_pend = 0; end

  function automatic int unsigned user_of(logic [63:0] u);
    return int'(u[UserW-1:0]);
  endfunction

  // fields of a user value: source core, AT, RCID, MCID
  function automatic int unsigned f_src(int unsigned u);  return u % (1 << SrcBits); endfunction
  function automatic int unsigned f_rcid(int unsigned u); return (u >> SrcBits) % (1 << ariane_pkg::QOS_RCID_WIDTH); endfunction
  function automatic int unsigned f_mcid(int unsigned u);
    return (u >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH)) % (1 << ariane_pkg::QOS_MCID_WIDTH);
  endfunction
  function automatic int unsigned f_at(int unsigned u);
    return (u >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH + ariane_pkg::QOS_MCID_WIDTH)) % 2;
  endfunction

  // what: 0 llc_in ar, 1 llc_in aw (tag not issued by any core for this line), 2 llc_out ar (no recent LLC request
  // to this line has this user field), 3 llc_out aw (... to this line or set)
  task automatic error(int unsigned what, longint unsigned addr, int unsigned u);
    n_err++;
    if (n_err <= 10)
      $display("[QOS] ERROR %s %s addr=0x%0h src=%0d at=%0d rcid=%0d mcid=%0d: %s", Name,
               (what % 2 || what == 4) ? "aw" : "ar", addr, f_src(u), f_at(u), f_rcid(u), f_mcid(u),
               (what < 2) ? "no core issued this tag for this line" :
               (what == 4) ? "a write-back while the LLC flushes, not user field 0" :
                             "no recent LLC request with this user field");
  endtask

  task automatic observe(bit is_w, longint unsigned addr, int unsigned u);
    longint unsigned line, set, key;
    int unsigned     src, tag;
    bit              found, flush;
    hist_t           h;
    line  = addr >> LineBits;
    set   = line & ((64'd1 << SetBits) - 1);
    src   = u % (1 << SrcBits);
    tag   = u >> SrcBits;
    found = 0;
    if (is_w) aw_n[u] = aw_n.exists(u) ? aw_n[u] + 1 : 1;
    else      ar_n[u] = ar_n.exists(u) ? ar_n[u] + 1 : 1;
    if (Role == "core") begin
      key = (longint'(Core) << 56) | line;
      h   = core_tags.exists(key) ? core_tags[key] : '0;
      core_tags[key] = push(h, tag);
      n_ok++;
    end else if (Role == "llc_in") begin
      key = (longint'(src) << 56) | line;
      if (core_tags.exists(key) && has(core_tags[key], tag)) begin
        n_ok++;
        found = 1;
      end else begin
        for (int c = 0; c < (1 << SrcBits); c++) begin
          key = (longint'(c) << 56) | line;
          if (!found && core_tags.exists(key) && has(core_tags[key], tag)) found = 1;
        end
        if (found) n_ccu++;
      end
      if (!found) begin
        if (u == 0 || src >= ariane_soc::NumCVA6) n_other++;   // not from a core: a DMA port of the CCU
        if (src >= ariane_soc::NumCVA6) sock_tags[u] = sock_tags.exists(u) ? sock_tags[u] + 1 : 1;
        else                                       error(is_w ? 1 : 0, addr, u);
      end
      h = llc_line.exists(line) ? llc_line[line] : '0;
      llc_line[line] = push(h, u);
      h = llc_set.exists(set) ? llc_set[set] : '0;
      llc_set[set] = push(h, u);
    end else begin
      flush = is_w && flush_pend > 0;
      if (flush) flush_pend--;
      if (flush && u != 0) error(4, addr, u);
      else if (llc_line.exists(line) && has(llc_line[line], u)) n_ok++;
      else if (is_w && llc_set.exists(set) && has(llc_set[set], u)) n_evict++;
      else if (flush) n_flush++;
      else error(is_w ? 3 : 2, addr, u);
    end
  endtask

  // role "core": a request is new in the first cycle its valid is high (the tag is then taken from srmcfg)
  logic ar_pending_q, aw_pending_q;
  initial begin ar_pending_q = 0; aw_pending_q = 0; end
  typedef struct { bit is_w; longint unsigned addr; int unsigned u; } obs_t;
  obs_t deferred[$];   // role "llc_out": requests sampled in the previous cycle
  task automatic check_csr(bit is_w, int unsigned u, bit fetch);
    if (f_rcid(u) != csr_rcid_i || f_mcid(u) != csr_mcid_i || f_at(u) != fetch) begin
      n_err++;
      if (n_err <= 10)
        $display("[QOS] ERROR %s%0d %s src=%0d at=%0d rcid=%0d mcid=%0d: srmcfg has rcid=%0d mcid=%0d, at should be %0d",
                 Name, Core, is_w ? "aw" : "ar", f_src(u), f_at(u), f_rcid(u), f_mcid(u), csr_rcid_i, csr_mcid_i,
                 fetch);
    end
  endtask

  always @(posedge clk_i) begin
    if (rst_ni && Role == "core") begin
      if (req_i.ar_valid && !ar_pending_q) check_csr(1'b0, user_of(64'(req_i.ar.user)), req_i.ar.id[3:2] == 2'b00);
      if (req_i.aw_valid && !aw_pending_q) check_csr(1'b1, user_of(64'(req_i.aw.user)), 1'b0);
      ar_pending_q <= req_i.ar_valid && !resp_i.ar_ready;
      aw_pending_q <= req_i.aw_valid && !resp_i.aw_ready;
    end
    if (rst_ni) begin
      if (Role == "llc_out") begin
        if (llc_flush_evict_i) flush_pend++;
        // the LLC's bypass path has no register: a bypassed request is at the output in the cycle it enters, and
        // this instance may sample it before the "llc_in" instance has recorded it. Check output requests one
        // cycle later.
        while (deferred.size() > 0) begin
          obs_t o;
          o = deferred.pop_front();
          observe(o.is_w, o.addr, o.u);
        end
        if (req_i.ar_valid && resp_i.ar_ready) deferred.push_back('{1'b0, longint'(req_i.ar.addr), user_of(64'(req_i.ar.user))});
        if (req_i.aw_valid && resp_i.aw_ready) deferred.push_back('{1'b1, longint'(req_i.aw.addr), user_of(64'(req_i.aw.user))});
      end else begin
        if (req_i.ar_valid && resp_i.ar_ready) observe(1'b0, longint'(req_i.ar.addr), user_of(64'(req_i.ar.user)));
        if (req_i.aw_valid && resp_i.aw_ready) observe(1'b1, longint'(req_i.aw.addr), user_of(64'(req_i.aw.user)));
      end
    end else flush_pend = 0;   // a reset drops a flush write-back the LLC has announced
  end

  final begin
    int unsigned keys [int unsigned];
    if (Role != "core") begin
      foreach (ar_n[u]) keys[u] = 1;
      foreach (aw_n[u]) keys[u] = 1;
      foreach (keys[k]) begin   // fields decoded inline: with several function calls on a foreach index in one
                                // statement, xsim returns 0 from all but the first (hardware/xsim/README.md)
        int unsigned u, u_src, u_rcid, u_mcid, u_at;
        u      = k;
        u_src  = u % (1 << SrcBits);
        u_rcid = (u >> SrcBits) % (1 << ariane_pkg::QOS_RCID_WIDTH);
        u_mcid = (u >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH)) % (1 << ariane_pkg::QOS_MCID_WIDTH);
        u_at   = (u >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH + ariane_pkg::QOS_MCID_WIDTH)) % 2;
        $display("[QOS] %s src=%0d at=%0d rcid=%0d mcid=%0d ar=%0d aw=%0d", Name, u_src, u_at, u_rcid, u_mcid,
                 ar_n.exists(u) ? ar_n[u] : 0, aw_n.exists(u) ? aw_n[u] : 0);
      end
    end
    if (Role == "core")
      $display("[QOS] check %s%0d: %0d requests, %0d errors%s", Name, Core, n_ok, n_err, n_err ? " ERROR" : "");
    else if (Role == "llc_in") begin
      $display("[QOS] check %s: %0d ok, %0d ccu, %0d other, %0d errors%s", Name, n_ok, n_ccu, n_other, n_err,
               n_err ? " ERROR" : "");
      foreach (sock_tags[k]) begin   // fields decoded inline, as above
        int unsigned kk, k_src, k_rcid, k_mcid, k_at;
        kk     = k;
        k_src  = kk % (1 << SrcBits);
        k_rcid = (kk >> SrcBits) % (1 << ariane_pkg::QOS_RCID_WIDTH);
        k_mcid = (kk >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH)) % (1 << ariane_pkg::QOS_MCID_WIDTH);
        k_at   = (kk >> (SrcBits + ariane_pkg::QOS_RCID_WIDTH + ariane_pkg::QOS_MCID_WIDTH)) % 2;
        $display("[QOS] %s socket user=0x%0h src=%0d rcid=%0d mcid=%0d at=%0d: %0d requests", Name, kk, k_src, k_rcid, k_mcid, k_at, sock_tags[k]);
      end
    end else if (n_flush == 0)
      $display("[QOS] check %s: %0d ok, %0d evict, %0d errors%s", Name, n_ok, n_evict, n_err, n_err ? " ERROR" : "");
    else
      $display("[QOS] check %s: %0d ok, %0d evict, %0d flush, %0d errors%s", Name, n_ok, n_evict, n_flush, n_err,
               n_err ? " ERROR" : "");
  end
`endif
  // pragma translate_on
endmodule
