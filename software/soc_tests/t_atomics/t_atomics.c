// RISC-V A extension from core 0 on cached DRAM (CCU + LLC atomics adapter) and on the on-chip SRAM
// (L2 atomics adapter): every AMO with its returned old value, and LR/SC success plus failure after an
// intervening store.
#include "soc_test.h"

static volatile uint64_t dram_v __attribute__((aligned(64)));
SOC_SRAM static volatile uint64_t sram_v;

#define AMO(op, p, x) ({ uint64_t _r; __asm__ volatile(op " %0, %1, (%2)" : "=r"(_r) : "r"((uint64_t)(x)), "r"(p) : "memory"); _r; })

static void run(volatile uint64_t *p, const char *where) {
  uint64_t r;
  *p = 10;
  r = AMO("amoadd.d", p, 5);              CHECK(r == 10 && *p == 15, "%s amoadd: ret %d mem %d", where, (int)r, (int)*p);
  r = AMO("amoswap.d", p, 0xF0);          CHECK(r == 15 && *p == 0xF0, "%s amoswap: ret %d", where, (int)r);
  r = AMO("amoand.d", p, 0x3C);           CHECK(r == 0xF0 && *p == 0x30, "%s amoand: mem %08x%08x", where, H64(*p));
  r = AMO("amoor.d", p, 0x05);            CHECK(r == 0x30 && *p == 0x35, "%s amoor: mem %08x%08x", where, H64(*p));
  r = AMO("amoxor.d", p, 0xFF);           CHECK(r == 0x35 && *p == 0xCA, "%s amoxor: mem %08x%08x", where, H64(*p));
  r = AMO("amomax.d", p, (uint64_t)-1);   CHECK(r == 0xCA && *p == 0xCA, "%s amomax (signed): mem %08x%08x", where, H64(*p));
  r = AMO("amomaxu.d", p, (uint64_t)-1);  CHECK(r == 0xCA && *p == (uint64_t)-1, "%s amomaxu: mem %08x%08x", where, H64(*p));
  r = AMO("amomin.d", p, 7);              CHECK(r == (uint64_t)-1 && *p == (uint64_t)-1, "%s amomin (signed): mem %08x%08x", where, H64(*p));
  r = AMO("amominu.d", p, 7);             CHECK(r == (uint64_t)-1 && *p == 7, "%s amominu: mem %08x%08x", where, H64(*p));
  // 32-bit AMO on the upper word
  *p = 0x0000000500000003ULL;
  uint32_t r32;
  __asm__ volatile("amoadd.w %0, %1, (%2)" : "=r"(r32) : "r"(2), "r"((volatile uint32_t *)p + 1) : "memory");
  CHECK(r32 == 5 && *p == 0x0000000700000003ULL, "%s amoadd.w upper: mem %08x%08x", where, H64(*p));
  // LR/SC: success
  uint64_t o, f;
  *p = 100;
  __asm__ volatile("lr.d %0, (%1)" : "=r"(o) : "r"(p) : "memory");
  __asm__ volatile("sc.d %0, %1, (%2)" : "=r"(f) : "r"(o + 1), "r"(p) : "memory");
  CHECK(o == 100 && f == 0 && *p == 101, "%s lr/sc: lr %d flag %d mem %d", where, (int)o, (int)f, (int)*p);
  // LR/SC: an SC without a reservation fails and leaves memory alone
  __asm__ volatile("sc.d %0, %1, (%2)" : "=r"(f) : "r"(555), "r"(p) : "memory");
  CHECK(f != 0 && *p == 101, "%s sc without lr: flag %d mem %d", where, (int)f, (int)*p);
}

int main(void) {
  soc_test_begin("t_atomics");
  run(&dram_v, "dram");
  run(&sram_v, "sram");
  return soc_test_end();
}
