#!/bin/bash
# Paper campaign, CPU chain: CUTEst pop1070, K2r (MadNCL configurations) and HSL MA57 with automatic scaling, one
# 3600 s cap, max_iter 3000, CPU_NW workers (default 30), stall watchdog 7200 s; one pool per configuration, in
# sequence, x 1 (the CPU runs reproduce exactly).   chain_cpu.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
WT=$LOGS/WALLTIME_cpu.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "P3_CHAIN_START cpu workers=$CPU_NW HEAD=$(head_sha) list=$CUTEST_LIST"
for c in S SP W U6A ipopt liftedkkt madnlp; do
    run_cpu_pool "$c" "$WT"
    emit cutest
done
mark "P3_CHAIN_DONE cpu"
