#=
    gain_law = :geometry
=#

@testset "Gain law (:geometry)" begin
    nlp = DenseDummyQP(zeros(Float64, 10); m=5)
    mk(; kw...) = MadNCL.NCLSolver(nlp;
        ncl_options=MadNCL.NCLOptions{Float64}(; verbose=false, gain_law=:geometry, kw...),
        print_level=MadNLP.ERROR)
    # write the x-block of the Jacobian so that row i has squared norm rowval[i]^2
    function loadw!(slv, rowval)
        jac = MadNLP.get_jacobian(slv.ipm.kkt)
        for k in 1:length(slv.gainws.jv)
            r = slv.gainws.rows[k]
            jac[k] = rowval[r] / sqrt(count(==(r), slv.gainws.rows))
        end
    end
    update!(slv, α) = MadNCL._update_gains!(slv, slv.gainws, α)

    @testset "workspace" begin
        @test mk().gainws isa MadNCL.GainWorkspace
        @test MadNCL.NCLSolver(nlp; ncl_options=MadNCL.NCLOptions{Float64}(verbose=false),
                               print_level=MadNLP.ERROR).gainws === nothing
    end

    @testset "target: (1/w)/G with G the geometric mean of 1/w" begin
        slv = mk(gain_clip=(1e-30, 1e16))
        rowval = [1.0, 2.0, 4.0, 0.5, 0.25]
        loadw!(slv, rowval)
        update!(slv, 1.0)
        g = Array(slv.ncl.γr)
        w = rowval .^ 2
        G = exp(sum(log.(1 ./ w)) / 5)
        @test g ≈ (1 ./ w) ./ G rtol=1e-12
        @test prod(g) ≈ 1.0 rtol=1e-12
    end

    @testset "clip" begin
        slv = mk(gain_clip=(0.5, 2.0))
        loadw!(slv, [1.0, 2.0, 4.0, 0.5, 0.25])
        update!(slv, 1.0)
        g = Array(slv.ncl.γr)
        @test all(0.5 .<= g .<= 2.0)
        @test count(==(2.0), g) >= 1 && count(==(0.5), g) >= 1
    end

    @testset "annealing: γ = target^α" begin
        rowval = [1.0, 2.0, 4.0, 0.5, 0.25]
        slv1 = mk(gain_clip=(1e-30, 1e16)); loadw!(slv1, rowval); update!(slv1, 1.0)
        t = Array(slv1.ncl.γr)
        slv0 = mk(); loadw!(slv0, rowval); slv0.ncl.γr .= 3.0; update!(slv0, 0.0)
        @test all(Array(slv0.ncl.γr) .== 1.0)
        slvh = mk(gain_clip=(1e-30, 1e16)); loadw!(slvh, rowval); update!(slvh, 0.5)
        @test Array(slvh.ncl.γr) == t .^ 0.5
    end

    @testset "dark rows (1/w not finite) keep their gain" begin
        # row 2: w = 0 exactly; row 4: w positive but subnormal, so 1/w = Inf
        sub = sqrt(5.0e-324)
        @test !isfinite(1.0 / (sub^2))
        rowval = [1.0, 0.0, 4.0, sub, 0.25]
        slv = mk(gain_clip=(1e-30, 1e16)); loadw!(slv, rowval)
        γ0 = [7.0, 3.0, 0.5, 11.0, 2.0]
        slv.ncl.γr .= γ0
        update!(slv, 1.0)
        g = Array(slv.ncl.γr)
        @test all(isfinite, g) && all(>(0.0), g)
        @test g[2] == 3.0
        @test g[4] == 11.0
        wobs = [1.0, 16.0, 0.0625]   # only rows 1, 3, 5 enter G
        G = exp(sum(log.(1 ./ wobs)) / 3)
        @test g[[1, 3, 5]] ≈ (1 ./ wobs) ./ G rtol=1e-12
        update!(slv, 1.0)
        g2 = Array(slv.ncl.γr)
        @test g2[2] == 3.0 && g2[4] == 11.0
    end

    @testset "zero Jacobian: neutral gains" begin
        slv = mk(); loadw!(slv, zeros(5))
        slv.ncl.γr .= 4.0
        update!(slv, 1.0)
        @test all(Array(slv.ncl.γr) .== 1.0)
    end
end
