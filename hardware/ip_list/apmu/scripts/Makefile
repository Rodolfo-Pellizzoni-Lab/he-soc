compile_fpga ?=

synth-fpga: | ../Bender.lock
	bender script vivado -t fpga -t ddr -t xilinx -t tech_cells_generic_include_xilinx_xpm --define="$(compile_fpga)" > ./compile.tcl
	vivado -mode batch -source synth_run.tcl

clean:
	rm -rf synth_apmu
	rm -f vivado*.log
	rm -f vivado*.jou