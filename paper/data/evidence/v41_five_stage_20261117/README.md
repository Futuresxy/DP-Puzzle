# Five-stage precision-migration case study

2026-11-17. Chinese review draft, Chapter V in `paper/main_temp.tex`.

This revision follows the requested single migration path. Current A/B/C/D/E correspond to previous A/B/D/E/F. The previous C branch (linear FP4 while attention remains BF16) is omitted. Every subsequent stage retains all earlier precision changes:

1. A: reference mapping; routed W4A8 uses FP8 compute capacity.
2. B: routed experts switch to FP4 compute.
3. C: main SWA/CSA QK/PV and Grouped O-down switch from BF16 to FP8.
4. D: shared experts and Q-up/O-up switch from FP8 to FP4.
5. E: main attention and Grouped O-down switch from FP8 to FP4.

Indexer, Q-down, KV projections and other background operators retain their original formats and remain counted. FP32 work is separately recorded. The workload model is the same full-CED cold prefill ledger as previous batches; operator shapes and total work are unchanged.

## Budget and scoring

Alpha=0.327, beta=1; 36 baseline cores, 256 DPs/core, 1 GHz, II=1. The area budget is the modeled AI-core pool; the power ceiling covers DP arrays and uses the maximum measured mode-average DP power. One physical count per design is retained across all requests and modes.

Batch=1, 11 log-spaced contexts from 1K to 1M. A–E cells use ratios of mean compute times over 11 contexts. All uses the ratio of baseline and candidate mean times over all 55 scenario/context combinations. Each request has equal probability. Service time sums per-precision FLOPs divided by the deployed chip's respective peak throughput, under full utilization and ideal operand supply. This is a compute estimate, not a model-accuracy or end-to-end inference result.

## Results

- A selects 1:2:4; B/C/D select 1:2:8; E selects 1:2:12.
- All: 1:2:8 = 1.13111299x, 1:2:6 = 1.10173272x, 1:2:12 = 0.93309118x, 1:8:16 = 0.77215503x.
- The five-stage score supersedes the six-stage 1.14731841x value for this draft only. Historical six-stage and beta=1.2 data remain unchanged.
- 1:2:8 deploys 32 cores versus 20 for 1:4:8, providing 60% higher chip FP4 peak despite equal per-DP FP4 throughput.

## Reproduce

From `paper/`:

```sh
make case-study
make pdf-temp
```

Configuration: `data/inputs/v41_five_stage.json`. Script: `scripts/v41_case_study.py`. Figure: `figures/temp/v41_five_stage.pdf`. The scenario table is `tables/temp/five_stage_migrations.tex`; its contents have been checked against the configuration. Historical batches can be reproduced using explicit `--config`, `--output` and `--figure` arguments.

`operators.csv`, `cases.csv`, `hardware.csv`, `evaluations.csv` and `gains.csv` retain the operator ledger, 55 precision workloads, nine deployments, 495 per-request/design estimates and 54 figure cells. The manifest binds inputs, hardware run provenance and outputs by SHA-256. The transition checks verify that each stage reduces at least one compute precision without increasing any, and that every retained case exactly matches its previous scenario's work. Budget feasibility, FLOP conservation, direct time calculation, baseline identity and aggregate consistency are checked by the generator.

Only Chapter V of the review draft is edited. Formal/English manuscripts and all other draft chapters retain their earlier wording. Their six-stage claims require separate synchronization when the new chapter is accepted. The current source revision constant/config provenance discrepancy is retained explicitly in the manifest; no model version was silently updated.
