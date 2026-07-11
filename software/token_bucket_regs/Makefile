APP  := tb
XLEN := 64

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk

# PMU firmware paths
PMU_FW_DIR    := pmu_firmware
PMU_BUILD_DIR := $(PMU_FW_DIR)/build
PMU_TEXT_BIN  := $(PMU_BUILD_DIR)/text_section.bin
PMU_DATA_BIN  := $(PMU_BUILD_DIR)/data_rodata_bss.bin

OBJCOPY ?= riscv64-unknown-elf-objcopy


# PMU Firmware: compile from source using riscv64-unknown-elf-gcc with rv32im
.PHONY: pmu_firmware
pmu_firmware:
	$(MAKE) -C $(PMU_FW_DIR) all

pmu_text.o: pmu_firmware
	cp $(PMU_TEXT_BIN) text_section.bin
	$(RISCV_GCC) -c pmu_text_wrapper.S -o $@

pmu_data.o: pmu_firmware
	cp $(PMU_DATA_BIN) data_rodata_bss.bin
	$(RISCV_GCC) -c pmu_data_wrapper.S -o $@


# CVA6 (rv64) test binary=
build: pmu_text.o pmu_data.o
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) -I$(shell pwd)/include \
		-T $(inc_dir)/test.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		$(APP).c \
		pmu_text.o pmu_data.o \
		$(SRC) \
		-o $(APP).riscv

clean:
	rm -f $(APP).riscv $(APP).dump *.slm
	$(MAKE) -C $(PMU_FW_DIR) clean
	rm -f pmu_text.o pmu_data.o text_section.bin data_rodata_bss.bin
