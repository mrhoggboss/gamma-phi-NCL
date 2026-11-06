#!/bin/bash
# Arm "ablation" (= U6A with the quadratic kernel, Yifan 2026-11-05), CPU part: CUTEst pop1070 with the campaign's CUTEst
# settings (run_cpu_pool: K2r + HSL MA57 with automatic scaling, tol 1e-8, cvtol 1e-4, max_iter 3000, one 3600 s cap,
# stall watchdog 7200 s, CPU_NW workers, x1). Markers: $P3_MARKS. Git writes take $ABL_GITLOCK (the campaign's lock: one
# repository, several worktrees).   chain_ablation_cpu.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
GITLOCK=${ABL_GITLOCK:-$GITLOCK}
WT=$LOGS/WALLTIME_ablation.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "ABL_CHAIN_START cpu workers=$CPU_NW HEAD=$(head_sha) list=$CUTEST_LIST"
run_cpu_pool ablation "$WT"
emit cutest
mark "ABL_CHAIN_DONE cpu"
