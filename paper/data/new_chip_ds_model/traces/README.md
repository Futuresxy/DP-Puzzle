# Production input-length traces

Each histogram gives the positive integer input length and number of LLM calls at that length. Counts are per call, retaining repeated lengths. A token count is transferred from the source tokenizer to the DeepSeek length axis. The inputs include available conversation history and system context. Replaying the full input assumes cold prefill, even when the source service could serve a shared prefix from cache. Output tokens are excluded.

| ID | Population and capture window | Field and selection |
|---|---|---|
| azure_chat | Microsoft Azure production conversation endpoint, 2024-05-12 00:00–06:00 UTC | First six contiguous hours of the conversation release; all invocations, full ContextTokens |
| agent_calls | FreeInference production coding and assistant agent traffic, final published weekly partition, 2026-08-30 through 2026-09-05 | All requests in the released processed weekly table, full provider-reported prompt_tokens |
| agent_first | First model invocation in each session represented by a step-zero row in the same weekly partition | Exactly the agent_calls rows with step equal to zero |

Azure gives a historical short-context conversation comparison. Its window selects the beginning of the trace for reproducibility and can have time-of-day effects. FreeInference records multiple models, providers and harnesses and covers the full prompt for each call, including follow-up tool steps. The step-zero subset provides a separate first-call sensitivity analysis. Its initial prompts can already include system text or history. The main and first-call populations overlap. Preserve them as separate conditional distributions. The trace supplies observed lengths, not the numerical precision assigned to a GEMM or a measured cold-cache latency.

The machine-readable [trace manifest](trace_manifest.json) records selection, publication URLs, downloaded column fingerprints, derived histogram hashes and coverage. Two agent_calls prompts exceed the model's 1,048,576-token range. Keep them in the source histogram, then report them separately from the eligible population in the scoring step. Short inputs remain at their recorded lengths in the primary score.

## Sources and attribution

- Microsoft Azure public dataset, CC BY. J. Stojkovic, C. Zhang, Í. Goiri, J. Torrellas, and E. Choukse, *DynamoLLM: Designing LLM Inference Clusters for Performance and Energy Efficiency*, HPCA 2025. [Publisher documentation](https://github.com/Azure/AzurePublicDataset/blob/master/AzureLLMInferenceDataset2024.md) · [Paper](https://arxiv.org/abs/2408.00741)
- Harvard MaDSys, FreeInference Agentic Trace, CC BY 4.0. *From Requests to Sessions: A Large-Scale Characterization of Human-Driven Agentic Workloads*. The original release covers 16 weeks, May 17–September 5, 2026. The analysis here takes the latest complete weekly partition. The derived files aggregate its published request table into counts. [Dataset at pinned revision](https://huggingface.co/datasets/harvardMadsys/freeinference_agentic_trace/tree/bb26cf72c9c20f2b05f765d88548156a74d3c253) · [Authors' documentation](https://github.com/HarvardMadSys/freeinference_agentic_trace) · [Paper](https://data.freeinference.org/pdf/paper/from-requests-to-sessions)

## Reproduction

Run with Python 3.11+, curl, requests, and pyarrow from this directory.

```sh
python build_histograms.py azure
python build_histograms.py agent
```

The Azure reader consumes the header and time-selected CSV prefix, verifies its exact source bytes, and stops at the first request on or after the cutoff. The FreeInference reader uses HTTP byte ranges on the pinned Parquet release to retrieve the footer and column data for all row groups. It checks the projected rows' SHA-256, with records canonically serialized as decimal step, comma, decimal prompt_tokens, newline. Either reader accepts a previously downloaded publisher file via `--local`. The full Parquet path additionally validates the source file hash. Both verify histogram bytes against the manifest.
