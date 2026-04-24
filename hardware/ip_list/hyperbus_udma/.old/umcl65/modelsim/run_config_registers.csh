#! /bin/tcsh -f

set VER=10.6b
set LIB=work

vsim-${VER} -t 1ps -work ${LIB} config_registers_tb -voptargs=+acc
