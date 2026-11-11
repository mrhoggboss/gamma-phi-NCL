# WO-69 Addendum C2: raw-unit screen (CPU). Same subproblem as screen_candidates (contingency_problem, base OPF by Ipopt
# MA27 max_iter 500, ExaModel -> ScaledModel (max_gradient 1) -> NCLModel, y = 0, ρ = 1e8, MA57, K2r, 200 iterations,
# tol 1e-8). Per outage it records BOTH the scaled ‖r‖∞ (the old admission quantity) and the raw max_i |rᵢ|/σcᵢ
# (σc = ScaledModel.scaling_cons, so |rᵢ|/σcᵢ is the violation of row i in the model's own units), the raw argmax row
# with its family, and counts of rows above raw thresholds. Admission flags at scaled 1e-4, raw 1e-4 and raw 1e-3.
#   julia --project=benchmarks/envs/screen benchmarks/scopf_protocol/julia/screen_run3.jl <case.m> <A|B|full|null> <ktop> <window> <out_prefix> [rho]
# (paper-repro: the scopf-pool file benchmarks/pilot/screen/screen_run3.jl, unchanged but for this usage line)
# A/B: screen in that order (A increasing key, B keys[randperm(MersenneTwister(69), n)]) at least the first <window>
#      candidates (the window of the earlier ρ = 1e8 screen), then continue while fewer than <ktop> are raw-admitted
#      (raw < 1e-4) and fewer than 300 are screened.  full: every in-service branch.  null: no outage (key 0).
# Writes <out_prefix>.csv, <out_prefix>_top.csv (5 largest raw rows per outage), <out_prefix>.meta.txt; for null also
# the σc distribution.
using Random, Statistics
import HSL_jll, SHA
filesize(HSL_jll.libhsl_path) > 1_000_000 || error("HSL_jll is the stub: $(HSL_jll.libhsl_path)")
include(joinpath(@__DIR__, "contingency_pool.jl"))
include(joinpath(@__DIR__, "bridges.jl"))
const MOI = JuMP.MOI
include(joinpath(@__DIR__, "null_probe_families.jl"))
const CASE, ORDER, KTOP, WINDOW, OUTP = ARGS[1], ARGS[2], parse(Int, ARGS[3]), parse(Int, ARGS[4]), ARGS[5]
const RHO = length(ARGS) >= 6 ? parse(Float64, ARGS[6]) : 1e8

function families(cm)
    moim = JuMP.backend(cm); fams = String[]
    for (F, S) in MOI.get(moim, MOI.ListOfConstraintTypesPresent())
        F <: MOI.VariableIndex && continue
        for ci in MOI.get(moim, MOI.ListOfConstraintIndices{F,S}())
            push!(fams, family(cm, ci))
        end
    end
    return fams
end
countmap_(v) = (d = Dict{String,Int}(); foreach(x -> d[x] = get(d, x, 0) + 1, v); d)
relabel(f) = startswith(f, "affine other") ? (occursin("\"p\"", f) ? "bus P balance (no shunt)" : "bus Q balance (no shunt)") : f

model = opf_model(CASE)
JuMP.set_optimizer(model, Ipopt.Optimizer)
JuMP.set_attribute(model, "print_level", 0); JuMP.set_attribute(model, "max_iter", 500)
JuMP.set_attribute(model, "hsllib", HSL_jll.libhsl_path); JuMP.set_attribute(model, "linear_solver", "ma27")
JuMP.optimize!(model)
base_status = string(JuMP.termination_status(model))
base_case = extract_solution(model)

info = ORDER == "null" ? nothing : network_info(CASE)
cands = ORDER == "null" ? [0] : ORDER in ("A", "full") ? info.keys :
        ORDER == "B" ? info.keys[randperm(MersenneTwister(69), length(info.keys))] : error("order")
# C2_SLICE=a:b (env): screen exactly candidates a..b of the order, no stop rule (a parallel part of a long screen; the parts
# are merged afterwards in candidate order and the stop rule is applied there — results are deterministic per outage)
const SLICE = get(ENV, "C2_SLICE", "")
if !isempty(SLICE)
    a_, b_ = parse.(Int, split(SLICE, ":")); cands = cands[a_:min(b_, length(cands))]
end
t0 = time()
f = open(OUTP * ".csv", "w"); ft = open(OUTP * "_top.csv", "w")
println(f, "k,status,iter,rinf_scaled,nviol_scaled,raw_max,raw_argmax_row,raw_argmax_family,raw_argmax_sigma_c,",
           "n_raw_gt_1e-6,n_raw_gt_1e-5,n_raw_gt_1e-4,n_raw_gt_1e-3,time,adm_scaled_1e-4,adm_raw_1e-4,adm_raw_1e-3,",
           "bridge,isl_buses,isl_load_mw,isl_ngen,isl_pmax_mw")
println(ft, "k,rank,row,family,sigma_c,r_scaled,raw")
nscr = 0; nraw = 0; σstats = nothing
for k in cands
    global nscr, nraw, σstats
    if isempty(SLICE) && ORDER in ("A", "B") && nscr >= WINDOW && (nraw >= KTOP || nscr >= 300)
        break
    end
    t = @elapsed begin
        cm = contingency_problem(CASE, base_case, k)
        fams = families(cm)
        nlp = ExaModels.ExaModel(cm)
        snlp = MadNCL.ScaledModel(nlp); ncl = MadNCL.NCLModel(snlp); ncl.yk .= 0; ncl.ρk[] = RHO
        res = madnlp(ncl; print_level=MadNLP.ERROR, linear_solver=Ma57Solver, max_iter=200, tol=1e-8,
                     kkt_system=MadNCL.K2rAuglagKKTSystem)
        nv = NLPModels.get_nvar(nlp); nc = NLPModels.get_ncon(nlp)
        r = res.solution[nv+1:nv+nc]; σc = Array(snlp.scaling_cons)
    end
    @assert length(fams) == length(r)
    raw = abs.(r) ./ σc
    i = argmax(raw)
    rs = norm(r, Inf); rm = raw[i]
    nscr += 1; rm < 1e-4 && (nraw += 1)
    a = info === nothing ? nothing : get(info.island, k, nothing)
    isl = a === nothing ? ("", "", "", "") : (a.nbus, round(a.load_mw, digits=3), a.ngen, round(a.pmax_mw, digits=3))
    println(f, join((k, Int(res.status), res.iter, rs, count(abs.(r) .> 1e-6), rm, i, relabel(fams[i]), σc[i],
                     count(raw .> 1e-6), count(raw .> 1e-5), count(raw .> 1e-4), count(raw .> 1e-3), round(t, digits=3),
                     Int(rs < 1e-4), Int(rm < 1e-4), Int(rm < 1e-3), Int(a !== nothing), isl...), ","))
    for (j, ii) in enumerate(sortperm(raw, rev=true)[1:min(5, length(raw))])
        println(ft, join((k, j, ii, relabel(fams[ii]), σc[ii], abs(r[ii]), raw[ii]), ","))
    end
    flush(f); flush(ft)
    if ORDER == "null"
        q = sort(σc)
        σstats = (min=q[1], q01=quantile(q, 0.01), q10=quantile(q, 0.10), median=median(q), n_lt_1=count(<(1.0), q), n=length(q),
                  famlow=sort(collect(countmap_(relabel.(fams[σc .< 1e-2]))), by=x -> -x[2]))
    end
end
close(f); close(ft)
tt = time() - t0
open(OUTP * ".meta.txt", "w") do g
    println(g, "base_status=$base_status rho=$RHO order=$ORDER ktop=$KTOP window=$WINDOW candidates=$(length(cands)) ",
            "screened=$nscr raw_admitted_1e-4=$nraw screen_s=$(round(tt, digits=1))")
    println(g, "case=$CASE sha256=$(bytes2hex(open(io_ -> SHA.sha256(io_), CASE)))")
    σstats === nothing || println(g, "sigma_c min=$(σstats.min) q01=$(σstats.q01) q10=$(σstats.q10) median=$(σstats.median) rows_below_1=$(σstats.n_lt_1) of $(σstats.n) families_with_sigma_c_below_1e-2=$(σstats.famlow)")
end
