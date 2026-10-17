// t_part: LLC way partitioning (CBQRI) between an accelerator's DMA and the application cores, measured as
// performance. Three principals share the 1 MB, 16-way LLC:
//   app      core 0, RCID 1: a dependent pointer chase over K = 8 lines in every LLC set (512 KB on the board),
//            which fits in 8 ways and thrashes in fewer; cycles per hop are its performance
//   streamer core 1, RCID 2: reads 16 lines per set over and over (never fits): the aggressor
//   accel    slot 0 (example), driven by core 2 with srmcfg RCID 3 so its DMA inherits that tag: in-place runs
//            over F = 4 lines per set (the same lines again after F runs: fits in 4 ways); cycles per word
// Phases set the three RCIDs' way masks, flush the LLC, run the actors, and measure; the phases are repeated with
// the DRAM timing model at the 1 GHz LPDDR4 settings (hardware/docs/dram_model.md), where a miss costs what it
// costs on a real system and the partition effects are the ones the checks hold the design to:
//   A0 app alone, all ways: hit latency        B0/B1 accel alone, all ways / 1 way
//   S  everyone shares all 16 ways             P  app 8 ways, streamer 2, accel 6 (everything fits)
//   Q  app 4 ways (too few), streamer 2, accel 6   R  app 8, streamer 2, accel 1 (too few)
#include "soc_test.h"
#include "accel.h"

#define SLOT      0
#define ARG       7u
#define NC        4
#define CC        0x10401800UL           // LLC CBQRI capacity controller
#define CC_ALLOC  0x18
#define CC_MASK   0x20
#define OP_CONFIG 1
#define LLC_FLUSH 0x10401008UL           // LLC CfgFlush: one bit per way, cleared by the LLC when the flush is done
#define SOC_CTRL      0x1A106000UL
#define LLC_CNT_EN    0x04
#define LLC_RD_MISS   0x08
#define DM         (SOC_CTRL + 0x100)    // DRAM timing model
#define DM_CTRL    0x00
#define DM_LAT_RD  0x04
#define DM_LAT_WR  0x08
#define DM_OCC16   0x0C
#define DM_ID      0x24
#define DM_ID_VAL  0xD2A30001u

#define SET_STEP  0x10000UL              // 1024 sets x 64 B: lines 64 KB apart share an LLC set
#define LINE      64UL
#define APP_BASE  0x80100000UL           // LLC-cached DRAM (0x8000_0000-0x807F_FFFF) above the program
#define STR_BASE  0x80200000UL
#define ACC_BASE  0x80400000UL
#define K   8                            // app lines per set
#define SL  16                           // streamer lines per set
#define F   4                            // accelerator lines per set (runs 64 KB apart)
#ifdef FPGA_EMULATION
#define NSETS      1024                  // every LLC set
#define SET_STRIDE 1
#define HOPS       65536
#define RUN_WORDS  4096                  // 32 KB per run: one line in each of 512 sets
#define RUNS       F                     // runs 64 KB apart: F lines per set
#else
#define NSETS      8                     // sets 0, 32, ..., 224: eight LLC sets that share one L1 set
#define SET_STRIDE 32
#define HOPS       1024
#define RUN_WORDS  8                     // one line per run
#define RUNS       (F * NSETS)           // F lines in each of the app's sets
#endif
#define WARM_RUNS  (RUNS + 1)
#define ALONE_RUNS (2 * RUNS)
#define ACC_LINES  (RUNS * RUN_WORDS / 8)
// stray misses tolerated in a "the lines survived" probe: first-touch code fetches
// on the other cores land in the global counter (visible at simulation scale)
#define NOISE      4
#define APP_KEEP   (NLINES / 64 > NOISE ? NLINES / 64 : NOISE)
#define ACC_KEEP   (ACC_LINES / 32 > NOISE ? ACC_LINES / 32 : NOISE)
#define SPIN_MAX   400000000ULL          // cycles before a wait gives up

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")
static inline uint64_t srmcfg(unsigned r, unsigned m) { return r | ((uint64_t)m << 16); }
static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }

#define CMD_STREAM 1u
#define CMD_ACCEL  2u
SOC_SRAM static volatile uint32_t cmd;
SOC_SRAM static volatile uint32_t str_busy, acc_busy;
SOC_SRAM static volatile uint64_t acc_runs, acc_cycles, acc_words, str_sink;

// ---- CBQRI
static unsigned cc_op(unsigned op, unsigned at, unsigned rcid) {
  REG32(CC + CC_ALLOC) = op | (at << 5) | (rcid << 8);
  uint32_t hi = REG32(CC + CC_ALLOC + 4);
  return hi & 0x7F;
}
static void set_limit(unsigned rcid, unsigned at, uint32_t mask) {
  REG32(CC + CC_MASK) = mask;
  unsigned st = cc_op(OP_CONFIG, at, rcid);
  CHECK(st == 1, "CONFIG_LIMIT rcid %d at %d mask 0x%x: status %d", rcid, at, mask, st);
}
static int llc_flush(void) {
  REG32(LLC_FLUSH) = 0xFFFF;
  uint64_t t0 = soc_cycles();
  while (REG32(LLC_FLUSH) != 0) if (soc_cycles() - t0 > SPIN_MAX) return -1;
  return 0;
}

// ---- app: a random cycle through K lines in each of NSETS sets, one 64-bit pointer per line
static uint64_t rng = 0x9E3779B97F4A7C15ULL;
static inline uint32_t rnd(void) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return (uint32_t)(rng >> 32); }
static inline uint64_t app_line(uint32_t i) {          // i = j * NSETS + s
  return APP_BASE + (uint64_t)(i / NSETS) * SET_STEP + (uint64_t)(i % NSETS) * SET_STRIDE * LINE;
}
#define NLINES (K * NSETS)
static void build_chain(void) {
  static uint32_t perm[NLINES];
  for (uint32_t i = 0; i < NLINES; i++) perm[i] = i;
  for (uint32_t i = NLINES - 1; i > 0; i--) {             // Sattolo: one cycle
    uint32_t j = rnd() % i;
    uint32_t t = perm[i]; perm[i] = perm[j]; perm[j] = t;
  }
  for (uint32_t i = 0; i < NLINES; i++) *(volatile uint64_t *)app_line(perm[i]) = app_line(perm[(i + 1) % NLINES]);
  __asm__ volatile("fence.i" ::: "memory");                  // write the chain back out of the L1 (it is dirty there)
}
static uint64_t chase(uint32_t hops) {                     // cycles for hops dependent loads
  uint64_t p = APP_BASE;
  uint64_t t0 = soc_cycles();
  for (uint32_t i = 0; i < hops; i += 8) {
    p = ld(p); p = ld(p); p = ld(p); p = ld(p);
    p = ld(p); p = ld(p); p = ld(p); p = ld(p);
  }
  uint64_t t1 = soc_cycles();
  __asm__ volatile("" :: "r"(p));
  return t1 - t0;
}

// ---- the other cores
static void streamer(void) {
  SRMCFG_W(srmcfg(2, 0));
  str_busy = 1;
  uint64_t s = 0;
  while (cmd & CMD_STREAM)
    for (int j = 0; j < SL && (cmd & CMD_STREAM); j++)
      for (int i = 0; i < NSETS; i++) s += ld(STR_BASE + (uint64_t)j * SET_STEP + (uint64_t)i * SET_STRIDE * LINE);
  str_sink = s;
  SRMCFG_W(0);
  str_busy = 0;
}
static void accel_driver(void) {
  SRMCFG_W(srmcfg(3, 0));                                   // the slot latches this tag at START
  acc_busy = 1;
  unsigned j = 0;
  while (cmd & CMD_ACCEL) {
    uint64_t a = ACC_BASE + (uint64_t)(j / NSETS) * SET_STEP + (uint64_t)(j % NSETS) * SET_STRIDE * LINE * (RUN_WORDS == 8);
    if (RUN_WORDS != 8) a = ACC_BASE + (uint64_t)j * SET_STEP;
    uint64_t t0 = soc_cycles();
    accel_wr64(SLOT, 0x08, a);
    accel_wr64(SLOT, 0x10, a);                              // in place: one line per word group, F lines per set
    accel_wr(SLOT, 0x18, RUN_WORDS);
    accel_wr(SLOT, 0x1C, ARG);
    accel_wr(SLOT, 0x00, 0x1);
    if (accel_wait(SLOT, 0x04, 0x3, 0x2, 100000000) != 0) break;
    accel_wr(SLOT, 0x04, 0x2);
    uint64_t t1 = soc_cycles();
    acc_cycles += t1 - t0; acc_words += RUN_WORDS; acc_runs++;
    j = (j + 1) % RUNS;
  }
  SRMCFG_W(0);
  acc_busy = 0;
}
int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 0) return 0;
  while (1) {
    if (cid == 1 && (cmd & CMD_STREAM)) streamer();
    if (cid == 2 && (cmd & CMD_ACCEL))  accel_driver();
    for (int i = 0; i < 2048; i++) __asm__ volatile("nop");   // idle cores poll the command word lazily
  }
}

// ---- one phase
typedef struct { uint32_t app_x100, acc_x100, misses, app_probe, acc_probe, acc_probe_x100; uint64_t acc_runs; } res_t;
static void snapshot(uint64_t *r, uint64_t *c, uint64_t *w) {
  do { *r = acc_runs; *c = acc_cycles; *w = acc_words; } while (*r != acc_runs);
}
static int wait_runs(uint64_t from, uint64_t n) {
  uint64_t t0 = soc_cycles();
  while (acc_runs - from < n) if (soc_cycles() - t0 > SPIN_MAX) return -1;
  return 0;
}
static int wait_flag(volatile uint32_t *f, uint32_t v) {
  uint64_t t0 = soc_cycles();
  while (*f != v) if (soc_cycles() - t0 > SPIN_MAX) return -1;
  return 0;
}
static void phase(const char *name, int use_app, int use_str, int use_acc, uint32_t m_app, uint32_t m_str,
                  uint32_t m_acc, res_t *r) {
  set_limit(1, 0, m_app); set_limit(1, 1, m_app);
  set_limit(2, 0, m_str);
  set_limit(3, 0, m_acc);
  CHECK(llc_flush() == 0, "%s: LLC flush did not finish", name);
  uint64_t r0 = acc_runs, r1, c1, w1, r2, c2, w2;
  cmd = (use_str ? CMD_STREAM : 0) | (use_acc ? CMD_ACCEL : 0);
  if (use_str) CHECK(wait_flag(&str_busy, 1) == 0, "%s: the streamer did not start", name);
  if (use_acc) {
    CHECK(wait_flag(&acc_busy, 1) == 0, "%s: the accelerator driver did not start", name);
    CHECK(wait_runs(r0, WARM_RUNS) == 0, "%s: accelerator warm-up runs", name);
  }
  if (use_app) chase(NLINES);                                 // warm-up pass
  uint32_t m0 = REG32(SOC_CTRL + LLC_RD_MISS);
  snapshot(&r1, &c1, &w1);
  uint64_t app_cycles = 0;
  if (use_app) app_cycles = chase(HOPS);
  else         CHECK(wait_runs(r1, ALONE_RUNS) == 0, "%s: accelerator runs", name);
  snapshot(&r2, &c2, &w2);
  r->misses = REG32(SOC_CTRL + LLC_RD_MISS) - m0;
  cmd = 0;
  if (use_str) CHECK(wait_flag(&str_busy, 0) == 0, "%s: the streamer did not stop", name);
  if (use_acc) CHECK(wait_flag(&acc_busy, 0) == 0, "%s: the accelerator driver did not stop", name);
  r->app_x100 = use_app ? (uint32_t)(app_cycles * 100 / HOPS) : 0;
  r->acc_runs = r2 - r1;
  r->acc_x100 = (w2 > w1) ? (uint32_t)((c2 - c1) * 100 / (w2 - w1)) : 0;
  if (use_acc) CHECK(r->acc_runs > 0, "%s: no accelerator run completed in the window", name);
  // probes, aggressors stopped: what each principal still holds in the LLC after the window
  r->app_probe = r->acc_probe = r->acc_probe_x100 = 0;
  if (use_app) {
    m0 = REG32(SOC_CTRL + LLC_RD_MISS);
    chase(NLINES);
    r->app_probe = REG32(SOC_CTRL + LLC_RD_MISS) - m0;
  }
  if (use_acc) {
    m0 = REG32(SOC_CTRL + LLC_RD_MISS);
    snapshot(&r1, &c1, &w1);
    cmd = CMD_ACCEL;
    CHECK(wait_runs(r1, RUNS) == 0, "%s: accelerator probe runs", name);
    cmd = 0;
    CHECK(wait_flag(&acc_busy, 0) == 0, "%s: the accelerator driver did not stop after the probe", name);
    snapshot(&r2, &c2, &w2);
    r->acc_probe = REG32(SOC_CTRL + LLC_RD_MISS) - m0;
    r->acc_probe_x100 = (w2 > w1) ? (uint32_t)((c2 - c1) * 100 / (w2 - w1)) : 0;
  }
  printf("  %-26s app %4d.%02d cyc/hop  accel %4d.%02d cyc/word (%d runs)  misses %d | after: app %d misses, accel %d misses %d.%02d cyc/word\r\n",
         name, r->app_x100 / 100, r->app_x100 % 100, r->acc_x100 / 100, r->acc_x100 % 100, (int)r->acc_runs, r->misses,
         r->app_probe, r->acc_probe, r->acc_probe_x100 / 100, r->acc_probe_x100 % 100);
  uart_wait_tx_done();
}

// the seven phases of one pass; strict = the DRAM model is on, hold the design to the expected effects
static void pass(const char *title, int strict) {
  res_t a0, b0, b1, s, p, q, rr;
  printf("%s\r\n", title);
  phase("A0 app alone, 16 ways",      1, 0, 0, 0xFFFF, 0xFFFF, 0xFFFF, &a0);
  phase("B0 accel alone, 16 ways",    0, 0, 1, 0xFFFF, 0xFFFF, 0xFFFF, &b0);
  phase("B1 accel alone, 1 way",      0, 0, 1, 0xFFFF, 0xFFFF, 0x0001, &b1);
  phase("S  all shared, 16 ways",     1, 1, 1, 0xFFFF, 0xFFFF, 0xFFFF, &s);
  phase("P  app 8 / str 2 / accel 6", 1, 1, 1, 0x00FF, 0x0300, 0xFC00, &p);
  phase("Q  app 4 / str 2 / accel 6", 1, 1, 1, 0x000F, 0x0300, 0xFC00, &q);
  phase("R  app 8 / str 2 / accel 1", 1, 1, 1, 0x00FF, 0x0300, 0x0400, &rr);
  // expected per partition type. Capacity (the probes, aggressors stopped): what each principal still holds.
  CHECK(p.app_probe <= APP_KEEP, "P: the app's %d lines did not survive in its 8 ways (%d misses)", NLINES, p.app_probe);
  CHECK(rr.app_probe <= APP_KEEP, "R: the app's lines did not survive in its 8 ways (%d misses)", rr.app_probe);
  CHECK(q.app_probe >= NLINES * 3 / 4, "Q: 8 lines per set in 4 ways did not thrash (%d misses)", q.app_probe);
  CHECK(s.app_probe >= NLINES / 64 && s.app_probe > 2 * p.app_probe, "S: sharing did not cost the app lines (%d misses, partitioned %d)",
        s.app_probe, p.app_probe);
  CHECK(p.acc_probe <= ACC_KEEP, "P: the accelerator's %d lines did not survive in its 6 ways (%d misses)", ACC_LINES, p.acc_probe);
  CHECK(b0.acc_probe <= ACC_KEEP, "B0: the accelerator alone with 16 ways misses (%d)", b0.acc_probe);
  CHECK(b1.acc_probe >= ACC_LINES * 3 / 4, "B1: 4 lines per set in 1 way did not thrash (%d misses)", b1.acc_probe);
  CHECK(rr.acc_probe >= ACC_LINES * 3 / 4, "R: the accelerator squeezed to 1 way did not thrash (%d misses)", rr.acc_probe);
  CHECK(s.acc_probe >= ACC_LINES / 4, "S: sharing did not cost the accelerator lines (%d misses)", s.acc_probe);
  // Latency. Under load every principal also pays the others' transactions: the coherence unit serializes them,
  // so an app hit behind a streaming core costs its own hit plus one of the streamer's misses whatever the masks.
  // What the masks decide is ordinal: partitioned <= shared, and too few ways < enough.
  CHECK(p.app_x100 <= s.app_x100, "P: partitioned is slower than shared for the app (%d vs %d)", p.app_x100, s.app_x100);
  CHECK(q.app_x100 > p.app_x100, "Q: the app with 4 ways for 8 lines per set is not slower than with 8 (%d vs %d)",
        q.app_x100, p.app_x100);
  CHECK(s.app_x100 >= a0.app_x100 * 130 / 100, "S: a streaming core costs the app nothing (%d vs alone %d)", s.app_x100, a0.app_x100);
  CHECK(rr.acc_probe_x100 > p.acc_probe_x100, "R: the accelerator with 1 way is not slower than with 6 (%d vs %d)",
        rr.acc_probe_x100, p.acc_probe_x100);
  if (strict) {   // with a real memory latency the capacity effects are large
    CHECK(q.app_x100 >= p.app_x100 * 120 / 100, "Q: too few ways cost the app under 20%% (%d vs %d)", q.app_x100, p.app_x100);
    CHECK(b1.acc_x100 >= b0.acc_x100 * 120 / 100, "B1: 1 way costs the accelerator under 20%% (%d vs %d)", b1.acc_x100, b0.acc_x100);
    CHECK(rr.acc_probe_x100 >= p.acc_probe_x100 * 120 / 100, "R: 1 way costs the accelerator under 20%% (%d vs %d)",
          rr.acc_probe_x100, p.acc_probe_x100);
    CHECK(p.acc_probe_x100 <= b0.acc_probe_x100 * 105 / 100, "P: the accelerator in its own 6 ways is not at its alone speed (%d vs %d)",
          p.acc_probe_x100, b0.acc_probe_x100);
  }
}

// Observed on the VCU118: after the chain build (512 KB of writes) and the first LLC flush, this core's LLC hits
// cost 61 cycles instead of 45, however long it chases, until the core has been idle on the bus (UART polling
// does not count) for about 1.5 M cycles after a few million cycles of that read traffic; the switch is one
// event (about 20 lines are refetched) and the fast state then persists. Idling before the reads does nothing.
// Cause not identified (hardware/accel/README.md). Every measurement starts settled: chase, idle, measure a chain
// pass, until a pass costs 47 cycles or less.
#ifdef FPGA_EMULATION
#define IDLE_CYCLES 2500000ULL
#else
#define IDLE_CYCLES 50000ULL
#endif
static void settle(void) {
  llc_flush();
  chase(NLINES);
  int round = 0;
  uint32_t x = 0;
  for (; round < 8; round++) {
    chase(HOPS);
    uint64_t t0 = soc_cycles();
    while (soc_cycles() - t0 < IDLE_CYCLES) __asm__ volatile("nop");
    x = (uint32_t)(chase(NLINES) * 100 / NLINES);
    if (x <= 4700) break;
  }
  printf("settled: a chain pass costs %d.%02d cycles per hop after %d rounds\r\n", x / 100, x % 100, round + 1);
  uart_wait_tx_done();
}

int main(void) {
  soc_test_begin("t_part");
  REG32(SOC_CTRL + LLC_CNT_EN) = 1;
  build_chain();
  SRMCFG_W(srmcfg(1, 0));
  soc_wake_all();
  settle();
  pass("DRAM timing model off:", 0);
  uint32_t tag = accel_rd(SLOT, ACCEL_TAG_REG), last = REG32(ACCEL_LAST_USER(SLOT));
  CHECK(tag == ACCEL_USER(2, 3, 0), "TAG 0x%x: the accelerator did not inherit RCID 3 from core 2", tag);
  CHECK(last == ACCEL_USER(0, 3, 0), "LAST_USER 0x%x: the DMA did not carry RCID 3", last);
  if (REG32(DM + DM_ID) == DM_ID_VAL) {
    REG32(DM + DM_CTRL) = 0;
    REG32(DM + DM_LAT_RD) = 80; REG32(DM + DM_LAT_WR) = 80; REG32(DM + DM_OCC16) = 20;
    REG32(DM + DM_CTRL) = 3;
    pass("DRAM timing model on (1 GHz target, LPDDR4-3200: LAT 80, OCC16 20):", 1);
    REG32(DM + DM_CTRL) = 0;
  } else {
    printf("no DRAM timing model in this design: the strict checks are skipped\r\n");
  }
  SRMCFG_W(0);
  for (int r = 0; r < 4; r++) { set_limit(r, 0, 0xFFFF); set_limit(r, 1, 0xFFFF); }
  return soc_test_end();
}
