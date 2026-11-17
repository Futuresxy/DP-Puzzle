---
name: dp-puzzle-en-writing
description: Evidence-based, minimal English language and terminology review for DP-Puzzle and related floating-point dot-product architecture papers. Supports report-only review; preserves technical claims, values, notation, references, and author voice.
---

# DP-Puzzle English writing review

Use this skill to diagnose or minimally repair an existing English architecture/IC manuscript.
It is not a translation task, an invitation to rewrite fluent prose, or permission to invent results.

## Read the right reference

| Task | Read first |
| --- | --- |
| Understand the corpus, statistics and limits | [corpus-analysis.md](references/corpus-analysis.md) |
| Grammar, syntax, paragraph flow, tense, units | [style-rules.md](references/style-rules.md) |
| Format names, arithmetic, hardware and workload vocabulary | [terminology.md](references/terminology.md) |
| Diagnose defensive phrases, calques or stacking | [anti-patterns.md](references/anti-patterns.md) |
| Find a repair pattern after establishing a defect | [phrase-bank.md](references/phrase-bank.md) |
| Check scope, evidence and delivery | [checklist.md](references/checklist.md) |
| Verify a quotation or statistic | [evidence/annotations.json](references/evidence/annotations.json), [evidence/curation.json](references/evidence/curation.json) |

## Evidence boundaries

The training corpus is the eight user-provided PDFs under `reference/` (69 pages).
All eight yielded text. **Scanned-only skipped files: none.**
There are 24 numbered corpus-supported rules: R01–R18 and A01–A06.
Each rule carries a quotation, original filename, PDF page, and extraction block.
The 60 glossary entries include 42 with local corpus evidence; related, external,
manuscript-only and gap entries are explicitly separate and cannot be counted as local attestation.
External OCP, NVIDIA and HiF4 documents supplement terminology only.
IEEE 754-2019 official full text was not retrieved; do not claim clause-level verification.

PDF extraction and sentence statistics are estimates with disclosed exclusions.
Paragraph-opening counts cover 48 purposively chosen openings, not every paragraph.
An observed phrase is not automatically a good phrase, a standard definition, or a mandatory rule.
Do not cite user-imposed targets as findings of the corpus.

## Review workflow and user constraints

These controls come from the user's `prompt.md`, not from corpus frequency:

1. Respect the authorized stage and mode. `MODE=report-only` produces findings and queries only.
2. Before language changes, compile the untouched paper and record command, exit status and log.
   If baseline compilation fails, report it; do not make language edits on that basis.
3. Diagnose terminology before editing. Distinguish real synonyms from different technical objects.
   Check abstract, keywords and body separately; first-use expansions are checked per context.
4. For each candidate, record location, original, minimal proposed repair, severity, category and evidence.
   Use must-fix for demonstrable grammar/meaning errors, should-fix for obstructed reading,
   optional for an actual but nonessential improvement. Preference alone is not a defect.
5. Preserve `we` and the author's voice; do not reorder paragraphs or turn prose into bullets.
6. Preserve all claims, numbers, units, ratios, percentages, ranges, assumptions and limitations.
   Never change citations, references, labels, inputs, macros, math, symbols or figure paths.
   Report missing baselines or ambiguous technical intent as author queries, not guessed repairs.
7. Do not replace mantissa with significand blindly, group with block blindly,
   power with energy, latency with throughput, or format precision with model accuracy.
   The glossary's evidence status controls how confidently a preference may be applied.
8. Sentence-length targets (mean 18–22, maximum 30 words), American spelling, and the
   design-present / experiment-past / conclusion-present table are user targets.
   Corpus counterexamples exist. A long but correct sentence is not permission to rewrite it.
9. Keep at most 10 directly decidable author queries. A wording candidate is not a technical verdict.
10. Editing, when separately authorized, requires the approved branch workflow, a successful rebuild,
    a complete patch, and a one-location-per-row change log. Use an explicit mapping between
    edits and hunks: raw diff line counts do not equal the number of linguistic edits.

## Reproduce the evidence

Run from the standalone manuscript directory; all commands write only generated evidence/log paths:

```sh
python3 skills/dp-puzzle-en-writing/scripts/extract_corpus.py --evidence skills/dp-puzzle-en-writing/references/evidence
python3 skills/dp-puzzle-en-writing/scripts/analyze_corpus.py
python3 skills/dp-puzzle-en-writing/scripts/qa.py --verify
```

`pdftotext` is required for this replay. If unavailable, stop and report the missing tool;
never infer PDF contents. A separately implemented fallback must record its method and
must not silently reuse bbox block IDs from a different extractor.
The optional `qa.py --scan dp-puzzle.tex` is a read-only surface scan, not a language verdict.
Full extracted text stays under ignored `build/stage-a/`; small evidence and hashes are retained.
