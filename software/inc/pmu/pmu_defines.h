/// This assumes the following:
///   1. The PMU counters are 32-bit: [31] pending, [30] overflow, [29:0] count.
///      The initial budget registers are 32-bit: [31] pending, [30:0] budget.
///   2. The event selection and event info configuration registers are 32-bit.
///
/// NUM_COUNTER is parameterizable and should be set to the number of counters in the PMU.
/// Diagram for NUM_COUNTER = 32
///
///   0x1040_5000                    /*******************************************\  PMU_B_BASE_ADDR (TIMER_ADDR)
///   PMU Bundle                     | +0x0  PMU Timer                           |  (64-bit)
///                                  | +0x8  MemGuard Period Register            |  (64-bit)
///                                  \*******************************************/
///   0x1040_6000                    /*******************************************\  PMC_STATUS_ADDR / PMC_BOOT_ADDR
///   PMU Bundle                     | +0x0  PMC Status Register (bit 0 = stall) |
///                                  | +0x4  PMC Boot Address Register           |
///                                  \*******************************************/
///   0x1040_7000                    /*******************************************\  COUNTER_B_BASE_ADDR
///   Counter Bundle 0               | +0x0  Counter                             |
///                                  | +0x4  Event Selection Register            |
///                                  | +0x8  Event Info Configuration Register   |
///                                  | +0xc  Initial Budget Register             |
///                                  \*******************************************/
///   0x1040_8000                    /*******************************************\  COUNTER_B_ADDR(1)
///   Counter Bundle 1               | +0x0  Counter                             |
///                                  | +0x4  Event Selection Register            |
///                                  | +0x8  Event Info Configuration Register   |
///                                  | +0xc  Initial Budget Register             |
///                                  \*******************************************/
///                                                        .
///                                                        .   ... x (NUM_COUNTER)
///                                                        .
///   0x1042_6000                    /*******************************************\  COUNTER_B_ADDR(NUM_COUNTER-1)
///   Counter Bundle NUM_COUNTER-1   | +0x0  Counter                             |
///                                  | +0x4  Event Selection Register            |
///                                  | +0x8  Event Info Configuration Register   |
///                                  | +0xc  Initial Budget Register             |
///                                  \*******************************************/
/// Each block is a separate 4kB-aligned page.

#ifndef PMU_DEFINES_H
#define PMU_DEFINES_H

#include <stdint.h>

#define NUM_COUNTER 32

#define TIMER_WIDTH     0x8
#define STATUS_WIDTH    0x4
#define BOOT_ADDR_WIDTH 0x4
#define COUNTER_WIDTH   0x4

// PMU bundle
#define PMU_B_BASE_ADDR     0x10405000
#define TIMER_ADDR          PMU_B_BASE_ADDR
#define PERIOD_ADDR         (PMU_B_BASE_ADDR + TIMER_WIDTH)
#define PMC_STATUS_ADDR     (PMU_B_BASE_ADDR + 0x1000)
#define PMC_BOOT_ADDR       (PMU_B_BASE_ADDR + 0x1004)
// 64-bit registers as 32-bit halves, LO first
#define TIMER_ADDR_LO       TIMER_ADDR
#define TIMER_ADDR_HI       (TIMER_ADDR + 0x4)
#define PERIOD_ADDR_LO      PERIOD_ADDR
#define PERIOD_ADDR_HI      (PERIOD_ADDR + 0x4)
// Two 4 kB pages
#define PMU_BUNDLE_SIZE     0x2000

// Counter bundles
#define COUNTER_B_BASE_ADDR     (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
// One 4 kB page per bundle
#define COUNTER_BUNDLE_SIZE     0x1000

// Offsets inside a bundle
#define COUNTER_OFF             0x0
#define EVENT_SEL_OFF           0x4
#define EVENT_INFO_OFF          0x8
#define INIT_BUDGET_OFF         0xC

// Registers of bundle n
#define COUNTER_B_ADDR(n)       (COUNTER_B_BASE_ADDR + (n)*COUNTER_BUNDLE_SIZE)
#define COUNTER_ADDR(n)         (COUNTER_B_ADDR(n) + COUNTER_OFF)
#define EVENT_SEL_ADDR(n)       (COUNTER_B_ADDR(n) + EVENT_SEL_OFF)
#define EVENT_INFO_ADDR(n)      (COUNTER_B_ADDR(n) + EVENT_INFO_OFF)
#define INIT_BUDGET_ADDR(n)     (COUNTER_B_ADDR(n) + INIT_BUDGET_OFF)

// Counter: [31] pending, [30] overflow, [29:0] count
// Init budget: [31] pending, [30:0] budget
#define PENDING_BIT             31
#define PENDING_MASK            0x80000000u
#define OVERFLOW_BIT            30
#define OVERFLOW_MASK           0x40000000u
#define COUNT_MASK              0x3FFFFFFFu

// Ibex scratchpads (sizes from host_domain.sv)
#define ISPM_BASE_ADDR  0x10427000
#define DSPM_BASE_ADDR  0x10429000
#define ISPM_SIZE       0x2000
#define DSPM_SIZE       0x20000

// Event Selection Register (pmu_pkg::event_sel_cfg_t)
//  31      24 23    20 19    16 15    12 11     8 7      4 3      0
// +----------+--------+--------+--------+--------+--------+--------+
// |   pad    |port_val|port_msk|src_val |src_msk |ev_val  |ev_msk  |
// +----------+--------+--------+--------+--------+--------+--------+
// Match if (mask & id) == val. Mask 0 matches all, ev_val 0 disables.
#define EVSEL_PORT(val, mask)   ((((val) & 0xFu) << 20) | (((mask) & 0xFu) << 16))
#define EVSEL_SRC(val, mask)    ((((val) & 0xFu) << 12) | (((mask) & 0xFu) <<  8))
#define EVSEL_EVENT(val, mask)     ((((val) & 0xFu) <<  4) | (((mask) & 0xFu) <<  0))

// Core <=> LLC events
// Ports: 1-4 EVU core 0-3, 5-8 core 0-3 <=> LLC, 9 LLC <=> mem
// Events: RD_REQ 1, WR_REQ 2, RD_RES 3, WR_RES 4
// No _CORE_X suffix = all ports, including EVU ports 1-4 (an EVU slot 0 event has e_id 1 too)
#define LLC_RD_REQ          0x00001F
#define LLC_RD_REQ_CORE_0   0x5F001F
#define LLC_RD_REQ_CORE_1   0x6F001F
#define LLC_RD_REQ_CORE_2   0x7F001F
#define LLC_RD_REQ_CORE_3   0x8F001F
#define LLC_RD_RES          0x00003F
#define LLC_RD_RES_CORE_0   0x5F003F
#define LLC_RD_RES_CORE_1   0x6F003F
#define LLC_RD_RES_CORE_2   0x7F003F
#define LLC_RD_RES_CORE_3   0x8F003F
#define LLC_WR_REQ          0x00002F
#define LLC_WR_REQ_CORE_0   0x5F002F
#define LLC_WR_REQ_CORE_1   0x6F002F
#define LLC_WR_REQ_CORE_2   0x7F002F
#define LLC_WR_REQ_CORE_3   0x8F002F
#define LLC_WR_RES          0x00004F
#define LLC_WR_RES_CORE_0   0x5F004F
#define LLC_WR_RES_CORE_1   0x6F004F
#define LLC_WR_RES_CORE_2   0x7F004F
#define LLC_WR_RES_CORE_3   0x8F004F
 
// LLC <=> Main Memory events (port 9, or 5 if NumCVA6 = 2)
#define MEM_RD_REQ   0x9F001F
#define MEM_WR_REQ   0x9F002F
#define MEM_RD_RES   0x9F003F  
#define MEM_WR_RES   0x9F004F
   
// Per core: source ID = core ID. Evictions count for the core whose miss caused them.
// uDMA TX and IOPMP also map to source IDs 0-3.
#define MEM_RD_REQ_CORE_0  0x9F0F1F
#define MEM_RD_REQ_CORE_1  0x9F1F1F
#define MEM_RD_REQ_CORE_2  0x9F2F1F
#define MEM_RD_REQ_CORE_3  0x9F3F1F
#define MEM_WR_REQ_CORE_0  0x9F0F2F
#define MEM_WR_REQ_CORE_1  0x9F1F2F
#define MEM_WR_REQ_CORE_2  0x9F2F2F
#define MEM_WR_REQ_CORE_3  0x9F3F2F
#define MEM_RD_RES_CORE_0  0x9F0F3F
#define MEM_RD_RES_CORE_1  0x9F1F3F
#define MEM_RD_RES_CORE_2  0x9F2F3F
#define MEM_RD_RES_CORE_3  0x9F3F3F
#define MEM_WR_RES_CORE_0  0x9F0F4F
#define MEM_WR_RES_CORE_1  0x9F1F4F
#define MEM_WR_RES_CORE_2  0x9F2F4F
#define MEM_WR_RES_CORE_3  0x9F3F4F

// Event Info Configuration Register (pmu_pkg::event_info_cfg_t)
//  31     25  24  23 22   19 18   15 14     10 9       5 4        0
// +---------+---+---+-------+-------+---------+---------+----------+
// |   pad   |ovf|en | val_u | val_l | opcode  |eisf_end |eisf_start|
// +---------+---+---+-------+-------+---------+---------+----------+
// Omitted fields are 0: opcode ADD, info_en 0 (plain increment).
#define EVINFO_EISF(start, end) ((((start) & 0x1Fu) << 0) | (((end) & 0x1Fu) << 5))
#define EVINFO_OP(op)           (((op) & 0x1Fu) << 10)
#define EVINFO_VAL(l, u)        ((((l) & 0xFu) << 15) | (((u) & 0xFu) << 19))
#define EVINFO_INFO_EN          (1u << 23)
#define EVINFO_OVF_EN           (1u << 24)

// Opcodes (pmu_pkg::opcode_e)
#define OP_ADD                  0
#define OP_KEEP_MAX             1
#define OP_KEEP_MIN             2
#define OP_INCR_CMP_EQ          3
#define OP_INCR_CMP_NEQ         4
#define OP_INCR_CMP_LT          5
#define OP_INCR_CMP_GT          6
#define OP_INCR_CMP_LTE         7
#define OP_INCR_CMP_GTE         8
#define OP_INCR_IN_RANGE        9
#define OP_INCR_NOT_IN_RANGE    10
#define OP_ADD_CMP_EQ           11
#define OP_ADD_CMP_NEQ          12
#define OP_ADD_CMP_LT           13
#define OP_ADD_CMP_GT           14
#define OP_ADD_CMP_LTE          15
#define OP_ADD_CMP_GTE          16
#define OP_ADD_IN_RANGE         17
#define OP_ADD_NOT_IN_RANGE     18

// Raw values. ADD_RESP_LAT needs a response (X_RES_X) event.
// ADD_RESP_LAT: info_en, ADD e_info[15:0].
// ADD_MEM_ONLY: info_en, INCR_CMP_EQ on e_info[16] == 1 (+1 per event with e_info[16] set, not an ADD).
// OVERFLOW_EN:  same bit as EVINFO_OVF_EN.
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000

// MMIO
#define pmu_read_32b(addr)        (*(volatile uint32_t *)(uintptr_t)(addr))
#define pmu_write_32b(addr, val)  (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

static inline uint32_t cntr_read(int n){
    return pmu_read_32b(COUNTER_ADDR(n));
}

#endif /* PMU_DEFINES_H */