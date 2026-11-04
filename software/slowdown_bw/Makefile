APP  := slowdown_bw
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
# soc_tests/common.mk: common.mk plus the include paths of soc_test.h (CHECK, TEST PASS/FAIL)
include $(shell pwd)/../soc_tests/common.mk

# ==============================================================================
# Single-core cost of a main-memory access through the slowdown IP (latency-bound).
#   make build      # -> slowdown_bw.riscv (fpga=1: the board's 2 MB working set)
#   make all        # -> also emits hyperram*.slm and copies them to hardware/
# ==============================================================================

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		slowdown_bw.c \
		$(SRC) \
		-o slowdown_bw.riscv

clean:
	rm -f slowdown_bw.riscv slowdown_bw.dump *.slm
