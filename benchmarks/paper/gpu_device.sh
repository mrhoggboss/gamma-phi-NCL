#!/bin/bash
# Run one command on one GPU, with a wall cap and an intruder sampler (every 60 s, the compute processes on the device
# other than ours are logged with their user as INTRUDER lines; nothing is killed).
#
#   benchmarks/paper/gpu_device.sh <dev> <cap seconds> <log> -- <command...>
#
# Exit status: the command's, or 2 if there is no such device.
set -u
DEV=$1; CAP=$2; LOG=$3; shift 3
[ "$1" = "--" ] && shift
UUID=$(nvidia-smi --query-gpu=index,uuid --format=csv,noheader | awk -F', ' -v d="$DEV" '$1==d{print $2}')
[ -n "$UUID" ] || { echo "no device $DEV" >&2; exit 2; }
apps() { nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory --format=csv,noheader | awk -F', ' -v u="$UUID" '$1==u{print $2" "$3}'; }
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
