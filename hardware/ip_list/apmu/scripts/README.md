## 1.1 (ToDo) Simulation 

## 1.2 Synthesis

Make sure that `ibex_core.sv` has `RegFile = ibex_pkg::RegFileFPGA`. 

Run the following commands:

    bender update
    ./compile_vsim.sh

This will generate the `compile.tcl` that Vivado needs for synthesis.
