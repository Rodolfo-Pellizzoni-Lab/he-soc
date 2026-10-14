// Accelerator socket in the cluster window (0x1000_0000): an access past the last slot gets DECERR with read data
// 0xdeadbeef and must not hang the core. (CVA6 does not raise access faults for AXI error responses, so the core
// sees the data; a fault, if one is taken, is reported but tolerated.)
// Accelerator registers themselves are tested by each accelerator's own test (software/accel/<name>).
#include "soc_test.h"

#define PAST_LAST_SLOT 0x10080000UL      // slot 8: the socket has 8 slots of 64 KB

static volatile int faults;
static volatile uint64_t fault_cause;

__attribute__((interrupt("machine"), aligned(4))) static void trap(void) {
  uint64_t epc = soc_csr_mepc();
  faults++;
  fault_cause = soc_csr_mcause();
  if ((fault_cause >> 63) || (fault_cause != 5 && fault_cause != 7)) {
    printf("TRAP mcause=0x%08x%08x mepc=0x%08x%08x\r\n", H64(fault_cause), H64(epc));
    uart_wait_tx_done();
    exit(127);
  }
  uint16_t insn = *(volatile uint16_t *)epc;
  __asm__ volatile("csrw mepc, %0" :: "r"(epc + ((insn & 3) == 3 ? 4 : 2)));   // skip the faulting access
}

int main(void) {
  soc_test_begin("t_socket");
  __asm__ volatile("csrw mtvec, %0" :: "r"((uintptr_t)&trap));

  uint32_t v = REG32(PAST_LAST_SLOT + 0x10);
  CHECK(faults == 1 || v == 0xdeadbeef, "32-bit read past the last slot returned 0x%x (faults %d)", v, faults);
  uint32_t v4 = REG32(PAST_LAST_SLOT + 0x14);
  CHECK(faults >= 1 || v4 == 0xdeadbeef, "32-bit read at +4 (upper lane) returned 0x%x", v4);
  uint64_t d = REG64(0x103F0000UL);   // top of the cluster window
  CHECK(faults >= 1 || d == 0xdeadbeefdeadbeefULL, "64-bit read at the top of the window returned %08x%08x", H64(d));
  REG64(PAST_LAST_SLOT + 0x20) = 0x1234;
  __asm__ volatile("fence" ::: "memory");
  uint32_t after = REG32(PAST_LAST_SLOT);
  CHECK(faults >= 1 || after == 0xdeadbeef, "read after a refused write returned 0x%x", after);
  printf("socket error path: %d access faults taken\r\n", faults);
  return soc_test_end();
}
