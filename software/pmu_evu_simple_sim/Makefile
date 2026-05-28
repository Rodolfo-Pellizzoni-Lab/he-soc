APP := pmu_simple_bench
XLEN:=64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
export HW_HOME ?= $(realpath $(SW_HOME)/../hardware)
include $(shell pwd)/../common.mk

DUMP     := pmu_simple_bench.dump
ADDRS_H  := auto_func_addrs.h
PYTHON   := python3

# PMU firmware paths (RV32 Ibex core firmware embedded into the CVA6 binary)
PMU_FW_DIR   := pmu_firmware
PMU_BUILD_DIR := $(PMU_FW_DIR)/build
PMU_TEXT_BIN  := $(PMU_BUILD_DIR)/text_section.bin
PMU_DATA_BIN  := $(PMU_BUILD_DIR)/data_rodata_bss.bin

OBJCOPY ?= $(RISCV_PREFIX)objcopy

# ==============================================================================
# PMU Firmware build + embedding
# ==============================================================================

.PHONY: pmu_firmware
pmu_firmware:
	$(MAKE) -C $(PMU_FW_DIR) all generate-bin-files \
		$(if $(FUNC_ENTRY),FUNC_ENTRY=$(FUNC_ENTRY),) \
		$(if $(FUNC_EXIT),FUNC_EXIT=$(FUNC_EXIT),)

pmu_text.o: pmu_firmware
	cp $(PMU_TEXT_BIN) text_section.bin
	$(RISCV_GCC) -c pmu_text_wrapper.S -o $@

pmu_data.o: pmu_firmware
	cp $(PMU_DATA_BIN) data_rodata_bss.bin
	$(RISCV_GCC) -c pmu_data_wrapper.S -o $@

# ==============================================================================
# Simple benchmark: 6 synthetic functions, no FAT/SDVB
# ==============================================================================

# ==============================================================================
# all: transparent two-pass build + SLM copy to hardware/
#      keeps the standard workflow: make -C .../pmu_evu_simple_sim clean all
#                                   make clean sim elf-bin=.../pmu_simple_bench.riscv
# ==============================================================================
.PHONY: all
all: two-pass
	$(SW_HOME)/elf_to_slm.py --binary=$(APP).riscv --vectors=hyperram0.slm
	cp hyperram*.slm $(HW_HOME)/
	cp $(APP).riscv  $(HW_HOME)/

build: pmu_text.o pmu_data.o
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		pmu_simple_bench.c \
		pmu_text.o pmu_data.o \
		$(SRC) \
		-o pmu_simple_bench.riscv

# ==============================================================================
# Two-pass build: extract func_l1_cold addresses, inject into firmware rebuild
# ==============================================================================

# Generate objdump listing from the built binary
$(DUMP): pmu_simple_bench.riscv
	$(RISCV_PREFIX)objdump -d $< > $@

# Parse the dump and write auto_func_addrs.h with correct FUNC_ENTRY/FUNC_EXIT
$(ADDRS_H): $(DUMP)
	$(PYTHON) extract_simple_addrs.py $(DUMP) > $(ADDRS_H)

gen-addrs: $(ADDRS_H)

# Full two-pass flow:
#   Pass 1 — build binary (firmware has placeholder addresses)
#   Extract — objdump pass-1 binary, run extract_simple_addrs.py → auto_func_addrs.h
#   Pass 2 — rebuild firmware with correct addresses, re-link CVA6 binary
#
# ALL address extraction is done with shell $(...) so it executes AFTER the
# python script writes auto_func_addrs.h.  Do NOT use $(eval)/$(shell) here —
# those are Make functions that expand before any shell command runs, so
# auto_func_addrs.h would not exist yet when they execute.
#
# Pass 2 builds firmware and embeds it manually (cp + as) to avoid re-invoking
# the pmu_firmware phony target, which would overwrite the correct firmware
# binary with a no-FUNC_ENTRY rebuild.
two-pass:
	$(MAKE) build
	$(RISCV_PREFIX)objdump -d $(APP).riscv > $(DUMP)
	$(PYTHON) extract_simple_addrs.py $(DUMP) > $(ADDRS_H)
	_E=$$(grep 'define FUNC_ENTRY' $(ADDRS_H) | awk '{print $$3}'); \
	_X=$$(grep 'define FUNC_EXIT'  $(ADDRS_H) | awk '{print $$3}'); \
	$(MAKE) -C $(PMU_FW_DIR) clean all generate-bin-files FUNC_ENTRY=$$_E FUNC_EXIT=$$_X && \
	cp $(PMU_TEXT_BIN) text_section.bin && \
	$(RISCV_GCC) -c pmu_text_wrapper.S -o pmu_text.o && \
	cp $(PMU_DATA_BIN) data_rodata_bss.bin && \
	$(RISCV_GCC) -c pmu_data_wrapper.S -o pmu_data.o && \
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		pmu_simple_bench.c \
		pmu_text.o pmu_data.o \
		$(SRC) \
		-o $(APP).riscv

clean:
	rm -f pmu_simple_bench.riscv $(DUMP) $(ADDRS_H) *.slm
	$(MAKE) -C $(PMU_FW_DIR) clean
	rm -f pmu_text.o pmu_data.o text_section.bin data_rodata_bss.bin
