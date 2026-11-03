# SCOPF CPU gate (N2): one SCOPF-as-MPCC instance on the CPU (ExaModels CPU backend, K2r + MadNLP LDLSolver),
# one arm, written in a canonical form; `compare` checks it against the research fork / comparator-tree run.
#
#   run:     julia +1.11.2 --project=gates/env_scopf gates/scopf_cpu.jl run <arm> <out.txt> <data_dir> [case] [K]
#   compare: julia gates/scopf_cpu.jl compare <ref.txt> <public.txt>
#
# Arms: U6A  power kernel p = 6, λ ≡ 1e-2, MadNLP acceptable_tol = 0
#       W    (γ,φ)-MadNCL: gain law + force gate
#       S    MadNCL (upstream constants; tolerance 1e-8, scaling_max_gradient 100), δc fold off
#       SP   MadNCL + parameters (S with μ_min = μ*, 40 outer iterations, ρ_max = 1e14)
# Model: scopf_model(<data_dir>/<case>.m, CONTINGENCIES[case][1:K]; adjust=:mpecdroop, voltage_control=:pvpq,
#        tau_relax=0, scale_obj=1e-4, scale_cc=1.0), ExaModel(...; prod=true) on the CPU.
using Printf
const MODE = ARGS[1]
hx(x::Float64) = string(reinterpret(UInt64, x), base=16)

if MODE == "run"

@eval using MadNCL, MadNLP, ExaModels, NLPModels
include(joinpath(@__DIR__, "scopf", "scopf_model.jl"))
include(joinpath(@__DIR__, "scopf", "contingencies.jl"))
const ARM = ARGS[2]; const OUT = ARGS[3]; const DATA = ARGS[4]
const CASE = length(ARGS) >= 5 ? ARGS[5] : "case118"
const K = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 10
const MUSTAR = (1e-8 / 100)^(1 / 1.05)
println("pathof(MadNCL) = ", pathof(MadNCL)); flush(stdout)

jm = scopf_model(joinpath(DATA, CASE * ".m"), CONTINGENCIES[CASE][1:K]; adjust=:mpecdroop, voltage_control=:pvpq,
                 tau_relax=0.0, scale_obj=1e-4, scale_cc=1.0)
model = ExaModels.ExaModel(jm; prod=true)
println("model nvar=$(NLPModels.get_nvar(model)) ncon=$(NLPModels.get_ncon(model))"); flush(stdout)
IPM = (kkt_system=MadNCL.K2rAuglagKKTSystem, linear_solver=MadNLP.LDLSolver, max_iter=3000,
       richardson_tol=1e-12, richardson_max_iter=20, print_level=MadNLP.ERROR)
FROZEN = (verbose=false, opt_tol=1e-8, feas_tol=1e-8, max_auglag_iter=40, scaling_max_gradient=100.0,
          mu_min=MUSTAR, rho_max=1e14, extrapolation=false)
kernel, opt, ipm_kw = if ARM == "U6A"
    (MadNCL.PowerKernel(6.0, 1e-2), MadNCL.NCLOptions{Float64}(; FROZEN...), (acceptable_tol=0.0,))
elseif ARM == "W"
    (MadNCL.QuadraticKernel(), MadNCL.NCLOptions{Float64}(; FROZEN..., gain_law=:geometry, gain_clip=(1e-30, 1e8),
        gain_anneal_horizon=6.0, gate_metric=:force), NamedTuple())
elseif ARM == "S"
    (MadNCL.QuadraticKernel(), MadNCL.NCLOptions{Float64}(; verbose=false, opt_tol=1e-8, feas_tol=1e-8,
        scaling_max_gradient=100.0, fold_dual_regularization=false), NamedTuple())
elseif ARM == "SP"
    (MadNCL.QuadraticKernel(), MadNCL.NCLOptions{Float64}(; verbose=false, opt_tol=1e-8, feas_tol=1e-8,
        scaling_max_gradient=100.0, mu_min=MUSTAR, max_auglag_iter=40, rho_max=1e14,
        fold_dual_regularization=false), NamedTuple())
else
    error("unknown arm $ARM")
end
println("NCLOPTS ", join(["$(f)=$(getfield(opt, f))" for f in fieldnames(typeof(opt))], " "))
slv = MadNCL.NCLSolver(model; ncl_options=opt, kernel=kernel, IPM..., ipm_kw...)
println("IPMOPTS bound_relax_factor=$(slv.ipm.opt.bound_relax_factor) s_max=$(slv.ipm.opt.s_max) acceptable_tol=$(slv.ipm.opt.acceptable_tol) richardson_tol=$(slv.ipm.opt.richardson_tol)")
dg = Any[]
t = @elapsed r = MadNCL.solve!(slv; diag=dg)
open(OUT, "w") do io
    println(io, "# $ARM $CASE@$K kind=diag pathof=$(pathof(MadNCL)) time=$(round(t, digits=1))")
    println(io, "status=", r.status); println(io, "iter=", r.iter)
    println(io, "nfact=", r.counters.factorization_cnt); println(io, "rho_final=", hx(slv.ncl.ρk[]))
    println(io, "x=", join(hx.(Vector{Float64}(r.solution)), ":"))
    println(io, "obj=", hx(Float64(r.objective)))
    for d in dg
        println(io, "diag[$(d.iter)]=", join([let v = getproperty(d, f); v isa Float64 ? hx(v) : string(v); end
            for f in (:iter, :rho, :mu, :pr_feas, :eta, :thr, :ratio, :has_converged, :extrapolated, :branch,
                      :extrap_fact, :inner_fact, :inner_iters)], ","))
    end
end
@printf("SCOPF_CPU_DONE arm=%s status=%s iter=%d nfact=%d outers=%d time=%.1f\n", ARM, r.status, r.iter,
        r.counters.factorization_cnt, length(dg), t)

elseif MODE == "compare"

function load(path)
    kv = Dict{String,String}(); diag = Vector{Vector{String}}(); wo22 = Vector{Vector{String}}()
    for l in readlines(path)
        startswith(l, "#") && continue
        k, v = split(l, "=", limit=2)
        startswith(k, "diag[") ? push!(diag, split(v, ",")) :
        startswith(k, "wo22[") ? push!(wo22, split(v, ",")) : (kv[k] = v)
    end
    return kv, diag, wo22
end
# The comparator tree logs (branch, μ and ρ AFTER the update, ‖r‖∞, inner iterations, cumulative
# factorizations) per outer iteration; rebuild the same quantities from the diag records.
function diag_to_wo22(diag, kv)
    letter = Dict("extrap" => "E", "mu_reduce" => "M", "rho_bump" => "R", "maxiter" => "X")
    nf = parse(Int, kv["nfact"])
    fact = [parse(Int, d[11]) + parse(Int, d[12]) for d in diag]
    out = Vector{Vector{String}}()
    for (j, d) in enumerate(diag)
        b = letter[d[10]]
        mu = b == "X" ? d[3] : (j < length(diag) ? diag[j+1][3] : "?")
        rho = b == "X" ? d[2] : (j < length(diag) ? diag[j+1][2] : kv["rho_final"])
        pr = b == "X" ? "?" : d[4]
        push!(out, [b, mu, rho, pr, d[13], string(nf - sum(fact[j+1:end]; init=0))])
    end
    return out
end
ka, da, wa = load(ARGS[2]); kb, db, wb = load(ARGS[3])
nd = 0
for k in ("status", "iter", "nfact", "rho_final", "x", "obj")
    global nd
    va, vb = get(ka, k, "<absent>"), get(kb, k, "<absent>")
    if va == vb
        println("  $k: identical", k == "x" ? " ($(length(split(va, ":"))) entries)" : " ($(va))")
    else
        nd += 1; println("  $k: DIFFERS  ref=$(first(va, 200))  public=$(first(vb, 200))")
    end
end
if !isempty(wa)          # comparator tree (S / SP): per-outer log vs rebuilt quantities
    pb = diag_to_wo22(db, kb)
    length(wa) == length(pb) || (nd += 1; println("  outer count differs: ref=$(length(wa)) public=$(length(pb))"))
    for j in 1:min(length(wa), length(pb)), (i, name) in enumerate(("branch", "mu_post", "rho_post", "pr", "inner", "cumfact"))
        a, b = wa[j][i], pb[j][i]
        (b == "?" || a == b) && continue
        nd += 1; println("  outer $j $name: ref=$a public=$b")
    end
    println("  per-outer: $(min(length(wa), length(pb))) records compared (branch, μ/ρ after the update, ‖r‖∞, inner iterations, cumulative factorizations)")
else                     # research fork (U6A / W): the 13 diag fields
    length(da) == length(db) || (nd += 1; println("  outer count differs: ref=$(length(da)) public=$(length(db))"))
    for j in 1:min(length(da), length(db))
        da[j] == db[j] || (nd += 1; println("  diag[$j] differs:\n    ref=$(join(da[j], ","))\n    pub=$(join(db[j], ","))"))
    end
    println("  per-outer: $(min(length(da), length(db))) diag records compared (13 fields)")
end
println(nd == 0 ? "SCOPF_CPU_COMPARE_IDENTICAL" : "SCOPF_CPU_COMPARE_DIFFS n=$nd")
end
