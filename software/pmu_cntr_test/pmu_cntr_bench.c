/*
 * pmu_cntr_bench.c: the APMU's per-core request counters, with N = SOC_NUM_CORES cores (built with
 * -DSOC_NUM_CORES=<n> for an n-core SoC). Self-checking (software/soc_tests/include/soc_test.h): exit code = failed
 * checks.
 *
 * Wakeup:
 *   Core 1      : woken by the startup code (mailbox IRQ)
 *   Cores 2..N-1: soc_wake_all(): PMU counter k's overflow raises PLIC IRQ 156 + k for core k + 2; the counters are
 *                 released once the cores have started
 *
 * PMU event counters (quad_boot/pmu_defines.h), configured by core 0 once every core has started:
 *   Ctr 4c+0  : LLC RD request, core c (the SPU on core c's port, APMU port N+1+c)
 *   Ctr 4c+1  : LLC WR request, core c
 *   Ctr 4c+2  : MEM RD request, core c (the SPU on the LLC's memory port, port 2N+1, source c)
 *   Ctr 4c+3  : MEM WR request, core c
 *   Ctr 4N, 4N+1: MEM RD / WR request, every source (up to seven cores: eight fill all 32 counters with the above)
 *
 * Traffic: each core traverses its own 64 KB of DRAM outside the LLC window (the LLC passes it through), the
 *   LINES 64-byte lines below 0x82000000 + hartid * 0x01000000 (no overlap between cores), one LD + SD per line,
 *   while the others wait in the uncached on-chip SRAM. So each line is a read that misses L1 and goes on to DRAM, and
 *   the stores leave the lines dirty in L1, which writes back the ones it evicts (16 KB, 8 ways of 16-byte lines: the
 *   lines fall in 32 sets, so about 3/4 of them during the traversal).
 * Checks, for each core: every line read on its port and in DRAM (at least LINES; at most half again on its port, for
 *   its instruction fetches and stack), at least half of them written back, nothing in DRAM that did not pass its
 *   port, and (with the every-source counters) nothing in DRAM credited to anyone else. A source credited to the wrong
 *   core leaves one core short and another over.
 * The counts are what changed between two snapshots of all counters, after the setup and once the traffic has
 *   settled, each read until two reads in a row agree: the counters are cleared and read one at a time, and core 0's
 *   own fetches and write-backs while that happens would otherwise land in some counters and not in others
 *   (2026-10-28, four cores: the cores' DRAM reads added up to 2 more than every source's, the writes to 1 fewer).
 *   Expected with four cores: per core 1024 DRAM reads and 768 write-backs (32 sets, 24 evictions each), core 0 a few
 *   more for its code and stack.
 */

#include "soc_test.h"

#define NC          SOC_NUM_CORES
#define LINES       1024
#define AREA(c)     (0x82000000UL + (uint64_t)(c) * 0x01000000UL)   // the top of core c's lines
#define NCTR_CORE   (4 * NC)
#define HAS_ALL     (NCTR_CORE + 2 <= NUM_COUNTER)   // room for the every-source counters
#define NCTR        (NCTR_CORE + 2 * HAS_ALL)
#define CTR_ALL     NCTR_CORE                        // MEM RD / WR request of every source: CTR_ALL, CTR_ALL + 1
#define SETTLE      10000          // cycles for write-backs and counter updates to land before the last snapshot
#define DONE_CYCLES 50000000ULL    // bound on the wait for the cores' traversals
#define SNAP_ROUNDS 8
#if NCTR_CORE > NUM_COUNTER
#error "pmu_cntr_bench needs more counters than the APMU has"
#endif

enum { LLC_RD, LLC_WR, MEM_RD, MEM_WR };
static const char *ctr_name[4] = { "LLC_RD", "LLC_WR", "MEM_RD", "MEM_WR" };

SOC_SRAM static volatile uint32_t pmu_go, done_mask;
// the counters before and after the traffic, and a second read of them: uncached, so taking a snapshot evicts
// nothing from L1 (with every set of the traversal full of dirty lines, a stack store would cost a write-back)
SOC_SRAM static volatile uint32_t before[NCTR], after[NCTR], snap_w[NCTR];
static uint32_t woke;
static int snap_ok = 1;

static void ctr_setup(void) {
  for (int i = 0; i < NCTR; i++) {
    uint32_t sel;
    if (i >= CTR_ALL) sel = i == CTR_ALL ? MEM_RD_REQ : MEM_WR_REQ;
    else switch (i % 4) {
      case LLC_RD: sel = LLC_RD_REQ_CORE(i / 4); break;
      case LLC_WR: sel = LLC_WR_REQ_CORE(i / 4); break;
      case MEM_RD: sel = MEM_RD_REQ_CORE(i / 4); break;
      default:     sel = MEM_WR_REQ_CORE(i / 4); break;
    }
    REG32(EVENT_SEL_BASE_ADDR  + i * COUNTER_BUNDLE_SIZE) = sel;
    REG32(EVENT_INFO_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;   // count only, no overflow
  }
  for (int i = 0; i < NCTR; i++) REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  __asm__ volatile("fence iorw, iorw" ::: "memory");
}

// every counter at one moment: read them all until two reads in a row agree; returns 0 if they did not settle
static int ctr_snap(volatile uint32_t *v) {
  int same, n = 0;
#pragma GCC unroll 1
  do {
    for (int i = 0; i < NCTR; i++) v[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    for (int i = 0; i < NCTR; i++) snap_w[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    same = 1;
    for (int i = 0; i < NCTR; i++) same &= v[i] == snap_w[i];
  } while (!same && ++n < SNAP_ROUNDS);
  return same;
}

static void traverse_array(int c) {
  volatile uint64_t *arr = (volatile uint64_t *)AREA(c);
  uint64_t var = 0;
  for (int i = 0; i < LINES; i++) {   // 8 words = one 64-byte line apart, downwards
    __asm__ volatile("ld %0, 0(%1)" : "=r"(var) : "r"(arr - 8 * i) : "memory");
    __asm__ volatile("sd %0, 0(%1)" :: "r"(var), "r"(arr - 8 * i) : "memory");
  }
  __asm__ volatile("fence iorw, iorw" ::: "memory");
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("pmu_cntr_bench");
    woke = soc_wake_all();
    printf("cores 0-%d, %d lines each, counted by counters 0-%d; starting traffic\r\n", NC - 1, LINES, NCTR - 1);
    uart_wait_tx_done();
    ctr_setup();                    // after soc_wake_all, which uses the first counters and then releases them
    snap_ok &= ctr_snap(before);
    return 0;                       // core 0 continues in main()
  }
  while (!pmu_go) __asm__ volatile("nop");
  traverse_array(cid);
  __atomic_fetch_or(&done_mask, 1u << cid, __ATOMIC_SEQ_CST);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  const uint32_t all = (uint32_t)((1ull << NC) - 1);
  uint32_t v[NCTR];

  pmu_go = 1;
  __asm__ volatile("fence iorw, iorw" ::: "memory");
  traverse_array(0);
  __atomic_fetch_or(&done_mask, 1u, __ATOMIC_SEQ_CST);
  uint64_t t0 = soc_cycles();
  while (done_mask != all && soc_cycles() - t0 < DONE_CYCLES) __asm__ volatile("nop");
  t0 = soc_cycles();
  while (soc_cycles() - t0 < SETTLE) ;
  snap_ok &= ctr_snap(after);
  for (int i = 0; i < NCTR; i++) v[i] = after[i] - before[i];

  printf("\r\n=== PMU Counter Results (%d cores, cache lines/core=%d) ===\r\n", NC, LINES);
  for (int i = 0; i < NCTR_CORE; i++)
    printf("  Ctr%d [%s_C%d]: %u\r\n", i, ctr_name[i % 4], i / 4, v[i]);
  if (HAS_ALL) {
    printf("  Ctr%d [MEM_RD_ALL]: %u\r\n", CTR_ALL, v[CTR_ALL]);
    printf("  Ctr%d [MEM_WR_ALL]: %u\r\n", CTR_ALL + 1, v[CTR_ALL + 1]);
  }
  printf("=============================================================\r\n");

  CHECK(snap_ok, "counter snapshots did not settle in %d rounds", SNAP_ROUNDS);
  CHECK(woke == SOC_WAKE_MASK, "cores woken: 0x%x, expected 0x%x", woke, SOC_WAKE_MASK);
  CHECK(done_mask == all, "cores that finished their traversal: 0x%x, expected 0x%x", done_mask, all);
  uint32_t mem_rd = 0, mem_wr = 0;
  for (int c = 0; c < NC; c++) {
    const uint32_t *d = &v[4 * c];
    mem_rd += d[MEM_RD];
    mem_wr += d[MEM_WR];
    CHECK(d[LLC_RD] >= LINES && d[LLC_RD] <= LINES + LINES / 2,
          "core %d: %u read requests on its port, expected %d to %d", c, d[LLC_RD], LINES, LINES + LINES / 2);
    CHECK(d[MEM_RD] >= LINES && d[MEM_RD] <= d[LLC_RD],
          "core %d: %u DRAM reads credited to it, expected %d to its %u port reads", c, d[MEM_RD], LINES, d[LLC_RD]);
    CHECK(d[LLC_WR] >= LINES / 2 && d[LLC_WR] <= LINES + LINES / 2,
          "core %d: %u write requests on its port, expected %d to %d", c, d[LLC_WR], LINES / 2, LINES + LINES / 2);
    CHECK(d[MEM_WR] >= LINES / 2 && d[MEM_WR] <= d[LLC_WR],
          "core %d: %u DRAM writes credited to it, expected %d to its %u port writes", c, d[MEM_WR], LINES / 2,
          d[LLC_WR]);
  }
  if (HAS_ALL)
    CHECK(v[CTR_ALL] == mem_rd && v[CTR_ALL + 1] == mem_wr,
          "DRAM requests of every source: %u reads and %u writes, the cores' add up to %u and %u", v[CTR_ALL],
          v[CTR_ALL + 1], mem_rd, mem_wr);
  return soc_test_end();
}
