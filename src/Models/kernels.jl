#=
    Penalty kernels for (γ,φ)-NCL.

    The NCL subproblem penalizes the residual r with

        P(r) = Σᵢ (γᵢ/ρ) φᵢ(−ρ rᵢ),

    where ρ > 0 is the penalty parameter, γᵢ > 0 a per-row weight and φᵢ a per-row penalty
    kernel. The derivatives that enter the inner interior-point solve are

        ∂P/∂rᵢ   = −γᵢ φᵢ'(−ρ rᵢ)          (the penalty force),
        ∂²P/∂rᵢ² =  γᵢ ρ φᵢ''(−ρ rᵢ)        (the penalty curvature, > 0).

    The quadratic kernel φ(t) = t²/2 with γ ≡ 1 gives the classical augmented-Lagrangian
    penalty (ρ/2)‖r‖² of MadNCL. Only the diagonal curvature block changes between kernels,
    so the custom KKT systems in `src/KKT/` need no kernel-specific code.
=#

"""
    AbstractKernel

Penalty kernel of the NCL subproblem. A concrete kernel `k` implements the three scalar forms

    phi(k, λ, t), dphi(k, λ, t), ddphi(k, λ, t)

(= ``φ(t)``, ``φ'(t)``, ``φ''(t)``) where `λ` is the row's kernel parameter, read from the
per-row vector `NCLModel.λr` (kernels without a per-row parameter ignore it). Every kernel
must satisfy ``φ(0) = 0``, ``φ'(0) = 0``, ``φ''(0) = 1`` and ``φ'' > 0``.

The kernel value is broadcast as `Ref(kernel)` together with the device arrays `λr` and `γr`,
so a concrete kernel must be an isbits struct (no arrays inside it).
"""
abstract type AbstractKernel end

"""
    QuadraticKernel <: AbstractKernel

``φ(t) = t²/2``: the classical augmented-Lagrangian penalty of MadNCL. The kernel parameter
is ignored. The penalty objective uses the closed form ``(ρ/2) Σᵢ γᵢ rᵢ²``.
"""
struct QuadraticKernel <: AbstractKernel end
@inline phi(::QuadraticKernel, λ, t::T) where {T} = t * t / T(2)
@inline dphi(::QuadraticKernel, λ, t::T) where {T} = t
@inline ddphi(::QuadraticKernel, λ, t::T) where {T} = one(T)

"""
    PowerKernel{T} <: AbstractKernel
    PowerKernel(p=6.0, λ=0.0)

Quadratic-plus-power kernel with a per-row weight ``λᵢ ≥ 0`` on the power term:

```math
φᵢ(t) = \\tfrac12 t² + \\tfrac{λᵢ}{p}|t|^p,\\quad
φᵢ'(t) = t + λᵢ\\,\\mathrm{sign}(t)|t|^{p-1},\\quad
φᵢ''(t) = 1 + λᵢ(p-1)|t|^{p-2},
```

with ``p > 2``. The per-row weights live in `NCLModel.λr`; `λ` is the value every row
receives when the model is built (set `ncl.λr` afterwards for row-dependent weights).
A row with ``λᵢ = 0`` is exactly quadratic, even where ``|t|^{p-2}`` overflows.
"""
struct PowerKernel{T} <: AbstractKernel
    p::T
    λ::T
end
PowerKernel(p::Real=6.0, λ::Real=0.0) = PowerKernel{Float64}(Float64(p), Float64(λ))
@inline function phi(k::PowerKernel, λ::T, t::T) where {T}
    p = T(k.p)
    q = t * t / T(2)
    return ifelse(λ == zero(T), q, q + λ * abs(t)^p / p)
end
@inline function dphi(k::PowerKernel, λ::T, t::T) where {T}
    p = T(k.p)
    return ifelse(λ == zero(T), t, t + λ * sign(t) * abs(t)^(p - one(T)))
end
@inline function ddphi(k::PowerKernel, λ::T, t::T) where {T}
    p = T(k.p)
    return ifelse(λ == zero(T), one(T), one(T) + λ * (p - one(T)) * abs(t)^(p - T(2)))
end

# Value written into every entry of `NCLModel.λr` when the model is built.
initial_parameter(::AbstractKernel, ::Type{T}) where {T} = zero(T)
initial_parameter(k::PowerKernel, ::Type{T}) where {T} = T(k.λ)
