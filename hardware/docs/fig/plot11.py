# Memory-bound variant of the kernel QoS-ID policy test (DRAM model LAT 100, OCC16 320) and the model calibration.
# Numbers from kernel_qos_id_policies_dram_model.txt and dram_model_calibration.txt (means where a case ran twice).
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
INK, SUB, GRID, SURF = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
C = {"victim": "#6b6a66", "tenant": "#2a78d6", "kernel": "#eb6834", "default": "#1baf7a", "alone": "#2a78d6", "with": "#eb6834"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": GRID, "text.color": INK, "axes.labelcolor": SUB, "xtick.color": SUB, "ytick.color": SUB})
def style(q):
    q.set_facecolor(SURF); q.spines[["top", "right", "left"]].set_visible(False); q.yaxis.grid(True, color=GRID, lw=0.8); q.set_axisbelow(True); q.tick_params(length=0)
ALONE, CAP = 8.45, 3.4
# label, victim MB/s, tenant group, kernel group, default group (alone baselines 0.18 / 0.36 subtracted)
D = [("readers\nno cap", 6.70, 9.02, 0.20, 0.07), ("readers\ncapped", 8.05, 3.36, 0.10, 0.03),
     ("writers\nno cap", 2.42, 9.43, 0.29, 1.22), ("writers\ncapped", 5.98, 3.32, 0.14, 0.37),
     ("system calls\nPLZA", 3.95, 0.01, 10.43, 0.0), ("system calls\nselective + tag", 6.58, 3.32, 0.17, 0.32),
     ("buffered writes\nselective", 5.09, 2.92, 3.37, 0.43), ("buffered writes\nselective + tag", 6.27, 3.16, 0.15, 0.31)]
fig, (a, b) = plt.subplots(2, 1, figsize=(11.5, 7.2), facecolor=SURF, gridspec_kw={"hspace": 0.5})
x = range(len(D))
style(a); v = [100 * d[1] / ALONE for d in D]
a.bar(x, v, width=0.5, color=C["victim"])
for xi, vi, d in zip(x, v, D): a.text(xi, vi + 2.5, "%.0f %%" % vi, ha="center", color=INK)
a.set_ylim(0, 118); a.set_yticks([0, 50, 100]); a.set_xticks(list(x)); a.set_xticklabels([d[0] for d in D], fontsize=8.5)
a.set_title("What the victim keeps, %% of running alone (%.2f MB/s)" % ALONE, loc="left", fontsize=10, pad=8)
style(b); bot = [0] * len(D)
for k, key, name in ((2, "tenant", "charged to the tenant's group"), (3, "kernel", "charged to the kernel's group"), (4, "default", "charged to the default group")):
    b.bar(x, [d[k] for d in D], width=0.5, bottom=bot, color=C[key], label=name, edgecolor=SURF, linewidth=1.5); bot = [s + d[k] for s, d in zip(bot, D)]
for xi, t in zip(x, bot): b.text(xi, t + 0.3, "%.1f" % t, ha="center", color=INK)
b.axhline(CAP, color=INK, lw=1, ls=(0, (4, 3))); b.text(len(D) - 0.45, CAP, " cap", va="center", ha="left", color=INK, clip_on=False)
b.set_ylim(0, 13); b.set_xticks(list(x)); b.set_xticklabels([d[0] for d in D], fontsize=8.5)
b.set_title("Memory traffic the tenant causes, MB/s, by the group it is charged to", loc="left", fontsize=10, pad=8)
b.legend(loc="upper center", bbox_to_anchor=(0.5, -0.22), ncol=3, frameon=False)
fig.suptitle("Memory as the bottleneck: three tenants next to a streaming victim (AlSaqr, VCU118, Linux 7.2)", x=0.06, ha="left", fontsize=11.5, y=0.985)
fig.text(0.06, 0.945, "DRAM model: latency 100 cycles, OCC16 320 (20 MB/s bus). Regulator capacity 17 MB/s; cap 3.4 MB/s for the tenant's group..", fontsize=8.5, color=SUB)
fig.subplots_adjust(left=0.06, right=0.96, top=0.87, bottom=0.14)
fig.savefig("kernel_qos_id_policies_dram_model.png", dpi=150, facecolor=SURF)
# calibration
S = [("model off", 27.7, 26.3, ""), ("latency 1\nOCC16 112\n(57 MB/s bus)", 21.2, 12.9, "nearly every\nread late"), ("latency 100\nOCC16 160\n(40 MB/s bus)", 11.0, 8.6, "0 late"), ("latency 100\nOCC16 320\n(20 MB/s bus)", 8.5, 4.4, "0 late\n(chosen)")]
fig, a = plt.subplots(figsize=(8.5, 4.6), facecolor=SURF); style(a); w = 0.34
for i, (lab, al, wi, note) in enumerate(S):
    a.bar(i - w / 2 - 0.01, al, width=w, color=C["alone"], label="victim alone" if i == 0 else None); a.bar(i + w / 2 + 0.01, wi, width=w, color=C["with"], label="victim next to three uncapped readers" if i == 0 else None)
    a.text(i - w / 2 - 0.01, al + 0.5, "%.1f" % al, ha="center"); a.text(i + w / 2 + 0.01, wi + 0.5, "%.1f" % wi, ha="center")
    if note: a.text(i, max(al, wi) + 3.2, note, ha="center", fontsize=8.5, color=SUB)
a.set_xticks(range(len(S))); a.set_xticklabels([s[0] for s in S], fontsize=8.5); a.set_ylim(0, 33); a.set_ylabel("victim, MB/s")
a.set_title("Choosing the DRAM model setting: when does memory become the bottleneck?", loc="left", fontsize=10.5, pad=10)
a.legend(loc="upper right", frameon=False); fig.tight_layout()
fig.savefig("dram_model_calibration.png", dpi=150, facecolor=SURF)
