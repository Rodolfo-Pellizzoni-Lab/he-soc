// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Description: Contains SoC information as constants

`ifdef TARGET_FPGA
 `ifndef TARGET_DDR
  `define HYPER_FPGA_DDR
 `endif
`endif
`define QUAD_CORE
package ariane_soc;

  // Number of CVA6 cores. NUM_CVA6=<n> (a +define, see hardware/Makefile and xsim/env.sh) sizes the CCU, the
  // CLINT, the PLIC contexts, the debug module, the APMU ports and the AXI user field for n cores; without it
  // QUAD_CORE gives the four cores every flow in this tree builds, else two.
  `ifdef NUM_CVA6
   localparam NumCVA6 = `NUM_CVA6;
  `elsif QUAD_CORE
   localparam NumCVA6 = 4;
  `else
   localparam NumCVA6 = 2;
  `endif

  // M-Mode Hart, S-Mode Hart
  localparam int unsigned NumTargets = 2*NumCVA6;
  // Uart, SPI, Ethernet, reserved
`ifdef USE_APLIC
  localparam int unsigned NumSources = 256;
`else
  localparam int unsigned NumSources = 255;
`endif

  localparam int unsigned MaxPriority = 7;
/*
  // AIA
  localparam int unsigned NumSourcesImsic = cva6_config_pkg::CVA6ConfigNrSourcesImsic;
  localparam int unsigned NrVSIntpFiles   = cva6_config_pkg::CVA6ConfigNrVSIntpFiles;
  localparam int unsigned NrVSIntpFilesW  = cva6_config_pkg::CVA6ConfigNrVSIntpFilesW;
  localparam int unsigned NrIntpFiles     = cva6_config_pkg::CVA6ConfigNrIntpFiles; 
  localparam int unsigned NrSourcesW      = cva6_config_pkg::CVA6ConfigNrSourcesW;
*/
  // actually masters, but slaves on the crossbar
  typedef enum int unsigned {
    CVA6        = 0,  // CVA6
    DEBUG_MST   = 1,  // Debug module master port
    CLUSTER_MST = 2,  // Cluster master port
    ROT         = 3,  // RoT
    UDMA_TX     = 4,  // uDMA (tx)
    UDMA_RX     = 5,  // uDMA (rx)
    IOMMU_COMP  = 6,  // IOMMU Completion Interface
    IOMMU_DS    = 7,  // IOMMU Data Structure Interface
    IOPMP_INIT  = 8,  // IOPMP Initiator Port
    PMU         = 9   // PMU's port
  } axi_masters_t;

  localparam NrSlaves = PMU + 1;   // 10

  typedef struct packed {
      logic [31:0] idx;
      logic [63:0] start_addr;
      logic [63:0] end_addr;
   } addr_map_rule_t;

  // Host crossbar IDs: every master's port is IdWidth bits, and the crossbar puts the index of that port
  // (axi_masters_t, XbarPortWidth bits) above them, so its slaves (the LLC among them) see IdWidthSlave bits.
  // 4 is what the masters on it are built for (OpenTitan's has fixed 4-bit IDs). Raising it widens every slave-side
  // ID, the LLC memory port's too, and with it the FPGA DDR4 controller, an IP generated with a fixed ID width
  // (fpga/setup.sh AXI_ID_DDR_WIDTH). (The CVA6 cores' own IDs are ariane_axi::IdWidth, a different width.)
  localparam IdWidth       = 4;
  localparam XbarPortWidth = $clog2(NrSlaves);
  localparam IdWidthSlave  = IdWidth + XbarPortWidth;

  // ---- Masters of the coherence unit (CCU, cva6_synth_wrap): the NumCVA6 cores are its ports 0..NumCVA6-1, then
  // its DMA ports, one per DMA master (cva6_subsystem): element k of the wrapper's DMA-port array is CCU port
  // CcuDmaPort + k. Both DMA ports exist in every build (without XILINX_ETHERNET the Ethernet's request is 0), so the
  // source numbers do not depend on build options. Every number and width that depends on how many masters the CCU
  // has derives from these.
  localparam int unsigned NumCcuDmaPorts = 2;
  localparam int unsigned NumCcuPorts    = NumCVA6 + NumCcuDmaPorts;
  localparam int unsigned CcuDmaPort     = NumCVA6;   // the first DMA port
  // The index in the wrapper's DMA-port array and the CCU port (the source the CCU writes: 4 and 5 with four cores,
  // 8 and 9 with eight) of the accelerator socket's DMA and of the Xilinx Ethernet's AXI DMA
  localparam int unsigned CcuDmaAccel    = 0;
  localparam int unsigned CcuDmaEth      = 1;
  localparam int unsigned CcuAccelPort   = CcuDmaPort + CcuDmaAccel;
  localparam int unsigned CcuEthPort     = CcuDmaPort + CcuDmaEth;
  // The CCU writes the port a request came from (its "source") into the low CcuSrcWidth bits of the AXI user field
  // (ace_ccu_top; ariane_axi_soc::QosUserLsb), and the source travels with the request to the memory.
  localparam int unsigned CcuSrcWidth    = (NumCcuPorts > 1) ? $clog2(NumCcuPorts) : 1;

  // ---- ID remapper between the CCU and the crossbar (cva6_axi_id_remap): RemapMaxUniqIds IDs in flight per
  // direction, and AXI ID = {source, slot}. RemapSrcWidth bits of the source fit next to the slot in IdWidth bits;
  // with fewer than CcuSrcWidth the ID keeps the source's low bits, and what needs the full source reads the user
  // field. IdWidth >= RemapSlotWidth + CcuSrcWidth would make the ID carry all of it.
  localparam int unsigned RemapMaxUniqIds = 4;
  localparam int unsigned RemapTxnsPerId  = 1;
  localparam int unsigned RemapSlotWidth  = cf_math_pkg::idx_width(RemapMaxUniqIds);   // as the remapper sizes it
  localparam int unsigned RemapSrcWidth   = IdWidth - RemapSlotWidth;

  // ---- Source of a request at the LLC memory port, as the APMU's SPU there reports it (host_domain,
  // ariane_axi_soc::mem_src): 0..NumCcuPorts-1 the CCU source (the cores, then CcuAccelPort and CcuEthPort),
  // NumCcuPorts + p - 1 for crossbar master p >= 1. MemSrcWidth is the APMU's source field, pmu_pkg::SOURCE_ID_BITS:
  // 4 bits with up to four cores, 5 with more (the NUM_CVA6 define). It must hold all NumMemSrcs (checked in
  // host_domain): codes 0-14 with four cores, 0-18 with eight.
  localparam int unsigned NumMemSrcs  = NumCcuPorts + NrSlaves - 1;
  localparam int unsigned MemSrcWidth = pmu_pkg::SOURCE_ID_BITS;

  // ---- APMU event ports (host_domain: spu_o, the APMU's port_i). Element i is APMU port i + 1, the PORT_ID an event
  // select names (pmu_port_wrap): the cores' EVUs (ports 1..NumCVA6), the SPUs on the cores' CCU ports
  // (NumCVA6+1..2*NumCVA6, cva6_synth_wrap), the SPU on the LLC memory port (2*NumCVA6+1, host_domain) and the SPU on
  // the accelerator socket's DMA (2*NumCVA6+2, cva6_subsystem): ports 1-4, 5-8, 9 and 10 with four cores, 1-8, 9-16,
  // 17 and 18 with eight. The highest port must fit pmu_pkg::PORT_ID_BITS (checked in host_domain and pmu_top): the
  // 4 bits of up to four cores name ports 1-15, the 5 bits of more cores ports 1-31 (up to 14 cores).
  localparam int unsigned ApmuEvuIdx      = 0;
  localparam int unsigned ApmuCoreSpuIdx  = NumCVA6;
  localparam int unsigned ApmuMemSpuIdx   = 2 * NumCVA6;
  localparam int unsigned ApmuAccelSpuIdx = 2 * NumCVA6 + 1;
  localparam int unsigned ApmuNumPorts    = 2 * NumCVA6 + 2;

  // ---- The cores' EVU configuration registers (cva6_synth_wrap, i_axi_lite_perfc): core c's at PerfcEvuBase +
  // PerfcEvuBytesPerCore * c, four 4-byte EventID registers, then four 8-byte PC_TRACK registers. The CPUs reach them
  // through the AXI-lite crossbar (axi_lite_subsystem) and the APMU's processing element as its system memory
  // (host_domain, pmu_top MEMORY_BASE_ADDR / MEMORY_LENGTH), both through one window of PerfcEvuLength bytes: every
  // core's registers rounded up to a power of two, at least 0x100. 0x100 with four cores (0xC0 of registers), 0x200
  // with eight (0x180; cva6_synth_wrap checks that the window covers its registers).
  localparam logic [31:0] PerfcEvuBase         = 32'h1060_6000;
  localparam int unsigned PerfcEvuBytesPerCore = 4 * ariane_pkg::NumPerfEvents + 8 * ariane_pkg::NumPCMilesRegs;
  localparam int unsigned PerfcEvuLength       = (NumCVA6 * PerfcEvuBytesPerCore <= 32'h100) ? 32'h100
                                                 : 2**$clog2(NumCVA6 * PerfcEvuBytesPerCore);

  /// Number of synchronization registers to insert on the async pointers
  localparam CdcSyncStages   = 3;

  // Ensure that SocToClusterIdWidth + $clog2(ClusterNrSlaves) = IdWidth
  localparam SocToClusterIdWidth = 3;

  //DebugModule ID
  localparam logic [31:0] DbgIdCode= 32'h20001001;

  typedef enum int unsigned {
    HYAXI       = 19,
    PMUS_IOPMP  = 18,
    Snooper     = 17,
    AXILiteDom  = 16,
    IOPMP_CFG   = 15,
    MDMA_CFG    = 14,
    IOMMU_CFG   = 13,
    SDMA_CFG    = 12,
    UART        = 11,
    Ethernet    = 10,
    IMSIC       = 9,
    SPI         = 8,
    Timer       = 7,
    APB_SLVS    = 6,
    L2SPM       = 5,
    Cluster_Slv = 4,
    PLIC        = 3,
    CLINT       = 2,
    ROM         = 1,
    Debug_Slv   = 0
  } axi_slaves_t;

  localparam NB_PERIPHERALS = HYAXI + 1;

  `ifdef HYPER_FPGA_DDR
  localparam HyperbusNumPhys          = 2;
  localparam NumChipsPerHyperbus      = 2;
  `else
  localparam HyperbusNumPhys          = 2;
  localparam NumChipsPerHyperbus      = 4;
  `endif
  localparam logic[63:0] HyperRamSize = 64'h4000000; // 64MB


  localparam logic[63:0] DebugLength    = 64'h1000;
  localparam logic[63:0] ROMLength      = 64'h10000;
  localparam logic[63:0] UARTLength     = 64'h1000;
  localparam logic[63:0] SDMALength     = 64'h1000;  
  localparam logic[63:0] IOMMULength    = 64'h1000;
  localparam logic[63:0] MDMALength     = 64'h1000;  
  localparam logic[63:0] IOPMPLength    = 64'h4000;
  localparam logic[63:0] AXILiteLength  = 64'h300000; // Same on cluster side
  localparam logic[63:0] CLINTLength    = 64'hC0000;
  localparam logic[63:0] PLICLength     = 64'h3FF_FFFF;
  localparam logic[63:0] ClusterLength  = 64'h400000;
  localparam logic[63:0] TimerLength    = 64'h1000;
  localparam logic[63:0] SPILength      = 64'h800000;
  localparam logic[63:0] IMSICLength    = 64'h800_0000;
  localparam logic[63:0] EthernetLength = 64'h10_0000;   // Xilinx AXI Ethernet (256 KB) + AXI DMA at +0x4_0000
  `ifdef HYPER_FPGA_DDR
  localparam logic[63:0] HYAXILength    = 64'h2000000;  //32MB of hyperrams
  `else
  localparam logic[63:0] HYAXILength    = 64'h20000000;  //HyperRamSize*NumChipsPerHyperbus*HyperbusNumPhys;  // 256MB of hyperrams
  `endif
  localparam logic[63:0] LLCSPMLength   = 64'h20000;     // up to 128KB of LLC that can be used as scratchpad
  localparam logic[63:0] L2SPMLength    = 64'h8000;      // 32KB of scratchpad memory
  localparam logic[63:0] APB_SLVSLength = 64'h132000;
  localparam logic[63:0] SnoopLength    = 64'h4000;
  localparam logic[63:0] IOPMP_PMULength = 64'h4000;

  // Instantiate AXI protocol checkers
  localparam bit GenProtocolChecker = 1'b0;

  typedef enum logic [63:0] {
    DebugBase     = 64'h0000_0000,
    ROMBase       = 64'h0001_0000,
    CLINTBase     = 64'h0200_0000,
    PLICBase      = 64'h0C00_0000,
    ClusterBase   = 64'h1000_0000,
    AXILiteBase   = 64'h1040_0000,
    APB_SLVSBase  = 64'h1A10_0000,
    L2SPMBase     = 64'h1C00_0000,
    TimerBase     = 64'h1800_0000,
    SPIBase       = 64'h2000_0000,
    IMSICBase     = 64'h2400_0000,
    EthernetBase  = 64'h3000_0000,
    UARTBase      = 64'h4000_0000,
    SDMABase      = 64'h5000_0000,
    IOMMUBase     = 64'h5001_0000,
    MDMABase      = 64'h5002_0000,
    IOPMPBase     = 64'h5003_0000,
    IOPMP_PMUBase = 64'h5004_0000,
    LLCSPMBase    = 64'h7000_0000,
    SnoopBase     = 64'h7100_0000,
    HYAXIBase     = 64'h8000_0000
  } soc_bus_start_t;
  // Let x = NB_PERIPHERALS: as long as Base(xth slave)+Length(xth slave) is < 1_0000_0000 we can cut the 32 MSBs addresses without any worries.


  localparam NrRegion = 1;
  localparam logic [NrRegion-1:0][NB_PERIPHERALS-1:0] ValidRule = {{NrRegion * NB_PERIPHERALS}{1'b1}};

  localparam ariane_pkg::ariane_cfg_t ArianeSocCfg = '{
    RASDepth: 2,
    BTBEntries: 32,
    BHTEntries: 128,
    // idempotent region
    NrNonIdempotentRules:  1,
    NonIdempotentAddrBase: {64'b0},
    NonIdempotentLength:   {HYAXIBase},
    NrExecuteRegionRules:  5,
    ExecuteRegionAddrBase: {HYAXIBase, LLCSPMBase, L2SPMBase,   ROMBase,   DebugBase},
    ExecuteRegionLength:   {HYAXILength, LLCSPMLength, L2SPMLength, ROMLength, DebugLength},
    // cached region
    NrCachedRegionRules:    1,
    CachedRegionAddrBase:  {HYAXIBase},
    CachedRegionLength:    {HYAXILength},
    // shared region
    NrSharedRegionRules:    1,
    SharedRegionAddrBase:  {HYAXIBase},
    SharedRegionLength:    {HYAXILength},
    //  cache config
    AxiCompliant:           1'b1,
    SwapEndianess:          1'b0,
     // CLIC
    CLICNumInterruptSrc:    1'b1,
    CLICIntCtlBits:         1,
   // debug
    DmBaseAddress:          DebugBase,
    NrPMPEntries:           8
  };

  // Ethernet
  typedef struct packed {
    logic eth_rxck_i ;
    logic eth_rxctl_i;
    logic eth_rxd0_i ;
    logic eth_rxd1_i ;
    logic eth_rxd2_i ;
    logic eth_rxd3_i ;
    logic eth_md_i;
  } pad_to_eth_t;

  typedef struct packed {
    logic eth_rstn_o;
    logic eth_txck_o;
    logic eth_txctl_o;
    logic eth_txd0_o;
    logic eth_txd1_o;
    logic eth_txd2_o;
    logic eth_txd3_o;
    logic eth_mdc_o;
    logic eth_md_o;
    logic eth_md_oe;
  } eth_to_pad_t;

  // Xilinx AXI 1G Ethernet on the VCU118 (SGMII over LVDS to the on-board DP83867, hardware/host/xilinx_eth_subsys.sv)
  localparam logic[63:0] XEthDmaOffset = 64'h4_0000;   // AXI DMA registers inside the Ethernet window
  typedef struct packed {
    logic sgmii_rxp;
    logic sgmii_rxn;
    logic lvds_clk_p;   // 625 MHz from the PHY
    logic lvds_clk_n;
    logic mdio_i;
  } pad_to_xeth_t;

  typedef struct packed {
    logic sgmii_txp;
    logic sgmii_txn;
    logic mdc;
    logic mdio_o;
    logic mdio_t;       // 1 = input (release the line)
    logic phy_rst_n;
  } xeth_to_pad_t;

  typedef struct packed {
    logic clk_soc_o;
    logic clk_cva6_o;
  } fll_to_pad_t;

  // AXI LLC
  // Cache size = 8 x 128 x 8 x 8 = 8kB.
  // Each core partition is 2kB.
  // LLC Cache Size = 256 x 8 x 8 = 128 KiB
  // LLC Cache Size = 128 x 8 x 8 = 64 KiB
  // LLC Cache Size = 64 x 8 x 8 = 32 KiB
  // localparam LLC_SET_ASSOC  = 32'd8;
  // localparam LLC_NUM_LINES  = 32'd64;
  // localparam LLC_NUM_BLOCKS = 32'd8;

  // LLC Cache Size = 1024 x 16 x 8 = 1MiB
  localparam LLC_SET_ASSOC  = 32'd16;
  localparam LLC_NUM_LINES  = 32'd1024;
  localparam LLC_NUM_BLOCKS = 32'd8;


endpackage
