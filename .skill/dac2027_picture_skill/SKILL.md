---
name: dac2027_picture_skill
description: 为 DP-Puzzle 的 DAC 2027 论文制作和审查面积功耗、Case Study 与 DSE 数据图。统一矢量 PDF、图中文字、坐标符号、插图宽度和 LaTeX 图注，并核对数据来源。
---

# DAC 2027 论文作图

## 图面与图注

- 图面保留坐标、刻度、数据标记和必要图例。多子图的顶部只标 `(a)`、`(b)`、`(c)` 等编号。整图标题、子图名称、实验条件、颜色含义和切换阈值交由 LaTeX 图注说明。
- 轴标直接沿用正文已定义的符号、单位和归一化口径。扩展联合预算图 (a) 横轴用 `\(\alpha\)` 表示基准核心中 DP 阵列的面积比例，刻度采用 `0.25` 到 `0.50` 的小数。纵轴用 `\(\beta\)` 表示功耗上限相对基准的倍率。图注用 `\(\alpha=0.327\)` 指明虚线对应的切片。

## 字体与插图尺寸

- 按 LaTeX 正文的字体和字号设置图内文字、数字和图例，数学符号沿用正文的 TeX 数学字体。当前独立英文稿用 IEEEtran 10 pt，普通文字和数字用 Nimbus Roman 10 pt。Matplotlib 图复用 [figure_style.py](../../dp-puzzle_dac2027/scripts/figure_style.py)，用普通文本格式输出数字刻度。
- 按实际插入宽度导出矢量 PDF 并嵌入字体。当前独立稿的单栏为 `\columnwidth`（252 TeX pt），双栏为 `\textwidth`（516 TeX pt）。面积功耗图的版式可参照 [DP_area_power](../../paper/data/DP_area_power/)。

## 数据与验收

- 从已核验的原始表或冻结的 CSV、JSON 重绘，关联实验 run、配置和 profile。图注沿用证据口径，例如 Power Compiler 功耗估计和模型 GEMM 计算时间。只改排版时，核对重绘前后的数据、边界和图例映射。
- 在最终插图尺寸预览 PDF，检查文字重叠、裁切及图文符号是否一致。用 `pdfinfo` 核对尺寸，用 `pdffonts` 核对嵌入字体，并编译相关 LaTeX 图注检查版面。
