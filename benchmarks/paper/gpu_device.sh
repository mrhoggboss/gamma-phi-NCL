#!/bin/bash
# Run one command on one GPU, only if no other process holds that device, with a wall cap and an
# intruder sampler (every 60 s, the compute processes on the device other than ours are logged with
# their user; nothing is killed).
#
#   benchmarks/paper/gpu_device.sh <dev 0|1> <cap seconds> <log> -- <command...>
#
# Exit status: the command's, or 3 if the device is busy at launch.
# GPU_DEVICE_NOGATE=1 (Yifan 2026-11-11): launch on a busy device anyway; the busy state is logged (DEVICE_BUSY_IGNORED)
# and the intruder sampler runs as usual. Default 0 = refuse (exit 3).
set -u
DEV=$1; CAP=$2; LOG=$3; shift 3
[ "$1" = "--" ] && shift
UUID=$(nvidia-smi --query-gpu=index,uuid --format=csv,noheader | awk -F', ' -v d="$DEV" '$1==d{print $2}')
[ -n "$UUID" ] || { echo "no device $DEV" >&2; exit 2; }
apps() { nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory --format=csv,noheader | awk -F', ' -v u="$UUID" '$1==u{print $2" "$3}'; }
BUSY=$(apps)
if [ -n "$BUSY" ]; then
    if [ "${GPU_DEVICE_NOGATE:-0}" = 1 ]; then
        echo "$(date -Is) DEVICE_BUSY_IGNORED dev=$DEV (GPU_DEVICE_NOGATE=1): $(echo "$BUSY" | while read -r p m; do echo "$p $m $(ps -o user= -p "$p")"; done | tr '\n' ';')" | tee -a "$LOG"
    else
        echo "$(date -Is) DEVICE_BUSY dev=$DEV: $(echo "$BUSY" | while read -r p m; do echo "$p $m $(ps -o user= -p "$p")"; done | tr '\n' ';')" | tee -a "$LOG"
        exit 3
    fi
fi
echo "$(date -Is) START dev=$DEV uuid=$UUID cap=$CAP cmd: $*" >> "$LOG"
CUDA_VISIBLE_DEVICES=$DEV timeout --signal=KILL "$CAP" "$@" >> "$LOG" 2>&1 &
PID=$!
tree() { local p=$1 c; echo "$p"; for c in $(pgrep -P "$p" 2>/dev/null); do tree "$c"; done; }
( while kill -0 $PID 2>/dev/null; do
      sleep 60
      mine="|$(tree $PID | tr '\n' '|')"
      apps | awk -v m="$mine" 'index(m,"|"$1"|")==0' | while read -r p mem; do
          echo "$(date -Is) INTRUDER dev=$DEV pid=$p mem=$mem user=$(ps -o user= -p "$p")" >> "$LOG"
      done
  done ) &
SAMPLER=$!
wait $PID; RC=$?
kill $SAMPLER 2>/dev/null
echo "$(date -Is) END dev=$DEV rc=$RC" >> "$LOG"
exit $RC
