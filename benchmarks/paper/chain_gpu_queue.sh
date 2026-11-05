#!/bin/bash
# Paper campaign, GPU consumer (2026-11-05): every remaining PGLIB / COPS / COPS-ladder cell runs on whichever GPU frees
# first — one consumer per device, each serving the claim queue in lib.sh (run_gpu_queue). The consumer that settles
# the last cell writes P3_CHAIN_DONE gpu1 (finalize.sh's marker); the other exits quietly.   chain_gpu_queue.sh <device>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
DEV=${1:?usage: chain_gpu_queue.sh <device>}; WT=$LOGS/WALLTIME_gpu1.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "P3_CHAIN_START gpuq dev=$DEV HEAD=$(head_sha)"
run_gpu_queue "$DEV"
