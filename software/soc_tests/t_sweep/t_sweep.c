// Memory latency sweep: a dependent pointer chase over a random cyclic chain of 16-byte elements (one L1 line
// each) in an array of growing size, placed in LLC-cached DRAM. Cycles per read go from the L1 hit (array under
// 16 KB: the write-back data cache of the cv64a6_imafdc_sv39_wb configuration, 8 ways of 16-byte lines) to the
// LLC hit (under 1 MB: 16 ways of 64-byte lines) to the DRAM. With the DRAM timing model present (hardware/docs/dram_model.md) every size is chased again with the 1 GHz target
// settings (LAT_RD 80, LAT_WR 80, OCC16 20). One line per size and mode, for plotting:
//   SWEEP <off|1ghz> <array KB> <cycles per read x100>
// Built with fpga=1 the sizes go up to 7 MB (software/soc_tests/plot_sweep.py draws the console log); in
// simulation the sweep stops at 48 KB with short chases, enough to see the L1 knee.
#include "soc_test.h"

#define SOC_CTRL   0x1A106000UL
#define DM         (SOC_CTRL + 0x100)
#define DM_CTRL    0x00
#define DM_LAT_RD  0x04
#define DM_LAT_WR  0x08
#define DM_OCC16   0x0C
#define DM_ID      0x24
#define DM_ID_VAL  0xD2A30001u

#define BASE 0x80100000UL   // LLC-cached DRAM (0x8000_0000-0x807F_FFFF) above the program: 7 MB free
#define ELEM 16UL           // one L1 line per element

#ifdef FPGA_EMULATION
static const uint32_t sizes_kb[] = {1, 2, 3, 4, 6, 8, 12, 16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 80, 96, 112, 128,
                                    160, 192, 224, 256, 320, 384, 448, 512, 640, 768, 896, 1024, 1152, 1280, 1536,
                                    1792, 2048, 2560, 3072, 3584, 4096, 5120, 6144, 7168};
#define MIN_HOPS 65536
#define KB_LLC   256         // a size that hits the LLC and misses the L1
#else
static const uint32_t sizes_kb[] = {1, 2, 4, 8, 16, 24, 32, 48};
#define MIN_HOPS 1024
#define KB_LLC   48
#endif
#define KB_L1   8
#define NSIZES  (sizeof sizes_kb / sizeof sizes_kb[0])

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }

static uint64_t rng = 0x9E3779B97F4A7C15ULL;
static inline uint32_t rnd(void) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return (uint32_t)(rng >> 32); }

// one random cycle through the n elements (Sattolo's shuffle), each element holding the address of the next
static void build(uint64_t base, uint32_t n) {
  volatile uint64_t *a = (volatile uint64_t *)base;
  for (uint32_t i = 0; i < n; i++) a[i * 2] = i;
  for (uint32_t i = n - 1; i > 0; i--) {
    uint32_t j = rnd() % i;
    uint64_t t = a[i * 2]; a[i * 2] = a[j * 2]; a[j * 2] = t;
  }
  for (uint32_t i = 0; i < n; i++) a[i * 2] = base + a[i * 2] * ELEM;
}

// cycles per read x100: one warm-up pass over the chain, then max(n, MIN_HOPS) timed dependent reads
static uint32_t chase_x100(uint64_t base, uint32_t n) {
  uint32_t hops = n > MIN_HOPS ? n : MIN_HOPS;   // n is a multiple of 64
  uint64_t p = base;
  for (uint32_t i = 0; i < n; i++) p = ld(p);
  uint64_t t0 = soc_cycles();
  for (uint32_t i = 0; i < hops; i += 8) {
    p = ld(p); p = ld(p); p = ld(p); p = ld(p);
    p = ld(p); p = ld(p); p = ld(p); p = ld(p);
  }
  uint64_t t1 = soc_cycles();
  __asm__ volatile("" :: "r"(p));
  return (uint32_t)((t1 - t0) * 100 / hops);
}

static void dm_set(uint32_t lat_rd, uint32_t lat_wr, uint32_t occ16) {
  REG32(DM + DM_CTRL) = 0;
  REG32(DM + DM_LAT_RD) = lat_rd;
  REG32(DM + DM_LAT_WR) = lat_wr;
  REG32(DM + DM_OCC16) = occ16;
  REG32(DM + DM_CTRL) = 3;
}

static void print_x100(const char *what, uint32_t v) {
  printf("%s %u.%c%c cycles per read\r\n", what, v / 100, '0' + (v / 10) % 10, '0' + v % 10);
}

int main(void) {
  soc_test_begin("t_sweep");
  int present = REG32(DM + DM_ID) == DM_ID_VAL;
  if (present) REG32(DM + DM_CTRL) = 0;
  printf("latency sweep: random chase of 16-byte elements, %u sizes from %u KB to %u KB, dram timing model %s\r\n",
         (uint32_t)NSIZES, sizes_kb[0], sizes_kb[NSIZES - 1], present ? "present" : "absent");
  uint32_t l1 = 0, llc = 0, last = 0, last_on = 0;
  for (uint32_t s = 0; s < NSIZES; s++) {
    uint32_t kb = sizes_kb[s], n = kb * 1024 / ELEM;
    build(BASE, n);
    uint32_t off = chase_x100(BASE, n);
    printf("SWEEP off %u %u\r\n", kb, off);
    if (kb == KB_L1) l1 = off;
    if (kb == KB_LLC) llc = off;
    last = off;
    if (present) {
      dm_set(80, 80, 20);
      last_on = chase_x100(BASE, n);
      REG32(DM + DM_CTRL) = 0;
      printf("SWEEP 1ghz %u %u\r\n", kb, last_on);
    }
  }
  print_x100("L1 hit:", l1);
  print_x100("LLC hit:", llc);
  print_x100("largest array:", last);
  if (present) print_x100("largest array, 1 GHz target settings:", last_on);
  CHECK(l1 > 100 && l1 < 1000, "L1 hit %u/100 cycles per read", l1);
  CHECK(llc > l1 + 500, "past the L1 (%u KB): %u/100 cycles per read, L1 hit %u/100", KB_LLC, llc, l1);
#ifdef FPGA_EMULATION
  CHECK(last > llc + 1000 && last < 40000, "DRAM: %u/100 cycles per read, LLC hit %u/100", last, llc);
  if (present) CHECK(last_on > last + 3000, "1 GHz settings: %u/100 cycles per read, model off %u/100", last_on, last);
#else
  if (present) CHECK(last_on < last + 500 && last < last_on + 500, "model enabled, LLC hits: %u/100 vs %u/100 off", last_on, last);
#endif
  return soc_test_end();
}
