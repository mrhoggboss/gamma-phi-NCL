#!/usr/bin/env python3
"""Console summary of the 41 SCOPF instances (the 23 reference-list instances and the 18 protocol instances; the
scoring of tab_gpu_scopf_summary (common.suite_scores): majority of the repetitions, median factorizations of the
succeeding repetitions, LiftedKKT within the runs' constr_viol_tol). Prints: the solved counts (per repetition, by majority, and by group);
the nesting of the majority-solved sets; the instances solved by exactly one configuration and by none; and the
co-solved geometric-mean factorization ratios phi/LK, phi/gamma, phi/SP, gamma/LK over all 41, K <= 16 and K >= 32
(and per group).

Usage: python3 benchmarks/tables/summary_scopf_all.py <scopf resdir> <scopf_pglib resdir> [--cvtol=<t>]
"""
import sys
from common import NAMES, fmt, gm, suite_scores
from tab_gpu_scopf_all import is_pglib, kval, load

SHORTN = {"W": "gamma-NCL", "U6A": "phi-NCL", "S": "MadNCL", "SP": "MadNCL+par", "liftedkkt": "LiftedKKT"}
PAIRS = [("U6A", "liftedkkt"), ("U6A", "W"), ("U6A", "SP"), ("W", "liftedkkt")]


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 2:
        print(__doc__); return 2
    configs, data, names, cvtol, ref = load(pos[0], pos[1], opt)
    nm = {c: SHORTN.get(c, NAMES.get(c, c)) for c in configs}
    sc = {c: suite_scores(data[c], names, c, cvtol) for c in configs}
    S = {c: set(sc[c]["solved"]) for c in configs}
    nf = {c: {n: sc[c]["majority"][n][1] for n in S[c]} for c in configs}
    prot = [n for n in names if is_pglib(n)]
    groups = [("all 41", names), ("reference 23", ref), ("protocol 18", prot),
              ("K <= 16", [n for n in names if kval(n) <= 16]), ("K >= 32", [n for n in names if kval(n) >= 32])]
    print(f"SCOPF, 41 instances ({len(ref)} reference-list + {len(prot)} protocol), majority of the repetitions, "
          f"constr_viol_tol {cvtol:g}; K <= 16: {len(groups[3][1])} instances, K >= 32: {len(groups[4][1])}")
    print()
    print("solved counts (majority; per repetition guarded(raw) over all 41; gm factorizations over the own solved set)")
    print(f"  {'configuration':12s} {'all 41':>7s} {'ref 23':>7s} {'prot 18':>8s} {'K<=16':>6s} {'K>=32':>6s} {'gm fact':>8s}  per repetition")
    for c in configs:
        reps = " ".join(f"{t}:{g}" + (f"({r})" if r != g else "") for t, (g, r) in sorted(sc[c]["per_rep"].items()))
        cnt = [len(S[c] & set(g)) for _, g in groups]
        raw = f" (unguarded {sc[c]['n_raw']})" if sc[c]["n_raw"] != len(S[c]) else ""
        print(f"  {nm[c]:12s} {cnt[0]:>7d} {cnt[1]:>7d} {cnt[2]:>8d} {cnt[3]:>6d} {cnt[4]:>6d} {fmt(sc[c]['cost']):>8s}  {reps}{raw}")
    print()
    print("nesting of the majority-solved sets: entry = instances the row configuration solves and the column one does not")
    print("  " + " " * 12 + "".join(f"{nm[c]:>12s}" for c in configs))
    for a in configs:
        print(f"  {nm[a]:12s}" + "".join(f"{len(S[a] - S[b]):>12d}" for b in configs))
    sup = [(a, b) for a in configs for b in configs if a != b and S[a] >= S[b]]
    print("  containments (A contains B): " + (", ".join(f"{nm[a]} ⊇ {nm[b]}" + (" (equal)" if S[a] == S[b] else "")
                                                        for a, b in sup) or "none"))
    print()
    one = [(n, [c for c in configs if n in S[c]]) for n in names]
    only = [(n, cs[0]) for n, cs in one if len(cs) == 1]
    none = [n for n, cs in one if not cs]
    print(f"solved by exactly one configuration ({len(only)}):")
    for c in configs:
        L = [n for n, x in only if x == c]
        if L:
            print(f"  {nm[c]:12s} {len(L):>2d}: {' '.join(L)}")
    print(f"solved by none ({len(none)}): {' '.join(none)}")
    print()
    print("co-solved geometric-mean factorizations (median over the succeeding repetitions), ratio A/B on the shared set")
    print(f"  {'pair':24s} {'subset':13s} {'shared':>6s} {'gm A':>9s} {'gm B':>9s} {'A/B':>7s}")
    for a, b in PAIRS:
        if a not in S or b not in S:
            continue
        for g, L in groups:
            sh = [n for n in L if n in S[a] and n in S[b]]
            ga, gb = gm([nf[a][n] for n in sh]), gm([nf[b][n] for n in sh])
            print(f"  {nm[a] + ' / ' + nm[b]:24s} {g:13s} {len(sh):>6d} {fmt(ga):>9s} {fmt(gb):>9s} "
                  f"{(f'{ga / gb:.3f}' if sh else '---'):>7s}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
