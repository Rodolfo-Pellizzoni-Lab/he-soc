APP  := pmu_cntr_bench
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)

# ==============================================================================
# CVA6 (rv64) test binary — no PMU firmware needed for this simplified test.
# Built like the SoC tests (soc_tests/common.mk: soc_test.h, the common linker
# script and start-up code, SOC_NUM_CORES); make build.
# ==============================================================================
include $(SW_HOME)/soc_tests/common.mk
