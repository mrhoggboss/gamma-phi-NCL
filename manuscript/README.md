# The manuscript's floats

`tables/*.tex` (the seven tables) and `figures/fig_example_degenerate.tex` are the files the manuscript *(γ, φ)-NCL*
`\input`s, byte copies of the manuscript's `tables/` and `figures/` at its Overleaf commit `f5b534b` (2026-11-12; the
seven tables are unchanged since its commit `6d581d7`; the figure was regenerated at `9254149`, its caption and panel
labels were finalized at `8258bba`, and the label of panel (c) was changed at `f5b534b`).

`../reproduce.sh` emits these eight files from the result CSVs and checks the output against the copies here, byte for
byte. They are reference copies only: nothing in this repository writes them. They change only when the manuscript's
floats change, and then they are copied again from the manuscript.
