// Interrupts on core 0: CLINT machine software interrupt (msip), CLINT timer interrupt (mtimecmp; mtime runs at
// RTC/2, one tick per ~61 us of simulated time), and PLIC register read-back. Every wait is bounded.
#include "soc_test.h"

#define CLINT        0x02000000UL
#define MSIP(h)      (CLINT + 4 * (h))
#define MTIMECMP(h)  (CLINT + 0x4000 + 8 * (h))
#define MTIME        (CLINT + 0xBFF8)

static volatile int sw_hits, timer_hits;
static volatile uint64_t last_cause;

__attribute__((interrupt("machine"), aligned(4))) static void irq_handler(void) {
  uint64_t c = soc_csr_mcause();
  last_cause = c;
  if (c == ((1ULL << 63) | 3))      { sw_hits++; REG32(MSIP(0)) = 0; }
  else if (c == ((1ULL << 63) | 7)) { timer_hits++; REG64(MTIMECMP(0)) = ~0ULL; }
  else {
    printf("TRAP mcause=0x%08x%08x mepc=0x%08x%08x mtval=0x%08x%08x\r\n", H64(c), H64(soc_csr_mepc()),
           H64(soc_csr_mtval()));
    uart_wait_tx_done();
    exit(127);
  }
}

int main(void) {
  soc_test_begin("t_irq");
  __asm__ volatile("csrw mtvec, %0" :: "r"((uintptr_t)&irq_handler));
  REG64(MTIMECMP(0)) = ~0ULL;

  // mtime must advance (bounded poll: ~2 ticks)
  uint64_t t0 = REG64(MTIME), t = t0;
  for (int i = 0; i < 20000 && t < t0 + 2; i++) t = REG64(MTIME);
  CHECK(t >= t0 + 2, "mtime does not advance: %d -> %d", (int)t0, (int)t);

  // software interrupt
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 3));
  __asm__ volatile("csrs mstatus, %0" :: "r"(1 << 3));
  REG32(MSIP(0)) = 1;
  for (int i = 0; i < 1000 && !sw_hits; i++) __asm__ volatile("nop");
  CHECK(sw_hits == 1, "msip interrupt taken %d times (mcause 0x%08x%08x)", sw_hits, H64(last_cause));
  CHECK(REG32(MSIP(0)) == 0, "msip not cleared");

  // timer interrupt (bounded poll, no wfi)
  t0 = REG64(MTIME);
  REG64(MTIMECMP(0)) = t0 + 2;
  __asm__ volatile("csrs mie, %0" :: "r"(1 << 7));
  uint64_t mip = 0;
  for (int i = 0; i < 20000 && !timer_hits; i++) __asm__ volatile("csrr %0, mip" : "=r"(mip));
  t = REG64(MTIME);
  CHECK(timer_hits == 1, "timer interrupt taken %d times (mtime %d -> %d, mtimecmp %d, mip 0x%x)", timer_hits,
        (int)t0, (int)t, (int)(t0 + 2), (unsigned)mip);
  __asm__ volatile("csrc mstatus, %0" :: "r"(1 << 3));

  // PLIC: priority and threshold registers read back
  REG32(SOC_PLIC_BASE + 9 * 4) = 3;
  CHECK(REG32(SOC_PLIC_BASE + 9 * 4) == 3, "PLIC priority 9 read back %d", REG32(SOC_PLIC_BASE + 9 * 4));
  REG32(SOC_PLIC_BASE + 9 * 4) = 0;
  REG32(SOC_PLIC_BASE + 0x200000) = 1;
  CHECK(REG32(SOC_PLIC_BASE + 0x200000) == 1, "PLIC threshold ctx 0 read back %d", REG32(SOC_PLIC_BASE + 0x200000));
  REG32(SOC_PLIC_BASE + 0x200000) = 0;
  return soc_test_end();
}
