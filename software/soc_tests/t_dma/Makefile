APP := t_dma
XLEN:=64
include $(shell pwd)/../common.mk
RISCV_FLAGS += -I$(SW_HOME)/accel/include
# DMA_NONCOHERENT=1: a bitstream from before a0dd722c, whose socket master bypasses the coherence unit; steps 2 and 4
# then report the stale outcome instead of failing on it
ifdef DMA_NONCOHERENT
RISCV_FLAGS += -DDMA_NONCOHERENT
endif
