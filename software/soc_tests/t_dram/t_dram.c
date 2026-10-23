// DRAM timing model (hardware/host/axi_dram_timing.sv, registers at 0x1A10_6100; hardware/docs/dram_model.md).
// The memory traffic is a pointer chase over 64 lines that share one LLC set (and one L1 set): 16 LLC ways and
// 8 L1 ways cannot hold them, so nearly every hop is an L1 miss, an LLC miss and a 64-byte refill from the DRAM
// (the LLC replaces at random: a few percent of hops may hit, the checks allow for that).
//  1. model off: cycles of a dependent DRAM line read (the real memory path in SoC cycles: printed, it is the
//     number to calibrate the model against)
//  2. fixed latency: with LAT_RD = 256 every hop takes at least 256 cycles and at most 256 + the real latency;
//     the model counts one read per hop, none late, and holds data back for the difference
//  3. late detection: with LAT_RD = 1 the real memory is slower than the model and every read is counted late
//  4. bandwidth: 32 cycles of bus time per beat make a line cost 256 cycles; a dependent chase and a stream of
//     independent lines both take at least that per line, and the stream is faster again with the limit removed
//  5. the write path: dirty lines evicted from the LLC are written back through the model (LAT_WR) and read back
//     correct
//  6. model off again: the chase is back to the real latency
// On a bitstream without the model (ID register absent) only step 1 runs.
#include "soc_test.h"

#define SOC_CTRL   0x1A106000UL
#define DM         (SOC_CTRL + 0x100)
#define DM_CTRL    0x00
#define DM_LAT_RD  0x04
#define DM_LAT_WR  0x08
#define DM_OCC16   0x0C
#define DM_RD_CNT  0x10
#define DM_WR_CNT  0x14
#define DM_RD_LATE 0x18
#define DM_LATE_CY 0x1C
#define DM_HOLD_CY 0x20
#define DM_ID      0x24
#define DM_BEATS   0x28
#define DM_ID_VAL  0xD2A30001u

#define REGION   0x80400000UL   // LLC-cached DRAM not used by the program (the LLC caches 0x8000_0000-0x807F_FFFF)
#define SET_STEP 0x10000UL      // lines 64 KB apart share an LLC set (1024 sets x 64 B) and an L1 set
#define CHASE    (REGION)            // chain A: LLC set 0
#define CHASE2   (REGION + 0x40)     // chain B: LLC set 1
#define BYPASS   0x81000000UL   // DRAM outside the LLC window: the LLC passes the requests through
#define BYP_STEP 0x1040UL
#define N        64
#define SLACK    6              // hops the random LLC replacement may turn into hits

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }
static inline void     st(uint64_t a, uint64_t v) { *(volatile uint64_t *)a = v; }

// read 64 KB of LLC-cached DRAM in sets 2..1023: everything else leaves the 16 KB L1
static void l1_sweep(void) {
  uint64_t s = 0;
  for (uint64_t a = REGION + 0x80; a < REGION + 0x10000; a += 64) s += ld(a);
  __asm__ volatile("" :: "r"(s));
}

// cycles per hop of the chain at `base` (N dependent line reads)
static uint32_t chase(uint64_t base) {
  uint64_t p = base;
  uint64_t t0 = soc_cycles();
  for (int i = 0; i < N; i++) p = ld(p);
  uint64_t t1 = soc_cycles();
  __asm__ volatile("" :: "r"(p));
  return (uint32_t)((t1 - t0) / N);
}

// cycles for N independent reads of the chain's lines
static uint32_t stream(uint64_t base) {
  uint64_t s = 0;
  uint64_t t0 = soc_cycles();
  for (int i = 0; i < N; i++) s += ld(base + i * SET_STEP + 8);
  uint64_t t1 = soc_cycles();
  __asm__ volatile("" :: "r"(s));
  return (uint32_t)(t1 - t0);
}

static void build_chain(uint64_t base) {
  for (int i = 0; i < N; i++) st(base + i * SET_STEP, base + ((i + 1) % N) * SET_STEP);
}

static void dm_set(uint32_t lat_rd, uint32_t lat_wr, uint32_t occ16) {
  REG32(DM + DM_CTRL) = 0;
  REG32(DM + DM_LAT_RD) = lat_rd;
  REG32(DM + DM_LAT_WR) = lat_wr;
  REG32(DM + DM_OCC16) = occ16;
  REG32(DM + DM_CTRL) = 3;   // enable, clear the counters
}

int main(void) {
  soc_test_begin("t_dram");
  int present = REG32(DM + DM_ID) == DM_ID_VAL;
  printf("dram timing model %s\r\n", present ? "present" : "absent: only the real latency is measured");
  if (present) REG32(DM + DM_CTRL) = 0;

  // 1. the real memory
  uint32_t t;
  build_chain(CHASE);
  chase(CHASE);                                   // the chain's dirty lines leave the L1 and the LLC
  uint32_t base = chase(CHASE);
  printf("dependent DRAM line read, model off: %u cycles\r\n", base);
  CHECK(base > 10 && base < 4000, "real DRAM line read latency %u cycles", base);
  // the same for DRAM outside the LLC window: L1 line fills that the LLC passes through (the L1 gets its word
  // from the first beat, so this is shorter than the LLC path, which needs the whole line)
  for (int i = 0; i < N; i++) st(BYPASS + i * BYP_STEP, BYPASS + ((i + 1) % N) * BYP_STEP);
  l1_sweep();
  uint32_t bypass = chase(BYPASS);
  printf("dependent line read outside the LLC window, model off: %u cycles\r\n", bypass);
  CHECK(bypass > 10 && bypass < 4000, "real bypass read latency %u cycles", bypass);
  if (!present) return soc_test_end();

  // 2. fixed latency
  dm_set(256, 0, 0);
  t = chase(CHASE);
  uint32_t rd = REG32(DM + DM_RD_CNT), late = REG32(DM + DM_RD_LATE), hold = REG32(DM + DM_HOLD_CY);
  uint32_t beats = REG32(DM + DM_BEATS);
  printf("LAT_RD 256: %u cycles per hop, %u reads of %u beats, %u late, hold %u cycles\r\n", t, rd, beats, late, hold);
  CHECK(t >= 256 - 4 * SLACK, "LAT_RD 256: a hop took %u cycles", t);
  CHECK(t <= 256 + base, "LAT_RD 256: %u cycles is more than the model plus the real path (%u)", t, 256 + base);
  CHECK(rd >= N - SLACK && rd <= N + 8, "LAT_RD 256: %u reads counted for %d hops", rd, N);
  CHECK(beats >= 8 * (rd - 2) && beats <= 8 * rd + 16, "LAT_RD 256: %u beats for %u reads: not 64-byte lines", beats, rd);
  CHECK(late == 0, "LAT_RD 256: %u reads late", late);
  if (base < 256) CHECK(hold >= (uint32_t)(N - SLACK) * (256 - base), "LAT_RD 256: hold %u cycles for %d reads of %u", hold, N, base);

  // 2b. the same two settings on the bypass path, where the model sees the L1's own 16-byte line fills (2 beats).
  // With 32 cycles per beat the second beat, which completes the fill, comes 32 cycles after the burst's start;
  // the real memory's own time to the first beat is hidden inside that, so a hop grows by 32 minus that time.
  dm_set(256, 0, 0);
  l1_sweep();
  t = chase(BYPASS);
  rd = REG32(DM + DM_RD_CNT);
  beats = REG32(DM + DM_BEATS);
  printf("LAT_RD 256, outside the LLC window: %u cycles per hop, %u reads of %u beats\r\n", t, rd, beats);
  CHECK(t >= 256, "LAT_RD 256 on the bypass path: a hop took %u cycles", t);
  CHECK(rd >= N - SLACK && rd <= N + 8 && beats >= 2 * rd && beats <= 2 * rd + 8, "bypass path: %u reads of %u beats for %d hops", rd, beats, N);
  dm_set(0, 0, 512);
  l1_sweep();
  t = chase(BYPASS);
  printf("OCC16 512, outside the LLC window: %u cycles per hop (%u with no limit)\r\n", t, bypass);
  CHECK(t + 8 >= bypass && t <= bypass + 40, "OCC16 512 on the bypass path: a hop took %u cycles (2 beats x 32, was %u)", t, bypass);

  // 3. the real memory slower than the model
  dm_set(1, 0, 0);
  t = chase(CHASE);
  rd = REG32(DM + DM_RD_CNT);
  late = REG32(DM + DM_RD_LATE);
  uint32_t late_cy = REG32(DM + DM_LATE_CY);
  printf("LAT_RD 1: %u cycles per hop, %u reads, %u late, %u late cycles\r\n", t, rd, late, late_cy);
  CHECK(late >= N - SLACK && late == rd, "LAT_RD 1: %u of %u reads counted late", late, rd);
  CHECK(late_cy > 0, "LAT_RD 1: no late cycles");
  CHECK(t <= base + 16, "LAT_RD 1: %u cycles per hop, the model should add nothing (%u)", t, base);

  // 4. bandwidth: 32 cycles per beat, 256 per 64-byte line
  dm_set(0, 0, 512);
  t = chase(CHASE);
  printf("OCC16 512: %u cycles per dependent line read\r\n", t);
  CHECK(t >= 224 - 4 * SLACK, "OCC16 512: a dependent line read took %u cycles (8 beats x 32)", t);
  uint32_t slow = stream(CHASE);
  dm_set(0, 0, 0);
  uint32_t fast = stream(CHASE);
  printf("stream of %d lines: %u cycles at 32 cycles per beat, %u unlimited\r\n", N, slow, fast);
  CHECK(slow >= (uint32_t)(N - SLACK) * 256, "OCC16 512: %d lines streamed in %u cycles", N, slow);
  // The limit must take the stream at least half way from its unlimited time to the limit's own floor (N lines x
  // 256 cycles). A fixed margin of N x 128 assumed the memory is far faster than the limit, and fails with a slow
  // memory controller (OpenDRAM with 16x timing: 10600 unlimited, 18602 limited) where the limit works as intended.
  uint32_t floor_cy = (uint32_t)N * 256;
  uint32_t gain = fast < floor_cy ? (floor_cy - fast) / 2 : 0;
  CHECK(slow >= fast + gain, "the bandwidth limit did not slow the stream (%u vs %u)", slow, fast);

  // 5. writes through the model: 64 dirty lines into a 16-way set, at least 48 are evicted and written back
  dm_set(0, 300, 0);
  build_chain(CHASE2);
  chase(CHASE2);
  uint32_t wr = REG32(DM + DM_WR_CNT);
  int bad = 0;
  for (int i = 0; i < N; i++) if (ld(CHASE2 + i * SET_STEP) != CHASE2 + ((i + 1) % N) * SET_STEP) bad++;
  printf("LAT_WR 300: %u writes, %d lines wrong\r\n", wr, bad);
  CHECK(wr >= N - 16, "LAT_WR 300: %u write bursts for %d dirty lines in a 16-way set", wr, N);
  CHECK(bad == 0, "LAT_WR 300: %d lines read back wrong", bad);

  // 6. off again
  REG32(DM + DM_CTRL) = 0;
  t = chase(CHASE);
  printf("model off: %u cycles per hop\r\n", t);
  CHECK(t < 256 - 4 * SLACK && t <= 2 * base + 16, "model off: %u cycles per hop (was %u)", t, base);
  return soc_test_end();
}
