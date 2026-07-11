# ==============================================================================
# Standalone Questa simulation for the slowdown IP (unit-level, self-contained).
#
#   make            # compile + run the testbench, batch
#   make gui        # compile + run in the Questa GUI
#   make compile    # compile only
#   make clean
#
# Self-contained: the sim_deps/ stubs (axi_pkg, axi_intf, ariane_soc/axi_soc
# packages) let the DUT compile with plain vlog — no Bender / platform deps.
# The DUT is the *he-soc* slowdown source under ../src (the version we debug),
# so its in-RTL checker (pragma translate_off) also runs here because this flow
# does NOT pass vopt -check_synthesis.
# ==============================================================================

VLIB ?= vlib
VLOG ?= vlog
VSIM ?= vsim
LIB  := work
TOP  := tb_slowdown

# Compile order matters: axi_pkg -> axi_intf -> ariane_soc_stub -> ariane_axi_soc
SIM_DEPS := \
    sim_deps/axi_pkg.sv \
    sim_deps/axi_intf.sv \
    sim_deps/ariane_soc_stub_pkg.sv \
    sim_deps/ariane_axi_soc_pkg.sv

# DUT = he-soc slowdown source (the version under debug)
DUT_SRC := \
    ../src/fifo_sync.sv \
    ../src/countdown_timer.sv \
    ../src/data_write_fifo.sv \
    ../src/throughput_regulator.sv \
    ../src/latency_r_chan.sv \
    ../src/latency_b_chan.sv \
    ../src/slowdown_mem_top.sv

TB := tb_slowdown.sv

VLOG_FLAGS := -sv -work $(LIB) -suppress 2583 -suppress 13314 -suppress 2275

.PHONY: all compile sim gui clean

all: sim

compile:
	@rm -rf $(LIB)
	$(VLIB) $(LIB)
	$(VLOG) $(VLOG_FLAGS) $(SIM_DEPS) $(DUT_SRC) $(TB)

sim: compile
	$(VSIM) -c -work $(LIB) $(TOP) -do "run -all; quit -f" | tee sim.log

gui: compile
	$(VSIM) -work $(LIB) $(TOP) -do "add wave -r /*; run -all" &

clean:
	rm -rf $(LIB) transcript vsim.wlf sim.log modelsim.ini *.vstf
