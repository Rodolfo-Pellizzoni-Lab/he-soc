# random-parameter attack runs of tb_llc_wmaster (run_llc_wmaster.sh):  fuzz_llc_wmaster.py <runs> <jobs> <rng seed> <out file> [KEY=VAL ...]
import os, random, subprocess, sys, concurrent.futures as cf, re
N, J, RS, OUT = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
EXTRA = dict(a.split("=", 1) for a in sys.argv[5:])
T = os.path.dirname(os.path.abspath(__file__))
rng = random.Random(RS)
def params(i):
    bmin, bmax = rng.choice([(0, 0), (0, 1), (0, 4), (0, 60), (10, 120), (30, 300), (200, 1500)])
    p = dict(SEED=rng.randrange(1, 1 << 30), PEND=rng.choice([1, 2, 3, 4, 4, 4, 5, 8, 16]), BMIN=bmin, BMAX=bmax,
             NLINE=rng.choice([5, 5, 6, 9, 12]), NID=rng.choice([1, 2, 3, 8, 16]), PRDY=rng.choice([0, 1, 3, 3, 7]),
             BREORDER=rng.choice([0, 1, 1]), LEGAL=rng.choice([1, 1, 1, 0]), NDESC=rng.choice([60000, 120000, 200000]))
    p.update(EXTRA)
    return p
def run(i, p):
    name = "fz%d_%d" % (RS, i)
    env = dict(os.environ, LLC_RUN=name, SHOW="40", **{k: str(v) for k, v in p.items()})
    r = subprocess.run(["./run_llc_wmaster.sh"], cwd=T, env=env, capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r"(\d+) write-backs, at most (\d+) unanswered at a time, (\d+) responses out of order, (\d+) responses nobody", out)
    h = re.search(r"counters: (\d+) refills waited", out)
    res = "PASS" if r.returncode == 0 else "FAIL"
    line = "%s %s wb=%s maxun=%s ooo=%s stray=%s held=%s | %s" % (res, name, *(m.groups() if m else ("?",) * 4), h.group(1) if h else "?",
            " ".join("%s=%s" % kv for kv in p.items()))
    if res == "FAIL":
        line += "\n    " + "\n    ".join(l[:200] for l in out.splitlines() if ("FAIL" in l or l.startswith("Error") or "ERROR" in l))[:1500]
    with open(OUT, "a") as f: f.write(line + "\n")
    return res
ps = [params(i) for i in range(N)]
open(OUT, "w").close()
with cf.ThreadPoolExecutor(J) as ex: rs = list(ex.map(lambda ip: run(*ip), enumerate(ps)))
with open(OUT, "a") as f: f.write("DONE %d runs: %d PASS, %d FAIL\n" % (N, rs.count("PASS"), rs.count("FAIL")))
