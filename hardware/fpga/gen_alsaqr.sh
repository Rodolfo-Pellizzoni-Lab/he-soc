#!/bin/bash

# exit if any command fails
set -e

# increase the maximum number of open file descriptors for bender 
ulimit -n 4096

# define maximum number of attempts to run bender
MAX_ATTEMPTS=10
attempt_count=1

# arguments passed for making compile.tcl
# setting quad-core =1
COMPILE_ARGS="simple-padframe=1 exclude-cluster=1 quad-core=1"

# indicate if synthesis is required
# read from command line arguments
SYNTHESIS=true

# required path
TARGET_DIR=""
SETUP_FILE="./he-soc/uw_setup.sh"

# parse command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        -synth ) 
            SYNTHESIS=true
            shift
            ;;
        * )
            TARGET_DIR=$1
            shift
            ;;
    esac
done

# check if the target directory is provided
if [ -z "$TARGET_DIR" ]; then
	echo "[error] target directory not specified!"
	echo "Usage: $0 [-synth] <TARGET_DIR>"
	exit 1
fi

# change directory
cd $TARGET_DIR

# set the log file path
LOG_FILE="$(pwd)/fanos.log"

# remove previous log file
if [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
fi

# clone the repository
echo "[$(date)] [FanosLab] cloning repository..." >> $LOG_FILE
# git clone git@github.com:AlSaqr-platform/he-soc.git
echo -e "[$(date)] [FanosLab] repository cloned.\n" >> $LOG_FILE

# Log branch name and current directory
#BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CWD=$(pwd)

#echo "[$(date)] [FanosLab] Current branch: ${BRANCH}" >> "$LOG_FILE"
echo "[$(date)] [FanosLab] Current directory: ${CWD}" >> "$LOG_FILE"

# remove the default setup script
if [ -f "$SETUP_FILE" ]; then
    rm -f "$SETUP_FILE"
fi

# create a new setup script that matches the system
cat << EOF > "$SETUP_FILE"
#!/bin/bash
echo "exporting RISCV"
export PATH=/opt/riscv64/bin:\$PATH
export RISCV=/opt/riscv64
export SW_HOME=\$(pwd)/software
export HW_HOME=\$(pwd)/hardware
echo "exporting QUESTASIM PATH"
export QUESTASIM_HOME=/tools/questasim/
echo "exporting RISCV 32 bit with zfinx"
export PATH=/opt/riscv/bin:\$PATH
echo "cloning submodules"
git submodule update --init --recursive
EOF

# change directory
cd he-soc/


echo -e "[$(date)] [FanosLab] Switched to Sandro Branch.\n" >> $LOG_FILE

# source the updated tool setup script
source uw_setup.sh
echo -e "[$(date)] [FanosLab] sourced updated tool setup script.\n" >> $LOG_FILE

# source the pulp cluster setup
source software/pulp-runtime/configs/pulp_cluster.sh
echo -e "[$(date)] [FanosLab] sourced cluster setup script.\n" >> $LOG_FILE

# change directory
cd hardware/

# call bender to clone dependencies (MAX_ATTEMPTS times at most)
echo "[$(date)] [FanosLab] calling bender to clone dependencies..." >> $LOG_FILE
#while [ $attempt_count -le $MAX_ATTEMPTS ]; do
#    echo "[$(date)] [FanosLab] attempt $attempt_count of $MAX_ATTEMPTS." >> $LOG_FILE
    # make init && break
#    attempt_count=$((attempt_count + 1))
#    sleep 1 
#done

if [ $attempt_count -gt $MAX_ATTEMPTS ]; then
    echo "[$(date)] [FanosLab] bender failed after $MAX_ATTEMPTS attempts." >> $LOG_FILE
    echo "[$(date)] [FanosLab] bender failed, exit." >> $LOG_FILE
    exit 1
else
    echo -e "[$(date)] [FanosLab] bender command done.\n" >> $LOG_FILE
fi

# clone RTL files and verification IPs
echo "[$(date)] [FanosLab] cloning RTL files and verification IPs..." >> $LOG_FILE
# make scripts_vip
echo -e "[$(date)] [FanosLab] RTL files and verification IPs cloned.\n" >> $LOG_FILE

# add missing argument "-t rtl" to the Makefile targets
sed -i '/$(BENDER) script vivado -t $(CVA6_PKG) -t fpga / s/-t fpga /&-t rtl /' Makefile

# generate compile.tcl
echo "[$(date)] [FanosLab] generating the compile file..." >> $LOG_FILE
echo "[$(date)] [FanosLab] arguments: $COMPILE_ARGS" >> $LOG_FILE
make $COMPILE_ARGS scripts-bender-fpga-ddr
echo -e "[$(date)] [FanosLab] compile file generated.\n" >> $LOG_FILE

# change directory
cd fpga

# source the Alsaqr setup file and respond automatically
# FPGA Board: 1-ZCU102 2-VCU118
# Instantiating LLC: y/n
# Main Memory Type: 1-DDR 2-HYPER
# Instantiating OpenTitan: y/n
# Numebr of CVA6 Cores: 2/4 >>> Set this for to have quad core!
echo "[$(date)] [FanosLab] Setting up the Alsaqr project..." >> $LOG_FILE
{
    source setup.sh << EOF
2
y
1
y
4	
EOF
} >> "$LOG_FILE" 2>&1
echo -e "[$(date)] [FanosLab] Alsaqr setup done.\n" >> $LOG_FILE

# remove "vivado-2018.2" from Vivado call commands used in Makefiles of all IP projects
find ./alsaqr/tcl/ips/ -name "Makefile" -exec sed -i 's/vivado-2018\.2 //g' {} \;

# define the board_part in Xilinx QSPI IP run.tcl
sed -i '/create_project xilinx_qspi \. -part \$partNumber/a set_property board_part $boardName [current_project]' ./alsaqr/tcl/ips/qspi/run.tcl

# generate IP projects
echo "[$(date)] [FanosLab] generating IP projects..." >> $LOG_FILE
make ips
echo -e "[$(date)] [FanosLab] IP projects generated.\n" >> $LOG_FILE

# remove "$(VITIS)" from Vivado call command used in main project Makefile
sed -i 's/\$(VITIS) //g' Makefile

# define the board_part in the main project run.tcl
sed -i '/file mkdir \$outputDir/a set boardName  \$::env(XILINX_BOARD)' run.tcl
sed -i '/create_project alsaqr \$::env(PROJECT_HOME) -part \$::env(XILINX_PART)/a set_property board_part \$boardName \[current_project\]' run.tcl

# check if -synth argument is provided
# if passed -synth, change the synth_design command in run.tcl
# if not passed -synth, comment synthesis commands in run.tcl and generate a separate synth.tcl
if $SYNTHESIS; then

    echo -e "[$(date)] [FanosLab] synthesis and implementation is enable.\n" >> $LOG_FILE
    # change synth_design command to launch_runs in run.tcl
    sed -i '/synth_design/c\
    launch_runs synth_1 -jobs 64 \
    wait_on_run synth_1 \
    open_run synth_1 -name synth_1
    ' run.tcl
    
else

    echo "[$(date)] [FanosLab] synthesis and implementation is disable." >> $LOG_FILE
    
    # generate a separate file synth.tcl for synthesis and implementation
    tmp=$(mktemp)
    awk '{print}' run.tcl > $tmp
    mv $tmp run.tcl
    line_number=$(grep -n "read_xdc ./timing_constr.xdc" run.tcl | cut -d: -f1)
    line_start=$(($line_number + 1))
    line_end=$(awk '{print}' run.tcl | wc -l)
    sed -n "${line_start},${line_end}p" run.tcl > synth.tcl

    # change synth_design command to launch_runs in synth.tcl
    sed -i '/synth_design/c\
    set outputDir reports \
    launch_runs synth_1 -jobs 64 \
    wait_on_run synth_1 \
    open_run synth_1 -name synth_1
    ' synth.tcl

    # comment everything related to the synthesis and implementation in the main project run.tcl
    sed -i "${line_start},${line_end}s|.*|# &|" run.tcl
    
    echo -e "[$(date)] [FanosLab] synth.tcl generated.\n" >> $LOG_FILE
fi

# create Alsaqr project
echo "[$(date)] [FanosLab] generating Alsaqr project..." >> $LOG_FILE
make clean run
echo "[$(date)] [FanosLab] Alsaqr project generated! :D." >> $LOG_FILE

