#!/usr/bin/env python3
"""bootrom_sv2coe.py [bootrom.sv] [boot_code.coe]: the FPGA boot ROM image from the simulated one.

The FPGA builds do not use bootrom.sv: fpga/ddr/boot_rom.sv reads word addr[12:3] of a 1024 x 64-bit Xilinx ROM
(dist_mem_gen xilinx_rom_bank_1024x64) initialised from fpga/alsaqr/tcl/ips/boot_rom/boot_code.coe. This writes that
file from bootrom.sv's words, so the board boots what xsim verifies: word i of the .coe is mem[i], and the words past
RomSize are 0, which is what bootrom.sv returns there. Regenerate the IP afterwards (fpga/alsaqr/tcl/ips/boot_rom:
vivado -mode batch -source run.tcl, then copy the outputs into ip/ as its Makefile does).
"""
import re
import sys

DEPTH = 1024   # words of xilinx_rom_bank_1024x64 (fpga/alsaqr/tcl/ips/boot_rom/run.tcl)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else 'bootrom.sv'
    dst = sys.argv[2] if len(sys.argv) > 2 else '../../fpga/alsaqr/tcl/ips/boot_rom/boot_code.coe'
    text = open(src).read()
    size = int(re.search(r'localparam\s+int\s+RomSize\s*=\s*(\d+)\s*;', text).group(1))
    body = text[text.index('mem = {'):text.index('};')]
    words = re.findall(r"64'h([0-9a-fA-F]{16})", body)
    if len(words) != size:
        sys.exit(f'{src}: {len(words)} words, RomSize {size}')
    if size > DEPTH:
        sys.exit(f'{src}: {size} words do not fit the {DEPTH}-word FPGA ROM')
    mem = [w.lower() for w in reversed(words)]   # the list runs from mem[RomSize-1] down to mem[0]
    mem += ['0' * 16] * (DEPTH - size)
    with open(dst, 'w') as f:
        f.write('memory_initialization_radix = 16;\nmemory_initialization_vector =\n')
        f.write(',\n'.join(mem) + ';\n')
    print(f'{dst}: the {size} words of {src}, then {DEPTH - size} zero words')


if __name__ == '__main__':
    main()
