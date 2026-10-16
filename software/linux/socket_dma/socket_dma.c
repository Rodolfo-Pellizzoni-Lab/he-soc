// socket_dma: drive slot 0 of the accelerator socket (the `example` engine, dst[i] = src[i] + ARG over LEN 64-bit
// words) from Linux user space, with the buffers in memory Linux owns. This is the user-space form of what a
// kernel driver does with dma_alloc_coherent / dma_map_single: hand the device physical addresses, start it,
// wait for the interrupt, use the result. The socket's DMA is a port of the SoC's coherence unit, so the data
// the device reads is what the CPU wrote (even if it still sits dirty in the L1) and what the device wrote is
// what the CPU reads next, without any cache maintenance; this program also checks exactly that.
//
//   socket_dma [pool] [anon] [uio] [irq]        (default: all of them)
//     pool  registers and buffers through /dev/mem; buffers in the reserved DMA pool (device tree
//           reserved-memory "dma-pool@9f000000": 16 MB nobody else uses, physically contiguous)
//     anon  buffers in ordinary memory of this process (one locked page each, physical address from
//           /proc/self/pagemap): the kernel's cached RAM, as a driver's streaming DMA mapping would give it
//     uio   registers mapped through /dev/uio0 (the socket window, device tree node "accel-socket@10000000",
//           driver uio_pdrv_genirq) instead of /dev/mem; buffers as in `anon`
//     irq   completion by the interrupt (PLIC 9 through /dev/uio0) instead of polling STATUS
//   Prints one "SOCKET_DMA <mode> ok|FAIL ..." line per mode; the exit code is the number of failed modes.
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define SOCKET_BASE   0x10000000UL      // slot s at +s*0x10000
#define SLOT          0
#define POOL_BASE     0x9F000000UL      // reserved-memory dma-pool@9f000000 in the device tree
#define PAGE          4096UL
#define N             (PAGE / 8)        // one page of 64-bit words per buffer
#define ARG           0x11u
#define EXAMPLE_ID    0xAC0C9B9Fu

#define R_CTRL   0x00
#define R_STATUS 0x04
#define R_SRC_LO 0x08
#define R_DST_LO 0x10
#define R_LEN    0x18
#define R_ARG    0x1C
#define R_ID     0x20
#define R_CYCLES 0x24

static volatile uint32_t *regs;        // slot 0 registers
static int uio_fd = -1;

static inline void     wr(unsigned off, uint32_t v) { regs[off / 4] = v; }
static inline uint32_t rd(unsigned off)             { return regs[off / 4]; }
static inline void     fence(void)                  { __asm__ volatile("fence" ::: "memory"); }

static double now_us(void) {
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e6 + t.tv_nsec / 1e3;
}

static uint64_t pat(uint32_t round, unsigned i) { return 0x0101010100000000ULL * round + 0x1000ULL * (i + 1) + i; }

// physical address of a page of this process (it must be resident: touched and locked)
static uint64_t phys_of(void *va) {
  int fd = open("/proc/self/pagemap", O_RDONLY);
  if (fd < 0) { perror("/proc/self/pagemap"); exit(2); }
  uint64_t entry;
  if (pread(fd, &entry, 8, ((uintptr_t)va / PAGE) * 8) != 8) { perror("pagemap read"); exit(2); }
  close(fd);
  if (!(entry & (1ULL << 63))) { fprintf(stderr, "page %p not present\n", va); exit(2); }
  return (entry & ((1ULL << 55) - 1)) * PAGE + ((uintptr_t)va % PAGE);
}

static void *map_phys(int memfd, uint64_t pa, size_t len) {
  void *p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, pa);
  if (p == MAP_FAILED) { perror("mmap /dev/mem"); exit(2); }
  return p;
}

static void *anon_page(void) {
  void *p = mmap(NULL, PAGE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE | MAP_LOCKED, -1, 0);
  if (p == MAP_FAILED) { perror("mmap anon"); exit(2); }
  memset(p, 0, PAGE);
  return p;
}

// one transfer: returns the engine's cycle count, or -1 if it never finished
static long run(uint64_t src_pa, uint64_t dst_pa, int use_irq) {
  wr(R_SRC_LO, (uint32_t)src_pa); wr(R_SRC_LO + 4, (uint32_t)(src_pa >> 32));
  wr(R_DST_LO, (uint32_t)dst_pa); wr(R_DST_LO + 4, (uint32_t)(dst_pa >> 32));
  wr(R_LEN, N);
  wr(R_ARG, ARG);
  fence();                                                     // buffer writes are issued before the start
  if (use_irq) {
    uint32_t one = 1, count = 0;
    if (write(uio_fd, &one, 4) != 4) { perror("uio enable"); return -1; }    // the UIO interrupt is enabled
    wr(R_CTRL, 0x3);                                           // START + IRQ_EN
    if (read(uio_fd, &count, 4) != 4) { perror("uio read"); return -1; }    // blocks until PLIC 9 fires
    if (!(rd(R_STATUS) & 0x2)) { fprintf(stderr, "interrupt without DONE, STATUS 0x%x\n", rd(R_STATUS)); return -1; }
  } else {
    wr(R_CTRL, 0x1);
    for (long i = 0; i < 10000000; i++) if ((rd(R_STATUS) & 0x3) == 0x2) break;
    if ((rd(R_STATUS) & 0x3) != 0x2) return -1;
  }
  fence();
  long cycles = rd(R_CYCLES);
  wr(R_STATUS, 0x2);                                           // clear DONE (drops the interrupt line)
  return cycles;
}

// the transfer with the CPU-side checks: how many words came out right with no cache maintenance at all
static int check(const char *mode, volatile uint64_t *src, volatile uint64_t *dst, uint64_t src_pa, uint64_t dst_pa,
                 int use_irq, uint32_t round) {
  for (unsigned i = 0; i < N; i++) { src[i] = pat(round, i); dst[i] = 0; }
  double t0 = now_us();
  long cycles = run(src_pa, dst_pa, use_irq);
  double us = now_us() - t0;
  if (cycles < 0) { printf("SOCKET_DMA %s FAIL: the engine did not finish (STATUS 0x%x)\n", mode, rd(R_STATUS)); return 1; }
  unsigned fresh = 0, zero = 0;
  for (unsigned i = 0; i < N; i++) {
    if (dst[i] == pat(round, i) + ARG) fresh++;
    else if (dst[i] == 0) zero++;
  }
  // a second pass with fence.i (the only cache maintenance CVA6 has: write back + invalidate the whole L1)
  // tells a stale read from a lost write when the hardware is not coherent
  __asm__ volatile("fence.i" ::: "memory");
  unsigned fresh_fi = 0;
  for (unsigned i = 0; i < N; i++) if (dst[i] == pat(round, i) + ARG) fresh_fi++;
  int ok = (fresh == N);
  printf("SOCKET_DMA %s %s: %u/%lu words correct without maintenance (%u still the old value), %u after fence.i; "
         "%ld engine cycles, %.0f us; src 0x%lx dst 0x%lx\n",
         mode, ok ? "ok" : "FAIL", fresh, N, zero, fresh_fi, cycles, us, (unsigned long)src_pa, (unsigned long)dst_pa);
  return !ok;
}

int main(int argc, char **argv) {
  int do_pool = 0, do_anon = 0, do_uio = 0, do_irq = 0, fails = 0;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "pool")) do_pool = 1; else if (!strcmp(argv[i], "anon")) do_anon = 1;
    else if (!strcmp(argv[i], "uio")) do_uio = 1; else if (!strcmp(argv[i], "irq")) do_irq = 1;
    else { fprintf(stderr, "usage: socket_dma [pool] [anon] [uio] [irq]\n"); return 2; }
  }
  if (!do_pool && !do_anon && !do_uio && !do_irq) do_pool = do_anon = do_uio = do_irq = 1;

  int memfd = open("/dev/mem", O_RDWR | O_SYNC);
  if (memfd < 0) { perror("/dev/mem"); return 2; }
  regs = map_phys(memfd, SOCKET_BASE + SLOT * 0x10000, PAGE);
  if (rd(R_ID) != EXAMPLE_ID) { printf("SOCKET_DMA FAIL: slot 0 ID 0x%x, expected the example engine 0x%x\n", rd(R_ID), EXAMPLE_ID); return 2; }
  if (rd(R_STATUS) & 0x1) { printf("SOCKET_DMA FAIL: slot 0 busy\n"); return 2; }
  wr(R_STATUS, 0x2);

  if (do_pool) {
    volatile uint64_t *src = map_phys(memfd, POOL_BASE, PAGE), *dst = map_phys(memfd, POOL_BASE + PAGE, PAGE);
    fails += check("pool", src, dst, POOL_BASE, POOL_BASE + PAGE, 0, 1);
  }
  if (do_anon) {
    volatile uint64_t *src = anon_page(), *dst = anon_page();
    fails += check("anon", src, dst, phys_of((void *)src), phys_of((void *)dst), 0, 2);
  }
  if (do_uio || do_irq) {
    uio_fd = open("/dev/uio0", O_RDWR);
    if (uio_fd < 0) { perror("/dev/uio0"); printf("SOCKET_DMA uio FAIL: no /dev/uio0 (device tree node accel-socket, uio_pdrv_genirq.of_id=generic-uio)\n"); return fails + 1; }
    volatile uint32_t *win = mmap(NULL, 0x400000, PROT_READ | PROT_WRITE, MAP_SHARED, uio_fd, 0);   // map 0 = the socket window
    if (win == MAP_FAILED) { perror("mmap /dev/uio0"); return fails + 1; }
    regs = win + (SLOT * 0x10000) / 4;
    if (rd(R_ID) != EXAMPLE_ID) { printf("SOCKET_DMA uio FAIL: ID 0x%x through /dev/uio0\n", rd(R_ID)); return fails + 1; }
    if (do_uio) {
      volatile uint64_t *src = anon_page(), *dst = anon_page();
      fails += check("uio", src, dst, phys_of((void *)src), phys_of((void *)dst), 0, 3);
    }
    if (do_irq) {
      volatile uint64_t *src = anon_page(), *dst = anon_page();
      fails += check("irq", src, dst, phys_of((void *)src), phys_of((void *)dst), 1, 4);
    }
  }
  printf("SOCKET_DMA %s\n", fails ? "FAIL" : "PASS");
  return fails;
}
