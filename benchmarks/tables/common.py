"""Shared helpers of the table and figure emitters (Python standard library only).

Configuration tokens in the result files are mapped to the names used in the paper. Every emitter
writes LaTeX (booktabs tables, pgfplots figures) under benchmarks/out/tables unless --out is given.
"""
import csv, glob, math, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), "out", "tables")

# Paper names. TODO: the power-kernel cell's name is a placeholder, deferred until the shipped variant is
# confirmed.
NAMES = {
    "W": "$(\\gamma,\\varphi)$-MadNCL",
    "S": "MadNCL",
    "SP": "MadNCL + parameters",
    "U6A": "power kernel ($p=6$, $\\lambda=10^{-2}$)",
    "liftedkkt": "LiftedKKT $\\epsilon=10^{-8}$",
    "ipopt": "Ipopt",
    "madnlp": "MadNLP augmented",
}
ORDER = ["W", "U6A", "S", "SP", "liftedkkt", "ipopt", "madnlp"]
SUCCESS = {"SOLVE_SUCCEEDED", "first_order"}


def gm(v):
    v = [x for x in v if x > 0]
    return math.exp(sum(map(math.log, v)) / len(v)) if v else float("nan")


def fmt(x, digits=1):
    return "---" if x != x else f"{x:.{digits}f}"


def read_rows(path, key):
    with open(path) as f:
        return {r[key]: r for r in csv.DictReader(f)}


def find(resdir, pattern):
    """Files matching `pattern` (a regex with one group for the configuration and optionally one for the
    tag) under `resdir`, as {config: {tag: path}}."""
    out = {}
    for p in sorted(glob.glob(os.path.join(resdir, "*.csv"))):
        m = re.fullmatch(pattern, os.path.basename(p))
        if m:
            cfg = m.group(1)
            tag = m.group(2) if m.lastindex and m.lastindex >= 2 else ""
            out.setdefault(cfg, {})[tag] = p
    return out


def ordered(configs):
    return [c for c in ORDER if c in configs] + sorted(c for c in configs if c not in ORDER)


# Solvers without a constraint-violation test of their own (MadNLP: LiftedKKT and the augmented system).
# Their successes are counted only if the returned point's raw all-rows violation (`viol` on the CPU,
# `pr_res` on the GPU) is within the run's constr_viol_tol: the same guard the MadNCL configurations apply
# inside their own success test and Ipopt applies through its constr_viol_tol. The unguarded count is
# printed next to it.
GUARDED = {"liftedkkt", "madnlp"}


def violation(r):
    v = r.get("viol", r.get("pr_res", "nan"))
    try:
        return float(v)
    except ValueError:
        return float("nan")


def solved(r, cap=None, cvtol=None):
    """The solver's own success test passed, within the wall-time cap, and (if cvtol is given) with the
    returned point's raw violation at most cvtol."""
    if r is None or r["status"] not in SUCCESS:
        return False
    if cap is not None:
        try:
            if not float(r.get("time", r.get("wall", "nan"))) <= cap:
                return False
        except ValueError:
            return False
    return cvtol is None or violation(r) <= cvtol


def success(r, config, cap=None, cvtol=None):
    """Success as scored in the tables: the post-hoc violation guard applies to the GUARDED solvers only."""
    return solved(r, cap, cvtol if config in GUARDED else None)


def read_cvtol(resdir, opt):
    """constr_viol_tol of the run, from --cvtol or from the configuration files the drivers wrote."""
    if "cvtol" in opt:
        return float(opt["cvtol"])
    vals = set()
    for p in glob.glob(os.path.join(resdir, "config*.txt")):
        m = re.search(r"constr_viol_tol=([0-9.eE+-]+)", open(p).read())
        if m:
            vals.add(float(m.group(1)))
    if len(vals) > 1:
        raise SystemExit(f"the runs in {resdir} used different constr_viol_tol values {sorted(vals)}; pass --cvtol")
    if not vals:
        print("  (no constr_viol_tol in the configuration files: using 1e-4)")
        return 1e-4
    return vals.pop()


def count_cell(guarded, raw, config):
    """`guarded (raw)` for the guarded solvers when the guard removed solves, else the count."""
    return f"{guarded} ({raw})" if config in GUARDED and guarded != raw else str(guarded)


def majority(rows_by_tag, name, config=None, cvtol=None):
    """(solved by majority?, median factorization count over the succeeding repetitions, median iterations)."""
    rs = [rows.get(name) for rows in rows_by_tag.values()]
    ok = [r for r in rs if success(r, config, None, cvtol)]
    maj = len(ok) * 2 > len(rs)
    if not ok:
        return maj, float("nan"), float("nan")
    return maj, statistics.median(float(r["nfact"]) for r in ok), statistics.median(float(r["iter"]) for r in ok)


def write(outdir, fname, lines):
    os.makedirs(outdir, exist_ok=True)
    p = os.path.join(outdir, fname)
    with open(p, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"  -> {p}")
    return p


def assert_no_tokens(text, tokens=("U6A", "liftedkkt", "madnlp", "_r1", "k2r", "ma57")):
    body = "\n".join(l for l in text.split("\n") if not l.startswith("%"))
    bad = [t for t in tokens if t in body]
    assert not bad, f"internal tokens in the output: {bad}"
