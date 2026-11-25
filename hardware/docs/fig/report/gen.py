import sys, collections, html
S = "/tmp/claude-1000/-home-mhassen-he-soc/508b8202-db72-4036-ab02-c975d3dae090/scratchpad"
sys.argv = ["x", S + "/e10_m2.out"]
exec(open(S + "/parse10.py").read().split('if __name__')[0])
acc = collections.defaultdict(list)
for r in runs: acc[(r["atk"], r["cap"], r["mode"])].append(r)
def avg(k, f): v = [f(r) for r in acc[k]]; return sum(v) / len(v)
alone = avg(("none", "-", 2), lambda r: r["victim"])

def chart(groups, ymax, yticks, w=560, h=250, fmt="%.1f", ref=None, ylabel="", title=""):
    """groups: [(label, [bar, ...])], bar = (value label or None, [(value, css class, tooltip)])"""
    L, R, T, B = 44, 34, 18, 46
    pw, ph = w - L - R, h - T - B
    y = lambda v: T + ph - ph * v / ymax
    o = ['<svg viewBox="0 0 %d %d" role="img" aria-label="%s">' % (w, h, html.escape(title))]
    for t in yticks:
        o.append('<line class="grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="tick" x="%d" y="%.1f" text-anchor="end">%s</text>' % (L, w - R, y(t), y(t), L - 6, y(t) + 3.5, ("%g" % t)))
    gw = pw / len(groups)
    for gi, (glabel, bars) in enumerate(groups):
        n = len(bars); bw = min(34, gw * 0.72 / n); x0 = L + gw * gi + (gw - bw * n - 3 * (n - 1)) / 2
        for bi, (blabel, segs) in enumerate(bars):
            x = x0 + bi * (bw + 3); base = 0
            for v, cls, tip in segs:
                if v <= 0: continue
                o.append('<rect class="%s" x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2"><title>%s</title></rect>' % (cls, x, y(base + v), bw, max(0.8, y(base) - y(base + v) - (1.5 if base else 0)), html.escape(tip)))
                base += v
            if blabel: o.append('<text class="val" x="%.1f" y="%.1f" text-anchor="middle">%s</text>' % (x + bw / 2, y(base) - 4, blabel))
        for li, line in enumerate(glabel.split("\n")):
            o.append('<text class="xl" x="%.1f" y="%d" text-anchor="middle">%s</text>' % (L + gw * gi + gw / 2, T + ph + 15 + 12 * li, html.escape(line)))
    o.append('<line class="axis" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/>' % (L, w - R, y(0), y(0)))
    if ref:
        o.append('<line class="ref" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="tick" x="%d" y="%.1f">%s</text>' % (L, w - R, y(ref[0]), y(ref[0]), w - R + 3, y(ref[0]) + 3.5, ref[1]))
    if ylabel: o.append('<text class="tick" x="%d" y="10">%s</text>' % (2, html.escape(ylabel)))
    o.append("</svg>"); return "".join(o)

def legend(items): return '<div class="legend">' + "".join('<span><i class="sw %s"></i>%s</span>' % (c, n) for c, n in items) + "</div>"

# A: before / after the hardware fix
A = [("1 capped\nreader", 24.7, 27.5), ("2 capped\nreaders", 20.2, 27.3), ("3 capped\nreaders", 18.2, 27.2), ("3 readers,\n6 ms period", 9.0, 27.2), ("3 readers,\nsmallest cap", 16.9, 25.4)]
chA = chart([(g, [("%.1f" % b, [(b, "s2", "before: %.1f MB/s" % b)]), ("%.1f" % a, [(a, "s1", "after: %.1f MB/s" % a)])]) for g, b, a in A], 32, [0, 10, 20, 30], w=640, ref=(28.2, "alone"), ylabel="victim, MB/s", title="Victim bandwidth before and after the regulator fix")
# B: JTAG samples
Bd = [("capped\ncore A", 33, 2), ("capped\ncore B", 29, 4), ("capped\ncore C", 30, 7), ("victim's\ncore", 8, 10)]
chB = chart([(g, [("%d %%" % b, [(b, "s2", "kernel ID only: %d %% of samples" % b)]), ("%d %%" % a, [(a, "s1", "kernel + firmware IDs: %d %%" % a)])]) for g, b, a in Bd], 40, [0, 10, 20, 30, 40], w=520, ylabel="samples found in firmware, %", title="Share of JTAG samples in firmware")
# C: loader variants
Cd = [("cap 9.4 MB/s", 27.2, 27.3, 27.2), ("cap 0.23 MB/s", 21.5, 27.35, 27.7), ("cap 0.05 MB/s", 26.8, 25.3, 27.5)]
names = ["no separate IDs", "kernel ID", "kernel + firmware IDs"]
chC = chart([(g, [("%.1f" % v, [(v, "s%d" % (i + 1), "%s: %.1f MB/s" % (names[i], v))]) for i, v in enumerate(vs)]) for g, *vs in Cd], 32, [0, 10, 20, 30], w=640, ref=(28.0, "alone"), ylabel="victim, MB/s", title="Victim bandwidth by loader configuration")
# D: policy matrix
cols = [("user", "5", "User-mode reader", "Only timer ticks enter the kernel. Cap 0.23 MB/s.", 0.23), ("sys", "205", "System calls", "pread: the kernel copies for the caller. Cap 9.4 MB/s.", 9.4),
        ("pf", "205", "Page faults", "The kernel clears pages for the caller. Cap 9.4 MB/s.", 9.4), ("loop", "205", "Buffered writes", "Writeback and loop workers copy later. Cap 9.4 MB/s.", 9.4)]
pol = {1: "stock", 2: "PLZA", 3: "selective", 4: "selective\n+ tag"}
panels = []
for atk, cap, title, sub, capmb in cols:
    modes = [m for m in (1, 2, 3, 4) if (atk, cap, m) in acc]
    top = chart([(pol[m], [("%.0f %%" % (100 * avg((atk, cap, m), lambda r: r["victim"]) / alone), [(100 * avg((atk, cap, m), lambda r: r["victim"]) / alone, "sn", "victim: %.1f MB/s" % avg((atk, cap, m), lambda r: r["victim"]))])]) for m in modes],
                118, [0, 50, 100], w=300, h=190, ylabel="victim, % of alone", title=title + ": victim bandwidth")
    if atk == "user":
        g = [(pol[m], [("%.2f" % avg((atk, cap, m), lambda r: sum(r["work"])), [(avg((atk, cap, m), lambda r: sum(r["work"])), "s1", "tenant's readers: %.2f MB/s" % avg((atk, cap, m), lambda r: sum(r["work"])))])]) for m in modes]
        bot = chart(g, 0.3, [0, 0.1, 0.2, 0.3], w=300, h=200, ref=(capmb, "cap"), ylabel="what the tenant's readers get, MB/s", title=title + ": tenant progress")
    else:
        g = []; mx = 0
        for m in modes:
            segs = []
            for cls, mc, nm in (("s1", 2, "tenant's group"), ("s2", 8, "kernel's group"), ("s3", 0, "default group")):
                base = avg(("none", "-", 2), lambda r: r["mc"].get(mc, 0)) if mc != 2 else 0
                v = max(0, avg((atk, cap, m), lambda r: r["mc"].get(mc, 0)) - base); segs.append((v, cls, "%s: %.1f MB/s" % (nm, v)))
            tot = sum(s[0] for s in segs); mx = max(mx, tot); g.append((pol[m], [("%.1f" % tot, segs)]))
        bot = chart(g, 25, [0, 5, 10, 15, 20, 25], w=300, h=200, ref=(capmb, "cap"), ylabel="traffic the tenant causes, MB/s", title=title + ": who is charged")
    panels.append('<div class="panel"><h4>%s</h4><p class="sub">%s</p>%s%s</div>' % (title, sub, top, bot))

# E-G: memory-bound runs (DRAM model LAT 100, OCC16 320; capacity 17 MB/s; cap 3.4)
Ed = [("model off", 27.7, 26.3), ("latency 1, 7 cycles/beat\n57 MB/s bus, reads late", 21.2, 12.9), ("latency 100, 10 cycles/beat\n40 MB/s bus", 11.0, 8.6), ("latency 100, 20 cycles/beat\n20 MB/s bus (used)", 8.5, 4.4)]
chE = chart([(g_, [("%.1f" % a_, [(a_, "s1", "victim alone: %.1f MB/s" % a_)]), ("%.1f" % w_, [(w_, "s2", "next to three uncapped readers: %.1f MB/s" % w_)])]) for g_, a_, w_ in Ed], 32, [0, 10, 20, 30], w=760, ylabel="victim, MB/s", title="Victim bandwidth alone and next to three uncapped readers, by DRAM model setting")
MA = 8.45
Md = [("readers\nno cap", 6.70, 9.02, 0.20, 0.07), ("readers\ncapped", 8.05, 3.36, 0.10, 0.03), ("writers\nno cap", 2.42, 9.43, 0.29, 1.22), ("writers\ncapped", 5.98, 3.32, 0.14, 0.37),
      ("system calls\nPLZA", 3.95, 0.01, 10.43, 0.0), ("system calls\nselective + tag", 6.58, 3.32, 0.17, 0.32), ("buffered writes\nselective", 5.09, 2.92, 3.37, 0.43), ("buffered writes\nselective + tag", 6.27, 3.16, 0.15, 0.31)]
chF = chart([(d[0], [("%.0f %%" % (100 * d[1] / MA), [(100 * d[1] / MA, "sn", "victim: %.2f MB/s" % d[1])])]) for d in Md], 118, [0, 50, 100], w=880, h=230, ylabel="victim, % of alone", title="Memory-bound: what the victim keeps")
chG = chart([(d[0], [("%.1f" % sum(d[2:]), [(d[2], "s1", "tenant's group: %.1f MB/s" % d[2]), (d[3], "s2", "kernel's group: %.1f MB/s" % d[3]), (d[4], "s3", "default group: %.1f MB/s" % d[4])])]) for d in Md], 13, [0, 4, 8, 12], w=880, h=250, ref=(3.4, "cap"), ylabel="traffic the tenant causes, MB/s", title="Memory-bound: who is charged")

# Clean baselines (baseline.sh on bitstream wbpend_4c): medians per (victim, tenants, level)
import re, statistics as st
FIG = "/home/mhassen/he-soc/hardware/docs/fig/"
def load(fn):
    c = collections.defaultdict(list)
    for l in open(FIG + fn):
        m = re.match(r"RES rep=(\d+) v=(\S+) t=(\S+) reg=(\S+) part=(\d) model=(\S+) cap=(\d+) \| victim=(\S*) t2=(\S*) t3=(\S*) t0=(\S*) \| (.*)", l)
        if not m: continue
        f = lambda s: float(s) if s else None
        ten = [f(m.group(i)) for i in (9, 10, 11)]
        c[(m.group(2), m.group(3), m.group(4))].append((f(m.group(8)), sum(x for x in ten if x is not None) if any(x is not None for x in ten) else None))
    return c
BP, BS = load("baseline_partitioned_wbpend.txt"), load("baseline_shared_wbpend.txt")
vic = lambda c, k: st.median([r[0] for r in c[k]])
ten = lambda c, k: st.median([r[1] for r in c[k]])
TN = [("user", "readers"), ("uwr", "writers"), ("sys", "system\ncalls"), ("loop", "buffered\nwrites")]
VN = [("user", "Reader", "MB/s read"), ("uwr", "Writer", "MB/s of lines written"), ("sys", "System-call copier", "MB/s copied")]
LV = [("off", "sn", "no regulator"), ("fair", "s2", "regulator, equal shares"), ("cap", "s1", "tenants capped")]
def bpanels(c):
    o = []
    for v, vname, unit in VN:
        base = {"off": vic(c, (v, "none", "off")), "fair": vic(c, (v, "none", "fair")), "cap": vic(c, (v, "none", "fair"))}
        g = [(tl, [("%d" % round(100 * vic(c, (v, t_, lv)) / base[lv]), [(100 * vic(c, (v, t_, lv)) / base[lv], cls, "%s: %.2f MB/s, %d %% of alone" % (ln, vic(c, (v, t_, lv)), round(100 * vic(c, (v, t_, lv)) / base[lv])))]) for lv, cls, ln in LV]) for t_, tl in TN]
        o.append('<div class="panel"><h4>Victim: %s</h4><p class="sub">Alone: %.2f %s. Bars by the kind of the three tenants.</p>%s</div>' % (vname.lower(), base["off"], unit, chart(g, 118, [0, 50, 100], w=440, h=230, ylabel="victim, % of itself alone", title="%s victim, share of its solo rate by tenant kind and protection level" % vname)))
    return "".join(o)
# H: shared cache against partitioned cache, capped tenants, reader victim
pct = lambda c, t_: 100 * vic(c, ("user", t_, "cap")) / vic(c, ("user", "none", "fair"))
chH = chart([(tl.replace("\n", " "), [("%.0f %%" % pct(BS, t_), [(pct(BS, t_), "s2", "shared cache: %.2f MB/s" % vic(BS, ("user", t_, "cap")))]), ("%.0f %%" % pct(BP, t_), [(pct(BP, t_), "s1", "partitioned cache: %.2f MB/s" % vic(BP, ("user", t_, "cap")))])]) for t_, tl in TN], 118, [0, 50, 100], w=640, h=230, ylabel="victim, % of alone", title="Reader victim next to capped tenants, shared cache against partitioned cache")
rows = []
for t_, tl in (("user", "Readers"), ("uwr", "Writers"), ("sys", "System-call copiers"), ("loop", "Buffered writers")):
    for c, cn in ((BS, "shared"), (BP, "partitioned")):
        rows.append('          <tr><td>%s</td><td>%s</td>%s</tr>' % (tl if cn == "shared" else "", cn, "".join('<td class="num">%.2f</td>' % ten(c, (v, t_, "cap")) for v in ("none", "user", "uwr"))))
# I: bare metal t_wbhol, before / after the write-stage change (board, model 100/100/320)
chI = chart([(g_, [("%d %%" % b_, [(b_, "s2", "write stage waits for each acknowledgement: %d %% of alone" % b_)]), ("%d %%" % a_, [(a_, "s1", "write stage moves on: %d %% of alone" % a_)])]) for g_, b_, a_ in (("next to readers", 92, 93), ("next to writers", 77, 87))], 118, [0, 50, 100], w=460, h=220, ylabel="victim, % of alone", title="Bare-metal reader next to paced readers and writers, before and after the write-stage change")
# J: cap sweep (partitioned): what the victim keeps as the tenants' cap goes down
SW = load("baseline_cap_sweep_wbpend.txt")
CL = [("cap", "s2", "3.4 MB/s"), ("cap51", "s3", "0.85 MB/s"), ("cap3", "s1", "0.05 MB/s")]
def swp(v, t_, lv): return 100 * vic(SW, (v, t_, lv)) / vic(SW, (v, "none", "fair"))
chJ = chart([(gl, [("%d %%" % round(swp(v, t_, lv)), [(swp(v, t_, lv), cls, "tenants capped at %s: victim %.2f MB/s, %d %% of alone" % (ln, vic(SW, (v, t_, lv)), round(swp(v, t_, lv))))]) for lv, cls, ln in CL])
             for v, t_, gl in (("user", "user", "reader\nnext to readers"), ("user", "uwr", "reader\nnext to writers"), ("uwr", "user", "writer\nnext to readers"), ("uwr", "uwr", "writer\nnext to writers"))],
            118, [0, 50, 100], w=700, h=240, ylabel="victim, % of itself alone", title="What the victim keeps as the cap on the three tenants is lowered")
LB = legend([(cls, ln) for _, cls, ln in LV])
tpl = open(S + "/report/template.html").read()
out = tpl.replace("{{CHART_A}}", chA + legend([("s2", "before (bitstream <code>qosgate_4c</code>)"), ("s1", "after (<code>qosfix4_4c</code>)")])) \
         .replace("{{CHART_B}}", chB + legend([("s2", "kernel ID only"), ("s1", "kernel + firmware IDs")])) \
         .replace("{{CHART_C}}", chC + legend([("s1", names[0]), ("s2", names[1]), ("s3", names[2])])) \
         .replace("{{CHART_E}}", chE + legend([("s1", "victim alone"), ("s2", "victim next to three uncapped readers")])) \
         .replace("{{CHART_F}}", '<div class="sx">' + chF + "</div>").replace("{{CHART_G}}", '<div class="sx">' + chG + "</div>" + legend([("s1", "charged to the tenant's group (capped)"), ("s2", "charged to the kernel's group"), ("s3", "charged to the default group")])) \
         .replace("{{CHART_H}}", chH + legend([("s2", "shared cache"), ("s1", "victim and tenants in separate ways")])) \
         .replace("{{CHART_I}}", chI + legend([("s2", "write stage waits for each acknowledgement"), ("s1", "write stage moves on (table of four)")])) \
         .replace("{{CHART_J}}", chJ + legend([(cls, "tenants capped at " + ln) for _, cls, ln in CL])) \
         .replace("{{PANELS_BP}}", bpanels(BP)).replace("{{PANELS_BS}}", bpanels(BS)).replace("{{LEGEND_B}}", LB).replace("{{TENANT_ROWS}}", "\n".join(rows)) \
         .replace("{{PANELS}}", "".join(panels) ) \
         .replace("{{LEGEND_D}}", legend([("sn", "victim"), ("s1", "charged to the tenant's group (capped)"), ("s2", "charged to the kernel's group"), ("s3", "charged to the default group")])) \
         .replace("{{ALONE}}", "%.1f" % alone)
open(S + "/report/memory-qos-report.html", "w").write(out); print(len(out))
