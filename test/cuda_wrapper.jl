
using CUDA
using CUDSS
using MadNLPGPU

function test_model_gpu(ncl_cpu, ncl_gpu)
    n, m = NLPModels.get_nvar(ncl_gpu), NLPModels.get_ncon(ncl_gpu)
    @test n == NLPModels.get_nvar(ncl_cpu)
    @test m == NLPModels.get_ncon(ncl_cpu)
    # initial position
    x0_cpu = NLPModels.get_x0(ncl_cpu)
    x0_gpu = NLPModels.get_x0(ncl_gpu)
    @test x0_cpu ≈ Array(x0_gpu)
    # objective
    val_cpu = NLPModels.obj(ncl_cpu, x0_cpu)
    val_gpu = NLPModels.obj(ncl_gpu, x0_gpu)
    @test val_cpu ≈ val_gpu
    # constraint
    c_cpu = NLPModels.cons(ncl_cpu, x0_cpu)
    c_gpu = NLPModels.cons(ncl_gpu, x0_gpu)
    @test c_cpu ≈ Array(c_gpu)
    # gradient
    g_cpu = NLPModels.grad(ncl_cpu, x0_cpu)
    g_gpu = NLPModels.grad(ncl_gpu, x0_gpu)
    @test g_cpu ≈ Array(g_gpu)
    # Jacobian sparsity pattern
    nnzj_cpu = NLPModels.get_nnzj(ncl_cpu)
    nnzj_gpu = NLPModels.get_nnzj(ncl_gpu)
    @test nnzj_cpu == nnzj_gpu
    i_cpu = zeros(Int, nnzj_cpu)
    j_cpu = zeros(Int, nnzj_cpu)
    NLPModels.jac_structure!(ncl_cpu, i_cpu, j_cpu)
    i_gpu = CUDA.zeros(Int, nnzj_gpu)
    j_gpu = CUDA.zeros(Int, nnzj_gpu)
    NLPModels.jac_structure!(ncl_gpu, i_gpu, j_gpu)
    @test i_cpu == Array(i_gpu)
    @test j_cpu == Array(j_gpu)
    # Jacobian values
    jac_cpu = zeros(Float64, nnzj_cpu)
    NLPModels.jac_coord!(ncl_cpu, x0_cpu, jac_cpu)
    jac_gpu = CUDA.zeros(Float64, nnzj_gpu)
    NLPModels.jac_coord!(ncl_gpu, x0_gpu, jac_gpu)
    @test jac_cpu ≈ Array(jac_gpu)
    # Hessian sparsity pattern
    nnzh_cpu = NLPModels.get_nnzh(ncl_cpu)
    nnzh_gpu = NLPModels.get_nnzh(ncl_gpu)
    @test nnzh_cpu == nnzh_gpu
    i_cpu = zeros(Int, nnzh_cpu)
    j_cpu = zeros(Int, nnzh_cpu)
    NLPModels.hess_structure!(ncl_cpu, i_cpu, j_cpu)
    i_gpu = CUDA.zeros(Int, nnzh_gpu)
    j_gpu = CUDA.zeros(Int, nnzh_gpu)
    NLPModels.hess_structure!(ncl_gpu, i_gpu, j_gpu)
    @test i_cpu == Array(i_gpu)
    @test j_cpu == Array(j_gpu)
    # Hessian values
    hess_gpu = CUDA.zeros(Float64, nnzh_gpu)
    y_gpu = CUDA.ones(Float64, m)
    NLPModels.hess_coord!(ncl_gpu, x0_gpu, y_gpu, hess_gpu)
    hess_cpu = zeros(Float64, nnzh_cpu)
    y_cpu = ones(Float64, m)
    NLPModels.hess_coord!(ncl_cpu, x0_cpu, y_cpu, hess_cpu)
    @test hess_cpu ≈ Array(hess_gpu)
    return
end

@testset "[CUDA] Test NCL model" begin
    # N.B.: n should not be too small to avoid fatal bug with cuDSS
    #       (solver hanging as the matrix is too small).
    n, m = 100, 5
    # Host evaluator
    nlp_cpu = DenseDummyQP(zeros(Float64, n); m=m)
    ncl_cpu = MadNCL.NCLModel(nlp_cpu)
    # Device evaluator
    nlp_gpu = DenseDummyQP(CUDA.zeros(Float64, n); m=m)
    ncl_gpu = MadNCL.NCLModel(nlp_gpu)

    # Test instantiation of NCLModel on the GPU.
    test_model_gpu(ncl_cpu, ncl_gpu)

    # Test NCL algorithm on the GPU.
    for KKTSystem in [
        MadNCL.K2rAuglagKKTSystem,
        MadNCL.K1sAuglagKKTSystem,
    ]
        res = MadNCL.madncl(
            nlp_gpu;
            print_level=MadNLP.ERROR,
            kkt_system=KKTSystem,
            linear_solver=MadNLPGPU.CUDSSSolver,
            cudss_algorithm=MadNLP.LDL,
        )
        @test res.status == MadNLP.SOLVE_SUCCEEDED
    end
end


#=
    (γ,φ) kernels on the GPU.

    The quadratic kernel uses the closed-form penalty objective, so the testset above never
    runs the generic kernel path on the device. The kernels below force it:
    - `GenericQuadraticKernel`: the quadratic kernel as a distinct type (generic path);
    - `QuarticTestKernel`: φ'' = 1 + t², a non-constant curvature with polynomial growth.
    The kernel solves pass `s_max=1e20` to MadNLP (unrelieved inner termination test).
=#
struct GenericQuadraticKernel <: MadNCL.AbstractKernel end
MadNCL.phi(::GenericQuadraticKernel, λ, t::T) where {T} = t * t / T(2)
MadNCL.dphi(::GenericQuadraticKernel, λ, t::T) where {T} = t
MadNCL.ddphi(::GenericQuadraticKernel, λ, t::T) where {T} = one(T)

struct QuarticTestKernel <: MadNCL.AbstractKernel end
MadNCL.phi(::QuarticTestKernel, λ, t::T) where {T} = t * t / T(2) + (t * t) * (t * t) / T(12)
MadNCL.dphi(::QuarticTestKernel, λ, t::T) where {T} = t + t * t * t / T(3)
MadNCL.ddphi(::QuarticTestKernel, λ, t::T) where {T} = one(T) + t * t

const KERNEL_GPU_OPTS = MadNCL.NCLOptions{Float64}(; verbose=false)

@testset "[CUDA] (γ,φ) NCL on GPU" begin
    n, m = 100, 5
    nlp_cpu = DenseDummyQP(zeros(Float64, n); m=m)
    nlp_gpu = DenseDummyQP(CUDA.zeros(Float64, n); m=m)
    gpu_kw = (linear_solver=MadNLPGPU.CUDSSSolver, cudss_algorithm=MadNLP.LDL,
              print_level=MadNLP.ERROR, s_max=1e20)

    @test isbitstype(MadNCL.PowerKernel{Float64})

    # model callbacks: host ≈ device on the generic path, with per-row λ (a zero row included,
    # for the exact-quadratic guard) and per-row γ
    @testset "model $(nameof(typeof(kernel)))" for kernel in (
        GenericQuadraticKernel(), QuarticTestKernel(), MadNCL.PowerKernel(6.0),
    )
        ncl_cpu = MadNCL.NCLModel(nlp_cpu; kernel=kernel, resid=0.3)
        ncl_gpu = MadNCL.NCLModel(nlp_gpu; kernel=kernel, resid=0.3)
        λh = collect(range(0.0, 1.5; length=m))
        γh = [0.5, 1.0, 2.0, 1e-3, 1e3]
        copyto!(ncl_cpu.λr, λh); copyto!(ncl_gpu.λr, λh)
        copyto!(ncl_cpu.γr, γh); copyto!(ncl_gpu.γr, γh)
        ncl_cpu.ρk[] = 37.0
        ncl_gpu.ρk[] = 37.0
        test_model_gpu(ncl_cpu, ncl_gpu)
    end

    for KKTSystem in (MadNCL.K2rAuglagKKTSystem, MadNCL.K1sAuglagKKTSystem)
        res_quad = MadNCL.madncl(nlp_gpu; ncl_options=KERNEL_GPU_OPTS, kkt_system=KKTSystem, gpu_kw...)
        @test res_quad.status == MadNLP.SOLVE_SUCCEEDED
        for kernel in (GenericQuadraticKernel(), QuarticTestKernel())
            res = MadNCL.madncl(nlp_gpu; ncl_options=KERNEL_GPU_OPTS, kernel=kernel,
                                kkt_system=KKTSystem, gpu_kw...)
            @test res.status == MadNLP.SOLVE_SUCCEEDED
            if kernel isa GenericQuadraticKernel
                @test res.objective ≈ res_quad.objective rtol=1e-6
            end
        end
        # power kernel: λ = 0 reproduces the quadratic kernel
        res0 = MadNCL.madncl(nlp_gpu; ncl_options=KERNEL_GPU_OPTS, kernel=MadNCL.PowerKernel(6.0, 0.0),
                             kkt_system=KKTSystem, gpu_kw...)
        @test res0.status == MadNLP.SOLVE_SUCCEEDED
        @test res0.objective ≈ res_quad.objective rtol=1e-6
        # steep power kernel, λ ≡ 0.5 (regression test for steep-kernel changes; do not relax)
        res5 = MadNCL.madncl(nlp_gpu; ncl_options=KERNEL_GPU_OPTS, kernel=MadNCL.PowerKernel(6.0, 0.5),
                             kkt_system=KKTSystem, gpu_kw...)
        @test res5.status == MadNLP.SOLVE_SUCCEEDED
    end

    # steep kernel through ρ-bumps: equality constraints and a small ρ_init force the penalty
    # ladder (regression test for steep-kernel changes; do not relax)
    nlp_eq = DenseDummyQP(CUDA.zeros(Float64, n); m=m, equality_cons=CuVector(collect(1:2)))
    solver = MadNCL.NCLSolver(nlp_eq;
        ncl_options=MadNCL.NCLOptions{Float64}(; verbose=false, extrapolation=false, rho_init=1e-2),
        kernel=QuarticTestKernel(), kkt_system=MadNCL.K2rAuglagKKTSystem, gpu_kw...)
    diag = Any[]
    res = MadNCL.solve!(solver; diag=diag)
    @test res.status == MadNLP.SOLVE_SUCCEEDED
    @test count(d -> d.branch == :rho_bump, diag) > 0

    # gain law and force gate on the device
    for KKTSystem in (MadNCL.K2rAuglagKKTSystem, MadNCL.K1sAuglagKKTSystem)
        opts = MadNCL.NCLOptions{Float64}(; verbose=false, extrapolation=false,
                                          gain_law=:geometry, gate_metric=:force)
        slv = MadNCL.NCLSolver(nlp_gpu; ncl_options=opts, kkt_system=KKTSystem, gpu_kw...)
        @test slv.gainws isa MadNCL.GainWorkspaceDevice
        res = MadNCL.solve!(slv)
        @test res.status == MadNLP.SOLVE_SUCCEEDED
        @test all(isfinite, Array(slv.ncl.γr))
    end
end
