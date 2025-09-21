#include "encoding.h"
#include <stdio.h>
#include <stdlib.h>
#include "utils.h"
#include "pmu_test_func.c"

// The CUA will always miss in the L1 but after one run of the loop, it will never miss in the LLC.
#define NUM_NON_CUA 3

__attribute__ ((section(".heapl2ram"))) volatile int flag[2] = { 0, 0};

__attribute__ ((section(".heapl2ram"))) volatile int victim = -1;

__attribute__ ((section(".heapl2ram"))) volatile int core_1 = -1;

static __attribute__ ((noinline)) void lock(int cid) {
 flag[cid] = 1;
 victim = cid;
 int other_cid = 1-cid;
 while( flag[other_cid] && (victim==cid) ) {
   __asm__ volatile("nop;");
 }
}

static __attribute__ ((noinline)) void unlock(int cid) {
 flag[cid] = 0;
}



// ********************************************************************************************************//

#ifndef TESTS_AUTO
  #define JUMP_CUA        8    // multiply by 8 for bytes
  #define JUMP_NONCUA     8    // multiply by 8 for bytes
  // #define LEN_NONCUA   32768
  // #define LEN_NONCUA   524288
  #define LEN_NONCUA   40960      // array size: 320 kB
  // #define LEN_NONCUA   262144  // array size: 2048 kB
  #define START_NONCUA    0
#endif


#define INTF_RD

void end_test(uint32_t mhartid){
  printf("Exiting: %0d.\r\n", mhartid);
}

#define read_32b(addr)         (*(volatile uint32_t *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile uint32_t *)(long)(addr) = val_)

int thread_entry(int cid, int nc){
  return 0;
}

// *********************************************************************
// Main Function
// *********************************************************************
int main(int argc, char const *argv[]) {
  
  volatile uint32_t read_target_0;
  volatile uint32_t read_target_1;
  volatile uint32_t read_target_2;
  volatile uint32_t read_target_3;

  

  uint32_t mhartid;
  asm volatile (
    "csrr %0, 0xF14\n"
    : "=r" (mhartid)
  );
  uint32_t dspm_base_addr;
  uint32_t read_target;
  uint32_t error_count = 0;

  // In RTL: PMU Connected to irq_sources 155 <=> 162
  // pmu_plic_id needs to be 156 <=> 163
  int pmu_plic_id1 = 156;
  int pmu_plic_id2 = 157;

  // *******************************************************************
  // Core 0
  // *******************************************************************
  if (mhartid == 0) {   
    #ifdef FPGA_EMULATION
    uint32_t baud_rate = 9600;
    uint32_t test_freq = 100000000;
    #else
    set_flls();
    uint32_t baud_rate = 115200;
    uint32_t test_freq = 50000000;
    #endif
    uart_set_cfg(0,(test_freq/baud_rate)>>4);

    // Fix for LLC Addr
    write_32b(0x1C + 0x1A106000, 0xA0000000);
    lock(mhartid);
    printf("Hello from Core0 %d!! :) \n", mhartid);
    unlock(mhartid);
    // PLIC code
    #define PLIC_BASE     0x0C000000
    #define PLIC_CHECK1    PLIC_BASE + 0x205004
    #define PLIC_CHECK2    PLIC_BASE + 0x207004
    //enable bits for sources 0-31
    #define PLIC_EN_BITS1  PLIC_BASE + 0x2280
    #define PLIC_EN_BITS2  PLIC_BASE + 0x2380
    
    
    // Initialazing the interrupt controller - 1
    pulp_write32(PLIC_BASE+pmu_plic_id1*4, 1);                                // set pmu interrupt priority to 1
    pulp_write32(PLIC_EN_BITS1+(((int)(pmu_plic_id1/32))*4), 1<<(pmu_plic_id1%32)); // enable interrupt
    lock(mhartid);
    printf("PLIC Configured \n");
    unlock(mhartid);
    // Initialazing the interrupt controller - 2
    pulp_write32(PLIC_BASE+pmu_plic_id2*4, 1);                                // set pmu interrupt priority to 1
    pulp_write32(PLIC_EN_BITS2+(((int)(pmu_plic_id2/32))*4), 1<<(pmu_plic_id2%32)); // enable interrupt

    // PMU Config
    uint32_t event_info_val = OVERFLOW_EN; 
    // Counter 0:
    write_32b (EVENT_INFO_BASE_ADDR, event_info_val);
    write_32b (COUNTER_BASE_ADDR, 0x40000000);
    lock(mhartid);
    printf("PMU Interrupt Raised - Counter0! \n");
    unlock(mhartid);
    // Counter 1:
    write_32b (EVENT_INFO_BASE_ADDR + COUNTER_BUNDLE_SIZE, event_info_val);
    write_32b (COUNTER_BASE_ADDR + COUNTER_BUNDLE_SIZE, 0x40000000);
    lock(mhartid);
    printf("PMU Interrupt Raised - Counter1! \n");
    unlock(mhartid);

    while (1) {    
    }


  // *******************************************************************
  // Core 1-3
  // *******************************************************************
  } else if (mhartid == 1) {
      lock(mhartid);
      printf("Hello from Core1 %d!! :) \n", mhartid);
      unlock(mhartid);


  } else if (mhartid == 2) {
      // Start of """Interrupt Service Routine""" (this code should be into an IRQ Handler)
      // printf("irq has been received and processed. :)\r\n");
      // pulp_write32(0x10407000, 0x00000000); // Cleaning the irq source
      // pulp_write32(PLIC_CHECK1, pmu_plic_id1);    // Completing irq (according to riscv specs)
      
      // Disabling the Overflow interrupt of PMU:
      // #define OVERFLOW_EN    0x1000000
      //   uint32_t event_info_val_disable = 0x0000000; 
      // // Counter 0:
      // write_32b (EVENT_INFO_BASE_ADDR, event_info_val_disable);
      // write_32b (COUNTER_BASE_ADDR, 0x40000000);

      //lock(mhartid);
      printf("Hello from Core2 %d!! :) \n", mhartid);
      //unlock(mhartid);

    

} else if (mhartid == 3) {
  
  printf("Hello from Core3 %d!! :) \n", mhartid);

} else if (mhartid <= NUM_NON_CUA) {
    uint64_t var;
    while (1) {    
    }
    
  } else {
    end_test(mhartid);
    uart_wait_tx_done();
    while (1);
  }
  return 0;
}