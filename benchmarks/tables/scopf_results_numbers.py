#!/usr/bin/env python3
"""scopf_results_numbers -- every number the SCOPF Results paragraph quotes, from the result CSVs, with the tables'
scoring (common.suite_scores through tab_gpu_scopf_all.load; Python standard library only; seconds). Not a float.

  python3 benchmarks/tables/scopf_results_numbers.py <scopf resdir> <scopf_pglib resdir>

Prints: the summary table's per-repetition counts (and how many instances each repetition covers), majority counts and
geometric means; the LiftedKKT violation-guard count; the nesting of the majority-solved sets; the majority solves
outside phi-NCL's set, the instances solved by exactly one configuration and by none; the co-solved factorization ratios
phi/LK, phi/gamma, phi/SP, gamma/LK with their shared counts (all 41, reference networks, PGLIB networks, K <= 16,
K >= 32); the ACTIVSg500 ladder per configuration; the per-K counts on the PGLIB networks.
"""
import sys
from common import fmt, gm, solved, success, suite_scores
from tab_gpu_scopf_all import is_pglib, kval, load

N = {"W": "gamma-NCL", "U6A": "phi-NCL", "S": "MadNCL", "SP": "MadNCL+par", "liftedkkt": "LiftedKKT"}


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 2:
        print(__doc__); return 2
    configs, data, names, cvtol, ref = load(pos[0], pos[1], opt)
    prot = [n for n in names if is_pglib(n)]
    tags = sorted({t for c in configs for t in data[c]})
    sc = {c: suite_scores(data[c], names, c, cvtol) for c in configs}
    S = {c: set(sc[c]["solved"]) for c in configs}
    nf = {c: {n: sc[c]["majority"][n][1] for n in S[c]} for c in configs}
    p = print
    p(f"SCOPF, {len(names)} instances ({len(ref)} reference networks + {len(prot)} PGLIB networks), constr_viol_tol {cvtol:g}")
    cover = {t: sum(1 for n in names if n in data[configs[0]][t]) for t in tags}
    p(f"\n== summary table: per repetition (instances covered: {cover}), majority, gm factorizations")
    for c in configs:
        p(f"  {N[c]:11s} reps {[sc[c]['per_rep'][t][0] for t in tags]}  solved {len(S[c]):2d}  gm {fmt(sc[c]['cost'])}")
    lk = "liftedkkt"
    if lk in configs:
        rem = sum(1 for t, rows in data[lk].items() for n in names if solved(rows.get(n)) and not success(rows.get(n), lk, None, cvtol))
        p(f"\n== LiftedKKT violation guard: {rem} runs removed; majority {len(S[lk])} guarded vs {sc[lk]['n_raw']} unguarded; "
          f"per repetition (guarded, raw) {sorted(sc[lk]['per_rep'].items())}")
    p("\n== nesting: entry = instances the row configuration solves and the column one does not")
    p("  " + " " * 12 + "".join(f"{N[c]:>12s}" for c in configs))
    for a in configs:
        p(f"  {N[a]:12s}" + "".join(f"{len(S[a] - S[b]):>12d}" for b in configs))
    p("  containments: " + (", ".join(f"{N[a]} ⊇ {N[b]}" for a in configs for b in configs if a != b and S[a] >= S[b]) or "none"))
    if "U6A" in configs:
        p("\n== majority solves outside phi-NCL's set: " + str({N[c]: sorted(S[c] - S["U6A"]) for c in configs if c != "U6A" and S[c] - S["U6A"]}))
    one = {N[c]: [n for n in names if [x for x in configs if n in S[x]] == [c]] for c in configs}
    p("== solved by exactly one configuration: " + str({k: v for k, v in one.items() if v}))
    none = [n for n in names if not any(n in S[c] for c in configs)]
    p(f"== solved by none ({len(none)}): {none}")
    groups = [("all", names), ("reference", ref), ("PGLIB", prot), ("K<=16", [n for n in names if kval(n) <= 16]),
              ("K>=32", [n for n in names if kval(n) >= 32])]
    p("\n== co-solved geometric-mean factorizations (median over the succeeding repetitions), ratio A/B, shared n")
    for a, b in (("U6A", "liftedkkt"), ("U6A", "W"), ("U6A", "SP"), ("W", "liftedkkt")):
        if a not in S or b not in S:
            continue
        for g, L in groups:
            sh = [n for n in L if n in S[a] and n in S[b]]
            ga, gb = gm([nf[a][n] for n in sh]), gm([nf[b][n] for n in sh])
            p(f"  {N[a] + ' / ' + N[b]:24s} {g:10s} n={len(sh):2d}  {fmt(ga):>8s} / {fmt(gb):>8s}  " + (f"{ga / gb:.3f}" if sh else "---"))
    ks = sorted(kval(n) for n in names if n.startswith("case_ACTIVSg500_"))
    p("\n== ACTIVSg500 ladder (majority solved): K = " + str(ks))
    for c in configs:
        p(f"  {N[c]:11s} " + " ".join(("S" if f"case_ACTIVSg500_nK{k}" in S[c] else "-") for k in ks)
          + f"   solved at K = {[k for k in ks if f'case_ACTIVSg500_nK{k}' in S[c]]}")
    p("\n== PGLIB networks per K (majority solved)")
    for k in sorted({kval(n) for n in prot}):
        L = [n for n in prot if kval(n) == k]
        p(f"  K={k:2d} (n={len(L)}) " + "  ".join(f"{N[c]} {len(S[c] & set(L))}" for c in configs))
    p("\n== counts by group: reference " + str({N[c]: len(S[c] & set(ref)) for c in configs})
      + " | PGLIB " + str({N[c]: len(S[c] & set(prot)) for c in configs}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
