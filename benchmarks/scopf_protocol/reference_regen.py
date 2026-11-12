#!/usr/bin/env python3
"""reference_regen -- the protocol applied to four networks of the reference SCOPF set, compared with the published lists
(Python standard library only; seconds). Nothing here changes an instance list.

  python3 benchmarks/scopf_protocol/reference_regen.py compare [--check]
  python3 benchmarks/scopf_protocol/reference_regen.py jobs <data dir>

For case_ACTIVSg500, case1354pegase, case2869pegase and case_ACTIVSg2000 the protocol of README.md is applied in order A
(increasing PowerModels branch key) to the MATPOWER 7.0 files (fetch_scopf_data.sh data_mp70/): the screen at penalty 1e8
(admitted iff the scaled ||r||_inf < 1e-4 after at most 200 iterations, any status, bridges kept), the island rule, the
single-contingency verification and drop-and-backfill (the rules of build_lists.py), with the list as long as the
largest K of the reference set (100, 32, 16, 16). Records (records/reference_regen/):
  screens/<net>_A.csv      julia/screen_run2.jl order A, stop at 64 admitted (case_ACTIVSg500: the full S0' screen of
                           records/reference_screens/, whose order is order A)
  islands.csv              julia/islands.jl on the four networks
  k1/k1_10000it_3600s/     julia/k1_verify.jl rows (label A) of the admitted outages that had no K = 1 row; the published
                           entries reuse their rows in records/k1/reference/ (label EPSR, the same case files)
compare  per network: the protocol list, its drops and backfills, and at every K the reference set uses the overlap of the
         first K entries with the published list and the first differing entry; for case_ACTIVSg500 also the published
         entries the screen rejects; then the K = 1 outcomes of the rows added here (label A) and their protocol
         verdicts. With --check the output must equal records/reference_regen/compare.md.
jobs     the K = 1 jobs (<net>,A,<branch>,<data dir>/data_mp70/<net>.m) still missing: the first 100 (case_ACTIVSg500) or
         40 (the other three) island-passing admitted outages without a row.
"""
import csv, glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_lists import island_ok, verdict   # noqa: E402  (the protocol's rules 2 and 3)

REC = os.path.join(HERE, "records")
G = os.path.join(REC, "reference_regen")
NETS = [("case_ACTIVSg500", 100, (4, 8, 10, 16, 32, 50, 64, 100), 100),
        ("case1354pegase", 32, (8, 16, 32), 40),
        ("case2869pegase", 16, (8, 16), 40),
        ("case_ACTIVSg2000", 16, (8, 16), 40)]
ST = {"1": "SUCC", "2": "ACCEPTABLE", "3": "SMALL_STEP", "4": "DIVERGING", "5": "INFEASIBLE", "6": "MAXITER"}


def published():
    src = open(os.path.join(os.path.dirname(HERE), "instances", "scopf_contingencies.jl")).read()
    return {m.group(1): [int(x) for x in m.group(2).replace("\n", " ").split(",") if x.strip()]
            for m in re.finditer(r'"(\w+)" => \[([^\]]*)\]', src)}


def screen_rows(net):
    p = (os.path.join(REC, "reference_screens", "case_ACTIVSg500_full_rho1e8.csv") if net == "case_ACTIVSg500"
         else os.path.join(G, "screens", f"{net}_A.csv"))
    R = list(csv.DictReader(open(p)))
    return p, R


def islands():
    return {(r["net"], int(r["branch"])): r for r in csv.DictReader(open(os.path.join(G, "islands.csv")))}


def k1rows():
    out = {}
    for f in sorted(glob.glob(os.path.join(G, "k1", "*", "*.csv")) + glob.glob(os.path.join(REC, "k1", "reference", "*", "*.csv"))):
        v = open(f).read().strip().split(",")
        out.setdefault((v[0], int(v[2])), []).append((v, os.path.relpath(f, REC)))
    return out


def k1row(K, net, k):
    """The K = 1 row of outage k: the regen row (label A) if there is one, else the published-list row (label EPSR)."""
    rows = K.get((net, k), [])
    for lab in ("A", "EPSR"):
        for v, p in rows:
            if v[1] == lab:
                return v, p
    return None


def build(net, n, ISL, K):
    path, R = screen_rows(net)
    adm = [int(r["k"]) for r in R if r["admitted"] == "1"]
    kept, drops, backs, skipped, pending = [], [], [], [], None
    for k in adm[:n]:
        ok, d = island_ok(ISL, net, k)
        if not ok:
            drops.append((k, "island rule: " + d)); continue
        row = k1row(K, net, k)
        if row is None:
            pending = k; break
        ok, why = verdict(row[0])
        (kept.append(k) if ok else drops.append((k, why)))
    cand = iter(adm[n:])
    while pending is None and len(kept) + len(backs) < n:
        k = next(cand, None)
        if k is None:
            pending = "screen exhausted"; break
        ok, d = island_ok(ISL, net, k)
        if not ok:
            skipped.append((k, "island rule: " + d)); continue
        row = k1row(K, net, k)
        if row is None:
            pending = k; break
        ok, why = verdict(row[0])
        (backs.append(k) if ok else skipped.append((k, why)))
    return dict(path=path, R=R, adm=adm, first=adm[:n], kept=kept, drops=drops, backs=backs, skipped=skipped,
                pending=pending, final=kept + backs)


def first_diff(a, b):
    i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), None)
    return i + 1 if i is not None else (min(len(a), len(b)) + 1 if len(a) != len(b) else None)


def compare():
    P, ISL, K = published(), islands(), k1rows()
    out = ["Protocol lists in order A against the published lists (records/reference_regen/; reference_regen.py compare).", ""]
    summary = []
    for net, n, Ks, _ in NETS:
        x = build(net, n, ISL, K)
        R, pub = x["R"], P[net]
        n64 = None; a = 0
        for i, r in enumerate(R):
            a += r["admitted"] == "1"
            if a == 64:
                n64 = i + 1; break
        out.append(f"## {net}")
        out.append("")
        out.append(f"Screen {os.path.relpath(x['path'], REC)}: {len(R)} branches screened, {len(x['adm'])} admitted"
                   + (f"; the 64th admission at branch position {n64}" if n64 else "; fewer than 64 admitted") + ".")
        out.append(f"Protocol list (first {n} admitted, island rule, K = 1 verification, backfill): "
                   + (f"pending {x['pending']}" if x["pending"] is not None else f"{x['final']}"))
        out.append(f"Dropped: {[(k, w) for k, w in x['drops']] or 'none'}; backfilled: {x['backs'] or 'none'}; "
                   f"skipped candidates: {x['skipped'] or 'none'}.")
        out.append(f"Published list ({len(pub)}): {pub}")
        out.append("")
        if x["pending"] is None:
            L = x["final"]
            out.append("| K | overlap of the first K | first K identical | first differing entry |")
            out.append("|---|---|---|---|")
            for k in Ks:
                fd = first_diff(L[:k], pub[:k])
                out.append(f"| {k} | {len(set(L[:k]) & set(pub[:k]))} | {'yes' if L[:k] == pub[:k] else 'no'} | "
                           f"{fd if fd is not None else '—'} |")
                summary.append((net, k, len(set(L[:k]) & set(pub[:k])), L[:k] == pub[:k], fd))
            out.append("")
        SR = {int(r["k"]): r for r in R}
        rej = [(k, SR[k]) for k in pub[:n] if k in SR and SR[k]["admitted"] != "1"]
        unscr = [k for k in pub[:n] if k not in SR]
        if rej:
            out.append(f"Published entries the screen rejects ({len(rej)}): " + "; ".join(
                f"{k} (entry {pub.index(k) + 1}, {ST.get(r['status'], r['status'])}, scaled ||r||_inf {float(r['rinf']):.3e}"
                + (", bridge" if r["bridge"] == "1" else "") + ")" for k, r in rej) + ".")
        else:
            out.append("Published entries the screen rejects: none.")
        if unscr:
            out.append(f"Published entries beyond the screened branches (not screened): {unscr}.")
        out.append("")
    out.append("## K = 1 verification of the outages added here (label A)")
    out.append("")
    out.append("| network | rows | Solve_Succeeded | other outcomes (branch: status, unscaled inf_pr, protocol verdict) | "
               "max iterations | max solve time (s) |")
    out.append("|---|---|---|---|---|---|")
    for net, _, _, _ in NETS:
        rows = sorted((v for (n, _k), L in K.items() if n == net for v, p in L if v[1] == "A" and p.startswith("reference_regen")),
                      key=lambda v: int(v[2]))
        if not rows:
            continue
        oth = [f"{v[2]}: {v[3]}, {float(v[6]):.2e}, " + ("kept" if verdict(v)[0] else "dropped") for v in rows if v[3] != "Solve_Succeeded"]
        out.append(f"| {net} | {len(rows)} | {sum(v[3] == 'Solve_Succeeded' for v in rows)} | {'; '.join(oth) or 'none'} | "
                   f"{max(int(v[5]) for v in rows)} | {max(float(v[12]) for v in rows):.1f} |")
    out.append("")
    out.append("## Summary")
    out.append("")
    out.append("| network | K | overlap | identical | first differing entry |")
    out.append("|---|---|---|---|---|")
    for net, k, ov, eq, fd in summary:
        out.append(f"| {net} | {k} | {ov} | {'yes' if eq else 'no'} | {fd if fd is not None else '—'} |")
    return "\n".join(out) + "\n"


def jobs(data):
    ISL, K = islands(), k1rows()
    J = []
    for net, n, Ks, m in NETS:
        if net != "case_ACTIVSg500" and not os.path.isfile(os.path.join(G, "screens", f"{net}_A.csv")):
            continue   # screen not recorded yet
        _, R = screen_rows(net)
        c = 0
        for r in R:
            if c >= m:
                break
            k = int(r["k"])
            if r["admitted"] != "1" or not island_ok(ISL, net, k)[0]:
                continue
            c += 1
            if k1row(K, net, k) is None:
                J.append(f"{net},A,{k},{os.path.join(os.path.abspath(data), 'data_mp70', net + '.m')}")
    return "\n".join(J) + ("\n" if J else "")


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    if not a or a[0] not in ("compare", "jobs") or (a[0] == "jobs" and len(a) < 2):
        print(__doc__); sys.exit(2)
    if a[0] == "jobs":
        print(jobs(a[1]), end=""); sys.exit(0)
    s = compare(); print(s, end="")
    if "--check" in sys.argv:
        same = s == open(os.path.join(G, "compare.md")).read()
        print("check vs records/reference_regen/compare.md:", "IDENTICAL" if same else "DIFFERS"); sys.exit(0 if same else 1)
