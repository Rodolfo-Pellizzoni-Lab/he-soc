APP  := pmu_cntr_bench
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk

# ==============================================================================
# CVA6 (rv64) test binary — no PMU firmware needed for this simplified test
# ==============================================================================

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		pmu_cntr_bench.c \
		$(SRC) \
		-o pmu_cntr_bench.riscv

clean:
	rm -f pmu_cntr_bench.riscv pmu_cntr_bench.dump *.slm
