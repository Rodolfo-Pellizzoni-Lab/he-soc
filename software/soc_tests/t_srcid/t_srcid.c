// t_srcid: the source every DRAM request is credited to. The APMU's SPU on the LLC memory port (port 9) gives each
// request a source (hardware/include/ariane_soc_pkg.sv, ariane_axi_soc::mem_src): 0-3 the cores and 4 the DMA port of
// the accelerator socket and the Ethernet DMA, which the coherence unit writes into the AXI user field, then one per
// other crossbar master; a response counts for the source of its request. (The ID remapper behind the coherence unit
// also puts the source's low bits into the AXI ID, for the LLC's per-source way masks.)
// One source at a time makes DRAM traffic while the cores not involved wait in a barrier in the uncached on-chip SRAM
// (no DRAM traffic), and the port-9 counters of request and response events filtered by source must credit all of it
// to that source:
//   A. core c, LLC refills: 32 lines of LLC-cached DRAM nobody touched before (L1 and LLC misses: shareable reads
//      through the CCU FSM, 64-byte refills): exactly 32 reads
//   B. core c, DRAM outside the LLC window (passed through the LLC): 16 lines written in one L1 set, then 16 more read
//      in it: exactly 32 reads (16 write-allocates, 16 fills) and 8 to 24 write-backs (the CCU's non-shareable path)
//   D. the accelerator socket's DMA (slot 0, the example accelerator, started by core 0): 16 words copied outside the
//      LLC window, a single-beat read and write each: exactly 16 of each, from source 4
// Every request gets its response, credited to the same source, and the sources add up to the port's totals. Only
// the cores and the socket touch DRAM here; writes the coherence unit issues itself and LLC evictions are not
// exercised. An instruction fetch that misses the LLC is a DRAM read of the core that runs it, also when it is fetched
// ahead: a first pass over other addresses runs all of the measured code and is not checked, every phase ends with a
// barrier that holds the cores until core 0 has taken its snapshot (so none runs ahead into code that has never run),
// and a snapshot is read until two reads in a row agree. Main before the ID-remapper fix (and the October bitstreams) credits the cores' reads to source 2
// and their write-backs by core parity; with only that fix the DMA port still counts as core 0.
#include "soc_test.h"
#include "accel.h"

#define NC        4
#define SRC_DMA   4              // source of the DMA port (ariane_soc::CcuDmaPort)
#define NSRC      5
#define LLC_BASE  0x80400000UL   // LLC-cached DRAM not used by the program (the LLC caches 0x8000_0000-0x807F_FFFF)
#define BYP_BASE  0x81000000UL   // DRAM outside the LLC window: the LLC passes the requests through
#define DMA_BASE  0x81800000UL   // the same, for the accelerator's buffers
#define PASS_STEP 0x100000UL
#define CORE_STEP 0x40000UL
#define L1_STEP   0x800UL        // 16 KB L1, 8 ways of 16-byte lines: lines 2 KB apart share an L1 set
#define NA        32             // A: lines read
#define NW        16             // B: lines written, then as many read
#define ND        16             // D: words copied
#define SLOT      0
#define ARG       7u
#define SETTLE    1000           // cycles for write-backs and counter updates to land before a snapshot
#define SNAP_ROUNDS 8

// APMU counters from 2 on (0 and 1 wake cores 2 and 3), port 9: for each SPU event (1 read request, 2 write request,
// 3 read response, 4 write response) one counter per source 0..NSRC-1, then one for every source
#define EV(ev, src) (0x9F0F0Fu | ((unsigned)(src) << 12) | ((unsigned)(ev) << 4))
#define EV_ALL(ev)  (0x9F000Fu | ((unsigned)(ev) << 4))
#define NEV         4
#define CTR0        2
#define NCTR        (NEV * (NSRC + 1))
#define CTR(e, s)   ((e) * (NSRC + 1) + (s))     // event e = 0..3, source s (NSRC: every source)
#define RD_REQ 0
#define WR_REQ 1
#define RD_RES 2
#define WR_RES 3

// phases: core c's A and B at 2c and 2c+1, then D
#define NPH       (2 * NC + 1)
#define PH_DMA    (2 * NC)

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }
static inline void     st(uint64_t a, uint64_t v) { *(volatile uint64_t *)a = v; }

SOC_SRAM static volatile uint32_t delta[NPH][NCTR];   // [phase][counter], measured pass
SOC_SRAM static volatile uint32_t snap_bad, dma_timeout;

static void ctr_setup(void) {
  for (int e = 0; e < NEV; e++)
    for (int s = 0; s <= NSRC; s++) {
      int i = CTR0 + CTR(e, s);
      REG32(EVENT_SEL_BASE_ADDR  + i * COUNTER_BUNDLE_SIZE) = s < NSRC ? EV(e + 1, s) : EV_ALL(e + 1);
      REG32(EVENT_INFO_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
      REG32(COUNTER_BASE_ADDR    + i * COUNTER_BUNDLE_SIZE) = 0;
    }
}

// every counter at one moment: read them all until two reads in a row agree; returns 0 if they did not settle
static int ctr_snap(uint32_t *v) {
  uint32_t w[NCTR];
  int same, n = 0;
#pragma GCC unroll 1
  do {
    for (int i = 0; i < NCTR; i++) v[i] = REG32(COUNTER_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    for (int i = 0; i < NCTR; i++) w[i] = REG32(COUNTER_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    same = 1;
    for (int i = 0; i < NCTR; i++) same &= v[i] == w[i];
  } while (!same && ++n < SNAP_ROUNDS);
  return same;
}

static void traffic(int pass, int p) {
  uint64_t s = 0;
  if (p == PH_DMA) {
    uint64_t b = DMA_BASE + pass * PASS_STEP;
    accel_wr64(SLOT, 0x08, b); accel_wr64(SLOT, 0x10, b + 0x10000); accel_wr(SLOT, 0x18, ND); accel_wr(SLOT, 0x1C, ARG);
    accel_wr(SLOT, 0x00, 0x1);
    if (accel_wait(SLOT, 0x04, 0x3, 0x2, 100000) != 0) dma_timeout++;
    accel_wr(SLOT, 0x04, 0x2);
  } else if (p % 2 == 0) {
    uint64_t b = LLC_BASE + pass * PASS_STEP + (p / 2) * CORE_STEP;
    for (int i = 0; i < NA; i++) s += ld(b + i * 64);
  } else {
    uint64_t b = BYP_BASE + pass * PASS_STEP + (p / 2) * CORE_STEP;
    for (int i = 0; i < NW; i++) st(b + i * L1_STEP, i);
    for (int i = 0; i < NW; i++) s += ld(b + (NW + i) * L1_STEP);
  }
  __asm__ volatile("fence rw, rw" ::: "memory");
  __asm__ volatile("" :: "r"(s));
}

// every core runs the same schedule; core 0 takes the counter snapshots around each phase and drives D
static void run(int cid) {
  uint32_t before[NCTR], after[NCTR];
  int round = 1;
  for (int pass = 0; pass < 2; pass++)
    for (int p = 0; p < NPH; p++) {
      int ok = 1;
      if (cid == 0) ok &= ctr_snap(before);
      soc_barrier(NC, round++);
      if (cid == (p == PH_DMA ? 0 : p / 2)) traffic(pass, p);
      soc_barrier(NC, round++);
      if (cid == 0) {
        uint64_t t = soc_cycles();
        while (soc_cycles() - t < SETTLE) ;
        ok &= ctr_snap(after);
        for (int i = 0; i < NCTR; i++) delta[p][i] = after[i] - before[i];   // the measured pass overwrites
        if (pass && !ok) snap_bad++;
      }
      soc_barrier(NC, round++);
    }
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_srcid");
    ctr_setup();
    soc_wake_all();
    return 0;                       // core 0 continues in main()
  }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  static const char *what[3] = {"LLC refills", "outside the LLC window", "socket DMA outside the LLC window"};
  run(0);
  CHECK(snap_bad == 0, "%u counter snapshots did not settle in %d rounds", snap_bad, SNAP_ROUNDS);
  CHECK(dma_timeout == 0, "the accelerator did not finish (%u times)", dma_timeout);
  for (int p = 0; p < NPH; p++) {
    volatile uint32_t *d = delta[p];
    int src = p == PH_DMA ? SRC_DMA : p / 2, k = p == PH_DMA ? 2 : p % 2;
    uint32_t rd = d[CTR(RD_REQ, src)], wr = d[CTR(WR_REQ, src)], other = 0;
    printf("source %d, %s: read requests by source 0-4 %u %u %u %u %u, write requests %u %u %u %u %u, "
           "responses %u read %u write\r\n", src, what[k], d[CTR(RD_REQ, 0)], d[CTR(RD_REQ, 1)], d[CTR(RD_REQ, 2)],
           d[CTR(RD_REQ, 3)], d[CTR(RD_REQ, 4)], d[CTR(WR_REQ, 0)], d[CTR(WR_REQ, 1)], d[CTR(WR_REQ, 2)],
           d[CTR(WR_REQ, 3)], d[CTR(WR_REQ, 4)], d[CTR(RD_RES, src)], d[CTR(WR_RES, src)]);
    if (k == 0) CHECK(rd == NA, "source %d, %s: %u reads credited to it, expected %d", src, what[k], rd, NA);
    if (k == 1) {
      CHECK(rd == 2 * NW, "source %d, %s: %u reads credited to it, expected %d", src, what[k], rd, 2 * NW);
      CHECK(wr >= NW / 2 && wr <= NW + NW / 2, "source %d, %s: %u write-backs credited to it, expected %d to %d", src,
            what[k], wr, NW / 2, NW + NW / 2);
    }
    if (k == 2) CHECK(rd == ND && wr == ND, "source %d, %s: %u reads and %u writes, expected %d each", src, what[k], rd,
                      wr, ND);
    for (int s = 0; s < NSRC; s++)
      if (s != src) for (int e = 0; e < NEV; e++) other += d[CTR(e, s)];
    CHECK(other == 0, "source %d, %s: %u events credited to other sources", src, what[k], other);
    CHECK(d[CTR(RD_RES, src)] == rd && d[CTR(WR_RES, src)] == wr,
          "source %d, %s: %u of %u reads and %u of %u writes answered", src, what[k], d[CTR(RD_RES, src)], rd,
          d[CTR(WR_RES, src)], wr);
    int sums_ok = 1;
    for (int e = 0; e < NEV; e++) {
      uint32_t sum = 0;
      for (int s = 0; s < NSRC; s++) sum += d[CTR(e, s)];
      sums_ok &= sum == d[CTR(e, NSRC)];
    }
    CHECK(sums_ok, "source %d, %s: sources 0-4 do not add up to the port's totals (reads %u of %u)", src, what[k],
          d[CTR(RD_REQ, 0)] + d[CTR(RD_REQ, 1)] + d[CTR(RD_REQ, 2)] + d[CTR(RD_REQ, 3)] + d[CTR(RD_REQ, 4)],
          d[CTR(RD_REQ, NSRC)]);
  }
  return soc_test_end();
}
