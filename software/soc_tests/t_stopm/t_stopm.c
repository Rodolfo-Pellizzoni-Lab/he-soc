// Linux's multi_cpu_stop (kernel/stop_machine.c), ported to bare metal for every core of the build.
// Every core runs the same loop: read the shared state, and when it changed, acknowledge with an atomic decrement
// of thread_ack; the core whose decrement reaches zero resets thread_ack and writes the next state (plain stores),
// exactly like ack_state()/set_state(). state and thread_ack sit in one struct, i.e. one 16-byte CVA6 line, as
// msdata does. While waiting, a core does what the kernel loop does per iteration: a plain store to its own line
// (touch_nmi_watchdog) and an atomic add on its own line (rcu_momentary_dyntick_idle). A core that spins far too
// long counts a stall instead of hanging the test, and core 0 prints a stall report: the shared state and
// thread_ack as it sees them and, per core, the last state acknowledged, the value its decrement returned, how
// often it advanced the state and a heartbeat (loop iterations, in SRAM) that shows which core stopped moving.
// Only core 0 prints. Build with -DSOC_NUM_CORES=<n>; -DNO_SIDE_EFFECTS drops the per-iteration side effects,
// -DROUNDS=<n> -DVERBOSE -DSPIN_LIMIT=10000u suit a simulation run. hardware/docs/cores.md has the findings.
#include "soc_test.h"

#define NC         SOC_NUM_CORES
#ifndef ROUNDS
#define ROUNDS     200
#endif
#define ST_EXIT    4                      // PREPARE 1, DISABLE_IRQ 2, RUN 3, EXIT 4 as in the kernel
#ifndef SPIN_LIMIT
#define SPIN_LIMIT 1000000u                                             // iterations without a state change before a stall is counted (-DSPIN_LIMIT=10000u for xsim)
#endif

struct msdata { volatile uint32_t state; volatile uint32_t thread_ack; uint64_t pad; };
static struct msdata msd __attribute__((aligned(64)));                  // shared, cached DRAM
static volatile uint64_t percpu[SOC_NUM_CORES][8] __attribute__((aligned(64)));
SOC_SRAM static volatile uint32_t stalls[NC];
SOC_SRAM static volatile uint32_t done_flag[NC];
SOC_SRAM static volatile uint32_t advances[NC];                          // how often this core was the last acker
SOC_SRAM static volatile uint32_t acked[NC];                             // last state this core acknowledged
SOC_SRAM static volatile uint32_t ack_old[NC];                           // thread_ack value its atomic returned
SOC_SRAM static volatile uint32_t beats[NC];                             // loop iterations, a heartbeat per core
SOC_SRAM static volatile uint32_t diag_done;

static inline uint32_t ld32(volatile uint32_t *p) { uint32_t v; __asm__ volatile("lw %0, 0(%1)" : "=r"(v) : "r"(p) : "memory"); return v; }

static void multi_cpu_stop(int cid) {
  uint32_t curstate = 0;                                                 // MULTI_STOP_NONE
  unsigned spins = 0;
  do {
    // cpu_relax + the per-iteration side effects of the kernel loop (-DNO_SIDE_EFFECTS leaves only the bare spin)
#ifndef NO_SIDE_EFFECTS
    percpu[cid][1] = percpu[cid][1] + 1;                                // touch_nmi_watchdog: a store to my line
    __atomic_fetch_add(&percpu[cid][0], 2, __ATOMIC_SEQ_CST);           // rcu_momentary_dyntick_idle: an atomic on my line
#endif
    beats[cid]++;
    uint32_t newstate = ld32(&msd.state);
    if (newstate != curstate) {
      curstate = newstate; spins = 0;
      // ack_state(): the last one to ack moves everybody to the next state
      uint32_t old = __atomic_fetch_sub(&msd.thread_ack, 1, __ATOMIC_SEQ_CST);
      acked[cid] = curstate; ack_old[cid] = old;
      if (old == 1) {
        advances[cid]++;
        __atomic_store_n(&msd.thread_ack, (uint32_t)NC, __ATOMIC_SEQ_CST);   // set_state(): atomic_set, smp_wmb, WRITE_ONCE
        __atomic_store_n(&msd.state, curstate + 1, __ATOMIC_SEQ_CST);
      }
    } else if (++spins > SPIN_LIMIT) {
      stalls[cid]++; spins = 0;
      if (cid == 0 && diag_done < 2) {                                   // two diagnostics from core 0, one spin limit apart
        diag_done++;
        printf("STALL %u: state=%u thread_ack=%u (NC=%d); per core acked/old/advances/beats:", diag_done,
               ld32(&msd.state), ld32(&msd.thread_ack), NC);
        for (int c = 0; c < NC; c++) printf(" %u/%u/%u/%u", acked[c], ack_old[c], advances[c], beats[c]);
        printf("\r\n");
      }
    }
  } while (curstate != ST_EXIT);
}

static void run(int cid) {
  for (int r = 0; r < ROUNDS; r++) {
    soc_barrier(NC, 2 * r + 1);
    if (cid == 0) {                                                      // the caller: set_state(PREPARE), queue the works
      __atomic_store_n(&msd.thread_ack, (uint32_t)NC, __ATOMIC_SEQ_CST);
      __atomic_store_n(&msd.state, 1u, __ATOMIC_SEQ_CST);
    }
    multi_cpu_stop(cid);
    soc_barrier(NC, 2 * r + 2);
    if (cid == 0) {
      __atomic_store_n(&msd.state, 0u, __ATOMIC_SEQ_CST);
#ifdef VERBOSE
      printf("round %d done\r\n", r);
#endif
    }
  }
  done_flag[cid] = 1;
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_stopm");
    soc_wake_all();
    run(0);
    return 0;
  }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  uint32_t adv = 0;
  for (int c = 0; c < NC; c++) CHECK(done_flag[c] == 1, "core %d finished", c);
  for (int c = 0; c < NC; c++) CHECK(stalls[c] == 0, "core %d: %u stalled spins", c, stalls[c]);
  for (int c = 0; c < NC; c++) adv += advances[c];
  CHECK(adv == (uint32_t)ROUNDS * ST_EXIT, "state advances %u, expected %u", adv, (unsigned)ROUNDS * ST_EXIT);
  printf("multi_cpu_stop port: %d rounds x %d states on %d cores; advances per core:", ROUNDS, ST_EXIT, NC);
  for (int c = 0; c < NC; c++) printf(" %u", advances[c]);
  printf("\r\n");
  return soc_test_end();
}
