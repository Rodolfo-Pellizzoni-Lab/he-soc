/*
 * slowdown_st.c — single-core DRAM traffic generator for the slowdown IP.
 *
 * Purpose (debug stage 1): push a small, reproducible amount of read AND write
 * traffic through the LLC -> SPU -> slowdown -> main-memory path so the in-RTL
 * checker in slowdown_mem_top (drop / duplication / AXI valid-stability, and the
 * AR+AW simultaneity hazard) is exercised, and report the SPU->PMU MEM_RD/WR
 * request counts + cycle cost.
 *
 * Trick: the LLC is 16-way, 1024 sets, 64 B line (1 MB) — see ariane_soc_pkg.sv.
 * Addresses spaced by LLC_SETS*LINE = 64 KiB map to the SAME set, so touching
 * > 16 of them forces evictions. That yields guaranteed MEM reads (misses) AND
 * MEM writes (dirty write-backs) with only a handful of accesses => fast sim.
 *
 * Only hart 0 generates traffic; harts 1-3 park in WFI (deterministic single
 * requester — the AR+AW hazard, if present, still shows because reads and
 * write-backs interleave on this one master).
 *
 * The RTL checker is the authoritative drop/dup detector (it verifies in==out);
 * the PMU MEM counts here are for MEASURING the throttle/latency effect.
 */

#include "encoding.h"
#include <stdio.h>
#include <stdint.h>
#include "utils.h"

#define write_32b(a, v) (*(volatile uint32_t *)(long)(a) = (v))
#define read_32b(a)     (*(volatile uint32_t *)(long)(a))

/* ---- PMU / SPU counter block (same layout as pmu_cntr_test) ---- */
#define PMU_B_BASE_ADDR      0x10405000UL
#define PMU_BUNDLE_SIZE      0x2000
#define COUNTER_B_BASE_ADDR  (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR    (COUNTER_B_BASE_ADDR + 0x0)
#define EVENT_SEL_BASE_ADDR  (COUNTER_B_BASE_ADDR + 0x4)
#define EVENT_INFO_BASE_ADDR (COUNTER_B_BASE_ADDR + 0x8)
#define COUNTER_BUNDLE_SIZE  0x1000

/* SPU event selects: MEM read/write request, all cores aggregate (SPU port 9) */
#define MEM_RD_REQ_ALL 0x9F001FUL
#define MEM_WR_REQ_ALL 0x9F002FUL
#define CTR_RD 2
#define CTR_WR 3

/* ---- Traffic knobs (tune here) ---- */
#define LLC_SETS     1024
#define LINE_BYTES   64
#define SET_STRIDE   (LLC_SETS * LINE_BYTES)   /* 64 KiB -> same LLC set        */
#define N_LINES      128                        /* > 16 ways -> forces evictions */
#define PASSES       3
#define TRAFFIC_BASE 0x82000000UL               /* inside L3 / DRAM              */

static inline uint32_t pmu_rd(int ctr) {
    return read_32b(COUNTER_BASE_ADDR + ctr * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFU;
}

static void gen_traffic(void) {
    volatile uint64_t *base = (volatile uint64_t *)TRAFFIC_BASE;
    for (int p = 0; p < PASSES; p++) {
        for (int i = 0; i < N_LINES; i++) {
            volatile uint64_t *line = base + (uint64_t)i * (SET_STRIDE / 8);
            uint64_t v;
            asm volatile ("ld %0, 0(%1)" : "=r"(v) : "r"(line) : "memory"); /* miss  -> MEM read  */
            asm volatile ("sd %0, 0(%1)" :: "r"(v + p + i), "r"(line) : "memory"); /* dirty -> MEM write */
        }
    }
    asm volatile ("fence iorw, iorw" ::: "memory");
}

int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

int main(void) {
    uint32_t hart;
    asm volatile ("csrr %0, mhartid" : "=r"(hart));
    if (hart != 0) { while (1) asm volatile ("wfi"); }   /* single-core test */

#ifdef FPGA_EMULATION
    uint32_t baud = 9600, freq = 100000000;
#else
    set_flls();
    uint32_t baud = 115200, freq = 50000000;
#endif
    uart_set_cfg(0, (freq / baud) >> 4);

    printf("\r\n[slowdown_st] single-core DRAM traffic (LLC set-conflict stride)\r\n");

    /* SPU->PMU: count MEM read/write requests (all cores aggregate) */
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_RD * COUNTER_BUNDLE_SIZE, MEM_RD_REQ_ALL);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_WR * COUNTER_BUNDLE_SIZE, MEM_WR_REQ_ALL);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    uint32_t c0 = (uint32_t)read_csr(mcycle);
    gen_traffic();
    uint32_t c1 = (uint32_t)read_csr(mcycle);

    uint32_t mem_rd = pmu_rd(CTR_RD);
    uint32_t mem_wr = pmu_rd(CTR_WR);

    printf("[slowdown_st] accesses = %d  (%d lines x %d passes, LD+SD each)\r\n",
           2 * N_LINES * PASSES, N_LINES, PASSES);
    printf("[slowdown_st] SPU MEM_RD = %u   MEM_WR = %u\r\n", mem_rd, mem_wr);
    printf("[slowdown_st] cycles    = %u\r\n", c1 - c0);
    printf("[slowdown_st] DONE - see transcript for [slowdown] checker msgs + summary\r\n");
    uart_wait_tx_done();

    while (1) asm volatile ("wfi");
    return 0;
}
