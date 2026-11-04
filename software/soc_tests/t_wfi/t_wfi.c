// Core 0 sleeps in wfi until the CLINT timer interrupt (mtimecmp ~100 us ahead) wakes it, and reports where the
// interrupt was taken. Not part of sim_regress: a repro of an open issue (2026-10-14).
// CVA6 takes the interrupt that ends a wfi a few instructions late (the privileged spec: on the instruction after the
// wfi, mepc = wfi + 4): a wfi does not flush the instructions decoded behind it, and an interrupt is decoded into the
// next new instruction (decoder.sv). Board, 2026-10-29: plain build at wfi + 12 (behind the lla); -DPLAIN_WFI five
// instructions late, the load of hits among them (it prints hits 0). -DDOUBLE_WFI: passes (the second wfi sees the
// interrupt pending). -DOLD_LOOP (`while (!hits) wfi;`, with rdcycle or -DNO_RDCYCLE): passes behind the lla, hangs
// with -DPLAIN_WFI though the interrupt is taken: the loop loads hits before the handler runs, the handler disarms
// the timer, and the branch on the stale 0 goes back into a wfi nothing wakes (seen_by_h: hits 1, mepc on the branch
// or the rdcycle check). -DSAFE_LOOP (-DPLAIN_WFI too): the loop asleep with mstatus.MIE clear, as Linux idles:
// passes, the interrupt taken right behind the csrs.
// mtime runs at RTC/2: a tick is ~61 us in sim but 40 ns on the FPGA (25 MHz). The first version armed mtime + 2
// before its "sleeping" print, so on the FPGA the interrupt was taken before the wfi, and nothing woke the wfi: the
// timer is now armed after the print, DT ticks ahead.
#include "soc_test.h"
#define CLINT 0x02000000UL
#ifdef FPGA_EMULATION
#define DT 2500
#else
#define DT 2
#endif
static volatile int hits;
static volatile uint64_t epc;
SOC_SRAM static volatile uint64_t seen_by_h[2];   // epc, hits: for a debugger's sysbus read when the run hangs (hits
                                                  // and epc can sit dirty in the L1)
__attribute__((interrupt("machine"), aligned(4))) static void h(void) {
  if (soc_csr_mcause() == ((1ULL << 63) | 7)) {
    hits++; epc = soc_csr_mepc(); REG64(CLINT + 0x4000) = ~0ULL;
    seen_by_h[0] = epc; seen_by_h[1] = hits;
  }
  else { printf("TRAP mcause=0x%08x%08x\r\n", H64(soc_csr_mcause())); uart_wait_tx_done(); exit(127); }
}
// a wfi, then its own address; -DPLAIN_WFI: the wfi alone, the caller's own code right behind it (as in the first
// version)
static inline uintptr_t wfi_at(void) {
  uintptr_t pc = 0;
#if defined(PLAIN_WFI)
  __asm__ volatile("wfi");
#elif defined(DOUBLE_WFI)
  // the interrupt is pending (taken a few instructions late): the second wfi must not sleep
  __asm__ volatile("1: wfi\n\twfi\n\tlla %0, 1b" : "=r"(pc) :: "memory");
#else
  __asm__ volatile("1: wfi\n\tlla %0, 1b" : "=r"(pc) :: "memory");
#endif
  return pc;
}
int main(void) {
  soc_test_begin("t_wfi");
  __asm__ volatile("csrw mtvec, %0" :: "r"((uintptr_t)&h));
  printf("sleeping for %d mtime ticks\r\n", DT); uart_wait_tx_done();
  uint64_t t0 = REG64(CLINT + 0xBFF8);
  REG64(CLINT + 0x4000) = t0 + DT;
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 7));
  __asm__ volatile("csrs mstatus, %0" :: "r"(1 << 3));
  const int early = hits;
  uintptr_t pc = 0;
#ifdef OLD_LOOP
  // the loop of the first t_irq version, which hung in the regression (the plain wfi no longer follows it: once the
  // loop has seen the interrupt, nothing is left to wake that wfi)
#ifndef NO_MSIE
  REG32(CLINT) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 3));
#endif
#ifdef NO_RDCYCLE
  while (!hits) pc = wfi_at();
#else
  uint64_t c0 = soc_cycles();
  while (!hits && soc_cycles() - c0 < 2000000) pc = wfi_at();
#endif
#elif defined(SAFE_LOOP)
  // the loop asleep with mstatus.MIE clear: the wfi wakes on the interrupt enabled in mie alone, and setting MIE (a
  // write of mstatus flushes the pipeline) takes it before hits is read again
  __asm__ volatile("csrc mstatus, %0" :: "r"(1 << 3));
  while (!hits) {
    pc = wfi_at();
    __asm__ volatile("csrs mstatus, %0\n\tcsrc mstatus, %0" :: "r"(1 << 3) : "memory");
  }
  __asm__ volatile("csrs mstatus, %0" :: "r"(1 << 3));
#else
  pc = wfi_at();
#endif
  const int seen = hits;
  const uint64_t t1 = REG64(CLINT + 0xBFF8);
  printf("woke: hits %d (%d right after the wfi) after %d ticks, interrupt taken at 0x%08x%08x", hits, seen,
         (int)(t1 - t0), H64(epc));
  if (pc) printf(" = wfi + %d", (int)(epc - pc));
  printf("\r\n");
  CHECK(early == 0, "timer interrupt taken before the wfi");
  CHECK(hits == 1, "timer interrupt after wfi: %d", hits);
  return soc_test_end();
}
