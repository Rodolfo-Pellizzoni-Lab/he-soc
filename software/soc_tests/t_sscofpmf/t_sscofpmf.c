// RV64 Sscofpmf architectural tests; runs in full-SoC simulation and on FPGA.
#include "soc_test.h"

#define STR_(x) #x
#define STR(x) STR_(x)
#define R(csr) ({ uint64_t _v; __asm__ volatile("csrr %0, " STR(csr) : "=r"(_v)); _v; })
#define W(csr, value) __asm__ volatile("csrw " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define S(csr, value) __asm__ volatile("csrs " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define C(csr, value) __asm__ volatile("csrc " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define INHIBIT 0x320
#define EVENT3 0x323
#define COUNT3 0xb03
#define SCOUNTOVF 0xda0
#define OF (1ULL << 63)
#define MINH (1ULL << 62)
#define LCOFI (1ULL << 13)
#define STIP (1ULL << 5)
#define ALL_HPM 0x1f8ULL

static volatile int m_hits, s_hits;
static volatile uint64_t m_history[8], s_cause, s_overflow;

__attribute__((interrupt("machine"), aligned(4))) static void machine_irq(void) {
  uint64_t cause = R(mcause);
  if (cause != (OF | 13) && cause != (OF | 5)) {
    printf("UNEXPECTED M IRQ %08x%08x\r\n", H64(cause));
    uart_wait_tx_done(); exit(127);
  }
  if (m_hits < 8) m_history[m_hits] = cause;
  m_hits++;
  C(mip, 1ULL << (cause & 63));
}

__attribute__((interrupt("supervisor"), aligned(4))) static void supervisor_irq(void) {
  s_cause = R(scause);
  s_overflow = R(SCOUNTOVF);
  s_hits++;
  C(sip, LCOFI);
  C(sie, LCOFI);
}

// The lower-mode path is exactly 64 NOPs followed by an unretired ECALL.
// Its M-mode prologue/epilogue are excluded by MINH in the filtering tests.
static uint64_t run_lower(int mode) {
  uint64_t cause, old_mtvec;
  uint64_t clear = (3ULL << 11) | (1ULL << 39);
  uint64_t set = ((uint64_t)(mode == 1 || mode == 3) << 11) | ((uint64_t)(mode >= 3) << 39);
  __asm__ volatile(
      "csrr %[old], mtvec\n la t0, 1f\n csrw mtvec, t0\n"
      "csrc mstatus, %[clear]\n csrs mstatus, %[set]\n"
      "la t0, 2f\n csrw mepc, t0\n mret\n"
      "2: .rept 64\n nop\n .endr\n ecall\n .align 2\n"
      "1: csrs 0x320, %[inhibit]\n csrr %[cause], mcause\n"
      "csrw mtvec, %[old]\n csrc mstatus, %[clear]\n"
      : [cause] "=&r"(cause), [old] "=&r"(old_mtvec)
      : [clear] "r"(clear), [set] "r"(set), [inhibit] "r"(8ULL)
      : "t0", "memory");
  return cause;
}

#define DEFINE_READ_PROBE(name, csr) \
static uint64_t name(int mode, uint64_t *value) { \
  uint64_t cause, read_value, old_mtvec; \
  uint64_t clear = (3ULL << 11) | (1ULL << 39); \
  uint64_t set = ((uint64_t)(mode == 1 || mode == 3) << 11) | ((uint64_t)(mode >= 3) << 39); \
  __asm__ volatile( \
      "csrr %[old], mtvec\n la t0, 1f\n csrw mtvec, t0\n" \
      "csrc mstatus, %[clear]\n csrs mstatus, %[set]\n" \
      "la t0, 2f\n csrw mepc, t0\n li t2, 0xbad\n mret\n" \
      "2: csrr t2, " STR(csr) "\n ecall\n .align 2\n" \
      "1: csrr %[cause], mcause\n mv %[value], t2\n" \
      "csrw mtvec, %[old]\n csrc mstatus, %[clear]\n" \
      : [cause] "=&r"(cause), [value] "=&r"(read_value), [old] "=&r"(old_mtvec) \
      : [clear] "r"(clear), [set] "r"(set) : "t0", "t2", "memory"); \
  *value = read_value; return cause; \
}

DEFINE_READ_PROBE(read_alias, 0xc03)
DEFINE_READ_PROBE(read_overflow, 0xda0)
#define DEFINE_MACHINE_READ_PROBE(name, csr) \
static uint64_t name(void) { \
  uint64_t cause, old_mtvec; \
  __asm__ volatile( \
      "csrr %[old], mtvec\n la t0, 1f\n csrw mtvec, t0\n" \
      "li %[cause], 0\n csrr t2, " STR(csr) "\n j 2f\n .align 2\n" \
      "1: csrr %[cause], mcause\n 2: csrw mtvec, %[old]\n" \
      : [cause] "=&r"(cause), [old] "=&r"(old_mtvec) \
      :: "t0", "t2", "memory"); \
  return cause; \
}
DEFINE_MACHINE_READ_PROBE(read_cyclecfg, 0x321)
DEFINE_MACHINE_READ_PROBE(read_instretcfg, 0x322)
DEFINE_MACHINE_READ_PROBE(read_event_high, 0x723)

static int ecall_cause(int mode) { return mode == 1 ? 9 : mode == 3 ? 10 : 8; }

static void test_unimplemented(void) {
  uint64_t combined = 0;
#define ZERO_SELECTOR(csr) W(csr, ~0ULL); combined |= R(csr);
  ZERO_SELECTOR(0x329) ZERO_SELECTOR(0x32a) ZERO_SELECTOR(0x32b)
  ZERO_SELECTOR(0x32c) ZERO_SELECTOR(0x32d) ZERO_SELECTOR(0x32e)
  ZERO_SELECTOR(0x32f) ZERO_SELECTOR(0x330) ZERO_SELECTOR(0x331)
  ZERO_SELECTOR(0x332) ZERO_SELECTOR(0x333) ZERO_SELECTOR(0x334)
  ZERO_SELECTOR(0x335) ZERO_SELECTOR(0x336) ZERO_SELECTOR(0x337)
  ZERO_SELECTOR(0x338) ZERO_SELECTOR(0x339) ZERO_SELECTOR(0x33a)
  ZERO_SELECTOR(0x33b) ZERO_SELECTOR(0x33c) ZERO_SELECTOR(0x33d)
  ZERO_SELECTOR(0x33e) ZERO_SELECTOR(0x33f)
#undef ZERO_SELECTOR
  CHECK(combined == 0, "unimplemented selectors are not zero");
  CHECK(read_cyclecfg() == 2, "absent mcyclecfg must trap");
  CHECK(read_instretcfg() == 2, "absent minstretcfg must trap");
  CHECK(read_event_high() == 2, "RV64 mhpmevent3h must trap");
}

static void test_filtering(void) {
  for (int filter = -1; filter < 5; filter++) {
    uint64_t bits = filter < 0 ? 0 : (1ULL << (62 - filter));
    W(INHIBIT, ALL_HPM); W(EVENT3, 24 | bits); W(COUNT3, 0);
    __asm__ volatile("csrc 0x320, %0\n .rept 64\n nop\n .endr\n csrs 0x320, %0"
                     :: "r"(8ULL) : "memory");
    uint64_t count = R(COUNT3);
    CHECK(count == (filter == 0 ? 0 : 65), "M filter %d count %d, expected %d",
          filter, (int)count, filter == 0 ? 0 : 65);
  }
  for (int mode = 1; mode < 5; mode++) {
    for (int filter = -1; filter < 5; filter++) {
      uint64_t bits = filter < 0 ? 0 : (1ULL << (62 - filter));
      W(INHIBIT, ALL_HPM); W(EVENT3, 24 | MINH | bits); W(COUNT3, 0);
      C(INHIBIT, 8);
      uint64_t cause = run_lower(mode), count = R(COUNT3);
      CHECK(cause == (uint64_t)ecall_cause(mode) && count == (filter == mode ? 0 : 64),
            "mode %d filter %d cause %d count %d", mode, filter, (int)cause, (int)count);
    }
  }
}

static void test_access(void) {
  W(INHIBIT, ALL_HPM); W(EVENT3, OF); W(COUNT3, 0x123456789abcdef0ULL);
  CHECK(R(SCOUNTOVF) == 8, "M scountovf is %x", (unsigned)R(SCOUNTOVF));
  for (int mode = 1; mode < 5; mode++) {
    for (int enables = 0; enables < 8; enables++) {
      int m = !!(enables & 1), h = !!(enables & 2), s = !!(enables & 4);
      W(mcounteren, m ? 8 : 0); W(hcounteren, h ? 8 : 0); W(scounteren, s ? 8 : 0);
      uint64_t value, cause = read_alias(mode, &value);
      int expected;
      if (!m) expected = 2;
      else if (mode >= 3 && (!h || (mode == 4 && !s))) expected = 22;
      else if (mode == 2 && !s) expected = 2;
      else expected = ecall_cause(mode);
      CHECK(cause == (uint64_t)expected &&
            (expected != ecall_cause(mode) || value == 0x123456789abcdef0ULL),
            "alias mode %d enables %d cause %d expected %d", mode, enables, (int)cause, expected);
      cause = read_overflow(mode, &value);
      expected = mode == 2 || mode == 4 ? 2 : ecall_cause(mode);
      CHECK(cause == (uint64_t)expected &&
            (expected == 2 || value == (uint64_t)(m && (mode != 3 || h) ? 8 : 0)),
            "scountovf mode %d enables %d cause %d value %x", mode, enables, (int)cause, (unsigned)value);
    }
  }
  W(mcounteren, ~0ULL); W(hcounteren, ~0ULL); W(scounteren, ~0ULL);
}

static void test_machine_irq(void) {
  W(mtvec, (uintptr_t)&machine_irq); W(mideleg, 0); W(mie, 0); C(mstatus, 8);
  W(INHIBIT, ALL_HPM); W(EVENT3, 23); W(COUNT3, ~0ULL - 8);
  C(mip, LCOFI); C(INHIBIT, 8);
  __asm__ volatile(".rept 64\n nop\n .endr");
  S(INHIBIT, 8);
  CHECK((R(EVENT3) & OF) && (R(SCOUNTOVF) & 8) && (R(mip) & LCOFI),
        "overflow state was not recorded with interrupts masked");
  CHECK(m_hits == 0, "masked overflow trapped");
  W(mie, LCOFI); S(mstatus, 8);
  for (int i = 0; i < 1000 && m_hits == 0; i++) __asm__ volatile("nop");
  C(mstatus, 8);
  CHECK(m_hits == 1 && m_history[0] == (OF | 13), "M LCOFI hits %d", m_hits);
  CHECK(!(R(mip) & LCOFI) && (R(EVENT3) & OF), "LCOFIP clear altered OF or reasserted pending");

  // Re-arm after acknowledging pending state, and ensure the next wrap traps.
  W(EVENT3, 23); W(COUNT3, ~0ULL - 8); C(INHIBIT, 8); S(mstatus, 8);
  for (int i = 0; i < 1000 && m_hits == 1; i++) __asm__ volatile("nop");
  C(mstatus, 8); S(INHIBIT, 8);
  CHECK(m_hits == 2, "re-armed LCOFI hits %d", m_hits);

  // A delegated supervisor pending source cannot starve a machine LCOFI.
  W(mideleg, STIP); W(mie, STIP | LCOFI); S(mip, STIP | LCOFI); S(mstatus, 8);
  for (int i = 0; i < 1000 && m_hits == 2; i++) __asm__ volatile("nop");
  C(mstatus, 8); C(mip, STIP | LCOFI);
  CHECK(m_hits == 3 && m_history[2] == (OF | 13), "delegated source blocked M LCOFI, hits %d", m_hits);

  // With the same destination, standard timer priority precedes LCOFI.
  W(mideleg, 0); S(mip, STIP | LCOFI); S(mstatus, 8);
  for (int i = 0; i < 1000 && m_hits < 5; i++) __asm__ volatile("nop");
  C(mstatus, 8); W(mie, 0); C(mip, STIP | LCOFI);
  CHECK(m_hits == 5 && m_history[3] == (OF | 5) && m_history[4] == (OF | 13),
        "same-mode interrupt order: hits %d causes %d %d", m_hits, (int)m_history[3], (int)m_history[4]);
}

static void test_supervisor_irq(void) {
  W(INHIBIT, ALL_HPM); W(EVENT3, MINH | 23); W(COUNT3, ~0ULL - 8);
  C(mip, LCOFI); W(mcounteren, 8); W(mideleg, LCOFI); W(mie, LCOFI);
  W(stvec, (uintptr_t)&supervisor_irq); S(mstatus, 2); C(INHIBIT, 8);
  uint64_t cause = run_lower(1);
  W(mie, 0); W(mideleg, 0); C(mstatus, 2);
  CHECK(cause == 9 && s_hits == 1 && s_cause == (OF | 13) && (s_overflow & 8),
        "S LCOFI: exit %d hits %d cause %d status %x", (int)cause, s_hits, (int)s_cause, (unsigned)s_overflow);
  CHECK(!(R(mip) & LCOFI) && (R(EVENT3) & OF), "S acknowledge failed or lost sticky OF");

  // A VS-target pending source is ineligible while executing in HS. It
  // must not starve the lower-fixed-priority HS counter overflow interrupt.
  W(INHIBIT, ALL_HPM); W(EVENT3, MINH | 23); W(COUNT3, ~0ULL - 8);
  W(hideleg, 1ULL << 2); W(hvip, 1ULL << 2);
  W(mideleg, LCOFI);
  W(mie, LCOFI | (1ULL << 2)); S(mstatus, 2); C(INHIBIT, 8);
  cause = run_lower(1);
  W(mie, 0); W(hvip, 0); W(hideleg, 0); W(mideleg, 0); C(mstatus, 2);
  CHECK(cause == 9 && s_hits == 2 && s_cause == (OF | 13),
        "VS pending source blocked HS LCOFI: exit %d hits %d", (int)cause, s_hits);
}

int main(void) {
  soc_test_begin("t_sscofpmf");
  W(mie, 0); W(medeleg, 0); C(mstatus, 8);
  W(satp, 0); W(vsatp, 0); W(hgatp, 0);
  W(pmpaddr0, ~0ULL); W(pmpcfg0, 0x1f);
  W(INHIBIT, ALL_HPM); W(EVENT3, ~0ULL);
  CHECK(R(EVENT3) == 0xfc0000000000001fULL, "selector WARL %08x%08x", H64(R(EVENT3)));
  test_filtering();
  printf("PMU FILTER PASS\r\n"); uart_wait_tx_done();
  test_access();
  test_unimplemented();
  printf("PMU ACCESS PASS\r\n"); uart_wait_tx_done();
  test_machine_irq();
  printf("PMU M IRQ PASS\r\n"); uart_wait_tx_done();
  test_supervisor_irq();
  W(INHIBIT, ALL_HPM); W(EVENT3, 0); C(mip, LCOFI); W(mie, 0); W(mideleg, 0);
  soc_install_trap_guard();
  return soc_test_end();
}
