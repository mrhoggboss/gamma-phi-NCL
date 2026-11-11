# WO-69: in-service branches of a case and its bridges (edges whose removal disconnects the bus graph; parallel
# branches are distinct edges), each bridge annotated with the islanded component = the side WITHOUT the reference bus:
# bus count, load (MW = Σ pd · baseMVA), generators (count, Σ pmax · baseMVA), in-service elements of PowerModels' ref.
using PowerModels
function network_info(case)
    data = PowerModels.parse_file(case)
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    base = data["baseMVA"]
    keysb = sort(collect(keys(ref[:branch])))
    buses = collect(keys(ref[:bus]))
    adj = Dict(b => Tuple{Int,Int}[] for b in buses)
    for l in keysb
        f, t = ref[:branch][l]["f_bus"], ref[:branch][l]["t_bus"]
        push!(adj[f], (t, l)); push!(adj[t], (f, l))
    end
    disc = Dict{Int,Int}(); low = Dict{Int,Int}(); bridges = Set{Int}(); timer = Ref(0)
    for s in buses
        haskey(disc, s) && continue
        stack = [(s, 0, 1)]; disc[s] = low[s] = (timer[] += 1)
        while !isempty(stack)
            u, pe, i = stack[end]
            if i <= length(adj[u])
                stack[end] = (u, pe, i + 1)
                v, l = adj[u][i]
                l == pe && continue
                if !haskey(disc, v)
                    disc[v] = low[v] = (timer[] += 1); push!(stack, (v, l, 1))
                else
                    low[u] = min(low[u], disc[v])
                end
            else
                pop!(stack)
                if !isempty(stack)
                    p = stack[end][1]
                    low[p] = min(low[p], low[u])
                    low[u] > disc[p] && push!(bridges, pe)
                end
            end
        end
    end
    refbus = first(keys(ref[:ref_buses]))
    loadmw = Dict(b => sum((ref[:load][l]["pd"] for l in ref[:bus_loads][b]); init=0.0) * base for b in buses)
    gens = Dict(b => ref[:bus_gens][b] for b in buses)
    island = Dict{Int,NamedTuple}()
    for l in bridges                                     # BFS from the reference bus without edge l
        seen = Set([refbus]); q = [refbus]
        while !isempty(q)
            u = pop!(q)
            for (v, e) in adj[u]
                (e == l || v in seen) && continue
                push!(seen, v); push!(q, v)
            end
        end
        isl = [b for b in buses if !(b in seen)]
        g = vcat([gens[b] for b in isl]...)
        island[l] = (nbus=length(isl), load_mw=sum((loadmw[b] for b in isl); init=0.0), ngen=length(g),
                     pmax_mw=sum((ref[:gen][i]["pmax"] for i in g); init=0.0) * base)
    end
    return (keys=keysb, island=island, nbus=length(buses), ngen=length(ref[:gen]))
end
