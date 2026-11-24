// t_bchol: does limiting one RCID slow down another? (hardware/docs/qos.md, "Memory bandwidth controller")
//
// On the board (qosgate_4c, Linux 7.2 resctrl, 2026-11-23) a best-effort reader (MB_MIN 1, MB_WGHT 255) lost bandwidth
// when the readers of another group were hard-limited with a reservation (MB_MIN 205 of 1024, MB_WGHT 0), and lost
// more the more of them there were: 24.7 / 20.2 / 18.4 MB/s next to 1 / 2 / 3, with the controller pacing 47 MB/s and
// the total far below it; the controller's pool never filled. This test rebuilds that configuration and separates two
// explanations:
//   priority   the limited RCID is inside its reservation at the start of every period, so its reads are released
//              before the best-effort victim's (release order 2 before 3), and with pacing they take the tokens until
//              the reservation is used up: the victim waits for that long once per period
//   remapper   a read parked in the controller keeps its output ID in the ID remapper between the coherence unit and
//              the crossbar (cva6_axi_id_remap: ariane_soc::RemapMaxUniqIds IDs, RemapTxnsPerId transactions each),
//              so parked reads can fill the table and every core's next read waits for an ID. The remapper prints
//              "[REMAP]" lines in simulation (waits of 1000 cycles or more, and totals at the end); the defines
//              REMAP_MAX_UNIQ_IDS / REMAP_TXNS_PER_ID resize it for an A/B run.
//
// Victim: core 1, RCID 1, all LLC ways but way 0. One op = a load and a fence, timed; counters go to the on-chip
//   SRAM every 8 ops.
//   MISS  1024 lines 2 KB apart (one L1 set, LLC sets 0x22 + 32k, 32 tags per set for 15 ways): every load misses
//         the L1 and the LLC, a DRAM refill
//   HIT   64 lines 2 KB apart, LLC-resident: every load misses the L1 and hits the LLC. It costs no DRAM bandwidth,
//         so a slower HIT can only be a wait in the fabric
// Aggressors: cores 2, 3 and 0 (core 0 between its checks of the clock), RCID 2, LLC way 0 only (a one-way mask:
//   every load misses the LLC), 16 lines 64 KB apart per core (core c: LLC set c, one L1 set): unfenced loads.
//   Core 2's lines are in LLC set 2, a set the victim's MISS lines use too (other lines, other ways): a lookup of
//   the victim there must not wait for core 2's parked line (the bloom-filter lock box made it wait).
// The controller paces CAP_LINES lines per period: about 1.65 times what the victim asks for alone, as on the board.
// Cases (victim MISS unless noted; aggressor Rbwb / Mweight):
//   S        the victim alone
//   P1 P2 P3 1, 2, 3 aggressors, 205 / 0: the board's configuration (a hard limit with a reservation of 20 %)
//   Q1 Q2 Q3 1, 2, 3 aggressors,   1 / 0: a hard limit with nothing reserved. "priority" predicts no loss here,
//            "remapper" the same loss as P
//   U3       3 aggressors, 1 / 255: best effort (the board's "no limit")
//   R3       as P3 with the victim reserved (Rbwb 400): what a reservation buys the victim
//   PH3      as P3 with the victim on HIT: "priority" predicts no loss (hits are free), "remapper" a loss
// Per case: the victim's ops per window (scaled to the cycles the window really took: core 0 is itself parked as
// the third aggressor and reads the clock late), its mean and longest op and how many took 1000 cycles or more, the
// aggressors' DRAM lines (APMU), the pool's high-water mark. The test reports; it checks only the limits and that
// the victim made progress.
#include "soc_test.h"

#define BC          0x10401C00UL
#define BC_ALLOC    0x18
#define BC_BW       0x20
#define BC_CTRL     0x80
#define BC_PERIOD   0x88
#define BC_CAPACITY 0x90
#define BC_POOL     0x98
#define BC_FULL     0xA0
#define CC          0x10401800UL
#define CC_ALLOC    0x18
#define CC_MASK     0x20
#define LINE        64
#define PERIOD      12800
#define CAP_LINES   155                           // 1.65 x the victim alone (about 94 lines per period)
#define A_RESV      205                           // the board's MB_MIN 205: 20 % of the capacity
#define PUB         8                             // ops between two updates of the SRAM counters
#define WINDOW      (4 * PERIOD)
#define V_RCID      1
#define A_RCID      2
#define VM_BASE     0x80500880UL                  // 1024 LLC-missing lines: L1 set 8, LLC sets 0x22 + 32k
#define VM_LINES    1024
#define VH_BASE     0x80140880UL                  // 64 LLC-resident lines, same sets
#define VH_LINES    64
#define V_STRIDE    0x800UL
#define A_BASE(c)   (0x80400000UL + (uintptr_t)(c) * 0x40UL)   // per core: LLC set c (way 0 only), one L1 set
#define A_STRIDE    0x10000UL
#define A_LINES     16                            // 16 lines per core: more than an L1 set or one LLC way holds
#define CTR0        4

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

enum { IDLE = 0, MISS = 1, HIT = 2, AGG = 3 };
SOC_SRAM static volatile uint32_t mode[4];
SOC_SRAM static volatile uint64_t prog[4], maxlat[4], sumlat[4], nlong[4];

static inline uint64_t rd64(uintptr_t a) { return (uint64_t)REG32(a + 4) << 32 | REG32(a); }
static inline void wr64(uintptr_t a, uint64_t v) { REG32(a + 4) = (uint32_t)(v >> 32); REG32(a) = (uint32_t)v; }
static void set_bc(unsigned rcid, unsigned rbwb, unsigned mw) {
  wr64(BC + BC_BW, (uint64_t)mw << 20 | rbwb);
  wr64(BC + BC_ALLOC, (uint64_t)rcid << 8 | 1);
  unsigned st = (rd64(BC + BC_ALLOC) >> 32) & 0x7F;
  CHECK(st == 1, "bandwidth CONFIG_LIMIT RCID %d Rbwb %d Mweight %d: STATUS %d", rcid, rbwb, mw, st);
}
static void set_cc(unsigned rcid, uint32_t mask) {
  for (unsigned at = 0; at < 2; at++) {
    REG32(CC + CC_MASK) = mask;
    REG32(CC + CC_ALLOC) = 1 | (at << 5) | (rcid << 8);
    CHECK((REG32(CC + CC_ALLOC + 4) & 0x7F) == 1, "capacity CONFIG_LIMIT RCID %d AT %d failed", rcid, at);
  }
}

// ---- workers
static inline void agg_load(int c, uint64_t *k, uint64_t *s) {
  *s += *(volatile uint64_t *)(A_BASE(c) + (*k)++ % A_LINES * A_STRIDE);
}
static void worker(int c) {
  uint64_t n = 0, s = 0, k = 0, mx = 0, sum = 0, lg = 0;
  uint32_t m = IDLE;
  SRMCFG_W(c == 1 ? ((uint64_t)V_RCID << 16 | V_RCID) : ((uint64_t)A_RCID << 16 | A_RCID));
  for (;;) {
    if ((n % PUB) == 0 || m == IDLE) {             // the SRAM is not cached: talk to it every PUB ops only
      if (c == 1) { prog[c] = n; sumlat[c] = sum; nlong[c] = lg; if (mx > maxlat[c]) maxlat[c] = mx; mx = 0; }
      m = mode[c];
    }
    if (m == IDLE) { for (int i = 0; i < 256; i++) __asm__ volatile("nop"); continue; }
    if (m == AGG) { agg_load(c, &k, &s); n++; __asm__ volatile("" :: "r"(s)); continue; }
    uintptr_t a = m == MISS ? VM_BASE + (k++ % VM_LINES) * V_STRIDE : VH_BASE + (k++ % VH_LINES) * V_STRIDE;
    uint64_t t0 = soc_cycles();
    s += *(volatile uint64_t *)a;
    __asm__ volatile("fence rw, rw" ::: "memory");
    uint64_t dt = soc_cycles() - t0;
    if (dt > mx) mx = dt;
    if (dt >= 1000) lg++;
    sum += dt;
    n++;
    __asm__ volatile("" :: "r"(s));
  }
}
int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 0) return 0;
  if (cid < 4) worker(cid);
  for (;;) __asm__ volatile("wfi");
}

// ---- APMU: DRAM read requests of cores 0, 2 and 3 (the aggressors)
static void apmu_setup(void) {
  const uint32_t ev[3] = { MEM_RD_REQ_CORE(0), MEM_RD_REQ_CORE(2), MEM_RD_REQ_CORE(3) };
  for (int i = 0; i < 3; i++) {
    REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = ev[i];
    REG32(EVENT_INFO_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(COUNTER_BASE_ADDR    + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
  }
}
static uint32_t agg_lines(void) {
  uint32_t n = 0;
  for (int i = 0; i < 3; i++) n += REG32(COUNTER_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
  return n;
}
static void wait_cycles(uint64_t n) { uint64_t t0 = soc_cycles(); while (soc_cycles() - t0 < n) ; }

typedef struct { uint32_t ops, raw, agg, pool_hwm, full, nlong; uint64_t mean, lat, cyc; } res_t;

// nagg aggressors: cores 2, 3, then core 0 itself (an unfenced load in every turn of the control loop)
static void run_case(const char *name, uint32_t vmode, int nagg, unsigned a_rbwb, unsigned a_mw, unsigned v_rbwb,
                     res_t *r) {
  set_bc(V_RCID, v_rbwb, 255);
  set_bc(A_RCID, a_rbwb, a_mw);
  mode[2] = nagg >= 1 ? AGG : IDLE;
  mode[3] = nagg >= 2 ? AGG : IDLE;
  int self = nagg >= 3;
  if (self) SRMCFG_W((uint64_t)A_RCID << 16 | A_RCID);
  mode[1] = vmode;
  uint64_t t0 = soc_cycles(), t_open = 0, t_close, p0 = 0, s0 = 0, l0 = 0, k = 0, s = 0;
  uint32_t a0 = 0;
  int open = 0;
  for (;;) {
    uint64_t t = soc_cycles() - t0;
    if (!open && t >= PERIOD) {                    // one period of warm-up, then the window
      maxlat[1] = 0; p0 = prog[1]; s0 = sumlat[1]; l0 = nlong[1];
      a0 = agg_lines();
      REG32(BC + BC_POOL) = 0; REG32(BC + BC_FULL) = 0;
      t_open = soc_cycles();
      open = 1;
    }
    if (open && t >= PERIOD + WINDOW) break;
    if (self) agg_load(0, &k, &s);
  }
  __asm__ volatile("" :: "r"(s));
  r->raw = (uint32_t)(prog[1] - p0);
  t_close = soc_cycles();
  r->cyc = t_close - t_open;
  r->ops = (uint32_t)((uint64_t)r->raw * WINDOW / r->cyc);
  r->lat = maxlat[1];
  r->mean = r->raw ? (sumlat[1] - s0) / r->raw : 0;
  r->nlong = (uint32_t)(nlong[1] - l0);
  r->agg = agg_lines() - a0;
  r->pool_hwm = (REG32(BC + BC_POOL) >> 8) & 0xFF;
  r->full = REG32(BC + BC_FULL);
  // wind down: stop everyone, release the parked reads unthrottled
  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  if (self) SRMCFG_W(0);
  set_bc(A_RCID, 1, 255);
  wait_cycles(2 * PERIOD);
  printf("  %-3s victim %4d ops per window (%d in %d cycles), mean %4d, longest %6d, %d of 1000+ cycles | %d aggressor(s)"
         " Rbwb %d Mweight %d: %d DRAM lines | pool hwm %d, full %d\r\n", name, r->ops, r->raw, (int)r->cyc,
         (int)r->mean, (int)r->lat, r->nlong, nagg, a_rbwb, a_mw, r->agg, r->pool_hwm, r->full);
  uart_wait_tx_done();
}
static int pct(uint32_t a, uint32_t b) { return b ? (int)(100ULL * a / b) : 0; }

int main(void) {
  res_t sv, p[4], q[4], u3, r3, ph3, sh;
  soc_test_begin("t_bchol");
  REG32(BC + BC_PERIOD)   = PERIOD;
  REG32(BC + BC_CAPACITY) = CAP_LINES * LINE;
  set_bc(0, 1, 255);
  set_bc(V_RCID, 1, 255);
  set_bc(A_RCID, 1, 255);
  set_cc(A_RCID, 0x0001);                          // the aggressors: one LLC way; everyone else the other fifteen
  set_cc(0, 0xFFFE); set_cc(V_RCID, 0xFFFE);
  apmu_setup();
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);
  for (int i = 0; i < VH_LINES; i++) (void)*(volatile uint64_t *)(VH_BASE + i * V_STRIDE);   // HIT lines into the LLC
  REG32(BC + BC_CTRL) = 3;
  printf("  controller: %d lines per period of %d cycles, window %d cycles; a reservation of %d blocks is %d lines per"
         " period\r\n", CAP_LINES, PERIOD, WINDOW, A_RESV, CAP_LINES * A_RESV / 1024);

  run_case("S",  MISS, 0, 1, 255, 1, &sv);
#ifdef BCHOL_SHORT                                 // the cases to look at with the simulation monitors
  run_case("Q3", MISS, 3, 1, 0, 1, &q[3]);
  run_case("P3", MISS, 3, A_RESV, 0, 1, &p[3]);
  run_case("P1", MISS, 1, A_RESV, 0, 1, &p[1]);
  run_case("Q1", MISS, 1, 1, 0, 1, &q[1]);
  (void)u3; (void)r3; (void)ph3; (void)sh;
  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  REG32(BC + BC_CTRL) = 2;
  return soc_test_end();
#endif
  for (int n = 1; n <= 3; n++) {
    char nm[4] = { 'P', (char)('0' + n), 0 };
    run_case(nm, MISS, n, A_RESV, 0, 1, &p[n]);
    nm[0] = 'Q';
    run_case(nm, MISS, n, 1, 0, 1, &q[n]);
  }
  run_case("U3",  MISS, 3, 1, 255, 1, &u3);
  run_case("R3",  MISS, 3, A_RESV, 0, 400, &r3);
  run_case("SH",  HIT,  0, 1, 255, 1, &sh);
  run_case("PH3", HIT,  3, A_RESV, 0, 1, &ph3);

  printf("  victim LLC-miss loads, %% of alone (%d ops, mean %d, longest %d cycles): reserved hard limit, 1 / 2 / 3"
         " aggressors %d / %d / %d (longest %d / %d / %d); hard limit with nothing reserved %d / %d / %d (longest"
         " %d / %d / %d); best effort, 3: %d; reserved hard limit, 3, victim reserved too: %d (longest %d)\r\n",
         sv.ops, (int)sv.mean, (int)sv.lat,
         pct(p[1].ops, sv.ops), pct(p[2].ops, sv.ops), pct(p[3].ops, sv.ops), (int)p[1].lat, (int)p[2].lat, (int)p[3].lat,
         pct(q[1].ops, sv.ops), pct(q[2].ops, sv.ops), pct(q[3].ops, sv.ops), (int)q[1].lat, (int)q[2].lat, (int)q[3].lat,
         pct(u3.ops, sv.ops), pct(r3.ops, sv.ops), (int)r3.lat);
  printf("  victim LLC-hit loads next to 3 aggressors with the reserved hard limit: %d %% of alone (%d ops, longest %d"
         " -> %d cycles)\r\n", pct(ph3.ops, sh.ops), sh.ops, (int)sh.lat, (int)ph3.lat);

  // what must hold either way: the limits (reservation plus about one release of up to two lines per period and
  // per parked read), and progress of the victim
  for (int n = 1; n <= 3; n++) {
    uint32_t per = (uint32_t)(p[n].cyc / PERIOD) + 1, qper = (uint32_t)(q[n].cyc / PERIOD) + 1;
    CHECK(q[n].agg <= 2 * n * qper + 4 * n, "Q%d: %d DRAM lines in %d periods with a 1-block hard limit", n, q[n].agg, qper);
    CHECK(p[n].agg <= (CAP_LINES * A_RESV / 1024 + 2 * n) * per + 4 * n, "P%d: %d DRAM lines in %d periods, reservation"
          " %d lines per period", n, p[n].agg, per, CAP_LINES * A_RESV / 1024);
  }
  CHECK(p[3].raw > 0 && q[3].raw > 0 && ph3.raw > 0, "the victim made no progress next to 3 limited aggressors");
  // a limit on RCID 2 does not slow RCID 1 down: the controller hands out more than both ask for
  for (int n = 1; n <= 3; n++) {
    CHECK(pct(p[n].ops, sv.ops) >= 90, "P%d: the victim does %d %% of alone next to the reserved hard limit", n, pct(p[n].ops, sv.ops));
    CHECK(pct(q[n].ops, sv.ops) >= 90, "Q%d: the victim does %d %% of alone next to the hard limit", n, pct(q[n].ops, sv.ops));
    CHECK(p[n].lat < 1000 && q[n].lat < 1000, "%d aggressor(s): the victim's longest load took %d (P) / %d (Q) cycles", n,
          (int)p[n].lat, (int)q[n].lat);
  }
  CHECK(pct(ph3.ops, sh.ops) >= 90 && ph3.lat < 1000, "PH3: the victim's LLC-hit loads do %d %% of alone, longest %d cycles",
        pct(ph3.ops, sh.ops), (int)ph3.lat);
  // and the limited RCID gets its reservation (the aggressors ask for far more)
  {
    uint32_t per = (uint32_t)(p[3].cyc / PERIOD), want = CAP_LINES * A_RESV / 1024 * per;
    CHECK(p[3].agg * 10 >= want * 8, "P3: the aggressors moved %d DRAM lines in %d periods, reservation %d", p[3].agg, per, want);
  }

  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  REG32(BC + BC_CTRL) = 2;
  set_bc(V_RCID, 1, 1); set_bc(A_RCID, 1, 1);
  for (unsigned rc = 0; rc < 3; rc++) set_cc(rc, 0xFFFF);
  SRMCFG_W(0);
  return soc_test_end();
}
