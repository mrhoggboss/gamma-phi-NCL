#=
    Penalty kernels and the (γ,φ) NCL model.
=#

@testset "Penalty kernels" begin
    @testset "isbits" begin
        @test isbitstype(MadNCL.QuadraticKernel)
        @test isbitstype(MadNCL.PowerKernel{Float64})
    end

    @testset "normalization φ(0) = φ'(0) = 0, φ''(0) = 1" for (k, λ) in (
        (MadNCL.QuadraticKernel(), 0.0),
        (MadNCL.PowerKernel(6.0), 0.01),
        (MadNCL.PowerKernel(4.0), 2.0),
    )
        @test MadNCL.phi(k, λ, 0.0) == 0.0
        @test MadNCL.dphi(k, λ, 0.0) == 0.0
        @test MadNCL.ddphi(k, λ, 0.0) == 1.0
    end

    @testset "derivatives (FiniteDiff) p=$p λ=$λ" for p in (4.0, 6.0), λ in (0.0, 0.01, 1.0)
        k = MadNCL.PowerKernel(p)
        for t in (-2.3, -0.7, -1e-3, 0.0, 1e-3, 0.9, 3.1)
            dphi_fd = FiniteDiff.finite_difference_derivative(s -> MadNCL.phi(k, λ, s), t)
            ddphi_fd = FiniteDiff.finite_difference_derivative(s -> MadNCL.dphi(k, λ, s), t)
            @test MadNCL.dphi(k, λ, t) ≈ dphi_fd rtol=1e-5 atol=1e-6
            @test MadNCL.ddphi(k, λ, t) ≈ ddphi_fd rtol=1e-5 atol=1e-6
            @test MadNCL.phi(k, λ, t) ≈ t^2 / 2 + λ * abs(t)^p / p
        end
    end

    @testset "PowerKernel: λ = 0 is exactly quadratic" begin
        k = MadNCL.PowerKernel(6.0)
        kq = MadNCL.QuadraticKernel()
        for t in (-2.3, -1e-3, 0.0, 0.9, 3.1)
            @test MadNCL.phi(k, 0.0, t) == MadNCL.phi(kq, 0.0, t)
            @test MadNCL.dphi(k, 0.0, t) == MadNCL.dphi(kq, 0.0, t)
            @test MadNCL.ddphi(k, 0.0, t) == MadNCL.ddphi(kq, 0.0, t)
        end
        # including where |t|^p overflows (0 * Inf would be NaN)
        @test MadNCL.phi(k, 0.0, 1e100) == 5e199
        @test MadNCL.dphi(k, 0.0, -1e150) == -1e150
        @test MadNCL.ddphi(k, 0.0, 1e200) == 1.0
    end

    @testset "PowerKernel: λ initializes NCLModel.λr" begin
        ncl = MadNCL.NCLModel(HS15Model(); kernel=MadNCL.PowerKernel(6.0, 0.25))
        @test all(ncl.λr .== 0.25)
        @test all(ncl.γr .== 1.0)
        ncl_q = MadNCL.NCLModel(HS15Model())
        @test all(ncl_q.λr .== 0.0)
    end
end

@testset "(γ,φ) NCL model" begin
    @testset "callbacks (FiniteDiff), $(name)" for (name, kernel, λ, γ) in (
        ("quadratic, γ ≠ 1", MadNCL.QuadraticKernel(), [0.0, 0.0], [0.4, 2.5]),
        ("power, per-row λ", MadNCL.PowerKernel(6.0), [0.5, 1.2], [1.0, 1.0]),
        ("power, per-row λ and γ", MadNCL.PowerKernel(6.0), [0.0, 1.2], [0.4, 2.5]),
    )
        ncl = MadNCL.NCLModel(HS15Model(); kernel=kernel, resid=0.3)
        ncl.ρk[] = 10.0
        ncl.λr .= λ
        ncl.γr .= γ
        test_nlp_model(ncl)
        # penalty Σ(γ/ρ)φ(−ρr), force −yk − γφ', curvature γρφ''
        xr = copy(NLPModels.get_x0(ncl)); xr .+= 0.1 .* (1:length(xr))
        r = xr[ncl.nx+1:end]; ρ = ncl.ρk[]
        pen = sum(γ[i] * MadNCL.phi(kernel, λ[i], -ρ * r[i]) for i in 1:2) / ρ
        @test NLPModels.obj(ncl, xr) - NLPModels.obj(HS15Model(), xr[1:ncl.nx]) + dot(ncl.yk, r) ≈ pen rtol=1e-14
        g = NLPModels.grad(ncl, xr)
        @test g[ncl.nx+1:end] ≈ [-ncl.yk[i] - γ[i] * MadNCL.dphi(kernel, λ[i], -ρ * r[i]) for i in 1:2] rtol=1e-14
        H = zeros(NLPModels.get_nnzh(ncl)); NLPModels.hess_coord!(ncl, xr, ones(2), H)
        @test H[end-1:end] ≈ [γ[i] * ρ * MadNCL.ddphi(kernel, λ[i], -ρ * r[i]) for i in 1:2] rtol=1e-14
    end

    @testset "γ ≡ 1, quadratic kernel: bitwise the classical penalty" begin
        ncl = MadNCL.NCLModel(HS15Model(); resid=0.3)
        ncl.ρk[] = 10.0
        @test all(ncl.γr .== 1.0)
        xr = copy(NLPModels.get_x0(ncl)); xr .+= 0.1 .* (1:length(xr))
        x, r = xr[1:ncl.nx], xr[ncl.nx+1:end]
        ρ = ncl.ρk[]
        @test NLPModels.obj(ncl, xr) == NLPModels.obj(HS15Model(), x) + (-dot(ncl.yk, r) + ρ * dot(r, r) / 2)
        g = NLPModels.grad(ncl, xr)
        @test g[ncl.nx+1:end] == .-ncl.yk .+ ρ .* r
        H = zeros(NLPModels.get_nnzh(ncl)); NLPModels.hess_coord!(ncl, xr, ones(2), H)
        @test H[end-1:end] == [ρ, ρ]
    end

    @testset "γ ≡ 1, power kernel: bitwise the γ-free formula" begin
        k = MadNCL.PowerKernel(6.0, 0.01)
        ncl = MadNCL.NCLModel(HS15Model(); kernel=k, resid=0.3)
        ncl.ρk[] = 10.0
        xr = copy(NLPModels.get_x0(ncl)); xr .+= 0.1 .* (1:length(xr))
        r = xr[ncl.nx+1:end]; ρ = ncl.ρk[]
        g = NLPModels.grad(ncl, xr)
        @test g[ncl.nx+1:end] == .-ncl.yk .- MadNCL.dphi.(Ref(k), 0.01, .-(ρ .* r))
        @test MadNCL._penalty_obj(ncl, ρ, r) == mapreduce(ri -> MadNCL.phi(k, 0.01, -ρ * ri), +, r; init=0.0) / ρ
        @test NLPModels.obj(ncl, xr) == NLPModels.obj(HS15Model(), xr[1:ncl.nx]) +
                                        (-dot(ncl.yk, r) + MadNCL._penalty_obj(ncl, ρ, r))
    end

    @testset "penalty sum is a sequential left fold" begin
        # the penalty objective must not depend on a pairwise reduction tree
        k = MadNCL.PowerKernel(6.0)
        N = 4000
        v = [(-1.0)^i * 10.0^(-8 + 16 * (i % 7) / 7) for i in 1:N]
        γ = [1.0 + (i % 3) for i in 1:N]
        λ = fill(0.01, N)
        vals = γ .* MadNCL.phi.(Ref(k), λ, .-(3.0 .* v))
        @test MadNCL._penalty_obj(k, γ, λ, 3.0, v) == foldl(+, vals; init=0.0) / 3.0
    end
end

@testset "(γ,φ) NCL algorithm" begin
    @testset "power kernel λ = 0 reproduces the quadratic kernel" begin
        opts = MadNCL.NCLOptions{Float64}(verbose=false)
        s_q = MadNCL.madncl(HS15Model(); ncl_options=opts, print_level=MadNLP.ERROR)
        s_0 = MadNCL.madncl(HS15Model(); ncl_options=opts, kernel=MadNCL.PowerKernel(6.0, 0.0),
                            print_level=MadNLP.ERROR)
        @test s_0.status == s_q.status == MadNLP.SOLVE_SUCCEEDED
        @test s_0.iter == s_q.iter
        @test s_0.objective ≈ s_q.objective rtol=1e-12
    end

    @testset "power kernel, weight law and force gate on HS15 ($(kkt))" for kkt in (
        MadNCL.K2rAuglagKKTSystem, MadNCL.K1sAuglagKKTSystem,
    )
        ref = MadNCL.madncl(HS15Model(); ncl_options=MadNCL.NCLOptions{Float64}(verbose=false),
                            kkt_system=kkt, print_level=MadNLP.ERROR)
        @test ref.status == MadNLP.SOLVE_SUCCEEDED
        for (kernel, opts) in (
            (MadNCL.PowerKernel(6.0, 0.01), MadNCL.NCLOptions{Float64}(verbose=false, extrapolation=false)),
            (MadNCL.QuadraticKernel(), MadNCL.NCLOptions{Float64}(verbose=false, extrapolation=false,
                weight_law=:geometry, gate_metric=:force)),
            (MadNCL.PowerKernel(6.0, 0.01), MadNCL.NCLOptions{Float64}(verbose=false, extrapolation=false,
                weight_law=:geometry, gate_metric=:force)),
        )
            stats = MadNCL.madncl(HS15Model(); ncl_options=opts, kernel=kernel, kkt_system=kkt,
                                  print_level=MadNLP.ERROR)
            @test stats.status == MadNLP.SOLVE_SUCCEEDED
            @test stats.objective ≈ ref.objective rtol=1e-6
            @test stats.solution ≈ ref.solution rtol=1e-6
        end
    end

    @testset "force gate at unit weights = residual gate (power kernel, HS15, $(kkt))" for kkt in (
        MadNCL.K2rAuglagKKTSystem, MadNCL.K1sAuglagKKTSystem,
    )
        # |φ'(−ρ rᵢ)| ≤ φ'(ρ thr) ⟺ |rᵢ| ≤ thr for an odd increasing φ': the two gates take the same decisions
        runs = map((:residual, :force)) do gate
            solver = MadNCL.NCLSolver(HS15Model();
                ncl_options=MadNCL.NCLOptions{Float64}(verbose=false, extrapolation=false, gate_metric=gate),
                kernel=MadNCL.PowerKernel(6.0, 0.01), kkt_system=kkt, print_level=MadNLP.ERROR)
            dg = Any[]
            stats = MadNCL.solve!(solver; diag=dg)
            (stats, [d.branch for d in dg])
        end
        (s_res, b_res), (s_frc, b_frc) = runs
        @test s_res.status == s_frc.status == MadNLP.SOLVE_SUCCEEDED
        @test b_res == b_frc
        @test s_res.iter == s_frc.iter
        @test s_res.counters.factorization_cnt == s_frc.counters.factorization_cnt
    end

    @testset "diag records" begin
        nlp = HS15Model()
        solver = MadNCL.NCLSolver(nlp; ncl_options=MadNCL.NCLOptions{Float64}(verbose=false),
                                  print_level=MadNLP.ERROR)
        diag = Any[]
        stats = MadNCL.solve!(solver; diag=diag)
        @test length(diag) >= 1
        @test propertynames(diag[1]) == (:iter, :rho, :mu, :pr_feas, :eta, :thr, :ratio,
            :has_converged, :extrapolated, :branch, :extrap_fact, :inner_fact, :inner_iters)
        @test [d.iter for d in diag] == collect(1:length(diag))
        @test sum(d.inner_iters for d in diag) == stats.iter
    end

    @testset "budget edge: a success on the last outer iteration is reported as a success" begin
        opts = MadNCL.NCLOptions{Float64}(verbose=false)
        d = Any[]
        full = MadNCL.solve!(MadNCL.NCLSolver(HS15Model(); ncl_options=opts, print_level=MadNLP.ERROR); diag=d)
        K = length(d)
        @test full.status == MadNLP.SOLVE_SUCCEEDED
        cut = MadNCL.madncl(HS15Model(); print_level=MadNLP.ERROR,
            ncl_options=MadNCL.NCLOptions{Float64}(verbose=false, max_auglag_iter=K))
        @test cut.status == MadNLP.SOLVE_SUCCEEDED
        @test cut.solution == full.solution
        short = MadNCL.madncl(HS15Model(); print_level=MadNLP.ERROR,
            ncl_options=MadNCL.NCLOptions{Float64}(verbose=false, max_auglag_iter=K - 1))
        @test short.status == MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
    end

    @testset "option validation" begin
        @test_throws ErrorException MadNCL.NCLSolver(HS15Model();
            ncl_options=MadNCL.NCLOptions{Float64}(weight_law=:bogus))
        @test_throws ErrorException MadNCL.NCLSolver(HS15Model();
            ncl_options=MadNCL.NCLOptions{Float64}(gate_metric=:bogus))
    end
end
