# Prefill context-range sensitivity: 1K–256K versus 1K–1M

Date: 2026-11-18. Analytical rerun only; no manuscript, figure in the manuscript,
or original experiment data was overwritten.

## Fixed assumptions

DeepSeek-V4.1-Flash, cold-start prefill only, batch=1, alpha=0.327, beta=1,
36 baseline cores and 256 DPs/core. Five cumulative precision migrations
A–E are unchanged. Other operators retain their original precision.
The new context set is 1K, 2K, 4K, 8K, 16K, 32K, 64K, 128K, 256K
(K=1024), giving 45 workloads and 405 design evaluations.
Each workload receives equal request weight. Scores divide baseline mean
compute time by candidate mean compute time, rather than averaging speedups.
No output-token length or decode work is included.

## Scenario winners

| Scenario | 1K–1M best ratio | Speedup | 1K–256K best ratio | Speedup |
|---|---|---:|---|---:|
| A | 1:2:4 | 1.000000 | 1:2:4 | 1.000000 |
| B | 1:2:8 | 1.081264 | 1:2:6 | 1.046565 |
| C | 1:2:8 | 1.127895 | 1:4:8 | 1.110033 |
| D | 1:2:8 | 1.358323 | 1:2:8 | 1.313832 |
| E | 1:2:12 | 1.688114 | 1:2:12 | 1.645431 |
| All | 1:2:8 | 1.131113 | 1:2:8 | 1.086573 |

The aggregate winner remains 1:2:8, with speedup decreasing from 1.131113x to
1.086573x (1.13x to 1.09x when displayed to two decimals). The runner-up
1:2:6 achieves 1.074807x; the speedup ratio between these two is only about
1.011x, so the shorter-range advantage is smaller. Aggressive 1:2:12 and
1:8:16 configurations achieve 0.880178x and 0.746868x overall.

Shorter contexts reduce the FP4 share of the aggregated useful GEMM work
from 63.21% to 56.74%, while FP8 rises from 31.39% to 36.92%. These are
shares of summed FLOPs, not arithmetic averages of per-request percentages.
Scenario B therefore favors the denser 1:2:6 slightly; in C, with attention
and Grouped O-down at FP8, 1:4:8 becomes the best choice. The broad conclusion
that moderate expansion balances deployment density and mixed-precision
demand remains valid for this case; individual scenario winners are not
invariant to the context distribution.

## Verification and reproduction

All 405 freshly calculated times and precision components match the original
five-stage evaluations restricted to contexts <=256K (relative tolerance 1e-12).
The hardware deployment CSV is byte-identical to the original. The generator
checks FLOP conservation, both budgets, direct latency calculation, baseline
identity and aggregation consistency. Inputs and generated outputs are bound
by `manifest.json`; `review_checks.json` binds the comparative summaries.

From `paper/`:

```sh
python scripts/v41_case_study.py \
  --config data/evidence/v41_context256k_20261118/config.json \
  --output data/evidence/v41_context256k_20261118 \
  --figure data/evidence/v41_context256k_20261118/heatmap.pdf
```

These are ideal GEMM compute estimates at full utilization and sufficient
operand supply. The existing model/config provenance qualification remains
in the generator manifest; this comparison changes only the context set.
