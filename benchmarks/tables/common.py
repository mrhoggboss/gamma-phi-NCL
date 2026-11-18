"""Shared helpers of the table emitters (Python standard library only).

Configuration tokens in the result files are mapped to the names used in the paper. Every table emitter writes LaTeX
tables (booktabs; longtable for the appendices) under benchmarks/out/tables unless --out is given.
"""
import csv, glob, math, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), "out", "tables")

# Paper names of the configurations: the two proposed methods are γ-NCL (adaptive weights, configuration W) and
# φ-NCL (power kernel p = 6, λ = 1e-2, configuration U6A).
NAMES = {
    "W": "$\\gamma$-NCL",
    "S": "MadNCL",
    "SP": "MadNCL + parameters",
    "U6A": "$\\varphi$-NCL",
    "liftedkkt": "LiftedKKT $\\varepsilon=10^{-8}$",
    "ipopt": "Ipopt",
    "madnlp": "MadNLP-aug",
}
# Two-part names for column headers (first line, second line), so that a configuration's header is no wider than its
# columns. Row-label tables keep the one-line NAMES.
NAMES2 = {
    "W": ("$\\gamma$-NCL", ""),
    "U6A": ("$\\varphi$-NCL", ""),
    "S": ("MadNCL", ""),
    "SP": ("MadNCL", "+ parameters"),
    "liftedkkt": ("LiftedKKT", "$\\varepsilon=10^{-8}$"),
    "ipopt": ("Ipopt", ""),
    "madnlp": ("MadNLP-aug", ""),
}


# Physical landscape pages for the appendix longtables: the PDF page size is swapped with the pdfTeX/XeTeX page
# primitives \\pdfpagewidth/\\pdfpageheight and the text is laid out on the rotated page with geometry's
# \\newgeometry. No page-rotation attribute and no pdflscape: the /Rotate attribute that pdflscape sets is not
# honoured by every PDF toolchain. LuaTeX would need \\pagewidth/\\pageheight instead.
LANDSCAPE_REQUIRES = ["% REQUIRES: booktabs, longtable, geometry",
                      "% Landscape pages: pdfTeX/XeTeX page-size primitives \\pdfpagewidth/\\pdfpageheight + geometry (no pdflscape)."]
LANDSCAPE_BEGIN = ["\\clearpage", "\\pdfpagewidth=\\paperheight \\pdfpageheight=\\paperwidth",
                   "\\newgeometry{layoutwidth=\\paperheight,layoutheight=\\paperwidth,margin=1in}"]
LANDSCAPE_END = ["\\clearpage", "\\pdfpagewidth=\\paperwidth \\pdfpageheight=\\paperheight", "\\restoregeometry"]


# Printed names and row order of the SCOPF instances (the 23 of the reference networks, the 18 of the PGLIB networks).
def scopf_ref_tex(name):
    """Short name of a reference-network instance: case118_nK100 -> \\texttt{case118}@100, case_ACTIVSg2000_nK16 ->
    \\texttt{ACTIVSg2000}@16, case1354pegase_nK8 -> \\texttt{1354pegase}@8."""
    m = re.fullmatch(r"(.+?)_nK(\d+)", name)
    if not m:
        return "\\texttt{" + name.replace("_", "\\_") + "}"
    net = m[1][5:] if m[1].startswith("case_") else (m[1][4:] if re.fullmatch(r"case\d+pegase", m[1]) else m[1])
    return "\\texttt{" + net.replace("_", "\\_") + "}@" + m[2]


PGLIB_SCOPF_PAT = re.compile(r"pglib_opf_case(\d+)_(.+?)(_B)?_nK(\d+)")


def pglib_scopf_parts(name):
    """(buses, network, order, K) of a PGLIB-network instance name such as pglib_opf_case500_goc_B_nK8."""
    m = PGLIB_SCOPF_PAT.fullmatch(name)
    if not m:
        raise SystemExit(f"unexpected instance name {name}")
    return int(m[1]), f"{m[1]}_{m[2]}", "B" if m[3] else "A", int(m[4])


def pglib_scopf_tex(name):
    """Printed name of a PGLIB-network instance: network, order and K (\\texttt{500\\_goc~A}@8)."""
    _, net, order, k = pglib_scopf_parts(name)
    return "\\texttt{" + net.replace("_", "\\_") + "~" + order + "}@" + str(k)


REF_NETS = ["case118", "case300", "case_ACTIVSg200", "case_ACTIVSg500", "case_ACTIVSg2000", "case1354pegase", "case2869pegase"]
REF_PAT = re.compile(r"(case.+?)_nK(\d+)")


def is_pglib(name):
    return name.startswith("pglib_opf_")


def scopf_key(name):
    """Row order: reference networks in REF_NETS order, then the PGLIB networks by bus count, network, order; K
    increasing within each."""
    if is_pglib(name):
        b, net, order, k = pglib_scopf_parts(name)
        return (1, b, net, order, k)
    m = REF_PAT.fullmatch(name)
    if not m or m[1] not in REF_NETS:
        raise SystemExit(f"unexpected reference instance name {name}")
    return (0, REF_NETS.index(m[1]), "", "", int(m[2]))


def buses(name):
    if is_pglib(name):
        return pglib_scopf_parts(name)[0]
    return int(re.search(r"(\d+)", REF_PAT.fullmatch(name)[1])[1])


def tex(name):
    return pglib_scopf_tex(name) if is_pglib(name) else scopf_ref_tex(name)


def name2(c):
    return NAMES2.get(c, (NAMES.get(c, c), ""))


def group_header(configs, span, lead, lead_labels=None):
    """Header rows of a table whose configurations head groups of `span` columns after `lead` leading columns: the first
    parts of the names, then the second parts (omitted when every second part is empty), then, for span > 1, cmidrules
    under the second row. `lead_labels` (one per leading column) go on the last name row (tables without a separate
    column-label row)."""
    def cell(t):
        return f"\\multicolumn{{{span}}}{{c}}{{{t}}}" if span > 1 else t
    parts = [name2(c) for c in configs]
    rows = [[p[0] for p in parts]]
    if any(p[1] for p in parts):
        rows.append([p[1] for p in parts])
    out = []
    for i, r in enumerate(rows):
        lead_cells = lead_labels if (lead_labels and i == len(rows) - 1) else [""] * lead
        out.append(" & ".join(list(lead_cells) + [cell(t) for t in r]) + " \\\\")
    if span > 1:
        out.append(" ".join(f"\\cmidrule(lr){{{lead + 1 + span * i}-{lead + span * (i + 1)}}}" for i in range(len(configs))))
    return out


# Every emitter shows exactly the configurations of ORDER that are present in its result directory, in this order;
# any other configuration found there is left out.
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
    return [c for c in ORDER if c in configs]


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


# Ipopt's acceptable-level exit (status "acceptable": its acceptable_tol 1e-6 met, not the common tolerance) is not
# a success; the count that includes it is printed in parentheses with a dagger.
LOOSE_STATUS = {"ipopt": {"acceptable"}}


def solved_loose(r, config, cap=None):
    """`solved`, but also counting the configuration's LOOSE_STATUS exits."""
    if r is not None and r["status"] in LOOSE_STATUS.get(config, ()):
        r = dict(r, status="first_order")
    return solved(r, cap)


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


# Per-repetition cells of the two appendix tables (tab_pglib_appendix, tab_scopf_all_appendix): the factorization
# count of a repetition that solves, else the reason for the non-solve as one short italic word, from one fixed
# abbreviated vocabulary for both tables (the abbreviations keep the tables at a readable type size).
FAIL_WORD = {"INFEASIBLE_PROBLEM_DETECTED": "infeas.", "MAXIMUM_ITERATIONS_EXCEEDED": "max it.",
             "MAXIMUM_WALLTIME_EXCEEDED": "wall", "RESTORATION_FAILED": "restor.",
             "SEARCH_DIRECTION_BECOMES_TOO_SMALL": "step"}


def rep_cell(r, c, cvtol):
    """The cell of one repetition: its factorization count if it solves (the scoring of the tables: success, with the
    post-hoc guard for the GUARDED solvers), else \\textit{<reason>} (FAIL_WORD; "error" for any other status). A missing
    row or a solve removed by the guard has no word: it raises, so that the vocabulary is extended first."""
    if r is None:
        raise SystemExit(f"rep_cell: no row for {c}; the failure codes of the caption have none for a missing run")
    if success(r, c, None, cvtol):
        return f"{float(r['nfact']):.0f}"
    if r["status"] in SUCCESS:
        raise SystemExit(f"rep_cell: a {c} solve removed by the post-hoc guard; the caption's codes have none for it")
    return "\\textit{" + FAIL_WORD.get(r["status"], "error") + "}"


def suite_scores(rows_by_tag, names, config, cvtol):
    """Scores of one configuration over `names`: per-repetition solved counts (guarded, raw), the majority-solved
    set (guarded) with the median factorizations, the raw majority count, and the geometric-mean cost."""
    per = {t: (sum(1 for n in names if success(rows.get(n), config, None, cvtol)),
               sum(1 for n in names if solved(rows.get(n)))) for t, rows in rows_by_tag.items()}
    maj = {n: majority(rows_by_tag, n, config, cvtol) for n in names}
    solved_set = [n for n in names if maj[n][0]]
    nraw = sum(1 for n in names if majority(rows_by_tag, n)[0])
    return {"per_rep": per, "solved": solved_set, "majority": maj, "n_raw": nraw,
            "cost": gm([maj[n][1] for n in solved_set])}


def load(resdir, opt):
    """The SCOPF results: (configs, {config: {tag: {instance: row}}}, instance names in table order (scopf_key), cvtol).
    Reads <resdir>/scopf__<config>__<tag>.csv."""
    cvtol = read_cvtol(resdir, opt)
    files = find(resdir, r"scopf__(.+?)__(.+?)\.csv")
    configs = ordered(files)
    data = {c: {t: read_rows(files[c][t], "instance") for t in files[c]} for c in configs}
    names = sorted({n for c in configs for rows in data[c].values() for n in rows}, key=scopf_key)
    return configs, data, names, cvtol
