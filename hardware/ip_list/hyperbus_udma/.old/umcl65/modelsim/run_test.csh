#! /bin/tcsh -f

set VER=10.6b
set LIB=work

vsim-${VER} -work ${LIB} hyperbus_tb -t 1ps -voptargs=+acc
