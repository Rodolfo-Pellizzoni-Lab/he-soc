// t_bcw: abuse of the LLC bandwidth controller's weak spot, write ordering (hardware/docs/qos.md, "Memory bandwidth
// controller"). The LLC's write unit takes W beats in arrival order, so the LLC keeps every write in order and the
// controller's pool must too: a parked write of a throttled RCID holds every later write, of any RCID. Priority
// inheritance releases it when a write of an RCID inside its reservation waits behind it (charged to its owner).
// This test measures what that costs: it reports, and checks only what must hold either way.
//
// Writes reach the LLC as L1 write-backs (CVA6's L1 is write-back, 16-byte lines, 8 ways x 128 sets): a store to a line
// the L1 lacks reads it (a ReadUnique: an LLC read), and when the L1 set is full the miss handler first writes back
// its dirty victim (an LLC write). All workers store to lines 2 KB or 64 KB apart, one L1 set, so after eight stores
// every store writes one line back. A fence after each store makes an op's time include its write-back and refill.
//   aggressor  core 1, RCID 1: Rbwb 1 block, Mweight 0 (a hard limit, about one release per period), one LLC way
//              (capacity controller mask 0x0001). 64 lines 64 KB apart (one LLC set): each write-back finds its line
//              already replaced in the aggressor's one way, an LLC write miss, parked until its next release.
//              Its L1 set is filled with dirty lines unthrottled before each window.
//   hot        core 2, RCID 2: Rbwb 1 block, Mweight 64. 64 lines 2 KB apart that stay in the LLC: its write-backs
//              hit and cost no bandwidth, so the RCID stays inside its reservation (used 0) and its waiting
//              writes make the aggressor's parked writes inherit: the leak.
//   cold       core 3, RCID 3: Rbwb 1 block, Mweight 64. 2048 lines 2 KB apart (4 MB, 64 per LLC set used): every
//              store's refill misses the LLC, so the RCID is past its 1-block reservation and its write-backs wait
//              behind the aggressor's parked write without inheriting: the stall.
// The controller hands out 45 lines per 12800-cycle period, regulation and pacing on, the memory fast.
//   A  hot and cold, no aggressor                                   (baseline)
//   B  hot and cold next to the hard-limited aggressor
//   C  as B, the aggressor with Mweight 16 instead of a hard limit  (for comparison)
//   D  hot and cold load instead of store, aggressor hard-limited   (reads are not ordered: control)
//   E  the aggressor alone, hard-limited                            (its limit: about one release per period)
//   F  cold next to the aggressor, hot idle                         (the stall with no one to inherit)
//   G  hot next to the aggressor, cold idle                         (the leak)
// Per case: ops per core, the longest op, DRAM reads and writes per core (APMU, memory-port SPU per source), the
// pool's high-water mark and cycles full.
#include "soc_test.h"

#define BC          0x10401C00UL
#define BC_ALLOC    0x18
#define BC_BW       0x20
#define BC_CTRL     0x80
#define BC_PERIOD   0x88
#define BC_CAPACITY 0x90
#define BC_POOL     0x98
#define BC_FULL     0xA0
#define CC          0x10401800UL                   // LLC CBQRI capacity controller
#define CC_ALLOC    0x18
#define CC_MASK     0x20
#define LINE        64
#define PERIOD      12800
#define CAP_LINES   45
#define WINDOW      (4 * PERIOD)
#define AGG_BASE    0x80400000UL                  // 64 lines 64 KB apart (LLC set 0, L1 set 0)
#define AGG_STRIDE  0x10000UL
#define AGG_LINES   64
#define HOT_BASE    0x80100800UL                  // 64 lines 2 KB apart (offset 0x800 in its 64 KB: never an aggressor line)
#define COLD_BASE   0x80100400UL                  // 2048 lines 2 KB apart (offset 0x400)
#define V_STRIDE    0x800UL
#define HOT_LINES   64
#define COLD_LINES  2048
#define CTR0        4

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

enum { IDLE = 0, STORE = 1, LOAD = 2 };
SOC_SRAM static volatile uint32_t mode[4];
SOC_SRAM static volatile uint64_t prog[4], maxlat[4];

static inline uint64_t rd64(uintptr_t a) { return (uint64_t)REG32(a + 4) << 32 | REG32(a); }
static inline void wr64(uintptr_t a, uint64_t v) { REG32(a + 4) = (uint32_t)(v >> 32); REG32(a) = (uint32_t)v; }
static unsigned bc_limit(unsigned rcid, unsigned rbwb, unsigned mw) {
  wr64(BC + BC_BW, (uint64_t)mw << 20 | rbwb);
  wr64(BC + BC_ALLOC, (uint64_t)rcid << 8 | 1);
  return (rd64(BC + BC_ALLOC) >> 32) & 0x7F;
}
static void set_bc(unsigned rcid, unsigned rbwb, unsigned mw) {
  unsigned st = bc_limit(rcid, rbwb, mw);
  CHECK(st == 1, "bandwidth CONFIG_LIMIT RCID %d Rbwb %d Mweight %d: STATUS %d", rcid, rbwb, mw, st);
}
static void set_cc(unsigned rcid, uint32_t mask) {
  for (unsigned at = 0; at < 2; at++) {
    REG32(CC + CC_MASK) = mask;
    REG32(CC + CC_ALLOC) = 1 | (at << 5) | (rcid << 8);
    CHECK((REG32(CC + CC_ALLOC + 4) & 0x7F) == 1, "capacity CONFIG_LIMIT RCID %d AT %d failed", rcid, at);
  }
}

// ---- workers: one op = a store (or load) and a fence; time the op
static void worker(int c, uintptr_t base, uintptr_t stride, uint32_t lines) {
  uint64_t n = 0, s = 0;
  SRMCFG_W((uint64_t)c << 16 | c);
  for (;;) {
    uint32_t m = mode[c];
    if (m == IDLE) { for (int i = 0; i < 256; i++) __asm__ volatile("nop"); continue; }
    volatile uint64_t *p = (volatile uint64_t *)(base + (n % lines) * stride);
    uint64_t t0 = soc_cycles();
    if (m == STORE) *p = n;
    else            s += *p;
    __asm__ volatile("fence rw, rw" ::: "memory");
    uint64_t dt = soc_cycles() - t0;
    if (dt > maxlat[c]) maxlat[c] = dt;
    n++;
    prog[c] = n;
    __asm__ volatile("" :: "r"(s));
  }
}
int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 1) worker(1, AGG_BASE, AGG_STRIDE, AGG_LINES);
  if (cid == 2) worker(2, HOT_BASE, V_STRIDE, HOT_LINES);
  if (cid == 3) worker(3, COLD_BASE, V_STRIDE, COLD_LINES);
  if (cid == 0) return 0;
  for (;;) __asm__ volatile("wfi");
}

// ---- APMU: DRAM read and write requests per source core
static void apmu_setup(void) {
  for (int c = 1; c < 4; c++) {
    int r = CTR0 + c, w = CTR0 + 3 + c;
    REG32(EVENT_SEL_BASE_ADDR + r * COUNTER_BUNDLE_SIZE) = MEM_RD_REQ_CORE(c);
    REG32(EVENT_SEL_BASE_ADDR + w * COUNTER_BUNDLE_SIZE) = MEM_WR_REQ_CORE(c);
    REG32(EVENT_INFO_BASE_ADDR + r * COUNTER_BUNDLE_SIZE) = 0; REG32(COUNTER_BASE_ADDR + r * COUNTER_BUNDLE_SIZE) = 0;
    REG32(EVENT_INFO_BASE_ADDR + w * COUNTER_BUNDLE_SIZE) = 0; REG32(COUNTER_BASE_ADDR + w * COUNTER_BUNDLE_SIZE) = 0;
  }
}
static uint32_t ctr(int i) { return REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu; }
static void wait_cycles(uint64_t n) { uint64_t t0 = soc_cycles(); while (soc_cycles() - t0 < n) ; }

typedef struct { uint32_t ops[4], rd[4], wr[4]; uint64_t lat[4]; uint32_t pool_max, full; } res_t;
// agg_mw: the aggressor's Mweight in the window (0: hard limit); its L1 set is filled with dirty lines first
static void run_case(const char *name, uint32_t m1, uint32_t m2, uint32_t m3, unsigned agg_mw, res_t *r) {
  uint64_t p0[4];
  uint32_t r0[4], w0[4];
  if (m1 == STORE) {                               // fill the aggressor's L1 set with dirty lines, unthrottled
    set_bc(1, 40, 255);
    mode[1] = STORE;
    uint64_t k0 = prog[1];
    while (prog[1] - k0 < 2 * 8) ;
    set_bc(1, 1, agg_mw);
  }
  mode[1] = m1; mode[2] = m2; mode[3] = m3;
  wait_cycles(PERIOD);                             // warm-up
  for (int c = 1; c < 4; c++) { maxlat[c] = 0; p0[c] = prog[c]; r0[c] = ctr(CTR0 + c); w0[c] = ctr(CTR0 + 3 + c); }
  REG32(BC + BC_POOL) = 0; REG32(BC + BC_FULL) = 0;
  wait_cycles(WINDOW);
  for (int c = 1; c < 4; c++) {
    r->ops[c] = (uint32_t)(prog[c] - p0[c]);
    r->rd[c] = ctr(CTR0 + c) - r0[c]; r->wr[c] = ctr(CTR0 + 3 + c) - w0[c];
    r->lat[c] = maxlat[c];
  }
  r->pool_max = (REG32(BC + BC_POOL) >> 8) & 0xFF;
  r->full = REG32(BC + BC_FULL);
  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  set_bc(1, 40, 255);                              // let the aggressor's parked descriptors drain
  wait_cycles(PERIOD);
  set_bc(1, 1, 0);
  printf("  %s ops aggr/hot/cold %d / %d / %d, longest op %d / %d / %d cycles, DRAM rd+wr lines %d+%d / %d+%d / %d+%d,"
         " pool max %d, full %d\r\n", name, r->ops[1], r->ops[2], r->ops[3], (int)r->lat[1], (int)r->lat[2],
         (int)r->lat[3], r->rd[1], r->wr[1], r->rd[2], r->wr[2], r->rd[3], r->wr[3], r->pool_max, r->full);
  uart_wait_tx_done();
}
static int pct(uint32_t a, uint32_t b) { return b ? (int)(100ULL * a / b) : 0; }

int main(void) {
  res_t a, b, c, d, e, f, g;
  soc_test_begin("t_bcw");
  REG32(BC + BC_PERIOD)   = PERIOD;
  REG32(BC + BC_CAPACITY) = CAP_LINES * LINE;
  set_bc(0, 1, 255);
  set_bc(1, 1, 0);
  set_bc(2, 1, 64);
  set_bc(3, 1, 64);
  set_cc(1, 0x0001);                               // the aggressor: one LLC way; everyone else the other fifteen
  set_cc(0, 0xFFFE); set_cc(2, 0xFFFE); set_cc(3, 0xFFFE);
  apmu_setup();
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);
  REG32(BC + BC_CTRL) = 3;
  printf("  the controller hands out %d lines per window of %d cycles; the aggressor's hard limit is 1 block\r\n",
         CAP_LINES * WINDOW / PERIOD, WINDOW);

  run_case("A", IDLE,  STORE, STORE, 0,  &a);
  run_case("B", STORE, STORE, STORE, 0,  &b);
  run_case("C", STORE, STORE, STORE, 16, &c);
  run_case("D", STORE, LOAD,  LOAD,  0,  &d);
  run_case("E", STORE, IDLE,  IDLE,  0,  &e);
  run_case("F", STORE, IDLE,  STORE, 0,  &f);
  run_case("G", STORE, STORE, IDLE,  0,  &g);

  uint32_t lim = e.rd[1] + e.wr[1];
  printf("  stall: cold stores %d alone, %d next to the hard-limited aggressor with nobody to inherit (%d %%), %d with "
         "the hot core inheriting (%d %%), %d when the aggressor has Mweight 16 (%d %%); longest cold store %d -> %d "
         "cycles\r\n", a.ops[3], f.ops[3], pct(f.ops[3], a.ops[3]), b.ops[3], pct(b.ops[3], a.ops[3]), c.ops[3],
         pct(c.ops[3], a.ops[3]), (int)a.lat[3], (int)f.lat[3]);
  printf("  leak: the aggressor moves %d DRAM lines alone at its hard limit, %d next to the hot core's write-backs "
         "(%d %%), %d next to the cold core's\r\n", lim, g.rd[1] + g.wr[1], pct(g.rd[1] + g.wr[1], lim ? lim : 1),
         f.rd[1] + f.wr[1]);
  printf("  hot stores: %d alone, %d next to the aggressor (%d %%)\r\n", a.ops[2], g.ops[2], pct(g.ops[2], a.ops[2]));

  // what must hold either way
  CHECK(lim <= 2 * 2 * (WINDOW / PERIOD) + 4, "E: the aggressor alone moved %d lines in %d periods past its hard limit",
        lim, WINDOW / PERIOD);
  CHECK(d.ops[3] * 10 >= a.ops[3] * 5, "D: cold loads %d next to the aggressor, cold stores alone %d", d.ops[3], a.ops[3]);

  for (int k = 1; k < 4; k++) mode[k] = IDLE;
  REG32(BC + BC_CTRL) = 2;
  set_bc(1, 1, 1); set_bc(2, 1, 1); set_bc(3, 1, 1);
  for (unsigned rc = 0; rc < 4; rc++) set_cc(rc, 0xFFFF);
  SRMCFG_W(0);
  return soc_test_end();
}
