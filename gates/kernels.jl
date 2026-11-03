# Kernels used by the identity gates, defined through the public kernel interface
# (subtypes of MadNCL.AbstractKernel implementing phi/dphi/ddphi(k, λ, t)).

# The quadratic kernel as a distinct type: runs the generic kernel path (the penalty objective is
# the left-fold sum instead of the closed form).
struct ExactQuadKernel <: MadNCL.AbstractKernel end
MadNCL.phi(::ExactQuadKernel, λ, t::T) where {T} = t * t / T(2)
MadNCL.dphi(::ExactQuadKernel, λ, t::T) where {T} = t
MadNCL.ddphi(::ExactQuadKernel, λ, t::T) where {T} = one(T)

# Arcsinh kernel phi_a(t) = a (t asinh(t/a) - sqrt(t^2 + a^2) + a), in the cancellation-free form
# a t asinh(t/a) - a t^2 / (sqrt(t^2 + a^2) + a); a -> Inf is the quadratic limit.
struct AsinhKernel{T} <: MadNCL.AbstractKernel
    a::T
end
AsinhKernel(a::Real=1.0) = AsinhKernel{Float64}(Float64(a))
@inline function MadNCL.phi(k::AsinhKernel, λ, t::T) where {T}
    a = T(k.a)
    return a * t * asinh(t / a) - a * (t * t) / (sqrt(t * t + a * a) + a)
end
@inline MadNCL.dphi(k::AsinhKernel, λ, t::T) where {T} = (a = T(k.a); a * asinh(t / a))
@inline MadNCL.ddphi(k::AsinhKernel, λ, t::T) where {T} = (a = T(k.a); a / sqrt(a * a + t * t))
