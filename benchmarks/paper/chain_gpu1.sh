#!/bin/bash
# Paper campaign, GPU chain B: PGLIB 66 (max_iter 1000, wall 1800; the 45-case table is scored from the same runs)
# x five configurations x 3 repetitions, repetition-interleaved; then COPS 13 x five x 3; then the COPS size ladder
# (46 rungs) x five x 1 (the scaling figure).   chain_gpu1.sh <device>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
DEV=${1:-1}; WT=$LOGS/WALLTIME_gpu1.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "P3_CHAIN_START gpu1 dev=$DEV HEAD=$(head_sha)"
for suite in opf cops; do
    for k in 1 2 3; do
        for c in S SP W U6A liftedkkt; do run_gpu_cell "$DEV" "$suite" "$c" "$k" "$WT"; done
        mark "P3_REP_DONE $suite r$k"
        emit "$suite"
    done
done
for c in S SP W U6A liftedkkt; do run_gpu_cell "$DEV" cops_ladder "$c" 1 "$WT"; done
mark "P3_REP_DONE cops_ladder r1"
emit cops_ladder
mark "P3_CHAIN_DONE gpu1"
