/*
 * slowdown_bw.c — single-core cost of a main-memory access through the
 * slowdown IP.
 *
 * slowdown_qc proves traffic *flows* through the regulator. This test measures,
 * on one core, how many cycles each 64-byte main-memory access costs, in three
 * phases that each start from empty caches (fence.i writes the L1 back and
 * empties it, the LLC's CfgFlush does the same for the LLC), so every line
 * misses to memory whatever the working-set size:
 *
 *   1. Streaming READ  — sequential, cache-line stride.
 *   2. Streaming WRITE — the same with stores (write-allocate refills), then the
 *      write-back of its dirty lines (the next flush, which also walks all of
 *      the LLC's lines).
 *   3. Pointer chase   — a dependent load chain (one outstanding request at a
 *      time) over the same lines: cycles/load = the full load-to-use latency of
 *      a miss, INCLUDING the injected Latency_param.
 *
 * One core has one data-cache miss in flight (the WB cache's miss handler has a
 * single MSHR), so the streams also pay a whole miss latency per line: all three
 * are latency-bound costs, not bandwidth, and a single core never reaches the
 * throttle (one request per Throughput_timer_param + 1 cycles). Each phase
 * reports its main-memory requests (SPU port 9, what crosses the slowdown) and
 * its cycles per request.
 *
 * Checks (TEST PASS/FAIL, exit code = failed checks, as the soc_tests): every
 * line of every phase reached main memory, i.e. the numbers above are memory
 * accesses and not cache hits.
 *
 * Single core: only hart 0 runs; the others park in wfi. No PMU-Ibex, no
 * overflow IRQ, no barrier — deliberately the simplest possible harness.
 *
 * Runs on the board (fpga=1: 2 MB) or in RTL sim (64 KB, see N_LINES).
 */

#include "soc_test.h"
#include "encoding.h"
#include <stdio.h>
#include "utils.h"

extern void exit(int code);   /* common/syscalls.c -> tohost -> EOC/$finish */

#define write_32b(addr, val_) (*(volatile uint32_t *)(long)(addr) = (val_))
#define read_32b(addr)        (*(volatile uint32_t *)(long)(addr))

/* ---- LLC cached-region widen (else traffic passes the LLC uncached, as 16-byte L1 fills) */
#define SOC_CTRL_CACHE_END  (0x1A106000UL + 0x1CUL)
#define CACHE_END_VAL       0xA0000000UL
#define LLC_FLUSH           0x10401008UL  /* LLC CfgFlush: one bit per way, cleared by the LLC when done */
#define FLUSH_MAX           400000000ULL  /* cycles before the flush wait gives up (as t_part) */

/* ---- PMU: count main-memory (SPU port 9) requests = what crosses the slowdown
 *      (counter map and the MEM_RD_REQ / MEM_WR_REQ selects: software/quad_boot/pmu_defines.h) */
#define CTR_RD               2          /* counter index for MEM_RD_REQ */
#define CTR_WR               3          /* counter index for MEM_WR_REQ */

/* ---- Expected RTL parameters (for context only; see host_domain.sv) ---- */
#define EXP_THROUGHPUT  11    /* Throughput_timer_param 10: accepted requests >= 11 cyc apart */
#define EXP_LATENCY     20    /* Latency_param: +20 cyc added to each response */

/* ---- Working set (disjoint, cached). N_LINES is a power of two so the
 *      pointer chase forms a single cycle. The flushes make every line miss,
 *      so the RTL-sim size need not exceed the 1 MB LLC. */
#define BASE_ADDR    0x82000000UL
#define LINE_BYTES   64
#define WORDS_LINE   (LINE_BYTES / 8)          /* 8 doublewords per line */
#ifdef FPGA_EMULATION
#define N_LINES      32768UL                   /* 32768 * 64 B = 2 MB */
#else
#define N_LINES      1024UL                    /* 1024 * 64 B = 64 KB */
#endif
#define CHASE_STRIDE 12289UL                   /* odd => coprime with 2^k => single cycle */

static inline uint64_t rd_cycle(void) {
    uint64_t c; asm volatile ("csrr %0, mcycle" : "=r"(c)); return c;
}

static inline uint32_t pmu_rd(int ctr) {
    return read_32b(COUNTER_BASE_ADDR + ctr * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFU;
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

/* Empty both cache levels: fence.i writes the WB L1 back and invalidates it (a
 * plain fence does not: the L1 is coherent), CfgFlush writes back and empties
 * all 16 LLC ways. Returns 0 once the LLC reports the flush done. */
static int caches_flush(void) {
    asm volatile ("fence.i" ::: "memory");
    write_32b(LLC_FLUSH, 0xFFFF);
    uint64_t t0 = rd_cycle();
    while (read_32b(LLC_FLUSH) != 0) if (rd_cycle() - t0 > FLUSH_MAX) return -1;
    return 0;
}

/* One measured phase: cycles and main-memory requests between begin and end. */
typedef struct { uint64_t c0, cyc; uint32_t rd0, wr0, rd, wr; } phase_t;

static void phase_begin(phase_t *p) {
    asm volatile ("fence iorw, iorw" ::: "memory");
    p->rd0 = pmu_rd(CTR_RD);
    p->wr0 = pmu_rd(CTR_WR);
    p->c0  = rd_cycle();
}

static void phase_end(phase_t *p) {
    asm volatile ("fence iorw, iorw" ::: "memory");
    p->cyc = rd_cycle() - p->c0;
    p->rd  = pmu_rd(CTR_RD) - p->rd0;
    p->wr  = pmu_rd(CTR_WR) - p->wr0;
}

static void report(const char *name, const phase_t *p, const char *per) {
    uint32_t req = p->rd + p->wr;
    printf("  %s: %u cyc, %u cyc/%s | memory: %u RD + %u WR, %u cyc/request\r\n", name, (uint32_t)p->cyc,
           (uint32_t)(p->cyc / N_LINES), per, p->rd, p->wr, req ? (uint32_t)(p->cyc / req) : 0);
}

int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

int main(void)
{
    uint32_t hart;
    asm volatile ("csrr %0, 0xF14" : "=r"(hart));
    if (hart != 0) { while (1) asm volatile ("wfi"); }   /* single-core test */

    /* On the board the startup code has set the UART (its DLL is hard-wired);
     * only the simulation sets it here. */
#ifndef FPGA_EMULATION
    set_flls();
    uart_set_cfg(0, (50000000 / 115200) >> 4);
#endif
    soc_test_begin("slowdown_bw");

    /* Cache the whole working set so it crosses the LLC -> SPU -> slowdown path. */
    write_32b(SOC_CTRL_CACHE_END, CACHE_END_VAL);
    asm volatile ("fence iorw, iorw" ::: "memory");

    /* PMU: count main-memory RD / WR requests (plain, no overflow / no IRQ). */
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_RD * COUNTER_BUNDLE_SIZE, MEM_RD_REQ);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_WR * COUNTER_BUNDLE_SIZE, MEM_WR_REQ);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    volatile uint64_t *base = (volatile uint64_t *)BASE_ADDR;
    const uint64_t bytes = N_LINES * LINE_BYTES;
    phase_t rd, wr, wb, ch;

    printf("\r\n=== slowdown_bw: single-core cost of a main-memory access ===\r\n");
    printf("  working set : %u KB (%u lines), caches flushed before each phase -> every line misses\r\n",
           (uint32_t)(bytes / 1024), (uint32_t)N_LINES);
    printf("  expected    : throttle >= %d cyc/req, injected latency ~%d cyc\r\n",
           EXP_THROUGHPUT, EXP_LATENCY);
    uart_wait_tx_done();

    /* ---------- 1) streaming READ ---------- */
    CHECK(caches_flush() == 0, "LLC flush before the READ stream did not finish");
    phase_begin(&rd);
    uint64_t sink = stream_read(base, N_LINES);
    phase_end(&rd);

    /* ---------- 2) streaming WRITE, then the write-back of its dirty lines ---------- */
    CHECK(caches_flush() == 0, "LLC flush before the WRITE stream did not finish");
    phase_begin(&wr);
    stream_write(base, N_LINES);
    phase_end(&wr);
    phase_begin(&wb);
    CHECK(caches_flush() == 0, "LLC flush writing back the WRITE stream did not finish");
    phase_end(&wb);

    /* ---------- 3) pointer-chase latency (build cycle, flush, then chase) ---------- */
    uint64_t idx = 0;
    for (uint64_t i = 0; i < N_LINES; i++) {
        uint64_t next = (idx + CHASE_STRIDE) & (N_LINES - 1);   /* N_LINES is 2^k */
        base[idx * WORDS_LINE] = (uint64_t)(base + next * WORDS_LINE);
        idx = next;
    }
    asm volatile ("fence iorw, iorw" ::: "memory");
    CHECK(caches_flush() == 0, "LLC flush before the chase did not finish");
    volatile uint64_t *p = base;
    phase_begin(&ch);
    for (uint64_t i = 0; i < N_LINES; i++) p = (volatile uint64_t *)(*p);
    phase_end(&ch);
    sink += (uint64_t)p;                                        /* keep p live */

    /* ---------- report ---------- */
    printf("\r\n  --- results (cyc/line = cost of one 64 B main-memory access, one miss in flight) ---\r\n");
    report("READ  stream ", &rd, "line");
    report("WRITE stream ", &wr, "line");
    report("write-back   ", &wb, "line");
    report("LATENCY chase", &ch, "load");
    printf("  (latency-bound, not bandwidth: one core cannot reach the throttle's %d cyc/request;\r\n",
           EXP_THROUGHPUT);
    printf("   the chase cyc/load carries the +%d cyc latency injection on top of memory latency)\r\n",
           EXP_LATENCY);

    /* every line of every phase crossed the slowdown to main memory */
    CHECK(rd.rd >= N_LINES, "READ stream: %u memory reads for %u lines", rd.rd, (uint32_t)N_LINES);
    CHECK(wr.rd >= N_LINES, "WRITE stream: %u write-allocate reads for %u lines", wr.rd, (uint32_t)N_LINES);
    CHECK(wr.wr + wb.wr >= N_LINES, "WRITE: %u memory writes for %u dirty lines", wr.wr + wb.wr,
          (uint32_t)N_LINES);
    CHECK(ch.rd >= N_LINES, "chase: %u memory reads for %u loads", ch.rd, (uint32_t)N_LINES);
    printf("  [sink=%u] [slowdown_bw] DONE\r\n", (uint32_t)sink);
    printf("===================================================\r\n");
    uart_wait_tx_done();

    exit(soc_test_end());
    while (1) asm volatile ("wfi");
}
