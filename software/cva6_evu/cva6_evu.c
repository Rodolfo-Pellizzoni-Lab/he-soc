/*
CVA6-EVU test: checks all three event categories on Core 1.
  1) Generic   - 25 stores.
  2) Context   - 8 scontext changes: event count, PID sum (e_info[14:0]),
                 s_id filter (M = 8, S = 0).
  3) Milestone - 4 PC probes x5.
hcontext is only checked for unexpected events (expected 0); it is never written.

The test depends on the new version of pmu_defines.h and evu_defines.h, which can be found in the inc/pmu directory.
*/


#include <stdio.h>
#include <stdint.h>
#include "pmu_defines.h"
#include "evu_defines.h"
#include "encoding.h"

#define read_32b(addr)       (*(volatile uint32_t *)(uintptr_t)(addr))
#define write_32b(addr, val) (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

#define CORE1_START_FLAG  (DSPM_BASE_ADDR + 0x10UL)
#define CORE1_STAGE_FLAG  (DSPM_BASE_ADDR + 0x20UL)
#define CORE1_DUMMY_STORE_ADDR  (DSPM_BASE_ADDR + 0x30UL)
#define CORE1_STORE_DELTA  (DSPM_BASE_ADDR + 0x40UL)

#define ITER 5
#define NUM_CONTEXT_EVENTS 8
#define NUM_GENERIC_EVENTS 25
#define PID_SUM 66543 // 3 + 4 + 5 + 32432 + 32767 + 12 + 120 + 1200
#define M_MODE_COUNT 8

// Address Stubs
__attribute__((noinline, optimize("O0")))
void probe0(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe1(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe2(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe3(void) { asm volatile("" ::: "memory"); }

// Benchmark functions (Core 1 executes these)
__attribute__((noinline))
void func_A(void) {
    probe0();                          /* entry marker — PC milestone 0 */
    volatile uint32_t acc = 0;
    for (int i = 0; i < 256; i++)
        acc += (uint32_t)i * (uint32_t)i;
    (void)acc;
    probe1();                          /* exit marker  — PC milestone 1 */
}

__attribute__((noinline))
void func_B(void) {
    probe2();                          /* entry marker — PC milestone 2 */
    volatile uint32_t acc = 0;
    for (int i = 0; i < 256; i++)
        acc += (uint32_t)i * 3U;
    (void)acc;
    probe3();                          /* exit marker  — PC milestone 3 */
}

void scontext_write(uint32_t val){
    asm volatile("csrrw x0, 0x5a8, %0" ::"r"(val): "memory"); 
}
__attribute__((optimize("O2")))
void generic_events(uint32_t count){
    uint32_t val = 0xBEEF;
    uintptr_t addr = CORE1_DUMMY_STORE_ADDR; 
    for(uint32_t i = 0; i < count; i++){
        asm volatile("sw %0, 0(%1)" :: "r"(val), "r"(addr): "memory");
    }
}

void thread_entry(int cid, int nc){
}

int main(void){
    uint32_t mhartid = read_csr(mhartid);

    if(mhartid == 0) {
        const char *labels[4] = {
            "func_A entry (probe0)",
            "func_A exit  (probe1)",
            "func_B entry (probe2)",
            "func_B exit  (probe3)"
        };


        printf("[CORE0] Programming Core 1 CVA6-EVU...\n");
        // evu_defines.h handles the EVU register map bug.
        write_32b(EVU_C1_EVENT_ID(3), EVU_EVENT_HCONTEXT_CHANGE);  // +0 , e_id = 0x8
        write_32b(EVU_C1_EVENT_ID(2), EVU_EVENT_SCONTEXT_CHANGE);  // +4 , e_id = 0x4
        write_32b(EVU_C1_EVENT_ID(1), EVU_EVENT_PC_MILESTONE);     // +8 , e_id = 0x2
        write_32b(EVU_C1_EVENT_ID(0), EVU_EVENT_STORE);            // +12, e_id = 0x1

        write_32b(EVU_C1_PCM_LO(0), (uint32_t)(uintptr_t)probe0);
        write_32b(EVU_C1_PCM_HI(0), 0);
        write_32b(EVU_C1_PCM_LO(1), (uint32_t)(uintptr_t)probe1);
        write_32b(EVU_C1_PCM_HI(1), 0);
        write_32b(EVU_C1_PCM_LO(2), (uint32_t)(uintptr_t)probe2);
        write_32b(EVU_C1_PCM_HI(2), 0);
        write_32b(EVU_C1_PCM_LO(3), (uint32_t)(uintptr_t)probe3);
        write_32b(EVU_C1_PCM_HI(3), 0);
        
        asm volatile("fence iorw, iorw" ::: "memory");

        printf("[CORE0] probe0=0x%08x probe1=0x%08x probe2=0x%08x probe3=0x%08x\n",
            (uint32_t)(uintptr_t)probe0, (uint32_t)(uintptr_t)probe1,
            (uint32_t)(uintptr_t)probe2, (uint32_t)(uintptr_t)probe3);        
        
        // Configure the APMU counters
        printf("[CORE0] Configuring APMU counters...\n");
        // Counter 0 counts store events on port 2.
        write_32b(EVENT_SEL_ADDR(0), EVSEL_PORT(2, 0b1111) | EVSEL_EVENT(1, 0b0001));
        write_32b(EVENT_INFO_ADDR(0), 0);

        // Counter 1 counts only scontext change events on port 2.
        write_32b(EVENT_SEL_ADDR(1), EVSEL_PORT(2, 0b1111) | EVSEL_EVENT(4, 0b0100));
        write_32b(EVENT_INFO_ADDR(1), 0);

        // Counter 2 records the sum of the observed PIDs.
        write_32b(EVENT_SEL_ADDR(2), EVSEL_PORT(2, 0b1111) | EVSEL_EVENT(4, 0b0100));
        write_32b(EVENT_INFO_ADDR(2), EVINFO_INFO_EN | EVINFO_EISF(0, 14));     
        // Counters 3 to 6 count PC milestones 0 to 3.
        for(int n = 3; n < 7; n++){
            write_32b(EVENT_SEL_ADDR(n), EVSEL_PORT(2, 0b1111) | EVSEL_EVENT(2, 0b0010));
            write_32b(EVENT_INFO_ADDR(n), EVINFO_INFO_EN | EVINFO_EISF(n-3, n-3));
        }

        // Counter 7 counts scontext changes in M-mode (s_id = 0b0011).
        write_32b(EVENT_SEL_ADDR(7), EVSEL_PORT(2, 0b1111) | EVSEL_SRC(3, 0b1111) | EVSEL_EVENT(4, 0b0100));
        write_32b(EVENT_INFO_ADDR(7), 0);

        // Counter 8 counts scontext changes in S-mode (s_id = 0b0001).
        write_32b(EVENT_SEL_ADDR(8), EVSEL_PORT(2, 0b1111) | EVSEL_SRC(1, 0b1111) | EVSEL_EVENT(4, 0b0100));
        write_32b(EVENT_INFO_ADDR(8), 0);
        
        // Counter 9 counts hcontext changes; expected 0.
        write_32b(EVENT_SEL_ADDR(9), EVSEL_PORT(2, 0b1111) | EVSEL_EVENT(8, 0b1000));
        write_32b(EVENT_INFO_ADDR(9), 0);
        
        // Reset counters 0 to 9
        for(int n = 0; n < 10; n++)
            write_32b(COUNTER_ADDR(n), 0);

        asm volatile("fence iorw, iorw" ::: "memory");

        // Start Core 1
        printf("[CORE0] Signalling Core 1 to start...\n");
        write_32b(CORE1_STAGE_FLAG, 0);
        asm volatile("fence iorw, iorw" ::: "memory");

        write_32b(CORE1_START_FLAG, 1);
        asm volatile("fence iorw, iorw" ::: "memory");


        // // Stage 1
        // printf("[CORE0] Stage 1. Generic Events (Store Access) Start: c0=0x%08x\n", cntr_read(0));
        // while (read_32b(CORE1_STAGE_FLAG) == 1);               
        // printf("[CORE0] Stage 1. Generic Events (Store Access) End: c0=0x%08x\n", cntr_read(0));
        
        // // Stage 2
        // printf("[CORE0] Stage 2. SCONTEXT_CHANGE Events Start: c1=0x%08x c2=0x%08x\n", cntr_read(1), cntr_read(2));
        // while (read_32b(CORE1_STAGE_FLAG) == 2);               
        // printf("[CORE0] Stage 2. SCONTEXT_CHANGE Events End: c1=0x%08x c2=0x%08x\n", cntr_read(1), cntr_read(2));

        // printf("[CORE0] Stage 3. PCM Events Start: c3=0x%08x c4=0x%08x c5=0x%08x c6=0x%08x\n",
        //        cntr_read(3), cntr_read(4), cntr_read(5), cntr_read(6));
        // while (read_32b(CORE1_STAGE_FLAG) == 3);
        // printf("[CORE0] Stage 3. PCM Events End: c3=0x%08x c4=0x%08x c5=0x%08x c6=0x%08x\n",
        //        cntr_read(3), cntr_read(4), cntr_read(5), cntr_read(6));

        while (read_32b(CORE1_STAGE_FLAG) != 4);
               
        // Scoreboard
        uint32_t err = 0;
        uint32_t delta = read_32b(CORE1_STORE_DELTA);
        uint32_t cnt1 = cntr_read(1) & COUNT_MASK;
        uint32_t cnt2 = cntr_read(2) & COUNT_MASK;
        uint32_t cnt7 = cntr_read(7) & COUNT_MASK; // M-mode
        uint32_t cnt8 = cntr_read(8) & COUNT_MASK; // S-mode
        uint32_t cnt9 = cntr_read(9) & COUNT_MASK;

        printf("[CORE0] Number of Generic Events (Store Access). Got: %u, Expected: %d\n", delta, NUM_GENERIC_EVENTS);
        if(delta != NUM_GENERIC_EVENTS)
            err++;    

        printf("[CORE0] Number of SCONTEXT Events. Got: %u, Expected: %d\n", cnt1, NUM_CONTEXT_EVENTS);
        if(cnt1 != NUM_CONTEXT_EVENTS)
            err++;
        printf("[CORE0] Sum of all transmitted PIDs. Got: %u, Expected: %d\n", cnt2, PID_SUM);
        if(cnt2 != PID_SUM)
            err++;

        printf("[CORE0] Number of M-mode SCONTEXT Events. Got: %u, Expected: %d\n", cnt7, M_MODE_COUNT);
        if(cnt7 != M_MODE_COUNT)
            err++;

        printf("[CORE0] Number of S-mode SCONTEXT Events. Got: %u, Expected: %d\n", cnt8, 0);
        if(cnt8 != 0)
            err++;

        printf("[CORE0] Number of HCONTEXT Events. Got: %u, Expected: %d\n", cnt9, 0);
        if(cnt9 != 0)
            err++;

        for(int n = 3; n < 7; n++){
            uint32_t cnt = cntr_read(n) & COUNT_MASK;
            printf("[CORE0] PC milestone %d, %s hits. Got: %u, Expected: %u\n",
                   n-3, labels[n-3], cnt, (unsigned)ITER);
            if(cnt != (unsigned)ITER)
                err++;
        }

        if(err)
            printf("[CORE0] FAIL\n");
        else
            printf("[CORE0] PASS\n");

    } else if (mhartid == 1) {
        while (read_32b(CORE1_START_FLAG) == 0)
            asm volatile("" ::: "memory");
        // Stage 1.
        write_32b(CORE1_STAGE_FLAG, 1);
        asm volatile("fence iorw, iorw" ::: "memory");
        // Core 1 snapshots counter 0 itself to get an accurate store count
        uint32_t cnt0_before = cntr_read(0) & COUNT_MASK;
        generic_events(NUM_GENERIC_EVENTS);
        asm volatile("fence iorw, iorw" ::: "memory");
        uint32_t cnt0_after = cntr_read(0) & COUNT_MASK;
        uint32_t delta = cnt0_after - cnt0_before;
        write_32b(CORE1_STORE_DELTA, delta);

        // Stage 2. SCONTEXT change events.
        write_32b(CORE1_STAGE_FLAG, 2);
        scontext_write(3);
        scontext_write(4);
        scontext_write(5);
        scontext_write(65200); // Wider than the CSR: only the lower 15 bits are kept, so the value is 32432
        scontext_write(32767); // Largest PID that fits in the CSR
        scontext_write(12);
        scontext_write(120);
        scontext_write(1200);
        scontext_write(1200);  // Same value: no scontext change, no event

        write_32b(CORE1_STAGE_FLAG, 3);
        // Stage 3. PCM Events
        for(int i = 0; i < ITER; i++) {
            func_A();
            func_B();
        }
        asm volatile("fence iorw, iorw" ::: "memory");
        write_32b(CORE1_STAGE_FLAG, 4);
        asm volatile("fence iorw, iorw" ::: "memory");
        while (1) asm volatile("wfi");

    } else {
        /* Other cores: park */
        while (1)
            asm volatile("wfi");        
    }
}