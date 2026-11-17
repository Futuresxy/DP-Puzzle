# Five-stage case-study narrative and overlaid deployment bars

2026-11-18. Temporary Chinese Chapter V only; accepted five-stage numeric results unchanged.

The case study uses alpha=0.327 and beta=1 with a fixed modeled core-pool area and DP-array power ceiling. It explicitly states the fixed peripheral-area assumption and uses maximum measured mode-average DP power to bound deployment. One design and core count serves all requests.

Five sequential precision assumptions retain unchanged shapes and FLOPs: A reference; B routed experts FP4; C main SWA/CSA QK/PV plus Grouped O-down FP8; D shared experts plus Q-up/O-up FP4; E main attention and Grouped O-down FP4. Expert groups include gate/up/down. All other operators retain their original precision. HQE work is counted; FP32 work is recorded separately and excluded from the modeled time. W4A8 routed experts in A map to FP8 throughput.

Batch=1, 11 doubling context lengths from 1K to 1M. Each stage/context pair has equal request probability. Sum each precision's FLOPs divided by its chip peak, average the 55 compute times, then divide baseline mean by candidate mean. This is not a mean of speedups or normalized FLOP shares. Longer contexts contribute more time through their actual work. Full operand supply and utilization are assumed.

Figure `figures/temp/v41_case_panels_overlay.pdf` places gray area-only counts behind blue joint-budget counts. Joint counts are labeled inside the blue bars; differing area counts are labeled beyond the gray endpoint, while equal values appear once. It retains all 18 count values through 15 labels and all 54 heatmap values. The old paired-bar PDF and ternary previews remain available and are not referenced by the revised chapter.

Insights retained: power limits reduce 1:4:8 from 29 to 20 cores and 1:8:16 from 22 to 10 while 1:2:8 retains 32; 1:2:8 has 60% more chip FP4 throughput than 1:4:8. Stage winners A=1:2:4, B/C/D=1:2:8, E=1:2:12. Overall 1:2:8 gives 1.13111299x; 1:2:6 gives 1.10173272x; 1:2:12 gives 0.93309118x; 1:8:16 gives 0.77215503x. The screenshot's six-stage 1.15x score is historical.

Reproduce from paper/:

```sh
PYTHONDONTWRITEBYTECODE=1 MPLCONFIGDIR=/tmp/dp_puzzle_mpl python3 scripts/plot_v41_case_panels.py
make pdf-temp
```

The plot manifest binds source hashes and the new PDF. Review checks independently recompute all 54 scores, compare the scenario table and protect unrequested manuscripts/chapters. The old conclusion still contains six-stage figures and awaits a separate authorized synchronization; this revision does not claim full-manuscript consistency.
