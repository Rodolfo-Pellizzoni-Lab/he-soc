GIT ?= git
BENDER ?= bender
VSIM ?= vsim

all: sim_all synth_all

clean: sim_clean

# Ensure half-built targets are purged
.DELETE_ON_ERROR:

# --------------
# RTL SIMULATION
# --------------

REG_PATH ?= $(shell $(BENDER) path register_interface)

VLOG_ARGS += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale \"1 ns / 1 ps\"
XVLOG_ARGS += -64bit -compile -vtimescale 1ns/1ns -quiet

define generate_vsim
	echo 'set ROOT [file normalize [file dirname [info script]]/$3]' > $1
	bender script $(VSIM) -t rtl -t test -t test_tb --vlog-arg="$(VLOG_ARGS)" $2 | grep -v "set ROOT" >> $1
	echo >> $1
endef

gen_regs:
	$(REG_PATH)/vendor/lowrisc_opentitan/util/regtool.py -r reg-pads.hjson --outdir ./src

sim_all: scripts/compile.tcl
sim_all: models/generic_delay_D4_O1_3P750_CG0.behav.sv

sim_clean:
	rm -rf scripts/compile.tcl
	rm -rf work

scripts/compile.tcl: Bender.yml
	$(call generate_vsim, $@, -t rtl -t test,..)

compile: scripts/compile.tcl
	vsim -c -do "source scripts/compile.tcl"
# --------------
# SYNTHESIS
# --------------

define generate_synopsys
	echo 'set ROOT [file normalize [file dirname [info script]]/../../..]' > $1
	bender script synopsys $2 | grep -v "set ROOT" >> $1
	echo >> $1
endef

synth_tsmc65: tsmc65/synopsys/scripts/analyze.tcl
synth_tsmc65: models/generic_delay_D4_O1_3P750_CG0_mid.db

tsmc65/cockpit.log:
	cd tsmc65 && icdesign tsmc65 -update all -nogui

tsmc65/synopsys/scripts/analyze.tcl: Bender.yml | tsmc65/cockpit.log
	$(call generate_synopsys, $@, -t rtl -t default -t synthesis -t tsmc65,..)

synth_gf22: gf22/synopsys/scripts/analyze.tcl

gf22/cockpit.log:
	cd gf22 && icdesign gf22 -update all -nogui

gf22/synopsys/scripts/analyze.tcl: Bender.yml | gf22/cockpit.log
	$(call generate_synopsys, $@, -t rtl -t default -t asic -t gf22,..)

post_synth_compile:
	echo 'set ROOT [file normalize [file dirname [info script]]/../]' > scripts/post_synth_compile.tcl
	bender script $(VSIM) --vlog-arg="-work gate" -t post_synth_sim -t test | grep -v "set ROOT" >> scripts/post_synth_compile.tcl

# --------------
# GENERIC-DELAY
# --------------

BUILD_DIR ?= /dev/shm/hyper

DELAY_REMOTE ?= git@iis-git.ee.ethz.ch:bslk/generic-delay.git
DELAY_TAG ?= master

DELAY_REPO ?= $(BUILD_DIR)/generic-delay
DELAY_OUTDIR ?= $(BUILD_DIR)/generic-delay-build
DELAY_TECH ?= tsmc65
export

-include $(DELAY_REPO)/delay.mk

DELAY_FILEPATHS ?= \
	models/generic_delay_D4_O1_3P750_CG0.behav.sv \
	models/generic_delay_D4_O1_3P750_CG0_mid.db

.PHONY: delay_clean

delay_clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(DELAY_OUTDIR)
	rm -rf $(DELAY_FILEPATHS)

$(DELAY_REPO)/delay.mk:
	mkdir -p $(BUILD_DIR)
	rm -rf $(DELAY_REPO)
	$(GIT) clone $(DELAY_REMOTE) $(DELAY_REPO) && cd $(DELAY_REPO) && $(GIT) checkout $(DELAY_TAG)

.SECONDEXPANSION:
$(DELAY_FILEPATHS): $$(DELAY_OUTDIR)/$$(notdir $$@)
	mkdir -p $(dir $@)
	cp $< $@
