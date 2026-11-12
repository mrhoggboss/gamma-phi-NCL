#!/bin/bash
# The manuscript's floats from the result CSVs: for each suite, its floats into benchmarks/out/paper/tables/ (the theory
# figure into benchmarks/out/paper/figures/), each compiled at the manuscript's geometry (lib.sh compile_tables), then
# the console summaries into benchmarks/out/paper/summaries/.
#   emit.sh [suite ...]              (default: cutest opf scopf scopf_pglib figure; scopf_all, the 41 SCOPF instances
#                                    merged into tab_gpu_scopf_all and tab_scopf_all_appendix, only when named)
#   RES=<dir> emit.sh ...            read the results from <dir>/<suite>/ (default: the banked benchmarks/results/paper;
#                                    benchmarks/out/paper/results after a rerun)
#   REPRO_NOCOMPILE=1 emit.sh ...    skip the compile check (a machine without pdflatex/pdfinfo)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
r=0
for s in ${*:-$SUITES}; do
    echo "== $s"
    emit "$s" || r=1
    summarize "$s" || r=1
done
echo "emit.sh rc=$r  tables: $TABLES  figures: $FIGURES  summaries: $SUMMARIES"
exit $r
