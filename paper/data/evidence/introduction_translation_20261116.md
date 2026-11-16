# English introduction translation

- Date: 2026-11-16.
- Authorization: translate the current Chinese Introduction into the corresponding section of `dp_puzzle.tex` using academic writing conventions.
- Source: `sections/01_introduction.tex` at task start, SHA-256 `5d63f3a0e68bd8e1913c61e21e0ce903e1c32a7e35a61e57c8973804bef28ef9`; inline precision-support table from `tables/related_features.tex`.
- Destination: the `01_introduction.tex` review-pair block in `dp_puzzle.tex` only. The author's English abstract and all text outside this block remain unchanged.
- Guidance: project `.skill/academic-humanizer/SKILL.md` and the available `scientific-writing` skill. No standalone academic-translation skill was found in the available catalogs or local skill directories.
- Editorial choices: retain the three background paragraphs and three contributions; use dot-product unit, peak throughput ratio, area efficiency, energy efficiency, and precision migration consistently. Render the inference estimate as estimated GEMM compute latency, consistent with the stated operation-count/peak-throughput model and the author's compute-only requirement.
- Evidence: preserve all nine ratio candidates; 12 nm / 1 GHz; 33.60%, 49.70%, 27.27%; 11 contexts from 1K to 1M; six scenarios; 30%; 1.147x and 1.103x. No additional measurements or external claims were introduced.
- Checks: Chinese/English introduction headings, labels, reference targets, citation keys, equations, figure references, and table structure/entries match after translating the table caption. All source files and English text outside the introduction are byte-preserved. Selected numerical claims were checked explicitly.
- Build: `make -f Makefile.en pdf` passed; no undefined references, duplicate labels, or overfull boxes. Final English PDF pages 1–2 visually inspected. The full English manuscript currently contains nine body pages and one reference page, so the existing six-page-limit warning remains; other English sections are outside this translation scope.
- Global bilingual check: not used as an acceptance check for untranslated chapters. The existing helper's signature functions were applied only to this introduction, with its extensionless table input expanded explicitly and the translated caption normalized.
