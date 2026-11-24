// t_trap: two properties of the core that firmware and an operating system rely on.
//   1. stvec reads back what was written (bit 1 reads 0): OpenSBI reads stvec to redirect to S-mode a trap it does
//      not handle (sbi_trap_redirect), so a masked read-back sends the trap to the wrong address.
//   2. An instruction the core does not decode raises an illegal-instruction exception (cause 2, mepc at the
//      instruction, mtval the instruction). The core offloads such instructions to the CVXIF first; with no
//      coprocessor answering, the instruction never completed and the hart hung.
// Runs in M-mode on core 0. A hang in part 2 shows as a test that never ends.
#include "soc_test.h"

static uint64_t t_cause, t_tval, t_epc, t_addr;
// run one instruction with a private trap handler: returns mcause (0: no trap), the handler skips the instruction
#define TRY(insn_asm) ({ uint64_t _c, _o, _v, _e, _a;                                              \
  __asm__ volatile("csrr %[o], mtvec\n la t0, 1f\n csrw mtvec, t0\n li %[c], 0\n li %[v], 0\n li %[e], 0\n" \
                   "la %[a], 3f\n 3: " insn_asm "\n j 2f\n .align 2\n"                              \
                   "1: csrr %[c], mcause\n csrr %[v], mtval\n csrr %[e], mepc\n la t0, 2f\n csrw mepc, t0\n mret\n" \
                   ".align 2\n 2: csrw mtvec, %[o]\n"                                               \
                   : [c] "=&r"(_c), [o] "=&r"(_o), [v] "=&r"(_v), [e] "=&r"(_e), [a] "=&r"(_a) :: "t0", "t1", "memory"); \
  t_cause = _c; t_tval = _v; t_epc = _e; t_addr = _a; _c; })

static void stvec_check(uint64_t v) {
  uint64_t old, rd, want = v & ~2ULL;
  __asm__ volatile("csrr %0, stvec" : "=r"(old));
  __asm__ volatile("csrw stvec, %0" :: "r"(v));
  __asm__ volatile("csrr %0, stvec" : "=r"(rd));
  __asm__ volatile("csrw stvec, %0" :: "r"(old));
  CHECK(rd == want, "stvec: wrote %x_%x, read %x_%x (expected %x_%x)", H64(v), H64(rd), H64(want));
}
static void illegal_check(const char *name, uint64_t cause, uint64_t insn, int check_tval) {
  CHECK(cause == 2, "%s: mcause %d (expected 2, illegal instruction)", name, (int)cause);
  CHECK(t_epc == t_addr, "%s: mepc %x_%x, the instruction is at %x_%x", name, H64(t_epc), H64(t_addr));
  if (check_tval) CHECK(t_tval == insn, "%s: mtval %x_%x (expected %x_%x)", name, H64(t_tval), H64(insn));
  printf("  %-28s mcause %d mtval %x_%x\r\n", name, (int)cause, H64(t_tval));
}

int main(void) {
  soc_test_begin("t_trap");
  // ---- 1. stvec: addresses with every combination of bits 5:2, direct and vectored mode
  stvec_check(0x8000107CULL);                       // the low bits of the Linux 7.2 handle_exception (...2b7c)
  stvec_check(0x80001040ULL);
  stvec_check(0x80001004ULL);
  stvec_check(0x8000103CULL);
  stvec_check(0x80001029ULL);                       // vectored (bit 0), bits 5 and 3
  stvec_check(0x8000107EULL);                       // bit 1 does not stick
  printf("  stvec reads back as written\r\n");
  // ---- 2. instructions the core does not decode
  uint64_t c;
  c = TRY("csrr t1, time");        illegal_check("rdtime (no time CSR)", c, 0xC0102373ULL, 1);
  c = TRY(".word 0xffffffff");     illegal_check("0xffffffff", c, 0xFFFFFFFFULL, 1);
  c = TRY(".word 0x0000002b");     illegal_check("custom-1 opcode 0x0000002b", c, 0x0000002BULL, 1);
  c = TRY(".word 0x02000057");     illegal_check("vector opcode 0x02000057", c, 0x02000057ULL, 1);
  c = TRY(".word 0x00000077");     illegal_check("reserved opcode 0x00000077", c, 0x00000077ULL, 1);
  c = TRY(".half 0x0000");         illegal_check("16-bit 0x0000", c, 0, 0);
  // the core still runs normally afterwards
  volatile uint64_t x = 0;
  for (int i = 0; i < 100; i++) x += i;
  CHECK(x == 4950, "arithmetic after the traps: %d", (int)x);
  return soc_test_end();
}
