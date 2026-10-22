// CVA6 architectural performance-monitoring smoke test.
#include "soc_test.h"

#define STR_(x) #x
#define STR(x) STR_(x)
#define CSR_R(csr) ({ uint64_t _v; __asm__ volatile("csrr %0, " STR(csr) : "=r"(_v)); _v; })
#define CSR_W(csr, v) __asm__ volatile("csrw " STR(csr) ", %0" :: "r"((uint64_t)(v)) : "memory")

#define MCOUNTINHIBIT 0x320
#define MCOUNTEREN    0x306
#define SCOUNTEREN    0x106
#define MCYCLE        0xb00
#define MINSTRET      0xb02
#define MHPMCOUNTER3  0xb03
#define MHPMCOUNTER4  0xb04
#define MHPMCOUNTER5  0xb05
#define MHPMCOUNTER6  0xb06
#define MHPMCOUNTER7  0xb07
#define MHPMCOUNTER8  0xb08
#define MHPMEVENT3    0x323
#define MHPMEVENT4    0x324
#define MHPMEVENT5    0x325
#define MHPMEVENT6    0x326
#define MHPMEVENT7    0x327
#define MHPMEVENT8    0x328
#define HPMCOUNTER3   0xc03
#define HPMCOUNTER9   0xc09

// Run "csrr t2, hpmcounter3; ecall" in S mode (mpp=1) or U mode
// (mpp=0). The trap returns to M mode and reports its cause and value.
static uint64_t try_hpmcounter3(int mpp, uint64_t *value) {
  uint64_t cause, read_value, old_mtvec;
  uint64_t mstatus_mpp = 3ULL << 11;
  uint64_t new_mpp = (uint64_t)mpp << 11;
  __asm__ volatile(
      "csrr %[omt], mtvec\n"
      "la   t0, 1f\n"
      "csrw mtvec, t0\n"
      "csrc mstatus, %[clr]\n"
      "csrs mstatus, %[set]\n"
      "la   t0, 2f\n"
      "csrw mepc, t0\n"
      "li   t2, 0xbad\n"
      "mret\n"
      "2: csrr t2, 0xc03\n"
      "ecall\n"
      ".align 2\n"
      "1: csrr %[cause], mcause\n"
      "mv   %[value], t2\n"
      "csrw mtvec, %[omt]\n"
      "csrc mstatus, %[clr]\n"
      : [cause] "=&r"(cause), [value] "=&r"(read_value), [omt] "=&r"(old_mtvec)
      : [clr] "r"(mstatus_mpp), [set] "r"(new_mpp)
      : "t0", "t2", "memory");
  *value = read_value;
  return cause;
}

int main(void) {
  soc_test_begin("t_hpm");

  CHECK(CSR_R(MCOUNTINHIBIT) == 0, "mcountinhibit reset value is nonzero");
  CSR_W(MCOUNTINHIBIT, ~0ULL);
  CHECK(CSR_R(MCOUNTINHIBIT) == 0x1fd, "mcountinhibit WARL mask is 0x%x, expected 0x1fd",
        (unsigned)CSR_R(MCOUNTINHIBIT));

  // Fixed counters stop independently and resume after their inhibit bits clear.
  CSR_W(MCOUNTINHIBIT, 1);
  uint64_t a = CSR_R(MCYCLE), b = CSR_R(MCYCLE);
  CHECK(a == b, "mcycle changed while inhibited: %d -> %d", (int)a, (int)b);
  CSR_W(MCOUNTINHIBIT, 0);
  a = CSR_R(MCYCLE); b = CSR_R(MCYCLE);
  CHECK(b > a, "mcycle did not resume: %d -> %d", (int)a, (int)b);

  CSR_W(MCOUNTINHIBIT, 1 << 2);
  a = CSR_R(MINSTRET);
  __asm__ volatile(".rept 16\n nop\n .endr");
  b = CSR_R(MINSTRET);
  CHECK(a == b, "minstret changed while inhibited: %d -> %d", (int)a, (int)b);
  CSR_W(MCOUNTINHIBIT, 0);
  a = CSR_R(MINSTRET); b = CSR_R(MINSTRET);
  CHECK(b > a, "minstret did not resume: %d -> %d", (int)a, (int)b);

  // Selectors are five-bit WARL registers. Touch all six implemented counters.
  CSR_W(MHPMEVENT3, ~0ULL); CSR_W(MHPMEVENT4, 24);
  CSR_W(MHPMEVENT5, 5);     CSR_W(MHPMEVENT6, 6);
  CSR_W(MHPMEVENT7, 23);    CSR_W(MHPMEVENT8, 24);
  CHECK(CSR_R(MHPMEVENT3) == 31, "mhpmevent3 WARL value is %d", (int)CSR_R(MHPMEVENT3));
  CHECK(CSR_R(MHPMEVENT4) == 24 && CSR_R(MHPMEVENT5) == 5 && CSR_R(MHPMEVENT6) == 6 &&
        CSR_R(MHPMEVENT7) == 23 && CSR_R(MHPMEVENT8) == 24, "event-selector readback failed");

  // Retired-instruction event counts every commit lane, not merely cycles with a commit.
  CSR_W(MCOUNTINHIBIT, 1 << 4);
  CSR_W(MHPMCOUNTER4, 0);
  __asm__ volatile(
      "csrc 0x320, %0\n"
      ".rept 64\n nop\n .endr\n"
      "csrs 0x320, %0\n"
      :: "r"(1ULL << 4) : "memory");
  a = CSR_R(MHPMCOUNTER4);
  CHECK(a >= 64, "retired-instruction event counted %d, expected at least 64", (int)a);

  // Cycle event and the standard read-only lower alias expose the same counter.
  CSR_W(MCOUNTINHIBIT, 1 << 3);
  CSR_W(MHPMEVENT3, 23);
  CSR_W(MHPMCOUNTER3, 0);
  CSR_W(MCOUNTINHIBIT, 0);
  __asm__ volatile(".rept 32\n nop\n .endr");
  CSR_W(MCOUNTINHIBIT, 1 << 3);
  a = CSR_R(MHPMCOUNTER3); b = CSR_R(HPMCOUNTER3);
  CHECK(a >= 32, "cycle event counted %d, expected at least 32", (int)a);
  CHECK(a == b, "mhpmcounter3 %d differs from hpmcounter3 alias %d", (int)a, (int)b);

  // Unimplemented architectural counters read zero rather than trapping.
  CSR_W(MCOUNTEREN, 1ULL << 9);
  CHECK(CSR_R(HPMCOUNTER9) == 0, "unimplemented hpmcounter9 is nonzero");

  // Lower-mode access follows the counter-enable chain:
  // S needs mcounteren; U needs both mcounteren and scounteren.
  uint64_t old_mcounteren = CSR_R(MCOUNTEREN), old_scounteren = CSR_R(SCOUNTEREN);
  uint64_t old_medeleg, value, cause;
  __asm__ volatile("csrr %0, medeleg\n csrw medeleg, zero" : "=r"(old_medeleg));
  __asm__ volatile("csrw pmpaddr0, %0\n csrw pmpcfg0, %1" :: "r"(~0ULL), "r"(0x1FULL));

  CSR_W(MCOUNTEREN, 1ULL << 3); CSR_W(SCOUNTEREN, 0);
  cause = try_hpmcounter3(1, &value);
  CHECK(cause == 9 && value == a, "S access: cause %d value %d, expected ecall and %d", (int)cause,
        (int)value, (int)a);
  cause = try_hpmcounter3(0, &value);
  CHECK(cause == 2, "U access with scounteren clear: cause %d, expected illegal instruction", (int)cause);

  CSR_W(SCOUNTEREN, 1ULL << 3);
  cause = try_hpmcounter3(0, &value);
  CHECK(cause == 8 && value == a, "U access: cause %d value %d, expected ecall and %d", (int)cause,
        (int)value, (int)a);
  CSR_W(MCOUNTEREN, 0);
  cause = try_hpmcounter3(0, &value);
  CHECK(cause == 2, "U access with mcounteren clear: cause %d, expected illegal instruction", (int)cause);

  CSR_W(MCOUNTEREN, old_mcounteren); CSR_W(SCOUNTEREN, old_scounteren);
  CSR_W(MCOUNTINHIBIT, 0);
  __asm__ volatile("csrw medeleg, %0" :: "r"(old_medeleg));
  return soc_test_end();
}
