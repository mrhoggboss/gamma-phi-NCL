# WO-69 Addendum 3 screening driver (CPU), the pilot rule: candidates = ALL in-service branches (bridges included) in
# the given order; admit iff ‖r‖∞ < 1e-4 after at most 200 iterations, any status; stop when `kadmit` are admitted or
# 300 candidates are screened. Bridges are annotated with the islanded component (the side without the reference bus):
# bus count, load (MW) and generation (count, total Pmax MW).
#   julia --project=benchmarks/envs/screen benchmarks/scopf_protocol/julia/screen_run2.jl <case.m> <A|B|full> <kadmit> <out_prefix> [rho]
# (paper-repro: the scopf-pool file benchmarks/pilot/screen/screen_run2.jl, unchanged but for this usage line)
# order A: increasing branch key; order B: keys[randperm(MersenneTwister(69), n)]; full: increasing key, every in-service
# branch, no stop (gate S0'). rho: the screen penalty (default 1e6; Addendum 4 uses 1e8).
# Writes <out_prefix>.csv (k,status,obj,rinf,nviol,time,admitted,bridge,isl_buses,isl_load_mw,isl_ngen,isl_pmax_mw) and
# <out_prefix>.meta.txt.
using Random
import HSL_jll, SHA
filesize(HSL_jll.libhsl_path) > 1_000_000 || error("HSL_jll is the stub: $(HSL_jll.libhsl_path)")
include(joinpath(@__DIR__, "contingency_pool.jl"))
include(joinpath(@__DIR__, "bridges.jl"))
const CASE, ORDER, KADM, OUTP = ARGS[1], ARGS[2], parse(Float64, ARGS[3]), ARGS[4]
const RHO = length(ARGS) >= 5 ? parse(Float64, ARGS[5]) : 1e6
const MAXSCR = ORDER == "full" ? Inf : 300
info = network_info(CASE)
keysb = info.keys
cands = ORDER in ("A", "full") ? keysb : ORDER == "B" ? keysb[randperm(MersenneTwister(69), length(keysb))] : error("order")
t0 = time()
io = open(OUTP * ".raw.csv", "w")
base_status, rows = screen_candidates(CASE, cands; kadmit=(ORDER == "full" ? Inf : KADM), log=io, any_status=true,
                                      max_screened=MAXSCR, rho=RHO)
close(io)
tt = time() - t0
open(OUTP * ".csv", "w") do f
    println(f, "k,status,obj,rinf,nviol,time,admitted,bridge,isl_buses,isl_load_mw,isl_ngen,isl_pmax_mw")
    for r in rows
        k = Int(r[1]); a = get(info.island, k, nothing)
        isl = a === nothing ? ("", "", "", "") : (a.nbus, round(a.load_mw, digits=3), a.ngen, round(a.pmax_mw, digits=3))
        println(f, join((k, Int(r[2]), r[3], r[4], Int(r[5]), round(r[6], digits=3), Int(r[4] < 1e-4),
                         Int(a !== nothing), isl...), ","))
    end
end
open(OUTP * ".meta.txt", "w") do f
    println(f, "base_status=$base_status rho=$RHO order=$ORDER kadmit=$KADM max_screened=$MAXSCR candidates=$(length(cands)) ",
            "in_service=$(length(keysb)) bridges=$(length(info.island)) buses=$(info.nbus) gens=$(info.ngen) ",
            "screened=$(length(rows)) admitted=$(count(r -> r[4] < 1e-4, rows)) screen_s=$(round(tt, digits=1))")
    println(f, "case=$CASE sha256=$(bytes2hex(open(io_ -> SHA.sha256(io_), CASE)))")
end
