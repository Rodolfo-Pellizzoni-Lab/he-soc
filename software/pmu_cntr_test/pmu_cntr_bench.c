/*
 * pmu_cntr_bench.c
 *
 * Wakeup (unchanged):
 *   Core 0  : PLIC + PMU counters 0/1 overflow IRQs → wakes cores 2/3
 *   Core 1  : woken by mailbox IRQ (_init)
 *   Core 2  : woken by PMU counter 0 overflow → PLIC IRQ 156
 *   Core 3  : woken by PMU counter 1 overflow → PLIC IRQ 157
 *
 * PMU event counters (2-19, configured by core 0 after wakeup):
 *   Ctr 2-5  : LLC RD request, cores 0-3  (SPU ports 5-8)
 *   Ctr 6-9  : LLC WR request, cores 0-3
 *   Ctr10-13 : MEM RD request, cores 0-3  (SPU port 9, src 4-7)
 *   Ctr14-17 : MEM WR request, cores 0-3
 *   Ctr 18   : MEM RD request, all cores aggregate
 *   Ctr 19   : MEM WR request, all cores aggregate
 *
 * Traffic: each core traverses its own 320 KB region in L3 starting at
 *   0x82000000 + hartid * 0x01000000  (no overlap between cores)
 *   Pattern: LD + SD per cache line (both read and write traffic).
 *   Tune ARRAY_LEN to adjust LLC/MEM traffic volume.
 */

#include "encoding.h"
#include <stdio.h>
#include <string.h>
#include "utils.h"

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
/* PMU addresses                                                       */
/* ------------------------------------------------------------------ */
#define PMU_B_BASE_ADDR     0x10405000UL
#define PMU_BUNDLE_SIZE     0x2000
#define COUNTER_B_BASE_ADDR (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR   (COUNTER_B_BASE_ADDR + 0x0)
#define EVENT_SEL_BASE_ADDR (COUNTER_B_BASE_ADDR + 0x4)
#define EVENT_INFO_BASE_ADDR (COUNTER_B_BASE_ADDR + 0x8)
#define COUNTER_BUNDLE_SIZE 0x1000
#define OVERFLOW_EN         0x01000000UL

/* ------------------------------------------------------------------ */
/* PLIC                                                                */
/* ------------------------------------------------------------------ */
#define PLIC_BASE       0x0C000000UL
#define PMU_PLIC_ID1    156
#define PMU_PLIC_ID2    157
#define PLIC_EN_BITS1   (PLIC_BASE + 0x2280UL)
#define PLIC_EN_BITS2   (PLIC_BASE + 0x2380UL)

/* ------------------------------------------------------------------ */
/* PMU event selects (counters 2-19; 0/1 reserved for wakeup)        */
/* ------------------------------------------------------------------ */
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

#define NUM_PMU_CTRS  18
#define PMU_CTR_FIRST  2

static const uint32_t event_sel[NUM_PMU_CTRS] = {
    LLC_RD_REQ_CORE_0, LLC_RD_REQ_CORE_1, LLC_RD_REQ_CORE_2, LLC_RD_REQ_CORE_3,
    LLC_WR_REQ_CORE_0, LLC_WR_REQ_CORE_1, LLC_WR_REQ_CORE_2, LLC_WR_REQ_CORE_3,
    MEM_RD_REQ_CORE_0, MEM_RD_REQ_CORE_1, MEM_RD_REQ_CORE_2, MEM_RD_REQ_CORE_3,
    MEM_WR_REQ_CORE_0, MEM_WR_REQ_CORE_1, MEM_WR_REQ_CORE_2, MEM_WR_REQ_CORE_3,
    MEM_RD_REQ_ALL, MEM_WR_REQ_ALL,
};

static const char *ctr_name[NUM_PMU_CTRS] = {
    "LLC_RD_C0", "LLC_RD_C1", "LLC_RD_C2", "LLC_RD_C3",
    "LLC_WR_C0", "LLC_WR_C1", "LLC_WR_C2", "LLC_WR_C3",
    "MEM_RD_C0", "MEM_RD_C1", "MEM_RD_C2", "MEM_RD_C3",
    "MEM_WR_C0", "MEM_WR_C1", "MEM_WR_C2", "MEM_WR_C3",
    "MEM_RD_ALL", "MEM_WR_ALL",
};

/* ------------------------------------------------------------------ */
/* Array traversal — mirrors pmu_L3_test_v2/pmu_test.c               */
/* 40960 elem * 8B stride = 320 KB per core; tune ARRAY_LEN as needed */
/* ------------------------------------------------------------------ */
#define ARRAY_LEN    8192
#define ARRAY_STRIDE 8      /* step in uint64_t → 64-byte cache-line stride */

static void traverse_array(uint32_t hartid)
{
    uint64_t var = 0;
    volatile uint64_t *arr =
        (volatile uint64_t *)(0x82000000UL + (uint64_t)hartid * 0x01000000UL);

    for (int i = 0; i < ARRAY_LEN; i += ARRAY_STRIDE) {
        asm volatile ("ld %0, 0(%1)" : "=r"(var) : "r"(arr - i) : "memory");
        asm volatile ("sd %0, 0(%1)" :: "r"(var), "r"(arr - i) : "memory");
    }
}

/* ------------------------------------------------------------------ */
/* Inter-core synchronisation (L3, volatile — no AMO needed)          */
/* ------------------------------------------------------------------ */
volatile int pmu_go       = 0;
volatile int cores_done[4] = {0, 0, 0, 0};

/* ------------------------------------------------------------------ */
/* thread_entry — let all cores reach main()                          */
/* ------------------------------------------------------------------ */
int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */
int main(int argc, char const *argv[])
{
    uint32_t mhartid;
    asm volatile ("csrr %0, 0xF14" : "=r"(mhartid));

    /* ==============================================================
     * CORE 0
     * ============================================================== */
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

        lock_uart();
        printf("Hello from Core 0!\r\n");
        uart_wait_tx_done();
        unlock_uart();

        /* --- Wakeup: fire PMU counters 0/1 overflow --- */
        write_32b(PLIC_BASE + PMU_PLIC_ID1 * 4, 1);
        write_32b(PLIC_EN_BITS1 + ((PMU_PLIC_ID1 / 32) * 4), 1U << (PMU_PLIC_ID1 % 32));
        write_32b(PLIC_BASE + PMU_PLIC_ID2 * 4, 1);
        write_32b(PLIC_EN_BITS2 + ((PMU_PLIC_ID2 / 32) * 4), 1U << (PMU_PLIC_ID2 % 32));

        write_32b(EVENT_INFO_BASE_ADDR,                       OVERFLOW_EN);
        write_32b(COUNTER_BASE_ADDR,                          0x40000000U);
        write_32b(EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE, OVERFLOW_EN);
        write_32b(COUNTER_BASE_ADDR   + COUNTER_BUNDLE_SIZE,  0x40000000U);

        lock_uart();
        printf("PMU wakeup IRQs fired (IRQ156->Core2, IRQ157->Core3)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        /* --- Configure PMU event counters 2-19 ---
         * Pass 1: write event selects (INFO=0 → count only, no overflow)
         * Pass 2: reset counters to 0 for a clean start just before go  */
        for (int i = 0; i < NUM_PMU_CTRS; i++) {
            int n = PMU_CTR_FIRST + i;
            write_32b(EVENT_SEL_BASE_ADDR  + n * COUNTER_BUNDLE_SIZE, event_sel[i]);
            write_32b(EVENT_INFO_BASE_ADDR + n * COUNTER_BUNDLE_SIZE, 0);
        }
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            write_32b(COUNTER_BASE_ADDR + (PMU_CTR_FIRST + i) * COUNTER_BUNDLE_SIZE, 0);

        asm volatile ("fence iorw, iorw" ::: "memory");

        lock_uart();
        printf("PMU counters 2-19 configured — starting traffic\r\n");
        uart_wait_tx_done();
        unlock_uart();

        /* Signal all cores to start, then run core 0's own traversal */
        pmu_go = 1;
        asm volatile ("fence iorw, iorw" ::: "memory");

        traverse_array(0);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[0] = 1;

        /* Wait for cores 1-3 to finish */
        for (int c = 1; c <= 3; c++)
            while (!cores_done[c]) asm volatile ("nop");
        asm volatile ("fence iorw, iorw" ::: "memory");

        /* --- Snapshot all counters then print --- */
        uint32_t ctr_val[NUM_PMU_CTRS];
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            ctr_val[i] = read_32b(COUNTER_BASE_ADDR + (PMU_CTR_FIRST + i) * COUNTER_BUNDLE_SIZE);

        lock_uart();
        printf("\r\n=== PMU Counter Results (ARRAY_LEN=%d, cache lines/core=%d) ===\r\n",
               ARRAY_LEN, ARRAY_LEN / ARRAY_STRIDE);
        for (int i = 0; i < NUM_PMU_CTRS; i++)
            printf("  Ctr%2d [%-12s]: %u\r\n",
                   PMU_CTR_FIRST + i, ctr_name[i], ctr_val[i] & 0x3FFFFFFFU);
        printf("=============================================================\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (1) asm volatile ("wfi");

    /* ==============================================================
     * CORE 1 — woken by mbox IRQ
     * ============================================================== */
    } else if (mhartid == 1) {

        lock_uart();
        printf("Hello from Core 1!\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        traverse_array(1);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[1] = 1;
        while (1) asm volatile ("wfi");

    /* ==============================================================
     * CORE 2 — woken by PMU IRQ 156
     * ============================================================== */
    } else if (mhartid == 2) {

        lock_uart();
        printf("Hello from Core 2! (PMU IRQ 156)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        traverse_array(2);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[2] = 1;
        while (1) asm volatile ("wfi");

    /* ==============================================================
     * CORE 3 — woken by PMU IRQ 157
     * ============================================================== */
    } else if (mhartid == 3) {

        lock_uart();
        printf("Hello from Core 3! (PMU IRQ 157)\r\n");
        uart_wait_tx_done();
        unlock_uart();

        while (!pmu_go) asm volatile ("nop");
        traverse_array(3);
        asm volatile ("fence iorw, iorw" ::: "memory");
        cores_done[3] = 1;
        while (1) asm volatile ("wfi");

    } else {
        while (1) asm volatile ("wfi");
    }

    return 0;
}
