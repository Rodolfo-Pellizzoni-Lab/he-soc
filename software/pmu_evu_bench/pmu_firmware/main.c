/*
 * PMU Firmware — Exhaustive CVA6-EVU Test, Two-Function Profiler
 *
 * Proves that Ibex can:
 *   1. Write CVA6-EVU EID registers (0x10606000–0x1060600C) via AXI-lite
 *   2. Program PC milestone slots to gate event counting windows
 *   3. Use cnt_wfp to sleep efficiently between function entry and exit
 *   4. Profile two distinct functions sequentially (phase 1 = alu, phase 2 = cold)
 *
 * Counter allocation:
 *   20 = EVU EV1 (EID=0x17, PC milestone) → cnt_wfp target
 *   21 = EVU EV0 (EID=0x02, L1D miss)
 *   22 = EVU EV2 (EID=0x16, pipeline stalls)
 *   23 = EVU EV3 (EID=0x09, branch instructions)
 *    4 = LLC_RD_REQ_CORE_0
 *    8 = LLC_WR_REQ_CORE_0
 *   12 = MEM_RD_REQ_CORE_0
 *   16 = MEM_WR_REQ_CORE_0
 *   27 = MEM_RD_RES_CORE_0 + ADD_RESP_LAT
 *   28 = MEM_WR_RES_CORE_0 + ADD_RESP_LAT
 *
 * DSPM log layout (at DSPM_BASE_ADDR + 0x2000):
 *   +0x000: total_call_count  (uint32_t, incremented for every logged pair)
 *   +0x004: state             (uint32_t, 0=idle, 1=waiting_exit)
 *   +0x008 + N*0x30: slot N, 0x30 bytes:
 *       [0x00] delta_cycles      [0x04] delta_l1d_miss  [0x08] delta_stalls
 *       [0x0C] delta_branches    [0x10] delta_llc_rd    [0x14] delta_llc_wr
 *       [0x18] delta_mem_rd      [0x1C] delta_mem_wr    [0x20] delta_mem_rd_lat
 *       [0x24] delta_mem_wr_lat  [0x28] entry_mcycle    [0x2C] exit_mcycle
 *   Slots 0-3: func_alu_chain results
 *   Slots 4-7: func_l1_cold results
 *   +0x200: phase  (uint32_t, 1=alu active, 2=cold active)
 */

#include <stddef.h>
#include <stdint.h>
#include "include/pmu_hw_desc.h"

// DSPM communication addresses (must match pmu_evu_bench.c)
#define DSPM_STATUS_ADDR        (DSPM_BASE_ADDR + 0x00)
#define DSPM_CMD_ADDR           (DSPM_BASE_ADDR + 0x80)

// DSPM log layout
#define DSPM_LOG_BASE           (DSPM_BASE_ADDR + 0x2000)
#define DSPM_LOG_CALL_COUNT     (DSPM_LOG_BASE + 0x000)
#define DSPM_LOG_STATE          (DSPM_LOG_BASE + 0x004)
#define DSPM_LOG_SLOT(n)        (DSPM_LOG_BASE + 0x008 + (n) * 0x30)
#define DSPM_LOG_PHASE          (DSPM_LOG_BASE + 0x200)

// Status and command codes
#define STATUS_STARTED          0xBB000001
#define STATUS_SENDING_IRQS     0xBB000010
#define STATUS_ALL_IRQS_SENT    0xBB000099

#define CMD_NONE                0x00000000
#define CMD_TRIGGER_INTERRUPT   0x000000FF

// Memory access macros
#define WRITE_MEM(addr, value)  (*((volatile uint32_t*)(addr)) = (value))
#define READ_MEM(addr)          (*((volatile uint32_t*)(addr)))

// Number of profiling calls per function
#define N_CALLS_SHORT   4   // func_alu_chain
#define N_CALLS_LONG    4   // func_l1_cold
#define N_CALLS_TOTAL   (N_CALLS_SHORT + N_CALLS_LONG)

// Counter indices
#define CNT_IRQ_BASE       0
#define CNT_LLC_RD_C0      4
#define CNT_LLC_WR_C0      8
#define CNT_MEM_RD_C0      12
#define CNT_MEM_WR_C0      16
#define CNT_MILESTONE_0    20   // EVU EV1 (EID=0x17, PC milestone) → cnt_wfp target
#define CNT_L1D_MISS       21   // EVU EV0 (EID=0x02, L1D miss)
#define CNT_STALLS         22   // EVU EV2 (EID=0x16, pipeline stalls)
#define CNT_BRANCHES       23   // EVU EV3 (EID=0x09, branch instructions)
#define CNT_MEM_RD_LAT     27
#define CNT_MEM_WR_LAT     28

// CVA6-EVU event ID registers for Core 0 (Ibex writes these via AXI-lite)
#define EVENTID_C0_BASE_ADDR    0x10606000

// PC milestone slot 0 (64-bit register — lower 32 bits at this address)
#define PC_MILESTONE_SLOT0      0x10606010

// Phase 1 (func_alu_chain) PC milestone addresses — injected by two-pass build
#ifndef FUNC_ALU_ENTRY
#define FUNC_ALU_ENTRY   0x80003000U  // PLACEHOLDER
#endif
#ifndef FUNC_ALU_EXIT
#define FUNC_ALU_EXIT    0x80003020U  // PLACEHOLDER
#endif

// Phase 2 (func_l1_cold) PC milestone addresses — injected by two-pass build
#ifndef FUNC_COLD_ENTRY
#define FUNC_COLD_ENTRY  0x80003100U  // PLACEHOLDER
#endif
#ifndef FUNC_COLD_EXIT
#define FUNC_COLD_EXIT   0x80003120U  // PLACEHOLDER
#endif

static inline void cnt_wr(uint32_t counter_idx, uint32_t value) {
    asm volatile(
        "mv a5, %0\n\t"
        "mv a4, %1\n\t"
        ".word 0x00e79007\n\t"
        :
        : "r" (counter_idx), "r" (value)
        : "a4", "a5"
    );
}

static inline uint32_t cnt_rd(uint32_t counter_idx) {
    uint32_t value;
    asm volatile(
        "mv a5, %1\n\t"
        ".word 0x00078707\n\t"
        "mv %0, a4\n\t"
        : "=r" (value)
        : "r" (counter_idx)
        : "a4", "a5"
    );
    return value;
}

// Sleep until any counter in bitmap fires its pending bit.
static inline uint32_t cnt_wfp(uint32_t counter_bitmap) {
    uint32_t woke_bitmap;
    asm volatile(
        "mv x14, %1\n\t"
        ".word 0x00072887\n\t"
        "mv %0, x17\n\t"
        : "=r" (woke_bitmap)
        : "r" (counter_bitmap)
        : "x14", "x17"
    );
    return woke_bitmap;
}

// Take a snapshot of all tracked counters into provided variables.
// All reads are back-to-back to minimize skew.
#define SNAPSHOT(cyc, l1d, stall, br, llcrd, llcwr, memrd, memwr, rlat, wlat) \
    do {                                                          \
        asm volatile ("csrr %0, mcycle" : "=r"(cyc));            \
        (l1d)   = cnt_rd(CNT_L1D_MISS)   & 0x7FFFFFFF;          \
        (stall) = cnt_rd(CNT_STALLS)      & 0x7FFFFFFF;          \
        (br)    = cnt_rd(CNT_BRANCHES)    & 0x7FFFFFFF;          \
        (llcrd) = cnt_rd(CNT_LLC_RD_C0)  & 0x7FFFFFFF;          \
        (llcwr) = cnt_rd(CNT_LLC_WR_C0)  & 0x7FFFFFFF;          \
        (memrd) = cnt_rd(CNT_MEM_RD_C0)  & 0x7FFFFFFF;          \
        (memwr) = cnt_rd(CNT_MEM_WR_C0)  & 0x7FFFFFFF;          \
        (rlat)  = cnt_rd(CNT_MEM_RD_LAT) & 0x7FFFFFFF;          \
        (wlat)  = cnt_rd(CNT_MEM_WR_LAT) & 0x7FFFFFFF;          \
    } while (0)

// Write deltas to a DSPM slot.
#define WRITE_SLOT(slot_base, e_cyc, x_cyc,                \
                   e_l1d,  x_l1d,  e_stall, x_stall,       \
                   e_br,   x_br,   e_llcrd, x_llcrd,       \
                   e_llcwr,x_llcwr,e_memrd, x_memrd,       \
                   e_memwr,x_memwr,e_rlat,  x_rlat,        \
                   e_wlat, x_wlat)                         \
    do {                                                    \
        uint32_t _b = (slot_base);                          \
        WRITE_MEM(_b + 0x00, (x_cyc)   - (e_cyc));         \
        WRITE_MEM(_b + 0x04, (x_l1d)   - (e_l1d));         \
        WRITE_MEM(_b + 0x08, (x_stall) - (e_stall));       \
        WRITE_MEM(_b + 0x0C, (x_br)    - (e_br));          \
        WRITE_MEM(_b + 0x10, (x_llcrd) - (e_llcrd));       \
        WRITE_MEM(_b + 0x14, (x_llcwr) - (e_llcwr));       \
        WRITE_MEM(_b + 0x18, (x_memrd) - (e_memrd));       \
        WRITE_MEM(_b + 0x1C, (x_memwr) - (e_memwr));       \
        WRITE_MEM(_b + 0x20, (x_rlat)  - (e_rlat));        \
        WRITE_MEM(_b + 0x24, (x_wlat)  - (e_wlat));        \
        WRITE_MEM(_b + 0x28, (e_cyc));                      \
        WRITE_MEM(_b + 0x2C, (x_cyc));                      \
    } while (0)

int main() {
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");

    WRITE_MEM(0x10429000, 0xC4A0E440);

    asm volatile ("csrw 0x320, zero");

    WRITE_MEM(DSPM_CMD_ADDR, CMD_NONE);

    // Clear IRQ counters
    for (uint32_t c = 0; c < 4; c++)
        cnt_wr(CNT_IRQ_BASE + c, 0);

    // Clear DSPM log area (slots + phase field)
    for (uint32_t i = 0; i < 0x300; i += 4)
        WRITE_MEM(DSPM_LOG_BASE + i, 0);

    WRITE_MEM(DSPM_STATUS_ADDR, STATUS_STARTED);

    // Wait for CVA6 to signal
    while (READ_MEM(DSPM_CMD_ADDR) != CMD_TRIGGER_INTERRUPT)
        asm volatile ("nop");

    WRITE_MEM(DSPM_CMD_ADDR, CMD_NONE);
    WRITE_MEM(DSPM_STATUS_ADDR, STATUS_SENDING_IRQS);
    WRITE_MEM(DSPM_STATUS_ADDR, STATUS_ALL_IRQS_SENT);

    // ================================================================
    // Step A: Configure CVA6-EVU event IDs via Ibex AXI-lite master
    //   EID0 = 0x02: L1D miss        → counter 21
    //   EID1 = 0x17: PC milestone    → counter 20 (cnt_wfp target)
    //   EID2 = 0x16: pipeline stalls → counter 22
    //   EID3 = 0x09: branch instrs   → counter 23
    // ================================================================
    WRITE_MEM(EVENTID_C0_BASE_ADDR + 0x00, 0x00000002);
    WRITE_MEM(EVENTID_C0_BASE_ADDR + 0x04, 0x00000017);
    WRITE_MEM(EVENTID_C0_BASE_ADDR + 0x08, 0x00000016);
    WRITE_MEM(EVENTID_C0_BASE_ADDR + 0x0C, 0x00000009);

    // ================================================================
    // Step B: Clear all stat counters
    // ================================================================
    cnt_wr(CNT_MILESTONE_0, 0);
    cnt_wr(CNT_L1D_MISS,    0);
    cnt_wr(CNT_STALLS,      0);
    cnt_wr(CNT_BRANCHES,    0);
    cnt_wr(CNT_LLC_RD_C0,   0);
    cnt_wr(CNT_LLC_WR_C0,   0);
    cnt_wr(CNT_MEM_RD_C0,   0);
    cnt_wr(CNT_MEM_WR_C0,   0);
    cnt_wr(CNT_MEM_RD_LAT,  0);
    cnt_wr(CNT_MEM_WR_LAT,  0);

    uint32_t milestone_mask = (1u << CNT_MILESTONE_0);
    uint32_t total_count = 0;

    // ================================================================
    // Step C: Arm phase 1 milestone and signal CVA6
    //   Writing FUNC_ALU_ENTRY here acts as the "ready" signal:
    //   CVA6 polls PC_MILESTONE_SLOT0 != 0 to know Ibex is set up.
    // ================================================================
    WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_ALU_ENTRY);
    WRITE_MEM(DSPM_LOG_PHASE, 1);

    // ================================================================
    // Phase 1: profile N_CALLS_SHORT func_alu_chain entry/exit pairs
    //   CVA6 runs func_alu_chain and waits for total_count to increment
    //   before running the next call (per-call sync for short function).
    // ================================================================
    while (total_count < N_CALLS_SHORT) {
        uint32_t e_cyc, x_cyc;
        uint32_t e_l1d, x_l1d, e_stall, x_stall, e_br, x_br;
        uint32_t e_llcrd, x_llcrd, e_llcwr, x_llcwr;
        uint32_t e_memrd, x_memrd, e_memwr, x_memwr;
        uint32_t e_rlat, x_rlat, e_wlat, x_wlat;

        WRITE_MEM(DSPM_LOG_STATE, 0);

        // Sleep until FUNC_ALU_ENTRY fires
        cnt_wfp(milestone_mask);

        // Entry snapshot (back-to-back to minimize skew)
        SNAPSHOT(e_cyc, e_l1d, e_stall, e_br,
                 e_llcrd, e_llcwr, e_memrd, e_memwr, e_rlat, e_wlat);

        WRITE_MEM(DSPM_LOG_STATE, 1);

        // Reprogram to exit address — CVA6 must not reach FUNC_ALU_EXIT
        // before this write completes; per-call sync on CVA6 side ensures
        // CVA6 waits for total_count to increment before calling again.
        WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_ALU_EXIT);

        // Sleep until FUNC_ALU_EXIT fires
        cnt_wfp(milestone_mask);

        // Exit snapshot
        SNAPSHOT(x_cyc, x_l1d, x_stall, x_br,
                 x_llcrd, x_llcwr, x_memrd, x_memwr, x_rlat, x_wlat);

        // Write deltas to DSPM slot[total_count]
        WRITE_SLOT(DSPM_LOG_SLOT(total_count),
                   e_cyc, x_cyc, e_l1d, x_l1d, e_stall, x_stall,
                   e_br, x_br, e_llcrd, x_llcrd, e_llcwr, x_llcwr,
                   e_memrd, x_memrd, e_memwr, x_memwr, e_rlat, x_rlat,
                   e_wlat, x_wlat);

        total_count++;
        WRITE_MEM(DSPM_LOG_CALL_COUNT, total_count);

        // Rearm for next ALU call (CVA6 detects count increment and calls again)
        if (total_count < N_CALLS_SHORT)
            WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_ALU_ENTRY);
    }

    // ================================================================
    // Transition to phase 2: arm FUNC_COLD_ENTRY milestone
    //   CVA6 polls DSPM_LOG_PHASE == 2 before starting func_l1_cold calls.
    // ================================================================
    WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_COLD_ENTRY);
    WRITE_MEM(DSPM_LOG_PHASE, 2);

    // ================================================================
    // Phase 2: profile N_CALLS_LONG func_l1_cold entry/exit pairs
    //   func_l1_cold is long enough (~10000+ cycles) that Ibex can
    //   reprogram the milestone between entry and exit without per-call sync.
    // ================================================================
    while (total_count < N_CALLS_TOTAL) {
        uint32_t e_cyc, x_cyc;
        uint32_t e_l1d, x_l1d, e_stall, x_stall, e_br, x_br;
        uint32_t e_llcrd, x_llcrd, e_llcwr, x_llcwr;
        uint32_t e_memrd, x_memrd, e_memwr, x_memwr;
        uint32_t e_rlat, x_rlat, e_wlat, x_wlat;

        WRITE_MEM(DSPM_LOG_STATE, 0);

        // Sleep until FUNC_COLD_ENTRY fires
        cnt_wfp(milestone_mask);

        // Entry snapshot
        SNAPSHOT(e_cyc, e_l1d, e_stall, e_br,
                 e_llcrd, e_llcwr, e_memrd, e_memwr, e_rlat, e_wlat);

        WRITE_MEM(DSPM_LOG_STATE, 1);

        // Reprogram to exit address
        WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_COLD_EXIT);

        // Sleep until FUNC_COLD_EXIT fires
        cnt_wfp(milestone_mask);

        // Exit snapshot
        SNAPSHOT(x_cyc, x_l1d, x_stall, x_br,
                 x_llcrd, x_llcwr, x_memrd, x_memwr, x_rlat, x_wlat);

        // Write deltas to DSPM slot[total_count] (slots 4-7 for cold)
        WRITE_SLOT(DSPM_LOG_SLOT(total_count),
                   e_cyc, x_cyc, e_l1d, x_l1d, e_stall, x_stall,
                   e_br, x_br, e_llcrd, x_llcrd, e_llcwr, x_llcwr,
                   e_memrd, x_memrd, e_memwr, x_memwr, e_rlat, x_rlat,
                   e_wlat, x_wlat);

        total_count++;
        WRITE_MEM(DSPM_LOG_CALL_COUNT, total_count);

        // Rearm for next cold call
        if (total_count < N_CALLS_TOTAL)
            WRITE_MEM(PC_MILESTONE_SLOT0, FUNC_COLD_ENTRY);
    }

    // All pairs profiled — spin until CVA6 halts us via PMC_STATUS_ADDR
    while (1)
        asm volatile ("nop");
}
