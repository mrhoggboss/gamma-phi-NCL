#!/bin/bash
# Paper campaign launcher: the three chains and the finalizer, each detached.
#   benchmarks/paper/run_campaign.sh [scopf_device=0] [gpu1_device=1]
# Markers: $P3_MARKS (default benchmarks/out/paper/progress.txt). Every chain is resumable: run this again after a
# crash; completed cells (DONE files) are skipped and a cell in progress resumes from its result files.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
D0=${1:-0}; D1=${2:-1}
mark "P3_START HEAD=$(head_sha) scopf_dev=$D0 gpu1_dev=$D1 cpu_workers=$CPU_NW"
H=$PUB/benchmarks/paper
reset_unfinished_claims   # failed attempts of the GPU claim queue are retried on a relaunch
setsid nohup "$H/chain_scopf.sh" "$D0" >> "$LOGS/chain_scopf.out" 2>&1 < /dev/null &
# PGLIB / COPS / COPS-ladder cells: one claim-queue consumer per device, cells on whichever GPU frees first (2026-11-05)
setsid nohup "$H/chain_gpu_queue.sh" "$D0" >> "$LOGS/chain_gpuq_dev$D0.out" 2>&1 < /dev/null &
setsid nohup "$H/chain_gpu_queue.sh" "$D1" >> "$LOGS/chain_gpuq_dev$D1.out" 2>&1 < /dev/null &
setsid nohup "$H/chain_cpu.sh" >> "$LOGS/chain_cpu.out" 2>&1 < /dev/null &
setsid nohup "$H/finalize.sh" >> "$LOGS/finalize.out" 2>&1 < /dev/null &
