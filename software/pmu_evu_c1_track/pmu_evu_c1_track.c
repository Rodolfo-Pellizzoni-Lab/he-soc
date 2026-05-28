/*
 * pmu_evu_c1_track.c — CVA6-EVU PC Milestone Tracking Test (Core 1)
 *
 * Core 0 role:
 *   1. Writes Core 1's CVA6-EVU registers: EVENTID1=0x17 (PC milestone), PC addresses
 *   2. Configures 4 APMU counter bundles to detect each individual milestone hit
 *   3. Signals Core 1 to start
 *   4. Polls counters 0-3 in order; prints a message on each hit
 *
 * Core 1 role:
 *   1. Waits for Core 0's go signal
 *   2. Calls func_A() then func_B(), each instrumented with entry/exit probes
 *
 * EVU register layout for Core 1 (cva6_synth_wrap.sv flip bug accounted for):
 *   EVENTID2 reg (0x10606038, addr+8) → ev_id2 field (bits[9:5]) → perf slot i=1
 *     → perfc_resp[1]=1 → e_id[1]=1 → e_id=0x2  (matches EVU_C1_EV1_SEL event_id_val=2)
 *   PC milestones 0-3 (0x10606040..0x1060605F): compared against commit_pc
 *   When milestone N matches: e_info[N] = 1 in the outgoing event packet
 *
 * APMU counter configuration:
 *   Event Selection Cfg: port_id_val=2, port_id_mask=0xF, event_id_val=0x2, mask=0x2
 *   Event Info Cfg for counter N: INCR_CMP_EQ, extract e_info[N:N], compare == 1
 */

#include "encoding.h"
#include <stdio.h>
#include <stdint.h>

/* ---------------------------------------------------------------------------
 * Memory-mapped I/O primitives
 * ---------------------------------------------------------------------------*/
#define read_32b(addr)        (*(volatile uint32_t *)(uintptr_t)(addr))
#define write_32b(addr, val)  (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

/* ---------------------------------------------------------------------------
 * PMU address map (from pmu_top.sv)
 * ---------------------------------------------------------------------------*/
#define PMU_B_BASE_ADDR      0x10405000UL
#define PMU_BUNDLE_SIZE      0x2000UL
#define COUNTER_B_BASE_ADDR  (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)  /* 0x10407000 */
#define COUNTER_BUNDLE_SIZE  0x1000UL

/* Offsets within a counter bundle */
#define CNTR_OFF   0x0   /* counter value */
#define SEL_OFF    0x4   /* Event Selection Cfg */
#define INFO_OFF   0x8   /* Event Info Cfg */

/* ---------------------------------------------------------------------------
 * CVA6-EVU registers for Core 1 (cva6_synth_wrap.sv)
 * ---------------------------------------------------------------------------*/
#define EVENTID_C1_BASE      0x10606030UL   /* EID0..EID3 at +0,+4,+8,+C */
#define PC_MILESTONE_C1_BASE 0x10606040UL   /* 4 × (lo32, hi32) at +0..+1C */

/* ---------------------------------------------------------------------------
 * DSPM — inter-core synchronisation
 * ---------------------------------------------------------------------------*/
#define DSPM_BASE_ADDR   0x10428000UL
#define CORE1_START_FLAG (DSPM_BASE_ADDR + 0x10UL)

/* ---------------------------------------------------------------------------
 * APMU counter programming values
 *
 * Event Selection Cfg layout (32-bit, from pmu_pkg.sv):
 *   {pad[7:0], port_id_val[3:0], port_id_mask[3:0],
 *    source_id_val[3:0], source_id_mask[3:0],
 *    event_id_val[3:0], event_id_mask[3:0]}
 *
 * Core 1 → PORT_ID = 2 (pmu_port_wrap.sv i+1 convention)
 * EVU slot 1 fires → e_id = 0b0010 → event_id_val=0x2, event_id_mask=0x2
 *   → 0x00_2F_00_22
 * ---------------------------------------------------------------------------*/
#define EVU_C1_EV1_SEL  0x002F0022UL

/*
 * Event Info Cfg layout (32-bit):
 *   {pad[6:0], overflow_intr_en[1], event_info_en[1],
 *    val_u[3:0], val_l[3:0], opcode[4:0], eisf_end[4:0], eisf_start[4:0]}
 *
 * For counter N: extract e_info[N:N] (1 bit), ADD opcode (0)
 *   event_info_en=1 → bit 23
 *   opcode=0 (ADD)  → bits[14:10] = 0b00000
 *   eisf_end=N      → bits[9:5]
 *   eisf_start=N    → bits[4:0]
 * Adds e_info[N] (0 or 1) to counter → increments by 1 when milestone N fires
 */
#define EVU_INFO_CFG(n) \
    ((1UL << 23) | ((uint32_t)(n) << 5) | (uint32_t)(n))

/* ---------------------------------------------------------------------------
 * Probe stubs — noinline so each has a stable, unique address
 * Core 0 passes these addresses to the CVA6-EVU PC milestone registers.
 * ---------------------------------------------------------------------------*/
__attribute__((noinline, optimize("O0")))
void probe0(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe1(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe2(void) { asm volatile("" ::: "memory"); }

__attribute__((noinline, optimize("O0")))
void probe3(void) { asm volatile("" ::: "memory"); }

/* ---------------------------------------------------------------------------
 * Benchmark functions (Core 1 executes these)
 * probe0/probe1 bracket func_A; probe2/probe3 bracket func_B.
 * ---------------------------------------------------------------------------*/
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

/* ---------------------------------------------------------------------------
 * Helpers
 * ---------------------------------------------------------------------------*/
static inline uint32_t get_hartid(void) {
    uint32_t id;
    asm volatile ("csrr %0, mhartid" : "=r"(id));
    return id;
}

static inline uint32_t counter_read(int n) {
    return read_32b(COUNTER_B_BASE_ADDR + (uint32_t)n * COUNTER_BUNDLE_SIZE + CNTR_OFF);
}

static inline void counter_config(int n, uint32_t sel, uint32_t info) {
    write_32b(COUNTER_B_BASE_ADDR + (uint32_t)n * COUNTER_BUNDLE_SIZE + SEL_OFF,  sel);
    write_32b(COUNTER_B_BASE_ADDR + (uint32_t)n * COUNTER_BUNDLE_SIZE + INFO_OFF, info);
}

int thread_entry(int cid, int nc){
  return 0;
}

/* ---------------------------------------------------------------------------
 * Main
 * ---------------------------------------------------------------------------*/
int main(void)
{
    uint32_t hartid = get_hartid();

    if (hartid == 0) {
        /* ------------------------------------------------------------------ */
        /* Core 0 — Setup                                                      */
        /* ------------------------------------------------------------------ */

        printf("[CORE0] Programming Core 1 CVA6-EVU...\n");

        /* EVU event IDs: EVENTID2 reg (addr+8) = 0x17 (PC milestone)
         * addr+8 → ev_id2 field (bits[9:5] of perfc_req) → perf slot i=1
         * → perfc_resp[1]=1 → e_id[1]=1 → e_id=2
         * Matches EVU_C1_EV1_SEL event_id_val=2: (mask=2 & e_id=2)==2 ✓ */
        write_32b(EVENTID_C1_BASE + 0,  0x00);   /* EVENTID0: disabled */
        write_32b(EVENTID_C1_BASE + 4,  0x00);   /* EVENTID1: disabled */
        write_32b(EVENTID_C1_BASE + 8,  0x17);   /* EVENTID2: PC milestone → e_id=2 */
        write_32b(EVENTID_C1_BASE + 12, 0x00);   /* EVENTID3: disabled */

        /*
         * PC milestone addresses — lower 32 bits of each 64-bit register pair.
         * All four probe functions live in the same RV64 binary at 0x80xxxxxx,
         * so the upper 32 bits are zero.
         */
        write_32b(PC_MILESTONE_C1_BASE + 0,  (uint32_t)(uintptr_t)probe0);
        write_32b(PC_MILESTONE_C1_BASE + 4,  0);
        write_32b(PC_MILESTONE_C1_BASE + 8,  (uint32_t)(uintptr_t)probe1);
        write_32b(PC_MILESTONE_C1_BASE + 12, 0);
        write_32b(PC_MILESTONE_C1_BASE + 16, (uint32_t)(uintptr_t)probe2);
        write_32b(PC_MILESTONE_C1_BASE + 20, 0);
        write_32b(PC_MILESTONE_C1_BASE + 24, (uint32_t)(uintptr_t)probe3);
        write_32b(PC_MILESTONE_C1_BASE + 28, 0);

        asm volatile("fence iorw, iorw" ::: "memory");

        printf("[CORE0] probe0=0x%08x probe1=0x%08x probe2=0x%08x probe3=0x%08x\n",
               (uint32_t)(uintptr_t)probe0, (uint32_t)(uintptr_t)probe1,
               (uint32_t)(uintptr_t)probe2, (uint32_t)(uintptr_t)probe3);

        /* ------------------------------------------------------------------ */
        /* Configure APMU counters 0-3                                         */
        /* ------------------------------------------------------------------ */
        printf("[CORE0] Configuring 4 APMU counters...\n");

        for (int n = 0; n < 4; n++) {
            counter_config(n, EVU_C1_EV1_SEL, EVU_INFO_CFG(n));
        }

        asm volatile("fence iorw, iorw" ::: "memory");

        /* ------------------------------------------------------------------ */
        /* Signal Core 1 to start                                              */
        /* ------------------------------------------------------------------ */
        printf("[CORE0] Signalling Core 1 to start...\n");
        write_32b(CORE1_START_FLAG, 1);
        asm volatile("fence iorw, iorw" ::: "memory");

        /* ------------------------------------------------------------------ */
        /* Poll counters sequentially — known execution order:                 */
        /*   probe0 (func_A entry) → probe1 (func_A exit)                     */
        /*   probe2 (func_B entry) → probe3 (func_B exit)                     */
        /* ------------------------------------------------------------------ */
        static const char *labels[4] = {
            "func_A entry (probe0)",
            "func_A exit  (probe1)",
            "func_B entry (probe2)",
            "func_B exit  (probe3)",
        };
        static const char *ordinal[4] = { "1st", "2nd", "3rd", "4th" };

        for (int n = 0; n < 4; n++) {
            while (counter_read(n) == 0)
                asm volatile("" ::: "memory");
            printf("[CORE0] %s PC track successful: %s hit (count=%u)\n",
                   ordinal[n], labels[n], counter_read(n));
        }

        printf("[CORE0] All 4 PC milestones tracked successfully!\n");

    } else if (hartid == 1) {
        /* ------------------------------------------------------------------ */
        /* Core 1 — Wait for signal then run benchmark                         */
        /* ------------------------------------------------------------------ */
        while (read_32b(CORE1_START_FLAG) == 0)
            asm volatile("" ::: "memory");

        func_A();
        func_B();
        while (1) asm volatile("wfi");

    } else {
        /* Other cores: park */
        while (1)
            asm volatile("wfi");
    }

    return 0;
}
