# DeepSeek-V4.1-Flash fixed-budget case study

2026-11-17. Chinese review draft, Chapter V in `paper/main_temp.tex`.

This batch uses alpha=0.327, beta=1.2, 36 baseline cores, 256 DPs/core, and the nine full-precision DP profiles. It evaluates batch-one full-CED cold prefill at 11 log-spaced contexts from 1K to 1M. Six configurable precision mappings preserve operator shapes and arithmetic work. The primary score is the ratio of baseline and candidate mean HQE GEMM compute times, with equal request probabilities across contexts and scenarios. All candidates use full utilization and ideal operand supply. This is an analytical compute estimate, not an end-to-end latency measurement.

## Reproduce

From `paper/`:

```sh
python3 scripts/v41_case_study.py --config data/inputs/v41_case_study.json --output data/evidence/v41_case_study_20261117 --figure figures/temp/v41_case_study.pdf
```

This historical beta=1.2 batch is retained for comparison. The current `make case-study` target uses the separate beta=1 batch. The command above reads `data/inputs/v41_case_study.json`, calls `scripts/v41_case_study.py`, and updates this batch plus `figures/temp/v41_case_study.pdf`. It does not run the older portfolio entry point or alter formal figures. Scenario precision mappings can be changed independently of the operator formulas. The scope, full utilization, and equal-weight scoring policy are checked explicitly.

## Results and provenance

- `operators.csv`: per-layer/operator analytical ledger, including dimensions, repeated groups, valid position-pair counts, original operand formats and FLOPs.
- `cases.csv`: 66 scenario/context cases, HQE FLOPs and shares; FP32 work recorded separately.
- `hardware.csv`: nine deployments, actual modeled area, DP-pool power and precision-specific chip peak throughput.
- `evaluations.csv`: 594 request/design compute-time estimates and precision contributions.
- `gains.csv`: 63 figure cells (nine designs, A–F plus All), exact mean-time ratios and worst baseline-relative time increase.
- `manifest.json`: model and hardware input hashes, hardware run provenance, output hashes, parameters, accounting checks and interpretation.

For the All score, 1:2:12 yields 1.15133436x and 1:2:8 yields 1.14731841x. The latter takes 0.350029% more mean compute time but uses 17.253765% less maximum-mode DP-pool power. Their deployments are 29 and 32 cores, respectively. Figure labels round to two decimal places; outlines use unrounded values.

The native reference uses W4A8 routed experts mapped to FP8 throughput, and FP4 indexing; scenario B switches the routed compute to W4A4. C–F are future precision-allocation hypotheses, not new model-quality measurements. Three measured DP modes proxy the three compute families. Power is workload-driven DP power scaled by physical deployment, not measured whole-chip TDP.

Validation: 66 workload cases match the prior frozen audit; FLOP conservation, area/power feasibility, direct time calculation, baseline identity and aggregate-score consistency pass. The existing hardware-cost and migration suites pass 8 and 6 tests. The figure is vector PDF with no embedded image objects. The Chinese draft compiles without undefined references or overfull boxes. Existing other chapters retain their earlier content; abstract/introduction/conclusion claims still need a separate authorized synchronization when this case study is promoted.

The stored model configuration provenance and the analytical module's revision constant differ; the exact files used are hashed in the manifest. No source version was silently replaced. This batch adds no RTL, EDA or model-inference measurements.
