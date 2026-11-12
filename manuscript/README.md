# The manuscript's floats

`tables/*.tex` (the seven tables) and `figures/fig_example_degenerate.tex` are the files the manuscript *(γ, φ)-NCL*
`\input`s, byte copies of the manuscript's `tables/` and `figures/` at its Overleaf commit `1bec9fa` (2026-11-12; the
CUTEst table was regenerated at `eb4b53d` under the CUTEst population rule, 1060 instances; the other six tables are
unchanged since its commit `6d581d7`; the figure was regenerated at `9254149`, its caption and panel labels were
finalized at `8258bba`, the label of panel (c) was changed at `f5b534b`, and the three panel titles gained their second
line at `70d2cd6`, with its bold words set at `b70e85d` and `1bec9fa`).

`../reproduce.sh` emits these eight files from the result CSVs and checks the output against the copies here, byte for
byte. They are reference copies only: nothing in this repository writes them. They change only when the manuscript's
floats change, and then they are copied again from the manuscript.
