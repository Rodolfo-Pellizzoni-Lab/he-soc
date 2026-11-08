# t_iopmp_linux_n<NCORES>: ../t_iopmp.c, unchanged, as a Linux program. soc_test.h here stands in for
# soc_tests/include/soc_test.h and reaches the registers through /dev/mem. Built with the bundle's buildroot compiler,
# like t_storm/linux, once per core count (the PLIC check reads every hart's S-mode context). Run it as root on the
# board: ./t_iopmp_linux_n8 (the IOPMP must be off, as after a reset, for phase B to run).
#   make [NCORES=4]; make install copies it to the board
BUNDLE  ?= $(abspath ../../../../../alsaqr-software)
CC      := $(BUNDLE)/linux/cva6-sdk/buildroot/output/host/bin/riscv64-linux-gcc
NCORES  ?= 8
CFLAGS  ?= -O2 -static -Wall -DSOC_NUM_CORES=$(NCORES) -fmacro-prefix-map=../= -I. -I../../../inc -I../../../quad_boot
BOARD   ?= root@10.42.0.2
SSHOPT  := -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
PROG    := t_iopmp_linux_n$(NCORES)

$(PROG): ../t_iopmp.c soc_test.h ../../../inc/iopmp.h ../../../quad_boot/pmu_defines.h
	$(CC) $(CFLAGS) -o $@ $<

install: $(PROG)
	scp -O $(SSHOPT) $< $(BOARD):

clean:
	rm -f t_iopmp_linux_n*

.PHONY: install clean
