#!/bin/bash
# Case files of the 18 PGLIB-network SCOPF instances (benchmarks/instances/scopf_pglib18.csv), checked against
# benchmarks/instances/scopf_pglib_data.sha256.
#
#   benchmarks/instances/fetch_pglib_scopf_data.sh <dest>      # then pass --data=<dest> to benchmarks/gpu.jl
#
# Creates <dest>/pglib/ with
#   pglib_opf_case500_goc.m, pglib_opf_case588_sdet.m, pglib_opf_case793_goc.m   PGLIB-OPF v23.07, copied from the PGLib_opf
#                       artifact of benchmarks/Artifacts.toml (git-tree-sha1 0e8968a89b6ad43910a8eda4ec30656add35cf91) when a
#                       Julia depot holds it, else extracted from the v23.07 release tarball (sha256 checked)
#   pglib_opf_<net>_B.m byte copies of the three files: the order-B instances are keyed by their own case name in
#                       benchmarks/instances/scopf_pglib_contingencies.jl, and gpu.jl reads <data>/pglib/<case>.m
#   case118.m           MATPOWER 7.0 data/case118.m (the warm-up solve of gpu.jl: case118 with the first contingency of
#                       its list); copied from <dest>/data/case118.m when fetch_scopf_data.sh has filled <dest>,
#                       else downloaded from github.com/MATPOWER/matpower
set -eu
DEST=${1:?usage: fetch_pglib_scopf_data.sh <dest>}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TREE=0e8968a89b6ad43910a8eda4ec30656add35cf91
TARBALL_URL=https://github.com/power-grid-lib/pglib-opf/archive/refs/tags/v23.07.tar.gz
TARBALL_SHA=f1421ce22f0a7b9de8a8b2111776b496348220192ad24aace392c3bf608706c2
NETS="pglib_opf_case500_goc pglib_opf_case588_sdet pglib_opf_case793_goc"
mkdir -p "$DEST/pglib"

SRC=""
IFS=: read -r -a DEPOTS <<< "${JULIA_DEPOT_PATH:-$HOME/.julia}"
for d in "${DEPOTS[@]}"; do
    [ -n "$d" ] && [ -d "$d/artifacts/$TREE/pglib-opf-23.07" ] && { SRC="$d/artifacts/$TREE/pglib-opf-23.07"; break; }
done
if [ -n "$SRC" ]; then
    echo "PGLIB v23.07 from the Julia artifact $SRC"
    for n in $NETS; do cp "$SRC/$n.m" "$DEST/pglib/$n.m"; done
else
    echo "PGLIB v23.07 artifact not found in ${DEPOTS[*]}: downloading $TARBALL_URL"
    TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
    curl -fsSL "$TARBALL_URL" -o "$TMP/pglib.tar.gz"
    echo "$TARBALL_SHA  $TMP/pglib.tar.gz" | sha256sum -c -
    tar -xzf "$TMP/pglib.tar.gz" -C "$TMP" $(for n in $NETS; do echo "pglib-opf-23.07/$n.m"; done)
    for n in $NETS; do cp "$TMP/pglib-opf-23.07/$n.m" "$DEST/pglib/$n.m"; done
fi
for n in $NETS; do cp "$DEST/pglib/$n.m" "$DEST/pglib/${n}_B.m"; done

if [ -f "$DEST/data/case118.m" ]; then
    cp "$DEST/data/case118.m" "$DEST/pglib/case118.m"
else
    curl -fsSL https://raw.githubusercontent.com/MATPOWER/matpower/7.0/data/case118.m -o "$DEST/pglib/case118.m"
fi
(cd "$DEST" && sha256sum -c "$HERE/scopf_pglib_data.sha256")
