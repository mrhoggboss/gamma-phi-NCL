# Security-constrained AC optimal power flow written as an MPCC (SCOPF): multi-scenario polar AC-OPF in
# which scenario k removes one branch, with generator-recourse and PV/PQ-switching complementarity rows.
#
# Source: the SCOPF model of the MadNCL paper's benchmark harness (`benchmarks/OPF/scopf.jl` of the
# pre-release MadNCL.jl, as vendored in github.com/SanjayJohnson02/ACOPF under acopf_scratch/MadNCL.jl-main),
# maintained as `models/scopf.jl` in github.com/frapac/pscc-scopf (F. Pacaud) and packaged in
# github.com/MadNLP/MPCCbenchmark.jl. Modified here: JuMP + PowerModels only (the original also imports
# Ipopt, HSL and NLPModelsJuMP), and the keyword arguments below.
#
#   tau_relax   right-hand side of the complementarity rows ρ·(bound − var) ≤ tau_relax (0: hard product)
#   scale_obj   objective scaling, scale_cc   scaling of the complementarity rows (applied as in
#               pscc-scopf `models/scopf.jl`; the defaults 1.0 / 1.0 leave the model unscaled)
using JuMP
using PowerModels
PowerModels.silence()

function scopf_model(file_name, contingencies; load_factor=1.0, adjust=:droop, voltage_control=:none,
                     tau_relax=0.0, scale_obj=1.0, scale_cc=1.0)
    data = PowerModels.parse_file(file_name)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]

    ngen = length(ref[:gen])
    alpha = ones(ngen)

    # Parse contingencies
    K = length(contingencies) + 1

    # Build model
    model = JuMP.Model()

    JuMP.@variable(model, va[i in keys(ref[:bus]), 1:K])
    JuMP.@variable(model, ref[:bus][i]["vmin"] <= vm[i in keys(ref[:bus]), 1:K] <= ref[:bus][i]["vmax"], start=1.0)
    JuMP.@variable(model, ref[:gen][i]["pmin"] <= pg[i in keys(ref[:gen]), 1:K] <= ref[:gen][i]["pmax"])
    JuMP.@variable(model, ref[:gen][i]["qmin"] <= qg[i in keys(ref[:gen]), 1:K] <= ref[:gen][i]["qmax"])
    JuMP.@variable(model, -ref[:branch][l]["rate_a"] <= p[(l,i,j) in ref[:arcs], 1:K] <= ref[:branch][l]["rate_a"])
    JuMP.@variable(model, -ref[:branch][l]["rate_a"] <= q[(l,i,j) in ref[:arcs], 1:K] <= ref[:branch][l]["rate_a"])
    if adjust == :mpecdroop
        JuMP.@variable(model, 0.0 <= ρp[i in keys(ref[:gen]), 2:K])
        JuMP.@variable(model, 0.0 <= ρn[i in keys(ref[:gen]), 2:K])
    end
    if voltage_control == :pvpq
        JuMP.@variable(model, 0.0 <= vp[i in keys(ref[:gen]), 2:K])
        JuMP.@variable(model, 0.0 <= vn[i in keys(ref[:gen]), 2:K])
    end

    # Automatic adjustment of generators
    JuMP.@variable(model, Δ[1:K-1])

    JuMP.@objective(model, Min, scale_obj * sum(gen["cost"][1]*pg[i, 1]^2 + gen["cost"][2]*pg[i, 1] + gen["cost"][3] for (i,gen) in ref[:gen]))

    for k in 2:K
        # Droop control
        for (j, i) in enumerate(keys(ref[:gen]))
            pmin, pmax = ref[:gen][i]["pmin"], ref[:gen][i]["pmax"]
            if adjust == :droop
                @constraint(model, pg[i, k] == pg[i, 1] + alpha[j] * Δ[k-1])
            elseif adjust == :mpecdroop
                @constraint(model, ρp[i, k] - ρn[i, k] == pg[i, k] - pg[i, 1] - alpha[j] * Δ[k-1])
                @constraint(model, scale_cc * ρn[i, k] * (pmax - pg[i, k]) <= tau_relax)
                @constraint(model, scale_cc * ρp[i, k] * (pg[i, k] - pmin) <= tau_relax)
                # @constraint(model, [ρn[i, k], (pmax - pg[i, k])] in MOI.Complements(2))
                # @constraint(model, [ρp[i, k], (pg[i, k] - pmin)] in MOI.Complements(2))
            elseif adjust == :preventive
                @constraint(model, pg[i, k] == pg[i, 1])
            elseif adjust == :relaxed
                Δp = pmax - pmin
                @constraint(model, - 0.1 * Δp <= pg[i, k] - pg[i, 1] <= 0.1 * Δp)
            end
        end
        # Voltage magnitude are not adjusted at PV buses
        for g in keys(ref[:gen])
            b = ref[:gen][g]["gen_bus"]
            if voltage_control == :pvpq
                qmin, qmax = ref[:gen][g]["qmin"], ref[:gen][g]["qmax"]
                @constraint(model, vp[g, k] - vn[g, k] == vm[b, k] - vm[b, 1])
                if isfinite(qmax)
                    @constraint(model, scale_cc * vn[g, k] * (qmax - qg[g, k]) <= tau_relax)
                    # @constraint(model, [vn[g, k], (qmax - qg[g, k])] in MOI.Complements(2))
                end
                if isfinite(qmin)
                    @constraint(model, scale_cc * vp[g, k] * (qg[g, k] - qmin) <= tau_relax)
                    # @constraint(model, [vp[g, k], (qg[g, k] - qmin)] in MOI.Complements(2))
                end
            else
                @constraint(model, vm[b, k] == vm[b, 1])
            end
        end
        # Set flux to 0
        for (l, i, j) in ref[:arcs]
            if l == contingencies[k-1]
                @constraint(model, p[(l, i, j), k] == 0.0)
                @constraint(model, q[(l, i, j), k] == 0.0)
            end
        end
    end

    for k in 1:K
        for (i, bus) in ref[:ref_buses]
            JuMP.@constraint(model, va[i, k] == 0)
        end

        for (i,bus) in ref[:bus]
            bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

            JuMP.@constraint(model,
                sum(p[a, k] for a in ref[:bus_arcs][i]) ==
                sum(pg[g, k] for g in ref[:bus_gens][i]) -
                sum(load_factor * load["pd"] for load in bus_loads) -
                sum(shunt["gs"] for shunt in bus_shunts)*vm[i, k]^2
            )

            JuMP.@constraint(model,
                sum(q[a, k] for a in ref[:bus_arcs][i]) ==
                sum(qg[g, k] for g in ref[:bus_gens][i]) -
                sum(load_factor * load["qd"] for load in bus_loads) +
                sum(shunt["bs"] for shunt in bus_shunts)*vm[i, k]^2
            )
        end

        # Branch power flow physics and limit constraints
        for (i,branch) in ref[:branch]
            if (k >= 2) && i == contingencies[k-1]
                continue
            end
            f_idx = (i, branch["f_bus"], branch["t_bus"])
            t_idx = (i, branch["t_bus"], branch["f_bus"])

            p_fr = p[f_idx, k]
            q_fr = q[f_idx, k]
            p_to = p[t_idx, k]
            q_to = q[t_idx, k]

            vm_fr = vm[branch["f_bus"], k]
            vm_to = vm[branch["t_bus"], k]
            va_fr = va[branch["f_bus"], k]
            va_to = va[branch["t_bus"], k]

            g, b = PowerModels.calc_branch_y(branch)
            tr, ti = PowerModels.calc_branch_t(branch)
            ttm = tr^2 + ti^2
            g_fr = branch["g_fr"]
            b_fr = branch["b_fr"]
            g_to = branch["g_to"]
            b_to = branch["b_to"]

            # From side of the branch flow
            JuMP.@constraint(model, p_fr ==  (g+g_fr)/ttm*vm_fr^2 + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )
            JuMP.@constraint(model, q_fr == -(b+b_fr)/ttm*vm_fr^2 - (-b*tr-g*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )

            # To side of the branch flow
            JuMP.@constraint(model, p_to ==  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )
            JuMP.@constraint(model, q_to == -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )

            # Apparent power limit, from side and to side
            JuMP.@constraint(model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
            JuMP.@constraint(model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
        end
    end

    return model
end
