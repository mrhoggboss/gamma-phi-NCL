# (γ,φ)-NCL: code and data of the manuscript

This repository reproduces every number in the five tables and the figure of the manuscript *(γ, φ)-NCL*. It holds
the solver (MadNCL with per-row weights and penalty kernels), the benchmark drivers and the solver configurations, the
campaign's result CSVs with the configuration echo of every run, the emitters that turn those CSVs into the
manuscript's floats, the generation protocol of the protocol SCOPF instances, and the generator of the theory figure.

## One command

```bash
./reproduce.sh
```

emits the five tables and the figure from the campaign's results (`benchmarks/results/paper/`), compiles each at the
manuscript's page geometry, and compares each byte for byte with the file the manuscript `\input`s (`manuscript/`):
one line per float, `IDENTICAL`, or `DIFFERS` followed by the first lines of the diff; the exit status is 0 only if all
six are identical. It takes about a minute, runs from any directory, and writes only under `benchmarks/out/paper/`
(gitignored; `PAPER_OUT=<dir>` moves it). Requirements: bash, Python 3 (standard library only), and `pdflatex` (with
booktabs, longtable, geometry, tikz) and `pdfinfo` for the compile check; on a machine without TeX,
`REPRO_NOCOMPILE=1 ./reproduce.sh` skips the compile check and still compares. Output (2026-11-12):

```
IDENTICAL  tab_cutest_ma57
IDENTICAL  tab_gpu_opf
IDENTICAL  tab_pglib_appendix
IDENTICAL  tab_gpu_scopf_summary
IDENTICAL  tab_scopf_all_appendix
IDENTICAL  fig_example_degenerate
reproduce.sh: all 6 floats IDENTICAL to manuscript/
```

```bash
./reproduce.sh rerun all --device 0
```

reruns every solve behind the tables (`rerun cpu`, `opf`, `scopf` or `scopf_pglib` runs one suite; `--device N` picks
the GPU, default 0), fetching the SCOPF case files first when their sha256 check does not already pass, then emits
from the rerun's results (`benchmarks/out/paper/results/`) and compares with `manuscript/` in the same way (the SCOPF
tables cover both SCOPF suites; a suite not rerun is read from the banked results). It needs
the Julia environments of "Hardware and software" below, a licensed HSL MA57 for the CPU suite and a CUDA GPU for the
others. Compute, from the campaign's logs: CUTEst 20.6 h at 30 workers for six of the seven configurations, plus SP
(its per-solve times sum to 0.96 h of 30 workers, a lower bound); PGLIB 4.0 h; SCOPF on the reference networks 21.7 h
(plus 13.1 GPU-hours for the 2026-11-13 rerun of the 12 instances whose lists were regenerated, 7.0 h on two devices);
the protocol SCOPF set 4518–5887 s per (configuration, repetition), 15 of them, in the campaign's one-instance-per-process
mode (solve and build alone 515–1562 s per (configuration, repetition)); the GPU suites on one device. A CPU rerun is
expected to reproduce the result CSVs in every column but the timing columns, so its table is expected to be
identical; a GPU rerun matches only within the GPU nondeterminism band described below, so the comparison is
informational there and the exit status is that of the emit.

| manuscript float | label | file the manuscript `\input`s | emitter |
|---|---|---|---|
| CUTEst table | `tab:cutest` | `tables/tab_cutest_ma57.tex` | `benchmarks/tables/tab_cutest.py` |
| PGLIB table | `tab:gpu-opf` | `tables/tab_gpu_opf.tex` | `benchmarks/tables/tab_gpu_opf.py` |
| PGLIB appendix | `tab:pglib-appendix` | `tables/tab_pglib_appendix.tex` | `benchmarks/tables/tab_pglib_appendix.py` |
| SCOPF, the 41 instances | `tab:gpu-scopf` | `tables/tab_gpu_scopf_summary.tex` | `benchmarks/tables/tab_gpu_scopf_summary.py` |
| SCOPF appendix, the 41 instances | `tab:scopf-appendix` | `tables/tab_scopf_all_appendix.tex` | `benchmarks/tables/tab_scopf_all_appendix.py` |
| Figure 1, in the Introduction | `fig:example-degenerate` | `figures/fig_example_degenerate.tex` | `benchmarks/figures/make_fig_example_degenerate.py` |

The manuscript `\input`s all five tables and the figure (checked 2026-11-13 against its Overleaf commit `4f65d06`: line
67 of the manuscript's source for the figure, lines 801, 812, 842, 855 and 856 for the tables); `manuscript/` holds those six files. The
41 SCOPF instances are the 23 instances of the seven reference networks and the 18 of the three PGLIB networks. Not emitted by `emit.sh`, because
they are no longer floats of the manuscript: the 41-row SCOPF table (`tab_gpu_scopf_all.py`; its module also supplies
the loader of the appendix and summary emitters) and the separate tables of the two sets (`tab_gpu_scopf.py`,
`tab_gpu_scopf_pglib.py`, `tab_scopf_pglib_appendix.py`). The scripts remain and can be run by hand; `tab_gpu_scopf_all.py`
and `tab_gpu_scopf.py` write the label `tab:gpu-scopf` too, so their output must never be `\input` next to
`tab_gpu_scopf_summary.tex`.

## What "reproduced" means here

The result CSVs under `benchmarks/results/paper/` are the campaign's, copied verbatim (rows, header and column order as
the drivers wrote them), with the configuration echo of every cell next to them. The emitters turn them into the floats:

```bash
benchmarks/paper/emit.sh        # all five tables and the figure, ~45 s; writes benchmarks/out/paper/{tables,figures,summaries}
```

That command writes exactly the six files above, every one of them compiles at the manuscript's page geometry
(`lib.sh compile_tables`; its scaffolding goes to `benchmarks/out/paper/compile/`), all six are byte-identical to the
manuscript's files (`manuscript/`, Overleaf commit `4f65d06`; `./reproduce.sh` makes that comparison), and the console
summaries `cutest.txt`, `opf.txt`, `scopf.txt` and `scopf_pglib.txt` equal the banked
`benchmarks/results/paper/<suite>/summary.txt` (checked 2026-11-12; the CUTEst summary was rewritten that day under
the population rule); `scopf_all.txt` summarizes the 41 SCOPF instances (solved counts, nesting of the solved sets,
instances solved by exactly one configuration and by none, co-solved cost ratios over all 41 and for K ≤ 16 and
K ≥ 32).

Rerunning the solves reproduces the CSVs **bitwise on the CPU** in every column but the timing columns (the CPU solvers
are deterministic; a solve that ends at its wall-time cap can stop at a different iteration) and **to within GPU
nondeterminism on the GPU, ±2 solves**: cuDSS's device reductions are not bitwise reproducible, so single repetitions
differ (spread of the per-repetition solve counts in the banked data, `benchmarks/results/paper/<suite>/summary.txt`:
PGLIB at most 2 per configuration, SCOPF reference networks up to 5 (MadNCL 9/6/4, MadNCL + parameters 7/12/8),
protocol set up to 4, between r1 and r2 of φ-NCL);
every GPU suite is therefore run three times and scored by majority of three, and the manuscript makes no robustness
claim about GPU solve-count differences of two instances or fewer (Section 5, "Budgets and scoring"). The CPU claim was checked on the protocol records (one K = 1 verification and two screened outages,
identical but for their time columns, and the island table, byte-identical) and on the CUTEst smoke run of the CUTEst
section below (32 rows); the full CUTEst table and the GPU suites were not rerun.

## Hardware and software of the campaign

- 2 x Intel Xeon Gold 6130 (2 x 16 cores, 64 threads), 2 x NVIDIA Quadro GV100 (32 GB, compute capability 7.0),
  NVIDIA driver 580.178.04 / CUDA 13.0 at build time; CUTEst runs used 30 Distributed workers, the GPU
  suites one device per cell.
- CPU: Julia 1.10.11, `benchmarks/envs/cpu` (MadNLP 0.10.1, MadNLPHSL 0.7.3, CUTEst.jl 1.4.0 with its SIF collection
  artifact, NLPModelsIpopt 0.11.3 / Ipopt 3.14.19), **HSL MA57 from a licensed HSL_jll** (2025.1.19).
- GPU: Julia 1.11.2, `benchmarks/envs/gpu` (CUDA.jl 6.2.0, **cuDSS** via CUDSS.jl 0.7.0 / CUDSS_jll 0.7.1, MadNLPGPU
  0.10.1, ExaModels 0.11.2, JuMP 1.30.1, PowerModels 0.21.6).
- SCOPF protocol scripts: Julia 1.10.11, `benchmarks/envs/screen` (adds PowerModels 0.21.6, JuMP 1.32.1, Ipopt 1.16.0).
- Emitters and the figure: Python 3 (standard library only); `pdflatex` and `pdfinfo` for the compile check.

Setup: `julia --project=benchmarks/envs/cpu -e 'using Pkg; Pkg.instantiate()'`, the same for `envs/screen` and, with
`julia +1.11.2`, `envs/gpu`. Every env takes MadNCL from this checkout (`path = "../../.."`). The CPU and screen
Manifests record the path of our licensed HSL_jll; `Pkg.develop(path="<your HSL_jll.jl>")` in those two envs, and check
that `filesize(HSL_jll.libhsl_path)` is megabytes (the registry HSL_jll is a stub).

## Table `tab:cutest` — CUTEst on the CPU

- Data: the 1070 constrained CUTEst problems of `benchmarks/instances/cutest_pop1070.txt`, fetched and decoded by
  CUTEst.jl (the driver decodes missing ones before the run). Every configuration is run on all 1070.
- Population rule (2026-11-12): an instance is excluded when its objective gradient, its constraint values or its
  constraint Jacobian is not finite at the starting point CUTEst provides (x0 as given, not projected into the
  bounds), which makes the comparison between the interior-point baselines and the augmented-Lagrangian
  configurations fair (Yifan, 2026-11-12): the four augmented-Lagrangian configurations stop on 9 of these instances
  with `InvalidNumberException` (:grad, :cons or :jac) before any iteration, whereas LiftedKKT solves 5 of those 9,
  MadNLP-aug 4 and Ipopt 3; all seven configurations solve the tenth, LIN. The census
  `benchmarks/instances/cutest_x0_census.csv` (f, grad f, c, J and the bound check at x0 for all 1070, written by
  `julia --project=benchmarks/envs/cpu benchmarks/cutest_x0_census.jl`) defines the 10 excluded
  instances of `benchmarks/instances/cutest_excluded_x0.txt`: DITTERT, LHAIFAM, LIN, NET2, NET3, NET4, S365, S365MOD,
  STEENBRD, STEENBRE (6 in the regular tier, 4 in the other m > n class; none has m_eq > n). The emitters
  (`benchmarks/tables/common.py`, `cutest_excluded`) drop every configuration's rows of those instances, baselines
  included, before scoring, so the table and the summary score **1060** instances (709 regular, 179 with
  m_eq > n, 172 other m > n); the result CSVs keep all 1070 rows.
- Run (all seven configurations: S, SP, W, U6A, liftedkkt, ipopt, madnlp; MA57, 30 workers, 3600 s per solve):

  ```bash
  benchmarks/paper/chain_cpu.sh                       # or one configuration:
  julia --project=benchmarks/envs/cpu benchmarks/cutest.jl benchmarks/instances/cutest_pop1070.txt W ma57 30 3600 benchmarks/out/paper/cutest/W_r1 --trace
  ```

  Campaign elapsed per configuration at 30 workers: S 2.4 h, W 1.7 h, U6A 3.6 h, LiftedKKT 5.1 h, Ipopt 3.6 h,
  MadNLP-aug 4.3 h (the campaign's `WALLTIME_cpu.csv`, see Provenance); SP's logged elapsed covers only a 60-s
  resume, and its
  per-solve times sum to 103 489 s (0.96 h of 30 workers, a lower bound). 20.6 h for the six others.
- Smoke run: the first N names of `benchmarks/instances/cutest_pop1070.txt`, e.g. with N = 8, four configurations and
  8 workers:

  ```bash
  head -n 8 benchmarks/instances/cutest_pop1070.txt > benchmarks/out/smoke8.txt
  julia --project=benchmarks/envs/cpu benchmarks/cutest.jl benchmarks/out/smoke8.txt W,U6A,S,SP ma57 8 3600 benchmarks/out/smoke
  ```

  Checked 2026-11-11: 79 s, and all 32 rows equal the banked rows of `benchmarks/results/paper/cutest/` in every column
  but the time column.
- Emit: `benchmarks/paper/emit.sh cutest`, or
  `python3 benchmarks/tables/tab_cutest.py benchmarks/results/paper/cutest --cap=3600 --out=<dir>` (seconds).

## Tables `tab:gpu-opf` and `tab:pglib-appendix` — PGLIB on the GPU

- Data: the 66 PGLIB v23.07 cases of `benchmarks/instances/pglib66.txt`, from the `PGLib_opf` artifact of
  `benchmarks/Artifacts.toml` (downloaded on first use).
- Run (five configurations x three repetitions, 1000 iterations, 1800 s per solve):

  ```bash
  benchmarks/paper/chain_gpu.sh <device> opf          # 15 cells; one cell is:
  julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl opf W benchmarks/out/paper/opf/W_r1 --tag=r1 --trace
  ```

  Campaign elapsed per cell 720–1441 s, 4.0 h for the 15 (`WALLTIME_gpu1.csv`, last attempt of each cell).
- Emit: `benchmarks/paper/emit.sh opf` (`tab_gpu_opf.py`, `tab_pglib_appendix.py`; seconds). The appendix table lists,
  per configuration and repetition, the factorization count of a solve or the reason for the non-solve (an italic word:
  infeas. = local infeasibility declared, max it. = iteration limit, wall = wall-time limit, restor. = restoration
  failed, step = step too small, error = evaluation or other error); no iteration or wall-time columns; landscape pages,
  `\footnotesize` with `\tabcolsep` 2.5pt (the largest size at which both appendix tables fit the text width). Footer:
  the solved count of every repetition ("solved (of N)") and, as the last row, the cost of the summary table
  ("factorizations (geom. mean)": the geometric mean over the majority-solved instances of the median factorization
  count of the succeeding repetitions), both labels spanning the identifier columns.
- Derived record: `benchmarks/results/paper/opf/derived_sp_losses.csv` lists, for the eight cases MadNCL + parameters
  loses against MadNCL, each repetition's status, outer-iteration count, final penalty ρ and final dual residual
  (`dual_feas`); ρ comes from the campaign's per-outer traces, which are not in this repository
  (`derived_sp_losses_SOURCE.txt` gives their sha256 and the derivation).

## SCOPF runs: the 23 instances of the reference networks

- Data: the MATPOWER case files, downloaded and checked against `benchmarks/instances/scopf_data.sha256`:
  `benchmarks/instances/fetch_scopf_data.sh <dir>` (`<dir>/data`, `<dir>/data_mp70`); the instance list is
  `benchmarks/instances/scopf23.csv`, the contingency lists `benchmarks/instances/scopf_contingencies.jl`. All 41 SCOPF
  instances are protocol-generated (`benchmarks/scopf_protocol/README.md`): on the seven reference networks the
  protocol's screening step reproduces the reference benchmark's published lists exactly for `case118`, `case300`,
  `case_ACTIVSg200` and `case2869pegase`, and the lists of `case_ACTIVSg500`, `case1354pegase` and `case_ACTIVSg2000` are
  the protocol's own (regenerated on 2026-11-13, `benchmarks/scopf_protocol/reference_regen.py lists`; the published
  lists are kept in `benchmarks/instances/scopf_contingencies_published.jl`); the 18 instances of the three PGLIB
  networks are described below.
- Run (five configurations x three repetitions, 3000 iterations, 1800 s per solve; the SCOPF model and solver settings
  of every cell are in its configuration echo, `benchmarks/results/paper/scopf/config_scopf__<config>__r<k>.txt`):

  ```bash
  SCOPF_DATA=<dir> benchmarks/paper/chain_gpu.sh <device> scopf     # 15 cells; one cell is:
  julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl scopf W benchmarks/out/paper/scopf/W_r1 --tag=r1 --trace --data=<dir>
  ```

  Campaign elapsed per cell 3182–7804 s, 21.7 h for the 15 (`WALLTIME_scopf.csv`). The 12 instances whose lists were
  regenerated (ACTIVSg500 K = 8 … 100, 1354pegase K = 8, 16, 32, ACTIVSg2000 K = 8, 16) were rerun with the same command
  restricted to them (`--instances=`), 15 cells of 1801–4143 s on two devices, 2026-11-12/13; their rows replace the
  campaign's (`benchmarks/results/paper/scopf/SOURCE.txt`), and the campaign's runs of them on the published lists are
  kept in `benchmarks/results/paper/scopf_published/`.
- Emit: the SCOPF tables below (`emit.sh scopf`).

## SCOPF runs: the 18 protocol instances

- Data: `benchmarks/instances/fetch_pglib_scopf_data.sh <dir>` writes `<dir>/pglib/` (the three PGLIB v23.07 networks
  from the Julia artifact or the release tarball, their `_B` copies for the order-B instances, MATPOWER 7.0
  `case118.m` for the warm-up) and checks it against `benchmarks/instances/scopf_pglib_data.sha256` (seconds).
- Instances: `benchmarks/instances/scopf_pglib18.csv` and `benchmarks/instances/scopf_pglib_contingencies.jl`, generated
  by the protocol of `benchmarks/scopf_protocol/README.md` (screen at penalty 1e8, residual < 1e-4 after at most 200
  iterations, bridges kept; island rule; K = 1 verification by Ipopt-MA57; drop and backfill; orders A and B with seed
  69; K ∈ {4, 8, 16}). Rebuild the lists from the protocol records in seconds:
  `python3 benchmarks/scopf_protocol/build_lists.py lists --check=benchmarks/instances/scopf_pglib_contingencies.jl`.
- Run (five configurations x three repetitions, the SCOPF settings of the 23):

  ```bash
  SCOPF_PGLIB_DATA=<dir> benchmarks/paper/chain_gpu.sh <device> scopf_pglib    # 15 cells; one cell is:
  julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl scopf W benchmarks/out/paper/scopf_pglib/W_r1 --tag=r1 --trace \
      --instances=benchmarks/instances/scopf_pglib18.csv --data=<dir> --contingencies=benchmarks/instances/scopf_pglib_contingencies.jl
  ```

  The campaign ran one instance per process (`--cases=<instance>` added): 240–481 s per instance (median 300 s) with
  start-up and warm-up, 4518–5887 s per complete (configuration, repetition); the solve and build times alone sum to
  515–1562 s per complete (configuration, repetition).
- Emit: the SCOPF tables below (`emit.sh scopf`).
- **Data.** `benchmarks/results/paper/scopf_pglib/` holds all three repetitions of all 18 instances for the five
  configurations (270 rows, 270 configuration echoes); `benchmarks/results/paper/scopf_pglib/SOURCE.txt` records
  their source (see Provenance).

## Tables `tab:gpu-scopf` and `tab:scopf-appendix` — SCOPF, the 41 instances

`benchmarks/paper/emit.sh scopf` (seconds) writes the two SCOPF floats over the 41 instances (the 23 of the reference
networks and the 18 of the PGLIB networks), from both result sets with the scoring of the other GPU tables (majority of three, medians
over the succeeding repetitions, LiftedKKT within constr_viol_tol): `tab_gpu_scopf_summary.tex`
(`tab_gpu_scopf_summary.py`, label `tab:gpu-scopf`; the layout of the PGLIB table: per configuration the solved count of
each repetition, the majority count and the geometric mean of factorizations) and `tab_scopf_all_appendix.tex`
(`tab_scopf_all_appendix.py`, label `tab:scopf-appendix`, landscape; one row per instance, the reference networks and
then the protocol networks, K increasing, with no rule between them; per configuration and repetition the
factorization count of a solve or the reason for the non-solve, with the words, type size, column separation and
footer rows of the PGLIB appendix). It also writes the summaries `scopf.txt`, `scopf_pglib.txt` (each
set alone) and `scopf_all.txt` (the 41, `summary_scopf_all.py`). The result directories are `benchmarks/results/paper/scopf/` and `benchmarks/results/paper/scopf_pglib/`
(`SCOPF_RES=<dir>` and `SCOPF_PGLIB_RES=<dir>` override either).

## The published-list runs (kept for reference; not a manuscript float)

On 2026-11-13 the contingency lists of `case_ACTIVSg500`, `case1354pegase` and `case_ACTIVSg2000`, which the protocol's
screen does not reproduce, were replaced by their protocol lists (`benchmarks/scopf_protocol/reference_regen.py lists`;
the published file is kept as `benchmarks/instances/scopf_contingencies_published.jl`). The campaign's runs of the 12
instances whose list changed (ACTIVSg500 K = 8 … 100, 1354pegase K = 8, 16, 32, ACTIVSg2000 K = 8, 16;
`benchmarks/instances/scopf_published12.csv`) are kept as a dataset, `benchmarks/results/paper/scopf_published/` (their
rows byte-copied from the banked `scopf/` CSVs, with their configuration echoes; `SOURCE.txt`). `emit.sh scopf_published`
writes their per-repetition table `tab_scopf_published_appendix.tex` (the layout of the SCOPF appendix; draft caption;
`--from=benchmarks/results/paper/scopf --plus=case_ACTIVSg500_nK4` adds the K = 4 instance, whose list is the same
under both) and the summary `scopf_published.txt`; `./reproduce.sh rerun scopf_published` reruns them (the campaign
settings, `--contingencies=benchmarks/instances/scopf_contingencies_published.jl`). The table is not in `manuscript/`
and `./reproduce.sh` does not compare it.

## Figure `fig:example-degenerate`

```bash
python3 benchmarks/figures/make_fig_example_degenerate.py --out=<dir>     # ~20 s; or benchmarks/paper/emit.sh figure
```

Plain Python (standard library). Writes `<dir>/fig_example_degenerate.tex` (TikZ; needs `\usetikzlibrary{shapes.geometric,
arrows.meta}`), byte-identical to the manuscript's `figures/fig_example_degenerate.tex` (sha256 `93b35494…5aa68`). The
instance is c1(x) = x1² − x2² − 4 = 0, c2(x) = x1 − 4 = 0 with no objective; the three panels draw the level sets of the
selected merit for (γ, p) = ((1, 1), 2), ((1, 4), 2) and ((1, 1), 6), its stationary points, the basin boundary of the
spurious minimizer and two steepest-descent paths (the generator's docstring has the details).

## Rerunning everything and comparing

Every chain writes under `benchmarks/out/paper/` and never into the banked `benchmarks/results/paper/`: each finished
cell's CSV and configuration echo is copied, under the banked file names, into `benchmarks/out/paper/results/<suite>/`.
Emit from the rerun with `RES=benchmarks/out/paper/results benchmarks/paper/emit.sh <suite>`
(`./reproduce.sh rerun <suite>` runs the chain, this emit and the comparison with `manuscript/`). The chains are
resumable (a cell killed part-way resumes from its finished rows), refuse a GPU that carries another process unless
`GPU_DEVICE_NOGATE=1`, and log every foreign process seen on the device during a cell (`INTRUDER` lines; wall times of
such cells are contaminated, solve counts are not).

## The solver configurations

| token | paper name | definition |
|---|---|---|
| `S` | MadNCL | `benchmarks/arms.jl` |
| `SP` | MadNCL + parameters | `benchmarks/arms.jl` |
| `W` | γ-NCL | `benchmarks/arms.jl` |
| `U6A` | φ-NCL | `benchmarks/arms.jl` |
| `liftedkkt` | LiftedKKT | `benchmarks/liftedkkt.jl` (GPU), `benchmarks/cutest.jl` (CPU) |
| `ipopt` | Ipopt | `benchmarks/cutest.jl` (CPU only) |
| `madnlp` | MadNLP-aug | `benchmarks/cutest.jl` (CPU only) |

All configurations use the tolerance `1e-8` and the gradient scaling `scaling_max_gradient=100`.
With `μ* = (1e-8/100)^(1/1.05) ≈ 2.9936e-10`:

```julia
using MadNCL, MadNLP
μstar = (1e-8 / 100)^(1 / 1.05)

# MadNCL: MadNCL's own constants (ρ_max = 1e12, 20 outer iterations, μ_min = 1e-9,
# extrapolation step on); the dual-regularization fold of K2r/K1s is switched off.
S = MadNCL.NCLOptions{Float64}(opt_tol=1e-8, feas_tol=1e-8, scaling_max_gradient=100.0,
                               fold_dual_regularization=false)

# MadNCL + parameters: MadNCL with the constants of the two proposed methods (ρ_max, μ_min, K_max), and MadNLP's acceptable-level exit
# disabled (pass acceptable_tol=0.0 to madncl, as below).
SP = MadNCL.NCLOptions{Float64}(opt_tol=1e-8, feas_tol=1e-8, scaling_max_gradient=100.0,
                                mu_min=μstar, max_auglag_iter=40, rho_max=1e14,
                                fold_dual_regularization=false)

# γ-NCL: weight law, force gate (with the quadratic kernel: maxᵢ γᵢ |rᵢ| ≤ thr), no extrapolation step,
# acceptable-level exit disabled.
frozen = (opt_tol=1e-8, feas_tol=1e-8, scaling_max_gradient=100.0, mu_min=μstar,
          max_auglag_iter=40, rho_max=1e14, extrapolation=false)
W = MadNCL.NCLOptions{Float64}(; frozen..., weight_law=:geometry, weight_clip=(1e-30, 1e8),
                               weight_anneal_horizon=6.0, gate_metric=:force)
madncl(nlp; ncl_options=W, kkt_system=MadNCL.K2rAuglagKKTSystem, acceptable_tol=0.0)

# φ-NCL: power kernel with p = 6 and λ ≡ 1e-2 on every row, unit weights, residual gate,
# and MadNLP's acceptable-level exit disabled.
P = MadNCL.NCLOptions{Float64}(; frozen...)
madncl(nlp; ncl_options=P, kernel=MadNCL.PowerKernel(6.0, 1e-2),
       kkt_system=MadNCL.K2rAuglagKKTSystem, acceptable_tol=0.0)
```

Only S keeps MadNLP's acceptable-level inner exit (`acceptable_tol = 1e-6`, the upstream default). SP, γ-NCL (W),
φ-NCL (U6A) and the LiftedKKT comparator run with `acceptable_tol = 0`, so that no inner solve stops short
of its budget at the looser tolerance (`benchmarks/arms.jl`, `benchmarks/liftedkkt.jl`).

One known label difference with the released MadNCL package: when the success test passes at the last
allowed outer iteration (`max_auglag_iter`), the released package overwrites the status with
`MAXIMUM_ITERATIONS_EXCEEDED`, while this repository's solver reports `SOLVE_SUCCEEDED`. The iterate is the same; only the
label differs. With S (20 outer iterations) this matters on runs that converge exactly at outer 20; on the
SCOPF benchmark it relabels two runs (case_ACTIVSg200 with 50 contingencies, repetition 1, and case300 with 100
contingencies, repetition 3); the first removes ACTIVSg200@50 from MadNCL's majority-solved set (6 would become 5 of
41). None of the protocol or PGLIB runs is affected. On CUTEst it relabels GAUSSELM and ORTHRDS2C (767 would become
765). (The runs are those of S with `SOLVE_SUCCEEDED` and `n_outer` = 20 in the banked CSVs; the released package
overwrites the status when the loop ends at `iter >= max_auglag_iter`.)

The success test is the same for every configuration: the returned primal-dual pair must satisfy
the KKT conditions of the problem solved by the interior-point method, with the complementarity
measured at μ = 0 and the multipliers scaled as in Ipopt (`s_max = 100`), and the constraint
violation in the original scaling must not exceed `constr_viol_tol` (see `MadNCL.NCLOptions`).

The drivers print the full option set of every configuration, read back from the constructed solver, into the
configuration echoes (`config_*.txt`) next to the results (a SCOPF configuration table, `tab_scopf_config`, was emitted
from them until the manuscript dropped it at Overleaf `da30c73`; its emitter was removed). Two banked
echoes of γ-NCL, `benchmarks/results/paper/cutest/config_W.txt` and `benchmarks/results/paper/scopf/config_scopf__W__r1.txt`,
carry the configuration's older label `((γ,φ)-MadNCL)` where a fresh echo prints `(γ-NCL)`: a label difference only,
every option value is identical (checked on the CUTEst smoke run, and between the r1 and r2 echoes of `scopf`).
Likewise the r1 echoes of φ-NCL in `opf/` and `scopf/` (`config_opf__U6A__r1.txt`, `config_scopf__U6A__r1.txt`) carry
the older label `(power-kernel cell (p = 6, λ = 1e-2))` where a fresh echo prints `(φ-NCL)`; every option value is
identical to their r2 echoes (only the tag and the warm-up time differ).

## Layout

| path | contents |
|---|---|
| `reproduce.sh` | the one command: emit every float and compare it with `manuscript/`; `rerun <suite>` reruns the solves first |
| `manuscript/` | the five tables and the figure as the manuscript `\input`s them (Overleaf commit `4f65d06`), the reference of `reproduce.sh` |
| `src/`, `ext/` | the solver (MadNCL with per-row weights and penalty kernels) |
| `benchmarks/arms.jl`, `liftedkkt.jl`, `common.jl` | the configurations and shared driver helpers |
| `benchmarks/cutest.jl`, `benchmarks/gpu.jl` | the CPU (CUTEst) and GPU (`opf`, `scopf`) drivers; they take paths, devices and tags as arguments and read no environment variables |
| `benchmarks/models/` | the AC-OPF model (ExaModels) and the SCOPF-as-MPCC model (JuMP + PowerModels; from the MadNCL paper's harness and github.com/frapac/pscc-scopf) |
| `benchmarks/instances/` | instance lists (CUTEst 1070, its certified traps, used by the CUTEst summary, and its x0 census and the population rule's 10 exclusions; PGLIB 66; SCOPF 23 and 18, and the 12 instances of the published-list runs), contingency lists (the lists in use, and the reference benchmark's lists as published), data fetch scripts and sha256 manifests |
| `benchmarks/scopf_protocol/` | the generation protocol of the 18 protocol SCOPF instances: scripts, records, list builder |
| `benchmarks/tables/`, `benchmarks/figures/` | the emitters (Python, standard library only) |
| `benchmarks/paper/` | `chain_cpu.sh`, `chain_gpu.sh`, `emit.sh`, their shared `lib.sh`, `watch.sh` (stall watchdog), `gpu_device.sh` (device gate) |
| `benchmarks/results/paper/` | the campaign's result CSVs, configuration echoes and summaries (`cutest`, `opf`, `scopf`, `scopf_pglib`; `scopf_published`, the published-list runs kept for reference) |
| `benchmarks/envs/{cpu,gpu,screen}` | the pinned environments |
| `test/` | the package's unit tests (`julia --project=. -e 'using Pkg; Pkg.test()'`) |

## Citing MadNCL.jl

```bibtex
@article{MadNCL,
  title   = {{MadNCL: A GPU Implementation of Algorithm NCL for Large-Scale, Degenerate Nonlinear Programs}},
  author  = {Alexis Montoison and François Pacaud and Michael Saunders and Sungho Shin and Dominique Orban},
  journal = {arXiv preprint arXiv:2510.05885},
  year    = {2025},
}
```

## Provenance

- This repository was cut from the authors' research repository: the public MadNCL harness of its branch
  `gamma-phi-ncl` (commit `3383a34`), with the protocol SCOPF set ported from the branch that generated it
  (`scopf-pool`), the theory figure's generator added, and everything else removed (COPS and the COPS size ladder, the
  ablation and one-sided configurations, the identity gates, the campaign scheduler). The solver source `src/` and
  `ext/` is byte-identical to `gamma-phi-ncl` (`src/` unchanged since `10238f9`).
- `benchmarks/results/paper/{cutest,opf,scopf}/` are the campaign's results as banked on `gamma-phi-ncl`: every file is
  identical to its counterpart there (whose directories also hold the removed configurations' files), except that in
  `scopf/` the rows of the 12 instances whose contingency lists were regenerated come from the rerun of 2026-11-12/13 on
  `gamma-phi-ncl` (HEAD `f20e8d5`; `scopf/SOURCE.txt`), and the summary is rewritten accordingly; the campaign's rows of
  those instances are in `scopf_published/`.
  `benchmarks/results/paper/scopf_pglib/` was copied from `scopf-pool` (`results/pilot` as committed at `76a53fe`)
  after the protocol block ended on 2026-11-11; its rows and echoes are identical to those banked on `gamma-phi-ncl`
  (commit `835508a`); `SOURCE.txt` there lists every source file with its sha256.
- The campaign's per-cell elapsed-time logs quoted above (`WALLTIME_cpu.csv`, `WALLTIME_gpu1.csv`,
  `WALLTIME_scopf.csv`) are in `gamma-phi-ncl`'s uncommitted `benchmarks/out/paper/logs/`, not in this repository.
- The two γ-NCL echoes with the label `((γ,φ)-MadNCL)` and the two φ-NCL r1 echoes with the label `(power-kernel cell
  (p = 6, λ = 1e-2))` predate the renaming of the configurations' paper names on `gamma-phi-ncl`.
- Internal labels that appear in the protocol records and their SOURCE files: `WO-69` (with its Addendum and gate
  sub-labels) is the campaign's internal name of the protocol work; `S0′` is its comparison of the full reference
  screens (`benchmarks/scopf_protocol/records/reference_screens/`); `C3` is the K = 1 check at 3000 iterations / 600 s
  (`records/k1/c3_3000it_600s/`), and `C3b` its re-run of the wall-capped outages at 10000 iterations / 3600 s; the
  "factorial block" is the ×3 runs of the 18 protocol instances (`benchmarks/results/paper/scopf_pglib/`);
  `scopf_pilot_factorial18.csv` is `scopf-pool`'s name for `benchmarks/instances/scopf_pglib18.csv`.
- Earlier checks of the emitted floats: the five tables and the figure that the manuscript `\input`ed at its Overleaf
  commit `e55ef05` were byte-identical to its files, and the two protocol-set tables, not yet `\input` there, were
  byte-identical to the `gamma-phi-ncl` emissions; at Overleaf commit `6d581d7` all eight were byte-identical
  (2026-11-11). At Overleaf commit `9254149` the example moved to the introduction as a regular instance and the figure
  was regenerated (its generator replaced this repository's); at Overleaf commit `8258bba` the figure's caption and
  panel labels are Yifan's final wording (carried into the generator), and at `f5b534b` the label of panel (c) reads
  φ(t) = t²/2 + t⁶/6 (drawing unchanged); at `eb4b53d` the CUTEst table is the 1060-instance table of the population
  rule; at `70d2cd6` the three panel titles gained a second line ("Classical ALM", "Ours, custom weights", "Ours, custom
  kernel"), set in bold at `b70e85d` ("Ours" of panel (c)) and `1bec9fa` ("Classical ALM", "Ours" of panel (b)), as
  carried into the generator (drawing unchanged); at `cc4c9bd` the steepest-descent paths are thicker (line width 1.1 pt,
  arrow tips 4.5 pt, start dots 1.4 pt; Yifan: "thicken the trajectory"); at `498801f` Yifan edited two tables by hand
  (`tab_cutest_ma57`: new caption, the iterations block commented out, the dagger note after the tabular removed;
  `tab_gpu_opf`: float placement `[hbp]`), carried into `tab_cutest.py` and `tab_gpu_opf.py` byte for byte; at
  `f240805` the two 41-instance SCOPF tables replace the three separate tables of the 23 and the 18 (`tab_gpu_scopf`,
  `tab_gpu_scopf_pglib`, `tab_scopf_pglib_appendix`), and the source `\input`s them from `b912c04` on; at `8c9eb60` the
  commented-out iterations block of `tab_cutest_ma57` is deleted, at `46f37ef` its float placement becomes `[hbp]`, and
  at `da30c73` its caption loses the iterations sentence (Yifan: "we never measure iterations, so we remove it; the
  dagger note is moved to the caption"), all carried into `tab_cutest.py`; at `da30c73` the SCOPF configuration table
  `tab_scopf_config` also left the manuscript (its emitter was removed); at `c4923de` the PGLIB caption is Yifan's new
  wording (carried into `tab_gpu_opf.py`); at `dd0dd0d` the summary table `tab_gpu_scopf_summary` (the layout of the PGLIB
  table) replaces the 41-row `tab_gpu_scopf_all` as `tab:gpu-scopf`; at `0eae8ef` the two appendix tables and the SCOPF
  summary get Yifan's final captions, at `7e9363f` the appendix tables list per repetition the factorization count or
  the reason for the non-solve, with no iteration, wall-time or median columns (Yifan: "we do not use walltime anymore"),
  and at `4500ec4` they end with the geometric-mean factorization row of the summary tables; at `da372e8` the five
  tables carry the roster name "MadNLP-aug" and the relaxation written `$\varepsilon=10^{-8}$` (label lines only;
  `common.NAMES`/`NAMES2`); at `0d73736` the captions of `tab_gpu_opf`, `tab_gpu_scopf_summary` and
  `tab_scopf_all_appendix` use the acronyms OPF and SCOPF ("PGLIB OPF instances", "SCOPF instances", "SCOPF problems
  formulated as MPCCs"), carried into their emitters; `f2e9695` changes only the manuscript's source and bibliography
  (the floats are byte-unchanged); at `0e5d6bc` the PGLIB caption reads "PGLIB ACOPF instances" (OPF unified to ACOPF;
  carried into `tab_gpu_opf.py`); `4f65d06` inserts the list-generation algorithm (`alg:screen`) into the source (the
  floats are byte-unchanged); all six floats are byte-identical (`manuscript/`, Overleaf `4f65d06`, 2026-11-13).
