#!/usr/bin/env python3
"""reference_networks -- the contingency lists of the seven reference networks (the 23 instances of
benchmarks/instances/scopf23.csv), rebuilt from the protocol records (Python standard library only; seconds).

  python3 benchmarks/scopf_protocol/reference_networks.py [--records=<dir>] lists [--write | --check]
  python3 benchmarks/scopf_protocol/reference_networks.py [--records=<dir>] report [--check]
  python3 benchmarks/scopf_protocol/reference_networks.py [--records=<dir>] jobs <data dir> [<n>]

The protocol of README.md in order A (increasing PowerModels branch key) on the MATPOWER 7.0 case files
(fetch_scopf_data.sh <D>/data_mp70/), each list as long as the largest K of its network's instances (case118, case300,
case_ACTIVSg200, case_ACTIVSg500: 100; case1354pegase: 32; case2869pegase, case_ACTIVSg2000: 16): the first n admitted
outages of the screen (scaled ||r||_inf < 1e-4 after at most 200 iterations at penalty 1e8, any status, bridges kept),
the island rule, the single-contingency (K = 1) verification and drop-and-backfill, with the rules of build_lists.py.
Records (<dir>, default records/reference_networks/ next to this script):
  screens/<net>_full_rho1e8.csv  julia/screen_run2.jl in order full (every in-service branch in increasing key, no stop
                                 rule): case118, case300, case_ACTIVSg200, case_ACTIVSg500
  screens/<net>_A.csv            julia/screen_run2.jl in order A, stopped at 64 admitted: case1354pegase, case2869pegase,
                                 case_ACTIVSg2000
  islands.csv                    julia/islands.jl on the seven networks (every bridge)
  k1/<budget>/<net>_<label>__<k>.csv   julia/k1_verify.jl rows; label A = the MATPOWER 7.0 file (the screen's file);
                                 label Amp81 = case300 on the MATPOWER 8.1 file (the file of its K = 100 instance),
                                 reported only
lists   benchmarks/instances/scopf_contingencies.jl, the seven lists (asserted: every list complete, no K = 1 check
        pending, every bridge of a list in islands.csv). Prints the file; --write writes it; --check compares it with the
        file: IDENTICAL, or (records of a rerun, whose screen sha256 differ) whether the lists are equal.
report  per network the screen, the list, its drops and backfills, the bridges of the list and their islands, the K = 1
        outcomes of the list's outages, and the further K = 1 rows of the records; with --check the output must equal
        records/reference_networks/lists.md.
jobs    the K = 1 jobs (<net>,A,<branch>,<data dir>/data_mp70/<net>.m) the rule still needs: the first <n> (default: the
        list length) island-passing admitted outages without a row, and the outage a backfill waits for.
"""
import csv, glob, hashlib, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_lists import island_ok, verdict   # noqa: E402  (the protocol's island rule and K = 1 verdict)

G = os.path.join(HERE, "records", "reference_networks")
LISTS = os.path.join(os.path.dirname(HERE), "instances", "scopf_contingencies.jl")
# network, list length (the largest K of its instances in scopf23.csv), screen file
NETS = [("case118", 100, "case118_full_rho1e8.csv"),
        ("case300", 100, "case300_full_rho1e8.csv"),
        ("case_ACTIVSg200", 100, "case_ACTIVSg200_full_rho1e8.csv"),
        ("case_ACTIVSg500", 100, "case_ACTIVSg500_full_rho1e8.csv"),
        ("case1354pegase", 32, "case1354pegase_A.csv"),
        ("case2869pegase", 16, "case2869pegase_A.csv"),
        ("case_ACTIVSg2000", 16, "case_ACTIVSg2000_A.csv")]
ST = {"1": "SUCC", "2": "ACCEPTABLE", "3": "SMALL_STEP", "4": "DIVERGING", "5": "INFEASIBLE", "6": "MAXITER"}
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()


def screen_rows(fname):
    p = os.path.join(G, "screens", fname)
    return p, list(csv.DictReader(open(p)))


def islands():
    return {(r["net"], int(r["branch"])): r for r in csv.DictReader(open(os.path.join(G, "islands.csv")))}


def k1rows():
    out = {}
    for f in sorted(glob.glob(os.path.join(G, "k1", "*", "*.csv"))):
        v = open(f).read().strip().split(",")
        key = (v[0], v[1], int(v[2]))
        assert key not in out, f"two K = 1 rows for {key}"
        out[key] = (v, os.path.basename(os.path.dirname(f)))
    return out


def build(net, n, fname, ISL, K):
    path, R = screen_rows(fname)
    SR = {int(r["k"]): r for r in R}
    adm = [int(r["k"]) for r in R if r["admitted"] == "1"]
    kept, drops, backs, skipped, pending = [], [], [], [], None

    def check(k):
        assert SR[k]["bridge"] != "1" or (net, k) in ISL, f"{net} {k}: a bridge without an islands.csv row"
        ok, d = island_ok(ISL, net, k)
        if not ok:
            return False, "island rule: " + d
        if (net, "A", k) not in K:
            return None, ""
        return verdict(K[(net, "A", k)][0])

    for k in adm[:n]:
        ok, why = check(k)
        if ok is None:
            pending = k; break
        (kept.append(k) if ok else drops.append((k, why)))
    cand = iter(adm[n:])
    while pending is None and len(kept) + len(backs) < n:
        k = next(cand, None)
        if k is None:
            pending = "screen exhausted"; break
        ok, why = check(k)
        if ok is None:
            pending = k; break
        (backs.append(k) if ok else skipped.append((k, why)))
    return dict(net=net, n=n, path=path, R=R, SR=SR, adm=adm, first=adm[:n], kept=kept, drops=drops, backs=backs,
                skipped=skipped, pending=pending, final=kept + backs)


def build_all():
    ISL, K = islands(), k1rows()
    return [build(net, n, f, ISL, K) for net, n, f in NETS], ISL, K


def lists_file():
    res, _, K = build_all()
    for x in res:
        assert x["pending"] is None and len(x["final"]) == x["n"], (x["net"], x["pending"])
    L = ["# Contingency lists of the seven reference networks (the 23 instances of benchmarks/instances/scopf23.csv): for each",
         "# network, the branches whose outage defines scenarios 2, 3, ... (an instance with K contingencies uses the first K).",
         "# Generated by benchmarks/scopf_protocol/reference_networks.py from the protocol records",
         "# (benchmarks/scopf_protocol/records/reference_networks/; protocol in benchmarks/scopf_protocol/README.md): order A",
         "# (increasing PowerModels branch key) on the MATPOWER 7.0 case files; screen at rho = 1e8, admitted iff the scaled",
         "# ||r||_inf < 1e-4 after at most 200 iterations of one NCL subproblem (any status, bridges kept); the first n admitted",
         "# outages, n = the largest K of the network's instances; island rule; K = 1 verification (Ipopt-MA57, tol 1e-8); every",
         "# vacancy backfilled at the end in screening order.",
         "CONTINGENCIES = Dict("]
    for x in res:
        budgets = sorted({K[(x["net"], "A", k)][1] for k in x["final"]})
        L.append(f"    # {x['net']}: {x['n']} entries, screen screens/{os.path.basename(x['path'])} sha256 {sha(x['path'])};")
        L.append(f"    # K = 1 rows {', '.join('k1/' + b for b in budgets)}; dropped {[d[0] for d in x['drops']]}"
                 + "".join(f" ({w})" for _, w in x["drops"]) + f", backfilled {x['backs']}")
        L.append(f'    "{x["net"]}" => [{", ".join(map(str, x["final"]))}],')
    L.append(")")
    return "\n".join(L) + "\n"


def table(out, h, rows):
    out.append("| " + " | ".join(h) + " |"); out.append("|" + "---|" * len(h))
    for r in rows:
        out.append("| " + " | ".join(str(x) for x in r) + " |")
    out.append("")


def k1summary(rows):
    """(rows, Solve_Succeeded, other outcomes, max iterations, max solve time) of a list of K = 1 rows."""
    oth = [f"{v[2]}: {v[3]}, {float(v[6]):.2e}, " + ("kept" if verdict(v)[0] else "dropped") for v in rows
           if v[3] != "Solve_Succeeded"]
    return (len(rows), sum(v[3] == "Solve_Succeeded" for v in rows), "; ".join(oth) or "none",
            max(int(v[5]) for v in rows), f"{max(float(v[12]) for v in rows):.2f}")


def report():
    res, ISL, K = build_all()
    out = ["Contingency lists of the seven reference networks, rebuilt from the records (records/reference_networks/; "
           "reference_networks.py report). Order A (increasing PowerModels branch key), MATPOWER 7.0 files; admitted = "
           "scaled ||r||_inf < 1e-4 after at most 200 iterations at penalty 1e8 (any status, bridges kept).", ""]
    rows = []
    for x in res:
        R, a, pos = x["R"], 0, None
        for i, r in enumerate(R):
            a += r["admitted"] == "1"
            if a == x["n"]:
                pos = i + 1; break
        br = [r for r in R if r["bridge"] == "1"]
        rows.append((x["net"], f"screens/{os.path.basename(x['path'])}", len(R),
                     f"{len(br)} ({sum(r['admitted'] == '1' for r in br)})", len(x["adm"]), x["n"], pos,
                     len(x["drops"]), len(x["backs"]), "complete" if x["pending"] is None else f"pending {x['pending']}"))
    out.append("## Screens and lists")
    out.append("")
    table(out, ["network", "screen", "branches screened", "bridges screened (admitted)", "admitted", "list length n",
                "n-th admission at branch position", "dropped", "backfilled", "list"], rows)
    out.append("## K = 1 verification of the list entries (label A: the MATPOWER 7.0 file)")
    out.append("")
    out.append("Ipopt + MA57 on the K = 1 problem of the harness model, tol 1e-8; budget = <max_iter>it_<wall>s of the "
               "record directory. Verdict: dropped on Infeasible_Problem_Detected, or on an exhausted iteration or wall "
               "budget with an unscaled constraint violation (inf_pr) above 1e-3; kept otherwise.")
    out.append("")
    rows = []
    for x in res:
        by = {}
        for e, k in enumerate(x["final"], 1):
            v, b = K[(x["net"], "A", k)]
            by.setdefault(b, []).append((e, v))
        for b in sorted(by):
            E = [e for e, _ in by[b]]
            rows.append((x["net"], b, f"{min(E)}-{max(E)}" if E == list(range(min(E), max(E) + 1)) else
                         ", ".join(map(str, E)), *k1summary([v for _, v in by[b]])))
    table(out, ["network", "budget", "entries", "rows", "Solve_Succeeded", "other outcomes (branch: status, unscaled "
                "inf_pr, verdict)", "max iterations", "max solve time (s)"], rows)
    c300 = next(x for x in res if x["net"] == "case300")["final"]
    A81 = [K[("case300", "Amp81", k)] for k in c300 if ("case300", "Amp81", k) in K]
    if A81:
        out.append("## case300 on the MATPOWER 8.1 file (label Amp81; the file of its K = 100 instance; reported only)")
        out.append("")
        table(out, ["network", "budget", "rows", "Solve_Succeeded", "other outcomes (branch: status, unscaled inf_pr, "
                    "verdict)", "max iterations", "max solve time (s)"],
              [("case300", ", ".join(sorted({b for _, b in A81})), *k1summary([v for v, _ in A81]))])
    out.append("## Further K = 1 rows (admitted outages after the lists, label A)")
    out.append("")
    rows = []
    for x in res:
        extra = sorted((v for (n, lab, k), (v, b) in K.items() if n == x["net"] and lab == "A" and k not in x["final"]),
                       key=lambda v: x["adm"].index(int(v[2])))
        if extra:
            rows.append((x["net"], ", ".join(v[2] for v in extra), *k1summary(extra)))
    table(out, ["network", "branches", "rows", "Solve_Succeeded", "other outcomes (branch: status, unscaled inf_pr, "
                "verdict)", "max iterations", "max solve time (s)"], rows or [("none",) + ("",) * 6])
    out.append("## Bridges in the lists (islanded side = the side without the reference bus)")
    out.append("")
    rows = []
    for x in res:
        for e, k in enumerate(x["final"], 1):
            if x["SR"][k]["bridge"] == "1":
                r = ISL[(x["net"], k)]
                rows.append((x["net"], e, k, r["isl_nbus"], r["isl_load_mw"], r["isl_ngen"],
                             f"{r['isl_pmin_mw']}/{r['isl_pmax_mw']}", "pass" if island_ok(ISL, x["net"], k)[0] else "fail"))
    table(out, ["network", "list entry", "branch", "islanded buses", "load (MW)", "units", "sum Pmin/Pmax (MW)",
                "island rule"], rows or [("none",) + ("",) * 7])
    out.append("## The lists")
    out.append("")
    for x in res:
        out.append(f"- {x['net']} ({x['n']}): {x['final']}")
    out.append("")
    out.append("## Every list entry")
    out.append("")
    rows = []
    for x in res:
        for e, k in enumerate(x["final"], 1):
            s = x["SR"][k]; v, b = K[(x["net"], "A", k)]
            rows.append((x["net"], e, k, ST.get(s["status"], s["status"]), f"{float(s['rinf']):.3e}",
                         "yes" if s["bridge"] == "1" else "", v[3], v[5], v[6], v[12], b))
    table(out, ["network", "entry", "branch", "screen status", "screen scaled ‖r‖∞", "bridge", "K = 1 Ipopt status",
                "iterations", "inf_pr (unscaled)", "time (s)", "K = 1 record"], rows)
    return "\n".join(out)


def jobs(data, n=None):
    res, ISL, K = build_all()
    J = []
    for x in res:
        m, c, want = n or x["n"], 0, []
        for k in x["adm"]:
            if c >= m:
                break
            if not island_ok(ISL, x["net"], k)[0]:
                continue
            c += 1
            if (x["net"], "A", k) not in K:
                want.append(k)
        if isinstance(x["pending"], int) and x["pending"] not in want:
            want.append(x["pending"])
        J += [f"{x['net']},A,{k},{os.path.join(os.path.abspath(data), 'data_mp70', x['net'] + '.m')}" for k in want]
    return "\n".join(J) + ("\n" if J else "")


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    G = next((os.path.abspath(x.split("=", 1)[1]) for x in sys.argv[1:] if x.startswith("--records=")), G)
    if not a or a[0] not in ("lists", "report", "jobs") or (a[0] == "jobs" and len(a) < 2):
        print(__doc__); sys.exit(2)
    if a[0] == "jobs":
        print(jobs(a[1], int(a[2]) if len(a) > 2 else None), end=""); sys.exit(0)
    if a[0] == "lists":
        s = lists_file()
        if "--write" in sys.argv:
            open(LISTS, "w").write(s); print("wrote", os.path.relpath(LISTS, os.path.dirname(os.path.dirname(HERE)))); sys.exit(0)
        print(s, end="")
        if "--check" in sys.argv:
            have = open(LISTS).read()
            parse = lambda t: [(m.group(1), m.group(2).replace(" ", "")) for m in re.finditer(r'"(\w+)" => \[([^\]]*)\]', t)]
            same = "IDENTICAL" if s == have else "the lists are equal (comment lines differ)" if parse(s) == parse(have) else "DIFFERS"
            print("check vs benchmarks/instances/scopf_contingencies.jl:", same); sys.exit(0 if same != "DIFFERS" else 1)
        sys.exit(0)
    s = report() + "\n"
    print(s, end="")
    if "--check" in sys.argv:
        same = s == open(os.path.join(G, "lists.md")).read()
        print("check vs records/reference_networks/lists.md:", "IDENTICAL" if same else "DIFFERS"); sys.exit(0 if same else 1)
