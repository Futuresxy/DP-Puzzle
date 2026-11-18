# Author queries — remaining decisions after B2–B5

共 5 条。先前 Q1–Q7 的作者回复保留在 [author-decisions.json](evidence/author-decisions.json) 与 Git 历史；已确认事项及实际处理见 [change-log.md](change-log.md)。当前仅以下项目需要决策。

## Q-C1 — optional O01：表题大小写与句点

- 位置：`tables/related_features.tex:5`。
- 问题：`Feature Comparison of Related Dot-Product Unit Designs` 与其他 caption 的 sentence case 风格不同。
- A：保持原文。B：改为 `Feature comparison of related dot-product unit designs.`。
- 建议：B；仅版式一致性。本轮未改，等待批准。

## Q-C2 — optional O02：上下文长度说明

- 位置：`dp-puzzle.tex:55`，相关说明在 L262。
- 问题：作者已确认 1K–1M 指上下文长度，1M=1024K；是否把该说明写入论文。
- A：保留 `1K--1M contexts`。B：写成 `context lengths from 1K to 1M tokens, where 1M = 1024K`，不改变端点或另推 1K 的绝对值。
- 建议：B；数值释义已确认，新增表述仍待本轮 optional 授权。未改单位空格。

## Q-C3 — optional O03：图注比较基线

- 位置：`dp-puzzle.tex:251`。
- 问题：图注中的 `Ideal GEMM compute speedups:` 未就地写出正文已经定义的分母。
- A：保持原文。B：改为 `Ideal GEMM compute speedups relative to the baseline configuration:`。
- 建议：B，以提高图注独立可读性；本轮未改。

## Q-C4 — 算子标签展开范围

- 位置：`dp-puzzle.tex:46` 与 `tables/five_stage_migrations.tex:8,16`。
- 问题：SWA/CSA2 已按作者名称落地；QK/PV、Q-up、O-up、Grouped O-down 仍沿用模型标签，未凭字面推测具体算子定义。
- A：保留为模型原始标签并豁免首现展开。B：由作者提供各标签的准确全称/运算含义，之后在首现或表注补充。
- 建议：B；作者未补充前保持 A 的文本状态。本条不是新技术含义提案。

## Q-C5 — 修改后页数

- 位置：完整稿件；AI 使用说明移到第 7 页，参考文献从第 8 页开始。
- 问题：术语展开后编译成功，但原先 6 页正文增加到 7 页，触发模板的页数告警。
- A：授权另做保持所有 claim/数值/限定不变的压缩审计，再给精简候选。B：保留本轮文字，由作者决定删减或版面安排。
- 建议：A；本轮不擅自重写通顺句、不改字体/页边距、不移除 AI 使用说明。当前 PDF 尚不满足模板的正文 6 页目标。
