// CBQRI capacity controller of the LLC (hardware/docs/qos.md): way partitioning by RCID and access type.
//  1. register interface at 0x1040_1800: cc_capabilities, monitoring absent, READ_LIMIT / CONFIG_LIMIT round trips,
//     the STATUS codes (2 bad OP, 3 bad RCID, 4 bad AT, 5 empty mask), BUSY always 0
//  2. isolation: 8 "victim" lines (RCID 1) and 40 "aggressor" lines (RCID 2) in one LLC set. With disjoint masks
//     (ways 0-7 / 8-15) the victims stay in the LLC: reading them again causes no LLC read miss (SoC control LLC
//     miss counter). With shared masks (RCIDs 10 / 11) the aggressors evict them: 8 more misses
//  3. code vs data: RCID 3 with data mask ways 0-3 and code mask ways 4-7 runs code that was never fetched
//  4. 4 cores, RCIDs 4-7 with disjoint 4-way data masks, write and read 16 lines each in one shared LLC set
// The LLC checks every refill against the mask of its (RCID, AT) in simulation; sim_status(run_id, qos=true)
// shows the "llc_alloc" lines (ways used per RCID/AT) and the check summaries.
#include "soc_test.h"

#define NC        4
#define CC        0x10401800UL           // LLC CBQRI capacity controller
#define CC_CAPS   0x00
#define CC_MON    0x08
#define CC_MONV   0x10
#define CC_ALLOC  0x18
#define CC_MASK   0x20
#define CC_CUNITS 0x28
#define OP_CONFIG 1
#define OP_READ   2

#define REGION    0x80400000UL           // LLC-cached DRAM not used by the program (the LLC caches 0x8000_0000-0x807F_FFFF)
#define SET_STEP  0x10000UL              // 1024 sets x 64 B: lines 64 KB apart share an LLC set (and an L1 set)
#define L1_STEP   0x800UL                // lines 2 KB apart share an L1 set but not an LLC set

#define SOC_CTRL      0x1A106000UL     // SoC control registers: LLC event counters
#define LLC_CNT_EN    0x04
#define LLC_RD_MISS   0x08

#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

static uint64_t cc_rd(unsigned off) { return REG32(CC + off) | ((uint64_t)REG32(CC + off + 4) << 32); }
// returns STATUS; checks BUSY = 0
static unsigned cc_op(unsigned op, unsigned at, unsigned rcid) {
  REG32(CC + CC_ALLOC) = op | (at << 5) | (rcid << 8);
  uint32_t hi = REG32(CC + CC_ALLOC + 4);
  CHECK(!(hi & 0x80), "cc_alloc_ctl BUSY set after op %d", op);
  return hi & 0x7F;
}
static void set_limit(unsigned rcid, unsigned at, uint32_t mask) {
  REG32(CC + CC_MASK) = mask;
  unsigned st = cc_op(OP_CONFIG, at, rcid);
  CHECK(st == 1, "CONFIG_LIMIT rcid %d at %d mask 0x%x: status %d", rcid, at, mask, st);
}
static uint32_t get_limit(unsigned rcid, unsigned at) {
  unsigned st = cc_op(OP_READ, at, rcid);
  CHECK(st == 1, "READ_LIMIT rcid %d at %d: status %d", rcid, at, st);
  return REG32(CC + CC_MASK);
}

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }

// push the lines of L1 set `off` out of the L1 (random replacement: 64 other lines of that L1 set)
static void l1_sweep(uint64_t off) {
  uint64_t s = 0;
  for (int j = 1, n = 0; n < 64; j++) {
    if (j % 32 == 0) continue;           // those would land in LLC set 0 again
    s += ld(REGION + 0x200000UL + off + j * L1_STEP);
    n++;
  }
  __asm__ volatile("" :: "r"(s));
}

// one isolation experiment in LLC set `off` (victims RCID rv, aggressors RCID ra); returns the LLC read misses
// while reading the 8 victims again
static uint32_t isolation(uint64_t off, unsigned rv, unsigned ra) {
  uint64_t s = 0;
  SRMCFG_W(rv);
  for (int k = 0; k < 8; k++) s += ld(REGION + off + k * SET_STEP);
  SRMCFG_W(ra);
  for (int r = 0; r < 2; r++)
    for (int k = 8; k < 48; k++) s += ld(REGION + off + k * SET_STEP);
  l1_sweep(off);
  SRMCFG_W(rv);
  uint32_t m0 = REG32(SOC_CTRL + LLC_RD_MISS);
  for (int k = 0; k < 8; k++) s += ld(REGION + off + k * SET_STEP);
  uint32_t m = REG32(SOC_CTRL + LLC_RD_MISS) - m0;
  __asm__ volatile("" :: "r"(s));
  return m;
}

// never executed before the code/data phase, so its fetches miss in the LLC
__attribute__((noinline, aligned(64))) static void cold_code(void) {
  __asm__ volatile(".option push\n.option norvc\n.rept 256\naddi x0, x0, 0\n.endr\n.option pop");
}

SOC_SRAM static volatile uint64_t stress_sum[NC];

static void stress(int c) {
  SRMCFG_W(4 + c);
  uint64_t s = 0;
  for (int pass = 0; pass < 3; pass++) {
    for (int j = 0; j < 16; j++) {
      volatile uint64_t *p = (volatile uint64_t *)(REGION + 0x80 + (c * 16 + j) * SET_STEP);
      if (pass == 0) *p = ((uint64_t)c << 32) | j;
      else           s += *p;
    }
  }
  stress_sum[c] = s;
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_cbqri");
    return 0;                       // core 0 continues in main()
  }
  soc_barrier(NC, 1);              // core 0 has configured the stress masks
  stress(cid);
  soc_barrier(NC, 2);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  // 1. register interface
  uint64_t caps = cc_rd(CC_CAPS);
  printf("cc_capabilities 0x%08x%08x\r\n", H64(caps));
  CHECK((caps & 0xFF) == 0x10, "VER 0x%x", (unsigned)(caps & 0xFF));
  CHECK(((caps >> 8) & 0xFFFF) == 16, "NCBLKS %d", (int)((caps >> 8) & 0xFFFF));
  CHECK((caps >> 24) == 0, "FRCID/CUNITS/RPFX/P not 0: %08x%08x", H64(caps));
  CHECK(cc_rd(CC_MON) == 0 && cc_rd(CC_MONV) == 0 && cc_rd(CC_CUNITS) == 0, "monitoring / cunits not zero");
  CHECK(get_limit(0, 0) == 0xFFFF && get_limit(0, 1) == 0xFFFF && get_limit(15, 1) == 0xFFFF, "reset masks not all ways");
  REG32(CC + CC_MASK) = 0xFFFF;
  CHECK(cc_op(0, 0, 0) == 2, "OP 0: status not 2");
  CHECK(cc_op(3, 0, 0) == 2, "FLUSH_RCID (FRCID = 0): status not 2");
  CHECK(cc_op(OP_CONFIG, 0, 16) == 3, "RCID 16: status not 3");
  CHECK(cc_op(OP_CONFIG, 2, 0) == 4, "AT 2: status not 4");
  REG32(CC + CC_MASK) = 0;
  CHECK(cc_op(OP_CONFIG, 0, 9) == 5, "empty mask: status not 5");
  CHECK(get_limit(9, 0) == 0xFFFF, "a refused CONFIG_LIMIT changed the mask");
  set_limit(9, 1, 0x0F0F);
  CHECK(get_limit(9, 1) == 0x0F0F && get_limit(9, 0) == 0xFFFF, "per-AT masks: code 0x%x data 0x%x",
        get_limit(9, 1), get_limit(9, 0));
  REG32(CC + CC_MASK) = 0xFFFFFFFF;
  CHECK(REG32(CC + CC_MASK) == 0xFFFF, "cc_block_mask bits above NCBLKS not read-only zero: 0x%x", REG32(CC + CC_MASK));

  // 2. isolation (data accesses: AT 0)
  REG32(SOC_CTRL + LLC_CNT_EN) = 1;
  (void)isolation(0x0C0, 12, 13);                       // warm-up: brings this code into the LLC, so the miss
                                                        // counter sees only the victims below
  set_limit(1, 0, 0x00FF);
  set_limit(2, 0, 0xFF00);
  uint32_t m_part = isolation(0x000, 1, 2);             // victims RCID 1 (ways 0-7), aggressors RCID 2 (ways 8-15)
  uint32_t m_shared = isolation(0x040, 10, 11);         // RCIDs 10 and 11 keep the reset masks (all ways)
  printf("victims read again: %d LLC read misses with disjoint masks, %d with shared masks\r\n", m_part, m_shared);
  CHECK(m_part == 0, "disjoint masks: the victims were evicted (%d LLC read misses)", m_part);
  CHECK(m_shared >= 8, "shared masks: the victims were not evicted (%d LLC read misses)", m_shared);

  // 3. code and data of one RCID in different ways
  set_limit(3, 0, 0x000F);
  set_limit(3, 1, 0x00F0);
  SRMCFG_W(3);
  cold_code();
  SRMCFG_W(0);

  // 4. four cores, disjoint data masks, one shared LLC set
  for (int c = 0; c < NC; c++) set_limit(4 + c, 0, 0xFu << (4 * c));
  soc_wake_all();
  soc_barrier(NC, 1);
  stress(0);
  soc_barrier(NC, 2);
  SRMCFG_W(0);
  for (int c = 0; c < NC; c++) {
    uint64_t want = 2 * (16 * ((uint64_t)c << 32) + 120);
    CHECK(stress_sum[c] == want, "core %d read back %08x%08x", c, H64(stress_sum[c]));
  }
  return soc_test_end();
}
