# Makefile for PMU Firmware - Snapshot test (RV32IM, Ibex core)

# Compiler and tools
RISCV_PREFIX ?= riscv64-unknown-elf-
CC      = $(RISCV_PREFIX)gcc
OBJDUMP = $(RISCV_PREFIX)objdump
OBJCOPY = $(RISCV_PREFIX)objcopy

SW_HOME ?= $(shell cd ../.. && pwd)

# Compiler flags for RV32IM (Ibex core)
# GCC 8.3.0 (SiFive) bundles CSR instructions into rv32im — no _zicsr suffix needed; GCC 12 and later (the
# alsaqr-software toolchain is 15.1) need it for crt0.s, so add it when the toolchain takes it
ZICSR := $(shell echo 'csrr a0, mcycle' | $(CC) -march=rv32im_zicsr -mabi=ilp32 -x assembler -c -o /dev/null - \
                   2>/dev/null && echo _zicsr)
# pmu_defines.h and pmu_hw_desc.h: inc/pmu
CFLAGS = -march=rv32im$(ZICSR) -mabi=ilp32 -mcmodel=medlow \
         -Wall -fvisibility=hidden -ffreestanding \
         -O2 -nostdlib \
         -I $(SW_HOME)/inc/pmu

# Linker script
LDSCRIPT = linker.ld
LDFLAGS  = -T $(LDSCRIPT) -nostdlib

BUILD_DIR = build

TARGET   = $(BUILD_DIR)/pmu_firmware.elf
ASM_FILE = $(BUILD_DIR)/pmu_firmware.asm
BIN_FILE = $(BUILD_DIR)/pmu_firmware.bin

OBJ_FILES = $(BUILD_DIR)/crt0.o \
            $(BUILD_DIR)/main.o

.PHONY: all clean dump generate-bin-files

all: $(TARGET) dump

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/crt0.o: crt0.s | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/main.o: main.c $(SW_HOME)/inc/pmu/pmu_hw_desc.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJ_FILES) $(LDSCRIPT) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJ_FILES) -o $@

dump: $(TARGET)
	$(OBJDUMP) -D $(TARGET) > $(ASM_FILE)
	$(OBJCOPY) -O binary $(TARGET) $(BIN_FILE)

# Separate binaries for .text (ISPM) and .data/.rodata/.bss (DSPM + 0x200): CVA6 loads them
generate-bin-files: $(TARGET)
	$(OBJCOPY) -O binary --only-section=.text $(TARGET) $(BUILD_DIR)/text_section.bin
	$(OBJCOPY) -O binary --only-section=.data --only-section=.rodata --only-section=.bss \
	    $(TARGET) $(BUILD_DIR)/data_rodata_bss.bin
	@echo ""
	@echo "=== PMU Firmware Binary Sizes ==="
	@ls -lh $(BUILD_DIR)/text_section.bin $(BUILD_DIR)/data_rodata_bss.bin
	@echo ""

clean:
	rm -rf $(BUILD_DIR)
