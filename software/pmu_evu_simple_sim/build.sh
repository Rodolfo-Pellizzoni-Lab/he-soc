#!/bin/bash
source /home/mhassen/mahdi_setup.sh
cd /home/mhassen/he-soc/software/pmu_evu_simple_sim
make clean build fpga=1
