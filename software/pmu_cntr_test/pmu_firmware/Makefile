# Makefile for PMU Firmware - Counter Read (RV32IM, Ibex core)

CC      = /opt/riscv64/bin/riscv64-unknown-elf-gcc
OBJDUMP = /opt/riscv64/bin/riscv64-unknown-elf-objdump
OBJCOPY = /opt/riscv64/bin/riscv64-unknown-elf-objcopy

# RV32IM: Ibex has M extension (RV32MFast)
CFLAGS = -march=rv32im -mabi=ilp32 -mcmodel=medlow \
         -Wall -ffreestanding -O2 -nostdlib \
         -I include

LDSCRIPT = linker.ld
LDFLAGS  = -T $(LDSCRIPT) -nostdlib

BUILD_DIR = build

TARGET        = $(BUILD_DIR)/pmu_firmware.elf
ASM_FILE      = $(BUILD_DIR)/pmu_firmware.asm
BIN_FILE      = $(BUILD_DIR)/pmu_firmware.bin
TEXT_BIN      = $(BUILD_DIR)/text_section.bin
DATA_BIN      = $(BUILD_DIR)/data_rodata_bss.bin

OBJ_FILES = $(BUILD_DIR)/crt0.o \
            $(BUILD_DIR)/main.o

.PHONY: all clean dump generate-bin-files

all: $(TARGET) dump generate-bin-files

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/crt0.o: crt0.s | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/main.o: main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJ_FILES) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJ_FILES) -o $@

dump: $(TARGET)
	$(OBJDUMP) -D $(TARGET) > $(ASM_FILE)
	$(OBJCOPY) -O binary $(TARGET) $(BIN_FILE)

generate-bin-files: $(TARGET)
	$(OBJCOPY) -O binary --only-section=.text $(TARGET) $(TEXT_BIN)
	$(OBJCOPY) -O binary \
	    --only-section=.data --only-section=.rodata --only-section=.bss \
	    $(TARGET) $(DATA_BIN)
	@echo ""
	@echo "=== PMU Firmware Binary Sizes ==="
	@ls -lh $(TEXT_BIN) $(DATA_BIN)
	@echo ""

clean:
	rm -rf $(BUILD_DIR)
