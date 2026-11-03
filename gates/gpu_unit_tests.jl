# The GPU testsets (test/cuda_wrapper.jl, unchanged) in the pinned GPU environment. `Pkg.test()` cannot run them on
# Volta GPUs (GV100, sm_70): its sandbox resolves a CUDA toolkit 13, whose ptxas has no sm_70 target, while
# benchmarks/envs/gpu pins CUDA.jl 6.2 with a toolkit that still supports it.
#
#   CUDA_VISIBLE_DEVICES=<d> julia +1.11.2 --project=benchmarks/envs/gpu gates/gpu_unit_tests.jl
using Test, LinearAlgebra, Random
using MadNLP, MadNCL, NLPModels
using CUDA
const TESTDIR = joinpath(@__DIR__, "..", "test")
include(joinpath(TESTDIR, "dummy_qp.jl"))
println("pathof(MadNCL) = ", pathof(MadNCL), "  device = ", CUDA.name(CUDA.device()), "  CUDA.jl ", pkgversion(CUDA))
@testset "GPU" begin
    include(joinpath(TESTDIR, "cuda_wrapper.jl"))
end
