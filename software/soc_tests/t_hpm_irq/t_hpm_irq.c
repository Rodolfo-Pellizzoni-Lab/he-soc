// t_hpm_irq: the overflow interrupt of CVA6's six programmable counters (mhpmcounter3..8, Sscofpmf: overflow bit 63
// of mhpmevent, scountovf, local interrupt 13), for every counter and every hart. t_sscofpmf covers filtering, the
// access rules and the interrupt of counter 3; this test goes through all of them.
//   A. each counter alone: counting cycles from 2^64-64 it wraps and interrupts hart 0 in M-mode (cause 13), with its
//      own bit, and only that bit, in scountovf
//   B. all six: wrapping in the same cycle they raise one interrupt with all six bits; wrapping 4000 cycles apart, six
//      interrupts, each adding one bit (the overflow bit stays set, and a counter whose bit is set raises no new one)
//   C. the event decides when: for events counted at retirement (instructions, loads, stores, control flow, calls,
//      returns, integer instructions) a counter loaded with 2^64-K wraps on exactly the K-th event of a fixed region
//      (counted first, twice), 2^64-(K+1) does not, and with the interrupt on, 2^64-K/2 interrupts inside the region.
//      For events whose count varies (D-cache misses and accesses, I-cache accesses, mispredicts, bubbles, cycles) a
//      workload that makes many of them wraps a counter loaded with 2^64-8 and interrupts
//   D. sampling user code: counter 4 counts user-mode instructions only, period 500, and the M-mode handler reloads it
//      on every interrupt, as a profiler does: 100,000 user instructions give 194..200 samples, each with mepc inside
//      the user loop and MPP = U
//   E. delegated to S-mode: each counter's overflow in S-mode code traps to the S-mode handler (cause 13, its bit)
//   F. no interrupt without its enables: with mie.LCOFIE clear the overflow stays pending until it is set; an
//      inhibited counter (mcountinhibit) and a counter that does not count in M-mode (MINH) do not wrap
//   G. every hart, at the same time: each hart wraps each of its six counters and takes the six interrupts itself
//      (cause 13 in its own handler, its own bit each time)
#include "soc_test.h"

#define NC SOC_NUM_CORES
#define STR_(x) #x
#define STR(x) STR_(x)
#define R(csr) ({ uint64_t _v; __asm__ volatile("csrr %0, " STR(csr) : "=r"(_v)); _v; })
#define W(csr, value) __asm__ volatile("csrw " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define S(csr, value) __asm__ volatile("csrs " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define C(csr, value) __asm__ volatile("csrc " STR(csr) ", %0" :: "r"((uint64_t)(value)) : "memory")
#define INHIBIT 0x320
#define SCOUNTOVF 0xda0
#define EVT(k) 0x32##k
#define CNT(k) 0xb0##k
#define OF (1ULL << 63)                 // mhpmevent's overflow bit, and mcause's interrupt bit
#define MINH (1ULL << 62)
#define LCOFI (1ULL << 13)
#define ALL_HPM 0x1f8ULL
#define IRQ13 (OF | 13)
#define EV_CYCLES 23
#define EV_INSTRET 24
#define PERIOD 500                      // D
#define U_ITERS 25000                   // D: 4 user instructions each
#define REGION_ITERS 200                // C

#define ON_CTR(n, OP) do { switch (n) { case 3: OP(3); break; case 4: OP(4); break; case 5: OP(5); break; \
                                        case 6: OP(6); break; case 7: OP(7); break; case 8: OP(8); break; } } while (0)
static uint64_t ev_r(int n)  { uint64_t v = 0;
#define OP(k) v = R(EVT(k))
  ON_CTR(n, OP);
#undef OP
  return v; }
static void ev_w(int n, uint64_t x) {
#define OP(k) W(EVT(k), x)
  ON_CTR(n, OP);
#undef OP
}
static uint64_t cnt_r(int n) { uint64_t v = 0;
#define OP(k) v = R(CNT(k))
  ON_CTR(n, OP);
#undef OP
  return v; }
static void cnt_w(int n, uint64_t x) {
#define OP(k) W(CNT(k), x)
  ON_CTR(n, OP);
#undef OP
}

// what the M-mode handler saw, per hart
#define MAXREC 8
typedef struct {
  volatile uint64_t hits, cause[MAXREC], ovf[MAXREC], epc[MAXREC];
} rec_t;
static rec_t rec[NC] __attribute__((aligned(64)));
static volatile uint64_t bad_hart;
// D: sampling (hart 0)
static volatile int sampling, user_active;
static volatile uint64_t samples, s_outside, s_not_user, s_no_bit;
static volatile uintptr_t u_lo, u_hi, u_exit;
// E: the S-mode handler
static volatile uint64_t s_hits, s_cause, s_ovf;

__attribute__((interrupt("machine"), aligned(4))) static void m_handler(void) {
  uint64_t cause = R(mcause), h = R(mhartid);
  if (cause == 8 && user_active) {              // D: the user loop's ecall: back to M-mode after the asm block
    user_active = 0;
    W(mepc, u_exit);
    S(mstatus, 3ULL << 11);
    return;
  }
  if (cause != IRQ13) {
    printf("UNEXPECTED M TRAP hart %d mcause %08x%08x mepc %08x%08x\r\n", (int)h, H64(cause), H64(R(mepc)));
    uart_wait_tx_done();
    exit(127);
  }
  if (sampling) {
    const uint64_t epc = R(mepc);
    samples++;
    if (epc < u_lo || epc > u_hi) s_outside++;
    if ((R(mstatus) >> 11) & 3) s_not_user++;
    if (!(R(SCOUNTOVF) & (1ULL << 4))) s_no_bit++;
    W(EVT(4), EV_INSTRET | MINH);               // the overflow bit cleared
    W(CNT(4), -(uint64_t)PERIOD);
    C(mip, LCOFI);
    return;
  }
  if (h >= NC) { bad_hart++; C(mip, LCOFI); return; }
  rec_t *r = &rec[h];
  const uint64_t k = r->hits;
  if (k < MAXREC) { r->cause[k] = cause; r->ovf[k] = R(SCOUNTOVF); r->epc[k] = R(mepc); }
  r->hits = k + 1;
  C(mip, LCOFI);                                // one-shot: the overflow bit stays set
}

__attribute__((interrupt("supervisor"), aligned(4))) static void s_handler(void) {
  s_cause = R(scause);
  s_ovf = R(SCOUNTOVF);
  s_hits++;
  C(sip, LCOFI);
  C(sie, LCOFI);
}

static void reset_rec(int h) { rec[h].hits = 0; for (int k = 0; k < MAXREC; k++) rec[h].cause[k] = rec[h].ovf[k] = 0; }

static void stop_all(void) {
  C(mstatus, 8); W(mie, 0);
  S(INHIBIT, ALL_HPM);
  for (int n = 3; n <= 8; n++) { ev_w(n, 0); cnt_w(n, 0); }
  C(mip, LCOFI);
}

static void wait_hits(volatile uint64_t *hits, uint64_t want, int loops) {
  for (int i = 0; i < loops && *hits < want; i++) __asm__ volatile("nop");
}

// ---- A
static void phase_a(void) {
  rec_t *r = &rec[0];
  for (int n = 3; n <= 8; n++) {
    stop_all(); reset_rec(0);
    ev_w(n, EV_CYCLES); cnt_w(n, -64ULL);
    W(mie, LCOFI); S(mstatus, 8);
    C(INHIBIT, 1ULL << n);
    wait_hits(&r->hits, 1, 20000);
    for (int i = 0; i < 200; i++) __asm__ volatile("nop");     // room for a second, wrong, interrupt
    S(INHIBIT, ALL_HPM); C(mstatus, 8); W(mie, 0);
    const uint64_t c = cnt_r(n);
    CHECK(r->hits == 1, "A counter %d: %d interrupts", n, (int)r->hits);
    CHECK(r->cause[0] == IRQ13, "A counter %d: mcause %08x%08x", n, H64(r->cause[0]));
    CHECK(r->ovf[0] == (1ULL << n), "A counter %d: scountovf %x in the handler", n, (unsigned)r->ovf[0]);
    CHECK((ev_r(n) & OF) && R(SCOUNTOVF) == (1ULL << n), "A counter %d: overflow bit %d, scountovf %x", n,
          (int)(ev_r(n) >> 63), (unsigned)R(SCOUNTOVF));
    CHECK(c < 100000, "A counter %d: %08x%08x after the wrap", n, H64(c));
  }
  stop_all();
  printf("A: each of the six counters wraps and interrupts hart 0 (cause 13, only its own bit)\r\n");
}

// ---- B
static void phase_b(void) {
  rec_t *r = &rec[0];
  stop_all(); reset_rec(0);
  for (int n = 3; n <= 8; n++) { ev_w(n, EV_CYCLES); cnt_w(n, -64ULL); }
  W(mie, LCOFI); S(mstatus, 8);
  C(INHIBIT, ALL_HPM);                                          // all six start in the same cycle
  wait_hits(&r->hits, 1, 20000);
  for (int i = 0; i < 2000; i++) __asm__ volatile("nop");
  S(INHIBIT, ALL_HPM); C(mstatus, 8); W(mie, 0);
  CHECK(r->hits == 1 && r->cause[0] == IRQ13 && r->ovf[0] == ALL_HPM,
        "B same cycle: %d interrupts, scountovf %x in the first", (int)r->hits, (unsigned)r->ovf[0]);
  CHECK(R(SCOUNTOVF) == ALL_HPM, "B same cycle: scountovf %x after", (unsigned)R(SCOUNTOVF));

  stop_all(); reset_rec(0);
  for (int n = 3; n <= 8; n++) { ev_w(n, EV_CYCLES); cnt_w(n, -(uint64_t)(400 + 4000 * (n - 3))); }
  W(mie, LCOFI); S(mstatus, 8);
  C(INHIBIT, ALL_HPM);
  wait_hits(&r->hits, 6, 200000);
  for (int i = 0; i < 2000; i++) __asm__ volatile("nop");
  S(INHIBIT, ALL_HPM); C(mstatus, 8); W(mie, 0);
  CHECK(r->hits == 6, "B staggered: %d interrupts", (int)r->hits);
  for (int k = 0; k < 6 && k < (int)r->hits; k++)
    CHECK(r->cause[k] == IRQ13 && r->ovf[k] == ((1ULL << (4 + k)) - 8),
          "B staggered: interrupt %d: mcause %08x%08x, scountovf %x, expected %x", k, H64(r->cause[k]),
          (unsigned)r->ovf[k], (unsigned)((1ULL << (4 + k)) - 8));
  stop_all();
  printf("B: six counters wrapping in one cycle give one interrupt with six bits; wrapping apart, six\r\n");
}

// ---- C
static volatile uint64_t cbuf[64];
__attribute__((noinline)) static uint64_t leaf(uint64_t x) { __asm__ volatile(""); return x * 3 + 1; }
__attribute__((noinline)) static uint64_t region(void) {
  uint64_t acc = 1;
  for (int i = 0; i < REGION_ITERS; i++) {
    acc += cbuf[i & 63];
    cbuf[(i + 7) & 63] = acc;
    if (acc & 1) acc = leaf(acc); else acc ^= (uint64_t)i;
  }
  return acc;
}
static volatile uint8_t big[48 * 1024] __attribute__((aligned(64)));
__attribute__((noinline)) static uint64_t busy(void) {
  uint64_t acc = 0, x = 12345;
  for (int i = 0; i < (int)sizeof big; i += 64) {
    acc += big[i];                                                 // one load per line: D-cache misses
    x = x * 6364136223846793005ULL + 1442695040888963407ULL;
    if (x >> 63) acc += (uint64_t)i; else acc ^= x;                // a data-dependent branch: mispredicts
  }
  return acc;
}
static volatile uint64_t sink;
// counter n counts only around the call
static void window(int n, uint64_t (*f)(void)) {
  const uint64_t m = 1ULL << n;
  for (int i = 0; i < 64; i++) cbuf[i] = (uint64_t)i * 7 + 3;
  __asm__ volatile("csrc 0x320, %0" :: "r"(m) : "memory");
  const uint64_t a = f();
  __asm__ volatile("csrs 0x320, %0" :: "r"(m) : "memory");
  sink = a;
}
static int in_region(uint64_t epc) {
  return (epc >= (uintptr_t)&region && epc < (uintptr_t)&region + 1024) ||
         (epc >= (uintptr_t)&leaf && epc < (uintptr_t)&leaf + 256);
}

static void phase_c(void) {
  rec_t *r = &rec[0];
  static const struct { int ev; const char *name; } exact[] = {
    { EV_INSTRET, "instructions" }, { 5, "loads" }, { 6, "stores" }, { 9, "control flow" },
    { 12, "calls" }, { 13, "returns" }, { 20, "integer instructions" },
  };
  for (unsigned e = 0; e < sizeof exact / sizeof exact[0]; e++) {
    const int n = 3 + (int)(e % 6), ev = exact[e].ev;
    stop_all();
    ev_w(n, ev); cnt_w(n, 0); window(n, region);
    const uint64_t k = cnt_r(n);
    cnt_w(n, 0); window(n, region);
    const uint64_t k2 = cnt_r(n);
    CHECK(k >= 50 && k == k2, "C %s on counter %d: %d then %d in the region", exact[e].name, n, (int)k, (int)k2);
    // masked: K wraps on the last event, K+1 does not
    ev_w(n, ev); C(mip, LCOFI); cnt_w(n, -k); window(n, region);
    CHECK((ev_r(n) & OF) && (R(mip) & LCOFI) && cnt_r(n) == 0, "C %s: loaded with -K: overflow %d pending %d count %d",
          exact[e].name, (int)(ev_r(n) >> 63), (int)((R(mip) >> 13) & 1), (int)cnt_r(n));
    ev_w(n, ev); C(mip, LCOFI); cnt_w(n, -(k + 1)); window(n, region);
    CHECK(!(ev_r(n) & OF) && !(R(mip) & LCOFI) && cnt_r(n) == ~0ULL,
          "C %s: loaded with -(K+1): overflow %d pending %d count %08x%08x", exact[e].name, (int)(ev_r(n) >> 63),
          (int)((R(mip) >> 13) & 1), H64(cnt_r(n)));
    // the interrupt, inside the region
    ev_w(n, ev); C(mip, LCOFI); reset_rec(0); cnt_w(n, -(k / 2));
    W(mie, LCOFI); S(mstatus, 8);
    window(n, region);
    C(mstatus, 8); W(mie, 0);
    CHECK(r->hits == 1 && r->cause[0] == IRQ13 && r->ovf[0] == (1ULL << n) && in_region(r->epc[0]),
          "C %s: loaded with -K/2: %d interrupts, scountovf %x, mepc %08x%08x (region at %08x%08x)", exact[e].name,
          (int)r->hits, (unsigned)r->ovf[0], H64(r->epc[0]), H64((uintptr_t)&region));
  }
  static const struct { int ev; const char *name; uint64_t (*work)(void); } loose[] = {
    { 2, "D-cache misses", busy }, { 10, "branch mispredicts", busy }, { 17, "D-cache accesses", region },
    { 16, "I-cache accesses", region }, { 22, "pipeline bubbles", busy }, { EV_CYCLES, "cycles", region },
  };
  for (unsigned e = 0; e < sizeof loose / sizeof loose[0]; e++) {
    const int n = 3 + (int)(e % 6), ev = loose[e].ev;
    stop_all();
    ev_w(n, ev); cnt_w(n, 0); window(n, loose[e].work);
    const uint64_t k = cnt_r(n);
    CHECK(k >= 16, "C %s on counter %d: %d in the workload", loose[e].name, n, (int)k);
    ev_w(n, ev); C(mip, LCOFI); reset_rec(0); cnt_w(n, -8ULL);
    W(mie, LCOFI); S(mstatus, 8);
    window(n, loose[e].work);
    C(mstatus, 8); W(mie, 0);
    CHECK(r->hits == 1 && r->cause[0] == IRQ13 && r->ovf[0] == (1ULL << n),
          "C %s: loaded with -8: %d interrupts, scountovf %x", loose[e].name, (int)r->hits, (unsigned)r->ovf[0]);
  }
  stop_all();
  printf("C: a counter wraps on exactly its K-th event (7 exact events) and interrupts on all 13 events tried\r\n");
}

// ---- D: a user-mode loop of U_ITERS x 4 instructions; the handler's ecall path returns to label 1 in M-mode
static void run_user_loop(uint64_t iters) {
  const uint64_t clear = (3ULL << 11) | (1ULL << 39);           // MPP = U, MPV = 0
  user_active = 1;
  __asm__ volatile(
      "la t0, 2f\n sd t0, 0(%[lo])\n la t0, 3f\n sd t0, 0(%[hi])\n la t0, 1f\n sd t0, 0(%[ex])\n"
      "csrc mstatus, %[clear]\n"
      "la t0, 2f\n csrw mepc, t0\n mv t1, %[n]\n mret\n"
      "2: addi t1, t1, -1\n nop\n nop\n bnez t1, 2b\n"
      "3: ecall\n"
      ".align 2\n1: csrs 0x320, %[inh]\n"
      :
      : [lo] "r"(&u_lo), [hi] "r"(&u_hi), [ex] "r"(&u_exit), [clear] "r"(clear), [n] "r"(iters), [inh] "r"(ALL_HPM)
      : "t0", "t1", "memory");
}

static void phase_d(void) {
  stop_all();
  samples = s_outside = s_not_user = s_no_bit = 0;
  ev_w(4, EV_INSTRET | MINH); cnt_w(4, -(uint64_t)PERIOD);
  sampling = 1;
  W(mie, LCOFI);
  C(INHIBIT, 1ULL << 4);
  run_user_loop(U_ITERS);
  S(INHIBIT, ALL_HPM); W(mie, 0);
  sampling = 0;
  const uint64_t ins = 4ULL * U_ITERS, lo = ins / (PERIOD + 16), hi = ins / PERIOD;
  CHECK(!user_active, "D: the user loop did not come back through its ecall");
  CHECK(samples >= lo && samples <= hi, "D: %d samples for %d user instructions, expected %d..%d", (int)samples,
        (int)ins, (int)lo, (int)hi);
  CHECK(s_outside == 0, "D: %d samples with mepc outside the user loop at %08x%08x", (int)s_outside, H64(u_lo));
  CHECK(s_not_user == 0, "D: %d samples with MPP not U", (int)s_not_user);
  CHECK(s_no_bit == 0, "D: %d samples without counter 4's bit in scountovf", (int)s_no_bit);
  stop_all();
  printf("D: sampling user code: %d samples for %d instructions at period %d, every mepc in the loop, MPP U\r\n",
         (int)samples, (int)ins, PERIOD);
}

// ---- E: 64 S-mode NOPs, then an ecall back to M-mode through label 1 (mtvec swapped, as t_sscofpmf does)
static uint64_t run_supervisor(void) {
  uint64_t cause, old;
  const uint64_t clear = (3ULL << 11) | (1ULL << 39), set = 1ULL << 11;
  __asm__ volatile(
      "csrr %[old], mtvec\n la t0, 1f\n csrw mtvec, t0\n"
      "csrc mstatus, %[clear]\n csrs mstatus, %[set]\n"
      "la t0, 2f\n csrw mepc, t0\n mret\n"
      "2: .rept 64\n nop\n .endr\n ecall\n .align 2\n"
      "1: csrs 0x320, %[inh]\n csrr %[cause], mcause\n"
      "csrw mtvec, %[old]\n csrc mstatus, %[clear]\n"
      : [cause] "=&r"(cause), [old] "=&r"(old)
      : [clear] "r"(clear), [set] "r"(set), [inh] "r"(ALL_HPM)
      : "t0", "memory");
  return cause;
}

static void phase_e(void) {
  W(mcounteren, ~0ULL);
  W(stvec, (uintptr_t)&s_handler);
  for (int n = 3; n <= 8; n++) {
    stop_all();
    s_hits = s_cause = s_ovf = 0;
    ev_w(n, EV_CYCLES | MINH); cnt_w(n, -30ULL);
    W(mideleg, LCOFI); W(mie, LCOFI); S(mstatus, 2);
    C(INHIBIT, 1ULL << n);
    const uint64_t cause = run_supervisor();
    W(mie, 0); W(mideleg, 0); C(mstatus, 2);
    CHECK(cause == 9 && s_hits == 1 && s_cause == IRQ13 && s_ovf == (1ULL << n),
          "E counter %d: exit cause %d, %d S interrupts, scause %08x%08x, scountovf %x", n, (int)cause, (int)s_hits,
          H64(s_cause), (unsigned)s_ovf);
  }
  stop_all();
  printf("E: delegated, each counter's overflow interrupts S-mode (cause 13, its own bit)\r\n");
}

// ---- F
static void phase_f(void) {
  rec_t *r = &rec[0];
  stop_all(); reset_rec(0);
  ev_w(8, EV_CYCLES); cnt_w(8, -64ULL);
  C(INHIBIT, 1ULL << 8);
  for (int i = 0; i < 500; i++) __asm__ volatile("nop");
  CHECK((ev_r(8) & OF) && (R(mip) & LCOFI) && r->hits == 0, "F masked: overflow %d pending %d interrupts %d",
        (int)(ev_r(8) >> 63), (int)((R(mip) >> 13) & 1), (int)r->hits);
  W(mie, LCOFI); S(mstatus, 8);
  wait_hits(&r->hits, 1, 2000);
  C(mstatus, 8); W(mie, 0);
  CHECK(r->hits == 1 && r->ovf[0] == (1ULL << 8), "F unmasked: %d interrupts, scountovf %x", (int)r->hits,
        (unsigned)r->ovf[0]);

  stop_all(); reset_rec(0);
  ev_w(5, EV_CYCLES); cnt_w(5, ~0ULL);                           // inhibited: does not count
  W(mie, LCOFI); S(mstatus, 8);
  for (int i = 0; i < 500; i++) __asm__ volatile("nop");
  C(mstatus, 8); W(mie, 0);
  CHECK(cnt_r(5) == ~0ULL && !(ev_r(5) & OF) && r->hits == 0, "F mcountinhibit: count %08x%08x, interrupts %d",
        H64(cnt_r(5)), (int)r->hits);

  stop_all(); reset_rec(0);
  ev_w(6, EV_CYCLES | MINH); cnt_w(6, ~0ULL);                    // counts outside M-mode only
  W(mie, LCOFI); S(mstatus, 8);
  C(INHIBIT, 1ULL << 6);
  for (int i = 0; i < 500; i++) __asm__ volatile("nop");
  S(INHIBIT, ALL_HPM); C(mstatus, 8); W(mie, 0);
  CHECK(cnt_r(6) == ~0ULL && !(ev_r(6) & OF) && r->hits == 0, "F MINH: count %08x%08x, interrupts %d",
        H64(cnt_r(6)), (int)r->hits);
  stop_all();
  printf("F: no interrupt with mie.LCOFIE clear (pending until set), inhibited, or not counting in M-mode\r\n");
}

// ---- G: every hart at once
static void hart_work(int cid) {
  W(mtvec, (uintptr_t)&m_handler);
  stop_all(); reset_rec(cid);
  soc_barrier(NC, 1);
  for (int n = 3; n <= 8; n++) {
    S(INHIBIT, ALL_HPM); ev_w(n, EV_CYCLES); cnt_w(n, -200ULL); C(mip, LCOFI);
    W(mie, LCOFI); S(mstatus, 8);
    C(INHIBIT, 1ULL << n);
    wait_hits(&rec[cid].hits, (uint64_t)(n - 2), 20000);
    S(INHIBIT, ALL_HPM); C(mstatus, 8); W(mie, 0);
    ev_w(n, 0); C(mip, LCOFI);
  }
  soc_barrier(NC, 2);
}

static void check_g(void) {
  for (int h = 0; h < NC; h++) {
    rec_t *r = &rec[h];
    CHECK(r->hits == 6, "G hart %d: %d interrupts", h, (int)r->hits);
    for (int k = 0; k < 6 && k < (int)r->hits; k++)
      CHECK(r->cause[k] == IRQ13 && r->ovf[k] == (1ULL << (3 + k)), "G hart %d interrupt %d: mcause %08x%08x, "
            "scountovf %x", h, k, H64(r->cause[k]), (unsigned)r->ovf[k]);
  }
  CHECK(bad_hart == 0, "G: %d interrupts on a hart id beyond %d", (int)bad_hart, NC - 1);
  printf("G: on each of the %d harts, each counter's interrupt is taken by that hart, with its own bit\r\n", NC);
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_hpm_irq");
    CHECK(soc_wake_all() == SOC_WAKE_MASK, "not every hart started");
    hart_work(0);
    return 0;                                 // core 0 continues in main()
  }
  hart_work(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  check_g();
  W(mtvec, (uintptr_t)&m_handler);
  W(medeleg, 0); W(mideleg, 0);
  W(satp, 0); W(vsatp, 0); W(hgatp, 0);
  W(pmpaddr0, ~0ULL); W(pmpcfg0, 0x1f);
  phase_a();
  phase_b();
  phase_c();
  phase_d();
  phase_e();
  phase_f();
  stop_all();
  W(INHIBIT, 0);
  soc_install_trap_guard();
  return soc_test_end();
}
