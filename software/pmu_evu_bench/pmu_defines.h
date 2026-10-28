// The APMU map, the event selects and the EVU registers (EVU_EID_REG) come from the shared copy.
#include "../quad_boot/pmu_defines.h"

//Results structure layout in memory
// 0x85000000: Test status (0=running, 1=complete, 0xDEAD=error), Dddd0001=finished 
// 0x85000004: Error count, if 0xCODE0000 test was finished no error
// 0x85000008: PMU Counter 0 value (LLC_RD_REQ_CORE_0) 
// 0x8500000C: PMU Counter 1 value (LLC_WR_REQ_CORE_0)

// 0x85000010: PMU Counter 2 value (MEM_RD_REQ_CORE_0)
// 0x85000014: PMU Counter 3 value (MEM_WR_REQ_CORE_0) 
// 0x85000018: PMU Counter 4 value - (LLC_RD_RES_CORE_0)
// 0x8500001C: PMU Counter 5 value - (LLC_WR_RES_CORE_0) 


// 0x85000020: PMU Counter 6 value - (MEM_RD_RES_CORE_0)
// 0x85000024: PMU Counter 7 value - (MEM_WR_RES_CORE_0)
// 0x85000028: Test Info - sent reads in cache line
// 0x8500002C: Test Info - Calculated clock cycles per read

// 0x85000030: Core 0 execution cycles LOW 32-bits (PMU timer)
// 0x85000034: Core 0 execution cycles HIGH 32-bits (PMU timer)
// 0x85000038: Test Info - Reserved
// 0x8500003C: End Marker: always 0xDDDDCCCC
//-----

// Per-run config passed via counter registers (CVA6 writes, Ibex reads via cnt_rd).
// Using counter slots avoids DSPM address range constraints entirely.
#define CNT_CONFIG_B     27   /* int32_t  B value   (CVA6 -> firmware) */
#define CNT_CONFIG_PMASK 28   /* uint32_t police_mask (CVA6 -> firmware) */

/// **********************************************************************
/// CVA6 Performance Counter EVU Defines
/// **********************************************************************
/// Event Selection: [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value, EventID Mask], laid out
/// for the core count (EVU_SLOT_SEL, ../quad_boot/pmu_defines.h)
/// PortID-1 = Core 0, PortID-2 = Core 1

// Performance Counter EVU event selection (per-core, per-event): EVs counts slot s, whose event ID is the register
// EVU_EID_REG(core, s)
#define PERF_COUNTER_EVU_C0_EV0     EVU_SLOT_SEL(0, 0)
#define PERF_COUNTER_EVU_C0_EV1     EVU_SLOT_SEL(0, 1)
#define PERF_COUNTER_EVU_C0_EV2     EVU_SLOT_SEL(0, 2)
#define PERF_COUNTER_EVU_C0_EV3     EVU_SLOT_SEL(0, 3)
#define PERF_COUNTER_EVU_C1_EV0     EVU_SLOT_SEL(1, 0)
#define PERF_COUNTER_EVU_C1_EV1     EVU_SLOT_SEL(1, 1)
#define PERF_COUNTER_EVU_C1_EV2     EVU_SLOT_SEL(1, 2)
#define PERF_COUNTER_EVU_C1_EV3     EVU_SLOT_SEL(1, 3)

// Performance Counter EVU Event IDs per slot, for EVU_EID_REG(core, slot). Not used here: the firmware programs
// core 0's slots.
#define PERF_COUNTER_EVU_C0_EID0    0x00000017
#define PERF_COUNTER_EVU_C0_EID1    0x00000017
#define PERF_COUNTER_EVU_C0_EID2    0x00000017
#define PERF_COUNTER_EVU_C0_EID3    0x00000017
#define PERF_COUNTER_EVU_C1_EID0    0x00000010
#define PERF_COUNTER_EVU_C1_EID1    0x00000001
#define PERF_COUNTER_EVU_C1_EID2    0x00000002
#define PERF_COUNTER_EVU_C1_EID3    0x00000017

/// **********************************************************************
/// PC Milestone Defines
/// **********************************************************************
/// The hardware compares the core's committed PCs against 4 milestone addresses. A slot whose event ID is 0x17
/// reports a match, and the event's e_info bit m tells which milestone.

// PC Milestone event selection: slot 3 (EV3), so EVU_EID_REG(core, 3) must hold 0x17
#define PC_MILESTONE_C0             EVU_SLOT_SEL(0, 3)
#define PC_MILESTONE_C1             EVU_SLOT_SEL(1, 3)

// PC Milestone addresses — UPDATE THESE to match your binary's symbol addresses
// Use: riscv64-unknown-elf-nm pmu_bench.riscv | grep <function_name>
// ADDR0 = computeSAD entry, ADDR1 = integralImage2D2D entry, ADDR2 = finalSAD entry
#define PCMILESTONE_C0_ADDR0        0x800046fc // computeSAD entry
#define PCMILESTONE_C0_ADDR1        0x80004a6a // integralImage2D2D entry
#define PCMILESTONE_C0_ADDR2        0x800047f2 // finalSAD entry
#define PCMILESTONE_C0_ADDR3        0x0        // unused
#define PCMILESTONE_C1_ADDR0        0x00000000  // TODO: configure for core 1
#define PCMILESTONE_C1_ADDR1        0x00000000
#define PCMILESTONE_C1_ADDR2        0x00000000
#define PCMILESTONE_C1_ADDR3        0x00000000

/// **********************************************************************
/// Disparity Function Entry and Exit Addresses
/// **********************************************************************
/// Extracted from pmu_bench.dump - use for milestone tracking
/// Format: FUNC_ENTRY = function entry point, FUNC_EXIT = ret instruction address

// Main disparity algorithm functions
#define GETDISPARITY_ENTRY          0x8000492e
#define GETDISPARITY_EXIT           0x80004a68
#define READIMAGE_ENTRY             0x80004e40
#define READIMAGE_EXIT              0x80004fe4

// Array allocation functions
#define ISETARRAY_ENTRY             0x800050da
#define ISETARRAY_EXIT              0x800051cc
#define FSETARRAY_ENTRY             0x800051d2
#define FSETARRAY_EXIT              0x8000521c

// Image processing functions
#define PADARRAY2_ENTRY             0x80004B30
#define PADARRAY2_EXIT              0x80004C00
#define PADARRAY4_ENTRY             0x80004C28
#define PADARRAY4_EXIT              0x80004D3C

// SAD correlation loop functions (called 8 times per disparity computation)
#define CORRELATESAD_2D_ENTRY       0x8000473C
#define CORRELATESAD_2D_EXIT        0x80004886
#define COMPUTESAD_ENTRY            0x800046DC
#define COMPUTESAD_EXIT             0x8000473A
#define INTEGRALIMAGE2D2D_ENTRY     0x80004A4A
#define INTEGRALIMAGE2D2D_EXIT      0x80004B28
#define FINALSAD_ENTRY              0x800047D2
#define FINALSAD_EXIT               0x80004886

// Disparity map update function
#define FINDDISPARITY_ENTRY         0x80004888
#define FINDDISPARITY_EXIT          0x8000490C

// AXI_LITE_SLAVE base addresses inside CVA6_SYNTH_WRAP for EventID and PC Milestone config (the EventID registers
// are in reverse slot order: slot s is EVENTID_Cx_BASE_ADDR + 4*(3-s), EVU_EID_REG)
#define EVENTID_C0_BASE_ADDR        0x10606000
#define PC_MILESTONE_C0_BASE_ADDR   0x10606010
#define EVENTID_C1_BASE_ADDR        0x10606030
#define PC_MILESTONE_C1_BASE_ADDR   0x10606040

// Note: FUNC_ENTRY / FUNC_EXIT are only needed by the Ibex firmware (main.c).
// They are injected there at compile time via -DFUNC_ENTRY=... -DFUNC_EXIT=...
// (generated by extract_simple_addrs.py during the two-pass build).
// The CVA6-side code does NOT use these symbols.