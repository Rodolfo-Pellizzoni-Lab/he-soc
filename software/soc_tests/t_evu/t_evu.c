// t_evu: the cores' event units (EVUs) and the APMU's ports for them, with N = SOC_NUM_CORES cores. Core c's EVU
// configuration registers (hardware/host/cva6_synth_wrap.sv, ariane_soc::PerfcEvu*) are 0x30 bytes at
// EVU_BASE_ADDR + 0x30*c: four 32-bit event IDs in reverse slot order (EVU_EID_REG; the EVU uses bits [4:0]), then
// four 64-bit PC milestones. All of them sit in one window, which the CPUs reach through the AXI-lite crossbar
// (axi_lite_subsystem) and the APMU's processing element (PE) as its system memory (host_domain): 0x100 bytes with
// four cores (0xC0 of registers), 0x200 with eight (0x180). Core c's EVU reports to APMU port c + 1, bit s of the
// event field set while slot s sees its event (EVU_SLOT_SEL).
//   A. core 0 writes a pattern into every register word of every core (event IDs with bits [4:0] clear, so off) and
//      reads them all back
//   B. the PE copies all of them into its DSPM (a 12-instruction loop in its ISPM; its loads of anything outside its
//      window are never granted, so a window that is too small stalls it): every word equals the pattern
//   C. one core at a time counts its own committed loads (event ID 0x05) in slot c % 4 of its EVU, enabled only around
//      a loop of K loads, while APMU counter j counts slot j % 4 of port j + 1 for every core j: core c's counter
//      sees the K loads (and the read-back of the enable, which may land after it), every other core's nothing.
#include "soc_test.h"

#define NC          SOC_NUM_CORES
#define EVU_WORDS   12                       // a core's 32-bit register words: four event IDs, four 64-bit milestones
#define EVU_BYTES   (4 * EVU_WORDS * NC)     // every core's (ariane_soc::PerfcEvuBytesPerCore * NumCVA6)
#define EVU_WORD(c, w) (EVU_BASE_ADDR + 4 * (EVU_WORDS * (c) + (w)))
#define EV_LOAD     0x05                     // the EVU's event ID of a committed load (perf_counters_evu.sv)
#define K           100                      // C: loads per core
#define SETTLE      1000                     // cycles for the last events to reach the counters
#define PE_DST      (DSPM_BASE_ADDR + 0x100) // B: the PE's copy
#define PE_DONE     0x5A5                    // B: what the PE writes to DSPM_BASE_ADDR once it has copied everything
#define PE_CYCLES   2000000ULL               // B: bound on the wait for it
#if NC > NUM_COUNTER
#error "t_evu needs a counter per core"
#endif

// B: the PE's program (rv32i) at its boot address (this Ibex starts at boot_addr itself, not at +0x80)
static const uint32_t pe_prog[] = {
  0x106060B7,                      //    lui  x1, 0x10606      the EVU registers (EVU_BASE_ADDR)
  0x104291B7,                      //    lui  x3, 0x10429      the DSPM (DSPM_BASE_ADDR)
  0x00008293 | (EVU_BYTES << 20),  //    addi x5, x1, EVU_BYTES   their end
  0x10018313,                      //    addi x6, x3, 0x100    the copy (PE_DST)
  0x0000A103,                      // 1: lw   x2, 0(x1)
  0x00232023,                      //    sw   x2, 0(x6)
  0x00408093,                      //    addi x1, x1, 4
  0x00430313,                      //    addi x6, x6, 4
  0xFE5098E3,                      //    bne  x1, x5, 1b
  0x5A500393,                      //    li   x7, 0x5A5        PE_DONE
  0x0071A023,                      //    sw   x7, 0(x3)        at DSPM_BASE_ADDR
  0x0000006F,                      // 2: j    2b
};
_Static_assert(EVU_BASE_ADDR == 0x10606000 && DSPM_BASE_ADDR == 0x10429000 && PE_DST == DSPM_BASE_ADDR + 0x100 &&
               EVU_BYTES < 0x800, "t_evu: the PE program's constants");

SOC_SRAM static volatile uint32_t cnt[NC][NC];   // C: [phase c][counter j]
static uint64_t load_buf[NC][8];

// A: word w of core c: event IDs (w < 4) with bits [4:0] clear, milestones at addresses no code has
static uint32_t pattern(int c, int w) {
  if (w < 4) return 0xE0000000u | (uint32_t)c << 16 | (uint32_t)w << 8 | 0x20u;
  return (w % 2 ? 0xFFFF0000u : 0x5A000000u) | (uint32_t)c << 8 | (uint32_t)w;
}

// the words of core c that differ from the pattern in the window at base (the registers, or the PE's copy)
static int check_core(uint64_t base, int c, uint32_t *first) {
  int bad = 0;
  for (int w = EVU_WORDS - 1; w >= 0; w--) {
    uint32_t v = REG32(base + 4 * (EVU_WORDS * c + w));
    if (v != pattern(c, w)) { bad++; *first = (uint32_t)w; }
  }
  return bad;
}

// C: core c's K loads, with slot c % 4 of its EVU counting committed loads only around them. One load in every four
// instructions, so no two of them commit in the same cycle (the EVU's event is one bit per cycle).
static void count_loads(int c) {
  volatile uint64_t *p = &load_buf[c][0];
  uint64_t s = 0, n = K;
  REG32(EVU_EID_REG(c, c % 4)) = EV_LOAD;
  (void)REG32(EVU_EID_REG(c, c % 4));               // the enable has landed (this load may count too)
  __asm__ volatile("1: ld   t0, 0(%2)\n"
                   "   add  %0, %0, t0\n"
                   "   addi %1, %1, -1\n"
                   "   bnez %1, 1b\n"
                   : "+r"(s), "+r"(n) : "r"(p) : "t0", "memory");
  __asm__ volatile("fence" ::: "memory");
  REG32(EVU_EID_REG(c, c % 4)) = 0;
  __asm__ volatile("fence" ::: "memory");
  __asm__ volatile("" :: "r"(s));
}

// C: every core runs the same schedule; core 0 clears the counters before each phase and reads them after it
static void phases(int cid) {
  int round = 1;
  for (int c = 0; c < NC; c++) {
    if (cid == 0)
      for (int j = 0; j < NC; j++) REG32(COUNTER_BASE_ADDR + j * COUNTER_BUNDLE_SIZE) = 0;
    soc_barrier(NC, round++);
    if (cid == c) count_loads(c);
    soc_barrier(NC, round++);
    if (cid == 0) {
      uint64_t t = soc_cycles();
      while (soc_cycles() - t < SETTLE) ;
      for (int j = 0; j < NC; j++) cnt[c][j] = REG32(COUNTER_BASE_ADDR + j * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    }
  }
}

static uint32_t woke;

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_evu");
    woke = soc_wake_all();          // with the first counters, which it releases
    return 0;                       // core 0 continues in main()
  }
  phases(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  uint32_t first = 0;
  CHECK(woke == SOC_WAKE_MASK, "cores woken: 0x%x, expected 0x%x", woke, SOC_WAKE_MASK);

  // A
  for (int c = 0; c < NC; c++)
    for (int w = 0; w < EVU_WORDS; w++) REG32(EVU_WORD(c, w)) = pattern(c, w);
  __asm__ volatile("fence" ::: "memory");
  for (int c = 0; c < NC; c++) {
    int bad = check_core(EVU_BASE_ADDR, c, &first);
    CHECK(bad == 0, "core %d's EVU registers: %d of %d words read back wrong, word %u at 0x%08x is 0x%08x, not 0x%08x",
          c, bad, EVU_WORDS, first, (unsigned)EVU_WORD(c, first), REG32(EVU_WORD(c, first)), pattern(c, first));
  }
  printf("A: %d cores' EVU registers, 0x%x bytes at 0x%08x, written and read back\r\n", NC, EVU_BYTES,
         (unsigned)EVU_BASE_ADDR);

  // B
  REG32(PMC_STATUS_ADDR) = 1;                                   // hold the PE
  for (unsigned i = 0; i < sizeof pe_prog / sizeof pe_prog[0]; i++) REG32(ISPM_BASE_ADDR + 4 * i) = pe_prog[i];
  REG32(DSPM_BASE_ADDR) = 0;
  for (int i = 0; i < EVU_BYTES / 4; i++) REG32(PE_DST + 4 * i) = 0;
  __asm__ volatile("fence" ::: "memory");
  REG32(PMC_BOOT_ADDR) = ISPM_BASE_ADDR;
  REG32(PMC_STATUS_ADDR) = 0;                                   // run
  uint64_t t0 = soc_cycles();
  while (REG32(DSPM_BASE_ADDR) != PE_DONE && soc_cycles() - t0 < PE_CYCLES) __asm__ volatile("nop");
  uint32_t done = REG32(DSPM_BASE_ADDR);
  REG32(PMC_STATUS_ADDR) = 1;                                   // and stop it
  CHECK(done == PE_DONE, "the PE did not finish copying the EVU registers (DSPM word 0 is 0x%08x)", done);
  for (int c = 0; c < NC; c++) {
    int bad = check_core(PE_DST, c, &first);
    CHECK(bad == 0, "core %d's EVU registers as the PE read them: %d of %d words wrong, word %u is 0x%08x, not 0x%08x",
          c, bad, EVU_WORDS, first, REG32(PE_DST + 4 * (EVU_WORDS * c + first)), pattern(c, first));
  }
  printf("B: the PE copied them (0x%x bytes): DSPM word 0 = 0x%x\r\n", EVU_BYTES, done);

  // C: event IDs are all off after A (bits [4:0] clear); counter j counts slot j % 4 of port j + 1
  for (int j = 0; j < NC; j++) {
    REG32(EVENT_SEL_BASE_ADDR  + j * COUNTER_BUNDLE_SIZE) = EVU_SLOT_SEL(j, j % 4);
    REG32(EVENT_INFO_BASE_ADDR + j * COUNTER_BUNDLE_SIZE) = 0;
  }
  phases(0);
  for (int c = 0; c < NC; c++) {
    uint32_t other = 0;
    printf("C: core %d counts %d loads in slot %d, port %d: counters 0-%d", c, K, c % 4, APMU_PORT_EVU(c), NC - 1);
    for (int j = 0; j < NC; j++) { printf(" %u", cnt[c][j]); if (j != c) other += cnt[c][j]; }
    printf("\r\n");
    CHECK(cnt[c][c] >= K && cnt[c][c] <= K + 2, "core %d: port %d slot %d counted %u loads, expected %d (or %d)", c,
          APMU_PORT_EVU(c), c % 4, cnt[c][c], K, K + 1);
    CHECK(other == 0, "core %d: %u events counted for other cores' ports", c, other);
  }
  return soc_test_end();
}
