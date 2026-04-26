/*
 * PMU Firmware - Counter Read (Ibex RV32IM side)
 *
 * Sequence:
 *   1. Set overflow bit on counter 0 and counter 1.
 *      CVA6 core 0 must have written OVERFLOW_EN to event_info[0/1]
 *      before releasing Ibex.  These two overflows trigger PLIC sources
 *      156 and 157, which the bootrom uses to wake CVA6 cores 2 and 3
 *      from their WFI loops.
 *   2. Signal CVA6 core 0: STATUS_STARTED.
 *   3. Spin until CVA6 core 0 issues CMD_READ_NOW.
 *   4. Read counters 2-11 (LLC RD/WR x4, MEM RD, MEM WR) via the
 *      custom counter_read instruction and write results to DSPM.
 *   5. Signal CVA6 core 0: STATUS_DONE.
 *
 * DSPM layout (must match pmu_cntr_bench.c):
 *   0x10428000 : ibex_status  — Ibex writes: 0=idle, 1=started, 2=done
 *   0x10428004 : cva6_cmd     — CVA6 writes: 0=wait, 1=read_now
 *   0x10428010 : results[10]  — Ibex writes counter values for ctrs 2-11
 */

#include <stdint.h>
#include "include/pmu_hw_desc.h"

/* ------------------------------------------------------------------ */
/* DSPM communication addresses                                        */
/* ------------------------------------------------------------------ */
#define DSPM_BASE           0x10428000U
#define IBEX_STATUS_ADDR    (DSPM_BASE + 0x00)
#define CVA6_CMD_ADDR       (DSPM_BASE + 0x04)
#define RESULTS_BASE_ADDR   (DSPM_BASE + 0x10)

#define STATUS_IDLE         0x00000000U
#define STATUS_STARTED      0x00000001U
#define STATUS_DONE         0x00000002U

#define CMD_WAIT            0x00000000U
#define CMD_READ_NOW        0x00000001U

/* ------------------------------------------------------------------ */
/* Counter index assignments                                           */
/* ------------------------------------------------------------------ */
#define CNT_IRQ_CORE2       0   /* overflow -> PLIC source 156 -> wakes core 2 */
#define CNT_IRQ_CORE3       1   /* overflow -> PLIC source 157 -> wakes core 3 */
#define CNT_FIRST_STAT      2   /* first event counter (LLC_RD_REQ_CORE_0) */
#define NUM_STAT_COUNTERS   10  /* ctrs 2-11: LLC RD/WR x4, MEM RD, MEM WR */

#define WRITE32(addr, val)  (*((volatile uint32_t *)(addr)) = (val))
#define READ32(addr)        (*((volatile uint32_t *)(addr)))

int main(void) {
    volatile uint32_t *results = (volatile uint32_t *)RESULTS_BASE_ADDR;

    /* Signal idle */
    WRITE32(IBEX_STATUS_ADDR, STATUS_IDLE);
    WRITE32(CVA6_CMD_ADDR,    CMD_WAIT);

    /* ------------------------------------------------------------------
     * Wake CVA6 cores 2 and 3 by setting the overflow/pending bit on
     * counters 0 and 1.  CVA6 core 0 must have written OVERFLOW_EN
     * (0x01000000) into event_info for these two counters before
     * releasing Ibex, so the overflow fires as an IRQ immediately.
     * ------------------------------------------------------------------ */
    counter_write(CNT_IRQ_CORE2, 0x40000000U);
    counter_write(CNT_IRQ_CORE3, 0x40000000U);

    /* Signal to CVA6 core 0 that Ibex is up and IRQs have been sent */
    WRITE32(IBEX_STATUS_ADDR, STATUS_STARTED);

    /* Wait for CVA6 core 0 to finish traffic generation */
    while (READ32(CVA6_CMD_ADDR) != CMD_READ_NOW)
        ;

    /* Read counters 2-11 using the custom counter_read instruction */
    for (uint32_t i = 0; i < NUM_STAT_COUNTERS; i++) {
        uint32_t val;
        uint32_t cidx = CNT_FIRST_STAT + i;
        counter_read(val, cidx);
        results[i] = val & 0x7FFFFFFFU;  /* strip pending bit */
    }

    /* Signal done */
    WRITE32(IBEX_STATUS_ADDR, STATUS_DONE);

    while (1) ;
    return 0;
}
