#!/bin/bash
# One GPU suite on one device: the five configurations x the repetitions, repetition-major (repetition 1 of every
# configuration first). Results land in benchmarks/out/paper/results/<suite>/ (see lib.sh); the banked
# benchmarks/results/paper/<suite>/ is not touched. Resumable: run the same command again after a crash.
#   chain_gpu.sh <device> <suite> [reps] [configs]
#     suite   opf (Tables tab:gpu-opf, tab:pglib-appendix) | scopf, scopf_pglib (the 23 reference-list and the 18
#             protocol instances, together in Tables tab:gpu-scopf and tab:scopf-appendix)
#     reps    default "1 2 3"; configs default "S SP W U6A liftedkkt"
#   env: SCOPF_DATA (scopf) / SCOPF_PGLIB_DATA (scopf_pglib): the data directories of the fetch scripts;
#        GPU_DEVICE_NOGATE=1 runs on a device that carries other processes (logged, nothing is killed)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
DEV=${1:?usage: chain_gpu.sh <device> <suite> [reps] [configs]}; SUITE=${2:?usage: chain_gpu.sh <device> <suite> [reps] [configs]}
REPS=${3:-1 2 3}; CONFIGS=${4:-S SP W U6A liftedkkt}
WT=$LOGS/WALLTIME_$SUITE.csv; wt_header "$WT"
mark "CHAIN_START $SUITE dev=$DEV HEAD=$(head_sha) reps=$REPS configs=$CONFIGS"
for k in $REPS; do
    for c in $CONFIGS; do run_gpu_cell "$DEV" "$SUITE" "$c" "$k" "$WT"; done
done
mark "CHAIN_DONE $SUITE"
