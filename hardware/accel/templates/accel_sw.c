// SoC test of __NAME__ (slot __SLOT__, registers at __BASE__): run with accel_soc_test(name='__NAME__').
// Prints TEST PASS / TEST FAIL; the exit code is the number of failed checks.
#include "accel.h"

#define SLOT __SLOT__
#define N    16

ACCEL_BUF static volatile uint64_t src[N], dst[N];

int main(void) {
  soc_test_begin("__NAME__");
  CHECK(accel_rd(SLOT, 0x20) == 0x__ID__u, "ID register = 0x%x", accel_rd(SLOT, 0x20));

  for (int i = 0; i < N; i++) { src[i] = 0x1111111100000000ULL * (i + 1) + i; dst[i] = 0; }
  accel_wr64(SLOT, 0x08, (uintptr_t)src);
  accel_wr64(SLOT, 0x10, (uintptr_t)dst);
  accel_wr(SLOT, 0x18, N);
  accel_wr(SLOT, 0x1C, 5);
  accel_plic_enable();
  accel_wr(SLOT, 0x00, 0x3);                                   // START + IRQ_EN
  CHECK(accel_wait(SLOT, 0x04, 0x3, 0x2, 100000) == 0, "DONE not set, STATUS = 0x%x", accel_rd(SLOT, 0x04));
  for (int i = 0; i < N; i++)
    CHECK(dst[i] == src[i] + 5, "dst[%d] = %08x%08x, expected %08x%08x", i, H64(dst[i]), H64(src[i] + 5));
  CHECK(accel_plic_pending(), "PLIC interrupt %d pending after DONE", ACCEL_IRQ_ID);
  uint32_t id = accel_plic_claim();
  CHECK(id == ACCEL_IRQ_ID, "PLIC claim returned %d", id);
  accel_wr(SLOT, 0x04, 0x2);                                   // clear DONE -> interrupt line drops
  accel_plic_complete(id);
  CHECK(!accel_plic_pending(), "PLIC interrupt still pending after clearing DONE");
  printf("cycles: %d for %d words\r\n", accel_rd(SLOT, 0x24), N);
  return soc_test_end();
}
