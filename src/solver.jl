import MadNLP: full, primal, dual, dual_lb, dual_ub

#=
    NCLOptions
=#

"""
    NCLOptions{T}

Options of the NCL outer loop. The defaults are those of MadNCL; the (γ,φ) extensions are
off by default (quadratic kernel, unit gains, residual gate).

Outer loop and tolerances
- `verbose`: print one log line per outer iteration.
- `extrapolation`, `extrapolation_rho`: the extrapolation (crossover) step of Armand & Omheni
  between outer iterations, and its acceptance factor.
- `scaling`, `scaling_max_gradient`: gradient-based scaling of the problem (`ScaledModel`).
- `opt_tol`, `feas_tol`: tolerances of the success test (see below) and of the acceptance test.
- `constr_viol_tol`: bound on the constraint violation of the returned point, in the
  original scaling of the problem.
- `rho_init`, `rho_max`: initial and maximal penalty ρ. The penalty is multiplied by 10 after
  every outer iteration whose subproblem is not accepted; the solver declares the problem
  infeasible when ρ reaches `rho_max` while ‖r‖∞ is still above `opt_tol`.
- `max_auglag_iter`: maximum number of outer iterations.
- `mu_init`, `mu_tau`, `mu_fac`, `mu_min`: barrier schedule, μ ← max(min(μ^τ, fac·μ), μ_min)
  after every accepted subproblem.

(γ,φ) extensions
- `gain_law`: `:none` (default) keeps the per-row gains γ (`NCLModel.γr`) as set by the
  caller. `:geometry` recomputes them after every outer iteration from the row norms of the
  scaled Jacobian at the last iterate (see `_update_gains!`).
- `gain_clip`: interval to which the target gains of `:geometry` are clipped.
- `gain_anneal_horizon`: the installed gains are `target^α` with
  `α = clamp(n_acc / gain_anneal_horizon, 0, 1)`, where `n_acc` is the number of accepted
  subproblems so far (`≤ 0` disables the annealing: α ≡ 1).
- `gate_metric`: acceptance test of a subproblem (multiplier update and barrier decrease).
  `:residual` accepts when ‖r‖∞ ≤ max(η, feas_tol); `:force` accepts when the penalty force
  satisfies ‖γ φ'(−ρ r)‖∞ ≤ ρ · max(η, feas_tol). Both also require the inner solve to have
  converged. The two tests coincide for the quadratic kernel with γ ≡ 1.
- `fold_dual_regularization`: with `K2rAuglagKKTSystem`, factorize the dual-regularized
  reduced block (see its docstring). `false` restores the original MadNCL assembly.

Success test. The solve terminates when the current primal-dual pair satisfies the KKT
conditions of the problem solved by the interior-point method (the original problem with the
bounds of its inequality rows relaxed by MadNLP's `bound_relax_factor`):

    max(du / s_d, cc / s_c, pr) ≤ opt_tol   and   viol ≤ constr_viol_tol,

where `du` is the dual infeasibility, `cc` the complementarity at μ = 0 and `pr` the distance
of c(x) to the relaxed constraint bounds, all in the scaled problem, `s_d`, `s_c` are Ipopt's
multiplier scaling factors with `s_max = 100`, and `viol` is the distance of c(x) to the
original constraint bounds in the original scaling.
"""
@kwdef struct NCLOptions{T}
    verbose::Bool = true
    extrapolation::Bool = true
    extrapolation_rho::T = T(0.3)
    scaling::Bool = true
    scaling_max_gradient::T = T(1)
    opt_tol::T = T(1e-6)
    feas_tol::T = T(1e-6)
    constr_viol_tol::T = max(T(100) * feas_tol, T(1e-4))
    rho_init::T = T(1e2)
    rho_max::T = T(1e12)
    max_auglag_iter::Int = 20
    mu_init::T = T(1e-1)
    mu_tau::T = T(1.99)
    mu_fac::T = T(0.2)
    mu_min::T = T(1e-9)
    gain_law::Symbol = :none
    gain_clip::NTuple{2, T} = (T(1e-30), T(1e8))
    gain_anneal_horizon::T = T(6)
    gate_metric::Symbol = :residual
    fold_dual_regularization::Bool = true
end

# Ipopt's s_max, used for the multiplier scaling factors s_d, s_c of the success test.
const _SUCCESS_S_MAX = 100

#=
    Gain workspace (gain_law = :geometry)
=#

abstract type AbstractGainWorkspace{T} end

# Host workspace. `rows[k]` is the constraint row of the k-th entry of the x-block of the
# (scaled) NCL Jacobian; the structure is fixed for the whole solve.
struct GainWorkspace{T} <: AbstractGainWorkspace{T}
    rows::Vector{Int}
    jv::Vector{T}       # x-block Jacobian values
    w::Vector{T}        # squared row norms wᵢ
    obs::BitVector      # rows with a finite 1/wᵢ
    g::Vector{T}        # new gains
    gprev::Vector{T}    # gains in force before the update
end

# Device workspace: the row norms are one sparse matrix-vector product w = S * jv.^2 with the
# fixed 0/1 selector S[rows[k], k] = 1; every other step is a broadcast or a reduction.
struct GainWorkspaceDevice{T, MT, VT, VB} <: AbstractGainWorkspace{T}
    S::MT
    jv2::VT
    w::VT
    logt::VT
    g::VT
    obs::VB
    gprev::VT
end

# Host build of the row selector; the CUDA extension specializes it on device prototypes.
_build_row_selector(proto::AbstractArray, rows::Vector{Int}, nr::Int, nnz_x::Int) =
    sparse(rows, collect(1:nnz_x), ones(eltype(proto), nnz_x), nr, nnz_x)

# The Jacobian read by the gain law is MadNLP.get_jacobian(kkt): the scaled NCL Jacobian at the
# last evaluated iterate, x-block entries first and the nr entries of the r-identity last.
function _build_gain_workspace(ncl::NCLModel{T}, ipm::MadNLP.MadNLPSolver,
                               options::NCLOptions{T}) where T
    options.gain_law === :none && return nothing
    cb = ipm.cb
    nnz_x = cb.nnzj - ncl.nr
    jac = MadNLP.get_jacobian(ipm.kkt)
    (jac isa AbstractVector && length(jac) == cb.nnzj) ||
        error("gain_law=:geometry requires a sparse KKT system exposing the callback Jacobian")
    Ji = MadNLP.create_array(cb, Int32, cb.nnzj)
    Jj = MadNLP.create_array(cb, Int32, cb.nnzj)
    MadNLP._jac_sparsity_wrapper!(cb, Ji, Jj)
    rows = Vector{Int}(Array(Ji)[1:nnz_x])
    nr = ncl.nr
    if jac isa Array
        return GainWorkspace{T}(rows, Vector{T}(undef, nnz_x), zeros(T, nr), falses(nr),
                                Vector{T}(undef, nr), Vector{T}(undef, nr))
    else
        dev(n) = MadNLP.create_array(cb, T, n)
        S = _build_row_selector(dev(0), rows, nr, nnz_x)
        obs = MadNLP.create_array(cb, Bool, nr); fill!(obs, false)
        return GainWorkspaceDevice{T, typeof(S), typeof(dev(0)), typeof(obs)}(
            S, dev(nnz_x), dev(nr), dev(nr), dev(nr), obs, dev(nr))
    end
end

#=
    NCLSolver
=#

struct NCLSolver{T, VT, M, K}
    ncl::NCLModel{T, VT, M, K}
    ipm::MadNLP.MadNLPSolver{T, VT}
    options::NCLOptions{T}
    n::Int
    m::Int
    gainws::Union{Nothing, AbstractGainWorkspace{T}}
end

"""
    NCLSolver(nlp; ncl_options=NCLOptions{T}(), kernel=QuadraticKernel(), ipm_options...)

Build the NCL reformulation of `nlp` with the penalty kernel `kernel`, and the MadNLP solver of
its subproblems (`ipm_options` are passed to `MadNLP.MadNLPSolver`). The per-row gains and
kernel parameters can be set through `solver.ncl.γr` and `solver.ncl.λr` before `solve!`.
"""
function NCLSolver(nlp::NLPModels.AbstractNLPModel{T, VT}; ncl_options=NCLOptions{T}(),
                   kernel::AbstractKernel=QuadraticKernel(), ipm_options...) where {T, VT}
    ncl_options.gain_law in (:none, :geometry) ||
        error("unknown gain_law $(ncl_options.gain_law) (expected :none or :geometry)")
    ncl_options.gate_metric in (:residual, :force) ||
        error("unknown gate_metric $(ncl_options.gate_metric) (expected :residual or :force)")
    ncl = if ncl_options.scaling
        NCLModel(ScaledModel(nlp; max_gradient=ncl_options.scaling_max_gradient); kernel=kernel)
    else
        NCLModel(nlp; kernel=kernel)
    end
    solver = MadNLP.MadNLPSolver(
        ncl;
        nlp_scaling=false,
        ipm_options...,
    )
    m = MadNLP.n_constraints(solver.cb)
    # Remove regularization variables to work in the original space
    n = MadNLP.n_variables(solver.cb) - m
    @assert solver.m == m
    if solver.kkt isa K2rAuglagKKTSystem
        solver.kkt.fold_dual_regularization[] = ncl_options.fold_dual_regularization
    end
    gainws = _build_gain_workspace(ncl, solver, ncl_options)
    return NCLSolver{T, VT, typeof(ncl.nlp), typeof(kernel)}(ncl, solver, ncl_options, n, m, gainws)
end

#=
    NCLStats
=#

mutable struct NCLStats{T, VT} <: AbstractExecutionStats
    status::MadNLP.Status
    solution::VT
    regularization::VT
    objective::T
    dual_feas::T
    primal_feas::T
    multipliers::VT
    multipliers_L::VT
    multipliers_U::VT
    iter::Int
    counters::MadNLP.MadNLPCounters
end

function NCLStats(solver::NCLSolver{T, VT, M}, status) where {T, VT, M<:NLPModels.AbstractNLPModel}
    ipm = solver.ipm # MadNLP instance
    ncl = solver.ncl
    # Get original number of variables (before removing the fixed variables)
    n = NLPModels.get_nvar(ncl.nlp)
    m = solver.m
    is_min = NLPModels.get_minimize(ncl.nlp)
    ρk = ncl.ρk[]
    x = similar(VT, n + m)
    zl = similar(VT, n + m)
    zu = similar(VT, n + m)
    MadNLP.unpack_x!(x, ipm.cb, MadNLP.variable(solver.ipm.x))
    MadNLP.unpack_z!(zl, ipm.cb, MadNLP.variable(solver.ipm.zl))
    MadNLP.unpack_z!(zu, ipm.cb, MadNLP.variable(solver.ipm.zu))

    y = copy(solver.ipm.y)
    r = x[n+1:n+m]
    # Remove the penalty term added in NCLModel.obj
    obj_val = solver.ipm.obj_val + dot(y, r) - _penalty_obj(ncl, ρk, r)
    MadNLP.update_z!(ipm.cb, x, y, zl, zu, ipm.jacl)
    # Scale back problem data
    if isa(ncl.nlp, ScaledModel)
        obj_scale, con_scale = ncl.nlp.scaling_obj, ncl.nlp.scaling_cons
        obj_val /= obj_scale
        y .= y .* con_scale ./ obj_scale
        zl .= zl ./ obj_scale
        zu .= zu ./ obj_scale
    end
    return NCLStats{T, VT}(
        status,
        x[1:n],
        r,
        is_min ? obj_val : -obj_val,
        solver.ipm.inf_du,
        norm(r, Inf),
        is_min ? y : .-y,
        zl[1:n],
        zu[1:n],
        solver.ipm.cnt.k,
        solver.ipm.cnt,
    )
end

function getStatus(result::NCLStats)
    if result.status == MadNLP.SOLVE_SUCCEEDED
        println("Optimal solution found.")
    elseif result.status == MadNLP.INFEASIBLE_PROBLEM_DETECTED
        println("Convergence to an infeasible point.")
    elseif result.status == MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
        println("Maximum number of iterations reached.")
    else
        println("Unknown return status.")
    end
end

#=
    NCL Algorithm
=#

function _introduce(nx, nr)
    println("MadNCL algorithm\n")

    println("Total number of variables............................:      ", nx)
    println("Total number of constraints..........................:      ", nr)
    println()
end

function _log_header()
    @printf(
        "outer  inner     objective    inf_pr   inf_du    η        μ       ρ \n"
    )
end

function _log_iter(nit, flag, n_inner, obj, inf_pr, inf_du, alpha, mu, rho)
    @printf(
        "%5s%1s %5i %+13.7e %6.2e %6.2e %6.2e %6.1e %6.2e\n",
        nit, flag, n_inner, obj, inf_pr, inf_du, alpha, mu, rho,
    )
end

function get_inf_du(solver::NCLSolver)
    return solver.ipm.inf_du
end

#=
    Success test
=#

# Constraint bounds of the problem solved by the interior-point method. MadNLP relaxes the
# bounds of the inequality rows by `bound_relax_factor` in `initialize!`; the same call
# (MadNLP.set_initial_bounds!) is applied here. Under EnforceEquality the equality rows stay
# exact; under RelaxEquality every row is relaxed twice, as in MadNLP. Computed once per solve.
function _relaxed_con_bounds(ncl::NCLModel, ipm::MadNLP.MadNLPSolver)
    nlp = ncl.nlp
    lc0 = NLPModels.get_lcon(nlp); uc0 = NLPModels.get_ucon(nlp)
    lc = copy(lc0); uc = copy(uc0)
    ε = ipm.opt.bound_relax_factor
    eqt = ipm.opt.equality_treatment
    if eqt === MadNLP.RelaxEquality
        MadNLP.set_initial_bounds!(lc, uc, ε)
        MadNLP.set_initial_bounds!(lc, uc, ε)
    elseif eqt === MadNLP.EnforceEquality
        lr = copy(lc); ur = copy(uc)
        MadNLP.set_initial_bounds!(lr, ur, ε)
        isineq = lc0 .!= uc0
        lc .= ifelse.(isineq, lr, lc)
        uc .= ifelse.(isineq, ur, uc)
    else
        error("unknown equality_treatment $eqt (expected MadNLP.EnforceEquality or MadNLP.RelaxEquality)")
    end
    return lc, uc
end

# From one evaluation of c(x): (distance of c(x) to the relaxed bounds [lcε, ucε] in the scaled
# problem, distance of c(x) to the original bounds in the original scaling).
function _primal_infeasibility(ncl::NCLModel, x::AbstractVector, lcε::AbstractVector, ucε::AbstractVector)
    nlp = ncl.nlp
    m = NLPModels.get_ncon(nlp)
    z = zero(eltype(x))
    m == 0 && return (z, z)
    c = similar(x, m)
    NLPModels.cons!(nlp, x, c)
    pr = maximum(max.(max.(lcε .- c, c .- ucε), z))
    lc = NLPModels.get_lcon(nlp); uc = NLPModels.get_ucon(nlp)
    c .= max.(max.(lc .- c, c .- uc), z)
    nlp isa ScaledModel && (c ./= nlp.scaling_cons)
    return (pr, maximum(c))
end

# The x-block of the primal iterate in the full variable space. Under MadNLP's MakeParameter
# treatment of fixed variables the IPM primal does not contain the fixed columns; they are
# restored with MadNLP.unpack_x!.
function _full_x_block(solver::NCLSolver{T}, x::AbstractVector) where T
    n_full = NLPModels.get_nvar(solver.ncl.nlp)
    length(x) == n_full && return x
    ipm = solver.ipm
    xr = similar(x, n_full + solver.m)
    MadNLP.unpack_x!(xr, ipm.cb, MadNLP.variable(ipm.x))
    return @view xr[1:n_full]
end

function _is_solved(solver::NCLSolver{T}, x, du_feas::T, cc_feas::T, lcon_eps, ucon_eps) where T
    ipm = solver.ipm
    options = solver.options
    s_max = T(_SUCCESS_S_MAX)
    nzb = length(ipm.zl_r) + length(ipm.zu_r)
    dual_avg = (norm(ipm.y, 1) + norm(ipm.zl_r, 1) + norm(ipm.zu_r, 1)) / max(1, solver.m + nzb)
    bound_avg = (norm(ipm.zl_r, 1) + norm(ipm.zu_r, 1)) / max(1, nzb)
    s_d = max(s_max, dual_avg) / s_max
    s_c = max(s_max, bound_avg) / s_max
    pr_feas, viol = _primal_infeasibility(solver.ncl, _full_x_block(solver, x), lcon_eps, ucon_eps)
    return max(du_feas / s_d, cc_feas / s_c, pr_feas) <= options.opt_tol &&
           viol <= options.constr_viol_tol
end

#=
    Gain law
=#

# gain_law = :geometry. With wᵢ the squared norm of row i of the x-block of the scaled
# Jacobian at the last iterate, the target gain of row i is
#     tᵢ = clamp((1/wᵢ) / G, gain_clip...),   G = geometric mean of 1/wᵢ over the rows with a finite 1/wᵢ;
# a row with a non-finite 1/wᵢ keeps its current gain. The installed gains are tᵢ^α.
function _update_gains!(solver::NCLSolver{T}, ws::GainWorkspace{T}, α::T) where T
    ncl = solver.ncl
    m = ncl.nr
    m == 0 && return
    jac = MadNLP.get_jacobian(solver.ipm.kkt)
    copyto!(ws.jv, 1, jac, 1, length(ws.jv))
    fill!(ws.w, zero(T))
    @inbounds for k in eachindex(ws.jv)
        ws.w[ws.rows[k]] += ws.jv[k] * ws.jv[k]
    end
    copyto!(ws.gprev, ncl.γr)
    wmax = maximum(ws.w)
    if !(isfinite(wmax) && wmax > zero(T))
        fill!(ws.g, one(T))
    else
        nobs = 0
        μlog = zero(T)
        @inbounds for i in 1:m
            ws.obs[i] = isfinite(one(T) / ws.w[i])
            if ws.obs[i]
                μlog += log(one(T) / ws.w[i])
                nobs += 1
            end
        end
        lo, hi = solver.options.gain_clip
        if nobs == 0
            fill!(ws.g, one(T))
        else
            G = exp(μlog / nobs)
            @inbounds for i in 1:m
                ws.g[i] = ws.obs[i] ? clamp((one(T) / ws.w[i]) / G, lo, hi) : ws.gprev[i]
            end
        end
    end
    if α <= zero(T)
        fill!(ws.g, one(T))
    elseif α < one(T)
        @inbounds for i in 1:m
            ws.g[i] = ws.g[i]^α
        end
    end
    @inbounds for i in 1:m
        isfinite(ws.g[i]) && ws.g[i] > zero(T) ||
            error("non-finite or non-positive gain at row $i: $(ws.g[i])")
    end
    copyto!(ncl.γr, ws.g)
    return
end

# The same law on the device (the reductions run in a different order than on the host, so the
# two methods agree only up to round-off).
function _update_gains!(solver::NCLSolver{T}, ws::GainWorkspaceDevice{T}, α::T) where T
    ncl = solver.ncl
    m = ncl.nr
    m == 0 && return
    jac = MadNLP.get_jacobian(solver.ipm.kkt)
    nnz = length(ws.jv2)
    @views ws.jv2 .= jac[1:nnz] .^ 2
    mul!(ws.w, ws.S, ws.jv2)
    copyto!(ws.gprev, ncl.γr)
    wmax = maximum(ws.w)
    if !(isfinite(wmax) && wmax > zero(T))
        fill!(ws.obs, false)
        fill!(ws.g, one(T))
    else
        lo, hi = solver.options.gain_clip
        ws.obs .= isfinite.(one(T) ./ ws.w)
        nobs = Int(sum(ws.obs))
        if nobs == 0
            fill!(ws.g, one(T))
        else
            ws.logt .= ifelse.(ws.obs, log.(one(T) ./ ws.w), zero(T))
            G = exp(sum(ws.logt) / nobs)
            ws.g .= ifelse.(ws.obs, clamp.((one(T) ./ ws.w) ./ G, lo, hi), ws.gprev)
        end
    end
    if α <= zero(T)
        fill!(ws.g, one(T))
    elseif α < one(T)
        ws.g .= ws.g .^ α
    end
    (all(isfinite.(ws.g)) && all(ws.g .> zero(T))) ||
        error("non-finite or non-positive gain on the device gain path")
    copyto!(ncl.γr, ws.g)
    return
end

#=
    Outer loop
=#

function setup!(solver::MadNLP.MadNLPSolver{T}; μ=1e-1, tol=1e-8) where T
    barrier = solver.opt.barrier
    # Update options
    barrier.mu_init = μ
    solver.opt.tol = tol
    solver.mu = barrier.mu_init
    # Ensure the barrier parameter is fixed
    barrier.mu_min = barrier.mu_init

    # Refresh values
    solver.obj_val = MadNLP.eval_f_wrapper(solver, solver.x)
    MadNLP.eval_grad_f_wrapper!(solver, solver.f, solver.x)
    MadNLP.eval_cons_wrapper!(solver, solver.c, solver.x)

    # Update filter
    theta = MadNLP.get_theta(solver.c)
    solver.theta_max = T(1e4) * max(1,theta)
    solver.theta_min = T(1e-4) * max(1,theta)
    solver.tau = max(solver.opt.tau_min,one(T)-barrier.mu_init)
    empty!(solver.filter)
    push!(solver.filter, (solver.theta_max,-Inf))

    return MadNLP.REGULAR
end

# RHS for extrapolation step
function set_aug_rhs_extrapolation!(solver::NCLSolver, kkt::MadNLP.AbstractKKTSystem, μ)
    ipm = solver.ipm
    ncl = solver.ncl
    ρ = ncl.ρk[]

    n_ineq = length(ipm.ind_ineq)
    n, m = solver.n, solver.m

    # Variables
    px = @view primal(ipm.p)[1:n]
    fx = @view primal(ipm.f)[1:n]
    jaclx = @view ipm.jacl[1:n]
    zlx = @view primal(ipm.zl)[1:n]
    zux = @view primal(ipm.zu)[1:n]
    # Slacks
    ps = @view primal(ipm.p)[n+m+1:n+m+n_ineq]
    fs = @view primal(ipm.f)[n+m+1:n+m+n_ineq]
    jacls = @view ipm.jacl[n+m+1:n+m+n_ineq]
    zls = @view primal(ipm.zl)[n+m+1:n+m+n_ineq]
    zus = @view primal(ipm.zu)[n+m+1:n+m+n_ineq]
    # Regularization
    r = @view primal(ipm.x)[n+1:n+m]
    pr = @view primal(ipm.p)[n+1:n+m]

    py = dual(ipm.p)
    pzl = dual_lb(ipm.p)
    pzu = dual_ub(ipm.p)

    px .= .-fx .+ zlx .- zux .- jaclx
    # r-block: the penalty force γ φ'(−ρ r) (= −ρ r for the quadratic kernel with γ ≡ 1)
    pr .= ncl.γr .* dphi.(Ref(ncl.kernel), ncl.λr, .-(ρ .* r))
    ps .= .-fs .+ zls .- zus .- jacls
    py .= .-ipm.c
    pzl .= (ipm.xl_r .- ipm.x_lr) .* ipm.zl_r .+ μ
    pzu .= (ipm.xu_r .- ipm.x_ur) .* ipm.zu_r .- μ
    return
end


# N.B.: The extrapolation step is described in detail in:
# [1, Section 3.2] Armand, Paul, and Riadh Omheni.
#    "A mixed logarithmic barrier-augmented Lagrangian method for nonlinear optimization."
#    Journal of Optimization Theory and Applications 173.2 (2017): 523-547.
# [2, Algorithm 1] Armand, Paul, Joël Benoist, and Dominique Orban.
#    "From global to local convergence of interior methods for nonlinear optimization."
#    Optimization Methods and Software 28.5 (2013): 1051-1080.
function extrapolation!(solver::NCLSolver{T}) where T
    ipm = solver.ipm
    ρ = solver.ncl.ρk[]
    rho = solver.options.extrapolation_rho
    μk = ipm.mu
    μ_fac, μ_tau, μ_min = solver.options.mu_fac, solver.options.mu_tau, solver.options.mu_min

    # Evaluate model with new rho and mu.
    ipm.obj_val = MadNLP.eval_f_wrapper(ipm, ipm.x)
    MadNLP.eval_grad_f_wrapper!(ipm, ipm.f, ipm.x)
    MadNLP.eval_cons_wrapper!(ipm, ipm.c, ipm.x)
    MadNLP.eval_jac_wrapper!(ipm, ipm.kkt, ipm.x)
    MadNLP.jtprod!(ipm.jacl, ipm.kkt, ipm.y)
    MadNLP.eval_lag_hess_wrapper!(ipm, ipm.kkt, ipm.x, ipm.y)

    # Previous KKT residual is the norm of the RHS
    set_aug_rhs_extrapolation!(solver, ipm.kkt, μk)
    res_p = norm(ipm.p.values, Inf)

    # Update barrier for extrapolation step
    μp = max(min(μk^μ_tau, μ_fac * μk), μ_min)
    τ = max(T(0.995), one(T) - μp)

    # Solve KKT system
    MadNLP.set_aug_diagonal!(ipm.kkt, ipm)
    set_aug_rhs_extrapolation!(solver, ipm.kkt, μp)
    is_solved = MadNLP.inertia_correction!(ipm.inertia_corrector, ipm)

    # If the linear solver has failed, we leave the extrapolation step
    if !is_solved
        return (false, res_p)
    end

    # Fraction to boundary
    alpha_p = MadNLP.get_alpha_max(
        primal(ipm.x),
        primal(ipm.xl),
        primal(ipm.xu),
        primal(ipm.d),
        τ,
    )
    alpha_d = MadNLP.get_alpha_z(
        ipm.zl_r,
        ipm.zu_r,
        dual_lb(ipm.d),
        dual_ub(ipm.d),
        τ,
    )

    # Take full Newton step
    axpy!(alpha_p, primal(ipm.d), primal(ipm.x))
    axpy!(alpha_p, dual(ipm.d), ipm.y)
    ipm.zl_r .+= alpha_d .* dual_lb(ipm.d)
    ipm.zu_r .+= alpha_d .* dual_ub(ipm.d)

    # Update barrier term
    ipm.mu = μk + alpha_p * (μp - μk)

    # Update callbacks
    ipm.obj_val = MadNLP.eval_f_wrapper(ipm, ipm.x)
    MadNLP.eval_grad_f_wrapper!(ipm, ipm.f, ipm.x)
    MadNLP.eval_cons_wrapper!(ipm, ipm.c, ipm.x)
    MadNLP.eval_jac_wrapper!(ipm, ipm.kkt, ipm.x)
    MadNLP.jtprod!(ipm.jacl, ipm.kkt, ipm.y)

    # Compute KKT residual to check if crossover has succeeded
    set_aug_rhs_extrapolation!(solver, ipm.kkt, ipm.mu)
    res_k = norm(ipm.p.values, Inf)

    if res_k <= rho * res_p + T(10) * alpha_p^T(0.2) * μk
        return (true, res_k)
    else
        # If decrease is not sufficient, the solver does not take
        # the full step and we return to the previous iterate.
        ipm.mu = μk
        axpy!(-alpha_p, primal(ipm.d), primal(ipm.x))
        axpy!(-alpha_p, dual(ipm.d), ipm.y)
        ipm.zl_r .-= alpha_d .* dual_lb(ipm.d)
        ipm.zu_r .-= alpha_d .* dual_ub(ipm.d)
        # Refresh values in callback
        ipm.obj_val = MadNLP.eval_f_wrapper(ipm, ipm.x)
        MadNLP.eval_grad_f_wrapper!(ipm, ipm.f, ipm.x)
        MadNLP.eval_cons_wrapper!(ipm, ipm.c, ipm.x)
        return (false, res_p)
    end
end

"""
    solve!(solver::NCLSolver; diag=nothing)

Run the NCL outer loop and return an `NCLStats`. If `diag` is a vector, one record is pushed
per outer iteration: a `NamedTuple` with the fields `iter, rho, mu, pr_feas, eta, thr, ratio,
has_converged, extrapolated, branch, extrap_fact, inner_fact, inner_iters`, where `rho`, `mu`,
`eta` are the values in force during the iteration, `thr = max(eta, feas_tol)`, `ratio =
pr_feas / thr`, and `branch` is `:extrap`, `:mu_reduce`, `:rho_bump` or `:maxiter` (the inner
iteration budget ran out).
"""
function solve!(solver::NCLSolver{T}; diag=nothing) where T
    n, m = solver.n, solver.m
    ncl = solver.ncl
    ipm = solver.ipm
    options = solver.options

    options.verbose && _introduce(n, m)

    # Parameters
    ### Penalty ρ
    ncl.ρk[] = options.rho_init
    ρ_max = options.rho_max
    tau_ρ = T(10)
    ### Barrier parameters
    μ = options.mu_init
    μ_min = options.mu_min
    μ_fac = options.mu_fac
    τ = options.mu_tau
    ### Forcing parameters
    γ = T(0.05)
    eps_d = T(100)*μ^(one(T)+γ)
    η = T(0.1)   # initial primal feasibility tolerance
    ### Number of accepted subproblems (clock of the gain annealing)
    n_accepted = 0

    start_time = time()

    ncl_status = MadNLP.INITIAL

    # Unless the parameter `dual_initialized` is set to `true`,
    # MadNLP computes the initial multipliers y0 in `initialize!`.
    MadNLP.initialize!(ipm)
    lcon_eps, ucon_eps = _relaxed_con_bounds(ncl, ipm)
    # Update initial multiplier using multiplier computed by MadNLP in `initialize!`.
    ncl.yk .= ipm.y

    ipm.status = MadNLP.REGULAR

    x = view(MadNLP.primal(ipm.x), 1:n)
    r = view(MadNLP.primal(ipm.x), 1+n:n+m)

    pr_feas = ipm.inf_pr
    du_feas = get_inf_du(solver)

    is_extrapolated = false
    options.verbose && _log_header()
    flag = " "
    options.verbose && _log_iter(0, flag, 0, ipm.obj_val, pr_feas, du_feas, η, μ, ncl.ρk[])

    iter = 1
    while iter <= options.max_auglag_iter
        # Update parameters in MadNLP
        setup!(
            ipm;
            tol=eps_d,
            μ=μ,
        )

        nfact_start = ipm.cnt.factorization_cnt
        k_start = ipm.cnt.k
        if iter >= 2 && options.extrapolation
            is_extrapolated, delta = extrapolation!(solver)
            flag = is_extrapolated ? "+" : " "
        end
        nfact_extrap = ipm.cnt.factorization_cnt
        has_converged = false
        if !is_extrapolated
            status = MadNLP.regular!(ipm)
            if status == MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
                diag !== nothing && push!(diag, (iter=iter, rho=ncl.ρk[], mu=μ, pr_feas=T(NaN),
                    eta=η, thr=max(η, options.feas_tol), ratio=T(NaN), has_converged=false,
                    extrapolated=is_extrapolated, branch=:maxiter,
                    extrap_fact=nfact_extrap - nfact_start,
                    inner_fact=ipm.cnt.factorization_cnt - nfact_extrap,
                    inner_iters=ipm.cnt.k - k_start))
                ncl_status = MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
                break
            end
            has_converged = status == MadNLP.SOLVE_SUCCEEDED
            flag = has_converged ? " " : "r"
        end

        # Get KKT residuals for scaled problem
        pr_feas = norm(r, Inf)
        du_feas = MadNLP.get_inf_du(
            MadNLP.full(ipm.f), MadNLP.full(ipm.zl), MadNLP.full(ipm.zu), ipm.jacl, 1.0,
        )
        cc_feas = MadNLP.get_inf_compl(
            ipm.x_lr, ipm.xl_r, ipm.zl_r, ipm.xu_r, ipm.x_ur, ipm.zu_r, zero(T), one(T),
        )

        # Acceptance test
        thr = max(η, options.feas_tol)
        accepted = if options.gate_metric === :force
            # Penalty force, read from the stored gradient: ∂L/∂r = −yk − γ φ'(−ρ r).
            fr = view(MadNLP.primal(ipm.f), n+1:n+m)
            v_inf = m == 0 ? zero(T) : maximum(abs.(fr .+ ncl.yk))
            v_inf <= ncl.ρk[] * thr
        else
            pr_feas <= thr
        end
        rho_used, mu_used, eta_used = ncl.ρk[], μ, η

        # Update parameters
        if is_extrapolated
            ncl.yk .= ipm.y
            n_accepted += 1
            ncl.ρk[] = min(max(one(T) / delta, T(1.1) * ncl.ρk[]), ρ_max)
            μ = ipm.mu  # mu has been updated previously when computing extrapolation step
            branch = :extrap
        elseif accepted && has_converged
            ncl.yk .= ipm.y
            n_accepted += 1
            μ = max(min(μ^τ, μ_fac * μ), μ_min)
            branch = :mu_reduce
        else
            ncl.ρk[] = min(ncl.ρk[] * tau_ρ, ρ_max)
            branch = :rho_bump
        end

        diag !== nothing && push!(diag, (iter=iter, rho=rho_used, mu=mu_used, pr_feas=pr_feas,
            eta=eta_used, thr=thr, ratio=pr_feas / thr, has_converged=has_converged,
            extrapolated=is_extrapolated, branch=branch,
            extrap_fact=nfact_extrap - nfact_start,
            inner_fact=ipm.cnt.factorization_cnt - nfact_extrap,
            inner_iters=ipm.cnt.k - k_start))

        η = min(μ^T(1.1), T(0.1) * μ)
        eps_d = T(100) * μ^(one(T)+γ)

        # Log evolution
        ipm_iter = ipm.cnt.k
        obj_val = ipm.obj_val + dot(ncl.yk, r) - _penalty_obj(ncl, ncl.ρk[], r)
        options.verbose && _log_iter(iter, flag, ipm_iter, obj_val, pr_feas, du_feas, η, μ, ncl.ρk[])

        # Check convergence
        if _is_solved(solver, x, du_feas, cc_feas, lcon_eps, ucon_eps)
            ncl_status = MadNLP.SOLVE_SUCCEEDED
            break
        # Check infeasibility
        elseif (ncl.ρk[] >= options.rho_max) && (pr_feas > options.opt_tol)
            ncl_status = MadNLP.INFEASIBLE_PROBLEM_DETECTED
            break
        end

        # Refresh the gains for the next subproblem. Never after the last outer iteration, so
        # that the returned objective uses the gains of the subproblem actually solved.
        if options.gain_law === :geometry && iter < options.max_auglag_iter
            h = options.gain_anneal_horizon
            α = h <= zero(T) ? one(T) : clamp(T(n_accepted) / h, zero(T), one(T))
            _update_gains!(solver, solver.gainws, α)
        end

        iter += 1
    end

    # Budget exhausted (no status was set inside the loop)
    if (ncl_status == MadNLP.INITIAL) &&
       ((iter > options.max_auglag_iter) || (ipm.status == MadNLP.MAXIMUM_ITERATIONS_EXCEEDED))
        ncl_status = MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
    end

    ipm.cnt.total_time = time() - start_time

    return NCLStats(solver, ncl_status)
end

"""
    madncl(nlp; ncl_options=NCLOptions{T}(), kernel=QuadraticKernel(), ipm_options...)

Solve `nlp` with Algorithm NCL. See [`NCLSolver`](@ref) and [`NCLOptions`](@ref).
"""
function madncl(
    nlp::NLPModels.AbstractNLPModel;
    options...
)
    solver = NCLSolver(nlp; options...)
    return solve!(solver)
end
