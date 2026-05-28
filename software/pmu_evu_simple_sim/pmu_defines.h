/// This assumes the following: 
///   1. The PMU counters (including the initial budget registers) are 32-bit with 
///      the 31st bit reserved for Pending.
///   2. Both the configuration registers are 32-bits.
///
/// NUM_COUNTER is parameterizable and should be set to the number of counters in the PMU.
/// The memory map of the PMU is as follows:
///     /************************************\
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     \************************************/
///                     .
///                     .                         ... x (NUM_COUNTER)
///                     .
///     /************************************\
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned          
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     \************************************/
///     /************************************\
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     \************************************/
///     /************************************\
///     | MemGuard Period Register           |          Not yet 4kB aligned
///     | PMU Timer                          |              PMU Bundle
///     \************************************/
/// Each block is a separate 4kB-aligned page.
/// The PMU Bundle includes the PMU Timer and the MemGuard Period Register.
/// A counter bundle includes:
///     1. Counter                                BASE_ADDR + 0x0
///     2. Event Selection Register               BASE_ADDR + 0x4
///     3. Event Info Configuration Register      BASE_ADDR + 0x8
///     4. Initial Budget Register                BASE_ADDR + 0xc

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

#define NUM_COUNTER 32

#define TIMER_WIDTH     0x8
#define STATUS_WIDTH    0x4
#define BOOT_ADDR_WIDTH 0x4
#define COUNTER_WIDTH   0x4

// PMU Bundle Addresses
#define PMU_B_BASE_ADDR     0x10405000
#define TIMER_ADDR          PMU_B_BASE_ADDR
#define PERIOD_ADDR         (PMU_B_BASE_ADDR + TIMER_WIDTH)
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

// PMU Core Addresses
#define ISPM_BASE_ADDR  0x10427000
#define DSPM_BASE_ADDR  0x10428000

/// **********************************************************************
/// PMU Event Defines for Event Selection Register
/// **********************************************************************
/// Defines for Core to/from LLC
/// ****************************
// Read requests from Core X to LLC
// Read requests from Core X to LLC
#define LLC_RD_REQ          0x00001F
#define LLC_RD_REQ_CORE_0   0x5F001F
#define LLC_RD_REQ_CORE_1   0x6F001F
#define LLC_RD_REQ_CORE_2   0x7F001F
#define LLC_RD_REQ_CORE_3   0x8F001F
// Read responses to Core X from LLC
#define LLC_RD_RES          0x00003F
#define LLC_RD_RES_CORE_0   0x1F003F
#define LLC_RD_RES_CORE_1   0x2F003F
#define LLC_RD_RES_CORE_2   0x3F003F
#define LLC_RD_RES_CORE_3   0x4F003F
// Write requests from Core X to LLC
#define LLC_WR_REQ          0x00002F
#define LLC_WR_REQ_CORE_0   0x5F002F
#define LLC_WR_REQ_CORE_1   0x6F002F
#define LLC_WR_REQ_CORE_2   0x7F002F
#define LLC_WR_REQ_CORE_3   0x8F002F
// Write responses to Core X from LLC
#define LLC_RD_RES          0x00004F
#define LLC_WR_RES_CORE_0   0x1F004F
#define LLC_WR_RES_CORE_1   0x2F004F
#define LLC_WR_RES_CORE_2   0x3F004F
#define LLC_WR_RES_CORE_3   0x4F004F
 
/// ***********************************
/// Defines for LLC to/from Main Memory
/// ***********************************
/// Port ID and Mask | Source ID and Mask | Event ID and Mask
///     LLC:0        |     4, 5, 6, 7     |    REQ: 1, 2 
///     MEM:1        |                    |    RES: 3, 4
///  ________________|____________________|_____ RD, WR ______
 

// If numCVA6 = 2 => PortID = 3 for LLC <=> Main Memory
// If numCVA6 = 4 => PortID = 5 for LLC <=> Main Memory
// Read and write requests of all cores to Main Memory from LLC
#define MEM_RD_REQ   0x5F001F  //2 core is 0x3F001F...
#define MEM_WR_REQ   0x5F002F   //2 core
// Read and write responses of all cores to LLC from Main Memory
#define MEM_RD_RES   0x5F003F  
#define MEM_WR_RES   0x5F004F
   
// Read and write requests of Core X to Main Memory from LLC
#define MEM_RD_REQ_CORE_0  0x9F0F1F
#define MEM_RD_REQ_CORE_1  0x9F1F1F
#define MEM_RD_REQ_CORE_2  0x9F2F1F
#define MEM_RD_REQ_CORE_3  0x9F3F1F
#define MEM_WR_REQ_CORE_0  0x9F0F2F
#define MEM_WR_REQ_CORE_1  0x9F2F2F
#define MEM_WR_REQ_CORE_2  0x9F2F2F
#define MEM_WR_REQ_CORE_3  0x9F3F2F
// Read and write responses of Core X to LLC from Main Memory
#define MEM_RD_RES_CORE_0  0x5F0F3F
#define MEM_RD_RES_CORE_1  0x5F1F3F
#define MEM_RD_RES_CORE_2  0x5F2F3F
#define MEM_RD_RES_CORE_3  0x5F3F3F
#define MEM_WR_RES_CORE_0  0x5F0F4F
#define MEM_WR_RES_CORE_1  0x5F1F4F
#define MEM_WR_RES_CORE_2  0x5F2F4F
#define MEM_WR_RES_CORE_3  0x5F3F4F


/// **********************************************************************
/// Defines for Event Info Register
/// **********************************************************************
/// Note: The following define only works if the response (X_RES_X) events are selected
//        using the corresponding Event Select Register.
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000

// Per-run config passed via counter registers (CVA6 writes, Ibex reads via cnt_rd).
// Using counter slots avoids DSPM address range constraints entirely.
#define CNT_CONFIG_B     27   /* int32_t  B value   (CVA6 -> firmware) */
#define CNT_CONFIG_PMASK 28   /* uint32_t police_mask (CVA6 -> firmware) */

/// **********************************************************************
/// CVA6 Performance Counter EVU Defines
/// **********************************************************************
/// Event Selection: [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value, EventID Mask]
/// PortID-1 = Core 0, PortID-2 = Core 1

// Performance Counter EVU event selection (per-core, per-event)
#define PERF_COUNTER_EVU_C0_EV0     0x1F0011
#define PERF_COUNTER_EVU_C0_EV1     0x1F0022
#define PERF_COUNTER_EVU_C0_EV2     0x1F0044
#define PERF_COUNTER_EVU_C0_EV3     0x1F0088
#define PERF_COUNTER_EVU_C1_EV0     0x2F0011
#define PERF_COUNTER_EVU_C1_EV1     0x2F0022
#define PERF_COUNTER_EVU_C1_EV2     0x2F0044
#define PERF_COUNTER_EVU_C1_EV3     0x2F0088

// Performance Counter EVU Event IDs (what the EVU monitors)
// These are written to the AXI_LITE_SLAVE EVENTID registers
#define PERF_COUNTER_EVU_C0_EID0    0x00000017  // L1 I-cache access (EV0 — broken, not used)
#define PERF_COUNTER_EVU_C0_EID1    0x00000017  // L1 I-cache miss   (EV1 — works)
#define PERF_COUNTER_EVU_C0_EID2    0x00000017  // Pipeline stalls   (EV2 — works)
#define PERF_COUNTER_EVU_C0_EID3    0x00000017  // UNUSED — keeps EV3 clean for PC milestones only
#define PERF_COUNTER_EVU_C1_EID0    0x00000010
#define PERF_COUNTER_EVU_C1_EID1    0x00000001
#define PERF_COUNTER_EVU_C1_EID2    0x00000002
#define PERF_COUNTER_EVU_C1_EID3    0x00000017

/// **********************************************************************
/// PC Milestone Defines
/// **********************************************************************
/// PC Milestones use the same PortID as perf counter EVU EV3 (EventID=0x88)
/// The hardware compares the core's PC against 4 milestone addresses.
/// When a match occurs, an event is generated on the AXI interconnect.

// PC Milestone event selection (same encoding as EVU EV3)
#define PC_MILESTONE_C0             0x1F0088
#define PC_MILESTONE_C1             0x2F0088

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

// AXI_LITE_SLAVE base addresses inside CVA6_SYNTH_WRAP for EventID and PC Milestone config
#define EVENTID_C0_BASE_ADDR        0x10606000
#define PC_MILESTONE_C0_BASE_ADDR   0x10606010
#define EVENTID_C1_BASE_ADDR        0x10606030
#define PC_MILESTONE_C1_BASE_ADDR   0x10606040

// Note: FUNC_ENTRY / FUNC_EXIT are only needed by the Ibex firmware (main.c).
// They are injected there at compile time via -DFUNC_ENTRY=... -DFUNC_EXIT=...
// (generated by extract_simple_addrs.py during the two-pass build).
// The CVA6-side code does NOT use these symbols.