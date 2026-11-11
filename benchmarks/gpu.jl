# GPU benchmark: PGLIB optimal power flow, COPS, the COPS size ladder, and the security-constrained
# OPF problems written as MPCCs (SCOPF).
#
#   julia +1.11.2 --project=benchmarks/envs/gpu benchmarks/gpu.jl <suite> <configs> <outdir> [options]
#
#   <suite>    opf | cops | cops_ladder | scopf
#   <configs>  comma list of S, SP, W, U6A, ablation, Wos (benchmarks/arms.jl) and liftedkkt (benchmarks/liftedkkt.jl)
#   <outdir>   results: <suite>__<config>__<tag>.csv (rewritten after every instance; running the same command
#              again resumes: rows already there are kept and their instances skipped) and
#              config_<suite>__<tag>.txt (the full option set of every configuration, read back from the solvers)
#   options    --tag=<tag>            repetition tag in the file names (default r1)
#              --device=cuda|cpu      cuda (default): ExaModels on CUDABackend, cuDSS LDL;
#                                     cpu: ExaModels on the CPU, MadNLP LDLSolver (for smoke tests)
#              --instances=<file>     opf: one PGLIB case per line (default instances/pglib66.txt, all 66 cases:
#                                     the paper's runs cover all of them for every configuration);
#                                     scopf: CSV with columns case,K,data (default instances/scopf23.csv)
#              --data=<dir>           scopf: directory containing the case-file directories named in the
#                                     `data` column (required for scopf; the case files are not distributed here)
#              --contingencies=<file> scopf: a Julia file defining `CONTINGENCIES` (case name => branch list; it must
#                                     also carry the "case118" key used by the warm-up); default
#                                     instances/scopf_contingencies.jl
#              --cases=<a,b,...>      restrict the run to these instance names
#              --wall=<seconds>       wall-time limit per solve (default 1800)
#              --tol=<t>              optimality and feasibility tolerance of every configuration (default 1e-8)
#              --cvtol=<t>            constraint-violation tolerance in the original scaling (default 1e-4), the
#                                     MadNCL configurations' constr_viol_tol; MadNLP (LiftedKKT) has no such test
#                                     and runs without it (the violation is recorded as pr_res in every row)
#              --warmup=0             skip the warm-up solves (they are on by default)
#              --trace                per-outer-iteration records of the MadNCL configurations
#                                     (trace__<suite>__<config>__<tag>.csv)
#
# Every configuration factorizes the KKT system with the same linear solver (cuDSS LDL on the GPU) and
# runs under the suite's budgets below. One warm-up solve per configuration precedes the measured
# solves, so that compilation is not charged to the first instance. `wall` is the solve time only; the
# model build time is reported separately (`build_s`). MadNCL configurations use the K2r KKT system.
include(joinpath(@__DIR__, "common.jl"))

const POS, OPT = parse_args(ARGS)
length(POS) == 3 || error("usage: gpu.jl <suite> <configs> <outdir> [--tag=] [--device=] [--instances=] [--data=] [--contingencies=] [--cases=] [--wall=] [--tol=] [--cvtol=] [--warmup=0]")
const SUITE = POS[1]
SUITE in ("opf", "cops", "cops_ladder", "scopf") || error("unknown suite $SUITE")
const CONFIGS = String.(split(POS[2], ","))
const OUTDIR = abspath(POS[3])
const TAG = get(OPT, "tag", "r1")
const DEVICE = get(OPT, "device", "cuda")
DEVICE in ("cuda", "cpu") || error("--device must be cuda or cpu")
const WALL = parse(Float64, get(OPT, "wall", "1800"))
const WARMUP = get(OPT, "warmup", "1") != "0"
const TOL = parse(Float64, get(OPT, "tol", "1e-8"))
const CVTOL = parse(Float64, get(OPT, "cvtol", "1e-4"))
const CASES = filter(!isempty, String.(split(get(OPT, "cases", ""), ",")))
const TRACE = haskey(OPT, "trace")

using MadNCL, MadNLP, ExaModels, NLPModels, PowerModels, COPSBenchmark, Printf
using Pkg.Artifacts
include(joinpath(@__DIR__, "arms.jl"))
include(joinpath(@__DIR__, "liftedkkt.jl"))
include(joinpath(@__DIR__, "models", "acopf_model.jl"))
include(joinpath(@__DIR__, "models", "scopf_model.jl"))
const CONTINGENCY_FILE = haskey(OPT, "contingencies") ? abspath(OPT["contingencies"]) : ""
include(isempty(CONTINGENCY_FILE) ? joinpath(@__DIR__, "instances", "scopf_contingencies.jl") : CONTINGENCY_FILE)
for c in CONFIGS; c in ARMS || c == "liftedkkt" || error("unknown configuration $c"); end

if DEVICE == "cuda"
    @eval using CUDA, CUDSS, MadNLPGPU
    CUDA.allowscalar(true)
    MadNLPGPU.CUDSSSolver === nothing && error("MadNLPGPU.CUDSSSolver is not available (CUDSS extension not loaded)")
    const BACKEND = CUDABackend()
    const LINEAR_SOLVER = (linear_solver=MadNLPGPU.CUDSSSolver, cudss_algorithm=MadNLP.LDL)
    reclaim() = (GC.gc(); CUDA.reclaim())
else
    const BACKEND = nothing
    const LINEAR_SOLVER = (linear_solver=MadNLP.LDLSolver,)
    reclaim() = GC.gc()
end

# ---- suite settings (identical for every configuration) ----
# SCOPF: the problem (P) with the hard complementarity product (tau_relax = 0) and the objective scaled by
# 1e-4; the interior-point refinement settings of the SCOPF reference benchmark (Richardson tolerance 1e-12,
# at most 20 refinement steps; cuDSS pivot perturbation 1e-10 on the GPU).
const SCOPF_MODEL = (adjust=:mpecdroop, voltage_control=:pvpq, tau_relax=0.0, scale_obj=1e-4, scale_cc=1.0)
const SCOPF_IPM = DEVICE == "cuda" ?
    (richardson_tol=1e-12, richardson_max_iter=20, cudss_pivot_epsilon=1e-10) :
    (richardson_tol=1e-12, richardson_max_iter=20)
const MAX_ITER = SUITE == "scopf" ? 3000 : 1000
const SUITE_IPM = SUITE == "scopf" ? SCOPF_IPM : NamedTuple()
ipm_kw(; max_iter=MAX_ITER) = (LINEAR_SOLVER..., max_iter=max_iter, max_wall_time=WALL,
                               print_level=MadNLP.ERROR, SUITE_IPM...)

# ---- instances: (name, family, size, build) ----
const COPS13 = [
    ("bearing", (400, 400)), ("catmix", (3200,)), ("channel", (3200,)), ("elec", (400,)),
    ("gasoil", (3200,)), ("marine", (3200,)), ("minsurf", (400, 400)), ("pinene", (3200,)),
    ("polygon", (100,)), ("robot", (3200,)), ("rocket", (400,)), ("steering", (3200,)), ("torsion", (200, 200)),
]
const COPS_LADDER = [
    ("bearing",  [(200, 200), (400, 400), (800, 800), (1600, 1600)]),
    ("catmix",   [(800,), (3200,), (12800,), (51200,)]),
    ("channel",  [(800,), (3200,), (12800,), (51200,)]),
    ("elec",     [(100,), (400,), (1600,)]),
    ("gasoil",   [(800,), (3200,), (12800,), (51200,)]),
    ("marine",   [(800,), (3200,), (12800,), (51200,)]),
    ("minsurf",  [(200, 200), (400, 400), (800, 800), (1600, 1600)]),
    ("pinene",   [(800,), (3200,), (12800,), (51200,)]),
    ("polygon",  [(25,), (100,), (400,)]),
    ("robot",    [(800,), (3200,), (12800,), (51200,)]),
    ("steering", [(800,), (3200,), (12800,), (51200,)]),
    ("torsion",  [(100, 100), (200, 200), (400, 400), (800, 800)]),
]
cops_model(fam, sz) = ExaModels.ExaModel(getfield(COPSBenchmark, Symbol(fam, "_model"))(sz...); prod=true, backend=BACKEND)
size_str(sz) = join(sz, "x")

function scopf_build(datadir, case, K)
    jm = scopf_model(joinpath(datadir, case * ".m"), CONTINGENCIES[case][1:K]; SCOPF_MODEL...)
    return ExaModels.ExaModel(jm; prod=true, backend=BACKEND)
end

function instances()
    if SUITE == "opf"
        pglib = joinpath(artifact"PGLib_opf", "pglib-opf-23.07")
        file = get(OPT, "instances", joinpath(@__DIR__, "instances", "pglib66.txt"))
        list = String.(filter(!isempty, strip.(readlines(file))))
        insts = [(c, "pglib", "", () -> ac_power_model(joinpath(pglib, c * ".m"); prod=true, backend=BACKEND)) for c in list]
        warm = () -> ac_power_model(joinpath(pglib, "pglib_opf_case1354_pegase.m"); prod=true, backend=BACKEND)
    elseif SUITE == "cops"
        insts = [(f, f, size_str(sz), () -> cops_model(f, sz)) for (f, sz) in COPS13]
        warm = () -> cops_model("polygon", (100,))
    elseif SUITE == "cops_ladder"
        insts = [("$(f)_$(size_str(sz))", f, size_str(sz), () -> cops_model(f, sz)) for (f, szs) in COPS_LADDER for sz in szs]
        warm = () -> cops_model("polygon", (100,))
    else
        haskey(OPT, "data") || error("scopf needs --data=<dir> (the directory holding the case-file directories)")
        file = get(OPT, "instances", joinpath(@__DIR__, "instances", "scopf23.csv"))
        lines = filter(!isempty, strip.(readlines(file)))
        hdr = strip.(split(lines[1], ","))
        rows = [Dict(zip(hdr, strip.(split(l, ",")))) for l in lines[2:end]]
        insts = [("$(r["case"])_nK$(r["K"])", r["case"], r["K"],
                  let d = joinpath(OPT["data"], r["data"]), c = r["case"], k = parse(Int, r["K"])
                      () -> scopf_build(d, c, k)
                  end) for r in rows]
        wdir = joinpath(OPT["data"], first(rows)["data"])
        warm = () -> scopf_build(wdir, "case118", 1)
    end
    isempty(CASES) || (insts = [i for i in insts if i[1] in CASES])
    return insts, warm
end

# ---- one solve ----
function make_solver(model, config; max_iter=MAX_ITER)
    if config == "liftedkkt"
        return liftedkkt_solver(model, LINEAR_SOLVER, (tol=TOL, max_iter=max_iter, max_wall_time=WALL,
                                print_level=MadNLP.ERROR, SUITE_IPM...))
    end
    kernel, opt, ipm = arm_config(config; tol=TOL, constr_viol_tol=CVTOL)
    return MadNCL.NCLSolver(model; ncl_options=opt, kernel=kernel, kkt_system=MadNCL.K2rAuglagKKTSystem,
                            ipm_kw(; max_iter=max_iter)..., ipm...)
end
echo(io, config, slv) = config == "liftedkkt" ? echo_liftedkkt(io, slv) : echo_arm(io, config, slv)

function cc_max(model, x)
    # largest complementarity product (rows with lcon = -Inf and ucon = tau_relax)
    c = Array(NLPModels.cons(model, x)); lc = Array(NLPModels.get_lcon(model)); uc = Array(NLPModels.get_ucon(model))
    v = -Inf
    @inbounds for i in eachindex(c)
        (lc[i] == -Inf && uc[i] == SCOPF_MODEL.tau_relax) && (v = max(v, c[i]))
    end
    return v
end

const HEADER = (:instance, :config, :tag, :family, :size, :nvar, :ncon, :status, :obj, :iter, :nfact,
                :pr_res, :wall, :build_s, :n_outer, :dual_feas, :max_cc)

function append_trace(name, config, dg)
    p = joinpath(OUTDIR, "trace__$(SUITE)__$(config)__$(TAG).csv")
    fresh = !isfile(p)
    open(p, "a") do io
        fresh && println(io, join((:instance, TRACE_FIELDS...), ","))
        for d in dg
            println(io, join((name, (getproperty(d, f) for f in TRACE_FIELDS)...), ","))
        end
    end
end

function solve_row(model, name, fam, sz, build_s, config)
    t0 = time()
    try
        slv = make_solver(model, config)
        if config == "liftedkkt"
            r = MadNLP.solve!(slv); n_outer = -1
        else
            dg = Any[]
            r = MadNCL.solve!(slv; diag=dg); n_outer = length(dg)
            TRACE && append_trace(name, config, dg)
        end
        wall = time() - t0
        x = r.solution
        return (name, config, TAG, fam, sz, NLPModels.get_nvar(model), NLPModels.get_ncon(model), string(r.status),
                Float64(r.objective), r.iter, r.counters.factorization_cnt, constraint_violation(model, x),
                round(wall, digits=3), build_s, n_outer, Float64(r.dual_feas),
                SUITE == "scopf" ? cc_max(model, x) : NaN)
    catch e
        msg = "ERROR:" * first(split(sprint(showerror, e), '\n'))
        @warn "$name [$config] $msg"
        return (name, config, TAG, fam, sz, NLPModels.get_nvar(model), NLPModels.get_ncon(model), msg,
                NaN, -1, -1, NaN, round(time() - t0, digits=3), build_s, -1, NaN, NaN)
    end
end

# ---- restart ----
# A run killed part-way (a crash, or the stall watchdog benchmarks/paper/watch.sh) is resumed by running the same
# command again: the rows already in <suite>__<config>__<tag>.csv are kept and their instances skipped. The instance
# that was in flight is named in inflight__<suite>__<config>__<tag>.txt (with its start time); if the watchdog
# recorded its kill in <outdir>/KILLED_AT and the instance had by then run longer than 1.5 × wall, it is recorded as
# EXTERNAL_KILL (the solver did not return within its budget; it would hang again) instead of being re-run.
csv_path(config) = joinpath(OUTDIR, "$(SUITE)__$(config)__$(TAG).csv")
inflight_path(config) = joinpath(OUTDIR, "inflight__$(SUITE)__$(config)__$(TAG).txt")
trace_path(config) = joinpath(OUTDIR, "trace__$(SUITE)__$(config)__$(TAG).csv")
write_inflight(config, name) = (open(io -> print(io, name, "\t", time()), inflight_path(config) * ".tmp", "w");
                                mv(inflight_path(config) * ".tmp", inflight_path(config); force=true))

function resume!(config, insts)
    rows = Any[]
    p = csv_path(config)
    if isfile(p)
        lines = readlines(p)
        isempty(lines) || lines[1] == join(HEADER, ",") || error("$p: unexpected header, not resuming over it")
        append!(rows, [split(l, ",") for l in lines[2:end] if !isempty(l)])
    end
    done = Set(r[1] for r in rows)
    fi = inflight_path(config)
    if isfile(fi)
        name, t_start = split(strip(read(fi, String)), "\t")
        kf = joinpath(OUTDIR, "KILLED_AT")
        killed_at = isfile(kf) ? parse(Float64, strip(read(kf, String))) : NaN
        if !(name in done) && isfinite(killed_at) && killed_at - parse(Float64, t_start) > 1.5 * WALL
            i = findfirst(x -> x[1] == name, insts)
            fam, sz = i === nothing ? ("", "") : (insts[i][2], insts[i][3])
            push!(rows, (name, config, TAG, fam, sz, -1, -1, "EXTERNAL_KILL", NaN, -1, -1, NaN,
                         round(killed_at - parse(Float64, t_start), digits=3), NaN, -1, NaN, NaN))
            println("RESUME $config: $name was in flight for $(round(killed_at - parse(Float64, t_start))) s when killed -> EXTERNAL_KILL")
            push!(done, name)
        end
        rm(fi; force=true)
    end
    # keep only the trace records of instances with a row (an instance killed in flight is re-run from scratch)
    tp = trace_path(config)
    if isfile(tp)
        lines = readlines(tp)
        keep = [lines[1]; [l for l in lines[2:end] if split(l, ",")[1] in done]]
        open(io -> foreach(l -> println(io, l), keep), tp * ".tmp", "w"); mv(tp * ".tmp", tp; force=true)
    end
    isempty(rows) || (write_csv(p, HEADER, rows); println("RESUME $config: $(length(rows)) rows kept from $p"))
    flush(stdout)
    return rows
end

function main()
    mkpath(OUTDIR)
    insts, warm = instances()
    println("suite=$SUITE configs=$(join(CONFIGS, ",")) device=$DEVICE tag=$TAG wall=$WALL instances=$(length(insts)) ",
            "pathof(MadNCL)=$(pathof(MadNCL))"); flush(stdout)
    # warm-up: one solve per configuration on a small model of the same kind; its solvers are echoed
    cfgfile = joinpath(OUTDIR, "config_$(SUITE)__$(TAG).txt")
    open(cfgfile, "w") do io
        println(io, "suite=$SUITE device=$DEVICE tag=$TAG wall=$WALL tol=$TOL constr_viol_tol=$CVTOL max_iter=$MAX_ITER ",
                "linear_solver=$(LINEAR_SOLVER.linear_solver) suite_ipm=$(SUITE_IPM) pathof(MadNCL)=$(pathof(MadNCL))")
        SUITE == "scopf" && println(io, "scopf_model=$(SCOPF_MODEL)")
        isempty(CONTINGENCY_FILE) || println(io, "contingencies=$(CONTINGENCY_FILE)")
        wm = warm()
        for config in CONFIGS
            slv = make_solver(wm, config)
            echo(io, config, slv)
            if WARMUP
                tw = @elapsed (config == "liftedkkt" ? MadNLP.solve!(slv) : MadNCL.solve!(slv))
                println(io, "WARMUP $config $(round(tw, digits=2)) s")
            end
            reclaim()
        end
    end
    print(read(cfgfile, String)); flush(stdout)

    rows = Dict(c => resume!(c, insts) for c in CONFIGS)
    for (name, fam, sz, build) in insts
        all(c -> any(r -> r[1] == name, rows[c]), CONFIGS) && continue   # every configuration has its row
        tb = time()
        model = try; build(); catch e
            @warn "$name build failed: $(first(split(sprint(showerror, e), '\n')))"; nothing
        end
        build_s = round(time() - tb, digits=3)
        for config in CONFIGS
            any(r -> r[1] == name, rows[config]) && continue
            write_inflight(config, name)
            row = model === nothing ?
                (name, config, TAG, fam, sz, -1, -1, "BUILD_FAILED", NaN, -1, -1, NaN, NaN, build_s, -1, NaN, NaN) :
                solve_row(model, name, fam, sz, build_s, config)
            push!(rows[config], row)
            write_csv(csv_path(config), HEADER, rows[config])
            rm(inflight_path(config); force=true)
            @printf("%s [%s] %s iter=%d nfact=%d wall=%.1f s\n", name, config, row[8], row[10], row[11], row[13])
            flush(stdout)
            reclaim()
        end
        model = nothing; reclaim()
    end
    for c in CONFIGS
        n = count(r -> r[8] == "SOLVE_SUCCEEDED", rows[c])
        println("  $c: $n/$(length(rows[c])) solved -> $(SUITE)__$(c)__$(TAG).csv")
    end
end

main()
