**Note:** In this branch, the master and slave ports of the SPU are ACE_BUS instead of the AXI_BUS, as was the case in the master branch.

To run the testbench:

	
 	bender update
  
	cd scripts
 
	./compile_vsim.sh
 
	./run_vsim.sh

 	python3 post_sim_script.py <TbMasters> <TbNumReads> <TbNumWrites>
	
	
Things to do:

1. Generalize the spu_arbiter.sv
