# Network boot loader (netboot.c): runs from DRAM at 0x8F00_0000 (netboot.ld), loads fw_payload.bin + alsaqr.dtb
# over the Xilinx Ethernet with TFTP from alsaqr-mcp/scripts/netboot_server.py, jumps to the payload.
#   make fpga=1 [SERVER_IP=a.b.c.d] [STATIC_IP=a.b.c.d STATIC_MASK=... STATIC_GW=...]
APP := netboot
XLEN := 64
SW_HOME := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
include $(SW_HOME)/soc_tests/common.mk
RISCV_FLAGS += -I$(SW_HOME)/eth/include -I$(SW_HOME)/soc_tests/include -I$(inc_dir) -DXETH_NTX=4
ip2hex = $(shell python3 -c "import sys; p=[int(x) for x in '$(1)'.split('.')]; print('0x%02x%02x%02x%02xU' % tuple(p))")
ifdef SERVER_IP
RISCV_FLAGS += -DSERVER_IP=$(call ip2hex,$(SERVER_IP))
endif
ifdef STATIC_IP
RISCV_FLAGS += -DSTATIC_IP=$(call ip2hex,$(STATIC_IP)) -DSTATIC_MASK=$(call ip2hex,$(STATIC_MASK)) -DSTATIC_GW=$(call ip2hex,$(STATIC_GW))
endif
# link with the loader's own script instead of test.ld
build: $(APP).c
	$(RISCV_GCC) $(RISCV_FLAGS) -T netboot.ld $(RISCV_LINK_OPTS) $(cc-elf-y) $(inc_dir)/crt.S syscalls.c -L $(inc_dir) $(APP).c $(SRC) -o $(APP).riscv
