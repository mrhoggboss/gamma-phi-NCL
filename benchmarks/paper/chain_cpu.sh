#!/bin/bash
# CUTEst on the CPU (Table tab:cutest): the 1070 constrained problems, K2r (MadNCL configurations) and HSL MA57 with
# automatic scaling, one 3600 s cap per solve, max_iter 3000, CPU_NW workers (default 30), stall watchdog 7200 s; one
# pool per configuration, in sequence, x 1 (the CPU runs reproduce exactly). Results land in
# benchmarks/out/paper/results/cutest/ (see lib.sh); the banked benchmarks/results/paper/cutest/ is not touched.
#   chain_cpu.sh [config ...]        (default: S SP W U6A liftedkkt ipopt madnlp)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
WT=$LOGS/WALLTIME_cpu.csv; wt_header "$WT"
CONFIGS=${*:-S SP W U6A liftedkkt ipopt madnlp}
mark "CHAIN_START cpu workers=$CPU_NW HEAD=$(head_sha) list=$CUTEST_LIST configs=$CONFIGS"
for c in $CONFIGS; do run_cpu_pool "$c" "$WT"; done
mark "CHAIN_DONE cpu"
