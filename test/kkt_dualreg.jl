#=
    Dual regularization δc in K2rAuglagKKTSystem.

    MadNLP's inertia correction stores the dual regularization as du_diag = −δc. With
    `fold_dual_regularization` (default) the reduced (2,2) block of K2r is −θ + du_diag, so the
    factorized matrix agrees with the operator `mul!` and the computed step solves the
    operator-defined KKT system. Without it the block is −θ (the original MadNCL assembly).
=#

function _dualreg_prepare(nlp; δw, δc, fold::Bool=true)
    solver = MadNCL.NCLSolver(nlp;
        ncl_options=MadNCL.NCLOptions{Float64}(verbose=false, fold_dual_regularization=fold),
        kkt_system=MadNCL.K2rAuglagKKTSystem, linear_solver=MadNLP.LDLSolver,
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

@testset "K2r dual regularization" begin
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
end
