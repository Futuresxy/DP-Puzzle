# English microarchitecture translation

- Date: 2026-11-17.
- Authorization: translate the current formal Chinese Chapter III into professional academic English in `dp_puzzle.tex`.
- Guidance: project `.skill/academic-humanizer/SKILL.md`. No standalone academic-translation skill was found in the available catalogs or local skill directories.
- Source: `sections/03_architecture.tex`, SHA-256 `69e62a822512b3a7a917daee26a0ffb43503718cb8747543f4c0112e2b37e6bf`.
- Destination: the inline `03_architecture.tex` review-pair block. This replaces the older English architecture and separate expansion chapters with the five-subsection organization of the current Chinese chapter.
- Scope: preserved the author's Chinese sources and English abstract, contributions, background, evaluation, DSE, and conclusion. The introduction's organization sentence alone was mechanically updated to refer to the merged architecture chapter. Preexisting author edits are excluded from this task's local commit.
- Content: baseline Lane--Group--DP hierarchy; shared multipliers and alignment; block scaling and raw/effective Anchor definitions; fused DP accumulation; Q8E16/Q8/E16 specialization; nine Group compositions and CSA expansion. No experimental results or new external claims were added.
- Fidelity check: the existing `scripts/check_bilingual.py` signature functions were applied only to Chapter III. Headings, labels, reference targets, citation keys, three displayed equations, the shared table, and all three figure sources match the current Chinese chapter. The full-manuscript parity check was not used because later English chapters remain older versions.
- Numerical review: preserved T1H2Q4E8 / T2H4Q8E16 / T8H16Q32E64; 11-bit significand decomposition; UQ2.26; 31-bit Lane results; 14-by-8-bit scale multiplication and 22-bit result; 28/27/26/21/19 fractional-bit layouts; 39-bit alignment; eight-cycle latency; 14-bit E16 Lane and 15-bit Group sums; and the nine shared table configurations.
- Build: `make -f Makefile.en pdf` passed. No undefined references, duplicate labels, or overfull boxes. Pages 3--5 were visually inspected, including the baseline/unpacking/CSA figures and Table III. The architecture is Chapter III, specialization is III-E, and evaluation is now Chapter IV through automatic numbering.
- Current full English document: eight body pages and two reference pages. Existing page-limit warnings remain. The PDF converter also reports inclusion of author-provided PDF 1.7 figures into a PDF 1.5 output; the figures render successfully and were not edited.
- Remaining cross-chapter difference: the untouched English evaluation/DSE/conclusion still describe the previous six-DP/four-ratio K/N study. Translation of those sections is outside this task; the translated architecture follows the current nine-ratio Chinese source.
- Shared table source (read-only in this task): `tables/group_compositions.tex`, SHA-256 `9dbf01cc55c0ec9cef9a43b0b40e305714b6275a7d26456eff30d14ab147fda9`.
- Built PDF SHA-256: `df98da6f0874bacea766bb9714b4e2513a380b932ed26996fc494cc96c776584`.
- Review status: translation and consistency checks by Codex; author review remains separate.

## Terminology used

| Chinese concept | English rendering |
| --- | --- |
| 指数 / 指数域 | exponent / exponent field |
| 有效数、参与运算的尾数 | significand |
| 编码中的小数域 | fraction field |
| 缩放因子 | scale factor |
| 解码 / 解包 | decoding / unpacking |
| 移位对齐 | alignment shifting |
| 局部 / 全局对齐基准 | local / global reference exponent |
| 前导零检测 | leading-zero detection (LZD) |
| 进位保存压缩 / 进位传播加法器 | carry-save compression / carry-propagate adder (CPA) |
| 向零截断 | truncation toward zero |
| 最近偶数舍入 | round-to-nearest, ties-to-even |
