// t_chk: data-integrity stress of the coherent path under load, every core at once. Each core owns a private
// region of cached DRAM larger than its L1 (so every pass evicts and writes back lines), fills it with a pattern
// that encodes the word index, the round and the core, copies it to a second region and verifies every word of
// both, round after round, while the other cores do the same. A mismatch is reported with its address, the value
// read and the value expected (a stale value from an earlier round means a lost store or a stale refill).
//   -DSOC_NUM_CORES=<n>; -DCHK_WORDS=<words per region> (default 4096 = 32 KB, twice the L1); -DCHK_ROUNDS (default 3)
// The on-board version (Linux, software bw/chk.c in the session scratchpad) found single stale words with eight
// harts on the decoupled CCU (2026-10-25); this is its bare-metal twin for xsim.
#include "soc_test.h"

#define NC SOC_NUM_CORES
#ifndef CHK_WORDS
#define CHK_WORDS 4096
#endif
#ifndef CHK_ROUNDS
#define CHK_ROUNDS 3
#endif

static volatile uint64_t region_a[NC][CHK_WORDS] __attribute__((aligned(64)));
static volatile uint64_t region_b[NC][CHK_WORDS] __attribute__((aligned(64)));
static volatile uint32_t go_gen __attribute__((aligned(64)));
SOC_SRAM static volatile uint32_t arrive;
SOC_SRAM static volatile uint32_t bad[NC], done_cnt[NC];
SOC_SRAM static volatile uint64_t first_bad_addr[NC], first_bad_got[NC], first_bad_want[NC];
SOC_SRAM static volatile uint32_t first_bad_round[NC];

static void chk_barrier(void) {
  uint32_t g = go_gen;
  if (__atomic_fetch_add(&arrive, 1, __ATOMIC_SEQ_CST) == (uint32_t)NC - 1) { arrive = 0; __atomic_store_n(&go_gen, g + 1, __ATOMIC_SEQ_CST); }
  else while (go_gen == g) __asm__ volatile("nop");
}
static inline uint64_t pat(uint64_t i, uint64_t round, uint64_t core) {
  return (i * 0x9E3779B97F4A7C15ULL) ^ (round << 56) ^ (core << 48);
}

static void run(int cid) {
  volatile uint64_t *a = region_a[cid], *b = region_b[cid];
  chk_barrier();
  for (int r = 0; r < CHK_ROUNDS; r++) {
    for (int i = 0; i < CHK_WORDS; i++) a[i] = pat(i, r, cid);
    for (int i = 0; i < CHK_WORDS; i++) b[i] = a[i];
    for (int p = 0; p < 2; p++)
      for (int i = 0; i < CHK_WORDS; i++) {
        uint64_t want = pat(i, r, cid), ga = a[i], gb = b[i];
        if (ga != want) { if (!bad[cid]) { first_bad_addr[cid] = (uint64_t)&a[i]; first_bad_got[cid] = ga; first_bad_want[cid] = want; first_bad_round[cid] = r; } bad[cid]++; }
        if (gb != want) { if (!bad[cid]) { first_bad_addr[cid] = (uint64_t)&b[i]; first_bad_got[cid] = gb; first_bad_want[cid] = want; first_bad_round[cid] = r; } bad[cid]++; }
      }
  }
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
  for (int c = 0; c < NC; c++) CHECK(done_cnt[c] == 1, "core %d finished", c);
  for (int c = 0; c < NC; c++) {
    if (bad[c])
      printf("core %d: first bad word round %u at %08x%08x got %08x%08x want %08x%08x\r\n", c, first_bad_round[c],
             H64(first_bad_addr[c]), H64(first_bad_got[c]), H64(first_bad_want[c]));
    CHECK(bad[c] == 0, "core %d: %u bad words in %d rounds of %d words", c, bad[c], CHK_ROUNDS, CHK_WORDS);
  }
  printf("t_chk: %d cores, %d rounds, %d words per region\r\n", NC, CHK_ROUNDS, CHK_WORDS);
  return soc_test_end();
}
