# Candidate changes — B2–B5 status

当前状态优先于下方历史候选：M01 在编辑前已由作者修正；其余 9 项 must-fix / should-fix 已落地为 [change-log.md](change-log.md) 的 10 处源码修改。O01/O02/O03 均未落地，等待作者批准。历史原句及作者回复保留供追溯；最新源行与落地映射见 [candidates.json](evidence/candidates.json)。

## 以下为先前 report-only 候选快照

# Candidate changes — MODE=report-only

最终检查另观察到 `dp-puzzle.tex` 的摘要及关键词有并行工作区修改；本助手未写入任何 `.tex`，也未提交这些修改。下文候选保留审计时的原句，不构成对新增摘要措辞的完整重审；旧编译结果不覆盖当前稿件。

初次审计共 13 项（5 must-fix、5 should-fix、3 optional），编号及初次原文保留。当前 M01 已在用户工作区修正；其余 12 项仍保留为候选/待决表述，不能把作者确认视为已应用修改。详见 [queries.md](queries.md)。

本次不修改任何 `.tex`。表中“初次原文”来自原 B1 快照；M01/M03 的当前源行见 evidence/candidates.json，避免将用户的后续编辑误报为没有变化。

依据：[style-rules.md](../skills/dp-puzzle-en-writing/references/style-rules.md)、[terminology.md](../skills/dp-puzzle-en-writing/references/terminology.md)、作者本轮回复及本地规格。

## must-fix

| ID / 位置 | 初次原文 | 最新候选/处理 | 状态与依据 |
| --- | --- | --- | --- |
| M01 / `tables/group_compositions.tex:13` | T1H2Q4E16 | T2H4Q8E16 | confirmed_source_already_updated；本轮开始前当前表头已为 T2H4Q8E16；此项不再是当前源码的待改项。 依据：R08；glossary group/lane；本稿交叉证据 |
| M02 / `dp-puzzle.tex:257` | the maximum measured power across precision modes | the maximum estimated power across precision modes | confirmed_pending_manuscript_edit；所有功耗均为 Power Compiler 的软件估计值，不是硅上实际测量。 依据：R11（实测/综合/模型不可互换） |
| M03 / `tables/five_stage_migrations.tex:16` | Main QK/PV includes SWA/CSA. | Main QK/PV includes Sliding-Window Attention (SWA) and Compressed Sparse Attention 2 (CSA2). | confirmed_pending_manuscript_edit；SWA/CSA2 展开已由作者提供；当前表注仍是 CSA，保留用户已有修改。 依据：R14；R08；glossary carry-save |
| M04 / `dp-puzzle.tex:36` | on DeepSeek-V4.1-Flash GEMMs | on DeepSeek-V4.1-Flash general matrix multiplications (GEMMs) | not_applied；摘要首次使用 GEMMs 未展开；正文 L46 的 GEMM 展开不能替代摘要独立定义。按用户“摘要+正文各一次”要求判定。 依据：R14；prompt.md B1；glossary GEMM |
| M05 / `dp-puzzle.tex:36` | Mixed-precision AI workloads | Mixed-precision artificial intelligence (AI) workloads；正文 L46 首现 AI 也需独立展开。 | not_applied；AI 在摘要、关键词和正文均出现，但没有完整展开；这是用户指定的缩写检查要求，不是主张读者不了解 AI。 依据：R14；prompt.md B1 |

## should-fix

| ID / 位置 | 初次原文 | 最新候选/处理 | 状态与依据 |
| --- | --- | --- | --- |
| S01 / `dp-puzzle.tex:36` | doubling FP4 throughput | doubling MXFP4 throughput | confirmed_pending_manuscript_edit；所讨论结果具体指 MXFP4；FP4/FP8 在概括性讨论中是按位宽区分的精度族代称。 依据：R09；R08；glossary MXFP4/NVFP4/HiF4；OCP S01 |
| S02 / `dp-puzzle.tex:36` | At matched area and power | Under common area and power budgets | confirmed_pending_manuscript_edit；面积和功耗为共同上限约束；不同配置的实际消耗不要求相等。 依据：R08；R09；L257 的部署定义 |
| S03 / `dp-puzzle.tex:155` | the U31 magnitude interface | U31 denotes a 31-bit unsigned magnitude container; its binary-point position depends on the precision mode. HiF4 原始元素另明确为 sign-magnitude；不直接改称二补码 Q1.2。 | partly_resolved_encoding_wording_pending；S1P2 的现用输入编码是 sign-magnitude，而稿件 QI.F 被定义为二补码。可以说明同为 1+1+2 位分配，不能直接把 S1P2 编码改称本稿定义下的 Q1.2。建议保持二补码 QI.F 约定，并明确 HiF4 元素为符号—幅值定点编码；这是待作者选择的表述，不是实施编码变更。 依据：R14；glossary Q-format 的 manuscript-only 状态 |
| S04 / `dp-puzzle.tex:93` | Related Work on Dot-Product Design and DSE | Related Work on Dot-Product Design and Design-Space Exploration | not_applied；DSE 在此首现，L98 后面虽写 design-space exploration，但没建立缩写映射；仅出现一次时直接全称更清楚。 依据：R14；prompt.md B1 |
| S05 / `dp-puzzle.tex:39` | LLM inference | large language model inference（关键词）；正文 GPGPU/NPU、RTL/TT/MLP 的首现按同一约定补全称或列明豁免。 | not_applied；LLM 只在关键词作为缩写出现，正文未给 large language model 全称；其余缩写是常见术语但也无首现展开。不猜表内专用算子全称。 依据：R14；prompt.md B1；glossary prefill/GEMM |

## optional

| ID / 位置 | 初次原文 | 最新候选/处理 | 状态与依据 |
| --- | --- | --- | --- |
| O01 / `tables/related_features.tex:5` | Feature Comparison of Related Dot-Product Unit Designs | Feature comparison of related dot-product unit designs. | not_applied；该 caption 源码用标题式大小写且无句点，其余活动 caption 多为 sentence case + 句点。IEEE 表题会再做样式处理，因此不是含义错误。 依据：R18 的局部一致性原则；prompt.md B1 caption 检查 |
| O02 / `dp-puzzle.tex:55` | 1K--1M contexts | 上下文长度 1K–1M；1M = 1024K。保留当前空格排版，不推断 1K 的绝对 token 数。 | meaning_confirmed_format_unchanged；1K–1M 表示上下文长度，且 1M = 1024K。 依据：style-rules 用户目标/语料分离；R15 |
| O03 / `dp-puzzle.tex:251` | Ideal GEMM compute speedups: | Ideal GEMM compute speedups relative to the baseline configuration: | not_applied；图 3 图注标了聚合方式，未就地说明 speedup 分母；正文 L257/L262 已定义基线。可提高图注独立可读性，数值与正文均不改。 依据：R09；R16；prompt.md B1 caption 检查 |

## 刻意不列为修改候选

- mixed-precision workloads 与 multi-precision hardware 有不同修饰对象，不机械统一。
- Lane/Group 为项目命名层级，quantization block 为格式分组；大小写与词形差异有语义。
- modeled、ideal、estimated、compute-only、before clock-tree synthesis and place-and-route、under sufficient data supply and full array utilization 都保留。
- 评测现在时是可接受的本文叙述方式；不全篇改过去时。
- 摘要与正文的小数位差异（如 33.6 与 33.60）是保护对象，不据此更改数值。
- 语料无证据的禁用词规则、不超过 30 词目标和编辑者偏好，都不足以独立支持重写。
- 图 1 的 S10/S11 为信号宽度风格标记；不把它们误当 10/11 级流水而报时序矛盾。图内 mant/man 为信号缩写，未作为正文术语漂移处理。
