#! /bin/tcsh -f

set VER=10.6b
set LIB=work

vsim-${VER} -work ${LIB} \
          -L uk65lscllmvbbl_vlog \
          -L uk65lscllmvbbr_vlog \
          -L uk65lscllmvbbh_vlog \
          -L u065gioll25mvir_vlog \
          -t 1ps \
          -voptargs=+acc \
          hyperbus_tb

