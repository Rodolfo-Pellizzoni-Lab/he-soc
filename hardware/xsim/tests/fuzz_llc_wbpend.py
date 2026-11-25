# random-parameter attack runs of tb_llc_wbpend (run_llc_wbpend.sh; the script's exit status is the verdict):  fuzz_llc_wbpend.py <runs> <jobs> <rng seed> <out file> [KEY=VAL ...]
import os, random, subprocess, sys, concurrent.futures as cf, re
N, J, RS, OUT = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
EXTRA = dict(a.split("=", 1) for a in sys.argv[5:])
T = os.path.dirname(os.path.abspath(__file__))
rng = random.Random(RS)
def params(i):
    bmin, bmax = rng.choice([(0, 0), (0, 3), (1, 8), (5, 40), (20, 250), (100, 900), (300, 2000)])
    rmin, rmax = rng.choice([(0, 0), (0, 3), (2, 40), (2, 40), (50, 300)])
    p = dict(SEED=rng.randrange(1, 1 << 30), PEND=rng.choice([1, 2, 3, 4, 4, 4, 8]), BMIN=bmin, BMAX=bmax, RMIN=rmin, RMAX=rmax,
             HOT=rng.choice([0, 0, 4, 8]), HOTS=rng.choice([1, 1, 2, 4]), HOTL=rng.choice([5, 6, 9]), BYP=rng.choice([0, 1]),
             AWLIM=rng.choice([0, 0, 1, 2, 3, 6]), BBURST=rng.choice([0, 0, 1]), FLUSHMID=rng.choice([0, 0, 3, 8]),
             BREORDER=rng.choice([0, 1, 1]), WBUF=rng.choice([0, 8, 8]), REGION=rng.choice([256, 512, 1024, 4096]),
             NOPS=rng.choice([150, 250, 400]), COVER=0)
    p.update(EXTRA)
    return p
def run(i, p):
    name = "fz%d_%d" % (RS, i)
    env = dict(os.environ, LLC_RUN=name, SHOW="12", **{k: str(v) for k, v in p.items()})
    r = subprocess.run(["./run_llc_wbpend.sh"], cwd=T, env=env, capture_output=True, text=True)
    out = r.stdout + r.stderr
    wu = re.search(r"write unit: (\d+) write-backs; (\d+) refills waited", out)
    mm = re.search(r"at most (\d+) complete ones unanswered at a time, (\d+) responses out of order; bypass (\d+) writes, (\d+) reads; (\d+) flushes ended", out)
    res = "PASS" if r.returncode == 0 else "FAIL"      # the script's exit status is the verdict
    line = "%s %s wb=%s held=%s maxun=%s ooo=%s byp=%s flush=%s | %s" % (res, name, wu.group(1) if wu else "?", wu.group(2) if wu else "?",
            mm.group(1) if mm else "?", mm.group(2) if mm else "?", mm.group(3) if mm else "?", mm.group(5) if mm else "?",
            " ".join("%s=%s" % kv for kv in p.items()))
    if res == "FAIL":
        line += "\n    " + "\n    ".join(l[:200] for l in out.splitlines() if ("FAIL" in l or l.startswith("Error") or "ERROR" in l))[:1500]
    with open(OUT, "a") as f: f.write(line + "\n")
    return res
ps = [params(i) for i in range(N)]
open(OUT, "w").close()
with cf.ThreadPoolExecutor(J) as ex: rs = list(ex.map(lambda ip: run(*ip), enumerate(ps)))
with open(OUT, "a") as f: f.write("DONE %d runs: %d PASS, %d FAIL\n" % (N, rs.count("PASS"), rs.count("FAIL")))
