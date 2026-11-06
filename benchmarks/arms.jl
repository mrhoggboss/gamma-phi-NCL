# The solver configurations of the paper, as named option sets. Every driver reads them from here.
#
#   S    MadNCL               MadNCL's own constants (ρ_max 1e12, 20 outer iterations, μ_min 1e-9,
#                             extrapolation step on), K2r/K1s dual-regularization fold off
#   SP   MadNCL + parameters  S with μ_min = μ*, 40 outer iterations, ρ_max 1e14, MadNLP's acceptable-level exit
#                             disabled
#   (S and SP differ from the released MadNCL package in one label: a solve whose success test passes at the
#   last allowed outer iteration is reported SOLVE_SUCCEEDED here, MAXIMUM_ITERATIONS_EXCEEDED by the package.)
#   W    (γ,φ)-MadNCL         weight (weight) law + force gate, no extrapolation step, MadNLP's acceptable-level
#                             exit disabled
#   U6A  power-kernel cell    φᵢ(t) = t²/2 + (λ/6)|t|⁶ with λ ≡ 1e-2 on every row, unit weights,
#                             residual gate, MadNLP's acceptable-level exit disabled
#   ablation (of φ-NCL)      U6A with the quadratic kernel: unit weights, quadratic kernel, residual gate (at γ ≡ 1 and
#                             φ(t) = t²/2 this is eq:gate), no extrapolation step, MadNLP's acceptable-level exit disabled
#   Wos  γ-NCL, one-sided     W with the weights capped at 1 (weight_clip upper bound 1.0 instead of 1e8): only
#                             down-weights are installed; everything else as W (Yifan 2026-11-06, CPU probe)
#   Only S keeps MadNLP's acceptable-level inner exit (acceptable_tol 1e-6, the upstream default); every other
#   configuration, and the LiftedKKT comparator (liftedkkt.jl), runs with acceptable_tol = 0, so that no inner solve
#   stops short of its budget at a looser tolerance (protocol of 2026-11-04).
#
# All four use scaling_max_gradient = 100 and the tolerances given by the drivers (defaults: opt_tol =
# feas_tol = 1e-8, constr_viol_tol = 1e-4); μ* = (opt_tol/100)^(1/1.05), the barrier floor at which the
# inner dual tolerance 100·μ^1.05 reaches opt_tol (2.9935772947204935e-10 at 1e-8). Suite-specific
# interior-point settings (iteration budget, wall time, linear solver) are added by the drivers,
# identically for every configuration.

using MadNCL

const ARMS = ("S", "SP", "W", "U6A", "ablation", "Wos")
const ARM_NAMES = Dict("S" => "MadNCL", "SP" => "MadNCL + parameters",
                       "W" => "γ-NCL", "U6A" => "φ-NCL", "ablation" => "ablation",
                       "Wos" => "γ-NCL, one-sided (γ ≤ 1)")
mu_star(tol) = (tol / 100)^(1 / 1.05)

"""
    arm_config(name; tol=1e-8, constr_viol_tol=1e-4) -> (kernel, ncl_options, ipm_options)

The penalty kernel, the NCL options and the MadNLP options that define configuration `name`, at the
optimality/feasibility tolerance `tol` and the constraint-violation tolerance `constr_viol_tol`.
"""
function arm_config(name::AbstractString; tol=1e-8, constr_viol_tol=1e-4)
    base = (verbose=false, opt_tol=tol, feas_tol=tol, constr_viol_tol=constr_viol_tol, scaling_max_gradient=100.0)
    tuned = (base..., mu_min=mu_star(tol), max_auglag_iter=40, rho_max=1e14)
    if name == "S"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; base..., fold_dual_regularization=false), NamedTuple())
    elseif name == "SP"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., fold_dual_regularization=false), (acceptable_tol=0.0,))
    elseif name == "W"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., extrapolation=false, weight_law=:geometry,
                                           weight_clip=(1e-30, 1e8), weight_anneal_horizon=6.0, gate_metric=:force),
                (acceptable_tol=0.0,))
    elseif name == "Wos"   # W with weight_clip = (1e-30, 1.0) (Yifan 2026-11-06): the weight law with up-weights removed
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., extrapolation=false, weight_law=:geometry,
                                           weight_clip=(1e-30, 1.0), weight_anneal_horizon=6.0, gate_metric=:force),
                (acceptable_tol=0.0,))
    elseif name == "U6A"
        return (MadNCL.PowerKernel(6.0, 1e-2),
                MadNCL.NCLOptions{Float64}(; tuned..., extrapolation=false), (acceptable_tol=0.0,))
    elseif name == "ablation"   # U6A with the quadratic kernel (Yifan 2026-11-05): the framework at γ ≡ 1, φ quadratic
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., extrapolation=false), (acceptable_tol=0.0,))
    end
    error("unknown configuration $name (expected one of $(join(ARMS, ", ")))")
end

"""
    echo_arm(io, name, solver)

Print the full option set of configuration `name` as constructed in `solver` (an `NCLSolver`):
kernel, every NCLOptions field, and the MadNLP options that matter for the comparison, read back
from the solver object.
"""
function echo_arm(io::IO, name::AbstractString, solver)
    o = solver.options
    k = solver.ncl.kernel
    λ = Array(solver.ncl.λr)
    println(io, "CONFIG $name ($(ARM_NAMES[name])) kernel=$(k) λr=[$(isempty(λ) ? "" : "$(minimum(λ)), $(maximum(λ))")] ",
            join(["$(f)=$(getfield(o, f))" for f in fieldnames(typeof(o))], " "))
    io_ = solver.ipm.opt
    println(io, "CONFIG $name ipm kkt_system=$(nameof(typeof(solver.ipm.kkt))) ",
            "linear_solver=$(nameof(typeof(solver.ipm.kkt.linear_solver))) tol=$(io_.tol) max_iter=$(io_.max_iter) ",
            "max_wall_time=$(io_.max_wall_time) bound_relax_factor=$(io_.bound_relax_factor) s_max=$(io_.s_max) ",
            "acceptable_tol=$(io_.acceptable_tol) acceptable_iter=$(io_.acceptable_iter) ",
            "equality_treatment=$(io_.equality_treatment) fixed_variable_treatment=$(io_.fixed_variable_treatment) ",
            "richardson_tol=$(solver.ipm.iterator.opt.richardson_tol) richardson_max_iter=$(solver.ipm.iterator.opt.richardson_max_iter)")
    flush(io)
end
