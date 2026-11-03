"""Shared helpers of the table and figure emitters (Python standard library only).

Configuration tokens in the result files are mapped to the names used in the paper. Every emitter
writes LaTeX (booktabs tables, pgfplots figures) under benchmarks/out/tables unless --out is given.
"""
import csv, glob, math, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), "out", "tables")

# Paper names. The power-kernel cell's name is not fixed yet (Yifan's call).
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


def solved(r, cap=None):
    if r is None or r["status"] not in SUCCESS:
        return False
    if cap is not None:
        try:
            return float(r.get("time", r.get("wall", "nan"))) <= cap
        except ValueError:
            return False
    return True


def majority(rows_by_tag, name):
    """(solved by majority?, median factorization count over the succeeding repetitions, median iterations)."""
    rs = [rows.get(name) for rows in rows_by_tag.values()]
    ok = [r for r in rs if solved(r)]
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
