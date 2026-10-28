// Four-core boot check. Core 1 is woken by the startup code; core 0 wakes cores 2 and 3 through APMU counter
// overflows (counters 0/1 -> PLIC sources 156/157 on the S-mode contexts 5 and 7, the ones that wake a core parked in
// the boot ROM's wfi). Cores 1-3 then say hello in turn and check in, and park instead of returning (a return would
// end the test at that core's exit). Core 0 undoes the wake-up and returns the number of cores that did not check in
// (TEST PASS/FAIL, software/soc_tests/include/soc_test.h).
#include "encoding.h"
#include <stdio.h>
#include <stdlib.h>
#include "utils.h"
#include "soc_test.h"

#ifdef FPGA_EMULATION
#define WAIT_MAX 100000000ULL   // cycles core 0 waits for each core's hello (2 s at 50 MHz)
#else
#define WAIT_MAX 300000ULL
#endif

#define read_32b(addr)         (*(volatile uint32_t *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile uint32_t *)(long)(addr) = val_)

// PLIC code
#define PLIC_BASE      0x0C000000
#define PLIC_CHECK1    (PLIC_BASE + 0x205004)   // claim/complete of context 5 (hart 2, S-mode)
#define PLIC_CHECK2    (PLIC_BASE + 0x207004)   // context 7 (hart 3, S-mode)
// enable words of contexts 5 and 7 (+4 per 32 sources)
#define PLIC_EN_BITS1  (PLIC_BASE + 0x2280)
#define PLIC_EN_BITS2  (PLIC_BASE + 0x2380)

SOC_SRAM static volatile uint32_t turn;    // the core that may print now (uncached on-chip SRAM)
SOC_SRAM static volatile uint32_t up[4];   // 0x100 + mhartid once a core has said hello

// cores 1-3: say hello when it is their turn, so the lines do not interleave, check in and park
static void hello(uint32_t mhartid) {
  while (turn != mhartid) __asm__ volatile("nop");
  printf("Hello from Core%d %d!! :) \n", mhartid, mhartid);
  uart_wait_tx_done();
  up[mhartid] = 0x100 + soc_hartid();
  while (1) __asm__ volatile("wfi");
}

// Undo the wake-up once cores 2 and 3 run (as soc_wake_all() in soc_test.h). The boot ROM completes 156/157 without
// claiming them, so they stay pending with counters 0/1 overflowed (a level): whoever enables them later takes a stale
// interrupt. Clear the overflow while its interrupt enable is still set (cleared first, the APMU would freeze the line
// high), enable the sources again (the ROM's write to enable word 0 clears the whole context on this PLIC) so that a
// claim + complete clears the pending bit, then disable them.
static void wake_release(int pmu_plic_id1, int pmu_plic_id2) {
  write_32b(COUNTER_BASE_ADDR, 0);
  write_32b(COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE, 0);
  write_32b(EVENT_INFO_BASE_ADDR, 0);
  write_32b(EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE, 0);
  write_32b(PLIC_EN_BITS1+(((int)(pmu_plic_id1/32))*4), 1<<(pmu_plic_id1%32));
  write_32b(PLIC_EN_BITS2+(((int)(pmu_plic_id2/32))*4), 1<<(pmu_plic_id2%32));
  __asm__ volatile("fence" ::: "memory");   // line low and sources enabled before the claims
  uint32_t id = read_32b(PLIC_CHECK1);
  if (id) write_32b(PLIC_CHECK1, id);
  id = read_32b(PLIC_CHECK2);
  if (id) write_32b(PLIC_CHECK2, id);
  write_32b(PLIC_EN_BITS1+(((int)(pmu_plic_id1/32))*4), 0);
  write_32b(PLIC_EN_BITS2+(((int)(pmu_plic_id2/32))*4), 0);
}

int thread_entry(int cid, int nc){
  return 0;
}

// *********************************************************************
// Main Function
// *********************************************************************
int main(int argc, char const *argv[]) {

  uint32_t mhartid;
  asm volatile (
    "csrr %0, 0xF14\n"
    : "=r" (mhartid)
  );

  // In RTL: PMU Connected to irq_sources 155 <=> 162
  // pmu_plic_id needs to be 156 <=> 163
  int pmu_plic_id1 = 156;
  int pmu_plic_id2 = 157;

  // *******************************************************************
  // Core 0
  // *******************************************************************
  if (mhartid == 0) {
    // On the board the startup code has set the UART: its DLL is hard-wired, so the divisor for 9600 Bd at 100 MHz
    // (651) would set DLM and garble the console. Only the simulation sets it here.
    #ifndef FPGA_EMULATION
    set_flls();
    uint32_t baud_rate = 115200;
    uint32_t test_freq = 50000000;
    uart_set_cfg(0,(test_freq/baud_rate)>>4);
    #endif
    soc_test_begin("quad_boot");

    // Fix for LLC Addr
    write_32b(0x1C + 0x1A106000, 0xA0000000);
    printf("Hello from Core0 %d!! :) \n", mhartid);

    // Initialazing the interrupt controller - 1
    pulp_write32(PLIC_BASE+pmu_plic_id1*4, 1);                                // set pmu interrupt priority to 1
    pulp_write32(PLIC_EN_BITS1+(((int)(pmu_plic_id1/32))*4), 1<<(pmu_plic_id1%32)); // enable interrupt
    printf("PLIC Configured \n");
    // Initialazing the interrupt controller - 2
    pulp_write32(PLIC_BASE+pmu_plic_id2*4, 1);                                // set pmu interrupt priority to 1
    pulp_write32(PLIC_EN_BITS2+(((int)(pmu_plic_id2/32))*4), 1<<(pmu_plic_id2%32)); // enable interrupt

    // PMU Config
    uint32_t event_info_val = OVERFLOW_EN;
    // Counter 0:
    write_32b (EVENT_INFO_BASE_ADDR, event_info_val);
    write_32b (COUNTER_BASE_ADDR, 0x40000000);
    printf("PMU Interrupt Raised - Counter0! \n");
    // Counter 1:
    write_32b (EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE, event_info_val);
    write_32b (COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE, 0x40000000);
    printf("PMU Interrupt Raised - Counter1! \n");
    uart_wait_tx_done();

    // cores 1-3 say hello one after the other; a core that does not within WAIT_MAX loses its turn
    for (uint32_t h = 1; h <= 3; h++) {
      turn = h;
      uint64_t t0 = soc_cycles();
      while (up[h] == 0 && soc_cycles() - t0 < WAIT_MAX) __asm__ volatile("nop");
      turn = 0;
      CHECK(up[h] == 0x100 + h, "core %d did not check in (0x%x)", h, up[h]);
    }
    wake_release(pmu_plic_id1, pmu_plic_id2);
    return soc_test_end();

  // *******************************************************************
  // Core 1-3
  // *******************************************************************
  } else if (mhartid <= 3) {
    soc_install_trap_guard();
    hello(mhartid);
  }

  while (1) __asm__ volatile("wfi");
}
