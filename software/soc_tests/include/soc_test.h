// Helpers for self-checking SoC tests (simulation and FPGA).
//
//   CHECK(cond, "fmt", ...)  count a check; a failing one prints "CHECK FAIL <file>:<line> <message>"
//   soc_test_begin("name")   installs the trap guard and prints "TEST <name>"
//   return soc_test_end();   prints "TEST PASS <n> checks" or "TEST FAIL <k>/<n> checks"; main's return value is
//                            the program exit code (0 = pass, else the number of failed checks, max 126)
// Trap guard: any exception prints "TRAP mcause=.. mepc=.. mtval=.." and exits with code 127 (instead of the
// startup code's endless loop, which would only end at the simulation timeout).
// printf (software/inc/string_lib) knows only %s %d %u %x %X %c, all 32-bit: print a 64-bit value with
// printf("%08x%08x", H64(v)).
// Multi-core: soc_wake_all() wakes cores 2 and 3 (core 1 is woken by the startup code); soc_barrier(n) is a
// sense-free counter barrier in the uncached on-chip SRAM. Override thread_entry() to run code on cores 1-3.
#ifndef SOC_TEST_H
#define SOC_TEST_H
#include <stdint.h>
#include <stdio.h>
#include "utils.h"
#include "pmu_defines.h"

#define SOC_SRAM     __attribute__((section(".heapl2ram"), aligned(64)))   // on-chip SRAM 0x1C00_0000, not cached
#define REG32(a)     (*(volatile uint32_t *)(uintptr_t)(a))
#define REG64(a)     (*(volatile uint64_t *)(uintptr_t)(a))
#define H64(v)       (unsigned)((uint64_t)(v) >> 32), (unsigned)(uint64_t)(v)

static int soc_checks, soc_fails;

#define CHECK(cond, ...) do {                                                   \
    soc_checks++;                                                               \
    if (!(cond)) {                                                              \
      soc_fails++;                                                              \
      printf("CHECK FAIL %s:%d ", __FILE__, __LINE__); printf(__VA_ARGS__);     \
      printf("\r\n"); uart_wait_tx_done();                                      \
    }                                                                           \
  } while (0)

static inline uint64_t soc_csr_mcause(void) { uint64_t v; __asm__ volatile("csrr %0, mcause" : "=r"(v)); return v; }
static inline uint64_t soc_csr_mepc(void)   { uint64_t v; __asm__ volatile("csrr %0, mepc"   : "=r"(v)); return v; }
static inline uint64_t soc_csr_mtval(void)  { uint64_t v; __asm__ volatile("csrr %0, mtval"  : "=r"(v)); return v; }
static inline uint64_t soc_cycles(void)     { uint64_t v; __asm__ volatile("rdcycle %0"      : "=r"(v)); return v; }
static inline int      soc_hartid(void)     { uint64_t v; __asm__ volatile("csrr %0, mhartid": "=r"(v)); return (int)v; }

extern void exit(int);
__attribute__((aligned(4), noreturn, used)) static void soc_trap_guard(void) {
  printf("TRAP hart=%d mcause=0x%08x%08x mepc=0x%08x%08x mtval=0x%08x%08x\r\n", soc_hartid(), H64(soc_csr_mcause()),
         H64(soc_csr_mepc()), H64(soc_csr_mtval()));
  uart_wait_tx_done();
  exit(127);
  while (1) ;
}
static inline void soc_install_trap_guard(void) {
  __asm__ volatile("csrw mtvec, %0" :: "r"((uintptr_t)&soc_trap_guard));   // direct mode
}

static inline void soc_test_begin(const char *name) {
  soc_install_trap_guard();
  printf("TEST %s\r\n", name); uart_wait_tx_done();
}
static inline int soc_test_end(void) {
  if (soc_fails) printf("TEST FAIL %d/%d checks\r\n", soc_fails, soc_checks);
  else           printf("TEST PASS %d checks\r\n", soc_checks);
  uart_wait_tx_done();
  return soc_fails > 126 ? 126 : soc_fails;
}

// ---- multi-core: wake cores 2 and 3 through APMU counter-overflow interrupts (as software/quad_boot does)
#define SOC_PLIC_BASE 0x0C000000UL
static inline void soc_wake_all(void) {
  REG32(SOC_PLIC_BASE + 156 * 4) = 1;                            // priority of APMU IRQ 156 (-> hart 2)
  REG32(SOC_PLIC_BASE + 0x2280 + (156 / 32) * 4) = 1u << (156 % 32);   // enable, context 5 (hart 2 S-mode)
  REG32(SOC_PLIC_BASE + 157 * 4) = 1;                            // APMU IRQ 157 (-> hart 3)
  REG32(SOC_PLIC_BASE + 0x2380 + (157 / 32) * 4) = 1u << (157 % 32);   // context 7 (hart 3 S-mode)
  REG32(EVENT_INFO_BASE_ADDR) = OVERFLOW_EN;
  REG32(COUNTER_BASE_ADDR) = 0x40000000;
  REG32(EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE) = OVERFLOW_EN;
  REG32(COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE) = 0x40000000;
}

SOC_SRAM static volatile uint64_t soc_barrier_count;
// all n cores call it once per round (round = 1, 2, ...)
static inline void soc_barrier(int n, int round) {
  __atomic_fetch_add(&soc_barrier_count, 1, __ATOMIC_SEQ_CST);
  while (soc_barrier_count < (uint64_t)(n * round)) __asm__ volatile("nop");
}
#endif
