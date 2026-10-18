// The Xilinx AXI Ethernet subsystem + AXI DMA (hardware/host/xilinx_eth_subsys.sv) from a core, with the frames
// looped back: in xsim by the MAC stand-in (tb/eth_sgmii_model.sv), on the VCU118 by the PCS/PMA of the real IP
// (MDIO loopback bit at the PCS address), so the DMA path through the coherence unit is the same in both.
//   1. the DMA resets and the rings come up; the MAC answers on MDIO (PHY scan)
//   2. frames of every interesting size go out and come back intact, from cached DRAM buffers written by the
//      core without any cache maintenance, into cached DRAM buffers the core had already read (coherent DMA)
//   3. a burst of frames fills the TX ring before any is collected (ring wrap, back-to-back DMA)
//   4. the TX and RX completion interrupts reach the PLIC (IDs 11 and 15) and clear with SR + claim/complete
//   5. on the board, with the PHY reporting a link: loopback off, listen for a while and report what the LAN
//      sends (informational: a campus network broadcasts ARP every few seconds)
#include "soc_test.h"
#include "xeth.h"

#define NSIZES 8
static const unsigned sizes[NSIZES] = { 14, 60, 61, 64, 100, 257, 1000, 1514 };
#ifdef FPGA_EMULATION
#define POLLS     2000000UL
#define LISTEN_S  4
#else
#define POLLS     200000UL
#endif

static xeth_t eth;                                                      // rings + RX buffers: cached DRAM (.bss)
static uint8_t txf[XETH_NTX][XETH_BUF_SIZE] __attribute__((aligned(64)));
static const uint8_t mac[6] = { 0x00, 0x0A, 0x35, 0x01, 0x02, 0x03 }; // Xilinx OUI

static void fill(uint8_t *f, unsigned len, unsigned seed) {
  memcpy(f, "\xff\xff\xff\xff\xff\xff", 6);                              // broadcast, so the filter does not matter
  memcpy(f + 6, mac, 6);
  f[12] = 0x88; f[13] = 0xB5;                                            // IEEE local experimental ethertype
  for (unsigned i = 14; i < len; i++) f[i] = (uint8_t)(seed * 31 + i * 7 + (i >> 8));
}
static int compare(const uint8_t *a, const uint8_t *b, unsigned len) {   // first differing offset, or -1
  for (unsigned i = 0; i < len; i++) if (a[i] != b[i]) return (int)i;
  return -1;
}
static void plic_enable(int id) {                                        // priority 1, hart 0 M-mode context
  REG32(SOC_PLIC_BASE + id * 4) = 1;
  REG32(SOC_PLIC_BASE + 0x2000) |= 1u << id;
}
static int plic_pending(int id) { return (REG32(SOC_PLIC_BASE + 0x1000) >> id) & 1; }
static void plic_drain(void) {                                           // claim and complete whatever is pending
  unsigned id;                                                           // (a gateway keeps a source pending until
  while ((id = REG32(SOC_PLIC_BASE + 0x200004)) != 0) REG32(SOC_PLIC_BASE + 0x200004) = id;  // it is claimed)
}

// send one frame of len bytes and wait for it to come back; returns 0 or a failure code
static int roundtrip(unsigned len, unsigned seed, uint64_t *cycles) {
  uint8_t *rx; int n;
  uint64_t t0 = soc_cycles();
  fill(txf[0], len, seed);
  if (xeth_tx(&eth, txf[0], len)) return 1;
  if (xeth_tx_wait(&eth, POLLS)) return 2;
  n = xeth_rx_wait(&eth, &rx, POLLS);
  if (cycles) *cycles = soc_cycles() - t0;
  if (n <= 0) return n == 0 ? 3 : 4;
  unsigned want = len < 60 ? 60 : len;                                   // the MAC pads short frames
  if ((unsigned)n != want) { xeth_rx_done(&eth); return 5; }
  int d = compare(rx, txf[0], len);
  xeth_rx_done(&eth);
  return d < 0 ? 0 : 6;
}

int main(void) {
  soc_test_begin("t_eth");
  // 1. bring-up
  printf("MAC ID 0x%08x, DMA TX SR 0x%08x RX SR 0x%08x\n", xeth_rd(XAE_ID), xdma_rd(XDMA_TX + XDMA_SR), xdma_rd(XDMA_RX + XDMA_SR));
  CHECK(xeth_dma_init(&eth) == 0, "DMA reset / ring setup");
  CHECK(!(xdma_rd(XDMA_TX + XDMA_SR) & XDMA_SR_HALTED), "TX channel running (SR 0x%08x)", xdma_rd(XDMA_TX + XDMA_SR));
  CHECK(!(xdma_rd(XDMA_RX + XDMA_SR) & XDMA_SR_HALTED), "RX channel running (SR 0x%08x)", xdma_rd(XDMA_RX + XDMA_SR));
  xeth_mac_init(&eth, mac, 1);
  printf("MDIO scan: DP83867 at %d, PCS/PMA at %d\n", eth.phy_addr, eth.pcs_addr);
  CHECK(eth.phy_addr >= 0, "the DP83867 answers on MDIO");
#ifdef FPGA_EMULATION
  CHECK(xeth_phy_init(&eth) == 0, "PHY: SGMII clock output + reset");
  CHECK(xeth_phy_ext_read(eth.phy_addr, 0x00D3) == 0x4000, "PHY SGMIICTL reads back 0x4000");
  if (eth.pcs_addr < 0) xeth_pcs_probe(&eth);                           // its management runs on the PHY's clock
  printf("MAC IS 0x%08x (RxDcmLock %d MgtRdy %d PhyRstCmplt %d AutoNeg %d) after the PHY clock enable\n", xeth_rd(XAE_IS),
         (xeth_rd(XAE_IS) >> 6) & 1, (xeth_rd(XAE_IS) >> 7) & 1, (xeth_rd(XAE_IS) >> 8) & 1, (xeth_rd(XAE_IS) >> 1) & 1);
  for (int a = 0; a < 32; a++) {                                        // who answers on MDIO now
    int r0 = xeth_mdio_read(a, 0), r1 = xeth_mdio_read(a, 1), r2 = xeth_mdio_read(a, 2), r3 = xeth_mdio_read(a, 3);
    if (!(r0 == 0xFFFF && r1 == 0xFFFF && r2 == 0xFFFF && r3 == 0xFFFF)) printf("  MDIO %2d: r0 %04x r1 %04x id %04x %04x\n", a, r0, r1, r2, r3);
  }
  printf("PHY: BMCR %04x BMSR %04x PHYSTS %04x CFG2 %04x SGMIICTL %04x\n", xeth_mdio_read(eth.phy_addr, 0), xeth_mdio_read(eth.phy_addr, 1),
         xeth_mdio_read(eth.phy_addr, 0x11), xeth_mdio_read(eth.phy_addr, 0x14), xeth_phy_ext_read(eth.phy_addr, 0x00D3));
#endif
  CHECK(eth.pcs_addr >= 0, "the PCS/PMA answers on MDIO");
#ifdef FPGA_EMULATION
  for (unsigned i = 0; i < 50; i++) { if (xeth_phy_link(&eth)) break; for (volatile int d = 0; d < 1000000; d++); }
  printf("PHY link %s, %d Mb/s (BMSR 0x%04x)\n", eth.link ? "up" : "down", eth.speed, xeth_mdio_read(eth.phy_addr, 1));
  CHECK(xeth_pcs_loopback(&eth, 1) == 0, "PCS/PMA loopback on");
  int pcs0 = xeth_mdio_read(eth.pcs_addr, 0);
  CHECK(pcs0 & 0x4000, "PCS/PMA control reads back loopback (0x%04x)", pcs0);
  for (volatile int d = 0; d < 2000000; d++);                           // let the PCS settle
#endif
  // 2. sizes, from cached buffers
  for (unsigned i = 0; i < XETH_NRX; i++) for (unsigned k = 0; k < XETH_BUF_SIZE; k += 64) eth.rx_buf[i][k] = 0xEE;  // RX buffers in the L1 beforehand
  for (int s = 0; s < NSIZES; s++) {
    uint64_t cyc = 0;
    int r = roundtrip(sizes[s], (unsigned)s, &cyc);
    CHECK(r == 0, "frame of %u bytes: loopback (code %d, TX SR 0x%08x RX SR 0x%08x)", sizes[s], r, xdma_rd(XDMA_TX + XDMA_SR), xdma_rd(XDMA_RX + XDMA_SR));
    printf("  %4u bytes: round trip %u cycles\n", sizes[s], (unsigned)cyc);
  }
  // 3. a burst: fill the TX ring, then collect everything
  {
    unsigned n = XETH_NTX - 1, got = 0, bad = 0;
    for (unsigned i = 0; i < n; i++) { fill(txf[i], 200 + 37 * i, 100 + i); CHECK(xeth_tx(&eth, txf[i], 200 + 37 * i) == 0, "burst: queue frame %u", i); }
    for (unsigned i = 0; i < n; i++) CHECK(xeth_tx_wait(&eth, POLLS) == 0, "burst: frame %u sent", i);
    for (unsigned i = 0; i < n; i++) {
      uint8_t *rx; int len = xeth_rx_wait(&eth, &rx, POLLS);
      if (len == (int)(200 + 37 * i) && compare(rx, txf[i], len) < 0) got++; else bad++;
      if (len > 0) xeth_rx_done(&eth);
    }
    CHECK(got == n && bad == 0, "burst of %u frames through the rings (%u ok, %u bad)", n, got, bad);
  }
  // 4. interrupts
  {
    xdma_wr(XDMA_TX + XDMA_SR, XDMA_SR_IRQ_ALL);                        // clear what the previous transfers raised
    xdma_wr(XDMA_RX + XDMA_SR, XDMA_SR_IRQ_ALL);
    plic_enable(XETH_TX_IRQ); plic_enable(XETH_RX_IRQ);
    plic_drain();
    CHECK(!plic_pending(XETH_TX_IRQ) && !plic_pending(XETH_RX_IRQ), "DMA interrupts quiet after clearing and claiming");
    CHECK(roundtrip(300, 77, 0) == 0, "frame for the interrupt check");
    CHECK(plic_pending(XETH_TX_IRQ), "TX completion interrupt pending at the PLIC (ID %d)", XETH_TX_IRQ);
    CHECK(plic_pending(XETH_RX_IRQ), "RX completion interrupt pending at the PLIC (ID %d)", XETH_RX_IRQ);
    xdma_wr(XDMA_TX + XDMA_SR, XDMA_SR_IRQ_ALL);                        // source down first, then claim/complete
    xdma_wr(XDMA_RX + XDMA_SR, XDMA_SR_IRQ_ALL);
    plic_drain();
    CHECK(!plic_pending(XETH_TX_IRQ) && !plic_pending(XETH_RX_IRQ), "DMA interrupts cleared through SR + claim");
  }
#ifdef FPGA_EMULATION
  // 5. the LAN
  xeth_pcs_loopback(&eth, 0);
  for (volatile int d = 0; d < 2000000; d++);
  if (xeth_phy_link(&eth)) {
    unsigned frames = 0, bytes = 0;
    uint64_t t0 = soc_cycles();
    while (soc_cycles() - t0 < 50000000ULL * LISTEN_S) {
      uint8_t *rx; int n = xeth_rx(&eth, &rx);
      if (n > 0) {
        if (frames < 6) printf("  LAN frame %d bytes: dst %02x:%02x:%02x:%02x:%02x:%02x src %02x:%02x:%02x:%02x:%02x:%02x type %02x%02x\n", n,
                               rx[0], rx[1], rx[2], rx[3], rx[4], rx[5], rx[6], rx[7], rx[8], rx[9], rx[10], rx[11], rx[12], rx[13]);
        frames++; bytes += (unsigned)n;
      }
      if (n) xeth_rx_done(&eth);
    }
    printf("LAN: %u frames, %u bytes in %d s at %d Mb/s\n", frames, bytes, LISTEN_S, eth.speed);
  } else {
    printf("LAN: no link (no cable?), skipped\n");
  }
#endif
  return soc_test_end();
}
