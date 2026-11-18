# The SCOPF contingency lists: case name => the branches whose outage defines scenarios 2, 3, ... (an instance with K
# contingencies uses the first K). Each list file defines `CONTINGENCIES`. By default the two files written by the
# protocol's list builders are merged: instances/scopf_contingencies.jl (the reference networks,
# scopf_protocol/reference_networks.py) and instances/scopf_pglib_contingencies.jl (the PGLIB networks,
# scopf_protocol/build_lists.py). A case found in several files must carry the same list in each.
const DEFAULT_CONTINGENCY_FILES = [joinpath(@__DIR__, "instances", "scopf_contingencies.jl"),
                                   joinpath(@__DIR__, "instances", "scopf_pglib_contingencies.jl")]

function load_contingencies(files)
    merged = Dict{String,Vector{Int}}()
    for f in files
        m = Module()
        Base.include(m, f)
        for (case, list) in Base.invokelatest(getglobal, m, :CONTINGENCIES)
            if haskey(merged, case)
                merged[case] == list || error("$f: the contingency list of $case differs from the one read before it")
            else
                merged[case] = list
            end
        end
    end
    return merged
end
