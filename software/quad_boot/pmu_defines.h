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
/// The event selects depend on the SoC's core count (the hardware's NUM_CVA6): build with -DSOC_NUM_CORES=<n> for an
/// n-core SoC (soc_tests/common.mk adds it for SOC_NUM_CORES=<n> or NUM_CVA6=<n>); without it, four cores. Addresses
/// and counter indexes do not depend on it.
#ifndef PMU_DEFINES_H
#define PMU_DEFINES_H

// The SoC's core count, the same default as soc_test.h
#ifndef SOC_NUM_CORES
#define SOC_NUM_CORES 4
#endif

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
// a window of 0x100 bytes with four cores, 0x200 with eight): a load or store anywhere else is never granted and
// stalls the PE. The firmware linker scripts (pmu_firmware/linker.ld) repeat both bases. Load the SPMs with aligned
// 32-bit stores: they index their SRAM by byte address, so a byte store (memcpy of a size that is not a multiple of 8)
// lands in a lane the PE does not read.
#define ISPM_BASE_ADDR  0x10427000
#define ISPM_SIZE       0x2000
#define DSPM_BASE_ADDR  0x10429000
#define DSPM_SIZE       0x20000

/// **********************************************************************
/// PMU Event Defines for Event Selection Register
/// **********************************************************************
/// Event select = {pad, port value, port mask, source value, source mask, event value, event mask}
/// (hardware/ip_list/apmu/src/pmu_pkg.sv): a counter counts an event of port P, source S and event ID E when
/// (P & port mask) == port value, (S & source mask) == source value and (E & event mask) == event value; an event
/// value of 0 turns the counter off. The event fields are 4 bits; the port and source fields follow the core count,
/// 4 bits with up to four cores and 5 bits with more (pmu_pkg::PORT_ID_BITS / SOURCE_ID_BITS):
///                    pad      port val  port mask  src val  src mask  ev val  ev mask
///   4-bit fields     [31:24]  [23:20]   [19:16]    [15:12]  [11:8]    [7:4]   [3:0]
///   5-bit fields     [31:28]  [27:23]   [22:18]    [17:13]  [12:8]    [7:4]   [3:0]
/// So a select written for one layout means something else in the other: build for the bitstream's core count.
#define APMU_PORT_BITS  (SOC_NUM_CORES > 4 ? 5 : 4)
#define APMU_SRC_BITS   (SOC_NUM_CORES > 4 ? 5 : 4)
#define APMU_EV_BITS    4
#define APMU_PORT_ALL   ((1 << APMU_PORT_BITS) - 1)     // the port / source / event mask that compares every bit
#define APMU_SRC_ALL    ((1 << APMU_SRC_BITS) - 1)
#define APMU_EV_ALL     ((1 << APMU_EV_BITS) - 1)
#define APMU_SEL(port, pmask, src, smask, ev, emask)                                                          \
  (((port) << (2 * APMU_EV_BITS + 2 * APMU_SRC_BITS + APMU_PORT_BITS)) |                                      \
   ((pmask) << (2 * APMU_EV_BITS + 2 * APMU_SRC_BITS)) | ((src) << (2 * APMU_EV_BITS + APMU_SRC_BITS)) |       \
   ((smask) << (2 * APMU_EV_BITS)) | ((ev) << APMU_EV_BITS) | (emask))
// event ev of one port, of every source / of one source; event ev of every port and source
#define APMU_SEL_PORT_EV(port, ev)          APMU_SEL(port, APMU_PORT_ALL, 0, 0, ev, APMU_EV_ALL)
#define APMU_SEL_PORT_SRC_EV(port, src, ev) APMU_SEL(port, APMU_PORT_ALL, src, APMU_SRC_ALL, ev, APMU_EV_ALL)
#define APMU_SEL_ANY_EV(ev)                 APMU_SEL(0, 0, 0, 0, ev, APMU_EV_ALL)

/// The APMU's ports with N = SOC_NUM_CORES cores (ariane_soc::Apmu*Idx: element i of host_domain's spu_o is port i+1):
/// 1..N the cores' EVUs, N+1..2N the SPUs on the cores' ports to the LLC (one per core), 2N+1 the SPU on the LLC's
/// memory port, 2N+2 the SPU on the accelerator socket's DMA. Four cores: 1-4, 5-8, 9, 10; eight: 1-8, 9-16, 17, 18.
/// SPU events: 1 read request, 2 write request, 3 read response, 4 write response.
#define APMU_PORT_EVU(core)        (1 + (core))
#define APMU_PORT_CORE_SPU(core)   (1 + SOC_NUM_CORES + (core))
#define APMU_PORT_MEM_SPU          (2 * SOC_NUM_CORES + 1)
#define APMU_PORT_ACCEL_SPU        (2 * SOC_NUM_CORES + 2)
#define APMU_NUM_PORTS             (2 * SOC_NUM_CORES + 2)
#define APMU_EV_RD_REQ             1
#define APMU_EV_WR_REQ             2
#define APMU_EV_RD_RES             3
#define APMU_EV_WR_RES             4

/// The source of a request at the LLC's memory port (port 2N+1), as its SPU reports it (hardware/include/
/// ariane_soc_pkg.sv, ariane_axi_soc::mem_src): 0..N-1 the cores, N the accelerator socket's DMA, N+1 the Xilinx
/// Ethernet's DMA (each a port of the coherence unit of its own), then one per other crossbar master p = 1..9
/// (ariane_soc::axi_masters_t), N+1+p: N+2 debug module, N+3 cluster, N+4 RoT, N+5 / N+6 uDMA TX / RX, N+7 iDMA through
/// the IOMMU, N+8 IOMMU data structures, N+9 IOPMP initiator, N+10 the APMU's own master. Four cores: 0-3, 4, 5, 6-14;
/// eight: 0-7, 8, 9, 10-18. A response counts for the source of its request.
#define APMU_SRC_CORE(core)        (core)
#define APMU_SRC_ACCEL             SOC_NUM_CORES                 // ariane_soc::CcuAccelPort
#define APMU_SRC_ETH               (SOC_NUM_CORES + 1)           // ariane_soc::CcuEthPort
#define APMU_SRC_XBAR(p)           (SOC_NUM_CORES + 1 + (p))     // ariane_soc::NumCcuPorts + p - 1
#define APMU_SRC_DEBUG             APMU_SRC_XBAR(1)
#define APMU_SRC_CLUSTER           APMU_SRC_XBAR(2)
#define APMU_SRC_ROT               APMU_SRC_XBAR(3)
#define APMU_SRC_UDMA_TX           APMU_SRC_XBAR(4)
#define APMU_SRC_UDMA_RX           APMU_SRC_XBAR(5)
#define APMU_SRC_IOMMU_COMP        APMU_SRC_XBAR(6)
#define APMU_SRC_IOMMU_DS          APMU_SRC_XBAR(7)
#define APMU_SRC_IOPMP             APMU_SRC_XBAR(8)
#define APMU_SRC_PMU               APMU_SRC_XBAR(9)
#define APMU_NUM_SRCS              (SOC_NUM_CORES + 11)          // ariane_soc::NumMemSrcs

/// ****************************
/// Defines for Core to/from LLC
/// ****************************
/// Ports N+1..2N, one per core. LLC_RD_REQ etc. match any port: the memory port 2N+1, the socket's port 2N+2 and the
/// EVUs' events with the same event ID count too.
// Read requests from Core X to LLC
#define LLC_RD_REQ          APMU_SEL_ANY_EV(APMU_EV_RD_REQ)
#define LLC_RD_REQ_CORE(c)  APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_RD_REQ)
#define LLC_RD_REQ_CORE_0   LLC_RD_REQ_CORE(0)
#define LLC_RD_REQ_CORE_1   LLC_RD_REQ_CORE(1)
#define LLC_RD_REQ_CORE_2   LLC_RD_REQ_CORE(2)
#define LLC_RD_REQ_CORE_3   LLC_RD_REQ_CORE(3)
// Read responses to Core X from LLC
#define LLC_RD_RES          APMU_SEL_ANY_EV(APMU_EV_RD_RES)
#define LLC_RD_RES_CORE(c)  APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_RD_RES)
#define LLC_RD_RES_CORE_0   LLC_RD_RES_CORE(0)
#define LLC_RD_RES_CORE_1   LLC_RD_RES_CORE(1)
#define LLC_RD_RES_CORE_2   LLC_RD_RES_CORE(2)
#define LLC_RD_RES_CORE_3   LLC_RD_RES_CORE(3)
// Write requests from Core X to LLC
#define LLC_WR_REQ          APMU_SEL_ANY_EV(APMU_EV_WR_REQ)
#define LLC_WR_REQ_CORE(c)  APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_WR_REQ)
#define LLC_WR_REQ_CORE_0   LLC_WR_REQ_CORE(0)
#define LLC_WR_REQ_CORE_1   LLC_WR_REQ_CORE(1)
#define LLC_WR_REQ_CORE_2   LLC_WR_REQ_CORE(2)
#define LLC_WR_REQ_CORE_3   LLC_WR_REQ_CORE(3)
// Write responses to Core X from LLC
#define LLC_WR_RES          APMU_SEL_ANY_EV(APMU_EV_WR_RES)
#define LLC_WR_RES_CORE(c)  APMU_SEL_PORT_EV(APMU_PORT_CORE_SPU(c), APMU_EV_WR_RES)
#define LLC_WR_RES_CORE_0   LLC_WR_RES_CORE(0)
#define LLC_WR_RES_CORE_1   LLC_WR_RES_CORE(1)
#define LLC_WR_RES_CORE_2   LLC_WR_RES_CORE(2)
#define LLC_WR_RES_CORE_3   LLC_WR_RES_CORE(3)

/// ***********************************
/// Defines for LLC to/from Main Memory
/// ***********************************
/// Port 2N+1 (9 with four cores, 17 with eight), its source field the source of the request (APMU_SRC_*, above).
// Event ev (APMU_EV_*) of one source
#define MEM_SEL(ev, src)   APMU_SEL_PORT_SRC_EV(APMU_PORT_MEM_SPU, src, ev)
// Read and write requests / responses of every source
#define MEM_RD_REQ   APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_RD_REQ)
#define MEM_WR_REQ   APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_WR_REQ)
#define MEM_RD_RES   APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_RD_RES)
#define MEM_WR_RES   APMU_SEL_PORT_EV(APMU_PORT_MEM_SPU, APMU_EV_WR_RES)
// Read and write requests of Core X to Main Memory from LLC
#define MEM_RD_REQ_CORE(c) MEM_SEL(APMU_EV_RD_REQ, APMU_SRC_CORE(c))
#define MEM_WR_REQ_CORE(c) MEM_SEL(APMU_EV_WR_REQ, APMU_SRC_CORE(c))
#define MEM_RD_REQ_CORE_0  MEM_RD_REQ_CORE(0)
#define MEM_RD_REQ_CORE_1  MEM_RD_REQ_CORE(1)
#define MEM_RD_REQ_CORE_2  MEM_RD_REQ_CORE(2)
#define MEM_RD_REQ_CORE_3  MEM_RD_REQ_CORE(3)
#define MEM_WR_REQ_CORE_0  MEM_WR_REQ_CORE(0)
#define MEM_WR_REQ_CORE_1  MEM_WR_REQ_CORE(1)
#define MEM_WR_REQ_CORE_2  MEM_WR_REQ_CORE(2)
#define MEM_WR_REQ_CORE_3  MEM_WR_REQ_CORE(3)
// Read and write responses of Core X to LLC from Main Memory
#define MEM_RD_RES_CORE(c) MEM_SEL(APMU_EV_RD_RES, APMU_SRC_CORE(c))
#define MEM_WR_RES_CORE(c) MEM_SEL(APMU_EV_WR_RES, APMU_SRC_CORE(c))
#define MEM_RD_RES_CORE_0  MEM_RD_RES_CORE(0)
#define MEM_RD_RES_CORE_1  MEM_RD_RES_CORE(1)
#define MEM_RD_RES_CORE_2  MEM_RD_RES_CORE(2)
#define MEM_RD_RES_CORE_3  MEM_RD_RES_CORE(3)
#define MEM_WR_RES_CORE_0  MEM_WR_RES_CORE(0)
#define MEM_WR_RES_CORE_1  MEM_WR_RES_CORE(1)
#define MEM_WR_RES_CORE_2  MEM_WR_RES_CORE(2)
#define MEM_WR_RES_CORE_3  MEM_WR_RES_CORE(3)
// The same for the accelerator socket's DMA (source N)
#define MEM_RD_REQ_ACCEL   MEM_SEL(APMU_EV_RD_REQ, APMU_SRC_ACCEL)
#define MEM_WR_REQ_ACCEL   MEM_SEL(APMU_EV_WR_REQ, APMU_SRC_ACCEL)
#define MEM_RD_RES_ACCEL   MEM_SEL(APMU_EV_RD_RES, APMU_SRC_ACCEL)
#define MEM_WR_RES_ACCEL   MEM_SEL(APMU_EV_WR_RES, APMU_SRC_ACCEL)
// ... and for the Xilinx Ethernet's DMA (source N+1)
#define MEM_RD_REQ_ETH     MEM_SEL(APMU_EV_RD_REQ, APMU_SRC_ETH)
#define MEM_WR_REQ_ETH     MEM_SEL(APMU_EV_WR_REQ, APMU_SRC_ETH)
#define MEM_RD_RES_ETH     MEM_SEL(APMU_EV_RD_RES, APMU_SRC_ETH)
#define MEM_WR_RES_ETH     MEM_SEL(APMU_EV_WR_RES, APMU_SRC_ETH)
// The old names: source N is the accelerator socket's DMA only; it no longer includes the Ethernet DMA, which
// shared that port until it had one of its own (MEM_*_ETH)
#define MEM_RD_REQ_DMA     MEM_RD_REQ_ACCEL
#define MEM_WR_REQ_DMA     MEM_WR_REQ_ACCEL
#define MEM_RD_RES_DMA     MEM_RD_RES_ACCEL
#define MEM_WR_RES_DMA     MEM_WR_RES_ACCEL

/// ********************************************************
/// Defines for the accelerator socket's DMA (port 2N+2)
/// ********************************************************
/// Port 2N+2 (10 with four cores, 18 with eight): the SPU on the accelerator socket's DMA master, in front of its port
/// of the coherence unit (hardware/host/cva6_subsystem.sv, i_spu_accel). It sees every DRAM request of the
/// accelerators before the LLC, hits and misses alike, and nothing else (not the Ethernet DMA, not the cores, not the
/// on-chip SRAM or LLC scratchpad). Every event has source N, the socket's code on port 2N+1 too; which slot made the
/// request is not recorded. Port 2N+1's MEM_*_ACCEL count the part of it that reached DRAM.
#define ACC_RD_REQ         APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_RD_REQ)
#define ACC_WR_REQ         APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_WR_REQ)
#define ACC_RD_RES         APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_RD_RES)
#define ACC_WR_RES         APMU_SEL_PORT_SRC_EV(APMU_PORT_ACCEL_SPU, APMU_SRC_ACCEL, APMU_EV_WR_RES)
// Read requests of every source on port 2N+2 (all of them are source N's)
#define ACC_RD_REQ_ANY     APMU_SEL_PORT_EV(APMU_PORT_ACCEL_SPU, APMU_EV_RD_REQ)

/// ****************************************
/// Defines for the cores' EVUs (ports 1-N)
/// ****************************************
/// Port core+1 carries a 4-bit event field: bit s is set while slot s of the core's EVU sees its event, so slot s is
/// event value and mask 1 << s on port core+1 (EVU_SLOT_SEL: 0x1F0022 for core 0, slot 1, with four cores; 0xFC0022
/// with eight); the source is 0. A slot's event ID picks the event (hardware/ip_list/cva6/core/perf_counters_evu.sv):
/// 0 off, 0x01 L1I miss, 0x02 L1D miss, 0x09 branch, 0x11 L1D access, 0x16 pipeline bubble, 0x17 PC milestone, ...
/// The configuration registers (hardware/host/cva6_synth_wrap.sv, ariane_soc::PerfcEvu*) are 0x30 bytes per core:
/// four 32-bit event IDs in reverse slot order (+0x0 programs slot 3, +0xC slot 0; the EVU uses bits [4:0]), then the
/// four 64-bit PC milestones, milestone m at +0x10 + 8*m (not reversed). A slot with event ID 0x17 fires when a
/// milestone PC commits, and e_info bit m tells which.
#define EVU_BASE_ADDR             0x10606000
#define EVU_EID_REG(core, slot)   (EVU_BASE_ADDR + 0x30*(core) + 4*(3-(slot)))
#define EVU_PC_REG(core, m)       (EVU_BASE_ADDR + 0x30*(core) + 0x10 + 8*(m))   // low word; the high word at +4
#define EVU_SLOT_SEL(core, slot)  APMU_SEL(APMU_PORT_EVU(core), APMU_PORT_ALL, 0, 0, 1 << (slot), 1 << (slot))

/// **********************************************************************
/// Defines for Event Info Register
/// **********************************************************************
/// Note: The following define only works if the response (X_RES_X) events are selected
//        using the corresponding Event Select Register.
//        An event-info counter adds the info of one port per cycle: when several ports match it in the same cycle,
//        the highest-numbered one's is used (pmu_port_wrap.sv), so select a single port (port 2N+2 wins over 2N+1).
#define ADD_RESP_LAT   0x8001E0
#define ADD_MEM_ONLY   0x808E10
#define OVERFLOW_EN    0x1000000   // counter bit 30 (overflow) raises PLIC source 156 + counter index

#ifndef __ASSEMBLER__
// Every port and every memory-port source fits its field (as host_domain checks on the hardware side)
_Static_assert(APMU_NUM_PORTS <= APMU_PORT_ALL, "pmu_defines.h: the APMU's ports do not fit APMU_PORT_BITS");
_Static_assert(APMU_NUM_SRCS <= APMU_SRC_ALL + 1, "pmu_defines.h: the memory port's sources do not fit APMU_SRC_BITS");
#if SOC_NUM_CORES == 4
// With four cores every select is the value it had as a literal before it was computed: a four-core build programs
// exactly what it did
#define PMU_DEFINES_IS(name, value) _Static_assert((name) == (value), "pmu_defines.h: " #name " is not " #value)
PMU_DEFINES_IS(APMU_PORT_MEM_SPU, 9);
PMU_DEFINES_IS(APMU_PORT_ACCEL_SPU, 10);
PMU_DEFINES_IS(APMU_SRC_ACCEL, 4);
PMU_DEFINES_IS(APMU_SRC_ETH, 5);
PMU_DEFINES_IS(APMU_SRC_DEBUG, 6);
PMU_DEFINES_IS(APMU_SRC_UDMA_TX, 9);
PMU_DEFINES_IS(APMU_SRC_UDMA_RX, 10);
PMU_DEFINES_IS(APMU_SRC_IOMMU_COMP, 11);
PMU_DEFINES_IS(APMU_SRC_IOMMU_DS, 12);
PMU_DEFINES_IS(LLC_RD_REQ, 0x00001F);
PMU_DEFINES_IS(LLC_RD_REQ_CORE_0, 0x5F001F);
PMU_DEFINES_IS(LLC_RD_REQ_CORE_1, 0x6F001F);
PMU_DEFINES_IS(LLC_RD_REQ_CORE_2, 0x7F001F);
PMU_DEFINES_IS(LLC_RD_REQ_CORE_3, 0x8F001F);
PMU_DEFINES_IS(LLC_RD_RES, 0x00003F);
PMU_DEFINES_IS(LLC_RD_RES_CORE_0, 0x5F003F);
PMU_DEFINES_IS(LLC_RD_RES_CORE_1, 0x6F003F);
PMU_DEFINES_IS(LLC_RD_RES_CORE_2, 0x7F003F);
PMU_DEFINES_IS(LLC_RD_RES_CORE_3, 0x8F003F);
PMU_DEFINES_IS(LLC_WR_REQ, 0x00002F);
PMU_DEFINES_IS(LLC_WR_REQ_CORE_0, 0x5F002F);
PMU_DEFINES_IS(LLC_WR_REQ_CORE_1, 0x6F002F);
PMU_DEFINES_IS(LLC_WR_REQ_CORE_2, 0x7F002F);
PMU_DEFINES_IS(LLC_WR_REQ_CORE_3, 0x8F002F);
PMU_DEFINES_IS(LLC_WR_RES, 0x00004F);
PMU_DEFINES_IS(LLC_WR_RES_CORE_0, 0x5F004F);
PMU_DEFINES_IS(LLC_WR_RES_CORE_1, 0x6F004F);
PMU_DEFINES_IS(LLC_WR_RES_CORE_2, 0x7F004F);
PMU_DEFINES_IS(LLC_WR_RES_CORE_3, 0x8F004F);
PMU_DEFINES_IS(MEM_RD_REQ, 0x9F001F);
PMU_DEFINES_IS(MEM_WR_REQ, 0x9F002F);
PMU_DEFINES_IS(MEM_RD_RES, 0x9F003F);
PMU_DEFINES_IS(MEM_WR_RES, 0x9F004F);
PMU_DEFINES_IS(MEM_RD_REQ_CORE_0, 0x9F0F1F);
PMU_DEFINES_IS(MEM_RD_REQ_CORE_1, 0x9F1F1F);
PMU_DEFINES_IS(MEM_RD_REQ_CORE_2, 0x9F2F1F);
PMU_DEFINES_IS(MEM_RD_REQ_CORE_3, 0x9F3F1F);
PMU_DEFINES_IS(MEM_WR_REQ_CORE_0, 0x9F0F2F);
PMU_DEFINES_IS(MEM_WR_REQ_CORE_1, 0x9F1F2F);
PMU_DEFINES_IS(MEM_WR_REQ_CORE_2, 0x9F2F2F);
PMU_DEFINES_IS(MEM_WR_REQ_CORE_3, 0x9F3F2F);
PMU_DEFINES_IS(MEM_RD_RES_CORE_0, 0x9F0F3F);
PMU_DEFINES_IS(MEM_RD_RES_CORE_1, 0x9F1F3F);
PMU_DEFINES_IS(MEM_RD_RES_CORE_2, 0x9F2F3F);
PMU_DEFINES_IS(MEM_RD_RES_CORE_3, 0x9F3F3F);
PMU_DEFINES_IS(MEM_WR_RES_CORE_0, 0x9F0F4F);
PMU_DEFINES_IS(MEM_WR_RES_CORE_1, 0x9F1F4F);
PMU_DEFINES_IS(MEM_WR_RES_CORE_2, 0x9F2F4F);
PMU_DEFINES_IS(MEM_WR_RES_CORE_3, 0x9F3F4F);
PMU_DEFINES_IS(MEM_RD_REQ_ACCEL, 0x9F4F1F);
PMU_DEFINES_IS(MEM_WR_REQ_ACCEL, 0x9F4F2F);
PMU_DEFINES_IS(MEM_RD_RES_ACCEL, 0x9F4F3F);
PMU_DEFINES_IS(MEM_WR_RES_ACCEL, 0x9F4F4F);
PMU_DEFINES_IS(MEM_RD_REQ_ETH, 0x9F5F1F);
PMU_DEFINES_IS(MEM_WR_REQ_ETH, 0x9F5F2F);
PMU_DEFINES_IS(MEM_RD_RES_ETH, 0x9F5F3F);
PMU_DEFINES_IS(MEM_WR_RES_ETH, 0x9F5F4F);
PMU_DEFINES_IS(MEM_RD_REQ_DMA, 0x9F4F1F);
PMU_DEFINES_IS(MEM_WR_REQ_DMA, 0x9F4F2F);
PMU_DEFINES_IS(MEM_RD_RES_DMA, 0x9F4F3F);
PMU_DEFINES_IS(MEM_WR_RES_DMA, 0x9F4F4F);
PMU_DEFINES_IS(ACC_RD_REQ, 0xAF4F1F);
PMU_DEFINES_IS(ACC_WR_REQ, 0xAF4F2F);
PMU_DEFINES_IS(ACC_RD_RES, 0xAF4F3F);
PMU_DEFINES_IS(ACC_WR_RES, 0xAF4F4F);
PMU_DEFINES_IS(ACC_RD_REQ_ANY, 0xAF001F);
PMU_DEFINES_IS(EVU_SLOT_SEL(0, 0), 0x1F0011);   // the benches' PERF_COUNTER_EVU_C0_EV0 .. C1_EV3
PMU_DEFINES_IS(EVU_SLOT_SEL(0, 1), 0x1F0022);
PMU_DEFINES_IS(EVU_SLOT_SEL(0, 2), 0x1F0044);
PMU_DEFINES_IS(EVU_SLOT_SEL(0, 3), 0x1F0088);
PMU_DEFINES_IS(EVU_SLOT_SEL(1, 0), 0x2F0011);
PMU_DEFINES_IS(EVU_SLOT_SEL(1, 1), 0x2F0022);
PMU_DEFINES_IS(EVU_SLOT_SEL(1, 2), 0x2F0044);
PMU_DEFINES_IS(EVU_SLOT_SEL(1, 3), 0x2F0088);
PMU_DEFINES_IS(EVU_SLOT_SEL(3, 3), 0x4F0088);
PMU_DEFINES_IS(EVU_EID_REG(1, 1), 0x10606038);
PMU_DEFINES_IS(EVU_PC_REG(1, 0), 0x10606040);
#undef PMU_DEFINES_IS
#endif
#endif

#endif // PMU_DEFINES_H
