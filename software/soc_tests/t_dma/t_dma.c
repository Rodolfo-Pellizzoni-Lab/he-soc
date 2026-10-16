// DMA from the accelerator socket against the cores' caches: what a device plugged into the socket (an
// accelerator, or an emulated disk / NIC / GPU driven by Linux) sees of the memory the cores wrote, and what the
// cores see of the memory the device wrote.
//
// The socket's memory port enters the host crossbar after the coherency unit (hardware/accel/README.md), so it
// is not snooped by the cores' write-back L1 data caches (cv64a6_imafdc_sv39_wb: 16 KB, 16-byte lines). In that
// configuration CVA6 treats a plain `fence` as a no-op for the data cache (the cache is coherent with the other
// cores), while `fence.i` writes back every dirty line and invalidates the whole data cache
// (core/controller.sv, INVALIDATE_ON_FLUSH). This test pins those facts down with slot 0 of the socket (`example`,
// dst[i] = src[i] + ARG, one 64-bit word in flight) and measures the cost of the maintenance:
//   1. buffers in the uncached on-chip SRAM: correct without any maintenance
//   2. source in DRAM, written by the core, plain fence: the device reads the old DRAM contents (stale)
//   3. source in DRAM, fence.i before the start: the device reads the new data
//   4. destination in DRAM already in the L1: the core reads its stale copy until a fence.i
//   5. the full recipe for DRAM buffers: fence.i before the start, fence.i after completion
// The stale cases are reported as the observed behaviour (either outcome passes, corruption fails) and the
// summary line says whether the socket's DMA is coherent with the L1, so a change of the hardware shows up here.
#include "accel.h"

#define SLOT 0
#define N    64                      // 64-bit words per buffer: 512 bytes = 32 L1 lines
#define ARG  0x11u
#define HI_BASE 0x98000000UL         // DRAM outside the cores' cacheable region (0x8000_0000 + 256 MB)

ACCEL_BUF static volatile uint64_t src_sram[N], dst_sram[N];
static volatile uint64_t src_dram[N] __attribute__((aligned(64)));
static volatile uint64_t dst_dram[N] __attribute__((aligned(64)));

static inline void fence(void)   { __asm__ volatile("fence" ::: "memory"); }
static inline void fence_i(void) { __asm__ volatile("fence.i" ::: "memory"); }

static uint64_t pat(uint32_t round, int i) { return 0x0101010100000000ULL * round + 0x1000ULL * (i + 1) + i; }

// run the engine from src to dst; returns the cycles reported by the engine, or -1 if DONE never came
static int run(uint64_t src, uint64_t dst, int n) {
  accel_wr64(SLOT, 0x08, src);
  accel_wr64(SLOT, 0x10, dst);
  accel_wr(SLOT, 0x18, n);
  accel_wr(SLOT, 0x1C, ARG);
  accel_wr(SLOT, 0x00, 0x1);                                      // START, no interrupt
  if (accel_wait(SLOT, 0x04, 0x3, 0x2, 1000000) != 0) return -1;
  accel_wr(SLOT, 0x04, 0x2);                                      // clear DONE
  return (int)accel_rd(SLOT, 0x24);
}

// how many words of dst hold old[i] + ARG (stale) / new[i] + ARG (fresh)
static void classify(volatile uint64_t *dst, uint32_t old_round, uint32_t new_round, int *stale, int *fresh) {
  *stale = *fresh = 0;
  for (int i = 0; i < N; i++) {
    if (dst[i] == pat(old_round, i) + ARG) (*stale)++;
    else if (dst[i] == pat(new_round, i) + ARG) (*fresh)++;
  }
}

int main(void) {
  int stale, fresh, cyc;
  uint64_t t0, t1;
  int src_coherent = -1, dst_coherent = -1;
  soc_test_begin("t_dma");
  CHECK(accel_rd(SLOT, 0x20) == 0xAC0C9B9Fu, "slot 0 ID register = 0x%x (expected the example engine)", accel_rd(SLOT, 0x20));

  // ---- 1. uncached SRAM buffers, no maintenance at all
  for (int i = 0; i < N; i++) { src_sram[i] = pat(1, i); dst_sram[i] = 0; }
  cyc = run((uintptr_t)src_sram, (uintptr_t)dst_sram, N);
  CHECK(cyc >= 0, "SRAM to SRAM: DONE never set, STATUS 0x%x", accel_rd(SLOT, 0x04));
  classify(dst_sram, 0, 1, &stale, &fresh);
  CHECK(fresh == N, "SRAM to SRAM: %d of %d words correct", fresh, N);
  printf("SRAM to SRAM: %d cycles for %d words (%d per word)\r\n", cyc, N, cyc / N);

  // ---- 2. source in DRAM, dirty in the L1, plain fence: what does the device read?
  for (int i = 0; i < N; i++) src_dram[i] = pat(2, i);            // round 2 ...
  fence_i();                                                      // ... written back: DRAM holds round 2, L1 empty
  for (int i = 0; i < N; i++) src_dram[i] = pat(3, i);            // round 3: dirty in the L1 only
  fence();
  for (int i = 0; i < N; i++) dst_sram[i] = 0;
  cyc = run((uintptr_t)src_dram, (uintptr_t)dst_sram, N);
  CHECK(cyc >= 0, "DRAM source: DONE never set");
  classify(dst_sram, 2, 3, &stale, &fresh);
  CHECK(stale + fresh == N, "DRAM source after a plain fence: %d stale, %d fresh of %d words (the rest corrupt)", stale, fresh, N);
  src_coherent = (fresh == N);
  printf("DRAM source dirty in the L1, plain fence: the device read %d stale, %d fresh words: %s\r\n", stale, fresh,
         src_coherent ? "COHERENT" : "NOT coherent (fence does not write back the L1)");
  printf("DRAM to SRAM: %d cycles for %d words (%d per word)\r\n", cyc, N, cyc / N);

  // ---- 3. same, with fence.i before the start (and its cost with 32 dirty lines, then with a clean cache)
  for (int i = 0; i < N; i++) src_dram[i] = pat(4, i);
  t0 = soc_cycles(); fence_i(); t1 = soc_cycles();
  uint32_t fi_dirty = (uint32_t)(t1 - t0);
  t0 = soc_cycles(); fence_i(); t1 = soc_cycles();
  uint32_t fi_clean = (uint32_t)(t1 - t0);
  for (int i = 0; i < N; i++) dst_sram[i] = 0;
  cyc = run((uintptr_t)src_dram, (uintptr_t)dst_sram, N);
  classify(dst_sram, 3, 4, &stale, &fresh);
  CHECK(cyc >= 0 && fresh == N, "DRAM source after fence.i: %d fresh, %d stale of %d words", fresh, stale, N);
  printf("fence.i: %u cycles with %d dirty lines, %u cycles with a clean cache\r\n", fi_dirty, N / 2, fi_clean);

  // ---- 4. destination in DRAM, present (clean) in the L1 while the device writes it
  for (int i = 0; i < N; i++) dst_dram[i] = pat(5, i);            // round 5 in DRAM ...
  fence_i();
  uint64_t sum = 0;
  for (int i = 0; i < N; i++) sum += dst_dram[i];                 // ... and now clean in the L1
  __asm__ volatile("" :: "r"(sum));
  for (int i = 0; i < N; i++) src_sram[i] = pat(6, i);
  cyc = run((uintptr_t)src_sram, (uintptr_t)dst_dram, N);         // the device writes round 6 + ARG to DRAM
  CHECK(cyc >= 0, "DRAM destination: DONE never set");
  fence();
  int stale_raw = 0;
  for (int i = 0; i < N; i++) if (dst_dram[i] == pat(5, i)) stale_raw++;
  classify(dst_dram, 5, 6, &stale, &fresh);                       // stale here = old value + ARG: never expected
  CHECK(stale_raw + fresh == N, "DRAM destination after a plain fence: %d stale, %d fresh of %d words (the rest corrupt)", stale_raw, fresh, N);
  dst_coherent = (fresh == N);
  printf("DRAM destination cached in the L1, plain fence: the core read %d stale, %d fresh words: %s\r\n", stale_raw, fresh,
         dst_coherent ? "COHERENT" : "NOT coherent (the device's writes do not invalidate the L1)");
  fence_i();
  classify(dst_dram, 5, 6, &stale, &fresh);
  CHECK(fresh == N, "DRAM destination after fence.i: %d fresh of %d words", fresh, N);
  printf("SRAM to DRAM: %d cycles for %d words (%d per word)\r\n", cyc, N, cyc / N);

  // ---- 5. the recipe for DRAM buffers on both sides
  for (int i = 0; i < N; i++) { src_dram[i] = pat(7, i); dst_dram[i] = 0; }
  fence_i();                                                      // before the start: write back the source
  cyc = run((uintptr_t)src_dram, (uintptr_t)dst_dram, N);
  fence_i();                                                      // after completion: drop the L1's copies
  classify(dst_dram, 0, 7, &stale, &fresh);
  CHECK(cyc >= 0 && fresh == N, "DRAM to DRAM with fence.i before and after: %d fresh of %d words", fresh, N);
  printf("DRAM to DRAM: %d cycles for %d words (%d per word)\r\n", cyc, N, cyc / N);

  // ---- 6. DRAM above the cores' cacheable region (ariane_soc::ArianeSocCfg caches 256 MB from 0x8000_0000;
  //         the DRAM is 512 MB): the cores access it uncached, so no maintenance is needed there either
  //         The host crossbar only routes what ariane_soc::HYAXILength covers (256 MB too), so probe first: the
  //         core writes, fence.i pushes the write to the bus, the device copies (STATUS.ERR reports a bus error).
  volatile uint64_t *src_hi = (volatile uint64_t *)HI_BASE, *dst_hi = (volatile uint64_t *)(HI_BASE + 0x1000);
  for (int i = 0; i < N; i++) { src_hi[i] = pat(8, i); dst_hi[i] = 0; }
  fence_i();
  int core_sees = (src_hi[0] == pat(8, 0) && src_hi[N - 1] == pat(8, N - 1));
  accel_wr64(SLOT, 0x08, (uintptr_t)src_hi); accel_wr64(SLOT, 0x10, (uintptr_t)dst_hi);
  accel_wr(SLOT, 0x18, N); accel_wr(SLOT, 0x1C, ARG); accel_wr(SLOT, 0x00, 0x1);
  int done = accel_wait(SLOT, 0x04, 0x3, 0x2, 1000000) == 0;
  uint32_t status = accel_rd(SLOT, 0x04);
  cyc = (int)accel_rd(SLOT, 0x24);
  accel_wr(SLOT, 0x04, 0x2);
  fence_i();
  classify(dst_hi, 0, 8, &stale, &fresh);
  if (done && !(status & 0x4) && core_sees) {
    CHECK(fresh == N, "DRAM above the cacheable region: %d fresh of %d words", fresh, N);
    printf("DRAM above 0x%x (outside the cacheable region) to the same region: %d cycles for %d words (%d per word), %s\r\n",
           (unsigned)HI_BASE, cyc, N, cyc / N, fresh == N ? "correct" : "WRONG");
  } else {
    printf("DRAM above 0x%x is not usable: device %s (STATUS 0x%x), core read back %s: the crossbar routes 256 MB of DRAM\r\n",
           (unsigned)HI_BASE, done ? "finished" : "hung", status, core_sees ? "its data" : "something else");
  }

  printf("socket DMA vs the L1 data cache: source %s, destination %s\r\n",
         src_coherent ? "coherent" : "NOT coherent", dst_coherent ? "coherent" : "NOT coherent");
  return soc_test_end();
}
