# Introduction citation additions

Date: 2026-11-16. Author requested citations for the opening low-precision motivation, Microscaling, systolic execution, and Qwen3-8B. The same four references appear in the Chinese and English introductions, preserving their wording and numerical claims.

| Claim / mention | Citation key | Primary evidence checked | Citation boundary |
| --- | --- | --- | --- |
| Model scaling and low-precision optimization | deepseekv3 | https://arxiv.org/html/2412.19437v2, Introduction and Sec. 3.3 | Model-scale example and FP8 computation/storage for training efficiency |
| Shared-scale Microscaling formats | ocpmx2023 | https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf, Secs. 4–5 | Format definition and shared block scales |
| Systolic dataflow | jouppi2017tpu | https://arxiv.org/pdf/1704.04760, Sec. 2 / Fig. 4, PDF p. 4; bibliographic title/authors/ISCA 2017 checked on paper p. 1 and https://research.google/pubs/in-datacenter-performance-analysis-of-a-tensor-processing-unit/ | Citation attached specifically to “systolic”; does not establish that all tensor cores use fused dot-product units |
| Qwen3-8B workload model | qwen3technicalreport | https://arxiv.org/abs/2505.09388 | Model attribution; this paper's activity extraction and power estimation remain its own methods |

Three existing BibTeX entries reused; only the TPU paper was added. The author's concurrent OCP citation in English and additional DeepSeek-V4.1-Flash citation in Chinese were preserved. Scope is citation insertion, with no changes to measurements, model assumptions, or contribution results.

Validation: citation-only diff verified after removing the four inserted citation commands; all four keys resolve in both generated bibliographies. Both LaTeX builds complete. Existing table edits produce duplicate `tab:vendor_ratios` labels in both manuscripts and unresolved `tab:related_features` references in Chinese; their table-input arrangement is present in the pre-task snapshots and was not changed. English body remains nine pages; Chinese body remains six pages.
