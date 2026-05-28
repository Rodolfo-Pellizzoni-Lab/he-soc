# Makefile for PMU Firmware (RV32IM)
# Adapted from APMU-OS Makefile for riscv-none-elf-gcc

# Compiler and tools — use the same riscv64-unknown-elf toolchain as pmu_test2
RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-
CC      = $(RISCV_PREFIX)gcc
OBJDUMP = $(RISCV_PREFIX)objdump
OBJCOPY = $(RISCV_PREFIX)objcopy

# Compiler flags for RV32IM (Ibex core)
# GCC 8.3.0 (SiFive) bundles CSR instructions into rv32im — no _zicsr suffix needed
CFLAGS = -march=rv32im -mabi=ilp32 -mcmodel=medlow \
         -Wall -fvisibility=hidden -ffreestanding \
         -O2 -nostdlib \
         -I include

# Allow the outer build to inject correct PC milestone addresses for both functions.
# All four are optional — main.c has placeholder #ifndef guards for each.
#   make FUNC_ALU_ENTRY=0x... FUNC_ALU_EXIT=0x... FUNC_COLD_ENTRY=0x... FUNC_COLD_EXIT=0x...
ifneq ($(FUNC_ALU_ENTRY),)
CFLAGS += -DFUNC_ALU_ENTRY=$(FUNC_ALU_ENTRY)
endif
ifneq ($(FUNC_ALU_EXIT),)
CFLAGS += -DFUNC_ALU_EXIT=$(FUNC_ALU_EXIT)
endif
ifneq ($(FUNC_COLD_ENTRY),)
CFLAGS += -DFUNC_COLD_ENTRY=$(FUNC_COLD_ENTRY)
endif
ifneq ($(FUNC_COLD_EXIT),)
CFLAGS += -DFUNC_COLD_EXIT=$(FUNC_COLD_EXIT)
endif

# Source directories
SRC_DIR = .
COMMON_DIR = ./common

# Source files
SRCS = $(SRC_DIR)/crt0.s $(SRC_DIR)/main.c $(wildcard $(COMMON_DIR)/*.c)

# Linker script
LDSCRIPT = $(SRC_DIR)/linker.ld
LDFLAGS = -T $(LDSCRIPT) -nostdlib

# Build directory
BUILD_DIR = build

# Output file
TARGET = $(BUILD_DIR)/pmu_firmware.elf

# Assembly dump file
ASM_FILE_DISASM = $(BUILD_DIR)/pmu_firmware.asm

# Object files
OBJ_FILES = $(BUILD_DIR)/crt0.o \
            $(BUILD_DIR)/main.o \
            $(patsubst $(COMMON_DIR)/%.c, $(BUILD_DIR)/%.o, $(wildcard $(COMMON_DIR)/*.c))

# Binary file
BIN_FILE = $(BUILD_DIR)/pmu_firmware.bin

.PHONY: all clean dump generate-bin-files print_sizes

all: $(TARGET) dump print_sizes

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile assembly startup code
$(BUILD_DIR)/crt0.o: $(SRC_DIR)/crt0.s | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile main.c
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile common .c files to .o
$(BUILD_DIR)/%.o: $(COMMON_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile .s to .o after modification
compile_asm: $(OBJ_FILES)

# Link object files to create ELF
$(TARGET): compile_asm | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJ_FILES) -o $@

clean:
	rm -rf $(BUILD_DIR)

dump: $(TARGET)
	$(OBJDUMP) -D $(TARGET) > $(ASM_FILE_DISASM)
	$(OBJCOPY) -O binary $(TARGET) $(BIN_FILE)

# Generate separate binary files for .text and .data sections
# These are used by CVA6 to load the firmware
generate-bin-files: $(TARGET)
	$(OBJCOPY) -O binary --only-section=.text $(TARGET) $(BUILD_DIR)/text_section.bin
	$(OBJCOPY) -O binary --only-section=.data --only-section=.rodata --only-section=.bss $(TARGET) $(BUILD_DIR)/data_rodata_bss.bin
	@echo ""
	@echo "=== PMU Firmware Binary Sizes ==="
	@ls -lh $(BUILD_DIR)/text_section.bin
	@ls -lh $(BUILD_DIR)/data_rodata_bss.bin
	@echo ""

print_sizes: $(TARGET)
	@TEXT_SIZE=$$($(OBJDUMP) -h $(TARGET) | awk '$$2 == ".text" { print $$3 }'); \
	DATA_SIZE=$$($(OBJDUMP) -h $(TARGET) | awk '$$2 == ".data" { print $$3 }'); \
	RODATA_SIZE=$$($(OBJDUMP) -h $(TARGET) | awk '$$2 == ".rodata" { print $$3 }'); \
	BSS_SIZE=$$($(OBJDUMP) -h $(TARGET) | awk '$$2 == ".bss" { print $$3 }'); \
	TOTAL_DATA_SIZE=$$(echo $$((0x$$DATA_SIZE + 0x$$RODATA_SIZE + 0x$$BSS_SIZE))); \
	echo "Text Section Size: $$((0x$$TEXT_SIZE)) bytes"; \
	echo "Data + Rodata + BSS Size: $$TOTAL_DATA_SIZE bytes"
