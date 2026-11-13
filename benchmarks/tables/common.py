"""Shared helpers of the table emitters and console summaries (Python standard library only).

Configuration tokens in the result files are mapped to the names used in the paper. Every table emitter writes LaTeX
tables (booktabs; longtable for the appendices) under benchmarks/out/tables unless --out is given.
"""
import csv, glob, math, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), "out", "tables")

# Paper names (settled by Yifan 2026-11-03): the two proposed methods of the (γ, φ)-NCL framework are γ-NCL
# (adaptive weights, configuration W) and φ-NCL (power kernel p = 6, λ = 1e-2, configuration U6A).
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
# columns (Yifan 2026-11-10: tables overflowed the page). Row-label tables keep the one-line NAMES.
NAMES2 = {
    "W": ("$\\gamma$-NCL", ""),
    "U6A": ("$\\varphi$-NCL", ""),
    "S": ("MadNCL", ""),
    "SP": ("MadNCL", "+ parameters"),
    "liftedkkt": ("LiftedKKT", "$\\varepsilon=10^{-8}$"),
    "ipopt": ("Ipopt", ""),
    "madnlp": ("MadNLP-aug", ""),
}


# Physical landscape pages for the appendix longtables (Yifan 2026-11-10: on Overleaf the /Rotate page attribute that
# pdflscape sets did not take effect): the PDF page size is swapped with the pdfTeX/XeTeX page primitives
# \\pdfpagewidth/\\pdfpageheight and the text is laid out on the rotated page with geometry's \\newgeometry; no
# page-rotation attribute, no pdflscape. LuaTeX would need \\pagewidth/\\pageheight instead.
LANDSCAPE_REQUIRES = ["% REQUIRES: booktabs, longtable, geometry",
                      "% Landscape pages: pdfTeX/XeTeX page-size primitives \\pdfpagewidth/\\pdfpageheight + geometry (no pdflscape)."]
LANDSCAPE_BEGIN = ["\\clearpage", "\\pdfpagewidth=\\paperheight \\pdfpageheight=\\paperwidth",
                   "\\newgeometry{layoutwidth=\\paperheight,layoutheight=\\paperwidth,margin=1in}"]
LANDSCAPE_END = ["\\clearpage", "\\pdfpagewidth=\\paperwidth \\pdfpageheight=\\paperheight", "\\restoregeometry"]


# Instance names of the SCOPF tables (moved here from tab_gpu_scopf.py and tab_gpu_scopf_pglib.py, which re-export them
# as tt, PAT, parts and tex_name): the reported SCOPF floats get their row order and printed names from these.
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


# The paper roster (Yifan 2026-11-09): every emitter shows exactly the configurations of ORDER that are present in its
# result directory, in this order; any other configuration found there is left out.
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


# The CUTEst population rule (Yifan 2026-11-12): an instance is excluded when its objective gradient, its constraint
# values or its constraint Jacobian is not finite at the starting point CUTEst provides. The names, with the rule and the
# census that defines them (benchmarks/instances/cutest_x0_census.csv, benchmarks/cutest_x0_census.jl) as provenance, are
# in benchmarks/instances/cutest_excluded_x0.txt. Every configuration's rows of those instances, baselines included, are
# dropped before scoring; the result CSVs keep them.
CUTEST_EXCLUDED = os.path.join(os.path.dirname(HERE), "instances", "cutest_excluded_x0.txt")


def cutest_excluded(path=CUTEST_EXCLUDED):
    """The excluded CUTEst names (one per line; '#' starts a comment)."""
    return {s for s in (l.split("#", 1)[0].strip() for l in open(path)) if s}


def drop_cutest_excluded(rows, excluded):
    """`rows` ({name: row}) without the excluded instances."""
    return {n: r for n, r in rows.items() if n not in excluded}


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
# a success (ruling 2026-11-03: solved = first_order only). The earlier campaigns counted it; that looser count is
# printed in parentheses with a dagger, for comparability with them.
LOOSE_STATUS = {"ipopt": {"acceptable"}}


def solved_loose(r, config, cap=None):
    """`solved`, but also counting the configuration's LOOSE_STATUS exits (the earlier campaigns' rule)."""
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


def majority_status(rows_by_tag, name, config=None, cvtol=None):
    """The status shown for a non-solve: the most frequent status over the repetitions, with a solve that
    fails the post-hoc guard reported as VIOLATION."""
    sts = []
    for rows in rows_by_tag.values():
        r = rows.get(name)
        if r is None:
            sts.append("MISSING")
        elif config in GUARDED and r["status"] in SUCCESS and not violation(r) <= cvtol:
            sts.append("VIOLATION")
        else:
            sts.append(r["status"])
    return max(sorted(set(sts)), key=sts.count)


# Status letters and short status names of the unreported extra tab_scopf_pglib_appendix only (the manuscript's appendix
# tables use FAIL_WORD/rep_cell below).
SHORT = {"MAXIMUM_ITERATIONS_EXCEEDED": "iter.\\ limit", "INFEASIBLE_PROBLEM_DETECTED": "infeasible",
         "MAXIMUM_WALLTIME_EXCEEDED": "wall limit", "SOLVED_TO_ACCEPTABLE_LEVEL": "acceptable",
         "VIOLATION": "viol.", "MISSING": "not run", "BUILD_FAILED": "no build"}
LETTER = {"MAXIMUM_ITERATIONS_EXCEEDED": "M", "INFEASIBLE_PROBLEM_DETECTED": "I", "MAXIMUM_WALLTIME_EXCEEDED": "W",
          "SOLVED_TO_ACCEPTABLE_LEVEL": "A"}


def short(st):
    if st.startswith("ERROR"):
        return "error"
    return SHORT.get(st, st.lower().replace("_", " "))


def letter(r, c, cvtol):
    if r is None:
        return "-"
    if r["status"] in SUCCESS:
        return "S" if success(r, c, None, cvtol) else "V"
    if r["status"].startswith("ERROR"):
        return "E"
    return LETTER.get(r["status"], "?")


# Per-repetition cells of the two per-instance appendix tables (tab_pglib_appendix, tab_scopf_all_appendix; Yifan
# 2026-11-12): the factorization count of a repetition that solves, else the reason for the non-solve as one short italic
# word, one fixed abbreviated vocabulary for both tables (Yifan's captions at Overleaf 0eae8ef define no codes; the
# abbreviations keep the tables at a readable type size).
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
