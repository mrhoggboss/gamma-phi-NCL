#!/bin/bash
# Stall watchdog for one benchmark run. Runs <cmd...> and relaunches it (the drivers resume from their per-task
# files) whenever no result file under <root> has changed for <stall_s> seconds while it is still running. The
# solvers check their wall-time limit between iterations only, never inside a factorization, so a hung solve is
# ended here. Before a kill the time is written to <killed_at>; on restart the drivers record every task that was
# then in flight for more than 1.5 x its wall limit as EXTERNAL_KILL instead of running it again.
#
#   watch.sh <root> <killed_at> <stall_s> <log> -- <cmd...>
#
# Result files: *.csv and inflight__* under <root> (benchmarks/cutest.jl: <outdir>/rows; benchmarks/gpu.jl: <outdir>).
# The whole process tree of <cmd> is killed (Distributed workers and `timeout` children run in other process groups).
# Exit status: the command's.
set -u
ROOT=$1; KAT=$2; STALL=$3; LOG=$4; shift 4; [ "${1:-}" = "--" ] && shift
newest() { find "$ROOT" -type f \( -name '*.csv' -o -name 'inflight__*' \) -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1; }
tree() { local p=$1 c; for c in $(pgrep -P "$p" 2>/dev/null); do tree "$c"; done; echo "$p"; }
attempt=0
while :; do
    attempt=$((attempt + 1))
    echo "$(date -Is) WATCH attempt=$attempt start" >> "$LOG"
    "$@" >> "$LOG" 2>&1 &
    PID=$!
    t_launch=$(date +%s)
    killed=0
    while kill -0 "$PID" 2>/dev/null; do
        sleep 60
        n=$(newest); [ -z "$n" ] && n=$t_launch; [ "$n" -lt "$t_launch" ] && n=$t_launch
        if [ $(( $(date +%s) - n )) -gt "$STALL" ]; then
            mkdir -p "$(dirname "$KAT")"; date +%s > "$KAT"
            echo "$(date -Is) WATCH STALL > ${STALL}s: killing the process tree of $PID and relaunching" >> "$LOG"
            kill -9 $(tree "$PID") 2>/dev/null; sleep 10
            killed=1
            break
        fi
    done
    wait "$PID" 2>/dev/null; rc=$?
    [ $killed -eq 1 ] && [ $attempt -lt 50 ] && continue
    echo "$(date -Is) WATCH done rc=$rc attempts=$attempt" >> "$LOG"
    exit "$rc"
done
