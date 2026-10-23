# hardware/ip_list/opendram/opendram.tcl -- sourced by hardware/fpga/run.tcl when OPENDRAM=1.
#
# Puts OpenDRAM in place of the DDR4 MIG's own memory controller (README.md here).
# Instead of reading the prebuilt alsaqr/tcl/ips/ddr/ip/ddr4_0.xci, it:
#   1. creates the DDR4 MIG in the project with the settings of alsaqr/tcl/ips/ddr/run.tcl,
#      except AUTO_AP_COL_A3, which must stay off: OpenDRAM's page table follows the PRE and
#      ACT commands it issues itself, and a CAS with auto-precharge would close a bank behind
#      its back;
#   2. generates it with no out-of-context synthesis, so its RTL is synthesized with the top,
#      where the include path set in step 4 applies, and locks it, so that Vivado cannot
#      regenerate the files patched in step 3;
#   3. applies patches/*.patch to two of the generated files, with no fuzz (a patch that does
#      not fit exactly stops the build);
#   4. puts OpenDRAM's sources (rtl/) on the include path: they reach synthesis only through
#      the `include in the patched ddr4_0_ddr4_mem_intfc.sv, not as design sources.

set od_dir [file normalize [file dirname [info script]]]
set od_mig_rev ddr4_v2_2_24
puts "OPENDRAM: creating the DDR4 MIG for OpenDRAM ($od_dir)"

create_ip -name ddr4 -vendor xilinx.com -library ip -version 2.2 -module_name ddr4_0
set_property -dict [list CONFIG.C0.DDR4_TimePeriod {1600} \
                        CONFIG.C0.DDR4_InputClockPeriod {4000} \
                        CONFIG.C0.DDR4_Specify_MandD {false} \
                        CONFIG.C0.DDR4_CLKOUT0_DIVIDE {8} \
                        CONFIG.C0.DDR4_MemoryPart {MT40A256M16GE-083E} \
                        CONFIG.C0.DDR4_DataWidth {16} \
                        CONFIG.C0.DDR4_AxiSelection {true} \
                        CONFIG.C0.DDR4_AUTO_AP_COL_A3 {false} \
                        CONFIG.C0.DDR4_CasLatency {9} CONFIG.C0.DDR4_CasWriteLatency {9} \
                        CONFIG.C0.DDR4_AxiDataWidth {64} CONFIG.C0.DDR4_AxiAddressWidth {29} \
                        CONFIG.C0.DDR4_AxiIDWidth "$::env(AXI_ID_DDR_WIDTH)" \
                        CONFIG.C0.BANK_GROUP_WIDTH {1} \
                        CONFIG.System_Clock {No_Buffer} ] [get_ips ddr4_0]
set_property generate_synth_checkpoint false [get_files ddr4_0.xci]
generate_target all [get_files ddr4_0.xci]

# Lock before patching: in Vivado 2024.2 the lock moves the IP's outputs from <proj>.gen to
# <proj>.srcs (IP_Flow 19-8015), so every path below is taken after it.
set_property IS_LOCKED true [get_files ddr4_0.xci]
set od_ip_out ""
foreach od_cand [list [get_property IP_OUTPUT_DIR [get_ips ddr4_0]] \
                      [file dirname [get_property NAME [get_files ddr4_0.xci]]]] {
    if {[file exists $od_cand/rtl/controller/ddr4_v2_2_mc_ctl.sv]} {
        set od_ip_out $od_cand
        break
    }
}
if {$od_ip_out eq ""} {
    error "OPENDRAM: cannot find the locked MIG's rtl/controller/ddr4_v2_2_mc_ctl.sv"
}
puts "OPENDRAM: MIG files in $od_ip_out"

# The patches fit the MIG that Vivado 2024.2 generates (module prefix ddr4_v2_2_24_).
set od_f [open $od_ip_out/rtl/controller/ddr4_v2_2_mc_ctl.sv]
set od_txt [read $od_f]
close $od_f
if {![regexp -line "^module ${od_mig_rev}_mc_ctl\\M" $od_txt]} {
    error "OPENDRAM: the generated MIG is not $od_mig_rev; hardware/ip_list/opendram/patches/ fits Vivado 2024.2's MIG only"
}

foreach {od_name od_sub} {ddr4_0_ddr4_mem_intfc ip_top ddr4_v2_2_mc_ctl controller} {
    set od_target $od_ip_out/rtl/$od_sub/$od_name.sv
    if {![file exists $od_target]} {
        error "OPENDRAM: Vivado did not generate $od_target"
    }
    if {[catch {exec patch -s -F0 --no-backup-if-mismatch -r - -o $od_target.opendram_tmp \
                    $od_target $od_dir/patches/$od_name.patch} od_msg]} {
        file delete -force $od_target.opendram_tmp
        error "OPENDRAM: patches/$od_name.patch does not apply to the generated $od_name.sv: $od_msg"
    }
    file attributes $od_target.opendram_tmp -permissions [file attributes $od_target -permissions]
    file rename -force $od_target.opendram_tmp $od_target
    puts "OPENDRAM: applied patches/$od_name.patch"
}

# The ddr4_0_ddr4_mem_intfc.sv that synthesis will read must be the patched one.
set od_used [get_files -quiet -all -of_objects [get_files ddr4_0.xci] *ddr4_0_ddr4_mem_intfc.sv]
if {[llength $od_used] != 1} {
    error "OPENDRAM: expected one ddr4_0_ddr4_mem_intfc.sv in the MIG's files, found: $od_used"
}
set od_f [open [lindex $od_used 0]]
set od_txt [read $od_f]
close $od_f
if {![regexp -line {^`include "opendram_mc\.sv"} $od_txt]} {
    error "OPENDRAM: [lindex $od_used 0] is not the patched file"
}

# OpenDRAM's directories first; the MIG's controller and cal directories for the MIG files
# that opendram_mc.sv and the patched ddr4_v2_2_mc_ctl.sv `include.
set_property include_dirs [concat [list $od_dir/rtl \
                                        $od_dir/rtl/request_scheduler \
                                        $od_dir/rtl/command_queue \
                                        $od_dir/rtl/command_scheduler \
                                        $od_dir/rtl/page_table \
                                        $od_ip_out/rtl/controller \
                                        $od_ip_out/rtl/cal] \
                              [get_property include_dirs [current_fileset]]] [current_fileset]
puts "OPENDRAM: MIG patched and locked; OpenDRAM on the include path"
