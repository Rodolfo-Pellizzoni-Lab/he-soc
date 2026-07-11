#include "encoding.h"
#include <stdio.h>
#include <string.h>
#include "utils.h"
#include "tb_defines.h"

#define read_32b(addr)          (*(volatile uint32_t *)(long)(addr))
#define write_32b(addr, val_)   (*(volatile uint32_t *)(long)(addr) = val_)
#define TB_CORE_BASE(c)         (TB_CFG_BASE_ADDR + (c) * TB_CORE_BYTES)
#define TB_READ(c, offset)      read_32b(TB_CORE_BASE(c)  + (offset))
#define TB_WRITE(c, offset, v)  write_32b(TB_CORE_BASE(c) + (offset), (v))

// Values the Ibex firmware writes to each core
// These must match the PMU firmware - they describe the state the Ibex leaves behind, which CVA6 verifies in the coherency check.
#define IBEX_TOKEN_LIMIT(c)     (128 + (c) * 64)
#define IBEX_REFILL_TOKENS(c)   (4   + (c))
#define IBEX_REFILL_INTERVAL(c) (50  + (c) * 10)
#define IBEX_AW_COST(c)         (2   + (c))
#define IBEX_AR_COST(c)         (3   + (c))

// CVA6's own pattern
#define CVA6_TOKEN_LIMIT(c)     (0x1000 + (c) * 0x10)
#define CVA6_REFILL_TOKENS(c)   (0x20   + (c))
#define CVA6_REFILL_INTERVAL(c) (0x300  + (c) * 0x10)
#define CVA6_AW_COST(c)         (0x40   + (c))
#define CVA6_AR_COST(c)         (0x50   + (c))

// Used by the isolation test 
#define ISOLATION_SENTINEL      0xABCD

// PMU addresses (from pmu_defines.h) 
#define PMC_STATUS_ADDR     0x10406000
#define PMC_BOOT_ADDR       0x10406004
#define ISPM_BASE_ADDR      0x10427000
#define DSPM_BASE_ADDR      0x10428000
#define PERIOD_ADDR         0x10405008

// DSPM communication slots 
#define IBEX_STATUS_ADDR    (DSPM_BASE_ADDR + 0x000)

// Ibex status codes 
#define STATUS_IDLE         0x00000000U
#define STATUS_DONE         0x00000001U

// External symbols for PMU firmware binary 
extern unsigned char _binary_text_section_bin_start[];
extern unsigned char _binary_text_section_bin_end[];
extern unsigned char _binary_data_rodata_bss_bin_start[];
extern unsigned char _binary_data_rodata_bss_bin_end[];


int main(int argc, char const *argv[]) {

  uint32_t mhartid;
  asm volatile (
    "csrr %0, 0xF14\n"
    : "=r" (mhartid)
  );

  uint32_t error_count = 0;
  uint32_t read_val;

  if (mhartid != 0) { while(1) asm volatile ("wfi");} 

  #ifdef FPGA_EMULATION
  uint32_t baud_rate = 9600;
  uint32_t test_freq = 100000000;
  #else
  set_flls();
  uint32_t baud_rate = 115200;
  uint32_t test_freq = 50000000;
  #endif
  uart_set_cfg(0, (test_freq / baud_rate) >> 4);

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
   * [2] Boot Ibex
   * ---------------------------------------------------------------- */
  printf("[2] Booting Ibex...\r\n");

  write_32b(PMC_BOOT_ADDR,   ISPM_BASE_ADDR);
  write_32b(PMC_STATUS_ADDR, 0);          /* release Ibex */
  asm volatile ("fence iorw, iorw" ::: "memory");

  /* ----------------------------------------------------------------
   * [3] Wait for Ibex to finish
   * ---------------------------------------------------------------- */
  printf("[3] Waiting for Ibex to finish...\r\n");

  uint32_t timeout = 5000000;
  uint32_t ibex_status;
  do {
      ibex_status = read_32b(IBEX_STATUS_ADDR);
  } while (ibex_status == STATUS_IDLE && --timeout > 0);

  if (ibex_status != STATUS_DONE) {
      printf("ERROR: Ibex failed (status=0x%08x)\r\n", ibex_status);
      while (1) asm volatile ("wfi");
  }
  printf("Ibex Passed The Tests\r\n");

  // =========================================================================
  // 1. Cross-master coherency check
  //
  // PMU firmware has already run at this point and modified token bucket registers. 
  // CVA6 must observe exactly this state, proving both masters address
  // the same token bucket register file consistently. 
  // =========================================================================
  printf("--- CVA6 Side Testing Begins ---\r\n");
  printf("Token Bucket Register Test (%d cores)\r\n", NUM_CORES);
  uart_wait_tx_done();
  printf("--- Cross-Master Coherency Check (state left by Ibex) ---\r\n");
  for (int c = 0; c < NUM_CORES; c++) {
    read_val = TB_READ(c, TOKEN_LIMIT_OFFSET);
    if (read_val != IBEX_TOKEN_LIMIT(c)) {
      printf("FAIL core%d: TOKEN_LIMIT expected 0x%x, got 0x%x\r\n", c, IBEX_TOKEN_LIMIT(c), read_val);
      error_count++;
    }

    read_val = TB_READ(c, REFILL_TOKENS_OFFSET);
    if (read_val != IBEX_REFILL_TOKENS(c)) {
      printf("FAIL core%d: REFILL_TOKENS expected 0x%x, got 0x%x\r\n", c, IBEX_REFILL_TOKENS(c), read_val);
      error_count++;
    }

    read_val = TB_READ(c, REFILL_INTERVAL_OFFSET);
    if (read_val != IBEX_REFILL_INTERVAL(c)) {
      printf("FAIL core%d: REFILL_INTERVAL expected 0x%x, got 0x%x\r\n", c, IBEX_REFILL_INTERVAL(c), read_val);
      error_count++;
    }

    read_val = TB_READ(c, AW_COST_OFFSET);
    if (read_val != IBEX_AW_COST(c)) {
      printf("FAIL core%d: AW_COST expected 0x%x, got 0x%x\r\n", c, IBEX_AW_COST(c), read_val);
      error_count++;
    }

    read_val = TB_READ(c, AR_COST_OFFSET);
    if (read_val != IBEX_AR_COST(c)) {
      printf("FAIL core%d: AR_COST expected 0x%x, got 0x%x\r\n", c, IBEX_AR_COST(c), read_val);
      error_count++;
    }

    read_val = TB_READ(c, CTRL_OFFSET);
    if (read_val != RST_CTRL) {  
      printf("FAIL core%d: CTRL expected 0x%x, got 0x%x\r\n", c, RST_CTRL, read_val);
      error_count++;
    }
  }
  printf("Coherency check done (%d errors so far)\r\n", error_count);
  uart_wait_tx_done();

  // =========================================================================
  // 2. CVA6 writes its own distinct pattern
  // =========================================================================
  printf("--- CVA6 Write Distinct Values ---\r\n");
  for (int c = 0; c < NUM_CORES; c++) {
    TB_WRITE(c, TOKEN_LIMIT_OFFSET,     CVA6_TOKEN_LIMIT(c));
    TB_WRITE(c, REFILL_TOKENS_OFFSET,   CVA6_REFILL_TOKENS(c));
    TB_WRITE(c, REFILL_INTERVAL_OFFSET, CVA6_REFILL_INTERVAL(c));
    TB_WRITE(c, AW_COST_OFFSET,         CVA6_AW_COST(c));
    TB_WRITE(c, AR_COST_OFFSET,         CVA6_AR_COST(c));
  }

  // =========================================================================
  // 3. Read back and verify CVA6's writes took effect
  // =========================================================================
  printf("--- CVA6 Readback Check ---\r\n");
  for (int c = 0; c < NUM_CORES; c++) {
    read_val = TB_READ(c, TOKEN_LIMIT_OFFSET);
    if (read_val != CVA6_TOKEN_LIMIT(c)) {
      printf("FAIL core%d: TOKEN_LIMIT expected 0x%x, got 0x%x\r\n", c, CVA6_TOKEN_LIMIT(c), read_val);
      error_count++;
    } else {
      printf("PASS core%d: TOKEN_LIMIT     = 0x%x\r\n", c, read_val);
    }

    read_val = TB_READ(c, REFILL_TOKENS_OFFSET);
    if (read_val != CVA6_REFILL_TOKENS(c)) {
      printf("FAIL core%d: REFILL_TOKENS expected 0x%x, got 0x%x\r\n", c, CVA6_REFILL_TOKENS(c), read_val);
      error_count++;
    } else {
      printf("PASS core%d: REFILL_TOKENS   = 0x%x\r\n", c, read_val);
    }

    read_val = TB_READ(c, REFILL_INTERVAL_OFFSET);
    if (read_val != CVA6_REFILL_INTERVAL(c)) {
      printf("FAIL core%d: REFILL_INTERVAL expected 0x%x, got 0x%x\r\n", c, CVA6_REFILL_INTERVAL(c), read_val);
      error_count++;
    } else {
      printf("PASS core%d: REFILL_INTERVAL = 0x%x\r\n", c, read_val);
    }

    read_val = TB_READ(c, AW_COST_OFFSET);
    if (read_val != CVA6_AW_COST(c)) {
      printf("FAIL core%d: AW_COST expected 0x%x, got 0x%x\r\n", c, CVA6_AW_COST(c), read_val);
      error_count++;
    } else {
      printf("PASS core%d: AW_COST         = 0x%x\r\n", c, read_val);
    }

    read_val = TB_READ(c, AR_COST_OFFSET);
    if (read_val != CVA6_AR_COST(c)) {
      printf("FAIL core%d: AR_COST expected 0x%x, got 0x%x\r\n", c, CVA6_AR_COST(c), read_val);
      error_count++;
    } else {
      printf("PASS core%d: AR_COST         = 0x%x\r\n", c, read_val);
    }
  }
  uart_wait_tx_done();

  // =========================================================================
  // 4. CTRL enable/disable for each core
  // =========================================================================
  printf("--- CTRL Enable/Disable ---\r\n");
  for (int c = 0; c < NUM_CORES; c++) {
    TB_WRITE(c, CTRL_OFFSET, CTRL_ENABLE);
    read_val = TB_READ(c, CTRL_OFFSET);
    if (read_val != CTRL_ENABLE) {
      printf("FAIL core%d: CTRL enable expected 0x%x, got 0x%x\r\n", c, CTRL_ENABLE, read_val);
      error_count++;
    } else {
      printf("PASS core%d: CTRL enable     = 0x%x\r\n", c, read_val);
    }

    TB_WRITE(c, CTRL_OFFSET, CTRL_DISABLE);
    read_val = TB_READ(c, CTRL_OFFSET);
    if (read_val != CTRL_DISABLE) {
      printf("FAIL core%d: CTRL disable expected 0x%x, got 0x%x\r\n", c, CTRL_DISABLE, read_val);
      error_count++;
    } else {
      printf("PASS core%d: CTRL disable    = 0x%x\r\n", c, read_val);
    }
  }
  uart_wait_tx_done();

  // =========================================================================
  // 5. Cross-core isolation: Making sure that writing cfg to one core doesn't disturb other cores. 
  // =========================================================================
  printf("--- Cross-Core Isolation ---\r\n");
  for (int c = 0; c < NUM_CORES; c++) {
    TB_WRITE(c, TOKEN_LIMIT_OFFSET, ISOLATION_SENTINEL);

    int leaked = 0;
    for (int o = 0; o < NUM_CORES; o++) {
      if (o == c) continue;
      read_val = TB_READ(o, TOKEN_LIMIT_OFFSET);
      if (read_val != CVA6_TOKEN_LIMIT(o)) {
        printf("FAIL: write to core%d disturbed core%d (expected 0x%x, got 0x%x)\r\n",
               c, o, CVA6_TOKEN_LIMIT(o), read_val);
        error_count++;
        leaked = 1;
      }
    }

    read_val = TB_READ(c, TOKEN_LIMIT_OFFSET);
    if (read_val != ISOLATION_SENTINEL) {
      printf("FAIL core%d: sentinel write expected 0x%x, got 0x%x\r\n", c, ISOLATION_SENTINEL, read_val);
      error_count++;
      leaked = 1;
    }

    if (!leaked) {
      printf("PASS core%d: isolated write OK\r\n", c);
    }

    TB_WRITE(c, TOKEN_LIMIT_OFFSET, CVA6_TOKEN_LIMIT(c));
  }
  uart_wait_tx_done();

  // =========================================================================
  // 6. Final result
  // =========================================================================
  if (error_count == 0) {
    printf("Token Bucket Test PASSED (%d errors)\r\n", error_count);
  } else {
    printf("Token Bucket Test FAILED (%d errors)\r\n", error_count);
  }
  uart_wait_tx_done();



  return 0;
}
