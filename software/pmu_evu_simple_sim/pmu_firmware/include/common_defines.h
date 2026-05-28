#ifndef __COMMON_DEFINES_H__
#define __COMMON_DEFINES_H__

// Macros for 32-bit read-write to memory address.
#define read_32b(addr)         (*(volatile int *)(long)(addr))
#define write_32b(addr, val_)  (*(volatile int *)(long)(addr) = val_)

// Macros for debug printf to memory
#define PRINT_START_ADDRESS ((volatile char *)0x10428800)
#define PRINT_END_ADDRESS   ((volatile char *)0x10428FFC)

// Macros for PMU Receiver Queue
#define QUEUE_HEAD_ADDR 0x10428000  // Address of head pointer (producer)
#define QUEUE_TAIL_ADDR 0x10428004  // Address of tail pointer (consumer)
#define QUEUE_START_ADDR 0x10428008  // Start of the queue
#define QUEUE_SIZE 0x3F8  // Define the queue size minus head ADDR and Tail ADDR
// QUEUE Size currently ~ 1K bytes

#endif