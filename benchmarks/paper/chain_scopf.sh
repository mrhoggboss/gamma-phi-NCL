#!/bin/bash
# Paper campaign, GPU chain A: the SCOPF suite (23 pairs, tau_relax = 0, max_iter 3000, wall 1800), the five
# configurations x 3 repetitions, repetition-interleaved (repetition 1 of every configuration first), so that a
# partial campaign is already a usable table.   chain_scopf.sh <device>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
DEV=${1:-0}; WT=$LOGS/WALLTIME_scopf.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "P3_CHAIN_START scopf dev=$DEV HEAD=$(head_sha) data=$SCOPF_DATA"
for k in 1 2 3; do
    for c in S SP W U6A liftedkkt; do
        run_gpu_cell "$DEV" scopf "$c" "$k" "$WT" --data="$SCOPF_DATA"
    done
    mark "P3_REP_DONE scopf r$k"
    emit scopf
done
mark "P3_CHAIN_DONE scopf"
