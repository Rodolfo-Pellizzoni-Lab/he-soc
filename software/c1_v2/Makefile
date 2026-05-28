APP  := pmu_evu_c1_track
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
export HW_HOME ?= $(realpath $(SW_HOME)/../hardware)
include $(shell pwd)/../common.mk

# ==============================================================================
# Build — no PMU firmware needed; pure CVA6 test
# ==============================================================================
.PHONY: build
build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		$(APP).c \
		$(SRC) \
		-o $(APP).riscv

# ==============================================================================
# all: build + copy SLM/ELF to hardware/
# ==============================================================================
.PHONY: all
all: build
	$(SW_HOME)/elf_to_slm.py --binary=$(APP).riscv --vectors=hyperram0.slm
	cp hyperram*.slm $(HW_HOME)/
	cp $(APP).riscv  $(HW_HOME)/

.PHONY: clean
clean:
	rm -f $(APP).riscv *.slm
