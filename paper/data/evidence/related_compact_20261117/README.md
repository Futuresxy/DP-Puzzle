# Single-column Table IV and concise case-study draft

2026-11-17. Temporary Chinese manuscript only.

Table IV is transposed from eight design columns to eight design rows. Process node, voltage and frequency share a compact condition column; precision-specific area and energy efficiencies are adjacent. Accumulation formats remain under design names. The table uses the normal footnote font, without scaling a wide table into one column. Original process nodes, Ten-Four Q8/Q16 pairs, and TransDot estimated-area markers are preserved.

The prior temporary table was a stale snapshot. This layout instead reads current implementation conditions from `tables/related_ppa_native.tex` and the latest efficiency records from `data/evidence/related_native_dc_area_20261117/efficiencies.csv`. No shared/formal table is edited. The temporary comparison paragraph is synchronized to 0:2:4 area efficiencies of 6.56/13.11 TFLOP/s/mm² and energy efficiencies of 5.23/13.93 TFLOP/s/W. All 36 recorded efficiency values are retained, with two-decimal display values in `displayed_efficiencies.csv`.

Reproduce from `paper/`:

```sh
make related-compact
make pdf-temp
```

The same draft revision condenses Chapter V's prose by approximately half, retaining the budget model, five-stage precision table, full-utilization compute-time estimate, uniform 55-case aggregation and two findings. The 13.11% overall modeled gain is unchanged. No new experiment is performed. Other chapters, except the immediate Table IV comparison paragraph, are unchanged; formal and English manuscripts remain untouched.

The compiled temporary Table IV occupies one column on page 5. Compilation has no undefined references or overfull boxes. Pages 5–6 were visually checked. `manifest.json` records source and table hashes; `review_checks.json` records scope and compression checks.
