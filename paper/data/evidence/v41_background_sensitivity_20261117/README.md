# Background-operator precision-migration sensitivity

2026-11-17. Analysis only; manuscript, figure and accepted five-stage data unchanged.

Run `python3 data/evidence/v41_background_sensitivity_20261117/analyze.py` from paper/. Reads the existing five-stage operator ledger, cases, hardware and gains. Checks source hashes, reproduces all current scores, and conserves modeled FLOPs during migration. Results remain ideal compute estimates with alpha=0.327, beta=1, batch=1, 11 contexts and equal scenario/context request weights.

Three variants:

- `current`: existing five-stage migration path; background precision unchanged.
- `listed_extra`: also migrate Q-down, SWA-KV projection, Index Q projection, and the BF16 portion of Global-KV projection. BF16 becomes FP8 at C and FP4 at E; original FP8 becomes FP4 at D. Earlier changes persist.
- `all_extra`: additionally migrate Engram projection (FP8), Index K projection and Index head weights (BF16), following the same timing. FP32 remains separately excluded; native FP4 indexing remains included.

Both baseline and candidates use the same hypothetical migrated workload in each comparison. This does not establish quantization accuracy or feasibility.

The four listed extra operators represent 2.45% of modeled FLOPs at 1K and 1.71% at 1M. All retained BF16/FP8 background operators together represent 4.81% of the summed modeled FLOPs across 11 contexts, but 16.91% of the modeled 1:2:8 computation time in E (ratio of summed times). FLOP shares alone therefore understate their time contribution after major GEMMs move to FP4.

All retains 1:2:8 as winner in every variant: current 1.13111299x, listed_extra 1.13642985x, all_extra 1.14490344x. However, E changes from 1:2:12 to 1:2:16 in either expanded migration. For fixed 1:2:8 hardware, listed_extra reduces average time by 0.99% and E time by 5.01%; all_extra reduces average time by 2.51% and E time by 12.71%. These time reductions differ from the reported relative speedup, whose baseline also benefits from migration.

Conclusion: focusing on major families keeps the aggregate choice unchanged in these checks, but omitting migration is a scenario boundary, not proof of negligible effect or numerical sensitivity. Terminal-stage design selection depends on the retained high-precision work.
