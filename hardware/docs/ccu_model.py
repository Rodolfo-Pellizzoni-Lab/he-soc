#!/usr/bin/env python3
"""Cycle-level model of the AlSaqr coherent memory path: N CVA6 cores with a blocking L1 miss path, the Culsans
CCU (one state machine, one transaction at a time), the snoop round to the other L1s, the crossbar and the LLC.

A discrete-event simulation driven by latencies measured in xsim (t_bw windows + sim_session traces, see
hardware/docs/ccu_model.md). Variants change the structure to predict what each remedy buys:

  base       the RTL before 2026-10-25: the state machine waits for the LLC's response (READ_MEM)
  decouple   the state machine hands the memory read to the LLC and takes the next request; responses return by
             AXI id; up to --inflight reads outstanding (the change implemented in ccu_fsm.sv, DecoupledReads)
  spec       the memory read is issued together with the snoop round, discarded if a cache answers (not built)
  filter     a snoop filter: lines held by no other L1 skip the snoop round (not built)
  ccu_nocut  the spill registers between the cores and the CCU removed (CCU LatencyMode NO_LATENCY)
  xbar_nocut the crossbar's spill registers removed (AXI_XBAR_CFG LatencyMode NO_LATENCY, was the default)

Modes: rd (ReadShared stream, LLC hits), wr (ReadUnique stream: a store miss per line), sh (all harts read the
same lines: the first fetches from the LLC, the others get the line from that L1 through the snoop channel),
wb (the write-back of the dirty lines by the flush, on the non-shareable path, not through the state machine).

Usage: ccu_model.py [--cores N] [--harts k] [--mode rd|wr|sh|wb] [--lines L] [--variant v,v,...] [--inflight K]
       ccu_model.py --table [--cores N]      # cycles per line for 1..N harts, every variant and mode
"""
import argparse, heapq, itertools

# --------------------------------------------------------------------------- measured latencies (cycles)
# xsim traces of one hart streaming (4 cores, CCU and crossbar with CUT_ALL_PORTS): scratchpad ccu/trace_k1rd.txt,
# trace_k1wr.txt (2026-10-25). Period 43 cycles per 16-byte line; the state machine is busy 34 of them.
P = dict(
    req_to_ccu   = 2,    # AR leaves the core's CCU port -> ccu_fsm sees ar_valid (demux spill + mux spill)
    decode       = 2,    # IDLE (request seen) -> DECODE_R -> SEND_READ
    ac_accept    = 1,    # SEND_READ: every snooped port accepts AC (idle snoop controllers)
    cr_idle      = 3,    # AC accepted -> CR of an idle snoop controller (WAIT_GNT, EVAL_FLAGS, SEND_CR_RESP)
    cr_busy_extra= 2,    # extra CR cycles while that core's miss handler writes its own refill (SRAM port busy)
    snoop_busy   = 4,    # cycles a snoop controller is busy per snoop (cannot accept the next AC meanwhile)
    mem_issue    = 1,    # all CR -> SEND_AXI_REQ_R -> AR accepted by the outer mux
    ccu_to_llc   = 9,    # AR leaves the CCU -> AR at the LLC's slave port (xbar spills, atomics adapter, cut)
    llc_hit      = 6,    # AR at the LLC -> first R beat at the LLC
    llc_to_ccu   = 9,    # first R beat at the LLC -> at the CCU
    beats        = 2,    # R beats per 16-byte line (64-bit data)
    fsm_done     = 1,    # last beat (or the AR hand-over) -> IDLE
    resp_to_core = 2,    # ccu_fsm r_valid -> the core's CCU port sees it (mux spill + demux spill)
    core_turn    = 5,    # last R beat at the core's port -> next AR at the port (refill, replay, next miss)
    snp_data     = 4,    # READ_SNP_DATA: CD beats from the answering L1 -> R beats out (per line)
    # write-backs (fence after a write window, t_bw "wb"): the miss handler writes each dirty line back and
    # waits for B; they bypass the state machine (ace_trs_dec routes WriteBack to the non-shareable path)
    wb_lat       = 35,   # one hart: cycles per written-back line (flush walk + AW/W + B through xbar and LLC)
    wb_gap       = 25,   # the shared write path: one 16-byte write per this many cycles (4 harts: 99 cycles/line each)
    llc_rd_gap   = 2,    # the LLC accepts one 16-byte read per this many cycles when several are in flight
)

class Sim:
    def __init__(s): s.t = 0; s.q = []; s.n = itertools.count()
    def at(s, dt, fn, *a): heapq.heappush(s.q, (s.t + dt, next(s.n), fn, a))
    def run(s):
        while s.q:
            s.t, _, fn, a = heapq.heappop(s.q); fn(*a)

class Model:
    """harts 0..k-1 stream `lines` misses each; the other cores idle (their snoop controllers answer at once)."""
    def __init__(s, cores, harts, lines, mode, variants, inflight, p=P):
        s.p = dict(p); s.cores = cores; s.k = harts; s.lines = lines; s.mode = mode
        s.v = set(variants); s.inflight = inflight
        if "ccu_nocut" in s.v: s.p["req_to_ccu"] = 0; s.p["resp_to_core"] = 0
        if "xbar_nocut" in s.v: s.p["ccu_to_llc"] -= 2; s.p["llc_to_ccu"] -= 2
        s.sim = Sim()
        s.fsm_free_at = 0
        s.pending = []
        s.mem_inflight = 0; s.mem_last_issue = -10**9; s.wb_last = -10**9
        s.done = {h: 0 for h in range(harts)}; s.finish = {h: 0 for h in range(harts)}
        s.refill_busy_until = {h: 0 for h in range(cores)}
        s.snoop_busy_until = {h: 0 for h in range(cores)}
        s.serial_cycles = 0; s.fsm_wait_mem = 0
        s.first_fetch = {}       # sh: line -> hart that fetched it from the LLC (others get snoop data)
        s.inflight_lines = {}    # decouple: line -> cycle its memory read returns (conflict table)
        s.line_idx = {h: 0 for h in range(harts)}

    def llc_lat(s): return s.p["ccu_to_llc"] + s.p["llc_hit"] + s.p["llc_to_ccu"]

    def start(s):
        if s.mode == "wb":
            for h in range(s.k): s.sim.at(0, s.wb_issue, h)
        else:
            for h in range(s.k): s.sim.at(0, s.core_issue, h)
        s.sim.run()
        return max(s.finish.values())

    # ---- write-back path (bypasses the state machine): blocking per hart, shared write throughput
    def wb_issue(s, h):
        t = max(s.sim.t, s.wb_last + s.p["wb_gap"])
        s.wb_last = t
        s.sim.at(t - s.sim.t + s.p["wb_lat"], s.wb_done, h)
    def wb_done(s, h):
        s.done[h] += 1
        if s.done[h] >= s.lines: s.finish[h] = s.sim.t
        else: s.sim.at(0, s.wb_issue, h)

    # ---- core side
    def core_issue(s, h):
        s.sim.at(s.p["req_to_ccu"], s.ccu_arrive, h)

    def core_resp(s, h):
        s.done[h] += 1
        s.refill_busy_until[h] = s.sim.t + 2
        if s.done[h] >= s.lines: s.finish[h] = s.sim.t
        else: s.sim.at(s.p["core_turn"], s.core_issue, h)

    # ---- state machine
    def ccu_arrive(s, h):
        s.pending.append((s.sim.t, h))
        s.try_start()

    def try_start(s):
        if not s.pending or s.sim.t < s.fsm_free_at: return
        s.pending.sort()
        t0, h = s.pending.pop(0)
        p = s.p
        line = s.line_idx[h]; s.line_idx[h] += 1
        serial = p["decode"]
        snoop = s.snoop_round(h)
        if "filter" in s.v and s.mode != "sh": snoop = 0
        data_from_cache = s.mode == "sh" and line in s.first_fetch
        if s.mode == "sh" and "decouple" in s.v and line in s.inflight_lines:
            # the line is still in flight: the request waits in IDLE (conflict table) and is retried later
            s.pending.append((s.sim.t, h)); s.line_idx[h] -= 1
            s.fsm_free_at = s.inflight_lines[line]
            s.sim.at(s.inflight_lines[line] - s.sim.t, s.try_start)
            return
        if s.mode == "sh" and line not in s.first_fetch: s.first_fetch[line] = h
        if data_from_cache:
            t = serial + snoop + p["snp_data"] + p["fsm_done"]
            s.fsm_free_at = s.sim.t + t; s.serial_cycles += t
            s.sim.at(t - p["fsm_done"] + p["resp_to_core"], s.core_resp, h)
            s.sim.at(t, s.try_start)
            return
        if "spec" in s.v:
            serial += max(snoop, p["mem_issue"])
            mem_wait = s.llc_lat() + p["beats"] - max(0, snoop - p["mem_issue"])
        else:
            serial += snoop + p["mem_issue"]
            mem_wait = s.llc_lat() + p["beats"]
        if "decouple" in s.v:
            issue_at = max(s.sim.t + serial, s.mem_last_issue + p["llc_rd_gap"])
            if s.mem_inflight >= s.inflight:
                # table full: the read waits in READ_MEM like the base design
                t = serial + mem_wait + p["fsm_done"]
                s.fsm_free_at = s.sim.t + t; s.serial_cycles += serial; s.fsm_wait_mem += mem_wait
                s.sim.at(serial + mem_wait + p["resp_to_core"], s.core_resp, h)
                s.sim.at(t, s.try_start)
                return
            s.mem_last_issue = issue_at
            s.fsm_free_at = issue_at + p["fsm_done"]; s.serial_cycles += issue_at + p["fsm_done"] - s.sim.t
            s.mem_inflight += 1
            s.inflight_lines[line] = issue_at + mem_wait
            s.sim.at(issue_at - s.sim.t + mem_wait, s.mem_return, h, line)
            s.sim.at(issue_at + p["fsm_done"] - s.sim.t, s.try_start)
        else:
            t = serial + mem_wait + p["fsm_done"]
            s.fsm_free_at = s.sim.t + t; s.serial_cycles += serial; s.fsm_wait_mem += mem_wait
            s.sim.at(serial + mem_wait + p["resp_to_core"], s.core_resp, h)
            s.sim.at(t, s.try_start)

    def mem_return(s, h, line=None):
        s.mem_inflight -= 1
        s.inflight_lines.pop(line, None)
        s.sim.at(s.p["resp_to_core"], s.core_resp, h)
        s.try_start()

    def snoop_round(s, h):
        """cycles from SEND_READ until every other port's CR is in: the slowest snooped core decides."""
        p = s.p; worst = 0
        for c in range(s.cores):
            if c == h: continue
            start = max(s.sim.t, s.snoop_busy_until[c])
            cr = start + p["ac_accept"] + p["cr_idle"]
            if s.refill_busy_until[c] > start: cr += p["cr_busy_extra"]
            s.snoop_busy_until[c] = start + p["ac_accept"] + p["snoop_busy"]
            worst = max(worst, cr - s.sim.t)
        return worst + 1

def cycles_per_line(cores, harts, lines, mode, variants, inflight):
    m = Model(cores, harts, lines, mode, variants, inflight)
    total = m.start()
    return total / (harts * lines), total / lines, m

VARIANTS = [["base"], ["decouple"], ["decouple", "filter"], ["spec"], ["ccu_nocut"], ["xbar_nocut"],
            ["decouple", "ccu_nocut", "xbar_nocut"]]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cores", type=int, default=4)
    ap.add_argument("--harts", type=int, default=1)
    ap.add_argument("--lines", type=int, default=256)
    ap.add_argument("--mode", default="rd")
    ap.add_argument("--variant", default="base")
    ap.add_argument("--inflight", type=int, default=8)
    ap.add_argument("--table", action="store_true")
    a = ap.parse_args()
    if a.table:
        hs = [h for h in (1, 2, 3, 4, 6, 8) if h <= a.cores]
        for mode in ("rd", "wr", "sh", "wb"):
            print(f"\n{mode}: aggregate cycles per 16-byte line (per-hart cycles per line), {a.cores} cores, "
                  f"harts " + " ".join(str(h) for h in hs))
            print("variant".ljust(30) + "".join(f"{h:>13d}" for h in hs))
            for v in (VARIANTS if mode != "wb" else [["base"]]):
                row = []
                for h in hs:
                    agg, per, _ = cycles_per_line(a.cores, h, a.lines, mode, v, a.inflight)
                    row.append(f"{agg:6.1f} ({per:4.0f})")
                print("+".join(v).ljust(30) + "".join(f"{r:>13s}" for r in row))
        return
    agg, per, m = cycles_per_line(a.cores, a.harts, a.lines, a.mode, a.variant.split(","), a.inflight)
    print(f"{a.cores} cores, {a.harts} harts, mode {a.mode}, variant {a.variant}: {agg:.1f} cycles/line aggregate, "
          f"{per:.0f} cycles/line per hart, {16/agg*1000:.0f} B/kcycle; fsm serial {m.serial_cycles} cycles, "
          f"waiting for memory {m.fsm_wait_mem}")

if __name__ == "__main__":
    main()
