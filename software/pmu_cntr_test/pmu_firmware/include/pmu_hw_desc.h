#ifndef __PMU_HW_DESC_H__
#define __PMU_HW_DESC_H__

// =============================================================================
// Custom PMU Ibex instructions
// =============================================================================
// Counter read:  rd = counter[counter_idx]
#define counter_read(rd, rs1) \
    asm volatile (".insn r 0x07, 0x0, 0, %0, %1, x0" : "=r" (rd) : "r" (rs1))

// Counter write: counter[counter_idx] = value
// Note: in .insn format rs1=value, rs2=counter_idx (reversed from macro params)
#define counter_write(counter_idx, value) \
    asm volatile (".insn r 0x07, 0x1, 0, x0, %1, %0" : : "r" (counter_idx), "r" (value))

// =============================================================================
// PMU hardware parameters
// =============================================================================
#define NUM_COUNTER         12

#define TIMER_WIDTH         0x8
#define STATUS_WIDTH        0x4
#define BOOT_ADDR_WIDTH     0x4
#define COUNTER_WIDTH       0x4

// PMU Bundle Addresses
#define PMU_B_BASE_ADDR     0x10405000
#define TIMER_ADDR          PMU_B_BASE_ADDR
#define PERIOD_ADDR         (PMU_B_BASE_ADDR + 0x8)
#define PMC_STATUS_ADDR     (PMU_B_BASE_ADDR + 0x1000)
#define PMC_BOOT_ADDR       (PMU_B_BASE_ADDR + 0x1004)
#define PMU_BUNDLE_SIZE     0x2000

// Counter Bundle Base Addresses
// Each counter bundle occupies COUNTER_BUNDLE_SIZE (0x1000) bytes:
//   BASE + 0x0 : Counter register
//   BASE + 0x4 : Event Selection register
//   BASE + 0x8 : Event Info register
//   BASE + 0xC : Initial Budget register
#define COUNTER_B_BASE_ADDR     (PMU_B_BASE_ADDR + PMU_BUNDLE_SIZE)
#define COUNTER_BASE_ADDR       (COUNTER_B_BASE_ADDR + 0*COUNTER_WIDTH)
#define EVENT_SEL_BASE_ADDR     (COUNTER_B_BASE_ADDR + 1*COUNTER_WIDTH)
#define EVENT_INFO_BASE_ADDR    (COUNTER_B_BASE_ADDR + 2*COUNTER_WIDTH)
#define INIT_BUDGET_BASE_ADDR   (COUNTER_B_BASE_ADDR + 3*COUNTER_WIDTH)
#define COUNTER_BUNDLE_SIZE     0x1000

// PMU SPM Addresses
#define ISPM_BASE_ADDR      0x10427000
#define DSPM_BASE_ADDR      0x10428000
#define DSPM_LENGTH         0x8000
#define DSPM_END_ADDR       (DSPM_BASE_ADDR + DSPM_LENGTH)

// =============================================================================
// PMU Event Selection Register encoding
//
// Field layout (24-bit value written to event select register):
//   [23:16]  Port ID + mask byte   (0xNF where N = port number)
//   [15:8]   Source ID + mask byte (0x00 = any source; 0xNF = source N)
//   [7:0]    Event ID + mask byte
//             0x1F = read  request
//             0x2F = write request
//             0x3F = read  response
//             0x4F = write response
//
// SPU port assignment for this 4-core SoC:
//   Ports 1-4  : CVA6-EVUs
//   Port  5    : SPU Core 0 <-> LLC
//   Port  6    : SPU Core 1 <-> LLC
//   Port  7    : SPU Core 2 <-> LLC
//   Port  8    : SPU Core 3 <-> LLC
//   Port  9    : SPU LLC <-> Main Memory
// =============================================================================

// -----------------------------------------------------------------------------
// Core <-> LLC events (SPU ports 5-8)
// -----------------------------------------------------------------------------

// Read requests from Core X to LLC
#define LLC_RD_REQ              0x00001F
#define LLC_RD_REQ_CORE_0       0x5F001F    // port 5
#define LLC_RD_REQ_CORE_1       0x6F001F    // port 6
#define LLC_RD_REQ_CORE_2       0x7F001F    // port 7
#define LLC_RD_REQ_CORE_3       0x8F001F    // port 8

// Read responses to Core X from LLC
#define LLC_RD_RES              0x00003F
#define LLC_RD_RES_CORE_0       0x5F003F
#define LLC_RD_RES_CORE_1       0x6F003F
#define LLC_RD_RES_CORE_2       0x7F003F
#define LLC_RD_RES_CORE_3       0x8F003F

// Write requests from Core X to LLC
#define LLC_WR_REQ              0x00002F
#define LLC_WR_REQ_CORE_0       0x5F002F
#define LLC_WR_REQ_CORE_1       0x6F002F
#define LLC_WR_REQ_CORE_2       0x7F002F
#define LLC_WR_REQ_CORE_3       0x8F002F

// Write responses to Core X from LLC
#define LLC_WR_RES              0x00004F
#define LLC_WR_RES_CORE_0       0x5F004F
#define LLC_WR_RES_CORE_1       0x6F004F
#define LLC_WR_RES_CORE_2       0x7F004F
#define LLC_WR_RES_CORE_3       0x8F004F

// -----------------------------------------------------------------------------
// LLC <-> Main Memory events (SPU port 9)
// Source IDs 4-7 identify which core's traffic reached main memory.
// -----------------------------------------------------------------------------

// All-core aggregate requests/responses
#define MEM_RD_REQ              0x9F001F    // port 9, any source, read  request
#define MEM_WR_REQ              0x9F002F    // port 9, any source, write request
#define MEM_RD_RES              0x9F003F    // port 9, any source, read  response
#define MEM_WR_RES              0x9F004F    // port 9, any source, write response

// Per-core requests reaching Main Memory
// CVA6 is at crossbar slave[0] → upper 4 bits of 8-bit AXI ID are 0000.
// SPU extracts id[7:2] as source_id = {0000, core_id[1:0]} → core 0=0, 1=1, 2=2, 3=3.
#define MEM_RD_REQ_CORE_0       0x9F0F1F   // port 9, src 0 (core 0), read  req
#define MEM_RD_REQ_CORE_1       0x9F1F1F   // port 9, src 1 (core 1), read  req
#define MEM_RD_REQ_CORE_2       0x9F2F1F   // port 9, src 2 (core 2), read  req
#define MEM_RD_REQ_CORE_3       0x9F3F1F   // port 9, src 3 (core 3), read  req
#define MEM_WR_REQ_CORE_0       0x9F0F2F
#define MEM_WR_REQ_CORE_1       0x9F1F2F
#define MEM_WR_REQ_CORE_2       0x9F2F2F
#define MEM_WR_REQ_CORE_3       0x9F3F2F

// Per-core responses from Main Memory to LLC
#define MEM_RD_RES_CORE_0       0x9F0F3F
#define MEM_RD_RES_CORE_1       0x9F1F3F
#define MEM_RD_RES_CORE_2       0x9F2F3F
#define MEM_RD_RES_CORE_3       0x9F3F3F
#define MEM_WR_RES_CORE_0       0x9F0F4F
#define MEM_WR_RES_CORE_1       0x9F1F4F
#define MEM_WR_RES_CORE_2       0x9F2F4F
#define MEM_WR_RES_CORE_3       0x9F3F4F

// =============================================================================
// Event Info Register flags
// =============================================================================
#define ADD_RESP_LAT            0x8001E0    // accumulate response latency
#define CNT_MEM_ONLY            0x808E10    // count only memory-subsystem accesses
#define OVERFLOW_EN             0x1000000   // enable overflow interrupt

#endif // __PMU_HW_DESC_H__
