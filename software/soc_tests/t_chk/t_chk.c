// t_chk: data-integrity stress of the coherent path under load, every core at once. Each core owns a private
// region of cached DRAM larger than its L1 (so every pass evicts and writes back lines), fills it with a pattern
// that encodes the word index, the round and the core, copies it to a second region and verifies every word of
// both, round after round, while the other cores do the same. A mismatch is reported with its address, the value
// read, the value expected and the other word of its 16-byte line (a stale value from an earlier round means a
// lost store or a stale refill).
//   -DSOC_NUM_CORES=<n>; -DCHK_WORDS=<words per region> (default 4096 = 32 KB in simulation, 65536 = 512 KB on
//   the board, where the regions sit at CHK_BASE in DRAM instead of .bss); -DCHK_ROUNDS (default 3 / 40)
//   -DCHK_MODE=0 plain write pass (default); 1: every stored word is read back at once (an L1 hit: a store merge
//   lost in the refill shows here); 2: the write pass goes in batches of CHK_BATCH lines, each batch flushed with
//   fence.i (write-backs) and read back (refetched from the LLC: a stale word here was lost in the write-back or
//   returned stale by the LLC), and a stale word is read once more after another flush to tell a stale LLC copy
//   from a transient wrong read
//   -DCHK_TRAFFIC=0 every core checks (default); 1: cores 1.. only load their region round after round
//   (ReadShared refills, no write-backs); 2: cores 1.. only store it (ReadUnique refills and write-backs)
//   -DCHK_SHARED=1 every core also touches a 32 KB array shared by all cores while it streams through its private
//   region (one shared line per private line, one in eight a store): snoops then hit in the other cores' L1s,
//   including lines a core is evicting for its own refill, as under Linux (kernel data), where the words were lost;
//   2: the shared lines are only loaded (only ReadShared snoops hit); 3: only stored (only invalidating snoops hit)
// The on-board version (Linux, software bw/chk.c in the session scratchpad) found single stale words with eight
// harts on the decoupled CCU (2026-10-25); this is its bare-metal twin for xsim and the board.
#include "soc_test.h"

#define NC SOC_NUM_CORES
#ifndef CHK_WORDS
#ifdef FPGA_EMULATION
#define CHK_WORDS 65536
#else
#define CHK_WORDS 4096
#endif
#endif
#ifndef CHK_ROUNDS
#ifdef FPGA_EMULATION
#define CHK_ROUNDS 40
#else
#define CHK_ROUNDS 3
#endif
#endif
#ifndef CHK_MODE
#define CHK_MODE 0
#endif
#ifndef CHK_TRAFFIC
#define CHK_TRAFFIC 0
#endif
#ifndef CHK_SHARED
#define CHK_SHARED 0
#endif
#define CHK_BATCH 256   /* lines per flushed batch (CHK_MODE 2) */
#define SH_LINES 2048   /* shared array: 32 KB, the size of the L1 */

#ifdef FPGA_EMULATION
// on the board the regions live in DRAM above the program (the ELF's .bss is zeroed over JTAG and its vector table
// must stay within a JAL of the code, so megabytes of arrays cannot be linked in)
#define CHK_BASE 0x90000000ULL
#define REGION_A(c) ((volatile uint64_t *)(CHK_BASE + (uint64_t)(c) * 2 * CHK_WORDS * 8))
#define REGION_B(c) ((volatile uint64_t *)(CHK_BASE + ((uint64_t)(c) * 2 + 1) * CHK_WORDS * 8))
#define SHARED ((volatile uint64_t *)(CHK_BASE + 0x1000000ULL))
#else
static volatile uint64_t shared_lines[SH_LINES * 2] __attribute__((aligned(64)));
#define SHARED shared_lines
static volatile uint64_t region_a[NC][CHK_WORDS] __attribute__((aligned(64)));
static volatile uint64_t region_b[NC][CHK_WORDS] __attribute__((aligned(64)));
#define REGION_A(c) region_a[c]
#define REGION_B(c) region_b[c]
#endif
static volatile uint32_t go_gen __attribute__((aligned(64)));
SOC_SRAM static volatile uint32_t arrive;
SOC_SRAM static volatile uint32_t bad[NC], imm_bad[NC], post_bad[NC], post_persist[NC], post_transient[NC], done_cnt[NC];
SOC_SRAM static volatile uint64_t first_bad_addr[NC], first_bad_got[NC], first_bad_want[NC], first_other_got[NC], first_other_want[NC];
SOC_SRAM static volatile uint32_t first_bad_round[NC], first_bad_kind[NC];
SOC_SRAM static volatile uint64_t cycles[NC];
static const char *kind_name[] = {"", "read-back", "post-flush", "verify-a", "verify-b"};

static void chk_barrier(void) {
  uint32_t g = go_gen;
  if (__atomic_fetch_add(&arrive, 1, __ATOMIC_SEQ_CST) == (uint32_t)NC - 1) { arrive = 0; __atomic_store_n(&go_gen, g + 1, __ATOMIC_SEQ_CST); }
  else while (go_gen == g) __asm__ volatile("nop");
}
static inline uint64_t pat(uint64_t i, uint64_t round, uint64_t core) {
  return (i * 0x9E3779B97F4A7C15ULL) ^ (round << 56) ^ (core << 48);
}
static inline void flush(void) { __asm__ volatile("fence.i" ::: "memory"); }
// CHK_SHARED: one access to the shared array per private line, a store on every eighth line (per core a
// different eighth), so the other cores see snoop hits on lines they hold and sometimes are evicting
static inline void sh_touch(int cid, int i) {
#if CHK_SHARED
  if (!(i & 1)) {
    volatile uint64_t *s = &SHARED[(((i >> 1) + cid * 97) & (SH_LINES - 1)) * 2];
#if CHK_SHARED == 2
    (void)*s;
#elif CHK_SHARED == 3
    *s = (uint64_t)i;
#else
    if (((i >> 1) & 7) == (cid & 7)) *s = (uint64_t)i; else (void)*s;
#endif
  }
#else
  (void)cid; (void)i;
#endif
}

static void record(int cid, int kind, int r, volatile uint64_t *p, int i, uint64_t got, uint64_t want) {
  if (!bad[cid]) {
    first_bad_kind[cid] = kind; first_bad_round[cid] = r; first_bad_addr[cid] = (uint64_t)&p[i];
    first_bad_got[cid] = got; first_bad_want[cid] = want;
    first_other_got[cid] = p[i ^ 1]; first_other_want[cid] = pat(i ^ 1, r, cid);
  }
  bad[cid]++;
}

static void run(int cid) {
  volatile uint64_t *a = REGION_A(cid), *b = REGION_B(cid);
  chk_barrier();
  uint64_t t0 = soc_cycles();
  for (int r = 0; r < CHK_ROUNDS; r++) {
#if CHK_TRAFFIC == 1
    if (cid) { uint64_t s = 0; for (int i = 0; i < CHK_WORDS; i++) s += a[i]; b[0] = s; continue; }
#elif CHK_TRAFFIC == 2
    if (cid) { for (int i = 0; i < CHK_WORDS; i++) a[i] = pat(i, r, cid); continue; }
#endif
#if CHK_MODE == 1
    for (int i = 0; i < CHK_WORDS; i++) {
      uint64_t w = pat(i, r, cid); sh_touch(cid, i); a[i] = w; uint64_t g = a[i];
      if (g != w) { imm_bad[cid]++; record(cid, 1, r, a, i, g, w); }
    }
#elif CHK_MODE == 2
    for (int i0 = 0; i0 < CHK_WORDS; i0 += 2 * CHK_BATCH) {
      int i1 = i0 + 2 * CHK_BATCH < CHK_WORDS ? i0 + 2 * CHK_BATCH : CHK_WORDS;
      for (int i = i0; i < i1; i++) { sh_touch(cid, i); a[i] = pat(i, r, cid); }
      flush();
      for (int i = i0; i < i1; i++) {
        uint64_t w = pat(i, r, cid), g = a[i];
        if (g != w) {
          post_bad[cid]++; record(cid, 2, r, a, i, g, w);
          flush();
          if (a[i] != w) post_persist[cid]++; else post_transient[cid]++;
        }
      }
    }
#else
    for (int i = 0; i < CHK_WORDS; i++) { sh_touch(cid, i); a[i] = pat(i, r, cid); }
#endif
    for (int i = 0; i < CHK_WORDS; i++) { sh_touch(cid, i); b[i] = a[i]; }
    for (int p = 0; p < 2; p++)
      for (int i = 0; i < CHK_WORDS; i++) {
        uint64_t want = pat(i, r, cid), ga = a[i], gb = b[i];
        if (ga != want) record(cid, 3, r, a, i, ga, want);
        if (gb != want) record(cid, 4, r, b, i, gb, want);
      }
  }
  cycles[cid] = soc_cycles() - t0;
  done_cnt[cid] = 1;
  chk_barrier();
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) { soc_test_begin("t_chk"); soc_wake_all(); run(0); return 0; }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  printf("t_chk: %d cores, mode %d, traffic %d, shared %d, %d rounds, %d words per region, batch %d lines\r\n", NC, CHK_MODE,
         CHK_TRAFFIC, CHK_SHARED, CHK_ROUNDS, CHK_WORDS, CHK_BATCH);
  for (int c = 0; c < NC; c++) CHECK(done_cnt[c] == 1, "core %d finished", c);
  for (int c = 0; c < NC; c++) {
    printf("core %d: %u bad (read-back %u, post-flush %u: persistent %u transient %u), %u k cycles\r\n", c, bad[c], imm_bad[c],
           post_bad[c], post_persist[c], post_transient[c], (unsigned)(cycles[c] / 1000));
    if (bad[c])
      printf("  first: %s round %u at %08x%08x got %08x%08x want %08x%08x | other word got %08x%08x want %08x%08x\r\n",
             kind_name[first_bad_kind[c] < 5 ? first_bad_kind[c] : 0], first_bad_round[c], H64(first_bad_addr[c]),
             H64(first_bad_got[c]), H64(first_bad_want[c]), H64(first_other_got[c]), H64(first_other_want[c]));
    CHECK(bad[c] == 0, "core %d: %u bad words", c, bad[c]);
  }
  return soc_test_end();
}
