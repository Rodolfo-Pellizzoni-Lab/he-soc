# root pathelf-bin
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
root-dir := $(dir $(mkfile_path))

# questa library
library        ?= work

# QuestaSim Version
questa_version ?= -10.7b

# additional definess
defines        ?=

# Compile and sim flags
compile_flag     += +cover=bcfst+/dut -incr -64 -nologo -svinputport=compat -override_timescale 1ns/1ps -quiet -suppress 13262 -suppress 3999 -suppress 3009 -suppress 8386 -suppress 8360 -permissive +define+$(defines)
uvm-flags        += +UVM_NO_RELNOTES +UVM_VERBOSITY=LOW
questa-flags     += -t 1ns -64 -coverage -classdebug -suppress 3999 -suppress 3009 -suppress 8360 -suppress 8386 $(gui-sim) $(QUESTASIM_FLAGS)
compile_flag_vhd += -64 -nologo -quiet -2008

compile_flag_bender   += +cover=bcfst+/dut -incr -64 -nologo -quiet -suppress 13262 -suppress 8386  -permissive
questa-cmd   := -do " set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log -r /*; run -all;"

compile_script := compile.tcl

# Top level module to compile
top_level      ?= eth_tb

BENDER:=./bender

util := $(addprefix $(root-dir), $(util))

bender:
	curl --proto '=https' --tlsv1.2 https://fabianschuiki.github.io/bender/init -sSf | sh -s -- 0.22.0

update:
	$(BENDER) update

scripts_tb:
	$(BENDER) script vsim \
		--vlog-arg="$(compile_flag) -work  $(library) -suppress 2583 " --vcom-arg="$(compile_flag_vhd)-work  $(library) -pedanticerrors" \
    -t eth_test  > compile.tcl

scripts_macro:
	$(BENDER) script vsim \
		--vlog-arg="$(compile_flag) -work  $(library) -suppress 2583 " --vcom-arg="$(compile_flag_vhd)  -work  $(library) -pedanticerrors" \
    -t gf22_macro -t eth_test > compile.tcl

build: bendertb
	vopt $(compile_flag) -suppress 3053 -suppress 8885 -work $(library)  $(top_level) -o $(top_level)_optimized +acc -check_synthesis

build_macro: bendertb_macro
	vopt $(compile_flag) -suppress 3053 -suppress 8885 -work $(library)  $(top_level) -o $(top_level)_optimized +acc -check_synthesis

run:
	vsim +permissive $(questa-flags) $(questa-cmd) -suppress 3053 -suppress 8885 -suppress 3999 -suppress 8386 -suppress 8360 -lib $(library)  \
	$(uvm-flags) $(QUESTASIM_FLAGS) \
	${top_level}_optimized +permissive-off| tee sim.log

$(library):
	vlib${questa_version} $(library)

bendertb: benderrun
	touch $(library)/.build-tb

bendertb_macro: benderrun_macro
	touch $(library)/.build-tb

benderrun: libbender $(util) $(library)
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	vsim -c -do 'source $(compile_script); quit'
	touch $(library)/.build-srcs

benderrun_macro: libbender $(util) $(library)
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	vsim -c -do 'source gf22/modelsim/libraries.sh; source $(compile_script); quit'
	touch $(library)/.build-srcs

libbender:
	vlib work
	vmap work ./work

clean:
	rm -f *.log
	rm -f transcript
	rm -f modelsim.ini
	rm -f compile.tcl
	rm -rf work
	rm -f vsim.wlf

all: clean scripts_tb build run