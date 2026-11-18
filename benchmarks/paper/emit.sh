#!/bin/bash
# The paper's tables from the result CSVs: for each suite, its tables into benchmarks/out/paper/tables/.
#   emit.sh [suite ...]              (default: cutest opf scopf; scopf = the 41 SCOPF instances)
#   RES=<dir> emit.sh ...            read the results from <dir>/<suite>/ (default: benchmarks/results/paper;
#                                    benchmarks/out/paper/results after a rerun)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
r=0
for s in ${*:-$SUITES}; do
    echo "== $s"
    emit "$s" || r=1
done
echo "emit.sh rc=$r  tables: $TABLES"
exit $r
