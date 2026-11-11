Screening census, read up to the 16th admitted outage of each list (rho = 1e8, scaled ||r||_inf < 1e-4, <= 200 iterations, any status; status codes of MadNLP).

| network | order | screened (to the 16th admission) | admitted | admitted by status | rejected by status | bridges screened (admitted) | screen time (s, sum per outage) | base OPF | screened in the record | admitted in the record |
|---|---|---|---|---|---|---|---|---|---|---|
| case500_goc | A | 19 | 16 | SUCC 16 | SUCC 3 | 0 (0) | 50.3 | LOCALLY_SOLVED | 75 | 64 |
| case500_goc | B | 23 | 16 | SUCC 16 | SUCC 7 | 7 (1) | 64.1 | LOCALLY_SOLVED | 23 | 16 |
| case588_sdet | A | 19 | 16 | SUCC 16 | SUCC 2, ACCEPTABLE 1 | 2 (0) | 65.0 | LOCALLY_SOLVED | 74 | 64 |
| case588_sdet | B | 18 | 16 | SUCC 16 | SUCC 2 | 3 (1) | 66.8 | LOCALLY_SOLVED | 300 | 226 |
| case793_goc | A | 31 | 16 | SUCC 16 | SUCC 12, ACCEPTABLE 3 | 16 (4) | 102.1 | LOCALLY_SOLVED | 110 | 64 |
| case793_goc | B | 24 | 16 | SUCC 15, ACCEPTABLE 1 | SUCC 7, MAXITER 1 | 7 (1) | 83.9 | LOCALLY_SOLVED | 300 | 231 |

Bridges screened up to the 16th admission (islanded side = the side without the reference bus):

| network | order | branch | status | scaled ‖r‖∞ | admitted | islanded buses | load (MW) | units | Pmax (MW) |
|---|---|---|---|---|---|---|---|---|---|
| case500_goc | B | 577 | SUCC | 2.64e-01 | no | 1 | 0.0 | 1 | 217.333 |
| case500_goc | B | 631 | SUCC | 9.64e-09 | yes | 1 | 0.0 | 0 | 0.0 |
| case500_goc | B | 662 | SUCC | 1.19e-01 | no | 1 | 0.0 | 1 | 61.25 |
| case500_goc | B | 128 | SUCC | 2.30e-01 | no | 1 | 46.07 | 0 | 0.0 |
| case500_goc | B | 592 | SUCC | 3.19e-01 | no | 1 | 0.0 | 1 | 178.467 |
| case500_goc | B | 686 | SUCC | 3.78e-01 | no | 1 | 0.0 | 1 | 225.0 |
| case500_goc | B | 471 | SUCC | 2.50e-02 | no | 2 | 0.091 | 1 | 25.0 |
| case588_sdet | A | 1 | SUCC | 4.49e-01 | no | 1 | 89.79 | 0 | 0.0 |
| case588_sdet | A | 14 | ACCEPTABLE | 1.97e-01 | no | 1 | 0.0 | 0 | 0.0 |
| case588_sdet | B | 572 | SUCC | 6.25e-03 | no | 1 | 0.43 | 0 | 0.0 |
| case588_sdet | B | 657 | SUCC | 5.08e-05 | yes | 2 | 52.85 | 0 | 0.0 |
| case588_sdet | B | 468 | SUCC | 1.80e-01 | no | 1 | 35.95 | 0 | 0.0 |
| case793_goc | A | 5 | SUCC | 1.33e-04 | no | 1 | 2.054 | 1 | 301.053 |
| case793_goc | A | 6 | SUCC | 1.27e-04 | no | 5 | 17.902 | 1 | 301.053 |
| case793_goc | A | 9 | SUCC | 3.88e-04 | no | 2 | 0.503 | 0 | 0.0 |
| case793_goc | A | 10 | SUCC | 3.93e-03 | no | 2 | 14.656 | 0 | 0.0 |
| case793_goc | A | 11 | SUCC | 3.03e-04 | no | 3 | 1.859 | 1 | 265.263 |
| case793_goc | A | 14 | SUCC | 6.53e-09 | yes | 1 | 0.0 | 0 | 0.0 |
| case793_goc | A | 15 | SUCC | 6.56e-05 | yes | 6 | 37.888 | 1 | 83.388 |
| case793_goc | A | 16 | SUCC | 6.53e-09 | yes | 1 | 0.0 | 0 | 0.0 |
| case793_goc | A | 17 | SUCC | 4.92e-05 | yes | 4 | 37.888 | 1 | 83.388 |
| case793_goc | A | 18 | SUCC | 1.14e-04 | no | 2 | 21.404 | 0 | 0.0 |
| case793_goc | A | 19 | SUCC | 1.58e-04 | no | 3 | 29.507 | 0 | 0.0 |
| case793_goc | A | 25 | SUCC | 5.27e-04 | no | 2 | 5.135 | 0 | 0.0 |
| case793_goc | A | 26 | SUCC | 2.05e-04 | no | 4 | 4.354 | 0 | 0.0 |
| case793_goc | A | 27 | SUCC | 7.26e-04 | no | 5 | 21.691 | 0 | 0.0 |
| case793_goc | A | 28 | SUCC | 3.80e-04 | no | 3 | 7.364 | 0 | 0.0 |
| case793_goc | A | 29 | SUCC | 1.00e-04 | no | 9 | 37.888 | 2 | 219.426 |
| case793_goc | B | 711 | SUCC | 1.87e-02 | no | 1 | 3.738 | 0 | 0.0 |
| case793_goc | B | 882 | SUCC | 6.53e-09 | yes | 1 | 0.0 | 0 | 0.0 |
| case793_goc | B | 49 | SUCC | 3.58e-02 | no | 1 | 7.169 | 0 | 0.0 |
| case793_goc | B | 499 | SUCC | 2.37e-01 | no | 1 | 47.312 | 0 | 0.0 |
| case793_goc | B | 468 | SUCC | 3.04e-01 | no | 1 | 60.757 | 0 | 0.0 |
| case793_goc | B | 292 | SUCC | 3.91e-03 | no | 2 | 32.476 | 1 | 126.316 |
| case793_goc | B | 823 | MAXITER | 4.87e-01 | no | 1 | 0.0 | 1 | 422.316 |

