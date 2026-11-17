# Corpus extraction and statistical evidence

日期：2026-11-18。只统计 `reference/` 下 8 篇 PDF，共 69 页。外部标准和目标稿均不计入语料统计。

## A1：抽取、清洗与可重放范围

- 首先逐篇运行 `pdftotext -layout -enc UTF-8`，再用 `-bbox-layout` 的独立文本块避免左右栏串行污染；默认阅读顺序抽取仅作为辅助。
- 原始版面、bbox XML、逐块清洗文本和逐句记录留在被忽略的 `build/stage-a/`；PDF hash、工具版本、选块、断词修复和统计摘要保存在本目录 evidence/。
- curation.json 显式列出六个修辞部分的块 ID/起止锚点。章节内背景折入 method；贡献从 introduction 拆出；不把贡献算两次。
- 排除参考文献、作者简介、版权、页眉页脚、行号、图表、程序和公式密集片段；清洗连字与换行空白，断词修复逐条可追溯。不更正语料作者原有语法或拼写。
- 无纯扫描件，跳过列表为空。P07 有大量审稿行号；按块筛除。P08 的乘号存在抽取缺失，不从它推算数值，也不作倍数书写依据。
- 部分块跨段或跨栏，未可靠拼接的首尾残句、少于 5 个 token 的片段和括号不平衡/含等式的句子不纳入句长统计。这是可重放的正文近似统计，不声称 100% 句法标注或 OCR 校对。
- 词定义：英文字母/数字串，内部连字符与撇号计一个词；如 1.09 可能分成两个 token。缩写句点有保护，但数学、小节标题和引文仍可能影响句界。原始 quotes 保留在 annotations.json，可独立核对。

## A2：句长

筛选后 1314 句、29340 个 token；均值 22.329，中位数 21.0，>30 词 223 句（16.971%）。

项目希望均值 18–22、硬上限 30；本次语料不支持把它们当作普遍事实。这个结论受上述筛选和 tokenization 口径限制。

| Paper | 文件 | 页数 | 句数 | 均值 | 中位数 | >30 词比例 |
| --- | --- | --- | --- | --- | --- | --- |
| P01 | FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf | 14 | 234 | 24.453 | 24.0 | 19.658% |
| P02 | LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf | 17 | 288 | 19.955 | 19.0 | 9.375% |
| P03 | Low-Cost Multiple-Precision.pdf | 6 | 103 | 21.117 | 19 | 17.476% |
| P04 | MPICC_paper.pdf | 6 | 142 | 21.761 | 21.0 | 17.606% |
| P05 | TransDot.pdf | 5 | 78 | 24.333 | 23.0 | 26.923% |
| P06 | fused-fp8.pdf | 8 | 207 | 21.87 | 20 | 15.942% |
| P07 | iccad2026-paper544.pdf | 9 | 152 | 23.921 | 23.0 | 21.053% |
| P08 | mxdotp.pdf | 4 | 110 | 23.136 | 21.0 | 19.091% |

逐篇六部分的全部统计见 [sentence-statistics.csv](evidence/sentence-statistics.csv)。`contributions` 对无列表的 P06 是叙述式贡献段，不伪造列表。

## 段首模式（48 个定向样本）

每篇每个修辞部分取 1 个可辨开篇，手工标注 claim-first（先陈述问题/优势/判断）或 topic-first（先介绍对象/活动/范围）。贡献处取条目开篇；这是平衡的定向样本，不是全篇所有段落的比例估计，不推断整领域偏好。原句、页码和标注理由见 annotations.json → paragraph_openings。

| Paper | claim-first | topic-first |
| --- | --- | --- |
| P01 | 1 | 5 |
| P02 | 0 | 6 |
| P03 | 2 | 4 |
| P04 | 1 | 5 |
| P05 | 1 | 5 |
| P06 | 1 | 5 |
| P07 | 4 | 2 |
| P08 | 2 | 4 |

## 贡献条目动词与平行性

| Paper | 条目数 | 开头/主干 | 平行性 |
| --- | --- | --- | --- |
| P01 | 4 | The design, Extensions, Integration, Integration | noun-phrase parallel |
| P02 | 3 | introduce, leverage, propose | We + present verb parallel |
| P03 | 2 | is designed, present | passive/active mixed |
| P04 | 3 | architecture (noun), is introduced, was designed | noun/passive, tense mixed |
| P05 | 3 | present, extend, evaluate | We + present verb parallel |
| P06 | 0 | 无显式列表 | no explicit list; narrative contribution statement |
| P07 | 3 | show, characterize, analyze | topic labels + We present verbs |
| P08 | 3 | design, introduce, integrate | We + present verb parallel |

条目主干计数（不把所有 We 句都当贡献）：Integration=2, introduce=2, present=2, The design=1, Extensions=1, leverage=1, propose=1, is designed=1, architecture (noun)=1, is introduced=1, was designed=1, extend=1, evaluate=1, show=1, characterize=1, analyze=1, design=1, integrate=1。
P08 跨页的 We demonstrate 是最后一项的延续，不另计条目。P05 We extend 跨栏，原始布局中可查。完整摘录见 annotations.json → contributions。

## 高频动宾搭配（表面模式）

这是带有限词距的 regex 命中句数，不是句法依存分析。以下输出包括提示词点名但未命中的搭配；0 不等于禁用。每项保存 regex、逐篇计数和原句示例。

| 搭配 | 命中句数 |
| --- | --- |
| support formats | 24 |
| reduce area | 8 |
| improve energy efficiency | 8 |
| achieve throughput | 8 |
| reduce power | 4 |
| amortize cost/overhead | 3 |
| incur overhead | 2 |
| hide latency | 1 |
| exploit sparsity | 0 |
| close timing | 0 |

## 指标与比较句

每篇选取最多 3 条带数值及 comparison/efficiency/overhead 等词的原句，见 comparison-examples.json；可复用模板和适用限制见 phrase-bank.md。这只是写法证据，不替本稿核验硬件结果。

## 拼写与模式频率

| 模式 | 命中句数 | 涉及论文数 |
| --- | --- | --- |
| bitwidth | 10 | 1 |
| bit width | 16 | 2 |
| bit-width | 3 | 2 |
| datapath | 56 | 7 |
| data path | 4 | 2 |
| dequantization | 0 | 0 |
| mantissa | 48 | 6 |
| significand | 15 | 2 |
| It is worth noting that | 0 | 0 |
| It is worth pointing out that | 1 | 1 |
| We believe | 2 | 1 |
| It should be noted | 1 | 1 |
| may potentially | 0 | 0 |
| can help to | 0 | 0 |
| to some extent | 0 | 0 |
| suggest … may | 0 | 0 |
| Aiming at | 0 | 0 |
| In order to | 3 | 1 |
| carry out experiments | 0 | 0 |
| has good performance | 0 | 0 |
| the reason lies in | 0 | 0 |
| With the rapid development of | 0 | 0 |
| plays an important role | 0 | 0 |
| not only … but also | 0 | 0 |
| on the one hand … on the other hand | 0 | 0 |
| significantly | 17 | 5 |
| very | 3 | 2 |
| greatly | 0 | 0 |
| dramatically | 0 | 0 |
| the … of the … of the | 7 | 4 |
| which chain | 1 | 1 |
| respectively | 25 | 7 |
| 12nm-like unit spacing | 9 | 4 |
| space before percent | 8 | 1 |
| no space before percent | 79 | 7 |
| American normalization | 43 | 7 |
| British normalisation | 0 | 0 |
| American optimization | 29 | 7 |
| British optimisation | 0 | 0 |

句子命中频率和论文投票数分别报告：长论文的重复词不能等同于多个独立来源。`respectively` 命中不代表超过三项；前置名词数量、重复结论、支持 significantly 的数据需人工判断。

## A3 与缺口

当前 24 条有本地证据的规则（18 条 style + 6 条 anti-pattern）；60 条词表项。状态分布：{'corpus': 42, 'external': 3, 'gap': 12, 'manuscript-only': 1, 'related': 2}。
本地语料不足：HiF4、MXFP6、E8M0 的完整术语实例，Q-format，initiation interval，throughput ratio，TOPS/W、TOPS/mm²、pJ/op 的确切写法，以及 calibration、outlier、precision migration、MoE、attention projection、dequantization。
OCP、NVIDIA、HiF4 原始资料只补充术语裁决，不进入本地统计。IEEE 754-2019 官方全文未能读取。没有证据的 anti-pattern 候选仅列在覆盖缺口，不升级成有证据规则。
