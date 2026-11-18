#!/bin/bash
# Run Julia in one of the pinned environments, with the Julia version that environment records:
#
#   benchmarks/paper/julia.sh <envdir> <julia arguments...>
#
# The version is the julia_version entry of <envdir>/Manifest.toml. The default `julia` runs when it is that version,
# else `julia +<version>` (juliaup); either way with --project=<envdir>.
set -eu
ENVDIR=${1:?usage: julia.sh <envdir> <julia arguments...>}; shift
V=$(sed -n 's/^julia_version = "\(.*\)"$/\1/p' "$ENVDIR/Manifest.toml" | head -n 1)
[ -n "$V" ] || { echo "julia.sh: no julia_version in $ENVDIR/Manifest.toml" >&2; exit 2; }
if [ "$(julia --version 2>/dev/null | awk '{print $3}')" = "$V" ]; then
    exec julia --project="$ENVDIR" "$@"
fi
exec julia +"$V" --project="$ENVDIR" "$@"
