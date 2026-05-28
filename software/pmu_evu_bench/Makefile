APP := pmu_evu_bench
XLEN:=64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
export HW_HOME ?= $(realpath $(SW_HOME)/../hardware)
include $(shell pwd)/../common.mk

DUMP     := pmu_evu_bench.dump
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
# Accepts four address defines (all optional — placeholders used if absent):
#   FUNC_ALU_ENTRY / FUNC_ALU_EXIT   — func_alu_chain  (phase 1)
#   FUNC_COLD_ENTRY / FUNC_COLD_EXIT — func_l1_cold    (phase 2)
# ==============================================================================

.PHONY: pmu_firmware
pmu_firmware:
	$(MAKE) -C $(PMU_FW_DIR) all generate-bin-files \
		$(if $(FUNC_ALU_ENTRY),FUNC_ALU_ENTRY=$(FUNC_ALU_ENTRY),)   \
		$(if $(FUNC_ALU_EXIT),FUNC_ALU_EXIT=$(FUNC_ALU_EXIT),)       \
		$(if $(FUNC_COLD_ENTRY),FUNC_COLD_ENTRY=$(FUNC_COLD_ENTRY),) \
		$(if $(FUNC_COLD_EXIT),FUNC_COLD_EXIT=$(FUNC_COLD_EXIT),)

pmu_text.o: pmu_firmware
	cp $(PMU_TEXT_BIN) text_section.bin
	$(RISCV_GCC) -c pmu_text_wrapper.S -o $@

pmu_data.o: pmu_firmware
	cp $(PMU_DATA_BIN) data_rodata_bss.bin
	$(RISCV_GCC) -c pmu_data_wrapper.S -o $@

# ==============================================================================
# all: transparent two-pass build + SLM copy to hardware/
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
		pmu_evu_bench.c \
		pmu_text.o pmu_data.o \
		$(SRC) \
		-o pmu_evu_bench.riscv

# ==============================================================================
# Two-pass build:
#   Pass 1 — build CVA6 binary with placeholder firmware
#   extract_addrs.py — parse objdump, emit four #defines for both functions
#   Pass 2 — rebuild firmware with real addresses, re-link CVA6 binary
# ==============================================================================

$(DUMP): pmu_evu_bench.riscv
	$(RISCV_PREFIX)objdump -d $< > $@

$(ADDRS_H): $(DUMP)
	$(PYTHON) extract_addrs.py $(DUMP) > $(ADDRS_H)

gen-addrs: $(ADDRS_H)

two-pass:
	$(MAKE) build
	$(RISCV_PREFIX)objdump -d $(APP).riscv > $(DUMP)
	$(PYTHON) extract_addrs.py $(DUMP) > $(ADDRS_H)
	_AE=$$(grep 'define FUNC_ALU_ENTRY'  $(ADDRS_H) | awk '{print $$3}'); \
	_AX=$$(grep 'define FUNC_ALU_EXIT'   $(ADDRS_H) | awk '{print $$3}'); \
	_CE=$$(grep 'define FUNC_COLD_ENTRY' $(ADDRS_H) | awk '{print $$3}'); \
	_CX=$$(grep 'define FUNC_COLD_EXIT'  $(ADDRS_H) | awk '{print $$3}'); \
	$(MAKE) -C $(PMU_FW_DIR) clean all generate-bin-files \
		FUNC_ALU_ENTRY=$$_AE FUNC_ALU_EXIT=$$_AX \
		FUNC_COLD_ENTRY=$$_CE FUNC_COLD_EXIT=$$_CX && \
	cp $(PMU_TEXT_BIN) text_section.bin && \
	$(RISCV_GCC) -c pmu_text_wrapper.S -o pmu_text.o && \
	cp $(PMU_DATA_BIN) data_rodata_bss.bin && \
	$(RISCV_GCC) -c pmu_data_wrapper.S -o pmu_data.o && \
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		pmu_evu_bench.c \
		pmu_text.o pmu_data.o \
		$(SRC) \
		-o $(APP).riscv

clean:
	rm -f pmu_evu_bench.riscv $(DUMP) $(ADDRS_H) *.slm
	$(MAKE) -C $(PMU_FW_DIR) clean
	rm -f pmu_text.o pmu_data.o text_section.bin data_rodata_bss.bin
