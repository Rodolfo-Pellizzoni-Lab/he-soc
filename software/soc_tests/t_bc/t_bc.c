// t_bc: the LLC's CBQRI bandwidth controller (hardware/ip_list/axi_llc/src/axi_llc_cbqri_bc.sv, registers at
// 0x1040_1C00) on the whole SoC. The DRAM timing model makes the memory the bottleneck (OCC16 = 512: 256 cycles of
// bus per 64-byte line); cores 1-3 stream reads that miss the LLC, each with RCID = MCID = its core number; core 0
// configures the controller and measures every core's DRAM reads with the APMU (the memory-port SPU counts read
// requests per source). The controller hands out BC_CAPACITY = 45 lines per 50-line period (90 % of the memory).
//   0  regulation off                                                        (shares logged)
//   R  RCID 1 Rbwb 50 % Mweight 0, RCID 2 20 % Mweight 0, RCID 3 1 block Mweight 16   -> 50 / 20 / 30 %
//   W  Rbwb 1 block each, Mweight 32 / 64 / 128                                     -> 1/7, 2/7, 4/7
//      Handing out 24 lines per period (a release every ~530 cycles): a core has one miss in flight and a line takes
//      about 290 cycles, so at 45 lines (a release every 284 cycles) the heavy core's next miss is often not there
//      yet when a release is due and the release goes to whoever waits (work-conserving; CBQRI weighs only the RCIDs
//      actively requesting): the shares come out compressed (19.8 / 33.7 / 46.4 % in simulation). Logged as W45.
//   F  RCID 1 Rbwb 40 % Mweight 1, RCIDs 2 and 3 1 block Mweight 255                 -> RCID 1 >= 40 %
//   H  core 1 alone, Rbwb 20 % Mweight 0: 20 % of the controller's bandwidth (a hard limit); Mweight 16: more
//   M  per-MCID monitors against the APMU, with the workers stopped and the pipeline drained at both ends of the
//      window so nothing is in flight: MCID 1 read+write bytes = 64 x (core 1's DRAM reads + writes), MCID 2 read
//      bytes = 64 x core 2's reads, MCID 3 write bytes = 64 x core 3's writes (evictions its refills cause), exactly
//   S  registers: capabilities, READ_LIMIT of the reset state, STATUS 2 / 3 / 5, BC_RATE
#include "soc_test.h"

#define NC          SOC_NUM_CORES
#define BC          0x10401C00UL
#define BC_CAPS     0x00
#define BC_MON_CTL  0x08
#define BC_MON_VAL  0x10
#define BC_ALLOC    0x18
#define BC_BW       0x20
#define BC_CTRL     0x80
#define BC_PERIOD   0x88
#define BC_CAPACITY 0x90
#define BC_POOL     0x98
#define BC_FULL     0xA0
#define BC_RATE     0xA8
#define SOC_CTRL    0x1A106000UL
#define DM          (SOC_CTRL + 0x100)            // DRAM timing model: CTRL, LAT_RD, LAT_WR, OCC16
#define LINE        64
#define LINE_CYC    256                           // OCC16 = 512: 8 beats x 32 cycles
#define PERIOD      (50 * LINE_CYC)               // the memory moves 50 lines per period
#define CAP_LINES   45
#define CAPACITY    (CAP_LINES * LINE)
#define WINDOW      (4 * PERIOD)
#define BUF_BASE    0x80200000UL                  // LLC-cached DRAM (0x8000_0000-0x807F_FFFF) above the program
#define BUF_SIZE    0x200000UL                    // 2 MB per core: three of them never fit the 1 MB LLC
#define CTR0        4                             // APMU counters 0 .. NC-3 woke the cores

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

SOC_SRAM static volatile uint32_t run[NC];
SOC_SRAM static volatile uint64_t sink[NC];

static inline uint64_t rd64(unsigned off) { return (uint64_t)REG32(BC + off + 4) << 32 | REG32(BC + off); }
static inline void wr64(unsigned off, uint64_t v) { REG32(BC + off + 4) = (uint32_t)(v >> 32); REG32(BC + off) = (uint32_t)v; }

// CONFIG_LIMIT (op 1) or READ_LIMIT (op 2); returns STATUS
static unsigned limit(unsigned op, unsigned rcid, unsigned rbwb, unsigned mw) {
  if (op == 1) wr64(BC_BW, (uint64_t)mw << 20 | rbwb);
  wr64(BC_ALLOC, (uint64_t)rcid << 8 | op);
  return (rd64(BC_ALLOC) >> 32) & 0x7F;
}
static void set_limit(unsigned rcid, unsigned rbwb, unsigned mw) {
  unsigned st = limit(1, rcid, rbwb, mw);
  CHECK(st == 1, "CONFIG_LIMIT RCID %d Rbwb %d Mweight %d: STATUS %d", rcid, rbwb, mw, st);
}
static unsigned mon(unsigned op, unsigned mcid, unsigned evt) {
  wr64(BC_MON_CTL, (uint64_t)evt << 20 | (uint64_t)mcid << 8 | op);
  return (rd64(BC_MON_CTL) >> 32) & 0x7F;
}
// set RCIDs 1..3 (after dropping them to one block each, so the sum rule never trips in between)
static void config(unsigned r1, unsigned w1, unsigned r2, unsigned w2, unsigned r3, unsigned w3) {
  set_limit(1, 1, 1); set_limit(2, 1, 1); set_limit(3, 1, 1);
  set_limit(1, r1, w1); set_limit(2, r2, w2); set_limit(3, r3, w3);
}

// ---- workers: stream one read per LLC line over their own 2 MB
static void worker(int c) {
  uintptr_t base = BUF_BASE + (uintptr_t)(c - 1) * BUF_SIZE, off = 0;
  uint64_t s = 0;
  SRMCFG_W((uint64_t)c << 16 | c);
  for (;;) {
    if (!run[c]) { for (int i = 0; i < 256; i++) __asm__ volatile("nop"); continue; }
    for (int k = 0; k < 32; k++) {
      s += *(volatile uint64_t *)(base + off);
      off = (off + LINE) & (BUF_SIZE - 1);
    }
    sink[c] = s;
  }
}
int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 0) return 0;
  if (cid < 4) worker(cid);
  for (;;) __asm__ volatile("wfi");
}

// ---- APMU: DRAM read requests per source core (port 2N+1)
static void apmu_setup(void) {
  for (int c = 1; c < 4; c++) {
    REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + c) * COUNTER_BUNDLE_SIZE) = MEM_RD_REQ_CORE(c);
    REG32(EVENT_INFO_BASE_ADDR + (CTR0 + c) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(COUNTER_BASE_ADDR    + (CTR0 + c) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + 3 + c) * COUNTER_BUNDLE_SIZE) = MEM_WR_REQ_CORE(c);
    REG32(EVENT_INFO_BASE_ADDR + (CTR0 + 3 + c) * COUNTER_BUNDLE_SIZE) = 0;
    REG32(COUNTER_BASE_ADDR    + (CTR0 + 3 + c) * COUNTER_BUNDLE_SIZE) = 0;
  }
}
static uint32_t apmu_wr(int c) { return REG32(COUNTER_BASE_ADDR + (CTR0 + 3 + c) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu; }
static void apmu_read(uint32_t v[4]) {
  for (int c = 1; c < 4; c++) v[c] = REG32(COUNTER_BASE_ADDR + (CTR0 + c) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
}
static void wait_cycles(uint64_t n) { uint64_t t0 = soc_cycles(); while (soc_cycles() - t0 < n) ; }

// lines each core read in one window (after one warm-up period)
static void measure(const char *name, uint32_t lines[4]) {
  uint32_t a[4], b[4];
  wait_cycles(PERIOD);
  apmu_read(a);
  wait_cycles(WINDOW);
  apmu_read(b);
  uint32_t tot = 0;
  for (int c = 1; c < 4; c++) { lines[c] = b[c] - a[c]; tot += lines[c]; }
  printf("  %-2s lines per core 1/2/3: %d / %d / %d of %d handed out (%d.%d %% / %d.%d %% / %d.%d %%)\r\n", name,
         lines[1], lines[2], lines[3], CAP_LINES * WINDOW / PERIOD,
         tot ? lines[1] * 1000 / tot / 10 : 0, tot ? lines[1] * 1000 / tot % 10 : 0,
         tot ? lines[2] * 1000 / tot / 10 : 0, tot ? lines[2] * 1000 / tot % 10 : 0,
         tot ? lines[3] * 1000 / tot / 10 : 0, tot ? lines[3] * 1000 / tot % 10 : 0);
  uart_wait_tx_done();
}
// share of core c in per mille
static unsigned pm(const uint32_t l[4], int c) { uint32_t t = l[1] + l[2] + l[3]; return t ? l[c] * 1000 / t : 0; }

int main(void) {
  uint32_t l[4];
  soc_test_begin("t_bc");

  // ---- S: registers
  uint64_t caps = rd64(BC_CAPS);
  CHECK(caps == ((uint64_t)819 << 32 | 1024 << 8 | 0x10), "bc_capabilities %lx", caps);
  CHECK(limit(2, 0, 0, 0) == 1 && (rd64(BC_BW) & 0xFFFF) == 819 && ((rd64(BC_BW) >> 20) & 0xFF) == 255,
        "reset allocation of RCID 0: %lx", rd64(BC_BW));
  CHECK(limit(1, 1, 1, 1) == 5, "Rbwb 1 for RCID 1 while RCID 0 holds MRBWB: not STATUS 5");
  CHECK(limit(3, 1, 0, 0) == 2, "OP 3: not STATUS 2");
  CHECK(limit(2, 16, 0, 0) == 3, "RCID 16: not STATUS 3");
  CHECK(mon(1, 1, 4) == 4, "EVT_ID 4: not STATUS 4");
  set_limit(0, 1, 255);                            // core 0 and everything else on RCID 0: best effort
  REG32(BC + BC_PERIOD)   = PERIOD;
  REG32(BC + BC_CAPACITY) = CAPACITY;
  wait_cycles(100);
  uint32_t rate = REG32(BC + BC_RATE);
  CHECK(rate == (uint32_t)(((uint64_t)CAPACITY << 16) / PERIOD), "BC_RATE %d", rate);

  // the memory as the bottleneck
  REG32(DM + 0x00) = 0;
  REG32(DM + 0x04) = 32; REG32(DM + 0x08) = 32; REG32(DM + 0x0C) = 512;
  REG32(DM + 0x00) = 3;
  apmu_setup();
  soc_wake_all();
  CHECK(soc_wait_harts(0xE, 200000000) == 0xE, "cores 1-3 did not start: harts_up %x", harts_up);
  for (int c = 1; c < 4; c++) run[c] = 1;

  // ---- 0
  REG32(BC + BC_CTRL) = 0;
  measure("0", l);

  // ---- R (and M: monitors over the same window)
  config(512, 0, 205, 0, 1, 16);
  REG32(BC + BC_CTRL) = 3;                         // regulation and pacing
  wait_cycles(PERIOD);
  {
    uint32_t a[4], b[4];
    CHECK(mon(1, 1, 1) == 1 && mon(1, 2, 2) == 1 && mon(1, 3, 2) == 1, "CONFIG_EVENT failed");
    apmu_read(a);
    wait_cycles(WINDOW);
    CHECK(mon(2, 1, 0) == 1, "READ_COUNTER failed");
    uint64_t m1 = rd64(BC_MON_VAL);
    mon(2, 2, 0); uint64_t m2 = rd64(BC_MON_VAL);
    mon(2, 3, 0); uint64_t m3 = rd64(BC_MON_VAL);
    apmu_read(b);
    uint32_t tot = 0;
    for (int c = 1; c < 4; c++) { l[c] = b[c] - a[c]; tot += l[c]; }
    printf("  R  lines per core 1/2/3: %d / %d / %d (%d / %d / %d per mille), monitors %d / %d / %d lines\r\n",
           l[1], l[2], l[3], pm(l, 1), pm(l, 2), pm(l, 3), (int)(m1 / LINE), (int)(m2 / LINE), (int)(m3 / LINE));
    CHECK(pm(l, 1) >= 450 && pm(l, 1) <= 550, "R: core 1 (Rbwb 50 %%, Mweight 0) got %d per mille", pm(l, 1));
    CHECK(pm(l, 2) >= 160 && pm(l, 2) <= 240, "R: core 2 (Rbwb 20 %%, Mweight 0) got %d per mille", pm(l, 2));
    CHECK(pm(l, 3) >= 240 && pm(l, 3) <= 360, "R: core 3 (shares the rest) got %d per mille", pm(l, 3));
    // (the monitors count at the controller and the APMU at the memory port, a few bus operations apart and
    // with lines in flight between the two points: compared exactly in M)
  }

  // ---- W
  config(1, 32, 1, 64, 1, 128);
  measure("W45", l);
  REG32(BC + BC_CAPACITY) = 24 * LINE;
  measure("W", l);
  REG32(BC + BC_CAPACITY) = CAPACITY;
  CHECK(pm(l, 1) >= 100 && pm(l, 1) <= 190, "W: Mweight 32 got %d per mille (1/7)", pm(l, 1));
  CHECK(pm(l, 2) >= 230 && pm(l, 2) <= 340, "W: Mweight 64 got %d per mille (2/7)", pm(l, 2));
  CHECK(pm(l, 3) >= 500 && pm(l, 3) <= 640, "W: Mweight 128 got %d per mille (4/7)", pm(l, 3));

  // ---- F
  config(410, 1, 1, 255, 1, 255);
  measure("F", l);
  CHECK(pm(l, 1) >= 370, "F: core 1 (Rbwb 40 %%) got %d per mille against two Mweight-255 cores", pm(l, 1));

  // ---- H: core 1 alone
  run[2] = 0; run[3] = 0;
  config(205, 0, 1, 1, 1, 1);
  measure("H", l);
  uint32_t hard = l[1], want = (uint32_t)((uint64_t)205 * CAPACITY / 1024 / LINE * (WINDOW / PERIOD));
  config(205, 16, 1, 1, 1, 1);
  measure("H", l);
  printf("  H  core 1 alone: %d lines at Rbwb 20 %% Mweight 0 (reservation %d), %d with Mweight 16\r\n", hard, want, l[1]);
  CHECK(hard + 2 >= want && hard <= want + 2, "H: hard limit gave %d lines, reservation %d", hard, want);
  CHECK(l[1] >= 2 * hard, "H: Mweight 16 alone gave %d lines, no more than twice the hard limit's %d", l[1], hard);

  // ---- M: exact, with the workers stopped and everything drained at both ends
  run[1] = 0;
  config(300, 8, 300, 8, 100, 8);
  run[1] = 1; run[2] = 1; run[3] = 1;
  wait_cycles(PERIOD);
  {
    uint32_t r0[4], r1[4], w0[4], w1[4];
    uint64_t mv[4];
    for (int c = 1; c < 4; c++) run[c] = 0;
    wait_cycles(2 * PERIOD);
    CHECK(mon(1, 1, 1) == 1 && mon(1, 2, 2) == 1 && mon(1, 3, 3) == 1, "M: CONFIG_EVENT failed");
    apmu_read(r0);
    for (int c = 1; c < 4; c++) w0[c] = apmu_wr(c);
    for (int c = 1; c < 4; c++) run[c] = 1;
    wait_cycles(WINDOW);
    for (int c = 1; c < 4; c++) run[c] = 0;
    wait_cycles(2 * PERIOD);
    for (int c = 1; c < 4; c++) { mon(2, c, 0); mv[c] = rd64(BC_MON_VAL); }
    apmu_read(r1);
    for (int c = 1; c < 4; c++) w1[c] = apmu_wr(c);
    uint64_t want[4];
    want[1] = (uint64_t)(r1[1] - r0[1] + w1[1] - w0[1]) * LINE;
    want[2] = (uint64_t)(r1[2] - r0[2]) * LINE;
    want[3] = (uint64_t)(w1[3] - w0[3]) * LINE;
    for (int c = 1; c < 4; c++) {
      printf("  M  MCID %d (EVT %d): counter %d bytes, APMU %d bytes (reads %d, writes %d)\r\n", c, c,
             (int)(mv[c] & ((1ULL << 62) - 1)), (int)want[c], r1[c] - r0[c], w1[c] - w0[c]);
      CHECK(!(mv[c] >> 62) && (mv[c] & ((1ULL << 62) - 1)) == want[c], "M: MCID %d counted %d bytes, the APMU %d",
            c, (int)(mv[c] & ((1ULL << 62) - 1)), (int)want[c]);
    }
  }

  // ---- done: pool statistics, everything back to the reset state
  uint32_t pool = REG32(BC + BC_POOL), full = REG32(BC + BC_FULL);
  printf("  pool: high-water mark %d descriptors, %d cycles full\r\n", (pool >> 8) & 0xFF, full);
  for (int c = 1; c < 4; c++) run[c] = 0;
  REG32(BC + BC_CTRL) = 2;
  REG32(DM + 0x00) = 0;
  config(1, 1, 1, 1, 1, 1);
  SRMCFG_W(0);
  return soc_test_end();
}
