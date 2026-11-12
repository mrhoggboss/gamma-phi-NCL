# Census of the CUTEst population at the starting point CUTEst provides (CPU, seconds per problem).
#
#   julia --project=benchmarks/envs/cpu benchmarks/cutest_x0_census.jl [<list>] [<out.csv>]
#     (defaults: benchmarks/instances/cutest_pop1070.txt, benchmarks/instances/cutest_x0_census.csv)
#
# For every problem: f(x0), grad f(x0), c(x0) and the Jacobian values J(x0), evaluated at x0 = nlp.meta.x0 exactly as
# CUTEst provides it (NOT projected into the bounds), and whether x0 lies within its variable bounds. Columns:
#   name, finite_f, finite_grad, finite_c, finite_jac (1 = every entry finite; c and J are 1 when the problem has no
#   constraints), x0_in_bounds (1 = lvar <= x0 <= uvar componentwise), first_nonfinite (the first non-finite value in
#   the order f, grad, c, J: "<kind>[<index>]=<value>", or "error: ..." when an evaluation throws; empty if none).
# Problems must be decoded already (benchmarks/cutest.jl decodes the population before a run).
using CUTEst, NLPModels

const BENCH = @__DIR__
const LIST = length(ARGS) >= 1 ? ARGS[1] : joinpath(BENCH, "instances", "cutest_pop1070.txt")
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(BENCH, "instances", "cutest_x0_census.csv")

function first_bad(kind, v)
    i = findfirst(!isfinite, v)
    return i === nothing ? "" : "$(kind)[$(i)]=$(v[i])"
end

names = String.(filter(!isempty, strip.(readlines(LIST))))
open(OUT, "w") do io
    println(io, "name,finite_f,finite_grad,finite_c,finite_jac,x0_in_bounds,first_nonfinite")
    for (j, name) in enumerate(names)
        nlp = CUTEstModel(name; decode=false)
        row = try
            x0 = copy(nlp.meta.x0)
            inb = all(nlp.meta.lvar .<= x0 .<= nlp.meta.uvar)
            f = [obj(nlp, x0)]
            g = grad(nlp, x0)
            m = nlp.meta.ncon
            c = m > 0 ? cons(nlp, x0) : Float64[]
            J = m > 0 ? jac_coord(nlp, x0) : Float64[]
            b = filter(!isempty, [first_bad("f", f), first_bad("grad", g), first_bad("c", c), first_bad("jac", J)])
            bad = isempty(b) ? "" : b[1]
            (Int(all(isfinite, f)), Int(all(isfinite, g)), Int(all(isfinite, c)), Int(all(isfinite, J)), Int(inb), bad)
        catch err
            (-1, -1, -1, -1, -1, "error: " * replace(sprint(showerror, err), r"[,\n]" => ";")[1:min(end, 120)])
        finally
            finalize(nlp)
        end
        println(io, join((name, row...), ",")); flush(io)
        j % 100 == 0 && (println("$j / $(length(names))"); flush(stdout))
    end
end
println("wrote ", OUT)
