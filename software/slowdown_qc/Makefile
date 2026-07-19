APP  := slowdown_qc
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk

# ==============================================================================
# Quad-core DRAM-traffic test for the slowdown IP (2 readers + 2 writers).
#   make build      # -> slowdown_qc.riscv
#   make all        # -> also emits hyperram*.slm and copies them to hardware/
# ==============================================================================

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		slowdown_qc.c \
		$(SRC) \
		-o slowdown_qc.riscv

clean:
	rm -f slowdown_qc.riscv slowdown_qc.dump *.slm
