/*
 * PMU EVU Bench — Exhaustive CVA6-EVU Test, Two-Function Profiler
 *
 * Proves:
 *   1. Ibex reads/writes CVA6-EVU registers (EID0-EID3 at 0x10606000)
 *   2. EVU pipeline events (L1D miss, stalls, branches) count correctly
 *   3. Two distinct functions are profiled — entry AND exit PC milestones gate
 *      each window, so events accumulate ONLY between entry and exit
 *   4. func_alu_chain (short, pure ALU) vs func_l1_cold (large, 512 cold loads)
 *      produce visibly different event profiles
 *
 * Architecture:
 *   CVA6  : loads firmware, configures PMU counter bundles (event selectors),
 *           triggers Ibex, runs phase 1 (alu) with per-call sync, then
 *           waits for Ibex to arm phase 2, runs phase 2 (cold), prints results.
 *
 *   Ibex  : writes EVU EIDs, programs PC milestone slot 0 = FUNC_ALU_ENTRY,
 *           profiles N_CALLS_SHORT alu entry/exit pairs, transitions milestone
 *           to FUNC_COLD_ENTRY, profiles N_CALLS_LONG cold entry/exit pairs.
 *           All results written to DSPM slots 0-7.
 *
 * DSPM result layout (slots 0-3 = alu, slots 4-7 = cold):
 *   +0x08 + N*0x30: slot N, each 0x30 bytes:
 *       [0x00] delta_cycles      (Ibex mcycle — overhead only, not CVA6 duration)
 *       [0x04] delta_l1d_miss   (EVU EV0, EID=0x02)
 *       [0x08] delta_stalls     (EVU EV2, EID=0x16)
 *       [0x0C] delta_branches   (EVU EV3, EID=0x09)
 *       [0x10] delta_llc_rd     (ctr 4)
 *       [0x14] delta_llc_wr     (ctr 8)
 *       [0x18] delta_mem_rd     (ctr 12)
 *       [0x1C] delta_mem_wr     (ctr 16)
 *       [0x20] delta_mem_rd_lat (ctr 27)
 *       [0x24] delta_mem_wr_lat (ctr 28)
 *       [0x28] entry_mcycle
 *       [0x2C] exit_mcycle
 */

#include "encoding.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "utils.h"
#include "pmu_test_func.c"

#define NUM_CORES       4
#define N_CALLS_SHORT   4   // func_alu_chain profiling calls
#define N_CALLS_LONG    4   // func_l1_cold profiling calls
#define N_CALLS_TOTAL   (N_CALLS_SHORT + N_CALLS_LONG)

// Cacheable memory base addresses
#define CORE0_DATA_BASE   0x81000000
#define CACHE_LINE_SIZE   64

// DSPM communication
#define DSPM_STATUS_ADDR  (DSPM_BASE_ADDR + 0x00)
#define DSPM_CMD_ADDR     (DSPM_BASE_ADDR + 0x80)

// DSPM log (must match firmware layout)
#define DSPM_LOG_BASE        (DSPM_BASE_ADDR + 0x2000)
#define DSPM_LOG_CALL_COUNT  (DSPM_LOG_BASE + 0x00)
#define DSPM_LOG_STATE       (DSPM_LOG_BASE + 0x04)
#define DSPM_LOG_SLOT(n)     (DSPM_LOG_BASE + 0x08 + (n) * 0x30)
#define DSPM_LOG_PHASE       (DSPM_LOG_BASE + 0x200)  // 1=alu active, 2=cold active

// Slot aliases for clarity
#define ALU_SLOT(n)   DSPM_LOG_SLOT(n)
#define COLD_SLOT(n)  DSPM_LOG_SLOT(N_CALLS_SHORT + (n))

// Status and command codes (must match firmware)
#define STATUS_STARTED        0xBB000001
#define STATUS_ALL_IRQS_SENT  0xBB000099
#define CMD_TRIGGER_INTERRUPT 0x000000FF

// External symbols for PMU firmware binary
extern unsigned char _binary_text_section_bin_start[];
extern unsigned char _binary_text_section_bin_end[];
extern unsigned char _binary_data_rodata_bss_bin_start[];
extern unsigned char _binary_data_rodata_bss_bin_end[];

void enable_llc(void) {
    write_32b(0x1C + 0x1A106000, 0xA0000000);
}

void partition_cache_4cores(void) {
    write_32b(0x10401040, 0xF0FF0FFF);
    write_32b(0x10401044, 0xFF0FFFF0);
    asm volatile ("fence iorw, iorw" ::: "memory");
}

// =====================================================================
// func_alu_chain: SHORT function — pure Fibonacci chain, N_ALU_ITER=128
//   Expected: 0 L1D misses, 0 LLC_RD, ~N_ALU_ITER branches, few stalls
//   Must be long enough (~500+ cycles) for Ibex to reprogram PC milestone
//   between entry and exit hits.
// =====================================================================
#define N_ALU_ITER  128

void __attribute__((noinline)) func_alu_chain(void) {
    uint32_t a = 1, b = 1, c = 0;
    for (uint32_t i = 0; i < N_ALU_ITER; i++) {
        c = a + b;
        a = b;
        b = c;
    }
    asm volatile ("" : : "r"(b) : );  // prevent dead-code elimination
}

// =====================================================================
// func_l1_cold: LARGE function — 512 cold loads, each at 64B stride
//   Expected: ~512 L1D misses, ~512 LLC_RD, >10000 cycles
// =====================================================================
#define N_ITER    512
#define CL_WORDS  16   // 64B / 4B

#define BASE         ((volatile uint32_t *)CORE0_DATA_BASE)
#define REGION_COLD  (BASE)
#define REGION_FLUSH (BASE + N_ITER * CL_WORDS)

void __attribute__((noinline)) func_l1_cold(void) {
    uint32_t sum = 0;
    for (uint32_t i = 0; i < N_ITER; i++)
        sum = REGION_COLD[i * CL_WORDS];
    (void)sum;
}

static void flush_l1_dcache(void) {
    volatile uint32_t sink = 0;
    for (uint32_t i = 0; i < N_ITER; i++)
        sink += REGION_FLUSH[i * CL_WORDS];
    (void)sink;
}

void thread_entry(int cid, int nc) { return; }

// =====================================================================
// print_results: print per-call table and average for a group of N slots
// =====================================================================
static void print_results(const char *label, uint32_t base_slot, uint32_t n) {
    const char *names[10] = {
        "Cycles(Ibex)", "L1D_misses", "Stalls", "Branches",
        "LLC_RD", "LLC_WR", "MEM_RD", "MEM_WR", "RdLat", "WrLat"
    };

    printf("  --- %s ---\r\n", label);
    printf("    %-16s", "Metric");
    for (uint32_t i = 0; i < n; i++)
        printf("   call%u", i);
    printf("     avg\r\n");

    uint32_t vals[n][10];
    uint32_t totals[10] = {0};
    for (uint32_t i = 0; i < n; i++) {
        uint32_t slot = DSPM_LOG_SLOT(base_slot + i);
        for (uint32_t m = 0; m < 10; m++) {
            vals[i][m] = read_32b(slot + m * 4);
            totals[m] += vals[i][m];
        }
    }

    for (uint32_t m = 0; m < 10; m++) {
        printf("    %-16s", names[m]);
        for (uint32_t i = 0; i < n; i++)
            printf(" %7u", vals[i][m]);
        printf(" %7u\r\n", totals[m] / n);
    }

    printf("    --- entry/exit mcycle ---\r\n");
    for (uint32_t i = 0; i < n; i++) {
        uint32_t slot = DSPM_LOG_SLOT(base_slot + i);
        uint32_t e = read_32b(slot + 0x28);
        uint32_t x = read_32b(slot + 0x2C);
        printf("    call%u: entry=%u  exit=%u  delta=%u\r\n", i, e, x, x - e);
    }
}

int main(int argc, char const *argv[]) {
    uint32_t mhartid;
    asm volatile ("csrr %0, 0xF14" : "=r"(mhartid));
    if (mhartid != 0) { while (1) asm volatile ("wfi"); }

    // UART setup
    #ifdef FPGA_EMULATION
    uint32_t baud_rate = 9600;
    uint32_t test_freq = 100000000;
    #else
    set_flls();
    uint32_t baud_rate = 115200;
    uint32_t test_freq = 50000000;
    #endif
    uart_set_cfg(0, (test_freq / baud_rate) >> 4);

    printf("\r\n========================================\r\n");
    printf("PMU EVU Bench — Exhaustive CVA6-EVU Test\r\n");
    printf("  Phase 1: func_alu_chain x%u (N_ALU_ITER=%u)\r\n", N_CALLS_SHORT, N_ALU_ITER);
    printf("  Phase 2: func_l1_cold   x%u (N_ITER=%u)\r\n",    N_CALLS_LONG,  N_ITER);
    printf("  Ibex configures EVU EIDs; CVA6 sets counter event selectors\r\n");
    printf("========================================\r\n");

    // ================================================================
    // [1] Load PMU firmware into ISPM/DSPM
    // ================================================================
    printf("[1] Loading PMU firmware...\r\n");

    uint32_t text_size = _binary_text_section_bin_end - _binary_text_section_bin_start;
    uint32_t data_size = _binary_data_rodata_bss_bin_end - _binary_data_rodata_bss_bin_start;

    write_32b(PMC_STATUS_ADDR, 1);
    asm volatile ("fence iorw, iorw" ::: "memory");

    write_32b(PERIOD_ADDR, 0xFFFFFFFF);
    write_32b(PERIOD_ADDR + 4, 0xFFFFFFFF);
    asm volatile ("fence iorw, iorw" ::: "memory");

    for (uint32_t i = 0; i < 0x200; i += 4)
        write_32b(DSPM_BASE_ADDR + i, 0);

    if (text_size > 0 && text_size < 4096) {
        memcpy((void*)ISPM_BASE_ADDR, _binary_text_section_bin_start, text_size);
        memcpy((void*)(DSPM_BASE_ADDR + 0x200), _binary_data_rodata_bss_bin_start, data_size);
        asm volatile ("fence iorw, iorw" ::: "memory");
        printf("    Firmware loaded (text=%u, data=%u bytes)\r\n", text_size, data_size);
    } else {
        printf("    ERROR: Invalid firmware size (text=%u)\r\n", text_size);
        while (1) asm volatile ("wfi");
    }

    write_32b(PMC_BOOT_ADDR, ISPM_BASE_ADDR);
    write_32b(PMC_STATUS_ADDR, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    printf("[2] Waiting for PMU to start...\r\n");
    uint32_t timeout = 10000;
    while (read_32b(DSPM_STATUS_ADDR) != STATUS_STARTED && timeout > 0)
        timeout--;
    if (timeout == 0) {
        printf("    TIMEOUT (status=0x%08x)\r\n", read_32b(DSPM_STATUS_ADDR));
        while (1) asm volatile ("wfi");
    }
    printf("    PMU started!\r\n");

    // ================================================================
    // [3] Enable LLC and configure PMU counter bundles
    //     CVA6 sets event selectors on counter bundles.
    //     CVA6 does NOT write EVENTID_C0_BASE_ADDR — Ibex owns that.
    // ================================================================
    enable_llc();
    partition_cache_4cores();

    // LLC and MEM counters for all cores
    uint32_t llc_rd_ev[NUM_CORES] = { LLC_RD_REQ_CORE_0, LLC_RD_REQ_CORE_1, LLC_RD_REQ_CORE_2, LLC_RD_REQ_CORE_3 };
    uint32_t llc_wr_ev[NUM_CORES] = { LLC_WR_REQ_CORE_0, LLC_WR_REQ_CORE_1, LLC_WR_REQ_CORE_2, LLC_WR_REQ_CORE_3 };
    uint32_t mem_rd_ev[NUM_CORES] = { MEM_RD_REQ_CORE_0, MEM_RD_REQ_CORE_1, MEM_RD_REQ_CORE_2, MEM_RD_REQ_CORE_3 };
    uint32_t mem_wr_ev[NUM_CORES] = { MEM_WR_REQ_CORE_0, MEM_WR_REQ_CORE_1, MEM_WR_REQ_CORE_2, MEM_WR_REQ_CORE_3 };
    uint32_t *grp_ev[4] = { llc_rd_ev, llc_wr_ev, mem_rd_ev, mem_wr_ev };
    uint32_t  grp_base[4] = { 4, 8, 12, 16 };

    for (uint32_t g = 0; g < 4; g++)
        for (uint32_t core = 0; core < NUM_CORES; core++) {
            uint32_t idx = grp_base[g] + core;
            write_32b(EVENT_SEL_BASE_ADDR  + idx * COUNTER_BUNDLE_SIZE, grp_ev[g][core]);
            write_32b(EVENT_INFO_BASE_ADDR + idx * COUNTER_BUNDLE_SIZE, 0);
            write_32b(COUNTER_BASE_ADDR    + idx * COUNTER_BUNDLE_SIZE, 0);
        }

    // Counter 20: PC milestone (EVU EV1, EID1=0x17 — programmed by Ibex)
    write_32b(EVENT_SEL_BASE_ADDR  + 20 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV1);
    write_32b(EVENT_INFO_BASE_ADDR + 20 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 20 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 21: L1D misses (EVU EV0, EID0=0x02 — programmed by Ibex)
    write_32b(EVENT_SEL_BASE_ADDR  + 21 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV0);
    write_32b(EVENT_INFO_BASE_ADDR + 21 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 21 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 22: pipeline stalls (EVU EV2, EID2=0x16 — programmed by Ibex)
    write_32b(EVENT_SEL_BASE_ADDR  + 22 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV2);
    write_32b(EVENT_INFO_BASE_ADDR + 22 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 22 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 23: branch instructions (EVU EV3, EID3=0x09 — programmed by Ibex)
    write_32b(EVENT_SEL_BASE_ADDR  + 23 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV3);
    write_32b(EVENT_INFO_BASE_ADDR + 23 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 23 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 27: MEM read response latency
    write_32b(EVENT_SEL_BASE_ADDR  + 27 * COUNTER_BUNDLE_SIZE, MEM_RD_RES_CORE_0);
    write_32b(EVENT_INFO_BASE_ADDR + 27 * COUNTER_BUNDLE_SIZE, ADD_RESP_LAT);
    write_32b(COUNTER_BASE_ADDR    + 27 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 28: MEM write response latency
    write_32b(EVENT_SEL_BASE_ADDR  + 28 * COUNTER_BUNDLE_SIZE, MEM_WR_RES_CORE_0);
    write_32b(EVENT_INFO_BASE_ADDR + 28 * COUNTER_BUNDLE_SIZE, ADD_RESP_LAT);
    write_32b(COUNTER_BASE_ADDR    + 28 * COUNTER_BUNDLE_SIZE, 0);

    asm volatile ("fence iorw, iorw" ::: "memory");
    printf("[3] LLC + PMU counter bundles configured (Ibex will configure EVU EIDs)\r\n");

    // ================================================================
    // [4] Signal PMU and wait for Ibex to arm phase 1 milestone
    //     Ibex arms PC_MILESTONE_SLOT0 = FUNC_ALU_ENTRY and sets PHASE=1.
    //     CVA6 polls the milestone slot for any non-zero value.
    // ================================================================
    printf("[4] Signaling PMU...\r\n");
    write_32b(DSPM_CMD_ADDR, CMD_TRIGGER_INTERRUPT);
    asm volatile ("fence iorw, iorw" ::: "memory");

    while (read_32b(PC_MILESTONE_C0_BASE_ADDR) == 0)
        asm volatile ("nop");
    asm volatile ("fence iorw, iorw" ::: "memory");
    printf("    Ibex armed phase 1 (func_alu_chain) milestone\r\n");

    // ================================================================
    // [5] Phase 1: func_alu_chain — per-call sync to ensure each
    //     entry/exit pair is captured before the next call executes.
    //     Required because func_alu_chain is short (~500+ cycles).
    // ================================================================
    printf("[5] Phase 1: func_alu_chain x%u (per-call sync)\r\n", N_CALLS_SHORT);
    for (uint32_t i = 0; i < N_CALLS_SHORT; i++) {
        func_alu_chain();

        // Wait for Ibex to log this call before issuing the next one.
        // Without this, CVA6 can enter func_alu_chain again before Ibex
        // reprograms the PC milestone, causing a missed exit hit.
        uint32_t tmo = 200000;
        while (read_32b(DSPM_LOG_CALL_COUNT) <= i && tmo > 0)
            tmo--;
        if (tmo == 0) {
            printf("    TIMEOUT waiting for alu call %u (count=%u)\r\n",
                   i, read_32b(DSPM_LOG_CALL_COUNT));
            while (1) asm volatile ("wfi");
        }
        printf("    alu call %u logged\r\n", i);
    }

    // ================================================================
    // [6] Wait for Ibex to transition to phase 2
    //     Ibex sets DSPM_LOG_PHASE=2 and arms FUNC_COLD_ENTRY milestone.
    // ================================================================
    printf("[6] Waiting for Ibex to transition to phase 2 (func_l1_cold)...\r\n");
    timeout = 200000;
    while (read_32b(DSPM_LOG_PHASE) != 2 && timeout > 0)
        timeout--;
    if (timeout == 0) {
        printf("    TIMEOUT waiting for phase 2 (phase=%u)\r\n",
               read_32b(DSPM_LOG_PHASE));
        while (1) asm volatile ("wfi");
    }
    asm volatile ("fence iorw, iorw" ::: "memory");
    printf("    Ibex armed phase 2 (func_l1_cold) milestone\r\n");

    // ================================================================
    // [7] Phase 2: func_l1_cold — no per-call sync needed; function is
    //     long enough (~10000+ cycles) for Ibex to reprogram between calls.
    //     Flush L1 D-cache before each call except the first (which
    //     gets a warm first-access effect from flush_l1_dcache's own loads).
    // ================================================================
    printf("[7] Phase 2: func_l1_cold x%u (512 cold loads each)\r\n", N_CALLS_LONG);
    for (uint32_t i = 0; i < N_CALLS_LONG; i++) {
        if (i > 0)
            flush_l1_dcache();
        func_l1_cold();
    }

    // Wait for all N_CALLS_TOTAL pairs to be logged
    timeout = 500000;
    while (read_32b(DSPM_LOG_CALL_COUNT) < N_CALLS_TOTAL && timeout > 0)
        timeout--;

    // ================================================================
    // [8] Halt PMU and print results
    // ================================================================
    write_32b(PMC_STATUS_ADDR, 1);
    asm volatile ("fence iorw, iorw" ::: "memory");

    uint32_t total_logged = read_32b(DSPM_LOG_CALL_COUNT);
    printf("\r\n========================================\r\n");
    printf("Results (%u/%u total pairs logged)\r\n", total_logged, N_CALLS_TOTAL);
    printf("========================================\r\n");
    printf("NOTE: Cycles(Ibex) = Ibex mcycle during snapshot code, not CVA6 duration\r\n");
    printf("      L1D_misses / LLC_RD / Branches = CVA6 events in entry->exit window\r\n\r\n");

    print_results("func_alu_chain (short, pure ALU)", 0, N_CALLS_SHORT);
    printf("\r\n");
    print_results("func_l1_cold (large, 512 cold loads)", N_CALLS_SHORT, N_CALLS_LONG);

    // ----------------------------------------------------------------
    // Summary comparison: expected contrast between the two functions
    // ----------------------------------------------------------------
    uint32_t alu_l1d = 0, cold_l1d = 0;
    uint32_t alu_llcrd = 0, cold_llcrd = 0;
    uint32_t alu_br = 0, cold_br = 0;
    for (uint32_t i = 0; i < N_CALLS_SHORT; i++) {
        uint32_t s = ALU_SLOT(i);
        alu_l1d  += read_32b(s + 0x04);
        alu_br   += read_32b(s + 0x0C);
        alu_llcrd += read_32b(s + 0x10);
    }
    for (uint32_t i = 0; i < N_CALLS_LONG; i++) {
        uint32_t s = COLD_SLOT(i);
        cold_l1d  += read_32b(s + 0x04);
        cold_br   += read_32b(s + 0x0C);
        cold_llcrd += read_32b(s + 0x10);
    }

    printf("\r\n  --- Comparison Summary ---\r\n");
    printf("    %-20s  %12s  %12s\r\n", "Metric", "alu (avg)", "cold (avg)");
    printf("    %-20s  %12u  %12u\r\n",
           "L1D_misses", alu_l1d / N_CALLS_SHORT, cold_l1d / N_CALLS_LONG);
    printf("    %-20s  %12u  %12u\r\n",
           "LLC_RD", alu_llcrd / N_CALLS_SHORT, cold_llcrd / N_CALLS_LONG);
    printf("    %-20s  %12u  %12u\r\n",
           "Branches", alu_br / N_CALLS_SHORT, cold_br / N_CALLS_LONG);

    printf("\r\nTest complete.\r\n");
    return 0;
}
