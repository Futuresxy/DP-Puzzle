# DP cost to fixed-budget chip capacity

2026-11-17. Current Chinese review draft, Chapter V in `paper/main_temp.tex`.

This batch is independent of any model workload. It loads the nine full-precision DP area/power profiles, calibrates the per-core peripheral area from the baseline fraction alpha, sizes each physical core pool under area and maximum-mode DP power ceilings, and computes absolute precision-specific peaks. The area budget covers the modeled AI-core pool; power covers DP arrays.

Settings: alpha=0.327, beta=1, 36 baseline cores and 256 DPs/core. All profiles operate at 1 GHz with II=1. The resulting area budget is 455.59 mm² and the DP-array power ceiling is 147.47 W. A mode peak counts each MAC as 2 FLOP. One physical core count is shared across modes, whose peaks are mutually exclusive.

## Reproduce

From `paper/`:

```sh
make deployment-model
make pdf-temp
```

The independent config is `data/inputs/deployment_capacity.json`. The generator is `scripts/build_deployment_capacity.py`, reusing `scripts/hardware_cost.py`. It writes `deployment_capacity.csv`, `manifest.json` and the English review-draft table `tables/temp/deployment_capacity.tex`.

The table reports area-only and power-only core limits, joint core count, and BF16/MXFP8 E4M3/MXFP4 E2M1 chip peaks. CSV retains full-precision values, total installed modeled area, DP-array power, frequency and II; the manuscript table uses two decimal places.

## Findings

- 1:8:16 permits 22 cores by area and 10 under the joint budget. Its FP8/FP4 peaks equal those of 20-core 1:4:8, while its BF16 peak is half as large.
- 1:2:8 deploys 32 cores and reaches 2097.15 TFLOP/s in FP4, 60% above 20-core 1:4:8 despite identical single-DP FP4 parallelism.

These findings concern deployment and peak throughput, without a workload-specific ranking. No GEMM latency, inference score or precision-migration assumption is used. Earlier DeepSeek operators, configurations, scores and figures remain in their historical batches for later workload-model discussion. In those ledgers the indexer was included as fixed background work; the old migration table listed only the operator families whose formats changed.

Checks: eight existing hardware-cost tests pass; nine deployments and 27 precision peaks match the preceding equal-budget hardware data; both budgets and direct peak formulas are checked in the generator. Input/output hashes and original hardware provenance are in `manifest.json`. The draft compiles without undefined references or overfull boxes. Formal and English manuscripts and non-Chapter-V draft content are unchanged. Their prior workload claims are outside this edit's scope.
