// The APMU map, the LLC / memory event selects and the EVU registers (EVU_EID_REG) come from the shared copy.
#include "../quad_boot/pmu_defines.h"

/// **********************************************************************
/// PMU Event Defines for Event Selection Register
/// **********************************************************************
/// Defines for Performance Counters EVU and PC Milestones

//Defines for Configuring the EventSelCfg Register of the PMU Counters.
// These counters monitor the Events out of the CVA6 Performance Counters.
// We Follow PortID-1 for Core 0 and PortID-2 for Core 1.
// The configuration is written as this template [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value,
// EventID Mask], laid out for the core count by EVU_SLOT_SEL (../quad_boot/pmu_defines.h)
#define PERF_COUNTER_EVU_C0_EV0     EVU_SLOT_SEL(0, 0)
#define PERF_COUNTER_EVU_C0_EV1     EVU_SLOT_SEL(0, 1)
#define PERF_COUNTER_EVU_C0_EV2     EVU_SLOT_SEL(0, 2)
#define PERF_COUNTER_EVU_C0_EV3     EVU_SLOT_SEL(0, 3)
#define PERF_COUNTER_EVU_C1_EV0     EVU_SLOT_SEL(1, 0)
#define PERF_COUNTER_EVU_C1_EV1     EVU_SLOT_SEL(1, 1)
#define PERF_COUNTER_EVU_C1_EV2     EVU_SLOT_SEL(1, 2)
#define PERF_COUNTER_EVU_C1_EV3     EVU_SLOT_SEL(1, 3)

 
//Defines for Configuring Performance Counter Event IDs to Monitor using the Performance Counters Event Unit inside the
//CVA6 Performance Counters. (CX) means Core X. EID means Event ID: EIDs is slot s's, written to EVU_EID_REG(X, s).
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
// We Follow PortID-1 for Core 0 and PortID-2 for Core 1; event mask 0x8 is slot 3, whose event ID is EID3.
// The configuration is written as this template [PortID Value, PortID Mask, SourceID Value, SourceID Mask, EventID Value,
// EventID Mask], laid out for the core count by EVU_SLOT_SEL (../quad_boot/pmu_defines.h)
// PLEASE NOTE TO CHECK THE VALUE OF THE EVENT ID AND CHECK THAT NO OTHER EVENT IS CONFIGURED FOR THIS ID.
// In THIS CASE, We look to set the last event ID as the PC Milestones Event ID. 
// Please make sure to follow it during Event Selection Configuration of PMU Counters as well.
#define PC_MILESTONE_C0             EVU_SLOT_SEL(0, 3)
#define PC_MILESTONE_C1             EVU_SLOT_SEL(1, 3)

//Defines for Base Addresses in AXI_LITE_SLAVE Module presnet inside CVA6_SYNTH_WRAP.
//These enable you to write the EventID or PCMilestone Configuration that is to be monitored. The EventID registers are
//in reverse slot order: slot s is EVENTID_CX_BASE_ADDR + 4*(3-s) (EVU_EID_REG).

#define EVENTID_CO_BASE_ADDR        0x10606000
#define PC_MILESTONE_C0_BASE_ADDR   0x10606010

#define EVENTID_C1_BASE_ADDR        0x10606030
#define PC_MILESTONE_C1_BASE_ADDR   0x10606040
