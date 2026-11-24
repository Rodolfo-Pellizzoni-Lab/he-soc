LAT, BEAT, LINE = 100, 20, 160
L, S, W = 128, 1.36, 760
X = lambda c: L + c * S
def timeline(title, xfers, cmax=440):
    """xfers: (name, kind 'r'|'w', accept cycle, css class). Computes the model's schedule exactly as the RTL does."""
    H = 236; o = ['<svg viewBox="0 0 %d %d" role="img" aria-label="%s">' % (W, H, title)]
    rows = {"acc": 46, "real": 84, "bus": 124, "out": 166}
    for c in range(0, cmax + 1, 20):
        big = c % 100 == 0
        o.append('<line class="%s" x1="%.1f" x2="%.1f" y1="26" y2="%d"/>' % ("g1" if big else "g0", X(c), X(c), H - 30))
        if big: o.append('<text class="tk" x="%.1f" y="%d" text-anchor="middle">%d</text>' % (X(c), H - 14, c))
    o.append('<text class="tk" x="%.1f" y="%d" text-anchor="end">cycle</text>' % (L - 12, H - 14))
    for k, lab in (("acc", "request accepted"), ("real", "real DRAM answers"), ("bus", "modelled bus"), ("out", "released to cache")):
        o.append('<text class="rl" x="%.1f" y="%d" text-anchor="end">%s</text>' % (L - 12, rows[k] + 4, lab))
    free = 0; notes = []
    for name, kind, acc, cls in xfers:
        start = max(acc + LAT, free); free = start + LINE
        y = rows["acc"]
        o.append('<circle class="%s" cx="%.1f" cy="%d" r="9"/><text class="in" x="%.1f" y="%d" text-anchor="middle">%s</text>' % (cls, X(acc), y, X(acc), y + 4, name))
        y = rows["real"]
        if kind == "r":
            o.append('<rect class="%s soft" x="%.1f" y="%d" width="%.1f" height="16" rx="3"/>' % (cls, X(acc + 66), y - 8, 19 * S))
        else:
            o.append('<rect class="%s soft" x="%.1f" y="%d" width="%.1f" height="16" rx="3"/>' % (cls, X(acc + 30), y - 8, 19 * S))
        y = rows["bus"]
        o.append('<rect class="%s" x="%.1f" y="%d" width="%.1f" height="24" rx="4"/>' % (cls, X(start) + 1, y - 12, LINE * S - 2))
        o.append('<text class="in" x="%.1f" y="%d" text-anchor="middle">%s: %s, 160 cycles</text>' % (X(start + LINE / 2), y + 4, name, "read" if kind == "r" else "write"))
        y = rows["out"]
        if kind == "r":
            for i in range(8): o.append('<rect class="%s" x="%.1f" y="%d" width="%.1f" height="16" rx="2"/>' % (cls, X(start + i * BEAT) - 3, y - 8, 6))
            o.append('<text class="tk" x="%.1f" y="%d" text-anchor="middle">%s: 8 beats, 20 cycles apart</text>' % (X(start + 70), y + 24, name))
        else:
            o.append('<rect class="%s" x="%.1f" y="%d" width="6" height="16" rx="2"/>' % (cls, X(free) - 3, y - 8))
            o.append('<text class="tk" x="%.1f" y="%d" text-anchor="end">%s: done</text>' % (X(free) + 4, y + 24, name))
        notes.append((name, acc, start, free))
    # latency of the first transfer, wait of the later ones
    n0 = notes[0]
    o.append('<line class="dim" x1="%.1f" x2="%.1f" y1="%d" y2="%d"/><text class="tk" x="%.1f" y="%d" text-anchor="middle">%s: latency 100</text>' % (X(max(n[1] for n in notes)) + 11, X(n0[2]), rows["acc"], rows["acc"], X((max(n[1] for n in notes) + n0[2]) / 2 + 4), rows["acc"] - 7, n0[0]))
    for name, acc, start, fr in notes[1:]:
        if start > acc + LAT:
            o.append('<line class="wait" x1="%.1f" x2="%.1f" y1="%d" y2="%d"/><text class="tk" x="%.1f" y="%d" text-anchor="middle">%s waits %d more cycles for the bus</text>' % (X(acc + LAT), X(start), rows["acc"], rows["acc"], X((acc + LAT + start) / 2), rows["acc"] - 7, name, start - acc - LAT))
    o.append("</svg>"); return "".join(o), notes

f1, n1 = timeline("One read on an idle bus", [("A", "r", 0, "ca")], 300)
f2, n2 = timeline("A second read waits for the bus", [("A", "r", 0, "ca"), ("B", "r", 20, "cb")])
f3, n3 = timeline("A write-back ahead of a read", [("W", "w", 0, "cw"), ("R", "r", 20, "cb")])
print(n1, n2, n3)

buf = '''<svg viewBox="0 0 760 190" role="img" aria-label="Requests pass through the model at once; responses wait in its buffer until they are due">
<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="currentColor"/></marker></defs>
<rect class="box" x="20" y="50" width="130" height="90" rx="8"/><text class="bt" x="85" y="92" text-anchor="middle">Last-level</text><text class="bt" x="85" y="109" text-anchor="middle">cache</text>
<rect class="box hot" x="290" y="30" width="200" height="130" rx="8"/><text class="bt" x="390" y="54" text-anchor="middle">DRAM timing model</text>
<rect class="inner" x="306" y="98" width="168" height="46" rx="5"/><text class="tk" x="390" y="117" text-anchor="middle">buffer: 32 beats, each</text><text class="tk" x="390" y="132" text-anchor="middle">stamped with its due time</text>
<rect class="box" x="630" y="50" width="110" height="90" rx="8"/><text class="bt" x="685" y="92" text-anchor="middle">Real</text><text class="bt" x="685" y="109" text-anchor="middle">DDR4</text>
<line class="ar" x1="150" y1="76" x2="630" y2="76" marker-end="url(#ah)"/><text class="tk lab" x="220" y="69" text-anchor="middle">request</text><text class="tk lab" x="560" y="69" text-anchor="middle">passed on at once</text>
<line class="ar" x1="630" y1="121" x2="476" y2="121" marker-end="url(#ah)"/><text class="tk" x="553" y="140" text-anchor="middle">8 beats, as fast</text><text class="tk" x="553" y="154" text-anchor="middle">as it can</text>
<line class="ar" x1="304" y1="121" x2="152" y2="121" marker-end="url(#ah)"/><text class="tk" x="228" y="140" text-anchor="middle">one beat when its</text><text class="tk" x="228" y="154" text-anchor="middle">time comes</text>
</svg>'''

page = '''<title>DRAM Timing Model</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Space+Grotesk:wght@500;600&display=swap">
<style>
/* layout: one reading column; each timing diagram is a full-width figure on a shared cycle axis */
:root { --bg:#fbfbf9; --fg:#16181b; --muted:#5b6068; --line:#dcdcd6; --grid:#e9e9e3; --surface:#f1f1ec;
  --a:#2a78d6; --b:#d9541e; --w:#8a5cc7; --on:#ffffff;
  --display:"Space Grotesk",system-ui,sans-serif; --body:"Inter",system-ui,sans-serif; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#15171a; --fg:#eceae4; --muted:#a2a6ad; --line:#353940; --grid:#262a30; --surface:#1e2126; --a:#5b9ee8; --b:#f0803f; --w:#b08ee6; --on:#101214; color-scheme:dark } }
:root[data-theme="dark"] { --bg:#15171a; --fg:#eceae4; --muted:#a2a6ad; --line:#353940; --grid:#262a30; --surface:#1e2126; --a:#5b9ee8; --b:#f0803f; --w:#b08ee6; --on:#101214; color-scheme:dark }
body { background:var(--bg); color:var(--fg); font-family:var(--body); font-size:16px; line-height:1.55; }
.wrap { max-width:820px; margin:0 auto; padding-block:40px 64px; padding-left:max(16px, env(safe-area-inset-left, 0px)); padding-right:max(16px, env(safe-area-inset-right, 0px)); display:flex; flex-direction:column; gap:40px; }
h1 { font-family:var(--display); font-size:2rem; line-height:1.15; margin:0; text-wrap:balance; }
h2 { font-family:var(--display); font-size:1.25rem; margin:0; text-wrap:balance; }
p, ul, ol { margin:0; max-width:66ch; } ul, ol { padding-left:1.2em; display:flex; flex-direction:column; gap:6px; }
.eyebrow { color:var(--muted); font-size:0.8rem; letter-spacing:0.06em; text-transform:uppercase; }
header, section { display:flex; flex-direction:column; gap:14px; }
.lede { font-size:1.08rem; color:var(--muted); }
.rule { display:grid; grid-template-columns:repeat(auto-fit, minmax(240px, 1fr)); gap:12px; }
.rule div { background:var(--surface); border-radius:8px; padding:14px 16px; min-width:0; }
.rule b { display:block; font-family:var(--display); }
.rule span { color:var(--muted); font-size:0.92rem; }
figure { margin:0; display:flex; flex-direction:column; gap:8px; }
.scroll { overflow-x:auto; border:1px solid var(--line); border-radius:8px; }
.scroll svg { display:block; width:100%; min-width:680px; height:auto; color:var(--fg); }
figcaption { color:var(--muted); font-size:0.92rem; max-width:66ch; }
svg text { font-family:var(--body); fill:currentColor; }
.tk { font-size:11.5px; fill:var(--muted); } .rl { font-size:12px; fill:var(--muted); } .in { font-size:12px; font-weight:600; fill:var(--on); } .bt { font-size:13px; font-weight:600; }
.g0 { stroke:var(--grid); stroke-width:1; } .g1 { stroke:var(--line); stroke-width:1; }
.ca { fill:var(--a); } .cb { fill:var(--b); } .cw { fill:var(--w); } .soft { fill-opacity:0.35; }
.dim { stroke:currentColor; stroke-width:1.2; } .wait { stroke:var(--b); stroke-width:1.6; stroke-dasharray:5 4; }
.box { fill:var(--surface); stroke:var(--line); stroke-width:1.2; } .hot { stroke:var(--a); stroke-width:1.6; } .inner { fill:var(--bg); stroke:var(--line); }
.ar { stroke:currentColor; stroke-width:1.4; fill:none; }
code { font-family:ui-monospace,Menlo,monospace; font-size:0.9em; }
table { border-collapse:collapse; font-size:0.94rem; font-variant-numeric:tabular-nums; } th, td { text-align:left; padding:6px 14px 6px 0; border-bottom:1px solid var(--line); } th { color:var(--muted); font-weight:500; }
.tw { overflow-x:auto; }
</style>
<div class="wrap">
<header>
  <p class="eyebrow">AlSaqr · axi_dram_timing</p>
  <h1>How the DRAM timing model spaces out memory traffic</h1>
  <p class="lede">The model never slows a request down. It lets the real memory answer, holds the answer in a buffer, and releases it on the schedule of a slower, modelled memory. The examples use our test setting: latency 100 cycles and 20 cycles per 8-byte beat (<code>OCC16</code> = 320).</p>
</header>

<section>
  <h2>Where it sits</h2>
  <figure><div class="scroll">BUF</div>
  <figcaption>Requests pass through at once. The real memory returns a line within about 85 cycles; the model's buffer holds each 8-byte beat until its due time.</figcaption></figure>
</section>

<section>
  <h2>The whole rule</h2>
  <p>The model keeps one number, the time the modelled bus becomes free. Each transfer, read or write, does two things when it is accepted.</p>
  <div class="rule">
    <div><b>1. Start</b><span>the later of (accept time + latency) and (bus free at)</span></div>
    <div><b>2. Bus free at</b><span>start + 8 beats × 20 cycles = start + 160</span></div>
  </div>
  <p>A read's eight beats are released 20 cycles apart from its start. A write's "done" is released at the end of its 160 cycles.</p>
</section>

<section>
  <h2>One read, idle bus</h2>
  <figure><div class="scroll">F1</div>
  <figcaption>Read A is accepted at cycle 0. The real memory has the data by about cycle 85, but the first beat is released at 100 and the last at 240. The bus is free again at 260.</figcaption></figure>
</section>

<section>
  <h2>A second read has to wait</h2>
  <figure><div class="scroll">F2</div>
  <figcaption>Read B is accepted at cycle 20. Alone it would start at 120. A holds the bus until 260, so B starts at 260 and finishes at 400. This wait is the contention between cores: transfers line up one per 160 cycles, which is 20 MB/s.</figcaption></figure>
</section>

<section>
  <h2>A write-back ahead of a read</h2>
  <figure><div class="scroll">F3</div>
  <figcaption>Write W is a dirty line being evicted; read R is the miss that caused the eviction. The write takes a full 160-cycle slot, so R's data starts at 260. A miss that evicts a dirty line costs two bus slots.</figcaption></figure>
</section>

<section>
  <h2>The numbers behind the pictures</h2>
  <div class="tw"><table>
    <thead><tr><th>Transfer</th><th>Accepted</th><th>Accept + latency</th><th>Bus free before</th><th>Start</th><th>Bus free after</th></tr></thead>
    <tbody>ROWS</tbody>
  </table></div>
  <p>Limits: the model can only delay, so the setting is faithful only while the real memory answers before the modelled time. With this setting the board reported no late reads.</p>
</section>
</div>'''
rows = ""
for tag, ns in (("", n2), ("", n3)):
    free = 0
    for name, acc, start, fr in ns:
        rows += "<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>" % (("Read " if name != "W" else "Write ") + name + (" (example 2)" if ns is n2 else " (example 3)"), acc, acc + LAT, free, start, fr); free = fr
open("dram-timing-model.html", "w").write(page.replace("BUF", buf).replace("F1", f1).replace("F2", f2).replace("F3", f3).replace("ROWS", rows))
