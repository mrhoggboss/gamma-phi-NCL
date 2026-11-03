# The LiftedKKT comparator: MadNLP with the condensed KKT system and relaxed equalities
# (SparseCondensedKKTSystem + RelaxEquality + RelaxBound, dual initialization on). On the GPU the
# condensed system is the only one cuDSS factorizes without pivoting, which is why the equalities
# are relaxed. bound_relax_factor is MadNLP's default 1e-8. Included by gpu.jl (configuration `liftedkkt`).

const LIFTEDKKT_OPTIONS = (kkt_system=MadNLP.SparseCondensedKKTSystem,
                           equality_treatment=MadNLP.RelaxEquality,
                           fixed_variable_treatment=MadNLP.RelaxBound,
                           dual_initialized=true, bound_relax_factor=1e-8)

"""
    liftedkkt_solver(model, linear_solver_kw, ipm_kw)

The comparator's `MadNLPSolver` on `model`, with the suite's tolerance, budgets and linear solver.
"""
liftedkkt_solver(model, linear_solver_kw, ipm_kw) =
    MadNLP.MadNLPSolver(model; LIFTEDKKT_OPTIONS..., linear_solver_kw..., ipm_kw...)

function echo_liftedkkt(io::IO, s)
    o = s.opt
    println(io, "CONFIG liftedkkt (LiftedKKT) kkt_system=$(nameof(typeof(s.kkt))) ",
            "linear_solver=$(nameof(typeof(s.kkt.linear_solver))) equality_treatment=$(o.equality_treatment) ",
            "fixed_variable_treatment=$(o.fixed_variable_treatment) dual_initialized=$(o.dual_initialized) ",
            "tol=$(o.tol) max_iter=$(o.max_iter) max_wall_time=$(o.max_wall_time) bound_relax_factor=$(o.bound_relax_factor) ",
            "s_max=$(o.s_max) richardson_tol=$(s.iterator.opt.richardson_tol) richardson_max_iter=$(s.iterator.opt.richardson_max_iter)")
    flush(io)
end
