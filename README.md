# (γ, φ)-NCL: A GPU-accelerated nonlinear programming solver

This repository reproduces the five tables of

> *(γ, φ)-NCL: A GPU-compatible General-kernel Algorithm NCL for Large-Scale, Degenerate Nonlinear Programming*

By Yifan Xu and Sungho Shin

## Reproducing the tables

Requirements:

- GNU make, bash and Python 3.
- juliaup, with the Julia version recorded at the top of each environment's `Manifest.toml`.
- A licensed HSL (MA57): the CPU and screen environments load it from `benchmarks/envs/hsl/HSL_jll.jl` (gitignored); put or link your `HSL_jll.jl` there and instantiate all three environments.

```bash
mkdir -p benchmarks/envs/hsl && ln -s <absolute path of your HSL_jll.jl> benchmarks/envs/hsl/HSL_jll.jl
for e in cpu gpu screen; do benchmarks/paper/julia.sh benchmarks/envs/$e -e 'using Pkg; Pkg.instantiate()'; done
```

- An NVIDIA GPU (cuDSS) for `opf` and `scopf`.

```bash
make -C benchmarks [cpu|opf|scopf] [DEVICE=N]
```

reruns every suite in turn, or only the one named (`DEVICE` picks the GPU, default 0), and then emits the tables from the new results (`benchmarks/out/paper/results/`). Before a SCOPF rerun it downloads the network case files, unless they are already present. The GPU chains resume a cell killed part-way from its finished rows.

The instance breakdown of each suite is as follows:

| suite | instances | configurations × repetitions | max_iter | wall cap per solve |
|---|---|---|---|---|
| `cpu` (CUTEst, MA57, 30 workers) | 1060 | 7 × 1 | 3000 | 3600 s |
| `opf` (PGLIB ACOPF, one GPU) | 66 | 5 × 3 | 3000 | 1800 s |
| `scopf` (one GPU) | 41 | 5 × 3 | 3000 | 1800 s |

The wall cap is checked between iterations only; the stall watchdog `benchmarks/paper/watch.sh` ends a solve hung in a factorization. CPU reruns typically reproduce the result CSVs in every column. GPU reruns reproduce them only up to the nondeterminism of cuDSS, as reported in the paper. 

```bash
make -C benchmarks tables
```

emits the five tables from the result CSVs in `benchmarks/results/paper/`. It needs only GNU make, bash and Python 3. Expected output:

```
make: Entering directory '<repository>/benchmarks'
emitting the tables of cutest opf scopf from benchmarks/results/paper
benchmarks/out/paper/tables/tab_cutest_ma57.tex
benchmarks/out/paper/tables/tab_gpu_opf.tex
benchmarks/out/paper/tables/tab_pglib_appendix.tex
benchmarks/out/paper/tables/tab_gpu_scopf_summary.tex
benchmarks/out/paper/tables/tab_scopf_all_appendix.tex
make: Leaving directory '<repository>/benchmarks'
```

| table | label | file | emitter |
|---|---|---|---|
| CUTEst | `tab:cutest` | `tab_cutest_ma57.tex` | `benchmarks/tables/tab_cutest.py` |
| PGLIB ACOPF | `tab:gpu-opf` | `tab_gpu_opf.tex` | `benchmarks/tables/tab_gpu_opf.py` |
| PGLIB ACOPF, per instance (appendix) | `tab:pglib-appendix` | `tab_pglib_appendix.tex` | `benchmarks/tables/tab_pglib_appendix.py` |
| SCOPF | `tab:gpu-scopf` | `tab_gpu_scopf_summary.tex` | `benchmarks/tables/tab_gpu_scopf_summary.py` |
| SCOPF, per instance (appendix) | `tab:scopf-appendix` | `tab_scopf_all_appendix.tex` | `benchmarks/tables/tab_scopf_all_appendix.py` |

## Solver config naming

| tokens | names in the paper | definition |
|---|---|---|
| `S`, `SP`, `W`, `U6A` | MadNCL, MadNCL + parameters, γ-NCL, φ-NCL | `benchmarks/arms.jl` |
| `liftedkkt` | LiftedKKT | `benchmarks/liftedkkt.jl` (GPU), `benchmarks/cutest.jl` (CPU) |
| `ipopt`, `madnlp` | Ipopt, MadNLP-aug | `benchmarks/cutest.jl` (CPU only) |
