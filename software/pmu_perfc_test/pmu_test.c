#include "encoding.h"
#include <stdio.h>
#include <stdlib.h>
#include "utils.h"
#include "pmu_test_func.c"

// The CUA will always miss in the L1 but after one run of the loop, it will never miss in the LLC.
#define NUM_NON_CUA 3

// ********************************************************************************************************//
// Change LEN_CUA to generate L1 hits, L1 misses, L2 hits, L2 misses
// Hit would be when LEN_CUA < Lx and miss would be when LEN_CUA > Lx
// #define LEN_CUA 262144    // To convert this length into bytes multiply by 8 right now it is 2MB
// Defining LEN_CUA to be a hit in LLC:
#define LEN_CUA 8096
// Choose either RD or WR for CUA
#define CUA_RD
// #define CUA_WR
// mhartid you can put always 0. count: try to put >= 3

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

void pmu_cntr_config() {

// ************************************************************************************//
    // THIS PORTION IS USED FOR CONFIGURING THE PMU COUNTERS TO TRACK THE CVA6 PERFORMANCE COUNTERS AND PC_MILESTONES.
    // EVENT_INFO_VAL IS AN ARRAY HOLDING THE E_INFO VALUES.
    // FOR PC_MILESTONE_C0 => {OPERATION_MODE=1, ADD_OPERATION OPCODE = 0, EISF_END = 3}
    uint32_t event_info_val[12] = {0x00800060, 0x00800060, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    // EVENT_SEL_VAL IS AN ARRAY HOLDING THE E_SEL VALUES.
    uint32_t event_sel_val[12]  = {PC_MILESTONE_C0, PC_MILESTONE_C1, 
      PERF_COUNTER_EVU_C0_EV0, PERF_COUNTER_EVU_C0_EV1, PERF_COUNTER_EVU_C0_EV2,
      PERF_COUNTER_EVU_C1_EV0, PERF_COUNTER_EVU_C1_EV1, PERF_COUNTER_EVU_C1_EV2, LLC_RD_REQ_CORE_0, LLC_RD_RES_CORE_0, MEM_RD_REQ, MEM_RD_RES
    };
    // write_32b_regs(EVENT_INFO_BASE_ADDR, num_counter, event_info, COUNTER_BUNDLE_SIZE);
    write_32b_regs(EVENT_INFO_BASE_ADDR, 12, event_info_val, COUNTER_BUNDLE_SIZE);
    // write_32b_regs(EVENT_SEL_BASE_ADDR, num_counter, event_sel, COUNTER_BUNDLE_SIZE);
    write_32b_regs(EVENT_SEL_BASE_ADDR, 12, event_sel_val, COUNTER_BUNDLE_SIZE);
    // core 0 initializes the synchronization variable and prints hello before core 1

}

void cua_core(uint32_t mhartid, int count, uint64_t eventIDBaseAddr,
  uint64_t eventIDValues[4],
  uint64_t pcMilesBaseAddr,
  uint64_t pcmilestones[4]) {

lock(mhartid);
printf("Core: %d -> Initial Print coming from Core: %d\r \n", mhartid, mhartid);
uart_wait_tx_done();
unlock(mhartid);

// ************************************************************************************//
// WRITING THE EVENTIDs AND PC MILESTONES TO THE RESPECTIVE REGISTERS

asm volatile("fence");

write_32b(eventIDBaseAddr,        eventIDValues[0]);
write_32b(eventIDBaseAddr+4,      eventIDValues[1]);
write_32b(eventIDBaseAddr+8,      eventIDValues[2]);
write_32b(eventIDBaseAddr+12,     eventIDValues[3]);
write_32b(pcMilesBaseAddr,        pcmilestones[0]);
write_32b(pcMilesBaseAddr+8,      pcmilestones[1]);
write_32b(pcMilesBaseAddr+16,     pcmilestones[2]);
write_32b(pcMilesBaseAddr+24,     pcmilestones[3]);
lock(mhartid);
printf("Core: %d -> PMU Configured. Moving onto run the cua_core in Core : %d\r \n", mhartid, mhartid);
uart_wait_tx_done();
unlock(mhartid);

uint64_t var;
volatile uint64_t *array = (uint64_t*)(uint64_t)(0x82000000 + mhartid * 0x01000000);
for (int i=0; i<count; i++) {       
  # if defined (CUA_RD) || defined (CUA_WR)
  for (int a_idx = 0; a_idx < LEN_CUA; a_idx +=8) {
    #ifdef CUA_RD
    asm volatile (
      "ld   %0, 0(%1)\n"
      : "=r"(var)
      : "r"(array - a_idx)
    );
    #elif defined(CUA_WR)
    asm volatile (
      "sd   %0, 0(%1)\n"
      :: "r"(var),
      "r"(array - a_idx)
    );
    #endif
  }
  #endif
	}
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

// Sometimes the UART skips over output.
// Gives the UART more time to finish output before filling up the UART Tx FIFO with more data.
void my_sleep() {
  uint32_t sleep = 100000;
  for (volatile uint32_t i=0; i<sleep; i++) {
    asm volatile ("fence");
    asm volatile ("addi x1, x1, 1");
    asm volatile ("fence");
  }  
}

void end_test(uint32_t mhartid){
  lock(mhartid);
  printf("Exiting: %0d.\r\n", mhartid);
  unlock(mhartid);
}

#define read_32b(addr)         (*(volatile uint32_t *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile uint32_t *)(long)(addr) = val_)

// *********************************************************************
// Main Function
// *********************************************************************
volatile uint64_t count __attribute__((section(".nocache_share_region")));

int thread_entry(int cid, int nc){
  int * pointer;
  int mbox_id = 10;
  int num_cores = 2;

  // Ack opentitan irq
  pointer = (int *) 0x10404020;
  *pointer = 0x1;

  #ifdef FPGA_EMULATION
  uint32_t baud_rate = 9600;
  uint32_t test_freq = 100000000;
  #else
  set_flls();
  uint32_t baud_rate = 115200;
  uint32_t test_freq = 50000000;
  #endif
  uart_set_cfg(0,(test_freq/baud_rate)>>4);
  count = 0;

  uint64_t misa = read_csr(misa);
  if(!(misa & 0x80)){
    printf("Hypervisor extension MISSING!\r\n");
    uart_wait_tx_done();
    return -1;
  }

  if (cid == 0){
    pmu_cntr_config();
    uint64_t pcMilestones_core0[4]  = {PCMILESTONE_C0_ADDR0, PCMILESTONE_C0_ADDR1, PCMILESTONE_C0_ADDR2, PCMILESTONE_C0_ADDR3};
    uint64_t eventIDValues_core0[4] = {PERF_COUNTER_EVU_C0_EID0, PERF_COUNTER_EVU_C0_EID1, PERF_COUNTER_EVU_C0_EID2, PERF_COUNTER_EVU_C0_EID3};
    
    asm volatile("fence");

    cua_core(cid, 3, EVENTID_CO_BASE_ADDR, eventIDValues_core0, PC_MILESTONE_C0_BASE_ADDR, pcMilestones_core0);

    lock(cid);
    printf("Core: %d -> CUA_CORE EXECUTED FOR CORE: %d\r\n", cid, cid);
    uart_wait_tx_done();
    unlock(cid);

    end_test(cid);
    uart_wait_tx_done();
  }
  else{
    uint64_t pcMilestones_core1[4]  = {PCMILESTONE_C1_ADDR0, PCMILESTONE_C1_ADDR1, PCMILESTONE_C1_ADDR2, PCMILESTONE_C1_ADDR3};
    uint64_t eventIDValues_core1[4] = {PERF_COUNTER_EVU_C1_EID0, PERF_COUNTER_EVU_C1_EID1, PERF_COUNTER_EVU_C1_EID2, PERF_COUNTER_EVU_C1_EID3};

    asm volatile("fence");
        // cua_core(mhartid, 3);
    cua_core(cid, 3, EVENTID_C1_BASE_ADDR, eventIDValues_core1, PC_MILESTONE_C1_BASE_ADDR, pcMilestones_core1);;
    lock(cid);
    printf("Core: %d -> CUA_CORE EXECUTED FOR CORE: %d\r\n", cid, cid);
    uart_wait_tx_done();
    unlock(cid);

    end_test(cid);
    uart_wait_tx_done();

  }

  count++;

  // cores wait here
  if(cid != 0){
    while (1)
       asm volatile ("wfi");

  // core 0 continues after all cores have finished
  } else{
      while (count < num_cores)
         asm volatile ("nop");
  }
  return 0;
}


