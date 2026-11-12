# The manuscript's floats

`tables/*.tex` (the five tables) and `figures/fig_example_degenerate.tex` are the files the manuscript *(γ, φ)-NCL*
`\input`s, byte copies of the manuscript's `tables/` and `figures/` at its Overleaf commit `dd0dd0d` (2026-11-12): the
SCOPF summary table `tab_gpu_scopf_summary` (the 41 instances, the layout of the PGLIB table) replaced the 41-row
`tab_gpu_scopf_all` at `dd0dd0d`; the 41-row appendix `tab_scopf_all_appendix` was added at `f240805` (the 41-instance
tables replaced the separate tables of the 23 reference-list and the 18 protocol instances there, `\input` from
`b912c04` on); the SCOPF configuration table `tab_scopf_config` was dropped at `da30c73`; `tab_cutest_ma57` was
regenerated at `eb4b53d` under the CUTEst population rule (1060 instances) and then edited by hand (caption, iterations
block and dagger note at `498801f`, iterations block deleted at `8c9eb60`, placement `[hbp]` at `46f37ef`, the caption's
iterations sentence removed at `da30c73`); `tab_gpu_opf` got placement `[hbp]` at `498801f` and its new caption at
`c4923de`; `tab_pglib_appendix` is unchanged since `6d581d7`; the figure was regenerated at `9254149`, its caption and
panel labels were finalized at `8258bba`, the label of panel (c) was changed at `f5b534b`, the three panel titles gained
their second line at `70d2cd6`, with its bold words set at `b70e85d` and `1bec9fa`, and the steepest-descent paths were
thickened at `cc4c9bd`. Lines of the `\input`s at `dd0dd0d`: 72 (figure); 824, 835, 843, 861, 862 (tables).

`../reproduce.sh` emits these six files from the result CSVs and checks the output against the copies here, byte for
byte. They are reference copies only: nothing in this repository writes them. They change only when the manuscript's
floats change, and then they are copied again from the manuscript.
