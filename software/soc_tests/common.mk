# Shared by the SoC validation tests (software/soc_tests/<test>/) and the accelerator tests (software/accel/<name>/).
include $(SW_HOME)/common.mk
RISCV_FLAGS += -I$(SW_HOME)/soc_tests/include -I$(SW_HOME)/quad_boot
# The SoC's core count (hardware NUM_CVA6; soc_test.h and quad_boot/pmu_defines.h default to 4): SOC_NUM_CORES=<n>,
# or NUM_CVA6=<n>, on the make command line or in the environment builds for an n-core SoC. The -D is added only when
# one of them is set, so that a -DSOC_NUM_CORES=<n> in RISCV_GCC (alsaqr-mcp's extra_cflags) still works without
# them; with both, they must agree.
SOC_NUM_CORES ?= $(NUM_CVA6)
ifneq ($(strip $(SOC_NUM_CORES)),)
ifneq ($(filter-out -DSOC_NUM_CORES=$(strip $(SOC_NUM_CORES)),$(filter -DSOC_NUM_CORES=%,$(RISCV_GCC))),)
$(error SOC_NUM_CORES=$(strip $(SOC_NUM_CORES)), but RISCV_GCC has $(filter -DSOC_NUM_CORES=%,$(RISCV_GCC)))
endif
RISCV_FLAGS += -DSOC_NUM_CORES=$(strip $(SOC_NUM_CORES))
endif
