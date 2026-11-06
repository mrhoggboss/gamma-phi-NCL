#!/bin/bash
# Arm "ablation", GPU part: SCOPF 23, PGLIB 66, COPS 13, COPS ladder (x1, tag r1, the campaign's gpu.jl settings), one
# consumer per device. The campaign has priority: no cell starts before its GPU queue has drained (`P3_CHAIN_DONE gpu1`
# in $ABL_CAMPAIGN_MARKS). Then each consumer waits for ITS device to be free of any process, claims the next suite in
# order (mkdir <cell>/CLAIM, the claim and stale-claim rules of lib.sh), runs it with run_gpu_cell (gates/gpu_device.sh:
# intruder sampling, wall cap; watch.sh stall watchdog), emits the suite's summary, and repeats; the consumer that
# settles the last suite writes ABL_CHAIN_DONE gpu.   chain_ablation_gpu.sh <device>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
GITLOCK=${ABL_GITLOCK:-$GITLOCK}
DEV=${1:?usage: chain_ablation_gpu.sh <device>}
CAMPAIGN_MARKS=${ABL_CAMPAIGN_MARKS:-/home/yifan_xu/MadNCL.jl/bench/wo64/progress_phase3.txt}
WT=$LOGS/WALLTIME_ablation.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "ABL_CHAIN_START gpu dev=$DEV HEAD=$(head_sha) data=$SCOPF_DATA"
waited=0
# and the campaign's ladder resume runs first (Yifan 2026-11-05 21:45): wait for its P3_LADDER_RESUME_DONE too
until grep -q "P3_CHAIN_DONE gpu1" "$CAMPAIGN_MARKS" && grep -q "P3_LADDER_RESUME_DONE" "$CAMPAIGN_MARKS"; do
    [ $((waited % 3600)) -eq 0 ] && mark "ABL_WAIT_CAMPAIGN dev=$DEV (waiting for P3_CHAIN_DONE gpu1 and P3_LADDER_RESUME_DONE)"
    sleep 60; waited=$((waited + 60))
done
ABL_SUITES=(scopf opf cops cops_ladder)
w=0
while :; do
    next=""
    for s in "${ABL_SUITES[@]}"; do
        d="$OUT/$s/ablation_r1"; _q_settled "$d" && continue
        if [ -d "$d/CLAIM" ]; then
            _prio_running "$d" && continue
            mark "ABL_STALE_CLAIM $s ablation r1 (claimer $(cat "$d/CLAIM/pid" 2>/dev/null) gone; freed)"; rm -rf "$d/CLAIM"
        fi
        next=$s; break
    done
    [ -z "$next" ] && break
    if [ -n "$(device_busy "$DEV")" ]; then
        [ $((w % 600)) -eq 0 ] && mark "P3_BUSY_WAIT ablation dev=$DEV next=$next pids=$(device_busy "$DEV" | tr '\n' ' ')"
        sleep 60; w=$((w + 60)); continue
    fi
    w=0
    for s in "${ABL_SUITES[@]}"; do
        d="$OUT/$s/ablation_r1"; _q_settled "$d" && continue
        mkdir -p "$d"; mkdir "$d/CLAIM" 2>/dev/null || continue
        echo $$ > "$d/CLAIM/pid"; echo "$DEV" > "$d/CLAIM/dev"
        mark "P3_PRIO_CLAIM $s ablation r1 dev=$DEV pid=$$"
        extra=(); [ "$s" = scopf ] && extra=(--data="$SCOPF_DATA")
        run_gpu_cell "$DEV" "$s" ablation 1 "$WT" "${extra[@]}"; rc=$?
        echo "$rc" > "$d/CLAIM/finished"
        [ "$rc" -ne 0 ] && mark "P3_Q_CELL_FAILED $s ablation r1 dev=$DEV rc=$rc"
        emit "$s"
        break
    done
done
all=1; for s in "${ABL_SUITES[@]}"; do _q_settled "$OUT/$s/ablation_r1" || all=0; done
[ $all -eq 1 ] && mkdir "$OUT/ABL_GPU_DONE" 2>/dev/null && mark "ABL_CHAIN_DONE gpu"
mark "ABL_GPU_EXIT dev=$DEV"
