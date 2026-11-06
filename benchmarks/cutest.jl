# CUTEst benchmark on the CPU.
#
#   julia --project=benchmarks/envs/cpu benchmarks/cutest.jl <list> <configs> <solvers> <nworkers> <wall> <outdir> [options]
#
#   <list>     instance list, one CUTEst name per line (benchmarks/instances/cutest_*.txt)
#   <configs>  comma list of S, SP, W, U6A, ablation (benchmarks/arms.jl) and the baselines
#              ipopt (Ipopt), liftedkkt (MadNLP, condensed KKT system), madnlp (MadNLP, augmented KKT system);
#              the baselines run with their acceptable-level termination disabled (Ipopt acceptable_iter = 0,
#              MadNLP acceptable_tol = 0), as every MadNCL configuration but S
#   <solvers>  comma list of linear solvers: ma57 (HSL MA57 with automatic scaling), ldl (MadNLP LDLSolver);
#              the MadNCL configurations use the K2r KKT system; ipopt runs with ma57 only
#   <nworkers> Distributed workers; the tasks (configuration × solver × problem) form one flat queue
#   <wall>     wall-time limit per solve, in seconds (also the success cap of the tables)
#   <outdir>   results: cutest__<config>__<solver>.csv (and trace__<config>__<solver>.csv with --trace);
#              finished tasks are kept under <outdir>/rows and skipped when the run is restarted (see "Restart"
#              below for tasks that were in flight when a run was killed)
#   options    --tol=<t>     optimality and feasibility tolerance of every configuration and baseline (default 1e-8)
#              --cvtol=<t>   constraint-violation tolerance in the original scaling (default 1e-4): the MadNCL
#                            configurations' constr_viol_tol and Ipopt's constr_viol_tol; MadNLP has no such test,
#                            so the two MadNLP baselines run without it (the violation is recorded in every row)
#              --trace       per-outer-iteration records of the MadNCL configurations
#
# Every solve uses max_iter = 3000 and bound_relax_factor = 1e-8. Problems must be decoded before the
# run (the driver decodes missing ones serially on the master; workers load them with decode=false).
using Distributed
include(joinpath(@__DIR__, "common.jl"))

const POS, OPT = parse_args(ARGS)
length(POS) == 6 || error("usage: cutest.jl <list> <configs> <solvers> <nworkers> <wall> <outdir> [--tol=] [--cvtol=] [--trace]")
const LIST = POS[1]
const CONFIGS = String.(split(POS[2], ","))
const SOLVERS = String.(split(POS[3], ","))
const NW = parse(Int, POS[4])
const WALL = parse(Float64, POS[5])
const OUTDIR = abspath(POS[6])
const TRACE = haskey(OPT, "trace")
const TOL = parse(Float64, get(OPT, "tol", "1e-8"))
const CVTOL = parse(Float64, get(OPT, "cvtol", "1e-4"))
const NCL_CONFIGS = ("S", "SP", "W", "U6A", "ablation")
const BASELINES = ("ipopt", "liftedkkt", "madnlp")
for c in CONFIGS; c in NCL_CONFIGS || c in BASELINES || error("unknown configuration $c"); end
for s in SOLVERS; s in ("ma57", "ldl") || error("unknown linear solver $s"); end
const HEADER = (:name, :nvar, :ncon, :n_eq, :status, :iter, :nfact, :time, :viol, :obj, :n_outer, :dual_feas)

problems = String.(filter(!isempty, strip.(readlines(LIST))))
mkpath(OUTDIR)

using CUTEst
isbuilt(name) = isfile(joinpath(CUTEst.libsif_path, "lib$(name)_double.so"))
println("decoding $(count(!isbuilt, problems)) of $(length(problems)) problems"); flush(stdout)
decode_failed = String[]
for p in problems
    isbuilt(p) && continue
    try; finalize(CUTEstModel(p)); catch; push!(decode_failed, p); end
end

addprocs(NW; exeflags="--project=$(Base.active_project())")
@everywhere begin
    include(joinpath($(@__DIR__), "common.jl"))
    include(joinpath($(@__DIR__), "arms.jl"))
    using MadNCL, MadNLP, MadNLPHSL, NLPModels, CUTEst, NLPModelsIpopt, HSL_jll
    const WALL_W = $WALL
    const TRACE_W = $TRACE
    const TOL_W = $TOL
    const CVTOL_W = $CVTOL
    linear_solver_kw(s) = s == "ma57" ? (linear_solver=MadNLPHSL.Ma57Solver, ma57_automatic_scaling=true) :
                                        (linear_solver=MadNLP.LDLSolver,)
    common_ipm(s) = (linear_solver_kw(s)..., bound_relax_factor=1e-8, max_iter=3000, max_wall_time=WALL_W,
                     print_level=MadNLP.ERROR)
    # the two MadNLP baselines, with MadNLP's acceptable-level exit disabled (acceptable_tol = 0), as every
    # configuration but S (protocol of 2026-11-04)
    madnlp_kw(config, s) = (kkt_system=config == "liftedkkt" ? MadNLP.SparseCondensedKKTSystem : MadNLP.SparseKKTSystem,
                            tol=TOL_W, acceptable_tol=0.0, common_ipm(s)...)
    # NCLSolver for a MadNCL configuration
    function ncl_solver(nlp, config, s)
        kernel, opt, ipm = arm_config(config; tol=TOL_W, constr_viol_tol=CVTOL_W)
        return MadNCL.NCLSolver(nlp; ncl_options=opt, kernel=kernel,
                                kkt_system=MadNCL.K2rAuglagKKTSystem, common_ipm(s)..., ipm...)
    end
    function solve_task(name, config, s)
        nlp = CUTEstModel(name; decode=false)
        base = (name, nlp.meta.nvar, nlp.meta.ncon, n_equalities(nlp))
        try
            if config == "ipopt"
                # acceptable_iter = 0 disables Ipopt's acceptable-level termination (protocol of 2026-11-04)
                t = @elapsed r = NLPModelsIpopt.ipopt(nlp; tol=TOL_W, constr_viol_tol=CVTOL_W, max_iter=3000, max_wall_time=WALL_W,
                    acceptable_iter=0, print_level=0, linear_solver="ma57", hsllib=HSL_jll.libhsl_path,
                    ma57_automatic_scaling="yes")
                # Ipopt does not expose its factorization count: the iteration count is recorded (a lower bound)
                return ((base..., string(r.status), r.iter, r.iter, t, constraint_violation(nlp, r.solution),
                         r.objective, -1, r.dual_feas), nothing)
            elseif config in ("liftedkkt", "madnlp")
                t = @elapsed r = MadNLP.madnlp(nlp; madnlp_kw(config, s)...)
                return ((base..., string(r.status), r.iter, r.counters.factorization_cnt, t,
                         constraint_violation(nlp, r.solution), r.objective, -1, r.dual_feas), nothing)
            else
                dg = Any[]
                t = @elapsed begin
                    slv = ncl_solver(nlp, config, s)
                    r = MadNCL.solve!(slv; diag=dg)
                end
                trace = TRACE_W ? [[name; [getproperty(d, f) for f in TRACE_FIELDS]] for d in dg] : nothing
                return ((base..., string(r.status), r.iter, r.counters.factorization_cnt, t,
                         constraint_violation(nlp, r.solution), r.objective, length(dg), r.dual_feas), trace)
            end
        catch e
            msg = "ERROR:" * first(split(sprint(showerror, e), '\n'))
            return ((base..., msg, -1, -1, NaN, NaN, NaN, -1, NaN), nothing)
        finally
            finalize(nlp)
        end
    end
    rowfile(dir, name) = joinpath(dir, name * ".csv")
    function run_task(t, rowdir)
        d = joinpath(rowdir, "$(t.config)__$(t.solver)"); mkpath(d)
        # in-flight stamps: the start time of this task, and the task this worker is on
        open(io -> print(io, time()), joinpath(d, t.name * ".start"), "w")
        open(io -> print(io, "$(t.config)__$(t.solver)/", t.name), joinpath(rowdir, "worker_$(myid()).cur"), "w")
        (row, trace) = solve_task(t.name, t.config, t.solver)
        trace === nothing || write_csv(joinpath(d, t.name * ".trace"), (:name, TRACE_FIELDS...), trace)
        write_csv(rowfile(d, t.name), HEADER_W, [row])
        rm(joinpath(rowdir, "worker_$(myid()).cur"); force=true)
        return (t.name, row[5], myid())
    end
end
@everywhere const HEADER_W = $HEADER

# configuration echo: the full option set of every (configuration, solver), constructed on the first problem
for w in workers()
    println("worker $w pathof(MadNCL) = ", remotecall_fetch(() -> pathof(MadNCL), w))
end
probe = first(p for p in problems if !(p in decode_failed))
open(joinpath(OUTDIR, "config.txt"), "w") do io
    println(io, "list=$LIST configs=$(join(CONFIGS, ",")) solvers=$(join(SOLVERS, ",")) workers=$NW wall=$WALL ",
            "tol=$TOL constr_viol_tol=$CVTOL max_iter=3000 bound_relax_factor=1e-8 pathof(MadNCL)=$(remotecall_fetch(() -> pathof(MadNCL), first(workers())))")
    for c in CONFIGS, s in SOLVERS
        c == "ipopt" && s != "ma57" && continue
        if c in NCL_CONFIGS
            txt = remotecall_fetch(first(workers())) do
                nlp = CUTEstModel(probe; decode=false)
                try
                    sprint(io_ -> echo_arm(io_, c, ncl_solver(nlp, c, s)))
                finally
                    finalize(nlp)
                end
            end
            print(io, replace(txt, "CONFIG $c " => "CONFIG $c [$s] "))
        elseif c == "ipopt"
            println(io, "CONFIG ipopt [ma57] tol=$TOL constr_viol_tol=$CVTOL max_iter=3000 max_wall_time=$WALL acceptable_iter=0 ",
                    "(acceptable-level termination disabled) linear_solver=ma57 ma57_automatic_scaling=yes (options as passed)")
        else
            # read back from a solver constructed with the run's options on the first problem
            txt = remotecall_fetch(first(workers())) do
                nlp = CUTEstModel(probe; decode=false)
                try
                    slv = MadNLP.MadNLPSolver(nlp; madnlp_kw(c, s)...)
                    o = slv.opt
                    "kkt_system=$(nameof(typeof(slv.kkt))) linear_solver=$(nameof(typeof(slv.kkt.linear_solver))) " *
                    "tol=$(o.tol) constr_viol_tol=n/a (MadNLP has no such test) max_iter=$(o.max_iter) " *
                    "max_wall_time=$(o.max_wall_time) bound_relax_factor=$(o.bound_relax_factor) " *
                    "acceptable_tol=$(o.acceptable_tol) acceptable_iter=$(o.acceptable_iter) " *
                    "equality_treatment=$(o.equality_treatment) fixed_variable_treatment=$(o.fixed_variable_treatment)"
                finally
                    finalize(nlp)
                end
            end
            println(io, "CONFIG $c [$s] ", txt)
        end
    end
end
print(read(joinpath(OUTDIR, "config.txt"), String)); flush(stdout)

rowdir = joinpath(OUTDIR, "rows")
tasks = [(name=p, config=c, solver=s) for c in CONFIGS for s in SOLVERS for p in problems
         if !(p in decode_failed) && !(c == "ipopt" && s != "ma57")]
# Restart. A task with a row file is done. A task with a start stamp but no row was in flight when the run was
# killed; if the stall watchdog (benchmarks/paper/watch.sh) recorded the kill in <outdir>/rows/KILLED_AT and the
# task had by then run longer than 1.5 × wall, it is recorded as EXTERNAL_KILL (the solver did not return within
# its budget, e.g. inside a factorization, where no solver checks its wall time; it would hang again) instead of
# being re-run. A worker that dies records WORKER_DIED for the task it was on; the run continues on the others.
taskdir(t) = joinpath(rowdir, "$(t.config)__$(t.solver)")
hasrow(t) = isfile(joinpath(taskdir(t), t.name * ".csv"))
function stamp_row(t, status, elapsed)
    nv, nc, ne = try
        nlp = CUTEstModel(t.name; decode=false)
        try; (nlp.meta.nvar, nlp.meta.ncon, n_equalities(nlp)); finally; finalize(nlp); end
    catch
        (-1, -1, -1)
    end
    write_csv(joinpath(taskdir(t), t.name * ".csv"), HEADER,
              [(t.name, nv, nc, ne, status, -1, -1, elapsed, NaN, NaN, -1, NaN)])
end
kf = joinpath(rowdir, "KILLED_AT")
killed_at = isfile(kf) ? parse(Float64, strip(read(kf, String))) : NaN
for t in tasks
    st = joinpath(taskdir(t), t.name * ".start")
    (hasrow(t) || !isfile(st) || !isfinite(killed_at)) && continue
    ran = killed_at - parse(Float64, strip(read(st, String)))
    if ran > 1.5 * WALL
        stamp_row(t, "EXTERNAL_KILL", round(ran, digits=1))
        println("  $(t.config)__$(t.solver)/$(t.name): in flight for $(round(ran)) s when killed -> EXTERNAL_KILL")
    end
end
foreach(f -> rm(f; force=true), filter(f -> startswith(basename(f), "worker_") && endswith(f, ".cur"),
                                       isdir(rowdir) ? readdir(rowdir; join=true) : String[]))
todo = [t for t in tasks if !hasrow(t)]
println("tasks: $(length(tasks)) ($(length(tasks) - length(todo)) restored from $rowdir), decode failures: $(length(decode_failed))")
flush(stdout)
t0 = time()
while !isempty(todo)
    alive = copy(workers())
    try
        pmap(t -> run_task(t, rowdir), WorkerPool(alive), todo)
        break
    catch e
        dead = setdiff(alive, workers())
        isempty(dead) && rethrow()
        for w in dead
            cur = joinpath(rowdir, "worker_$(w).cur")
            isfile(cur) || continue
            cd_, name = split(strip(read(cur, String)), "/")
            c_, s_ = split(cd_, "__")
            t = (name=String(name), config=String(c_), solver=String(s_))
            hasrow(t) || stamp_row(t, "WORKER_DIED", NaN)
            println("  WORKER $w DIED on $cd_/$name -> WORKER_DIED; $(length(workers())) workers left"); flush(stdout)
            rm(cur; force=true)
        end
        isempty(workers()) && error("every worker died")
        global todo = [t for t in todo if !hasrow(t)]
    end
end
println("solved $(length(tasks) - count(!hasrow, tasks)) of $(length(tasks)) tasks; $(round(time() - t0, digits=1)) s this run"); flush(stdout)

# assemble one CSV per (configuration, solver), in list order
for c in CONFIGS, s in SOLVERS
    c == "ipopt" && s != "ma57" && continue
    d = joinpath(rowdir, "$(c)__$(s)")
    rows = String[]; trace = String[]
    for p in problems
        if p in decode_failed
            push!(rows, join((p, -1, -1, -1, "DECODE_ERROR", -1, -1, NaN, NaN, NaN, -1, NaN), ","))
            continue
        end
        f = joinpath(d, p * ".csv")
        isfile(f) && push!(rows, readlines(f)[2])
        ft = joinpath(d, p * ".trace")
        isfile(ft) && append!(trace, readlines(ft)[2:end])
    end
    open(joinpath(OUTDIR, "cutest__$(c)__$(s).csv"), "w") do io
        println(io, join(HEADER, ",")); foreach(r -> println(io, r), rows)
    end
    if TRACE && c in NCL_CONFIGS
        open(joinpath(OUTDIR, "trace__$(c)__$(s).csv"), "w") do io
            println(io, join((:name, TRACE_FIELDS...), ",")); foreach(r -> println(io, r), trace)
        end
    end
    nsucc = count(r -> split(r, ",")[5] in ("SOLVE_SUCCEEDED", "first_order"), rows)
    println("  $(c) [$s]: $(nsucc)/$(length(rows)) solved -> cutest__$(c)__$(s).csv")
end
rmprocs(workers())
