#!/usr/bin/env python3
"""tab_gpu_scopf_all — the 41 SCOPF instances in one table, per instance: the 23 reference-list instances
(tab_gpu_scopf.py) and the 18 protocol instances (tab_gpu_scopf_pglib.py), merged. NOT a float of the manuscript and not
emitted by emit.sh or compared by reproduce.sh (an unreported extra, runnable by hand); its module also supplies load,
is_pglib, kval, buses and tex to tab_gpu_scopf_summary.py, tab_scopf_all_appendix.py and summary_scopf_all.py. It
writes the label tab:gpu-scopf, which the manuscript uses for tab_gpu_scopf_summary.tex: never \\input its output.

Reads <scopf resdir>/scopf__<config>__<tag>.csv and <scopf_pglib resdir>/scopf_pglib__<config>__<tag>.csv; a
configuration must have the same repetition tags in both. Columns and scoring of tab_gpu_scopf.py: per configuration
the median interior-point iterations and factorizations over the succeeding repetitions when a strict majority of the
repetitions succeeds, a dash otherwise; LiftedKKT (MadNLP) has no constraint-violation test, so its solves count only
if the returned point's raw violation (pr_res) is within the runs' constr_viol_tol (post-hoc guard; the unguarded
count in parentheses when it differs). Rows: the reference networks case118, case300, ACTIVSg200, ACTIVSg500,
ACTIVSg2000, 1354pegase, 2869pegase, then the protocol networks 500_goc A/B, 588_sdet A/B, 793_goc A/B, each with K
increasing, one thin rule between the two groups. Footer over all 41: solved count and the geometric mean of
factorizations over the solved set.

Usage: python3 benchmarks/tables/tab_gpu_scopf_all.py <scopf resdir> <scopf_pglib resdir> [--cvtol=<t>] [--out=<dir>]
"""
import re, sys
from common import (DEFAULT_OUT, assert_no_tokens, find, fmt, gm, group_header, majority, ordered, pglib_scopf_parts as pglib_parts,
                    pglib_scopf_tex as pglib_tex_name, read_cvtol, read_rows, scopf_ref_tex as tt, write)

# Unreported extra (an earlier manuscript layout); not a float, no caption will be written.
CAPTION = ("The 41 security-constrained complementarity problems, per instance: the reference networks "
           "with their published contingency lists, then the PGLIB networks with the protocol lists (network, screening "
           "order, number of contingencies $K$), majority of three repetitions. For each solve, the entry is the median "
           "interior-point iteration count and factorization count over the repetitions that succeed; a dash is a "
           "non-solve.")
REF_NETS = ["case118", "case300", "case_ACTIVSg200", "case_ACTIVSg500", "case_ACTIVSg2000", "case1354pegase", "case2869pegase"]
REF_PAT = re.compile(r"(case.+?)_nK(\d+)")


def is_pglib(name):
    return name.startswith("pglib_opf_")


def key(name):
    """Row order: reference networks in REF_NETS order, then the protocol networks by bus count, network, order; K
    increasing within each."""
    if is_pglib(name):
        b, net, order, k = pglib_parts(name)
        return (1, b, net, order, k)
    m = REF_PAT.fullmatch(name)
    if not m or m[1] not in REF_NETS:
        raise SystemExit(f"unexpected reference instance name {name}")
    return (0, REF_NETS.index(m[1]), "", "", int(m[2]))


def kval(name):
    return key(name)[4]


def buses(name):
    if is_pglib(name):
        return pglib_parts(name)[0]
    return int(re.search(r"(\d+)", REF_PAT.fullmatch(name)[1])[1])


def tex(name):
    return pglib_tex_name(name) if is_pglib(name) else tt(name)


def load(ref_dir, pglib_dir, opt):
    """(configs, {config: {tag: {instance: row}}} over both suites, ordered instance names, cvtol, reference names)."""
    cv = {read_cvtol(ref_dir, opt), read_cvtol(pglib_dir, opt)}
    if len(cv) != 1:
        raise SystemExit(f"the two suites used different constr_viol_tol values {sorted(cv)}; pass --cvtol")
    fr = find(ref_dir, r"scopf__(.+?)__(.+?)\.csv")
    fp = find(pglib_dir, r"scopf_pglib__(.+?)__(.+?)\.csv")
    configs = ordered(set(fr) & set(fp))
    left = sorted((set(fr) ^ set(fp)) & set(ordered(set(fr) | set(fp))))
    if left:
        print(f"  NOTE: configurations in only one suite, left out: {left}")
    data = {}
    for c in configs:
        if sorted(fr[c]) != sorted(fp[c]):
            raise SystemExit(f"{c}: repetition tags differ between the suites ({sorted(fr[c])} vs {sorted(fp[c])})")
        data[c] = {}
        for t in fr[c]:
            a, b = read_rows(fr[c][t], "instance"), read_rows(fp[c][t], "instance")
            assert not set(a) & set(b), (c, t, set(a) & set(b))
            data[c][t] = {**a, **b}
    names = sorted({n for c in configs for rows in data[c].values() for n in rows}, key=key)
    ref = [n for n in names if not is_pglib(n)]
    if (len(ref), len(names) - len(ref)) != (23, 18):
        print(f"  NOTE: {len(ref)} reference and {len(names) - len(ref)} protocol instances in the results (expected 23 and 18)")
    return configs, data, names, cv.pop(), ref


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(pos) != 2:
        print(__doc__); return 2
    configs, data, names, cvtol, ref = load(pos[0], pos[1], opt)
    k = len(configs)
    T = ["% GENERATED by benchmarks/tables/tab_gpu_scopf_all.py -- do not hand-edit.", "% REQUIRES: booktabs",
         # \\arraystretch 0.95 (1 in tab_gpu_scopf): at 1 the 41 rows make the float 5.8pt taller than the text height
         "\\begin{table}[tbp]\\centering\\small\\setlength{\\tabcolsep}{3pt}\\renewcommand{\\arraystretch}{0.95}",
         "\\caption{" + CAPTION + "}", "\\label{tab:gpu-scopf}",
         "\\begin{tabular}{l" + "rr" * k + "}\\toprule"] + group_header(configs, 2, 1) + [
         "instance & " + " & ".join("iter.\\ & fact." for _ in configs) + " \\\\\\midrule"]
    summ = {c: [] for c in configs}
    raw = {c: sum(1 for n in names if majority(data[c], n)[0]) for c in configs}
    for i, n in enumerate(names):
        if i and is_pglib(n) and not is_pglib(names[i - 1]):
            T.append("\\midrule")
        cells = []
        for c in configs:
            ok, nf, it = majority(data[c], n, c, cvtol)
            if ok:
                summ[c].append(nf)
                cells += [f"{it:.0f}", f"{nf:.0f}"]
            else:
                cells += ["---", "---"]
        T.append(f"{tex(n)} & " + " & ".join(cells) + " \\\\")
    T.append("\\midrule solved & " + " & ".join(
        f"\\multicolumn{{2}}{{c}}{{{len(summ[c])}/{len(names)}" + (f" ({raw[c]})" if raw[c] != len(summ[c]) else "") + "}"
        for c in configs) + " \\\\")
    T.append("factorizations (geom.\\ mean) & " + " & ".join(f"\\multicolumn{{2}}{{c}}{{{fmt(gm(summ[c]))}}}" for c in configs) + " \\\\")
    T.append("\\bottomrule\\end{tabular}\\end{table}")
    for c in configs:
        print(f"  {c:<10} solved {len(summ[c])}/{len(names)} (unguarded {raw[c]})  gm fact {gm(summ[c]):.1f}  reps {sorted(data[c])}")
    assert_no_tokens("\n".join(T))
    write(opt.get("out", DEFAULT_OUT), "tab_gpu_scopf_all.tex", T)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
