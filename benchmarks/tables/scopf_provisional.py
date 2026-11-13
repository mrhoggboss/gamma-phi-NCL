#!/usr/bin/env python3
"""scopf_provisional -- the provisional SCOPF export (Yifan 2026-11-13: a single-repetition version of the rerun of the
12 instances whose contingency lists became protocol lists, exported before the other repetitions are in). Not a float
of reproduce.sh; Python standard library plus benchmarks/paper/lib.sh's compile check.

  python3 benchmarks/tables/scopf_provisional.py [--rerun=<dir>] [--out=<dir>]

--rerun=<dir>: the rerun's output root, holding <cfg>_r1/scopf__<cfg>__r1.csv for the five configurations (MadNCL-public
benchmarks/out/paper/scopf_rerun/). Writes <out>/results/scopf/ (default <out> = benchmarks/out/paper/scopf_provisional):
r1 = the banked r1 rows with the rows of the rerun's instances replaced by the rerun's rep-1 rows; r2 and r3 = the banked
rows without those instances; the banked configuration echoes. Writes <out>/provisional_instances.txt (the rerun's
instances), emits tab_gpu_scopf_summary.tex and tab_scopf_all_appendix.tex into <out>/tables/ with --provisional,
compile-checks them (lib.sh compile_tables) and writes the Results numbers to <out>/numbers.txt
(scopf_results_numbers.py --provisional). The 18 PGLIB-network instances are read from the banked scopf_pglib/.

Without --rerun (dry run): the same pipeline on the banked rows alone, without --provisional; the two tables must be
byte-identical to manuscript/tables/ (checked; exit 1 otherwise).
"""
import csv, glob, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BANK = os.path.join(ROOT, "benchmarks", "results", "paper")
CONFIGS = ("S", "SP", "W", "U6A", "liftedkkt")
TABLES = ("tab_gpu_scopf_summary", "tab_scopf_all_appendix")


def rows_of(path):
    lines = open(path).read().split("\n")
    return lines[0], [l for l in lines[1:] if l]


def main(argv):
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    out = os.path.abspath(opt.get("out", os.path.join(ROOT, "benchmarks", "out", "paper", "scopf_provisional")))
    res = os.path.join(out, "results", "scopf")
    shutil.rmtree(os.path.join(out, "results"), ignore_errors=True)
    os.makedirs(res, exist_ok=True)
    for f in glob.glob(os.path.join(BANK, "scopf", "config_scopf__*.txt")):
        shutil.copy(f, res)
    rerun, prov = opt.get("rerun"), []
    new = {}
    if rerun:
        for c in CONFIGS:
            hdr, body = rows_of(os.path.join(rerun, f"{c}_r1", f"scopf__{c}__r1.csv"))
            new[c] = {l.split(",")[0]: l for l in body}
            prov = prov or sorted(new[c])
            assert sorted(new[c]) == prov, (c, sorted(new[c]), prov)
    for c in CONFIGS:
        for k in (1, 2, 3):
            hdr, body = rows_of(os.path.join(BANK, "scopf", f"scopf__{c}__r{k}.csv"))
            names = [l.split(",")[0] for l in body]
            assert all(p in names for p in prov), (c, k)
            keep = []
            for l in body:
                n = l.split(",")[0]
                if n not in prov:
                    keep.append(l)
                elif k == 1:
                    nl = new[c][n]
                    assert nl.split(",")[1:3] == [c, "r1"], (c, n, nl.split(",")[1:3])
                    keep.append(nl)
            open(os.path.join(res, f"scopf__{c}__r{k}.csv"), "w").write(hdr + "\n" + "\n".join(keep) + "\n")
    tables = os.path.join(out, "tables")
    os.makedirs(tables, exist_ok=True)
    extra = []
    if prov:
        lst = os.path.join(out, "provisional_instances.txt")
        open(lst, "w").write("\n".join(prov) + "\n")
        extra = ["--provisional=" + lst]
    pglib = os.path.join(BANK, "scopf_pglib")
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    for t, script in zip(TABLES, ("tab_gpu_scopf_summary.py", "tab_scopf_all_appendix.py")):
        subprocess.run([sys.executable, os.path.join(HERE, script), res, pglib, "--out=" + tables] + extra, check=True, env=env)
    files = " ".join(os.path.join(tables, t + ".tex") for t in TABLES)
    subprocess.run(["bash", "-c", f'source "{ROOT}/benchmarks/paper/lib.sh" && compile_tables {files}'], check=True,
                   env=dict(env, PAPER_OUT=out))
    with open(os.path.join(out, "numbers.txt"), "w") as f:
        subprocess.run([sys.executable, os.path.join(HERE, "scopf_results_numbers.py"), res, pglib] + extra,
                       check=True, stdout=f, env=env)
    print("wrote", tables, "and", os.path.join(out, "numbers.txt"), "(provisional:", len(prov), "instances)")
    if not rerun:
        bad = [t for t in TABLES if open(os.path.join(tables, t + ".tex"), "rb").read()
               != open(os.path.join(ROOT, "manuscript", "tables", t + ".tex"), "rb").read()]
        print("dry run vs manuscript/tables:", "IDENTICAL" if not bad else "DIFFERS " + " ".join(bad))
        return 1 if bad else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
