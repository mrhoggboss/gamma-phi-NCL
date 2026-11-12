#!/usr/bin/env python3
"""reference_check -- the reference benchmark's SCOPF contingency lists under the protocol, recomputed from the records
(Python standard library only; seconds).

  python3 benchmarks/scopf_protocol/reference_check.py [screens|k1|all] [--check]
  python3 benchmarks/scopf_protocol/reference_check.py jobs <data dir>      (the K = 1 jobs file of k1_10000it_3600s)

screens  The full screens of records/reference_screens/ (every in-service branch of case118, case300, case_ACTIVSg200 and
         case_ACTIVSg500, in increasing branch key, at penalty 1e8 with the protocol's admission rule: scaled residual
         ||r||_inf < 1e-4, any status, bridges kept) against the published lists
         (benchmarks/instances/scopf_contingencies_published.jl, the reference benchmark's lists as published): for case118, case300 and case_ACTIVSg200, whether the first
         len(list) admitted outages equal the list; for case_ACTIVSg500, the first differing entry and the overlaps of the
         first 10/16/32/64/100. The output has the format of the original comparison, records/reference_screens/
         S0p_compare.txt; with --check it must equal that file line for line.
k1       The single-contingency (K = 1) verifications of records/k1/reference/<budget>/ (one row per outage, written by
         julia/k1_verify.jl): per list and budget, the list entries covered, the counts by Ipopt status, the maximum
         iterations and wall time, and every outage that did not end Solve_Succeeded with its unscaled constraint
         violation. With --check the output must equal records/k1/reference/summary.txt.
jobs     The jobs file (lines <net>,<label>,<branch>,<case file>) of the protocol-budget verifications recorded in
         records/k1/reference/k1_10000it_3600s/, for julia/k1_verify.jl, with the case files under <data dir> (the
         directory of benchmarks/instances/fetch_scopf_data.sh: data/ and data_mp70/).
"""
import collections, csv, glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REC = os.path.join(HERE, "records")
# the reference benchmark's lists as published (benchmarks/instances/scopf_contingencies_published.jl: a byte copy of
# benchmarks/instances/scopf_contingencies.jl before three of its lists were replaced by the protocol lists,
# reference_regen.py lists)
LISTS_FILE = os.path.join(os.path.dirname(HERE), "instances", "scopf_contingencies_published.jl")


def published_lists():
    src = open(LISTS_FILE).read()
    return {m.group(1): [int(x) for x in m.group(2).replace("\n", " ").split(",") if x.strip()]
            for m in re.finditer(r'"(\w+)" => \[([^\]]*)\]', src)}


def screens():
    L = published_lists()
    D = os.path.join(REC, "reference_screens")
    out, ok_all = [], True
    for c in ("case118", "case300", "case_ACTIVSg200", "case_ACTIVSg500"):
        R = list(csv.DictReader(open(os.path.join(D, f"{c}_full_rho1e8.csv"))))
        adm = [int(r["k"]) for r in R if r["admitted"] == "1"]
        C = L[c]; n = len(C)
        st = collections.Counter(int(r["status"]) for r in R)
        sa = collections.Counter(int(r["status"]) for r in R if r["admitted"] == "1")
        fd = next((i + 1 for i, (a, b) in enumerate(zip(adm, C)) if a != b), None)
        if fd is None and len(adm) < n:
            fd = len(adm) + 1
        eq = adm[:n] == C
        out.append(f"{c}: screened {len(R)} (status counts {dict(st)}), bridges {sum(r['bridge'] == '1' for r in R)} "
                   f"(admitted {sum(r['bridge'] == '1' and r['admitted'] == '1' for r in R)}), admitted {len(adm)} (by status {dict(sa)})")
        if c != "case_ACTIVSg500":
            ok_all &= eq
            out.append(f"  first {n} admitted == EPSR list: {eq}" + ("" if eq else
                       f" (first difference at entry {fd}: ours {adm[fd-1] if fd <= len(adm) else None}, list {C[fd-1]}; "
                       f"only ours {sorted(set(adm[:n]) - set(C))[:20]}, only list {sorted(set(C) - set(adm[:n]))[:20]})"))
        else:
            out.append(f"  vs the EPSR 100-list: first differing index {fd}; overlaps of the first 10/16/32/64/100: " +
                       "/".join(str(len(set(adm[:k]) & set(C[:k]))) for k in (10, 16, 32, 64, 100)))
            out.append(f"  ours[:20] {adm[:20]}\n  list[:20] {C[:20]}")
    out.append("S0' (case118, case300, case_ACTIVSg200): " + ("PASS" if ok_all else "FAIL"))
    return "\n".join(out) + "\n"


CLASS = {"Solve_Succeeded": "SOLVED", "Infeasible_Problem_Detected": "LOCALLY_INFEASIBLE",
         "Maximum_Iterations_Exceeded": "MAXITER", "Maximum_WallTime_Exceeded": "WALL"}
VINTAGE = {"EPSR": "MATPOWER 7.0 file (fetch_scopf_data.sh data_mp70/, or data/ where identical)",
           "EPSRmp81": "MATPOWER 8.1 file (fetch_scopf_data.sh data/case300.m)"}


def entries(keys, C):
    """The 1-based positions in the published list C of the verified branch keys, as compact ranges."""
    pos = sorted(C.index(k) + 1 for k in keys if k in C)
    rng, i = [], 0
    while i < len(pos):
        j = i
        while j + 1 < len(pos) and pos[j + 1] == pos[j] + 1:
            j += 1
        rng.append(f"{pos[i]}" if i == j else f"{pos[i]}-{pos[j]}")
        i = j + 1
    extra = sorted(k for k in keys if k not in C)
    return ", ".join(rng) + (f"; not in the list: {extra}" if extra else "")


# The protocol-budget K = 1 verifications as run (list, label, data subdirectory, first and last list entry).
JOBS = [("case_ACTIVSg500", "EPSR", "data_mp70", 65, 100), ("case300", "EPSR", "data_mp70", 1, 100),
        ("case300", "EPSRmp81", "data", 1, 100), ("case_ACTIVSg200", "EPSR", "data_mp70", 1, 100),
        ("case2869pegase", "EPSR", "data", 1, 16), ("case_ACTIVSg2000", "EPSR", "data_mp70", 1, 16),
        ("case1354pegase", "EPSR", "data", 1, 32)]


def jobs(data):
    L = published_lists()
    return "".join(f"{net},{lab},{k},{os.path.join(os.path.abspath(data), sub, net + '.m')}\n"
                   for net, lab, sub, a, b in JOBS for k in L[net][a - 1:b])


def k1():
    L = published_lists()
    D = os.path.join(REC, "k1", "reference")
    groups = collections.defaultdict(list)
    for budget in sorted(d for d in os.listdir(D) if os.path.isdir(os.path.join(D, d))):
        for p in glob.glob(os.path.join(D, budget, "*.csv")):
            f = open(p).read().strip().split(",")
            groups[(f[0], f[1], budget)].append(f)
    out = ["Single-contingency (K = 1) verification of the published lists: harness scopf_model with the gpu.jl SCOPF",
           "settings, Ipopt + MA57, tol 1e-8; budget = <max_iter>it_<wall>s of the directory. viol = Ipopt's unscaled",
           "constraint violation at exit; worst = the largest violation over every row of the JuMP model at exit.", ""]
    hdr = "| list | data | budget | entries verified | SOLVED | LOCALLY_INFEASIBLE | MAXITER | WALL | other | max iter | max wall (s) |"
    out += [hdr, "|" + "---|" * 11]
    bad = []
    for (net, lab, budget) in sorted(groups, key=lambda g: (g[0], g[2], g[1])):
        rows = groups[(net, lab, budget)]
        cnt = collections.Counter(CLASS.get(r[3], "other") for r in rows)
        keys = [int(r[2]) for r in rows]
        out.append(f"| {net} | {lab} | {budget} | {entries(keys, L.get(net, []))} | {cnt['SOLVED']} | "
                   f"{cnt['LOCALLY_INFEASIBLE']} | {cnt['MAXITER']} | {cnt['WALL']} | {cnt['other']} | "
                   f"{max(int(r[5]) for r in rows)} | {max(float(r[12]) for r in rows)} |")
        for r in sorted(rows, key=lambda r: L.get(net, []).index(int(r[2])) if int(r[2]) in L.get(net, []) else 10**9):
            if r[3] != "Solve_Succeeded":
                bad.append(f"- {net} {lab} {budget} branch {r[2]}: {r[3]} after {r[5]} iterations, {r[12]} s; "
                           f"viol {r[6]}, worst {r[17]} ({r[14]}, {r[15]} {r[16]})")
    out += ["", "Data: " + "; ".join(f"{k} = {v}" for k, v in VINTAGE.items()) + ".", ""]
    out += (["Outages that did not end Solve_Succeeded:"] + bad) if bad else ["Every verified outage ended Solve_Succeeded."]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    what = args[0] if args else "all"
    check = "--check" in sys.argv
    rc = 0
    if what in ("screens", "all"):
        s = screens(); print(s, end="")
        if check:
            same = s == open(os.path.join(REC, "reference_screens", "S0p_compare.txt")).read()
            print("check vs records/reference_screens/S0p_compare.txt:", "IDENTICAL" if same else "DIFFERS"); rc |= not same
    if what in ("k1", "all"):
        what == "all" and print()
        s = k1(); print(s, end="")
        if check:
            same = s == open(os.path.join(REC, "k1", "reference", "summary.txt")).read()
            print("check vs records/k1/reference/summary.txt:", "IDENTICAL" if same else "DIFFERS"); rc |= not same
    if what == "jobs":
        if len(args) < 2:
            print(__doc__); sys.exit(2)
        print(jobs(args[1]), end="")
    elif what not in ("screens", "k1", "all"):
        print(__doc__); rc = 2
    sys.exit(rc)
