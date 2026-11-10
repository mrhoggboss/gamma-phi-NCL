#!/bin/bash
# Shared functions of the paper-campaign chains (sourced by chain_*.sh).
#
# Layout: raw outputs (result CSVs, configuration echoes, per-outer traces, logs) under
#   benchmarks/out/paper/<suite>/<config>_r<k>/            (gitignored)
# and, once a cell (one suite x configuration x repetition) is complete, its result CSV and configuration echo are
# copied flat into
#   benchmarks/results/paper/<suite>/                      (committed: the paper's data; the emitters read these)
# Every GPU cell runs through gates/gpu_device.sh (refuses a device that carries any other process; the chain waits
# until it is free; one job per device; a wall cap; the compute processes of others on the device are sampled every
# 60 s and counted per cell, and their cells' wall times are flagged) under watch.sh (stall watchdog, resume).
set -u
PUB=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=$PUB/benchmarks/out/paper
RES=$PUB/benchmarks/results/paper
LOGS=$OUT/logs
TABLES=$OUT/tables
GPUENV=$PUB/benchmarks/envs/gpu
CPUENV=$PUB/benchmarks/envs/cpu
SCOPF_DATA=${SCOPF_DATA:-$PUB/benchmarks/out/scopf_data}
MARKS=${P3_MARKS:-$OUT/progress.txt}
GITLOCK=$OUT/.gitlock
mkdir -p "$OUT" "$RES" "$LOGS" "$TABLES"

mark() { echo "$(date -Is) $*" >> "$MARKS"; }
head_sha() { git -C "$PUB" rev-parse --short HEAD; }

# commit the given paths (relative to $PUB) under a lock shared by the chains
commit_paths() {
    local msg=$1; shift
    (
        flock 9
        git -C "$PUB" add -- "$@" && \
        git -C "$PUB" commit -q -m "$msg

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015H5cioizWae4AHHh6Ppem7" -- "$@" >/dev/null 2>&1
        echo "commit rc=$? $(head_sha)"
    ) 9> "$GITLOCK"
}

device_busy() {   # device_busy <dev>: prints the compute processes on that device (empty = free)
    local uuid
    uuid=$(nvidia-smi --query-gpu=index,uuid --format=csv,noheader | awk -F', ' -v d="$1" '$1==d{print $2}')
    nvidia-smi --query-compute-apps=gpu_uuid,pid --format=csv,noheader | awk -F', ' -v u="$uuid" '$1==u{print $2}'
}

# run_gpu_cell <dev> <suite> <config> <k> <walltime_csv> [driver options...]
run_gpu_cell() {
    local dev=$1 suite=$2 config=$3 k=$4 wt=$5; shift 5
    local tag="r$k" dir="$OUT/$suite/${config}_r$k" log="$LOGS/${suite}_${config}_r$k.log"
    local stall=3300   # 1.5 x the 1800 s wall + 600 s; the stall clock restarts at every instance start
    mkdir -p "$dir"
    if [ -f "$dir/DONE" ]; then mark "P3_CELL_SKIP $suite $config r$k (already done)"; return 0; fi
    local waited=0
    while [ -n "$(device_busy "$dev")" ]; do
        [ $((waited % 600)) -eq 0 ] && mark "P3_BUSY_WAIT $suite $config r$k dev=$dev pids=$(device_busy "$dev" | tr '\n' ' ')"
        sleep 60; waited=$((waited + 60))
    done
    local t0 rc head
    t0=$(date +%s); head=$(head_sha)
    mark "P3_CELL_START $suite $config r$k dev=$dev HEAD=$head"
    while :; do
        "$PUB/benchmarks/paper/watch.sh" "$dir" "$dir/KILLED_AT" "$stall" "$log" -- \
            "$PUB/gates/gpu_device.sh" "$dev" 172800 "$log" -- \
            julia +1.11.2 --project="$GPUENV" "$PUB/benchmarks/gpu.jl" "$suite" "$config" "$dir" --tag="$tag" --trace "$@"
        rc=$?
        [ $rc -ne 3 ] && break          # 3 = the device became busy between the check and the launch: wait again
        mark "P3_BUSY_WAIT $suite $config r$k dev=$dev (at launch)"; sleep 120
    done
    local intr kills
    intr=$(grep -c " INTRUDER " "$log" 2>/dev/null); kills=$(grep -c "WATCH STALL" "$log" 2>/dev/null)
    echo "$suite,$config,r$k,$dev,$t0,$(date +%s),$(( $(date +%s) - t0 )),$rc,$intr,$kills,$head" >> "$wt"
    if [ $rc -eq 0 ] && [ -f "$dir/${suite}__${config}__r$k.csv" ]; then
        mkdir -p "$RES/$suite"
        cp "$dir/${suite}__${config}__r$k.csv" "$RES/$suite/"
        cp "$dir/config_${suite}__r$k.txt" "$RES/$suite/config_${suite}__${config}__r$k.txt"
        touch "$dir/DONE"
        commit_paths "paper results: $suite $config r$k (rc=$rc, intruder samples $intr, stall kills $kills)" \
            "benchmarks/results/paper/$suite/${suite}__${config}__r$k.csv" \
            "benchmarks/results/paper/$suite/config_${suite}__${config}__r$k.txt" >> "$log"
    fi
    mark "P3_CELL_DONE $suite $config r$k rc=$rc intruders=$intr stall_kills=$kills"
    return $rc
}

# compile_tables <dir>: \input every .tex fragment of <dir> into one document and run pdflatex
compile_tables() {
    local d=$1 doc
    doc=$d/_compile_check.tex
    {
        echo '\documentclass{article}'
        echo '\usepackage[margin=0.6in]{geometry}\usepackage{amsmath,amssymb,booktabs,longtable,multirow,array,graphicx,xcolor}'
        echo '\usepackage{pgfplots}\pgfplotsset{compat=1.17}\usepgfplotslibrary{groupplots}'
        echo '\newcommand{\claudegreen}[1]{\textcolor{green!50!black}{#1}}'
        echo '\begin{document}'
        for f in "$d"/*.tex; do
            case $(basename "$f") in _*) continue;; esac
            echo "\\clearpage\\input{$(basename "$f" .tex)}"
        done
        echo '\end{document}'
    } > "$doc"
    (cd "$d" && pdflatex -interaction=nonstopmode -halt-on-error _compile_check.tex > _compile_check.out 2>&1)
    local rc=$?
    echo "compile_tables $d rc=$rc ($(ls "$d"/*.tex | grep -vc '/_'))"
    return $rc
}

# emit <suite>: regenerate the suite's floats from the committed results into $TABLES and check they compile
emit() {
    local suite=$1 py=$PUB/benchmarks/tables r=0
    case $suite in
        scopf)  python3 "$py/tab_gpu_scopf.py" "$RES/scopf" --out="$TABLES" || r=1
                python3 "$py/tab_scopf_config.py" "$RES/scopf" --out="$TABLES" || r=1 ;;
        scopf_pglib)   # the protocol SCOPF set (18 PGLIB instances, WO-69): main-text float + per-instance appendix
                python3 "$py/tab_gpu_scopf_pglib.py" "$RES/scopf_pglib" --out="$TABLES" || r=1
                python3 "$py/tab_scopf_pglib_appendix.py" "$RES/scopf_pglib" --out="$TABLES" || r=1 ;;
        opf)    # the main-text float and the appendix both cover all 66 cases
                python3 "$py/tab_gpu_opf.py" "$RES/opf" --out="$TABLES" || r=1
                python3 "$py/tab_pglib_appendix.py" "$RES/opf" --out="$TABLES" || r=1 ;;
        cops)   : ;;   # no float: the console summary below is the record
        cops_ladder) python3 "$py/fig_gpu_scaling.py" "$RES/cops_ladder" --tag=r1 --out="$TABLES" || r=1 ;;
        cutest) python3 "$py/tab_cutest.py" "$RES/cutest" --cap=3600 --out="$TABLES" || r=1
                python3 "$py/summary.py" "$RES/cutest" --traps="$PUB/benchmarks/instances/cutest_traps.txt" --cap=3600 \
                    > "$RES/cutest/summary.txt" 2>&1 || r=1 ;;
    esac
    case $suite in
        scopf|scopf_pglib|opf|cops|cops_ladder)
            python3 "$py/summary_gpu.py" "$RES/$suite" "$suite" > "$RES/$suite/summary.txt" 2>&1 || r=1 ;;
    esac
    compile_tables "$TABLES" || r=1
    commit_paths "paper results: $suite summaries" "benchmarks/results/paper/$suite" >/dev/null
    mark "P3_EMIT $suite rc=$r"
    return $r
}

# kill leftover Julia processes of one CPU pool (Distributed workers inherit P3_POOL_TAG from the master)
cleanup_orphans() {
    local tag=$1 p n=0
    for p in $(pgrep -u "$(id -u)" julia); do
        if tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "P3_POOL_TAG=$tag"; then kill -9 "$p" 2>/dev/null && n=$((n + 1)); fi
    done
    echo "cleanup_orphans $tag: killed $n"
}

# run_cpu_pool <config> <walltime_csv>: CUTEst pop1070, K2r (MadNCL) / MA57, one 3600 s cap, under the stall watchdog
CPU_NW=${CPU_NW:-30}
CUTEST_LIST=${CUTEST_LIST:-$PUB/benchmarks/instances/cutest_pop1070.txt}
run_cpu_pool() {
    local config=$1 wt=$2
    local dir="$OUT/cutest/${config}_r1" log="$LOGS/cutest_${config}.log" tr="" rc head t0
    mkdir -p "$dir/rows"
    if [ -f "$dir/DONE" ]; then mark "P3_CELL_SKIP cutest $config r1 (already done)"; return 0; fi
    case $config in S|SP|W|U6A|ablation|Wos) tr=--trace ;; esac
    t0=$(date +%s); head=$(head_sha)
    mark "P3_CELL_START cutest $config r1 workers=$CPU_NW HEAD=$head"
    P3_POOL_TAG="p3_cutest_$config" "$PUB/benchmarks/paper/watch.sh" "$dir/rows" "$dir/rows/KILLED_AT" 7200 "$log" -- \
        julia --project="$CPUENV" "$PUB/benchmarks/cutest.jl" "$CUTEST_LIST" "$config" ma57 "$CPU_NW" 3600 "$dir" $tr
    rc=$?
    cleanup_orphans "p3_cutest_$config" >> "$log"
    local kills ek wd
    kills=$(grep -c "WATCH STALL" "$log" 2>/dev/null)
    ek=$(grep -c ",EXTERNAL_KILL," "$dir/cutest__${config}__ma57.csv" 2>/dev/null); wd=$(grep -c ",WORKER_DIED," "$dir/cutest__${config}__ma57.csv" 2>/dev/null)
    echo "cutest,$config,r1,cpu,$t0,$(date +%s),$(( $(date +%s) - t0 )),$rc,0,$kills,$head" >> "$wt"
    if [ $rc -eq 0 ] && [ -f "$dir/cutest__${config}__ma57.csv" ]; then
        mkdir -p "$RES/cutest"
        cp "$dir/cutest__${config}__ma57.csv" "$RES/cutest/"
        cp "$dir/config.txt" "$RES/cutest/config_${config}.txt"
        touch "$dir/DONE"
        commit_paths "paper results: cutest $config (rc=$rc, stall kills $kills, EXTERNAL_KILL $ek, WORKER_DIED $wd)" \
            "benchmarks/results/paper/cutest/cutest__${config}__ma57.csv" "benchmarks/results/paper/cutest/config_${config}.txt" >> "$log"
    fi
    mark "P3_CUTEST_DONE $config rc=$rc stall_kills=$kills external_kill=$ek worker_died=$wd"
    return $rc
}

# ---- priority queue: the rep-1 PGLIB and COPS cells on whichever GPU frees first (Yifan 2026-11-04 15:20) ----
# Both GPU chains call run_prio_queue before their own loops. A cell is claimed atomically with
# `mkdir <cell dir>/CLAIM` (holding the claimer's pid; `finished` is written when its attempt ends); a free device
# takes the next cell that is neither DONE nor claimed, so a free device never sits behind a claimed cell. A claim is
# stale only if its claimer is dead AND no benchmarks/gpu.jl process runs on that cell directory; a stale claim is
# freed and the cell resumes from its result files. With `wait`, the call returns only when no queue cell is still
# running on the other chain (chain_gpu1's own loop visits the same cells afterwards and must not start one twice).
# The rep-1 marker and emitters run once, by whichever chain sees all five cells of the suite DONE (EMITTED_r1 guard).
PRIO_QUEUE=("opf SP" "opf W" "opf liftedkkt" "cops S" "cops SP" "cops W" "cops U6A" "cops liftedkkt")
_prio_running() {   # _prio_running <dir>: 0 if a claimed, unfinished attempt on <dir> is alive
    local d=$1 pid
    [ -d "$d/CLAIM" ] && [ ! -f "$d/CLAIM/finished" ] || return 1
    pid=$(cat "$d/CLAIM/pid" 2>/dev/null)
    { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; } && return 0
    pgrep -u "$(id -u)" -f "benchmarks/gpu.jl [a-z_]+ [A-Za-z0-9]+ $d( |$)" > /dev/null && return 0
    return 1
}
run_prio_queue() {
    local dev=$1 mode=${2:-} item suite config d next running waited rc s c all
    while :; do
        next=""; running=""
        for item in "${PRIO_QUEUE[@]}"; do
            read -r suite config <<< "$item"; d="$OUT/$suite/${config}_r1"
            [ -f "$d/DONE" ] && continue
            if [ -d "$d/CLAIM" ]; then
                [ -f "$d/CLAIM/finished" ] && continue            # attempted and not DONE: left to the chain loops
                if _prio_running "$d"; then running="$running $suite/$config"; continue; fi
                mark "P3_PRIO_STALE_CLAIM $suite $config r1 (claimer $(cat "$d/CLAIM/pid" 2>/dev/null) gone; freed)"
                rm -rf "$d/CLAIM"
            fi
            [ -z "$next" ] && next="$item"
        done
        if [ -n "$next" ]; then
            waited=0
            while [ -n "$(device_busy "$dev")" ]; do
                [ $((waited % 600)) -eq 0 ] && mark "P3_BUSY_WAIT prio dev=$dev next=${next/ //} pids=$(device_busy "$dev" | tr '\n' ' ')"
                sleep 60; waited=$((waited + 60))
            done
            for item in "${PRIO_QUEUE[@]}"; do                 # claim after the wait: the first free cell now
                read -r suite config <<< "$item"; d="$OUT/$suite/${config}_r1"
                [ -f "$d/DONE" ] && continue
                mkdir -p "$d"
                mkdir "$d/CLAIM" 2>/dev/null || continue
                echo $$ > "$d/CLAIM/pid"; echo "$dev" > "$d/CLAIM/dev"
                mark "P3_PRIO_CLAIM $suite $config r1 dev=$dev pid=$$"
                run_gpu_cell "$dev" "$suite" "$config" 1 "$LOGS/WALLTIME_gpu1.csv"; rc=$?
                echo "$rc" > "$d/CLAIM/finished"
                break
            done
            continue
        fi
        if [ -n "$running" ] && [ "$mode" = wait ]; then sleep 60; continue; fi
        break
    done
    for s in opf cops; do
        all=1
        for c in S SP W U6A liftedkkt; do [ -f "$OUT/$s/${c}_r1/DONE" ] || all=0; done
        [ $all -eq 1 ] && rep_done "$s" 1
    done
    mark "P3_PRIO_QUEUE_EXIT dev=$dev mode=${mode:-nowait}${running:+ still running elsewhere:$running}"
}
# rep_done <suite> <k>: the repetition marker and the emitters, once per (suite, repetition) across both GPU chains
rep_done() {
    mkdir -p "$OUT/$1"
    if mkdir "$OUT/$1/EMITTED_r$2" 2>/dev/null; then mark "P3_REP_DONE $1 r$2"; emit "$1"; fi
}

# ---- device-agnostic claim queue for every remaining PGLIB / COPS / ladder cell (2026-11-05) ----
# Order: repetition 1, 2, 3, opf before cops within a repetition, then the COPS ladder (x1). Each consumer
# (chain_gpu_queue.sh <dev>, one per device) waits for ITS device to be free of any process, claims the first cell
# that is neither settled nor claimed (`mkdir <cell>/CLAIM`, with pid / dev / finished as in run_prio_queue; the same
# stale-claim rule), runs it with run_gpu_cell on its device, and repeats; while waiting it re-scans every minute and
# exits when nothing is left to claim. A cell is settled when it is DONE or its attempt has finished (a failed attempt,
# rc != 0, is left for a campaign resume; run_campaign.sh frees such claims before relaunching). After every cell the
# consumer emits each (suite, repetition) whose five cells are settled once (rep_done) and, once every queue cell is
# settled and none runs, `P3_CHAIN_DONE gpu1` once (guard $OUT/CHAIN_DONE_gpu1) — whichever consumer finishes last.
GPU_QUEUE=()
for _k in 1 2 3; do for _s in opf cops; do for _c in S SP W U6A liftedkkt; do GPU_QUEUE+=("$_s $_c $_k"); done; done; done
for _c in S SP W U6A liftedkkt; do GPU_QUEUE+=("cops_ladder $_c 1"); done
_q_settled() { [ -f "$1/DONE" ] || [ -f "$1/CLAIM/finished" ]; }
_q_check_done() {
    local s k c all item suite config kk d failed=""
    for s in opf cops cops_ladder; do for k in 1 2 3; do
        [ "$s" = cops_ladder ] && [ "$k" -gt 1 ] && continue
        all=1; for c in S SP W U6A liftedkkt; do _q_settled "$OUT/$s/${c}_r$k" || all=0; done
        [ $all -eq 1 ] && rep_done "$s" "$k"
    done; done
    all=1
    for item in "${GPU_QUEUE[@]}"; do
        read -r suite config kk <<< "$item"; d="$OUT/$suite/${config}_r$kk"
        _q_settled "$d" || all=0
        [ -f "$d/DONE" ] || failed="$failed $suite/$config/r$kk"
    done
    if [ $all -eq 1 ] && mkdir "$OUT/CHAIN_DONE_gpu1" 2>/dev/null; then
        mark "P3_CHAIN_DONE gpu1${failed:+ (attempted, not DONE:$failed)}"
    fi
}
run_gpu_queue() {
    local dev=$1 item suite config k d next waited=0 rc
    while :; do
        next=""
        for item in "${GPU_QUEUE[@]}"; do
            read -r suite config k <<< "$item"; d="$OUT/$suite/${config}_r$k"
            _q_settled "$d" && continue
            if [ -d "$d/CLAIM" ]; then
                _prio_running "$d" && continue
                mark "P3_PRIO_STALE_CLAIM $suite $config r$k (claimer $(cat "$d/CLAIM/pid" 2>/dev/null) gone; freed)"
                rm -rf "$d/CLAIM"
            fi
            next="$suite/$config/r$k"; break
        done
        [ -z "$next" ] && break
        if [ -n "$(device_busy "$dev")" ]; then
            [ $((waited % 600)) -eq 0 ] && mark "P3_BUSY_WAIT prio dev=$dev next=$next pids=$(device_busy "$dev" | tr '\n' ' ')"
            sleep 60; waited=$((waited + 60)); continue
        fi
        waited=0
        for item in "${GPU_QUEUE[@]}"; do
            read -r suite config k <<< "$item"; d="$OUT/$suite/${config}_r$k"
            _q_settled "$d" && continue
            mkdir -p "$d"
            mkdir "$d/CLAIM" 2>/dev/null || continue
            echo $$ > "$d/CLAIM/pid"; echo "$dev" > "$d/CLAIM/dev"
            mark "P3_PRIO_CLAIM $suite $config r$k dev=$dev pid=$$"
            run_gpu_cell "$dev" "$suite" "$config" "$k" "$LOGS/WALLTIME_gpu1.csv"; rc=$?
            echo "$rc" > "$d/CLAIM/finished"
            [ "$rc" -ne 0 ] && mark "P3_Q_CELL_FAILED $suite $config r$k dev=$dev rc=$rc (left for a campaign resume)"
            _q_check_done
            break
        done
    done
    _q_check_done
    mark "P3_PRIO_QUEUE_EXIT dev=$dev mode=queue"
}
# free the claims of queue cells that are not DONE (failed attempts), so that a relaunch retries them; run only while
# no GPU consumer is running (run_campaign.sh)
reset_unfinished_claims() {
    local item suite config k d n=0
    for item in "${GPU_QUEUE[@]}"; do
        read -r suite config k <<< "$item"; d="$OUT/$suite/${config}_r$k"
        if [ -d "$d/CLAIM" ] && [ ! -f "$d/DONE" ] && ! _prio_running "$d"; then rm -rf "$d/CLAIM"; n=$((n + 1)); fi
    done
    [ $n -gt 0 ] && mark "P3_Q_RESET_CLAIMS $n (not DONE, no live claimer)"
    return 0
}
