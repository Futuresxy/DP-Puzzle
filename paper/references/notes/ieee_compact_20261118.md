# Bibliography formatting and English case-study synchronization

Date: 2026-11-18 (Asia/Singapore). Scope: author-requested bibliography
compaction, followed by translation of the official Chinese Chapters V and VI
into `dp_puzzle.tex`. This is editorial work, with no new experiment or result.

## Bibliography

- Retained the bundled IEEEtran bibliography style, standard font sizes and page
  geometry. All 39 cited entries and their citation order remain unchanged.
- Abbreviated conference and journal names. For formally published papers with
  existing DOI metadata, printed a clickable DOI instead of a redundant URL.
  Explicit DOI notes are necessary because the bundled IEEEtran.bst 1.14 does
  not render the `doi` field.
- Printed clickable arXiv identifiers, including pinned versions, rather than
  repeating the same identifier in a full URL. Corrected the WikiText preprint's
  entry type from journal article to miscellaneous/preprint.
- Retained URLs for web-only sources. The DeepSeek-V4.1-Flash entry now prints
  the official model landing page and the short revision identifier. Its full
  immutable report URL remains in `archiveurl`.
- Original URLs, source-specific locators and other omitted display metadata
  remain in `archiveurl` and `source*` fields. Access dates were preserved.
- Kept the existing six-author threshold; corrected the already-truncated TPU
  author list to first author plus et al. The source lists 75 authors.

Formatting references consulted:

- [IEEE Reference Guide, 2018 edition hosted by IEEE](https://edu.ieee.org/mx-udgvalles/wp-content/uploads/sites/121/IEEE-Reference-Guide.pdf),
  author lists, abbreviated proceedings, DOI citations, and online references.
- [Official DeepSeek-V4.1-Flash model page](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash),
  checked for the report title and technical-report link.
- [TPU paper author listing](https://arxiv.org/abs/1704.04760).

## Translation and checks

The source is `sections/05_dse.tex` and `sections/06_conclusion.tex`. The English
text preserves alpha=0.327, beta=1, 36 baseline cores, 256 DPs/core, 1 GHz,
five successive migration scenarios, 11 doubling context lengths from 1K to
1M, batch=1, the ratio of equally weighted mean compute times across 55
combinations, and the 1.13x aggregate ideal GEMM compute speedup. Citations,
the shared migration table and case-study figure are preserved. This edit does
not modify Chapters I--IV or the abstract; concurrent author edits are retained.

Both manuscripts initially compiled with XeLaTeX/latexmk without undefined
references, BibTeX warnings or overfull boxes. The bibliography now occupies one page,
down from two, with full printed URLs reduced from 34 to 14. The Chinese PDF
has six body pages plus one reference page. The English PDF has seven body
pages plus one reference page; its existing body-length warning remains.
Reference layout, the translated case study, and its figure were visually checked.
During the final rebuild, a concurrent edit commented out the English
`dynamic_add.pdf` figure while retaining the Chapter III reference to
`fig:dp_csa_expansion`. This produces one undefined-reference warning in the
current English PDF; the author edit was preserved. The translated Chapters V
and VI have no undefined references.

For the author's next whole-paper revision: the English abstract and
introduction still describe the earlier six-scenario result (1.15x/1.147x),
whereas the translated case study describes five scenarios and 1.13x. Those
earlier sections were outside this edit's scope. The evaluation-to-case-study
transition also retains its earlier DSE wording. English float placement and
overall page reduction remain part of the planned layout revision.
