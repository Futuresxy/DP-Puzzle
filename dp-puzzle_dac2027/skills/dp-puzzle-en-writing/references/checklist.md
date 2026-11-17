# Review checklist and source of each control

The workflow controls below come from the user's prompt; they are not claimed as corpus-derived style rules.

## Stage A (skill construction)

- [ ] Every PDF is listed with SHA-256, pages, tool/version and extraction method.
- [ ] Scanned-only / extraction failures are explicit, not guessed from a title.
- [ ] Layout and bbox evidence resolve columns; boilerplate, reference lists and table content are excluded from prose statistics.
- [ ] Six rhetorical sections per paper have statistics; missing explicit contribution lists are marked.
- [ ] Counts identify tokenization, sample unit, exclusions and the difference between per-sentence frequency and per-paper votes.
- [ ] Each numbered rule has an exact local quote and file/page/block locator (R01–R18, A01–A06).
- [ ] All five terminology domains are represented, with missing/external evidence explicitly labeled.
- [ ] All three anti-pattern classes are addressed; absent phrases do not receive invented examples.
- [ ] SKILL.md is at most 250 lines and links its supporting references.
- [ ] Random seed 20261118 selects five rules; each quote can be found again in a fresh PDF extraction.
- [ ] Full local quote validation passes; before/after hashes prove no `.tex` changes.

## Stage B report-only

- [ ] Capture a baseline build of the unchanged manuscript, including command, return code and relevant warnings.
- [ ] If it fails, report failure; do not fabricate a passed baseline or perform language edits.
- [ ] Inventory concepts and abbreviations separately in abstract, keywords and body.
- [ ] Distinguish token differences that denote distinct concepts (R08, R12; glossary status).
- [ ] Flag concrete inconsistencies and unit/number typography without changing protected objects (R09, R15).
- [ ] Examine captions, comparison baselines and metric direction (R09, R10, R16).
- [ ] Candidate rows contain severity, exact source/line, minimal wording, reason and evidence.
- [ ] Do not treat the 30-word target or uncommon phrase as an automatic defect (R13; corpus-analysis).
- [ ] Questions are at most 10, with two usable options and a recommendation.
- [ ] No TeX, bibliography, macro, figure or technical-content changes occur.

## After separately authorized editing

- [ ] Every applied edit corresponds to an approved scope and a genuine defect.
- [ ] No values, units, assumptions, limitations, claims or mathematical objects changed.
- [ ] Compilation succeeds; a new error triggers rollback of the responsible edit and a report.
- [ ] Review both the full diff and change log; map each edit to a location/hunk explicitly.
- [ ] Recheck terminology across abstract/keywords/body and retain author voice.

The prompt's literal “change-log rows = diff modified lines” is not generally a valid invariant:
one wording edit may occupy multiple removed/added lines. In report-only mode neither a language
patch nor an applied-change log is produced. Resolve that accounting definition before an editing stage.
