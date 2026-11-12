# The manuscript's floats

`tables/*.tex` (the six tables) and `figures/fig_example_degenerate.tex` are the files the manuscript *(γ, φ)-NCL*
`\input`s, byte copies of the manuscript's `tables/` and `figures/` at its Overleaf commit `f240805` (2026-11-12; the
two 41-instance SCOPF tables `tab_gpu_scopf_all` and `tab_scopf_all_appendix` were added at `f240805`, replacing the
separate tables of the 23 reference-list and the 18 protocol instances; `tab_cutest_ma57` (caption, iterations block
commented out, dagger note removed) and `tab_gpu_opf` (placement `[hbp]`) were edited by hand at `498801f`, after the
CUTEst table had been regenerated at `eb4b53d` under the CUTEst population rule, 1060 instances; `tab_pglib_appendix` and
`tab_scopf_config` are unchanged since its commit `6d581d7`; the figure was regenerated at `9254149`, its caption and
panel labels were finalized at `8258bba`, the label of panel (c) was changed at `f5b534b`, the three panel titles
gained their second line at `70d2cd6`, with its bold words set at `b70e85d` and `1bec9fa`, and the steepest-descent
paths were thickened at `cc4c9bd`). The manuscript source `\input`s the two 41-instance tables from commit `da7c3ec` on.

`../reproduce.sh` emits these seven files from the result CSVs and checks the output against the copies here, byte for
byte. They are reference copies only: nothing in this repository writes them. They change only when the manuscript's
floats change, and then they are copied again from the manuscript.
