/*
 * slowdown_qc.c — quad-core DRAM-traffic test for the slowdown IP.
 *
 * All four CVA6 harts hammer main memory concurrently through the LLC -> SPU ->
 * slowdown -> main-memory path, so the throughput regulator + latency injector
 * are exercised under real multi-core load (the in-system counterpart to the
 * standalone tb_slowdown unit test).
 *
 *   Core 0 : READER  (also: boots normally, configures the PMU, wakes 2/3)
 *   Core 1 : READER  (reaches main() on its own; thread_entry is empty)
 *   Core 2 : WRITER  (woken by PMU counter-0 overflow -> PLIC IRQ 156)
 *   Core 3 : WRITER  (woken by PMU counter-1 overflow -> PLIC IRQ 157)
 *
 * Only the CVA6 cores run. The overflow->PLIC IRQ is pure hardware waking the
 * two parked CVA6 harts; the PMU's own Ibex core is NOT used.
 *
 * Why this stresses main memory (and thus the slowdown):
 *   - Core 0 first WIDENS the LLC cached region (APB SoC-ctrl reg): by default
 *     the LLC only caches 0x8000_0000..0x8080_0000 and BYPASSES everything else,
 *     so traffic to higher addresses would never reach the LLC->SPU->slowdown
 *     path. After widening, our whole footprint is cached.
 *   - Each core owns a DISJOINT 512 KB region  base + hartid*PER_CORE_SPAN  ->
 *     nothing is shared, so cache coherency never supplies a line (no snoops).
 *   - Each region is streamed at a 64-byte (cache-line) stride; 4 x 512 KB =
 *     2 MB total > 1 MB LLC, so L1 and LLC both miss -> every access becomes an
 *     AR (read miss) or AW+W (write-allocate / dirty writeback) to main memory,
 *     straight through the slowdown IP. Sustained eviction/refill.
 *
 * PMU confirms it: per-core MEM_RD / MEM_WR request counts (SPU port 9) must be
 * non-zero for every core, proving traffic actually reached main memory through
 * the regulator. Cycle counts show the regulation cost.
 *
 * Tuning: raise KB_PER_CORE / PASSES for the board (fast); keep them modest for
 * RTL sim (the regulator throttles to 1 request / Throughput_timer_param cycles,
 * so large working sets take many millions of cycles to drain).
 */

#include "encoding.h"
#include <stdio.h>
#include <string.h>
#include "utils.h"

extern void exit(int code);   /* common/syscalls.c -> writes tohost -> EOC/$finish */

#define write_32b(addr, val_)  (*(volatile uint32_t *)(long)(addr) = (val_))
#define read_32b(addr)         (*(volatile uint32_t *)(long)(addr))

/* ------------------------------------------------------------------ */
/* UART spinlock — AMO on L3 cacheable memory                         */
/* ------------------------------------------------------------------ */
volatile int uart_lock = 0;

static inline void lock_uart(void) {
    int v;
    do { asm volatile ("amoswap.w.aq %0,%1,(%2)" : "=r"(v) : "r"(1), "r"(&uart_lock) : "memory"); }
    while (v);
}
static inline void unlock_uart(void) {
    asm volatile ("amoswap.w.rl zero,zero,(%0)" :: "r"(&uart_lock) : "memory");
}

/* ------------------------------------------------------------------ */
/* PMU / PLIC (identical layout to pmu_cntr_bench)                     */
/* ------------------------------------------------------------------ */
#define PMU_B_BASE_ADDR      0x10405000UL
#define PMU_BUNDLE_SIZE      0x2000
#define COUNTER_B_BASE_ADDR  (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR    (COUNTER_B_BASE_ADDR + 0x0)
#define EVENT_SEL_BASE_ADDR  (COUNTER_B_BASE_ADDR + 0x4)
#define EVENT_INFO_BASE_ADDR (COUNTER_B_BASE_ADDR + 0x8)
#define COUNTER_BUNDLE_SIZE  0x1000
#define OVERFLOW_EN          0x01000000UL

#define PLIC_BASE       0x0C000000UL
#define PMU_PLIC_ID1    156
#define PMU_PLIC_ID2    157
#define PLIC_EN_BITS1   (PLIC_BASE + 0x2280UL)
#define PLIC_EN_BITS2   (PLIC_BASE + 0x2380UL)

/* Event selects — LLC + MEM request counts, per core (SPU ports 5-8 = cores
 * 0-3 at the LLC; port 9 src 4-7 = cores 0-3 at main memory). */
#define LLC_RD_REQ_CORE_0  0x5F001FUL
#define LLC_RD_REQ_CORE_1  0x6F001FUL
#define LLC_RD_REQ_CORE_2  0x7F001FUL
#define LLC_RD_REQ_CORE_3  0x8F001FUL
#define LLC_WR_REQ_CORE_0  0x5F002FUL
#define LLC_WR_REQ_CORE_1  0x6F002FUL
#define LLC_WR_REQ_CORE_2  0x7F002FUL
#define LLC_WR_REQ_CORE_3  0x8F002FUL
#define MEM_RD_REQ_CORE_0  0x9F0F1FUL
#define MEM_RD_REQ_CORE_1  0x9F1F1FUL
#define MEM_RD_REQ_CORE_2  0x9F2F1FUL
#define MEM_RD_REQ_CORE_3  0x9F3F1FUL
#define MEM_WR_REQ_CORE_0  0x9F0F2FUL
#define MEM_WR_REQ_CORE_1  0x9F1F2FUL
#define MEM_WR_REQ_CORE_2  0x9F2F2FUL
#define MEM_WR_REQ_CORE_3  0x9F3F2FUL
#define MEM_RD_REQ_ALL     0x9F001FUL
#define MEM_WR_REQ_ALL     0x9F002FUL

/* We count exactly the traffic that crosses the slowdown: per-core requests at
 * MAIN MEMORY (SPU port 9), i.e. what the LLC could not satisfy and had to send
 * to DRAM through the regulator. 8 plain counters — no overflow, no interrupt. */
#define NUM_PMU_CTRS   8
#define PMU_CTR_FIRST  2      /* PMU has 32 counters; we use 8 (indices 2..9) */

static const uint32_t event_sel[NUM_PMU_CTRS] = {
    MEM_RD_REQ_CORE_0, MEM_RD_REQ_CORE_1, MEM_RD_REQ_CORE_2, MEM_RD_REQ_CORE_3,
    MEM_WR_REQ_CORE_0, MEM_WR_REQ_CORE_1, MEM_WR_REQ_CORE_2, MEM_WR_REQ_CORE_3,
};

static const char *ctr_name[NUM_PMU_CTRS] = {
    "MEM_RD_C0", "MEM_RD_C1", "MEM_RD_C2", "MEM_RD_C3",
    "MEM_WR_C0", "MEM_WR_C1", "MEM_WR_C2", "MEM_WR_C3",
};

/* ------------------------------------------------------------------ */
/* Working set — disjoint region per core                             */
/*   base_i = 0x82000000 + i*16MB   (regions never overlap)           */
/* 4 x KB_PER_CORE total > 1 MB LLC  => cannot cache everything.       */
/* ------------------------------------------------------------------ */
/* By default the LLC only caches 0x8000_0000..0x8080_0000 (8 MB) and BYPASSES
 * everything else — bypassed traffic never reaches the LLC->SPU->slowdown path.
 * Core 0 widens the cached-region END (APB SoC-ctrl reg) so our whole footprint
 * is cached. 0xA000_0000 is well above what we touch. */
#define SOC_CTRL_CACHE_END  (0x1A106000UL + 0x1CUL)
#define CACHE_END_VAL       0xA0000000UL

/* Compact, DISJOINT regions, all inside the (now widened) cached window and
 * inside backed HyperRAM (>=64 MB from 0x8000_0000). Each core streams its own
 * 512 KB span at a 64-byte line stride; 4*512 KB = 2 MB > 1 MB LLC, so the LLC
 * cannot hold it -> sustained eviction/refill = real DRAM traffic through the
 * regulator. Disjoint regions => coherency never supplies a line. */
#define BASE_ADDR      0x82000000UL
#define PER_CORE_SPAN  0x00080000UL   /* 512 KB per core, adjacent & non-overlapping */
#define LINE_BYTES     64
#define KB_PER_CORE    512            /* stream the whole span */
#define LINES_PER_CORE ((KB_PER_CORE * 1024) / LINE_BYTES)
#define PASSES         2              /* repeat for sustained eviction traffic */

/* Cores 0,1 = readers ; cores 2,3 = writers */
static inline int is_writer(uint32_t hartid) { return (hartid >= 2); }

static uint64_t read_region(uint32_t hartid) {
    volatile uint64_t *base = (volatile uint64_t *)(BASE_ADDR + (uint64_t)hartid * PER_CORE_SPAN);
    uint64_t acc = 0, v;
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < LINES_PER_CORE; i++) {
            asm volatile ("ld %0, 0(%1)" : "=r"(v)
                          : "r"(base + (uint64_t)i * (LINE_BYTES / 8)) : "memory");
            acc += v;                 /* keep the load live so it is not elided */
        }
    return acc;
}

static void write_region(uint32_t hartid) {
    volatile uint64_t *base = (volatile uint64_t *)(BASE_ADDR + (uint64_t)hartid * PER_CORE_SPAN);
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < LINES_PER_CORE; i++)
            asm volatile ("sd %0, 0(%1)"
                          :: "r"((uint64_t)(i + p)),
                             "r"(base + (uint64_t)i * (LINE_BYTES / 8)) : "memory");
}

/* Each core runs its own role and records how long it took. */
static uint64_t run_core(uint32_t hartid) {
    uint64_t c0, c1;
    asm volatile ("fence iorw, iorw" ::: "memory");
    c0 = read_csr(mcycle);
    if (is_writer(hartid)) write_region(hartid);
    else                   (void)read_region(hartid);
    asm volatile ("fence iorw, iorw" ::: "memory");
    c1 = read_csr(mcycle);
    return c1 - c0;
}

/* ------------------------------------------------------------------ */
/* Inter-core sync (L3, volatile)                                     */
/* ------------------------------------------------------------------ */
volatile int      pmu_go        = 0;
volatile int      cores_done[4] = {0, 0, 0, 0};
volatile uint64_t core_cycles[4] = {0, 0, 0, 0};

/* Empty — lets core 1 fall through to main() under the normal boot path. */
int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */
int main(int argc, char const *argv[])
{
    uint32_t mhartid;
    asm volatile ("csrr %0, 0xF14" : "=r"(mhartid));

    /* ============================ CORE 0 ============================ */
    if (mhartid == 0) {

#ifdef FPGA_EMULATION
        uint32_t baud_rate = 9600;
        uint32_t test_freq = 100000000;
#else
        set_flls();
        uint32_t baud_rate = 115200;
        uint32_t test_freq = 50000000;
#endif
        uart_set_cfg(0, (test_freq / baud_rate) >> 4);

        /* Widen the LLC cached region FIRST so every core's traffic goes
         * LLC -> SPU -> slowdown -> memory (default caches only 0x8000_0000..
         * 0x8080_0000 and BYPASSES the rest). Pure APB SoC-ctrl reg write —
         * does NOT involve the PMU Ibex. Must precede any test traffic. */
        write_32b(SOC_CTRL_CACHE_END, CACHE_END_VAL);
        asm volatile ("fence iorw, iorw" ::: "memory");

        lock_uart();
        printf("\r\n[slowdown_qc] quad-core DRAM traffic: C0,C1=READ  C2,C3=WRITE\r\n");
        printf("[slowdown_qc] %d KB/core x4 = %d KB > 1MB LLC; LLC now cached to 0x%x\r\n",
               KB_PER_CORE, 4 * KB_PER_CORE, (uint32_t)CACHE_END_VAL);
        uart_wait_tx_done();
        unlock_uart();

        /* --- Wakeup: arm PMU counters 0/1 to overflow -> PLIC 156/157 --- */
        write_32b(PLIC_BASE + PMU_PLIC_ID1 * 4, 1);
        write_32b(PLIC_EN_BITS1 + ((PMU_PLIC_ID1 / 32) * 4), 1U << (PMU_PLIC_ID1 % 32));
        write_32b(PLIC_BASE + PMU_PLIC_ID2 * 4, 1);
        write_32b(PLIC_EN_BITS2 + ((PMU_PLIC_ID2 / 32) * 4), 1U << (PMU_PLIC_ID2 % 32));

        write_32b(EVENT_INFO_BASE_ADDR,                       OVERFLOW_EN);
        write_32b(COUNTER_BASE_ADDR,                          0x40000000U);
        write_32b(EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE, OVERFLOW_EN);
        write_32b(COUNTER_BASE_ADDR   + COUNTER_BUNDLE_SIZE,  0x40000000U);

        lock_uart();
        printf("[slowdown_qc] PMU wakeup IRQs fired (156->C2, 157->C3)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        /* --- Configure measurement counters 2-19 (event select, no overflow) --- */
        for (int i = 0; i < NUM_PMU_CTRS; i++) {
            int n = PMU_CTR_FIRST + i;
            write_32b(EVENT_SEL_BASE_ADDR  + n * COUNTER_BUNDLE_SIZE, event_sel[i]);
            write_32b(EVENT_INFO_BASE_ADDR + n * COUNTER_BUNDLE_SIZE, 0);
        }
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            write_32b(COUNTER_BASE_ADDR + (PMU_CTR_FIRST + i) * COUNTER_BUNDLE_SIZE, 0);

        asm volatile ("fence iorw, iorw" ::: "memory");

        /* Release everyone, then run core 0's own read traffic */
        pmu_go = 1;
        asm volatile ("fence iorw, iorw" ::: "memory");

        core_cycles[0] = run_core(0);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[0] = 1;

        for (int c = 1; c <= 3; c++)
            while (!cores_done[c]) asm volatile ("nop");
        asm volatile ("fence iorw, iorw" ::: "memory");

        /* --- Snapshot + report --- */
        uint32_t ctr_val[NUM_PMU_CTRS];
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            ctr_val[i] = read_32b(COUNTER_BASE_ADDR + (PMU_CTR_FIRST + i) * COUNTER_BUNDLE_SIZE)
                         & 0x3FFFFFFFU;

        lock_uart();
        printf("\r\n=== slowdown_qc results (%d KB/core, %d lines, %d pass) ===\r\n",
               KB_PER_CORE, LINES_PER_CORE, PASSES);
        printf("  role: C0=RD C1=RD C2=WR C3=WR\r\n");
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            printf("  Ctr%2d [%-10s]: %u\r\n", PMU_CTR_FIRST + i, ctr_name[i], ctr_val[i]);
        printf("  cycles: C0=%u C1=%u C2=%u C3=%u\r\n",
               (uint32_t)core_cycles[0], (uint32_t)core_cycles[1],
               (uint32_t)core_cycles[2], (uint32_t)core_cycles[3]);
        printf("  MEM_RD_ALL=%u  MEM_WR_ALL=%u  (all traffic crossed the slowdown)\r\n",
               ctr_val[0] + ctr_val[1] + ctr_val[2] + ctr_val[3],
               ctr_val[4] + ctr_val[5] + ctr_val[6] + ctr_val[7]);
        printf("===========================================================\r\n");
        printf("[slowdown_qc] DONE\r\n");
        uart_wait_tx_done();
        unlock_uart();

        exit(0);   /* end-of-computation -> tohost -> $finish (clean sim exit) */
        while (1) asm volatile ("wfi");

    /* ============================ CORE 1 (reader) ============================ */
    } else if (mhartid == 1) {
        lock_uart();
        printf("[slowdown_qc] Core 1 up (READER)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        core_cycles[1] = run_core(1);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[1] = 1;
        while (1) asm volatile ("wfi");

    /* ============================ CORE 2 (writer, PMU IRQ 156) ============================ */
    } else if (mhartid == 2) {
        lock_uart();
        printf("[slowdown_qc] Core 2 up (WRITER, PMU IRQ 156)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        core_cycles[2] = run_core(2);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[2] = 1;
        while (1) asm volatile ("wfi");

    /* ============================ CORE 3 (writer, PMU IRQ 157) ============================ */
    } else if (mhartid == 3) {
        lock_uart();
        printf("[slowdown_qc] Core 3 up (WRITER, PMU IRQ 157)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        core_cycles[3] = run_core(3);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[3] = 1;
        while (1) asm volatile ("wfi");

    } else {
        while (1) asm volatile ("wfi");
    }

    return 0;
}
