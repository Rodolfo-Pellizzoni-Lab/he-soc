// SoC test of crc32 (slot 1, registers at 0x10010000): run with accel_soc_test(name='crc32').
// CRC-32/ISO-HDLC accelerator: SRC (8-byte aligned), LEN in bytes -> CRC register, DONE, interrupt.
// Prints TEST PASS / TEST FAIL; the exit code is the number of failed checks.
#include "accel.h"

#define SLOT     1
#define R_CTRL   0x00
#define R_STATUS 0x04
#define R_SRC    0x08
#define R_LEN    0x10
#define R_CRC    0x14
#define R_ID     0x20
#define R_CYCLES 0x24
#define BUFSZ    2048

ACCEL_BUF static volatile uint8_t buf[BUFSZ] __attribute__((aligned(8)));

static uint32_t sw_crc32(const volatile uint8_t *p, uint32_t n) {
  uint32_t c = 0xFFFFFFFFu;
  for (uint32_t i = 0; i < n; i++) {
    c ^= p[i];
    for (int k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xEDB88320u : (c >> 1);
  }
  return ~c;
}

static uint32_t hw_crc32(const volatile uint8_t *p, uint32_t n, uint32_t ctrl) {
  accel_wr64(SLOT, R_SRC, (uintptr_t)p);
  accel_wr(SLOT, R_LEN, n);
  accel_wr(SLOT, R_CTRL, ctrl);
  CHECK(accel_wait(SLOT, R_STATUS, 0x7, 0x2, 200000) == 0, "len %d: DONE not set, STATUS = 0x%x", n,
        accel_rd(SLOT, R_STATUS));
  return accel_rd(SLOT, R_CRC);
}

int main(void) {
  soc_test_begin("crc32");
  CHECK(accel_rd(SLOT, R_ID) == 0xC3C32001u, "ID register = 0x%x", accel_rd(SLOT, R_ID));

  // 1) check vector "123456789" -> 0xCBF43926, with the interrupt
  const char *s = "123456789";
  for (int i = 0; i < 9; i++) buf[i] = s[i];
  for (int i = 9; i < 16; i++) buf[i] = 0xA5;           // junk past the end
  accel_plic_enable();
  uint32_t c = hw_crc32(buf, 9, 0x3);                   // START + IRQ_EN
  CHECK(c == 0xCBF43926u, "CRC(\"123456789\") = 0x%x, expected 0xcbf43926", c);
  CHECK(sw_crc32(buf, 9) == 0xCBF43926u, "software CRC(\"123456789\") = 0x%x", sw_crc32(buf, 9));
  CHECK(accel_plic_pending(), "PLIC interrupt %d pending after DONE", ACCEL_IRQ_ID);
  uint32_t id = accel_plic_claim();
  CHECK(id == ACCEL_IRQ_ID, "PLIC claim returned %d", id);
  accel_wr(SLOT, R_STATUS, 0x2);                        // clear DONE -> interrupt line drops
  accel_plic_complete(id);
  CHECK(!accel_plic_pending(), "PLIC interrupt still pending after clearing DONE");
  printf("crc32 \"123456789\" = 0x%x\r\n", c);

  // 2) pseudo-random buffers of several lengths and offsets vs. the software CRC on the core
  uint32_t x = 0x12345678u;
  for (int i = 0; i < BUFSZ; i++) { x = x * 1664525u + 1013904223u; buf[i] = x >> 24; }
  static const uint32_t lens[] = {0, 1, 7, 8, 9, 13, 64, 333, 1021};
  static const uint32_t offs[] = {0, 8, 16, 24, 32, 40, 48, 56, 1016};
  for (unsigned t = 0; t < sizeof(lens) / sizeof(lens[0]); t++) {
    const volatile uint8_t *p = buf + offs[t];
    uint32_t h = hw_crc32(p, lens[t], 0x1);
    uint32_t r = sw_crc32(p, lens[t]);
    CHECK(h == r, "len %d @+%d: hw CRC 0x%x, sw CRC 0x%x", lens[t], offs[t], h, r);
    printf("len %d: crc 0x%x (%d cycles)\r\n", lens[t], h, accel_rd(SLOT, R_CYCLES));
    accel_wr(SLOT, R_STATUS, 0x2);
  }
  CHECK(!accel_plic_pending(), "PLIC interrupt pending with IRQ_EN = 0");
  return soc_test_end();
}
