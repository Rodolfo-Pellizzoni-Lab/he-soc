#ifndef __COMMON_DEFINES_H__
#define __COMMON_DEFINES_H__

#include "../../../quad_boot/pmu_defines.h"

// Macros for 32-bit read-write to memory address.
#define read_32b(addr)         (*(volatile int *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile int *)(long)(addr) = val_)

// Macros for debug printf to memory
#define PRINT_START_ADDRESS ((volatile char *)(DSPM_BASE_ADDR + 0x800))
#define PRINT_END_ADDRESS   ((volatile char *)(DSPM_BASE_ADDR + 0xFFC))

// Macros for PMU Receiver Queue
#define QUEUE_HEAD_ADDR (DSPM_BASE_ADDR + 0x0)  // Address of head pointer (producer)
#define QUEUE_TAIL_ADDR (DSPM_BASE_ADDR + 0x4)  // Address of tail pointer (consumer)
#define QUEUE_START_ADDR (DSPM_BASE_ADDR + 0x8)  // Start of the queue
#define QUEUE_SIZE 0x3F8  // Define the queue size minus head ADDR and Tail ADDR
// QUEUE Size currently ~ 1K bytes

#endif