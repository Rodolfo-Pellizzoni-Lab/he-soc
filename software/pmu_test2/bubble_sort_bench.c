/*
 * Bubble Sort Benchmark - CVA6 + Ibex comparison test
 *
 * CVA6 (rv64) and Ibex (rv32im in APMU) both sort the same array
 * using bubble sort. CVA6 then compares both results.
 *
 * DSPM communication layout (must match pmu_firmware/main.c):
 *   0x10428000: ibex_status   -- Ibex writes: 1=done, 0xDEAD=error
 *   0x10428004: sort_n        -- CVA6 writes number of elements
 *   0x10428010: input_array   -- CVA6 writes unsorted values
 *   0x10428090: output_array  -- Ibex writes its sorted result
 */

#include "encoding.h"
#include <stdio.h>
#include <string.h>
#include "utils.h"

/* Memory-mapped I/O helpers */
#define write_32b(addr, val)  (*(volatile uint32_t *)(long)(addr) = (val))
#define read_32b(addr)        (*(volatile uint32_t *)(long)(addr))

/* PMU addresses (from pmu_defines.h) */
#define PMC_STATUS_ADDR     0x10406000
#define PMC_BOOT_ADDR       0x10406004
#define ISPM_BASE_ADDR      0x10427000
#define DSPM_BASE_ADDR      0x10428000
#define PERIOD_ADDR         0x10405008

/* DSPM communication slots */
#define IBEX_STATUS_ADDR    (DSPM_BASE_ADDR + 0x000)
#define SORT_N_ADDR         (DSPM_BASE_ADDR + 0x004)
#define INPUT_ARRAY_ADDR    (DSPM_BASE_ADDR + 0x010)
#define OUTPUT_ARRAY_ADDR   (DSPM_BASE_ADDR + 0x090)

/* Ibex status codes */
#define STATUS_IDLE         0x00000000U
#define STATUS_DONE         0x00000001U

/* External symbols for embedded PMU firmware binary */
extern unsigned char _binary_text_section_bin_start[];
extern unsigned char _binary_text_section_bin_end[];
extern unsigned char _binary_data_rodata_bss_bin_start[];
extern unsigned char _binary_data_rodata_bss_bin_end[];

/* ------------------------------------------------------------------ */
/* Unsorted input — 16 elements                                        */
/* ------------------------------------------------------------------ */
#define SORT_N 16
static const uint32_t input[SORT_N] = {
    15, 3, 9, 7, 1, 12, 5, 11, 2, 14, 6, 10, 4, 13, 8, 0
};

/* ------------------------------------------------------------------ */
/* CVA6 bubble sort (rv64, standard C)                                 */
/* ------------------------------------------------------------------ */
static void bubble_sort(uint32_t *arr, uint32_t n) {
    for (uint32_t i = 0; i < n - 1; i++) {
        for (uint32_t j = 0; j < n - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                uint32_t tmp  = arr[j];
                arr[j]        = arr[j + 1];
                arr[j + 1]    = tmp;
            }
        }
    }
}

static void print_array(const char *label, volatile uint32_t *arr, uint32_t n) {
    printf("  %s: [", label);
    for (uint32_t i = 0; i < n; i++) {
        printf("%u", arr[i]);
        if (i < n - 1) printf(", ");
    }
    printf("]\r\n");
}

void thread_entry(int cid, int nc) { return; }

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */
int main(int argc, char const *argv[]) {
    uint32_t mhartid;
    asm volatile ("csrr %0, 0xF14" : "=r"(mhartid));
    if (mhartid != 0) { while (1) asm volatile ("wfi"); }

    /* UART */
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
    printf("PMU Test2: Bubble Sort — CVA6 vs Ibex\r\n");
    printf("========================================\r\n");

    /* ----------------------------------------------------------------
     * [1] Load PMU firmware into Ibex
     * ---------------------------------------------------------------- */
    printf("[1] Loading PMU firmware...\r\n");

    uint32_t text_size = _binary_text_section_bin_end   - _binary_text_section_bin_start;
    uint32_t data_size = _binary_data_rodata_bss_bin_end - _binary_data_rodata_bss_bin_start;

    write_32b(PMC_STATUS_ADDR, 1);          /* halt Ibex */
    asm volatile ("fence iorw, iorw" ::: "memory");

    write_32b(PERIOD_ADDR,     0xFFFFFFFF);
    write_32b(PERIOD_ADDR + 4, 0xFFFFFFFF);
    asm volatile ("fence iorw, iorw" ::: "memory");

    /* Zero communication area */
    for (uint32_t i = 0; i < 0x200; i += 4)
        write_32b(DSPM_BASE_ADDR + i, 0);
    asm volatile ("fence iorw, iorw" ::: "memory");

    if (text_size == 0 || text_size > 4096) {
        printf("ERROR: bad firmware text size %u\r\n", text_size);
        while (1) asm volatile ("wfi");
    }

    memcpy((void *)ISPM_BASE_ADDR,              _binary_text_section_bin_start, text_size);
    memcpy((void *)(DSPM_BASE_ADDR + 0x200),    _binary_data_rodata_bss_bin_start, data_size);
    asm volatile ("fence iorw, iorw" ::: "memory");
    printf("    text=%u bytes, data=%u bytes\r\n", text_size, data_size);

    /* ----------------------------------------------------------------
     * [2] Write unsorted array to DSPM for Ibex
     * ---------------------------------------------------------------- */
    printf("[2] Writing input array to DSPM...\r\n");

    write_32b(SORT_N_ADDR, 0);              /* not yet — write N last */
    for (uint32_t i = 0; i < SORT_N; i++)
        write_32b(INPUT_ARRAY_ADDR + i * 4, input[i]);
    asm volatile ("fence iorw, iorw" ::: "memory");

    print_array("Input ", (volatile uint32_t *)INPUT_ARRAY_ADDR, SORT_N);

    /* ----------------------------------------------------------------
     * [3] CVA6 bubble sort (runs independently of Ibex)
     * ---------------------------------------------------------------- */
    printf("[3] CVA6 running bubble sort...\r\n");

    uint32_t cva6_result[SORT_N];
    memcpy(cva6_result, input, SORT_N * sizeof(uint32_t));
    bubble_sort(cva6_result, SORT_N);

    print_array("CVA6 sorted", (volatile uint32_t *)cva6_result, SORT_N);

    /* ----------------------------------------------------------------
     * [4] Boot Ibex, then tell it N so it starts sorting
     * ---------------------------------------------------------------- */
    printf("[4] Booting Ibex and triggering sort...\r\n");

    write_32b(PMC_BOOT_ADDR,   ISPM_BASE_ADDR);
    write_32b(PMC_STATUS_ADDR, 0);          /* release Ibex */
    asm volatile ("fence iorw, iorw" ::: "memory");

    /* Small delay to let Ibex start up before we write N */
    for (volatile int d = 0; d < 100; d++) asm volatile ("nop");

    write_32b(SORT_N_ADDR, SORT_N);         /* triggers Ibex to start */
    asm volatile ("fence iorw, iorw" ::: "memory");

    /* ----------------------------------------------------------------
     * [5] Wait for Ibex to finish
     * ---------------------------------------------------------------- */
    printf("[5] Waiting for Ibex to finish...\r\n");

    uint32_t timeout = 5000000;
    uint32_t ibex_status;
    do {
        ibex_status = read_32b(IBEX_STATUS_ADDR);
        timeout--;
    } while (ibex_status != STATUS_DONE && timeout > 0);

    if (timeout == 0) {
        printf("ERROR: Ibex timed out (status=0x%08x)\r\n", ibex_status);
        while (1) asm volatile ("wfi");
    }
    printf("    Ibex done (status=0x%08x)\r\n", ibex_status);

    /* ----------------------------------------------------------------
     * [6] Read Ibex result and compare
     * ---------------------------------------------------------------- */
    printf("[6] Comparing results...\r\n");

    volatile uint32_t *ibex_result = (volatile uint32_t *)OUTPUT_ARRAY_ADDR;
    print_array("Ibex sorted", ibex_result, SORT_N);

    uint32_t errors = 0;
    for (uint32_t i = 0; i < SORT_N; i++) {
        if (cva6_result[i] != ibex_result[i]) {
            printf("  MISMATCH at [%u]: CVA6=%u, Ibex=%u\r\n",
                   i, cva6_result[i], ibex_result[i]);
            errors++;
        }
    }

    /* ----------------------------------------------------------------
     * [7] Result
     * ---------------------------------------------------------------- */
    printf("\r\n========================================\r\n");
    if (errors == 0) {
        printf("RESULT: PASS — CVA6 and Ibex agree on sorted output\r\n");
    } else {
        printf("RESULT: FAIL — %u mismatches found\r\n", errors);
    }
    printf("========================================\r\n");

    return 0;
}
