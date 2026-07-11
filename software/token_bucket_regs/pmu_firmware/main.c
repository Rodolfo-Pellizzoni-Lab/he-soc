/*
 * PMU Firmware
 *
 * Protocol (DSPM communication area, 0x10428000-0x102281FF):
 *   0x10428000: ibex_status   -- Ibex writes: 1=done, 0xDEAD=error
 *
 */

#include <stdint.h>
#include <stddef.h>
#include "tb_defines.h"

#define read_32b(addr)        (*((volatile uint32_t *)(addr)))
#define write_32b(addr, val)  (*((volatile uint32_t *)(addr)) = (val))
#define TB_CORE_BASE(c)         (TB_CFG_BASE_ADDR + (c) * TB_CORE_BYTES)
#define TB_READ(c, offset)      read_32b(TB_CORE_BASE(c) + (offset))
#define TB_WRITE(c, offset, v)  write_32b(TB_CORE_BASE(c) + (offset), (v))

// Values the Ibex writes to each core 
#define IBEX_TOKEN_LIMIT(c)     (128 + (c) * 64)
#define IBEX_REFILL_TOKENS(c)   (4   + (c))
#define IBEX_REFILL_INTERVAL(c) (50  + (c) * 10)
#define IBEX_AW_COST(c)         (2   + (c))
#define IBEX_AR_COST(c)         (3   + (c))

// PMU addresses (from pmu_defines.h) 
#define DSPM_BASE_ADDR      0x10428000

// DSPM communication slots 
#define IBEX_STATUS_ADDR    (DSPM_BASE_ADDR + 0x000)

// Ibex status codes 
#define STATUS_IDLE         0x00000000U
#define STATUS_DONE         0x00000001U
#define STATUS_ERROR        0xDEAD0000U

// -----------------------------------------------------------------------------
// Inline check: increments err on mismatch
// -----------------------------------------------------------------------------
static inline void check(uint32_t got, uint32_t exp, uint32_t *err)
{
    if (got != exp)
        (*err)++;
}


int main(void) {
    // Signal idle 
    write_32b(IBEX_STATUS_ADDR, STATUS_IDLE);
    uint32_t err = 0;

    // -------------------------------------------------------------------------
    // 1. Reset value check
    // -------------------------------------------------------------------------
    for (uint32_t c = 0; c < NUM_CORES; c++) {
        check(TB_READ(c, TOKEN_LIMIT_OFFSET),     RST_TOKEN_LIMIT,     &err);
        check(TB_READ(c, REFILL_TOKENS_OFFSET),   RST_REFILL_TOKENS,   &err);
        check(TB_READ(c, REFILL_INTERVAL_OFFSET), RST_REFILL_INTERVAL, &err);
        check(TB_READ(c, AW_COST_OFFSET),         RST_AW_COST,         &err);
        check(TB_READ(c, AR_COST_OFFSET),         RST_AR_COST,         &err);
        check(TB_READ(c, CTRL_OFFSET),            RST_CTRL,            &err);
    }

    // -------------------------------------------------------------------------
    // 2. Write distinct values to every core
    // -------------------------------------------------------------------------
    for (uint32_t c = 0; c < NUM_CORES; c++) {
        TB_WRITE(c, TOKEN_LIMIT_OFFSET,     IBEX_TOKEN_LIMIT(c));
        TB_WRITE(c, REFILL_TOKENS_OFFSET,   IBEX_REFILL_TOKENS(c));
        TB_WRITE(c, REFILL_INTERVAL_OFFSET, IBEX_REFILL_INTERVAL(c));
        TB_WRITE(c, AW_COST_OFFSET,         IBEX_AW_COST(c));
        TB_WRITE(c, AR_COST_OFFSET,         IBEX_AR_COST(c));
    }

    // -------------------------------------------------------------------------
    // 3. Readback check
    // -------------------------------------------------------------------------
    for (uint32_t c = 0; c < NUM_CORES; c++) {
        check(TB_READ(c, TOKEN_LIMIT_OFFSET),     IBEX_TOKEN_LIMIT(c),     &err);
        check(TB_READ(c, REFILL_TOKENS_OFFSET),   IBEX_REFILL_TOKENS(c),   &err);
        check(TB_READ(c, REFILL_INTERVAL_OFFSET), IBEX_REFILL_INTERVAL(c), &err);
        check(TB_READ(c, AW_COST_OFFSET),         IBEX_AW_COST(c),         &err);
        check(TB_READ(c, AR_COST_OFFSET),         IBEX_AR_COST(c),         &err);
    }

    // -------------------------------------------------------------------------
    // 4. CTRL enable / disable per core
    // -------------------------------------------------------------------------
    for (uint32_t c = 0; c < NUM_CORES; c++) {
        TB_WRITE(c, CTRL_OFFSET, 0x1U);
        check(TB_READ(c, CTRL_OFFSET), 0x1U, &err);

        TB_WRITE(c, CTRL_OFFSET, 0x0U);
        check(TB_READ(c, CTRL_OFFSET), 0x0U, &err);
    }

    // -------------------------------------------------------------------------
    // 5. Cross-core isolation: earlier writes must not have bled into neighbours
    // -------------------------------------------------------------------------
    for (uint32_t c = 0; c < NUM_CORES; c++) {
        check(TB_READ(c, TOKEN_LIMIT_OFFSET), IBEX_TOKEN_LIMIT(c), &err);
    }

    write_32b(IBEX_STATUS_ADDR, (err == 0) ? STATUS_DONE : STATUS_ERROR);
    while (1);

    return 0;
}
