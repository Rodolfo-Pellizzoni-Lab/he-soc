#ifndef __PMU_HW_DESC_H__
#define __PMU_HW_DESC_H__

// Macros for custom PMU core instructions.
// Counter read: rd = cnt[rs1]
// #define counter_read(rd, rs1)       asm volatile ("cnt.rd\t%0,%1" : "=r" (rd) : "r" (rs1));
// // Counter write: cnt[rs1] = rs2
// #define counter_write(rs1, rs2)     asm volatile ("cnt.wr\t%0,%1" :: "r" (rs1), "r" (rs2));


// Macros for custom PMU core instructions.
// Counter read: rd = cnt[rs1]
// cnt.rd rd, counter_idx -> rd = counter[counter_idx]
#define counter_read(rd, rs1) \
    asm volatile (".insn r 0x07, 0x0, 0, %0, %1, x0" : "=r" (rd) : "r" (rs1))

// Counter write: cnt[counter_idx] = value
// cnt.wr counter_idx, value -> counter[counter_idx] = value
// Note: In .insn format, rs1=value, rs2=counter_idx (reversed from macro params)
#define counter_write(counter_idx, value) \
    asm volatile (".insn r 0x07, 0x1, 0, x0, %1, %0" : : "r" (counter_idx), "r" (value))

// #############################################################################
// Defines for PMU
// #############################################################################

#define NUM_COUNTER 12

#define TIMER_WIDTH     0x8
#define STATUS_WIDTH    0x4
#define BOOT_ADDR_WIDTH 0x4
#define COUNTER_WIDTH   0x4

// PMU Bundle Addresses (must match pmu_defines.h)
#define PMU_B_BASE_ADDR     0x10405000
#define TIMER_ADDR          PMU_B_BASE_ADDR
#define PERIOD_ADDR         (PMU_B_BASE_ADDR + 0x8)
#define PMC_STATUS_ADDR     (PMU_B_BASE_ADDR + 0x1000)
#define PMC_BOOT_ADDR       (PMU_B_BASE_ADDR + 0x1004)
// Two 64-bit (8B) timer and one 32-bit status registers in the PMU bundle.
#define PMU_BUNDLE_SIZE     0x2000

// Counter Bundle Base Addresses
#define COUNTER_B_BASE_ADDR     (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR       (COUNTER_B_BASE_ADDR + 0*COUNTER_WIDTH)
#define EVENT_SEL_BASE_ADDR     (COUNTER_B_BASE_ADDR + 1*COUNTER_WIDTH)
#define EVENT_INFO_BASE_ADDR    (COUNTER_B_BASE_ADDR + 2*COUNTER_WIDTH)
#define INIT_BUDGET_BASE_ADDR   (COUNTER_B_BASE_ADDR + 3*COUNTER_WIDTH)
// Four 32-bit (4B) registers in one counter bundle.
#define COUNTER_BUNDLE_SIZE     0x1000

// PMU Core Addresses (must match pmu_defines.h)
#define ISPM_BASE_ADDR  0x10427000
#define DSPM_BASE_ADDR  0x10428000
#define DSPM_LENGTH     0x8000
#define DSPM_END_ADDR   (DSPM_BASE_ADDR + DSPM_LENGTH)
/// **********************************************************************
/// PMU Event Defines for Event Selection Register
/// **********************************************************************
/// Defines for Core to/from LLC
/// ****************************
// Read requests from Core X to LLC
#define LLC_RD_REQ          0x00001F
#define LLC_RD_REQ_CORE_0   0x2F001F
#define LLC_RD_REQ_CORE_1   0x3F001F
#define LLC_RD_REQ_CORE_2   0x4F001F
#define LLC_RD_REQ_CORE_3   0x5F001F
// Read responses to Core X from LLC
#define LLC_RD_RES          0x00003F
#define LLC_RD_RES_CORE_0   0x2F003F
#define LLC_RD_RES_CORE_1   0x3F003F
#define LLC_RD_RES_CORE_2   0x4F003F
#define LLC_RD_RES_CORE_3   0x5F003F
// Write requests from Core X to LLC
#define LLC_WR_REQ          0x00002F
#define LLC_WR_REQ_CORE_0   0x2F002F
#define LLC_WR_REQ_CORE_1   0x3F002F
#define LLC_WR_REQ_CORE_2   0x4F002F
#define LLC_WR_REQ_CORE_3   0x5F002F
// Write responses to Core X from LLC
#define LLC_WR_RES          0x00004F
#define LLC_WR_RES_CORE_0   0x2F004F
#define LLC_WR_RES_CORE_1   0x3F004F
#define LLC_WR_RES_CORE_2   0x4F004F
#define LLC_WR_RES_CORE_3   0x5F004F

/// ***********************************
/// Defines for LLC to/from Main Memory
/// ***********************************
/// Port ID and Mask | Source ID and Mask | Event ID and Mask
///     LLC:0        |     4, 5, 6, 7     |    REQ: 1, 2 
///     MEM:1        |                    |    RES: 3, 4
///  ________________|____________________|_____ RD, WR ______

// Read and write requests of all cores to Main Memory from LLC
#define MEM_RD_REQ   0x1F001F  
#define MEM_WR_REQ   0x1F002F
// Read and write responses of all cores to LLC from Main Memory
#define MEM_RD_RES   0x1F003F  
#define MEM_WR_RES   0x1F004F

// Read and write requests of Core X to Main Memory from LLC
#define MEM_RD_REQ_CORE_0  0x1F4F1F
#define MEM_RD_REQ_CORE_1  0x1F5F1F
#define MEM_RD_REQ_CORE_2  0x1F6F1F
#define MEM_RD_REQ_CORE_3  0x1F7F1F
#define MEM_WR_REQ_CORE_0  0x1F4F2F
#define MEM_WR_REQ_CORE_1  0x1F5F2F
#define MEM_WR_REQ_CORE_2  0x1F6F2F
#define MEM_WR_REQ_CORE_3  0x1F7F2F
// Read and write responses of Core X to LLC from Main Memory
#define MEM_RD_RES_CORE_0  0x1F4F3F
#define MEM_RD_RES_CORE_1  0x1F5F3F
#define MEM_RD_RES_CORE_2  0x1F6F3F
#define MEM_RD_RES_CORE_3  0x1F7F3F
#define MEM_WR_RES_CORE_0  0x1F4F4F
#define MEM_WR_RES_CORE_1  0x1F5F4F
#define MEM_WR_RES_CORE_2  0x1F6F4F
#define MEM_WR_RES_CORE_3  0x1F7F4F

/// **********************************************************************
/// Defines for Event Info Register
/// **********************************************************************
/// Note: The following define only works if the response (X_RES_X) events are selected
//        using the corresponding Event Select Register.
#define ADD_RESP_LAT   0x8001E0
// Only count those accesses that are targetting memory subsystem (LLC, main memory).
#define CNT_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000

// #############################################################################

#endif