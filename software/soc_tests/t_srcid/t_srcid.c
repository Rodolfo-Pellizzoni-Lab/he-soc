// t_srcid: the source every DRAM request is credited to, with N = SOC_NUM_CORES cores. The APMU's SPU on the LLC
// memory port (port 2N+1, APMU_PORT_MEM_SPU: 9 with four cores, 17 with eight) gives each request a source
// (hardware/include/ariane_soc_pkg.sv, ariane_axi_soc::mem_src): 0..N-1 the cores, N the accelerator socket's DMA and
// N+1 the Xilinx Ethernet's DMA (each a port of the coherence unit of its own), which the coherence unit writes into
// the AXI user field, then one per other crossbar master; a response counts for the source of its request. (The ID
// remapper behind the coherence unit also puts the source's low bits into the AXI ID, for the LLC's per-source way
// masks.)
// One source at a time makes DRAM traffic while the cores not involved wait in a barrier in the uncached on-chip SRAM
// (no DRAM traffic), and the port-(2N+1) counters of request and response events filtered by source must credit all
// of it to that source:
//   A. core c, LLC refills: 32 lines of LLC-cached DRAM nobody touched before (L1 and LLC misses: shareable reads
//      through the CCU FSM, 64-byte refills): exactly 32 reads. Each pass's and core's lines follow the previous ones
//      (48 KB with eight cores, less than one 64 KB way of the LLC), so no two of them share an LLC set.
//   B. core c, DRAM outside the LLC window (passed through the LLC): 16 lines written in one L1 set, then 16 more read
//      in it: exactly 32 reads (16 write-allocates, 16 fills) and 8 to 24 write-backs (the CCU's non-shareable path)
//   D. the accelerator socket's DMA (slot 0, the example accelerator, started by core 0): 16 words copied outside the
//      LLC window, a single-beat read and write each: exactly 16 of each, from source N
//   E. the Ethernet's DMA: one 64-byte frame through the MAC's loopback (as in t_eth: the stand-in's in xsim, the
//      PCS/PMA's on the VCU118), its descriptors and buffers outside the LLC window. Its requests reach the coherence
//      unit as single 64-bit beats (hardware/host/xilinx_eth_subsys.sv: the 32-bit descriptor port upsized, then all
//      split), and the AXI DMA (with the control/status streams) fetches 13 descriptor words for TX and 8 for RX and
//      writes back the status word for TX and the status and 5 app words for RX. So the TX DMA reads its descriptor
//      (7 beats) and the frame (8), the RX DMA reads its descriptor (4) and writes the frame (8), and the descriptor
//      updates are 1 beat for TX and 4 for RX (0x1C-0x33): exactly 19 reads and 13 writes, all from source N+1
//      (counted the same way, t_eth's 16 frames give the 786 Ethernet writes of its QoS table). Before the phase core 0
//      builds the descriptors and the frame and then empties its L1 (fence.i writes it back and invalidates it), so
//      that the DMA finds every line it touches in DRAM and in no L1 (no snoop data, no write-back for a core); in the
//      phase it only writes the tail-descriptor registers and polls the status registers. Needs the Xilinx Ethernet
//      (xilinx-ethernet=1, as every flow builds it and t_eth needs it).
// The APMU's SPU on the accelerator socket's DMA (port 2N+2, APMU_PORT_ACCEL_SPU, in front of the socket's port of the
// coherence unit) sees D's 16 reads and 16 writes and their responses, all from source N, and as D's buffers are
// outside the LLC window that is also what port 2N+1 credits to source N; in every other phase it sees nothing (the
// cores and the Ethernet DMA have ports of their own).
// Every request gets its response, credited to the same source, and the sources add up to the port's totals. The
// N+2 sources' four events do not fit the APMU's 32 counters with more than four cores, so the phases run three
// times: pass 1 counts each source's read and write requests, pass 2 its read and write responses, both all four
// events of every source and port 2N+2's (28 counters with eight cores), and every check compares counts of one pass.
// Only the cores, the socket and the Ethernet DMA touch DRAM here; writes the coherence unit issues itself and LLC
// evictions are not exercised. An instruction fetch that misses the LLC is a DRAM read of the core that runs it, also
// when it is fetched ahead: a first pass over other addresses runs all of the measured code and is not checked, every
// phase ends with a barrier that holds the cores until core 0 has taken its snapshot (so none runs ahead into code
// that has never run), and a snapshot is read until two reads in a row agree. Main before the ID-remapper fix (and the
// October bitstreams) credits the cores' reads to source 2 and their write-backs by core parity; with only that fix
// the socket's DMA port (then shared with the Ethernet DMA) still counts as core 0.
#include "soc_test.h"
#include "accel.h"
#include "xeth.h"

#define NC        SOC_NUM_CORES   // every core takes part (built with -DSOC_NUM_CORES=<n> for an n-core SoC)
#define SRC_ACCEL APMU_SRC_ACCEL  // source of the accelerator socket's DMA, N (ariane_soc::CcuAccelPort)
#define SRC_ETH   APMU_SRC_ETH    // source of the Xilinx Ethernet's DMA, N+1 (ariane_soc::CcuEthPort)
#define NSRC      (NC + 2)
#define NPASS     3               // 0 not checked, 1 the requests by source, 2 the responses by source
#define LLC_BASE  0x80400000UL    // LLC-cached DRAM not used by the program (the LLC caches 0x8000_0000-0x807F_FFFF)
#define LLC_END   0x80800000UL
#define BYP_BASE  0x81000000UL    // DRAM outside the LLC window: the LLC passes the requests through
#define DMA_BASE  0x81800000UL    // the same, for the accelerator's buffers
#define ETH_BASE  0x81C00000UL    // the same, for the Ethernet DMA's descriptors and buffers
#define PASS_STEP 0x100000UL
#define CORE_STEP 0x20000UL       // B: a core's 32 lines, 2 KB apart
#define L1_STEP   0x800UL         // 16 KB L1, 8 ways of 16-byte lines: lines 2 KB apart share an L1 set
#define NA        32              // A: lines read
#define NW        16              // B: lines written, then as many read
#define ND        16              // D: words copied
#define ETH_LEN   64              // E: frame bytes, a multiple of 8 and not below the MAC's 60-byte minimum (no padding)
#define ETH_RD    (7 + ETH_LEN / 8 + 4)   // E: reads: TX descriptor (13 words), the frame, RX descriptor (8 words)
#define ETH_WR    (1 + ETH_LEN / 8 + 4)   // E: writes: TX status word, the frame, RX status and app words (6)
#define SLOT      0
#define ARG       7u
#define SETTLE    1000            // cycles for write-backs and counter updates to land before a snapshot
#define SNAP_ROUNDS 8
#ifdef FPGA_EMULATION
#define ETH_POLLS 2000000UL
#else
#define ETH_POLLS 200000UL
#endif
#if NC * CORE_STEP > PASS_STEP || LLC_BASE + NPASS * NC * NA * 64 > LLC_END
#error "t_srcid: the cores' areas do not fit a pass"
#endif

// The APMU counters, set up by core 0 at the start of each pass (soc_wake_all has woken the cores with the first ones
// and released them). Port 2N+1: per source 0..NSRC-1 the pass's read and write event (requests in passes 0 and 1,
// responses in pass 2), then each SPU event (1 read request, 2 write request, 3 read response, 4 write response) of
// every source; port 2N+2: its four events (from source N, as all of them are)
#define NEV         4
#define CTR0        0
#define PS(k, s)    ((k) * NSRC + (s))           // port 2N+1: the pass's read (k = 0) or write (k = 1) event, source s
#define TOT(e)      (2 * NSRC + (e))             // port 2N+1: event e = 0..3, every source
#define ACC(e)      (2 * NSRC + NEV + (e))       // port 2N+2: event e = 0..3
#define NCTR        (2 * NSRC + 2 * NEV)
#if CTR0 + NCTR > NUM_COUNTER
#error "t_srcid needs more counters than the APMU has"
#endif
#define RD_REQ 0
#define WR_REQ 1
#define RD_RES 2
#define WR_RES 3
#define PASS_EV(pass, k) (((pass) == NPASS - 1 ? RD_RES : RD_REQ) + (k))   // the event PS(k, s) counts in the pass

// phases: core c's A and B at 2c and 2c+1, then D and E
#define NPH       (2 * NC + 2)
#define PH_DMA    (2 * NC)
#define PH_ETH    (2 * NC + 1)

// E: one area per pass, its descriptors 64-byte aligned as the DMA requires; each pass's descriptors point at the
// next pass's (a ring of NPASS per channel), so a pass's tail-descriptor write continues from the previous pass's
typedef struct {
  xeth_bd_t tx, rx;
  uint8_t   txf[ETH_LEN]       __attribute__((aligned(64)));
  uint8_t   rxf[XETH_BUF_SIZE] __attribute__((aligned(64)));
} eth_area_t;
#define ETH_AREA(pass) ((volatile eth_area_t *)(ETH_BASE + (unsigned long)(pass) * PASS_STEP))
#define ETH_LO(p)      ((uint32_t)(uintptr_t)(p))
#define XDMA_SR_IOC    0x1000u   // DMASR IOC_Irq: a descriptor with EOF has completed (write 1 to clear)

static inline uint64_t ld(uint64_t a) { return *(volatile uint64_t *)a; }
static inline void     st(uint64_t a, uint64_t v) { *(volatile uint64_t *)a = v; }

SOC_SRAM static volatile uint32_t delta[NPASS - 1][NPH][NCTR];   // [pass 1, 2][phase][counter]
SOC_SRAM static volatile uint32_t snap_bad, dma_timeout, eth_timeout;

static xeth_t eth;                                     // the MAC and PHY state (its rings stay unused: E has its own)
static int    eth_up;                                  // eth_bringup()'s result
static const uint8_t eth_mac[6] = { 0x00, 0x0A, 0x35, 0x01, 0x02, 0x03 };   // Xilinx OUI, as in t_eth

static void ctr_set(int i, uint32_t sel) {
  REG32(EVENT_SEL_BASE_ADDR  + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = sel;
  REG32(EVENT_INFO_BASE_ADDR + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
  REG32(COUNTER_BASE_ADDR    + (CTR0 + i) * COUNTER_BUNDLE_SIZE) = 0;
}

static void ctr_setup(int pass) {
  for (int k = 0; k < 2; k++)
    for (int s = 0; s < NSRC; s++) ctr_set(PS(k, s), MEM_SEL(PASS_EV(pass, k) + 1, s));
  for (int e = 0; e < NEV; e++) {
    ctr_set(TOT(e), APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, e + 1));
    ctr_set(ACC(e), APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, SRC_ACCEL, e + 1));
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

// E, once before the passes: the DMA reset and both channels running on pass 0's descriptors (nothing moves before a
// tail descriptor is written), the MAC on, and its loopback (on the VCU118 the PCS/PMA's, once the PHY drives its
// SGMII clock, as in t_eth). Returns 0, or the step that failed.
static int eth_bringup(void) {
  if (xdma_reset(XDMA_TX) || xdma_reset(XDMA_RX)) return 1;
  xdma_wr(XDMA_TX + XDMA_CURDESC, ETH_LO(&ETH_AREA(0)->tx));
  xdma_wr(XDMA_TX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xdma_wr(XDMA_RX + XDMA_CURDESC, ETH_LO(&ETH_AREA(0)->rx));
  xdma_wr(XDMA_RX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xeth_mac_init(&eth, eth_mac, 1);
  if (eth.phy_addr < 0) return 2;
#ifdef FPGA_EMULATION
  if (xeth_phy_init(&eth)) return 3;
  if (eth.pcs_addr < 0) xeth_pcs_probe(&eth);                           // its management runs on the PHY's clock
#endif
  if (eth.pcs_addr < 0) return 4;
#ifdef FPGA_EMULATION
  { uint64_t t0 = soc_cycles(); while (!xeth_phy_link(&eth) && soc_cycles() - t0 < 50000000ULL * 10) for (volatile int d = 0; d < 100000; d++); }
  if (xeth_pcs_loopback(&eth, 1)) return 5;
  for (volatile int d = 0; d < 2000000; d++);                           // let the PCS settle
#endif
  return 0;
}

// E, before the phase's first snapshot: the pass's descriptors and frame, then core 0's L1 written back and
// invalidated, so that the DMA reads them from DRAM and none of its accesses meets a line an L1 holds
static void eth_prepare(int pass) {
  volatile eth_area_t *a = ETH_AREA(pass), *n = ETH_AREA((pass + 1) % NPASS);
  for (int i = 0; i < 16; i++) { ((volatile uint32_t *)&a->tx)[i] = 0; ((volatile uint32_t *)&a->rx)[i] = 0; }
  a->tx.next = ETH_LO(&n->tx);
  a->tx.buf  = ETH_LO(a->txf);
  a->tx.ctrl = ETH_LEN | XBD_CTRL_SOF | XBD_CTRL_EOF;
  a->rx.next = ETH_LO(&n->rx);
  a->rx.buf  = ETH_LO(a->rxf);
  a->rx.ctrl = XETH_BUF_SIZE;
  for (int i = 0; i < ETH_LEN; i++) {   // broadcast from our MAC address, IEEE local experimental ethertype, a pattern
    a->txf[i] = i < 6 ? 0xFF : i < 12 ? eth_mac[i - 6] : i == 12 ? 0x88 : i == 13 ? 0xB5 : (uint8_t)(pass * 31 + i * 7);
    a->rxf[i] = 0xEE;
  }
  __asm__ volatile("fence\n\tfence.i" ::: "memory");
  uint64_t t = soc_cycles();
  while (soc_cycles() - t < SETTLE) ;
}

// E: poll a channel's status register (not its descriptor: that would be a DRAM read by core 0) until its descriptor
// has completed, and clear the completion for the next pass; 0, or -1 on a DMA error or a timeout
static int eth_wait(unsigned ch) {
  for (unsigned long i = 0; i < ETH_POLLS; i++) {
    uint32_t sr = xdma_rd(ch + XDMA_SR);
    if (sr & XDMA_SR_ERR_MASK) return -1;
    if (sr & XDMA_SR_IOC) { xdma_wr(ch + XDMA_SR, XDMA_SR_IRQ_ALL); return 0; }
  }
  return -1;
}

static void traffic(int pass, int p) {
  uint64_t s = 0;
  if (p == PH_ETH) {
    volatile eth_area_t *a = ETH_AREA(pass);
    xdma_wr(XDMA_RX + XDMA_TAILDESC, ETH_LO(&a->rx));   // the RX DMA fetches its descriptor and waits for the frame
    xdma_wr(XDMA_TX + XDMA_TAILDESC, ETH_LO(&a->tx));   // the TX DMA fetches its descriptor and sends the frame
    if (eth_wait(XDMA_TX) || eth_wait(XDMA_RX)) eth_timeout++;
  } else if (p == PH_DMA) {
    uint64_t b = DMA_BASE + pass * PASS_STEP;
    accel_wr64(SLOT, 0x08, b); accel_wr64(SLOT, 0x10, b + 0x10000); accel_wr(SLOT, 0x18, ND); accel_wr(SLOT, 0x1C, ARG);
    accel_wr(SLOT, 0x00, 0x1);
    if (accel_wait(SLOT, 0x04, 0x3, 0x2, 100000) != 0) dma_timeout++;
    accel_wr(SLOT, 0x04, 0x2);
  } else if (p % 2 == 0) {
    uint64_t b = LLC_BASE + (uint64_t)(pass * NC + p / 2) * NA * 64;
    for (int i = 0; i < NA; i++) s += ld(b + i * 64);
  } else {
    uint64_t b = BYP_BASE + pass * PASS_STEP + (p / 2) * CORE_STEP;
    for (int i = 0; i < NW; i++) st(b + i * L1_STEP, i);
    for (int i = 0; i < NW; i++) s += ld(b + (NW + i) * L1_STEP);
  }
  __asm__ volatile("fence rw, rw" ::: "memory");
  __asm__ volatile("" :: "r"(s));
}

// every core runs the same schedule; core 0 sets up the counters for each pass, takes the counter snapshots around
// each phase and drives D and E
static void run(int cid) {
  uint32_t before[NCTR], after[NCTR];
  int round = 1;
  for (int pass = 0; pass < NPASS; pass++)
    for (int p = 0; p < NPH; p++) {
      int ok = 1;
      if (cid == 0 && p == 0) ctr_setup(pass);
      if (cid == 0 && p == PH_ETH) eth_prepare(pass);
      if (cid == 0) ok &= ctr_snap(before);
      soc_barrier(NC, round++);
      if (cid == (p >= PH_DMA ? 0 : p / 2)) traffic(pass, p);
      soc_barrier(NC, round++);
      if (cid == 0) {
        uint64_t t = soc_cycles();
        while (soc_cycles() - t < SETTLE) ;
        ok &= ctr_snap(after);
        if (pass) for (int i = 0; i < NCTR; i++) delta[pass - 1][p][i] = after[i] - before[i];
        if (pass && !ok) snap_bad++;
      }
      soc_barrier(NC, round++);
    }
}

int thread_entry(int cid, int nc) {
  soc_install_trap_guard();
  if (cid == 0) {
    soc_test_begin("t_srcid");
    eth_up = eth_bringup();
    soc_wake_all();                 // with the first counters, which it releases; run() sets them up for each pass
    return 0;                       // core 0 continues in main()
  }
  run(cid);
  while (1) __asm__ volatile("wfi");
}

// a phase's counts of the pass's event k (0 read, 1 write) for sources 0..NSRC-1
static void print_srcs(volatile uint32_t *d, int k) {
  for (int s = 0; s < NSRC; s++) printf(" %u", d[PS(k, s)]);
}

int main(void) {
  static const char *what[4] = {"LLC refills", "outside the LLC window", "socket DMA outside the LLC window",
                                "Ethernet DMA outside the LLC window"};
  run(0);
  CHECK(snap_bad == 0, "%u counter snapshots did not settle in %d rounds", snap_bad, SNAP_ROUNDS);
  CHECK(dma_timeout == 0, "the accelerator did not finish (%u times)", dma_timeout);
  CHECK(eth_up == 0, "Ethernet bring-up failed at step %d (DMA reset 1, PHY 2-3, PCS/PMA 4, loopback 5)", eth_up);
  CHECK(eth_timeout == 0, "the Ethernet DMA did not finish (%u times; TX SR 0x%08x RX SR 0x%08x)", eth_timeout,
        xdma_rd(XDMA_TX + XDMA_SR), xdma_rd(XDMA_RX + XDMA_SR));
  {   // E's frame of the last pass came back whole (read now: in a phase it would be core 0's DRAM traffic)
    volatile eth_area_t *a = ETH_AREA(NPASS - 1);
    uint32_t sts = a->rx.status, len = a->rx.app[4] & 0xFFFF;
    int diff = 0;
    for (int i = 0; i < ETH_LEN; i++) diff += a->rxf[i] != a->txf[i];
    CHECK((sts & XBD_STS_CMPLT) && !(sts & XBD_STS_ERR) && len == ETH_LEN && diff == 0
          && (a->tx.status & XBD_STS_CMPLT),
          "Ethernet frame: RX status 0x%08x, %u of %d bytes, %d bytes differ, TX status 0x%08x", sts, len, ETH_LEN,
          diff, a->tx.status);
  }
  for (int p = 0; p < NPH; p++) {
    volatile uint32_t *q = delta[0][p], *r = delta[1][p];   // pass 1: requests by source, pass 2: responses
    int src = p == PH_ETH ? SRC_ETH : p == PH_DMA ? SRC_ACCEL : p / 2;
    int k = p == PH_ETH ? 3 : p == PH_DMA ? 2 : p % 2;
    uint32_t rd = q[PS(0, src)], wr = q[PS(1, src)];            // pass 1: the requests credited to the source
    uint32_t rd2 = r[TOT(RD_REQ)], wr2 = r[TOT(WR_REQ)];        // pass 2: all requests of the port
    uint32_t other = 0;
    printf("source %d, %s: read requests by source 0-%d", src, what[k], NSRC - 1);
    print_srcs(q, 0);
    printf(", write requests");
    print_srcs(q, 1);
    printf("\r\nsource %d, %s: read responses by source 0-%d", src, what[k], NSRC - 1);
    print_srcs(r, 0);
    printf(", write responses");
    print_srcs(r, 1);
    printf("\r\n");
    // the expected amount in both passes: pass 1's credited to the source, pass 2's at the port
    if (k == 0) CHECK(rd == NA && rd2 == NA, "source %d, %s: %u and %u reads (passes 1 and 2), expected %d", src,
                      what[k], rd, rd2, NA);
    if (k == 1) {
      CHECK(rd == 2 * NW && rd2 == 2 * NW, "source %d, %s: %u and %u reads (passes 1 and 2), expected %d", src,
            what[k], rd, rd2, 2 * NW);
      CHECK(wr >= NW / 2 && wr <= NW + NW / 2 && wr2 >= NW / 2 && wr2 <= NW + NW / 2,
            "source %d, %s: %u and %u write-backs (passes 1 and 2), expected %d to %d", src, what[k], wr, wr2, NW / 2,
            NW + NW / 2);
    }
    if (k == 2) CHECK(rd == ND && wr == ND && rd2 == ND && wr2 == ND,
                      "source %d, %s: %u reads and %u writes, %u and %u (passes 1 and 2), expected %d each", src,
                      what[k], rd, wr, rd2, wr2, ND);
    if (k == 3) CHECK(rd == ETH_RD && wr == ETH_WR && rd2 == ETH_RD && wr2 == ETH_WR,
                      "source %d, %s: %u reads and %u writes, %u and %u (passes 1 and 2), expected %d and %d", src,
                      what[k], rd, wr, rd2, wr2, ETH_RD, ETH_WR);
    for (int s = 0; s < NSRC; s++)
      if (s != src) for (int j = 0; j < 2; j++) other += q[PS(j, s)] + r[PS(j, s)];
    CHECK(other == 0, "source %d, %s: %u events credited to other sources", src, what[k], other);
    // every request answered (pass 1: the port's totals), its response credited to the source (pass 2)
    CHECK(q[TOT(RD_RES)] == q[TOT(RD_REQ)] && q[TOT(WR_RES)] == q[TOT(WR_REQ)] && r[PS(0, src)] == rd2 &&
          r[PS(1, src)] == wr2,
          "source %d, %s: %u of %u reads and %u of %u writes answered (pass 1), %u of %u and %u of %u credited to it "
          "(pass 2)", src, what[k], q[TOT(RD_RES)], q[TOT(RD_REQ)], q[TOT(WR_RES)], q[TOT(WR_REQ)], r[PS(0, src)], rd2,
          r[PS(1, src)], wr2);
    // the sources add up to the port's totals, in both passes
    int sums_ok = 1;
    uint32_t rd_all = 0;
    for (int j = 0; j < 2; j++) {
      uint32_t sq = 0, sr = 0;
      for (int s = 0; s < NSRC; s++) { sq += q[PS(j, s)]; sr += r[PS(j, s)]; }
      sums_ok &= sq == q[TOT(PASS_EV(1, j))] && sr == r[TOT(PASS_EV(2, j))];
      if (j == 0) rd_all = sq;
    }
    CHECK(sums_ok, "source %d, %s: sources 0-%d do not add up to the port's totals (reads %u of %u)", src, what[k],
          NSRC - 1, rd_all, q[TOT(RD_REQ)]);
    // port 2N+2, the socket's SPU: D's DMA, all of it reaching DRAM (port 2N+1, source N), and nothing in other phases
    if (k == 2) {
      printf("source %d, %s: port %d (the socket's SPU) read requests %u, write requests %u, responses %u read %u "
             "write (pass 1), %u %u %u %u (pass 2)\r\n", src, what[k], APMU_PORT_ACCEL_SPU, q[ACC(RD_REQ)],
             q[ACC(WR_REQ)], q[ACC(RD_RES)], q[ACC(WR_RES)], r[ACC(RD_REQ)], r[ACC(WR_REQ)], r[ACC(RD_RES)],
             r[ACC(WR_RES)]);
      int nd = 1;
      for (int e = 0; e < NEV; e++) nd &= q[ACC(e)] == ND && r[ACC(e)] == ND;
      CHECK(nd, "source %d, %s: port %d saw %u reads, %u writes, %u read and %u write responses (pass 1), expected %d "
            "each", src, what[k], APMU_PORT_ACCEL_SPU, q[ACC(RD_REQ)], q[ACC(WR_REQ)], q[ACC(RD_RES)], q[ACC(WR_RES)],
            ND);
      CHECK(q[ACC(RD_REQ)] == rd && q[ACC(WR_REQ)] == wr && r[ACC(RD_RES)] == r[PS(0, src)] &&
            r[ACC(WR_RES)] == r[PS(1, src)],
            "source %d, %s: port %d (%u %u requests, %u %u responses) and port %d's source %d (%u %u, %u %u) differ",
            src, what[k], APMU_PORT_ACCEL_SPU, q[ACC(RD_REQ)], q[ACC(WR_REQ)], r[ACC(RD_RES)], r[ACC(WR_RES)],
            APMU_PORT_MEM_SPU, src, rd, wr, r[PS(0, src)], r[PS(1, src)]);
    } else {
      uint32_t acc = 0;
      for (int e = 0; e < NEV; e++) acc += q[ACC(e)] + r[ACC(e)];
      CHECK(acc == 0, "source %d, %s: %u events on port %d (the socket's SPU), expected none", src, what[k], acc,
            APMU_PORT_ACCEL_SPU);
    }
  }
  return soc_test_end();
}
