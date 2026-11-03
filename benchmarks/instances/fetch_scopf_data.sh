#!/bin/bash
# Fetch the MATPOWER case files of the SCOPF benchmark and verify them against scopf_data.sha256.
#
#   benchmarks/instances/fetch_scopf_data.sh <dest>
#
# Creates <dest>/data (the paper's 8 instances) and <dest>/data_mp70 (the 15 further instances); pass
# --data=<dest> to benchmarks/gpu.jl. Releases (tags of github.com/MATPOWER/matpower):
#   data_mp70/  all seven files from MATPOWER 7.0 (2019-06-21)
#   data/       case118, case1354pegase, case2869pegase, case_ACTIVSg200 from MATPOWER 7.0 (the same files
#               are in every release 7.0 to 8.1), and case300 from MATPOWER 8.1 (2025; it differs from the
#               7.0 file only in the TAP column of 22 transformer branches, which builds the same SCOPF model)
set -eu
DEST=${1:?usage: fetch_scopf_data.sh <dest>}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
URL=https://raw.githubusercontent.com/MATPOWER/matpower
get() {  # get <tag> <file> <dir>
    mkdir -p "$DEST/$3"
    curl -fsSL "$URL/$1/data/$2" -o "$DEST/$3/$2"
}
for f in case118.m case300.m case_ACTIVSg200.m case_ACTIVSg500.m case1354pegase.m case_ACTIVSg2000.m case2869pegase.m; do
    get 7.0 "$f" data_mp70
done
for f in case118.m case_ACTIVSg200.m case1354pegase.m case2869pegase.m; do
    get 7.0 "$f" data
done
get 8.1 case300.m data
(cd "$DEST" && sha256sum -c "$HERE/scopf_data.sha256")
