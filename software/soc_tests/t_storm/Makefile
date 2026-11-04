APP := t_storm
XLEN:=64

include $(shell pwd)/../common.mk
RISCV_FLAGS += -I$(SW_HOME)/accel/include
RISCV_FLAGS += -I$(SW_HOME)/eth/include

# pe_fw.h (tracked): the APMU PE's program, pe_fw.S (rv32im), as the words t_storm.c copies into the ISPM.
# Regenerate it after a change to pe_fw.S: make pe_fw.h
pe_fw.h: pe_fw.S
	riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -Wl,-Ttext=0x10427000 -o pe_fw.elf $<
	riscv64-unknown-elf-objcopy -O binary pe_fw.elf pe_fw.bin
	python3 -c "import struct; d = open('pe_fw.bin', 'rb').read(); \
	  w = struct.unpack('<%dI' % (len(d) // 4), d); \
	  print('// generated from pe_fw.S by make pe_fw.h: do not edit'); \
	  print('static const uint32_t pe_fw[] = {'); \
	  [print('  0x%08x,' % x) for x in w]; print('};')" > $@
	rm -f pe_fw.elf pe_fw.bin
