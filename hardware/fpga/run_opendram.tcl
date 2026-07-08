# run_opendram.tcl — AlSaqr Vivado project with OpenDRAM v5 integration.
#
# Derived from run.tcl.  Key differences from the standard DDR4 flow:
#   - Does NOT read the pre-built ddr4_0.xci
#   - Creates the DDR4 MIG IP inline with the same parameters as ddr/run.tcl
#   - Sets generate_synth_checkpoint=false BEFORE generate_target all so no
#     OOC synthesis run is created; the IP RTL compiles in the top-level
#     synthesis context where project include_dirs are visible
#   - Overwrites ddr4_0_ddr4_mem_intfc.sv with the OpenDRAM v5 version
#     (instantiates opendram_mc instead of Xilinx ddr4_v2_2_14_mc)
#   - Overwrites ddr4_v2_2_mc_ctl.sv with the OpenDRAM v5 patched version
#     (exposes casSlot2/winRead/winWrite scheduling ports to opendram_mc)
#   - Sets include_dirs so opendram_mc.sv and all its `include chain resolve
#
# Run via gen_alsaqr_opendram.sh — do not invoke directly.

set outputDir reports
file mkdir $outputDir
set boardName  $::env(XILINX_BOARD)

create_project alsaqr $::env(PROJECT_HOME) -part $::env(XILINX_PART) -force
set_property board_part $boardName [current_project]

source ./alsaqr/tcl/generated/compile.tcl
set_property top alsaqr_xilinx [current_fileset]

# ---- Pre-built IPs (ddr4 is created inline below) ----
read_ip ./alsaqr/tcl/ips/boot_rom/ip/xilinx_rom_bank_1024x64.xci
read_ip ./alsaqr/tcl/ips/clk_mngr/ip/xilinx_clk_mngr.xci
# NOTE: ddr4_0.xci is intentionally skipped — DDR4 IP is created inline below.
read_ip ./alsaqr/tcl/ips/qspi/ip/xilinx_qspi.xci
read_ip ./alsaqr/tcl/ips/rom_ot/ip/xilinx_rom_bank_8192x40.xci
read_ip ./alsaqr/tcl/ips/otp_ot/ip/xilinx_rom_bank_1024x22.xci

# ---- Report SoC clock frequency + hardcoded UART baud ----
# Mirror clk_mngr/run.tcl so the value printed here == the clock clk_mngr built.
if {$::env(MAIN_MEM)=="HYPER"} {
    set SOC_FREQ_MHZ 10
} elseif {$::env(MAIN_MEM)=="DDR4"} {
    if {$::env(NUM_CORES)==4} {
        set SOC_FREQ_MHZ 20
    } elseif {$::env(USE_OT)=="1"} {
        set SOC_FREQ_MHZ 25
    } else {
        set SOC_FREQ_MHZ 40
    }
}
# apb_uart hardcodes iDLL=0x20 -> divisor 32; baud = f / (32*16) = f / 512
set UART_BAUD [expr {int($SOC_FREQ_MHZ*1000000/512)}]
puts "################################################################"
puts "# SoC clock (clk_mngr CLKOUT1) = $SOC_FREQ_MHZ MHz"
puts "# UART: apb_uart hardcoded iDLL=0x20 (div 32) -> ~$UART_BAUD baud (target 38400)"
puts "################################################################"
# Cross-check against the actually-built clk_mngr IP (loud warning on mismatch).
if {![catch {set ip_freq [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ [get_ips xilinx_clk_mngr]]}]} {
    puts "INFO: clk_mngr XCI CLKOUT1_REQUESTED_OUT_FREQ = $ip_freq MHz"
    if {$ip_freq != $SOC_FREQ_MHZ} {
        puts "CRITICAL WARNING: built clk_mngr freq ($ip_freq MHz) != expected ($SOC_FREQ_MHZ MHz) -- UART baud will be wrong!"
    }
}

# ---- Constraints (identical to run.tcl) ----
add_files -fileset constrs_1 -norecurse "alsaqr/tcl/fmc_board_$::env(BOARD).xdc"
if {$::env(MAIN_MEM)=="HYPER"} {
    set SRC_CLK_PERIOD 100
} elseif {$::env(MAIN_MEM)=="DDR4"} {
    if {$::env(NUM_CORES)==4} {
        set SRC_CLK_PERIOD 50
    } elseif {$::env(USE_OT)=="1"} {
        set SRC_CLK_PERIOD 40
    } else {
        set SRC_CLK_PERIOD 25
    }
}
if {$::env(MAIN_MEM)=="HYPER"} {
    add_files -fileset constrs_1 -norecurse "alsaqr/tcl/fmc_board_hyper_$::env(BOARD).xdc"
} elseif {$::env(MAIN_MEM)=="DDR4"} {
    add_files -fileset constrs_1 -norecurse "alsaqr/tcl/ddr_$::env(BOARD).xdc"
    add_files -fileset constrs_1 -norecurse "alsaqr/tcl/fmc_board_validation_$::env(BOARD).xdc"
    if {$::env(USE_OT)=="1"} {
        add_files -fileset constrs_1 -norecurse "alsaqr/tcl/fmc_board_opentitan_$::env(BOARD).xdc"
    }
    if {[info exists ::env(ETH2FMC_NO_PAD)] && $::env(ETH2FMC_NO_PAD)=="1"} {
        add_files -fileset constrs_1 -norecurse \
            "alsaqr/tcl/fmc_board_validation_$::env(BOARD)_eth-no_padframe.xdc"
    }
}

# ================================================================
# OpenDRAM v5 Integration
# ================================================================

puts "INFO: Creating DDR4 MIG IP inline for OpenDRAM integration..."

create_ip -name ddr4 -vendor xilinx.com -library ip -version 2.2 \
    -module_name ddr4_0

set_property -dict [list \
    CONFIG.C0.DDR4_TimePeriod        {1600}                        \
    CONFIG.C0.DDR4_InputClockPeriod  {4000}                        \
    CONFIG.C0.DDR4_Specify_MandD     {false}                       \
    CONFIG.C0.DDR4_CLKOUT0_DIVIDE    {8}                           \
    CONFIG.C0.DDR4_MemoryPart        {MT40A256M16GE-083E}          \
    CONFIG.C0.DDR4_DataWidth         {16}                          \
    CONFIG.C0.DDR4_AxiSelection      {true}                        \
    CONFIG.C0.DDR4_CasLatency        {9}                           \
    CONFIG.C0.DDR4_CasWriteLatency   {9}                           \
    CONFIG.C0.DDR4_AxiDataWidth      {64}                          \
    CONFIG.C0.DDR4_AxiAddressWidth   {29}                          \
    CONFIG.C0.DDR4_AxiIDWidth        $::env(AXI_ID_DDR_WIDTH)      \
    CONFIG.C0.BANK_GROUP_WIDTH       {1}                           \
    CONFIG.System_Clock              {No_Buffer}                   \
] [get_ips ddr4_0]

# Generate instantiation template so the XCI is registered in the project.
generate_target {instantiation_template} [get_files ddr4_0.xci]
update_compile_order -fileset sources_1

# Disable OOC synthesis checkpoint BEFORE generate_target all.
# With no OOC run, the IP RTL compiles as part of top-level synthesis_1
# where the project include_dirs below are fully visible.
set_property generate_synth_checkpoint false [get_files ddr4_0.xci]

puts "INFO: Generating DDR4 MIG IP artifacts (no OOC checkpoint)..."
generate_target all [get_files ddr4_0.xci]

# Lock the IP file object so Vivado won't reset output products and
# overwrite the patched files we copy below.
set_property IS_LOCKED true [get_files ddr4_0.xci]

set ip_output [get_property IP_OUTPUT_DIR [get_ips ddr4_0]]
puts "INFO: IP output dir = $ip_output"

set opendram_dir [file normalize "../ip_list/opendram"]
set opendram_mod [file normalize "../ip_list/opendram/modified_xilinx"]

# ── Primary replacement: ddr4_0_ddr4_mem_intfc.sv ──────────────────────────
# This file is the entry point for the OpenDRAM include chain.  It does:
#   `include "opendram_mc.sv"   (found via include_dirs → $opendram_dir)
# then instantiates opendram_mc instead of Xilinx ddr4_v2_2_14_mc.
file copy -force $opendram_mod/ddr4_0_ddr4_mem_intfc.sv \
    $ip_output/rtl/ip_top/
puts "INFO: Replaced ddr4_0_ddr4_mem_intfc.sv with OpenDRAM v5 version."

# ── MC control replacement: ddr4_v2_2_mc_ctl.sv ───────────────────────────
# Adds casSlot2/winRead/winWrite scheduling ports consumed by opendram_mc.
# Copied to the IP RTL dir so it replaces the Xilinx original in both the
# include search (via include_dirs order) and the standalone IP compile.
file copy -force $opendram_mod/ddr4_v2_2_mc_ctl.sv \
    $ip_output/rtl/controller/
puts "INFO: Replaced ddr4_v2_2_mc_ctl.sv with OpenDRAM v5 version."

# ── Include directories ────────────────────────────────────────────────────
# The full include resolution chain is:
#
#   ddr4_0_ddr4_mem_intfc.sv  (`include "opendram_mc.sv")
#     → $opendram_dir/opendram_mc.sv          ← found via $opendram_dir
#       `include "./global.svh"               ← resolved relative to opendram_mc.sv dir
#       (USE_RELATIVE_PATH_INCLUDES defined in global.svh)
#       `include "ddr4_v2_2_mc_ctl.sv"        ← $opendram_mod (modified, listed first)
#       `include "ddr4_v2_2_mc_periodic.sv"   ← $ip_output/rtl/controller (original Xilinx)
#       `include "ddr4_v2_2_mc_ref.sv"        ← same
#       `include "ddr4_v2_2_mc_ecc.sv"        ← same
#       `include "./request_scheduler/..."    ← $opendram_dir/request_scheduler (subdir fallback)
#         `include "./request_scheduler_b.sv" ← $opendram_dir/request_scheduler (fallback)
#       `include "./command_queue/..."        ← $opendram_dir/command_queue
#         `include "./command_queue.sv"       ← $opendram_dir/command_queue
#       `include "./page_table/page_table.sv" ← found relative to opendram_mc.sv dir
#       `include "./command_scheduler/..."    ← $opendram_dir/command_scheduler
#         `include "./cs_macros.svh"          ← $opendram_dir/command_scheduler
#         `include "./time_constraints.vh"    ← $opendram_dir/command_scheduler
#
# Sub-module .sv files are NOT added as design sources — they reach synthesis
# exclusively via this include chain, avoiding duplicate module definitions.
# PREPEND OpenDRAM paths to the existing include_dirs — compile.tcl already set
# paths for ace/include, axi/include, etc.  Replacing them would break those IPs.
# $opendram_mod is first so our modified ddr4_v2_2_mc_ctl.sv takes precedence.
set existing_incdirs [get_property include_dirs [current_fileset]]
set_property include_dirs [concat [list \
    $opendram_mod \
    $opendram_dir \
    $opendram_dir/request_scheduler \
    $opendram_dir/command_queue \
    $opendram_dir/command_scheduler \
    $opendram_dir/page_table \
    [file normalize "$ip_output/rtl/controller"] \
] $existing_incdirs] [current_fileset]

puts "INFO: OpenDRAM include dirs prepended to existing [llength $existing_incdirs] dirs."

# ================================================================
# End OpenDRAM Integration
# ================================================================

update_compile_order -fileset sources_1
auto_detect_xpm

# Optional timing constraints file (generated by some flows; skip if absent).
if {[file exists ./timing_constr.xdc]} {
    read_xdc ./timing_constr.xdc
}

if {[info exists ::env(SYNTHESIS)] && $::env(SYNTHESIS) == "true"} {
    launch_runs synth_1 -jobs 64
    wait_on_run synth_1
    open_run synth_1 -name synth_1
    update_compile_order -fileset sources_1
    opt_design
    place_design
    report_clock_utilization -file $outputDir/clock_util.rpt
    write_checkpoint -force $outputDir/post_place.dcp
    report_utilization -file $outputDir/post_place_util.rpt
    report_timing_summary -file $outputDir/post_place_timing_summary.rpt
    route_design
    report_timing_summary -file $outputDir/post_route_preopt_timing_summary.rpt
    if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
        puts "Found setup timing violations => running physical optimization"
        phys_opt_design
        report_timing_summary -file $outputDir/post_route_timing_summary.rpt
    }
    write_checkpoint -force $outputDir/post_route.dcp
    report_route_status -file $outputDir/post_route_status.rpt
    report_timing_summary -file $outputDir/post_route_timing_summary.rpt
    report_power -file $outputDir/post_route_power.rpt
    report_drc -file $outputDir/post_imp_drc.rpt
    write_bitstream -force $outputDir/alsaqr_xilinx.bit
    puts "INFO: Bitstream written to $outputDir/alsaqr_xilinx.bit"
} else {
    puts "INFO: GUI mode — project loaded with OpenDRAM sources. No synthesis launched."
    puts "INFO: Re-run with -synth flag to build the bitstream."
}
