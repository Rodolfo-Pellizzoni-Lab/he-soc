// t_wbhol: does one core's write-back hold up another core's reads? (hardware/docs/qos.md, "Memory bandwidth
// controller"; board, Linux 7.2, 2026-11-24: next to tenants that write, a reader of another RCID keeps 77-82 % where
// it keeps 92 % next to readers that cause the same memory traffic, with the cache partitioned and the tenants inside
// their limit.)
//
// No regulation here (BC_CTRL.EN = 0; its per-MCID byte counters still count) and no kernel: only the cache and the
// memory. The LLC is partitioned: victim (RCID 1) ways 0-3, aggressors (RCID 2) ways 4-15.
//   victim      core 1: one LLC-missing load and a fence per op, timed (1024 lines 2 KB apart, as t_bchol)
//   aggressors  cores 2 and 3, paced: every PACE cycles either two loads (R) or one store (W). Each walks 64 lines
//               64 KB apart (one LLC set, one L1 set): the L1 keeps 8 of them and the LLC 12, so a load costs
//               about one refill, and a store a refill and, when the LLC evicts the line that the L1 wrote back
//               to it, a write-back. The lines really moved are counted (MCID 2 bytes, the model's write bursts).
// Cases: S (victim alone), R, W; with the DRAM timing model off and on (LAT 100, OCC16 320, the board's setting), and
// W with a short and a long write latency. Reported per case: the victim's mean and longest op, the aggressors'
// refills (APMU) and bytes (MCID 2), and from those the victim's extra cycles per aggressor transfer. In simulation
// (window 60k cycles) axi_llc_w_master prints "[LLC-WB]": how long descriptors stood behind a write-back that was only
// waiting for its write response (QOS_LLC_WBPEND = 0), and how many refills waited for their own line's write-back.
#include "soc_test.h"

#define BC          0x10401C00UL
#define BC_MON      0x08
#define BC_MON_VAL  0x10
#define BC_CTRL     0x80
#define CC          0x10401800UL
#define CC_ALLOC    0x18
#define CC_MASK     0x20
#define DM          0x1A106100UL
#define PUB         8
#ifdef FPGA_EMULATION
#define WINDOW      4000000
#define WARM        400000
#define PACE_M      3000
#else
#define WINDOW      60000
#define WARM        30000
#define PACE_M      1500
#endif
#define V_RCID      1
#define A_RCID      2
#define VM_BASE     0x80500880UL
#define VM_LINES    1024
#define V_STRIDE    0x800UL
#define A_BASE(c)   (0x80400000UL + (uintptr_t)(c) * 0x40UL)   // inside the window the LLC caches out of reset (8 MB)
#define A_STRIDE    0x10000UL
#define A_LINES     64
#define CTR0        4

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

enum { IDLE = 0, MISS = 1, AGG_R = 2, AGG_W = 3 };
SOC_SRAM static volatile uint32_t mode[4], pace;
SOC_SRAM static volatile uint64_t prog[4], maxlat[4], sumlat[4];

static inline uint64_t rd64(uintptr_t a) { return (uint64_t)REG32(a + 4) << 32 | REG32(a); }
static void set_cc(unsigned rcid, uint32_t mask) {
  for (unsigned at = 0; at < 2; at++) {
    REG32(CC + CC_MASK) = mask;
    REG32(CC + CC_ALLOC) = 1 | (at << 5) | (rcid << 8);
    CHECK((REG32(CC + CC_ALLOC + 4) & 0x7F) == 1, "capacity CONFIG_LIMIT RCID %d AT %d failed", rcid, at);
  }
}
static unsigned mon(unsigned op, unsigned mcid, unsigned evt) {
  REG32(BC + BC_MON + 4) = 0; REG32(BC + BC_MON) = evt << 20 | mcid << 8 | op;
  return REG32(BC + BC_MON + 4) & 0x7F;
}
static uint64_t mon_bytes(unsigned mcid) {
  CHECK(mon(2, mcid, 0) == 1, "READ_COUNTER MCID %d failed", mcid);
  return rd64(BC + BC_MON_VAL) & ((1ULL << 62) - 1);
}

static void worker(int c) {
  uint64_t n = 0, s = 0, k = 0, mx = 0, sum = 0, due = 0;
  uint32_t m = IDLE, pc = 0;
  SRMCFG_W(c == 1 ? ((uint64_t)V_RCID << 16 | V_RCID) : ((uint64_t)A_RCID << 16 | A_RCID));
  for (;;) {
    if ((n % PUB) == 0 || m == IDLE || m >= AGG_R) {
      if (c == 1) { prog[c] = n; sumlat[c] = sum; if (mx > maxlat[c]) maxlat[c] = mx; mx = 0; }
      m = mode[c]; pc = pace;
    }
    if (m == IDLE) { for (int i = 0; i < 256; i++) __asm__ volatile("nop"); due = 0; continue; }
    if (m >= AGG_R) {
      uint64_t now = soc_cycles();
      if (pc) {                                    // pace 0: as fast as it goes (the warm-up)
        if (due == 0 || (now > due && now - due > 8ULL * pc)) due = now;
        while (soc_cycles() < due) ;
        due += pc;
      } else due = 0;
      if (m == AGG_R) {
        s += *(volatile uint64_t *)(A_BASE(c) + k++ % A_LINES * A_STRIDE);
        s += *(volatile uint64_t *)(A_BASE(c) + k++ % A_LINES * A_STRIDE);
      } else {
        *(volatile uint64_t *)(A_BASE(c) + k % A_LINES * A_STRIDE) = k; k++;
      }
      n++;
      __asm__ volatile("" :: "r"(s));
      continue;
    }
    uintptr_t a = VM_BASE + (k++ % VM_LINES) * V_STRIDE;
    uint64_t t0 = soc_cycles();
    s += *(volatile uint64_t *)a;
    __asm__ volatile("fence rw, rw" ::: "memory");
    uint64_t dt = soc_cycles() - t0;
    if (dt > mx) mx = dt;
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

static void apmu_setup(void) {
  const uint32_t ev[2] = { MEM_RD_REQ_CORE(2), MEM_RD_REQ_CORE(3) };
  for (int i = 0; i < 2; i++) {
    REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = ev[i];
    REG32(EVENT_INFO_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(COUNTER_BASE_ADDR    + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
  }
}
static uint32_t agg_reads(void) {
  uint32_t n = 0;
  for (int i = 0; i < 2; i++) n += REG32(COUNTER_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
  return n;
}
static void wait_cycles(uint64_t n) { uint64_t t0 = soc_cycles(); while (soc_cycles() - t0 < n) ; }

typedef struct { uint32_t ops, rd, wr; uint64_t mean, lat, vbytes; } res_t;

// model: occ16 0 = off
static void run_case(const char *name, uint32_t amode, uint32_t pc, unsigned lat_rd, unsigned lat_wr, unsigned occ16,
                     res_t *r) {
  if (occ16) { REG32(DM + 4) = lat_rd; REG32(DM + 8) = lat_wr; REG32(DM + 12) = occ16; REG32(DM) = 3; }
  else REG32(DM) = 0;
  pace = 0;                                        // unpaced warm-up: the LLC's ways fill with the aggressors' lines
  mode[2] = amode; mode[3] = amode;
  mode[1] = MISS;
  wait_cycles(WARM);
  pace = pc;
  wait_cycles(WARM / 4);
  for (unsigned m = 0; m < 3; m++) CHECK(mon(1, m, 1) == 1, "CONFIG_EVENT MCID %d failed", m);
  maxlat[1] = 0;
  uint64_t p0 = prog[1], s0 = sumlat[1], t0 = soc_cycles();
  uint32_t a0 = agg_reads(), w0 = REG32(DM + 0x14);
  wait_cycles(WINDOW);
  uint64_t p1 = prog[1], s1 = sumlat[1], cyc = soc_cycles() - t0;
  uint32_t a1 = agg_reads(), w1 = REG32(DM + 0x14);
  uint64_t ab = mon_bytes(A_RCID);
  r->vbytes = mon_bytes(V_RCID);
  r->ops = (uint32_t)(p1 - p0);
  r->mean = r->ops ? (s1 - s0) / r->ops : 0;
  r->lat = maxlat[1];
  r->wr = occ16 ? w1 - w0 : 0;                     // the model counts write bursts only while it is enabled
  r->rd = (uint32_t)(ab / 64) - (r->wr < ab / 64 ? r->wr : 0);   // rd + wr: the aggressors' lines to and from memory
  uint32_t creq = a1 - a0;
  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  wait_cycles(WARM / 4);
  REG32(DM) = 0;
  printf("  %-5s model %3d/%3d/%3d | victim %6d ops in %d cycles, mean %4d, longest %6d, %d lines counted |"
         " aggressors: %d lines (%d write-backs), %d core requests\r\n", name, occ16 ? lat_rd : 0, occ16 ? lat_wr : 0, occ16,
         r->ops, (int)cyc, (int)r->mean, (int)r->lat, (int)(r->vbytes / 64), r->rd + r->wr, r->wr, creq);
  uart_wait_tx_done();
}
// the victim's extra cycles per aggressor transfer, against the case alone
static int cost(const res_t *c, const res_t *alone) {
  uint32_t x = c->rd + c->wr;
  return x && c->mean > alone->mean ? (int)((c->mean - alone->mean) * c->ops / x) : 0;
}

int main(void) {
  res_t s0, r0, w0, s1, r1, w1, wf, ws;
  soc_test_begin("t_wbhol");
  REG32(BC + BC_CTRL) = 0;
  set_cc(A_RCID, 0xFFF0);
  set_cc(0, 0x000F); set_cc(V_RCID, 0x000F);
  apmu_setup();
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);

#ifdef FPGA_EMULATION
  run_case("S",  IDLE,  1000, 0, 0, 0, &s0);
  run_case("R",  AGG_R, 1000, 0, 0, 0, &r0);
  run_case("W",  AGG_W, 1000, 0, 0, 0, &w0);
  printf("  model off: the victim does %d %% of alone next to readers, %d %% next to writers; extra victim cycles per"
         " aggressor transfer %d (R) / %d (W)\r\n", (int)(100ULL * r0.ops / s0.ops), (int)(100ULL * w0.ops / s0.ops),
         cost(&r0, &s0), cost(&w0, &s0));
#else
  (void)s0; (void)r0; (void)w0;
#endif
  run_case("S",  IDLE,  3000, 100, 100, 320, &s1);
  run_case("R",  AGG_R, PACE_M, 100, 100, 320, &r1);
  run_case("W",  AGG_W, PACE_M, 100, 100, 320, &w1);
  printf("  model 100/100/320: the victim does %d %% of alone next to readers, %d %% next to writers; extra victim"
         " cycles per aggressor transfer %d (R) / %d (W)\r\n", (int)(100ULL * r1.ops / s1.ops),
         (int)(100ULL * w1.ops / s1.ops), cost(&r1, &s1), cost(&w1, &s1));
#ifdef FPGA_EMULATION
  run_case("Wf", AGG_W, PACE_M, 100, 1,   320, &wf);
  run_case("Ws", AGG_W, PACE_M, 100, 300, 320, &ws);
  printf("  writers with write latency 1 / 100 / 300: the victim does %d / %d / %d %% of alone, extra cycles per"
         " transfer %d / %d / %d\r\n", (int)(100ULL * wf.ops / s1.ops), (int)(100ULL * w1.ops / s1.ops),
         (int)(100ULL * ws.ops / s1.ops), cost(&wf, &s1), cost(&w1, &s1), cost(&ws, &s1));
#else
  (void)wf; (void)ws;
#endif
  CHECK(r1.ops > 0 && w1.ops > 0, "the victim made no progress");
  CHECK(w1.wr > 0, "the writers caused no write-back (%d refills)", w1.rd);

  for (unsigned rc = 0; rc < 3; rc++) set_cc(rc, 0xFFFF);
  SRMCFG_W(0);
  return soc_test_end();
}
