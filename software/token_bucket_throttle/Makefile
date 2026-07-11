APP  := tb2
XLEN := 64

export SW_HOME := $(shell cd .. && pwd)
include $(shell pwd)/../common.mk


TB_INC := $(shell pwd)/../token_bucket_throttle/include

build:
	$(RISCV_GCC) $(RISCV_FLAGS) \
		-I$(TB_INC) \
		-T $(inc_dir)/test.ld $(RISCV_LINK_OPTS) $(cc-elf-y) \
		$(inc_dir)/crt.S $(inc_dir)/syscalls.c -L $(inc_dir) \
		$(APP).c \
		$(SRC) \
		-o $(APP).riscv

clean:
	rm -f $(APP).riscv $(APP).dump *.slm
