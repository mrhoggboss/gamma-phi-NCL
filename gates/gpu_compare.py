#!/usr/bin/env python3
"""GPU identity gate: compare one instance's result and per-outer records between this branch and the research
fork. GPU runs are not bitwise reproducible (device reductions), so the comparison reports, rather than
asserts: status, inner iterations and factorizations of both sides, and the first divergence of the per-outer
records (the first outer iteration whose branch or inner-iteration count differs, and the largest relative
difference of μ, ρ and ‖r‖∞ before it).

Usage: python3 gates/gpu_compare.py <instance> <ours_rows.csv> <ours_trace.csv> <ref_rows.csv> <ref_trace> [--ref-kind=wo2|stock]
  ours_*      benchmarks/gpu.jl outputs (rows, --trace)
  ref_rows    the fork's result CSV (column `instance`)
  ref_trace   wo2:   the fork's wo2_trace CSV (kernel_baseline.jl, KERNELBENCH_WO2=1)
              stock: the comparator tree's per-outer stock_outer.csv (scopf_stock.jl, KERNELBENCH_STOCKLOG=1)
"""
import csv, sys

BR = {"E": "extrap", "M": "mu_reduce", "R": "rho_bump", "X": "maxiter"}


def rel(a, b):
    if a == b:
        return 0.0
    return abs(a - b) / max(abs(a), abs(b), 1e-300)


def load_trace(path, kind, instance):
    out = []
    rows = list(csv.DictReader(open(path)))
    if kind == "stock":
        prev = None
        for r in rows:
            cum = int(r["cumfact"])
            out.append({"branch": BR.get(r["branch"], r["branch"]), "mu": float(r["mu_used"]), "rho": float(r["rho_used"]),
                        "pr": float(r["pr"]), "inner": int(r["inner"]), "fact": None if prev is None else cum - prev})
            prev = cum
        return out
    key = "instance" if "instance" in rows[0] else "name"
    for r in rows:
        if r[key] != instance:
            continue
        out.append({"branch": r["branch"], "mu": float(r["mu"]), "rho": float(r["rho"]), "pr": float(r["pr_feas"]),
                    "inner": int(r["inner_iters"]), "fact": int(r["inner_fact"]) + int(r["extrap_fact"])})
    return out


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 5:
        print(__doc__); return 2
    inst, ours_rows, ours_trace, ref_rows, ref_trace = pos
    kind = opt.get("ref-kind", "wo2")
    a = next(r for r in csv.DictReader(open(ours_rows)) if r["instance"] == inst)
    b = next(r for r in csv.DictReader(open(ref_rows)) if r["instance"] == inst)
    print(f"  result   ours: {a['status']} iter={a['iter']} nfact={a['nfact']}   fork: {b['status']} iter={b['iter']} nfact={b['nfact']}")
    ta, tb = load_trace(ours_trace, "wo2", inst), load_trace(ref_trace, kind, inst)
    first, worst = None, 0.0
    for j, (x, y) in enumerate(zip(ta, tb), start=1):
        if x["branch"] != y["branch"] or x["inner"] != y["inner"]:
            first = j
            break
        worst = max(worst, rel(x["mu"], y["mu"]), rel(x["rho"], y["rho"]), rel(x["pr"], y["pr"]))
    print(f"  per-outer: ours {len(ta)} outers, fork {len(tb)} outers; " +
          (f"first divergence at outer {first} (ours {ta[first-1]['branch']}/{ta[first-1]['inner']} inner, "
           f"fork {tb[first-1]['branch']}/{tb[first-1]['inner']} inner)" if first else "no divergence in branch or inner iterations")
          + f"; largest relative difference of mu/rho/pr before it: {worst:.2e}")
    same = a["status"] == b["status"]
    print(f"  VERDICT status {'equal' if same else 'DIFFERENT'}; iter {int(a['iter']) - int(b['iter']):+d}, "
          f"nfact {int(a['nfact']) - int(b['nfact']):+d} (ours - fork)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
