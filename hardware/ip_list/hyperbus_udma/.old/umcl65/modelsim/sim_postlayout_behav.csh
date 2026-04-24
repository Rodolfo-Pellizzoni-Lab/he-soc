#!/bin/tcsh -f

# sample script to run gatelevel simulation with sdf timings  
#
# >>> Adapt it for your design !!! <<<  (see README)
#

set DIR=".."
set VER=10.6b
set LIB=gate


vsim-$VER -t 1ps -lib $LIB \
          -v2k_int_delays +no_neg_tchk +ntc_warn +no_glitch_msg +notimingchecks\
          hyperbus_tb

# use:
#
#   vsim-10.5a -help 
#
# to see available options
