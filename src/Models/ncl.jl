#=
    NCLModel.

    Adapted from the NCLModel in: https://github.com/JuliaSmoothOptimizers/NCL.jl/blob/main/src/NCLModel.jl

=#

@doc raw"""
    NCLModel

Reformulate the nonlinear program
```
min_x        f(x)
subject to   c♭ ≤ c(x) ≤ c♯
             x ≥ 0

```
using a (γ,φ) augmented-Lagrangian formulation. For a given penalty ``ρ``, multiplier
estimate ``y_e``, per-row gains ``γ_i > 0`` and penalty kernel ``φ`` ([`AbstractKernel`](@ref)),
the NCL model writes
```
min_{x,r}    f(x) - y_eᵀ r + \sum_i \frac{γ_i}{ρ} φ_i(-ρ r_i)
subject to   c♭ ≤ c(x) + r ≤ c♯
             x ≥ 0

```
The quadratic kernel ``φ(t) = t²/2`` with ``γ ≡ 1`` gives the classical penalty
``\frac{ρ}{2}\|r\|^2``.

Per-row data (vectors aligned with ``r``, on the same device as the model):
- `γr`: the gains ``γ_i`` (default 1). They multiply the penalty only, never the ``-y_eᵀ r`` term.
- `λr`: the kernel parameters ``λ_i`` (see [`PowerKernel`](@ref); ignored by [`QuadraticKernel`](@ref)).
"""
struct NCLModel{T, VT, M, K} <: NLPModels.AbstractNLPModel{T, VT}
    nlp::M
    kernel::K
    nx::Int
    nr::Int
    meta::NLPModels.NLPModelMeta{T, VT}
    counters::NLPModels.Counters
    yk::VT
    ρk::Base.RefValue{T}
    λr::VT
    γr::VT
end

function NCLModel(
    nlp::NLPModels.AbstractNLPModel{T, VT};
    resid::T=zero(T),
    ρ::T=one(T),
    kernel::AbstractKernel=QuadraticKernel(),
) where {T, VT}

    nx = NLPModels.get_nvar(nlp)
    nr = NLPModels.get_ncon(nlp)
    nvar = nx + nr

    y = fill!(similar(VT, nr), one(T))

    lvarx = NLPModels.get_lvar(nlp)
    uvarx = NLPModels.get_uvar(nlp)

    lvarr = fill!(similar(VT, nr), -Inf)
    uvarr = fill!(similar(VT, nr),  Inf)

    x0 = NLPModels.get_x0(nlp)
    r0 = fill!(similar(VT, nr), resid)

    meta = NLPModels.NLPModelMeta{T, VT}(
        nvar;
        lvar=vcat(lvarx, lvarr),
        uvar=vcat(uvarx, uvarr),
        x0=vcat(x0, r0),
        y0=NLPModels.get_y0(nlp),
        nnzj=NLPModels.get_nnzj(nlp) + nr,
        nnzh=NLPModels.get_nnzh(nlp) + nr,
        ncon=nr,
        lcon=NLPModels.get_lcon(nlp),
        ucon=NLPModels.get_ucon(nlp),
        minimize=true,
    )
    cnt = NLPModels.Counters()

    λr = fill!(similar(VT, nr), initial_parameter(kernel, T))
    γr = fill!(similar(VT, nr), one(T))

    return NCLModel{T, VT, typeof(nlp), typeof(kernel)}(
        nlp, kernel, nx, nr, meta, cnt, y, Ref{T}(ρ), λr, γr,
    )
end

# Penalty term Σᵢ (γᵢ/ρ) φᵢ(−ρ rᵢ). The per-row values are reduced with a sequential left fold
# (`mapreduce(identity, +, ·; init)`), and the division by ρ comes after the sum.
@inline function _penalty_obj(kernel::AbstractKernel, γ, λ, ρ::T, r) where {T}
    return mapreduce(identity, +, γ .* phi.(Ref(kernel), λ, .-(ρ .* r)); init=zero(T)) / ρ
end
# Quadratic kernel: closed form (ρ/2) Σᵢ γᵢ rᵢ².
@inline _penalty_obj(::QuadraticKernel, γ, λ, ρ::T, r) where {T} = ρ * dot(γ .* r, r) / T(2)
@inline _penalty_obj(ncl::NCLModel, ρ, r) = _penalty_obj(ncl.kernel, ncl.γr, ncl.λr, ρ, r)

set_barrier!(ncl::NCLModel, μ) = nothing

function NLPModels.obj(ncl::NCLModel{T, VT}, xr::VT) where {T, VT <: AbstractVector{T}}
    sense = NLPModels.get_minimize(ncl.nlp) ? T(1) : T(-1)
    x = view(xr, 1:ncl.nx)
    r = view(xr, 1+ncl.nx:ncl.nx+ncl.nr)
    obj_val = NLPModels.obj(ncl.nlp, x)
    obj_res = -dot(ncl.yk, r) + _penalty_obj(ncl, ncl.ρk[], r)
    return sense * obj_val + obj_res
end

function NLPModels.cons!(ncl::NCLModel{T, VT}, xr::VT, cx::VT) where {T, VT <: AbstractVector{T}}
    x = view(xr, 1:ncl.nx)
    r = view(xr, 1+ncl.nx:ncl.nx+ncl.nr)
    NLPModels.cons!(ncl.nlp, x, cx)
    axpy!(one(T), r, cx)
    return cx
end

function NLPModels.grad!(ncl::NCLModel{T, VT}, xr::VT, gxr::VT) where {T, VT <: AbstractVector{T}}
    sense = NLPModels.get_minimize(ncl.nlp) ? T(1) : T(-1)
    x = view(xr, 1:ncl.nx)
    r = view(xr, 1+ncl.nx:ncl.nx+ncl.nr)
    gx = view(gxr, 1:ncl.nx)
    gr = view(gxr, 1+ncl.nx:ncl.nx+ncl.nr)
    NLPModels.grad!(ncl.nlp, x, gx)
    gx .*= sense
    # ∂P/∂rᵢ = −γᵢ φᵢ'(−ρ rᵢ)
    ρ = ncl.ρk[]
    gr .= .-ncl.yk .- ncl.γr .* dphi.(Ref(ncl.kernel), ncl.λr, .-(ρ .* r))
    return gxr
end

function NLPModels.jprod!(ncl::NCLModel{T, VT}, xr::VT, v::VT, Jv::VT) where {T, VT <: AbstractVector{T}}
    x = view(xr, 1:ncl.nx)
    vx = view(v, 1:ncl.nx)
    vr = view(v, 1+ncl.nx:ncl.nx+ncl.nr)
    NLPModels.jprod!(ncl.nlp, x, vx, Jv)
    axpy!(one(T), vr, Jv)
    return Jv
end

function NLPModels.jtprod!(ncl::NCLModel{T, VT}, xr::VT, v::VT, Jtv::VT) where {T, VT <: AbstractVector{T}}
    x = view(xr, 1:ncl.nx)
    Jtvx = view(Jtv, 1:ncl.nx)
    Jtvr = view(Jtv, 1+ncl.nx:ncl.nx+ncl.nr)
    NLPModels.jtprod!(ncl.nlp, x, v, Jtvx)
    Jtvr .= v
    return Jtv
end

function NLPModels.jac_structure!(ncl::NCLModel, jrows::VI, jcols::VI) where {VI <: AbstractVector{Int}}
    m, n = NLPModels.get_ncon(ncl), NLPModels.get_nvar(ncl)
    nnjx = NLPModels.get_nnzj(ncl.nlp)
    nnjxr = NLPModels.get_nnzj(ncl)
    jrowsx = view(jrows, 1:nnjx)
    jcolsx = view(jcols, 1:nnjx)
    NLPModels.jac_structure!(ncl.nlp, jrowsx, jcolsx)
    jrows[nnjx+1:nnjxr] .= 1:m
    jcols[nnjx+1:nnjxr] .= ncl.nx+1:n
    return (jrows, jcols)
end

function NLPModels.jac_coord!(ncl::NCLModel{T, VT}, xr::VT, jac::VT) where {T, VT <: AbstractVector{T}}
    nnjx = NLPModels.get_nnzj(ncl.nlp)
    nnjr = NLPModels.get_nnzj(ncl)
    x = view(xr, 1:ncl.nx)
    jacx = view(jac, 1:nnjx)
    NLPModels.jac_coord!(ncl.nlp, x, jacx)
    jac[nnjx+1:nnjr] .= one(T)
    return jac
end

function NLPModels.hess_structure!(ncl::NCLModel, hrows::VI, hcols::VI) where {VI <: AbstractVector{Int}}
    n = NLPModels.get_nvar(ncl)
    nnzhx = NLPModels.get_nnzh(ncl.nlp)
    nnzhxr = NLPModels.get_nnzh(ncl)
    hrowsx = view(hrows, 1:nnzhx)
    hcolsx = view(hcols, 1:nnzhx)
    NLPModels.hess_structure!(ncl.nlp, hrowsx, hcolsx)
    hrows[nnzhx+1:nnzhxr] .= ncl.nx+1:n
    hcols[nnzhx+1:nnzhxr] .= ncl.nx+1:n
    return (hrows, hcols)
end

function NLPModels.hess_coord!(
    ncl::NCLModel{T, VT},
    xr::AbstractVector{T},
    y::AbstractVector{T},
    hess::AbstractVector{T};
    obj_weight::T=one(T),
) where {T, VT <: AbstractVector{T}}
    sense = NLPModels.get_minimize(ncl.nlp) ? T(1) : T(-1)
    nnzhx = NLPModels.get_nnzh(ncl.nlp)
    nnzhxr = NLPModels.get_nnzh(ncl)
    x = view(xr, 1:ncl.nx)
    hessx = view(hess, 1:nnzhx)
    NLPModels.hess_coord!(ncl.nlp, x, y, hessx; obj_weight=sense * obj_weight)
    # Penalty curvature Dᵢ = γᵢ ρ φᵢ''(−ρ rᵢ): the only block of the KKT system that depends on
    # the kernel. The KKT systems read it back from this slice of the Hessian.
    r = view(xr, ncl.nx+1:ncl.nx+ncl.nr)
    hpen = view(hess, nnzhx+1:nnzhxr)
    ρ = ncl.ρk[]
    hpen .= ncl.γr .* ρ .* ddphi.(Ref(ncl.kernel), ncl.λr, .-(ρ .* r))
    return hess
end

