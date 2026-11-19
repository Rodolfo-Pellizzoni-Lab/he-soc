// t_bcd: who a throttled write stops, with the LLC bandwidth controller (hardware/docs/qos.md, "Memory bandwidth
// controller"). Two questions:
//   1. The load stalls t_bcw saw on the board: are they the write ordering (a load whose L1 victim is dirty first
//      writes it back, an LLC write that queues behind a parked write) or something every load meets?
//   2. A coherent DMA write goes through the coherence unit's state machine, which waits for the write's response
//      before it takes the next request, and every core's L1 misses go through that state machine too. Does a held
//      DMA write stop every core?
//
// Victims: cores 2 and 3, RCIDs 2 and 3. Their lines (64 per core, 2 KB apart: one L1 set, LLC sets 0x21 + 32k and
// 0x22 + 32k) stay in the LLC and miss the L1 on every access, so each op crosses the coherence unit but costs no
// memory bandwidth; a long op is a wait in the fabric. One op = a load and a fence, timed.
//   LOAD   loads only: the L1 victim is always clean (no write-back)
//   MLOAD  (core 3) loads only, of 1024 lines 2 KB apart (2 MB, 32 per LLC set used) that miss the LLC: RCID 3 pays
//          for its refills and is past its 1-block reservation for most of every period
//   DMLOAD (core 3) as MLOAD, in rounds of 8 stores to 8 other lines of the same L1 set (untimed, they dirty the
//          set) and 8 timed loads, each of which evicts a dirty line: a write-back to the LLC (a hit, free)
// A write that waits behind a parked one makes it inherit (released at once, charged to its owner) only while the
// waiting write's RCID is inside its reservation: the victims that stall are those past it (MLOAD, DMLOAD).
// Aggressor: core 1, RCID 1, as in t_bcw: Rbwb 1 block, Mweight 0, one LLC way (mask 0x0001), stores to 64 lines
//   64 KB apart (LLC set 0), its L1 set pre-dirtied: each write-back is an LLC write miss, parked until its next
//   release (about one per period).
// DMA: the accelerator socket's example engine (slot 0) copies 128 words (16 lines) with every request tagged
//   RCID = MCID 4 (TAG_POLICY.FORCE); reads ReadOnce, writes WriteUnique, through the coherence unit. Its lines sit in
//   LLC sets 0x43..0x72, apart from everyone else's. Core 0 restarts it whenever it finishes, each job on the next
//   of 32 destinations 64 KB apart (the same LLC sets, 32 tags for 15 ways): every line it writes misses the LLC.
//   reserved     RCID 4 Rbwb 200, Mweight 255
//   best effort  RCID 4 Rbwb 1, Mweight 255
//   hard         RCID 4 Rbwb 1, Mweight 0
// Cases (cores 2 / 3):
//   A  LOAD / MLOAD alone            B  LOAD / MLOAD, aggressor        question 1: a clean load, LLC miss or hit,
//   A' LOAD / DMLOAD alone           B' LOAD / DMLOAD, aggressor       does not wait; one that writes back does
//   A0 LOAD / LOAD alone (the reference for the DMA cases)
//   C  reserved DMA                  (sharing the coherence unit)
//   D  hard-limited DMA              question 2: the DMA's own write held
//   G  best-effort DMA               (alone it is never held long)
//   E  best-effort DMA + aggressor   question 2: the DMA's write held behind the aggressor's parked write
//   F  reserved DMA + aggressor      (the DMA inherits instead: no stall, the aggressor leaks)
// Per case: loads per victim in the window and the longest, the DMA's jobs and DRAM lines (its MCID's monitor), the
// aggressor's DRAM lines, and the cycles the DMA's requests waited at the admission gate in front of the coherence
// unit (BC_GATE_WAIT; with QOS_DMA_GATE a hard-limited DMA waits there, before the coherence unit, instead of parking
// a coherent write inside the LLC that the coherence unit and every core wait for). The test reports; it checks only
// what must hold either way (the DMA's data, the limits).
#include "soc_test.h"
#include "accel.h"

#define BC          0x10401C00UL
#define BC_MON_CTL  0x08
#define BC_MON_VAL  0x10
#define BC_ALLOC    0x18
#define BC_BW       0x20
#define BC_CTRL     0x80
#define BC_PERIOD   0x88
#define BC_CAPACITY 0x90
#define BC_GATE_WAIT 0xB0
#define CC          0x10401800UL
#define CC_ALLOC    0x18
#define CC_MASK     0x20
#define LINE        64
#define PERIOD      12800
#define CAP_LINES   45
#define WINDOW      (4 * PERIOD)
#define AGG_BASE    0x80400000UL                  // 64 lines 64 KB apart: LLC set 0, L1 set 0
#define AGG_STRIDE  0x10000UL
#define AGG_LINES   64
#define V2_BASE     0x80100840UL                  // 64 lines 2 KB apart: L1 set 4, LLC sets 0x21 + 32k
#define V3_BASE     0x80140880UL                  // 64 lines: L1 set 8, LLC sets 0x22 + 32k
#define V3S_BASE    0x80180880UL                  // core 3's 8 store lines, same L1 set
#define V3M_BASE    0x80500880UL                  // core 3's 1024 LLC-missing lines: L1 set 8, LLC sets 0x22 + 32k
#define V3M_LINES   1024
#define V_STRIDE    0x800UL
#define V_LINES     64
#define DMA_SLOT    0
#define DMA_WORDS   128                           // 16 lines
#define DMA_SRC     0x802018C0UL                  // LLC sets 0x63..0x72
#define DMA_DST(j)  (0x802010C0UL + (uintptr_t)((j) % 32) * 0x10000UL)   // LLC sets 0x43..0x52, 32 tags
#define DMA_RCID    4
#define CTR0        4

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

enum { IDLE = 0, STORE = 1, LOAD = 2, MLOAD = 3, DMLOAD = 4 };
SOC_SRAM static volatile uint32_t mode[4];
SOC_SRAM static volatile uint64_t prog[4], maxlat[4];

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
// MCID m's read+write bytes since the last call (CONFIG_EVENT resets the counter)
static uint64_t mon_take(unsigned m) {
  wr64(BC + BC_MON_CTL, (uint64_t)m << 8 | 2);
  uint64_t v = rd64(BC + BC_MON_VAL) & ((1ULL << 62) - 1);
  wr64(BC + BC_MON_CTL, (uint64_t)1 << 20 | (uint64_t)m << 8 | 1);
  return v;
}

// ---- workers
static inline uint64_t timed_load(volatile uint64_t *p, uint64_t *s) {
  uint64_t t0 = soc_cycles();
  *s += *p;
  __asm__ volatile("fence rw, rw" ::: "memory");
  return soc_cycles() - t0;
}
static void note(int c, uint64_t dt, uint64_t n) {
  if (dt > maxlat[c]) maxlat[c] = dt;
  prog[c] = n;
}
static void worker(int c) {
  uint64_t n = 0, s = 0, k = 0;
  SRMCFG_W((uint64_t)c << 16 | c);
  for (;;) {
    uint32_t m = mode[c];
    if (m == IDLE) { for (int i = 0; i < 256; i++) __asm__ volatile("nop"); continue; }
    if (c == 1) {                                  // the aggressor: a store and a fence, timed
      volatile uint64_t *p = (volatile uint64_t *)(AGG_BASE + (k++ % AGG_LINES) * AGG_STRIDE);
      uint64_t t0 = soc_cycles();
      *p = k;
      __asm__ volatile("fence rw, rw" ::: "memory");
      note(c, soc_cycles() - t0, ++n);
      continue;
    }
    uintptr_t base = c == 2 ? V2_BASE : m == LOAD ? V3_BASE : V3M_BASE;
    uint32_t lines = m == LOAD ? V_LINES : V3M_LINES;
    if (m == DMLOAD) {
      for (int i = 0; i < 8; i++) {                // dirty the L1 set (untimed)
        *(volatile uint64_t *)(V3S_BASE + i * V_STRIDE) = k + i;
        __asm__ volatile("fence rw, rw" ::: "memory");
      }
      for (int i = 0; i < 8; i++) {
        uint64_t dt = timed_load((volatile uint64_t *)(base + (k++ % lines) * V_STRIDE), &s);
        note(c, dt, ++n);
      }
    } else {
      uint64_t dt = timed_load((volatile uint64_t *)(base + (k++ % lines) * V_STRIDE), &s);
      note(c, dt, ++n);
    }
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

// ---- the DMA: one job of DMA_WORDS from DMA_SRC to dst, tagged RCID = MCID DMA_RCID by the socket
static void dma_start(uintptr_t dst) {
  accel_wr64(DMA_SLOT, 0x08, DMA_SRC); accel_wr64(DMA_SLOT, 0x10, dst);
  accel_wr(DMA_SLOT, 0x18, DMA_WORDS); accel_wr(DMA_SLOT, 0x1C, 7);
  __asm__ volatile("fence" ::: "memory");
  accel_wr(DMA_SLOT, 0x00, 1);
}
static int dma_done(void) {
  if (!(accel_rd(DMA_SLOT, 0x04) & 2)) return 0;
  accel_wr(DMA_SLOT, 0x04, 2);
  return 1;
}

// ---- APMU: DRAM read and write requests of core 1 and of the socket's DMA
static void apmu_setup(void) {
  const uint32_t ev[4] = { MEM_RD_REQ_CORE(1), MEM_WR_REQ_CORE(1), MEM_RD_REQ_ACCEL, MEM_WR_REQ_ACCEL };
  for (int i = 0; i < 4; i++) {
    REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = ev[i];
    REG32(EVENT_INFO_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(COUNTER_BASE_ADDR    + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
  }
}
static uint32_t ctr(int i) { return REG32(COUNTER_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu; }
static void wait_cycles(uint64_t n) { uint64_t t0 = soc_cycles(); while (soc_cycles() - t0 < n) ; }

enum { DMA_OFF = 0, DMA_RES = 1, DMA_BE = 2, DMA_HARD = 3 };
static const char *dma_name[] = { "off", "reserved", "best effort", "hard-limited" };
typedef struct { uint32_t ops[4], agg_lines, dma_lines, jobs, gate_wait; uint64_t lat[4]; } res_t;
static unsigned njob;

static void run_case(const char *name, int agg, uint32_t m2, uint32_t m3, int dma, res_t *r) {
  uintptr_t dst = DMA_DST(njob);
  if (agg) {                                       // fill the aggressor's L1 set with dirty lines, unthrottled
    set_bc(1, 40, 255);
    mode[1] = STORE;
    uint64_t k0 = prog[1];
    while (prog[1] - k0 < 16) ;
    set_bc(1, 1, 0);
  }
  if (dma == DMA_HARD)    set_bc(DMA_RCID, 1, 0);
  else if (dma == DMA_BE) set_bc(DMA_RCID, 1, 255);
  else                    set_bc(DMA_RCID, 200, 255);
  mode[2] = m2; mode[3] = m3;
  if (dma) dma_start(dst);
  // warm-up, then the window; core 0 restarts the DMA whenever it finishes
  uint64_t p0[4] = {0}, t0 = soc_cycles();
  uint32_t a0 = 0, jobs = 0;
  int open = 0;
  for (;;) {
    uint64_t t = soc_cycles() - t0;
    if (!open && t >= PERIOD) {
      for (int c = 1; c < 4; c++) { maxlat[c] = 0; p0[c] = prog[c]; }
      a0 = ctr(0) + ctr(1);
      mon_take(DMA_RCID);
      REG32(BC + BC_GATE_WAIT) = 0;
      jobs = 0;
      open = 1;
    }
    if (open && t >= PERIOD + WINDOW) break;
    if (dma && dma_done()) { jobs++; dst = DMA_DST(++njob); dma_start(dst); }
  }
  for (int c = 1; c < 4; c++) { r->ops[c] = (uint32_t)(prog[c] - p0[c]); r->lat[c] = maxlat[c]; }
  r->agg_lines = ctr(0) + ctr(1) - a0;
  r->dma_lines = (uint32_t)(mon_take(DMA_RCID) / LINE);
  r->jobs = jobs;
  r->gate_wait = REG32(BC + BC_GATE_WAIT);
  // wind down: stop the workers, let the parked descriptors and the DMA drain unthrottled
  mode[1] = IDLE; mode[2] = IDLE; mode[3] = IDLE;
  set_bc(1, 40, 255);
  set_bc(DMA_RCID, 200, 255);
  if (dma) {
    uint64_t w0 = soc_cycles();
    while (!dma_done() && soc_cycles() - w0 < 50ULL * PERIOD) ;
    volatile uint64_t *s = (volatile uint64_t *)DMA_SRC, *d = (volatile uint64_t *)dst;
    int ok = 1;
    for (int i = 0; i < DMA_WORDS; i++) if (d[i] != s[i] + 7) ok = 0;
    CHECK(ok, "%s: the DMA's last job wrote wrong data", name);
    njob++;
  }
  wait_cycles(PERIOD);
  set_bc(1, 1, 0);
  printf("  %-2s loads core 2 / 3: %d / %d, longest %d / %d cycles | aggressor %s, %d DRAM lines | DMA %s, %d jobs,"
         " %d DRAM lines, %d cycles at the gate\r\n", name, r->ops[2], r->ops[3], (int)r->lat[2], (int)r->lat[3],
         agg ? "on" : "off", r->agg_lines, dma_name[dma], r->jobs, r->dma_lines, (int)r->gate_wait);
  uart_wait_tx_done();
}
static int pct(uint32_t a, uint32_t b) { return b ? (int)(100ULL * a / b) : 0; }

int main(void) {
  res_t a0, a, b, a1, b1, c, d, e, f, g;
  soc_test_begin("t_bcd");
  CHECK(accel_rd(DMA_SLOT, 0x20) == 0xAC0C9B9Fu, "slot 0 ID 0x%x (expected the example engine)", accel_rd(DMA_SLOT, 0x20));
  for (int i = 0; i < DMA_WORDS; i++) ((volatile uint64_t *)DMA_SRC)[i] = 0x5000u + i;
  REG32(ACCEL_TAG_POLICY(DMA_SLOT)) = 0x80000000u | ACCEL_USER(0, DMA_RCID, DMA_RCID);
  REG32(BC + BC_PERIOD)   = PERIOD;
  REG32(BC + BC_CAPACITY) = CAP_LINES * LINE;
  set_bc(0, 1, 255);
  set_bc(1, 1, 0);
  set_bc(2, 1, 64);
  set_bc(3, 1, 64);
  set_bc(DMA_RCID, 200, 255);
  set_cc(1, 0x0001);                               // the aggressor: one LLC way; everyone else the other fifteen
  set_cc(0, 0xFFFE); set_cc(2, 0xFFFE); set_cc(3, 0xFFFE); set_cc(DMA_RCID, 0xFFFE);
  apmu_setup();
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);
  for (int i = 0; i < V_LINES; i++) {            // the victims' LLC-resident lines into the LLC
    (void)*(volatile uint64_t *)(V2_BASE + i * V_STRIDE);
    (void)*(volatile uint64_t *)(V3_BASE + i * V_STRIDE);
  }
  REG32(BC + BC_CTRL) = 3;
  printf("  the controller hands out %d lines per window of %d cycles; aggressor and hard-limited DMA: 1 block\r\n",
         CAP_LINES * WINDOW / PERIOD, WINDOW);

  run_case("A",  0, LOAD, MLOAD,  DMA_OFF,  &a);
  run_case("B",  1, LOAD, MLOAD,  DMA_OFF,  &b);
  run_case("A'", 0, LOAD, DMLOAD, DMA_OFF,  &a1);
  run_case("B'", 1, LOAD, DMLOAD, DMA_OFF,  &b1);
  run_case("A0", 0, LOAD, LOAD,   DMA_OFF,  &a0);
  run_case("C",  0, LOAD, LOAD,   DMA_RES,  &c);
  run_case("D",  0, LOAD, LOAD,   DMA_HARD, &d);
  run_case("G",  0, LOAD, LOAD,   DMA_BE,   &g);
  run_case("E",  1, LOAD, LOAD,   DMA_BE,   &e);
  run_case("F",  1, LOAD, LOAD,   DMA_RES,  &f);

  printf("  1. next to the aggressor: core 2's LLC-hit loads %d %% of alone (longest %d -> %d cycles); core 3's"
         " LLC-miss loads %d %% (longest %d -> %d), the same writing back a dirty line each %d %% (longest %d -> %d)"
         "\r\n", pct(b.ops[2], a.ops[2]), (int)a.lat[2], (int)b.lat[2], pct(b.ops[3], a.ops[3]), (int)a.lat[3],
         (int)b.lat[3], pct(b1.ops[3], a1.ops[3]), (int)a1.lat[3], (int)b1.lat[3]);
  printf("  2. LLC-hit loads of cores 2 / 3 (%d / %d alone, longest %d / %d cycles) next to the DMA, %% of alone"
         " (longest): reserved %d / %d (%d / %d), hard-limited %d / %d (%d / %d), best effort %d / %d (%d / %d),"
         " best effort with the aggressor %d / %d (%d / %d), reserved with the aggressor %d / %d (%d / %d; the"
         " aggressor moved %d DRAM lines, %d next to the best-effort DMA)\r\n",
         a0.ops[2], a0.ops[3], (int)a0.lat[2], (int)a0.lat[3],
         pct(c.ops[2], a0.ops[2]), pct(c.ops[3], a0.ops[3]), (int)c.lat[2], (int)c.lat[3],
         pct(d.ops[2], a0.ops[2]), pct(d.ops[3], a0.ops[3]), (int)d.lat[2], (int)d.lat[3],
         pct(g.ops[2], a0.ops[2]), pct(g.ops[3], a0.ops[3]), (int)g.lat[2], (int)g.lat[3],
         pct(e.ops[2], a0.ops[2]), pct(e.ops[3], a0.ops[3]), (int)e.lat[2], (int)e.lat[3],
         pct(f.ops[2], a0.ops[2]), pct(f.ops[3], a0.ops[3]), (int)f.lat[2], (int)f.lat[3], f.agg_lines, e.agg_lines);

  // what must hold either way: the hard limits (about one release per period, up to two lines each)
  CHECK(d.dma_lines <= 2 * (WINDOW / PERIOD) + 4, "D: the hard-limited DMA moved %d lines in %d periods",
        d.dma_lines, WINDOW / PERIOD);
  CHECK(b.agg_lines <= 2 * 2 * (WINDOW / PERIOD) + 4, "B: the aggressor moved %d lines in %d periods",
        b.agg_lines, WINDOW / PERIOD);

  for (int k = 1; k < 4; k++) mode[k] = IDLE;
  REG32(BC + BC_CTRL) = 2;
  REG32(ACCEL_TAG_POLICY(DMA_SLOT)) = 0;
  set_bc(1, 1, 1); set_bc(2, 1, 1); set_bc(3, 1, 1); set_bc(DMA_RCID, 1, 1);
  for (unsigned rc = 0; rc < 5; rc++) set_cc(rc, 0xFFFF);
  SRMCFG_W(0);
  return soc_test_end();
}
