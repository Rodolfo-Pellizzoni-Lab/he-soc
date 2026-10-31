// t_spulat: the latencies the APMU's SPUs report for DRAM writes and for the accelerator socket's DMA, with
// N = SOC_NUM_CORES cores (4 or 8: build with -DSOC_NUM_CORES=<n>; every select below comes from pmu_defines.h).
//
// A response event of an SPU carries its transfer's latency in SoC cycles in e_info[15:0] (e_info[16] is the address
// rule, 1 for DRAM; hardware/ip_list/spu/src/axi_spu_top.sv), and a counter with Event Info ADD_RESP_LAT adds it up.
// No test made a known number of DRAM writes at the LLC memory port yet, nor read the latency of the SPU on the
// socket's DMA. Here two masters make known DRAM traffic, one at a time, while every other core sleeps:
//   A. core 0, in DRAM outside the LLC window (the LLC passes it through to its memory port): NW lines stored (both
//      words of each) and NR lines loaded, none of them in the L1 at the start (fence.i), then fence.i, which writes
//      back every dirty line (t_dma). Exactly NW + NR reads (a write-allocate refill per stored line, a fill per
//      loaded one) and exactly NW writes (a stored line goes dirty once and is written back once, evicted or at the
//      fence.i), all of source 0 on the memory port's SPU (port 2N+1): its R_REQ, R_RESP, W_REQ and W_RESP, the
//      responses' latency sums, and their smallest and largest latency (Event Info opcodes KEEP_MIN and KEEP_MAX).
//   B. the socket's DMA (slot 0, example: dst[i] = src[i] + ARG, one word in flight) copies ND words outside the LLC
//      window, a single-beat read and a single-beat write each: exactly ND of every event on the socket's SPU (port
//      2N+2) and for source N on port 2N+1, with the latency sums of both.
// Latency bounds, in SoC cycles (both SPUs run on the SoC clock):
//   - port 2N+1 times a transfer from the first cycle its AR / AW is valid to the first cycle its last R beat / its B
//     is valid. Behind it the slowdown (hardware/host/host_domain.sv) offers a request to the memory 2 cycles after
//     it arrived at the earliest (FIFOs with registered pointers, then its release FSM) and holds every R beat and
//     every B for 20 cycles: no latency is below LAT_MIN = 22, whatever the memory does (23 when it answers no earlier
//     than the cycle after a handshake, 24 for core 0's 2-beat lines). The upper bounds are margins over the measured
//     reads (64 cycles in xsim, about 110 on the board).
//   - port 2N+2 sits in front of the AR / AW spill register of the socket's port of the coherence unit
//     (hardware/host/cva6_subsystem.sv): its latency is port 2N+1's for the same transfer plus that register, the
//     coherence unit (decode and the snoop round of every core's L1: a ReadOnce or a WriteUnique), the interconnect
//     and the LLC's pass-through, both ways. A read's data can only come from DRAM (no L1 or LLC holds it), so a
//     socket read takes 1 to CCU_MAX cycles more than on port 2N+1. A write is checked in its own range: that its B
//     is the memory's, passed back by every stage, is not verified here (both averages are printed).
// Exact counts need core 0's own code and data to stay out of DRAM in the windows, whose fence.i empties both L1
// caches: the LLC is flushed first (it replaces at random, and on the board it may still be full of an earlier
// program's lines), then the code the windows run is read into it (code_warm), and a warm-up pass runs the very same
// code from the same call site on the first lines of each kind (not checked); the windows touch only registers,
// MMIO, and stack and .bss lines the warm-up brought into the LLC. The DRAM timing model is switched off where the
// bitstream has it; the other cores and masters are left alone. No counter gets near bit 30.
#include "soc_test.h"
#include "accel.h"

// ---- the traffic
#define CORE0      0                     // phase A's core; it also runs the test and drives the socket
#define SLOT       0                     // the socket slot of the example engine
#define EXAMPLE_ID 0xAC0C9B9Fu           // its ID register, +0x20 (software/accel/example/example.c)
#define ARG        0x11u                 // the engine writes src[i] + ARG
// DRAM outside the LLC window (0x8000_0000-0x807F_FFFF, checked below) and inside the 256 MB the cores cache, where
// t_srcid's phase B works too (its BYP_BASE + 2 * PASS_STEP): the LLC passes every request through to its memory port
#define AREA       0x81200000UL
#define W_BASE     (AREA + 0x0000)       // A: the stored lines, 16 bytes apart (L1 sets 0-31)
#define R_BASE     (AREA + 0x0400)       // A: the loaded lines, 16 bytes apart (L1 sets 64-79)
#define DMA_SRC    (AREA + 0x1000)       // B: the engine's source words
#define DMA_DST    (AREA + 0x2000)       // B: its destination words
#define L1_LINE    16                    // the L1 D$: 16 KB, 8 ways of 16-byte lines
#define NW         32                    // A: lines stored: 32 refills and 32 write-backs
#define NR         16                    // A: lines loaded: 16 refills
#define ND         24                    // B: words copied: 24 reads and 24 writes
#define NW0        2                     // the warm-up pass: the same code on the first lines of each kind
#define NR0        2
#define ND0        2
#define PAT_W0     0x55u                 // a word's value: its address ^ the run's salt ^ PAT_*
#define PAT_W1     0xAAu
#define PAT_R      0x33u
#define PAT_D      0x0Fu
#define SALT_STEP  0x9E3779B97F4A7C15ULL // from the previous run's salt to this run's
#if AREA < 0x80800000UL || AREA + 0x3000 > 0x90000000UL
#error "t_spulat: the area must be outside the LLC window and inside the cores' cacheable DRAM"
#endif
_Static_assert(NW * L1_LINE <= 0x400 && NR * L1_LINE <= 0xC00 && 8 * ND <= 0x1000, "t_spulat: the buffers overlap");

// ---- the bounds, in SoC cycles
#ifndef LAT_MIN                          // a bitstream without the slowdown (USE_SLOWDOWN off) needs -DLAT_MIN=1
#define LAT_MIN    (2 + 20)              // the slowdown's earliest release + its R / B delay (host_domain.sv)
#endif
#ifdef FPGA_EMULATION                    // the board: OpenDRAM with 16x DRAM timing, about 110 cycles per read
#define LAT_AVG_MAX 600
#define LAT_EV_MAX  4000                 // one response (a DRAM refresh may hold one back)
#define POLL_MAX    2000000UL            // STATUS polls before a copy counts as failed
#define SETTLE      10000                // cycles for the last responses and the counters to land (t_storm)
#define CYC_MAX     500000000ULL         // cycles before the LLC flush counts as failed (t_storm)
#else                                    // xsim: 64 cycles per read
#define LAT_AVG_MAX 200
#define LAT_EV_MAX  1000
#define POLL_MAX    20000UL
#define SETTLE      1000
#define CYC_MAX     200000ULL
#endif
#define CCU_MAX     400                  // B: port 2N+2 over port 2N+1, per transfer, at most
#define SNAP_ROUNDS 8
#define WARM_FN     2048                 // code_warm: bytes from a window function's entry (its body and beyond)
#define WARM_MAIN   4096                 // code_warm: bytes from main's entry

// ---- the SoC
#define DM         0x1A106100UL          // the DRAM timing model (hardware/host/axi_dram_timing.sv, t_dram)
#define DM_CTRL    0x00
#define DM_ID      0x24
#define DM_ID_VAL  0xD2A30001u
#define LLC_START  0x1A106018UL          // the LLC's cached window (as t_storm checks it)
#define LLC_END    0x1A10601CUL
#define LLC_FLUSH  0x10401008UL          // a mask of ways to flush; reads 0 once they are (t_storm)

// ---- the APMU counters
// Event Info (pmu_pkg::event_info_cfg_t): eisf_start [4:0], eisf_end [9:5], opcode [14:10], event_info_en [23].
// ADD_RESP_LAT is event_info_en with e_info[15:0] and opcode ADD; KEEP_MAX (1) and KEEP_MIN (2) keep the largest and
// the smallest latency instead of adding them.
#define INFO_COUNT 0u
#define INFO_SUM   ADD_RESP_LAT
#define INFO_MAX   (ADD_RESP_LAT | (1u << 10))
#define INFO_MIN   (ADD_RESP_LAT | (2u << 10))
#define MIN_START  0x3FFFFFFFu           // KEEP_MIN's start: above every 16-bit latency, bit 30 (overflow) clear
enum {
  C_RRQ, C_RRS, C_RLAT,                  // A: port 2N+1, core 0: read requests, responses, latency sum
  C_WRQ, C_WRS, C_WLAT,                  //    write requests, responses, latency sum
  C_RMIN, C_RMAX, C_WMIN, C_WMAX,        //    the smallest and largest read / write latency (reset by each pass)
  C_TRQ, C_TWQ,                          // port 2N+1, every source: read / write requests
  C_SRQ, C_SRS, C_SRLAT,                 // B: port 2N+2 (the socket's SPU): read requests, responses, latency sum
  C_SWQ, C_SWS, C_SWLAT,                 //    write requests, responses, latency sum
  C_MRQ, C_MRS, C_MRLAT,                 // B: port 2N+1, source N (the socket's DMA): the same
  C_MWQ, C_MWS, C_MWLAT,
  NCTR
};
_Static_assert(NCTR <= NUM_COUNTER, "t_spulat needs more counters than the APMU has");
typedef struct { uint32_t sel, info, start; } ctr_cfg_t;
static const ctr_cfg_t ctr_cfg[NCTR] = {
  [C_RRQ]   = { MEM_RD_REQ_CORE(CORE0), INFO_COUNT, 0 },
  [C_RRS]   = { MEM_RD_RES_CORE(CORE0), INFO_COUNT, 0 },
  [C_RLAT]  = { MEM_RD_RES_CORE(CORE0), INFO_SUM,   0 },
  [C_WRQ]   = { MEM_WR_REQ_CORE(CORE0), INFO_COUNT, 0 },
  [C_WRS]   = { MEM_WR_RES_CORE(CORE0), INFO_COUNT, 0 },
  [C_WLAT]  = { MEM_WR_RES_CORE(CORE0), INFO_SUM,   0 },
  [C_RMIN]  = { MEM_RD_RES_CORE(CORE0), INFO_MIN,   MIN_START },
  [C_RMAX]  = { MEM_RD_RES_CORE(CORE0), INFO_MAX,   0 },
  [C_WMIN]  = { MEM_WR_RES_CORE(CORE0), INFO_MIN,   MIN_START },
  [C_WMAX]  = { MEM_WR_RES_CORE(CORE0), INFO_MAX,   0 },
  [C_TRQ]   = { MEM_RD_REQ,             INFO_COUNT, 0 },
  [C_TWQ]   = { MEM_WR_REQ,             INFO_COUNT, 0 },
  [C_SRQ]   = { ACC_RD_REQ,             INFO_COUNT, 0 },
  [C_SRS]   = { ACC_RD_RES,             INFO_COUNT, 0 },
  [C_SRLAT] = { ACC_RD_RES,             INFO_SUM,   0 },
  [C_SWQ]   = { ACC_WR_REQ,             INFO_COUNT, 0 },
  [C_SWS]   = { ACC_WR_RES,             INFO_COUNT, 0 },
  [C_SWLAT] = { ACC_WR_RES,             INFO_SUM,   0 },
  [C_MRQ]   = { MEM_RD_REQ_ACCEL,       INFO_COUNT, 0 },
  [C_MRS]   = { MEM_RD_RES_ACCEL,       INFO_COUNT, 0 },
  [C_MRLAT] = { MEM_RD_RES_ACCEL,       INFO_SUM,   0 },
  [C_MWQ]   = { MEM_WR_REQ_ACCEL,       INFO_COUNT, 0 },
  [C_MWS]   = { MEM_WR_RES_ACCEL,       INFO_COUNT, 0 },
  [C_MWLAT] = { MEM_WR_RES_ACCEL,       INFO_SUM,   0 },
};

// the snapshots around A's and B's window, and the window results (.bss: in the LLC once the warm-up has run)
static uint32_t a_bef[NCTR], a_aft[NCTR], b_bef[NCTR], b_aft[NCTR];
static uint64_t rd_sum;
static uint32_t snap_bad, dma_bad, dma_status;

static inline __attribute__((always_inline)) uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }
static inline __attribute__((always_inline)) void st(uint64_t a, uint64_t v) { *(volatile uint64_t *)a = v; }
static inline __attribute__((always_inline)) void wait_cycles(uint64_t n) {
  const uint64_t t = soc_cycles();
  while (soc_cycles() - t < n) ;
}
static inline uint32_t avg(uint32_t sum, uint32_t n) { return n ? sum / n : 0; }

static void ctr_set(int i, uint32_t sel, uint32_t info, uint32_t start) {
  REG32(EVENT_SEL_BASE_ADDR   + i * COUNTER_BUNDLE_SIZE) = 0;     // off first: a write is held while it counts
  REG32(EVENT_INFO_BASE_ADDR  + i * COUNTER_BUNDLE_SIZE) = info;
  REG32(INIT_BUDGET_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  REG32(COUNTER_BASE_ADDR     + i * COUNTER_BUNDLE_SIZE) = start;
  REG32(EVENT_SEL_BASE_ADDR   + i * COUNTER_BUNDLE_SIZE) = sel;
}
// the PE held and no MemGuard period (as t_storm), so that nothing but the events moves a counter; the counters this
// test does not use switched off, none of them with an overflow interrupt
static void apmu_setup(void) {
  REG32(PMC_STATUS_ADDR) = 1;
  REG32(PERIOD_ADDR) = 0; REG32(PERIOD_ADDR + 4) = 0;
  for (int i = 0; i < NUM_COUNTER; i++) {
    if (i < NCTR) ctr_set(i, ctr_cfg[i].sel, ctr_cfg[i].info, ctr_cfg[i].start);
    else          ctr_set(i, 0, 0, 0);
  }
}
// the smallest / largest latency counters start over for each pass (immediates only: no table read)
static void minmax_reset(void) {
  ctr_set(C_RMIN, MEM_RD_RES_CORE(CORE0), INFO_MIN, MIN_START);
  ctr_set(C_RMAX, MEM_RD_RES_CORE(CORE0), INFO_MAX, 0);
  ctr_set(C_WMIN, MEM_WR_RES_CORE(CORE0), INFO_MIN, MIN_START);
  ctr_set(C_WMAX, MEM_WR_RES_CORE(CORE0), INFO_MAX, 0);
}
// every way of the LLC written back and invalidated (t_storm); 0, or -1 if it did not finish within CYC_MAX
static int llc_flush(void) {
  REG32(LLC_FLUSH) = 0xFFFF;
  const uint64_t t0 = soc_cycles();
  while (REG32(LLC_FLUSH) != 0) if (soc_cycles() - t0 > CYC_MAX) return -1;
  return 0;
}
// before a window: core 0's L1 written back (stack and .bss lines: LLC hits) and emptied, the responses landed
static inline __attribute__((always_inline)) void quiet(void) {
  __asm__ volatile("fence\n\tfence.i" ::: "memory");
  wait_cycles(SETTLE);
}

// ---- the window code (noinline, noclone: code_warm reads it into the LLC from these functions' addresses)
// every counter at one moment: read them all until two reads in a row agree; 0 if they did not settle
__attribute__((noinline, noclone)) static int snap(uint32_t *v) {
  uint32_t w[NCTR];
  int same, n = 0;
#pragma GCC unroll 1
  do {
    for (int i = 0; i < NCTR; i++) v[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    for (int i = 0; i < NCTR; i++) w[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    same = 1;
    for (int i = 0; i < NCTR; i++) same &= v[i] == w[i];
  } while (!same && ++n < SNAP_ROUNDS);
  return same;
}
// A's window: nw lines stored (a refill each, dirty), nr loaded (a refill each, clean), then every dirty line
// written back; registers only
__attribute__((noinline, noclone)) static uint64_t core_traffic(uint32_t nw, uint32_t nr, uint64_t salt) {
  uint64_t s = 0;
#pragma GCC unroll 1
  for (uint32_t i = 0; i < nw; i++) {
    const uint64_t a = W_BASE + (uint64_t)i * L1_LINE;
    st(a, a ^ salt ^ PAT_W0);
    st(a + 8, a ^ salt ^ PAT_W1);
  }
#pragma GCC unroll 1
  for (uint32_t i = 0; i < nr; i++) s += ld(R_BASE + (uint64_t)i * L1_LINE);
  __asm__ volatile("fence\n\tfence.i" ::: "memory");
  return s;
}
// B's window: the engine copies nd words (MMIO only); its STATUS at the end (DONE 0x2 expected), ~0 on a timeout
__attribute__((noinline, noclone)) static uint32_t sock_traffic(uint32_t nd) {
  accel_wr64(SLOT, 0x08, DMA_SRC); accel_wr64(SLOT, 0x10, DMA_DST); accel_wr(SLOT, 0x18, nd); accel_wr(SLOT, 0x1C, ARG);
  accel_wr(SLOT, 0x00, 0x1);                                         // START, no interrupt
  const int late = accel_wait(SLOT, 0x04, 0x3, 0x2, POLL_MAX);      // DONE and not BUSY
  const uint32_t status = accel_rd(SLOT, 0x04) & 0x7;               // BUSY, DONE, ERR
  accel_wr(SLOT, 0x04, 0x2);                                         // clear DONE
  return late ? ~0u : status;
}
// one pass: A's window, then B's, each between two snapshots. noinline and noclone, and called from one call site,
// so that the warm-up's pass and the checked one run the very same instructions at the same stack depth
__attribute__((noinline, noclone)) static void pass(uint32_t nw, uint32_t nr, uint32_t nd, uint64_t salt) {
  minmax_reset();
  quiet();
  uint32_t bad = !snap(a_bef);
  const uint64_t s = core_traffic(nw, nr, salt);
  wait_cycles(SETTLE);
  bad += !snap(a_aft);
  quiet();
  bad += !snap(b_bef);
  const uint32_t status = sock_traffic(nd);
  wait_cycles(SETTLE);
  bad += !snap(b_aft);
  rd_sum = s;
  dma_status = status;
  dma_bad += status != 0x2;
  snap_bad += bad;
}

// the code the windows run into the (flushed) LLC, one load per 64-byte line: WARM_FN bytes from the entry of each
// window function and WARM_MAIN from main's, which calls them, wherever the linker put them; so that no instruction
// fetch in a window, even one down a wrong path (t_storm), is a DRAM read. The whole program (about 46 KB with the
// drivers the build links) would take about 0.8 ms of simulation after the flush.
int main(void);
static void warm(uintptr_t a, uintptr_t n) {
  uint64_t s = 0;
  for (uintptr_t p = a & ~63ul; p < a + n; p += 64) s += ld(p);
  __asm__ volatile("" :: "r"(s));
}
static void code_warm(void) {
  warm((uintptr_t)&pass, WARM_FN);
  warm((uintptr_t)&snap, WARM_FN);
  warm((uintptr_t)&core_traffic, WARM_FN);
  warm((uintptr_t)&sock_traffic, WARM_FN);
  warm((uintptr_t)&main, WARM_MAIN);
}

// every core but core 0 sleeps (harts 2 and up stay parked in the boot ROM unless an APMU counter overflow wakes them,
// which none of this test's counters raises): no DRAM traffic of its own
int thread_entry(int cid, int nc) {
  (void)nc;
  if (cid == CORE0) return 0;                                        // core 0 continues in main()
  soc_install_trap_guard();
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  soc_test_begin("t_spulat");
  if (REG32(DM + DM_ID) == DM_ID_VAL) REG32(DM + DM_CTRL) = 0;     // the DRAM timing model off: a wire
  const uint32_t llc_lo = REG32(LLC_START), llc_hi = REG32(LLC_END);
  const uint32_t id = accel_rd(SLOT, 0x20);
  apmu_setup();
  // this run's patterns, one salt step past the previous run's (read back from W_BASE), so that no data check can
  // pass on what an earlier run left in DRAM
  const uint64_t salt = (ld(W_BASE) ^ W_BASE ^ PAT_W0) + SALT_STEP;
  // A's loaded lines and B's source words: written, then written back to DRAM and dropped from the L1
  uint64_t want = 0;
  for (uint32_t i = 0; i < NR; i++) {
    const uint64_t a = R_BASE + (uint64_t)i * L1_LINE;
    st(a, a ^ salt ^ PAT_R);
    want += a ^ salt ^ PAT_R;
  }
  for (uint32_t i = 0; i < ND; i++) st(DMA_SRC + 8 * (uint64_t)i, (DMA_SRC + 8 * (uint64_t)i) ^ salt ^ PAT_D);
  __asm__ volatile("fence\n\tfence.i" ::: "memory");
  const int flush = llc_flush();                                     // the LLC empty: nothing below evicts a line
  code_warm();
  snap_bad = 0; dma_bad = 0; dma_status = 0; rd_sum = 0;
#pragma GCC unroll 1
  for (int k = 0; k < 2; k++) pass(k ? NW : NW0, k ? NR : NR0, k ? ND : ND0, salt);   // the warm-up, then the checked

  // the data the counted transfers moved, read after every window
  uint32_t wbad = 0, dbad = 0;
  for (uint32_t i = 0; i < NW; i++) {
    const uint64_t a = W_BASE + (uint64_t)i * L1_LINE;
    wbad += (ld(a) != (a ^ salt ^ PAT_W0)) + (ld(a + 8) != (a ^ salt ^ PAT_W1));
  }
  for (uint32_t i = 0; i < ND; i++) {
    const uint64_t a = DMA_SRC + 8 * (uint64_t)i;
    dbad += ld(DMA_DST + 8 * (uint64_t)i) != (a ^ salt ^ PAT_D) + ARG;
  }
  const uint32_t copy_cycles = accel_rd(SLOT, 0x24);                 // the engine's own count for the checked copy
  uint32_t da[NCTR], db[NCTR];                                       // the windows' counts
  for (int i = 0; i < NCTR; i++) {
    da[i] = (a_aft[i] - a_bef[i]) & 0x3FFFFFFFu;
    db[i] = (b_aft[i] - b_bef[i]) & 0x3FFFFFFFu;
  }
  printf("port %d source %d: %u/%u reads %u cy (%u-%u), %u/%u writes %u cy (%u-%u)\r\n", APMU_PORT_MEM_SPU,
         APMU_SRC_CORE(CORE0), da[C_RRQ], da[C_RRS], avg(da[C_RLAT], da[C_RRS]), a_aft[C_RMIN], a_aft[C_RMAX],
         da[C_WRQ], da[C_WRS], avg(da[C_WLAT], da[C_WRS]), a_aft[C_WMIN], a_aft[C_WMAX]);
  printf("port %d: %u/%u reads %u cy, %u/%u writes %u cy; port %d source %d: %u/%u reads %u cy, %u/%u writes %u cy; "
         "copy %u cy\r\n", APMU_PORT_ACCEL_SPU, db[C_SRQ], db[C_SRS], avg(db[C_SRLAT], db[C_SRS]), db[C_SWQ],
         db[C_SWS], avg(db[C_SWLAT], db[C_SWS]), APMU_PORT_MEM_SPU, APMU_SRC_ACCEL, db[C_MRQ], db[C_MRS],
         avg(db[C_MRLAT], db[C_MRS]), db[C_MWQ], db[C_MWS], avg(db[C_MWLAT], db[C_MWS]), copy_cycles);

  // ---- set-up
  CHECK(llc_lo == 0x80000000u && llc_hi == 0x80800000u && flush == 0, "LLC window 0x%x-0x%x, expected the reset one "
        "(0x%x must be outside it); LLC flush %s", llc_lo, llc_hi, (unsigned)AREA, flush ? "timed out" : "done");
  CHECK(id == EXAMPLE_ID, "socket slot %d: ID 0x%x, expected the example engine 0x%x", SLOT, id, EXAMPLE_ID);
  CHECK(snap_bad == 0, "%u of 8 counter snapshots did not settle in %d rounds", snap_bad, SNAP_ROUNDS);
  CHECK(dma_bad == 0, "socket: %u of 2 copies did not end with DONE and without ERR in %u polls (last STATUS 0x%x)",
        dma_bad, (unsigned)POLL_MAX, dma_status);
  // ---- A: core 0 on port 2N+1
  CHECK(da[C_RRQ] == NW + NR && da[C_RRS] == da[C_RRQ], "core %d: %u read requests and %u responses on port %d "
        "source %d, expected %d each (%d write-allocates, %d fills)", CORE0, da[C_RRQ], da[C_RRS], APMU_PORT_MEM_SPU,
        APMU_SRC_CORE(CORE0), NW + NR, NW, NR);
  CHECK(da[C_WRQ] == NW && da[C_WRS] == da[C_WRQ], "core %d: %u write requests and %u responses on port %d source "
        "%d, expected %d each (a write-back per stored line)", CORE0, da[C_WRQ], da[C_WRS], APMU_PORT_MEM_SPU,
        APMU_SRC_CORE(CORE0), NW);
  CHECK(da[C_TRQ] == da[C_RRQ] && da[C_TWQ] == da[C_WRQ] && da[C_SRQ] + da[C_SRS] + da[C_SWQ] + da[C_SWS] == 0,
        "core %d's window: port %d had %u reads and %u writes of every source (%u and %u of core %d), port %d %u "
        "events", CORE0, APMU_PORT_MEM_SPU, da[C_TRQ], da[C_TWQ], da[C_RRQ], da[C_WRQ], CORE0, APMU_PORT_ACCEL_SPU,
        da[C_SRQ] + da[C_SRS] + da[C_SWQ] + da[C_SWS]);
  CHECK(da[C_RRS] > 0 && da[C_RLAT] >= LAT_MIN * da[C_RRS] && da[C_RLAT] <= LAT_AVG_MAX * da[C_RRS],
        "core %d: read latency %u cycles over %u responses (%u each), expected %d to %d each", CORE0, da[C_RLAT],
        da[C_RRS], avg(da[C_RLAT], da[C_RRS]), LAT_MIN, LAT_AVG_MAX);
  CHECK(a_aft[C_RMIN] >= LAT_MIN && a_aft[C_RMIN] <= a_aft[C_RMAX] && a_aft[C_RMAX] <= LAT_EV_MAX,
        "core %d: single read latencies %u to %u cycles, expected %d to %d", CORE0, a_aft[C_RMIN], a_aft[C_RMAX],
        LAT_MIN, LAT_EV_MAX);
  CHECK(da[C_WRS] > 0 && da[C_WLAT] >= LAT_MIN * da[C_WRS] && da[C_WLAT] <= LAT_AVG_MAX * da[C_WRS],
        "core %d: write latency %u cycles over %u responses (%u each), expected %d to %d each (the slowdown alone "
        "holds a B 20)", CORE0, da[C_WLAT], da[C_WRS], avg(da[C_WLAT], da[C_WRS]), LAT_MIN, LAT_AVG_MAX);
  CHECK(a_aft[C_WMIN] >= LAT_MIN && a_aft[C_WMIN] <= a_aft[C_WMAX] && a_aft[C_WMAX] <= LAT_EV_MAX,
        "core %d: single write latencies %u to %u cycles, expected %d to %d", CORE0, a_aft[C_WMIN], a_aft[C_WMAX],
        LAT_MIN, LAT_EV_MAX);
  CHECK(rd_sum == want, "core %d: the loaded words add up to 0x%08x%08x, expected 0x%08x%08x", CORE0, H64(rd_sum),
        H64(want));
  CHECK(wbad == 0, "core %d: %u of %d stored words are not in DRAM after their write-backs", CORE0, wbad, 2 * NW);
  // ---- B: the socket's DMA on ports 2N+2 and 2N+1
  CHECK(db[C_SRQ] == ND && db[C_SRS] == ND && db[C_SWQ] == ND && db[C_SWS] == ND, "socket: port %d saw %u read "
        "requests, %u responses, %u write requests, %u responses, expected %d each", APMU_PORT_ACCEL_SPU, db[C_SRQ],
        db[C_SRS], db[C_SWQ], db[C_SWS], ND);
  CHECK(db[C_MRQ] == ND && db[C_MRS] == ND && db[C_MWQ] == ND && db[C_MWS] == ND, "socket: port %d source %d saw %u "
        "read requests, %u responses, %u write requests, %u responses, expected %d each", APMU_PORT_MEM_SPU,
        APMU_SRC_ACCEL, db[C_MRQ], db[C_MRS], db[C_MWQ], db[C_MWS], ND);
  CHECK(db[C_TRQ] == db[C_MRQ] && db[C_TWQ] == db[C_MWQ] && db[C_RRQ] + db[C_WRQ] == 0, "socket's window: port %d "
        "had %u reads and %u writes of every source (%u and %u of source %d), core %d %u", APMU_PORT_MEM_SPU,
        db[C_TRQ], db[C_TWQ], db[C_MRQ], db[C_MWQ], APMU_SRC_ACCEL, CORE0, db[C_RRQ] + db[C_WRQ]);
  CHECK(db[C_MRS] > 0 && db[C_MRLAT] >= LAT_MIN * db[C_MRS] && db[C_MRLAT] <= LAT_AVG_MAX * db[C_MRS],
        "socket: port %d read latency %u cycles over %u responses (%u each), expected %d to %d each",
        APMU_PORT_MEM_SPU, db[C_MRLAT], db[C_MRS], avg(db[C_MRLAT], db[C_MRS]), LAT_MIN, LAT_AVG_MAX);
  CHECK(db[C_MWS] > 0 && db[C_MWLAT] >= LAT_MIN * db[C_MWS] && db[C_MWLAT] <= LAT_AVG_MAX * db[C_MWS],
        "socket: port %d write latency %u cycles over %u responses (%u each), expected %d to %d each",
        APMU_PORT_MEM_SPU, db[C_MWLAT], db[C_MWS], avg(db[C_MWLAT], db[C_MWS]), LAT_MIN, LAT_AVG_MAX);
  CHECK(db[C_SRS] > 0 && db[C_SRS] == db[C_MRS] && db[C_SRLAT] >= db[C_MRLAT] + db[C_SRS] &&
        db[C_SRLAT] <= db[C_MRLAT] + CCU_MAX * db[C_SRS], "socket: port %d read latency %u cycles over %u responses, "
        "port %d %u over %u: expected 1 to %d more per transfer", APMU_PORT_ACCEL_SPU, db[C_SRLAT], db[C_SRS],
        APMU_PORT_MEM_SPU, db[C_MRLAT], db[C_MRS], CCU_MAX);
  CHECK(db[C_SWS] > 0 && db[C_SWS] == db[C_MWS] && db[C_SWLAT] >= db[C_SWS] &&
        db[C_SWLAT] <= (LAT_AVG_MAX + CCU_MAX) * db[C_SWS], "socket: port %d write latency %u cycles over %u "
        "responses (%u each), port %d %u over %u: expected 1 to %d each", APMU_PORT_ACCEL_SPU, db[C_SWLAT], db[C_SWS],
        avg(db[C_SWLAT], db[C_SWS]), APMU_PORT_MEM_SPU, db[C_MWLAT], db[C_MWS], LAT_AVG_MAX + CCU_MAX);
  CHECK(dbad == 0, "socket: %u of %d copied words wrong", dbad, ND);
  return soc_test_end();
}
