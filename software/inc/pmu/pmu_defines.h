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
///
/// Event selects follow the SoC's core count: build with -DSOC_NUM_CORES=<n> (software/common.mk adds it for
/// SOC_NUM_CORES=<n> or NUM_CVA6=<n>). Addresses and counter indexes do not depend on it.

#ifndef PMU_DEFINES_H
#define PMU_DEFINES_H

#include <stdint.h>
#include "evu_defines.h"

// The SoC's core count (hardware NUM_CVA6)
#ifndef SOC_NUM_CORES
#define SOC_NUM_CORES 4
#endif

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
// The PE's data port reaches only the DSPM, the APMU registers and the EVU registers: any other load or store stalls it.
// Load the SPMs with aligned 32-bit stores: a byte store lands in a lane the PE does not read.
#define ISPM_BASE_ADDR  0x10427000
#define DSPM_BASE_ADDR  0x10429000
#define ISPM_SIZE       0x2000
#define DSPM_SIZE       0x20000

// Event Selection Register (pmu_pkg::event_sel_cfg_t)
// Up to four cores (4-bit port and source fields):
//  31      24 23    20 19    16 15    12 11     8 7      4 3      0
// +----------+--------+--------+--------+--------+--------+--------+
// |   pad    |port_val|port_msk|src_val |src_msk |ev_val  |ev_msk  |
// +----------+--------+--------+--------+--------+--------+--------+
// More than four cores (5-bit port and source fields):
//  31      28 27    23 22    18 17    13 12     8 7      4 3      0
// +----------+--------+--------+--------+--------+--------+--------+
// |   pad    |port_val|port_msk|src_val |src_msk |ev_val  |ev_msk  |
// +----------+--------+--------+--------+--------+--------+--------+
// Match if (mask & id) == val. Mask 0 matches all, ev_val 0 disables.
#define EVSEL_FIELD_BITS        (SOC_NUM_CORES > 4 ? 5 : 4)
#define EVSEL_PORT_ALL          ((1u << EVSEL_FIELD_BITS) - 1)
#define EVSEL_SRC_ALL           EVSEL_PORT_ALL
#define EVSEL_EV_ALL            0xFu
#define EVSEL_PORT(val, mask)   ((((val) & EVSEL_PORT_ALL) << (8 + 3*EVSEL_FIELD_BITS)) | (((mask) & EVSEL_PORT_ALL) << (8 + 2*EVSEL_FIELD_BITS)))
#define EVSEL_SRC(val, mask)    ((((val) & EVSEL_SRC_ALL) << (8 + EVSEL_FIELD_BITS)) | (((mask) & EVSEL_SRC_ALL) << 8))
#define EVSEL_EVENT(val, mask)     ((((val) & 0xFu) <<  4) | (((mask) & 0xFu) <<  0))

// Event ev of one port, any source / one source
#define EVSEL_PORT_EV(port, ev)             (EVSEL_PORT(port, EVSEL_PORT_ALL) | EVSEL_EVENT(ev, EVSEL_EV_ALL))
#define EVSEL_PORT_SRC_EV(port, src, ev)    (EVSEL_PORT(port, EVSEL_PORT_ALL) | EVSEL_SRC(src, EVSEL_SRC_ALL) | EVSEL_EVENT(ev, EVSEL_EV_ALL))

// APMU ports, N = SOC_NUM_CORES: 1..N EVU, N+1..2N core <=> LLC, 2N+1 LLC <=> mem, 2N+2 accelerator socket DMA
#define APMU_PORT_EVU(core)         (1 + (core))
#define APMU_PORT_CORE_SPU(core)    (1 + SOC_NUM_CORES + (core))
#define APMU_PORT_MEM_SPU           (2*SOC_NUM_CORES + 1)
#define APMU_PORT_ACCEL_SPU         (2*SOC_NUM_CORES + 2)
#define APMU_NUM_PORTS              (2*SOC_NUM_CORES + 2)

// SPU events
#define APMU_EV_RD_REQ  1
#define APMU_EV_WR_REQ  2
#define APMU_EV_RD_RES  3
#define APMU_EV_WR_RES  4

// Sources on the memory port (ariane_axi_soc::mem_src): 0..N-1 cores, N accelerator socket DMA, N+1 Ethernet DMA,
// N+1+p crossbar master p = 1..9 (ariane_soc::axi_masters_t). A response counts for the source of its request.
#define APMU_SRC_CORE(core)     (core)
#define APMU_SRC_ACCEL          SOC_NUM_CORES
#define APMU_SRC_ETH            (SOC_NUM_CORES + 1)
#define APMU_SRC_XBAR(p)        (SOC_NUM_CORES + 1 + (p))
#define APMU_NUM_SRCS           (SOC_NUM_CORES + 11)

// Core <=> LLC events (ports N+1..2N)
// No _CORE_X suffix = all ports, including EVU ports (an EVU slot 0 event has e_id 1 too)
// Hex values below are for four cores.
#define LLC_RD_REQ_CORE(c)  EVSEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_RD_REQ)
#define LLC_RD_RES_CORE(c)  EVSEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_RD_RES)
#define LLC_WR_REQ_CORE(c)  EVSEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_WR_REQ)
#define LLC_WR_RES_CORE(c)  EVSEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_WR_RES)
#define LLC_RD_REQ          0x00001F
#define LLC_RD_REQ_CORE_0   LLC_RD_REQ_CORE(0)  // 0x5F001F
#define LLC_RD_REQ_CORE_1   LLC_RD_REQ_CORE(1)  // 0x6F001F
#define LLC_RD_REQ_CORE_2   LLC_RD_REQ_CORE(2)  // 0x7F001F
#define LLC_RD_REQ_CORE_3   LLC_RD_REQ_CORE(3)  // 0x8F001F
#define LLC_RD_RES          0x00003F
#define LLC_RD_RES_CORE_0   LLC_RD_RES_CORE(0)  // 0x5F003F
#define LLC_RD_RES_CORE_1   LLC_RD_RES_CORE(1)  // 0x6F003F
#define LLC_RD_RES_CORE_2   LLC_RD_RES_CORE(2)  // 0x7F003F
#define LLC_RD_RES_CORE_3   LLC_RD_RES_CORE(3)  // 0x8F003F
#define LLC_WR_REQ          0x00002F
#define LLC_WR_REQ_CORE_0   LLC_WR_REQ_CORE(0)  // 0x5F002F
#define LLC_WR_REQ_CORE_1   LLC_WR_REQ_CORE(1)  // 0x6F002F
#define LLC_WR_REQ_CORE_2   LLC_WR_REQ_CORE(2)  // 0x7F002F
#define LLC_WR_REQ_CORE_3   LLC_WR_REQ_CORE(3)  // 0x8F002F
#define LLC_WR_RES          0x00004F
#define LLC_WR_RES_CORE_0   LLC_WR_RES_CORE(0)  // 0x5F004F
#define LLC_WR_RES_CORE_1   LLC_WR_RES_CORE(1)  // 0x6F004F
#define LLC_WR_RES_CORE_2   LLC_WR_RES_CORE(2)  // 0x7F004F
#define LLC_WR_RES_CORE_3   LLC_WR_RES_CORE(3)  // 0x8F004F

// LLC <=> Main Memory events (port 2N+1)
#define MEM_SEL(ev, src)   EVSEL_PORT_SRC_EV(APMU_PORT_MEM_SPU, src, ev)
#define MEM_RD_REQ   EVSEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_RD_REQ)   // 0x9F001F
#define MEM_WR_REQ   EVSEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_WR_REQ)   // 0x9F002F
#define MEM_RD_RES   EVSEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_RD_RES)   // 0x9F003F
#define MEM_WR_RES   EVSEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_WR_RES)   // 0x9F004F

// Per core: source ID = core ID. Evictions count for the core whose miss caused them.
// Other masters have source IDs of their own (APMU_SRC_*).
#define MEM_RD_REQ_CORE(c) MEM_SEL(APMU_EV_RD_REQ, APMU_SRC_CORE(c))
#define MEM_WR_REQ_CORE(c) MEM_SEL(APMU_EV_WR_REQ, APMU_SRC_CORE(c))
#define MEM_RD_RES_CORE(c) MEM_SEL(APMU_EV_RD_RES, APMU_SRC_CORE(c))
#define MEM_WR_RES_CORE(c) MEM_SEL(APMU_EV_WR_RES, APMU_SRC_CORE(c))
#define MEM_RD_REQ_CORE_0  MEM_RD_REQ_CORE(0)   // 0x9F0F1F
#define MEM_RD_REQ_CORE_1  MEM_RD_REQ_CORE(1)   // 0x9F1F1F
#define MEM_RD_REQ_CORE_2  MEM_RD_REQ_CORE(2)   // 0x9F2F1F
#define MEM_RD_REQ_CORE_3  MEM_RD_REQ_CORE(3)   // 0x9F3F1F
#define MEM_WR_REQ_CORE_0  MEM_WR_REQ_CORE(0)   // 0x9F0F2F
#define MEM_WR_REQ_CORE_1  MEM_WR_REQ_CORE(1)   // 0x9F1F2F
#define MEM_WR_REQ_CORE_2  MEM_WR_REQ_CORE(2)   // 0x9F2F2F
#define MEM_WR_REQ_CORE_3  MEM_WR_REQ_CORE(3)   // 0x9F3F2F
#define MEM_RD_RES_CORE_0  MEM_RD_RES_CORE(0)   // 0x9F0F3F
#define MEM_RD_RES_CORE_1  MEM_RD_RES_CORE(1)   // 0x9F1F3F
#define MEM_RD_RES_CORE_2  MEM_RD_RES_CORE(2)   // 0x9F2F3F
#define MEM_RD_RES_CORE_3  MEM_RD_RES_CORE(3)   // 0x9F3F3F
#define MEM_WR_RES_CORE_0  MEM_WR_RES_CORE(0)   // 0x9F0F4F
#define MEM_WR_RES_CORE_1  MEM_WR_RES_CORE(1)   // 0x9F1F4F
#define MEM_WR_RES_CORE_2  MEM_WR_RES_CORE(2)   // 0x9F2F4F
#define MEM_WR_RES_CORE_3  MEM_WR_RES_CORE(3)   // 0x9F3F4F

// Accelerator socket DMA on the memory port: the part of its traffic that reached DRAM
#define MEM_RD_REQ_ACCEL   MEM_SEL(APMU_EV_RD_REQ, APMU_SRC_ACCEL)  // 0x9F4F1F
#define MEM_WR_REQ_ACCEL   MEM_SEL(APMU_EV_WR_REQ, APMU_SRC_ACCEL)  // 0x9F4F2F
#define MEM_RD_RES_ACCEL   MEM_SEL(APMU_EV_RD_RES, APMU_SRC_ACCEL)  // 0x9F4F3F
#define MEM_WR_RES_ACCEL   MEM_SEL(APMU_EV_WR_RES, APMU_SRC_ACCEL)  // 0x9F4F4F

// Accelerator socket DMA (port 2N+2, before the LLC): every DRAM request, hits and misses alike
#define ACC_RD_REQ   EVSEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_RD_REQ)   // 0xAF4F1F
#define ACC_WR_REQ   EVSEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_WR_REQ)   // 0xAF4F2F
#define ACC_RD_RES   EVSEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_RD_RES)   // 0xAF4F3F
#define ACC_WR_RES   EVSEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_WR_RES)   // 0xAF4F4F

// EVU (ports 1..N): bit s of the event field is slot s, register map in evu_defines.h
#define EVU_EID_REG(core, slot)     EVU_EVENT_ID(core, slot)
#define EVU_SLOT_SEL(core, slot)    (EVSEL_PORT(APMU_PORT_EVU(core), EVSEL_PORT_ALL) | EVSEL_EVENT(1u << (slot), 1u << (slot)))

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
// An event-info counter adds the info of one port per cycle, the highest-numbered match: select a single port.
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000

// MMIO
#define pmu_read_32b(addr)        (*(volatile uint32_t *)(uintptr_t)(addr))
#define pmu_write_32b(addr, val)  (*(volatile uint32_t *)(uintptr_t)(addr) = (val))

static inline uint32_t cntr_read(int n){
    return pmu_read_32b(COUNTER_ADDR(n));
}

// Every port and every memory-port source fits its field
_Static_assert(APMU_NUM_PORTS <= EVSEL_PORT_ALL, "pmu_defines.h: the APMU's ports do not fit EVSEL_FIELD_BITS");
_Static_assert(APMU_NUM_SRCS <= EVSEL_SRC_ALL + 1, "pmu_defines.h: the memory port's sources do not fit EVSEL_FIELD_BITS");

#endif /* PMU_DEFINES_H */