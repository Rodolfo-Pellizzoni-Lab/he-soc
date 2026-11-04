/*
 * PMU Firmware - Bubble Sort (Ibex RV32IM side)
 *
 * Protocol (DSPM communication area, DSPM+0x000-DSPM+0x1FF):
 *   DSPM+0x000: ibex_status   -- Ibex writes: 1=done, 0xDEAD=error
 *   DSPM+0x004: sort_n        -- CVA6 writes number of elements (max 32)
 *   DSPM+0x010: input_array   -- CVA6 writes unsorted array (sort_n * 4 bytes)
 *   DSPM+0x090: output_array  -- Ibex writes sorted result (sort_n * 4 bytes)
 *
 * Ibex waits for sort_n != 0, sorts the input, writes result, sets status=1.
 */

#include <stdint.h>
#include <stddef.h>
#include "include/pmu_hw_desc.h"

#define DSPM_BASE           DSPM_BASE_ADDR

#define IBEX_STATUS_ADDR    (DSPM_BASE + 0x000)
#define SORT_N_ADDR         (DSPM_BASE + 0x004)
#define INPUT_ARRAY_ADDR    (DSPM_BASE + 0x010)
#define OUTPUT_ARRAY_ADDR   (DSPM_BASE + 0x090)

#define STATUS_IDLE         0x00000000U
#define STATUS_DONE         0x00000001U
#define STATUS_ERROR        0xDEAD0000U

#define MAX_N               32

#define READ32(addr)        (*((volatile uint32_t *)(addr)))
#define WRITE32(addr, val)  (*((volatile uint32_t *)(addr)) = (val))

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

int main(void) {
    /* Signal idle */
    WRITE32(IBEX_STATUS_ADDR, STATUS_IDLE);

    /* Wait for CVA6 to write sort_n (nonzero = work ready) */
    uint32_t n;
    do {
        n = READ32(SORT_N_ADDR);
    } while (n == 0);

    /* Bounds check */
    if (n > MAX_N) {
        WRITE32(IBEX_STATUS_ADDR, STATUS_ERROR | n);
        while (1) ;
    }

    /* Copy input array into local buffer */
    uint32_t arr[MAX_N];
    for (uint32_t i = 0; i < n; i++)
        arr[i] = READ32(INPUT_ARRAY_ADDR + i * 4);

    /* Run bubble sort */
    bubble_sort(arr, n);

    /* Write sorted result to output area */
    for (uint32_t i = 0; i < n; i++)
        WRITE32(OUTPUT_ARRAY_ADDR + i * 4, arr[i]);

    /* Signal done */
    WRITE32(IBEX_STATUS_ADDR, STATUS_DONE);

    /* Done — sleep forever */
    while (1) ;

    return 0;
}
