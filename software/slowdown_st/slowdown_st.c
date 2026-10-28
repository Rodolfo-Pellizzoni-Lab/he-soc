/*
 * slowdown_st.c — single-core DRAM traffic generator for the slowdown IP.
 *
 * Debug driver for the in-RTL checker in slowdown_mem_top: pushes varied read
 * AND write traffic through LLC -> SPU -> slowdown -> main-memory so the checker
 * (drop / duplication / AXI valid and payload stability / throttle spacing; it
 * also counts same-cycle AR+AW intakes) is exercised, then reports the SPU->PMU
 * MEM_RD/WR counts + cycle cost, checks them and signals end-of-computation so
 * the sim reaches $finish (which triggers the checker's final in-vs-out balance
 * summary).
 *
 * The regions lie outside the LLC's default cached window (0x8000_0000..
 * 0x8080_0000), so every L1 miss is a memory read and every dirty L1 eviction a
 * memory write (16 bytes each). Addresses spaced by 64 KiB map to the SAME L1
 * set (8 ways of 16 B, 16 KB) — and to the same LLC set (16 ways, 1024 sets of
 * 64 B, ariane_soc_pkg.sv) when the window is widened — so touching > 16 of
 * them forces evictions => guaranteed MEM reads (misses) AND MEM writes (dirty
 * write-backs). Three traffic phases keep both AR and AW channels busy to
 * maximise the chance of a same-cycle AR+AW at the slowdown slave port.
 *
 * Checks (TEST PASS/FAIL, exit code = failed checks, as the soc_tests): every
 * distinct line touched is read from memory at least once (2 x CONFLICT_LINES +
 * STREAM_LINES - 1), and at least CONFLICT_LINES dirty lines are written back
 * (phases 1 and 3 dirty 2 x CONFLICT_LINES lines of one set), cached or not.
 *
 * Only hart 0 drives traffic; harts 1-3 park in WFI.
 */

#include "soc_test.h"
#include "encoding.h"
#include <stdio.h>
#include <stdint.h>
#include "utils.h"

extern void exit(int code);   /* from common/syscalls.c -> writes tohost -> EOC */

#define write_32b(a, v) (*(volatile uint32_t *)(long)(a) = (v))
#define read_32b(a)     (*(volatile uint32_t *)(long)(a))

/* ---- PMU / SPU counter block: software/quad_boot/pmu_defines.h ---- */

/* Counters for the SPU event selects MEM_RD_REQ / MEM_WR_REQ (pmu_defines.h):
 * MEM read/write request, all cores aggregate (SPU port 9) */
#define CTR_RD 2
#define CTR_WR 3

/* ---- Traffic knobs (tune here) ---- */
#define LLC_SETS       1024
#define LINE_BYTES     64
#define SET_STRIDE     (LLC_SETS * LINE_BYTES)   /* 64 KiB -> same LLC set        */
#define CONFLICT_LINES 128                        /* > 16 ways -> forces evictions */
#define STREAM_LINES   256                        /* sequential sweep length       */
#define PASSES         3
#define BASE_A         0x82000000UL               /* region A (inside L3 / DRAM)    */
#define BASE_B         0x8A000000UL               /* region B (far from A)          */

static inline uint32_t pmu_rd(int ctr) {
    return read_32b(COUNTER_BASE_ADDR + ctr * COUNTER_BUNDLE_SIZE) & 0x3FFFFFFFU;
}

static void gen_traffic(void) {
    volatile uint64_t *A = (volatile uint64_t *)BASE_A;
    volatile uint64_t *B = (volatile uint64_t *)BASE_B;
    uint64_t v;

    /* Phase 1: set-conflict LD+SD to the SAME line  -> AR(miss) + AW(eviction) */
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < CONFLICT_LINES; i++) {
            volatile uint64_t *l = A + (uint64_t)i * (SET_STRIDE / 8);
            asm volatile ("ld %0, 0(%1)" : "=r"(v) : "r"(l) : "memory");
            asm volatile ("sd %0, 0(%1)" :: "r"(v + p + i), "r"(l) : "memory");
        }

    /* Phase 2: sequential streaming LD+SD  -> sustained miss/writeback traffic  */
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < STREAM_LINES; i++) {
            volatile uint64_t *l = A + (uint64_t)i * (LINE_BYTES / 8);
            asm volatile ("ld %0, 0(%1)" : "=r"(v) : "r"(l) : "memory");
            asm volatile ("sd %0, 0(%1)" :: "r"(v + 1), "r"(l) : "memory");
        }

    /* Phase 3: read region A while writing region B -> keep AR & AW both busy  */
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < CONFLICT_LINES; i++) {
            volatile uint64_t *ra = A + (uint64_t)i * (SET_STRIDE / 8);
            volatile uint64_t *wb = B + (uint64_t)i * (SET_STRIDE / 8);
            asm volatile ("ld %0, 0(%1)" : "=r"(v) : "r"(ra) : "memory");
            asm volatile ("sd %0, 0(%1)" :: "r"(v), "r"(wb) : "memory");
        }

    asm volatile ("fence iorw, iorw" ::: "memory");
}

int thread_entry(int cid, int nc) { (void)cid; (void)nc; return 0; }

int main(void) {
    uint32_t hart;
    asm volatile ("csrr %0, mhartid" : "=r"(hart));
    if (hart != 0) { while (1) asm volatile ("wfi"); }   /* single-core test */

    /* On the board the startup code has set the UART: its DLL is hard-wired, so
     * the divisor for 9600 Bd at 100 MHz (651) would set DLM and garble the
     * console. Only the simulation sets it here. */
#ifndef FPGA_EMULATION
    set_flls();
    uint32_t baud = 115200, freq = 50000000;
    uart_set_cfg(0, (freq / baud) >> 4);
#endif
    soc_test_begin("slowdown_st");

    printf("\r\n[slowdown_st] single-core DRAM traffic (3 phases: conflict / stream / A-rd B-wr)\r\n");

    /* SPU->PMU: count MEM read/write requests (all cores aggregate) */
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_RD * COUNTER_BUNDLE_SIZE, MEM_RD_REQ);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(EVENT_SEL_BASE_ADDR  + CTR_WR * COUNTER_BUNDLE_SIZE, MEM_WR_REQ);
    write_32b(EVENT_INFO_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR + CTR_RD * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR + CTR_WR * COUNTER_BUNDLE_SIZE, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    uint32_t c0 = (uint32_t)read_csr(mcycle);
    gen_traffic();
    uint32_t c1 = (uint32_t)read_csr(mcycle);

    uint32_t mem_rd = pmu_rd(CTR_RD);
    uint32_t mem_wr = pmu_rd(CTR_WR);

    printf("[slowdown_st] SPU MEM_RD = %u   MEM_WR = %u\r\n", mem_rd, mem_wr);
    printf("[slowdown_st] cycles    = %u\r\n", c1 - c0);
    CHECK(mem_rd >= 2 * CONFLICT_LINES + STREAM_LINES - 1, "MEM_RD = %u, below the %d distinct lines touched",
          mem_rd, 2 * CONFLICT_LINES + STREAM_LINES - 1);
    CHECK(mem_wr >= CONFLICT_LINES, "MEM_WR = %u, below the %d write-backs the conflict phases force",
          mem_wr, CONFLICT_LINES);
    printf("[slowdown_st] DONE - signalling EOC; see [slowdown] checker summary below\r\n");
    uart_wait_tx_done();

    exit(soc_test_end());   /* write tohost -> tb detects EOC -> $finish -> checker 'final' summary prints */
    return 0;
}
