# Deployment and precision-migration case study: paired panels

2026-11-17. Temporary Chinese Chapter V only (`main_temp.tex`).

The single-column vector figure `figures/temp/v41_case_panels.pdf` replaces the heatmap-only figure in this draft. Panel (a) shows paired area-only and joint area/power core counts, with both counts labeled. Panel (b) uses the same nine rows and the existing five-stage A–E plus All scores. Solid outlines select the highest unrounded score in each column; displayed values are rounded to two decimals.

Source: `data/evidence/v41_five_stage_20261117/{hardware,gains}.csv`. The plotting script verifies both files against their source manifest. No model, budget, migration scenario, request weighting or result has changed. Alpha=0.327, beta=1; batch=1 and 11 contexts from 1K through 1M. The power ceiling applies to DP arrays. Heatmap values model fully utilized GEMM compute time, not end-to-end inference latency.

The revised text connects the two panels: 1:2:8 retains 32 cores; 1:4:8 drops from 29 to 20 and 1:8:16 from 22 to 10 after applying the power cap. The former has 60% more chip FP4 throughput than 1:4:8. Stage winners remain A=1:2:4, B/C/D=1:2:8, E=1:2:12; All selects 1:2:8 with a 13.11% modeled gain.

Replot existing data:

```sh
python3 scripts/plot_v41_case_panels.py
make pdf-temp
```

`make case-study` regenerates the underlying case study and then the paired panels. The previous heatmap-only figure and its source batch remain available. `manifest.json` binds the source data, plotting script and PDF; `review_checks.json` records numeric, scope, compile and visual checks. Formal and English manuscripts are unchanged by this revision.
