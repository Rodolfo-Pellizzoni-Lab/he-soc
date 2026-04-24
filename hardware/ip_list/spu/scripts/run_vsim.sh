set -e 

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[ ! -z "$VSIM" ] || VSIM=vsim

# Define the name of the testbench module
TB_MODULE=tb_spu

# Run the simulation and save the results to a log file
vsim -t 1ps -voptargs="+acc +cover=bcesfx" $TB_MODULE -do "log -r /*; run -all ; quit" | tee sim.log

# Check if the simulation completed successfully (0 errors)
grep "Errors: 0," sim.log

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
