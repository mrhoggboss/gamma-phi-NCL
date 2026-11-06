#!/bin/bash
# Configuration "Wos" (γ-NCL, one-sided: W with weight_clip = (1e-30, 1.0), Yifan 2026-11-06), CPU part: CUTEst pop1070
# with the campaign's CUTEst settings (run_cpu_pool: K2r + HSL MA57 with automatic scaling, tol 1e-8, cvtol 1e-4,
# max_iter 3000, one 3600 s cap, stall watchdog 7200 s, CPU_NW workers, x1). Markers: $P3_MARKS. Git writes take
# $ABL_GITLOCK (the campaign's lock: one repository, several worktrees).   chain_wos_cpu.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
GITLOCK=${ABL_GITLOCK:-$GITLOCK}
WT=$LOGS/WALLTIME_wos.csv
[ -f "$WT" ] || echo "suite,config,rep,dev,t_start,t_end,elapsed_s,rc,intruder_samples,stall_kills,head" > "$WT"
mark "WOS_CHAIN_START cpu workers=$CPU_NW HEAD=$(head_sha) list=$CUTEST_LIST"
run_cpu_pool Wos "$WT"
emit cutest
mark "WOS_CHAIN_DONE cpu"
