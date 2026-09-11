# Sourced by the xsim scripts: locations and the shared build configuration.
XSIM_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HW=$(cd "$XSIM_DIR/.." && pwd)
WORK=${XSIM_WORK:-$XSIM_DIR/work}

# Vivado 2024.2 is the version the port was verified with
VIVADO_SETTINGS=${VIVADO_SETTINGS:-/tools/Xilinx/Vivado/2024.2/settings64.sh}
if ! command -v xvlog >/dev/null 2>&1; then
  [ -f "$VIVADO_SETTINGS" ] || { echo "xvlog not on PATH and $VIVADO_SETTINGS missing (set VIVADO_SETTINGS)"; exit 1; }
  source "$VIVADO_SETTINGS"
fi

# bender targets of the Makefile's scripts_vip flow
BENDER_TARGETS="-t rtl -t use_idma -t test -t tb -t vip -t cva6 -t scm_use_latch_scm -t aia_msi -t aia_embedded -t cv64a6_imafdc_sv39_wb"

# SoC configuration (every block is compiled with these)
SOC_DEFINES="WT_DCACHE USE_LOCAL_JTAG NO_L3_CONNECTION CODE_IN_L2 EXCLUDE_CLUSTER EXCLUDE_ETHERNET COMMON_CELLS_ASSERTS_OFF"
# xsim-specific switches in the RTL/tb (see README.md, section 2)
XSIM_DEFINES="XSIM_TICK XSIM_NO_TRACER XSIM_NO_FREQMETER XSIM_SIM_DRAM XSIM_SRAM_INIT_ONCE XSIM_SRAM_NO_X_WRITE XSIM_RST_NO_REWRITE XSIM_FLL_IDLE_IN_RESET"

# device models that are switched off at elaboration (the flash arrays alone need ~29 GB in xsim)
GENERICS="-generic_top USE_S25FS256S_MODEL=0 -generic_top USE_24FC1025_MODEL=0 -generic_top USE_SDIO=0 -generic_top USE_SDVT_CPI=0 -generic_top USE_CAN=0 -generic_top USE_ETHERNET=0 -generic_top USE_USART=0"
