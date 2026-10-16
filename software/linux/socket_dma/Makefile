# Linux user-space test of the accelerator socket's DMA (software/linux/socket_dma/socket_dma.c), built with the
# buildroot toolchain of alsaqr-software (cva6-sdk/buildroot/output/host/bin) as a static binary, and dropped
# into the rootfs overlay so it ships in the initramfs: make install
ALSAQR_SW ?= $(HOME)/alsaqr-software
CROSS     ?= $(ALSAQR_SW)/linux/cva6-sdk/buildroot/output/host/bin/riscv64-buildroot-linux-gnu-
OVERLAY   ?= $(ALSAQR_SW)/linux/cva6-sdk/rootfs/usr/bin

socket_dma: socket_dma.c
	$(CROSS)gcc -O2 -Wall -static -o $@ $<

install: socket_dma
	mkdir -p $(OVERLAY)
	cp socket_dma $(OVERLAY)/socket_dma

clean:
	rm -f socket_dma

.PHONY: install clean
