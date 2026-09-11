#!/usr/bin/env python3
"""Convert a bender 'script vsim' Tcl file into a bash script of xvhdl/xvlog calls
(one call per vlog/vcom block, preserving each block's +incdir and +define).

usage: vsim2xsim.py <vsim.tcl> <compile.sh> <hardware root> [<comma-separated global defines>]
"""
import re, sys
src, out, root = sys.argv[1], sys.argv[2], sys.argv[3]
glob_defs = [d for d in sys.argv[4].split(',') if d] if len(sys.argv) > 4 else []
# IP-internal testbenches are not part of the SoC and several do not parse in xsim
prune = re.compile(r'/ip_list/[^/]+/(test|tb|testbench)/|/rtl/verif/|/common_verification/test/')
txt = open(src).read().replace('\\\n', ' ')
blocks = []
for line in txt.splitlines():
    line = line.strip()
    m = re.search(r'(vlog|vcom)\b', line)
    if not m or 'catch' not in line:
        continue
    kind = m.group(1)
    incs = re.findall(r'\+incdir\+"?\$ROOT(/[^"\s]+)', line)
    defs = re.findall(r'\+define\+([A-Za-z0-9_]+(?:=[^\s+"]+)?)', line)
    files = re.findall(r'"\$ROOT(/[^"]+)"', line)
    files = [root + f for f in files if not prune.search(f)]
    if files:
        blocks.append((kind, [root + i for i in incs], defs, files))
with open(out, 'w') as o:
    o.write('#!/bin/bash\nset -o pipefail\n')
    for n, (kind, incs, defs, files) in enumerate(blocks):
        if kind == 'vcom':
            cmd = 'xvhdl -2008 -work work ' + ' '.join(files)
        else:
            cmd = ('xvlog -sv -work work -L uvm ' + ' '.join('-i ' + i for i in incs) + ' ' +
                   ' '.join('-d ' + d for d in glob_defs + defs) + ' ' + ' '.join(files))
        o.write(f'echo "### block {n} ({kind}, {len(files)} files)"\n{cmd} || {{ echo "### FAILED block {n}"; exit 1; }}\n')
print(f'{len(blocks)} blocks written to {out}')
