# Shared by the SoC validation tests (software/soc_tests/<test>/) and the accelerator tests (software/accel/<name>/).
include $(SW_HOME)/common.mk
RISCV_FLAGS += -I$(SW_HOME)/soc_tests/include -I$(SW_HOME)/quad_boot
