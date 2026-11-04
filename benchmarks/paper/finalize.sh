#!/bin/bash
# Paper campaign: waits for the three chains, then regenerates every float, the appendix and the console summaries.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
until grep -q "P3_CHAIN_DONE scopf" "$MARKS" && grep -q "P3_CHAIN_DONE gpu1" "$MARKS" && grep -q "P3_CHAIN_DONE cpu" "$MARKS"; do
    sleep 300
done
r=0
for s in scopf opf cops cops_ladder cutest; do emit "$s" || r=1; done
mark "P3_ALL_DONE emit_rc=$r HEAD=$(head_sha)"
