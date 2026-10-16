#!/usr/bin/env python3
"""Rewrite always_comb blocks so that output-port variables are written once at the end (xsim propagates
transient intermediate values of default-then-override writes through ports; Questa only the final value)."""
import re, sys
path, ports = sys.argv[1], sys.argv[2:]
L = open(path).read().split('\n')
# port types
ptype = {}
for l in L:
    m = re.match(r'^\s*output\s+(.+?)\s+(' + '|'.join(ports) + r')\s*[,)]?\s*(//.*)?$', l)
    if m: ptype[m.group(2)] = m.group(1).strip()
for p in ports:
    if p in ptype: continue
    for l in L:  # internal variable declarations: '<type> a, b, p;' (single line)
        m = re.match(r'^\s*((?:logic|bit|T|[A-Za-z_]\w*_[te])(?:\s*\[[^\]]*\])*)\s+((?:\w+\s*,\s*)*)' + p + r'\s*[;,]', l)
        if m: ptype[p] = m.group(1).strip(); break
for p in ports:
    if p in ptype: continue
    for k, l in enumerate(L):
        if re.match(r'^\s*(?:\w+\s*,\s*)*' + p + r'\s*[;,]', l) and 'always' not in l and '=' not in l:
            for b in range(k, max(-1, k-6), -1):
                m = re.match(r'^\s*((?:logic|bit|[A-Za-z_]\w*_[te])(?:\s*\[[^\]]*\])*)\s+', L[b])
                if m: ptype[p] = m.group(1).strip(); break
            if p in ptype: break
missing = [p for p in ports if p not in ptype]
assert not missing, ("types not found", missing)
out = []; i = 0; nblk = 0
while i < len(L):
    l = L[i]
    if re.match(r'^\s*always_comb\s*(\(\*.*?\*\)\s*)?begin', l):
        # find block end by begin/end nesting
        depth = 0; j = i
        while True:
            depth += len(re.findall(r'\bbegin\b', L[j])) - len(re.findall(r'\bend\b', L[j]))
            if depth == 0: break
            j += 1
        blk = L[i:j+1]
        body = '\n'.join(blk)
        touched = {}
        for p in ports:
            # members written: p.member... = or p[...].member = or p = / p[..] =
            for m in re.finditer(r'\b' + p + r'\b(\[[^\]]*\])?(\.(\w+))?[.\w\[\]]*\s*(<=|=)(?!=)', body):
                if m.group(3): touched.setdefault(p, set()).add(m.group(3))
                else: touched.setdefault(p, set()).add('*')
        if touched:
            nblk += 1
            for p, mem in touched.items():
                if '*' in mem:
                    body = re.sub(r'\b' + p + r'\b', p + '_xc', body)
                    tail = f'      {p} = {p}_xc;'
                else:
                    for mname in mem:
                        body = re.sub(r'\b' + p + r'(\[[^\]]*\])?\.' + mname + r'\b', lambda m: p + '_xc' + (m.group(1) or '') + '.' + mname, body)
                    tail = '\n'.join(f'      {p}.{mname} = {p}_xc.{mname};' for mname in sorted(mem))
                # insert before the final 'end' of the block
                body = body.rsplit('end', 1)
                body = body[0] + tail + ' // xsim: outputs assigned once\n    end' + body[1]
        out.extend(body.split('\n')); i = j + 1
    else:
        out.append(l); i += 1
# declare shadows after the port list (first line containing ');' after module header)
# declare each shadow inside the module that declares the original (right after that module's port list)
def decl_line_of(name):
    for i, l in enumerate(out):
        if re.match(r'^\s*(output\s+)?\S.*\b' + name + r'\s*([;,)]|$)', l) and 'xsim: shadow' not in l and '_xc' not in l: return i
    return None
ins = {}
for p in ports:
    i = decl_line_of(p); assert i is not None, p
    if re.match(r'^\s*output\b', out[i]):
        j = i
        while j > 0 and not re.match(r'^\s*module\b', out[j]): j -= 1
        k = j
        while not re.match(r'^\s*\);\s*$', out[k]): k += 1
    else:
        k = i
        while ';' not in out[k]: k += 1
    ins.setdefault(k, []).append(f'  {ptype[p]} {p}_xc; // xsim: shadow of {p}')
for k in sorted(ins, reverse=True):
    out[k+1:k+1] = ins[k]
txt = '\n'.join(out)
open(path, 'w').write(txt); print(f'{path}: {nblk} blocks rewritten, ports {ports}')
