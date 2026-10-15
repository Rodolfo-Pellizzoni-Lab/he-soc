#!/usr/bin/env python3
"""Plot the console log of t_sweep: cycles per dependent read against the array size.

    plot_sweep.py <uart.log or console text> [out.png] [--linear]

Reads the "SWEEP <mode> <KB> <cycles x100>" lines; one curve per mode (off = the real memory path, 1ghz = the DRAM
timing model with LAT_RD 80 / OCC16 20). The cache sizes of the SoC are marked: 16 KB L1 data cache (8 ways of 16-byte lines), 1 MB LLC (16 ways of 64-byte lines).
"""
import re
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

L1_KB, LLC_KB = 16, 1024
LABEL = {"off": "model off (VCU118 at 50 MHz)", "1ghz": "DRAM model: 1 GHz target, 80 ns, 6.4 GB/s"}


def read(path):
    data = {}
    for line in open(path, errors="replace"):
        m = re.match(r"\s*SWEEP\s+(\S+)\s+(\d+)\s+(\d+)", line.replace("\r", ""))
        if m:
            data.setdefault(m.group(1), []).append((int(m.group(2)), int(m.group(3)) / 100.0))
    return data


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    linear = "--linear" in sys.argv
    src = args[0]
    out = args[1] if len(args) > 1 else "sweep.png"
    data = read(src)
    if not data:
        sys.exit(f"no SWEEP lines in {src}")
    fig, ax = plt.subplots(figsize=(9, 4.5))
    for mode, pts in data.items():
        pts.sort()
        ax.plot([p[0] for p in pts], [p[1] for p in pts], marker="o", markersize=3, linewidth=1.8, label=LABEL.get(mode, mode))
    for kb, name in ((L1_KB, "L1 16 KB"), (LLC_KB, "LLC 1 MB")):
        ax.axvline(kb, color="grey", linestyle="--", linewidth=0.8)
        ax.text(kb, ax.get_ylim()[1] * 0.97, " " + name, color="grey", va="top", fontsize=9)
    if not linear:
        ax.set_xscale("log", base=2)
        ticks = [1, 4, 16, 64, 256, 1024, 4096]
        ax.set_xticks(ticks)
        ax.set_xticklabels([str(t) if t < 1024 else f"{t // 1024} MB" for t in ticks])
    ax.set_xlabel("Array size (KB)")
    ax.set_ylabel("Clock cycles per read")
    ax.set_title("Dependent read latency: random pointer chase, 16-byte elements, core 0")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="center right")
    ax.set_ylim(bottom=0)
    fig.tight_layout()
    fig.savefig(out, dpi=130)
    print(out)
    for mode, pts in data.items():
        print(mode, " ".join(f"{kb}:{c:.1f}" for kb, c in sorted(pts)))


if __name__ == "__main__":
    main()
