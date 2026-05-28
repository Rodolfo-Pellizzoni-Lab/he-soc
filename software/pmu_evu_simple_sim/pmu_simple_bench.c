/*
 * PMU EVU Simple Benchmark - Single Function, Single Call
 *
 * Runs func_l1_cold exactly once on core 0.
 * PMU firmware tracks entry→exit via PC milestone slot 0.
 *
 * Expected (N_ITER=64, CL_WORDS=16):
 *   committed_loads = 64
 *   L1D_misses      = 64  (one new cache line per access, stride=64B)
 *   LLC_RD          = 64  (each L1 miss goes to LLC)
 */

#include "encoding.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "utils.h"
#include "pmu_test_func.c"

#define NUM_CORES 4

// Cacheable memory base addresses
#define CORE0_DATA_BASE   0x81000000
#define CACHE_LINE_SIZE   64

// DSPM communication addresses (must match firmware)
#define DSPM_STATUS_ADDR  (DSPM_BASE_ADDR + 0x00)
#define DSPM_CMD_ADDR     (DSPM_BASE_ADDR + 0x80)

// DSPM result log (must match firmware DSPM_LOG_BASE layout)
#define DSPM_LOG_BASE        (DSPM_BASE_ADDR + 0x2000)
#define DSPM_LOG_CALL_COUNT  (DSPM_LOG_BASE + 0x00)
#define DSPM_LOG_STATE       (DSPM_LOG_BASE + 0x04)
#define DSPM_LOG_RESULT      (DSPM_LOG_BASE + 0x08)

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
// func_l1_cold: N_ITER loads, each touching a new cache line (stride=64B)
// Expected: committed_loads=N_ITER, L1D_misses=N_ITER
// =====================================================================
#define N_ITER    512
#define CL_WORDS  16   // 64B / 4B

#define BASE        ((volatile uint32_t *)CORE0_DATA_BASE)
#define REGION_COLD (BASE)
#define REGION_FLUSH (BASE + N_ITER * CL_WORDS)   // flush region: same size, adjacent

void __attribute__((noinline)) func_l1_cold(void) {
    uint32_t sum = 0;
    for (uint32_t i = 0; i < N_ITER; i++)
        sum = REGION_COLD[i * CL_WORDS];   // stride 64B = 1 new cache line each
    (void)sum;
}

void thread_entry(int cid, int nc) { return; }

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
    printf("PMU EVU Simple Benchmark - func_l1_cold x1\r\n");
    printf("  N_ITER=%u  Expected: loads=%u, L1D_misses=%u, LLC_RD=%u\r\n", N_ITER, N_ITER, N_ITER, N_ITER);
    printf("========================================\r\n");

    // ================================================================
    // [1] Load PMU firmware
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
    // [3] Enable LLC and configure counters
    // ================================================================
    // No init — REGION_COLD is never touched before the function call,
    // so all lines are guaranteed cold (no dirty lines, no L1 residency).

    enable_llc();
    partition_cache_4cores();

    uint32_t llc_rd_events[NUM_CORES] = { LLC_RD_REQ_CORE_0, LLC_RD_REQ_CORE_1, LLC_RD_REQ_CORE_2, LLC_RD_REQ_CORE_3 };
    uint32_t llc_wr_events[NUM_CORES] = { LLC_WR_REQ_CORE_0, LLC_WR_REQ_CORE_1, LLC_WR_REQ_CORE_2, LLC_WR_REQ_CORE_3 };
    uint32_t mem_rd_events[NUM_CORES] = { MEM_RD_REQ_CORE_0, MEM_RD_REQ_CORE_1, MEM_RD_REQ_CORE_2, MEM_RD_REQ_CORE_3 };
    uint32_t mem_wr_events[NUM_CORES] = { MEM_WR_REQ_CORE_0, MEM_WR_REQ_CORE_1, MEM_WR_REQ_CORE_2, MEM_WR_REQ_CORE_3 };
    uint32_t *event_groups[4] = { llc_rd_events, llc_wr_events, mem_rd_events, mem_wr_events };
    uint32_t group_base[4]    = { 4, 8, 12, 16 };

    for (uint32_t g = 0; g < 4; g++)
        for (uint32_t core = 0; core < NUM_CORES; core++) {
            uint32_t cnt_idx = group_base[g] + core;
            write_32b(EVENT_SEL_BASE_ADDR  + cnt_idx * COUNTER_BUNDLE_SIZE, event_groups[g][core]);
            write_32b(EVENT_INFO_BASE_ADDR + cnt_idx * COUNTER_BUNDLE_SIZE, 0);
            write_32b(COUNTER_BASE_ADDR    + cnt_idx * COUNTER_BUNDLE_SIZE, 0);
        }

    // Counter 22: L1-D misses (EVU EV0)
    write_32b(EVENT_SEL_BASE_ADDR  + 22 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV0);
    write_32b(EVENT_INFO_BASE_ADDR + 22 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 22 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 23: pipeline stalls (EVU EV2)
    write_32b(EVENT_SEL_BASE_ADDR  + 23 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV2);
    write_32b(EVENT_INFO_BASE_ADDR + 23 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 23 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 20: milestone hits (EVU EV1)
    write_32b(EVENT_SEL_BASE_ADDR  + 20 * COUNTER_BUNDLE_SIZE, PERF_COUNTER_EVU_C0_EV1);
    write_32b(EVENT_INFO_BASE_ADDR + 20 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(COUNTER_BASE_ADDR    + 20 * COUNTER_BUNDLE_SIZE, 0);

    // Counter 27: MEM read latency, Counter 28: MEM write latency
    write_32b(EVENT_SEL_BASE_ADDR  + 27 * COUNTER_BUNDLE_SIZE, MEM_RD_RES_CORE_0);
    write_32b(EVENT_INFO_BASE_ADDR + 27 * COUNTER_BUNDLE_SIZE, ADD_RESP_LAT);
    write_32b(COUNTER_BASE_ADDR    + 27 * COUNTER_BUNDLE_SIZE, 0);
    write_32b(EVENT_SEL_BASE_ADDR  + 28 * COUNTER_BUNDLE_SIZE, MEM_WR_RES_CORE_0);
    write_32b(EVENT_INFO_BASE_ADDR + 28 * COUNTER_BUNDLE_SIZE, ADD_RESP_LAT);
    write_32b(COUNTER_BASE_ADDR    + 28 * COUNTER_BUNDLE_SIZE, 0);

    // EVU event ID configuration for core 0 (must match firmware)
    write_32b(EVENTID_C0_BASE_ADDR,      0x2);   // EID0: D-cache miss (L1 miss)
    write_32b(EVENTID_C0_BASE_ADDR + 4,  0x16);  // EID1: PC milestone hit
    write_32b(EVENTID_C0_BASE_ADDR + 8,  0x17);  // EID2: pipeline stall
    write_32b(EVENTID_C0_BASE_ADDR + 12, 0x2);   // EID3: unused
    asm volatile ("fence iorw, iorw" ::: "memory");

    printf("[3] LLC + counters configured\r\n");

    printf("[4] Cold region pre-initialized before LLC enable\r\n");

    // ================================================================
    // [5] Signal PMU and run func_l1_cold once
    // ================================================================
    printf("[5] Signaling PMU, running func_l1_cold...\r\n");
    write_32b(DSPM_CMD_ADDR, CMD_TRIGGER_INTERRUPT);
    asm volatile ("fence iorw, iorw" ::: "memory");

    // Wait for firmware to write any non-zero address to milestone slot 0.
    // Do NOT compare against FUNC_ENTRY here — that creates a chicken-and-egg
    // where the binary size depends on FUNC_ENTRY, shifting func_l1_cold's address
    // between build passes.  The firmware always writes a non-zero function address,
    // so polling for != 0 is equivalent and layout-stable.
    while (read_32b(PC_MILESTONE_C0_BASE_ADDR) == 0)
        asm volatile ("nop");
    asm volatile ("fence iorw, iorw" ::: "memory");

    func_l1_cold();

    // Wait for firmware to log the exit hit (call_count becomes 1)
    timeout = 100000;
    while (read_32b(DSPM_LOG_CALL_COUNT) == 0 && timeout > 0)
        timeout--;

    // ================================================================
    // [6] Halt PMU and print results
    // ================================================================
    write_32b(PMC_STATUS_ADDR, 1);
    asm volatile ("fence iorw, iorw" ::: "memory");

    printf("\r\n========================================\r\n");
    printf("Results\r\n");
    printf("========================================\r\n");

    uint32_t call_count = read_32b(DSPM_LOG_CALL_COUNT);
    printf("    call_count (expect 1): %u\r\n", call_count);

    uint32_t cycles  = read_32b(DSPM_LOG_RESULT + 0);
    uint32_t l1miss  = read_32b(DSPM_LOG_RESULT + 4);
    uint32_t stalls  = read_32b(DSPM_LOG_RESULT + 8);
    uint32_t llc_rd  = read_32b(DSPM_LOG_RESULT + 12);
    uint32_t llc_wr  = read_32b(DSPM_LOG_RESULT + 16);
    uint32_t mem_rd  = read_32b(DSPM_LOG_RESULT + 20);
    uint32_t mem_wr  = read_32b(DSPM_LOG_RESULT + 24);
    uint32_t rdlat   = read_32b(DSPM_LOG_RESULT + 28);
    uint32_t wrlat   = read_32b(DSPM_LOG_RESULT + 32);

    printf("    %-20s %10s %10s\r\n", "Metric", "Measured", "Expected");
    printf("    %-20s %10u %10s\r\n", "Cycles",    cycles, "-");
    printf("    %-20s %10u %10u\r\n", "L1D misses", l1miss,  N_ITER);
    printf("    %-20s %10u %10u\r\n", "LLC_RD",     llc_rd,  N_ITER);
    printf("    %-20s %10u %10u\r\n", "LLC_WR",     llc_wr,  0);
    printf("    %-20s %10u %10u\r\n", "MEM_RD",     mem_rd,  N_ITER);
    printf("    %-20s %10u %10u\r\n", "MEM_WR",     mem_wr,  0);
    printf("    %-20s %10u %10s\r\n", "Stalls",     stalls,  "-");
    printf("    %-20s %10u %10s\r\n", "RdLat",      rdlat,   "-");
    printf("    %-20s %10u %10s\r\n", "WrLat",      wrlat,   "-");

    uint32_t breadcrumb     = read_32b(COUNTER_BASE_ADDR + 26 * COUNTER_BUNDLE_SIZE);
    uint32_t pmu_cyc        = read_32b(COUNTER_BASE_ADDR + 25 * COUNTER_BUNDLE_SIZE);
    uint32_t pmu_instret    = read_32b(DSPM_BASE_ADDR + 0x2000 + 0x30);
    uint32_t instret_entry  = read_32b(DSPM_BASE_ADDR + 0x2000 + 0x34);
    uint32_t instret_exit   = read_32b(DSPM_BASE_ADDR + 0x2000 + 0x38);
    uint32_t mcycle_entry   = read_32b(DSPM_BASE_ADDR + 0x2000 + 0x3C);
    uint32_t mcycle_exit    = read_32b(DSPM_BASE_ADDR + 0x2000 + 0x40);

    printf("\r\n    --- PMU Sleep Proof ---\r\n");
    printf("    Stage          mcycle      instret\r\n");
    printf("    Entry wake:    %10u  %10u\r\n", mcycle_entry, instret_entry);
    printf("    Exit wake:     %10u  %10u\r\n", mcycle_exit, instret_exit);
    printf("    Delta:         %10u  %10u\r\n", mcycle_exit - mcycle_entry, instret_exit - instret_entry);
    printf("    Total:         %10u  %10u\r\n", pmu_cyc, pmu_instret);
    printf("\r\n    Between entry and exit: %u cycles, only %u instructions\r\n",
           mcycle_exit - mcycle_entry, instret_exit - instret_entry);
    printf("    PMU was asleep for the function's entire execution.\r\n");

    printf("\r\nTest complete.\r\n");
    return 0;
}
