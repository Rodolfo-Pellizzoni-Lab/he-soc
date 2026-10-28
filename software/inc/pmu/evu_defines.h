/// CVA6 EVU (perf_counters_evu.sv), registers in cva6_synth_wrap.sv.
/// One 0x30 block per core c:
///   +0x00 .. +0x0C  Event ID registers, one per EVU slot (5-bit event code)
///   +0x10 .. +0x2C  PC Milestone registers (64-bit, low half at the lower address)
///
/// Register map (NumCVA6 = 4, all registers 32-bit accessed):
///   0x1060_6000    +--------------------------------------------+
///   EVU Core 0     | +0x00  Event ID slot 3    -> e_id bit 3    |
///                  | +0x04  Event ID slot 2    -> e_id bit 2    |
///                  | +0x08  Event ID slot 1    -> e_id bit 1    |
///                  | +0x0C  Event ID slot 0    -> e_id bit 0    |
///                  | +0x10  PC Milestone 0 LO  -> e_info bit 0  |
///                  | +0x14  PC Milestone 0 HI                   |
///                  | +0x18  PC Milestone 1 LO  -> e_info bit 1  |
///                  | +0x1C  PC Milestone 1 HI                   |
///                  | +0x20  PC Milestone 2 LO  -> e_info bit 2  |
///                  | +0x24  PC Milestone 2 HI                   |
///                  | +0x28  PC Milestone 3 LO  -> e_info bit 3  |
///                  | +0x2C  PC Milestone 3 HI                   |
///                  +--------------------------------------------+
///   0x1060_6030    EVU Core 1 (same layout)
///   0x1060_6060    EVU Core 2 (same layout)
///   0x1060_6090    EVU Core 3 (same layout)
///   0x1060_60C0    unused up to 0x1060_60FF
/// Event ID register: bits [4:0] = event code (EVU_EVENT_*), bits [31:5] unused.

#ifndef EVU_DEFINES_H
#define EVU_DEFINES_H

#define EVU_BASE_ADDR       0x10606000
#define EVU_CORE_SIZE       0x30

// EVENT_ID(s): slot s, stored in reverse (slot 3 at +0x0)
// PCM_LO/HI(s): 64-bit PC milestone s

// Core 0
#define EVU_C0_BASE_ADDR    (EVU_BASE_ADDR + 0*EVU_CORE_SIZE)
#define EVU_C0_EVENT_ID(s)  (EVU_C0_BASE_ADDR + 4*(3 - (s)))
#define EVU_C0_PCM_LO(s)    (EVU_C0_BASE_ADDR + 0x10 + 8*(s))
#define EVU_C0_PCM_HI(s)    (EVU_C0_PCM_LO(s) + 0x4)

// Core 1
#define EVU_C1_BASE_ADDR    (EVU_BASE_ADDR + 1*EVU_CORE_SIZE)
#define EVU_C1_EVENT_ID(s)  (EVU_C1_BASE_ADDR + 4*(3 - (s)))
#define EVU_C1_PCM_LO(s)    (EVU_C1_BASE_ADDR + 0x10 + 8*(s))
#define EVU_C1_PCM_HI(s)    (EVU_C1_PCM_LO(s) + 0x4)

// Core 2
#define EVU_C2_BASE_ADDR    (EVU_BASE_ADDR + 2*EVU_CORE_SIZE)
#define EVU_C2_EVENT_ID(s)  (EVU_C2_BASE_ADDR + 4*(3 - (s)))
#define EVU_C2_PCM_LO(s)    (EVU_C2_BASE_ADDR + 0x10 + 8*(s))
#define EVU_C2_PCM_HI(s)    (EVU_C2_PCM_LO(s) + 0x4)

// Core 3
#define EVU_C3_BASE_ADDR    (EVU_BASE_ADDR + 3*EVU_CORE_SIZE)
#define EVU_C3_EVENT_ID(s)  (EVU_C3_BASE_ADDR + 4*(3 - (s)))
#define EVU_C3_PCM_LO(s)    (EVU_C3_BASE_ADDR + 0x10 + 8*(s))
#define EVU_C3_PCM_HI(s)    (EVU_C3_PCM_LO(s) + 0x4)

// Event codes
#define EVU_DISABLED                   0x00
#define EVU_EVENT_L1_ICACHE_MISS       0x01
#define EVU_EVENT_L1_DCACHE_MISS       0x02
#define EVU_EVENT_ITLB_MISS            0x03
#define EVU_EVENT_DTLB_MISS            0x04
#define EVU_EVENT_LOAD                 0x05
#define EVU_EVENT_STORE                0x06
#define EVU_EVENT_EXCEPTION            0x07
#define EVU_EVENT_EXCEPTION_RET        0x08
#define EVU_EVENT_BRANCH               0x09
#define EVU_EVENT_BRANCH_MISPREDICT    0x0A
#define EVU_EVENT_BRANCH_EXCEPTION     0x0B
#define EVU_EVENT_CALL                 0x0C
#define EVU_EVENT_RETURN               0x0D
#define EVU_EVENT_MSB_FULL             0x0E
#define EVU_EVENT_IFETCH_EMPTY         0x0F
#define EVU_EVENT_L1_ICACHE_ACCESS     0x10
#define EVU_EVENT_L1_DCACHE_ACCESS     0x11
#define EVU_EVENT_CACHE_EVICTION       0x12
#define EVU_EVENT_TLB_FLUSH            0x13
#define EVU_EVENT_INT_INSTR            0x14
#define EVU_EVENT_FP_INSTR             0x15
#define EVU_EVENT_STALL_ISSUE          0x16
#define EVU_EVENT_PC_MILESTONE         0x17
#define EVU_EVENT_SCONTEXT_CHANGE      0x18
#define EVU_EVENT_HCONTEXT_CHANGE      0x19

#endif /* EVU_DEFINES_H */
