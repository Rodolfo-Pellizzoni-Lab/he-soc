#!/bin/tcsh -f

# sample script to run gatelevel simulation with sdf timings  
#
# >>> Adapt it for your design !!! <<<  (see README)
#

set DIR=".."
set VER=10.6b
set LIB=gate


vsim-$VER -t 1ps -lib $LIB \
          -L uk65lscllmvbbl_vlog \
          -L uk65lscllmvbbr_vlog \
          -L uk65lscllmvbbh_vlog \
          -L u065gioll25mvir_vlog \
          -sdftyp dut_i/i_inflate=${DIR}/encounter/out/hyperbus_macro.sdf.gz +sdf_verbose \
          -v2k_int_delays +no_neg_tchk +ntc_warn +no_glitch_msg \
          hyperbus_tb

# +maxdelays

# +notimingchecks

# use:
#
#   vsim-10.5a -help 
#
# to see available options
