import sys, collections
sys.path.insert(0, "/home/mhassen/he-soc/hardware/docs/fig")
sys.argv = ["x", sys.path[0] + "/kernel_qos_id_policies.txt"]
src = open(sys.path[0] + "/parse10.py").read().split('if __name__')[0]; exec(src)
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
acc = collections.defaultdict(list)
for r in runs: acc[(r["atk"], r["cap"], r["mode"])].append(r)
def avg(k, f): v = [f(r) for r in acc[k]]; return sum(v) / len(v)
alone = avg(("none", "-", 2), lambda r: r["victim"])
INK, SUB, GRID, SURF = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
C = {"tenant": "#2a78d6", "kernel": "#eb6834", "default": "#1baf7a"}
cols = [("user", "5", "User-mode reader\n(only timer ticks enter the kernel)", 0.23),
        ("sys", "205", "System calls\n(pread: the kernel copies)", 9.4),
        ("pf", "205", "Page faults\n(the kernel clears pages)", 9.4),
        ("loop", "205", "Buffered writes\n(writeback + loop workers copy later)", 9.4)]
pol = {1: "task's ID\n(stock)", 2: "kernel ID\n(PLZA)", 3: "selective", 4: "selective\n+ work tag"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": GRID, "text.color": INK, "axes.labelcolor": SUB, "xtick.color": SUB, "ytick.color": SUB})
fig, ax = plt.subplots(2, 4, figsize=(13.5, 6.6), facecolor=SURF, gridspec_kw={"height_ratios": [1, 1], "hspace": 0.55, "wspace": 0.28})
for j, (atk, cap, title, capmb) in enumerate(cols):
    modes = [m for m in (1, 2, 3, 4) if (atk, cap, m) in acc]
    x = range(len(modes)); a = ax[0][j]; b = ax[1][j]
    for q in (a, b):
        q.set_facecolor(SURF); q.spines[["top", "right", "left"]].set_visible(False); q.yaxis.grid(True, color=GRID, lw=0.8); q.set_axisbelow(True); q.tick_params(length=0)
        q.set_xticks(list(x)); q.set_xticklabels([pol[m] for m in modes], fontsize=8.5); q.set_xlim(-0.6, len(modes) - 0.4)
    v = [100 * avg((atk, cap, m), lambda r: r["victim"]) / alone for m in modes]
    a.bar(list(x), v, width=0.5, color=SUB)
    for xi, vi in zip(x, v): a.text(xi, vi + 2, "%.0f %%" % vi, ha="center", fontsize=9, color=INK)
    a.set_ylim(0, 118); a.set_yticks([0, 50, 100]); a.set_title(title, fontsize=10, color=INK, loc="left", pad=10)
    if j == 0: a.set_ylabel("victim's bandwidth,\n% of running alone")
    if j == 0:      # no kernel copies here: show what the tenant itself gets
        w = [avg((atk, cap, m), lambda r: sum(r["work"])) for m in modes]
        b.bar(list(x), w, width=0.5, color=C["tenant"])
        for xi, t in zip(x, w): b.text(xi, t + 0.008, "%.2f" % t, ha="center", fontsize=9, color=INK)
        b.axhline(capmb, color=INK, lw=1, ls=(0, (4, 3))); b.text(len(modes) - 0.42, capmb, " cap", va="center", ha="left", fontsize=8.5, color=INK, clip_on=False)
        b.set_ylim(0, 0.3); b.set_ylabel("what the tenant's readers get, MB/s\n(other columns: traffic it causes)")
        continue
    bot = [0] * len(modes)
    for name, mc in (("tenant", 2), ("kernel", 8), ("default", 0)):
        base = avg(("none", "-", 2), lambda r: r["mc"].get(mc, 0)) if mc != 2 else 0     # traffic there without any tenant
        h = [max(0, avg((atk, cap, m), lambda r: r["mc"].get(mc, 0)) - base) for m in modes]
        b.bar(list(x), h, width=0.5, bottom=bot, color=C[name], edgecolor=SURF, linewidth=1.5, label={"tenant": "the tenant's group (capped)", "kernel": "the kernel's group", "default": "the default group"}[name])
        bot = [p + q for p, q in zip(bot, h)]
    for xi, t in zip(x, bot): b.text(xi, t + max(bot) * 0.03, "%.1f" % t if t >= 1 else "%.2f" % t, ha="center", fontsize=9, color=INK)
    b.axhline(capmb, color=INK, lw=1, ls=(0, (4, 3))); b.text(len(modes) - 0.42, capmb, " cap", va="center", ha="left", fontsize=8.5, color=INK, clip_on=False)
    b.set_ylim(0, max(max(bot), capmb) * 1.22)
    if j == 0: b.set_ylabel("memory traffic the tenant causes,\nMB/s, by the group charged")
ax[1][3].legend(loc="upper center", bbox_to_anchor=(-1.35, -0.28), ncol=3, frameon=False, fontsize=9)
fig.suptitle("Which QoS ID should kernel work carry?  Three tenants hard-capped next to a streaming victim (AlSaqr, VCU118, Linux 7.2)", x=0.065, ha="left", fontsize=11.5, color=INK, y=0.985)
fig.text(0.065, 0.935, "Cap: 9.4 MB/s of 47 for the tenant's group (0.23 MB/s in the first column). Victim alone: %.1f MB/s." % alone, fontsize=9, color=SUB)
fig.subplots_adjust(top=0.82, bottom=0.14, left=0.065, right=0.975)
out = "/home/mhassen/he-soc/hardware/docs/fig/kernel_qos_id_policies.png"; fig.savefig(out, dpi=150, facecolor=SURF); print(out)
