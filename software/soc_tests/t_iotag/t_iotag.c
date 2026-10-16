// QoS tags on the accelerator socket's DMA: "I/O on behalf of an RCID" (hardware/accel/README.md).
//
// Every register access hands the slot the requesting hart's user field (source port, RCID, MCID, AT); the
// accelerator latches it at START (its TAG register) and tags its DMA with it, so the work it does is charged to
// the hart that asked for it. The socket is the trusted tagging point: its per-slot TAG_POLICY register can force a
// tag the OS chose instead (the IOMMU device-context model), and LAST_USER shows what the slot's last DMA carried.
//   1. the socket's QoS probe (sanity), the policy registers at reset
//   2. inherit: core 0 with srmcfg (RCID 5, MCID 3) starts slot 0 (example): TAG and LAST_USER show that tag; a
//      new srmcfg -> both follow
//   3. force: TAG_POLICY = FORCE | (RCID 12, MCID 2): the accelerator still sees the requester (TAG), the DMA
//      carries the forced tag (LAST_USER); cleared -> inherit again
//   4. who sent the request: core 1 (srmcfg RCID 6, MCID 11) starts the run: TAG has source port 1 and its tag
//   5. the tag reaches the LLC: CBQRI way partitioning with the accelerator as the aggressor. Victim lines of
//      RCID 1 (ways 0-7) survive 80 aggressor DMA reads tagged RCID 2 by inheritance (ways 8-15): no LLC read
//      miss when the victims are read again; with the policy forcing the aggressor to RCID 1 they are evicted
// The simulation's QoS scoreboard prints the user fields the socket presented at the LLC ("[QOS] llc_in socket").
#include "accel.h"

#define SLOT      0
#define N         16
#define ARG       7u
#define CC        0x10401800UL           // LLC CBQRI capacity controller
#define CC_ALLOC  0x18
#define CC_MASK   0x20
#define OP_CONFIG 1
#define REGION    0x80400000UL           // LLC-cached DRAM not used by the program
#define SET_STEP  0x10000UL              // lines 64 KB apart share an LLC set (and an L1 set)
#define L1_STEP   0x800UL                // lines 2 KB apart share an L1 set but not an LLC set
#define SOC_CTRL      0x1A106000UL
#define LLC_CNT_EN    0x04
#define LLC_RD_MISS   0x08

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")
static inline uint64_t srmcfg(unsigned r, unsigned m) { return r | ((uint64_t)m << 16); }
static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }

ACCEL_BUF static volatile uint64_t src[N], dst[N], agg_dst[2];
SOC_SRAM static volatile uint32_t hart1_go, hart1_done;

static void setup(uint64_t s, uint64_t d, uint32_t n) {
  accel_wr64(SLOT, 0x08, s); accel_wr64(SLOT, 0x10, d); accel_wr(SLOT, 0x18, n); accel_wr(SLOT, 0x1C, ARG);
}
// START, wait for DONE, clear it; returns 0 or -1
static int run(void) {
  accel_wr(SLOT, 0x00, 0x1);
  if (accel_wait(SLOT, 0x04, 0x3, 0x2, 1000000) != 0) return -1;
  accel_wr(SLOT, 0x04, 0x2);
  return 0;
}

// core 1 starts a run with its own srmcfg, once core 0 says so
int thread_entry(int cid, int nc) {
  (void)nc;
  if (cid == 0) return 0;
  soc_install_trap_guard();
  if (cid == 1) {
    while (!hart1_go) __asm__ volatile("nop");
    SRMCFG_W(srmcfg(6, 11));
    accel_wr(SLOT, 0x00, 0x1);
    hart1_done = 1;
  }
  while (1) __asm__ volatile("wfi");
}

// ---- LLC isolation with the accelerator as the aggressor (as in t_cbqri, which uses a core)
static void set_limit(unsigned rcid, unsigned at, uint32_t mask) {
  REG32(CC + CC_MASK) = mask;
  REG32(CC + CC_ALLOC) = OP_CONFIG | (at << 5) | (rcid << 8);
  uint32_t st = REG32(CC + CC_ALLOC + 4) & 0x7F;
  CHECK(st == 1, "CONFIG_LIMIT rcid %d mask 0x%x: status %d", rcid, mask, st);
}
static void l1_sweep(uint64_t off) {
  uint64_t s = 0;
  for (int j = 1, n = 0; n < 64; j++) {
    if (j % 32 == 0) continue;
    s += ld(REGION + 0x200000UL + off + j * L1_STEP);
    n++;
  }
  __asm__ volatile("" :: "r"(s));
}
// 8 victim lines of RCID rv in LLC set `off`, then 2 x 40 aggressor lines read by the accelerator under RCID ra
// (inherited from this hart's srmcfg; the socket's policy may override it); returns the LLC read misses while the
// victims are read again
static uint32_t isolation_dma(uint64_t off, unsigned rv, unsigned ra) {
  uint64_t s = 0;
  SRMCFG_W(srmcfg(rv, 0));
  for (int k = 0; k < 8; k++) s += ld(REGION + off + k * SET_STEP);
  SRMCFG_W(srmcfg(ra, 0));
  for (int r = 0; r < 2; r++)
    for (int k = 8; k < 48; k++) {
      setup(REGION + off + k * SET_STEP, (uintptr_t)agg_dst, 1);
      if (run() != 0) { CHECK(0, "aggressor DMA of line %d never finished", k); return 0xFFFF; }
    }
  l1_sweep(off);
  SRMCFG_W(srmcfg(rv, 0));
  uint32_t m0 = REG32(SOC_CTRL + LLC_RD_MISS);
  for (int k = 0; k < 8; k++) s += ld(REGION + off + k * SET_STEP);
  uint32_t m = REG32(SOC_CTRL + LLC_RD_MISS) - m0;
  __asm__ volatile("" :: "r"(s));
  return m;
}

int main(void) {
  soc_test_begin("t_iotag");
  CHECK(accel_rd(SLOT, 0x20) == 0xAC0C9B9Fu, "slot 0 ID 0x%x (expected the example engine)", accel_rd(SLOT, 0x20));
  REG32(SOC_CTRL + LLC_CNT_EN) = 1;

  // ---- 1. probe and policy registers
  SRMCFG_W(srmcfg(5, 3));
  uint32_t probe = REG32(ACCEL_QOS_PROBE);
  CHECK(probe == ACCEL_USER(0, 5, 3), "QoS probe 0x%x, expected 0x%x", probe, ACCEL_USER(0, 5, 3));
  CHECK(REG32(ACCEL_TAG_POLICY(SLOT)) == 0, "TAG_POLICY(0) at reset = 0x%x", REG32(ACCEL_TAG_POLICY(SLOT)));
  CHECK(REG32(ACCEL_LAST_USER(SLOT)) == 0, "LAST_USER(0) before any DMA = 0x%x", REG32(ACCEL_LAST_USER(SLOT)));
  for (int i = 0; i < N; i++) { src[i] = 0x5000 + i; dst[i] = 0; }
  setup((uintptr_t)src, (uintptr_t)dst, N);

  // ---- 2. inherit the requester's tag
  CHECK(run() == 0, "run 1 (srmcfg RCID 5 MCID 3) finished");
  uint32_t tag = accel_rd(SLOT, ACCEL_TAG_REG), last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(tag == ACCEL_USER(0, 5, 3), "TAG after START by core 0 with RCID 5 / MCID 3: 0x%x, expected 0x%x", tag, ACCEL_USER(0, 5, 3));
  CHECK(last == ACCEL_USER(0, 5, 3), "LAST_USER (the DMA's user field): 0x%x, expected 0x%x", last, ACCEL_USER(0, 5, 3));
  int ok = 1;
  for (int i = 0; i < N; i++) if (dst[i] != src[i] + ARG) ok = 0;
  CHECK(ok, "run 1 data correct");
  SRMCFG_W(srmcfg(9, 1));
  CHECK(run() == 0, "run 2 (srmcfg RCID 9 MCID 1) finished");
  tag = accel_rd(SLOT, ACCEL_TAG_REG); last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(tag == ACCEL_USER(0, 9, 1), "TAG follows the new srmcfg: 0x%x, expected 0x%x", tag, ACCEL_USER(0, 9, 1));
  CHECK(last == ACCEL_USER(0, 9, 1), "LAST_USER follows: 0x%x, expected 0x%x", last, ACCEL_USER(0, 9, 1));
  printf("inherit: TAG 0x%x LAST_USER 0x%x (port 0, RCID 9, MCID 1)\r\n", tag, last);

  // ---- 3. the socket forces a tag
  REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_FORCE | ACCEL_USER(0, 12, 2);
  uint32_t pol = REG32(ACCEL_TAG_POLICY(SLOT));
  CHECK(pol == (ACCEL_POLICY_FORCE | ACCEL_USER(0, 12, 2)), "TAG_POLICY readback 0x%x", pol);
  CHECK(run() == 0, "run 3 (forced) finished");
  tag = accel_rd(SLOT, ACCEL_TAG_REG); last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(tag == ACCEL_USER(0, 9, 1), "forced: the accelerator still sees the requester (TAG 0x%x)", tag);
  CHECK(last == ACCEL_USER(0, 12, 2), "forced: the DMA carries the policy's tag (LAST_USER 0x%x, expected 0x%x)", last, ACCEL_USER(0, 12, 2));
  REG32(ACCEL_TAG_POLICY(SLOT)) = 0;
  CHECK(run() == 0, "run 4 (policy cleared) finished");
  last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(last == ACCEL_USER(0, 9, 1), "policy cleared: inherit again (LAST_USER 0x%x)", last);
  printf("force: LAST_USER 0x%x while forced to (RCID 12, MCID 2), TAG still 0x%x\r\n", ACCEL_USER(0, 12, 2), tag);

  // ---- 4. another hart starts the run: the tag names it
  hart1_done = 0;
  __asm__ volatile("fence" ::: "memory");
  hart1_go = 1;
  int t;
  for (t = 0; t < 2000000 && !hart1_done; t++) __asm__ volatile("nop");
  CHECK(hart1_done, "core 1 started the run");
  CHECK(accel_wait(SLOT, 0x04, 0x3, 0x2, 1000000) == 0, "run 5 (started by core 1) finished");
  accel_wr(SLOT, 0x04, 0x2);
  tag = accel_rd(SLOT, ACCEL_TAG_REG); last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(tag == ACCEL_USER(1, 6, 11), "TAG after START by core 1 (RCID 6, MCID 11): 0x%x, expected 0x%x", tag, ACCEL_USER(1, 6, 11));
  CHECK(last == ACCEL_USER(0, 6, 11), "LAST_USER (port bits cleared): 0x%x, expected 0x%x", last, ACCEL_USER(0, 6, 11));
  printf("who: core 1 started it, TAG 0x%x = port 1, RCID 6, MCID 11\r\n", tag);

  // ---- 5. the tag reaches the LLC: way partitioning against accelerator DMA
  set_limit(1, 0, 0x00FF);                                     // victims: ways 0-7
  set_limit(2, 0, 0xFF00);                                     // aggressor by inheritance: ways 8-15
  (void)isolation_dma(0x0C0, 12, 13);                          // warm-up: this code into the LLC
  uint32_t m_part = isolation_dma(0x000, 1, 2);
  REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_FORCE | ACCEL_USER(0, 1, 0);   // the aggressor forced into RCID 1
  uint32_t m_forced = isolation_dma(0x040, 1, 2);
  REG32(ACCEL_TAG_POLICY(SLOT)) = 0;
  set_limit(1, 0, 0xFFFF);
  set_limit(2, 0, 0xFFFF);
  SRMCFG_W(0);
  printf("LLC: victims re-read with %u misses when the DMA inherits RCID 2 (disjoint ways), %u when forced to RCID 1\r\n",
         m_part, m_forced);
  CHECK(m_part <= 2, "partitioned: %u LLC read misses on the 8 victims (expected 0, slack 2)", m_part);
  CHECK(m_forced >= 4, "forced into the victims' ways: %u LLC read misses on the 8 victims (expected ~8)", m_forced);
  return soc_test_end();
}
