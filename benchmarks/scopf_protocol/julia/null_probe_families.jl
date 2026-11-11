# The constraint-family classifier of null_probe.jl (copied verbatim).
basename_of(v) = (s = JuMP.name(v); i = findfirst('[', s); i === nothing ? s : s[1:i-1])
function family(jm, ci)
    cref = JuMP.constraint_ref_with_index(jm, ci)
    obj = JuMP.constraint_object(cref)
    f, s = obj.func, obj.set
    vs = Set{String}()
    if f isa JuMP.AffExpr
        foreach(v -> push!(vs, basename_of(v)), keys(f.terms))
    elseif f isa JuMP.QuadExpr
        foreach(v -> push!(vs, basename_of(v)), keys(f.aff.terms))
        foreach(t -> (push!(vs, basename_of(t.a)); push!(vs, basename_of(t.b))), keys(f.terms))
    else
        return s isa MOI.EqualTo ? "branch flow equality" : "nonlinear other"
    end
    if f isa JuMP.AffExpr
        s isa MOI.Interval && return "angle limit"
        s isa MOI.EqualTo && "p" in vs && return "bus P balance"   # buses without shunts: JuMP stores an affine row
        s isa MOI.EqualTo && "q" in vs && return "bus Q balance"
        "ρp" in vs && return "droop link"
        "vp" in vs && return "PV/PQ link"
        vs == Set(["va"]) && return "reference angle"
        return "affine other $(sort(collect(vs)))"
    end
    if s isa MOI.EqualTo
        "p" in vs && return "bus P balance"
        "q" in vs && return "bus Q balance"
        "pg" in vs && return "bus P balance"
        "qg" in vs && return "bus Q balance"
        return "quadratic eq other $(sort(collect(vs)))"
    end
    ("ρn" in vs || "ρp" in vs) && return "droop complementarity"
    ("vn" in vs || "vp" in vs) && return "PV/PQ complementarity"
    ("p" in vs && "q" in vs) && return "branch rating"
    return "quadratic other $(sort(collect(vs)))"
end

