#! /bin/tcsh -f

set DIR=".."
set VER=10.6b
set LIB=scan

vsim-${VER} -work ${LIB} \
          -L uk65lscllmvbbl_vlog \
          -L uk65lscllmvbbr_vlog \
          -L uk65lscllmvbbh_vlog \
          -L u065gioll25mvir_vlog \
          -sdftyp dut=${DIR}/encounter/out/hyperbus_macro.sdf.gz +sdf_verbose \
          -v2k_int_delays +no_neg_tchk +ntc_warn +no_glitch_msg \
          -t 1ps \
          -voptargs=+acc \
          scanchain_tb


#	hyperbus_macro_inflate_test

# scanchain_tb
#-sdftyp dut_i=${DIR}/encounter/out/hyperbus_macro.sdf.gz +sdf_verbose \

