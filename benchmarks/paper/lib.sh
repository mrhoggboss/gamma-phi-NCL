#!/bin/bash
# Shared functions of the paper scripts (sourced by chain_cpu.sh, chain_gpu.sh and emit.sh).
#
# Layout:
#   benchmarks/results/paper/<suite>/   the campaign's result CSVs and configuration echoes: the paper's data. Nothing here
#                                       writes there; emit reads it (or the directory given by RES=<dir>).
#   benchmarks/out/paper/               everything written here (gitignored; PAPER_OUT=<dir> moves it):
#     <suite>/<config>_r<k>/            one cell (suite x configuration x repetition): the driver's own outputs, traces, DONE
#     results/<suite>/                  the result CSV and configuration echo of every finished cell, flat and named as in
#                                       benchmarks/results/paper/<suite>/  (emit.sh with RES=benchmarks/out/paper/results)
#     tables/, figures/                 the floats of the manuscript, as \input by it (tables/<name>.tex, figures/<name>.tex)
#     compile/                          the compile check's scaffolding (_cc_<name>.{tex,log,pdf,...}), kept out of tables/
#     summaries/<suite>.txt             console summaries (the banked benchmarks/results/paper/<suite>/summary.txt)
#     logs/                             driver logs, WALLTIME_<chain>.csv (one line per cell), progress.txt (markers)
# Suites: cutest (CPU), opf, scopf, scopf_pglib (GPU); `figure` is the theory figure (no data).
# Every GPU cell runs under gpu_device.sh (refuses a device that carries any other process unless GPU_DEVICE_NOGATE=1; a
# wall cap; the compute processes of others on the device are sampled every 60 s and logged as INTRUDER lines, so that
# their cells' wall times can be flagged) and watch.sh (stall watchdog, resume).
set -u
export PYTHONDONTWRITEBYTECODE=1   # no __pycache__ next to the emitters
PUB=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${PAPER_OUT:-$PUB/benchmarks/out/paper}
RES=${RES:-$PUB/benchmarks/results/paper}
RUNRES=$OUT/results
LOGS=$OUT/logs
TABLES=$OUT/tables
FIGURES=$OUT/figures
SUMMARIES=$OUT/summaries
GPUENV=$PUB/benchmarks/envs/gpu
CPUENV=$PUB/benchmarks/envs/cpu
INST=$PUB/benchmarks/instances
SCOPF_DATA=${SCOPF_DATA:-$PUB/benchmarks/out/scopf_data}                    # benchmarks/instances/fetch_scopf_data.sh <dir>
SCOPF_PGLIB_DATA=${SCOPF_PGLIB_DATA:-$PUB/benchmarks/out/scopf_pglib_data}  # benchmarks/instances/fetch_pglib_scopf_data.sh <dir>
MARKS=$LOGS/progress.txt
mkdir -p "$OUT" "$LOGS"

mark() { echo "$(date -Is) $*" >> "$MARKS"; }
head_sha() { git -C "$PUB" rev-parse --short HEAD; }
wt_header() { [ -f "$1" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$1"; }

device_busy() {   # device_busy <dev>: prints the compute processes on that device (empty = free)
    local uuid
    uuid=$(nvidia-smi --query-gpu=index,uuid --format=csv,noheader | awk -F', ' -v d="$1" '$1==d{print $2}')
    nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader | awk -F', ' -v u="$uuid" '$1==u{print $2}'
}

# run_gpu_cell <dev> <suite> <config> <k> <walltime_csv>: one GPU cell, with the campaign's command:
#   opf          gpu.jl opf <config> <dir> --tag=r<k> --trace          (PGLIB 66 cases, max_iter 1000, wall 1800 s)
#   scopf        gpu.jl scopf ... --data=$SCOPF_DATA                    (the 23 reference-network instances, max_iter 3000)
#   scopf_pglib  gpu.jl scopf ... --instances=scopf_pglib18.csv --data=$SCOPF_PGLIB_DATA
#                --contingencies=scopf_pglib_contingencies.jl           (the 18 PGLIB-network instances, max_iter 3000)
# The campaign ran scopf_pglib one instance per process (--cases=<instance>, otherwise the same options); here the 18
# run in one process, as the 23 of scopf. A cell already DONE is skipped; a cell killed part-way resumes from its result
# file (the driver keeps its finished rows).
run_gpu_cell() {
    local dev=$1 suite=$2 config=$3 k=$4 wt=$5
    local tag="r$k" dir="$OUT/$suite/${config}_r$k" log="$LOGS/${suite}_${config}_r$k.log" drv=$suite extra=()
    local stall=3300   # 1.5 x the 1800 s wall + 600 s; the stall clock restarts at every instance start
    case $suite in
        opf) ;;
        scopf) extra=(--data="$SCOPF_DATA") ;;
        scopf_pglib) drv=scopf; extra=(--instances="$INST/scopf_pglib18.csv" --data="$SCOPF_PGLIB_DATA"
                                       --contingencies="$INST/scopf_pglib_contingencies.jl") ;;
        *) echo "run_gpu_cell: unknown suite $suite" >&2; return 2 ;;
    esac
    mkdir -p "$dir"
    if [ -f "$dir/DONE" ]; then mark "CELL_SKIP $suite $config r$k (already done)"; return 0; fi
    local waited=0
    while [ "${GPU_DEVICE_NOGATE:-0}" != 1 ] && [ -n "$(device_busy "$dev")" ]; do
        [ $((waited % 600)) -eq 0 ] && mark "BUSY_WAIT $suite $config r$k dev=$dev pids=$(device_busy "$dev" | tr '\n' ' ')"
        sleep 60; waited=$((waited + 60))
    done
    local t0 rc head
    t0=$(date +%s); head=$(head_sha)
    mark "CELL_START $suite $config r$k dev=$dev HEAD=$head"
    while :; do
        "$PUB/benchmarks/paper/watch.sh" "$dir" "$dir/KILLED_AT" "$stall" "$log" -- \
            "$PUB/benchmarks/paper/gpu_device.sh" "$dev" 172800 "$log" -- \
            julia +1.11.2 --project="$GPUENV" "$PUB/benchmarks/gpu.jl" "$drv" "$config" "$dir" --tag="$tag" --trace "${extra[@]}"
        rc=$?
        [ $rc -ne 3 ] && break          # 3 = the device became busy between the check and the launch: wait again
        mark "BUSY_WAIT $suite $config r$k dev=$dev (at launch)"; sleep 120
    done
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

# run_cpu_pool <config> <walltime_csv>: CUTEst (CUTEST_LIST, default the 1070 constrained problems), K2r (MadNCL
# configurations) / HSL MA57 with automatic scaling, one 3600 s cap per solve, max_iter 3000, CPU_NW workers
# (default 30), under the stall watchdog (7200 s)
CPU_NW=${CPU_NW:-30}
CUTEST_LIST=${CUTEST_LIST:-$INST/cutest_pop1070.txt}
run_cpu_pool() {
    local config=$1 wt=$2
    local dir="$OUT/cutest/${config}_r1" log="$LOGS/cutest_${config}.log" tr="" rc head t0
    mkdir -p "$dir/rows"
    if [ -f "$dir/DONE" ]; then mark "CELL_SKIP cutest $config r1 (already done)"; return 0; fi
    case $config in S|SP|W|U6A) tr=--trace ;; esac
    t0=$(date +%s); head=$(head_sha)
    mark "CELL_START cutest $config r1 workers=$CPU_NW HEAD=$head"
    PAPER_POOL_TAG="paper_cutest_$config" "$PUB/benchmarks/paper/watch.sh" "$dir/rows" "$dir/rows/KILLED_AT" 7200 "$log" -- \
        julia --project="$CPUENV" "$PUB/benchmarks/cutest.jl" "$CUTEST_LIST" "$config" ma57 "$CPU_NW" 3600 "$dir" $tr
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

# compile_tables <file.tex>...: compile every fragment in its own document with the manuscript's page geometry and
# packages (11pt article, letterpaper, margin 1in; booktabs, longtable, tikz with shapes.geometric and arrows.meta,
# and the \claudegreen macro, which the manuscript defines; no float uses it),
# two passes (the longtable column widths settle on the second), and FAIL if a fragment does not compile or has an
# Overfull \hbox wider than 2 pt; a fragment holding a longtable (the appendix tables, set on physical landscape
# pages) also FAILS unless every page of its PDF is wider than tall (pdfinfo page sizes). Prints one line per fragment.
# The scaffolding goes to $OUT/compile/ (the fragment is found through TEXINPUTS), so that tables/ and figures/ hold only
# the floats.
compile_tables() {
    local f n d doc rc=0 nf=0 over pages cdir=$OUT/compile
    mkdir -p "$cdir"
    for f in "$@"; do
        d=$(cd "$(dirname "$f")" && pwd); n=$(basename "$f" .tex)
        nf=$((nf + 1)); doc=$cdir/_cc_$n.tex
        {
            echo '\documentclass[11pt]{article}'
            echo '\usepackage[letterpaper,margin=1in]{geometry}'
            echo '\usepackage{amsmath,amssymb,booktabs,longtable,multirow,array,graphicx,xcolor}'
            echo '\usepackage{tikz}\usetikzlibrary{shapes.geometric,arrows.meta}'
            echo '\newcommand{\claudegreen}[1]{{\color{green!45!black}#1}}'   # defined by the manuscript; no float uses it
            echo '\begin{document}'
            echo "\\input{$n}"
            echo '\end{document}'
        } > "$doc"
        if ! (cd "$cdir" && export TEXINPUTS="$d:" \
                     && pdflatex -interaction=nonstopmode -halt-on-error "_cc_$n.tex" > "_cc_$n.out" 2>&1 \
                     && pdflatex -interaction=nonstopmode -halt-on-error "_cc_$n.tex" > "_cc_$n.out" 2>&1); then
            echo "  $n: COMPILE FAILED (see $cdir/_cc_$n.log)"; rc=1; continue
        fi
        over=$(grep -o 'Overfull \\hbox ([0-9.]*pt too wide)' "$cdir/_cc_$n.log" | grep -o '[0-9.]*pt' | sort | uniq -c \
               | awk '{printf "%s%s", (NR > 1 ? ", " : ""), $2 ($1 > 1 ? " x" $1 : "")}')
        if [ -n "$(grep -o 'Overfull \\hbox ([0-9.]*pt too wide)' "$cdir/_cc_$n.log" | grep -o '[0-9.]*' | awk '$1 > 2')" ]; then
            echo "  $n: OVERFULL ${over}"; rc=1
        else
            echo "  $n: ok${over:+ (overfull <= 2pt: $over)}"
        fi
        if grep -q 'begin{longtable}' "$f"; then
            pages=$(pdfinfo -f 1 -l 100000 "$cdir/_cc_$n.pdf" 2>/dev/null | awk '/^Page +[0-9]+ size:/ {
                        n++; s[$4 " x " $6]++; if (!($4 > $6)) bad++ }
                        END { printf "%d page(s), sizes", n; for (k in s) printf " %s pt x%d", k, s[k]; if (bad || !n) printf "; NOT LANDSCAPE: %d", bad + !n }')
            case $pages in *"NOT LANDSCAPE"*|"") echo "  $n: PAGES ${pages:-pdfinfo failed}"; rc=1;; *) echo "  $n: pages ok: $pages (all wider than tall)";; esac
        fi
    done
    echo "compile_tables rc=$rc ($nf)"
    return $rc
}

# The floats of each suite (the files the manuscript \inputs: tables/<name>.tex, figures/<name>.tex).
FLOATS_cutest="tab_cutest_ma57"
FLOATS_opf="tab_gpu_opf tab_pglib_appendix"
# scopf: the 41 SCOPF instances (the 23 reference-network and the 18 PGLIB-network instances, from the scopf and scopf_pglib
# results): the summary table (tab_gpu_scopf_summary, the layout of tab_gpu_opf) and the per-instance appendix table.
# Not emitted here (no longer floats; the scripts remain, runnable by hand): the 41-row main table tab_gpu_scopf_all
# (its module also serves the appendix and summary emitters) and the separate 23- and 18-instance tables of earlier
# manuscript versions (tab_gpu_scopf.py, tab_gpu_scopf_pglib.py, tab_scopf_pglib_appendix.py). The SCOPF configuration
# table (tab_scopf_config) left the manuscript at Overleaf da30c73 and its emitter was removed.
FLOATS_scopf="tab_gpu_scopf_summary tab_scopf_all_appendix"
FLOATS_figure="fig_example_degenerate"
SUITES="cutest opf scopf figure"

# emit <suite>: write the suite's floats from the results in $RES/<suite> into $TABLES (the figure into $FIGURES) and
# check that they compile (REPRO_NOCOMPILE=1 skips the check, for a machine without pdflatex/pdfinfo); nothing else is
# written. The scopf suite reads $RES/scopf and $RES/scopf_pglib (SCOPF_RES / SCOPF_PGLIB_RES override either).
emit() {
    local suite=$1 py=$PUB/benchmarks/tables r=0 f v files=()
    local rs=${SCOPF_RES:-$RES/scopf} rp=${SCOPF_PGLIB_RES:-$RES/scopf_pglib}
    mkdir -p "$TABLES" "$FIGURES"
    case $suite in
        cutest)      python3 "$py/tab_cutest.py" "$RES/cutest" --cap=3600 --out="$TABLES" || r=1 ;;
        opf)         python3 "$py/tab_gpu_opf.py" "$RES/opf" --out="$TABLES" || r=1
                     python3 "$py/tab_pglib_appendix.py" "$RES/opf" --out="$TABLES" || r=1 ;;
        scopf)       python3 "$py/tab_gpu_scopf_summary.py" "$rs" "$rp" --out="$TABLES" || r=1
                     python3 "$py/tab_scopf_all_appendix.py" "$rs" "$rp" --out="$TABLES" || r=1 ;;
        figure)      python3 "$PUB/benchmarks/figures/make_fig_example_degenerate.py" --out="$FIGURES" || r=1 ;;
        *) echo "emit: unknown suite $suite (expected one of $SUITES)" >&2; return 2 ;;
    esac
    v="FLOATS_$suite"
    for f in ${!v}; do
        if [ "$suite" = figure ]; then files+=("$FIGURES/$f.tex"); else files+=("$TABLES/$f.tex"); fi
    done
    if [ "${REPRO_NOCOMPILE:-0}" = 1 ]; then
        echo "compile_tables skipped (REPRO_NOCOMPILE=1)"
    else
        compile_tables "${files[@]}" || r=1
    fi
    mark "EMIT $suite rc=$r RES=$RES"
    return $r
}

# summarize <suite>: the console summary of a suite's results (solved counts, cost, co-solved pairs) into
# $SUMMARIES/<suite>.txt; the banked benchmarks/results/paper/<suite>/summary.txt are these summaries of the banked
# results. The scopf suite writes scopf.txt and scopf_pglib.txt (each result set alone) and scopf_all.txt (the 41).
summarize() {
    local suite=$1 py=$PUB/benchmarks/tables
    local rs=${SCOPF_RES:-$RES/scopf} rp=${SCOPF_PGLIB_RES:-$RES/scopf_pglib}
    mkdir -p "$SUMMARIES"
    case $suite in
        cutest) python3 "$py/summary.py" "$RES/cutest" --traps="$INST/cutest_traps.txt" --cap=3600 > "$SUMMARIES/cutest.txt" 2>&1 ;;
        opf) python3 "$py/summary_gpu.py" "$RES/opf" opf > "$SUMMARIES/opf.txt" 2>&1 ;;
        scopf) python3 "$py/summary_gpu.py" "$rs" scopf > "$SUMMARIES/scopf.txt" 2>&1 \
                   && python3 "$py/summary_gpu.py" "$rp" scopf_pglib > "$SUMMARIES/scopf_pglib.txt" 2>&1 \
                   && python3 "$py/summary_scopf_all.py" "$rs" "$rp" > "$SUMMARIES/scopf_all.txt" 2>&1 ;;
        figure) return 0 ;;
        *) echo "summarize: unknown suite $suite" >&2; return 2 ;;
    esac
}
