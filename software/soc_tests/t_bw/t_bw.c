// t_bw: streaming cost of the coherent path, in cycles per 16-byte line, for 1 .. SOC_NUM_CORES harts at once.
// The numbers calibrate the CCU performance model (hardware/docs/ccu_model.md) and measure its changes.
//
// Every hart owns a region of cached DRAM (LINES lines of 16 bytes, less than the 16 KB L1). Before each window
// every hart flushes its L1 with fence.i (CVA6 writes back and invalidates the whole data cache on fence.i; a plain
// fence does not flush a coherent cache), so each
// access of the window misses L1 once; the regions together are far below the 1 MiB LLC and a warm-up pass has
// filled it, so the misses are LLC hits. Harts that do not take part in a window spin on a cached flag (L1 hits,
// no coherence traffic) so the measured harts see only each other.
//   mode rd:   loads of the own region, one per line               -> ReadShared, data from the LLC
//   mode wr:   stores to the own region, one per line               -> ReadUnique, data from the LLC; the fence that
//              follows writes the LINES dirty lines back            -> WriteBack per line (timed as that fence)
//   mode sh:   loads of hart 0's region by all active harts         -> ReadShared answered by another L1 (snoop data)
// For k = 1, 2, 4, 8 (and SOC_NUM_CORES) harts 0..k-1 run the window together; each records rdcycle around it in
// SRAM and hart 0 prints
//   [BW] k=<k> <mode> hart <h>: <cycles> cycles = <c> cycles/line            (one line per active hart)
//   [BW] k=<k> <mode> aggregate: <k*LINES> lines in <max cycles> cycles = <c> cycles/line, <B/kcycle> B/kcycle
//   [BW] k=<k> wb hart <h>: fence <cycles> cycles = <c> cycles/line           (the flush after a write window)
// Checks: every hart completes, the harts of a shared window read the same data, and every region holds what its
// hart's last write window stored. Build with -DSOC_NUM_CORES=<n>; -DLINES=<n> changes the window (default 256 lines
// = 4 KB; keep it below the L1).
#include "soc_test.h"

#define NC      SOC_NUM_CORES
#ifndef LINES
#define LINES   256
#endif
#define NMODES  3
#define MAXK    5
enum { M_RD = 0, M_WR = 1, M_SH = 2 };
static const char *mode_name[NMODES] = { "rd", "wr", "sh" };

static volatile uint64_t region[NC][LINES * 2] __attribute__((aligned(64)));   // cached DRAM, one 16-byte line per 2 words
static volatile uint32_t go_gen __attribute__((aligned(64)));                   // cached barrier generation (spun on)
SOC_SRAM static volatile uint32_t arrive;                                       // barrier arrival counter (atomics, SRAM)
SOC_SRAM static volatile uint32_t win_cyc[NC][MAXK][NMODES];                    // window cycles [hart][k index][mode]
SOC_SRAM static volatile uint32_t fence_cyc[NC][MAXK][NMODES];                  // cycles of the fence before the window
SOC_SRAM static volatile uint32_t done_cnt[NC];
SOC_SRAM static volatile uint64_t sums[NC][MAXK][NMODES];
SOC_SRAM static volatile int ks[MAXK];
SOC_SRAM static volatile int nks;

static inline void bw_fence(void) { __asm__ volatile("fence.i" ::: "memory"); }   // fence.i flushes the write-back D$ (fence does not: the cache is coherent)

// sense-free barrier: arrival in SRAM, waiting on a cached generation flag (L1 hits while spinning)
static void bw_barrier(void) {
  uint32_t g = go_gen;
  if (__atomic_fetch_add(&arrive, 1, __ATOMIC_SEQ_CST) == (uint32_t)NC - 1) {
    arrive = 0;
    __atomic_store_n(&go_gen, g + 1, __ATOMIC_SEQ_CST);
  } else {
    while (go_gen == g) __asm__ volatile("nop");
  }
}

static uint64_t window(int cid, int mode, int k) {
  volatile uint64_t *r = (mode == M_SH) ? region[0] : region[cid];
  uint64_t s = 0;
  if (mode == M_WR) {
    for (int i = 0; i < LINES; i++) r[2 * i] = ((uint64_t)(cid + 1) << 32) | ((uint64_t)k << 16) | (uint64_t)i;
  } else {
    for (int i = 0; i < LINES; i++) s += r[2 * i];
  }
  return s;
}

static void run(int cid) {
  if (cid == 0) {
    int n = 0;
    for (int k = 1; k <= NC && n < MAXK; k *= 2) ks[n++] = k;
    if (ks[n - 1] != NC && n < MAXK) ks[n++] = NC;
    nks = n;
  }
  // warm up: own region in the LLC
  for (int i = 0; i < LINES; i++) region[cid][2 * i] = ((uint64_t)cid << 32) | (uint64_t)i;
  bw_fence();
  bw_barrier();
  for (int j = 0; j < nks; j++) {
    int k = ks[j];
    for (int mode = 0; mode < NMODES; mode++) {
      if (cid == 0) { printf("[BW] phase k=%d %s\r\n", k, mode_name[mode]); uart_wait_tx_done(); }
      uint64_t t0 = soc_cycles();
      bw_fence();                                                   // flush: writes the previous window's lines back
      uint64_t t1 = soc_cycles();
      fence_cyc[cid][j][mode] = (uint32_t)(t1 - t0);
      bw_barrier();
      if (cid < k) {
        __asm__ volatile("" ::: "memory");
        uint64_t a = soc_cycles();
        uint64_t s = window(cid, mode, k);
        uint64_t b = soc_cycles();
        __asm__ volatile("" ::: "memory");
        win_cyc[cid][j][mode] = (uint32_t)(b - a);
        sums[cid][j][mode] = s;
      }
      bw_barrier();
    }
  }
  done_cnt[cid] = 1;
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_bw");
    soc_wake_all();
    run(0);
    return 0;
  }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  for (int c = 0; c < NC; c++) CHECK(done_cnt[c] == 1, "core %d finished", c);
  for (int j = 0; j < nks; j++) {
    int k = ks[j];
    for (int mode = 0; mode < NMODES; mode++) {
      uint32_t maxc = 0;
      for (int c = 0; c < k; c++) {
        uint32_t cyc = win_cyc[c][j][mode];
        if (cyc > maxc) maxc = cyc;
        printf("[BW] k=%d %s hart %d: %u cycles = %u cycles/line\r\n", k, mode_name[mode], c, cyc, cyc / LINES);
        CHECK(cyc > 0 && cyc < 0x40000000u, "k=%d %s hart %d window cycles %u", k, mode_name[mode], c, cyc);
        if (mode == M_SH)
          CHECK(sums[c][j][M_SH] == sums[0][j][M_SH] && sums[0][j][M_SH] != 0,
                "k=%d sh hart %d sum %08x%08x, hart 0 %08x%08x", k, c, H64(sums[c][j][M_SH]), H64(sums[0][j][M_SH]));
      }
      unsigned bpk = maxc ? (unsigned)(((uint64_t)k * LINES * 16 * 1000) / maxc) : 0;
      printf("[BW] k=%d %s aggregate: %d lines in %u cycles = %u cycles/line, %u B/kcycle\r\n", k, mode_name[mode],
             k * LINES, maxc, maxc / (k * LINES), bpk);
      if (mode == M_WR)
        for (int c = 0; c < k; c++)                                // the fence before the sh window wrote them back
          printf("[BW] k=%d wb hart %d: fence %u cycles = %u cycles/line\r\n", k, c, fence_cyc[c][j][M_SH],
                 fence_cyc[c][j][M_SH] / LINES);
    }
  }
  printf("[BW] clean fence (no dirty lines), hart 0: %u cycles\r\n", fence_cyc[0][0][M_RD]);
  // every region holds its hart's last write window (k = NC, every hart took part)
  for (int c = 0; c < NC; c++) {
    int bad = 0;
    for (int i = 0; i < LINES; i++)
      if (region[c][2 * i] != ((((uint64_t)(c + 1)) << 32) | ((uint64_t)NC << 16) | (uint64_t)i)) bad++;
    CHECK(bad == 0, "region of hart %d: %d lines differ from its last write window", c, bad);
  }
  return soc_test_end();
}
