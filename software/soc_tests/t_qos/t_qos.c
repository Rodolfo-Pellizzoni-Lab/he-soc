// Ssqosid QoS identifiers (hardware/docs/qos.md): the srmcfg CSR and the {AT, MCID, RCID} tag that every core
// request carries in the AXI user field.
//  - srmcfg: reset value 0; WARL (only the implemented RCID / MCID bits stick); readable in M and S mode, illegal
//    instruction in U mode, virtual-instruction exception in VS and VU mode
//  - QoS probe of the accelerator socket (0x103F_0000): each core reads back the user field of its own uncached read
//    and write: source = core index, RCID / MCID = its srmcfg, AT = 0 (data); a new srmcfg value is used by the
//    very next request
//  - cached traffic: each core streams over its own 16 KB DRAM buffer with a distinct tag, then core 0 stores into
//    every line of core 1's buffer (dirty in core 1's cache: the CCU moves the dirty data to core 0, whose later
//    write-backs carry core 0's tag, "llc_in src=0 .. rcid=5 mcid=9 .. aw=.." grows by ~800). The
//    simulation prints "[QOS] llc_in / llc_out src=.. at=.. rcid=.. mcid=.. ar=.. aw=.." lines at the end
//    (refills, write-backs and instruction fetches per tag), which sim_status shows as markers.
//  - AMOs and LR/SC from all cores on one DRAM counter each, and 48 written lines (12 per core) in one LLC set
//    (16 ways), so the LLC evicts dirty lines to memory.
// The simulation's QoS scoreboard (hardware/host/qos_monitor.sv) checks every request: at the LLC input against the
// tags the cores issued for that line, at the LLC output (refills, evictions) against the LLC's requests;
// sim_status(run_id, qos=true) shows its "check" lines.
#include "soc_test.h"

#define NC        4
#define QOS_PROBE 0x103F0000UL
#define SRC_BITS  2                       // ariane_axi_soc::QosUserLsb
#define BUF_WORDS (16 * 1024 / 8)
#define ITERS     20
#define REGION    0x80400000UL           // LLC-cached DRAM not used by the program
#define SET_STEP  0x10000UL              // lines 64 KB apart share an LLC set

#define SRMCFG_R() ({ uint64_t _v; __asm__ volatile("csrr %0, 0x181" : "=r"(_v)); _v; })
#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

static volatile uint64_t buf[NC][BUF_WORDS] __attribute__((aligned(64)));
static volatile uint64_t amo_ctr  __attribute__((aligned(64)));
static volatile uint64_t lrsc_ctr __attribute__((aligned(64)));
SOC_SRAM static volatile uint64_t thrash_sum[NC];

static void lrsc_inc(volatile uint64_t *p) {
  uint64_t o, f;
  do {
    __asm__ volatile("lr.d %0, (%1)" : "=r"(o) : "r"(p) : "memory");
    __asm__ volatile("sc.d %0, %1, (%2)" : "=r"(f) : "r"(o + 1), "r"(p) : "memory");
  } while (f);
}

SOC_SRAM static volatile uint64_t reset_val[NC], warl_val[NC], sum_val[NC], sum_other;
SOC_SRAM static volatile uint32_t probe_ar[NC][2], probe_aw[NC];
SOC_SRAM static volatile uint32_t turn;

static uint64_t rmask, mmask;             // implemented RCID / MCID bits (from the WARL readback)
static int rbits, mbits;

static uint64_t tag_a_r(int c) { return (5 + c) & rmask; }
static uint64_t tag_a_m(int c) { return (9 + 2 * c) & mmask; }
static uint64_t tag_b_r(int c) { return (12 - c) & rmask; }
static uint64_t tag_b_m(int c) { return (2 + c) & mmask; }
static uint64_t srmcfg(uint64_t r, uint64_t m) { return r | (m << 16); }

static int popcount(uint64_t x) { int n = 0; while (x) { n += x & 1; x >>= 1; } return n; }

static void check_user(const char *what, int c, uint32_t u, uint64_t r, uint64_t m) {
  uint32_t src = u & ((1u << SRC_BITS) - 1);
  uint64_t ur  = (u >> SRC_BITS) & rmask;
  uint64_t um  = (u >> (SRC_BITS + rbits)) & mmask;
  uint32_t at  = (u >> (SRC_BITS + rbits + mbits)) & 1;
  CHECK(src == (uint32_t)c && ur == r && um == m && at == 0,
        "core %d %s: user 0x%x = src %d rcid %d mcid %d at %d, expected src %d rcid %d mcid %d at 0",
        c, what, u, src, (int)ur, (int)um, at, c, (int)r, (int)m);
}

static void work(int c) {
  reset_val[c] = SRMCFG_R();
  SRMCFG_W(~0ULL);
  warl_val[c] = SRMCFG_R();
  uint64_t rm = warl_val[c] & 0xFFF, mm = (warl_val[c] >> 16) & 0xFFF;

  // tag A: uncached read and (in turn, the probe keeps only the last write) write of the probe
  SRMCFG_W(srmcfg((5 + c) & rm, (9 + 2 * c) & mm));
  probe_ar[c][0] = REG32(QOS_PROBE);
  while (turn != (uint32_t)c) __asm__ volatile("nop");
  REG32(QOS_PROBE) = 0;
  probe_aw[c] = REG32(QOS_PROBE + 4);
  turn = c + 1;
  // tag B takes effect on the next request
  SRMCFG_W(srmcfg((12 - c) & rm, (2 + c) & mm));
  probe_ar[c][1] = REG32(QOS_PROBE);

  // tag A again for cached traffic: refills, write-backs (visible in the [QOS] lines)
  SRMCFG_W(srmcfg((5 + c) & rm, (9 + 2 * c) & mm));
  for (int i = 0; i < BUF_WORDS; i++) buf[c][i] = ((uint64_t)c << 32) | i;
  uint64_t s = 0;
  for (int i = 0; i < BUF_WORDS; i++) s += buf[c][i];
  sum_val[c] = s;

  // atomics on shared DRAM counters
  for (int i = 0; i < ITERS; i++) {
    __atomic_fetch_add(&amo_ctr, 1, __ATOMIC_RELAXED);
    lrsc_inc(&lrsc_ctr);
  }
  // LLC evictions: 12 lines per core, 48 in one 16-way LLC set, written then read twice
  s = 0;
  for (int pass = 0; pass < 3; pass++)
    for (int j = 0; j < 12; j++) {
      volatile uint64_t *p = (volatile uint64_t *)(REGION + 0xC0 + (c * 12 + j) * SET_STEP);
      if (pass == 0) *p = ((uint64_t)c << 32) | j;
      else           s += *p;
    }
  thrash_sum[c] = s;
}

// Runs "csrr t2, srmcfg; ecall" in privilege mode mpp (0 U, 1 S) with virtualization mpv. Returns the mcause of
// the trap that ends it (an ecall cause means the read worked) and the value read in *val.
static uint64_t try_srmcfg(int mpp, int mpv, uint64_t *val) {
  uint64_t cause, v, old_mtvec;
  uint64_t clr = (3ULL << 11) | (1ULL << 39);
  uint64_t set = ((uint64_t)mpp << 11) | ((uint64_t)mpv << 39);
  __asm__ volatile(
      "csrr %[omt], mtvec\n"
      "la   t0, 1f\n"
      "csrw mtvec, t0\n"
      "csrc mstatus, %[clr]\n"
      "csrs mstatus, %[set]\n"
      "la   t0, 2f\n"
      "csrw mepc, t0\n"
      "li   t2, 0xbad\n"
      "mret\n"
      "2: csrr t2, 0x181\n"
      "ecall\n"
      ".align 2\n"
      "1: csrr %[c], mcause\n"
      "mv   %[v], t2\n"
      "csrw mtvec, %[omt]\n"
      "csrc mstatus, %[clr]\n"
      : [c] "=&r"(cause), [v] "=&r"(v), [omt] "=&r"(old_mtvec)
      : [clr] "r"(clr), [set] "r"(set)
      : "t0", "t2", "memory");
  *val = v;
  return cause;
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_qos");
    soc_wake_all();
    work(0);
    soc_barrier(NC, 1);
    uint64_t s = 0;
    for (int i = 0; i < BUF_WORDS; i += 8) buf[1][i] = (1ULL << 32) | i;   // same value: the sum stays
    for (int i = 0; i < BUF_WORDS; i++) s += buf[1][i];
    sum_other = s;
    return 0;                       // core 0 continues in main()
  }
  work(cid);
  soc_barrier(NC, 1);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  rmask = warl_val[0] & 0xFFF;
  mmask = (warl_val[0] >> 16) & 0xFFF;
  rbits = popcount(rmask);
  mbits = popcount(mmask);
  printf("srmcfg: RCID %d bits, MCID %d bits\r\n", rbits, mbits);
  CHECK(rmask && !(rmask & (rmask + 1)) && mmask && !(mmask & (mmask + 1)) && warl_val[0] == srmcfg(rmask, mmask),
        "srmcfg after writing all ones: %08x%08x", H64(warl_val[0]));
  for (int c = 0; c < NC; c++) {
    CHECK(reset_val[c] == 0, "core %d srmcfg reset value %08x%08x", c, H64(reset_val[c]));
    CHECK(warl_val[c] == warl_val[0], "core %d srmcfg WARL readback %08x%08x", c, H64(warl_val[c]));
    check_user("probe read, tag A", c, probe_ar[c][0], tag_a_r(c), tag_a_m(c));
    check_user("probe write, tag A", c, probe_aw[c], tag_a_r(c), tag_a_m(c));
    check_user("probe read, tag B", c, probe_ar[c][1], tag_b_r(c), tag_b_m(c));
    uint64_t want = ((uint64_t)c << 32) * BUF_WORDS + (uint64_t)BUF_WORDS * (BUF_WORDS - 1) / 2;
    CHECK(sum_val[c] == want, "core %d buffer sum %08x%08x", c, H64(sum_val[c]));
  }
  CHECK(sum_other == sum_val[1], "core 0 wrote and read core 1's buffer: sum %08x%08x", H64(sum_other));
  CHECK(amo_ctr == NC * ITERS && lrsc_ctr == NC * ITERS, "amo counter %d, lr/sc counter %d, expected %d",
        (int)amo_ctr, (int)lrsc_ctr, NC * ITERS);
  for (int c = 0; c < NC; c++)
    CHECK(thrash_sum[c] == 2 * (12 * ((uint64_t)c << 32) + 66), "core %d LLC-thrash read back %08x%08x", c,
          H64(thrash_sum[c]));

  // privilege: the lower modes need a PMP entry (NAPOT, whole address space, RWX)
  uint64_t medeleg, v, cause, cur = SRMCFG_R();
  __asm__ volatile("csrr %0, medeleg\n csrw medeleg, zero" : "=r"(medeleg));
  __asm__ volatile("csrw pmpaddr0, %0\n csrw pmpcfg0, %1" :: "r"(~0ULL), "r"(0x1FULL));
  cause = try_srmcfg(1, 0, &v);
  CHECK(cause == 9 && v == cur, "S mode: mcause %d value %08x%08x, expected ecall (9) and %08x%08x", (int)cause,
        H64(v), H64(cur));
  cause = try_srmcfg(0, 0, &v);
  CHECK(cause == 2, "U mode: mcause %d, expected illegal instruction (2)", (int)cause);
  cause = try_srmcfg(1, 1, &v);
  CHECK(cause == 22, "VS mode: mcause %d, expected virtual instruction (22)", (int)cause);
  cause = try_srmcfg(0, 1, &v);
  CHECK(cause == 22, "VU mode: mcause %d, expected virtual instruction (22)", (int)cause);
  __asm__ volatile("csrw medeleg, %0" :: "r"(medeleg));
  return soc_test_end();
}
