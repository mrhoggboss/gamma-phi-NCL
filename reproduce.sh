#!/bin/bash
# Reproduce every number in the tables and the figure of the manuscript.
#
#   ./reproduce.sh
#       Emit the seven tables and the figure from the banked results (benchmarks/results/paper), compile each at the
#       manuscript's page geometry, and byte-compare it with the copy the manuscript \inputs (manuscript/tables/,
#       manuscript/figures/). One line per float; exit 0 only if all eight are IDENTICAL. About a minute.
#       Needs bash, python3, pdflatex and pdfinfo (REPRO_NOCOMPILE=1 skips the compile check).
#
#   ./reproduce.sh rerun <cpu|opf|scopf|scopf_pglib|all> [--device N]
#       Rerun the solves (cpu = CUTEst, benchmarks/paper/chain_cpu.sh; opf, scopf, scopf_pglib = the GPU suites,
#       benchmarks/paper/chain_gpu.sh on device N, default 0; all = cpu, then opf, scopf and scopf_pglib), fetching the
#       SCOPF case files first when their sha256 check does not already pass; then emit those floats from the rerun
#       (benchmarks/out/paper/results) and compare them with manuscript/ in the same way. The comparison is
#       informational there; the exit code is the emit's. Hours to days: see README.md, "One command".
#
# Everything is written under benchmarks/out/paper (PAPER_OUT=<dir> moves it); the banked results are never written.
set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PAPER=$ROOT/benchmarks/paper
source "$PAPER/lib.sh"    # OUT, TABLES, FIGURES, RUNRES, INST, SCOPF_DATA, SCOPF_PGLIB_DATA, FLOATS_<suite>, SUITES

usage() { sed -n '2,/^# Everything/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

# compare <suite>...: byte-compare the suites' emitted floats with manuscript/; prints one line per float, returns the
# number that differ
compare() {
    local s v f emitted ref nd=0
    for s in "$@"; do
        v="FLOATS_$s"
        for f in ${!v}; do
            if [ "$s" = figure ]; then emitted=$FIGURES/$f.tex; ref=$ROOT/manuscript/figures/$f.tex
            else emitted=$TABLES/$f.tex; ref=$ROOT/manuscript/tables/$f.tex; fi
            if cmp -s "$emitted" "$ref"; then
                echo "IDENTICAL  $f"
            else
                echo "DIFFERS    $f"
                diff "$ref" "$emitted" 2>&1 | head -n 20 | sed 's/^/    /'
                nd=$((nd + 1))
            fi
        done
    done
    return $nd
}

# emit_and_compare <suite>...: emit.sh (output in $LOGS/reproduce_emit.log), then compare; sets EMIT_RC and NDIFF
emit_and_compare() {
    local log=$LOGS/reproduce_emit.log
    echo "emitting $* from ${RES} (log: $log)"
    RES=$RES "$PAPER/emit.sh" "$@" > "$log" 2>&1; EMIT_RC=$?
    grep -E 'COMPILE FAILED|OVERFULL|PAGES' "$log"
    if grep -q 'skipped (REPRO_NOCOMPILE=1)' "$log"; then echo "compile check skipped (REPRO_NOCOMPILE=1)"
    else echo "compile check: $(grep -c '^  [A-Za-z0-9_]*: ok' "$log") fragments ok"; fi
    tail -n 1 "$log"
    [ $EMIT_RC -ne 0 ] && { echo "emit.sh failed (rc $EMIT_RC); last lines of the log:"; tail -n 15 "$log"; }
    compare "$@"; NDIFF=$?
}

# fetch_if_needed <dir> <manifest> <fetch script>: run the fetch script unless <dir> already passes the sha256 check
fetch_if_needed() {
    if (cd "$1" 2>/dev/null && sha256sum --quiet -c "$2" > /dev/null 2>&1); then
        echo "data in $1: sha256 check passes, no fetch"
    else
        "$3" "$1" || { echo "fetch failed: $3 $1"; exit 1; }
    fi
}

if [ $# -eq 0 ]; then
    emit_and_compare $SUITES
    n=$(for s in $SUITES; do v="FLOATS_$s"; echo ${!v}; done | wc -w)
    if [ $EMIT_RC -eq 0 ] && [ $NDIFF -eq 0 ]; then
        echo "reproduce.sh: all $n floats IDENTICAL to manuscript/"; exit 0
    fi
    echo "reproduce.sh: $NDIFF of $n floats differ from manuscript/ (emit rc $EMIT_RC)"; exit 1
fi

case $1 in -h|--help) usage 0 ;; rerun) shift ;; *) usage ;; esac
[ $# -ge 1 ] || usage
WHAT=$1; shift; DEV=0
while [ $# -gt 0 ]; do
    case $1 in --device) [ $# -ge 2 ] || usage; DEV=$2; shift 2 ;; *) usage ;; esac
done
case $WHAT in
    cpu|opf|scopf|scopf_pglib) RUNS=$WHAT ;;
    all) RUNS="cpu opf scopf scopf_pglib" ;;
    *) usage ;;
esac
[[ $DEV =~ ^[0-9]+$ ]] || usage

EMITS=""
for r in $RUNS; do
    echo "== rerun $r $(date -Is)"
    case $r in
        cpu)         "$PAPER/chain_cpu.sh"; EMITS="$EMITS cutest" ;;
        opf)         "$PAPER/chain_gpu.sh" "$DEV" opf; EMITS="$EMITS opf" ;;
        scopf)       fetch_if_needed "$SCOPF_DATA" "$INST/scopf_data.sha256" "$INST/fetch_scopf_data.sh"
                     SCOPF_DATA=$SCOPF_DATA "$PAPER/chain_gpu.sh" "$DEV" scopf; EMITS="$EMITS scopf" ;;
        scopf_pglib) fetch_if_needed "$SCOPF_PGLIB_DATA" "$INST/scopf_pglib_data.sha256" "$INST/fetch_pglib_scopf_data.sh"
                     SCOPF_PGLIB_DATA=$SCOPF_PGLIB_DATA "$PAPER/chain_gpu.sh" "$DEV" scopf_pglib; EMITS="$EMITS scopf_pglib" ;;
    esac
done
[ "$WHAT" = all ] && EMITS="$EMITS figure"
RES=$RUNRES
emit_and_compare $EMITS
echo "Expected: a CPU rerun reproduces the result CSVs in every column but the timing columns, so its table matches;"
echo "a GPU rerun matches only within the GPU nondeterminism band (cuDSS reductions are not bitwise reproducible; see"
echo "README.md), so the comparison above is informational. Exit code = emit.sh's ($EMIT_RC)."
exit $EMIT_RC
