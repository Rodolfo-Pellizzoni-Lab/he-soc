// Network boot loader for the SoC on the VCU118: fetches the Linux payload (OpenSBI + kernel, fw_payload.bin) and
// the device tree over the board's Ethernet from a server on the LAN, then jumps to it exactly as the JTAG boot
// does (hart 0: a0 = hart id, a1 = the DTB at 0x8180_0000, payload at 0x8000_0000). Loading over JTAG takes
// minutes; this takes seconds.
//
// Network: DHCP for an address (or a static one, -DSTATIC_IP=...), ARP, ICMP echo replies (the board answers
// ping while it runs), UDP. The server (alsaqr-mcp/scripts/netboot_server.py) is found by a broadcast
// "ALSAQR-NETBOOT?" on UDP port NETBOOT_PORT, or at SERVER_IP if given; it serves the files with TFTP
// (RFC 1350 + blksize 1428, RFC 2348) from that port. The loader runs from DRAM at 0x8F00_0000 (netboot.ld), out
// of the way of what it loads. Everything is polled on hart 0; the other harts stay parked in the boot ROM, as
// Linux here runs with maxcpus=1.
#include <stdint.h>
#include <string.h>
#include "soc_test.h"
#include "xeth.h"

#ifndef NETBOOT_PORT
#define NETBOOT_PORT 6969
#endif
#define OUR_PORT     6970
#define PAYLOAD_ADDR 0x80000000UL
#define DTB_ADDR     0x81800000UL
#define PAYLOAD_FILE "fw_payload.bin"
#define DTB_FILE     "alsaqr.dtb"
#define BLKSIZE      1428
#define CLK_HZ       50000000ULL

static xeth_t eth;
static uint8_t txf[2][XETH_BUF_SIZE] __attribute__((aligned(64)));
static const uint8_t our_mac[6] = { 0x00, 0x0A, 0x35, 0x01, 0x02, 0x03 };
static const uint8_t bcast[6]   = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
static uint32_t our_ip, our_mask, our_gw, server_ip;
static uint8_t  server_mac[6];
static uint16_t tftp_port;                               // the transfer in progress listens here too
static int      have_server_mac;

// ---------------------------------------------------------------- byte helpers (big-endian on the wire)
static inline uint16_t rd16(const uint8_t *p) { return (uint16_t)((p[0] << 8) | p[1]); }
static inline uint32_t rd32(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }
static inline void wr16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)(v >> 8); p[1] = (uint8_t)v; }
static inline void wr32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }
static uint16_t csum(const uint8_t *p, unsigned len, uint32_t acc) {
  for (unsigned i = 0; i + 1 < len; i += 2) acc += rd16(p + i);
  if (len & 1) acc += (uint32_t)p[len - 1] << 8;
  while (acc >> 16) acc = (acc & 0xFFFF) + (acc >> 16);
  return (uint16_t)~acc;
}
static int same(const uint8_t *a, const uint8_t *b, unsigned n) { for (unsigned i = 0; i < n; i++) if (a[i] != b[i]) return 0; return 1; }
static void print_ip(uint32_t ip) { printf("%d.%d.%d.%d", (int)(ip >> 24), (int)((ip >> 16) & 255), (int)((ip >> 8) & 255), (int)(ip & 255)); }
static uint64_t now(void) { return soc_cycles(); }
static int elapsed_ms(uint64_t t0) { return (int)((now() - t0) * 1000 / CLK_HZ); }

// ---------------------------------------------------------------- send
static int send_frame(uint8_t *f, unsigned len) {
  if (xeth_tx(&eth, f, len)) return -1;
  return xeth_tx_wait(&eth, 2000000) ? -1 : 0;
}
static void eth_hdr(uint8_t *f, const uint8_t *dst, uint16_t type) { memcpy(f, dst, 6); memcpy(f + 6, our_mac, 6); wr16(f + 12, type); }
static void ip_hdr(uint8_t *p, uint32_t src, uint32_t dst, uint8_t proto, uint16_t payload_len) {
  p[0] = 0x45; p[1] = 0; wr16(p + 2, 20 + payload_len); wr16(p + 4, 0); wr16(p + 6, 0x4000); p[8] = 64; p[9] = proto;
  wr16(p + 10, 0); wr32(p + 12, src); wr32(p + 16, dst); wr16(p + 10, csum(p, 20, 0));
}
// UDP datagram to (dst_ip, dst_port) via dst_mac; the payload is already at f + 42
static int send_udp(uint8_t *f, const uint8_t *dst_mac, uint32_t src_ip, uint32_t dst_ip, uint16_t sport, uint16_t dport, unsigned len) {
  eth_hdr(f, dst_mac, 0x0800);
  ip_hdr(f + 14, src_ip, dst_ip, 17, (uint16_t)(8 + len));
  wr16(f + 34, sport); wr16(f + 36, dport); wr16(f + 38, (uint16_t)(8 + len)); wr16(f + 40, 0);   // no UDP checksum
  return send_frame(f, 42 + len);
}
static int send_arp(uint16_t op, const uint8_t *dst_mac, const uint8_t *tha, uint32_t tip) {
  uint8_t *f = txf[1];
  eth_hdr(f, dst_mac, 0x0806);
  wr16(f + 14, 1); wr16(f + 16, 0x0800); f[18] = 6; f[19] = 4; wr16(f + 20, op);
  memcpy(f + 22, our_mac, 6); wr32(f + 28, our_ip); memcpy(f + 32, tha, 6); wr32(f + 38, tip);
  return send_frame(f, 60);
}

// ---------------------------------------------------------------- receive: the things we answer by ourselves
// Handles ARP and ICMP; returns the length of a UDP payload for our port (and its details) or 0.
typedef struct { uint32_t src_ip; uint16_t sport, dport; uint8_t src_mac[6]; const uint8_t *data; unsigned len; } udp_rx_t;
static int poll_rx(udp_rx_t *u) {
  uint8_t *rx; int n = xeth_rx(&eth, &rx);
  if (n <= 0) { if (n < 0) xeth_rx_done(&eth); return 0; }
  uint16_t type = rd16(rx + 12);
  int ret = 0;
  if (type == 0x0806 && n >= 42) {                                              // ARP
    if (rd16(rx + 20) == 1 && rd32(rx + 38) == our_ip && our_ip) send_arp(2, rx + 22, rx + 22, rd32(rx + 28));
    else if (rd16(rx + 20) == 2 && rd32(rx + 28) == server_ip) { memcpy(server_mac, rx + 22, 6); have_server_mac = 1; }
  } else if (type == 0x0800 && n >= 34 && (rx[14] >> 4) == 4) {                // IPv4
    unsigned ihl = (rx[14] & 15) * 4, tot = rd16(rx + 16);
    const uint8_t *ip = rx + 14, *l4 = ip + ihl;
    if (tot > (unsigned)n - 14) tot = (unsigned)n - 14;
    if (ip[9] == 1 && l4[0] == 8 && rd32(ip + 16) == our_ip) {                 // ICMP echo -> reply
      uint8_t *f = txf[1]; unsigned plen = tot - ihl;
      if (plen <= XETH_BUF_SIZE - 34) {
        eth_hdr(f, rx + 6, 0x0800);
        ip_hdr(f + 14, our_ip, rd32(ip + 12), 1, (uint16_t)plen);
        memcpy(f + 34, l4, plen); f[34] = 0; wr16(f + 36, 0); wr16(f + 36, csum(f + 34, plen, 0));
        send_frame(f, 34 + plen);
      }
    } else if (ip[9] == 17 && tot >= ihl + 8) {                                 // UDP
      u->src_ip = rd32(ip + 12); u->sport = rd16(l4); u->dport = rd16(l4 + 2);
      memcpy(u->src_mac, rx + 6, 6);
      u->data = l4 + 8; u->len = rd16(l4 + 4) >= 8 ? rd16(l4 + 4) - 8 : 0;
      if (u->len > tot - ihl - 8) u->len = tot - ihl - 8;
      if (u->dport == OUR_PORT || u->dport == 68 || (tftp_port && u->dport == tftp_port)) ret = (int)u->len ? (int)u->len : -1;
    }
  }
  if (ret == 0) xeth_rx_done(&eth);                                            // a UDP datagram stays until used
  return ret;
}
static void rx_release(void) { xeth_rx_done(&eth); }

// ---------------------------------------------------------------- DHCP
static int dhcp(void) {
  uint8_t *f = txf[0]; uint32_t xid = (uint32_t)now() | 1; uint32_t offer = 0, sid = 0;
  for (int attempt = 0; attempt < 4; attempt++) {
    for (int phase = 0; phase < 2; phase++) {                                  // DISCOVER, then REQUEST
      uint8_t *d = f + 42; memset(d, 0, 300);
      d[0] = 1; d[1] = 1; d[2] = 6; wr32(d + 4, xid); wr16(d + 10, 0x8000); memcpy(d + 28, our_mac, 6);
      wr32(d + 236, 0x63825363);
      uint8_t *o = d + 240;
      *o++ = 53; *o++ = 1; *o++ = phase ? 3 : 1;
      *o++ = 61; *o++ = 7; *o++ = 1; memcpy(o, our_mac, 6); o += 6;
      if (phase) { *o++ = 50; *o++ = 4; wr32(o, offer); o += 4; *o++ = 54; *o++ = 4; wr32(o, sid); o += 4; }
      *o++ = 55; *o++ = 3; *o++ = 1; *o++ = 3; *o++ = 6;
      *o++ = 12; *o++ = 6; memcpy(o, "alsaqr", 6); o += 6;
      *o++ = 255;
      unsigned len = (unsigned)(o - d); if (len < 300) len = 300;
      if (send_udp(f, bcast, 0, 0xFFFFFFFFu, 68, 67, len)) return -1;
      uint64_t t0 = now(); int got = 0;
      while (elapsed_ms(t0) < 3000 && !got) {
        udp_rx_t u; int n = poll_rx(&u);
        if (n <= 0) continue;
        const uint8_t *r = u.data;
        if (u.dport == 68 && n >= 240 && r[0] == 2 && rd32(r + 4) == xid) {
          int type = 0; uint32_t mask = 0, gw = 0, srv = 0;
          for (const uint8_t *p = r + 240; p + 1 < r + n && *p != 255; p += 2 + p[1]) {
            if (p[0] == 53) type = p[2];
            else if (p[0] == 1 && p[1] == 4) mask = rd32(p + 2);
            else if (p[0] == 3 && p[1] >= 4) gw = rd32(p + 2);
            else if (p[0] == 54 && p[1] == 4) srv = rd32(p + 2);
          }
          if (!phase && type == 2) { offer = rd32(r + 16); sid = srv; got = 1; }
          if (phase && type == 5)  { our_ip = rd32(r + 16); our_mask = mask; our_gw = gw; got = 1; }
        }
        rx_release();
      }
      if (!got) break;
    }
    if (our_ip) return 0;
  }
  return -1;
}

// ---------------------------------------------------------------- the server
static int resolve(uint32_t ip) {                      // ARP for ip (or the gateway if off-link) into server_mac
  uint32_t target = ((ip & our_mask) == (our_ip & our_mask)) ? ip : our_gw;
  server_ip = ip;
  for (int attempt = 0; attempt < 5 && !have_server_mac; attempt++) {
    uint32_t keep = server_ip; server_ip = target;
    send_arp(1, bcast, (const uint8_t *)"\0\0\0\0\0\0", target);
    uint64_t t0 = now();
    while (elapsed_ms(t0) < 500 && !have_server_mac) { udp_rx_t u; if (poll_rx(&u) > 0) rx_release(); }
    server_ip = keep;
  }
  return have_server_mac ? 0 : -1;
}
static int discover(void) {                             // "ALSAQR-NETBOOT?" broadcast; the server answers "ALSAQR-NETBOOT"
  uint8_t *f = txf[0];
  for (int attempt = 0; attempt < 5; attempt++) {
    memcpy(f + 42, "ALSAQR-NETBOOT?", 15);
    if (send_udp(f, bcast, our_ip, 0xFFFFFFFFu, OUR_PORT, NETBOOT_PORT, 15)) return -1;
    uint64_t t0 = now();
    while (elapsed_ms(t0) < 1000) {
      udp_rx_t u; int n = poll_rx(&u);
      if (n <= 0) continue;
      int ok = (u.dport == OUR_PORT && n >= 14 && same(u.data, (const uint8_t *)"ALSAQR-NETBOOT", 14));
      if (ok) { server_ip = u.src_ip; memcpy(server_mac, u.src_mac, 6); have_server_mac = 1; }
      rx_release();
      if (ok) return 0;
    }
  }
  return -1;
}

// ---------------------------------------------------------------- TFTP read into memory; returns the size or -1
static long tftp_get(const char *name, uint8_t *dst, unsigned long max) {
  uint8_t *f = txf[0];
  uint16_t sport = (uint16_t)(OUR_PORT + 1 + (now() & 0xFF)), tid = 0;
  tftp_port = sport;
  unsigned long got = 0; uint32_t block = 0; unsigned blk = 512; int retries = 0;
  // RRQ with blksize
  {
    uint8_t *p = f + 42; wr16(p, 1); p += 2;
    unsigned nl = strlen(name); memcpy(p, name, nl + 1); p += nl + 1;
    memcpy(p, "octet", 6); p += 6; memcpy(p, "blksize", 8); p += 8;
    p[0] = '1'; p[1] = '4'; p[2] = '2'; p[3] = '8'; p[4] = 0; p += 5;
    if (send_udp(f, server_mac, our_ip, server_ip, sport, NETBOOT_PORT, (unsigned)(p - f - 42))) return -1;
  }
  uint64_t t0 = now(), tlast = t0;
  for (;;) {
    udp_rx_t u; int n = poll_rx(&u);
    if (n == 0) {
      if (elapsed_ms(tlast) > 2000) {                                          // resend the last ACK (or give up)
        if (++retries > 5) { printf("tftp: timeout at block %u\n", (unsigned)block); return -1; }
        if (block) { wr16(f + 42, 4); wr16(f + 44, (uint16_t)block); send_udp(f, server_mac, our_ip, server_ip, sport, tid, 4); }
        tlast = now();
      }
      continue;
    }
    if (n < 0) { rx_release(); continue; }
    if (u.dport != sport || u.src_ip != server_ip || n < 4) { rx_release(); continue; }
    uint16_t op = rd16(u.data);
    if (tid == 0) tid = u.sport;
    if (op == 6) {                                                             // OACK: blksize accepted?
      for (const uint8_t *p = u.data + 2; p < u.data + n;) {
        const char *k = (const char *)p; p += strlen(k) + 1; const char *v = (const char *)p; p += strlen(v) + 1;
        if (strcmp(k, "blksize") == 0) { blk = 0; for (const char *c = v; *c; c++) blk = blk * 10 + (unsigned)(*c - '0'); }
      }
      wr16(f + 42, 4); wr16(f + 44, 0);
      send_udp(f, server_mac, our_ip, server_ip, sport, tid, 4);
      rx_release(); tlast = now(); retries = 0; continue;
    }
    if (op == 5) { printf("tftp: server error %d: %s\n", rd16(u.data + 2), (const char *)u.data + 4); rx_release(); return -1; }
    if (op != 3) { rx_release(); continue; }
    uint16_t bn = rd16(u.data + 2); unsigned dlen = (unsigned)n - 4;
    if (bn == (uint16_t)(block + 1)) {
      if (got + dlen > max) { printf("tftp: %s larger than %u bytes\n", name, (unsigned)max); rx_release(); return -1; }
      memcpy(dst + got, u.data + 4, dlen); got += dlen; block++;
      if ((block & 1023) == 0) printf("  %s: %u KB\r", name, (unsigned)(got >> 10));
    }
    rx_release();
    wr16(f + 42, 4); wr16(f + 44, (uint16_t)block);
    send_udp(f, server_mac, our_ip, server_ip, sport, tid, 4);
    tlast = now(); retries = 0;
    if (dlen < blk) break;
  }
  int ms = elapsed_ms(t0);
  printf("  %s: %u bytes in %d ms (%d KB/s)        \n", name, (unsigned)got, ms, ms ? (int)(got / 1024 * 1000 / (unsigned long)ms) : 0);
  return (long)got;
}

// ---------------------------------------------------------------- go, all four harts
// Hart 0 loads; the others follow it into the payload so that OpenSBI (and Linux) get all four harts, like the JTAG
// flow: hart 1 was parked here by the start-up code (thread_entry below), harts 2 and 3 are still in the boot ROM,
// which wakes them with the APMU interrupts (soc_wake_all) and jumps them to the address in the mailbox, set to
// enter_payload. Every hart arrives in OpenSBI with a0 = hart id and a1 = the DTB; hart 0 goes first and is the
// cold-boot hart, the others wait for hart_go and a little longer (OpenSBI parks warm harts until the cold boot).
static volatile uint32_t hart_go;
static void __attribute__((noreturn, naked)) enter_payload(void) {
  __asm__ volatile(
    "   .option push\n\t"
    "   .option norelax\n\t"                                                 // no gp: the ROM's harts bring their own
    "   la   t2, hart_go\n\t"
    "   .option pop\n\t"
    "1: lw   t0, 0(t2)\n\t"
    "   beqz t0, 1b\n\t"
    "   li   t1, 400000\n\t"
    "2: addi t1, t1, -1\n\t"
    "   bnez t1, 2b\n\t"
    "   csrw mie, zero\n\t"
    "   fence\n\t"
    "   fence.i\n\t"
    "   csrr a0, mhartid\n\t"
    "   li   a1, %0\n\t"
    "   li   t0, %1\n\t"
    "   jr   t0\n\t"
    :: "i"(DTB_ADDR), "i"(PAYLOAD_ADDR));
}
int thread_entry(int cid, int nc) {                                             // harts 1-3 (overrides the weak one)
  (void)nc;
  if (cid == 0) return 0;
  enter_payload();
}
static void __attribute__((noreturn)) jump(void) {
  xeth_wr(XAE_RCW1, xeth_rd(XAE_RCW1) & ~XAE_RCW1_RX);                        // no more DMA into memory
  xdma_reset(XDMA_RX); xdma_reset(XDMA_TX);
  REG32(0x10404000) = (uint32_t)(uintptr_t)enter_payload;                      // the boot ROM's harts jump here
  REG32(0x10404024) = 1;                                                       // hart 1: the mailbox doorbell
  soc_wake_all();                                                              // harts 2 and 3: the APMU interrupts
  uart_wait_tx_done();
  __asm__ volatile("fence");
  hart_go = 1;
  __asm__ volatile("csrw mie, zero\n\tfence\n\tfence.i\n\tcsrr a0, mhartid\n\tli a1, %0\n\tli t0, %1\n\tjr t0"
                   :: "i"(DTB_ADDR), "i"(PAYLOAD_ADDR) : "a0", "a1", "t0");
  for (;;);
}

#ifndef LLC_CACHED_END
#define LLC_CACHED_END 0xA0000000u     // top of the 512 MB DRAM; 0 keeps the boot ROM's 8 MB (the kernel image only)
#endif

int main(void) {
  printf("netboot: Xilinx Ethernet, MAC %02x:%02x:%02x:%02x:%02x:%02x\n", our_mac[0], our_mac[1], our_mac[2], our_mac[3], our_mac[4], our_mac[5]);
  // The LLC caches only 0x8000_0000-0x8080_0000 out of reset (SoC control 0x1A10_6018/1C). Widen it to all of RAM
  // now, while nothing else runs: Linux and its buffers are then LLC-cached (the LLC is the single path to DRAM, so
  // every master stays coherent). Shrinking the range later, on a running system, wedges the SoC, so it is set once here.
  if (LLC_CACHED_END && REG32(0x1A10601C) < LLC_CACHED_END) {
    REG32(0x1A10601C) = LLC_CACHED_END;
    printf("netboot: LLC cached range 0x%x-0x%x\n", REG32(0x1A106018), REG32(0x1A10601C));
  }
  if (xeth_dma_init(&eth)) { printf("netboot: DMA reset failed\n"); return 1; }
  xeth_mac_init(&eth, our_mac, 0);
  if (eth.phy_addr < 0) { printf("netboot: no PHY on MDIO\n"); return 1; }
  xeth_phy_init(&eth);
  uint64_t t0 = now();
  while (!xeth_phy_link(&eth)) {                                          // wait for a cable, however long
    if (elapsed_ms(t0) >= 15000) { printf("netboot: no link yet (cable?)\n"); t0 = now(); }
    for (volatile int d = 0; d < 100000; d++);
  }
  printf("netboot: link up, %d Mb/s\n", eth.speed);
#ifdef STATIC_IP
  our_ip = STATIC_IP; our_mask = STATIC_MASK; our_gw = STATIC_GW;
#else
  while (dhcp()) printf("netboot: DHCP failed, retrying\n");
#endif
  printf("netboot: address "); print_ip(our_ip); printf(" / "); print_ip(our_mask); printf(" gw "); print_ip(our_gw); printf("\n");
  int found;
  for (unsigned round = 1;; round++) {                                    // keep looking for the server, however long
    found = discover();
#ifdef SERVER_IP
    if (found) { printf("netboot: no answer to the broadcast, using the configured server\n"); found = resolve(SERVER_IP); }
#endif
    if (!found) break;
    printf("netboot: no server (round %u)\n", round); xeth_stats_dump("after discovery/ARP");
  }
  printf("netboot: server "); print_ip(server_ip); printf(" port %d\n", NETBOOT_PORT);
  long dtb = tftp_get(DTB_FILE, (uint8_t *)DTB_ADDR, 0x100000);
  if (dtb <= 0) return 1;
  long pl = tftp_get(PAYLOAD_FILE, (uint8_t *)PAYLOAD_ADDR, DTB_ADDR - PAYLOAD_ADDR);
  if (pl <= 0) return 1;
  uint32_t sum = 0;                                                       // additive checksum, printed so the host can compare
  for (long i = 0; i < pl; i++) sum += ((const uint8_t *)PAYLOAD_ADDR)[i];
  uint32_t dsum = 0;
  for (long i = 0; i < dtb; i++) dsum += ((const uint8_t *)DTB_ADDR)[i];
  printf("netboot: payload %u bytes at 0x80000000 (sum %08x), DTB %u bytes at 0x81800000 (sum %08x), jumping\n", (unsigned)pl, (unsigned)sum, (unsigned)dtb, (unsigned)dsum);
  jump();
}
