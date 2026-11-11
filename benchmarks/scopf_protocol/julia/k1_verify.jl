# WO-69 Addendum C3 worker (CPU): single-contingency (K = 1) harness SCOPF, solved by Ipopt + MA57 exactly as C1/D3:
# scopf_model(file, [k]; the gpu.jl SCOPF_MODEL keywords) = harness model (ε = Ipopt's default bound_relax_factor 1e-8,
# tau_relax 0, scale_obj 1e-4, scale_cc 1), JuMP start values = harness x0, Ipopt tol 1e-8, max_iter 3000,
# max_wall_time 600 s, every other Ipopt option at its default. Jobs are claimed from <jobs.txt> with mkdir locks, so any
# number of workers can run; one result file per job under <outdir>/rows/.
#   julia --project=benchmarks/envs/screen benchmarks/scopf_protocol/julia/k1_verify.jl <jobs.txt> <outdir>
# (paper-repro: the scopf-pool file benchmarks/pilot/c3/c3_k1.jl; only the two harness paths changed. The protocol budget
# is C3_WALL=3600 C3_MAXITER=10000 C3_FIRSTPR=1, as run for the order-B lists of case588_sdet and case793_goc; the defaults
# below, 600 s and 3000 iterations, are the budget of the recorded checks of the other four lists.)
# jobs.txt lines: <net>,<order>,<k>,<case file>
import HSL_jll
using JuMP, PowerModels, Ipopt, Printf
const MOI = JuMP.MOI
const BENCH = normpath(joinpath(@__DIR__, "..", ".."))   # benchmarks/ of this checkout (scopf-pool: PUB = the pool root)
include(joinpath(BENCH, "models", "scopf_model.jl"))
const SCOPF_MODEL = (adjust=:mpecdroop, voltage_control=:pvpq, tau_relax=0.0, scale_obj=1e-4, scale_cc=1.0)
let l = filter(s -> startswith(s, "const SCOPF_MODEL"), readlines(joinpath(BENCH, "gpu.jl")))
    @assert length(l) == 1 && occursin("(adjust=:mpecdroop, voltage_control=:pvpq, tau_relax=0.0, scale_obj=1e-4, scale_cc=1.0)", l[1])
end
@assert filesize(HSL_jll.libhsl_path) > 1_000_000
const JOBS, OUTD = ARGS[1], ARGS[2]
# C3b (WO-69): env overrides of the budget; defaults = the C3 budget (wall 600 s, max_iter 3000). With C3_FIRSTPR=1 the row gets
# one extra column: the first iteration whose iteration-table inf_pr (Ipopt's unscaled constraint violation) is < 1e-6 (-1: never).
const WALL_S = parse(Float64, get(ENV, "C3_WALL", "600"))
const MAXIT = parse(Int, get(ENV, "C3_MAXITER", "3000"))
const FIRSTPR = get(ENV, "C3_FIRSTPR", "0") == "1"
mkpath(joinpath(OUTD, "rows")); mkpath(joinpath(OUTD, "claims")); mkpath(joinpath(OUTD, "tails"))
const TMP = mktempdir()

# ---- row naming (harness model; as C1) ----
basename_of(v) = (s = JuMP.name(v); i = findfirst('[', s); i === nothing ? s : s[1:prevind(s, i)])
function vidx(v)
    s = JuMP.name(v); i = findfirst('[', s); b = s[1:prevind(s, i)]; inner = s[i+1:prevind(s, lastindex(s))]
    b == "Δ" && return b, "", parse(Int, inner) + 1
    j = findlast(',', inner)
    return b, inner[1:j-1], parse(Int, inner[j+1:end])
end
function vars_of(f)
    f isa JuMP.VariableRef && return [f]
    f isa JuMP.AffExpr && return collect(keys(f.terms))
    f isa JuMP.QuadExpr && return vcat(collect(keys(f.aff.terms)), [t.a for t in keys(f.terms)], [t.b for t in keys(f.terms)])
    out = JuMP.VariableRef[]
    walk(x) = x isa JuMP.VariableRef ? push!(out, x) : x isa JuMP.GenericNonlinearExpr ? foreach(walk, x.args) :
              x isa JuMP.AffExpr ? append!(out, keys(x.terms)) : x isa JuMP.QuadExpr ? append!(out, vars_of(x)) : nothing
    walk(f); return out
end
function classify(c, conts)
    obj = JuMP.constraint_object(c); f, s = obj.func, obj.set
    if f isa JuMP.VariableRef
        b, ix, k = vidx(f); return "bound $(b)", (k == 1 ? "base" : "outage"), "$(b)[$(ix)]"
    end
    vs = unique(vars_of(f)); bs = Set(basename_of.(vs)); k = maximum(vidx(v)[3] for v in vs); o = k == 1 ? "base" : "outage"
    arc = findfirst(v -> basename_of(v) in ("p", "q"), vs); gen = findfirst(v -> basename_of(v) in ("pg", "ρp", "ρn"), vs)
    vg = findfirst(v -> basename_of(v) in ("vp", "vn"), vs); arcix = arc === nothing ? "" : vidx(vs[arc])[2]
    if f isa JuMP.AffExpr || f isa JuMP.QuadExpr
        if s isa MOI.EqualTo
            bs == Set(["va"]) && return "reference angle", o, "bus $(vidx(vs[1])[2])"
            "ρp" in bs && return "droop link", o, "gen $(vidx(vs[gen])[2])"
            "vp" in bs && return "PV/PQ link", o, "gen $(vidx(vs[vg])[2])"
            if length(vs) == 1 && bs ⊆ Set(["p", "q"]) && s.value == 0.0 && k >= 2 &&
               parse(Int, split(strip(arcix, ['(', ')']), ",")[1]) == conts[k-1]
                return "outage pin p=q=0", o, "arc $(arcix)"
            end
            (("p" in bs) || ("q" in bs)) && return ("p" in bs ? "bus P balance" : "bus Q balance"), o, "bus $(strip(split(strip(arcix, ['(', ')']), ",")[2]))"
            return "other eq", o, ""
        end
        ("ρn" in bs || "ρp" in bs) && return "droop CC", o, "gen $(vidx(vs[gen])[2])"
        ("vn" in bs || "vp" in bs) && return "PV/PQ CC", o, "gen $(vidx(vs[vg])[2])"
        ("p" in bs && "q" in bs) && return "branch rating", o, "arc $(arcix)"
        return "other ineq", o, ""
    end
    s isa MOI.EqualTo && return "branch flow definition", o, "arc $(arcix)"
    return "other nonlinear", o, ""
end
viol(v, s::MOI.EqualTo) = abs(v - s.value)
viol(v, s::MOI.LessThan) = max(0.0, v - s.upper)
viol(v, s::MOI.GreaterThan) = max(0.0, s.lower - v)
viol(v, s::MOI.Interval) = max(0.0, s.lower - v, v - s.upper)
function worst_row(jm, conts)
    best = (-1.0, nothing)
    for (F, S) in JuMP.list_of_constraint_types(jm), c in JuMP.all_constraints(jm, F, S)
        obj = JuMP.constraint_object(c)
        v = viol(JuMP.value(obj.func), obj.set)
        v > best[1] && (best = (v, c))
    end
    fam, o, el = classify(best[2], conts)
    return best[1], fam, o, el
end
clean(s) = replace(string(s), "," => ";")

jobs = [String.(split(strip(l), ",")) for l in readlines(JOBS) if !isempty(strip(l))]
for (net, order, ks, file) in jobs
    tag = "$(net)_$(order)__$(ks)"
    try mkdir(joinpath(OUTD, "claims", tag)) catch; continue end
    k = parse(Int, ks)
    tb = time()
    jm = scopf_model(file, [k]; SCOPF_MODEL...)
    tbuild = time() - tb
    JuMP.set_optimizer(jm, Ipopt.Optimizer)
    JuMP.set_attribute(jm, "hsllib", HSL_jll.libhsl_path); JuMP.set_attribute(jm, "linear_solver", "ma57")
    JuMP.set_attribute(jm, "tol", 1e-8); JuMP.set_attribute(jm, "max_iter", MAXIT); JuMP.set_attribute(jm, "max_wall_time", WALL_S)
    JuMP.set_attribute(jm, "print_level", 0)
    log = joinpath(TMP, tag * ".log")
    JuMP.set_attribute(jm, "output_file", log); JuMP.set_attribute(jm, "file_print_level", 5)
    t = @elapsed JuMP.optimize!(jm)
    fin = Dict{String,Tuple{String,String}}()
    L = isfile(log) ? readlines(log) : String[]
    for l in L
        m = match(r"^(Objective|Dual infeasibility|Constraint violation|Variable bound violation|Complementarity|Overall NLP error)\.*:\s+(\S+)\s+(\S+)", l)
        m === nothing || (fin[m.captures[1]] = (m.captures[2], m.captures[3]))
    end
    firstpr = -1
    if FIRSTPR
        for l in L
            m = match(r"^\s*(\d+)r?\s+\S+\s+(\S+)\s", l)
            m === nothing && continue
            x = tryparse(Float64, m.captures[2]); x === nothing && continue
            if x < 1e-6; firstpr = parse(Int, m.captures[1]); break; end
        end
    end
    # keep the summary tail of the Ipopt log (the last iteration line onward), drop the rest
    lastit = findlast(l -> occursin(r"^\s*\d+r?\s+[-+0-9.eE]+\s", l), L)
    open(joinpath(OUTD, "tails", tag * ".txt"), "w") do io
        foreach(l -> println(io, l), L[(lastit === nothing ? max(1, length(L) - 30) : lastit):end])
    end
    rm(log; force=true)
    it = try MOI.get(JuMP.backend(jm), MOI.BarrierIterations()) catch; -1 end
    st = string(JuMP.raw_status(jm))
    g(key, j) = haskey(fin, key) ? fin[key][j] : "NA"
    w = JuMP.has_values(jm) ? worst_row(jm, [k]) : (NaN, "NA", "NA", "NA")
    obj = JuMP.has_values(jm) ? JuMP.objective_value(jm) : NaN
    open(joinpath(OUTD, "rows", tag * ".csv"), "w") do io
        println(io, join((net, order, k, clean(st), clean(JuMP.termination_status(jm)), it, g("Constraint violation", 2),
                          g("Dual infeasibility", 2), g("Constraint violation", 1), g("Dual infeasibility", 1),
                          g("Complementarity", 2), obj, round(t, digits=2), round(tbuild, digits=2),
                          clean(w[2]), w[3], clean(w[4]), w[1], JuMP.num_variables(jm), (FIRSTPR ? (firstpr,) : ())...), ","))
    end
    println("done $tag $st $(round(t, digits=1)) s"); flush(stdout)
end
