// t_wbrace: do stores survive when the LLC writes a line back and reads it again at once? (hardware/docs/qos.md,
// "Write-backs and their write responses"; axi_llc_w_master with QOS_LLC_WBPEND > 0 does not wait for the write
// response of a write-back before the next miss goes to the memory, except for a refill of that same line.)
//
// Every core hammers its own NL lines, 64 KB apart: one LLC set and four L1 sets, with far more lines than its LLC
// ways (the capacity controller leaves each core one or two ways) and than the L1's eight. Each access misses the L1;
// the L1 line it pushes out is written back to the LLC, which has usually dropped that line already, so the LLC
// reads the line back from the memory (16 of its 64 bytes are being written), and to make room writes another dirty
// line of the same set back: lines go to the memory and are asked for again within a few accesses. A refill that
// reached the memory before the write-back of its line was answered would bring back old words in the other 48
// bytes of the line.
// One op: a word of a line, picked at random, is either rewritten with a new version or read and compared with the
// version it must have (versions are kept in the on-chip SRAM, which no cache sees). Phases:
//   A  DRAM timing model off, no regulation
//   B  the model with a long write latency (the write response of a write-back comes LAT_WR cycles later): many
//      write-backs are unanswered when their line is asked for again
//   C  as B with the bandwidth controller on and one core's RCID hard-limited: its misses park in the controller,
//      the others' pass them
//   D  the model with a slow data bus (reads and writes queue for it)
//   E  ping-pong, the worst case, with the long write latency: each core walks round as many lines of its LLC set
//      as it has ways, plus one, so every access pushes out the line the next access but one asks for; between two
//      accesses it reads twelve lines of the same L1 set that sit in other LLC sets (and stay in the LLC), so the L1
//      has dropped the line by then and its dirty piece is back in the LLC. Every miss then refills a line whose
//      write-back went out a few hundred cycles earlier and is not answered yet.
//   F  ping-pong with the model off, then a flush;  on the board also G (as E with one core hard-limited, then a
//      flush) and H (ping-pong with the slow data bus)
//   S  owners and evictors, the case the phases above cannot make: with the model a core's own read waits behind
//      the write-back it caused, so that core never asks for the line again before the write is answered. Here all
//      cores share one RCID with two LLC ways and one LLC set. Cores 1 and 2 each own one hot line: they rewrite or
//      check a word of it and then read twelve lines of the same L1 set that stay in the LLC, so the hot line's
//      dirty piece goes back to the LLC, and they come round again every few hundred cycles without needing the
//      memory. Cores 0 and 3 walk eighteen lines each in the hot lines' LLC set: every miss of theirs pushes a line
//      out, often a hot one, dirty. Its owner asks for it again at once, while the write-back is unanswered.
//      (S: write latency 800; T: the model off)
// After each phase every core checks every word of its lines; after C the whole LLC is flushed first (the flush must
// not be reported before the memory has everything), so that check reads every line back from the memory.
// Pass: no word ever differs.
#include "soc_test.h"

#define BC          0x10401C00UL
#define BC_ALLOC    0x18
#define BC_BW       0x20
#define BC_CTRL     0x80
#define BC_PERIOD   0x88
#define BC_CAPACITY 0x90
#define CC          0x10401800UL
#define CC_ALLOC    0x18
#define CC_MASK     0x20
#define DM          0x1A106100UL
#define LLC_FLUSH   0x10401008UL
#define NL          24
#define NW          8
#ifdef FPGA_EMULATION
#define PH_CYCLES   250000000ULL                  // 5 s per phase at 50 MHz
#define LAT_WR      800
#else
#define PH_CYCLES   110000ULL
#define LAT_WR      200
#endif
#define LINE(c, k)  (0x80400000UL + (uintptr_t)(c) * 0x40UL + (uintptr_t)(k) * 0x10000UL)

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

enum { IDLE = 0, RUN = 1, SWEEP = 2, PING = 3, SHARE = 4, SSWEEP = 5 };
// phase S: lines of LLC set 4 (64 KB apart), all under RCID S_RCID
#define S_RCID      5
#define SLINE(j)    (0x80400100UL + (uintptr_t)(j) * 0x10000UL)
#define SFILL(j, i, w) (SLINE(j) + 0x800UL * (uintptr_t)(i) + 8 * (uintptr_t)(w))        // same L1 set, LLC set 4 + 32 i
#define S_NL        40                            // line 1, 2: the owners' (cores 1, 2); 3-20: core 0; 21-38: core 3
                                                  // (eighteen each: far more than the L1's eight ways)
#define NFILL       12                            // L1 fillers: more than the L1's 8 ways
#define FILL(c, i, w) (LINE(c, 0) + 0x800UL * (uintptr_t)(i) + 8 * (uintptr_t)(w))   // same L1 set, LLC set c + 32 i
static const unsigned char ways_of[4] = { 2, 1, 1, 2 };
SOC_SRAM static volatile uint32_t mode[4], ack[4];
SOC_SRAM static volatile uint32_t ver[4][NL][NW];
SOC_SRAM static volatile uint32_t sver[S_NL][NW];
SOC_SRAM static volatile uint64_t n_ops[4], n_err[4], bad_addr[4], bad_got[4], bad_exp[4];

static inline uint64_t rd64(uintptr_t a) { return (uint64_t)REG32(a + 4) << 32 | REG32(a); }
static inline void wr64(uintptr_t a, uint64_t v) { REG32(a + 4) = (uint32_t)(v >> 32); REG32(a) = (uint32_t)v; }
static void set_bc(unsigned rcid, unsigned rbwb, unsigned mw) {
  wr64(BC + BC_BW, (uint64_t)mw << 20 | rbwb);
  wr64(BC + BC_ALLOC, (uint64_t)rcid << 8 | 1);
  CHECK(((rd64(BC + BC_ALLOC) >> 32) & 0x7F) == 1, "bandwidth CONFIG_LIMIT RCID %d failed", rcid);
}
static void set_cc(unsigned rcid, uint32_t mask) {
  for (unsigned at = 0; at < 2; at++) {
    REG32(CC + CC_MASK) = mask;
    REG32(CC + CC_ALLOC) = 1 | (at << 5) | (rcid << 8);
    CHECK((REG32(CC + CC_ALLOC + 4) & 0x7F) == 1, "capacity CONFIG_LIMIT RCID %d AT %d failed", rcid, at);
  }
}
static inline uint64_t word_of(int c, unsigned k, unsigned w, uint32_t v) {
  return (uint64_t)(0xC0DE0000u | (unsigned)c << 12 | k << 4 | w) << 32 | v;
}
static void bad(int c, uintptr_t a, uint64_t got, uint64_t exp) {
  if (n_err[c]++ == 0) { bad_addr[c] = a; bad_got[c] = got; bad_exp[c] = exp; }
}
// every word of the core's lines against its version
static void sweep(int c) {
  for (unsigned k = 0; k < NL; k++)
    for (unsigned w = 0; w < NW; w++) {
      volatile uint64_t *p = (volatile uint64_t *)(LINE(c, k) + 8 * w);
      uint64_t got = *p, exp = word_of(c, k, w, ver[c][k][w]);
      if (got != exp) bad(c, (uintptr_t)p, got, exp);
    }
}
// ops until `until` says stop
static void hammer(int c, uint64_t t_end) {
  uint64_t x = 0x9E3779B97F4A7C15ULL * (uint64_t)(c + 1), n = 0;
  for (;;) {
    if ((n & 7) == 0) {                            // the SRAM is slow: look at the clock or the mode every 8 ops
      if (c == 0) { if (soc_cycles() >= t_end) break; }
      else if (mode[c] != RUN) break;
    }
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;       // xorshift64
    unsigned k = (unsigned)(x >> 8) % NL, w = (unsigned)(x >> 20) % NW;
    volatile uint64_t *p = (volatile uint64_t *)(LINE(c, k) + 8 * w);
    uint32_t v = ver[c][k][w];
    if ((x >> 40) & 1) {
      uint64_t got = *p, exp = word_of(c, k, w, v);
      if (got != exp) bad(c, (uintptr_t)p, got, exp);
    } else {
      *p = word_of(c, k, w, v + 1);
      ver[c][k][w] = v + 1;
    }
    n++;
  }
  n_ops[c] += n;
}
// ping-pong: line 0 .. ways of the core's LLC set in turn, the L1 emptied of the line in between
static void pingpong(int c, uint64_t t_end) {
  uint64_t x = 0xD1B54A32D192ED03ULL * (uint64_t)(c + 1), n = 0, s = 0;
  unsigned g = ways_of[c] + 1u;
  for (;;) {
    if (c == 0) { if (soc_cycles() >= t_end) break; }
    else if (mode[c] != PING) break;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    unsigned k = (unsigned)(n % g), w = (unsigned)(x >> 20) % NW;
    volatile uint64_t *p = (volatile uint64_t *)(LINE(c, k) + 8 * w);
    uint32_t v = ver[c][k][w];
    if (((x >> 40) & 3) == 0) {
      uint64_t got = *p, exp = word_of(c, k, w, v);
      if (got != exp) bad(c, (uintptr_t)p, got, exp);
    } else {
      *p = word_of(c, k, w, v + 1);
      ver[c][k][w] = v + 1;
    }
    for (unsigned i = 1; i <= NFILL; i++) s += *(volatile uint64_t *)FILL(c, i, w);
    n++;
  }
  __asm__ volatile("" :: "r"(s));
  n_ops[c] += n;
}
// phase S: an op on a word of line j (its owner only), a new version or a check
static inline void s_op(int c, unsigned j, unsigned w, int store) {
  volatile uint64_t *p = (volatile uint64_t *)(SLINE(j) + 8 * w);
  uint32_t v = sver[j][w];
  if (store) { *p = word_of(7, j, w, v + 1); sver[j][w] = v + 1; }
  else { uint64_t got = *p, exp = word_of(7, j, w, v); if (got != exp) bad(c, (uintptr_t)p, got, exp); }
}
static void s_lines(int c, unsigned *lo, unsigned *hi) {
  if (c == 1 || c == 2) { *lo = (unsigned)c; *hi = (unsigned)c; }
  else if (c == 0) { *lo = 3; *hi = 20; }
  else { *lo = 21; *hi = 38; }
}
static void s_sweep(int c) {
  unsigned lo, hi;
  s_lines(c, &lo, &hi);
  for (unsigned j = lo; j <= hi; j++) for (unsigned w = 0; w < NW; w++) s_op(c, j, w, 0);
}
static void share(int c, uint64_t t_end) {
  uint64_t x = 0xA24BAED4963EE407ULL * (uint64_t)(c + 1), n = 0, s = 0;
  unsigned lo, hi;
  s_lines(c, &lo, &hi);
  for (;;) {
    if (c == 0) { if (soc_cycles() >= t_end) break; }
    else if (mode[c] != SHARE) break;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    unsigned w = (unsigned)(x >> 20) % NW;
    if (lo == hi) {                                // an owner: its hot line, then the L1 emptied of it
      s_op(c, lo, w, ((x >> 40) & 3) != 0);
      for (unsigned i = 1; i <= NFILL; i++) s += *(volatile uint64_t *)SFILL(lo, i, w);
    } else {                                       // an evictor: the next of its lines of the set
      s_op(c, lo + (unsigned)(n % (hi - lo + 1)), w, ((x >> 40) & 1) != 0);
    }
    n++;
  }
  __asm__ volatile("" :: "r"(s));
  n_ops[c] += n;
}
static void worker(int c) {
  SRMCFG_W((uint64_t)(c + 1) << 16 | (unsigned)(c + 1));
  for (;;) {
    uint32_t m = mode[c];
    // (the ack is written on the way in: on the way out it would overwrite a later one that core 0 already saw)
    if (m == RUN) { ack[c] = RUN; hammer(c, 0); }
    else if (m == PING) { ack[c] = PING; pingpong(c, 0); }
    else if (m == SHARE) { ack[c] = SHARE; SRMCFG_W((uint64_t)S_RCID << 16 | S_RCID); share(c, 0); }
    else if (m == SSWEEP && ack[c] != SSWEEP) { s_sweep(c); SRMCFG_W((uint64_t)(c + 1) << 16 | (unsigned)(c + 1)); ack[c] = SSWEEP; }
    else if (m == SWEEP && ack[c] != SWEEP) { sweep(c); ack[c] = SWEEP; }
    else if (m == IDLE) { ack[c] = IDLE; for (int i = 0; i < 64; i++) __asm__ volatile("nop"); }
  }
}
int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 0) return 0;
  if (cid < 4) worker(cid);
  for (;;) __asm__ volatile("wfi");
}
static void all(uint32_t m) {
  for (int c = 1; c < 4; c++) mode[c] = m;
  for (int c = 1; c < 4; c++) { uint64_t t0 = soc_cycles(); while (ack[c] != m && soc_cycles() - t0 < 40 * PH_CYCLES) ; CHECK(ack[c] == m, "core %d did not reach mode %d", c, m); }
}
static void model(unsigned lat_rd, unsigned lat_wr, unsigned occ16) {
  if (occ16 || lat_rd || lat_wr) { REG32(DM + 4) = lat_rd; REG32(DM + 8) = lat_wr; REG32(DM + 12) = occ16; REG32(DM) = 3; }
  else REG32(DM) = 0;
}
static void phase(const char *name, int flush, uint32_t how) {
  uint64_t o0[4], e0 = 0, e1 = 0;
  for (int c = 0; c < 4; c++) { o0[c] = n_ops[c]; e0 += n_err[c]; }
  uint32_t w0 = REG32(DM + 0x14);
  all(IDLE);
  for (int c = 1; c < 4; c++) mode[c] = how;
  if (how == SHARE) { SRMCFG_W((uint64_t)S_RCID << 16 | S_RCID); share(0, soc_cycles() + PH_CYCLES); }
  else if (how == PING) pingpong(0, soc_cycles() + PH_CYCLES);
  else hammer(0, soc_cycles() + PH_CYCLES);
  all(IDLE);
  uint32_t w1 = REG32(DM + 0x14);
  if (flush) {                                     // every way of the LLC to the memory, then read everything back
    REG32(LLC_FLUSH) = 0xFFFF;
    uint64_t t0 = soc_cycles();
    while (REG32(LLC_FLUSH) != 0 && soc_cycles() - t0 < 2000000000ULL) ;
    CHECK(REG32(LLC_FLUSH) == 0, "the LLC flush did not finish");
  }
  if (how == SHARE) { all(SSWEEP); s_sweep(0); SRMCFG_W((uint64_t)1 << 16 | 1); all(IDLE); }
  else { all(SWEEP); sweep(0); all(IDLE); }
  for (int c = 0; c < 4; c++) e1 += n_err[c];
  printf("  %s: ops %d / %d / %d / %d (cores 0-3)%s, write bursts at the memory %d, mismatches %d\r\n", name,
         (int)(n_ops[0] - o0[0]), (int)(n_ops[1] - o0[1]), (int)(n_ops[2] - o0[2]), (int)(n_ops[3] - o0[3]),
         flush ? ", LLC flushed before the check" : "", (int)(w1 - w0), (int)(e1 - e0));
  uart_wait_tx_done();
}

int main(void) {
  soc_test_begin("t_wbrace");
  REG32(BC + BC_CTRL) = 0;
  // one or two LLC ways per core; everything else keeps the other ways
  set_cc(1, 0x0003); set_cc(2, 0x0004); set_cc(3, 0x0008); set_cc(4, 0x0030); set_cc(0, 0xFC00);
  set_cc(S_RCID, 0x0300);                          // phase S: every core, two ways
  for (int c = 0; c < 4; c++) for (unsigned k = 0; k < NL; k++) for (unsigned w = 0; w < NW; w++) ver[c][k][w] = 0;
  for (unsigned j = 0; j < S_NL; j++) for (unsigned w = 0; w < NW; w++) sver[j][w] = 0;
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);
  SRMCFG_W((uint64_t)1 << 16 | 1);
  // every word gets its version 0 (each core its own lines, under its own RCID)
  for (int c = 0; c < 4; c++) for (unsigned k = 0; k < NL; k++) for (unsigned w = 0; w < NW; w++)
    *(volatile uint64_t *)(LINE(c, k) + 8 * w) = word_of(c, k, w, 0);
  for (unsigned j = 0; j < S_NL; j++) for (unsigned w = 0; w < NW; w++)
    *(volatile uint64_t *)(SLINE(j) + 8 * w) = word_of(7, j, w, 0);
  all(SWEEP); sweep(0); all(IDLE);

  model(1, 800, 16);
  phase("S owners and evictors, write latency 800", 0, SHARE);
  model(0, 0, 0);
  phase("T owners and evictors, model off", 1, SHARE);
#ifndef WBRACE_SHARE_ONLY
#ifndef WBRACE_PING_ONLY
  model(0, 0, 0);
  phase("A model off", 0, RUN);
  model(1, LAT_WR, 16);
  phase("B long write latency", 0, RUN);
  REG32(BC + BC_PERIOD) = 12800; REG32(BC + BC_CAPACITY) = 60 * 64;
  set_bc(0, 1, 255); set_bc(1, 1, 255); set_bc(2, 1, 255); set_bc(3, 1, 255); set_bc(4, 100, 0);   // core 3: hard limit
  REG32(BC + BC_CTRL) = 3;
  phase("C long write latency, core 3 hard-limited", 1, RUN);
  REG32(BC + BC_CTRL) = 0; set_bc(4, 1, 255);
  model(100, 100, 320);
  phase("D slow data bus", 0, RUN);
#endif
  model(1, 800, 16);
  phase("E ping-pong, write latency 800", 0, PING);
  model(0, 0, 0);
  phase("F ping-pong, model off", 1, PING);
#ifdef FPGA_EMULATION                             // the board has the time for two more
  model(1, 800, 16);
  REG32(BC + BC_PERIOD) = 12800; REG32(BC + BC_CAPACITY) = 60 * 64;
  set_bc(0, 1, 255); set_bc(1, 1, 255); set_bc(2, 1, 255); set_bc(3, 1, 255); set_bc(4, 100, 0);
  REG32(BC + BC_CTRL) = 3;
  phase("G ping-pong, write latency 800, core 3 hard-limited", 1, PING);
  REG32(BC + BC_CTRL) = 0; set_bc(4, 1, 255);
  model(100, 100, 320);
  phase("H ping-pong, slow data bus", 0, PING);
  model(0, 0, 0);
#endif
#endif

  uint64_t e = 0, n = 0;
  for (int c = 0; c < 4; c++) { e += n_err[c]; n += n_ops[c]; }
  for (int c = 0; c < 4; c++)
    if (n_err[c]) printf("  core %d: %d mismatches, the first at %x: read %x_%x, expected %x_%x\r\n", c, (int)n_err[c],
                         (unsigned)bad_addr[c], (unsigned)(bad_got[c] >> 32), (unsigned)bad_got[c],
                         (unsigned)(bad_exp[c] >> 32), (unsigned)bad_exp[c]);
  CHECK(e == 0, "%d words differ from what was stored", (int)e);
  CHECK(n > 0, "no op ran");
  for (unsigned rc = 0; rc < 6; rc++) set_cc(rc, 0xFFFF);
  SRMCFG_W(0);
  return soc_test_end();
}
