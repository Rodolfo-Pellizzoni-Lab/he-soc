// Device DMA tags: per-job tags from the job queue, address-range tags and the socket's tag rules
// (hardware/docs/qos.md "Device DMA", hardware/accel/README.md).
//
// Slot 0 (example, template engine with the job queue) and slot 1 (crc32, single job, reads only).
//   1. capabilities and reset values: QOS_CAP, LAST_SRC, QSTAT, DROPPED, TAG_POLICY / range-entry write masks
//   2. per-job tags: three jobs queued by core 0 with three srmcfg values; each job's completion record carries the
//      tag of its SUBMIT write, LAST_USER the last job's (its completion write), LAST_SRC "device"
//   3. other submitters: cores 1 and 2 queue a job each with their own srmcfg: the tags name them (source port)
//   4. a full queue: the job past the depth is dropped (QSTAT.OVF, DROPPED) and never runs; the others do
//   5. privilege association (if built): an M-mode SUBMIT with mqosctl.M set carries mqosid
//   6. address ranges: lowest entry wins, BASE / LIMIT inclusive, V and slot bits, RANGE_EN / DEV_OFF / FORCE,
//      a miss falls back to the device's tag or the default; crc32 matched by a slot-1-only entry
// Builds without the queue (ACCEL_JOB_DEPTH=0) or the table (SOC_QOS_RANGES=0) check that they are absent.
#include "accel.h"

#define SLOT 0                                   // example: job queue
#define CRC  1                                   // crc32
#define NJ   8
#define W    96                                  // words of a long job
#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")
static inline uint64_t ids(unsigned r, unsigned m) { return r | ((uint64_t)m << 16); }
#define U(p, r, m) ACCEL_USER(p, r, m)
#define FENCE() __asm__ volatile("fence" ::: "memory")

static volatile accel_desc_t desc[NJ] __attribute__((aligned(64)));
static volatile uint64_t bsrc[NJ][W] __attribute__((aligned(64)));
static volatile uint64_t bdst[NJ][W] __attribute__((aligned(64)));
static volatile uint64_t pg[4][512] __attribute__((aligned(4096)));    // four consecutive pages for the ranges

SOC_SRAM static volatile uint32_t go, submitted[4];

static void mkjob(int j, uint32_t len, uint32_t arg) {
  for (uint32_t i = 0; i < len; i++) { bsrc[j][i] = 0x1000u * (j + 1) + i; bdst[j][i] = 0; }
  desc[j].src = (uintptr_t)bsrc[j]; desc[j].dst = (uintptr_t)bdst[j];
  desc[j].len = len; desc[j].arg = arg; desc[j].cpl = 0;
}
static int wait_cpl(int j) {
  for (long t = 0; t < 400000; t++) if (desc[j].cpl & ACCEL_CPL_DONE) return 0;
  return -1;
}
static int data_ok(int j) {
  for (uint32_t i = 0; i < desc[j].len; i++) if (bdst[j][i] != bsrc[j][i] + desc[j].arg) return 0;
  return 1;
}
// check job j's completion: done, no error, tag
static void check_job(int j, uint32_t tag, const char *what) {
  CHECK(wait_cpl(j) == 0, "%s: job %d completed", what, j);
  uint64_t c = desc[j].cpl;
  CHECK(!(c & ACCEL_CPL_ERR), "%s: job %d without bus error (completion %08x%08x)", what, j, H64(c));
  CHECK(ACCEL_CPL_TAG(c) == tag, "%s: job %d tag 0x%x, expected 0x%x", what, j, ACCEL_CPL_TAG(c), tag);
  CHECK(data_ok(j), "%s: job %d data", what, j);
}

// one job through the registers (START) on slot 0: LEN words from s to d
static int run_regs(uint64_t s, uint64_t d, uint32_t n) {
  accel_wr64(SLOT, 0x08, s); accel_wr64(SLOT, 0x10, d); accel_wr(SLOT, 0x18, n); accel_wr(SLOT, 0x1C, 1);
  FENCE();
  accel_wr(SLOT, 0x00, 0x1);
  if (accel_wait(SLOT, 0x04, 0x3, 0x2, 1000000) != 0) return -1;
  accel_wr(SLOT, 0x04, 0x2);
  return 0;
}
// a CRC over 8 bytes at s on slot 1 (one read)
static int run_crc(uint64_t s) {
  accel_wr64(CRC, 0x08, s); accel_wr(CRC, 0x10, 8);
  FENCE();
  accel_wr(CRC, 0x00, 0x1);
  if (accel_wait(CRC, 0x04, 0x3, 0x2, 1000000) != 0) return -1;
  accel_wr(CRC, 0x04, 0x2);
  return 0;
}
// the tag and the rule of slot s's last DMA request
static void check_last(int s, uint32_t tag, uint32_t src, unsigned idx, const char *what) {
  uint32_t u = REG32(ACCEL_LAST_USER(s)), l = REG32(ACCEL_LAST_SRC(s));
  uint32_t want = src | (src == ACCEL_SRC_RANGE ? idx << 8 : 0);
  CHECK(u == tag && l == want, "%s: LAST_USER 0x%x LAST_SRC 0x%x, expected 0x%x / 0x%x", what, u, l, tag, want);
}

// csrr of CSR n in M mode; returns the mcause of the trap it raised, 0 if none (the CSR exists)
#define TRY_CSRR(n) ({ uint64_t _c, _o;                                                        \
  __asm__ volatile("csrr %[o], mtvec\n la t0, 1f\n csrw mtvec, t0\n li %[c], 0\n csrr t1, " #n "\n" \
                   "j 2f\n .align 2\n 1: csrr %[c], mcause\n la t0, 2f\n csrw mepc, t0\n mret\n"     \
                   "2: csrw mtvec, %[o]\n"                                                      \
                   : [c] "=&r"(_c), [o] "=&r"(_o) :: "t0", "t1", "memory");                      \
  _c; })

// cores 1 and 2 queue one job each (jobs 3 and 4) with their own srmcfg
int thread_entry(int cid, int nc) {
  (void)nc;
  if (cid == 0) return 0;
  soc_install_trap_guard();
  if (cid == 1 || cid == 2) {
    while (!go) __asm__ volatile("nop");
    SRMCFG_W(cid == 1 ? ids(6, 11) : ids(10, 4));
    accel_submit(SLOT, &desc[2 + cid]);
    submitted[cid] = 1;
  }
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  soc_test_begin("t_iojob");
  CHECK(accel_rd(SLOT, 0x20) == 0xAC0C9B9Fu, "slot 0 ID 0x%x (expected the example engine)", accel_rd(SLOT, 0x20));
  CHECK(accel_rd(CRC, 0x20) == 0xC3C32001u, "slot 1 ID 0x%x (expected crc32)", accel_rd(CRC, 0x20));
  const uint32_t tagmask = (1u << (ACCEL_SRC_BITS + 9)) - 1;             // UserWidth: port, RCID, MCID, AT

  // ---- 1. capabilities and reset values
  uint32_t cap0 = REG32(ACCEL_QOS_CAP(SLOT)), cap1 = REG32(ACCEL_QOS_CAP(CRC));
  unsigned nr = (cap0 >> 8) & 0xFF;
  CHECK((cap0 & 0xFFFF00FEu) == 0 && (cap0 & 1) && cap1 == cap0, "QOS_CAP slot 0 0x%x, slot 1 0x%x (JOB, same table)", cap0, cap1);
  CHECK(REG32(ACCEL_LAST_SRC(SLOT)) == 0 && REG32(ACCEL_LAST_USER(SLOT)) == 0, "LAST_SRC / LAST_USER before any DMA");
  uint32_t qs = accel_rd(SLOT, ACCEL_QSTAT);
  unsigned depth = (qs >> 8) & 0xFF;
  CHECK((qs & 0x100FFu) == 0 && accel_rd(SLOT, ACCEL_DROPPED) == 0, "QSTAT 0x%x / DROPPED at reset", qs);
  CHECK(accel_rd(CRC, ACCEL_QSTAT) == 0, "crc32 has no job queue (QSTAT 0x%x)", accel_rd(CRC, ACCEL_QSTAT));
  printf("socket: %u range entries; example: job queue depth %u\r\n", nr, depth);
  REG32(ACCEL_TAG_POLICY(SLOT)) = 0xFFFFFFFFu;
  uint32_t pm = REG32(ACCEL_TAG_POLICY(SLOT));
  CHECK(pm == (0xE0000000u | tagmask), "TAG_POLICY write mask: all ones read 0x%x (expected 0x%x)", pm, 0xE0000000u | tagmask);
  REG32(ACCEL_TAG_POLICY(SLOT)) = 0;
  if (nr) {
    REG32(ACCEL_RANGE(0) + 8) = 0xFFFFFFFFu;
    REG32(ACCEL_RANGE(0))     = 0xFFFFFFFFu;
    REG32(ACCEL_RANGE(0) + 4) = 0x12345678u;
    uint32_t cf = REG32(ACCEL_RANGE(0) + 8), b = REG32(ACCEL_RANGE(0)), l = REG32(ACCEL_RANGE(0) + 4);
    CHECK(cf == (0x80FF0000u | tagmask) && b == 0xFFFFFFFFu && l == 0x12345678u,
          "range entry 0 write masks: CFG 0x%x BASE 0x%x LIMIT 0x%x", cf, b, l);
    REG32(ACCEL_RANGE(0) + 8) = 0; REG32(ACCEL_RANGE(0)) = 0; REG32(ACCEL_RANGE(0) + 4) = 0;
    CHECK(REG32(ACCEL_RANGE(nr - 1) + 8) == 0 && REG32(ACCEL_RANGE(nr - 1) + 12) == 0, "last range entry at reset");
  }
  CHECK(REG32(ACCEL_RANGE(nr)) == 0xdeadbeefu, "past the range table: DECERR (0x%x)", REG32(ACCEL_RANGE(nr)));

  // ---- 2. per-job tags: one hart, three srmcfg values, three queued jobs
  if (depth >= 2) {
    const unsigned r[3] = {2, 5, 9}, m[3] = {1, 3, 7};
    const uint32_t len[3] = {W, 5, 7};
    for (int j = 0; j < 3; j++) mkjob(j, len[j], 10 + j);
    uint32_t q = 0;
    for (int j = 0; j < 3; j++) { SRMCFG_W(ids(r[j], m[j])); q = accel_submit(SLOT, &desc[j]); }
    SRMCFG_W(0);
    CHECK((q & 0xFF) == 2, "after three SUBMITs %u jobs wait (expected 2, the long job 0 running)", q & 0xFF);
    for (int j = 0; j < 3; j++) check_job(j, U(0, r[j], m[j]), "one hart, three tags");
    CHECK((accel_rd(SLOT, ACCEL_QSTAT) & 0xFF) == 0, "queue empty afterwards");
    CHECK(accel_rd(SLOT, ACCEL_TAG_REG) == U(0, 9, 7), "TAG = the last job's (0x%x)", accel_rd(SLOT, ACCEL_TAG_REG));
    check_last(SLOT, U(0, 9, 7), ACCEL_SRC_DEV, 0, "after the jobs");
    CHECK(ACCEL_CPL_CYCLES(desc[0].cpl) > 2 * W, "job 0 took %u cycles", ACCEL_CPL_CYCLES(desc[0].cpl));
    printf("per-job tags: jobs tagged 0x%x 0x%x 0x%x (RCID/MCID 2/1 5/3 9/7), job 0 %u cycles\r\n",
           ACCEL_CPL_TAG(desc[0].cpl), ACCEL_CPL_TAG(desc[1].cpl), ACCEL_CPL_TAG(desc[2].cpl), ACCEL_CPL_CYCLES(desc[0].cpl));
    accel_wr(SLOT, 0x04, 0x2);

    // ---- 3. other submitters
    mkjob(3, 9, 20); mkjob(4, 11, 21);
    FENCE();
    CHECK(soc_wake_all() == SOC_WAKE_MASK, "cores 2..%d started", SOC_NUM_CORES - 1);
    go = 1;
    for (long t = 0; t < 2000000 && !(submitted[1] && submitted[2]); t++) __asm__ volatile("nop");
    CHECK(submitted[1] && submitted[2], "cores 1 and 2 submitted");
    check_job(3, U(1, 6, 11), "core 1's job");
    check_job(4, U(2, 10, 4), "core 2's job");
    printf("other submitters: core 1 -> 0x%x, core 2 -> 0x%x\r\n", ACCEL_CPL_TAG(desc[3].cpl), ACCEL_CPL_TAG(desc[4].cpl));
    accel_wr(SLOT, 0x04, 0x2);
  }

  // ---- 4. a full queue
  if (depth >= 1 && depth + 2 <= NJ) {
    const int n = depth + 2;                          // job 0 runs, jobs 1..depth wait, job depth+1 is dropped
    mkjob(0, W, 30);
    for (int j = 1; j < n; j++) mkjob(j, 2, 30 + j);
    SRMCFG_W(ids(3, 2));
    uint32_t q = 0;
    for (int j = 0; j < n; j++) q = accel_submit(SLOT, &desc[j]);
    SRMCFG_W(0);
    uint32_t drop = accel_rd(SLOT, ACCEL_DROPPED);
    CHECK((q & 0xFF) == depth && (q & ACCEL_QSTAT_OVF), "full: QSTAT 0x%x (expected %u waiting and OVF)", q, depth);
    CHECK(drop == 1, "DROPPED %u (expected 1)", drop);
    for (int j = 0; j < n - 1; j++) check_job(j, U(0, 3, 2), "full queue");
    for (long t = 0; t < 20000; t++) __asm__ volatile("nop");
    CHECK(desc[n - 1].cpl == 0 && bdst[n - 1][0] == 0, "the dropped job never ran");
    accel_wr(SLOT, ACCEL_QSTAT, ACCEL_QSTAT_OVF);
    q = accel_rd(SLOT, ACCEL_QSTAT);
    CHECK(!(q & ACCEL_QSTAT_OVF) && accel_rd(SLOT, ACCEL_DROPPED) == 1, "OVF cleared (QSTAT 0x%x), DROPPED kept", q);
    printf("full queue: %d submitted, %u ran, 1 dropped\r\n", n, depth + 1);
    accel_wr(SLOT, 0x04, 0x2);
  } else if (depth == 0) {
    mkjob(0, 2, 1);
    uint32_t q = accel_submit(SLOT, &desc[0]);
    for (long t = 0; t < 20000; t++) __asm__ volatile("nop");
    CHECK(q == 0 && desc[0].cpl == 0 && accel_rd(SLOT, ACCEL_DROPPED) == 0, "no queue: SUBMIT ignored (QSTAT 0x%x)", q);
    printf("job queue absent: SUBMIT ignored\r\n");
  }

  // ---- 5. privilege association: an M-mode doorbell carries mqosid when mqosctl.M is set
  if (depth >= 1 && TRY_CSRR(0x7C1) == 0) {
    mkjob(0, 3, 40);
    SRMCFG_W(ids(1, 1));
    __asm__ volatile("csrw 0x7C0, %0\n csrw 0x7C1, 1" :: "r"(ids(13, 4)) : "memory");   // mqosid, mqosctl.M
    accel_submit(SLOT, &desc[0]);
    __asm__ volatile("csrw 0x7C1, zero\n csrw 0x7C0, zero" ::: "memory");
    SRMCFG_W(0);
    check_job(0, U(0, 13, 4), "M-mode doorbell with mqosctl.M");
    printf("privilege association: the M-mode SUBMIT carried mqosid 0x%x\r\n", ACCEL_CPL_TAG(desc[0].cpl));
    accel_wr(SLOT, 0x04, 0x2);
  }

  // ---- 6. address ranges (jobs through the registers: the last DMA request is the write of the last word)
  const uint32_t D = U(0, 14, 10);                            // the slots' default tag
  const uint64_t P0 = (uintptr_t)pg[0], P1 = (uintptr_t)pg[1], P2 = (uintptr_t)pg[2], P3 = (uintptr_t)pg[3];
  const uint64_t S = (uintptr_t)bsrc[7];
  bsrc[7][0] = 0x77;
  SRMCFG_W(ids(2, 2));                                        // the device's tag: core 0, RCID 2, MCID 2
  const uint32_t DEV = U(0, 2, 2);
  if (nr >= 4) {
    accel_range_set(0, P1, P1, ACCEL_RANGE_SLOT(0), U(0, 7, 5));
    accel_range_set(1, P0, P2, ACCEL_RANGE_SLOT(0) | ACCEL_RANGE_SLOT(1), U(0, 8, 6));
    accel_range_set(2, P3, P3, ACCEL_RANGE_SLOT(0), U(0, 1, 1));
    REG32(ACCEL_RANGE(2) + 8) &= ~ACCEL_RANGE_V;              // entry 2 invalid
    accel_range_set(3, P3, P3, ACCEL_RANGE_SLOT(1), U(0, 11, 9));
    FENCE();

    REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_RANGE_EN | D;
    CHECK(run_regs(S, P1, 1) == 0, "range job 1");
    check_last(SLOT, U(0, 7, 5), ACCEL_SRC_RANGE, 0, "page P1: entries 0 and 1 match, 0 wins");
    CHECK(run_regs(S, P0, 1) == 0, "range job 2");
    check_last(SLOT, U(0, 8, 6), ACCEL_SRC_RANGE, 1, "first word of P0 (BASE inclusive)");
    CHECK(run_regs(S, P2 + 4088, 1) == 0, "range job 3");
    check_last(SLOT, U(0, 8, 6), ACCEL_SRC_RANGE, 1, "last word of P2 (LIMIT inclusive)");
    CHECK(run_regs(S, P3, 1) == 0, "range job 4");
    check_last(SLOT, DEV, ACCEL_SRC_DEV, 0, "P3: entry 2 invalid, entry 3 for slot 1 only -> the device's tag");
    REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_RANGE_EN | ACCEL_POLICY_DEV_OFF | D;
    CHECK(run_regs(S, P3, 1) == 0, "range job 5");
    check_last(SLOT, D, ACCEL_SRC_DEFAULT, 0, "P3 with DEV_OFF -> the default");
    CHECK(run_regs(S, P1, 1) == 0, "range job 6");
    check_last(SLOT, U(0, 7, 5), ACCEL_SRC_RANGE, 0, "P1 with DEV_OFF -> still entry 0");
    REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_FORCE | ACCEL_POLICY_RANGE_EN | D;
    CHECK(run_regs(S, P1, 1) == 0, "range job 7");
    check_last(SLOT, D, ACCEL_SRC_FORCE, 0, "P1 with FORCE -> the default");
    REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_RANGE_EN | D;
    REG32(ACCEL_RANGE(0) + 8) &= ~ACCEL_RANGE_V;
    CHECK(run_regs(S, P1, 1) == 0, "range job 8");
    check_last(SLOT, U(0, 8, 6), ACCEL_SRC_RANGE, 1, "P1 with entry 0 invalid -> entry 1");
    REG32(ACCEL_TAG_POLICY(SLOT)) = 0;
    CHECK(run_regs(S, P1, 1) == 0, "range job 9");
    check_last(SLOT, DEV, ACCEL_SRC_DEV, 0, "P1 without RANGE_EN -> the device's tag");
    CHECK(pg[1][0] == 0x78 && pg[2][511] == 0x78 && pg[3][0] == 0x78, "range jobs' data");

    // crc32 (slot 1): its last DMA request is its read
    REG32(ACCEL_TAG_POLICY(CRC)) = ACCEL_POLICY_RANGE_EN | ACCEL_POLICY_DEV_OFF | D;
    CHECK(run_crc(P3) == 0, "crc job 1");
    check_last(CRC, U(0, 11, 9), ACCEL_SRC_RANGE, 3, "crc32 reads P3: entry 3 (slot 1 only)");
    CHECK(run_crc(P1) == 0, "crc job 2");
    check_last(CRC, U(0, 8, 6), ACCEL_SRC_RANGE, 1, "crc32 reads P1: entry 1 (slots 0 and 1)");
    CHECK(run_crc(S) == 0, "crc job 3");
    check_last(CRC, D, ACCEL_SRC_DEFAULT, 0, "crc32 reads outside the ranges with DEV_OFF -> the default");
    REG32(ACCEL_TAG_POLICY(CRC)) = 0;
    CHECK(run_crc(S) == 0, "crc job 4");
    check_last(CRC, DEV, ACCEL_SRC_DEV, 0, "crc32 without a policy -> the device's tag");
    for (unsigned k = 0; k < 4; k++) REG32(ACCEL_RANGE(k) + 8) = 0;
    printf("ranges: lowest entry wins, inclusive bounds, V / slot bits, RANGE_EN / DEV_OFF / FORCE checked\r\n");
  } else {
    REG32(ACCEL_TAG_POLICY(SLOT)) = ACCEL_POLICY_RANGE_EN | D;
    CHECK(run_regs(S, P1, 1) == 0, "job without a range table");
    check_last(SLOT, DEV, ACCEL_SRC_DEV, 0, "no range table: RANGE_EN has nothing to match");
    REG32(ACCEL_TAG_POLICY(SLOT)) = 0;
    printf("range table absent\r\n");
  }
  SRMCFG_W(0);
  return soc_test_end();
}
