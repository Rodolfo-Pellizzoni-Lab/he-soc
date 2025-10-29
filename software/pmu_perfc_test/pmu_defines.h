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

#define NUM_COUNTER 12

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
/// Defines for Performance Counters EVU and PC Milestones

//Defines for Configuring the EventSelCfg Register of the PMU Counters.
// These counters monitor the Events out of the CVA6 Performance Counters.
// We Follow PortID-1 for Core 0 and PortID-2 for Core 1.
// The configuration is written as this template [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value, EventID Mask]
#define PERF_COUNTER_EVU_C0_EV0     0x1F0011
#define PERF_COUNTER_EVU_C0_EV1     0x1F0022
#define PERF_COUNTER_EVU_C0_EV2     0x1F0044
#define PERF_COUNTER_EVU_C0_EV3     0x1F0088
#define PERF_COUNTER_EVU_C1_EV0     0x2F0011
#define PERF_COUNTER_EVU_C1_EV1     0x2F0022
#define PERF_COUNTER_EVU_C1_EV2     0x2F0044
#define PERF_COUNTER_EVU_C1_EV3     0x2F0088

 
//Defines for Configuring Performance Counter Event IDs to Monitor using the Performance Counters Event Unit inside the
//CVA6 Performance Counters. (CX) means Core X. EID means Event ID.
#define PERF_COUNTER_EVU_C0_EID0    0x00000010
#define PERF_COUNTER_EVU_C0_EID1    0x00000001
#define PERF_COUNTER_EVU_C0_EID2    0x00000002
#define PERF_COUNTER_EVU_C0_EID3    0x00000017
#define PERF_COUNTER_EVU_C1_EID0    0x00000010
#define PERF_COUNTER_EVU_C1_EID1    0x00000001
#define PERF_COUNTER_EVU_C1_EID2    0x00000002
#define PERF_COUNTER_EVU_C1_EID3    0x00000017

//Defines for Configuring PC Milestones to Monitor using the Performance Counters Event Unit inside the
//CVA6 Performance Counters. (CX) means Core X. ADDR means Address.

#define PCMILESTONE_C0_ADDR0        0x80000E96 //START OF CUA_CORE
#define PCMILESTONE_C0_ADDR1        0x80000EA0 //NEAR START OF CUA_CORE
#define PCMILESTONE_C0_ADDR2        0x80000EA6 //NEAR END OF THE CUA_CORE
#define PCMILESTONE_C0_ADDR3        0x80000EBE //END OF CUA_CORE

#define PCMILESTONE_C1_ADDR0        0x80000E96 //START OF CUA_CORE
#define PCMILESTONE_C1_ADDR1        0x80000EA0 //NEAR START OF THE CUA_CORE
#define PCMILESTONE_C1_ADDR2        0x80000EA6 //NEAR END OF CUA CORE
#define PCMILESTONE_C1_ADDR3        0x80000EBE //END OF CUA_CORE

//Defines for Configuring the EventSelCfg Register of the PMU Counters.
// These counters monitor the PC Milestones of the CVA6 Performance Counters.
// We Follow PortID-3 for Core 0 and PortID-4 for Core 1.
// The configuration is written as this template [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value, EventID Mask]
// PLEASE NOTE TO CHECK THE VALUE OF THE EVENT ID AND CHECK THAT NO OTHER EVENT IS CONFIGURED FOR THIS ID.
// In THIS CASE, We look to set the last event ID as the PC Milestones Event ID. 
// Please make sure to follow it during Event Selection Configuration of PMU Counters as well.
#define PC_MILESTONE_C0             0x1F0088
#define PC_MILESTONE_C1             0x2F0088

//Defines for Base Addresses in AXI_LITE_SLAVE Module presnet inside CVA6_SYNTH_WRAP.
//These enable you to write the EventID or PCMilestone Configuration that is to be monitored.

#define EVENTID_CO_BASE_ADDR        0x10606000
#define PC_MILESTONE_C0_BASE_ADDR   0x10606010

#define EVENTID_C1_BASE_ADDR        0x10606030
#define PC_MILESTONE_C1_BASE_ADDR   0x10606040

//** May or Maynot use these for this test.**//
/// Defines for Core to/from LLC
/// ****************************
// Read requests from Core X to LLC
#define LLC_RD_REQ_CORE_0           0x3F0011
#define LLC_RD_REQ_CORE_1           0x4F0011
#define LLC_RD_RES_CORE_0           0x3F0033
#define LLC_RD_RES_CORE_1           0x4F0033
#define LLC_WR_REQ_CORE_0           0x3F0022
#define LLC_WR_REQ_CORE_1           0x4F0022
#define LLC_WR_RES_CORE_0           0x3F0044
#define LLC_WR_RES_CORE_1           0x4F0044

// If numCVA6 = 2 => PortID = 3 for LLC <=> Main Memory
// If numCVA6 = 4 => PortID = 5 for LLC <=> Main Memory
// Read and write requests of all cores to Main Memory from LLC
#define MEM_RD_REQ                  0x5F0011  
#define MEM_WR_REQ                  0x5F0022
// Read and write responses of all cores to LLC from Main Memory
#define MEM_RD_RES                  0x5F0033  
#define MEM_WR_RES                  0x5F0044
 
/// ***********************************
/// Defines for LLC to/from Main Memory
/// ***********************************
/// Port ID and Mask | Source ID and Mask | Event ID and Mask
///     LLC:0        |     4, 5, 6, 7     |    REQ: 1, 2 
///     MEM:1        |                    |    RES: 3, 4
///  ________________|____________________|_____ RD, WR ______
 


/// **********************************************************************
/// Defines for Event Info Register
/// **********************************************************************
/// Note: The following define only works if the response (X_RES_X) events are selected
//        using the corresponding Event Select Register.
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000