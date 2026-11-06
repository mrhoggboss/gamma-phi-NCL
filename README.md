# MadNCL.jl

[![Run tests](https://github.com/MadNLP/MadNCL.jl/actions/workflows/action.yml/badge.svg)](https://github.com/MadNLP/MadNCL.jl/actions/workflows/action.yml)

An implementation of [Algorithm NCL](https://link.springer.com/chapter/10.1007/978-3-319-90026-1_8) in Julia.

MadNCL is built as [MadNLP](https://github.com/MadNLP/MadNLP.jl)'s extension, and supports the solution of
large-scale nonlinear programs on GPUs. MadNCL is particularly good at solving infeasible
or degenerate optimization problems.

## Installation

MadNCL can be installed and tested through the Julia package manager:

```julia
julia> ]
pkg> add MadNCL
pkg> test MadNCL
```

## Quickstart

MadNCL leverages [JuliaSmoothOptimizers](https://jso.dev)'s ecosystem.
For instance, you can solve any instance in [CUTEst.jl](https://github.com/JuliaSmoothOptimizers/CUTEst.jl/) simply as:

```julia
using MadNCL
using CUTEst
nlp = CUTEstModel("HS15")
results = madncl(nlp)
```

You gain more fine-grained control on the solver by tuning the options:

```julia
# Specify NCL's options
ncl_options = MadNCL.NCLOptions{Float64}(
    verbose=true,       # print convergence logs
    scaling=false,      # specify if we should scale the problem
    opt_tol=1e-8,       # tolerance on dual infeasibility
    feas_tol=1e-8,      # tolerance on primal infeasibility
    rho_init=1e1,       # initial augmented Lagrangian penalty
    max_auglag_iter=20, # maximum number of outer iterations
)
# MadNLP's options are passed directly to madncl:
results = madncl(
    nlp;
    ncl_options=ncl_options,
    linear_solver=LDLSolver,   # factorize the KKT system with a LDL decomposition
    print_level=MadNLP.INFO,   # activate logs inside MadNLP
)
```

## (γ,φ)-NCL: per-row weights and penalty kernels

This branch extends MadNCL's augmented-Lagrangian subproblem to the penalty

```math
\sum_i \frac{γ_i}{ρ} φ_i(-ρ r_i),
```

with per-row weights `γᵢ > 0` (`solver.ncl.γr`, default 1) and a penalty kernel `φ`:

- `MadNCL.QuadraticKernel()` — `φ(t) = t²/2`, the classical MadNCL penalty (default);
- `MadNCL.PowerKernel(p, λ)` — `φᵢ(t) = t²/2 + (λᵢ/p)|t|^p`, with per-row weights `λᵢ`
  (`solver.ncl.λr`, initialized to `λ`).

New kernels are added by subtyping `MadNCL.AbstractKernel` and implementing
`phi(k, λ, t)`, `dphi(k, λ, t)`, `ddphi(k, λ, t)`. The weights can be updated automatically by
the weight law `weight_law=:geometry`, and the subproblem
acceptance test can be measured on the penalty force (`gate_metric=:force`): accept when
|γᵢ φᵢ'(−ρ rᵢ)| ≤ φᵢ'(ρ · thr) on every row, thr = max(η, feas_tol), instead of ‖r‖∞ ≤ thr. At
γ ≡ 1 the two tests coincide for every admissible kernel (φ' odd and increasing); for the quadratic
kernel the force test reads maxᵢ γᵢ |rᵢ| ≤ thr. See the docstring of `MadNCL.NCLOptions`.

### Reproducing the solver configurations of the paper

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

## Benchmarks

`benchmarks/` holds the harness that produces the paper's numbers. Layout:

| path | contents |
|---|---|
| `benchmarks/arms.jl` | the four solver configurations as named option sets: `S` (MadNCL), `SP` (MadNCL + parameters), `W` (γ-NCL), `U6A` (φ-NCL) |
| `benchmarks/cutest.jl` | CUTEst on the CPU: one flat pool of (configuration × linear solver × problem) tasks over Distributed workers; the four configurations plus Ipopt, LiftedKKT (MadNLP, condensed KKT) and MadNLP (augmented KKT); MA57 or LDL |
| `benchmarks/gpu.jl` | GPU suites: PGLIB OPF (`opf`), COPS (`cops`), the COPS size ladder (`cops_ladder`), SCOPF as MPCC (`scopf`); cuDSS LDL; one warm-up solve per configuration; `--device=cpu` runs the same code on the CPU for smoke tests |
| `benchmarks/liftedkkt.jl` | the LiftedKKT comparator used by `gpu.jl` (configuration `liftedkkt`) |
| `benchmarks/models/` | the AC-OPF model (ExaModels) and the SCOPF-as-MPCC model (JuMP + PowerModels) |
| `benchmarks/instances/` | instance lists: CUTEst (1070 and a 16-problem smoke), certified CUTEst traps, PGLIB (all 66 cases, run for every configuration; `pglib45.txt` = the 45 cases with at least 1000 buses, a scoring subset of the main-text table only), SCOPF (23 case/contingency pairs, with the case-file directory of each) and the SCOPF contingency lists |
| `benchmarks/tables/` | stdlib-Python emitters of the paper's tables and figure (LaTeX: booktabs, pgfplots) from the result CSVs, and a console summary of a CUTEst run |
| `benchmarks/envs/{cpu,gpu}` | pinned environments: Julia 1.10.11 with MadNLP 0.10.1 and HSL MA57 (CPU); Julia 1.11.2 with CUDA 6.2, cuDSS 0.7, ExaModels 0.11.2 (GPU) |
| `gates/` | identity gates of this branch against the research code it was extracted from |

Each driver prints the full option set of every configuration, read back from the constructed solver,
and writes it next to the results (`config.txt`, `config_<suite>__<tag>.txt`). The drivers take paths,
devices and tags as arguments and read no environment variables.

```bash
# CUTEst, the four configurations and the three baselines, MA57, 30 workers, 3600 s per solve
julia --project=benchmarks/envs/cpu benchmarks/cutest.jl benchmarks/instances/cutest_pop1070.txt \
    S,SP,W,U6A,ipopt,liftedkkt,madnlp ma57 30 3600 results/cutest --trace
python3 benchmarks/tables/summary.py results/cutest --cap=3600
python3 benchmarks/tables/tab_cutest.py results/cutest --cap=3600

# GPU suites, one repetition (tag r1)
julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl opf S,SP,W,U6A,liftedkkt results/gpu --tag=r1
julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl cops_ladder S,SP,W,liftedkkt results/gpu --tag=r1
julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl scopf S,SP,W,U6A,liftedkkt results/gpu --tag=r1 \
    --data=<directory with data/ and data_mp70/>
python3 benchmarks/tables/tab_gpu_opf.py results/gpu --subset=benchmarks/instances/pglib45.txt   # main-text table
python3 benchmarks/tables/tab_pglib_appendix.py results/gpu   # appendix: all 66 cases, every configuration
python3 benchmarks/tables/tab_gpu_scopf.py results/gpu
python3 benchmarks/tables/tab_scopf_config.py results/gpu
python3 benchmarks/tables/fig_gpu_scaling.py results/gpu
```

The tolerances are inputs of both drivers: `--tol` (optimality and feasibility, default `1e-8`) and
`--cvtol` (constraint violation in the original scaling, default `1e-4`), applied to every
configuration; Ipopt receives both, while MadNLP (LiftedKKT and the augmented baseline) has no
constraint-violation test and receives `--tol` only. The violation of every returned point is recorded
(`viol`, `pr_res`), and the summary and the table emitters count a MadNLP solve only if that violation is
within the run's `constr_viol_tol` (post-hoc guard, the same test the other solvers apply themselves); the
unguarded count is printed in parentheses. The result files themselves are left as the solvers returned them.

Data. CUTEst problems are fetched by CUTEst.jl, the PGLIB v23.07 cases by the artifact in
`benchmarks/Artifacts.toml`, and the COPS models are built by COPSBenchmark.jl. The SCOPF case files
(MATPOWER format) are not distributed here; fetch them with

```bash
benchmarks/instances/fetch_scopf_data.sh <dir>     # then pass --data=<dir> to gpu.jl
```

which downloads them from github.com/MATPOWER/matpower and checks them against
`benchmarks/instances/scopf_data.sha256`:

| directory | instances | files and MATPOWER release |
|---|---|---|
| `data/` | the 8 of the MadNCL paper | case118, case1354pegase, case2869pegase, case_ACTIVSg200 from MATPOWER 7.0 (identical in every release 7.0–8.1); case300 from MATPOWER 8.1 (it differs from the 7.0 file only in the TAP column of 22 transformer branches, which gives the same SCOPF model) |
| `data_mp70/` | the 15 further pairs | case118, case300, case1354pegase, case2869pegase, case_ACTIVSg200, case_ACTIVSg500, case_ACTIVSg2000, all from MATPOWER 7.0 |

The SCOPF model (`benchmarks/models/scopf_model.jl`) and the contingency lists
(`benchmarks/instances/scopf_contingencies.jl`) come from the MadNCL paper's harness and
github.com/frapac/pscc-scopf (see the attribution in each file).

## JuMP

MadNCL does not yet provide an extension for [MathOptInterface.jl](https://github.com/jump-dev/MathOptInterface.jl), but a JuMP model can be wrapped
as a `MathOptNLPModel` using [NLPModelsJuMP.jl](https://github.com/JuliaSmoothOptimizers/NLPModelsJuMP.jl).

```julia
using JuMP
using NLPModelsJuMP
using MadNCL

jm = Model()
x0 = [10, 10, 10, 10]
@variable(jm, x[i = 1:4], start = x0[i])
@constraint(jm, x[1]^2 - x[2] - x[4]^2 == 0)
@constraint(jm, x[2] - x[1]^3 - x[3]^2 == 0)
@objective(jm, Min, -x[1])

nlp = MathOptNLPModel(jm)
results = madncl(nlp)
```

## GPU support

MadNCL supports natively the solution of nonlinear programs on the GPU using MadNLPGPU.
To evaluate your model on the GPU, we recommend using [ExaModels](https://github.com/exanauts/ExaModels.jl).
For instance, you can implement the instance `elec` from the [COPS benchmark](https://www.mcs.anl.gov/~more/cops/) directly as:

```julia
using ExaModels

function elec_model(np; seed = 2713, T = Float64, backend = nothing, kwargs...)
    Random.seed!(seed)
    # Set the starting point to a quasi-uniform distribution of electrons on a unit sphere
    theta = (2pi) .* rand(np)
    phi = pi .* rand(np)

    core = ExaModels.ExaCore(T; backend= backend)
    x = ExaModels.variable(core, 1:np; start = [cos(theta[i])*sin(phi[i]) for i=1:np])
    y = ExaModels.variable(core, 1:np; start = [sin(theta[i])*sin(phi[i]) for i=1:np])
    z = ExaModels.variable(core, 1:np; start = [cos(phi[i]) for i=1:np])
    # Coulomb potential
    itr = [(i,j) for i in 1:np-1 for j in i+1:np]
    ExaModels.objective(core, 1.0 / sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2 + (z[i] - z[j])^2) for (i,j) in itr)
    # Unit-ball
    ExaModels.constraint(core, x[i]^2 + y[i]^2 + z[i]^2 - 1 for i=1:np)

    return ExaModels.ExaModel(core; kwargs...)
end
```

You can instantiate the model and solve it on the GPU using CUDA and MadNLPGPU, respectively:
```julia
using CUDA
using MadNLPGPU

nlp = elec_model(100; backend=CUDABackend())

results = madncl(
    nlp;
    print_level=MadNLP.INFO,                # activate logs inside MadNLP
    kkt_system=MadNCL.K2rAuglagKKTSystem,   # we need to reformulate the Newton system inside MadNCL
    linear_solver=MadNLPGPU.CUDSSSolver,    # factorize the KKT system on the GPU using NVIDIA cuDSS
)
```

## Citing MadNCL.jl

If you use MadNCL.jl in your research, we would greatly appreciate your citing it.

```bibtex
@article{MadNCL,
  title   = {{MadNCL: A GPU Implementation of Algorithm NCL for Large-Scale, Degenerate Nonlinear Programs}},
  author  = {Alexis Montoison and François Pacaud and Michael Saunders and Sungho Shin and Dominique Orban},
  journal = {arXiv preprint arXiv:2510.05885},
  year    = {2025},
}
```
