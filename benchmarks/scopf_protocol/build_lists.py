#!/usr/bin/env python3
"""The contingency lists of the 18 PGLIB-network SCOPF instances, rebuilt from the protocol records (Python standard library only).

  python3 build_lists.py [--records=<dir>] census                  screening census of the six lists (Markdown)
  python3 build_lists.py [--records=<dir>] lists [--write=<file>] [--check=<file>]
                                                                   apply the island rule and the K = 1 verdicts; print the drops,
                                                                   backfills and the K = 1 row of every checked outage; --write
                                                                   writes the Julia contingency file, --check asserts that the
                                                                   lists of <file> equal the rebuilt ones
  python3 build_lists.py [--records=<dir>] jobs <data_dir> [<n>]   K = 1 jobs (net,order,k,case file) for the outages that the
                                                                   rule still has to check: the first <n> (default 16)
                                                                   island-passing admitted outages of each list without a K = 1 row

<records> (default: records/ next to this script) holds
  screens/<net>_<order>.csv      one row per screened outage, in screening order (julia/screen_run2.jl: column `admitted`;
                                 julia/screen_run3.jl: column `adm_scaled_1e-4`); admitted = scaled ||r||_inf < 1e-4
  islands.csv                    julia/islands.jl: for every bridge, the islanded side (bus count, load, units, Pmin, Pmax)
  k1/<budget>/<net>_<order>__<k>.csv   julia/k1_verify.jl rows (Ipopt-MA57 on the K = 1 problem)

Rule (the protocol of the manuscript; WO-69 Addendum C5 with the amended rule (b)):
  1. the first 16 admitted outages of the screen, in screening order;
  2. island rule: drop an outage whose island has load > 0 and no unit, or sum Pmax < load, or sum Pmin > load (P only);
  3. verification: drop an outage whose K = 1 solve ended Infeasible_Problem_Detected, or exhausted its iteration / wall
     budget with an unscaled constraint violation > 1e-3 ("presumed infeasible (stuck primal)"); every other outcome stays;
  4. backfill: each vacancy is filled, at the end of the list, by the next admitted outage of the same screen (screening
     order) that passes 2 and 3.
"""
import csv, glob, hashlib, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BENCH = os.path.dirname(HERE)
# (instance key, network, order, screen file) — order A: increasing PowerModels branch key; order B:
# keys[randperm(MersenneTwister(69), n)] of the in-service branches
LISTS = [("pglib_opf_case500_goc", "case500_goc", "A"), ("pglib_opf_case500_goc_B", "case500_goc", "B"),
         ("pglib_opf_case588_sdet", "case588_sdet", "A"), ("pglib_opf_case588_sdet_B", "case588_sdet", "B"),
         ("pglib_opf_case793_goc", "case793_goc", "A"), ("pglib_opf_case793_goc_B", "case793_goc", "B")]
NLIST = 16
ST = {"1": "SUCC", "2": "ACCEPTABLE", "3": "SMALL_STEP", "4": "DIVERGING", "5": "INFEASIBLE", "6": "MAXITER"}
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()


def table(h, rows):
    print("| " + " | ".join(h) + " |"); print("|" + "---|" * len(h))
    for r in rows:
        print("| " + " | ".join(str(x) for x in r) + " |")
    print()


def screen(rec, net, order):
    p = f"{rec}/screens/{net}_{order}.csv"
    R = list(csv.DictReader(open(p)))
    col = "admitted" if "admitted" in R[0] else "adm_scaled_1e-4"
    rinf = "rinf" if "rinf" in R[0] else "rinf_scaled"
    for r in R:
        r["_adm"] = r[col] == "1"; r["_rinf"] = float(r[rinf])
    return p, R


def islands(rec):
    return {(r["net"], int(r["branch"])): r for r in csv.DictReader(open(f"{rec}/islands.csv"))}


def island_ok(ISL, net, k):
    r = ISL.get((net, k))
    if r is None:
        return True, ""
    load, ng, pmin, pmax = float(r["isl_load_mw"]), int(r["isl_ngen"]), float(r["isl_pmin_mw"]), float(r["isl_pmax_mw"])
    d = (f"island {r['isl_nbus']} bus(es), load {load:g} MW, units {ng}, sum Pmin/Pmax {pmin:g}/{pmax:g} MW, "
         f"Q load {float(r['isl_load_mvar']):g} MVAr")
    return ((load <= 0) if ng == 0 else not (pmax < load or pmin > load)), d


def k1rows(rec):
    out = {}
    for f in sorted(glob.glob(f"{rec}/k1/*/*.csv")):
        v = open(f).read().strip().split(",")
        key = (v[0], v[1], int(v[2]))
        assert key not in out, f"two K = 1 rows for {key}"
        out[key] = (v, os.path.basename(os.path.dirname(f)))
    return out


def verdict(v):
    st = v[3]
    pr = float(v[6]) if v[6] not in ("NA", "") else float("nan")
    if st == "Infeasible_Problem_Detected":
        return False, "K = 1 LOCALLY_INFEASIBLE"
    if st in ("Maximum_WallTime_Exceeded", "Maximum_Iterations_Exceeded") and pr > 1e-3:
        return False, f"presumed infeasible (stuck primal): K = 1 {st}, inf_pr {pr:.3e}"
    return True, st


def build(rec):
    ISL, K = islands(rec), k1rows(rec)
    out = []
    for key, net, order in LISTS:
        path, R = screen(rec, net, order)
        adm = [int(r["k"]) for r in R if r["_adm"]]
        L = adm[:NLIST]
        kept, drops, backs, skipped, pending = [], [], [], [], None
        for k in L:
            ok, d = island_ok(ISL, net, k)
            if not ok:
                drops.append((k, "island rule: " + d)); continue
            if (net, order, k) not in K:
                pending = k; break
            ok, why = verdict(K[(net, order, k)][0])
            (kept.append(k) if ok else drops.append((k, why)))
        cand = iter(adm[NLIST:])
        while pending is None and len(kept) + len(backs) < NLIST:
            k = next(cand, None)
            if k is None:
                pending = "screen exhausted"; break
            ok, d = island_ok(ISL, net, k)
            if not ok:
                skipped.append((k, "island rule: " + d)); continue
            if (net, order, k) not in K:
                pending = k; break
            ok, why = verdict(K[(net, order, k)][0])
            (backs.append(k) if ok else skipped.append((k, why)))
        out.append(dict(key=key, net=net, order=order, screen=path, R=R, adm=adm, first=L, kept=kept, drops=drops,
                        backs=backs, skipped=skipped, pending=pending, final=kept + backs))
    return out, K


def julia_file(res, rec):
    src = open(os.path.join(BENCH, "instances", "scopf_contingencies.jl")).read()
    i = src.index('"case118" => [')
    c118 = src[i:src.index("]", i) + 1]
    L = ["# Contingency lists of the 18 PGLIB-network SCOPF instances (benchmarks/instances/scopf_pglib18.csv): network",
         "# case500_goc, case588_sdet, case793_goc (PGLIB v23.07) x order A / B; an instance with K contingencies uses the",
         "# first K entries (K in {4, 8, 16}). Generated by benchmarks/scopf_protocol/build_lists.py from the protocol records",
         "# (benchmarks/scopf_protocol/records/; protocol in benchmarks/scopf_protocol/README.md): screen at rho = 1e8,",
         "# admitted iff the scaled ||r||_inf < 1e-4 after at most 200 iterations of one NCL subproblem (any status, bridges",
         "# kept); first 16 admitted outages in screening order (A: increasing PowerModels branch key; B:",
         "# keys[randperm(MersenneTwister(69), n)]); island rule; K = 1 verification (Ipopt-MA57, tol 1e-8); every vacancy",
         "# backfilled at the end in screening order. These are the first 16 entries of the same keys in the file the",
         "# campaign ran (scopf-pool, benchmarks/pilot/instances/scopf_pilot_contingencies.jl, sha256",
         "# 6b70bf25e834cd258c6bb53ca5d63f5030755eff4654f9b2596054ff1c688bb7, whose order-A keys carry 64 entries).",
         "# \"case118\" = the reference-network list of benchmarks/instances/scopf_contingencies.jl, used by the warm-up only",
         "# (CONTINGENCIES[\"case118\"][1:1] on case118.m).",
         "CONTINGENCIES = Dict(",
         f"    {c118},"]
    for x in res:
        budgets = sorted({b for (n, o, k), (v, b) in K_ALL.items() if n == x["net"] and o == x["order"] and k in x["first"] + x["backs"]})
        L.append(f"    # {x['key']}: order {x['order']}, screen {os.path.relpath(x['screen'], HERE)} sha256 {sha(x['screen'])};")
        L.append(f"    # K = 1 rows {', '.join('k1/' + b for b in budgets)}; dropped {[d[0] for d in x['drops']]}"
                 + "".join(f" ({w})" for _, w in x["drops"]) + f", backfilled {x['backs']}")
        L.append(f'    "{x["key"]}" => [{", ".join(map(str, x["final"]))}],')
    L.append(")")
    return "\n".join(L) + "\n"


def read_julia_lists(p):
    import re
    src = open(p).read()
    return {m.group(1): [int(t) for t in m.group(2).split(",") if t.strip()]
            for m in re.finditer(r'"([^"]+)" => \[([^\]]*)\]', src)}


def main(argv):
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    pos = [a for a in argv if not a.startswith("--")]
    rec = os.path.abspath(opt.get("records", os.path.join(HERE, "records")))
    if not pos:
        print(__doc__); return 2
    global K_ALL
    res, K_ALL = build(rec)
    if pos[0] == "census":
        rows, brows = [], []
        for x in res:
            R = x["R"]; a = 0; n16 = None
            for i, r in enumerate(R):
                a += r["_adm"]
                if a == NLIST:
                    n16 = i + 1; break
            W = R[:n16]
            adm = [r for r in W if r["_adm"]]; rej = [r for r in W if not r["_adm"]]
            cnt = lambda X: ", ".join(f"{ST.get(s, s)} {sum(1 for r in X if r['status'] == s)}"
                                      for s in sorted({r["status"] for r in X})) or "—"
            br = [r for r in W if r["bridge"] == "1"]
            metas = sorted(glob.glob(f"{rec}/screens/{x['net']}_{x['order']}*.meta.txt"))
            base = sorted({t.split("=", 1)[1] for m in metas for t in open(m).read().split() if t.startswith("base_status=")})
            rows.append((x["net"], x["order"], n16, len(adm), cnt(adm), cnt(rej), f"{len(br)} ({sum(r['_adm'] for r in br)})",
                         f"{sum(float(r['time']) for r in W):.1f}", "/".join(base), len(R), len(x["adm"])))
            for r in br:
                brows.append((x["net"], x["order"], r["k"], ST.get(r["status"], r["status"]), f"{r['_rinf']:.2e}",
                              "yes" if r["_adm"] else "no", r["isl_buses"], r["isl_load_mw"], r["isl_ngen"], r["isl_pmax_mw"]))
        print("Screening census, read up to the 16th admitted outage of each list (rho = 1e8, scaled ||r||_inf < 1e-4, "
              "<= 200 iterations, any status; status codes of MadNLP).\n")
        table(["network", "order", "screened (to the 16th admission)", "admitted", "admitted by status",
               "rejected by status", "bridges screened (admitted)", "screen time (s, sum per outage)", "base OPF",
               "screened in the record", "admitted in the record"], rows)
        print("Bridges screened up to the 16th admission (islanded side = the side without the reference bus):\n")
        table(["network", "order", "branch", "status", "scaled ‖r‖∞", "admitted", "islanded buses", "load (MW)", "units",
               "Pmax (MW)"], brows)
        return 0
    if pos[0] == "lists":
        for x in res:
            print(f"**{x['key']}** (order {x['order']}): first {NLIST} admitted {x['first']}; dropped "
                  f"{[(k, w) for k, w in x['drops']] or 'none'}; backfilled {x['backs'] or 'none'}; skipped candidates "
                  f"{x['skipped'] or 'none'}; pending {x['pending']}; list {x['final']}\n")
        rows = []
        for x in res:
            SR = {int(r["k"]): r for r in x["R"]}
            dk = [d[0] for d in x["drops"]]
            for k in x["first"] + x["backs"] + [s[0] for s in x["skipped"]]:
                v, b = K_ALL.get((x["net"], x["order"], k), (None, ""))
                role = "kept" if k in x["kept"] else "backfilled" if k in x["backs"] else "dropped" if k in dk else "skipped"
                rows.append((x["key"], k, role, ST.get(SR[k]["status"], SR[k]["status"]), f"{SR[k]['_rinf']:.3e}",
                             "yes" if SR[k]["bridge"] == "1" else "", v[3] if v else "—", v[5] if v else "",
                             v[6] if v else "", v[12] if v else "", b))
        table(["instance key", "outage", "role", "screen status", "screen scaled ‖r‖∞", "bridge", "K = 1 Ipopt status",
               "iterations", "inf_pr (unscaled)", "time (s)", "K = 1 record"], rows)
        assert all(x["pending"] is None for x in res), "K = 1 checks pending: run `jobs` and julia/k1_verify.jl"
        assert all(len(x["final"]) == NLIST for x in res)
        if "write" in opt:
            open(opt["write"], "w").write(julia_file(res, rec)); print("wrote", opt["write"], sha(opt["write"]))
        if "check" in opt:
            have = read_julia_lists(opt["check"])
            bad = [x["key"] for x in res if have.get(x["key"]) != x["final"]]
            assert not bad, f"{opt['check']}: lists differ from the rebuilt ones: {bad}"
            print(f"check: the {len(res)} lists of {opt['check']} equal the rebuilt lists")
        return 0
    if pos[0] == "jobs":
        data, n = pos[1], int(pos[2]) if len(pos) > 2 else NLIST
        ISL = islands(rec); J = []
        for x in res:
            c = 0
            for k in x["adm"]:
                if c >= n:
                    break
                if not island_ok(ISL, x["net"], k)[0]:
                    continue
                c += 1
                if (x["net"], x["order"], k) not in K_ALL:
                    J.append(f"{x['net']},{x['order']},{k},{os.path.abspath(data)}/pglib_opf_{x['net']}.m")
        print("\n".join(J))
        return 0
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
