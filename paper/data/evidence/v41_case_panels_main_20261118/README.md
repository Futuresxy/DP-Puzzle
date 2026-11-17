# Official promotion: five-stage case study and concise conclusion

2026-11-18. The author explicitly requested promotion of the current Chapter V and conclusion from `main_temp.tex` into the official `main.tex` manuscript.

The official entry still includes `sections/05_dse.tex` and `sections/06_conclusion.tex`. Their text matches the current review draft exactly, including the author's latest workload paragraph; only figure/table paths change. The single retained result is 1:2:8's 1.13x ideal GEMM compute speedup under matched area and DP-array power budgets, with five migration scenarios and eleven equally weighted context requests. The conclusion is one short paragraph.

`tables/five_stage_migrations.tex` is the shared table body; the temporary-path file is a compatibility include. `figures/v41_case_panels_overlay.pdf` is byte-identical to the accepted review figure: gray/blue overlaid deployment counts and five-stage heatmap. All source model data and scores are unchanged. Old six-stage and triangle figures remain historical artifacts.

Reproduce the official figure and compile:

```sh
PYTHONDONTWRITEBYTECODE=1 MPLCONFIGDIR=/tmp/dp_puzzle_mpl python3 scripts/plot_v41_case_panels.py --official
make pdf
```

`make presentation` now uses the five-stage plotter for the case-study figure. Its other table-generation command is unchanged and was not rerun during this promotion. The plot manifest binds the frozen input CSVs, current plotter and official PDF.

The formal and temporary manuscripts compile without undefined references or overfull boxes. The official PDF has six body pages plus two reference pages; its existing reference-length warning remains. Figure 5 floats to page 6; text and short conclusion are on page 5. Both pages were inspected. Abstract, introduction, prior chapters, English draft and review text are unchanged by this task. Their remaining earlier claims are not implicitly synchronized. `promotion_checks.json` records exact-text and protected-file checks.
