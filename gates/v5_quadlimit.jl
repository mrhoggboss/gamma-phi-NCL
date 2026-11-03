# V5: quadratic-limit gate.
#   T0: QuadraticKernel (closed-form penalty objective)
#   T1: ExactQuadKernel — the quadratic kernel through the generic kernel path
#   T2: a kernel family at its quadratic limit: AsinhKernel(1e12) (default) or, with the argument
#       `srcpow`, PowerKernel(6, λ = 0)
# T1 must reproduce T0 bitwise (status, outer and inner iterations, every per-outer iterate);
# T2 is reported as a drift profile (thresholds as in the research fork's verification/v5_quadlimit.jl).
# Per-outer iterates come from budget-truncated solves (max_auglag_iter = k); their diag records
# must be a prefix of the full solve's records.
#   julia --project=benchmarks/envs/cpu gates/v5_quadlimit.jl [srcpow]
using MadNCL, MadNLP, NLPModels, CUTEst, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "hs15.jl"))
include(joinpath(@__DIR__, "kernels.jl"))
println("pathof(MadNCL) = ", pathof(MadNCL))

const LEG = "srcpow" in ARGS ? "srcpow" : "asinh"
const OUTDIR = joinpath(@__DIR__, "out", "v5_$(LEG)"); mkpath(OUTDIR)
const MU_MIN = (1e-8 / 100)^(1 / 1.05)
const FROZEN = (extrapolation=false, scaling_max_gradient=100.0, opt_tol=1e-8, feas_tol=1e-8,
                rho_max=1e14, mu_min=MU_MIN, max_auglag_iter=20)

function cviol(nlp, x)
    m = NLPModels.get_ncon(nlp)
    m == 0 && return 0.0
    c = NLPModels.cons(nlp, x)
    lc, uc = NLPModels.get_lcon(nlp), NLPModels.get_ucon(nlp)
    return maximum(max.(lc .- c, c .- uc, 0.0))
end

function run_arm(make_nlp, kernel; maxouter=FROZEN.max_auglag_iter, diag=nothing, cfg=:k2r)
    nlp = make_nlp()
    opts = MadNCL.NCLOptions{Float64}(; verbose=false, FROZEN..., max_auglag_iter=maxouter)
    kkt, ls = cfg === :k2r ? (MadNCL.K2rAuglagKKTSystem, MadNLP.LDLSolver) :
                             (MadNCL.K1sAuglagKKTSystem, MadNLP.CHOLMODSolver)
    solver = MadNCL.NCLSolver(nlp; ncl_options=opts, kernel=kernel,
                              kkt_system=kkt, linear_solver=ls, print_level=MadNLP.ERROR)
    stats = MadNCL.solve!(solver; diag=diag)
    out = (status=stats.status, x=copy(stats.solution), obj=stats.objective,
           inner_total=stats.iter, cv=cviol(nlp, stats.solution))
    nlp isa CUTEstModel && finalize(nlp)
    return out
end

relx(a, b) = norm(a .- b, Inf) / max(1.0, norm(b, Inf))

T2K = LEG == "srcpow" ? MadNCL.PowerKernel(6.0, 0.0) : AsinhKernel(1e12)
ARMS = [("T0", MadNCL.QuadraticKernel()), ("T1", ExactQuadKernel()), ("T2", T2K)]
INSTANCES = [
    ("HS15",  () -> HS15Model()),
    ("HS6",   () -> CUTEstModel("HS6"; decode=false)),
    ("HS7",   () -> CUTEstModel("HS7"; decode=false)),
    ("HS26",  () -> CUTEstModel("HS26"; decode=false)),
    ("HS77",  () -> CUTEstModel("HS77"; decode=false)),
]

summary = []
for cfg in (:k2r, :k1s), (iname, make_nlp) in INSTANCES
    full = Dict(); diags = Dict()
    for (aname, kernel) in ARMS
        d = Any[]
        full[aname] = run_arm(make_nlp, kernel; diag=d, cfg=cfg)
        diags[aname] = d
    end
    K = length(diags["T0"])
    xs = Dict(a => Vector{Vector{Float64}}() for (a, _) in ARMS)
    objs = Dict(a => Float64[] for (a, _) in ARMS)
    cvs = Dict(a => Float64[] for (a, _) in ARMS)
    prefix_ok = true
    for k in 1:K, (aname, kernel) in ARMS
        d = Any[]
        res = run_arm(make_nlp, kernel; maxouter=k, diag=d, cfg=cfg)
        push!(xs[aname], res.x); push!(objs[aname], res.obj); push!(cvs[aname], res.cv)
        for j in 1:min(length(d), k, length(diags[aname]))
            prefix_ok &= isequal(d[j], diags[aname][j])
        end
    end
    open(joinpath(OUTDIR, "quadlimit_$(iname)_$(cfg).csv"), "w") do io
        println(io, "outer,relx_T1_T0,relx_T2_T0,cinf_T0,cinf_T1,cinf_T2,obj_T0,obj_T1,obj_T2,inner_T0,inner_T1,inner_T2,branch_T0")
        for k in 1:K
            it(a) = k <= length(diags[a]) ? diags[a][k].inner_iters : -1
            println(io, join([k, relx(xs["T1"][k], xs["T0"][k]), relx(xs["T2"][k], xs["T0"][k]),
                              cvs["T0"][k], cvs["T1"][k], cvs["T2"][k],
                              objs["T0"][k], objs["T1"][k], objs["T2"][k],
                              it("T0"), it("T1"), it("T2"), diags["T0"][k].branch], ","))
        end
    end
    t1_bitwise = all(xs["T1"][k] == xs["T0"][k] for k in 1:K) &&
                 isequal(diags["T1"], diags["T0"]) && full["T1"].x == full["T0"].x
    r2 = maximum(relx(xs["T2"][k], xs["T0"][k]) for k in 1:K)
    outer_match = length(diags["T0"]) == length(diags["T1"]) == length(diags["T2"])
    inner_match = full["T0"].inner_total == full["T1"].inner_total == full["T2"].inner_total
    status_match = full["T0"].status == full["T1"].status == full["T2"].status
    obj_gap2 = abs(full["T2"].obj - full["T0"].obj) / max(1, abs(full["T0"].obj))
    cv_gap2 = abs(full["T2"].cv - full["T0"].cv)
    pass = t1_bitwise && outer_match && inner_match && status_match && prefix_ok &&
           r2 <= 1e-6 && obj_gap2 <= 1e-8 && cv_gap2 <= 1e-8
    push!(summary, (cfg=cfg, inst=iname, K=K, t1_bitwise=t1_bitwise, outer_match=outer_match,
                    inner_match=inner_match, status_match=status_match, prefix_ok=prefix_ok,
                    max_relx_T2=r2, obj_gap_T2=obj_gap2, cv_gap_T2=cv_gap2,
                    status=full["T0"].status, inner=full["T0"].inner_total, pass=pass))
    @printf("%-5s %-5s K=%2d T1bitwise=%s outer=%s inner=%s status=%s prefix=%s relxT2=%.2e objgapT2=%.2e cvgapT2=%.2e %s %d => %s\n",
            cfg, iname, K, t1_bitwise, outer_match, inner_match, status_match, prefix_ok, r2,
            obj_gap2, cv_gap2, full["T0"].status, full["T0"].inner_total, pass ? "PASS" : "FAIL")
end
open(joinpath(OUTDIR, "quadlimit_summary.csv"), "w") do io
    println(io, "cfg,instance,K_outer,t1_bitwise,outer_match,inner_match,status_match,prefix_ok,max_relx_T2,obj_gap_T2,cv_gap_T2,status_T0,inner_total_T0,pass")
    for s in summary
        println(io, join(values(s), ","))
    end
end
println(all(s -> s.pass, summary) ? "V5_QUADLIMIT ($LEG): PASS" : "V5_QUADLIMIT ($LEG): FAIL")
