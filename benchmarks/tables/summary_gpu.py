#!/usr/bin/env python3
"""Console summary of a GPU suite (benchmarks/gpu.jl): per configuration, the solved count of every repetition, the
per-instance majority over the repetitions, and the geometric mean over the majority-solved set of the median
factorization count of the succeeding repetitions (the scoring of tab_gpu_opf.py, for any suite). LiftedKKT
successes count only within the run's constr_viol_tol (post-hoc guard; the unguarded count in parentheses).

Usage: python3 benchmarks/tables/summary_gpu.py <resdir> <suite> [--subset=<instance list>] [--cvtol=<t>]
  reads <resdir>/<suite>__<config>__<tag>.csv
"""
import re, sys
from common import NAMES, count_cell, find, fmt, ordered, read_cvtol, read_rows, suite_scores


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 2:
        print(__doc__); return 2
    resdir, suite = pos
    cvtol = read_cvtol(resdir, opt)
    files = find(resdir, re.escape(suite) + r"__(.+?)__(.+?)\.csv")
    if not files:
        print(f"no {suite}__<config>__<tag>.csv in {resdir}"); return 1
    tables = {c: {t: read_rows(p, "instance") for t, p in tags.items()} for c, tags in files.items()}
    names = sorted(set().union(*(set(r) for tags in tables.values() for r in tags.values())))
    if "subset" in opt:
        keep = {l.strip() for l in open(opt["subset"]) if l.strip()}
        names = [n for n in names if n in keep]
    print(f"{suite}: {len(names)} instances, constr_viol_tol {cvtol:g}")
    print(f"  {'configuration':28s} {'per repetition':24s} {'majority':>10s} {'gm fact':>8s}")
    for c in ordered(tables):
        s = suite_scores(tables[c], names, c, cvtol)
        reps = " ".join(f"{t}:{g}" + (f"({r})" if c in ("liftedkkt",) and r != g else "")
                        for t, (g, r) in sorted(s["per_rep"].items()))
        print(f"  {NAMES.get(c, c) + ' [' + c + ']':28s} {reps:24s} "
              f"{count_cell(len(s['solved']), s['n_raw'], c):>10s} {fmt(s['cost']):>8s}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
