// All cores (SOC_NUM_CORES, 4 unless built with -DSOC_NUM_CORES=<n>) on shared cached DRAM (coherence through
// the CCU): wake-up of all cores, a contended amoadd counter, an LR/SC increment loop, per-core cache lines
// written by their owner and read by core 0, and a message-passing ring (data then flag) between neighbouring
// cores. Only core 0 prints.
#include "soc_test.h"

#define NC    SOC_NUM_CORES
#define ITERS 40

static volatile uint64_t amo_counter  __attribute__((aligned(64)));
static volatile uint64_t lrsc_counter __attribute__((aligned(64)));
static volatile uint64_t lines[NC][8] __attribute__((aligned(64)));      // one cache line per core
static volatile uint64_t mp_data[NC][8] __attribute__((aligned(64)));
static volatile uint64_t mp_flag[NC][8] __attribute__((aligned(64)));
SOC_SRAM static volatile uint32_t seen_hart[NC];
SOC_SRAM static volatile uint64_t mp_got[NC];

static void lrsc_inc(volatile uint64_t *p) {
  uint64_t o, f;
  do {
    __asm__ volatile("lr.d %0, (%1)" : "=r"(o) : "r"(p) : "memory");
    __asm__ volatile("sc.d %0, %1, (%2)" : "=r"(f) : "r"(o + 1), "r"(p) : "memory");
  } while (f);
}

static void work(int cid) {
  seen_hart[cid] = 0x100 + soc_hartid();
  soc_barrier(NC, 1);
  for (int i = 0; i < ITERS; i++) {
    __atomic_fetch_add(&amo_counter, 1, __ATOMIC_RELAXED);
    lrsc_inc(&lrsc_counter);
  }
  for (int w = 0; w < 8; w++) lines[cid][w] = ((uint64_t)cid << 32) | w;
  soc_barrier(NC, 2);
  // ring: core c sends to core (c+1) % NC
  int to = (cid + 1) % NC, from = (cid + NC - 1) % NC;
  mp_data[to][0] = 0xABC0 + cid;
  __atomic_thread_fence(__ATOMIC_RELEASE);
  mp_flag[to][0] = 1;
  while (mp_flag[cid][0] == 0) __asm__ volatile("nop");
  __atomic_thread_fence(__ATOMIC_ACQUIRE);
  mp_got[cid] = mp_data[cid][0] | ((uint64_t)from << 32);
  soc_barrier(NC, 3);
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_smp");
    soc_wake_all();
    work(0);
    return 0;                       // core 0 continues in main()
  }
  work(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  for (int c = 0; c < NC; c++) CHECK(seen_hart[c] == 0x100u + c, "core %d reported hart 0x%x", c, seen_hart[c]);
  CHECK(amo_counter == NC * ITERS, "amoadd counter %d, expected %d", (int)amo_counter, NC * ITERS);
  CHECK(lrsc_counter == NC * ITERS, "lr/sc counter %d, expected %d", (int)lrsc_counter, NC * ITERS);
  for (int c = 0; c < NC; c++)
    for (int w = 0; w < 8; w++)
      CHECK(lines[c][w] == (((uint64_t)c << 32) | w), "line of core %d word %d = %08x%08x", c, w, H64(lines[c][w]));
  for (int c = 0; c < NC; c++) {
    int from = (c + NC - 1) % NC;
    CHECK(mp_got[c] == ((0xABC0u + from) | ((uint64_t)from << 32)), "core %d got message %08x%08x", c, H64(mp_got[c]));
  }
  return soc_test_end();
}
