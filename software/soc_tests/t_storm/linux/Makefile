# t_storm_linux: t_storm's every-master-at-once traffic under Linux (the 8-core bitstream's Linux, linux/prebuilt/8core
# of alsaqr-software), built with the bundle's buildroot compiler. make; make install copies it to the board.
BUNDLE  ?= $(abspath ../../../../../alsaqr-software)
CC      := $(BUNDLE)/linux/cva6-sdk/buildroot/output/host/bin/riscv64-linux-gcc
NCORES  ?= 8
CFLAGS  ?= -O2 -static -pthread -Wall -DSOC_NUM_CORES=$(NCORES) -I../../../quad_boot -I..
BOARD   ?= root@10.42.0.2
SSHOPT  := -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR

t_storm_linux: t_storm_linux.c ../pe_fw.h
	$(CC) $(CFLAGS) -o $@ $<

install: t_storm_linux
	scp -O $(SSHOPT) $< $(BOARD):

clean:
	rm -f t_storm_linux

.PHONY: install clean
