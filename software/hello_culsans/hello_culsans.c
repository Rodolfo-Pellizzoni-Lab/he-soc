//#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include "utils.h"
#include "encoding.h"
#include "soc_test.h"

// Cores 0 and 1 (core 1 is woken by the startup code) each say hello and read misa. Core 1 then parks, so only core 0
// ends the test: it waits for core 1 and returns the number of failed checks (core 1 came up, both have the
// hypervisor extension), as the soc_tests do (software/soc_tests/include/soc_test.h).
#ifdef FPGA_EMULATION
#define WAIT_MAX 100000000ULL   // cycles core 0 waits for core 1 (2 s at 50 MHz)
#else
#define WAIT_MAX 300000ULL
#endif

__attribute__ ((section(".heapl2ram"))) volatile int flag[2] = { 0, 0};

__attribute__ ((section(".heapl2ram"))) volatile int victim = -1;

__attribute__ ((section(".heapl2ram"))) volatile int core_1 = -1;

__attribute__ ((section(".heapl2ram"))) volatile uint64_t misa_of[2] = { 0, 0};   // each core's misa, once read

static __attribute__ ((noinline)) void lock(int cid) {
  flag[cid] = 1;
  victim = cid;
  int other_cid = 1-cid;
  while( flag[other_cid] && (victim==cid) ) {
    __asm__ volatile("nop;");
  }
}

static __attribute__ ((noinline)) void unlock(int cid) {
  flag[cid] = 0;
}

int thread_entry(int cid, int nc){

  soc_install_trap_guard();
  lock(cid);
  if (cid == 0) soc_test_begin("hello_culsans");
  uint64_t misa = read_csr(misa);
  if(!(misa & 0x80)){
    printf("Hypervisor extension MISSING!\r\n");
  } else {
    printf("Hello Culsans! I'm Core %d!\r\n", cid);
  }
  uart_wait_tx_done();
  unlock(cid);
  misa_of[cid] = misa;

  // core 1 parks: returning would run main() and end the test at its exit
  if (cid != 0) while (1) __asm__ volatile("wfi");
  return 0;
}

int main(void) {
  uint64_t t0 = soc_cycles();
  while (misa_of[1] == 0 && soc_cycles() - t0 < WAIT_MAX) __asm__ volatile("nop");
  CHECK(misa_of[1] != 0, "core 1 did not say hello");
  for (int c = 0; c < 2; c++)
    if (misa_of[c] != 0)
      CHECK(misa_of[c] & 0x80, "core %d: misa 0x%08x%08x without the hypervisor extension", c, H64(misa_of[c]));
  return soc_test_end();
}
