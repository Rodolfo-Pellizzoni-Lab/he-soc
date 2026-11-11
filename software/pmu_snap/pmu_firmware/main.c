/*
Ibex firmware for the APMU snapshot test (pmu_snap.c).
Runs cnt.snap / cnt.rds on idle counters set with cnt.wr and writes every value it reads to the DSPM; Core 0
checks them.
  1) snap {0,5,31}, rds 0, 5, 31.
  2) cnt.wr 0 and 5, then rds 5 and cnt.rd 5.
  3) snap {0}, rds 0 and 5.

The firmware depends on pmu_defines.h and pmu_hw_desc.h in the inc/pmu directory.
*/

#include <stdint.h>
#include "pmu_defines.h"
#include "pmu_hw_desc.h"

#define write_32b(addr, val) (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

// DSPM mailbox (must match pmu_snap.c)
#define IBEX_STAGE_FLAG   (DSPM_BASE_ADDR + 0x10UL)   // 1 = checks done
#define RESULT_ADDR(r)    (DSPM_BASE_ADDR + 0x100UL + 4 * (r))

// Test values (must match pmu_snap.c), below the overflow bit
#define CNT0_VAL_OLD   0x01234567
#define CNT5_VAL_OLD   0x05555555
#define CNT31_VAL_OLD  0x3ABCDEF1
#define CNT0_VAL_NEW   0x00C0FFEE
#define CNT5_VAL_NEW   0x0AAAAAAA

int main(void){
    // Enable mcycle and minstret (mcountinhibit = 0)
    asm volatile("csrw 0x320, zero");

    // Set the idle counters
    cnt_wr(0, CNT0_VAL_OLD);
    cnt_wr(5, CNT5_VAL_OLD);
    cnt_wr(31, CNT31_VAL_OLD);

    // 1) snap {0,5,31}
    cnt_snap((1u << 31) | (1u << 5) | (1u << 0));
    write_32b(RESULT_ADDR(0), cnt_rds(0));
    write_32b(RESULT_ADDR(1), cnt_rds(5));
    write_32b(RESULT_ADDR(2), cnt_rds(31));

    // 2) Snapshot vs counter
    cnt_wr(0, CNT0_VAL_NEW);
    cnt_wr(5, CNT5_VAL_NEW);
    write_32b(RESULT_ADDR(3), cnt_rds(5));
    write_32b(RESULT_ADDR(4), cnt_rd(5));

    // 3) snap {0} only
    cnt_snap(1u << 0);
    write_32b(RESULT_ADDR(5), cnt_rds(0));
    write_32b(RESULT_ADDR(6), cnt_rds(5));

    write_32b(IBEX_STAGE_FLAG, 1);
    while (1);
    return 0;
}
