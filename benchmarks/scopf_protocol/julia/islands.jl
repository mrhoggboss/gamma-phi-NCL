# WO-69 Addendum C4: per bridge (bridges.jl: edges whose removal disconnects the in-service bus graph), the islanded side
# (without the reference bus): bus ids, load (MW / MVAr), shunts, and every in-service generator with Pmin/Pmax/Qmin/Qmax (MW,
# MVAr). In-service elements of PowerModels' ref, as both models see them.
#   julia --project=benchmarks/envs/screen benchmarks/scopf_protocol/julia/islands.jl <out.csv> <label>=<case.m> ...
# (paper-repro: the scopf-pool file benchmarks/pilot/c4/c4_islands.jl; only the include path of bridges.jl changed)
using PowerModels
PowerModels.silence()
include(joinpath(@__DIR__, "bridges.jl"))
out = open(ARGS[1], "w")
println(out, "net,branch,f_bus,t_bus,isl_nbus,isl_buses,isl_load_mw,isl_load_mvar,isl_shunt_gs_mw,isl_ngen,isl_gens,isl_pmin_mw,isl_pmax_mw")
for a in ARGS[2:end]
    lab, case = split(a, "="; limit=2)
    data = PowerModels.parse_file(String(case)); ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]; base = data["baseMVA"]
    info = network_info(String(case))
    keysb = info.keys; buses = collect(keys(ref[:bus]))
    adj = Dict(b => Tuple{Int,Int}[] for b in buses)
    for l in keysb
        f, t = ref[:branch][l]["f_bus"], ref[:branch][l]["t_bus"]; push!(adj[f], (t, l)); push!(adj[t], (f, l))
    end
    refbus = first(keys(ref[:ref_buses]))
    for l in sort(collect(keys(info.island)))
        seen = Set([refbus]); q = [refbus]
        while !isempty(q)
            u = pop!(q)
            for (v, e) in adj[u]
                (e == l || v in seen) && continue
                push!(seen, v); push!(q, v)
            end
        end
        isl = sort([b for b in buses if !(b in seen)])
        pd = sum((ref[:load][x]["pd"] for b in isl for x in ref[:bus_loads][b]); init=0.0) * base
        qd = sum((ref[:load][x]["qd"] for b in isl for x in ref[:bus_loads][b]); init=0.0) * base
        gs = sum((ref[:shunt][x]["gs"] for b in isl for x in ref[:bus_shunts][b]); init=0.0) * base
        g = sort(vcat([ref[:bus_gens][b] for b in isl]...))
        gstr = join(["$(i):P[$(round(ref[:gen][i]["pmin"]*base, digits=3));$(round(ref[:gen][i]["pmax"]*base, digits=3))]Q[$(round(ref[:gen][i]["qmin"]*base, digits=3));$(round(ref[:gen][i]["qmax"]*base, digits=3))]" for i in g], " ")
        br = ref[:branch][l]
        println(out, join((lab, l, br["f_bus"], br["t_bus"], length(isl), join(isl, " "), round(pd, digits=3), round(qd, digits=3),
                           round(gs, digits=3), length(g), gstr, round(sum((ref[:gen][i]["pmin"] for i in g); init=0.0)*base, digits=3),
                           round(sum((ref[:gen][i]["pmax"] for i in g); init=0.0)*base, digits=3)), ","))
    end
    flush(out)
end
close(out)
