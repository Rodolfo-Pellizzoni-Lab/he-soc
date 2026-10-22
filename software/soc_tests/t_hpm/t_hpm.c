// CVA6 architectural performance-monitoring smoke test.
#include "soc_test.h"

#define STR_(x) #x
#define STR(x) STR_(x)
#define CSR_R(csr) ({ uint64_t _v; __asm__ volatile("csrr %0, " STR(csr) : "=r"(_v)); _v; })
#define CSR_W(csr, v) __asm__ volatile("csrw " STR(csr) ", %0" :: "r"((uint64_t)(v)) : "memory")

#define MCOUNTINHIBIT 0x320
#define MCOUNTEREN    0x306
#define SCOUNTEREN    0x106
#define HCOUNTEREN    0x606
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
// (mpp=0), with virtualization selected by mpv. Report the M-mode trap.
static uint64_t try_hpmcounter3(int mpp, int mpv, uint64_t *value) {
  uint64_t cause, read_value, old_mtvec;
  uint64_t mstatus_mpp = (3ULL << 11) | (1ULL << 39);
  uint64_t new_mpp = ((uint64_t)mpp << 11) | ((uint64_t)mpv << 39);
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

  // Exercise all enable combinations in S, U, VS and VU mode.
  uint64_t old_mcounteren = CSR_R(MCOUNTEREN), old_scounteren = CSR_R(SCOUNTEREN);
  uint64_t old_hcounteren = CSR_R(HCOUNTEREN);
  uint64_t old_medeleg, value, cause;
  __asm__ volatile("csrr %0, medeleg\n csrw medeleg, zero" : "=r"(old_medeleg));
  __asm__ volatile("csrw pmpaddr0, %0\n csrw pmpcfg0, %1" :: "r"(~0ULL), "r"(0x1FULL));

  for (int enables = 0; enables < 8; enables++) {
    int m = enables & 1, h = (enables >> 1) & 1, s = (enables >> 2) & 1;
    CSR_W(MCOUNTEREN, (uint64_t)m << 3);
    CSR_W(HCOUNTEREN, (uint64_t)h << 3);
    CSR_W(SCOUNTEREN, (uint64_t)s << 3);
    for (int mode = 0; mode < 4; mode++) {
      int mpv = mode >> 1, mpp = (mode & 1) ? 0 : 1;
      uint64_t expected = mpp ? (mpv ? 10 : 9) : 8;
      if (!m) expected = 2;
      else if (mpv && (!h || (!mpp && !s))) expected = 22;
      else if (!mpv && !mpp && !s) expected = 2;
      cause = try_hpmcounter3(mpp, mpv, &value);
      CHECK(cause == expected && ((expected == 2 || expected == 22) || value == a),
            "mode %d enables M/H/S=%d/%d/%d: cause %d value %d, expected cause %d value %d",
            mode, m, h, s, (int)cause, (int)value, (int)expected, (int)a);
    }
  }

  // Unimplemented event selectors are WARL zero, including ignored writes.
#define CHECK_ZERO_EVENT(csr) do { CSR_W(csr, ~0ULL); \
    CHECK(CSR_R(csr) == 0, "unimplemented selector " STR(csr) " is nonzero"); } while (0)
  CHECK_ZERO_EVENT(0x329); CHECK_ZERO_EVENT(0x32a); CHECK_ZERO_EVENT(0x32b);
  CHECK_ZERO_EVENT(0x32c); CHECK_ZERO_EVENT(0x32d); CHECK_ZERO_EVENT(0x32e);
  CHECK_ZERO_EVENT(0x32f); CHECK_ZERO_EVENT(0x330); CHECK_ZERO_EVENT(0x331);
  CHECK_ZERO_EVENT(0x332); CHECK_ZERO_EVENT(0x333); CHECK_ZERO_EVENT(0x334);
  CHECK_ZERO_EVENT(0x335); CHECK_ZERO_EVENT(0x336); CHECK_ZERO_EVENT(0x337);
  CHECK_ZERO_EVENT(0x338); CHECK_ZERO_EVENT(0x339); CHECK_ZERO_EVENT(0x33a);
  CHECK_ZERO_EVENT(0x33b); CHECK_ZERO_EVENT(0x33c); CHECK_ZERO_EVENT(0x33d);
  CHECK_ZERO_EVENT(0x33e); CHECK_ZERO_EVENT(0x33f);

  CSR_W(MCOUNTEREN, old_mcounteren); CSR_W(SCOUNTEREN, old_scounteren);
  CSR_W(HCOUNTEREN, old_hcounteren);
  CSR_W(MCOUNTINHIBIT, 0);
  __asm__ volatile("csrw medeleg, %0" :: "r"(old_medeleg));
  return soc_test_end();
}
