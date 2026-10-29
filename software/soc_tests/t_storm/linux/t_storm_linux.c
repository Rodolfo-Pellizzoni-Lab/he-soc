// t_storm_linux: t_storm's every-master-at-once traffic under Linux, counted by the APMU (/dev/mem), on the 8-core
// bitstream. Built with the bundle's buildroot compiler:
//   riscv64-linux-gcc -O2 -static -pthread -DSOC_NUM_CORES=8 -I<he-soc>/software/quad_boot -I<t_storm dir>
//     -o t_storm_linux t_storm_linux.c
// Run as root on the board: ./t_storm_linux [rounds] [passes] [MiB per core]
// Per round (the event of the SPUs rotating through read requests, write requests, read responses, write responses):
//   a worker thread pinned to every hart writes, then reads back and checks, its own buffer, one 8-byte word per 64-byte
//   line, `passes` times; buffers of 4 MiB each are 32 times the LLC, so nearly every access misses the L1 and the LLC
//   the main thread (hart 0) keeps the accelerator socket busy meanwhile: slot 0 copies LEN0 words and slot 1 CRCs LEN1
//   bytes, in the socket's DMA pool (0x9F00_0000), job after job, each checked
//   the APMU's PE arms both slots of every core's EVU (D$ and I$ refills) and samples every counter
// Linux runs too (timer, scheduler, the SSH session), so the counts are checked against bounds, except the socket's
// port, which sees nothing but our jobs: exact. Checked: every core's memory-port traffic is its worker's (each core
// credited with what it caused, no other core), a core's SPU requests cover its EVU's D$ + I$ refills, the socket's
// port = the jobs exactly, the memory port's total covers its sources, the PE armed, sampled monotonically and
// stopped, every word of data.
#define _GNU_SOURCE
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "pmu_defines.h"
#include "pe_fw.h"

#define NC        SOC_NUM_CORES
#define LEN0      4096                     // words slot 0 copies per job
#define LEN1      16384                    // bytes slot 1 CRCs per job
#define POOL      0x9F000000UL             // the socket's DMA pool (reserved in the device tree)
#define POOL_SZ   0x01000000UL
#define ACC_SRC   0x000000UL               // offsets in the pool
#define ACC_DST   0x100000UL
#define CRC_SRC   0x200000UL
#define ACCEL     0x10000000UL
#define ACCEL_SZ  0x20000UL                // slots 0 and 1
#define APMU      0x10405000UL             // PMU_B_BASE_ADDR .. the DSPM's end
#define APMU_SZ   0x44000UL
#define EVU       0x10606000UL
#define ARG       7u
#define RING_N    32
#define PE_PERIOD 500000                   // cycles between the PE's samples (10 ms at 50 MHz)

#define C_EVU(c)  (c)                      // as in t_storm.c
#define C_SPU(c)  (NC + (c))
#define C_ACC     (2 * NC)
#define C_MEM(s)  (2 * NC + 1 + (s))
#define C_TOT     (3 * NC + 3)
#define C_EVU0    (3 * NC + 4)
#define C_DBG     (3 * NC + 5)
#define C_PMU     (3 * NC + 6)
#define NCTR      (3 * NC + 7)

static volatile uint32_t *apmu, *accel;
static volatile uint8_t *pool;
#define AP(a)     apmu[((a) - APMU) / 4]
#define ACR(s, o) accel[((s) * 0x10000 + (o)) / 4]

static void *map(const char *dev, unsigned long pa, unsigned long sz) {
  int fd = open(dev, O_RDWR | O_SYNC);
  if (fd < 0) { perror(dev); exit(2); }
  void *p = mmap(0, sz, PROT_READ | PROT_WRITE, MAP_SHARED, fd, pa);
  if (p == MAP_FAILED) { fprintf(stderr, "mmap %s 0x%lx: ", dev, pa); perror(""); exit(2); }
  return p;
}
static uint64_t now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000000000ull + t.tv_nsec; }
static void pin(int cpu) { cpu_set_t s; CPU_ZERO(&s); CPU_SET(cpu, &s); pthread_setaffinity_np(pthread_self(), sizeof s, &s); }

// ---- the workers
static int passes = 4;
static size_t buf_bytes = 4 << 20;
static pthread_barrier_t bar;
static volatile int stop_all, finished;
static uint64_t wbad[NC], wlines[NC];
#define PSTEP 0x9E3779B97F4A7C15ULL
static void *worker(void *arg) {
  const int c = (int)(uintptr_t)arg;
  pin(c);
  volatile uint64_t *b = mmap(0, buf_bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0);
  if (b == MAP_FAILED) { perror("buffer"); exit(2); }
  const size_t n = buf_bytes / 64;
  for (unsigned r = 0;; r++) {
    pthread_barrier_wait(&bar);                 // the round starts
    if (stop_all) return 0;
    uint64_t bad = 0;
    for (int p = 0; p < passes; p++) {
      uint64_t v = ((uint64_t)(c + 1) << 56) ^ ((uint64_t)r << 40) ^ ((uint64_t)p << 32);
      for (size_t i = 0; i < n; i++, v += PSTEP) b[i * 8] = v;
      v = ((uint64_t)(c + 1) << 56) ^ ((uint64_t)r << 40) ^ ((uint64_t)p << 32);
      for (size_t i = 0; i < n; i++, v += PSTEP) bad += b[i * 8] != v;
    }
    wbad[c] += bad;
    wlines[c] = n * passes;
    __sync_fetch_and_add(&finished, 1);
    pthread_barrier_wait(&bar);                 // the round's traffic is done
  }
}

// ---- the socket (main thread, hart 0): jobs until the workers are done, each checked
static uint32_t sw_crc32(const volatile uint8_t *p, uint32_t n) {
  uint32_t c = 0xFFFFFFFFu;
  for (uint32_t i = 0; i < n; i++) { c ^= p[i]; for (int k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xEDB88320u : (c >> 1); }
  return ~c;
}
static int acc_wait(int s) {
  for (long i = 0; i < 100000000; i++) { uint32_t st = ACR(s, 0x04); if ((st & 7) == 2) { ACR(s, 0x04) = 2; return 0; } if (st & 4) break; }
  return -1;
}
static uint64_t jobs, acc_bad, crc_bad, acc_fail;
static void acc_job(unsigned k) {
  volatile uint64_t *src = (volatile uint64_t *)(pool + ACC_SRC), *dst = (volatile uint64_t *)(pool + ACC_DST);
  volatile uint8_t *crc = pool + CRC_SRC;
  for (unsigned i = 0; i < LEN0; i++) { src[i] = ((uint64_t)k << 32) ^ (i * PSTEP); dst[i] = 0; }
  for (unsigned i = 0; i < LEN1; i++) crc[i] = (uint8_t)(k * 13 + i * 7 + 1);
  __sync_synchronize();
  ACR(0, 0x08) = POOL + ACC_SRC; ACR(0, 0x0C) = 0; ACR(0, 0x10) = POOL + ACC_DST; ACR(0, 0x14) = 0;
  ACR(0, 0x18) = LEN0; ACR(0, 0x1C) = ARG; ACR(0, 0x00) = 1;
  ACR(1, 0x08) = POOL + CRC_SRC; ACR(1, 0x0C) = 0; ACR(1, 0x10) = LEN1; ACR(1, 0x00) = 1;
  int e0 = acc_wait(0), e1 = acc_wait(1);
  if (e0 || e1) { acc_fail++; return; }
  for (unsigned i = 0; i < LEN0; i++) acc_bad += dst[i] != src[i] + ARG;
  crc_bad += ACR(1, 0x14) != sw_crc32(crc, LEN1);
  jobs++;
}

// ---- the APMU
static void ctr_set(int i, uint32_t sel) {
  AP(EVENT_SEL_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  AP(EVENT_INFO_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  AP(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  AP(EVENT_SEL_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = sel;
}
static void ctr_setup(unsigned ev) {
  const int rd = ev == APMU_EV_RD_REQ || ev == APMU_EV_RD_RES;
  for (int c = 0; c < NC; c++) {
    ctr_set(C_EVU(c), EVU_SLOT_SEL(c, rd ? 1 : 0));
    ctr_set(C_SPU(c), APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), ev));
  }
  ctr_set(C_ACC, APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, ev));
  for (int s = 0; s < NC + 2; s++) ctr_set(C_MEM(s), MEM_SEL(ev, s));
  ctr_set(C_TOT, APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, ev));
  ctr_set(C_EVU0, EVU_SLOT_SEL(0, rd ? 0 : 1));
  ctr_set(C_DBG, MEM_SEL(ev, APMU_SRC_XBAR(1)));
  ctr_set(C_PMU, MEM_SEL(ev, APMU_SRC_XBAR(9)));
}
static void snap(uint32_t *v) { for (int i = 0; i < NCTR; i++) v[i] = AP(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu; }
#define D(o) AP(DSPM_BASE_ADDR + (o))
static int pe_arm(void) {
  AP(PMC_STATUS_ADDR) = 1;
  D(0x000) = 0; D(0x004) = 0; D(0x008) = 0; D(0x00C) = 0; D(0x020) = 0; D(0x024) = ~0u;
  D(0x010) = NCTR; D(0x014) = PE_PERIOD; D(0x018) = RING_N; D(0x01C) = 2 * NC;
  for (int c = 0; c < NC; c++) {
    D(0x040 + 16 * c) = EVU_EID_REG(c, 0); D(0x044 + 16 * c) = 0x02;
    D(0x048 + 16 * c) = EVU_EID_REG(c, 1); D(0x04C + 16 * c) = 0x01;
  }
  __sync_synchronize();
  AP(PMC_BOOT_ADDR) = ISPM_BASE_ADDR;
  AP(PMC_STATUS_ADDR) = 0;
  for (long i = 0; i < 10000000 && D(0x000) != 1; i++) ;
  return D(0x000) == 1 ? 0 : -1;
}
static int pe_stop(void) {
  D(0x004) = 1;
  for (long i = 0; i < 10000000 && D(0x008) != 1; i++) ;
  return D(0x008) == 1 ? 0 : -1;
}

static int fails, checks;
static int warm;   // round 0: its checks only print, they do not count (first-touch effects)
#define CHECK(cond, ...) do { if (warm) { if (!(cond)) { printf("(warm-up) "); printf(__VA_ARGS__); printf("\n"); } break; } \
    checks++; if (!(cond)) { fails++; printf("CHECK FAIL "); printf(__VA_ARGS__); printf("\n"); } } while (0)

int main(int argc, char **argv) {
  const int rounds = argc > 1 ? atoi(argv[1]) : 8;
  if (argc > 2) passes = atoi(argv[2]);
  if (argc > 3) buf_bytes = (size_t)atoi(argv[3]) << 20;
  if (sysconf(_SC_NPROCESSORS_ONLN) != NC) { fprintf(stderr, "%ld CPUs online, built for %d\n", sysconf(_SC_NPROCESSORS_ONLN), NC); return 2; }
  apmu = map("/dev/mem", APMU, APMU_SZ);
  accel = map("/dev/uio0", 0, ACCEL_SZ);
  pool = map("/dev/mem", POOL, POOL_SZ);
  pin(0);
  printf("t_storm_linux: %d harts, %d rounds of %d passes over %zu MiB per hart, socket jobs %d+%d\n", NC, rounds, passes,
         buf_bytes >> 20, LEN0, LEN1 / 8);
  CHECK(ACR(0, 0x20) == 0xAC0C9B9Fu && ACR(1, 0x20) == 0xC3C32001u, "socket IDs 0x%x 0x%x", ACR(0, 0x20), ACR(1, 0x20));
  // the APMU: PE held with its program, no MemGuard period, every counter off
  AP(PMC_STATUS_ADDR) = 1;
  AP(PERIOD_ADDR) = 0; AP(PERIOD_ADDR + 4) = 0;
  for (int i = 0; i < NUM_COUNTER; i++) { ctr_set(i, 0); AP(INIT_BUDGET_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0; }
  for (unsigned i = 0; i < sizeof pe_fw / sizeof pe_fw[0]; i++) AP(ISPM_BASE_ADDR + 4 * i) = pe_fw[i];

  pthread_barrier_init(&bar, 0, NC + 1);
  pthread_t th[NC];
  for (int c = 0; c < NC; c++) pthread_create(&th[c], 0, worker, (void *)(uintptr_t)c);
  uint32_t before[NCTR], after[NCTR], d[NCTR];
  for (int r = 0; r < rounds; r++) {
    const unsigned ev = r % 4 + 1;
    warm = r == 0;
    const int rd = ev == APMU_EV_RD_REQ || ev == APMU_EV_RD_RES;
    ctr_setup(ev);
    const int armed = pe_arm();
    snap(before);
    const uint64_t j0 = jobs, t0 = now_ns();
    finished = 0;
    __sync_synchronize();
    pthread_barrier_wait(&bar);                  // the workers go
    // the socket, job after job, until they are done (the main thread shares hart 0 with worker 0)
    while (finished < NC) acc_job((unsigned)(jobs + 1));
    pthread_barrier_wait(&bar);                  // and they are
    const uint64_t t1 = now_ns(), nj = jobs - j0;
    const int stopped = pe_stop();
    snap(after);
    for (int i = 0; i < NCTR; i++) d[i] = after[i] - before[i];
    // the PE: armed (EVU registers read back), sampled, its counts never went down, its last sample before ours
    uint32_t mono = 0, late = 0;
    const uint32_t cnt = D(0x00C), ns = cnt < RING_N ? cnt : RING_N, first = cnt < RING_N ? 0 : cnt % RING_N;
    for (uint32_t n = 1; n < ns; n++)
      for (int i = 0; i < NCTR; i++)
        mono += (D(0x400 + 4 * (NCTR + 1) * ((first + n) % RING_N) + 4 + 4 * i) & 0x3FFFFFFFu) <
                (D(0x400 + 4 * (NCTR + 1) * ((first + n - 1) % RING_N) + 4 + 4 * i) & 0x3FFFFFFFu);
    for (int i = 0; i < NCTR; i++) late += (D(0x200 + 4 + 4 * i) & 0x3FFFFFFFu) > after[i];
    CHECK(armed == 0 && stopped == 0 && D(0x020) == 0x5A5 && D(0x024) == 0 && cnt >= 1 && mono == 0 && late == 0,
          "round %d: PE armed %d stopped %d magic 0x%x errs %u samples %u decreases %u after-ours %u", r, armed, stopped,
          D(0x020), D(0x024), cnt, mono, late);
    // the socket's port: our jobs, exactly
    const uint64_t acc = rd ? nj * (LEN0 + LEN1 / 8) : nj * LEN0;
    CHECK(d[C_ACC] == acc, "round %d ev %u: socket port %u, %llu jobs = %llu", r, ev, d[C_ACC], (unsigned long long)nj,
          (unsigned long long)acc);
    CHECK(d[C_MEM(NC)] <= d[C_ACC], "round %d ev %u: memory port source %d %u above the socket's port %u", r, ev, NC,
          d[C_MEM(NC)], d[C_ACC]);
    // every core credited with its worker's traffic: reads ~2 per line (the write's refill and the read's); its L1
    // writes back each line once; the LLC's write-backs are credited to whichever core's miss evicts them, so a core's
    // share of the memory port's writes only roughly follows its own lines; Linux adds a little
    uint64_t sum = d[C_DBG] + d[C_PMU];
    for (int s = 0; s < NC + 2; s++) sum += d[C_MEM(s)];
    CHECK(d[C_TOT] >= sum, "round %d ev %u: memory port %u below its sources %llu", r, ev, d[C_TOT], (unsigned long long)sum);
    // (hart 0 also runs this thread, which drives the socket and checks its buffers: its bounds are wider; the
    // kernel's interrupts push a worker's loop out of the 8 KiB I$, so a core's SPU reads are its D$ refills plus a
    // varying number of I$ refills, which the read rounds count)
    printf("  per line (mem spu evu):");
    for (int c = 0; c < NC; c++) {
      const double l = (double)wlines[c], m = d[C_MEM(c)] / l, s = d[C_SPU(c)] / l, e = d[C_EVU(c)] / l;
      printf(" %.2f %.2f %.2f |", m, s, e);
      if (rd) {
        CHECK(m >= 1.7 && m <= (c ? 4.0 : 6.0), "round %d ev %u: core %d memory port %.3f per line", r, ev, c, m);
        CHECK(s >= e + 1.8 && s <= e + (c ? 3.0 : 8.0), "round %d ev %u: core %d SPU %.3f per line, I$ refills %.3f", r, ev,
              c, s, e);
        if (c == 0)
          CHECK(d[C_SPU(0)] >= d[C_EVU(0)] + d[C_EVU0] && d[C_SPU(0)] <= 1.02 * (d[C_EVU(0)] + d[C_EVU0]) + 2000,
                "round %d ev %u: core 0 SPU %u, D$ %u + I$ %u refills", r, ev, d[C_SPU(0)], d[C_EVU0], d[C_EVU(0)]);
      } else {
        CHECK(m >= 0.3 && m <= (c ? 1.7 : 3.0), "round %d ev %u: core %d memory port %.3f per line", r, ev, c, m);
        CHECK(s >= 0.9 && s <= (c ? 1.5 : 4.0), "round %d ev %u: core %d SPU %.3f per line", r, ev, c, s);
        CHECK(e >= 1.8 && e <= (c ? 2.8 : 8.0), "round %d ev %u: core %d D$ refills %.3f per line", r, ev, c, e);
      }
    }
    printf("\n");
    double mbs = 0; for (int c = 0; c < NC; c++) mbs += wlines[c] * 2 * 64.0;
    printf("round %d ev %u: %.1f s, %.1f MB/s by the harts, %llu socket jobs; mem %u acc %u eth %u dbg %u pmu %u; "
           "core0 mem %u spu %u evu %u/%u; PE %u samples\n", r, ev, (t1 - t0) / 1e9, mbs / ((t1 - t0) / 1e3),
           (unsigned long long)nj, d[C_TOT], d[C_ACC], d[C_MEM(NC + 1)], d[C_DBG], d[C_PMU], d[C_MEM(0)], d[C_SPU(0)],
           d[C_EVU(0)], d[C_EVU0], cnt);
    fflush(stdout);
  }
  warm = 0;
  stop_all = 1;
  pthread_barrier_wait(&bar);
  for (int c = 0; c < NC; c++) pthread_join(th[c], 0);
  AP(PMC_STATUS_ADDR) = 1;
  uint64_t wb = 0; for (int c = 0; c < NC; c++) wb += wbad[c];
  CHECK(wb == 0 && acc_bad == 0 && crc_bad == 0 && acc_fail == 0, "bad data: harts %llu, socket copy %llu, CRC %llu, jobs failed %llu",
        (unsigned long long)wb, (unsigned long long)acc_bad, (unsigned long long)crc_bad, (unsigned long long)acc_fail);
  printf(fails ? "TEST FAIL %d/%d checks\n" : "TEST PASS %d checks\n", fails ? fails : checks, checks);
  return fails != 0;
}
