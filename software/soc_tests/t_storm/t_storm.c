// t_storm: every master of the SoC making DRAM traffic at once, and every APMU event source counting it, with
// N = SOC_NUM_CORES cores (built with -DSOC_NUM_CORES=<n> for an n-core SoC).
// In each round's window all cores, the accelerator socket's two slots (example copying LEN0 words, crc32 reading
// LEN1 bytes) and the Ethernet DMA (F frames through the MAC's loopback) run together, while one APMU counter each
// counts: every core's EVU (armed by the APMU's PE), every core's SPU (port N+1+c: what leaves its L1), the socket's
// SPU (port 2N+2), and the LLC memory port's SPU (port 2N+1) by source: each core, the socket, the Ethernet, two that
// must stay idle (the debug module, the APMU) and all of them together. The PE samples every counter while the traffic
// runs and once after it; the host checks the PE's view against its own snapshot.
// A round counts one SPU event: read requests, write requests, read responses, write responses, each with the DRAM
// timing model off and then on (1 GHz target settings). Round 0 warms up and is not checked. The traffic is the same
// in every round: per core c,
//   C. R_LINES reads of LLC-cached lines (one word per 64-byte line) holding the round's pattern: the LLC is flushed
//      before the window, so each is one L1 refill and one LLC refill
//   P. K_SETS x W_LINES stores outside the LLC window, W_LINES lines in each of K_SETS L1 sets that hold nothing else
//      (the D$ has 8 ways): K x W write-allocating reads, and K x (W - 8) write-backs, as every store into a set full
//      of dirty lines writes one back (the last 8 per set go at the next fence.i, after the window)
//   E. core N-1 only: LE_LINES reads, with RCID 15, of lines whose LLC sets hold in way 15 a dirty line core N-2 wrote
//      with RCID 14 before the window; RCIDs 14 and 15 may allocate only in way 15, and nothing else may. Every refill
//      evicts that line, and the eviction is credited to the source of the miss that caused it: core N-1
//   core 0 also drives the socket and the Ethernet (MMIO only)
// Exact: the memory port's count per source, the socket's port (= the memory port's source N), the Ethernet's 19
// reads and 13 writes per 64-byte frame, nothing from the idle sources, the sum over the sources = the port's total,
// responses = requests, model on = model off, the timing model's burst counters = the memory port's total, the PE's
// final sample = the host's snapshot (bar core 0's own SPU: its fetches after the PE's sample), every word of data.
// EVU vs SPU: the PE arms two slots of every core's EVU, D$ refills (event 0x02) and I$ refills (0x01). In the read
// rounds the counters take every core's I$ refills (and core 0's D$ refills too), and a core's SPU read requests
// (responses) must be C + P + E's D$ refills plus them, exactly; in the write rounds they take every core's D$
// refills, which must be C + P + E's. Each round runs its steps twice through the same code (the warm-up's pass on
// dummy lines, then the real one), and the whole program is loaded into the LLC after the round's flush, so no code
// line is a DRAM read in the window; a core's front end may still fetch a line its pass does not run (down a wrong
// path while its loads miss), which the I$ refills count. On the board the D$ refills and the core SPUs' write-backs
// may run over by up to SLACK (a stack line that C's 512 lines push out of the L1 is a write-back, and a refill when it
// comes back); in simulation they are exact.
#include "soc_test.h"
#include "accel.h"
#include "xeth.h"

#define NC         SOC_NUM_CORES
#define CA         (NC - 2)                // E: the core whose dirty LLC lines are evicted
#define CB         (NC - 1)                // E: the core whose misses evict them
#define RCID_A     14
#define RCID_B     15
#define WAY_E      15                      // the one LLC way RCIDs 14 and 15 allocate in, and nothing else
#define MASK_E     (1u << WAY_E)
#define MASK_REST  (0xFFFFu & ~MASK_E)
#if NC < 3
#error "t_storm needs three cores or more"
#endif

#ifdef FPGA_EMULATION                      // the board: bigger rounds, repeated
#define SZ(sim, fpga) (fpga)
#else
#define SZ(sim, fpga) (sim)
#endif
#ifndef R_LINES
#define R_LINES    SZ(16, 512)
#endif
#ifndef K_SETS
#define K_SETS     SZ(1, 8)
#endif
#ifndef W_LINES
#define W_LINES    SZ(12, 32)
#endif
#ifndef LE_LINES
#define LE_LINES   SZ(8, 512)
#endif
#ifndef LEN0
#define LEN0       SZ(16, 2048)            // words the example slot copies
#endif
#ifndef LEN1
#define LEN1       SZ(64, 16384)           // bytes the crc32 slot reads
#endif
#ifndef F_FRAMES
#define F_FRAMES   SZ(1, 8)
#endif
#ifndef REPEAT
#define REPEAT     SZ(1, 8)                // times the 8 checked rounds run
#endif
#define PE_PERIOD  SZ(2000, 20000)         // cycles between the PE's samples
#define NQ         8                       // checked round kinds: 4 events x model off / on
#define NROUNDS    (1 + NQ * REPEAT)
#define SETTLE     10000                   // cycles for write-backs and counter updates to land
#define SLACK      SZ(0, 8)
#define SNAP_ROUNDS 8
#define POLL_MAX   SZ(20000, 2000000)        // MMIO polls before a DMA counts as failed
#define CYC_MAX    SZ(200000ULL, 500000000ULL)    // cycles before the PE or an LLC flush counts as failed

// DRAM: C, E and the warm-up's lines inside the LLC window (0x8000_0000-0x807F_FFFF), P and the DMA's outside it
#define C_BASE     0x80200000UL            // C: core c's lines at C_BASE + c * C_STEP, 64 bytes apart
#define C_STEP     0x8000UL
#define EA_BASE    0x80400000UL            // E: core N-2's lines, LLC sets 0 .. LE-1
#define EB_BASE    0x80500000UL            // E: core N-1's lines, the same sets (1 MB apart)
#define SCR_BASE   0x80600000UL            // the warm-up's lines: core c's at SCR_BASE + c * 0x1000
#define SCR_E      (SCR_BASE + 1000 * 64)  // the warm-up's E line: LLC set 1000, none of E's
#define P_BASE     0x81000000UL            // P: core c's lines at P_BASE + c * P_STEP + set * 16 + j * L1_STEP
#define P_STEP     0x20000UL
#define L1_STEP    0x800UL                 // 16 KB D$, 8 ways of 16-byte lines: lines 2 KB apart share a set
#define ACC_SRC    0x81800000UL            // the socket: example's source and destination, crc32's source
#define ACC_DST    0x81880000UL
#define CRC_SRC    0x81900000UL
#define ACC_DRY    0x81980000UL            // the warm-up's DMA buffers
#define ETH_BASE   0x81C00000UL            // the Ethernet: F_FRAMES + 1 areas (0: the warm-up's frame)
#define ETH_STEP   0x1000UL
#define ETH_LEN    64                      // frame bytes (a multiple of 8, no padding): 19 reads and 13 writes
#define ETH_RD     (7 + ETH_LEN / 8 + 4)
#define ETH_WR     (1 + ETH_LEN / 8 + 4)
#define ARG        7u
#if C_BASE + NC * C_STEP > EA_BASE || R_LINES * 64 > C_STEP || LE_LINES >= 1000 || W_LINES * L1_STEP > P_STEP || \
    K_SETS > 8 || W_LINES <= 8 || LEN0 * 8 > ACC_DST - ACC_SRC || (F_FRAMES + 1) * ETH_STEP > 0x100000 || LEN1 % 8
#error "t_storm: the sizes do not fit the layout"
#endif

// APMU counters
#define C_EVU(c)   (c)                     // core c's EVU: I$ refills (slot 1) in read rounds, D$ refills (slot 0) in write rounds
#define C_SPU(c)   (NC + (c))              // core c's SPU (port N+1+c)
#define C_ACC      (2 * NC)                // the socket's SPU (port 2N+2)
#define C_MEM(s)   (2 * NC + 1 + (s))      // the memory port (2N+1), source s: 0 .. N-1 the cores, N the socket, N+1 the Ethernet
#define C_TOT      (3 * NC + 3)            // the memory port, every source
#define C_EVU0     (3 * NC + 4)            // core 0's EVU: D$ refills in read rounds, I$ refills in write rounds
#define C_DBG      (3 * NC + 5)            // the memory port, the debug module's source
#define C_PMU      (3 * NC + 6)            // the memory port, the APMU's source
#define NCTR       (3 * NC + 7)
#define S_DMRD     NCTR                    // in the snapshots: the timing model's read and write bursts
#define S_DMWR     (NCTR + 1)
#define NSNAP      (NCTR + 2)
#if NCTR > NUM_COUNTER
#error "t_storm needs more counters than the APMU has"
#endif
#define EVU_DMISS  0x02
#define EVU_IMISS  0x01

// the DRAM timing model and the LLC (SoC control, CBQRI capacity controller)
#define DM         0x1A106100UL
#define DM_CTRL    0x00
#define DM_LAT_RD  0x04
#define DM_LAT_WR  0x08
#define DM_OCC16   0x0C
#define DM_RDC     0x10
#define DM_WRC     0x14
#define LLC_START  0x1A106018UL
#define LLC_END    0x1A10601CUL
#define LLC_FLUSH  0x10401008UL
#define CC         0x10401800UL
#define CC_ALLOC   0x18
#define CC_MASK    0x20
#define OP_CONFIG  1
#define SRMCFG_W(x) __asm__ volatile("csrw 0x181, %0" :: "r"((uint64_t)(x)) : "memory")

// the PE's program and its parameters (pe_fw.S)
#include "pe_fw.h"
#define PE_ACK     (DSPM_BASE_ADDR + 0x000)
#define PE_STOP    (DSPM_BASE_ADDR + 0x004)
#define PE_DONE    (DSPM_BASE_ADDR + 0x008)
#define PE_COUNT   (DSPM_BASE_ADDR + 0x00C)
#define PE_K       (DSPM_BASE_ADDR + 0x010)
#define PE_T       (DSPM_BASE_ADDR + 0x014)
#define PE_RINGN   (DSPM_BASE_ADDR + 0x018)
#define PE_NEVU    (DSPM_BASE_ADDR + 0x01C)
#define PE_MAGIC   (DSPM_BASE_ADDR + 0x020)
#define PE_ERRS    (DSPM_BASE_ADDR + 0x024)
#define PE_EVU     (DSPM_BASE_ADDR + 0x040)
#define PE_FINAL   (DSPM_BASE_ADDR + 0x200)
#define PE_RING    (DSPM_BASE_ADDR + 0x400)
#define RING_N     SZ(8, 32)

// one core's window: what traffic() and core 0's DMA part read (in the uncached SRAM, so that reading it is no
// traffic); [0] the window's, [1] the warm-up's, which runs the same code on dummy lines
typedef struct {
  uint64_t cb, pb, eb, sets, pc, pp, pe, rcid_e;
  uint64_t acc_src, acc_dst, crc_src;
  uint32_t nr, nk, nw, ne, len0, len1, f0, nf;
} job_t;
SOC_SRAM static volatile job_t jobs[2][NC];
SOC_SRAM static volatile uint32_t sets_ok[NC], data_bad[NC], wbad[NC];
SOC_SRAM static volatile uint32_t before[NSNAP], after[NSNAP], tmp[NSNAP];
SOC_SRAM static volatile uint32_t delta[NQ][NSNAP];
SOC_SRAM static volatile uint32_t snap_bad, flush_bad, dma_bad, eth_bad, pe_bad, crc_bad, acc_bad, eth_data_bad;

typedef struct {
  xeth_bd_t tx, rx;
  uint8_t   txf[ETH_LEN]       __attribute__((aligned(64)));
  uint8_t   rxf[XETH_BUF_SIZE] __attribute__((aligned(64)));
} eth_area_t;
#define ETH_AREA(k) ((volatile eth_area_t *)(ETH_BASE + (unsigned long)(k) * ETH_STEP))
#define ETH_LO(p)   ((uint32_t)(uintptr_t)(p))
#define XDMA_SR_IOC 0x1000u
static xeth_t eth;
static int eth_up;                         // eth_bringup()'s result; no frames unless 0
#define NFRAMES (eth_up ? 0 : F_FRAMES)
static const uint8_t eth_mac[6] = { 0x00, 0x0A, 0x35, 0x01, 0x02, 0x03 };

static int round_prints;   // failures printed in this round
#define RCHECK(cond, ...) do {                                                  \
    soc_checks++;                                                               \
    if (!(cond)) {                                                              \
      soc_fails++;                                                              \
      if (round_prints++ < 6) { printf("CHECK FAIL %d ", __LINE__); printf(__VA_ARGS__); printf("\r\n"); } \
    }                                                                           \
  } while (0)

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }
static inline void st(uint64_t a, uint64_t v) { *(volatile uint64_t *)a = v; }
static inline void wait_cycles(uint64_t n) { uint64_t t = soc_cycles(); while (soc_cycles() - t < n) ; }
// the round's patterns: kind 1 C, 2 P, 3 E (core N-2's), 4 E (core N-1's), 5 the socket's source; word i = base ^ i * PSTEP
#define PSTEP 0x9E3779B97F4A7C15ULL
static inline uint64_t pat(unsigned kind, unsigned c, unsigned r) {
  return ((uint64_t)kind << 60) ^ ((uint64_t)c << 52) ^ ((uint64_t)r << 36) ^ 0x5A5A5A5AULL;
}
static inline uint8_t crc_byte(unsigned r, unsigned i) { return (uint8_t)(r * 13 + i * 7 + 1); }

// ---- the window: C, P and E of one core, from registers and its job only; returns C's and E's bad words
__attribute__((noinline)) static uint32_t traffic(volatile job_t *j) {
  const uint64_t cb = j->cb, pb = j->pb, eb = j->eb, sets = j->sets, pc = j->pc, pp = j->pp, pe = j->pe;
  const uint32_t nr = j->nr, nk = j->nk, nw = j->nw, ne = j->ne;
  const uint64_t rcid_e = j->rcid_e;
  uint32_t bad = 0;
  uint64_t want = pc;
  for (uint32_t i = 0; i < nr; i++, want += PSTEP) bad += ld(cb + (uint64_t)i * 64) != want;
  want = pp;
  for (uint32_t k = 0; k < nk; k++) {
    const uint64_t b = pb + ((sets >> (7 * k)) & 127) * 16;
    for (uint32_t w = 0; w < nw; w++, want += PSTEP) st(b + (uint64_t)w * L1_STEP, want);
  }
  if (ne) {
    SRMCFG_W(rcid_e);
    want = pe;
    for (uint32_t i = 0; i < ne; i++, want += PSTEP) bad += ld(eb + (uint64_t)i * 64) != want;
    SRMCFG_W(0);
  }
  __asm__ volatile("fence rw, rw" ::: "memory");
  return bad;
}

// ---- core 0's DMA part of the window: MMIO only (the DMA's buffers and descriptors are in no L1)
static void eth_send(unsigned k) {
  volatile eth_area_t *a = ETH_AREA(k);
  xdma_wr(XDMA_RX + XDMA_TAILDESC, ETH_LO(&a->rx));   // the RX DMA fetches its descriptor and waits for the frame
  xdma_wr(XDMA_TX + XDMA_TAILDESC, ETH_LO(&a->tx));   // the TX DMA fetches its descriptor and sends the frame
}
static int eth_wait(unsigned ch) {
  for (uint32_t i = 0; i < POLL_MAX; i++) {
    uint32_t sr = xdma_rd(ch + XDMA_SR);
    if (sr & XDMA_SR_ERR_MASK) return -1;
    if (sr & XDMA_SR_IOC) { xdma_wr(ch + XDMA_SR, XDMA_SR_IRQ_ALL); return 0; }
  }
  return -1;
}
__attribute__((noinline)) static uint32_t window(int cid, volatile job_t *j) {
  uint32_t bad, e = 0;
  if (cid == 0) {
    accel_wr64(0, 0x08, j->acc_src); accel_wr64(0, 0x10, j->acc_dst); accel_wr(0, 0x18, j->len0);
    accel_wr(0, 0x1C, ARG); accel_wr(0, 0x00, 0x1);
    accel_wr64(1, 0x08, j->crc_src); accel_wr(1, 0x10, j->len1); accel_wr(1, 0x00, 0x1);
    for (uint32_t f = j->f0; f < j->f0 + j->nf; f++) {
      eth_send(f);
      if (eth_wait(XDMA_TX) || eth_wait(XDMA_RX)) e |= 1;
    }
  }
  bad = traffic(j);
  if (cid == 0) {
    if (accel_wait(0, 0x04, 0x7, 0x2, POLL_MAX)) e |= 2;
    accel_wr(0, 0x04, 0x2);
    if (accel_wait(1, 0x04, 0x7, 0x2, POLL_MAX)) e |= 4;
    accel_wr(1, 0x04, 0x2);
    if (e & 1) eth_bad++;
    if (e & 6) dma_bad++;
  }
  return bad;
}

// ---- setup
static void ctr_set(int i, uint32_t sel) {
  REG32(EVENT_SEL_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;      // off first: a clear is held while the counter moves
  REG32(EVENT_INFO_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  REG32(EVENT_SEL_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = sel;
}
static void ctr_setup(unsigned ev) {   // ev: APMU_EV_RD_REQ .. APMU_EV_WR_RES
  const int rd = ev == APMU_EV_RD_REQ || ev == APMU_EV_RD_RES;
  for (int c = 0; c < NC; c++) {
    ctr_set(C_EVU(c), EVU_SLOT_SEL(c, rd ? 1 : 0));
    ctr_set(C_SPU(c), APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), ev));
  }
  ctr_set(C_ACC, APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, ev));
  for (int s = 0; s < NC + 2; s++) ctr_set(C_MEM(s), MEM_SEL(ev, s));
  ctr_set(C_TOT, APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, ev));
  ctr_set(C_EVU0, EVU_SLOT_SEL(0, rd ? 0 : 1));
  ctr_set(C_DBG, MEM_SEL(ev, APMU_SRC_XBAR(1)));
  ctr_set(C_PMU, MEM_SEL(ev, APMU_SRC_XBAR(9)));
}
// every counter (and the model's two) at one moment: read them all until two reads in a row agree
static int snap(volatile uint32_t *v) {
  int same, n = 0;
#pragma GCC unroll 1
  do {
    for (int i = 0; i < NCTR; i++) v[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    v[S_DMRD] = REG32(DM + DM_RDC); v[S_DMWR] = REG32(DM + DM_WRC);
    for (int i = 0; i < NCTR; i++) tmp[i] = REG32(COUNTER_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFu;
    tmp[S_DMRD] = REG32(DM + DM_RDC); tmp[S_DMWR] = REG32(DM + DM_WRC);
    same = 1;
    for (int i = 0; i < NSNAP; i++) same &= v[i] == tmp[i];
  } while (!same && ++n < SNAP_ROUNDS);
  return same;
}
static unsigned cc_op(unsigned op, unsigned at, unsigned rcid) {
  REG32(CC + CC_ALLOC) = op | (at << 5) | (rcid << 8);
  return REG32(CC + CC_ALLOC + 4) & 0x7F;
}
static void set_limit(unsigned rcid, unsigned at, uint32_t mask) {
  REG32(CC + CC_MASK) = mask;
  unsigned s = cc_op(OP_CONFIG, at, rcid);
  CHECK(s == 1, "CBQRI CONFIG_LIMIT rcid %d at %d mask 0x%x: status %d", rcid, at, mask, s);
}
static int llc_flush(void) {
  REG32(LLC_FLUSH) = 0xFFFF;
  uint64_t t0 = soc_cycles();
  while (REG32(LLC_FLUSH) != 0) if (soc_cycles() - t0 > CYC_MAX) return -1;
  return 0;
}
static int eth_bringup(void) {   // as t_srcid: DMA reset, both channels on area 0, the MAC, the loopback
  if (xdma_reset(XDMA_TX) || xdma_reset(XDMA_RX)) return 1;
  xdma_wr(XDMA_TX + XDMA_CURDESC, ETH_LO(&ETH_AREA(0)->tx));
  xdma_wr(XDMA_TX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xdma_wr(XDMA_RX + XDMA_CURDESC, ETH_LO(&ETH_AREA(0)->rx));
  xdma_wr(XDMA_RX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xeth_mac_init(&eth, eth_mac, 1);
  if (eth.phy_addr < 0) return 2;
#ifdef FPGA_EMULATION
  if (xeth_phy_init(&eth)) return 3;
  if (eth.pcs_addr < 0) xeth_pcs_probe(&eth);
#endif
  if (eth.pcs_addr < 0) return 4;
#ifdef FPGA_EMULATION
  { uint64_t t0 = soc_cycles(); while (!xeth_phy_link(&eth) && soc_cycles() - t0 < 50000000ULL * 10) for (volatile int d = 0; d < 100000; d++); }
  if (xeth_pcs_loopback(&eth, 1)) return 5;
  for (volatile int d = 0; d < 2000000; d++);
#endif
  return 0;
}

// ---- a round's steps (outside the window)
static int p_set_ok(int cid, int s) { return (sets_ok[cid] >> (s / 4)) & 1; }   // a P candidate (s % 4 == 2) far from the stack
// the round's data and both jobs of core cid; core 0 also the DMA's source and destination and the Ethernet's frames
static void init_round(int cid, unsigned r) {
  volatile job_t *j = &jobs[0][cid], *d = &jobs[1][cid];
  uint64_t sets = 0;
  for (int s = 2, k = 0; s < 128 && k < K_SETS; s += 4) if (p_set_ok(cid, s)) sets |= (uint64_t)s << (7 * k++);
  j->cb = C_BASE + cid * C_STEP; j->nr = R_LINES; j->pc = pat(1, cid, r);
  j->pb = P_BASE + cid * P_STEP; j->sets = sets; j->nk = K_SETS; j->nw = W_LINES; j->pp = pat(2, cid, r);
  j->eb = EB_BASE; j->ne = cid == CB ? LE_LINES : 0; j->pe = pat(4, CB, r); j->rcid_e = RCID_B;
  j->acc_src = ACC_SRC; j->acc_dst = ACC_DST; j->crc_src = CRC_SRC; j->len0 = LEN0; j->len1 = LEN1;
  j->f0 = 1; j->nf = NFRAMES;
  // the warm-up: one line of each kind, in an L1 set none of P's (C: set 0 mod 4, P: set 1), E in LLC set 1000
  d->cb = SCR_BASE + cid * 0x1000; d->nr = 1; d->pc = 0;
  d->pb = SCR_BASE + cid * 0x1000; d->sets = 1; d->nk = 1; d->nw = 1; d->pp = 0;
  d->eb = SCR_E; d->ne = cid == CB ? 1 : 0; d->pe = 0; d->rcid_e = RCID_B;
  d->acc_src = ACC_DRY; d->acc_dst = ACC_DRY + 0x1000; d->crc_src = ACC_DRY + 0x2000; d->len0 = 1; d->len1 = 8;
  d->f0 = 0; d->nf = NFRAMES ? 1 : 0;
  uint64_t v = pat(1, cid, r);
  for (uint32_t i = 0; i < R_LINES; i++, v += PSTEP) st(j->cb + i * 64, v);
  st(d->cb, 0);
  if (cid == CB) st(d->eb, 0);
  if (cid == CB) { v = pat(4, CB, r); for (uint32_t i = 0; i < LE_LINES; i++, v += PSTEP) st(EB_BASE + i * 64, v); }
  if (cid == 0) {
    v = pat(5, 0, r);
    for (uint32_t i = 0; i < LEN0; i++, v += PSTEP) { st(ACC_SRC + i * 8, v); st(ACC_DST + i * 8, 0); }
    for (uint32_t i = 0; i < LEN1; i++) ((volatile uint8_t *)CRC_SRC)[i] = crc_byte(r, i);
    for (unsigned k = 0; k <= F_FRAMES; k++) {
      volatile eth_area_t *a = ETH_AREA(k), *n = ETH_AREA((k + 1) % (F_FRAMES + 1));
      for (int i = 0; i < 16; i++) { ((volatile uint32_t *)&a->tx)[i] = 0; ((volatile uint32_t *)&a->rx)[i] = 0; }
      a->tx.next = ETH_LO(&n->tx); a->tx.buf = ETH_LO(a->txf); a->tx.ctrl = ETH_LEN | XBD_CTRL_SOF | XBD_CTRL_EOF;
      a->rx.next = ETH_LO(&n->rx); a->rx.buf = ETH_LO(a->rxf); a->rx.ctrl = XETH_BUF_SIZE;
      for (int i = 0; i < ETH_LEN; i++) {   // broadcast from our MAC address, IEEE local experimental ethertype, a pattern
        a->txf[i] = i < 6 ? 0xFF : i < 12 ? eth_mac[i - 6] : i == 12 ? 0x88 : i == 13 ? 0xB5 : (uint8_t)(r * 31 + k * 17 + i * 7);
        a->rxf[i] = 0xEE;
      }
    }
  }
}
// after the round's LLC flush: the program (code and constants) back into the LLC, a slice per core, one load per
// 64-byte line (L1 sets 0 mod 4: none of P's), so that no fetch in the window, even one down a wrong path, reads DRAM
extern char _start[], __cluster_code_end[];
static void code_warm(int cid) {
  const uintptr_t a0 = (uintptr_t)_start & ~63ul, a1 = ((uintptr_t)__cluster_code_end + 63) & ~63ul;
  const uintptr_t n = (a1 - a0) / 64, from = a0 + 64 * (n * cid / NC), to = a0 + 64 * (n * (cid + 1) / NC);
  uint64_t s = 0;
  for (uintptr_t a = from; a < to; a += 64) s += ld(a);
  __asm__ volatile("" :: "r"(s));
}
// E: core N-2's lines, dirty in the LLC's way 15 (the only way RCID 14 allocates in), in no L1
static void evict_setup(unsigned r) {
  SRMCFG_W(RCID_A);
  uint64_t v = pat(3, CA, r);
  for (uint32_t i = 0; i < LE_LINES; i++, v += PSTEP) st(EA_BASE + i * 64, v);
  __asm__ volatile("fence\n\tfence.i" ::: "memory");
  SRMCFG_W(0);
}
#ifndef DM_ON_LAT_RD                       // the model's settings in the model-on rounds (default: the 1 GHz targets)
#define DM_ON_LAT_RD 80
#endif
#ifndef DM_ON_LAT_WR
#define DM_ON_LAT_WR 80
#endif
#ifndef DM_ON_OCC16
#define DM_ON_OCC16 20
#endif
static void dm_set(int on) {
  REG32(DM + DM_CTRL) = 0;
  if (on) {
    REG32(DM + DM_LAT_RD) = DM_ON_LAT_RD; REG32(DM + DM_LAT_WR) = DM_ON_LAT_WR; REG32(DM + DM_OCC16) = DM_ON_OCC16;
    REG32(DM + DM_CTRL) = 3;
  }
}
// core 0, before the window: the round's counters and model, the PE (it arms the EVUs), the first snapshot
static void open_round(unsigned r, unsigned ev, int model) {
  ctr_setup(ev);
  dm_set(model);
  REG32(PMC_STATUS_ADDR) = 1;                                   // hold the PE: its release restarts it
  REG32(PE_ACK) = 0; REG32(PE_STOP) = 0; REG32(PE_DONE) = 0; REG32(PE_COUNT) = 0; REG32(PE_MAGIC) = 0;
  REG32(PE_ERRS) = ~0u;
  REG32(PE_K) = NCTR; REG32(PE_T) = PE_PERIOD; REG32(PE_RINGN) = RING_N; REG32(PE_NEVU) = 2 * NC;
  for (int c = 0; c < NC; c++) {
    REG32(PE_EVU + 16 * c + 0) = EVU_EID_REG(c, 0); REG32(PE_EVU + 16 * c + 4)  = EVU_DMISS;
    REG32(PE_EVU + 16 * c + 8) = EVU_EID_REG(c, 1); REG32(PE_EVU + 16 * c + 12) = EVU_IMISS;
  }
  __asm__ volatile("fence" ::: "memory");
  REG32(PMC_BOOT_ADDR) = ISPM_BASE_ADDR;
  REG32(PMC_STATUS_ADDR) = 0;
  uint64_t t0 = soc_cycles();
  while (REG32(PE_ACK) != 1 && soc_cycles() - t0 < CYC_MAX) ;
  if (REG32(PE_ACK) != 1 && r) pe_bad++;
  wait_cycles(SETTLE);
  if (!snap(before) && r) snap_bad++;
}
// the round's expectations, per source
static uint32_t ex_mem(int s, int rd) {
  if (s < NC) return rd ? R_LINES + K_SETS * W_LINES + (s == CB ? LE_LINES : 0) : K_SETS * (W_LINES - 8) + (s == CB ? LE_LINES : 0);
  if (s == NC) return rd ? LEN0 + LEN1 / 8 : LEN0;
  return NFRAMES * (rd ? ETH_RD : ETH_WR);
}
// core 0, after the window: the PE's last sample, the snapshot, the checks of this round
// (p = 1: the same steps on the warm-up's pass, which stops after the snapshot)
static void close_round(unsigned r, unsigned ev, int model, int p) {
  wait_cycles(SETTLE);
  REG32(PE_STOP) = 1;
  uint64_t t0 = soc_cycles();
  while (REG32(PE_DONE) != 1 && soc_cycles() - t0 < CYC_MAX) ;
  wait_cycles(SETTLE);
  int ok = snap(after);
  if (p || !r) return;
  round_prints = 0;
  if (!ok) snap_bad++;
  const unsigned q = (r - 1) % NQ;
  const int rd = ev == APMU_EV_RD_REQ || ev == APMU_EV_RD_RES, res = ev >= APMU_EV_RD_RES;
  // the window ends at the PE's final sample (EVUs disarmed, traffic drained, core 0 in a warm loop); the host's
  // snapshot comes after core 0 has run more code, whose I$ refills only its own SPU sees
  volatile uint32_t *d = delta[q];
  uint32_t fin_bad = 0, mono_bad = 0;
  for (int i = 0; i < NCTR; i++) {
    const uint32_t f = REG32(PE_FINAL + 4 + 4 * i) & 0x3FFFFFFFu;
    fin_bad += i == C_SPU(0) ? f > after[i] : f != after[i];
    d[i] = f - before[i];
  }
  d[S_DMRD] = after[S_DMRD] - before[S_DMRD]; d[S_DMWR] = after[S_DMWR] - before[S_DMWR];
  // the PE: booted, armed (every EVU register read back), sampled, stopped; its ring never goes down
  const uint32_t cnt = REG32(PE_COUNT), done = REG32(PE_DONE), magic = REG32(PE_MAGIC), errs = REG32(PE_ERRS);
  const uint32_t ns = cnt < RING_N ? cnt : RING_N, first = cnt < RING_N ? 0 : cnt % RING_N;
  for (uint32_t n = 1; n < ns; n++) {
    const uint64_t a = PE_RING + 4 * (NCTR + 1) * ((first + n - 1) % RING_N), b = PE_RING + 4 * (NCTR + 1) * ((first + n) % RING_N);
    for (int i = 0; i < NCTR; i++) mono_bad += (REG32(b + 4 + 4 * i) & 0x3FFFFFFFu) < (REG32(a + 4 + 4 * i) & 0x3FFFFFFFu);
  }
  RCHECK(magic == 0x5A5 && done == 1 && errs == 0 && cnt >= 1 && fin_bad == 0 && mono_bad == 0,
        "round %u: PE magic 0x%x done %u EVU read-back errors %u samples %u, %u counters differ from the host's, %u "
        "decreases", r, magic, done, errs, cnt, fin_bad, mono_bad);
  // the memory port: every source exact, the idle ones 0, the total their sum; the socket's port = its source
  uint32_t sum = d[C_DBG] + d[C_PMU];
  for (int s = 0; s < NC + 2; s++) {
    sum += d[C_MEM(s)];
    RCHECK(d[C_MEM(s)] == ex_mem(s, rd), "round %u ev %u: source %d: %u, expected %u", r, ev, s, d[C_MEM(s)], ex_mem(s, rd));
  }
  RCHECK(d[C_DBG] == 0 && d[C_PMU] == 0, "round %u ev %u: debug %u, APMU %u", r, ev, d[C_DBG], d[C_PMU]);
  RCHECK(d[C_TOT] == sum, "round %u ev %u: memory port %u, sources %u", r, ev, d[C_TOT], sum);
  RCHECK(d[C_ACC] == d[C_MEM(NC)], "round %u ev %u: socket port %u, memory port source %d %u", r, ev, d[C_ACC], NC,
        d[C_MEM(NC)]);
  if (model)
    RCHECK((rd ? d[S_DMRD] : d[S_DMWR]) == d[C_TOT], "round %u ev %u: timing model %u bursts, memory port %u", r, ev,
          rd ? d[S_DMRD] : d[S_DMWR], d[C_TOT]);
  // the cores' SPUs and EVUs
  for (int c = 0; c < NC; c++) {
    const uint32_t spu = d[C_SPU(c)], evu = d[C_EVU(c)], l1 = R_LINES + K_SETS * W_LINES + (c == CB ? LE_LINES : 0);
    if (rd) {   // evu: I$ refills
      RCHECK(spu >= l1 + evu && spu <= l1 + evu + SLACK, "round %u ev %u: core %d SPU %u, expected %u D$ + %u I$ refills "
             "(+%d)", r, ev, c, spu, l1, evu, SLACK);
      if (c == 0)
        RCHECK(spu == d[C_EVU0] + evu, "round %u ev %u: core 0 SPU %u, EVU D$ refills %u + I$ refills %u", r, ev, spu,
               d[C_EVU0], evu);
    } else {    // evu: D$ refills
      const uint32_t wb = K_SETS * (W_LINES - 8);
      RCHECK(evu >= l1 && evu <= l1 + SLACK, "round %u ev %u: core %d D$ refills %u, expected %u (+%d)", r, ev, c, evu,
             l1, SLACK);
      RCHECK(spu >= wb && spu <= wb + SLACK, "round %u ev %u: core %d SPU %u, expected %u (+%d)", r, ev, c, spu, wb, SLACK);
    }
  }
  if (rd) RCHECK(d[C_EVU0] >= R_LINES + K_SETS * W_LINES && d[C_EVU0] <= R_LINES + K_SETS * W_LINES + SLACK,
                 "round %u ev %u: core 0 D$ refills %u, expected %u (+%d)", r, ev, d[C_EVU0], R_LINES + K_SETS * W_LINES,
                 SLACK);
  // responses = requests, model on = model off (the exact counters)
  const unsigned qreq = res ? q - 2 : q, qoff = model ? q - 4 : q;
  for (int i = 2 * NC; i <= C_TOT; i++) {
    RCHECK(d[i] == delta[qreq][i], "round %u ev %u: counter %d %u, its request round %u", r, ev, i, d[i], delta[qreq][i]);
    RCHECK(d[i] == delta[qoff][i], "round %u ev %u: counter %d %u, model off %u", r, ev, i, d[i], delta[qoff][i]);
  }
}
// after the window: the data (P's lines, E's evicted lines, the DMA's results), outside every count
static void verify(int cid, unsigned r) {
  volatile job_t *j = &jobs[0][cid];
  uint32_t bad = 0;
  __asm__ volatile("fence\n\tfence.i" ::: "memory");             // P's last dirty lines to DRAM
  uint64_t want = j->pp;
  for (uint32_t k = 0; k < j->nk; k++) {
    const uint64_t b = j->pb + ((j->sets >> (7 * k)) & 127) * 16;
    for (uint32_t w = 0; w < j->nw; w++, want += PSTEP) bad += ld(b + (uint64_t)w * L1_STEP) != want;
  }
  if (cid == CA) {   // what core N-1's refills evicted: core N-2's lines, now in DRAM
    want = pat(3, CA, r);
    for (uint32_t i = 0; i < LE_LINES; i++, want += PSTEP) bad += ld(EA_BASE + i * 64) != want;
  }
  data_bad[cid] += bad + wbad[cid];
  if (cid == 0) {
    uint64_t v = pat(5, 0, r);
    for (uint32_t i = 0; i < LEN0; i++, v += PSTEP) acc_bad += ld(ACC_DST + i * 8) != v + ARG;
    uint32_t c = 0xFFFFFFFFu;
    for (uint32_t i = 0; i < LEN1; i++) {
      c ^= ((volatile uint8_t *)CRC_SRC)[i];
      for (int k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xEDB88320u : (c >> 1);
    }
    crc_bad += accel_rd(1, 0x14) != ~c;
    for (unsigned k = 1; k <= NFRAMES; k++) {
      volatile eth_area_t *a = ETH_AREA(k);
      int diff = !(a->rx.status & XBD_STS_CMPLT) || (a->rx.status & XBD_STS_ERR) || (a->rx.app[4] & 0xFFFF) != ETH_LEN;
      for (int i = 0; i < ETH_LEN; i++) diff += a->rxf[i] != a->txf[i];
      eth_data_bad += diff != 0;
    }
  }
}

// one pass through a round's window: from core 0's setup and first snapshot to its last; noinline and noclone, so that
// the warm-up's pass and the real one run the very same instructions
__attribute__((noinline, noclone)) static void pass(int cid, unsigned r, unsigned ev, int model, int p, unsigned *bar) {
  if (cid == 0) open_round(r, ev, model);
  soc_barrier(NC, ++*bar);
  const uint32_t bad = window(cid, &jobs[p][cid]);
  soc_barrier(NC, ++*bar);
  wbad[cid] = bad;
  if (cid == 0) close_round(r, ev, model, p);
  soc_barrier(NC, ++*bar);
}

// every core runs the rounds; core 0 also sets each one up and checks it
static void run(int cid) {
  unsigned bar = 0;
  uintptr_t sp;
  __asm__ volatile("mv %0, sp" : "=r"(sp));
  uint32_t ok = 0;   // P's candidate L1 sets (2 mod 4) that no line of this hart's stack frames maps to
  for (int s = 2; s < 128; s += 4) {
    int clash = 0;
    for (uintptr_t a = sp - 1024; a < sp + 256; a += 16) clash |= (int)((a >> 4) & 127) == s;
    if (!clash) ok |= 1u << (s / 4);
  }
  sets_ok[cid] = ok;
  for (unsigned r = 0; r < NROUNDS; r++) {
    const unsigned q = r ? (r - 1) % NQ : 0, ev = (q % 4) + 1;
    const int model = r && q >= 4;
    init_round(cid, r);
    soc_barrier(NC, ++bar);
    __asm__ volatile("fence\n\tfence.i" ::: "memory");           // every L1 written back and emptied
    soc_barrier(NC, ++bar);
    if (cid == 0 && llc_flush()) flush_bad++;                     // the LLC too: every line of the round cold
    soc_barrier(NC, ++bar);
    if (cid == CA) evict_setup(r);
    soc_barrier(NC, ++bar);
    code_warm(cid);
    soc_barrier(NC, ++bar);
    pass(cid, r, ev, model, 1, &bar);                             // the warm-up's pass on dummy lines: counts thrown away
    pass(cid, r, ev, model, 0, &bar);                             // the window
    verify(cid, r);
    soc_barrier(NC, ++bar);
  }
}

int thread_entry(int cid, int nc) {
  (void)nc;
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_storm");
    eth_up = eth_bringup();
    const uint32_t woke = soc_wake_all();
    CHECK(woke == SOC_WAKE_MASK, "woke harts 0x%x of 0x%x", woke, SOC_WAKE_MASK);
    return 0;                       // core 0 continues in main()
  }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

int main(void) {
  // the APMU: the PE held with its program loaded, no MemGuard period, every counter off and cleared
  REG32(PMC_STATUS_ADDR) = 1;
  REG32(PERIOD_ADDR) = 0; REG32(PERIOD_ADDR + 4) = 0;
  for (int i = 0; i < NUM_COUNTER; i++) {
    ctr_set(i, 0);
    REG32(INIT_BUDGET_BASE_ADDR + i * COUNTER_BUNDLE_SIZE) = 0;
  }
  for (unsigned i = 0; i < sizeof pe_fw / sizeof pe_fw[0]; i++) REG32(ISPM_BASE_ADDR + 4 * i) = pe_fw[i];
  // the LLC: its reset window, and way 15 for RCIDs 14 and 15 alone
  CHECK(REG32(LLC_START) == 0x80000000u && REG32(LLC_END) == 0x80800000u, "LLC window 0x%x-0x%x, not the reset one",
        REG32(LLC_START), REG32(LLC_END));
  set_limit(0, 0, MASK_REST); set_limit(0, 1, MASK_REST);
  set_limit(RCID_A, 0, MASK_E); set_limit(RCID_A, 1, MASK_REST);
  set_limit(RCID_B, 0, MASK_E); set_limit(RCID_B, 1, MASK_REST);
  CHECK(eth_up == 0, "Ethernet bring-up failed at step %d (DMA reset 1, PHY 2-3, PCS/PMA 4, loopback 5)", eth_up);
  printf("t_storm: %d cores, %d rounds: C %d, P %dx%d, E %d, socket %d+%d, Ethernet %d\r\n", NC, NROUNDS, R_LINES,
         K_SETS, W_LINES, LE_LINES, LEN0, LEN1 / 8, F_FRAMES);
  uart_wait_tx_done();

  run(0);

  REG32(PMC_STATUS_ADDR) = 1;
  dm_set(0);
  set_limit(0, 0, 0xFFFF); set_limit(0, 1, 0xFFFF); set_limit(RCID_A, 0, 0xFFFF); set_limit(RCID_A, 1, 0xFFFF);
  set_limit(RCID_B, 0, 0xFFFF); set_limit(RCID_B, 1, 0xFFFF);
  uint32_t dbad = 0, nsets = 0;
  for (int c = 0; c < NC; c++) dbad += data_bad[c];
  for (int c = 0; c < NC; c++) { uint32_t n = 0; for (int s = 2; s < 128; s += 4) n += (sets_ok[c] >> (s / 4)) & 1; nsets = c ? (n < nsets ? n : nsets) : n; }
  CHECK(nsets >= K_SETS, "only %u L1 sets clear of a stack for P", nsets);
  CHECK(snap_bad == 0 && flush_bad == 0 && pe_bad == 0, "snapshots unsettled %u, LLC flushes timed out %u, PE not armed %u",
        snap_bad, flush_bad, pe_bad);
  CHECK(dma_bad == 0 && eth_bad == 0, "socket jobs failed %u, Ethernet frames failed %u", dma_bad, eth_bad);
  CHECK(dbad == 0 && acc_bad == 0 && crc_bad == 0 && eth_data_bad == 0,
        "bad data: cores %u, socket copy %u words, CRC %u, Ethernet frames %u", dbad, acc_bad, crc_bad, eth_data_bad);
  // the last repeat's counts: per round kind, the memory port's total, the socket, the Ethernet, the cores' SPUs and EVUs
  for (int q = 0; q < NQ; q++) {
    volatile uint32_t *d = delta[q];
    uint32_t spu = 0, evu = 0;
    for (int c = 0; c < NC; c++) { spu += d[C_SPU(c)]; evu += d[C_EVU(c)]; }
    printf("ev %d dm %d: mem %u acc %u eth %u spu %u evu %u evu0 %u dm %u/%u\r\n", q % 4 + 1, q / 4, d[C_TOT], d[C_ACC],
           d[C_MEM(NC + 1)], spu, evu, d[C_EVU0], d[S_DMRD], d[S_DMWR]);
  }
  return soc_test_end();
}
