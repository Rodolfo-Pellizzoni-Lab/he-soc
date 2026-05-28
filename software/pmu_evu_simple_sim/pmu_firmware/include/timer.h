#ifndef __TIMER_H__
#define __TIMER_H__

#include <stdint.h>

#define __APMU_CLOCK_FREQ__ 50000000   // 50 MHz

// Function to get the current cycle count
uint64_t get_cycles(void);

// Function to create a delay in cycles
void delay_cycles(uint32_t cycles);

// Function to get the current time in microseconds
uint64_t get_time_us(void);

// Function to create a delay in microseconds
void delay_time_us(uint32_t microseconds);

#endif // __TIMER_H__
