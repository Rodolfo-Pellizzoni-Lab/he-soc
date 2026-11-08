// soc_test.h for Linux: the interface of soc_tests/include/soc_test.h (CHECK, soc_test_begin, soc_test_end, REG32,
// soc_cycles, SOC_PLIC_BASE) for a root process on the board, so that ../t_iopmp.c builds unchanged as a Linux
// program (Makefile here).
//   REG32 reaches the registers through /dev/mem mappings opened with O_SYNC (uncached, as alsaqr-software's apmuctl
//   and t_storm_linux map them) of the windows in soc_win[]. An address outside them, or a set-up that fails, ends the
//   program with exit code 127, the bare-metal code for a test that did not run to its end.
//   soc_cycles() counts 10 us ticks of the test thread's CPU time, not cycles: a bound of N cycles in the test (N / 50
//   us on the 50 MHz board) becomes N x 10 us here, 500 times longer, and time the scheduler gives to others does not
//   count, so a preemption cannot run a bound out.
//   soc_test_begin pins the process to CPU 0, as the bare-metal test runs on core 0.
// The PLIC. t_iopmp's phase J claims the IOPMP's interrupt (source 14) in hart 0's M-mode context, context 0, whose
// threshold and enables are 0 from reset on bare metal. Under Linux, OpenSBI's alsaqr platform (platform.c, warm init)
// leaves every M-mode context with threshold 1 and sources 32-63 enabled, and Linux gives every source priority 1;
// this PLIC offers a source only above the threshold (rv_plic_target.sv), so J's interrupt would never come. Nothing
// under Linux takes an interrupt from context 0 (OpenSBI never sets mie.MEIE, Linux uses the S-mode contexts 2h+1), so
// soc_test_begin saves context 0's threshold and 8 enable words and source 14's priority, turns the enables off and
// then the threshold to 0, and completes source 14 once (a claim and complete if it is pending), so a source left in
// service by an earlier, interrupted run cannot hold J's interrupt back. soc_test_end, an exit() and SIGINT, SIGTERM,
// SIGHUP, SIGQUIT or SIGPIPE put the three back, threshold first. One write of an enable word sets the context's whole
// vector (that word takes the data, the others become 0: plic_regmap.sv), so the enables can be put back only if at
// most one word was set; any difference is printed as a "linux: ERROR" line. So is source 14 found enabled in an S-mode
// context, where Linux could take J's interrupts. Neither is counted as a check, so the count stays t_iopmp's.
// The IOPMP. Under Linux the next program runs without a reset, so the same exit paths leave the IOPMP as phase K does
// (t_iopmp.c: the PE held, entry 0 allowing everything) when the test ends early with the IOPMP on; soc_test_end says
// so in a "linux:" line.
#ifndef SOC_TEST_H
#define SOC_TEST_H
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "iopmp.h"
#include "pmu_defines.h"

#define SOC_PLIC_BASE 0x0C000000UL

static struct { uintptr_t pa, size; volatile uint8_t *va; } soc_win[] = {
  { IOPMP_BASE_ADDR, 0x3000, NULL },    // the IOPMP: configuration, error record, MDCFG (0x800), SRCMD (0x1000), entries (0x2000)
  { PMU_B_BASE_ADDR, 0x44000, NULL },   // the APMU: its registers (PMC_STATUS_ADDR, PMC_BOOT_ADDR), ISPM and DSPM
  { EVU_BASE_ADDR, 0x1000, NULL },      // the EVUs' registers
  { SOC_PLIC_BASE, 0x201000, NULL },    // the PLIC: priorities, pending bits, enables, context 0's threshold and claim
};
#define SOC_NWIN (sizeof soc_win / sizeof soc_win[0])

static volatile uint32_t *soc_reg32(uintptr_t pa) {
  for (unsigned i = 0; i < SOC_NWIN; i++)
    if (soc_win[i].va && pa - soc_win[i].pa < soc_win[i].size && !(pa & 3))
      return (volatile uint32_t *)(soc_win[i].va + (pa - soc_win[i].pa));
  printf("TEST FAIL: 0x%08lx is not in a mapped window\r\n", (unsigned long)pa);
  exit(127);
}
#define REG32(a)     (*soc_reg32((uintptr_t)(a)))

static int soc_checks, soc_fails;

#define CHECK(cond, ...) do {                                                   \
    soc_checks++;                                                               \
    if (!(cond)) {                                                              \
      soc_fails++;                                                              \
      printf("CHECK FAIL %s:%d ", __FILE__, __LINE__); printf(__VA_ARGS__);     \
      printf("\r\n");                                                           \
    }                                                                           \
  } while (0)

static inline uint64_t soc_cycles(void) {
  struct timespec t;
  clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t);
  return (uint64_t)t.tv_sec * 100000u + (uint64_t)t.tv_nsec / 10000u;
}

// ---- the IOPMP as phase K leaves it (t_iopmp.c, phase K)
#define SOC_IOPMP(off)     REG32(IOPMP_BASE_ADDR + (off))
#define SOC_K_ADDR         0x40000000u           // entry 0: TOR up to 4 GiB
#define SOC_K_CFG          (MODE_TOR | ACCESS_READ | ACCESS_WRITE)
#define SOC_K_RULES        6                     // the entries t_iopmp uses (its NUM_RULES)

static int soc_iopmp_as_k(void) {
  int k = (REG32(PMC_STATUS_ADDR) & 1) && !(SOC_IOPMP(IOPMP_ERRREACT_OFFSET) & 0x112) &&      // ie, ire, iwe
          !(SOC_IOPMP(IOPMP_ERR_REQINFO_OFFSET) & 1) && SOC_IOPMP(IOPMP_ENTRY_ADDR_OFFSET) == SOC_K_ADDR &&
          SOC_IOPMP(IOPMP_ENTRY_ADDRH_OFFSET) == 0 && SOC_IOPMP(IOPMP_ENTRY_CFG_OFFSET) == SOC_K_CFG &&
          SOC_IOPMP(IOPMP_MDCFG_OFFSET) == 1 && SOC_IOPMP(IOPMP_MDCFG_OFFSET + 4) == 1 &&
          SOC_IOPMP(IOPMP_SRCMD_EN_OFFSET) == 2;
  for (int n = 1; n < SOC_K_RULES; n++) k &= SOC_IOPMP(IOPMP_ENTRY_CFG_OFFSET + 16 * n) == MODE_OFF;
  return k;
}

// MMIO only (the signal handler calls it); 1 if the IOPMP was on and not as K leaves it, so it had to be set
static int soc_iopmp_leave_open(void) {
  if (!(SOC_IOPMP(IOPMP_HWCFG0_OFFSET) & 0x80000000u) || soc_iopmp_as_k()) return 0;
  REG32(PMC_STATUS_ADDR) = 1;                    // hold the PE
  SOC_IOPMP(IOPMP_ERRREACT_OFFSET) = 0;
  for (int n = 1; n < SOC_K_RULES; n++) {
    SOC_IOPMP(IOPMP_ENTRY_ADDR_OFFSET + 16 * n) = 0;
    SOC_IOPMP(IOPMP_ENTRY_ADDRH_OFFSET + 16 * n) = 0;
    SOC_IOPMP(IOPMP_ENTRY_CFG_OFFSET + 16 * n) = MODE_OFF;
  }
  SOC_IOPMP(IOPMP_ENTRY_ADDR_OFFSET) = SOC_K_ADDR;
  SOC_IOPMP(IOPMP_ENTRY_ADDRH_OFFSET) = 0;
  SOC_IOPMP(IOPMP_ENTRY_CFG_OFFSET) = SOC_K_CFG;
  SOC_IOPMP(IOPMP_MDCFG_OFFSET) = 1;
  SOC_IOPMP(IOPMP_MDCFG_OFFSET + 4) = 1;
  SOC_IOPMP(IOPMP_SRCMD_EN_OFFSET) = 2;          // domain 0 (bit 0 is the lock)
  SOC_IOPMP(IOPMP_ERR_REQINFO_OFFSET) = 1;       // the record cleared
  for (int w = 0; w < 12; w++) REG32(EVU_BASE_ADDR + 4 * w) = 0;   // core 0's EVU words, as K clears them
  __asm__ volatile("fence" ::: "memory");
  return 1;
}

// ---- the PLIC
#define SOC_PLIC_SRC       14                    // the IOPMP's source (ariane_peripherals.sv: irq_sources[13])
#define SOC_PLIC_WORDS     8                     // enable words of a context: 255 sources (ariane_soc_pkg NumSources)
#define SOC_PLIC_PRIO(s)   (SOC_PLIC_BASE + 4 * (s))
#define SOC_PLIC_PEND(w)   (SOC_PLIC_BASE + 0x1000 + 4 * (w))
#define SOC_PLIC_EN(t, w)  (SOC_PLIC_BASE + 0x2000 + 0x80 * (t) + 4 * (w))
#define SOC_PLIC_THR(t)    (SOC_PLIC_BASE + 0x200000 + 0x1000 * (t))
#define SOC_PLIC_CLAIM(t)  (SOC_PLIC_THR(t) + 4)
static struct { uint32_t thr, prio, en[SOC_PLIC_WORDS]; } soc_plic;
static volatile sig_atomic_t soc_plic_saved, soc_plic_restored;

static void soc_plic_restore(void) {             // MMIO only: also called from the signal handler
  if (!soc_plic_saved || soc_plic_restored) return;
  REG32(SOC_PLIC_THR(0)) = soc_plic.thr;         // context 0 masked again first
  int w1 = 0;
  for (int w = 0; w < SOC_PLIC_WORDS; w++)
    if (soc_plic.en[w]) w1 = w;
  REG32(SOC_PLIC_EN(0, w1)) = soc_plic.en[w1];   // (the last set word, if several were set)
  REG32(SOC_PLIC_PRIO(SOC_PLIC_SRC)) = soc_plic.prio;
  __asm__ volatile("fence" ::: "memory");
  soc_plic_restored = 1;                         // after the writes: a signal in between does them again
}

static void soc_on_signal(int sig) {
  soc_iopmp_leave_open();
  soc_plic_restore();
  _exit(128 + sig);
}

static void soc_at_exit(void) {
  soc_iopmp_leave_open();
  soc_plic_restore();
}

static void soc_plic_print(const char *what) {
  printf("linux: PLIC %s: context 0 threshold %u, enables", what, REG32(SOC_PLIC_THR(0)));
  for (int w = 0; w < SOC_PLIC_WORDS; w++) printf(" %08x", REG32(SOC_PLIC_EN(0, w)));
  printf(", source %d priority %u, pending %u\r\n", SOC_PLIC_SRC, REG32(SOC_PLIC_PRIO(SOC_PLIC_SRC)),
         (REG32(SOC_PLIC_PEND(0)) >> SOC_PLIC_SRC) & 1);
}

static void soc_plic_setup(void) {
  soc_plic.thr = REG32(SOC_PLIC_THR(0));
  soc_plic.prio = REG32(SOC_PLIC_PRIO(SOC_PLIC_SRC));
  for (int w = 0; w < SOC_PLIC_WORDS; w++) soc_plic.en[w] = REG32(SOC_PLIC_EN(0, w));
  soc_plic_saved = 1;
  atexit(soc_at_exit);
  signal(SIGINT, soc_on_signal);
  signal(SIGTERM, soc_on_signal);
  signal(SIGHUP, soc_on_signal);
  signal(SIGQUIT, soc_on_signal);
  signal(SIGPIPE, soc_on_signal);
  soc_plic_print("as found");
  uint32_t s_ctx = 0;                            // the harts whose S-mode context has source 14 enabled
  for (int h = 0; h < SOC_NUM_CORES; h++)
    if (REG32(SOC_PLIC_EN(2 * h + 1, 0)) & (1u << SOC_PLIC_SRC)) s_ctx |= 1u << h;
  if (s_ctx) printf("linux: ERROR: source %d is enabled in the S-mode contexts of harts 0x%x\r\n", SOC_PLIC_SRC, s_ctx);
  REG32(SOC_PLIC_EN(0, 0)) = 0;                  // context 0: no source enabled (all its words)
  __asm__ volatile("fence" ::: "memory");
  REG32(SOC_PLIC_THR(0)) = 0;
  // source 14: in service since an earlier, interrupted run (only a complete frees it) or pending. The IOPMP's line
  // is low without its ERRREACT.ie, which phase A clears anyway.
  SOC_IOPMP(IOPMP_ERRREACT_OFFSET) = 0;
  __asm__ volatile("fence" ::: "memory");
  if ((REG32(SOC_PLIC_PEND(0)) >> SOC_PLIC_SRC) & 1) {
    REG32(SOC_PLIC_PRIO(SOC_PLIC_SRC)) = 1;      // above the threshold of 0 (J sets 1 too; the restore puts it back)
    REG32(SOC_PLIC_EN(0, 0)) = 1u << SOC_PLIC_SRC;
    __asm__ volatile("fence" ::: "memory");
    const uint32_t id = REG32(SOC_PLIC_CLAIM(0));
    printf("linux: source %d was pending from before: claimed %u\r\n", SOC_PLIC_SRC, id);
    REG32(SOC_PLIC_EN(0, 0)) = 0;
  }
  REG32(SOC_PLIC_CLAIM(0)) = SOC_PLIC_SRC;       // complete
  __asm__ volatile("fence" ::: "memory");
  if ((REG32(SOC_PLIC_PEND(0)) >> SOC_PLIC_SRC) & 1)
    printf("linux: ERROR: source %d still pending after the claim and complete\r\n", SOC_PLIC_SRC);
}

static void soc_plic_check_restored(void) {
  int same = REG32(SOC_PLIC_THR(0)) == soc_plic.thr && REG32(SOC_PLIC_PRIO(SOC_PLIC_SRC)) == soc_plic.prio;
  for (int w = 0; w < SOC_PLIC_WORDS; w++) same &= REG32(SOC_PLIC_EN(0, w)) == soc_plic.en[w];
  soc_plic_print(same ? "put back" : "NOT as found (linux: ERROR)");
}

static inline void soc_test_begin(const char *name) {
  setvbuf(stdout, NULL, _IOLBF, 0);
  printf("TEST %s\r\n", name);
  cpu_set_t cpus;
  CPU_ZERO(&cpus);
  CPU_SET(0, &cpus);
  if (sched_setaffinity(0, sizeof cpus, &cpus)) {
    printf("TEST FAIL: sched_setaffinity to CPU 0: %s\r\n", strerror(errno));
    exit(127);
  }
  const int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) {
    printf("TEST FAIL: open /dev/mem: %s\r\n", strerror(errno));
    exit(127);
  }
  for (unsigned i = 0; i < SOC_NWIN; i++) {
    void *p = mmap(NULL, soc_win[i].size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)soc_win[i].pa);
    if (p == MAP_FAILED) {
      printf("TEST FAIL: mmap of /dev/mem at 0x%08lx, 0x%lx bytes: %s\r\n", (unsigned long)soc_win[i].pa,
             (unsigned long)soc_win[i].size, strerror(errno));
      exit(127);
    }
    soc_win[i].va = p;
  }
  close(fd);
  soc_plic_setup();
}

static inline int soc_test_end(void) {
  if (soc_iopmp_leave_open())
    printf("linux: the test ended before phase K: the IOPMP is now as K leaves it (the PE held, entry 0 allowing "
           "everything)\r\n");
  if (soc_plic_saved && !soc_plic_restored) {
    soc_plic_restore();
    soc_plic_check_restored();
  }
  if (soc_fails) printf("TEST FAIL %d/%d checks\r\n", soc_fails, soc_checks);
  else           printf("TEST PASS %d checks\r\n", soc_checks);
  return soc_fails > 126 ? 126 : soc_fails;
}
#endif
