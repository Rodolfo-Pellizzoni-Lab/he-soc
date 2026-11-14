APP := pmu_snap
XLEN := 64

export SW_HOME ?= $(shell cd .. && pwd)
include $(shell pwd)/../common.mk
RISCV_FLAGS += -I$(SW_HOME)/inc/pmu

# Ibex firmware (pmu_firmware/), embedded into the CVA6 binary by the two .incbin wrappers
SRC += pmu_text_wrapper.S pmu_data_wrapper.S

.PHONY: pmu_firmware clean_fw
pmu_firmware:
	$(MAKE) -C pmu_firmware all generate-bin-files RISCV_PREFIX=$(RISCV_PREFIX) SW_HOME=$(SW_HOME)

build: pmu_firmware
clean: clean_fw
clean_fw:
	$(MAKE) -C pmu_firmware clean
