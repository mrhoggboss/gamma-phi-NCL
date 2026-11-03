# CUTEst smoke gate (N3): one solve per problem of an instance list, on Distributed workers,
# with the result row and the per-outer trace written in the format of the research fork's pool
# driver (bench/drivers/driver_kernel_core.jl), so the two can be compared string-for-string.
#
#   run:     julia --project=benchmarks/envs/cpu gates/smoke.jl run <arm> <list> <outdir> [nworkers] [maxwall]
#   compare: julia gates/smoke.jl compare <rows_a.csv> <trace_a.csv> <rows_b.csv> <trace_b.csv>
#
# <arm>: U6A  = PowerKernel(6), λ ≡ 1e-2, MadNLP acceptable_tol = 0
#        W    = quadratic kernel, weight law + force gate ((γ,φ)-MadNCL)
#        both on K2r + MA57 (automatic scaling) at the frozen campaign constants.
using Printf
using Distributed

const MODE = ARGS[1]

const ROW_COLS = (:name, :nvar, :ncon, :status, :iter, :nfact, :eqfeas, :viol, :obj, :du_sd1, :y_inf,
                  :n_outer, :n_extrap_acc, :extrap_fact_total, :inner_fact_total, :backsolves,
                  :eqv_inf, :eqv_l1, :inv_inf, :inv_l1, :mer_l1, :mer_l2, :mer_l4, :mer_l6, :mer_linf)
const TRACE_COLS = (:iter, :branch, :mu, :rho, :eta, :thr, :ratio, :has_converged, :extrapolated,
                    :inner_iters, :inner_fact, :extrap_fact, :pr_feas)

if MODE == "run"

const ARM = ARGS[2]
const LIST = ARGS[3]
const OUT = ARGS[4]
const NW = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 4
const MAXWALL = length(ARGS) >= 6 ? parse(Float64, ARGS[6]) : 3600.0
ARM in ("U6A", "W") || error("unknown arm $ARM")
mkpath(OUT)
const PROJ = Base.active_project()
probs = String.(filter(!isempty, strip.(readlines(LIST))))

@eval using CUTEst
isbuilt(name) = isfile(joinpath(CUTEst.libsif_path, "lib$(name)_double.so"))
missing_ = filter(!isbuilt, probs)
isempty(missing_) || error("not decoded (decode them first, serially): $(missing_)")

addprocs(NW; exeflags="--project=$(PROJ)")
@everywhere begin
    using MadNCL, MadNLP, MadNLPHSL, NLPModels, CUTEst
    const ARM_W = $ARM
    const MAXWALL_W = $MAXWALL
    const MU_MIN = (1e-8 / 100)^(1 / 1.05)
    const FROZEN = (verbose=false, extrapolation=false, scaling_max_gradient=100.0, opt_tol=1e-8,
                    feas_tol=1e-8, rho_max=1e14, mu_min=MU_MIN, max_auglag_iter=40)
    const TRACE_COLS_W = $TRACE_COLS
    function arm_config(arm)
        if arm == "U6A"
            return (MadNCL.PowerKernel(6.0, 1e-2), MadNCL.NCLOptions{Float64}(; FROZEN...), (acceptable_tol=0.0,))
        else
            return (MadNCL.QuadraticKernel(),
                    MadNCL.NCLOptions{Float64}(; FROZEN..., weight_law=:geometry, weight_clip=(1e-30, 1e8),
                                               weight_anneal_horizon=6.0, gate_metric=:force),
                    NamedTuple())
        end
    end
    function _eqfeas(nlp, x)
        m = NLPModels.get_ncon(nlp); m == 0 && return 0.0
        c = similar(x, m); NLPModels.cons!(nlp, x, c)
        lc = NLPModels.get_lcon(nlp); uc = NLPModels.get_ucon(nlp)
        return Float64(maximum(abs.(c .- lc) .* (lc .== uc)))
    end
    function _viol(nlp, x)
        m = NLPModels.get_ncon(nlp); m == 0 && return 0.0
        c = similar(x, m); NLPModels.cons!(nlp, x, c)
        lc = NLPModels.get_lcon(nlp); uc = NLPModels.get_ucon(nlp)
        return Float64(maximum(max.(lc .- c, c .- uc, zero(eltype(c)))))
    end
    function _fournorms(nlp, x)
        m = NLPModels.get_ncon(nlp); m == 0 && return (0.0, 0.0, 0.0, 0.0)
        c = similar(x, m); NLPModels.cons!(nlp, x, c)
        lc = NLPModels.get_lcon(nlp); uc = NLPModels.get_ucon(nlp)
        iseq = lc .== uc
        eqv = abs.(c .- lc) .* iseq
        inv = max.(lc .- c, c .- uc, zero(eltype(c))) .* .!iseq
        return (Float64(maximum(eqv; init=0.0)), Float64(sum(eqv)),
                Float64(maximum(inv; init=0.0)), Float64(sum(inv)))
    end
    function _merits(nlp, x)
        m = NLPModels.get_ncon(nlp); m == 0 && return (0.0, 0.0, 0.0, 0.0, 0.0)
        c = similar(x, m); NLPModels.cons!(nlp, x, c)
        lc = NLPModels.get_lcon(nlp); uc = NLPModels.get_ucon(nlp)
        v = max.(lc .- c, c .- uc, zero(eltype(c)))
        vs = min.(v, 1e50)
        return (Float64(sum(vs)), Float64(sum(abs2, vs)),
                Float64(sum(t -> t^4, vs)), Float64(sum(t -> t^6, vs)),
                Float64(maximum(v; init=0.0)))
    end
    function solve_one(name)
        nlp = CUTEstModel(name; decode=false)
        try
            kernel, opt, ipm_kw = arm_config(ARM_W)
            slv = MadNCL.NCLSolver(nlp; ncl_options=opt, kernel=kernel,
                kkt_system=MadNCL.K2rAuglagKKTSystem, linear_solver=MadNLPHSL.Ma57Solver,
                ma57_automatic_scaling=true, bound_relax_factor=1e-8, ipm_kw...,
                max_iter=3000, max_wall_time=MAXWALL_W, print_level=MadNLP.ERROR)
            dg = Any[]
            r = MadNCL.solve!(slv; diag=dg)
            fn = _fournorms(nlp, r.solution); mr = _merits(nlp, r.solution)
            row = (name=name, nvar=nlp.meta.nvar, ncon=nlp.meta.ncon, status=string(r.status),
                   iter=r.iter, nfact=r.counters.factorization_cnt,
                   eqfeas=_eqfeas(nlp, r.solution), viol=_viol(nlp, r.solution),
                   obj=Float64(r.objective), du_sd1=Float64(r.dual_feas),
                   y_inf=Float64(maximum(abs, r.multipliers; init=0.0)),
                   n_outer=length(dg), n_extrap_acc=count(d -> d.extrapolated, dg),
                   extrap_fact_total=sum(Int(d.extrap_fact) for d in dg; init=0),
                   inner_fact_total=sum(Int(d.inner_fact) for d in dg; init=0),
                   backsolves=r.counters.backsolve_cnt,
                   eqv_inf=fn[1], eqv_l1=fn[2], inv_inf=fn[3], inv_l1=fn[4],
                   mer_l1=mr[1], mer_l2=mr[2], mer_l4=mr[3], mer_l6=mr[4], mer_linf=mr[5])
            trace = [map(k -> getproperty(d, k), TRACE_COLS_W) for d in dg]
            return (row, trace, pathof(MadNCL))
        finally
            finalize(nlp)
        end
    end
end

for w in workers()
    println("worker $w pathof(MadNCL) = ", remotecall_fetch(() -> pathof(MadNCL), w))
end
println("ARM=$ARM LIST=$LIST NW=$NW MAXWALL=$MAXWALL PROJ=$PROJ")
flush(stdout)
t0 = time()
res = pmap(solve_one, probs)
println(@sprintf("all %d problems done in %.1f s", length(probs), time() - t0))
paths = unique(r[3] for r in res)
println("worker-side pathof(MadNCL) over all tasks: ", paths)
open(joinpath(OUT, "rows_$(ARM).csv"), "w") do io
    println(io, join(ROW_COLS, ","))
    for (row, _, _) in res
        println(io, join((row[c] for c in ROW_COLS), ","))
    end
end
open(joinpath(OUT, "trace_$(ARM).csv"), "w") do io
    println(io, "name," * join(TRACE_COLS, ","))
    for (p, (_, trace, _)) in zip(probs, res)
        for t in trace
            println(io, p * "," * join(t, ","))
        end
    end
end
nsucc = count(r -> r[1].status == "SOLVE_SUCCEEDED", res)
println("SMOKE_DONE arm=$ARM succ=$nsucc/$(length(probs)) out=$OUT")
rmprocs(workers())

elseif MODE == "compare"

# Compare two (rows, trace) pairs on the columns they share, string-for-string.
function readcsv(path)
    L = readlines(path)
    hdr = split(L[1], ",")
    return hdr, [split(l, ",") for l in L[2:end]]
end
function cmp_tables(pa, pb, keycols)
    ha, ra = readcsv(pa); hb, rb = readcsv(pb)
    common = [c for c in ha if c in hb && c != "time"]
    ia = Dict(c => findfirst(==(c), ha) for c in common)
    ib = Dict(c => findfirst(==(c), hb) for c in common)
    key(r, idx) = join((r[idx[c]] for c in keycols), "|")
    # occurrence index makes repeated keys (one trace row per outer) unique
    function keyed(rows, idx)
        seen = Dict{String,Int}(); out = Dict{String,Any}(); order = String[]
        for r in rows
            k0 = key(r, idx); n = get(seen, k0, 0) + 1; seen[k0] = n
            k = k0 * "#$n"; out[k] = r; push!(order, k)
        end
        return out, order
    end
    A, oa = keyed(ra, ia); B, ob = keyed(rb, ib)
    ndiff = 0
    for k in sort(collect(union(keys(A), keys(B))))
        if !haskey(A, k) || !haskey(B, k)
            ndiff += 1; println("  MISSING ", k, haskey(A, k) ? " (only in A)" : " (only in B)"); continue
        end
        for c in common
            va, vb = A[k][ia[c]], B[k][ib[c]]
            if va != vb
                ndiff += 1
                println("  DIFF $k $c: A=$va B=$vb")
            end
        end
    end
    return ndiff, common, length(ra), length(rb)
end
nr, cr, na, nb = cmp_tables(ARGS[2], ARGS[4], ["name"])
println("ROWS: $(na) vs $(nb) rows; compared columns: ", join(cr, " "), "; differing cells: $nr")
nt, ct, ta, tb = cmp_tables(ARGS[3], ARGS[5], ["name"])
println("TRACE: $(ta) vs $(tb) rows; compared columns: ", join(ct, " "), "; differing cells: $nt")
println(nr == 0 && nt == 0 && na == nb && ta == tb ? "SMOKE_COMPARE_IDENTICAL" : "SMOKE_COMPARE_DIFFS")
end
