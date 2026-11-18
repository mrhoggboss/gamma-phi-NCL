#!/bin/bash
# Shared functions of the paper scripts (sourced by chain_cpu.sh, chain_gpu.sh, emit.sh and the Makefile).
#
# Layout:
#   benchmarks/results/paper/<suite>/   the result CSVs and configuration echoes of the paper's runs. Nothing here writes
#                                       there; emit reads it (or the directory given by RES=<dir>).
#   benchmarks/out/paper/               everything written here (gitignored; PAPER_OUT=<dir> moves it):
#     <suite>/<config>_r<k>/            one cell (suite x configuration x repetition): the driver's own outputs, traces, DONE
#     results/<suite>/                  the result CSV and configuration echo of every finished cell, flat and named as in
#                                       benchmarks/results/paper/<suite>/  (emit.sh with RES=benchmarks/out/paper/results)
#     tables/                           the emitted tables (<name>.tex)
#     logs/                             driver logs, WALLTIME_<chain>.csv (one line per cell), progress.txt (markers)
# Suites: cutest (CPU), opf, scopf (GPU).
# Every GPU cell runs under gpu_device.sh (a wall cap; the compute processes of others on the device are sampled every
# 60 s and logged as INTRUDER lines, so that their cells' wall times can be flagged) and watch.sh (stall watchdog,
# resume).
set -u
export PYTHONDONTWRITEBYTECODE=1   # no __pycache__ next to the emitters
PUB=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${PAPER_OUT:-$PUB/benchmarks/out/paper}
RES=${RES:-$PUB/benchmarks/results/paper}
RUNRES=$OUT/results
LOGS=$OUT/logs
TABLES=$OUT/tables
GPUENV=$PUB/benchmarks/envs/gpu
CPUENV=$PUB/benchmarks/envs/cpu
JULIA=$PUB/benchmarks/paper/julia.sh   # julia.sh <envdir> ...: the Julia version the environment records
INST=$PUB/benchmarks/instances
SCOPF_DATA=${SCOPF_DATA:-$PUB/benchmarks/out/scopf_data}  # the <dir> of both SCOPF fetch scripts (benchmarks/instances)
MARKS=$LOGS/progress.txt
mkdir -p "$OUT" "$LOGS"

mark() { echo "$(date -Is) $*" >> "$MARKS"; }
head_sha() { git -C "$PUB" rev-parse --short HEAD; }
wt_header() { [ -f "$1" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$1"; }

# run_gpu_cell <dev> <suite> <config> <k> <walltime_csv>: one GPU cell:
#   opf          gpu.jl opf <config> <dir> --tag=r<k> --trace          (PGLIB 66 cases, max_iter 3000, wall 1800 s)
#   scopf        gpu.jl scopf ... --instances=scopf41.csv --data=$SCOPF_DATA  (the 41 SCOPF instances, max_iter 3000)
# A cell already DONE is skipped; a cell killed part-way resumes from its result file (the driver keeps its finished
# rows).
run_gpu_cell() {
    local dev=$1 suite=$2 config=$3 k=$4 wt=$5
    local tag="r$k" dir="$OUT/$suite/${config}_r$k" log="$LOGS/${suite}_${config}_r$k.log" drv=$suite extra=()
    local stall=3300   # 1.5 x the 1800 s wall + 600 s; the stall clock restarts at every instance start
    case $suite in
        opf) ;;
        scopf) extra=(--instances="$INST/scopf41.csv" --data="$SCOPF_DATA") ;;
        *) echo "run_gpu_cell: unknown suite $suite" >&2; return 2 ;;
    esac
    mkdir -p "$dir"
    if [ -f "$dir/DONE" ]; then mark "CELL_SKIP $suite $config r$k (already done)"; return 0; fi
    local t0 rc head
    t0=$(date +%s); head=$(head_sha)
    mark "CELL_START $suite $config r$k dev=$dev HEAD=$head"
    "$PUB/benchmarks/paper/watch.sh" "$dir" "$dir/KILLED_AT" "$stall" "$log" -- \
        "$PUB/benchmarks/paper/gpu_device.sh" "$dev" 172800 "$log" -- \
        "$JULIA" "$GPUENV" "$PUB/benchmarks/gpu.jl" "$drv" "$config" "$dir" --tag="$tag" --trace "${extra[@]}"
    rc=$?
    local intr kills
    intr=$(grep -c " INTRUDER " "$log" 2>/dev/null); kills=$(grep -c "WATCH STALL" "$log" 2>/dev/null)
    echo "$suite,$config,r$k,$dev,$t0,$(date +%s),$(( $(date +%s) - t0 )),$rc,$intr,$kills,$head" >> "$wt"
    if [ $rc -eq 0 ] && [ -f "$dir/${drv}__${config}__r$k.csv" ]; then
        mkdir -p "$RUNRES/$suite"
        cp "$dir/${drv}__${config}__r$k.csv" "$RUNRES/$suite/${suite}__${config}__r$k.csv"
        cp "$dir/config_${drv}__r$k.txt" "$RUNRES/$suite/config_${suite}__${config}__r$k.txt"
        touch "$dir/DONE"
    fi
    mark "CELL_DONE $suite $config r$k rc=$rc intruders=$intr stall_kills=$kills"
    return $rc
}

# kill leftover Julia processes of one CPU pool (Distributed workers inherit PAPER_POOL_TAG from the master)
cleanup_orphans() {
    local tag=$1 p n=0
    for p in $(pgrep -u "$(id -u)" julia); do
        if tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "PAPER_POOL_TAG=$tag"; then kill -9 "$p" 2>/dev/null && n=$((n + 1)); fi
    done
    echo "cleanup_orphans $tag: killed $n"
}

# run_cpu_pool <config> <walltime_csv>: CUTEst (CUTEST_LIST, default the 1060 problems of cutest1060.txt), K2r
# (MadNCL configurations) / HSL MA57 with automatic scaling, one 3600 s cap per solve, max_iter 3000, CPU_NW workers
# (default 30), under the stall watchdog (7200 s)
CPU_NW=${CPU_NW:-30}
CUTEST_LIST=${CUTEST_LIST:-$INST/cutest1060.txt}
run_cpu_pool() {
    local config=$1 wt=$2
    local dir="$OUT/cutest/${config}_r1" log="$LOGS/cutest_${config}.log" tr="" rc head t0
    mkdir -p "$dir/rows"
    if [ -f "$dir/DONE" ]; then mark "CELL_SKIP cutest $config r1 (already done)"; return 0; fi
    case $config in S|SP|W|U6A) tr=--trace ;; esac
    t0=$(date +%s); head=$(head_sha)
    mark "CELL_START cutest $config r1 workers=$CPU_NW HEAD=$head"
    PAPER_POOL_TAG="paper_cutest_$config" "$PUB/benchmarks/paper/watch.sh" "$dir/rows" "$dir/rows/KILLED_AT" 7200 "$log" -- \
        "$JULIA" "$CPUENV" "$PUB/benchmarks/cutest.jl" "$CUTEST_LIST" "$config" ma57 "$CPU_NW" 3600 "$dir" $tr
    rc=$?
    cleanup_orphans "paper_cutest_$config" >> "$log"
    local kills
    kills=$(grep -c "WATCH STALL" "$log" 2>/dev/null)
    echo "cutest,$config,r1,cpu,$t0,$(date +%s),$(( $(date +%s) - t0 )),$rc,0,$kills,$head" >> "$wt"
    if [ $rc -eq 0 ] && [ -f "$dir/cutest__${config}__ma57.csv" ]; then
        mkdir -p "$RUNRES/cutest"
        cp "$dir/cutest__${config}__ma57.csv" "$RUNRES/cutest/"
        cp "$dir/config.txt" "$RUNRES/cutest/config_${config}.txt"
        touch "$dir/DONE"
    fi
    mark "CELL_DONE cutest $config r1 rc=$rc stall_kills=$kills"
    return $rc
}

# The tables of each suite (<name>.tex in $TABLES).
FLOATS_cutest="tab_cutest_ma57"
FLOATS_opf="tab_gpu_opf tab_pglib_appendix"
# scopf: the 41 SCOPF instances: the summary table (tab_gpu_scopf_summary, the layout of tab_gpu_opf) and the per-instance
# appendix table.
FLOATS_scopf="tab_gpu_scopf_summary tab_scopf_all_appendix"
SUITES="cutest opf scopf"

# emit <suite>: write the suite's tables from the results in $RES/<suite> into $TABLES; nothing else is written. The
# suite's tables are deleted first, so that a failed emitter leaves no stale table behind; a results directory without
# any result CSV fails the suite (the emitters themselves would write empty tables).
has_csv() { local x; for x in "$1"/*.csv; do [ -e "$x" ] && return 0; done; return 1; }
emit() {
    local suite=$1 py=$PUB/benchmarks/tables r=0 v f
    case $suite in
        cutest|opf|scopf) ;;
        *) echo "emit: unknown suite $suite (expected one of $SUITES)" >&2; return 2 ;;
    esac
    mkdir -p "$TABLES"
    v="FLOATS_$suite"
    for f in ${!v}; do rm -f "$TABLES/$f.tex"; done
    has_csv "$RES/$suite" || { echo "emit: no result CSV in $RES/$suite" >&2; r=1; }
    if [ $r -eq 0 ]; then
        case $suite in
            cutest) python3 "$py/tab_cutest.py" "$RES/cutest" --cap=3600 --out="$TABLES" || r=1 ;;
            opf)    python3 "$py/tab_gpu_opf.py" "$RES/opf" --out="$TABLES" || r=1
                    python3 "$py/tab_pglib_appendix.py" "$RES/opf" --out="$TABLES" || r=1 ;;
            scopf)  python3 "$py/tab_gpu_scopf_summary.py" "$RES/scopf" --out="$TABLES" || r=1
                    python3 "$py/tab_scopf_all_appendix.py" "$RES/scopf" --out="$TABLES" || r=1 ;;
        esac
    fi
    mark "EMIT $suite rc=$r RES=$RES"
    return $r
}
