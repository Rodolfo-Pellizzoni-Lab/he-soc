// Memory paths from core 0: cached DRAM (L1 -> CCU -> LLC -> DRAM) with every access size, an eviction sweep
// larger than the L1 data cache, and the uncached on-chip SRAM (L2 SPM).
#include "soc_test.h"

#define SWEEP_WORDS (64 * 1024 / 8)        // 64 KB: twice the L1 D$, forces write-backs and refills
static volatile uint64_t dram_buf[SWEEP_WORDS] __attribute__((aligned(64)));
SOC_SRAM static volatile uint64_t sram_buf[256];

static uint64_t pat(uint64_t i) { return 0x9e3779b97f4a7c15ULL * (i + 1) ^ (i << 7); }

int main(void) {
  soc_test_begin("t_mem");
  // every access size on DRAM and SRAM
  volatile uint8_t *regions[2] = { (volatile uint8_t *)dram_buf, (volatile uint8_t *)sram_buf };
  const char *names[2] = { "dram", "sram" };
  for (int r = 0; r < 2; r++) {
    volatile uint8_t *b = regions[r];
    for (int i = 0; i < 16; i++) b[i] = (uint8_t)(0xA0 + i);
    for (int i = 0; i < 8; i++) ((volatile uint16_t *)(b + 16))[i] = (uint16_t)(0xB000 + i);
    for (int i = 0; i < 4; i++) ((volatile uint32_t *)(b + 32))[i] = 0xC0000000u + i;
    for (int i = 0; i < 2; i++) ((volatile uint64_t *)(b + 48))[i] = 0xD000000000000000ULL + i;
    for (int i = 0; i < 16; i++) CHECK(b[i] == (uint8_t)(0xA0 + i), "%s byte %d = %x", names[r], i, b[i]);
    CHECK(((volatile uint64_t *)b)[0] == 0xA7A6A5A4A3A2A1A0ULL, "%s bytes read as dword", names[r]);
    for (int i = 0; i < 8; i++) CHECK(((volatile uint16_t *)(b + 16))[i] == 0xB000 + i, "%s half %d", names[r], i);
    for (int i = 0; i < 4; i++) CHECK(((volatile uint32_t *)(b + 32))[i] == 0xC0000000u + i, "%s word %d", names[r], i);
    for (int i = 0; i < 2; i++) CHECK(((volatile uint64_t *)(b + 48))[i] == 0xD000000000000000ULL + i, "%s dword %d", names[r], i);
    // byte write inside a dword keeps its neighbours
    b[50] = 0x5A;
    CHECK(((volatile uint64_t *)(b + 48))[0] == 0xD0000000005A0000ULL, "%s byte merge = %08x%08x", names[r],
          H64(((volatile uint64_t *)(b + 48))[0]));
  }
  // eviction sweep: write 64 KB, read it back (the first half has been evicted by then)
  for (int i = 0; i < SWEEP_WORDS; i++) dram_buf[i] = pat(i);
  int bad = 0, first = -1;
  for (int i = 0; i < SWEEP_WORDS; i++) if (dram_buf[i] != pat(i)) { bad++; if (first < 0) first = i; }
  CHECK(bad == 0, "dram sweep: %d of %d words wrong, first at %d", bad, SWEEP_WORDS, first);
  // SRAM block
  for (int i = 0; i < 256; i++) sram_buf[i] = pat(i) ^ 0xffff;
  bad = 0;
  for (int i = 0; i < 256; i++) if (sram_buf[i] != (pat(i) ^ 0xffff)) bad++;
  CHECK(bad == 0, "sram block: %d of 256 words wrong", bad);
  return soc_test_end();
}
