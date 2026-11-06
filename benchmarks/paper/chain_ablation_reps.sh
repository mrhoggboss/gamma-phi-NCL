#!/bin/bash
# Arm "ablation", repetitions 2 and 3 of the GPU suites (Yifan 2026-11-06): {scopf, cops, opf} x {r2, r3}, claimed in the
# order scopf r2, scopf r3, cops r2, cops r3, opf r2, opf r3, with the campaign's gpu.jl settings (identical to r1), one
# consumer per device. Each consumer waits for ITS device to be free of any process, claims the first cell that is neither
# settled nor claimed (mkdir <cell>/CLAIM holding pid / dev / finished; the stale-claim rule of lib.sh), runs it with
# run_gpu_cell (gates/gpu_device.sh: intruder sampling, wall cap; watch.sh stall watchdog) and repeats. A failed attempt is
# settled, not re-run. Each suite whose two cells are settled is emitted once (guard <suite>/EMITTED_ablation_reps); the
# consumer that settles the last cell writes the chain's completion marker. Every marker of this chain carries the
# ABL_REP_ prefix: mark() below replaces lib.sh's P3_ prefix.   chain_ablation_reps.sh <device>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mark() { local m="$*"; m="ABL_REP_${m#P3_}"; echo "$(date -Is) $m" >> "$MARKS"; }
DEV=${1:?usage: chain_ablation_reps.sh <device>}
WT=$LOGS/WALLTIME_ablation_reps.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
REP_QUEUE=("scopf 2" "scopf 3" "cops 2" "cops 3" "opf 2" "opf 3")
mark "CHAIN_START gpu dev=$DEV HEAD=$(head_sha) data=$SCOPF_DATA"
w=0
while :; do
    next=""
    for item in "${REP_QUEUE[@]}"; do
        read -r s k <<< "$item"; d="$OUT/$s/ablation_r$k"
        _q_settled "$d" && continue
        if [ -d "$d/CLAIM" ]; then
            _prio_running "$d" && continue
            mark "STALE_CLAIM $s ablation r$k (claimer $(cat "$d/CLAIM/pid" 2>/dev/null) gone; freed)"; rm -rf "$d/CLAIM"
        fi
        next="$s r$k"; break
    done
    [ -z "$next" ] && break
    if [ -n "$(device_busy "$DEV")" ]; then
        [ $((w % 600)) -eq 0 ] && mark "BUSY_WAIT ablation dev=$DEV next=${next/ /\/} pids=$(device_busy "$DEV" | tr '\n' ' ')"
        sleep 60; w=$((w + 60)); continue
    fi
    w=0
    for item in "${REP_QUEUE[@]}"; do
        read -r s k <<< "$item"; d="$OUT/$s/ablation_r$k"
        _q_settled "$d" && continue
        mkdir -p "$d"; mkdir "$d/CLAIM" 2>/dev/null || continue
        echo $$ > "$d/CLAIM/pid"; echo "$DEV" > "$d/CLAIM/dev"
        mark "CLAIM $s ablation r$k dev=$DEV pid=$$"
        extra=(); [ "$s" = scopf ] && extra=(--data="$SCOPF_DATA")
        run_gpu_cell "$DEV" "$s" ablation "$k" "$WT" "${extra[@]}"; rc=$?
        echo "$rc" > "$d/CLAIM/finished"
        [ "$rc" -ne 0 ] && mark "Q_CELL_FAILED $s ablation r$k dev=$DEV rc=$rc"
        if _q_settled "$OUT/$s/ablation_r2" && _q_settled "$OUT/$s/ablation_r3" && mkdir "$OUT/$s/EMITTED_ablation_reps" 2>/dev/null; then
            emit "$s"
        fi
        break
    done
done
all=1
for item in "${REP_QUEUE[@]}"; do read -r s k <<< "$item"; _q_settled "$OUT/$s/ablation_r$k" || all=0; done
[ $all -eq 1 ] && mkdir "$OUT/ABL_REP_DONE" 2>/dev/null && mark "CHAIN_DONE gpu"
mark "GPU_EXIT dev=$DEV"
