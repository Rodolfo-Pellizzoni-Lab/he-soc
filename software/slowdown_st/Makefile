APP  := slowdown_st
XLEN := 64

RISCV_PREFIX ?= /opt/riscv64/bin/riscv64-unknown-elf-

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk

# ==============================================================================
# Single-core DRAM-traffic test for the slowdown IP (drives the in-RTL checker)
# ==============================================================================

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(shell pwd) \
		-T test_sim.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		slowdown_st.c \
		$(SRC) \
		-o slowdown_st.riscv

clean:
	rm -f slowdown_st.riscv slowdown_st.dump *.slm
