Contingency lists of the seven reference networks, rebuilt from the records (records/reference_networks/; reference_networks.py report). Order A (increasing PowerModels branch key), MATPOWER 7.0 files; admitted = scaled ||r||_inf < 1e-4 after at most 200 iterations at penalty 1e8 (any status, bridges kept).

## Screens and lists

| network | screen | branches screened | bridges screened (admitted) | admitted | list length n | n-th admission at branch position | dropped | backfilled | list |
|---|---|---|---|---|---|---|---|---|---|
| case118 | screens/case118_full_rho1e8.csv | 186 | 9 (0) | 156 | 100 | 122 | 0 | 0 | complete |
| case300 | screens/case300_full_rho1e8.csv | 411 | 89 (0) | 231 | 100 | 159 | 0 | 0 | complete |
| case_ACTIVSg200 | screens/case_ACTIVSg200_full_rho1e8.csv | 245 | 72 (11) | 179 | 100 | 144 | 0 | 0 | complete |
| case_ACTIVSg500 | screens/case_ACTIVSg500_full_rho1e8.csv | 597 | 254 (33) | 353 | 100 | 157 | 0 | 0 | complete |
| case1354pegase | screens/case1354pegase_A.csv | 103 | 33 (7) | 64 | 32 | 52 | 0 | 0 | complete |
| case2869pegase | screens/case2869pegase_A.csv | 74 | 4 (2) | 64 | 16 | 16 | 0 | 0 | complete |
| case_ACTIVSg2000 | screens/case_ACTIVSg2000_A.csv | 88 | 15 (3) | 64 | 16 | 19 | 0 | 0 | complete |

## K = 1 verification of the list entries (label A: the MATPOWER 7.0 file)

Ipopt + MA57 on the K = 1 problem of the harness model, tol 1e-8; budget = <max_iter>it_<wall>s of the record directory. Verdict: dropped on Infeasible_Problem_Detected, or on an exhausted iteration or wall budget with an unscaled constraint violation (inf_pr) above 1e-3; kept otherwise.

| network | budget | entries | rows | Solve_Succeeded | other outcomes (branch: status, unscaled inf_pr, verdict) | max iterations | max solve time (s) |
|---|---|---|---|---|---|---|---|
| case118 | c3_3000it_600s | 1-100 | 100 | 100 | none | 210 | 4.90 |
| case300 | k1_10000it_3600s | 1-100 | 100 | 100 | none | 2686 | 132.92 |
| case_ACTIVSg200 | k1_10000it_3600s | 1-100 | 100 | 100 | none | 380 | 9.45 |
| case_ACTIVSg500 | c3_3000it_600s | 1-56 | 56 | 56 | none | 806 | 110.85 |
| case_ACTIVSg500 | k1_10000it_3600s | 57-100 | 44 | 44 | none | 674 | 65.61 |
| case1354pegase | k1_10000it_3600s | 1-32 | 32 | 29 | 6: Restoration_Failed, 1.93e-12, kept; 8: Restoration_Failed, 2.08e-12, kept; 46: Restoration_Failed, 2.90e-12, kept | 2543 | 780.31 |
| case2869pegase | k1_10000it_3600s | 1-16 | 16 | 15 | 15: Restoration_Failed, 1.46e-11, kept | 2522 | 2666.59 |
| case_ACTIVSg2000 | k1_10000it_3600s | 1-16 | 16 | 12 | 3: Maximum_WallTime_Exceeded, 1.78e-04, kept; 8: Maximum_WallTime_Exceeded, 3.10e-04, kept; 12: Maximum_WallTime_Exceeded, 2.69e-05, kept; 15: Maximum_WallTime_Exceeded, 1.10e-04, kept | 2332 | 3793.54 |

## case300 on the MATPOWER 8.1 file (label Amp81; the file of its K = 100 instance; reported only)

| network | budget | rows | Solve_Succeeded | other outcomes (branch: status, unscaled inf_pr, verdict) | max iterations | max solve time (s) |
|---|---|---|---|---|---|---|
| case300 | k1_10000it_3600s | 100 | 100 | none | 2686 | 125.79 |

## Further K = 1 rows (admitted outages after the lists, label A)

| network | branches | rows | Solve_Succeeded | other outcomes (branch: status, unscaled inf_pr, verdict) | max iterations | max solve time (s) |
|---|---|---|---|---|---|---|
| case1354pegase | 54, 56, 60, 61 | 4 | 4 | none | 1283 | 376.33 |
| case2869pegase | 17, 18, 20, 21, 22, 23, 24, 25, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 39, 40, 41, 42, 45, 46 | 24 | 22 | 18: Maximum_WallTime_Exceeded, 1.34e-03, dropped; 27: Maximum_WallTime_Exceeded, 1.16e-04, kept | 3397 | 3606.74 |
| case_ACTIVSg2000 | 25, 26, 34, 36, 38, 39, 40, 41, 43, 44, 45, 50, 53 | 13 | 9 | 39: Maximum_WallTime_Exceeded, 2.22e-06, kept; 41: Maximum_WallTime_Exceeded, 4.83e-05, kept; 50: Maximum_WallTime_Exceeded, 9.06e-03, dropped; 53: Maximum_WallTime_Exceeded, 3.13e-03, dropped | 1383 | 3897.11 |

## Bridges in the lists (islanded side = the side without the reference bus)

| network | list entry | branch | islanded buses | load (MW) | units | sum Pmin/Pmax (MW) | island rule |
|---|---|---|---|---|---|---|---|
| case_ACTIVSg200 | 75 | 115 | 1 | 0.0 | 0 | 0.0/0.0 | pass |
| case_ACTIVSg200 | 76 | 116 | 1 | 0.0 | 0 | 0.0/0.0 | pass |
| case_ACTIVSg200 | 96 | 138 | 1 | 0.0 | 0 | 0.0/0.0 | pass |
| case_ACTIVSg500 | 73 | 110 | 1 | 0.0 | 0 | 0.0/0.0 | pass |
| case1354pegase | 3 | 6 | 1 | 0.0 | 1 | 0.0/80.0 | pass |
| case1354pegase | 4 | 8 | 1 | 0.0 | 1 | 0.0/80.0 | pass |
| case1354pegase | 5 | 9 | 1 | 0.0 | 1 | 0.0/31.92 | pass |

## The lists

- case118 (100): [1, 2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 37, 38, 40, 41, 42, 43, 44, 45, 46, 48, 49, 53, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 95, 98, 99, 100, 101, 102, 106, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121, 122]
- case300 (100): [10, 11, 12, 13, 14, 23, 39, 40, 41, 42, 43, 46, 47, 49, 50, 51, 52, 53, 54, 56, 57, 58, 59, 60, 61, 62, 64, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 115, 119, 120, 123, 124, 125, 127, 128, 131, 133, 136, 138, 139, 140, 141, 142, 143, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159]
- case_ACTIVSg200 (100): [2, 3, 4, 6, 7, 9, 10, 12, 13, 14, 16, 17, 18, 19, 22, 23, 24, 25, 26, 27, 33, 34, 37, 38, 40, 41, 43, 44, 46, 47, 50, 51, 53, 54, 57, 58, 60, 61, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 83, 84, 85, 86, 87, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 111, 112, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 138, 140, 142, 143, 144]
- case_ACTIVSg500 (100): [2, 3, 5, 6, 10, 13, 14, 15, 16, 18, 19, 21, 22, 23, 24, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 41, 42, 43, 44, 45, 46, 47, 50, 51, 53, 54, 56, 57, 59, 60, 61, 62, 63, 64, 66, 67, 69, 70, 74, 75, 76, 78, 80, 81, 83, 85, 86, 91, 92, 94, 95, 97, 98, 99, 100, 101, 102, 104, 105, 106, 108, 109, 110, 112, 113, 114, 115, 116, 118, 120, 121, 125, 126, 128, 129, 133, 134, 135, 137, 138, 140, 142, 146, 148, 149, 151, 153, 154, 156, 157]
- case1354pegase (32): [4, 5, 6, 8, 9, 14, 15, 18, 20, 21, 22, 23, 26, 30, 32, 33, 36, 37, 38, 39, 40, 41, 42, 43, 44, 46, 47, 48, 49, 50, 51, 52]
- case2869pegase (16): [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
- case_ACTIVSg2000 (16): [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 16, 18, 19]

## Every list entry

| network | entry | branch | screen status | screen scaled ‖r‖∞ | bridge | K = 1 Ipopt status | iterations | inf_pr (unscaled) | time (s) | K = 1 record |
|---|---|---|---|---|---|---|---|---|---|---|
| case118 | 1 | 1 | SUCC | 4.757e-09 |  | Solve_Succeeded | 210 | 9.5312646664069689e-14 | 4.9 | c3_3000it_600s |
| case118 | 2 | 2 | SUCC | 1.886e-06 |  | Solve_Succeeded | 94 | 5.3124171728313740e-14 | 2.39 | c3_3000it_600s |
| case118 | 3 | 3 | SUCC | 1.741e-05 |  | Solve_Succeeded | 72 | 1.0632467128957046e-13 | 1.86 | c3_3000it_600s |
| case118 | 4 | 4 | SUCC | 9.343e-06 |  | Solve_Succeeded | 115 | 8.2461815154033502e-14 | 2.95 | c3_3000it_600s |
| case118 | 5 | 5 | SUCC | 1.535e-05 |  | Solve_Succeeded | 72 | 6.3227201252402665e-14 | 2.1 | c3_3000it_600s |
| case118 | 6 | 6 | SUCC | 5.822e-06 |  | Solve_Succeeded | 172 | 4.8266945995578681e-14 | 3.68 | c3_3000it_600s |
| case118 | 7 | 8 | SUCC | 1.445e-05 |  | Solve_Succeeded | 106 | 9.5590202420225978e-14 | 3.15 | c3_3000it_600s |
| case118 | 8 | 10 | SUCC | 9.413e-06 |  | Solve_Succeeded | 60 | 5.4040105723629495e-14 | 1.43 | c3_3000it_600s |
| case118 | 9 | 11 | SUCC | 1.188e-05 |  | Solve_Succeeded | 65 | 7.8728690233731413e-14 | 1.52 | c3_3000it_600s |
| case118 | 10 | 12 | SUCC | 2.292e-06 |  | Solve_Succeeded | 70 | 4.6851411639181606e-14 | 1.61 | c3_3000it_600s |
| case118 | 11 | 13 | SUCC | 1.773e-09 |  | Solve_Succeeded | 76 | 1.2691236950246321e-13 | 1.69 | c3_3000it_600s |
| case118 | 12 | 14 | SUCC | 4.271e-09 |  | Solve_Succeeded | 159 | 8.8859475333435967e-14 | 3.85 | c3_3000it_600s |
| case118 | 13 | 15 | SUCC | 1.867e-06 |  | Solve_Succeeded | 77 | 5.9841021027295938e-14 | 1.75 | c3_3000it_600s |
| case118 | 14 | 16 | SUCC | 1.112e-06 |  | Solve_Succeeded | 74 | 5.9616200864809343e-13 | 1.77 | c3_3000it_600s |
| case118 | 15 | 17 | SUCC | 8.070e-06 |  | Solve_Succeeded | 90 | 8.1878948066105295e-14 | 2.19 | c3_3000it_600s |
| case118 | 16 | 18 | SUCC | 3.484e-08 |  | Solve_Succeeded | 81 | 5.4244803093794758e-14 | 1.88 | c3_3000it_600s |
| case118 | 17 | 19 | SUCC | 1.865e-07 |  | Solve_Succeeded | 81 | 5.8758553578286410e-14 | 1.93 | c3_3000it_600s |
| case118 | 18 | 20 | SUCC | 1.764e-08 |  | Solve_Succeeded | 77 | 3.9968028886505635e-14 | 1.68 | c3_3000it_600s |
| case118 | 19 | 24 | SUCC | 2.070e-06 |  | Solve_Succeeded | 90 | 5.4733995114020217e-14 | 2.15 | c3_3000it_600s |
| case118 | 20 | 25 | SUCC | 2.499e-07 |  | Solve_Succeeded | 77 | 4.3631764867768652e-14 | 1.96 | c3_3000it_600s |
| case118 | 21 | 26 | SUCC | 2.134e-07 |  | Solve_Succeeded | 90 | 7.2275518903097691e-14 | 2.23 | c3_3000it_600s |
| case118 | 22 | 27 | SUCC | 2.502e-06 |  | Solve_Succeeded | 76 | 5.2770288139214472e-14 | 1.68 | c3_3000it_600s |
| case118 | 23 | 28 | SUCC | 9.649e-05 |  | Solve_Succeeded | 76 | 3.5998981573470701e-14 | 1.76 | c3_3000it_600s |
| case118 | 24 | 30 | SUCC | 1.623e-05 |  | Solve_Succeeded | 86 | 4.6851411639181606e-14 | 2.06 | c3_3000it_600s |
| case118 | 25 | 31 | SUCC | 5.046e-06 |  | Solve_Succeeded | 106 | 6.1652072336215724e-14 | 2.48 | c3_3000it_600s |
| case118 | 26 | 32 | SUCC | 2.113e-07 |  | Solve_Succeeded | 104 | 3.3401059695847835e-13 | 2.52 | c3_3000it_600s |
| case118 | 27 | 33 | SUCC | 5.024e-05 |  | Solve_Succeeded | 67 | 3.8857805861880479e-14 | 1.48 | c3_3000it_600s |
| case118 | 28 | 34 | SUCC | 8.752e-06 |  | Solve_Succeeded | 72 | 5.8619775700208265e-14 | 2.07 | c3_3000it_600s |
| case118 | 29 | 35 | SUCC | 4.232e-06 |  | Solve_Succeeded | 84 | 7.1165295878472534e-14 | 1.86 | c3_3000it_600s |
| case118 | 30 | 37 | SUCC | 3.129e-06 |  | Solve_Succeeded | 83 | 8.6430862467068437e-14 | 1.88 | c3_3000it_600s |
| case118 | 31 | 38 | SUCC | 9.833e-06 |  | Solve_Succeeded | 77 | 2.7790270085148450e-13 | 1.75 | c3_3000it_600s |
| case118 | 32 | 40 | SUCC | 6.784e-07 |  | Solve_Succeeded | 87 | 7.1553873937091339e-14 | 1.99 | c3_3000it_600s |
| case118 | 33 | 41 | SUCC | 6.458e-05 |  | Solve_Succeeded | 59 | 7.1227745923607712e-14 | 1.37 | c3_3000it_600s |
| case118 | 34 | 42 | SUCC | 3.232e-06 |  | Solve_Succeeded | 97 | 5.3679283240626319e-14 | 2.24 | c3_3000it_600s |
| case118 | 35 | 43 | SUCC | 5.463e-06 |  | Solve_Succeeded | 73 | 1.0492995361488511e-13 | 1.62 | c3_3000it_600s |
| case118 | 36 | 44 | SUCC | 1.987e-06 |  | Solve_Succeeded | 97 | 7.4412698225501117e-14 | 2.35 | c3_3000it_600s |
| case118 | 37 | 45 | SUCC | 1.506e-06 |  | Solve_Succeeded | 71 | 8.8873353121243781e-14 | 1.56 | c3_3000it_600s |
| case118 | 38 | 46 | SUCC | 8.061e-09 |  | Solve_Succeeded | 95 | 4.5186077102243871e-14 | 2.24 | c3_3000it_600s |
| case118 | 39 | 48 | SUCC | 8.370e-05 |  | Solve_Succeeded | 94 | 4.8933079810353775e-14 | 2.38 | c3_3000it_600s |
| case118 | 40 | 49 | SUCC | 2.573e-05 |  | Solve_Succeeded | 79 | 2.1583290710225356e-12 | 1.89 | c3_3000it_600s |
| case118 | 41 | 53 | SUCC | 7.781e-05 |  | Solve_Succeeded | 93 | 5.5760951411798487e-14 | 2.19 | c3_3000it_600s |
| case118 | 42 | 55 | SUCC | 5.371e-06 |  | Solve_Succeeded | 74 | 5.5289106626332796e-14 | 1.84 | c3_3000it_600s |
| case118 | 43 | 56 | SUCC | 2.071e-05 |  | Solve_Succeeded | 79 | 7.6633144274751418e-14 | 1.86 | c3_3000it_600s |
| case118 | 44 | 57 | SUCC | 1.421e-06 |  | Solve_Succeeded | 80 | 8.0629947163401994e-14 | 2.15 | c3_3000it_600s |
| case118 | 45 | 58 | SUCC | 3.000e-06 |  | Solve_Succeeded | 77 | 6.9610983643997315e-14 | 1.83 | c3_3000it_600s |
| case118 | 46 | 59 | SUCC | 6.183e-07 |  | Solve_Succeeded | 115 | 6.0729199446996063e-14 | 3.04 | c3_3000it_600s |
| case118 | 47 | 60 | SUCC | 7.285e-05 |  | Solve_Succeeded | 88 | 1.5268342146157465e-13 | 1.99 | c3_3000it_600s |
| case118 | 48 | 61 | SUCC | 2.690e-05 |  | Solve_Succeeded | 138 | 4.7226111909992596e-14 | 3.3 | c3_3000it_600s |
| case118 | 49 | 62 | SUCC | 8.937e-07 |  | Solve_Succeeded | 60 | 1.0641487691032125e-13 | 1.73 | c3_3000it_600s |
| case118 | 50 | 63 | SUCC | 5.421e-06 |  | Solve_Succeeded | 75 | 5.6066262743570405e-14 | 1.72 | c3_3000it_600s |
| case118 | 51 | 64 | SUCC | 4.486e-08 |  | Solve_Succeeded | 91 | 7.2997163869104043e-14 | 2.14 | c3_3000it_600s |
| case118 | 52 | 65 | SUCC | 6.352e-07 |  | Solve_Succeeded | 69 | 8.6070039984065261e-14 | 1.57 | c3_3000it_600s |
| case118 | 53 | 66 | SUCC | 8.713e-06 |  | Solve_Succeeded | 63 | 4.9633908094648405e-14 | 1.33 | c3_3000it_600s |
| case118 | 54 | 67 | SUCC | 8.713e-06 |  | Solve_Succeeded | 63 | 4.9897586062996879e-14 | 1.41 | c3_3000it_600s |
| case118 | 55 | 68 | SUCC | 7.561e-07 |  | Solve_Succeeded | 72 | 4.4797499043625066e-14 | 1.75 | c3_3000it_600s |
| case118 | 56 | 69 | SUCC | 2.203e-07 |  | Solve_Succeeded | 66 | 2.3780977187470853e-13 | 1.47 | c3_3000it_600s |
| case118 | 57 | 70 | SUCC | 5.590e-07 |  | Solve_Succeeded | 113 | 6.9812211567210625e-14 | 2.94 | c3_3000it_600s |
| case118 | 58 | 71 | SUCC | 7.522e-07 |  | Solve_Succeeded | 123 | 1.4578338536352931e-12 | 3.02 | c3_3000it_600s |
| case118 | 59 | 72 | SUCC | 9.319e-08 |  | Solve_Succeeded | 72 | 6.7723604502134549e-14 | 1.6 | c3_3000it_600s |
| case118 | 60 | 73 | SUCC | 3.310e-08 |  | Solve_Succeeded | 81 | 9.1759932985269188e-14 | 1.97 | c3_3000it_600s |
| case118 | 61 | 74 | SUCC | 6.278e-06 |  | Solve_Succeeded | 138 | 1.1297213164951359e-13 | 3.45 | c3_3000it_600s |
| case118 | 62 | 75 | SUCC | 4.130e-07 |  | Solve_Succeeded | 77 | 7.3149819534990002e-14 | 1.73 | c3_3000it_600s |
| case118 | 63 | 76 | SUCC | 4.347e-07 |  | Solve_Succeeded | 72 | 4.4891174111327814e-14 | 1.65 | c3_3000it_600s |
| case118 | 64 | 77 | SUCC | 8.206e-09 |  | Solve_Succeeded | 94 | 6.6724403779971908e-14 | 2.28 | c3_3000it_600s |
| case118 | 65 | 78 | SUCC | 8.002e-09 |  | Solve_Succeeded | 101 | 6.3060667798708891e-14 | 2.39 | c3_3000it_600s |
| case118 | 66 | 79 | SUCC | 1.123e-08 |  | Solve_Succeeded | 106 | 6.1270433171500827e-14 | 2.74 | c3_3000it_600s |
| case118 | 67 | 80 | SUCC | 2.773e-07 |  | Solve_Succeeded | 79 | 9.5645713571457223e-14 | 1.88 | c3_3000it_600s |
| case118 | 68 | 81 | SUCC | 4.442e-07 |  | Solve_Succeeded | 86 | 4.7892245724767690e-14 | 2.09 | c3_3000it_600s |
| case118 | 69 | 82 | SUCC | 9.135e-09 |  | Solve_Succeeded | 140 | 7.3482886442377549e-14 | 3.44 | c3_3000it_600s |
| case118 | 70 | 83 | SUCC | 1.145e-07 |  | Solve_Succeeded | 172 | 4.1633363423443377e-14 | 3.61 | c3_3000it_600s |
| case118 | 71 | 84 | SUCC | 1.557e-05 |  | Solve_Succeeded | 69 | 1.1082801343320625e-13 | 1.73 | c3_3000it_600s |
| case118 | 72 | 85 | SUCC | 1.273e-05 |  | Solve_Succeeded | 76 | 1.2208983823924768e-13 | 1.67 | c3_3000it_600s |
| case118 | 73 | 86 | SUCC | 1.345e-05 |  | Solve_Succeeded | 77 | 9.7366559259626229e-14 | 2.04 | c3_3000it_600s |
| case118 | 74 | 87 | SUCC | 1.623e-05 |  | Solve_Succeeded | 72 | 2.1872503808140209e-12 | 1.65 | c3_3000it_600s |
| case118 | 75 | 88 | SUCC | 2.675e-07 |  | Solve_Succeeded | 81 | 7.1193051454088151e-14 | 1.92 | c3_3000it_600s |
| case118 | 76 | 89 | SUCC | 3.632e-07 |  | Solve_Succeeded | 84 | 7.0568551002736500e-14 | 2.05 | c3_3000it_600s |
| case118 | 77 | 90 | SUCC | 4.386e-05 |  | Solve_Succeeded | 97 | 5.3290705182007514e-14 | 2.39 | c3_3000it_600s |
| case118 | 78 | 91 | SUCC | 1.043e-08 |  | Solve_Succeeded | 80 | 1.6309176231743550e-13 | 1.77 | c3_3000it_600s |
| case118 | 79 | 92 | SUCC | 4.317e-05 |  | Solve_Succeeded | 86 | 7.7167439105352299e-14 | 1.94 | c3_3000it_600s |
| case118 | 80 | 95 | SUCC | 9.223e-05 |  | Solve_Succeeded | 107 | 9.0483176506950258e-14 | 2.62 | c3_3000it_600s |
| case118 | 81 | 98 | SUCC | 3.741e-05 |  | Solve_Succeeded | 82 | 7.3292066860020100e-14 | 1.87 | c3_3000it_600s |
| case118 | 82 | 99 | SUCC | 3.741e-05 |  | Solve_Succeeded | 82 | 7.3292066860020100e-14 | 1.91 | c3_3000it_600s |
| case118 | 83 | 100 | SUCC | 1.535e-07 |  | Solve_Succeeded | 109 | 9.6758712153643955e-13 | 2.54 | c3_3000it_600s |
| case118 | 84 | 101 | SUCC | 1.027e-07 |  | Solve_Succeeded | 124 | 1.3969381207346032e-13 | 3.01 | c3_3000it_600s |
| case118 | 85 | 102 | SUCC | 6.654e-05 |  | Solve_Succeeded | 94 | 4.4096670759330436e-14 | 2.3 | c3_3000it_600s |
| case118 | 86 | 106 | SUCC | 9.288e-05 |  | Solve_Succeeded | 115 | 6.0202537399689504e-13 | 2.65 | c3_3000it_600s |
| case118 | 87 | 108 | SUCC | 6.647e-05 |  | Solve_Succeeded | 82 | 9.8532293435482643e-14 | 1.94 | c3_3000it_600s |
| case118 | 88 | 109 | SUCC | 9.574e-09 |  | Solve_Succeeded | 80 | 7.3441253078954093e-14 | 1.75 | c3_3000it_600s |
| case118 | 89 | 110 | SUCC | 1.679e-05 |  | Solve_Succeeded | 84 | 1.0237644065824725e-13 | 2.29 | c3_3000it_600s |
| case118 | 90 | 111 | SUCC | 2.942e-06 |  | Solve_Succeeded | 77 | 8.0033202287665972e-14 | 1.74 | c3_3000it_600s |
| case118 | 91 | 112 | SUCC | 6.847e-06 |  | Solve_Succeeded | 74 | 4.4214631955696859e-14 | 1.65 | c3_3000it_600s |
| case118 | 92 | 114 | SUCC | 7.533e-07 |  | Solve_Succeeded | 158 | 5.1791904098763546e-14 | 4.18 | c3_3000it_600s |
| case118 | 93 | 115 | SUCC | 6.995e-08 |  | Solve_Succeeded | 101 | 6.6266436782314031e-14 | 2.54 | c3_3000it_600s |
| case118 | 94 | 116 | SUCC | 2.792e-05 |  | Solve_Succeeded | 88 | 5.0320858591135220e-14 | 2.25 | c3_3000it_600s |
| case118 | 95 | 117 | SUCC | 1.147e-05 |  | Solve_Succeeded | 74 | 4.7534892688716468e-14 | 2.08 | c3_3000it_600s |
| case118 | 96 | 118 | SUCC | 9.766e-06 |  | Solve_Succeeded | 138 | 1.1549095013663191e-13 | 3.33 | c3_3000it_600s |
| case118 | 97 | 119 | SUCC | 3.914e-07 |  | Solve_Succeeded | 99 | 5.4622972811557708e-14 | 2.33 | c3_3000it_600s |
| case118 | 98 | 120 | SUCC | 4.777e-06 |  | Solve_Succeeded | 145 | 7.3677175471686951e-14 | 3.48 | c3_3000it_600s |
| case118 | 99 | 121 | SUCC | 2.768e-07 |  | Solve_Succeeded | 164 | 6.8556271770603416e-14 | 3.9 | c3_3000it_600s |
| case118 | 100 | 122 | SUCC | 1.375e-06 |  | Solve_Succeeded | 90 | 8.5320639442443280e-14 | 2.09 | c3_3000it_600s |
| case300 | 1 | 10 | SUCC | 2.987e-05 |  | Solve_Succeeded | 117 | 4.5607961851601431e-13 | 6.26 | k1_10000it_3600s |
| case300 | 2 | 11 | SUCC | 1.153e-05 |  | Solve_Succeeded | 125 | 7.2564176889500231e-13 | 7.57 | k1_10000it_3600s |
| case300 | 3 | 12 | SUCC | 1.153e-05 |  | Solve_Succeeded | 125 | 9.0416563125472749e-13 | 6.62 | k1_10000it_3600s |
| case300 | 4 | 13 | SUCC | 2.194e-09 |  | Solve_Succeeded | 85 | 8.4868917449298920e-12 | 4.4 | k1_10000it_3600s |
| case300 | 5 | 14 | SUCC | 2.194e-09 |  | Solve_Succeeded | 85 | 8.4858092774808824e-12 | 4.31 | k1_10000it_3600s |
| case300 | 6 | 23 | SUCC | 2.194e-09 |  | Solve_Succeeded | 112 | 6.5281113847959205e-13 | 5.96 | k1_10000it_3600s |
| case300 | 7 | 39 | SUCC | 2.382e-05 |  | Solve_Succeeded | 150 | 4.1858183585929964e-12 | 8.41 | k1_10000it_3600s |
| case300 | 8 | 40 | SUCC | 4.923e-09 |  | Solve_Succeeded | 157 | 1.7440339450391917e-10 | 8.88 | k1_10000it_3600s |
| case300 | 9 | 41 | SUCC | 2.181e-09 |  | Solve_Succeeded | 185 | 1.1849688452691964e-09 | 10.19 | k1_10000it_3600s |
| case300 | 10 | 42 | SUCC | 2.813e-05 |  | Solve_Succeeded | 121 | 6.4667715626853806e-13 | 6.69 | k1_10000it_3600s |
| case300 | 11 | 43 | SUCC | 4.922e-09 |  | Solve_Succeeded | 123 | 1.6089136967156747e-10 | 7.6 | k1_10000it_3600s |
| case300 | 12 | 46 | SUCC | 2.176e-09 |  | Solve_Succeeded | 181 | 6.7364169797912155e-13 | 10.06 | k1_10000it_3600s |
| case300 | 13 | 47 | SUCC | 2.212e-05 |  | Solve_Succeeded | 259 | 1.4315468532810627e-09 | 14.77 | k1_10000it_3600s |
| case300 | 14 | 49 | SUCC | 2.186e-09 |  | Solve_Succeeded | 136 | 1.2780557168134976e-10 | 7.63 | k1_10000it_3600s |
| case300 | 15 | 50 | SUCC | 2.185e-09 |  | Solve_Succeeded | 167 | 1.7642301508580260e-10 | 9.6 | k1_10000it_3600s |
| case300 | 16 | 51 | SUCC | 4.922e-09 |  | Solve_Succeeded | 74 | 1.6088227972055336e-10 | 3.72 | k1_10000it_3600s |
| case300 | 17 | 52 | SUCC | 2.176e-09 |  | Solve_Succeeded | 159 | 1.1595169269185135e-12 | 8.52 | k1_10000it_3600s |
| case300 | 18 | 53 | SUCC | 2.178e-09 |  | Solve_Succeeded | 250 | 1.3242116431166906e-09 | 14.53 | k1_10000it_3600s |
| case300 | 19 | 54 | SUCC | 2.178e-09 |  | Solve_Succeeded | 76 | 2.1058642329929711e-10 | 3.76 | k1_10000it_3600s |
| case300 | 20 | 56 | SUCC | 2.177e-09 |  | Solve_Succeeded | 243 | 1.8222139075430022e-10 | 15.12 | k1_10000it_3600s |
| case300 | 21 | 57 | SUCC | 2.184e-09 |  | Solve_Succeeded | 85 | 7.5511819019880022e-13 | 5.46 | k1_10000it_3600s |
| case300 | 22 | 58 | SUCC | 2.183e-09 |  | Solve_Succeeded | 117 | 5.0086323977183156e-13 | 6.22 | k1_10000it_3600s |
| case300 | 23 | 59 | SUCC | 1.927e-05 |  | Solve_Succeeded | 254 | 3.6814995496570191e-13 | 13.9 | k1_10000it_3600s |
| case300 | 24 | 60 | SUCC | 7.239e-07 |  | Solve_Succeeded | 83 | 3.5310022961088094e-10 | 4.11 | k1_10000it_3600s |
| case300 | 25 | 61 | SUCC | 4.933e-09 |  | Solve_Succeeded | 204 | 7.1301298198989116e-13 | 13.35 | k1_10000it_3600s |
| case300 | 26 | 62 | SUCC | 4.960e-09 |  | Solve_Succeeded | 159 | 6.3252181270456731e-13 | 8.18 | k1_10000it_3600s |
| case300 | 27 | 64 | SUCC | 4.966e-09 |  | Solve_Succeeded | 184 | 1.2312886821241875e-11 | 10.52 | k1_10000it_3600s |
| case300 | 28 | 71 | SUCC | 2.178e-09 |  | Solve_Succeeded | 173 | 1.6815299153094543e-12 | 9.46 | k1_10000it_3600s |
| case300 | 29 | 72 | SUCC | 4.939e-09 |  | Solve_Succeeded | 207 | 5.6887827781793021e-13 | 11.61 | k1_10000it_3600s |
| case300 | 30 | 73 | SUCC | 8.641e-07 |  | Solve_Succeeded | 73 | 5.7288951360590090e-10 | 4.01 | k1_10000it_3600s |
| case300 | 31 | 74 | SUCC | 4.954e-09 |  | Solve_Succeeded | 119 | 5.3401727484470030e-13 | 6.4 | k1_10000it_3600s |
| case300 | 32 | 75 | SUCC | 2.179e-09 |  | Solve_Succeeded | 102 | 2.1175257380878776e-10 | 6.14 | k1_10000it_3600s |
| case300 | 33 | 76 | SUCC | 3.102e-07 |  | Solve_Succeeded | 73 | 6.0590421568917918e-13 | 3.58 | k1_10000it_3600s |
| case300 | 34 | 77 | SUCC | 6.254e-06 |  | Solve_Succeeded | 75 | 5.2558651875145301e-12 | 3.51 | k1_10000it_3600s |
| case300 | 35 | 78 | SUCC | 3.351e-06 |  | Solve_Succeeded | 172 | 6.1808891338444027e-13 | 9.68 | k1_10000it_3600s |
| case300 | 36 | 79 | SUCC | 6.500e-05 |  | Solve_Succeeded | 66 | 1.1172729408315263e-12 | 3.69 | k1_10000it_3600s |
| case300 | 37 | 80 | SUCC | 5.628e-08 |  | Solve_Succeeded | 81 | 9.5733143634646467e-13 | 3.89 | k1_10000it_3600s |
| case300 | 38 | 81 | SUCC | 4.965e-09 |  | Solve_Succeeded | 102 | 7.0610184366159956e-13 | 4.98 | k1_10000it_3600s |
| case300 | 39 | 82 | SUCC | 4.823e-06 |  | Solve_Succeeded | 179 | 6.1795013550636213e-13 | 9.89 | k1_10000it_3600s |
| case300 | 40 | 83 | SUCC | 2.186e-09 |  | Solve_Succeeded | 242 | 2.5248468593641604e-10 | 14.94 | k1_10000it_3600s |
| case300 | 41 | 84 | SUCC | 1.965e-07 |  | Solve_Succeeded | 86 | 7.9498907457065116e-13 | 4.87 | k1_10000it_3600s |
| case300 | 42 | 85 | SUCC | 4.211e-07 |  | Solve_Succeeded | 82 | 1.0889206203401613e-12 | 4.26 | k1_10000it_3600s |
| case300 | 43 | 86 | SUCC | 4.943e-09 |  | Solve_Succeeded | 147 | 1.6345555464702954e-10 | 8.08 | k1_10000it_3600s |
| case300 | 44 | 87 | SUCC | 6.120e-07 |  | Solve_Succeeded | 86 | 4.3062456378528680e-10 | 4.68 | k1_10000it_3600s |
| case300 | 45 | 89 | SUCC | 1.199e-05 |  | Solve_Succeeded | 67 | 3.4047889507782259e-11 | 3.36 | k1_10000it_3600s |
| case300 | 46 | 90 | SUCC | 5.905e-05 |  | Solve_Succeeded | 89 | 7.6991191200193033e-13 | 4.76 | k1_10000it_3600s |
| case300 | 47 | 91 | SUCC | 4.961e-09 |  | Solve_Succeeded | 281 | 5.1181281435219717e-13 | 15.81 | k1_10000it_3600s |
| case300 | 48 | 92 | SUCC | 1.099e-07 |  | Solve_Succeeded | 92 | 5.9897919957307977e-13 | 4.99 | k1_10000it_3600s |
| case300 | 49 | 93 | SUCC | 2.075e-05 |  | Solve_Succeeded | 307 | 6.1489702218864295e-13 | 17.65 | k1_10000it_3600s |
| case300 | 50 | 94 | SUCC | 6.547e-06 |  | Solve_Succeeded | 2686 | 6.4309668701412203e-13 | 132.92 | k1_10000it_3600s |
| case300 | 51 | 95 | SUCC | 4.968e-09 |  | Solve_Succeeded | 89 | 1.6097095878464529e-10 | 4.54 | k1_10000it_3600s |
| case300 | 52 | 96 | SUCC | 7.396e-09 |  | Solve_Succeeded | 121 | 1.0116352200384426e-12 | 6.42 | k1_10000it_3600s |
| case300 | 53 | 97 | SUCC | 1.629e-05 |  | Solve_Succeeded | 131 | 1.0383499615684855e-12 | 7.24 | k1_10000it_3600s |
| case300 | 54 | 98 | SUCC | 9.715e-07 |  | Solve_Succeeded | 82 | 9.9853458834786579e-13 | 4.26 | k1_10000it_3600s |
| case300 | 55 | 100 | SUCC | 4.949e-09 |  | Solve_Succeeded | 152 | 8.5551010720053000e-13 | 9.03 | k1_10000it_3600s |
| case300 | 56 | 101 | SUCC | 1.502e-05 |  | Solve_Succeeded | 178 | 7.3283740187335411e-12 | 11.41 | k1_10000it_3600s |
| case300 | 57 | 102 | SUCC | 4.956e-09 |  | Solve_Succeeded | 128 | 4.9271697832864447e-13 | 6.67 | k1_10000it_3600s |
| case300 | 58 | 103 | SUCC | 1.699e-05 |  | Solve_Succeeded | 81 | 5.6529780856351408e-13 | 4.34 | k1_10000it_3600s |
| case300 | 59 | 104 | SUCC | 1.961e-06 |  | Solve_Succeeded | 202 | 6.3367366909261591e-13 | 11.27 | k1_10000it_3600s |
| case300 | 60 | 105 | SUCC | 4.962e-09 |  | Solve_Succeeded | 95 | 1.0002693118238426e-12 | 4.95 | k1_10000it_3600s |
| case300 | 61 | 106 | SUCC | 1.642e-07 |  | Solve_Succeeded | 206 | 1.7658138840026538e-10 | 11.32 | k1_10000it_3600s |
| case300 | 62 | 107 | SUCC | 2.192e-09 |  | Solve_Succeeded | 136 | 8.9706020389712659e-13 | 7.7 | k1_10000it_3600s |
| case300 | 63 | 108 | SUCC | 4.999e-09 |  | Solve_Succeeded | 165 | 7.1054273576010019e-13 | 9.52 | k1_10000it_3600s |
| case300 | 64 | 109 | SUCC | 2.139e-08 |  | Solve_Succeeded | 128 | 1.8162731596493842e-09 | 6.79 | k1_10000it_3600s |
| case300 | 65 | 110 | SUCC | 1.378e-08 |  | Solve_Succeeded | 131 | 9.6949337446972095e-11 | 7.01 | k1_10000it_3600s |
| case300 | 66 | 111 | SUCC | 1.552e-08 |  | Solve_Succeeded | 200 | 7.3968609015651055e-13 | 12.99 | k1_10000it_3600s |
| case300 | 67 | 112 | SUCC | 8.825e-09 |  | Solve_Succeeded | 104 | 6.5758509748548022e-13 | 5.24 | k1_10000it_3600s |
| case300 | 68 | 113 | SUCC | 6.328e-08 |  | Solve_Succeeded | 146 | 1.0062506383690106e-12 | 8.39 | k1_10000it_3600s |
| case300 | 69 | 115 | SUCC | 4.921e-09 |  | Solve_Succeeded | 240 | 1.8036593052439542e-10 | 13.62 | k1_10000it_3600s |
| case300 | 70 | 119 | SUCC | 4.942e-09 |  | Solve_Succeeded | 156 | 1.3908737217516176e-09 | 7.83 | k1_10000it_3600s |
| case300 | 71 | 120 | SUCC | 6.571e-07 |  | Solve_Succeeded | 71 | 5.7999438585198959e-13 | 3.54 | k1_10000it_3600s |
| case300 | 72 | 123 | SUCC | 4.942e-09 |  | Solve_Succeeded | 182 | 2.0783674781199579e-10 | 10.1 | k1_10000it_3600s |
| case300 | 73 | 124 | SUCC | 4.945e-09 |  | Solve_Succeeded | 155 | 2.3458811143628466e-09 | 8.58 | k1_10000it_3600s |
| case300 | 74 | 125 | SUCC | 1.447e-06 |  | Solve_Succeeded | 141 | 6.0717986194447349e-11 | 7.52 | k1_10000it_3600s |
| case300 | 75 | 127 | SUCC | 2.254e-06 |  | Solve_Succeeded | 62 | 2.6907198691361600e-11 | 3.04 | k1_10000it_3600s |
| case300 | 76 | 128 | SUCC | 9.435e-06 |  | Solve_Succeeded | 135 | 8.0335738061876327e-13 | 7.14 | k1_10000it_3600s |
| case300 | 77 | 131 | SUCC | 2.107e-06 |  | Solve_Succeeded | 87 | 4.3176573427672338e-13 | 4.68 | k1_10000it_3600s |
| case300 | 78 | 133 | SUCC | 4.970e-09 |  | Solve_Succeeded | 78 | 6.2234939424143931e-13 | 4.08 | k1_10000it_3600s |
| case300 | 79 | 136 | SUCC | 4.931e-09 |  | Solve_Succeeded | 179 | 6.2319593929771600e-13 | 10.2 | k1_10000it_3600s |
| case300 | 80 | 138 | SUCC | 4.967e-09 |  | Solve_Succeeded | 82 | 1.0321016263858951e-10 | 4.17 | k1_10000it_3600s |
| case300 | 81 | 139 | SUCC | 9.353e-06 |  | Solve_Succeeded | 207 | 7.2208905521620181e-13 | 11.78 | k1_10000it_3600s |
| case300 | 82 | 140 | SUCC | 4.935e-09 |  | Solve_Succeeded | 273 | 9.9457803104385789e-12 | 16.02 | k1_10000it_3600s |
| case300 | 83 | 141 | SUCC | 4.953e-09 |  | Solve_Succeeded | 145 | 1.6272853897714157e-10 | 8.07 | k1_10000it_3600s |
| case300 | 84 | 142 | SUCC | 3.842e-06 |  | Solve_Succeeded | 93 | 9.1696095161353242e-13 | 5.44 | k1_10000it_3600s |
| case300 | 85 | 143 | SUCC | 7.532e-06 |  | Solve_Succeeded | 105 | 8.8662410746565001e-13 | 5.73 | k1_10000it_3600s |
| case300 | 86 | 145 | SUCC | 2.994e-06 |  | Solve_Succeeded | 203 | 9.2004182050686723e-13 | 12.05 | k1_10000it_3600s |
| case300 | 87 | 146 | SUCC | 5.418e-06 |  | Solve_Succeeded | 208 | 2.7257168744299065e-11 | 11.23 | k1_10000it_3600s |
| case300 | 88 | 147 | SUCC | 4.932e-09 |  | Solve_Succeeded | 75 | 7.1034844673079078e-13 | 3.58 | k1_10000it_3600s |
| case300 | 89 | 148 | SUCC | 4.925e-09 |  | Solve_Succeeded | 193 | 7.5137174260220263e-11 | 12.92 | k1_10000it_3600s |
| case300 | 90 | 149 | SUCC | 1.675e-07 |  | Solve_Succeeded | 85 | 7.3790973331711019e-13 | 4.89 | k1_10000it_3600s |
| case300 | 91 | 150 | SUCC | 2.179e-09 |  | Solve_Succeeded | 114 | 1.4013012972213801e-11 | 5.9 | k1_10000it_3600s |
| case300 | 92 | 151 | SUCC | 2.182e-09 |  | Solve_Succeeded | 80 | 8.7699292272702678e-13 | 3.95 | k1_10000it_3600s |
| case300 | 93 | 152 | SUCC | 2.186e-09 |  | Solve_Succeeded | 73 | 6.2083671537038754e-13 | 3.74 | k1_10000it_3600s |
| case300 | 94 | 153 | SUCC | 2.186e-09 |  | Solve_Succeeded | 85 | 7.9025078147942907e-11 | 4.45 | k1_10000it_3600s |
| case300 | 95 | 154 | SUCC | 1.119e-06 |  | Solve_Succeeded | 68 | 7.0415895336850554e-13 | 3.25 | k1_10000it_3600s |
| case300 | 96 | 155 | SUCC | 2.194e-09 |  | Solve_Succeeded | 74 | 5.0449922017747895e-13 | 3.71 | k1_10000it_3600s |
| case300 | 97 | 156 | SUCC | 2.190e-09 |  | Solve_Succeeded | 76 | 1.6083658016530222e-10 | 3.89 | k1_10000it_3600s |
| case300 | 98 | 157 | SUCC | 3.253e-06 |  | Solve_Succeeded | 75 | 1.2662509929484145e-12 | 3.8 | k1_10000it_3600s |
| case300 | 99 | 158 | SUCC | 2.181e-09 |  | Solve_Succeeded | 282 | 1.6090176413463553e-10 | 17.82 | k1_10000it_3600s |
| case300 | 100 | 159 | SUCC | 5.479e-08 |  | Solve_Succeeded | 94 | 2.8926874784396261e-11 | 5.03 | k1_10000it_3600s |
| case_ACTIVSg200 | 1 | 2 | MAXITER | 1.575e-09 |  | Solve_Succeeded | 63 | 6.1359624412699043e-11 | 2.0 | k1_10000it_3600s |
| case_ACTIVSg200 | 2 | 3 | SUCC | 1.573e-09 |  | Solve_Succeeded | 69 | 1.2471501343582977e-11 | 2.05 | k1_10000it_3600s |
| case_ACTIVSg200 | 3 | 4 | SUCC | 8.157e-07 |  | Solve_Succeeded | 86 | 4.6093090824185501e-12 | 2.57 | k1_10000it_3600s |
| case_ACTIVSg200 | 4 | 6 | SUCC | 2.639e-06 |  | Solve_Succeeded | 66 | 3.1098176334412586e-13 | 1.98 | k1_10000it_3600s |
| case_ACTIVSg200 | 5 | 7 | SUCC | 2.867e-06 |  | Solve_Succeeded | 95 | 1.7769350173137827e-12 | 2.86 | k1_10000it_3600s |
| case_ACTIVSg200 | 6 | 9 | MAXITER | 4.094e-08 |  | Solve_Succeeded | 69 | 6.2515021642412655e-12 | 2.13 | k1_10000it_3600s |
| case_ACTIVSg200 | 7 | 10 | SUCC | 3.671e-09 |  | Solve_Succeeded | 88 | 2.1315282546820191e-11 | 2.91 | k1_10000it_3600s |
| case_ACTIVSg200 | 8 | 12 | SUCC | 4.049e-09 |  | Solve_Succeeded | 83 | 2.5793760031513069e-12 | 2.53 | k1_10000it_3600s |
| case_ACTIVSg200 | 9 | 13 | SUCC | 2.608e-09 |  | Solve_Succeeded | 87 | 6.0240701316160994e-13 | 2.77 | k1_10000it_3600s |
| case_ACTIVSg200 | 10 | 14 | SUCC | 3.867e-09 |  | Solve_Succeeded | 91 | 1.2305969557171309e-11 | 2.79 | k1_10000it_3600s |
| case_ACTIVSg200 | 11 | 16 | SUCC | 1.575e-09 |  | Solve_Succeeded | 68 | 1.1531896042703477e-11 | 2.39 | k1_10000it_3600s |
| case_ACTIVSg200 | 12 | 17 | SUCC | 1.822e-09 |  | Solve_Succeeded | 84 | 3.3809524190714368e-12 | 2.64 | k1_10000it_3600s |
| case_ACTIVSg200 | 13 | 18 | SUCC | 1.790e-09 |  | Solve_Succeeded | 87 | 6.8808652352314592e-12 | 2.89 | k1_10000it_3600s |
| case_ACTIVSg200 | 14 | 19 | SUCC | 5.904e-09 |  | Solve_Succeeded | 92 | 1.3318325500603911e-11 | 3.06 | k1_10000it_3600s |
| case_ACTIVSg200 | 15 | 22 | SUCC | 1.572e-09 |  | Solve_Succeeded | 87 | 1.2827270148840775e-10 | 2.64 | k1_10000it_3600s |
| case_ACTIVSg200 | 16 | 23 | SUCC | 1.572e-09 |  | Solve_Succeeded | 82 | 7.9428472805030681e-12 | 2.62 | k1_10000it_3600s |
| case_ACTIVSg200 | 17 | 24 | SUCC | 5.027e-06 |  | Solve_Succeeded | 107 | 1.0360537839974870e-11 | 3.39 | k1_10000it_3600s |
| case_ACTIVSg200 | 18 | 25 | SUCC | 4.969e-06 |  | Solve_Succeeded | 138 | 1.0022608285843726e-12 | 4.83 | k1_10000it_3600s |
| case_ACTIVSg200 | 19 | 26 | SUCC | 3.674e-09 |  | Solve_Succeeded | 61 | 1.2240813918040772e-10 | 1.92 | k1_10000it_3600s |
| case_ACTIVSg200 | 20 | 27 | SUCC | 1.440e-05 |  | Solve_Succeeded | 90 | 5.7406937276766046e-12 | 2.98 | k1_10000it_3600s |
| case_ACTIVSg200 | 21 | 33 | SUCC | 3.667e-09 |  | Solve_Succeeded | 76 | 5.9482540420985330e-13 | 2.26 | k1_10000it_3600s |
| case_ACTIVSg200 | 22 | 34 | SUCC | 3.667e-09 |  | Solve_Succeeded | 70 | 6.2153927837815814e-13 | 2.07 | k1_10000it_3600s |
| case_ACTIVSg200 | 23 | 37 | SUCC | 1.574e-09 |  | Solve_Succeeded | 89 | 2.1103605516749335e-12 | 2.84 | k1_10000it_3600s |
| case_ACTIVSg200 | 24 | 38 | SUCC | 1.573e-09 |  | Solve_Succeeded | 87 | 5.3617897882024534e-12 | 2.77 | k1_10000it_3600s |
| case_ACTIVSg200 | 25 | 40 | SUCC | 2.535e-05 |  | Solve_Succeeded | 157 | 1.3596717827156490e-11 | 6.01 | k1_10000it_3600s |
| case_ACTIVSg200 | 26 | 41 | SUCC | 1.714e-05 |  | Solve_Succeeded | 190 | 1.0197380808686651e-11 | 6.69 | k1_10000it_3600s |
| case_ACTIVSg200 | 27 | 43 | SUCC | 3.670e-09 |  | Solve_Succeeded | 85 | 8.8266855304865166e-12 | 2.85 | k1_10000it_3600s |
| case_ACTIVSg200 | 28 | 44 | SUCC | 1.572e-09 |  | Solve_Succeeded | 86 | 8.7898665668099951e-12 | 3.85 | k1_10000it_3600s |
| case_ACTIVSg200 | 29 | 46 | SUCC | 1.580e-09 |  | Solve_Succeeded | 69 | 4.9333214108878559e-13 | 2.02 | k1_10000it_3600s |
| case_ACTIVSg200 | 30 | 47 | SUCC | 2.236e-09 |  | Solve_Succeeded | 110 | 6.1994561502583256e-12 | 3.5 | k1_10000it_3600s |
| case_ACTIVSg200 | 31 | 50 | MAXITER | 1.458e-06 |  | Solve_Succeeded | 191 | 7.8553827396847520e-12 | 6.49 | k1_10000it_3600s |
| case_ACTIVSg200 | 32 | 51 | SUCC | 1.276e-06 |  | Solve_Succeeded | 96 | 7.8297331183689589e-12 | 3.08 | k1_10000it_3600s |
| case_ACTIVSg200 | 33 | 53 | SUCC | 1.608e-05 |  | Solve_Succeeded | 126 | 2.2402333352093684e-12 | 4.27 | k1_10000it_3600s |
| case_ACTIVSg200 | 34 | 54 | SUCC | 2.207e-06 |  | Solve_Succeeded | 92 | 1.0116608861531840e-11 | 2.76 | k1_10000it_3600s |
| case_ACTIVSg200 | 35 | 57 | SMALL_STEP | 7.909e-06 |  | Solve_Succeeded | 77 | 8.6958907956347087e-12 | 2.34 | k1_10000it_3600s |
| case_ACTIVSg200 | 36 | 58 | SUCC | 3.672e-09 |  | Solve_Succeeded | 69 | 1.2190359832686683e-11 | 2.3 | k1_10000it_3600s |
| case_ACTIVSg200 | 37 | 60 | SUCC | 3.668e-09 |  | Solve_Succeeded | 67 | 2.1801445604331324e-13 | 2.12 | k1_10000it_3600s |
| case_ACTIVSg200 | 38 | 61 | SUCC | 3.669e-09 |  | Solve_Succeeded | 107 | 8.0343814825960258e-12 | 3.67 | k1_10000it_3600s |
| case_ACTIVSg200 | 39 | 63 | SMALL_STEP | 5.722e-05 |  | Solve_Succeeded | 105 | 6.7187810762030231e-13 | 3.54 | k1_10000it_3600s |
| case_ACTIVSg200 | 40 | 64 | MAXITER | 4.119e-05 |  | Solve_Succeeded | 80 | 1.2324930572654713e-12 | 2.76 | k1_10000it_3600s |
| case_ACTIVSg200 | 41 | 65 | SUCC | 3.668e-09 |  | Solve_Succeeded | 77 | 6.1267986344037961e-11 | 2.35 | k1_10000it_3600s |
| case_ACTIVSg200 | 42 | 66 | SUCC | 3.682e-09 |  | Solve_Succeeded | 85 | 1.6627698566987203e-12 | 2.64 | k1_10000it_3600s |
| case_ACTIVSg200 | 43 | 67 | SUCC | 8.120e-07 |  | Solve_Succeeded | 85 | 1.2153417473250404e-11 | 2.59 | k1_10000it_3600s |
| case_ACTIVSg200 | 44 | 68 | SUCC | 8.464e-07 |  | Solve_Succeeded | 84 | 5.7584489917595922e-12 | 2.64 | k1_10000it_3600s |
| case_ACTIVSg200 | 45 | 69 | SUCC | 3.668e-09 |  | Solve_Succeeded | 59 | 1.4312910110044451e-11 | 1.77 | k1_10000it_3600s |
| case_ACTIVSg200 | 46 | 70 | SUCC | 3.668e-09 |  | Solve_Succeeded | 97 | 1.4183676314612897e-11 | 2.89 | k1_10000it_3600s |
| case_ACTIVSg200 | 47 | 71 | MAXITER | 3.675e-09 |  | Solve_Succeeded | 93 | 1.4469869530006618e-12 | 2.97 | k1_10000it_3600s |
| case_ACTIVSg200 | 48 | 72 | SUCC | 3.673e-09 |  | Solve_Succeeded | 81 | 3.2552627260429290e-11 | 2.65 | k1_10000it_3600s |
| case_ACTIVSg200 | 49 | 73 | SUCC | 3.667e-09 |  | Solve_Succeeded | 80 | 8.6449963127791657e-12 | 2.74 | k1_10000it_3600s |
| case_ACTIVSg200 | 50 | 74 | SUCC | 7.334e-07 |  | Solve_Succeeded | 95 | 5.9303892092216204e-12 | 3.07 | k1_10000it_3600s |
| case_ACTIVSg200 | 51 | 75 | MAXITER | 1.694e-09 |  | Solve_Succeeded | 92 | 1.3496500575124748e-11 | 2.86 | k1_10000it_3600s |
| case_ACTIVSg200 | 52 | 76 | SUCC | 1.601e-09 |  | Solve_Succeeded | 80 | 1.0972695354324186e-11 | 3.01 | k1_10000it_3600s |
| case_ACTIVSg200 | 53 | 77 | SUCC | 1.585e-09 |  | Solve_Succeeded | 90 | 1.2111180927500825e-11 | 2.79 | k1_10000it_3600s |
| case_ACTIVSg200 | 54 | 83 | SUCC | 3.667e-09 |  | Solve_Succeeded | 62 | 7.4582839904024935e-11 | 1.96 | k1_10000it_3600s |
| case_ACTIVSg200 | 55 | 84 | SUCC | 2.457e-07 |  | Solve_Succeeded | 100 | 3.8945723951572600e-12 | 3.25 | k1_10000it_3600s |
| case_ACTIVSg200 | 56 | 85 | SUCC | 1.242e-07 |  | Solve_Succeeded | 100 | 5.3789929867036068e-12 | 3.42 | k1_10000it_3600s |
| case_ACTIVSg200 | 57 | 86 | SUCC | 3.668e-09 |  | Solve_Succeeded | 79 | 3.4752821714140181e-11 | 2.46 | k1_10000it_3600s |
| case_ACTIVSg200 | 58 | 87 | MAXITER | 3.673e-09 |  | Solve_Succeeded | 72 | 1.4271261076511483e-11 | 2.18 | k1_10000it_3600s |
| case_ACTIVSg200 | 59 | 88 | SUCC | 1.571e-09 |  | Solve_Succeeded | 94 | 1.2204748767608714e-11 | 3.21 | k1_10000it_3600s |
| case_ACTIVSg200 | 60 | 89 | SUCC | 1.571e-09 |  | Solve_Succeeded | 78 | 1.0254626385238289e-11 | 2.48 | k1_10000it_3600s |
| case_ACTIVSg200 | 61 | 90 | SUCC | 3.845e-09 |  | Solve_Succeeded | 104 | 3.8433313064197006e-12 | 3.4 | k1_10000it_3600s |
| case_ACTIVSg200 | 62 | 91 | SUCC | 2.363e-06 |  | Solve_Succeeded | 64 | 7.5948268941222752e-12 | 1.92 | k1_10000it_3600s |
| case_ACTIVSg200 | 63 | 93 | SUCC | 3.657e-06 |  | Solve_Succeeded | 97 | 1.1433449510506871e-11 | 3.9 | k1_10000it_3600s |
| case_ACTIVSg200 | 64 | 94 | SUCC | 2.993e-06 |  | Solve_Succeeded | 103 | 8.8746112238483055e-12 | 4.69 | k1_10000it_3600s |
| case_ACTIVSg200 | 65 | 95 | SUCC | 4.457e-06 |  | Solve_Succeeded | 100 | 1.1018659644640785e-11 | 3.26 | k1_10000it_3600s |
| case_ACTIVSg200 | 66 | 96 | SUCC | 3.667e-09 |  | Solve_Succeeded | 67 | 7.7239044695733006e-12 | 2.0 | k1_10000it_3600s |
| case_ACTIVSg200 | 67 | 97 | SUCC | 1.571e-09 |  | Solve_Succeeded | 69 | 9.3293159655893909e-12 | 2.09 | k1_10000it_3600s |
| case_ACTIVSg200 | 68 | 98 | SUCC | 3.669e-09 |  | Solve_Succeeded | 81 | 4.9066536424169360e-12 | 2.59 | k1_10000it_3600s |
| case_ACTIVSg200 | 69 | 99 | SUCC | 2.204e-06 |  | Solve_Succeeded | 71 | 2.6942586481065386e-12 | 2.12 | k1_10000it_3600s |
| case_ACTIVSg200 | 70 | 100 | MAXITER | 3.672e-09 |  | Solve_Succeeded | 82 | 2.2800404793354989e-11 | 2.58 | k1_10000it_3600s |
| case_ACTIVSg200 | 71 | 101 | MAXITER | 8.063e-05 |  | Solve_Succeeded | 121 | 7.9903965388705700e-13 | 4.33 | k1_10000it_3600s |
| case_ACTIVSg200 | 72 | 102 | SUCC | 9.449e-05 |  | Solve_Succeeded | 97 | 1.7602878356337559e-11 | 3.32 | k1_10000it_3600s |
| case_ACTIVSg200 | 73 | 111 | SUCC | 1.080e-05 |  | Solve_Succeeded | 108 | 4.3867042702309955e-12 | 3.78 | k1_10000it_3600s |
| case_ACTIVSg200 | 74 | 112 | SUCC | 3.670e-09 |  | Solve_Succeeded | 63 | 4.4119608242135493e-12 | 2.29 | k1_10000it_3600s |
| case_ACTIVSg200 | 75 | 115 | SUCC | 7.117e-09 | yes | Solve_Succeeded | 237 | 3.4203892973136418e-12 | 7.12 | k1_10000it_3600s |
| case_ACTIVSg200 | 76 | 116 | SUCC | 7.117e-09 | yes | Solve_Succeeded | 237 | 3.8326659012287434e-12 | 7.12 | k1_10000it_3600s |
| case_ACTIVSg200 | 77 | 117 | SUCC | 1.583e-09 |  | Solve_Succeeded | 88 | 6.8665559349589955e-13 | 2.79 | k1_10000it_3600s |
| case_ACTIVSg200 | 78 | 118 | MAXITER | 1.635e-09 |  | Solve_Succeeded | 87 | 2.7668446418542547e-12 | 2.84 | k1_10000it_3600s |
| case_ACTIVSg200 | 79 | 119 | SUCC | 2.893e-05 |  | Solve_Succeeded | 94 | 6.0249751693795817e-12 | 3.1 | k1_10000it_3600s |
| case_ACTIVSg200 | 80 | 120 | SUCC | 7.442e-05 |  | Solve_Succeeded | 118 | 1.8147594971901215e-11 | 3.86 | k1_10000it_3600s |
| case_ACTIVSg200 | 81 | 121 | SUCC | 1.994e-05 |  | Solve_Succeeded | 84 | 5.8424932372538180e-13 | 2.68 | k1_10000it_3600s |
| case_ACTIVSg200 | 82 | 122 | MAXITER | 6.607e-08 |  | Solve_Succeeded | 61 | 3.9297652453104334e-12 | 1.89 | k1_10000it_3600s |
| case_ACTIVSg200 | 83 | 123 | SUCC | 1.632e-05 |  | Solve_Succeeded | 93 | 5.5798749952137849e-12 | 2.91 | k1_10000it_3600s |
| case_ACTIVSg200 | 84 | 124 | MAXITER | 7.303e-08 |  | Solve_Succeeded | 64 | 1.0484326948279055e-11 | 1.88 | k1_10000it_3600s |
| case_ACTIVSg200 | 85 | 125 | SUCC | 4.626e-08 |  | Solve_Succeeded | 62 | 2.3467665392342893e-12 | 1.84 | k1_10000it_3600s |
| case_ACTIVSg200 | 86 | 126 | SUCC | 1.046e-06 |  | Solve_Succeeded | 74 | 1.6334156249797616e-13 | 3.0 | k1_10000it_3600s |
| case_ACTIVSg200 | 87 | 127 | MAXITER | 3.448e-08 |  | Solve_Succeeded | 66 | 9.3506428457384300e-12 | 2.08 | k1_10000it_3600s |
| case_ACTIVSg200 | 88 | 128 | SUCC | 4.428e-09 |  | Solve_Succeeded | 87 | 1.3621705326205547e-11 | 2.7 | k1_10000it_3600s |
| case_ACTIVSg200 | 89 | 129 | SUCC | 1.242e-08 |  | Solve_Succeeded | 100 | 8.4002784112371942e-12 | 3.09 | k1_10000it_3600s |
| case_ACTIVSg200 | 90 | 130 | SUCC | 4.158e-09 |  | Solve_Succeeded | 84 | 2.1416430369576578e-12 | 2.59 | k1_10000it_3600s |
| case_ACTIVSg200 | 91 | 131 | SUCC | 1.580e-09 |  | Solve_Succeeded | 72 | 3.7310832422504225e-12 | 2.49 | k1_10000it_3600s |
| case_ACTIVSg200 | 92 | 132 | SUCC | 1.573e-09 |  | Solve_Succeeded | 71 | 9.3377604842739652e-12 | 2.08 | k1_10000it_3600s |
| case_ACTIVSg200 | 93 | 133 | SUCC | 1.639e-09 |  | Solve_Succeeded | 96 | 7.2934146786232668e-12 | 3.0 | k1_10000it_3600s |
| case_ACTIVSg200 | 94 | 134 | SUCC | 1.575e-09 |  | Solve_Succeeded | 71 | 8.5766017700913792e-12 | 2.23 | k1_10000it_3600s |
| case_ACTIVSg200 | 95 | 135 | SUCC | 1.218e-08 |  | Solve_Succeeded | 98 | 3.7396847229163865e-12 | 2.91 | k1_10000it_3600s |
| case_ACTIVSg200 | 96 | 138 | SUCC | 7.117e-09 | yes | Solve_Succeeded | 380 | 1.0383242117668889e-12 | 9.45 | k1_10000it_3600s |
| case_ACTIVSg200 | 97 | 140 | SUCC | 5.125e-06 |  | Solve_Succeeded | 102 | 1.2136094971852696e-11 | 3.17 | k1_10000it_3600s |
| case_ACTIVSg200 | 98 | 142 | SUCC | 3.669e-09 |  | Solve_Succeeded | 86 | 6.8219952256698413e-12 | 2.56 | k1_10000it_3600s |
| case_ACTIVSg200 | 99 | 143 | SUCC | 3.947e-06 |  | Solve_Succeeded | 108 | 9.2318057495419104e-12 | 3.18 | k1_10000it_3600s |
| case_ACTIVSg200 | 100 | 144 | SUCC | 1.574e-09 |  | Solve_Succeeded | 57 | 1.7286826538374239e-12 | 1.6 | k1_10000it_3600s |
| case_ACTIVSg500 | 1 | 2 | SUCC | 1.156e-07 |  | Solve_Succeeded | 242 | 1.4551915228366852e-11 | 19.91 | c3_3000it_600s |
| case_ACTIVSg500 | 2 | 3 | SUCC | 1.546e-08 |  | Solve_Succeeded | 172 | 1.4551915228366852e-11 | 13.46 | c3_3000it_600s |
| case_ACTIVSg500 | 3 | 5 | SUCC | 2.906e-07 |  | Solve_Succeeded | 304 | 2.0432266989445227e-13 | 24.94 | c3_3000it_600s |
| case_ACTIVSg500 | 4 | 6 | SUCC | 1.496e-06 |  | Solve_Succeeded | 187 | 2.1123727766969580e-13 | 14.84 | c3_3000it_600s |
| case_ACTIVSg500 | 5 | 10 | SUCC | 4.107e-07 |  | Solve_Succeeded | 375 | 1.4551915228366852e-11 | 32.49 | c3_3000it_600s |
| case_ACTIVSg500 | 6 | 13 | SUCC | 4.509e-07 |  | Solve_Succeeded | 267 | 2.0702883851697604e-13 | 21.71 | c3_3000it_600s |
| case_ACTIVSg500 | 7 | 14 | SUCC | 7.430e-07 |  | Solve_Succeeded | 300 | 1.4551915228366852e-11 | 25.72 | c3_3000it_600s |
| case_ACTIVSg500 | 8 | 15 | SUCC | 4.700e-07 |  | Solve_Succeeded | 160 | 1.9478862967048374e-13 | 13.69 | c3_3000it_600s |
| case_ACTIVSg500 | 9 | 16 | SUCC | 7.869e-09 |  | Solve_Succeeded | 204 | 1.4551915228366852e-11 | 16.18 | c3_3000it_600s |
| case_ACTIVSg500 | 10 | 18 | SUCC | 3.313e-08 |  | Solve_Succeeded | 391 | 2.2243318298365011e-13 | 31.88 | c3_3000it_600s |
| case_ACTIVSg500 | 11 | 19 | SUCC | 4.837e-08 |  | Solve_Succeeded | 348 | 1.4551915228366852e-11 | 28.5 | c3_3000it_600s |
| case_ACTIVSg500 | 12 | 21 | MAXITER | 1.150e-06 |  | Solve_Succeeded | 215 | 1.4551915228366852e-11 | 17.15 | c3_3000it_600s |
| case_ACTIVSg500 | 13 | 22 | SUCC | 3.348e-07 |  | Solve_Succeeded | 314 | 2.0272672429655358e-13 | 26.76 | c3_3000it_600s |
| case_ACTIVSg500 | 14 | 23 | SUCC | 1.660e-06 |  | Solve_Succeeded | 175 | 2.0289325775024733e-13 | 13.69 | c3_3000it_600s |
| case_ACTIVSg500 | 15 | 24 | MAXITER | 4.682e-06 |  | Solve_Succeeded | 370 | 2.0159568459021671e-13 | 30.09 | c3_3000it_600s |
| case_ACTIVSg500 | 16 | 29 | SUCC | 5.182e-07 |  | Solve_Succeeded | 565 | 2.0287937996243957e-13 | 48.51 | c3_3000it_600s |
| case_ACTIVSg500 | 17 | 30 | SUCC | 5.084e-07 |  | Solve_Succeeded | 511 | 1.4551915228366852e-11 | 42.88 | c3_3000it_600s |
| case_ACTIVSg500 | 18 | 31 | SUCC | 1.393e-07 |  | Solve_Succeeded | 193 | 1.4551915228366852e-11 | 14.97 | c3_3000it_600s |
| case_ACTIVSg500 | 19 | 32 | SUCC | 2.059e-06 |  | Solve_Succeeded | 364 | 1.4551915228366852e-11 | 30.12 | c3_3000it_600s |
| case_ACTIVSg500 | 20 | 33 | SUCC | 5.307e-09 |  | Solve_Succeeded | 589 | 7.4601436139687394e-12 | 49.85 | c3_3000it_600s |
| case_ACTIVSg500 | 21 | 34 | SUCC | 9.238e-08 |  | Solve_Succeeded | 110 | 2.0367041386748497e-13 | 8.09 | c3_3000it_600s |
| case_ACTIVSg500 | 22 | 35 | SUCC | 1.158e-08 |  | Solve_Succeeded | 134 | 4.9149573300155680e-13 | 10.96 | c3_3000it_600s |
| case_ACTIVSg500 | 23 | 37 | SUCC | 1.419e-06 |  | Solve_Succeeded | 186 | 1.4551915228366852e-11 | 14.48 | c3_3000it_600s |
| case_ACTIVSg500 | 24 | 38 | SUCC | 2.360e-06 |  | Solve_Succeeded | 242 | 2.2849083736176112e-13 | 19.72 | c3_3000it_600s |
| case_ACTIVSg500 | 25 | 39 | SUCC | 1.096e-05 |  | Solve_Succeeded | 111 | 2.0750068330244176e-13 | 8.25 | c3_3000it_600s |
| case_ACTIVSg500 | 26 | 41 | SUCC | 1.999e-06 |  | Solve_Succeeded | 164 | 2.1598001165301642e-13 | 12.71 | c3_3000it_600s |
| case_ACTIVSg500 | 27 | 42 | SUCC | 5.301e-09 |  | Solve_Succeeded | 345 | 1.4551915228366852e-11 | 34.07 | c3_3000it_600s |
| case_ACTIVSg500 | 28 | 43 | SUCC | 3.638e-06 |  | Solve_Succeeded | 702 | 2.1685431228490873e-13 | 59.15 | c3_3000it_600s |
| case_ACTIVSg500 | 29 | 44 | SUCC | 5.307e-09 |  | Solve_Succeeded | 246 | 1.8943180357666733e-13 | 19.06 | c3_3000it_600s |
| case_ACTIVSg500 | 30 | 45 | SUCC | 2.375e-09 |  | Solve_Succeeded | 619 | 2.2197521598599221e-13 | 50.73 | c3_3000it_600s |
| case_ACTIVSg500 | 31 | 46 | SUCC | 1.914e-08 |  | Solve_Succeeded | 601 | 1.9113877147702851e-13 | 91.01 | c3_3000it_600s |
| case_ACTIVSg500 | 32 | 47 | MAXITER | 5.802e-07 |  | Solve_Succeeded | 255 | 2.3875346144563991e-13 | 21.69 | c3_3000it_600s |
| case_ACTIVSg500 | 33 | 50 | SUCC | 2.574e-08 |  | Solve_Succeeded | 405 | 1.8424151093654470e-13 | 34.18 | c3_3000it_600s |
| case_ACTIVSg500 | 34 | 51 | SUCC | 4.148e-06 |  | Solve_Succeeded | 228 | 1.4551915228366852e-11 | 17.88 | c3_3000it_600s |
| case_ACTIVSg500 | 35 | 53 | SUCC | 5.306e-09 |  | Solve_Succeeded | 598 | 2.1083135237631723e-13 | 51.99 | c3_3000it_600s |
| case_ACTIVSg500 | 36 | 54 | SUCC | 4.603e-05 |  | Solve_Succeeded | 563 | 2.2507343211408681e-13 | 47.66 | c3_3000it_600s |
| case_ACTIVSg500 | 37 | 56 | SUCC | 5.573e-07 |  | Solve_Succeeded | 146 | 1.4551915228366852e-11 | 10.17 | c3_3000it_600s |
| case_ACTIVSg500 | 38 | 57 | SUCC | 9.389e-09 |  | Solve_Succeeded | 210 | 2.2448709557920665e-13 | 16.36 | c3_3000it_600s |
| case_ACTIVSg500 | 39 | 59 | MAXITER | 1.181e-05 |  | Solve_Succeeded | 194 | 3.9732292456129414e-10 | 16.31 | c3_3000it_600s |
| case_ACTIVSg500 | 40 | 60 | SUCC | 1.939e-05 |  | Solve_Succeeded | 246 | 2.3933632853356812e-13 | 21.54 | c3_3000it_600s |
| case_ACTIVSg500 | 41 | 61 | MAXITER | 5.761e-06 |  | Solve_Succeeded | 212 | 2.5256641396353974e-13 | 16.92 | c3_3000it_600s |
| case_ACTIVSg500 | 42 | 62 | SUCC | 7.478e-06 |  | Solve_Succeeded | 88 | 1.4551915228366852e-11 | 6.32 | c3_3000it_600s |
| case_ACTIVSg500 | 43 | 63 | SUCC | 5.278e-06 |  | Solve_Succeeded | 84 | 1.0734607647222560e-12 | 5.91 | c3_3000it_600s |
| case_ACTIVSg500 | 44 | 64 | SUCC | 2.101e-05 |  | Solve_Succeeded | 182 | 1.4551915228366852e-11 | 14.89 | c3_3000it_600s |
| case_ACTIVSg500 | 45 | 66 | SUCC | 4.940e-07 |  | Solve_Succeeded | 685 | 2.2004620348070603e-13 | 55.98 | c3_3000it_600s |
| case_ACTIVSg500 | 46 | 67 | SUCC | 1.245e-06 |  | Solve_Succeeded | 134 | 2.1262158700352532e-13 | 10.21 | c3_3000it_600s |
| case_ACTIVSg500 | 47 | 69 | MAXITER | 2.515e-07 |  | Solve_Succeeded | 230 | 2.2649937481133975e-13 | 18.57 | c3_3000it_600s |
| case_ACTIVSg500 | 48 | 70 | SUCC | 2.302e-08 |  | Solve_Succeeded | 200 | 2.2837287616539470e-13 | 16.13 | c3_3000it_600s |
| case_ACTIVSg500 | 49 | 74 | SUCC | 2.542e-07 |  | Solve_Succeeded | 101 | 2.2057355941740300e-13 | 7.09 | c3_3000it_600s |
| case_ACTIVSg500 | 50 | 75 | SUCC | 1.081e-08 |  | Solve_Succeeded | 806 | 1.4551915228366852e-11 | 110.85 | c3_3000it_600s |
| case_ACTIVSg500 | 51 | 76 | SUCC | 1.730e-07 |  | Solve_Succeeded | 608 | 1.4551915228366852e-11 | 80.36 | c3_3000it_600s |
| case_ACTIVSg500 | 52 | 78 | SUCC | 2.587e-08 |  | Solve_Succeeded | 226 | 1.7016249520551696e-13 | 17.77 | c3_3000it_600s |
| case_ACTIVSg500 | 53 | 80 | SUCC | 3.361e-07 |  | Solve_Succeeded | 291 | 1.9999280009841414e-13 | 23.57 | c3_3000it_600s |
| case_ACTIVSg500 | 54 | 81 | SUCC | 2.959e-07 |  | Solve_Succeeded | 260 | 1.4551915228366852e-11 | 21.63 | c3_3000it_600s |
| case_ACTIVSg500 | 55 | 83 | SUCC | 1.127e-07 |  | Solve_Succeeded | 234 | 2.1216362000586741e-13 | 18.84 | c3_3000it_600s |
| case_ACTIVSg500 | 56 | 85 | SUCC | 1.766e-07 |  | Solve_Succeeded | 110 | 1.4551915228366852e-11 | 8.49 | c3_3000it_600s |
| case_ACTIVSg500 | 57 | 86 | SUCC | 7.238e-07 |  | Solve_Succeeded | 142 | 2.0197732375493160e-13 | 16.81 | k1_10000it_3600s |
| case_ACTIVSg500 | 58 | 91 | SUCC | 2.575e-09 |  | Solve_Succeeded | 215 | 2.3954449535068534e-13 | 23.81 | k1_10000it_3600s |
| case_ACTIVSg500 | 59 | 92 | SUCC | 5.308e-09 |  | Solve_Succeeded | 265 | 1.4551915228366852e-11 | 29.16 | k1_10000it_3600s |
| case_ACTIVSg500 | 60 | 94 | SUCC | 5.077e-08 |  | Solve_Succeeded | 271 | 3.8664210721961467e-13 | 28.51 | k1_10000it_3600s |
| case_ACTIVSg500 | 61 | 95 | SUCC | 9.192e-09 |  | Solve_Succeeded | 114 | 1.4551915228366852e-11 | 15.53 | k1_10000it_3600s |
| case_ACTIVSg500 | 62 | 97 | SUCC | 2.776e-08 |  | Solve_Succeeded | 203 | 1.0590972543411681e-12 | 24.34 | k1_10000it_3600s |
| case_ACTIVSg500 | 63 | 98 | SUCC | 2.394e-08 |  | Solve_Succeeded | 113 | 1.9155510511126295e-13 | 15.55 | k1_10000it_3600s |
| case_ACTIVSg500 | 64 | 99 | MAXITER | 1.376e-06 |  | Solve_Succeeded | 175 | 1.8557377856609494e-13 | 20.93 | k1_10000it_3600s |
| case_ACTIVSg500 | 65 | 100 | MAXITER | 1.376e-06 |  | Solve_Succeeded | 142 | 2.0339285811132868e-13 | 18.59 | k1_10000it_3600s |
| case_ACTIVSg500 | 66 | 101 | SUCC | 6.834e-06 |  | Solve_Succeeded | 548 | 1.9852175459078580e-13 | 57.08 | k1_10000it_3600s |
| case_ACTIVSg500 | 67 | 102 | SUCC | 8.376e-07 |  | Solve_Succeeded | 256 | 2.1346119316589807e-13 | 27.57 | k1_10000it_3600s |
| case_ACTIVSg500 | 68 | 104 | SUCC | 1.201e-07 |  | Solve_Succeeded | 647 | 1.4551915228366852e-11 | 65.61 | k1_10000it_3600s |
| case_ACTIVSg500 | 69 | 105 | SUCC | 1.157e-06 |  | Solve_Succeeded | 156 | 1.4551915228366852e-11 | 18.65 | k1_10000it_3600s |
| case_ACTIVSg500 | 70 | 106 | SUCC | 1.156e-06 |  | Solve_Succeeded | 124 | 1.4551915228366852e-11 | 17.91 | k1_10000it_3600s |
| case_ACTIVSg500 | 71 | 108 | SUCC | 7.637e-09 |  | Solve_Succeeded | 151 | 2.0167201242315966e-13 | 20.88 | k1_10000it_3600s |
| case_ACTIVSg500 | 72 | 109 | SUCC | 7.627e-09 |  | Solve_Succeeded | 131 | 1.4551915228366852e-11 | 18.07 | k1_10000it_3600s |
| case_ACTIVSg500 | 73 | 110 | SUCC | 6.382e-09 | yes | Solve_Succeeded | 514 | 1.4551915228366852e-11 | 42.64 | k1_10000it_3600s |
| case_ACTIVSg500 | 74 | 112 | SUCC | 5.954e-08 |  | Solve_Succeeded | 221 | 1.4551915228366852e-11 | 25.61 | k1_10000it_3600s |
| case_ACTIVSg500 | 75 | 113 | SUCC | 1.497e-07 |  | Solve_Succeeded | 149 | 2.3029321505330103e-13 | 18.15 | k1_10000it_3600s |
| case_ACTIVSg500 | 76 | 114 | SUCC | 3.785e-08 |  | Solve_Succeeded | 204 | 2.1022072971277337e-13 | 24.12 | k1_10000it_3600s |
| case_ACTIVSg500 | 77 | 115 | SUCC | 5.309e-09 |  | Solve_Succeeded | 674 | 1.4551915228366852e-11 | 63.25 | k1_10000it_3600s |
| case_ACTIVSg500 | 78 | 116 | SUCC | 3.669e-06 |  | Solve_Succeeded | 565 | 2.0158527624936082e-13 | 54.81 | k1_10000it_3600s |
| case_ACTIVSg500 | 79 | 118 | SUCC | 5.308e-09 |  | Solve_Succeeded | 169 | 1.4551915228366852e-11 | 21.46 | k1_10000it_3600s |
| case_ACTIVSg500 | 80 | 120 | SUCC | 5.307e-09 |  | Solve_Succeeded | 140 | 1.8493540032693543e-13 | 18.35 | k1_10000it_3600s |
| case_ACTIVSg500 | 81 | 121 | SUCC | 5.307e-09 |  | Solve_Succeeded | 130 | 1.4551915228366852e-11 | 16.95 | k1_10000it_3600s |
| case_ACTIVSg500 | 82 | 125 | SUCC | 9.902e-08 |  | Solve_Succeeded | 276 | 2.0856927296364347e-13 | 29.02 | k1_10000it_3600s |
| case_ACTIVSg500 | 83 | 126 | SUCC | 1.790e-07 |  | Solve_Succeeded | 226 | 2.8194113710355850e-13 | 25.18 | k1_10000it_3600s |
| case_ACTIVSg500 | 84 | 128 | SUCC | 2.839e-06 |  | Solve_Succeeded | 107 | 2.0085322294249863e-13 | 15.01 | k1_10000it_3600s |
| case_ACTIVSg500 | 85 | 129 | SUCC | 2.481e-06 |  | Solve_Succeeded | 114 | 2.9887203822909214e-13 | 15.65 | k1_10000it_3600s |
| case_ACTIVSg500 | 86 | 133 | SUCC | 2.161e-06 |  | Solve_Succeeded | 340 | 1.4551915228366852e-11 | 27.61 | k1_10000it_3600s |
| case_ACTIVSg500 | 87 | 134 | SUCC | 2.164e-06 |  | Solve_Succeeded | 338 | 1.8664583767424861e-13 | 27.93 | k1_10000it_3600s |
| case_ACTIVSg500 | 88 | 135 | SUCC | 6.333e-07 |  | Solve_Succeeded | 619 | 2.5422164373622991e-12 | 52.05 | k1_10000it_3600s |
| case_ACTIVSg500 | 89 | 137 | SUCC | 1.994e-06 |  | Solve_Succeeded | 162 | 2.1158075291793923e-13 | 12.75 | k1_10000it_3600s |
| case_ACTIVSg500 | 90 | 138 | SUCC | 4.006e-08 |  | Solve_Succeeded | 510 | 2.2567364643677479e-13 | 46.98 | k1_10000it_3600s |
| case_ACTIVSg500 | 91 | 140 | SUCC | 1.338e-08 |  | Solve_Succeeded | 266 | 1.4551915228366852e-11 | 23.16 | k1_10000it_3600s |
| case_ACTIVSg500 | 92 | 142 | MAXITER | 5.776e-06 |  | Solve_Succeeded | 201 | 1.4551915228366852e-11 | 23.87 | k1_10000it_3600s |
| case_ACTIVSg500 | 93 | 146 | MAXITER | 1.793e-05 |  | Solve_Succeeded | 240 | 1.4551915228366852e-11 | 26.41 | k1_10000it_3600s |
| case_ACTIVSg500 | 94 | 148 | SUCC | 6.832e-09 |  | Solve_Succeeded | 178 | 1.7930101847696281e-13 | 20.82 | k1_10000it_3600s |
| case_ACTIVSg500 | 95 | 149 | SUCC | 1.099e-08 |  | Solve_Succeeded | 166 | 1.9326207301162412e-13 | 24.1 | k1_10000it_3600s |
| case_ACTIVSg500 | 96 | 151 | SUCC | 6.577e-09 |  | Solve_Succeeded | 128 | 1.4551915228366852e-11 | 16.78 | k1_10000it_3600s |
| case_ACTIVSg500 | 97 | 153 | MAXITER | 1.533e-07 |  | Solve_Succeeded | 289 | 2.2185031589572191e-13 | 30.2 | k1_10000it_3600s |
| case_ACTIVSg500 | 98 | 154 | SUCC | 1.659e-08 |  | Solve_Succeeded | 341 | 1.9084733793306441e-13 | 36.31 | k1_10000it_3600s |
| case_ACTIVSg500 | 99 | 156 | SUCC | 7.218e-09 |  | Solve_Succeeded | 112 | 1.4551915228366852e-11 | 16.06 | k1_10000it_3600s |
| case_ACTIVSg500 | 100 | 157 | SUCC | 7.585e-08 |  | Solve_Succeeded | 119 | 2.0941581801992013e-13 | 15.86 | k1_10000it_3600s |
| case1354pegase | 1 | 4 | MAXITER | 2.849e-06 |  | Solve_Succeeded | 1114 | 5.5723203828961232e-12 | 348.37 | k1_10000it_3600s |
| case1354pegase | 2 | 5 | SUCC | 1.639e-08 |  | Solve_Succeeded | 957 | 1.4551915228366852e-11 | 307.43 | k1_10000it_3600s |
| case1354pegase | 3 | 6 | SUCC | 7.155e-09 | yes | Restoration_Failed | 1038 | 1.9323154187844693e-12 | 273.63 | k1_10000it_3600s |
| case1354pegase | 4 | 8 | SUCC | 7.155e-09 | yes | Restoration_Failed | 1034 | 2.0846939625951411e-12 | 323.48 | k1_10000it_3600s |
| case1354pegase | 5 | 9 | SUCC | 7.155e-09 | yes | Solve_Succeeded | 665 | 2.2286478218447314e-12 | 175.65 | k1_10000it_3600s |
| case1354pegase | 6 | 14 | SUCC | 5.166e-07 |  | Solve_Succeeded | 856 | 1.4551915228366852e-11 | 267.08 | k1_10000it_3600s |
| case1354pegase | 7 | 15 | SUCC | 7.086e-07 |  | Solve_Succeeded | 1664 | 1.4551915228366852e-11 | 602.75 | k1_10000it_3600s |
| case1354pegase | 8 | 18 | SUCC | 3.650e-08 |  | Solve_Succeeded | 1219 | 2.2408463973278003e-12 | 380.98 | k1_10000it_3600s |
| case1354pegase | 9 | 20 | MAXITER | 1.068e-08 |  | Solve_Succeeded | 799 | 2.3561985695863541e-12 | 241.42 | k1_10000it_3600s |
| case1354pegase | 10 | 21 | MAXITER | 7.201e-09 |  | Solve_Succeeded | 1063 | 2.2231771978908906e-11 | 314.22 | k1_10000it_3600s |
| case1354pegase | 11 | 22 | MAXITER | 4.088e-06 |  | Solve_Succeeded | 1325 | 5.8683169434914362e-11 | 413.28 | k1_10000it_3600s |
| case1354pegase | 12 | 23 | SUCC | 7.148e-09 |  | Solve_Succeeded | 1152 | 1.4551915228366852e-11 | 366.73 | k1_10000it_3600s |
| case1354pegase | 13 | 26 | SUCC | 7.149e-09 |  | Solve_Succeeded | 1412 | 1.7958079467916832e-11 | 402.93 | k1_10000it_3600s |
| case1354pegase | 14 | 30 | MAXITER | 1.265e-08 |  | Solve_Succeeded | 847 | 4.2873937733389766e-10 | 290.88 | k1_10000it_3600s |
| case1354pegase | 15 | 32 | MAXITER | 1.200e-08 |  | Solve_Succeeded | 1538 | 3.6244762746662218e-10 | 490.63 | k1_10000it_3600s |
| case1354pegase | 16 | 33 | SUCC | 3.686e-08 |  | Solve_Succeeded | 641 | 8.2942097634486345e-11 | 179.51 | k1_10000it_3600s |
| case1354pegase | 17 | 36 | MAXITER | 5.113e-09 |  | Solve_Succeeded | 1138 | 1.4551915228366852e-11 | 389.55 | k1_10000it_3600s |
| case1354pegase | 18 | 37 | SUCC | 1.057e-08 |  | Solve_Succeeded | 1320 | 2.6811330933185218e-12 | 389.77 | k1_10000it_3600s |
| case1354pegase | 19 | 38 | SUCC | 7.150e-09 |  | Solve_Succeeded | 1009 | 1.4551915228366852e-11 | 307.27 | k1_10000it_3600s |
| case1354pegase | 20 | 39 | SUCC | 7.150e-09 |  | Solve_Succeeded | 1415 | 1.4551915228366852e-11 | 412.58 | k1_10000it_3600s |
| case1354pegase | 21 | 40 | SUCC | 9.950e-09 |  | Solve_Succeeded | 1760 | 3.1325636529189183e-12 | 673.31 | k1_10000it_3600s |
| case1354pegase | 22 | 41 | MAXITER | 1.364e-08 |  | Solve_Succeeded | 1035 | 3.9107383997816214e-11 | 305.79 | k1_10000it_3600s |
| case1354pegase | 23 | 42 | MAXITER | 1.084e-08 |  | Solve_Succeeded | 1481 | 2.1841556341328783e-12 | 453.9 | k1_10000it_3600s |
| case1354pegase | 24 | 43 | SUCC | 6.248e-07 |  | Solve_Succeeded | 813 | 1.7836843113627765e-12 | 264.25 | k1_10000it_3600s |
| case1354pegase | 25 | 44 | SUCC | 4.517e-07 |  | Solve_Succeeded | 2098 | 2.4551582988863174e-11 | 662.61 | k1_10000it_3600s |
| case1354pegase | 26 | 46 | SUCC | 4.062e-08 |  | Restoration_Failed | 1044 | 2.8990976286280556e-12 | 338.96 | k1_10000it_3600s |
| case1354pegase | 27 | 47 | SUCC | 5.465e-07 |  | Solve_Succeeded | 1060 | 1.4551915228366852e-11 | 333.29 | k1_10000it_3600s |
| case1354pegase | 28 | 48 | SUCC | 1.255e-07 |  | Solve_Succeeded | 934 | 1.4551915228366852e-11 | 301.59 | k1_10000it_3600s |
| case1354pegase | 29 | 49 | SUCC | 6.979e-07 |  | Solve_Succeeded | 1075 | 1.4551915228366852e-11 | 312.06 | k1_10000it_3600s |
| case1354pegase | 30 | 50 | MAXITER | 7.066e-09 |  | Solve_Succeeded | 2543 | 1.4551915228366852e-11 | 780.31 | k1_10000it_3600s |
| case1354pegase | 31 | 51 | MAXITER | 1.034e-07 |  | Solve_Succeeded | 1493 | 4.4220238581971216e-11 | 475.75 | k1_10000it_3600s |
| case1354pegase | 32 | 52 | SUCC | 7.148e-09 |  | Solve_Succeeded | 1767 | 8.0254403123092288e-10 | 537.11 | k1_10000it_3600s |
| case2869pegase | 1 | 1 | SUCC | 7.319e-07 |  | Solve_Succeeded | 2392 | 1.4551915228366852e-11 | 2010.28 | k1_10000it_3600s |
| case2869pegase | 2 | 2 | MAXITER | 8.437e-07 |  | Solve_Succeeded | 2522 | 3.6047498319646820e-11 | 2056.05 | k1_10000it_3600s |
| case2869pegase | 3 | 3 | MAXITER | 2.470e-05 |  | Solve_Succeeded | 1380 | 1.4551915228366852e-11 | 1094.48 | k1_10000it_3600s |
| case2869pegase | 4 | 4 | SUCC | 2.548e-05 |  | Solve_Succeeded | 2173 | 1.4551915228366852e-11 | 2666.59 | k1_10000it_3600s |
| case2869pegase | 5 | 5 | MAXITER | 1.495e-07 |  | Solve_Succeeded | 1671 | 1.4551915228366852e-11 | 1293.55 | k1_10000it_3600s |
| case2869pegase | 6 | 6 | SUCC | 1.435e-07 |  | Solve_Succeeded | 1973 | 8.5674356498088855e-11 | 2232.41 | k1_10000it_3600s |
| case2869pegase | 7 | 7 | MAXITER | 1.423e-07 |  | Solve_Succeeded | 1814 | 1.4551915228366852e-11 | 1534.5 | k1_10000it_3600s |
| case2869pegase | 8 | 8 | MAXITER | 1.357e-07 |  | Solve_Succeeded | 1736 | 1.0474177081221114e-10 | 1350.3 | k1_10000it_3600s |
| case2869pegase | 9 | 9 | SUCC | 1.756e-07 |  | Solve_Succeeded | 1408 | 3.0525426630845232e-10 | 1146.19 | k1_10000it_3600s |
| case2869pegase | 10 | 10 | MAXITER | 4.265e-07 |  | Solve_Succeeded | 1701 | 1.4551915228366852e-11 | 1503.26 | k1_10000it_3600s |
| case2869pegase | 11 | 11 | MAXITER | 2.448e-07 |  | Solve_Succeeded | 1483 | 1.4551915228366852e-11 | 1297.47 | k1_10000it_3600s |
| case2869pegase | 12 | 12 | MAXITER | 2.448e-07 |  | Solve_Succeeded | 933 | 2.0903584418974219e-11 | 780.85 | k1_10000it_3600s |
| case2869pegase | 13 | 13 | SUCC | 3.795e-08 |  | Solve_Succeeded | 1521 | 1.4551915228366852e-11 | 1232.3 | k1_10000it_3600s |
| case2869pegase | 14 | 14 | MAXITER | 4.302e-08 |  | Solve_Succeeded | 1419 | 8.1799012008332284e-11 | 1054.74 | k1_10000it_3600s |
| case2869pegase | 15 | 15 | SUCC | 1.002e-05 |  | Restoration_Failed | 1754 | 1.4551915228366852e-11 | 1396.57 | k1_10000it_3600s |
| case2869pegase | 16 | 16 | SUCC | 1.098e-05 |  | Solve_Succeeded | 1656 | 1.4551915228366852e-11 | 1391.87 | k1_10000it_3600s |
| case_ACTIVSg2000 | 1 | 1 | MAXITER | 3.349e-06 |  | Solve_Succeeded | 1091 | 1.4551915228366852e-11 | 963.66 | k1_10000it_3600s |
| case_ACTIVSg2000 | 2 | 2 | MAXITER | 3.643e-06 |  | Solve_Succeeded | 441 | 1.4551915228366852e-11 | 454.8 | k1_10000it_3600s |
| case_ACTIVSg2000 | 3 | 3 | MAXITER | 3.378e-06 |  | Maximum_WallTime_Exceeded | 861 | 1.7751254779055370e-04 | 3608.84 | k1_10000it_3600s |
| case_ACTIVSg2000 | 4 | 4 | MAXITER | 3.091e-06 |  | Solve_Succeeded | 419 | 1.4551915228366852e-11 | 310.32 | k1_10000it_3600s |
| case_ACTIVSg2000 | 5 | 5 | MAXITER | 5.000e-06 |  | Solve_Succeeded | 561 | 1.4551915228366852e-11 | 504.21 | k1_10000it_3600s |
| case_ACTIVSg2000 | 6 | 6 | MAXITER | 4.971e-06 |  | Solve_Succeeded | 463 | 1.4551915228366852e-11 | 367.42 | k1_10000it_3600s |
| case_ACTIVSg2000 | 7 | 7 | MAXITER | 1.915e-06 |  | Solve_Succeeded | 880 | 1.4551915228366852e-11 | 777.51 | k1_10000it_3600s |
| case_ACTIVSg2000 | 8 | 8 | SUCC | 2.306e-05 |  | Maximum_WallTime_Exceeded | 610 | 3.0992592387413254e-04 | 3793.54 | k1_10000it_3600s |
| case_ACTIVSg2000 | 9 | 9 | MAXITER | 3.164e-05 |  | Solve_Succeeded | 862 | 1.4551915228366852e-11 | 677.83 | k1_10000it_3600s |
| case_ACTIVSg2000 | 10 | 10 | SUCC | 3.905e-06 |  | Solve_Succeeded | 2332 | 1.4551915228366852e-11 | 1693.01 | k1_10000it_3600s |
| case_ACTIVSg2000 | 11 | 12 | MAXITER | 7.809e-06 |  | Maximum_WallTime_Exceeded | 1450 | 2.6866530808578037e-05 | 3605.16 | k1_10000it_3600s |
| case_ACTIVSg2000 | 12 | 14 | SUCC | 6.787e-05 |  | Solve_Succeeded | 1363 | 1.4551915228366852e-11 | 978.61 | k1_10000it_3600s |
| case_ACTIVSg2000 | 13 | 15 | SUCC | 1.415e-08 |  | Maximum_WallTime_Exceeded | 821 | 1.1005838462274653e-04 | 3607.68 | k1_10000it_3600s |
| case_ACTIVSg2000 | 14 | 16 | MAXITER | 3.535e-05 |  | Solve_Succeeded | 367 | 1.4551915228366852e-11 | 237.39 | k1_10000it_3600s |
| case_ACTIVSg2000 | 15 | 18 | MAXITER | 7.594e-06 |  | Solve_Succeeded | 1275 | 1.4551915228366852e-11 | 973.05 | k1_10000it_3600s |
| case_ACTIVSg2000 | 16 | 19 | SUCC | 1.120e-06 |  | Solve_Succeeded | 505 | 1.4551915228366852e-11 | 510.82 | k1_10000it_3600s |

