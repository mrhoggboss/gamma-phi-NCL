# Shared helpers of the benchmark drivers: solution metrics computed on the host, CSV output.

using NLPModels

"""
    constraint_violation(nlp, x)

‖dist(c(x), [lcon, ucon])‖∞ on the original (unscaled) model: equality and inequality rows,
computed on the host. 0 for an unconstrained model.
"""
function constraint_violation(nlp, x)
    m = NLPModels.get_ncon(nlp)
    m == 0 && return 0.0
    c = Array(NLPModels.cons(nlp, x))
    lc = Array(NLPModels.get_lcon(nlp)); uc = Array(NLPModels.get_ucon(nlp))
    v = 0.0
    @inbounds for i in eachindex(c)
        isfinite(lc[i]) && (v = max(v, lc[i] - c[i]))
        isfinite(uc[i]) && (v = max(v, c[i] - uc[i]))
    end
    return Float64(v)
end

n_equalities(nlp) = count(Array(NLPModels.get_lcon(nlp)) .== Array(NLPModels.get_ucon(nlp)))

csv_field(x) = replace(string(x), r"[,\n\r]" => ";")

"""
    write_csv(path, header, rows)

Write `rows` (iterables of fields, in the order of `header`) to `path`, replacing the file.
"""
function write_csv(path, header, rows)
    mkpath(dirname(path))
    tmp = path * ".tmp"
    open(tmp, "w") do io
        println(io, join(header, ","))
        for r in rows
            println(io, join((csv_field(x) for x in r), ","))
        end
    end
    mv(tmp, path; force=true)
    return path
end

const TRACE_FIELDS = (:iter, :rho, :mu, :pr_feas, :eta, :thr, :ratio, :has_converged, :extrapolated,
                      :branch, :extrap_fact, :inner_fact, :inner_iters)

"""
    parse_args(args) -> (positional::Vector{String}, options::Dict{String,String})

Split `--key=value` options from positional arguments.
"""
function parse_args(args)
    pos = String[]; opt = Dict{String,String}()
    for a in args
        if startswith(a, "--")
            k, v = occursin("=", a) ? split(a[3:end], "=", limit=2) : (a[3:end], "true")
            opt[String(k)] = String(v)
        else
            push!(pos, a)
        end
    end
    return pos, opt
end
