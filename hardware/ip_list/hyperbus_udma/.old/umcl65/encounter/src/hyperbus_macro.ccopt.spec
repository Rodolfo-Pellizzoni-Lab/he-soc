delete_ccopt_clock_tree_spec

#-----------------------------------------------------------------------------------------
# CCOpt Clock Tree Config based on EDI ckSpec
# generated on Tue, Jun 09, 2015 02:29:17 pm CEST
# by Native Mode version 036
#-----------------------------------------------------------------------------------------
if { [dbGet head.routeTypes.name default_route_type_leaf] != "default_route_type_leaf" } {
create_route_type -name default_route_type_leaf -bottom_preferred_layer 1 -top_preferred_layer 4 
}
if { [dbGet head.routeTypes.name default_route_type_nonleaf] != "default_route_type_nonleaf" } {
create_route_type -name default_route_type_nonleaf -bottom_preferred_layer 2 -top_preferred_layer 6
}


# global constraints
#-----------------------------------------------------------------------------------------
# Add that the pads are transparent.
#set_ccopt_property extract_through_to pad_frame_pulp_i/padinst_clk0/Y -pin pad_frame_pulp_i/padinst_clk0/PAD

# buffer/inverter/clock_gating cells
set_ccopt_property buffer_cells [ list CKBUFM3W CKBUFM4W CKBUFM6W CKBUFM8W CKBUFM12W CKBUFM16W CKBUFM20W CKBUFM22WA CKBUFM24W CKBUFM26WA CKBUFM32W CKBUFM40W CKBUFM48W]
set_ccopt_property inverter_cells [ list CKINVM3W CKINVM4W CKINVM6W CKINVM8W CKINVM12W CKINVM16W CKINVM20W CKINVM22WA CKINVM24W CKINVM26WA CKINVM32W CKINVM40W CKINVM48W]
set_ccopt_property clock_gating_cells [ list LAGCESM2WA LAGCESM4WA LAGCESM6WA LAGCESM8WA LAGCESM12WA LAGCESM16WA LAGCESM24WA LAGCESM32WA LAGCESM40WA LAGCESM48WA ]

#                                             LAGCECSM2WA LAGCECSM4WA LAGCECSM6WA LAGCECSM8WA LAGCECSM12WA LAGCECSM16WA LAGCECSM24WA LAGCECSM32WA LAGCECSM40WA LAGCECSM48WA \
#                                             LAGCEM2W LAGCEM3W LAGCEM4W LAGCEM6W LAGCEM8W LAGCEM12W LAGCEM16W LAGCEM20W \
#                                             LAGCEPM2W LAGCEPM3W LAGCEPM4W LAGCEPM6W LAGCEPM8W LAGCEPM12W LAGCEPM16W LAGCEPM20W \
#                                             LAGCEPOM2W LAGCEPOM3W LAGCEPOM4W LAGCEPOM6W LAGCEPOM8W LAGCEPOM12W LAGCEPOM16W LAGCEPOM20W \
#                                             LAGCESOM2W LAGCESOM3W LAGCESOM4W LAGCESOM6W LAGCESOM8W LAGCESOM12W LAGCESOM16W LAGCESOM20W \
#                                             CKAN2M2W CKAN2M4W CKAN2M6WA CKAN2M8W CKAN2M12W CKAN2M16WA CKXOR2M1WA CKXOR2M2WA CKXOR2M4WA CKXOR2M8WA CKXOR2M12WA

#get ignore and case_analysis pin information from create_ccopt_clock_tree_spec -views func_view
#set_ccopt_property sink_type -pin Clk_CO ignore

#get ignore and case_analysis pin information from create_ccopt_clock_tree_spec -views func_view
#create_ccopt_clock_tree_spec -views func_tc

# from local ThroughPin constraints (locality only effects skew groups not clock trees)
# and from any local Unsync/Excluded/LeafPin constraints which no other clock passes through
# and so are on the boundary of the clock network
#set_ccopt_property sink_type -pin XXXX stop


set oddr_cells [list \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_0__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_1__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_2__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_3__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_4__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_5__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_6__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_out_bus_7__ddr_data/ddrmux/clk_mux_i/S \
    i_deflate/i_hyperbus/phy_i/ddr_data_strb/ddrmux/U1/S \
]
foreach cell $oddr_cells {
    set_ccopt_property sink_type -pin $cell stop
}

set_ccopt_property sink_type -pin i_deflate/pad_hyper_ck_o/DO stop
set_ccopt_property sink_type -pin i_deflate/pad_hyper_ck_no/DO stop


# MacroModel constraints
#-----------------------------------------------------------------------------------------
# If the offset at a macro clock pin is big it can be fixed by adding the insertion_delay to it.
# This can help to fix hold violations to the macro without opt must add delis to the input signals.

#set_ccopt_property -pin mem1/CK insertion_delay 0.6
#set_ccopt_property -pin mem1/CK insertion_delay 0.6


# clock tree definitions
#-----------------------------------------------------------------------------------------

# In EDI when two AutoCTSRootPins trace over a common sub-tree the AutoCTSRootPin which appears
# first in the spec file owns the sub-tree for the purposes of DRV/NDR (maxTrans, non-default rules, etc.)
# In CCOpt define_clock_tree is greedy and steels common sub-trees from previously defined clock_tees.
# Also, in CCOpt clock_trees are global and cannot overlap - i.e. they determine only what is in or out
# of the clock network and what DRV/NDRs to apply to different bits of the clock network.
# CCOpt has a separate skew_group construct for defining balancing constraints, and these can overlap.

# There are two side effects of these differences in behavior between EDI and CCOpt:

#  1. We need to reverse the order of define_clock_tree definitions compared to AutoCTSRootPin definitions.

#  2. We need to handle the case where there are dis-continous AutoCTSRootPins, e.g. where
#     the first AutoCTSRootPin to reach a clock mux input has that input as a local UnsyncPin,
#     but another AutoCTSRootPin defined later in the spec file reaches the same mux input and
#     doesn't have a local UnsyncPin. In these situations we need to explicitly define a generated
#     clock_tree on the mux output and explicitly copy over the DRV/NDR settings from the first
#     AutoCTSRootPin to it.

create_ccopt_clock_tree -name clk_sys     -source clk_sys_i
create_ccopt_clock_tree -name clk_phy     -source clk_phy_i
create_ccopt_clock_tree -name clk_rwds    -source hyper_rwds_io -no_skew_group
# promote any clock trees whose source is within one combinational arc of
# another clock tree sink to generated clock trees

create_ccopt_generated_clock_tree \
    -generated_by [get_pins i_deflate/i_hyperbus/ddr_clk/r_clk0_o_reg/CK] \
    -name clk0 \
    -parents clk_phy \
    -source i_deflate/i_hyperbus/ddr_clk/r_clk0_o_reg/Q

create_ccopt_generated_clock_tree \
    -generated_by [get_pins i_deflate/i_hyperbus/ddr_clk/r_clk90_o_reg/CKB] \
    -name clk90 \
    -parents clk_phy \
    -source i_deflate/i_hyperbus/ddr_clk/r_clk90_o_reg/Q

# skew group modification based on local constraints
#-----------------------------------------------------------------------------------------
#create_ccopt_skew_group -name SG_clk01 -balance_skew_groups {clk1 clk0}
#create_ccopt_skew_group -name ddr_in -sources hyper_rwds_io -exclusive_sinks [get_pins -hierarchical ddr_*_reg/CK*]
#create_ccopt_skew_group -name ddr_in -sources hyper_rwds_io -exclusive_sinks ddr_*_reg/CKB
#create_ccopt_skew_group -name ddr_out -sources clk0 -exclusive_sinks [concat [get_pins i_deflate/i_hyperbus/phy_i/ddr_out_bus_?__ddr_data/q?_reg/CK] [get_pins i_deflate/i_hyperbus/phy_i/ddr_out_bus_?__ddr_data/ddrmux/clk_mux_i/S]]

create_ccopt_skew_group -name hyper_ck -sources i_deflate/i_hyperbus/ddr_clk/r_clk90_o_reg/Q -exclusive_sinks {i_deflate/pad_hyper_ck_o/DO i_deflate/pad_hyper_ck_no/DO}

# skew group skew and ID targets
#-----------------------------------------------------------------------------------------
set_ccopt_property target_skew -skew_group hyper_ck 50ps -delay_corner *
set_ccopt_property  target_insertion_delay -skew_group hyper_ck 1250ps

#worst case values
set target_delays [list \
    2200ps \
    2500ps \
    3000ps \
    3600ps \
    4200ps \
    5000ps \
    6000ps \
    8000ps \
]

set pins [list \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_0/A \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_0/B \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_1/A \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_1/B \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_2/A \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_2/B \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_3/A \
    i_deflate/i_hyperbus/phy_i/i_read_clk_rwds/hyperbus_delay_line_i/i_clk_mux_l2_3/B \
]
for {set i 0} {$i < 8} {incr i} {
    create_ccopt_skew_group -name clk_rwds/del$i -sources hyper_rwds_io -auto_sinks

    for {set j 0} {$j < 8} {incr j} {
        if {$j != $i} {
            modify_ccopt_skew_group -skew_group clk_rwds/del$i -add_ignore_pins [lindex $pins $j]
        }
    }

    set_ccopt_property  target_insertion_delay -skew_group clk_rwds/del$i [lindex $target_delays $i]
}

# DRV/NDR constraints for clock trees
#-----------------------------------------------------------------------------------------

#set_clock_latency [expr 1.5 + 0.4 ] hyper_rwds_io



set_ccopt_property  target_max_trans -net_type top   -clock_tree * 500ps
set_ccopt_property  target_max_trans -net_type trunk -clock_tree * 350ps
set_ccopt_property  target_max_trans -net_type leaf  -clock_tree * 250ps

#set_ccopt_property  route_type -net_type trunk -clock_tree * default_route_type_nonleaf
#set_ccopt_property  route_type -net_type top   -clock_tree * default_route_type_nonleaf
#set_ccopt_property  route_type -net_type leaf  -clock_tree * default_route_type_leaf

#set_ccopt_property source_input_max_trans 500.0ps
set_ccopt_property source_max_capacitance 30pf
  # **WARN: (IMPCCOPT-1033):        Did not meet the max_capacitance constraint of 0.000pF below the root driver for clock_tree clk at (600.000,1196.120), in power domain PD_core. Achieved capacitance of 22.688pF.
  # **WARN: (IMPCCOPT-1023):        Did not meet the skew target of 0.100ns for skew group clk in half corner worst_delay:setup.late. Achieved skew of 0.103ns.


# ClockGroup constraints
#-----------------------------------------------------------------------------------------


# LeafPinGroup constraints
#-----------------------------------------------------------------------------------------


# DynamicMacroModel constraints
#-----------------------------------------------------------------------------------------


# Preserve* and DontTouchNet constraints
#-----------------------------------------------------------------------------------------


# CellHalo constraints for clock trees
#-----------------------------------------------------------------------------------------


# maxfanout constraints for clock trees
#-----------------------------------------------------------------------------------------

# opt constraints
#-----------------------------------------------------------------------------------------
# turn off the merge of clock gates.
# The merge can create problems in the LVS hierarchy there is often a empty hierarhcy instance left.
set_ccopt_property ccopt_merge_clock_gates false
set_ccopt_property cts_merge_clock_gates false

# turn off move_clock_gates" "move_logic" to improve timing
set_ccopt_property move_clock_gates false
set_ccopt_property move_logic false
