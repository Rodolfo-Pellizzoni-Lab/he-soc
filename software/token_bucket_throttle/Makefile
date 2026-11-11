APP  := tb_throttle
XLEN := 64

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk
RISCV_FLAGS += -I$(SW_HOME)/inc/pmu

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-T $(inc_dir)/test.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		$(APP).c \
		$(SRC) \
		-o $(APP).riscv

clean:
	rm -f $(APP).riscv $(APP).dump *.slm
