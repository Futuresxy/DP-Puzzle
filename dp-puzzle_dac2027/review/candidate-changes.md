# Candidate changes — MODE=report-only

共 13 项：must-fix 5，should-fix 5，optional 3。全部未应用。

“must-fix”表示需优先解决的确定不一致或用户硬指标缺失，不表示已授权自动改动。含技术数字、来源、符号定义或表格的项须作者确认；表格只读。未发现必须修复的明确主谓/冠词等普通语法错误，不为凑分类制造问题。

依据统一指向 [style-rules.md](../skills/dp-puzzle-en-writing/references/style-rules.md)、[terminology.md](../skills/dp-puzzle-en-writing/references/terminology.md) 与用户 prompt.md。R14 的摘要/正文双展开要求来自用户，不伪称为语料统计结论。

## must-fix

| ID | 位置 | 原文 | 候选/处理 | 原因与依据 | 作者查询 |
| --- | --- | --- | --- | --- | --- |
| M01 | `tables/group_compositions.tex:13` | T1H2Q4E16 | 作者核对后决定是否为 T2H4Q8E16；不提供自动替换。 | 表 III 基础 Group 列头与正文 L121/L155、图 1 图注 L126 及图内 Group 标签不一致。名称包含技术数字，必须由作者确认。 依据：R08；glossary group/lane；本稿交叉证据 | Q1 |
| M02 | `dp-puzzle.tex:257` | the maximum measured power across precision modes | the maximum estimated power across precision modes（若同指 L224 的 Power Compiler 结果） | L224 明说 Power Compiler estimates total power，且是综合后、CTS/布线前；measured 可能被理解为硅上实测。 依据：R11（实测/综合/模型不可互换） | Q2 |
| M03 | `tables/five_stage_migrations.tex:16` | Main QK/PV includes SWA/CSA. | 在表注写出作者确认的 SWA 与此处 CSA 全称；避免裸用与硬件加法器相同的 CSA。 | 正文 L179 已将 CSA 定义为 carry-save adder；本表的 attention 语境显然需要另行界定，但当前稿没有给出 SWA/CSA 全称。不能猜其展开。 依据：R14；R08；glossary carry-save | Q5 |
| M04 | `dp-puzzle.tex:36` | on DeepSeek-V4.1-Flash GEMMs | on DeepSeek-V4.1-Flash general matrix multiplications (GEMMs) | 摘要首次使用 GEMMs 未展开；正文 L46 的 GEMM 展开不能替代摘要独立定义。按用户“摘要+正文各一次”要求判定。 依据：R14；prompt.md B1；glossary GEMM | — |
| M05 | `dp-puzzle.tex:36` | Mixed-precision AI workloads | Mixed-precision artificial intelligence (AI) workloads；正文 L46 首现 AI 也需独立展开。 | AI 在摘要、关键词和正文均出现，但没有完整展开；这是用户指定的缩写检查要求，不是主张读者不了解 AI。 依据：R14；prompt.md B1 | — |

## should-fix

| ID | 位置 | 原文 | 候选/处理 | 原因与依据 | 作者查询 |
| --- | --- | --- | --- | --- | --- |
| S01 | `dp-puzzle.tex:36` | doubling FP4 throughput | doubling MXFP4 throughput（若这里专指 L53 的同组结果） | 摘要的数值结果在贡献 L53 和评测 L237 使用 MXFP4；裸 FP4 可能被读成 NVFP4/HiF4 等整个族均有相同收益。只建议核对所指，不改任何数值。 依据：R09；R08；glossary MXFP4/NVFP4/HiF4；OCP S01 | Q3 |
| S02 | `dp-puzzle.tex:36` | At matched area and power | Under common area and power budgets（若 matched 指共同预算） | L257 是共同预算下取整数核数，不保证每个候选实际消耗完全相等。L55 的 Under matched area and power budgets 已明确 budgets，建议区别处理。 依据：R08；R09；L257 的部署定义 | Q4 |
| S03 | `dp-puzzle.tex:155` | the U31 magnitude interface | 若 U31 指位宽类型，在首次出现处补充作者认可的定义；S1P2 (L72) 同理，先查询不改符号。 | QI.F/UQI.F 在 L119 有定义，U31/S1P2 未同样解释。不能直接假定 U31 与某一固定小数位格式等价。 依据：R14；glossary Q-format 的 manuscript-only 状态 | Q6 |
| S04 | `dp-puzzle.tex:93` | Related Work on Dot-Product Design and DSE | Related Work on Dot-Product Design and Design-Space Exploration | DSE 在此首现，L98 后面虽写 design-space exploration，但没建立缩写映射；仅出现一次时直接全称更清楚。 依据：R14；prompt.md B1 | — |
| S05 | `dp-puzzle.tex:39` | LLM inference | large language model inference（关键词）；正文 GPGPU/NPU、RTL/TT/MLP 的首现按同一约定补全称或列明豁免。 | LLM 只在关键词作为缩写出现，正文未给 large language model 全称；其余缩写是常见术语但也无首现展开。不猜表内专用算子全称。 依据：R14；prompt.md B1；glossary prefill/GEMM | — |

## optional

| ID | 位置 | 原文 | 候选/处理 | 原因与依据 | 作者查询 |
| --- | --- | --- | --- | --- | --- |
| O01 | `tables/related_features.tex:5` | Feature Comparison of Related Dot-Product Unit Designs | Feature comparison of related dot-product unit designs. | 该 caption 源码用标题式大小写且无句点，其余活动 caption 多为 sentence case + 句点。IEEE 表题会再做样式处理，因此不是含义错误。 依据：R18 的局部一致性原则；prompt.md B1 caption 检查 | — |
| O02 | `dp-puzzle.tex:55` | 1K--1M contexts | 仅报告：prompt.md 目标为 1 K–1 M。先确认 K/M 含义与排版策略，当前保留 1K--1M。 | L55 和 L262 的写法内部一致，却与用户指定单位空格目标不同。任何数值/单位编辑都在红线内，不自动执行。 依据：style-rules 用户目标/语料分离；R15 | Q7 |
| O03 | `dp-puzzle.tex:251` | Ideal GEMM compute speedups: | Ideal GEMM compute speedups relative to the baseline configuration: | 图 3 图注标了聚合方式，未就地说明 speedup 分母；正文 L257/L262 已定义基线。可提高图注独立可读性，数值与正文均不改。 依据：R09；R16；prompt.md B1 caption 检查 | — |

## 刻意不列为修改候选

- mixed-precision workloads 与 multi-precision hardware 有不同修饰对象，不机械统一。
- Lane/Group 为项目命名层级，quantization block 为格式分组；大小写与词形差异有语义。
- modeled、ideal、estimated、compute-only、before clock-tree synthesis and place-and-route、under sufficient data supply and full array utilization 都保留。
- 评测现在时是可接受的本文叙述方式；不全篇改过去时。
- 摘要与正文的小数位差异（如 33.6 与 33.60）是保护对象，不据此更改数值。
- 语料无证据的禁用词规则、不超过 30 词目标和编辑者偏好，都不足以独立支持重写。
- 图 1 的 S10/S11 为信号宽度风格标记；不把它们误当 10/11 级流水而报时序矛盾。图内 mant/man 为信号缩写，未作为正文术语漂移处理。
