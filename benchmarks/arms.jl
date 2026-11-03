# The solver configurations of the paper, as named option sets. Every driver reads them from here.
#
#   S    MadNCL               MadNCL's own constants (ρ_max 1e12, 20 outer iterations, μ_min 1e-9,
#                             extrapolation step on), K2r/K1s dual-regularization fold off
#   SP   MadNCL + parameters  S with μ_min = μ*, 40 outer iterations, ρ_max 1e14
#   W    (γ,φ)-MadNCL         weight (weight) law + force gate, no extrapolation step
#   U6A  power-kernel cell    φᵢ(t) = t²/2 + (λ/6)|t|⁶ with λ ≡ 1e-2 on every row, unit weights,
#                             residual gate, MadNLP's acceptable-level exit disabled
#
# All four use the tolerance 1e-8 and scaling_max_gradient = 100; μ* = (1e-8/100)^(1/1.05).
# Suite-specific interior-point settings (iteration budget, wall time, linear solver) are added by
# the drivers, identically for every configuration.

using MadNCL

const ARMS = ("S", "SP", "W", "U6A")
const ARM_NAMES = Dict("S" => "MadNCL", "SP" => "MadNCL + parameters",
                       "W" => "(γ,φ)-MadNCL", "U6A" => "power-kernel cell (p = 6, λ = 1e-2)")
const TOL = 1e-8
const MU_STAR = (TOL / 100)^(1 / 1.05)

"""
    arm_config(name) -> (kernel, ncl_options::NCLOptions{Float64}, ipm_options::NamedTuple)

The penalty kernel, the NCL options and the MadNLP options that define configuration `name`.
"""
function arm_config(name::AbstractString)
    base = (verbose=false, opt_tol=TOL, feas_tol=TOL, scaling_max_gradient=100.0)
    tuned = (base..., mu_min=MU_STAR, max_auglag_iter=40, rho_max=1e14)
    if name == "S"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; base..., fold_dual_regularization=false), NamedTuple())
    elseif name == "SP"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., fold_dual_regularization=false), NamedTuple())
    elseif name == "W"
        return (MadNCL.QuadraticKernel(),
                MadNCL.NCLOptions{Float64}(; tuned..., extrapolation=false, weight_law=:geometry,
                                           weight_clip=(1e-30, 1e8), weight_anneal_horizon=6.0, gate_metric=:force),
                NamedTuple())
    elseif name == "U6A"
        return (MadNCL.PowerKernel(6.0, 1e-2),
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
