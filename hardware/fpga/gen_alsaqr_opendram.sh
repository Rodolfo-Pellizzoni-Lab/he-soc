#!/bin/bash
# OpenDRAM v5 integration build script for AlSaqr (VCU118).
# Creates a bitstream with OpenDRAM's FRFCFS scheduler replacing the Xilinx
# MIG DDR4 internal command scheduler.  The AXI interface, PHY, and all pin
# assignments are unchanged from the standard gen_alsaqr.sh flow.
#
# Usage:
#   ./gen_alsaqr_opendram.sh          # open Vivado GUI (elaborate only)
#   ./gen_alsaqr_opendram.sh -synth   # run full synthesis → bitstream in batch
#
# Do NOT modify this script's companion files: from_Ali/ or gen_alsaqr.sh.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HE_SOC_DIR="$SCRIPT_DIR/he-soc"

SYNTHESIS=false
for arg in "$@"; do
    case $arg in
        -synth) SYNTHESIS=true ;;
    esac
done
export SYNTHESIS

echo "================================================================"
echo " gen_alsaqr_opendram.sh — OpenDRAM v5 + AlSaqr"
echo " SYNTHESIS=$SYNTHESIS"
echo "================================================================"

cd "$HE_SOC_DIR"

# Standalone branch: all deps vendored, no make init needed.
source uw_setup.sh

cd hardware/

# Export Vivado environment (4-core DDR4 with LLC and OpenTitan, VCU118).
# Must be set before any IP make targets — each IP's run.tcl reads XILINX_PART.
export XILINX_PART=xcvu9p-flga2104-2L-e
export XILINX_BOARD=xilinx.com:vcu118:part0:2.4
export BOARD=vcu118
export AXI_ID_DDR_WIDTH=9      # LLC enabled: ariane_soc::IdWidthSlave + 1
export MAIN_MEM=DDR4
export NUM_CORES=4
export USE_OT=1
export ETH2FMC_NO_PAD=0
export PROJECT_HOME="$(pwd)/fpga/alsaqr"

# ---- SoC clock frequency + hardcoded 38400 UART verification ----
# Mirror clk_mngr/run.tcl so this matches the clock the bitstream will use.
if [ "$MAIN_MEM" = "HYPER" ]; then
    SOC_FREQ_MHZ=10
elif [ "$MAIN_MEM" = "DDR4" ]; then
    if [ "$NUM_CORES" = "4" ]; then
        SOC_FREQ_MHZ=20
    elif [ "$USE_OT" = "1" ]; then
        SOC_FREQ_MHZ=25
    else
        SOC_FREQ_MHZ=40
    fi
fi
# iDLL=0x20 -> divisor 32; baud = f / (divisor * 16) = f / 512
UART_BAUD=$(( SOC_FREQ_MHZ * 1000000 / 512 ))
echo "================================================================"
echo " SoC clock : ${SOC_FREQ_MHZ} MHz   (clk_mngr CLKOUT1)"
echo " UART baud : ~${UART_BAUD}   (apb_uart iDLL=0x20, div 32; target 38400)"
echo "================================================================"

# Guarantee the hardcoded 38400 UART is actually in the apb_uart that gets compiled.
UART_VHD="deps/apb_uart/src/apb_uart.vhd"
if grep -qE 'iDLL[[:space:]]*<=[[:space:]]*X"20"' "$UART_VHD"; then
    echo "[OK] Hardcoded UART divisor iDLL=0x20 present in $UART_VHD"
else
    echo "[ERROR] $UART_VHD is NOT hardcoded to iDLL=0x20 (38400 baud)."
    echo "        Build would use a software-programmable divisor -> likely garbage UART. Aborting."
    exit 1
fi

# Regenerate QuestaSim compile script from Bender.yml (fast, no network).
make scripts_vip

# Regenerate FPGA compile.tcl from Bender.yml (reads existing Bender.lock).
# Must use "make VAR=val target" form (not COMPILE_ARGS="...") so the Makefile's
# ifdef simple-padframe / ifdef quad-core blocks fire and emit SIMPLE_PADFRAME,
# QUAD_CORE, EXCLUDE_CLUSTER into compile.tcl — matching what gen_alsaqr.sh does.
COMPILE_ARGS="simple-padframe=1 exclude-cluster=1 quad-core=1"
make $COMPILE_ARGS scripts-bender-fpga-ddr

# Build all IPs EXCEPT DDR.
# DDR4 is created inline by run_opendram.tcl so that we can lock the IP
# immediately and overwrite the generated mem_intfc with OpenDRAM's version.
make -C fpga/alsaqr/tcl/ips/boot_rom  clean all
make -C fpga/alsaqr/tcl/ips/clk_mngr  clean all
make -C fpga/alsaqr/tcl/ips/qspi      clean all
make -C fpga/alsaqr/tcl/ips/otp_ot    clean all
make -C fpga/alsaqr/tcl/ips/rom_ot    clean all

cd fpga/

if $SYNTHESIS; then
    vivado -mode batch -source run_opendram.tcl \
        2>&1 | tee "$SCRIPT_DIR/vivado_opendram.log"
    echo ""
    echo "================================================================"
    echo " Bitstream (if successful): fpga/reports/alsaqr_xilinx.bit"
    echo "================================================================"
else
    vivado -mode gui -source run_opendram.tcl
fi
