# Trajectory capture / compare (identity gate N1).
#
#   capture: julia --project=benchmarks/envs/cpu gates/trajcap.jl capture <outdir>
#   compare: julia gates/trajcap.jl compare <dirA> <dirB>
#
# For every cell, the full solve in bit-exact form (Float64 as hex): final status, inner
# iterations, factorizations, objective, dual/primal residuals and solution; one line per outer
# iteration with the 13 fields of the `diag` record; and, for k = 1..K, the status and solution
# of the same solve truncated to k outer iterations.
#
# Cells (all at the frozen campaign constants, success test of this branch):
#   5 problems (HS15, HS6, HS7, HS26, HS77) x
#     {k2r (K2r + LDL), k1s (K1s + CHOLMOD)} x {T0 quadratic, T1 quadratic via the generic
#       kernel path, T2 arcsinh kernel a = 1e12}
#     {k2rldl (K2r + LDL), k2rma57 (K2r + MA57)} x {P power kernel p = 6, λ ≡ 1e-2;
#       PA = P with MadNLP acceptable_tol = 0; W = weight law + force gate}

using Printf
const MODE = ARGS[1]
MODE == "capture" && @eval using MadNCL, MadNLP, MadNLPHSL, NLPModels, CUTEst, LinearAlgebra

if MODE == "capture"

include(joinpath(@__DIR__, "..", "test", "hs15.jl"))
include(joinpath(@__DIR__, "kernels.jl"))
const OUT = ARGS[2]; mkpath(OUT)
println("pathof(MadNCL) = ", pathof(MadNCL))

hx(x::Float64) = string(reinterpret(UInt64, x), base=16)
hx(v::AbstractVector{Float64}) = join(hx.(v), ":")
const DIAG_FIELDS = (:iter, :rho, :mu, :pr_feas, :eta, :thr, :ratio, :has_converged,
                     :extrapolated, :branch, :extrap_fact, :inner_fact, :inner_iters)
diagline(d) = join([let v = getproperty(d, f); v isa Float64 ? hx(v) : string(v); end
                    for f in DIAG_FIELDS], ",")

# μ_min matched to the outer tolerance: (opt_tol / 100)^(1 / 1.05)
const MU_MIN = (1e-8 / 100)^(1 / 1.05)
@assert MU_MIN === 2.9935772947204935e-10
const FROZEN = (extrapolation=false, scaling_max_gradient=100.0, opt_tol=1e-8, feas_tol=1e-8,
                rho_max=1e14, mu_min=MU_MIN)
const W_KW = (weight_law=:geometry, weight_clip=(1e-30, 1e8), weight_anneal_horizon=6.0, gate_metric=:force)

function run_one(make_nlp, arm, cfg; maxouter=20)
    nlp = make_nlp()
    kernel = arm == "T1" ? ExactQuadKernel() : arm == "T2" ? AsinhKernel(1e12) :
             arm in ("P", "PA") ? MadNCL.PowerKernel(6.0, 0.01) : MadNCL.QuadraticKernel()
    extra = arm == "W" ? W_KW : NamedTuple()
    opts = MadNCL.NCLOptions{Float64}(; verbose=false, max_auglag_iter=maxouter, FROZEN..., extra...)
    kkt, ls, lskw = cfg in ("k2r", "k2rldl") ? (MadNCL.K2rAuglagKKTSystem, MadNLP.LDLSolver, NamedTuple()) :
                    cfg == "k2rma57" ? (MadNCL.K2rAuglagKKTSystem, MadNLPHSL.Ma57Solver, (ma57_automatic_scaling=true,)) :
                                       (MadNCL.K1sAuglagKKTSystem, MadNLP.CHOLMODSolver, NamedTuple())
    acc = arm == "PA" ? (acceptable_tol=0.0,) : NamedTuple()
    solver = MadNCL.NCLSolver(nlp; ncl_options=opts, kernel=kernel,
                              kkt_system=kkt, linear_solver=ls, lskw..., acc..., print_level=MadNLP.ERROR)
    d = Any[]
    stats = MadNCL.solve!(solver; diag=d)
    out = (diag=d, status=stats.status, x=copy(stats.solution), obj=stats.objective,
           du=stats.dual_feas, pr=stats.primal_feas, k=stats.iter,
           nfact=stats.counters.factorization_cnt)
    nlp isa CUTEstModel && finalize(nlp)
    return out
end

INSTANCES = [
    ("HS15",  () -> HS15Model()),
    ("HS6",   () -> CUTEstModel("HS6"; decode=false)),
    ("HS7",   () -> CUTEstModel("HS7"; decode=false)),
    ("HS26",  () -> CUTEstModel("HS26"; decode=false)),
    ("HS77",  () -> CUTEstModel("HS77"; decode=false)),
]
CELLS = vcat([(c, a) for c in ("k2r", "k1s") for a in ("T0", "T1", "T2")],
             [(c, a) for c in ("k2rldl", "k2rma57") for a in ("P", "PA", "W")])

for (cfg, aname) in CELLS, (iname, mk) in INSTANCES
    full = run_one(mk, aname, cfg)
    K = length(full.diag)
    open(joinpath(OUT, "$(iname)_$(cfg)_$(aname).txt"), "w") do io
        println(io, "# cell $iname $cfg $aname")
        println(io, "status=", full.status)
        println(io, "inner_total=", full.k)
        println(io, "nfact=", full.nfact)
        println(io, "obj=", hx(full.obj))
        println(io, "du=", hx(full.du))
        println(io, "pr=", hx(full.pr))
        println(io, "x=", hx(full.x))
        for (j, d) in enumerate(full.diag)
            println(io, "diag[$j]=", diagline(d))
        end
        for k in 1:K
            t = run_one(mk, aname, cfg; maxouter=k)
            println(io, "sweep[$k].status=", t.status)
            println(io, "sweep[$k].x=", hx(t.x))
        end
    end
    @printf("%s %s %s K=%d %s\n", iname, cfg, aname, K, full.status)
end
println("CAPTURE_DONE out=$OUT")

elseif MODE == "compare"

da, db = ARGS[2], ARGS[3]
files = sort(readdir(da))
sort(readdir(db)) == files || error("file sets differ")
ndiff = 0
for f in files
    global ndiff
    A = readlines(joinpath(da, f)); B = readlines(joinpath(db, f))
    A == B && continue
    ndiff += 1
    println("DIFF cell $f:")
    kA = Dict(split(l, "=", limit=2)[1] => l for l in A if !startswith(l, "#"))
    kB = Dict(split(l, "=", limit=2)[1] => l for l in B if !startswith(l, "#"))
    for key in sort(collect(union(keys(kA), keys(kB))))
        va, vb = get(kA, key, "<absent>"), get(kB, key, "<absent>")
        va != vb && println("   ", key, ": A={", va, "}  B={", vb, "}")
    end
end
println(ndiff == 0 ? "COMPARE_IDENTICAL ($(length(files)) cells)" :
        "COMPARE_DIFFS cells=$ndiff of $(length(files))")
end
