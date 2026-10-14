// Core 0 sleeps in wfi until the CLINT timer interrupt (mtimecmp = mtime + 2, ~120 us) wakes it.
// Not part of sim_regress: a repro of an open issue (2026-10-14). Plain build: passes (wfi wakes; the interrupt is
// taken a few instructions later). -DDOUBLE_WFI: passes. -DOLD_LOOP (`while (!hits) wfi;` loop, with or without
// rdcycle / -DNO_RDCYCLE, with or without msie / -DNO_MSIE): the interrupt is never taken and the run never ends.
#include "soc_test.h"
#define CLINT 0x02000000UL
static volatile int hits;
__attribute__((interrupt("machine"), aligned(4))) static void h(void) {
  if (soc_csr_mcause() == ((1ULL << 63) | 7)) { hits++; REG64(CLINT + 0x4000) = ~0ULL; }
  else { printf("TRAP mcause=0x%08x%08x\r\n", H64(soc_csr_mcause())); uart_wait_tx_done(); exit(127); }
}
int main(void) {
  soc_test_begin("t_wfi");
  __asm__ volatile("csrw mtvec, %0" :: "r"((uintptr_t)&h));
  uint64_t t0 = REG64(CLINT + 0xBFF8);
  REG64(CLINT + 0x4000) = t0 + 2;
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 7));
  __asm__ volatile("csrs mstatus, %0" :: "r"(1 << 3));
  printf("sleeping at mtime %d\r\n", (int)t0); uart_wait_tx_done();
#ifdef OLD_LOOP
  // the loop of the first t_irq version, which hung in the regression
#ifndef NO_MSIE
  REG32(CLINT) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 3));
#endif
#ifdef NO_RDCYCLE
  while (!hits) __asm__ volatile("wfi");
#else
  uint64_t c0 = soc_cycles();
  while (!hits && soc_cycles() - c0 < 2000000) __asm__ volatile("wfi");
#endif
#endif
  __asm__ volatile("wfi");
#ifdef DOUBLE_WFI
  __asm__ volatile("wfi");   // the interrupt is pending (taken a few instructions late): this wfi must not sleep
#endif
  printf("woke: hits %d mtime %d\r\n", hits, (int)REG64(CLINT + 0xBFF8));
  CHECK(hits == 1, "timer interrupt after wfi: %d", hits);
  return soc_test_end();
}
