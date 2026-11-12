#!/usr/bin/env python3
"""Console summary of a CUTEst run (benchmarks/cutest.jl): solved counts, raw and without the
certified traps, the geometric mean of factorizations over each configuration's own solved set, and
co-solved pairs against a reference configuration, without the instances of the population rule
(benchmarks/instances/cutest_excluded_x0.txt: grad f, c or J not finite at CUTEst's x0; every configuration).

The MadNLP baselines (LiftedKKT, augmented) have no constraint-violation test: their successes count only
if the returned point's raw violation is within the run's constr_viol_tol (post-hoc guard); the unguarded
count is printed in parentheses.

Usage: python3 benchmarks/tables/summary.py <resdir> [--traps=<file>] [--cap=<seconds>] [--ref=<config>] [--cvtol=<t>]
  --traps  instance list of the certified traps (default benchmarks/instances/cutest_traps.txt)
  --cap    a solve counts only if its wall time is within the cap (default: no cap)
  --ref    reference configuration of the co-solved pairs (default W)
  --cvtol  the guard's tolerance (default: constr_viol_tol from the run's config.txt)
"""
import os, sys
from common import (GUARDED, HERE, LOOSE_STATUS, cutest_excluded, drop_cutest_excluded, find, gm, ordered, read_cvtol,
                    read_rows, solved, solved_loose, success)


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 1:
        print(__doc__); return 2
    resdir = pos[0]
    traps_file = opt.get("traps", os.path.join(os.path.dirname(HERE), "instances", "cutest_traps.txt"))
    traps = {l.strip() for l in open(traps_file) if l.strip()}
    cap = float(opt["cap"]) if "cap" in opt else None
    cvtol = read_cvtol(resdir, opt)
    print(f"post-hoc violation guard on {sorted(GUARDED)}: viol <= {cvtol:g}; Ipopt solved = first_order only "
          f"(n+ = also counting its acceptable-level exit, as earlier campaigns did)")
    files = find(resdir, r"cutest__(.+?)__(ma57|ldl)\.csv")
    excluded = cutest_excluded()
    print(f"population rule: {len(excluded)} instances excluded, every configuration "
          f"(benchmarks/instances/cutest_excluded_x0.txt): {' '.join(sorted(excluded))}")
    data = {}
    for cfg, by in files.items():
        for solver, p in by.items():
            data[(cfg, solver)] = drop_cutest_excluded(read_rows(p, "name"), excluded)
    print(f"{'configuration':<28}{'solver':>7}{'rows':>6}{'solved raw':>12}{'non-trap':>10}{'traps':>7}{'gm fact':>9}{'gm iter':>9}")
    for cfg in ordered({c for c, _ in data}):
        for solver in ("ma57", "ldl"):
            rows = data.get((cfg, solver))
            if rows is None:
                continue
            ok = [n for n, r in rows.items() if success(r, cfg, cap, cvtol)]
            raw = sum(1 for r in rows.values() if solved(r, cap))
            nt = [n for n in ok if n not in traps]
            ntrap_rows = sum(1 for n in rows if n not in traps)
            sol = f"{len(ok)}" + (f" ({raw})" if cfg in GUARDED else "")
            if cfg in LOOSE_STATUS:
                loose = sum(1 for r in rows.values() if solved_loose(r, cfg, cap))
                sol += f" ({loose}+)" if loose != len(ok) else ""
            print(f"{cfg:<28}{solver:>7}{len(rows):>6}{sol:>12}{len(nt):>6}/{ntrap_rows:<4}"
                  f"{len(ok) - len(nt):>6}{gm([float(rows[n]['nfact']) for n in ok]):>9.1f}"
                  f"{gm([float(rows[n]['iter']) for n in ok]):>9.1f}")
    ref = opt.get("ref", "W")
    for solver in ("ma57", "ldl"):
        base = data.get((ref, solver))
        if base is None:
            continue
        o = {n for n, r in base.items() if success(r, ref, cap, cvtol)}
        print(f"\nco-solved with {ref} [{solver}] (gm factorizations on the shared set, {ref} / other):")
        for cfg in ordered({c for c, s in data if s == solver and c != ref}):
            rows = data[(cfg, solver)]
            b = {n for n, r in rows.items() if success(r, cfg, cap, cvtol)}
            co = sorted(o & b)
            a1 = gm([float(base[n]["nfact"]) for n in co]); b1 = gm([float(rows[n]["nfact"]) for n in co])
            print(f"  {cfg:<12} shared {len(co):>5}  {a1:8.1f} / {b1:8.1f}  only {ref} {len(o - b):>4}  only {cfg} {len(b - o):>4}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
