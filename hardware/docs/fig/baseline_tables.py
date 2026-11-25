# Tables from baseline.sh output (alsaqr-software linux/resctrl): each workload against itself.
#   baseline_tables.py <RES file> [markdown]
# A cell is the median over the repetitions with the range in brackets. Percentages are of the same victim alone
# with the controller in the same state (off for "off", on for "fair" and "cap").
import re, sys, statistics as st, collections
NAME = {"user": "reader", "uwr": "writer", "sys": "system-call copy", "ucp": "user-mode copy", "loop": "buffered writes", "none": "-"}
runs = []
for l in open(sys.argv[1]):
    m = re.match(r"RES rep=(\d+) v=(\S+) t=(\S+) reg=(\S+) part=(\d) model=(\S+) cap=(\d+) \| victim=(\S*) t2=(\S*) t3=(\S*) t0=(\S*) \| (.*)", l)
    if not m: continue
    f = lambda s: float(s) if s else None
    mc = {int(a): float(b) for a, b in re.findall(r"mcid (\d+): ([\d.]+) MB/s", m.group(12))}
    ten = [f(m.group(i)) for i in (9, 10, 11)]
    runs.append(dict(rep=int(m.group(1)), v=m.group(2), t=m.group(3), reg=m.group(4), part=m.group(5), victim=f(m.group(8)),
                     ten=sum(x for x in ten if x is not None) if any(x is not None for x in ten) else None, mc=mc))
cell = collections.defaultdict(list)
for r in runs: cell[(r["v"], r["t"], r["reg"])].append(r)
def med(k, key):
    v = [key(r) for r in cell.get(k, []) if key(r) is not None]
    return (st.median(v), min(v), max(v), len(v)) if v else None
def fmt(x, base=None):
    if not x: return "-"
    s = "%.2f [%.2f-%.2f]" % x[:3]
    if base: s += " (%d %%)" % round(100 * x[0] / base[0])
    return s
victims = [v for v in ("user", "uwr", "ucp", "sys") if any(r["v"] == v for r in runs)]
tenants = [t for t in ("user", "uwr", "ucp", "sys", "loop") if any(r["t"] == t for r in runs)]
n = max((r["rep"] for r in runs), default=0)
idle = [r for r in runs if r["v"] == "none" and r["t"] == "none"]
bg = {m: st.median([r["mc"].get(m, 0.0) for r in idle]) for m in (0, 8, 9)} if idle else {0: 0.5, 8: 0.2, 9: 0.02}
print("%d runs, %d passes, cache %s" % (len(runs), n, "partitioned" if runs and runs[0]["part"] == "1" else "shared"))
print("idle system (nothing running), MB/s of memory traffic: default group %.2f, kernel %.2f, firmware %.2f" % (bg[0], bg[8], bg[9]))
# a run disturbed from outside (a login, a cron job) shows as traffic of the default group well above the idle level
# when neither side writes through the kernel; reported, not removed
odd = [r for r in runs if r["mc"].get(0, 0.0) > bg[0] + 0.6 and r["t"] in ("none", "user") and r["v"] in ("none", "user")]
print("runs of readers only with default-group traffic more than 0.6 MB/s above idle: %d" % len(odd))
for v in victims:
    a_off, a_on = med((v, "none", "off"), lambda r: r["victim"]), med((v, "none", "fair"), lambda r: r["victim"])
    print("\n### Victim: %s. Alone: %s MB/s with the controller off, %s with it on" % (NAME[v], fmt(a_off), fmt(a_on)))
    print("| Tenants (three) | No controller | Controller, equal shares | Tenants capped |\n|---|---|---|---|")
    for t in tenants:
        print("| %s | %s | %s | %s |" % (NAME[t], fmt(med((v, t, "off"), lambda r: r["victim"]), a_off),
              fmt(med((v, t, "fair"), lambda r: r["victim"]), a_on), fmt(med((v, t, "cap"), lambda r: r["victim"]), a_on)))
print("\n### Tenants: MB/s of work of the three together, and (in braces) the memory traffic charged to their group")
print("| Tenants | Next to | No controller | Controller, equal shares | Capped |\n|---|---|---|---|---|")
for t in tenants:
    for v in ["none"] + victims:
        row = []
        for reg in ("off", "fair", "cap"):
            w, tr = med((v, t, reg), lambda r: r["ten"]), med((v, t, reg), lambda r: r["mc"].get(2))
            row.append("%s {%s}" % (fmt(w), "%.1f" % tr[0] if tr else "-"))
        print("| %s | %s | %s |" % (NAME[t], "nobody" if v == "none" else "a " + NAME[v], " | ".join(row)))
print("\n### Memory traffic charged to the victim's group (MB/s), median")
print("| Victim | Tenants | No controller | Equal shares | Capped |\n|---|---|---|---|---|")
for v in victims:
    for t in ["none"] + tenants:
        print("| %s | %s | %s |" % (NAME[v], NAME[t], " | ".join(("%.1f" % med((v, t, reg), lambda r: r["mc"].get(1))[0]) if med((v, t, reg), lambda r: r["mc"].get(1)) else "-" for reg in ("off", "fair", "cap"))))
bad = [l.strip() for l in open(sys.argv[1]) if l.startswith("KILLED") or "oops=" in l and not l.rstrip().endswith("oops=0")]
print("\nruns that had to be killed or saw an oops: %d %s" % (len(bad), bad[:3]))
