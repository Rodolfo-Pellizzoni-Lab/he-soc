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
#define LEN_CUA 8000
// Choose either RD or WR for CUA
#define CUA_RD
// #define CUA_WR
// mhartid you can put always 0. count: try to put >= 3
void cua_core(uint32_t mhartid, int count){
  printf("Inside the CUA CORE function, hartID:%d \n", mhartid);
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
// void my_sleep() {
//   uint32_t sleep = 100000;
//   for (volatile uint32_t i=0; i<sleep; i++) {
//     // asm volatile ("fence");
//     // asm volatile ("addi x1, x1, 1");
//     // asm volatile ("fence");
//   }  
// }

void end_test(uint32_t mhartid){
  printf("Exiting: %0d.\r\n", mhartid);
}

#define read_32b(addr)         (*(volatile uint32_t *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile uint32_t *)(long)(addr) = val_)

int thread_entry(int cid, int nc){
  // printf("Hello Culsans! I'm Core %d!\r\n", cid);
  // uart_wait_tx_done();
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

    while (1) {    
    }


  // *******************************************************************
  // Core 1-3
  // *******************************************************************
  } else if (mhartid == 1) {
      printf("Hello from Core %d!! :) \n", mhartid);

      // ************************************************************************************//
      // THIS PORTION IS FOR COUNTER 0, 1, 2, 3 TO TRACK REQUESTS & RESPONSES BETWEEN CORE0<=>LLC, & LLC<=>MAIN MEM
      uint32_t event_sel_val[4] = {LLC_RD_REQ_CORE_1, LLC_RD_RES_CORE_1, MEM_RD_REQ, MEM_RD_RES};
      uint32_t event_info_val[4] = {0, 0, 0, 0};
      // write_32b_regs(EVENT_SEL_BASE_ADDR, num_counter, event_sel, COUNTER_BUNDLE_SIZE);
      write_32b_regs(EVENT_SEL_BASE_ADDR, 4, event_sel_val, COUNTER_BUNDLE_SIZE);
      // write_32b_regs(EVENT_INFO_BASE_ADDR, num_counter, event_info, COUNTER_BUNDLE_SIZE);
      write_32b_regs(EVENT_INFO_BASE_ADDR, 4, event_info_val, COUNTER_BUNDLE_SIZE);
      // ************************************************************************************//
      printf("Printing after PMU config, hartID:%d \n", mhartid);
      // cua_core(mhartid, 3);
      cua_core(1, 3);
      // asm volatile ("fence");
      printf("Line After the cua_core function, hartID:%d \n", mhartid);
      // asm volatile ("fence");
      end_test(mhartid);
      uart_wait_tx_done();

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