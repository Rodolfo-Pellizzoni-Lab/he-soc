/*
 * slowdown_bw.c — single-core BANDWIDTH + LATENCY characterization of the
 * slowdown IP.
 *
 * slowdown_qc proves traffic *flows* through the regulator. This test proves
 * the regulator *enforces its contract*: it measures, on one core, how many
 * cycles each 64-byte main-memory access actually costs, and compares that to
 * the throttle period (throughput) and to a dependent-load chain (latency).
 *
 *   1. Streaming READ  — sequential, cache-line stride, working set > LLC so
 *      every line misses to memory. cycles/line = the sustained read rate the
 *      slowdown allows (bandwidth-limited).
 *   2. Streaming WRITE — same, write-allocate + dirty writeback traffic.
 *   3. Pointer chase   — a dependent load chain (one outstanding request at a
 *      time) hopping >LLC each step, so nothing is cached and nothing overlaps:
 *      cycles/load = the full load-to-use latency, INCLUDING the injected
 *      Latency_param.
 *
 * Single core: only hart 0 runs; the others park in wfi. No PMU-Ibex, no
 * overflow IRQ, no barrier — deliberately the simplest possible harness.
 *
 * Runs on the board (fast) or in RTL sim (reduce N_LINES for sim — see below).
 */

#include "encoding.h"
#include <stdio.h>
#include "utils.h"

extern void exit(int code);   /* common/syscalls.c -> tohost -> EOC/$finish */

#define write_32b(addr, val_) (*(volatile uint32_t *)(long)(addr) = (val_))
#define read_32b(addr)        (*(volatile uint32_t *)(long)(addr))

/* ---- LLC cached-region widen (else traffic bypasses the LLC->slowdown path) */
#define SOC_CTRL_CACHE_END  (0x1A106000UL + 0x1CUL)
#define CACHE_END_VAL       0xA0000000UL

/* ---- PMU: count main-memory (SPU port 9) requests = what crosses the slowdown */
#define PMU_B_BASE_ADDR      0x10405000UL
#define PMU_BUNDLE_SIZE      0x2000
#define COUNTER_B_BASE_ADDR  (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR    (COUNTER_B_BASE_ADDR + 0x0)
#define EVENT_SEL_BASE_ADDR  (COUNTER_B_BASE_ADDR + 0x4)
#define EVENT_INFO_BASE_ADDR (COUNTER_B_BASE_ADDR + 0x8)
#define COUNTER_BUNDLE_SIZE  0x1000
#define MEM_RD_REQ_ALL       0x9F001FUL
#define MEM_WR_REQ_ALL       0x9F002FUL
#define CTR_RD               2          /* counter index for MEM_RD_ALL */
#define CTR_WR               3          /* counter index for MEM_WR_ALL */

/* ---- Expected RTL parameters (for context only; see host_domain.sv) ---- */
#define EXP_THROUGHPUT  10    /* Throughput_timer_param: >=1 request / 10 cyc  */
#define EXP_LATENCY     20    /* Latency_param: +20 cyc added to each response */

/* ---- Working set (disjoint, cached, > LLC). N_LINES is a power of two so the
 *      pointer chase forms a single cycle. 2 MB > 1 MB LLC => every access
 *      misses to memory. For RTL sim, drop N_LINES to e.g. 4096 (256 KB).   */
#define BASE_ADDR    0x82000000UL
#define LINE_BYTES   64
#define WORDS_LINE   (LINE_BYTES / 8)          /* 8 doublewords per line */
#define N_LINES      32768UL                   /* 32768 * 64 B = 2 MB */
#define CHASE_STRIDE 12289UL                   /* odd => coprime with 2^k => single cycle */

static inline uint64_t rd_cycle(void) {
    uint64_t c; asm volatile ("csrr %0, mcycle" : "=r"(c)); return c;
}

/* Sequential read of every line; returns an accumulator so loads are not elided. */
static uint64_t stream_read(volatile uint64_t *base, uint64_t nlines) {
    uint64_t acc = 0, v;
    for (uint64_t i = 0; i < nlines; i++) {
        asm volatile ("ld %0, 0(%1)" : "=r"(v) : "r"(base + i * WORDS_LINE) : "memory");
        acc += v;
    }
    return acc;
}

/* Sequential write of every line. */
static void stream_write(volatile uint64_t *base, uint64_t nlines) {
    for (uint64_t i = 0; i < nlines; i++)
        asm volatile ("sd %0, 0(%1)" :: "r"(i), "r"(base + i * WORDS_LINE) : "memory");
}

int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

int main(void)
{
    uint32_t hart;
    asm volatile ("csrr %0, 0xF14" : "=r"(hart));
    if (hart != 0) { while (1) asm volatile ("wfi"); }   /* single-core test */

    set_flls();
    uart_set_cfg(0, (50000000 / 115200) >> 4);

    /* Cache the whole working set so it crosses the LLC -> SPU -> slowdown path. */
    write_32b(SOC_CTRL_CACHE_END, CACHE_END_VAL);
    asm volatile ("fence iorw, iorw" ::: "memory");

    /* PMU: count main-memory RD / WR requests (plain, no overflow / no IRQ). */
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_RD * COUNTER_BUNDLE_SIZE, MEM_RD_REQ_ALL);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_WR * COUNTER_BUNDLE_SIZE, MEM_WR_REQ_ALL);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    volatile uint64_t *base = (volatile uint64_t *)BASE_ADDR;
    const uint64_t bytes = N_LINES * LINE_BYTES;

    printf("\r\n=== slowdown_bw: single-core characterization ===\r\n");
    printf("  working set : %u KB (%u lines) > 1 MB LLC -> every access misses\r\n",
           (uint32_t)(bytes / 1024), (uint32_t)N_LINES);
    printf("  expected    : throttle ~%d cyc/req, injected latency ~%d cyc\r\n",
           EXP_THROUGHPUT, EXP_LATENCY);
    uart_wait_tx_done();

    /* ---------- 1) streaming READ bandwidth ---------- */
    uint64_t c0 = rd_cycle();
    uint64_t sink = stream_read(base, N_LINES);
    uint64_t rd_cyc = rd_cycle() - c0;

    /* ---------- 2) streaming WRITE bandwidth ---------- */
    c0 = rd_cycle();
    stream_write(base, N_LINES);
    asm volatile ("fence iorw, iorw" ::: "memory");
    uint64_t wr_cyc = rd_cycle() - c0;

    /* ---------- 3) pointer-chase latency (build cycle, then chase) ---------- */
    uint64_t idx = 0;
    for (uint64_t i = 0; i < N_LINES; i++) {
        uint64_t next = (idx + CHASE_STRIDE) & (N_LINES - 1);   /* N_LINES is 2^k */
        base[idx * WORDS_LINE] = (uint64_t)(base + next * WORDS_LINE);
        idx = next;
    }
    asm volatile ("fence iorw, iorw" ::: "memory");
    volatile uint64_t *p = base;
    c0 = rd_cycle();
    for (uint64_t i = 0; i < N_LINES; i++) p = (volatile uint64_t *)(*p);
    uint64_t chase_cyc = rd_cycle() - c0;
    sink += (uint64_t)p;                                        /* keep p live */

    /* ---------- report ---------- */
    uint32_t rd_all = read_32b(COUNTER_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFU;
    uint32_t wr_all = read_32b(COUNTER_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFU;

    printf("\r\n  --- results (cyc/line = achieved cost per 64 B main-memory access) ---\r\n");
    printf("  READ  stream : %u cyc total, %u cyc/line\r\n",
           (uint32_t)rd_cyc,    (uint32_t)(rd_cyc    / N_LINES));
    printf("  WRITE stream : %u cyc total, %u cyc/line\r\n",
           (uint32_t)wr_cyc,    (uint32_t)(wr_cyc    / N_LINES));
    printf("  LATENCY chase: %u cyc total, %u cyc/load  (serial, 1 outstanding)\r\n",
           (uint32_t)chase_cyc, (uint32_t)(chase_cyc / N_LINES));
    printf("  PMU crossing the slowdown: MEM_RD_ALL=%u  MEM_WR_ALL=%u\r\n", rd_all, wr_all);
    printf("  (streaming cyc/line >= %d confirms the throughput cap; chase cyc/load\r\n", EXP_THROUGHPUT);
    printf("   carries the +%d cyc latency injection on top of memory latency)\r\n", EXP_LATENCY);
    printf("  [sink=%u] [slowdown_bw] DONE\r\n", (uint32_t)sink);
    printf("===================================================\r\n");
    uart_wait_tx_done();

    exit(0);
    while (1) asm volatile ("wfi");
}
