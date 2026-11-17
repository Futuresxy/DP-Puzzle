# Joint-budget H/Q/E regions and 25 DeepSeek workload points

2026-11-17. Standalone previews only; no manuscript, accepted figure or scoring data is changed.

## Scope

Uses the current complete BF16/FP8/FP4 GEMM ledger, with retained background operators and FP32 excluded. This is **not** the proposed seven-family-only subset; Q-down still retains FP8 and the original five-stage mapping is unchanged. Contexts shown: 1K, 8K, 64K, 256K, 1M, across stages A–E (25 points). No aggregate point or resampled aggregate score is introduced.

Budgets and capacities come directly from `v41_five_stage_20261117/hardware.csv`: alpha=0.327, beta=1, 36 baseline cores, 256 DPs/core and 1 GHz. Both area and DP-array power constraints apply. Only modeled, fully utilized GEMM compute time is compared.

## Construction and validation

For normalized FLOP shares x, choose the candidate minimizing `sum_p x_p/C_jp`. Each pairwise cost inequality is a half-plane. `scripts/simplex.py` intersects these half-planes to obtain exact polygonal regions; a coarse raster does not determine the borders. A common coefficient scaling preserves these inequalities while avoiding absolute clipping tolerance problems.

Checks: source CSV hashes match their frozen manifest; all 25 point winners reproduce the existing per-request evaluations; region fractions sum to one; each positive-area region centroid selects the associated candidate; 15,913 strict-interior points from a 16,471-point simplex grid agree with direct cost evaluation. Fonts are embedded TrueType. Overview and detail PNG previews were visually reviewed. Final adoption/layout review remains with the author.

Seven candidates have positive-area winner regions. 1:6:12 is strictly dominated by 1:4:8. 1:8:16 has the same Q/E capacities as 1:4:8 and less H capacity, so can only tie on part of H=0 and never wins a positive-area region. Region fractions describe geometric parameter-space coverage, not probability, hardware area or empirical workload frequency.

## Outputs and reading

- `figures/temp/v41_ternary_regions.pdf`: regions only, all nine candidates listed.
- `figures/temp/v41_ternary_points.pdf`: full triangle with 25 points. Color denotes context, shape denotes stage, arrows connect A to E at fixed context.
- `figures/temp/v41_ternary_detail.pdf`: same triangle plus C/D/E edge details. Details plot actual E and H percentages with independently expanded axes; Q=100%-H-E. Points are never jittered. Within each detail, lines connect contexts in increasing order (1K,8K,64K,256K,1M), which need not move monotonically in E share.
- `points.csv`: exact fractions, Cartesian positions, point winner and speedup over same-workload 1:2:4.
- `regions.json` and `region_summary.csv`: exact vertices, capacities and geometric fractions.

C–E have H shares of only 0.0277%–0.0378%, explaining why they visually collapse onto the Q–E edge. A selects 1:2:4 for all five displayed contexts. B selects 1:2:6 for 1K–256K and 1:2:8 at 1M. C selects 1:4:8 for 1K–256K and 1:2:8 at 1M. D selects 1:2:8 throughout; E selects 1:2:12 throughout. These are individual-request optima, not the aggregate fixed-chip decision.

Reproduce from paper/:

```sh
PYTHONDONTWRITEBYTECODE=1 MPLCONFIGDIR=/tmp/dp_puzzle_mpl python3 scripts/plot_v41_ternary_preview.py
```

Inputs and vector outputs are SHA-256 bound in `manifest.json`. PNG previews are generated under `/tmp` and not versioned. The model and source attribution are inherited from the referenced five-stage evidence batch; no new model accuracy, EDA or end-to-end inference measurements are performed.
