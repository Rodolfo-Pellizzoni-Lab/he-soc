vsim apb_fll_tb -t 1ps -voptargs=+acc -voptargs=-check_synthesis -classdebug

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
add log -r /*

delete wave *
