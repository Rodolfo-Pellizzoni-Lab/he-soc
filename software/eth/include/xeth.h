// Bare-metal driver for the Xilinx AXI 1G Ethernet subsystem + AXI DMA of the SoC (hardware/host/xilinx_eth_subsys.sv):
// polled, scatter-gather rings in memory, no interrupts needed (the DMA's completion interrupts are wired to the
// PLIC, IDs XETH_TX_IRQ / XETH_RX_IRQ, for tests and for Linux). Register names follow the Linux driver
// (drivers/net/ethernet/xilinx/xilinx_axienet.h), so the two can be read side by side.
//
// Memory: descriptors and frame buffers may live in cached DRAM: the DMA enters the SoC through the coherence
// unit's DMA port (snooped reads, invalidating writes), so no cache maintenance is needed. The same code runs in
// xsim against tb/eth_sgmii_model.sv (a loopback MAC) and on the VCU118 against the real IP and the DP83867 PHY.
#ifndef XETH_H
#define XETH_H
#include <stdint.h>
#include <string.h>

#define XETH_BASE     0x30000000UL                 // ariane_soc::EthernetBase
#define XETH_DMA_BASE (XETH_BASE + 0x40000UL)      // + ariane_soc::XEthDmaOffset
#define XETH_MAC_IRQ  3                            // PLIC IDs
#define XETH_TX_IRQ   11
#define XETH_RX_IRQ   15

#define XETH_R32(a)      (*(volatile uint32_t *)(uintptr_t)(a))

// AXI Ethernet registers
#define XAE_RAF       0x000
#define XAE_IS        0x00C
#define XAE_IP        0x010
#define XAE_IE        0x014
#define XAE_RCW1      0x404
#define XAE_TC        0x408
#define XAE_FCC       0x40C
#define XAE_EMMC      0x410
#define XAE_PHYC      0x414
#define XAE_ID        0x4F8
#define XAE_MDIO_MC   0x500
#define XAE_MDIO_MCR  0x504
#define XAE_MDIO_MWD  0x508
#define XAE_MDIO_MRD  0x50C
#define XAE_UAW0      0x700
#define XAE_UAW1      0x704
#define XAE_FMI       0x708
#define XAE_RCW1_RX        0x10000000u
#define XAE_RCW1_FCS       0x20000000u             // pass the FCS to the stream
#define XAE_TC_TX          0x10000000u
#define XAE_EMMC_1000      0x40000000u
#define XAE_EMMC_100       0x80000000u
#define XAE_FMI_PM         0x80000000u             // promiscuous
#define XAE_MDIO_MC_EN     0x40u
#define XAE_MDIO_MCR_INIT  0x800u
#define XAE_MDIO_MCR_READY 0x80u
#define XAE_MDIO_OP_RD     (2u << 14)
#define XAE_MDIO_OP_WR     (1u << 14)
#define XAE_INT_RXCMPIT    0x4u
#define XAE_INT_TXCMPIT    0x20u

// AXI DMA registers (TX = MM2S at 0x00, RX = S2MM at 0x30)
#define XDMA_TX       0x00
#define XDMA_RX       0x30
#define XDMA_CR       0x00
#define XDMA_SR       0x04
#define XDMA_CURDESC  0x08
#define XDMA_TAILDESC 0x10
#define XDMA_CR_RS       0x1u
#define XDMA_CR_RESET    0x4u
#define XDMA_CR_IOC_IRQ  0x1000u
#define XDMA_CR_ERR_IRQ  0x4000u
#define XDMA_CR_THRESH1  (1u << 16)
#define XDMA_SR_HALTED   0x1u
#define XDMA_SR_IDLE     0x2u
#define XDMA_SR_ERR_MASK 0x770u
#define XDMA_SR_IRQ_ALL  0x7000u

// scatter-gather descriptor (64-byte aligned; 16-bit lengths as configured)
typedef struct {
  uint32_t next, next_hi, buf, buf_hi, rsv0, rsv1;
  uint32_t ctrl;        // [15:0] length, bit 27 TXSOF, bit 26 TXEOF
  uint32_t status;      // bit 31 complete, 30 DecErr, 29 SlvErr, 28 IntErr, 27 RXSOF, 26 RXEOF, [15:0] bytes
  uint32_t app[5];      // TX: control words; RX: status words, app[4][15:0] = received length
  uint32_t id, pad0, pad1;
} __attribute__((aligned(64))) xeth_bd_t;
#define XBD_CTRL_SOF   0x08000000u
#define XBD_CTRL_EOF   0x04000000u
#define XBD_STS_CMPLT  0x80000000u
#define XBD_STS_ERR    0x70000000u

#ifndef XETH_NTX
#define XETH_NTX 8
#endif
#ifndef XETH_NRX
#define XETH_NRX 8
#endif
#define XETH_BUF_SIZE 2048            // one frame per buffer (1518 + room)

typedef struct {
  xeth_bd_t tx_bd[XETH_NTX];
  xeth_bd_t rx_bd[XETH_NRX];
  uint8_t   rx_buf[XETH_NRX][XETH_BUF_SIZE];
  unsigned  tx_head, tx_tail;          // next BD to fill / next BD whose completion is awaited
  unsigned  rx_next;                   // next BD to look at
  int       phy_addr;                  // DP83867, -1 if not found
  int       pcs_addr;                  // the subsystem's PCS/PMA (1), -1 if not found
  int       link, speed;               // from the PHY: link up, 10/100/1000
} xeth_t;

static inline uint32_t xeth_rd(unsigned off)             { return XETH_R32(XETH_BASE + off); }
static inline void     xeth_wr(unsigned off, uint32_t v) { XETH_R32(XETH_BASE + off) = v; }
static inline uint32_t xdma_rd(unsigned off)             { return XETH_R32(XETH_DMA_BASE + off); }
static inline void     xdma_wr(unsigned off, uint32_t v) { XETH_R32(XETH_DMA_BASE + off) = v; }
static inline void     xeth_mb(void) { __asm__ volatile("fence" ::: "memory"); }

// ---------------------------------------------------------------- MDIO (polled, the MAC's own MDIO master)
static inline int xeth_mdio_wait(void) {
  for (unsigned i = 0; i < 1000000; i++) if (xeth_rd(XAE_MDIO_MCR) & XAE_MDIO_MCR_READY) return 0;
  return -1;
}
static inline int xeth_mdio_read(int phy, int reg) {
  if (xeth_mdio_wait()) return -1;
  xeth_wr(XAE_MDIO_MCR, ((uint32_t)phy << 24) | ((uint32_t)reg << 16) | XAE_MDIO_OP_RD | XAE_MDIO_MCR_INIT);
  if (xeth_mdio_wait()) return -1;
  return (int)(xeth_rd(XAE_MDIO_MRD) & 0xFFFF);
}
static inline int xeth_mdio_write(int phy, int reg, uint16_t val) {
  if (xeth_mdio_wait()) return -1;
  xeth_wr(XAE_MDIO_MWD, val);
  xeth_wr(XAE_MDIO_MCR, ((uint32_t)phy << 24) | ((uint32_t)reg << 16) | XAE_MDIO_OP_WR | XAE_MDIO_MCR_INIT);
  return xeth_mdio_wait();
}
// DP83867 extended registers through REGCR (0x0D) / ADDAR (0x0E)
static inline int xeth_phy_ext_write(int phy, uint16_t reg, uint16_t val) {
  if (xeth_mdio_write(phy, 0x0D, 0x001F)) return -1;
  if (xeth_mdio_write(phy, 0x0E, reg))    return -1;
  if (xeth_mdio_write(phy, 0x0D, 0x401F)) return -1;
  return xeth_mdio_write(phy, 0x0E, val);
}
static inline int xeth_phy_ext_read(int phy, uint16_t reg) {
  if (xeth_mdio_write(phy, 0x0D, 0x001F)) return -1;
  if (xeth_mdio_write(phy, 0x0E, reg))    return -1;
  if (xeth_mdio_write(phy, 0x0D, 0x401F)) return -1;
  return xeth_mdio_read(phy, 0x0E);
}

// ---------------------------------------------------------------- DMA rings
static inline int xdma_reset(unsigned ch) {
  xdma_wr(ch + XDMA_CR, XDMA_CR_RESET);
  for (unsigned i = 0; i < 1000000; i++) if (!(xdma_rd(ch + XDMA_CR) & XDMA_CR_RESET)) return 0;
  return -1;
}
static inline uint32_t xeth_lo(const void *p) { return (uint32_t)(uintptr_t)p; }

static inline void xeth_rx_post(xeth_t *e, unsigned i) {   // hand BD i back to the DMA
  e->rx_bd[i].status = 0;
  e->rx_bd[i].ctrl   = XETH_BUF_SIZE;
  for (int k = 0; k < 5; k++) e->rx_bd[i].app[k] = 0;
  xeth_mb();
  xdma_wr(XDMA_RX + XDMA_TAILDESC, xeth_lo(&e->rx_bd[i]));
}

// Bring the DMA up with the rings; returns 0, or -1 if a reset never completes
static inline int xeth_dma_init(xeth_t *e) {
  if (xdma_reset(XDMA_TX) || xdma_reset(XDMA_RX)) return -1;
  memset(e->tx_bd, 0, sizeof(e->tx_bd));
  memset(e->rx_bd, 0, sizeof(e->rx_bd));
  for (unsigned i = 0; i < XETH_NTX; i++) e->tx_bd[i].next = xeth_lo(&e->tx_bd[(i + 1) % XETH_NTX]);
  for (unsigned i = 0; i < XETH_NRX; i++) {
    e->rx_bd[i].next = xeth_lo(&e->rx_bd[(i + 1) % XETH_NRX]);
    e->rx_bd[i].buf  = xeth_lo(e->rx_buf[i]);
    e->rx_bd[i].ctrl = XETH_BUF_SIZE;
  }
  e->tx_head = e->tx_tail = 0;
  e->rx_next = 0;
  xeth_mb();
  // interrupts on every completion (the PLIC decides whether anyone listens)
  xdma_wr(XDMA_TX + XDMA_CURDESC, xeth_lo(&e->tx_bd[0]));
  xdma_wr(XDMA_TX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xdma_wr(XDMA_RX + XDMA_CURDESC, xeth_lo(&e->rx_bd[0]));
  xdma_wr(XDMA_RX + XDMA_CR, XDMA_CR_RS | XDMA_CR_IOC_IRQ | XDMA_CR_ERR_IRQ | XDMA_CR_THRESH1);
  xdma_wr(XDMA_RX + XDMA_TAILDESC, xeth_lo(&e->rx_bd[XETH_NRX - 1]));
  return 0;
}

// Queue one frame (no FCS; the MAC pads and appends it). Returns 0, -1 if the ring is full.
static inline int xeth_tx(xeth_t *e, const void *frame, unsigned len) {
  xeth_bd_t *bd = &e->tx_bd[e->tx_head];
  if ((e->tx_head + 1) % XETH_NTX == e->tx_tail) return -1;
  bd->buf    = xeth_lo(frame);
  bd->status = 0;
  bd->ctrl   = (len & 0xFFFF) | XBD_CTRL_SOF | XBD_CTRL_EOF;
  for (int k = 0; k < 5; k++) bd->app[k] = 0;      // no checksum offload
  xeth_mb();
  xdma_wr(XDMA_TX + XDMA_TAILDESC, xeth_lo(bd));
  e->tx_head = (e->tx_head + 1) % XETH_NTX;
  return 0;
}
// Wait for the oldest queued frame to be sent: 0, 1 if the BD reports an error, -1 on timeout
static inline int xeth_tx_wait(xeth_t *e, unsigned long max_polls) {
  xeth_bd_t *bd = &e->tx_bd[e->tx_tail];
  if (e->tx_tail == e->tx_head) return 0;
  for (unsigned long i = 0; i < max_polls; i++) {
    xeth_mb();
    uint32_t st = bd->status;
    if (st & XBD_STS_CMPLT) { e->tx_tail = (e->tx_tail + 1) % XETH_NTX; return (st & XBD_STS_ERR) ? 1 : 0; }
  }
  return -1;
}
// A received frame? Returns its length (>0) and sets *buf; 0 if none; <0 on a BD error (the BD is recycled)
static inline int xeth_rx(xeth_t *e, uint8_t **buf) {
  xeth_bd_t *bd = &e->rx_bd[e->rx_next];
  xeth_mb();
  uint32_t st = bd->status;
  if (!(st & XBD_STS_CMPLT)) return 0;
  *buf = e->rx_buf[e->rx_next];
  int len = (int)(bd->app[4] & 0xFFFF);
  if (st & XBD_STS_ERR) len = -(int)(st >> 24);
  return len;
}
static inline void xeth_rx_done(xeth_t *e) {              // release the frame xeth_rx returned
  xeth_rx_post(e, e->rx_next);
  e->rx_next = (e->rx_next + 1) % XETH_NRX;
}
static inline int xeth_rx_wait(xeth_t *e, uint8_t **buf, unsigned long max_polls) {
  for (unsigned long i = 0; i < max_polls; i++) { int n = xeth_rx(e, buf); if (n) return n; }
  return 0;
}

// ---------------------------------------------------------------- MAC + PHY
static inline void xeth_set_mac(const uint8_t m[6]) {
  xeth_wr(XAE_UAW0, (uint32_t)m[0] | ((uint32_t)m[1] << 8) | ((uint32_t)m[2] << 16) | ((uint32_t)m[3] << 24));
  xeth_wr(XAE_UAW1, (xeth_rd(XAE_UAW1) & 0xFFFF0000u) | (uint32_t)m[4] | ((uint32_t)m[5] << 8));
}
static inline void xeth_set_speed(int mbps) {
  xeth_wr(XAE_EMMC, mbps == 1000 ? XAE_EMMC_1000 : mbps == 100 ? XAE_EMMC_100 : 0);
}
// MAC on, MDIO on (MDC = clk / (2 * (div + 1)); 50 MHz / 20 = 2.5 MHz), PHYs located. Does not touch the link.
static inline void xeth_mac_init(xeth_t *e, const uint8_t mac[6], int promiscuous) {
  xeth_wr(XAE_RCW1, xeth_rd(XAE_RCW1) & ~XAE_RCW1_RX);
  xeth_wr(XAE_TC,   xeth_rd(XAE_TC)   & ~XAE_TC_TX);
  xeth_wr(XAE_MDIO_MC, XAE_MDIO_MC_EN | 9);
  xeth_wr(XAE_IE, 0);
  xeth_wr(XAE_IS, 0xFFFFFFFFu);
  xeth_set_mac(mac);
  xeth_wr(XAE_FMI, promiscuous ? XAE_FMI_PM : 0);
  xeth_wr(XAE_FCC, 0);
  xeth_set_speed(1000);
  e->phy_addr = e->pcs_addr = -1;
  for (int a = 0; a < 32; a++) {
    int id1 = xeth_mdio_read(a, 2), id2 = xeth_mdio_read(a, 3);
    if (id1 == 0x2000 && (id2 & 0xFFF0) == 0xA230) e->phy_addr = a;        // TI DP83867
    else if (id1 == 0x0174 && id2 == 0x0C00) e->pcs_addr = a;                // Xilinx PCS/PMA (also answers at 0)
  }
  e->link = 0; e->speed = 0;
  xeth_wr(XAE_RCW1, xeth_rd(XAE_RCW1) | XAE_RCW1_RX);
  xeth_wr(XAE_TC,   xeth_rd(XAE_TC)   | XAE_TC_TX);
}
// DP83867 on the VCU118: enable its 625 MHz SGMII clock output (6-wire mode), then a soft reset
static inline int xeth_phy_init(xeth_t *e) {
  if (e->phy_addr < 0) return -1;
  if (xeth_phy_ext_write(e->phy_addr, 0x00D3, 0x4000)) return -1;
  if (xeth_mdio_write(e->phy_addr, 0, 0x9140)) return -1;                    // reset, AN, 1000, full duplex
  for (unsigned i = 0; i < 100000; i++) { int r = xeth_mdio_read(e->phy_addr, 0); if (r >= 0 && !(r & 0x8000)) break; }
  return 0;
}
// The PCS/PMA's management interface only answers once its SGMII clock runs (from the PHY, after SGMIICTL): look
// for it again, for a while. Returns 0 once it answers.
static inline int xeth_pcs_probe(xeth_t *e) {
  for (unsigned i = 0; i < 20000; i++) {
    int id1 = xeth_mdio_read(1, 2), id2 = xeth_mdio_read(1, 3);
    if (id1 == 0x0174 && id2 == 0x0C00) { e->pcs_addr = 1; return 0; }
  }
  return -1;
}
// Read the link state; sets e->link / e->speed and the MAC speed. Returns the link state.
static inline int xeth_phy_link(xeth_t *e) {
  if (e->phy_addr < 0) return 0;
  int bmsr = xeth_mdio_read(e->phy_addr, 1);
  bmsr = xeth_mdio_read(e->phy_addr, 1);                                     // latched-low link bit: read twice
  e->link = (bmsr >= 0) && (bmsr & 0x4);
  int sts = xeth_mdio_read(e->phy_addr, 0x11);                               // PHYSTS: [15:14] speed, bit 10 link
  e->speed = (sts >> 14) == 2 ? 1000 : (sts >> 14) == 1 ? 100 : 10;
  if (e->link) xeth_set_speed(e->speed);
  return e->link;
}
// Loop the PCS/PMA back on itself (frames return without touching the PHY); 0 restores normal operation
static inline int xeth_pcs_loopback(xeth_t *e, int on) {
  if (e->pcs_addr < 0) return -1;
  int r = xeth_mdio_read(e->pcs_addr, 0);
  if (r < 0) return -1;
  return xeth_mdio_write(e->pcs_addr, 0, on ? (r | 0x4000) : (r & ~0x4000));
}
#endif
