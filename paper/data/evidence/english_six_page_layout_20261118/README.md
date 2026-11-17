# English manuscript: six body pages plus one reference page

Author-requested editorial/layout revision, 2026-11-18. The reviewed base is
the author's current English working copy. Chinese manuscripts, shared tables,
figure assets, bibliography metadata and experimental data were not edited.

The final revision retains the chapter structure, four numbered equations,
Lane/Group/DP arithmetic details, all nine configurations, and all comparison
works. Only repetitive explanations and verbose wording were shortened;
the initial more aggressive compression was discarded at the author's request.
The abstract and contribution summary now use the official five-scenario,
1.13x result from `sections/05_dse.tex` instead of the superseded six-scenario
1.15x/1.147x result. No experiment was rerun or changed.

Layout changes queue existing floats earlier without changing font sizes,
figure scales or IEEE page geometry. Table I remains on page 1; Table II moves
to page 2. Table IV and the area/power plot occupy page 5, within Evaluation;
the case study begins on page 6. Figure 3's caption is shortened while retaining
budget values, panel meanings, aggregation scope and optimum markers. The last
page's right column has about 92 pt (roughly eight text lines) available for
one or two short paragraphs of subsequent revision.

Validation: `latexmk -xelatex -interaction=nonstopmode -halt-on-error
-file-line-error dp_puzzle.tex`. The resulting `build/dp_puzzle.pdf` has six
body pages and one references-only page, 39 references, no unresolved references,
no overfull boxes, and no missing glyphs. Independent builds used
`-outdir=build/layout-review` to avoid concurrent editor-build interference.
The final standard build also passed. Page placement and visual readability
were inspected. Machine-readable checks and output hashes are in `checks.json`.

The [DAC 2027 submission page](https://dac.com/2027/program/research-manuscript-submissions)
was consulted for its six-page body, one references-only page, and IEEE
double-column 9/10 pt requirements. The manuscript retains 10 pt body type.
This layout check is not a final scientific or submission-approval audit.
