# Five context-aggregated workload points

2026-11-17. Standalone preview, no changes to manuscript or existing results.

`figures/temp/v41_ternary_aggregate.pdf` replaces the visual clutter of 25 displayed context/scenario points with one point per migration stage A–E. Each point sums the three precision FLOP counts across all **11** original contexts from 1K to 1M, then normalizes. Contexts have equal request weight; longer requests contribute more FLOPs. This is not an arithmetic mean of per-request fractions and not an aggregation of only the five displayed lengths from the prior figure.

For any fixed candidate j, mean time is sum_p(mean_i F_ip / C_jp). Its minimizer therefore equals that at the normalized aggregate workload point. All 45 stage/design speedups were checked against the accepted five-stage `gains.csv`, with no change. Stage optima remain A=1:2:4, B/C/D=1:2:8, E=1:2:12. No cross-stage All point or new overall score is plotted.

This retains the current complete HQE ledger, including fixed-precision background work, and excludes separately recorded FP32. The proposed seven-family subset has not been substituted. Alpha=0.327, beta=1; capacities and analytic advantage regions are unchanged. Region polygons use exact pairwise linear cost inequalities. No jitter is applied. C–E have H=0.03050% and stay close to the Q–E edge, but reducing the display to three distinct edge points makes the sequence readable.

Source hashes, exact aggregate shares and score consistency are recorded in `manifest.json` and `points.csv`. The PDF/PNG preview was visually inspected. Figures remain exploratory until author review.

Reproduce from paper/:

```sh
PYTHONDONTWRITEBYTECODE=1 MPLCONFIGDIR=/tmp/dp_puzzle_mpl python3 scripts/plot_v41_ternary_aggregate.py
```

The PNG preview is written to `/tmp/v41_ternary_aggregate.png`; the vector PDF, script and compact evidence are retained. No new EDA, end-to-end inference or quantization-quality measurement is performed.
