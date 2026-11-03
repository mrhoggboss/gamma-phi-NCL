# Stock configurations on small CUTEst problems (gate N4): the MadNCL option sets with the K2r dual-regularization
# fold switched off, written in the format of the comparator tree's per-outer log, for a bitwise comparison against
# upstream MadNCL (+ the success test of this branch).
#   run:     julia --project=gates/env gates/stock_hs.jl run <outdir> [fold_on]
#            (fold_on: keep the K2r fold switched on — a control: cells that change carry δc ≠ 0)
#   compare: julia gates/stock_hs.jl compare <refdir> <outdir>
# Option sets: STOCK = tolerance 1e-8; S = STOCK + scaling_max_gradient 100 (MadNCL); PIN = MadNCL + parameters.
# Per outer iteration: iter, branch (E extrapolation, M multiplier update, R penalty increase, X inner budget),
# μ and ρ after the update, ‖r‖∞, inner iterations, cumulative factorizations.
using Printf
const MODE = ARGS[1]
hx(x::Float64) = string(reinterpret(UInt64, x), base=16)
hx(v::AbstractVector{Float64}) = join(hx.(v), ":")

if MODE == "run"
@eval using MadNCL, MadNLP, NLPModels, CUTEst, LinearAlgebra
include(joinpath(@__DIR__, "..", "test", "hs15.jl"))
const OUT = ARGS[2]; mkpath(OUT)
const FOLD = length(ARGS) >= 3 && ARGS[3] == "fold_on"
println("pathof(MadNCL) = ", pathof(MadNCL), " fold_dual_regularization=", FOLD)
const MUSTAR = (1e-8 / 100)^(1 / 1.05)
const OPTSETS = [
    ("STOCK", (opt_tol=1e-8, feas_tol=1e-8)),
    ("S",     (opt_tol=1e-8, feas_tol=1e-8, scaling_max_gradient=100.0)),
    ("PIN",   (opt_tol=1e-8, feas_tol=1e-8, max_auglag_iter=40, rho_max=1e14, scaling_max_gradient=100.0, mu_min=MUSTAR)),
]
INSTANCES = [("HS15", () -> HS15Model()), ("HS6", () -> CUTEstModel("HS6"; decode=false)), ("HS7", () -> CUTEstModel("HS7"; decode=false)),
             ("HS26", () -> CUTEstModel("HS26"; decode=false)), ("HS77", () -> CUTEstModel("HS77"; decode=false))]
letter = Dict(:extrap => 'E', :mu_reduce => 'M', :rho_bump => 'R', :maxiter => 'X')
for (oname, okw) in OPTSETS, cfg in (:k2r, :k1s), (iname, mk) in INSTANCES
    nlp = mk()
    opts = MadNCL.NCLOptions{Float64}(; verbose=false, fold_dual_regularization=FOLD, okw...)
    kkt, ls = cfg === :k2r ? (MadNCL.K2rAuglagKKTSystem, MadNLP.LDLSolver) :
                             (MadNCL.K1sAuglagKKTSystem, MadNLP.CHOLMODSolver)
    slv = MadNCL.NCLSolver(nlp; ncl_options=opts, kkt_system=kkt, linear_solver=ls, print_level=MadNLP.ERROR)
    dg = Any[]
    s = MadNCL.solve!(slv; diag=dg)
    nf = s.counters.factorization_cnt
    fact = [d.extrap_fact + d.inner_fact for d in dg]
    open(joinpath(OUT, "$(oname)_$(iname)_$(cfg).txt"), "w") do io
        println(io, "status=", s.status); println(io, "iter=", s.iter)
        println(io, "nfact=", nf); println(io, "x=", hx(Vector{Float64}(s.solution)))
        println(io, "obj=", hx(Float64(s.objective)))
        println(io, "n_outer=", length(dg))
        for (j, d) in enumerate(dg)
            b = letter[d.branch]
            mu = b == 'X' ? hx(d.mu) : (j < length(dg) ? hx(dg[j+1].mu) : "?")
            rho = b == 'X' ? hx(d.rho) : (j < length(dg) ? hx(dg[j+1].rho) : hx(slv.ncl.ρk[]))
            println(io, "outer[$j]=", d.iter, ",", b, ",", mu, ",", rho, ",", b == 'X' ? "?" : hx(d.pr_feas), ",",
                    d.inner_iters, ",", nf - sum(fact[j+1:end]; init=0))
        end
    end
    @printf("%s %-5s %s n_outer=%2d %-28s inner=%4d nfact=%4d\n", oname, iname, cfg, length(dg), string(s.status), s.iter, nf)
    nlp isa CUTEstModel && finalize(nlp)
end
println("STOCK_HS_DONE out=$OUT")

elseif MODE == "compare"
# '?' (μ after the last update, unknown from the diag records) matches anything.
da, db = ARGS[2], ARGS[3]
files = sort(readdir(da)); sort(readdir(db)) == files || error("file sets differ")
ndiff = 0
for f in files
    global ndiff
    A = readlines(joinpath(da, f)); B = readlines(joinpath(db, f))
    bad = length(A) != length(B)
    for (a, b) in zip(A, B)
        a == b && continue
        if startswith(a, "outer[") && startswith(b, "outer[")
            fa, fb = split(a, ","), split(b, ",")
            length(fa) == length(fb) && all(fa[i] == fb[i] || fa[i] == "?" || fb[i] == "?" for i in eachindex(fa)) && continue
        end
        bad = true
        println("DIFF $f:\n   A=$(first(a, 160))\n   B=$(first(b, 160))")
    end
    ndiff += bad
end
println(ndiff == 0 ? "STOCK_HS_COMPARE_IDENTICAL ($(length(files)) cells)" : "STOCK_HS_COMPARE_DIFFS cells=$ndiff of $(length(files))")
end
