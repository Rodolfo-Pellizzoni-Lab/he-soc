/*
APMU snapshot test: checks cnt.snap and cnt.rds on the Ibex, on idle counters set with cnt.wr.
  1) snap {0,5,31}   - rds returns each counter's value.
  2) Snapshot vs cnt - after cnt.wr, rds returns the old value and cnt.rd the new one.
  3) Mask            - snap {0} updates entry 0 only; entry 5 keeps its old value.
Core 0 loads and starts the Ibex firmware (pmu_firmware/), then checks the values it writes to the DSPM.

The test depends on pmu_defines.h and pmu_hw_desc.h, which can be found in the inc/pmu directory.
*/

#include <stdio.h>
#include <stdint.h>
#include "pmu_defines.h"
#include "encoding.h"

#define read_32b(addr)       (*(volatile uint32_t *)(uintptr_t)(addr))
#define write_32b(addr, val) (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

// DSPM mailbox (must match pmu_firmware/main.c)
#define IBEX_STAGE_FLAG   (DSPM_BASE_ADDR + 0x10UL)   // 1 = checks done
#define RESULT_ADDR(r)    (DSPM_BASE_ADDR + 0x100UL + 4 * (r))
#define FW_DATA_ADDR      (DSPM_BASE_ADDR + 0x200UL)  // pmu_firmware/linker.ld

// Test values (must match pmu_firmware/main.c)
#define CNT0_VAL_OLD   0x01234567
#define CNT5_VAL_OLD   0x05555555
#define CNT31_VAL_OLD  0x3ABCDEF1
#define CNT0_VAL_NEW   0x00C0FFEE
#define CNT5_VAL_NEW   0x0AAAAAAA

#define TIMEOUT     100000

extern unsigned char _binary_text_section_bin_start[];
extern unsigned char _binary_text_section_bin_end[];
extern unsigned char _binary_data_rodata_bss_bin_start[];
extern unsigned char _binary_data_rodata_bss_bin_end[];

static uint32_t err = 0;

static void check(const char *label, uint32_t slot, uint32_t expected){
    uint32_t got = read_32b(RESULT_ADDR(slot));
    printf("[CORE0] %s. Got: 0x%08x, Expected: 0x%08x\n", label, got, expected);
    if(got != expected)
        err++;
}

void thread_entry(int cid, int nc){
}

int main(void){
    uint32_t mhartid = read_csr(mhartid);

    if(mhartid != 0) {
        /* Other cores: park */
        while (1)
            asm volatile("wfi");
    }

    // Hold the Ibex and load its firmware (word stores: the SPMs lose byte stores)
    printf("[CORE0] Loading Ibex firmware...\n");
    uint32_t text_size = _binary_text_section_bin_end - _binary_text_section_bin_start;
    uint32_t data_size = _binary_data_rodata_bss_bin_end - _binary_data_rodata_bss_bin_start;

    write_32b(PMC_STATUS_ADDR, 1);
    asm volatile("fence iorw, iorw" ::: "memory");

    for(uint32_t i = 0; i < 0x200; i += 4)
        write_32b(DSPM_BASE_ADDR + i, 0);
    for(uint32_t i = 0; i < (text_size + 3) / 4; i++)
        write_32b(ISPM_BASE_ADDR + 4 * i, ((uint32_t *)_binary_text_section_bin_start)[i]);
    for(uint32_t i = 0; i < (data_size + 3) / 4; i++)
        write_32b(FW_DATA_ADDR + 4 * i, ((uint32_t *)_binary_data_rodata_bss_bin_start)[i]);

    // Configure the APMU counters
    printf("[CORE0] Configuring APMU counters...\n");
    // No MemGuard period: the counters are never reloaded.
    write_32b(PERIOD_ADDR_LO, 0);
    write_32b(PERIOD_ADDR_HI, 0);
    // All counters off and cleared.
    for(int n = 0; n < NUM_COUNTER; n++){
        write_32b(EVENT_SEL_ADDR(n), 0);
        write_32b(EVENT_INFO_ADDR(n), 0);
        write_32b(INIT_BUDGET_ADDR(n), 0);
        write_32b(COUNTER_ADDR(n), 0);
    }
    asm volatile("fence iorw, iorw" ::: "memory");

    // Start the Ibex
    printf("[CORE0] Starting Ibex (text=%u, data=%u bytes)...\n", text_size, data_size);
    write_32b(PMC_BOOT_ADDR, ISPM_BASE_ADDR);
    write_32b(PMC_STATUS_ADDR, 0);
    asm volatile("fence iorw, iorw" ::: "memory");

    uint32_t timeout = TIMEOUT;
    while(read_32b(IBEX_STAGE_FLAG) != 1 && --timeout);
    if(!timeout){
        printf("[CORE0] Ibex stuck (stage flag %u)\n", read_32b(IBEX_STAGE_FLAG));
        err++;
    } else {
        check("1) snap {0,5,31}: rds 0", 0, CNT0_VAL_OLD);
        check("1) snap {0,5,31}: rds 5", 1, CNT5_VAL_OLD);
        check("1) snap {0,5,31}: rds 31", 2, CNT31_VAL_OLD);
        check("2) cnt.wr 5: rds 5 (reading snapshot)", 3, CNT5_VAL_OLD);
        check("2) cnt.wr 5: cnt.rd 5 (reading counter)", 4, CNT5_VAL_NEW);
        check("3) snap {0}: rds 0", 5, CNT0_VAL_NEW);
        check("3) snap {0}: rds 5, untouched", 6, CNT5_VAL_OLD);
    }

    // Halt the Ibex
    write_32b(PMC_STATUS_ADDR, 1);

    if(err)
        printf("[CORE0] FAIL\n");
    else
        printf("[CORE0] PASS\n");
    return err;
}
