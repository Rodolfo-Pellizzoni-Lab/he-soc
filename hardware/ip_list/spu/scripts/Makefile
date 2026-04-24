clean:
	rm -rf work
	rm -rf synth
	rm -rf spu_log
	rm -rf axi_log
	rm -f transcript
	rm -f *.log
	rm -f *.wlf
	rm -f *.vstf
	rm -f *.jou
	rm -f *.txt	

sim:
	./compile_vsim.sh
	./run_vsim.sh

synth: clean
	./compile_synth.sh
	vivado -mode batch -source run.tcl
