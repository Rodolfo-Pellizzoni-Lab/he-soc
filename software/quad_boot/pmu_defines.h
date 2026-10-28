/// This assumes the following: 
///   1. The PMU counters (including the initial budget registers) are 32-bit with 
///      the 31st bit reserved for Pending.
///   2. Both the configuration registers are 32-bits.
///
/// NUM_COUNTER is parameterizable and should be set to the number of counters in the PMU.
/// The memory map of the PMU is as follows:
///     +------------------------------------+
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     +------------------------------------+
///                     .
///                     .                         ... x (NUM_COUNTER)
///                     .
///     +------------------------------------+
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned          
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     +------------------------------------+
///     +------------------------------------+
///     | Initial Budget Register            |
///     | Event Info Configuration Register  |          Not yet 4kB aligned
///     | Event Selection Register           |              Counter Bundle
///     | Counter                            |
///     +------------------------------------+
///     +------------------------------------+
///     | MemGuard Period Register           |          Not yet 4kB aligned
///     | PMU Timer                          |              PMU Bundle
///     +------------------------------------+
/// Each block is a separate 4kB-aligned page.
/// The PMU Bundle includes the PMU Timer and the MemGuard Period Register.
/// A counter bundle includes:
///     1. Counter                                BASE_ADDR + 0x0
///     2. Event Selection Register               BASE_ADDR + 0x4
///     3. Event Info Configuration Register      BASE_ADDR + 0x8
///     4. Initial Budget Register                BASE_ADDR + 0xc
///
/// The one copy of the APMU map: the soc tests, the PMU benches' CVA6 code (their pmu_defines.h) and the PE firmware
/// (pmu_firmware/include/pmu_hw_desc.h) include this file.
#ifndef PMU_DEFINES_H
#define PMU_DEFINES_H

// APMU_NUM_COUNTER in hardware/host/host_domain.sv
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

// PMU Core Addresses (pmu_top in hardware/host/host_domain.sv; the DSPM moved from 0x10428000 in 05eee786). The PE
// fetches from the ISPM; its data port reaches only the DSPM, the registers above and the EVU registers (EVU_BASE_ADDR,
// 0x100 bytes): a load or store anywhere else is never granted and stalls the PE. The firmware linker scripts
// (pmu_firmware/linker.ld) repeat both bases. Load the SPMs with aligned 32-bit stores: they index their SRAM by byte
// address, so a byte store (memcpy of a size that is not a multiple of 8) lands in a lane the PE does not read.
#define ISPM_BASE_ADDR  0x10427000
#define ISPM_SIZE       0x2000
#define DSPM_BASE_ADDR  0x10429000
#define DSPM_SIZE       0x20000

/// **********************************************************************
/// PMU Event Defines for Event Selection Register
/// **********************************************************************
/// Defines for Core to/from LLC
/// ****************************
/// Event select = {port value, port mask, source value, source mask, event value, event mask}, a nibble each
/// (hardware/ip_list/apmu/src/pmu_pkg.sv). Ports with NumCVA6 = 4: 1-4 the cores' EVUs, 5-8 the SPUs on the cores'
/// ports to the LLC (one per core), 9 the SPU on the LLC's memory port, 10 the SPU on the accelerator socket's DMA
/// (ariane_soc::Apmu*Idx: 1..N, N+1..2N, 2N+1, 2N+2 with N cores). SPU events: 1 read request, 2 write request,
/// 3 read response, 4 write response. An event value of 0 turns the counter off.
// Read requests from Core X to LLC (LLC_RD_REQ etc. match any port: the memory port 9, the socket's port 10 and the
// EVUs' events with the same event ID count too)
#define LLC_RD_REQ          0x00001F
#define LLC_RD_REQ_CORE_0   0x5F001F
#define LLC_RD_REQ_CORE_1   0x6F001F
#define LLC_RD_REQ_CORE_2   0x7F001F
#define LLC_RD_REQ_CORE_3   0x8F001F
// Read responses to Core X from LLC
#define LLC_RD_RES          0x00003F
#define LLC_RD_RES_CORE_0   0x5F003F
#define LLC_RD_RES_CORE_1   0x6F003F
#define LLC_RD_RES_CORE_2   0x7F003F
#define LLC_RD_RES_CORE_3   0x8F003F
// Write requests from Core X to LLC
#define LLC_WR_REQ          0x00002F
#define LLC_WR_REQ_CORE_0   0x5F002F
#define LLC_WR_REQ_CORE_1   0x6F002F
#define LLC_WR_REQ_CORE_2   0x7F002F
#define LLC_WR_REQ_CORE_3   0x8F002F
// Write responses to Core X from LLC
#define LLC_WR_RES          0x00004F
#define LLC_WR_RES_CORE_0   0x5F004F
#define LLC_WR_RES_CORE_1   0x6F004F
#define LLC_WR_RES_CORE_2   0x7F004F
#define LLC_WR_RES_CORE_3   0x8F004F

/// ***********************************
/// Defines for LLC to/from Main Memory
/// ***********************************
/// Port 9 (2*NumCVA6+1). Its source field is the source of the request (hardware/include/ariane_soc_pkg.sv,
/// ariane_axi_soc::mem_src): 0-3 the cores, 4 the accelerator socket's DMA, 5 the Xilinx Ethernet's DMA (each a port
/// of the coherence unit of its own), then one per other crossbar master p, NumCcuPorts + p - 1: 6 debug module,
/// 9 uDMA TX, 10 uDMA RX, 11 iDMA through the IOMMU, 12 IOMMU data structures. A response counts for the source of
/// its request. The values here are the four-core ones.
// Read and write requests / responses of every source
#define MEM_RD_REQ   0x9F001F
#define MEM_WR_REQ   0x9F002F
#define MEM_RD_RES   0x9F003F
#define MEM_WR_RES   0x9F004F
// Read and write requests of Core X to Main Memory from LLC
#define MEM_RD_REQ_CORE_0  0x9F0F1F
#define MEM_RD_REQ_CORE_1  0x9F1F1F
#define MEM_RD_REQ_CORE_2  0x9F2F1F
#define MEM_RD_REQ_CORE_3  0x9F3F1F
#define MEM_WR_REQ_CORE_0  0x9F0F2F
#define MEM_WR_REQ_CORE_1  0x9F1F2F
#define MEM_WR_REQ_CORE_2  0x9F2F2F
#define MEM_WR_REQ_CORE_3  0x9F3F2F
// Read and write responses of Core X to LLC from Main Memory
#define MEM_RD_RES_CORE_0  0x9F0F3F
#define MEM_RD_RES_CORE_1  0x9F1F3F
#define MEM_RD_RES_CORE_2  0x9F2F3F
#define MEM_RD_RES_CORE_3  0x9F3F3F
#define MEM_WR_RES_CORE_0  0x9F0F4F
#define MEM_WR_RES_CORE_1  0x9F1F4F
#define MEM_WR_RES_CORE_2  0x9F2F4F
#define MEM_WR_RES_CORE_3  0x9F3F4F
// The same for the accelerator socket's DMA (source 4)
#define MEM_RD_REQ_ACCEL   0x9F4F1F
#define MEM_WR_REQ_ACCEL   0x9F4F2F
#define MEM_RD_RES_ACCEL   0x9F4F3F
#define MEM_WR_RES_ACCEL   0x9F4F4F
// ... and for the Xilinx Ethernet's DMA (source 5)
#define MEM_RD_REQ_ETH     0x9F5F1F
#define MEM_WR_REQ_ETH     0x9F5F2F
#define MEM_RD_RES_ETH     0x9F5F3F
#define MEM_WR_RES_ETH     0x9F5F4F
// The old names: source 4 is the accelerator socket's DMA only; it no longer includes the Ethernet DMA, which
// shared that port until it had one of its own (MEM_*_ETH)
#define MEM_RD_REQ_DMA     MEM_RD_REQ_ACCEL
#define MEM_WR_REQ_DMA     MEM_WR_REQ_ACCEL
#define MEM_RD_RES_DMA     MEM_RD_RES_ACCEL
#define MEM_WR_RES_DMA     MEM_WR_RES_ACCEL

/// *****************************************************
/// Defines for the accelerator socket's DMA (port 10)
/// *****************************************************
/// Port 10 (2*NumCVA6+2): the SPU on the accelerator socket's DMA master, in front of its port of the coherence unit
/// (hardware/host/cva6_subsystem.sv, i_spu_accel). It sees every DRAM request of the accelerators before the LLC, hits
/// and misses alike, and nothing else (not the Ethernet DMA, not the cores, not the on-chip SRAM or LLC scratchpad).
/// Every event has source 4, the socket's code on port 9 too; which slot made the request is not recorded. Port 9's
/// MEM_*_ACCEL count the part of it that reached DRAM. The values here are the four-core ones.
#define ACC_RD_REQ         0xAF4F1F
#define ACC_WR_REQ         0xAF4F2F
#define ACC_RD_RES         0xAF4F3F
#define ACC_WR_RES         0xAF4F4F
// Read requests of every source on port 10 (all of them are source 4's)
#define ACC_RD_REQ_ANY     0xAF001F

/// ***************************************
/// Defines for the cores' EVUs (ports 1-4)
/// ***************************************
/// Port core+1 carries a 4-bit event field: bit s is set while slot s of the core's EVU sees its event, so slot s is
/// select 0x11 << s with port value core+1 (0x1F0022: core 0, slot 1); the source is 0. A slot's event ID picks the
/// event (hardware/ip_list/cva6/core/perf_counters_evu.sv): 0 off, 0x01 L1I miss, 0x02 L1D miss, 0x09 branch,
/// 0x11 L1D access, 0x16 pipeline bubble, 0x17 PC milestone, ... The configuration registers
/// (hardware/host/cva6_synth_wrap.sv) are 0x30 bytes per core: four 32-bit event IDs in reverse slot order (+0x0
/// programs slot 3, +0xC slot 0), then the four 64-bit PC milestones, milestone m at +0x10 + 8*m (not reversed). A
/// slot with event ID 0x17 fires when a milestone PC commits, and e_info bit m tells which.
#define EVU_BASE_ADDR             0x10606000
#define EVU_EID_REG(core, slot)   (EVU_BASE_ADDR + 0x30*(core) + 4*(3-(slot)))

/// **********************************************************************
/// Defines for Event Info Register
/// **********************************************************************
/// Note: The following define only works if the response (X_RES_X) events are selected
//        using the corresponding Event Select Register.
//        An event-info counter adds the info of one port per cycle: when several ports match it in the same cycle,
//        the highest-numbered one's is used (pmu_port_wrap.sv), so select a single port (port 10 wins over 9).
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000   // counter bit 30 (overflow) raises PLIC source 156 + counter index

#endif // PMU_DEFINES_H
