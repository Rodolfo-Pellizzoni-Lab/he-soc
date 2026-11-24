#!/usr/bin/env python3
# parse10.py <e10 output>...: one row per run
import sys, re, json
runs = []
for f in sys.argv[1:]:
    cur = None
    for l in open(f):
        m = re.match(r"== mode (\d) tenant (\w+) cap (\S+)/(\d+)", l)
        if m:
            cur = dict(mode=int(m[1]), atk=m[2], cap=m[3], victim=None, stall=None, maxms=None, mc={}, work=[], file=f); runs.append(cur); continue
        if cur is None: continue
        if l.startswith("1:g1"):
            t = l.split(); cur["victim"] = float(t[1]); cur["maxms"] = int(t[3]) / 50000.0; cur["stall"] = float(t[5].rstrip("%"))
        m = re.match(r"mcid\s+(\d+):\s+([\d.]+) MB/s", l)
        if m: cur["mc"][int(m[1])] = float(m[2])
        m = re.match(r"\w+ cpu \d: ([\d.]+) MB/s of work", l)
        if m: cur["work"].append(float(m[1]))
if __name__ == "__main__":
    names = {1: "task (stock)", 2: "kernel (PLZA)", 3: "select", 4: "select+tag"}
    print("%-6s %-6s %-14s %7s %7s | %7s %7s %7s %7s | %s" % ("tenant", "cap", "policy", "victim", "max ms", "tenant", "kernel", "root", "firmw", "tenant work MB/s"))
    for r in runs:
        mc = r["mc"]
        print("%-6s %-6s %-14s %7.2f %7.1f | %7.2f %7.2f %7.2f %7.2f | %s" % (r["atk"], r["cap"], names[r["mode"]], r["victim"] or 0, r["maxms"] or 0,
              mc.get(2, 0), mc.get(8, 0), mc.get(0, 0), mc.get(9, 0), "%.2f" % sum(r["work"]) if r["work"] else "-"))
