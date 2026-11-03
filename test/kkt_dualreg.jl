#=
    Dual regularization δc in the K2r and K1s systems.

    MadNLP's inertia correction stores the dual regularization as du_diag = −δc. With
    `fold_dual_regularization` (default) it is kept in the reduced systems — K2r: the (2,2) block
    is −θ + du_diag; K1s: Ω is built from Π̃ = Π / (1 − Π du_diag) — so the factorized matrix
    agrees with the operator `mul!` and the computed step solves the operator-defined KKT system.
    Without it the original MadNCL assembly is used.
=#

function _dualreg_prepare(nlp; δw, δc, fold::Bool=true,
                          kkt_system=MadNCL.K2rAuglagKKTSystem, linear_solver=MadNLP.LDLSolver)
    solver = MadNCL.NCLSolver(nlp;
        ncl_options=MadNCL.NCLOptions{Float64}(verbose=false, fold_dual_regularization=fold),
        kkt_system=kkt_system, linear_solver=linear_solver,
        print_level=MadNLP.ERROR)
    ipm = solver.ipm
    MadNLP.initialize!(ipm)
    MadNLP.eval_jac_wrapper!(ipm, ipm.kkt, ipm.x)
    MadNLP.eval_lag_hess_wrapper!(ipm, ipm.kkt, ipm.x, ipm.y)
    MadNLP.set_aug_diagonal!(ipm.kkt, ipm)
    MadNLP.regularize_diagonal!(ipm.kkt, δw, δc)
    MadNLP.build_kkt!(ipm.kkt)
    MadNLP.factorize!(ipm.kkt.linear_solver)
    return solver
end

# deterministic RHS over the full KKT vector
function _dualreg_fill!(w)
    v = MadNLP.full(w)
    v .= sin.(1.0:length(v)) .+ 0.1
    return copy(v)
end

@testset "Dual regularization fold" begin
    @testset "factorized (2,2) block, δc = $δc" for δc in (0.0, 1e-3, 1e-1)
        solver = _dualreg_prepare(HS15Model(); δw=1e-4, δc=δc)
        kkt = solver.ipm.kkt
        n, m = kkt.n, kkt.m
        nx, nr = kkt.nx, kkt.nr
        @test kkt.fold_dual_regularization[]
        Σr = kkt.pr_diag[nx+1:nx+nr]
        θ = 1.0 ./ (kkt.ρk .+ Σr)
        for i in 1:m
            @test kkt.du_diag[i] == -δc
            @test kkt.aug_com[n+i, n+i] == -θ[i] + kkt.du_diag[i]
            @test kkt.aug_com[n+i, n+i] < 0
        end
        if MadNLP.is_inertia(kkt.linear_solver)
            num_pos, num_zero, num_neg = MadNLP.inertia(kkt.linear_solver)
            @test MadNLP.is_inertia_correct(kkt, num_pos, num_zero, num_neg)
        end
    end

    @testset "solve ≡ operator, δc = $δc" for δc in (0.0, 1e-3, 1e-1)
        solver = _dualreg_prepare(HS15Model(); δw=1e-4, δc=δc)
        kkt = solver.ipm.kkt
        w = MadNLP.UnreducedKKTVector(kkt)
        w0 = _dualreg_fill!(w)
        MadNLP.solve_kkt!(kkt, w)
        res = MadNLP.UnreducedKKTVector(kkt)
        mul!(res, kkt, w)
        @test MadNLP.full(res) ≈ w0 rtol=1e-9
    end

    @testset "fold_dual_regularization = false: original assembly" for δc in (0.0, 1e-1)
        solver = _dualreg_prepare(HS15Model(); δw=1e-4, δc=δc, fold=false)
        kkt = solver.ipm.kkt
        n, m, nx, nr = kkt.n, kkt.m, kkt.nx, kkt.nr
        @test !kkt.fold_dual_regularization[]
        θ = 1.0 ./ (kkt.ρk .+ kkt.pr_diag[nx+1:nx+nr])
        for i in 1:m
            @test kkt.aug_com[n+i, n+i] == -θ[i]
        end
    end

    @testset "δc = 0: fold on and off are bitwise identical" begin
        a = _dualreg_prepare(HS15Model(); δw=1e-4, δc=0.0, fold=true).ipm.kkt
        b = _dualreg_prepare(HS15Model(); δw=1e-4, δc=0.0, fold=false).ipm.kkt
        @test a.du_diag_reduced == b.du_diag_reduced
        @test MadNCL.nonzeros(a.aug_com) == MadNCL.nonzeros(b.aug_com)
    end

    # K1s: mixed equality / inequality rows to exercise both branches of Ω
    k1s_nlp() = DenseDummyQP(zeros(20); m=6, equality_cons=collect(1:3))
    k1s_kw = (kkt_system=MadNCL.K1sAuglagKKTSystem, linear_solver=MadNLP.CHOLMODSolver)

    @testset "K1s Ω with Π̃, δc = $δc" for δc in (0.0, 1e-3, 1e-1)
        kkt = _dualreg_prepare(k1s_nlp(); δw=1e-4, δc=δc, k1s_kw...).ipm.kkt
        @test kkt.fold_dual_regularization[]
        nx, nr, ns = kkt.nx, kkt.nr, length(kkt.ind_ineq)
        Σr = kkt.pr_diag[nx+1:nx+nr]
        Σs = kkt.pr_diag[nx+nr+1:nx+nr+ns]
        Π = kkt.ρk .+ Σr
        @test all(kkt.du_diag .== -δc)
        @test kkt.θtk ≈ Π ./ (1 .+ Π .* δc) rtol=1e-15
        @test all(kkt.diag_buffer .> 0)
        for i in kkt.ind_eq
            @test kkt.diag_buffer[i] == kkt.θtk[i]
        end
        for (j, i) in enumerate(kkt.ind_ineq)
            @test kkt.diag_buffer[i] ≈ 1.0 / (1.0 / Π[i] + 1.0 / Σs[j] + δc) rtol=1e-14
        end
    end

    @testset "K1s solve ≡ operator, δc = $δc" for δc in (0.0, 1e-3, 1e-1)
        kkt = _dualreg_prepare(k1s_nlp(); δw=1e-4, δc=δc, k1s_kw...).ipm.kkt
        w = MadNLP.UnreducedKKTVector(kkt)
        w0 = _dualreg_fill!(w)
        MadNLP.solve_kkt!(kkt, w)
        res = MadNLP.UnreducedKKTVector(kkt)
        mul!(res, kkt, w)
        @test MadNLP.full(res) ≈ w0 rtol=1e-9
    end

    @testset "K1s fold_dual_regularization = false: original Ω" for δc in (0.0, 1e-1)
        kkt = _dualreg_prepare(k1s_nlp(); δw=1e-4, δc=δc, fold=false, k1s_kw...).ipm.kkt
        @test !kkt.fold_dual_regularization[]
        nx, nr, ns = kkt.nx, kkt.nr, length(kkt.ind_ineq)
        Σs = kkt.pr_diag[nx+nr+1:nx+nr+ns]
        Π = kkt.ρk .+ kkt.pr_diag[nx+1:nx+nr]
        @test kkt.θtk == Π
        @test kkt.diag_buffer[kkt.ind_eq] == Π[kkt.ind_eq]
        @test kkt.diag_buffer[kkt.ind_ineq] == Π[kkt.ind_ineq] .* Σs ./ (Σs .+ Π[kkt.ind_ineq])
    end

    @testset "K1s δc = 0: fold on and off give the same step" begin
        steps = map((true, false)) do fold
            kkt = _dualreg_prepare(k1s_nlp(); δw=1e-4, δc=0.0, fold=fold, k1s_kw...).ipm.kkt
            w = MadNLP.UnreducedKKTVector(kkt)
            _dualreg_fill!(w)
            MadNLP.solve_kkt!(kkt, w)
            copy(MadNLP.full(w))
        end
        @test steps[1] == steps[2]
    end
end
