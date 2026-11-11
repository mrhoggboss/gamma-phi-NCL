# (γ,φ)-NCL — reproduction branch (`paper-repro`)

This branch reproduces every number in the tables and the figure of the manuscript *(γ, φ)-NCL* and nothing more. It
is the public MadNCL harness of branch `gamma-phi-ncl` (commit `3383a34`) with the protocol SCOPF set ported from the
branch that generated it (`scopf-pool`), the theory figure's generator added, and everything else removed (COPS and the
COPS size ladder, the ablation and one-sided configurations, the identity gates, the campaign scheduler). The solver
source `src/` and `ext/` is byte-identical to `gamma-phi-ncl` (`src/` unchanged since `10238f9`).

| manuscript float | label | file the manuscript `\input`s | emitter |
|---|---|---|---|
| CUTEst table | `tab:cutest` | `tables/tab_cutest_ma57.tex` | `benchmarks/tables/tab_cutest.py` |
| PGLIB table | `tab:gpu-opf` | `tables/tab_gpu_opf.tex` | `benchmarks/tables/tab_gpu_opf.py` |
| PGLIB appendix | `tab:pglib-appendix` | `tables/tab_pglib_appendix.tex` | `benchmarks/tables/tab_pglib_appendix.py` |
| SCOPF configuration | `tab:scopf-config` | `tables/tab_scopf_config.tex` | `benchmarks/tables/tab_scopf_config.py` |
| SCOPF, reference lists | `tab:gpu-scopf` | `tables/tab_gpu_scopf.tex` | `benchmarks/tables/tab_gpu_scopf.py` |
| SCOPF, protocol set | `tab:gpu-scopf-pglib` | `tables/tab_gpu_scopf_pglib.tex` | `benchmarks/tables/tab_gpu_scopf_pglib.py` |
| SCOPF protocol appendix | `tab:scopf-pglib-appendix` | `tables/tab_scopf_pglib_appendix.tex` | `benchmarks/tables/tab_scopf_pglib_appendix.py` |
| degenerate example | `fig:example-degenerate` | `figures/fig_example_degenerate.tex` | `benchmarks/figures/make_fig_example_degenerate.py` |

The two protocol-set tables are emitted for the manuscript's SCOPF section; the manuscript revision checked here
(Overleaf commit `e55ef05`) does not `\input` them yet. Their data are complete: all three repetitions of the 18
instances, re-copied from `scopf-pool` when the block ended (see the SCOPF protocol section below).

## What "reproduced" means here

The result CSVs under `benchmarks/results/paper/` are the campaign's, copied verbatim (rows, header and column order as
the drivers wrote them), with the configuration echo of every cell next to them. The emitters turn them into the floats:

```bash
benchmarks/paper/emit.sh        # all seven tables and the figure, ~45 s; writes benchmarks/out/paper/{tables,figures,summaries}
```

On this branch that command writes exactly the eight files above, every one of them compiles at the manuscript's page
geometry (`lib.sh compile_tables`), the five tables and the figure that the manuscript `\input`s are byte-identical to
its files (Overleaf commit `e55ef05`), the two protocol tables are byte-identical to the `gamma-phi-ncl` emissions, and
the console summaries equal the banked `benchmarks/results/paper/<suite>/summary.txt` (checked 2026-11-11).

Rerunning the solves reproduces the CSVs **bitwise on the CPU** in every column but the timing columns (the CPU solvers
are deterministic; a solve that ends at its wall-time cap can stop at a different iteration) and **to within GPU
nondeterminism on the GPU, ±2 solves**: cuDSS's device reductions are not bitwise reproducible, so single repetitions
differ (spread of the per-repetition solve counts in the banked data, `benchmarks/results/paper/<suite>/summary.txt`:
PGLIB at most 2 per configuration, SCOPF reference lists up to 3, protocol set up to 4, between r1 and r2 of φ-NCL);
every GPU suite is therefore run three times and scored by majority of three, and the manuscript makes no robustness
claim about GPU solve-count differences of two instances or fewer (Section 5, "Budgets and scoring"). In this build the CPU claim was checked on the protocol records only (one K = 1 verification and two
screened outages, identical but for their time columns, and the island table, byte-identical); the CUTEst table and the
GPU suites were not rerun.

## Hardware and software of the campaign

- 2 x Intel Xeon Gold 6130 (2 x 16 cores, 64 threads), 2 x NVIDIA Quadro GV100 (32 GB, compute capability 7.0),
  NVIDIA driver 580.178.04 / CUDA 13.0 on this node at build time; CUTEst runs used 30 Distributed workers, the GPU
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
  CUTEst.jl (the driver decodes missing ones before the run).
- Run (all seven configurations: S, SP, W, U6A, liftedkkt, ipopt, madnlp; MA57, 30 workers, 3600 s per solve):

  ```bash
  benchmarks/paper/chain_cpu.sh                       # or one configuration:
  julia --project=benchmarks/envs/cpu benchmarks/cutest.jl benchmarks/instances/cutest_pop1070.txt W ma57 30 3600 benchmarks/out/paper/cutest/W_r1 --trace
  ```

  Campaign elapsed per configuration at 30 workers: S 2.4 h, W 1.7 h, U6A 3.6 h, LiftedKKT 5.1 h, Ipopt 3.6 h,
  MadNLP-augmented 4.3 h (`WALLTIME_cpu.csv` of the campaign, in `gamma-phi-ncl`'s uncommitted
  `benchmarks/out/paper/logs/`); SP's logged elapsed covers only a 60-s resume, and its
  per-solve times sum to 103 489 s (0.96 h of 30 workers, a lower bound). 20.6 h for the six others.
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
- Emit: `benchmarks/paper/emit.sh opf` (`tab_gpu_opf.py`, `tab_pglib_appendix.py`; seconds).

## Tables `tab:scopf-config` and `tab:gpu-scopf` — SCOPF, the 23 reference-list instances

- Data: the MATPOWER case files, downloaded and checked against `benchmarks/instances/scopf_data.sha256`:
  `benchmarks/instances/fetch_scopf_data.sh <dir>` (`<dir>/data`, `<dir>/data_mp70`); the instance list is
  `benchmarks/instances/scopf23.csv`, the contingency lists `benchmarks/instances/scopf_contingencies.jl` (from the
  reference benchmark's harness).
- Run (five configurations x three repetitions, 3000 iterations, 1800 s per solve; the SCOPF model and solver settings
  are those of `tab:scopf-config`, read back from the configuration echoes):

  ```bash
  SCOPF_DATA=<dir> benchmarks/paper/chain_gpu.sh <device> scopf     # 15 cells; one cell is:
  julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl scopf W benchmarks/out/paper/scopf/W_r1 --tag=r1 --trace --data=<dir>
  ```

  Campaign elapsed per cell 3182–7804 s, 21.7 h for the 15 (`WALLTIME_scopf.csv`).
- Emit: `benchmarks/paper/emit.sh scopf` (`tab_gpu_scopf.py`, `tab_scopf_config.py`; seconds).

## Tables `tab:gpu-scopf-pglib` and `tab:scopf-pglib-appendix` — SCOPF, the 18 protocol instances

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
- Emit: `benchmarks/paper/emit.sh scopf_pglib` (`tab_gpu_scopf_pglib.py`, `tab_scopf_pglib_appendix.py`; seconds).
- **Data.** `benchmarks/results/paper/scopf_pglib/` holds all three repetitions of all 18 instances for the five
  configurations (270 rows, 270 configuration echoes), copied from `scopf-pool` (`results/pilot` as committed at
  `76a53fe`) after the block ended on 2026-11-11 (`benchmarks/results/paper/scopf_pglib/SOURCE.txt`).

## Figure `fig:example-degenerate`

```bash
python3 benchmarks/figures/make_fig_example_degenerate.py --out=<dir>     # ~35 s; or benchmarks/paper/emit.sh figure
```

Plain Python (standard library). Writes `<dir>/fig_example_degenerate.tex` (TikZ; needs `\usetikzlibrary{shapes.geometric,
arrows.meta}`), byte-identical to the manuscript's `figures/fig_example_degenerate.tex` (sha256 `698f1364…390d7a`).

## Rerunning everything and comparing

Every chain writes under `benchmarks/out/paper/` and never into the banked `benchmarks/results/paper/`: each finished
cell's CSV and configuration echo is copied, under the banked file names, into `benchmarks/out/paper/results/<suite>/`.
Emit from the rerun with `RES=benchmarks/out/paper/results benchmarks/paper/emit.sh <suite>`. The chains are
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
| `madnlp` | MadNLP-augmented | `benchmarks/cutest.jl` (CPU only) |

All configurations use the tolerance `1e-8` and the gradient scaling `scaling_max_gradient=100`.
With `μ* = (1e-8/100)^(1/1.05) ≈ 2.9936e-10`:

```julia
using MadNCL, MadNLP
μstar = (1e-8 / 100)^(1 / 1.05)

# MadNCL: MadNCL's own constants (ρ_max = 1e12, 20 outer iterations, μ_min = 1e-9,
# extrapolation step on); the dual-regularization fold of K2r/K1s is switched off.
S = MadNCL.NCLOptions{Float64}(opt_tol=1e-8, feas_tol=1e-8, scaling_max_gradient=100.0,
                               fold_dual_regularization=false)

# MadNCL + parameters: MadNCL with the constants of the (γ,φ) runs, and MadNLP's acceptable-level exit
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
`MAXIMUM_ITERATIONS_EXCEEDED`, while this branch reports `SOLVE_SUCCEEDED`. The iterate is the same; only the
label differs. With S (20 outer iterations) this matters on runs that converge exactly at outer 20; on the
SCOPF benchmark it relabels two runs (case_ACTIVSg500 and case_ACTIVSg200 with 100 contingencies) that the
released package reports as iteration-limit failures.

The success test is the same for every configuration: the returned primal-dual pair must satisfy
the KKT conditions of the problem solved by the interior-point method, with the complementarity
measured at μ = 0 and the multipliers scaled as in Ipopt (`s_max = 100`), and the constraint
violation in the original scaling must not exceed `constr_viol_tol` (see `MadNCL.NCLOptions`).

The drivers print the full option set of every configuration, read back from the constructed solver, into the
configuration echoes (`config_*.txt`) next to the results; `tab_scopf_config` is emitted from those echoes.

## Layout

| path | contents |
|---|---|
| `src/`, `ext/` | the solver (MadNCL with per-row weights and penalty kernels), unchanged from `gamma-phi-ncl` |
| `benchmarks/arms.jl`, `liftedkkt.jl`, `common.jl` | the configurations and shared driver helpers |
| `benchmarks/cutest.jl`, `benchmarks/gpu.jl` | the CPU (CUTEst) and GPU (`opf`, `scopf`) drivers; they take paths, devices and tags as arguments and read no environment variables |
| `benchmarks/models/` | the AC-OPF model (ExaModels) and the SCOPF-as-MPCC model (JuMP + PowerModels; from the MadNCL paper's harness and github.com/frapac/pscc-scopf) |
| `benchmarks/instances/` | instance lists (CUTEst 1070 and its certified traps, used by the CUTEst summary; PGLIB 66; SCOPF 23 and 18), contingency lists, data fetch scripts and sha256 manifests |
| `benchmarks/scopf_protocol/` | the generation protocol of the 18 protocol SCOPF instances: scripts, records, list builder |
| `benchmarks/tables/`, `benchmarks/figures/` | the emitters (Python, standard library only) |
| `benchmarks/paper/` | `chain_cpu.sh`, `chain_gpu.sh`, `emit.sh`, their shared `lib.sh`, `watch.sh` (stall watchdog), `gpu_device.sh` (device gate) |
| `benchmarks/results/paper/` | the campaign's result CSVs, configuration echoes and summaries (`cutest`, `opf`, `scopf`, `scopf_pglib`) |
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
