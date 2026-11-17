# Matched-budget case study

2026-11-17. This batch supports Chapter V of the Chinese review draft (`main_temp.tex`).

The case is a fixed-budget replacement: alpha=0.327 and beta=1, with 36 baseline cores and 256 DPs/core. Each of the nine candidates receives the same AI-core area budget and the same DP-array power ceiling. Beta=1 expresses no additional power allowance; it is not an inferred physical constant or a claim of universal optimality. The previous beta=1.2 results remain in `../v41_case_study_20261117/`; there 1:2:12 wins the overall mean-time objective. The matched-budget case was selected during manuscript revision for its simple comparison contract.

Workload settings are unchanged: six precision mappings, batch-one full-CED cold prefill, 11 log-spaced contexts from 1K to 1M, full utilization and ideal operand supply. Only the power ceiling changes. All 66 workload records are identical to the beta=1.2 batch. Background formats, including native FP4 indexing, remain unchanged; FP32 work is separately recorded. The shortened manuscript gives the six mappings in `tables/temp/case_migrations.tex` instead of changing the evaluated scenarios.

## Reproduce

From `paper/`:

```sh
make case-study
make pdf-temp
```

The script defaults to `data/inputs/v41_case_study_equal_budget.json`, this evidence directory and `figures/temp/v41_case_study_equal_budget.pdf`. Explicit `--config`, `--output` and `--figure` arguments retain the earlier case's replay path. No formal manuscript or formal figure is modified.

## Results

- Scenario A selects 1:2:4; B–E select 1:2:8; F selects 1:2:12.
- Across A–F, 1:2:8 yields 1.14731841x, versus 0.95282844x for 1:2:12.
- Omitting F, 1:2:8 remains best at 1.10344747x.
- 1:2:8 and 1:2:12 deploy 32 and 24 cores. The latter offers 50% more FP4 throughput per DP, but only 12.50% more chip-level FP4 throughput; BF16 and FP8 chip throughput each fall by 25%.

The score is the ratio of mean compute times over equal-probability requests, not an arithmetic mean of speedups. The figure reports exact winners and rounds labels to two decimals. The power model scales measured maximum-mode DP power by deployed DP count; it is not an end-to-end inference or whole-chip TDP measurement.

`operators.csv`, `cases.csv`, `hardware.csv`, `evaluations.csv` and `gains.csv` contain operator work, precision shares, physical deployments, per-request times and figure scores. `manifest.json` records input/output hashes, hardware source provenance and accounting checks. Checks cover FLOP conservation, both budgets, direct time recomputation, baseline identity and scenario aggregation. The Chinese draft compiles without undefined references or overfull boxes; formal/English manuscripts and the other draft chapters were kept unchanged. Figure numbering remains automatic.
