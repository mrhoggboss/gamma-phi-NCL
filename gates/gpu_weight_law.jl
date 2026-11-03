# Weight law on the GPU: run (γ,φ)-MadNCL on a small SCOPF instance with the device weight workspace, then apply
# one more update of the weights with the device method and with the host method to the same Jacobian and the same
# previous weights, and compare (the two differ only in the order of the reductions).
#
#   CUDA_VISIBLE_DEVICES=<d> julia +1.11.2 --project=benchmarks/envs/gpu gates/gpu_weight_law.jl <data_dir> [case] [K]
using CUDA, CUDSS, MadNLPGPU, MadNCL, MadNLP, ExaModels, NLPModels
CUDA.allowscalar(true)
include(joinpath(@__DIR__, "..", "benchmarks", "arms.jl"))
include(joinpath(@__DIR__, "..", "benchmarks", "models", "scopf_model.jl"))
include(joinpath(@__DIR__, "..", "benchmarks", "instances", "scopf_contingencies.jl"))
const DATA = ARGS[1]
const CASE = length(ARGS) >= 2 ? ARGS[2] : "case118"
const K = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 10
println("pathof(MadNCL) = ", pathof(MadNCL), "  device = ", CUDA.name(CUDA.device()))

jm = scopf_model(joinpath(DATA, CASE * ".m"), CONTINGENCIES[CASE][1:K]; adjust=:mpecdroop, voltage_control=:pvpq,
                 tau_relax=0.0, scale_obj=1e-4, scale_cc=1.0)
model = ExaModels.ExaModel(jm; prod=true, backend=CUDABackend())
kernel, opt, ipm = arm_config("W")
slv = MadNCL.NCLSolver(model; ncl_options=opt, kernel=kernel, kkt_system=MadNCL.K2rAuglagKKTSystem,
                       linear_solver=MadNLPGPU.CUDSSSolver, cudss_algorithm=MadNLP.LDL, max_iter=3000,
                       print_level=MadNLP.ERROR, richardson_tol=1e-12, richardson_max_iter=20, cudss_pivot_epsilon=1e-10)
ws = slv.weightws
println("weight workspace: ", nameof(typeof(ws)))
@assert ws isa MadNCL.WeightWorkspaceDevice
dg = Any[]
r = MadNCL.solve!(slv; diag=dg)
γ = Array(slv.ncl.γr)
println("solve: $(r.status) iter=$(r.iter) nfact=$(r.counters.factorization_cnt) outers=$(length(dg)) ",
        "weights: min=$(minimum(γ)) max=$(maximum(γ)) n≠1=$(count(!=(1.0), γ)) of $(length(γ))")

# one more update from the same state: the device method on the GPU solver, the host method on a CPU solver of
# the same model holding host copies of the Jacobian values and of the previous weights
γprev = copy(slv.ncl.γr)
jac_h = Array(MadNLP.get_jacobian(slv.ipm.kkt))
cpu = MadNCL.NCLSolver(ExaModels.ExaModel(jm; prod=true); ncl_options=opt, kernel=kernel,
                       kkt_system=MadNCL.K2rAuglagKKTSystem, linear_solver=MadNLP.LDLSolver, print_level=MadNLP.ERROR)
@assert cpu.weightws isa MadNCL.WeightWorkspace
@assert length(MadNLP.get_jacobian(cpu.ipm.kkt)) == length(jac_h)
@assert cpu.weightws.rows == Vector{Int}(Array(let Ji = MadNLP.create_array(slv.ipm.cb, Int32, slv.ipm.cb.nnzj),
        Jj = MadNLP.create_array(slv.ipm.cb, Int32, slv.ipm.cb.nnzj); MadNLP._jac_sparsity_wrapper!(slv.ipm.cb, Ji, Jj); Ji end)[1:length(ws.jv2)])
for α in (0.5, 1.0)
    copyto!(slv.ncl.γr, γprev)
    MadNCL._update_weights!(slv, ws, α)
    γd = Array(slv.ncl.γr)
    copyto!(MadNLP.get_jacobian(cpu.ipm.kkt), jac_h)
    copyto!(cpu.ncl.γr, Array(γprev))
    MadNCL._update_weights!(cpu, cpu.weightws, α)
    γh = cpu.ncl.γr
    d = maximum(abs.(γd .- γh) ./ max.(abs.(γh), 1e-300))
    println("alpha=$α: device vs host weights, max relative difference = $d over $(length(γh)) rows ",
            "(bitwise equal rows: $(count(γd .== γh)); range $(minimum(γh)) .. $(maximum(γh)))")
end
copyto!(slv.ncl.γr, γprev)
println("GPU_WEIGHT_LAW_DONE")
