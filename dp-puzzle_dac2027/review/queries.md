# Author queries — replies recorded, MODE=report-only

最终检查另观察到 `dp-puzzle.tex` 的摘要及关键词有并行工作区修改；本助手未写入任何 `.tex`，也未提交这些修改。下文候选保留审计时的原句，不构成对新增摘要措辞的完整重审；旧编译结果不覆盖当前稿件。

作者已逐项回复原 7 条查询。下文区分作者确认、源码现状与仍需保留的编码差异；不代表已执行语言修改。原查询选项与建议可从 Git 历史查阅。

本次仅更新审计记录。工作区中已有两份表格的用户修改予以保留；初次 B0 编译结果只适用于当时快照，不自动视为修改后表格的编译验收。

## Q1

状态：`confirmed_source_already_updated`。

基础 Group 表头应为 T2H4Q8E16。

英文候选：`T2H4Q8E16`

本轮开始前 tables/group_compositions.tex:13 已有该修改。保留用户工作区变更；不由本次报告更新再次改写或提交该 .tex。

## Q2

状态：`confirmed_pending_manuscript_edit`。

所有功耗均为 Power Compiler 的软件估计值，不是硅上实际测量。

英文候选：`the maximum estimated power across precision modes`

与已有 gate-level activity、综合后/CTS 和布线前等限定一起保留；不把真实负载驱动误写成真实芯片实测。

## Q3

状态：`confirmed_pending_manuscript_edit`。

所讨论结果具体指 MXFP4；FP4/FP8 在概括性讨论中是按位宽区分的精度族代称。

英文候选：`doubling MXFP4 throughput`

摘要具体收益使用 MXFP4；族级论述可保留 FP4/FP8，不进行全局替换，不推断其它编码拥有相同功耗/效率结果。

## Q4

状态：`confirmed_pending_manuscript_edit`。

面积和功耗为共同上限约束；不同配置的实际消耗不要求相等。

英文候选：`Under common area and power budgets`

避免用不带 budgets 的 matched area and power 暗示实际面积、功耗完全一致。

## Q5

状态：`attention_names_confirmed_other_labels_not_expanded`。

注意力侧 SWA 为 Sliding-Window Attention；应使用 Compressed Sparse Attention 2 (CSA2)。硬件侧 CSA 仍是 carry-save adder。

英文候选：`Main QK/PV includes Sliding-Window Attention (SWA) and Compressed Sparse Attention 2 (CSA2).`

本轮开始前表注已有 SWA 与 compressed Sparse attention (CSA) 的用户修改，但尚不是最新确认的 CSA2。保留现状，在候选清单记录准确目标。Q-up/O-up/Grouped O-down 与 QK/PV 的具体展开未由本条回复补充，不编造。

## Q6

状态：`u31_verified_s1p2_q_notation_requires_encoding_distinction`。

作者希望以 Q1.2 表达一位符号、一位整数和两位小数的布局；U31 是否只表示 31 位无符号容器已由本地规格确认。

英文候选：`U31 denotes a 31-bit unsigned magnitude container; its binary-point position depends on the precision mode.`

S1P2 的现用输入编码是 sign-magnitude，而稿件 QI.F 被定义为二补码。可以说明同为 1+1+2 位分配，不能直接把 S1P2 编码改称本稿定义下的 Q1.2。建议保持二补码 QI.F 约定，并明确 HiF4 元素为符号—幅值定点编码；这是待作者选择的表述，不是实施编码变更。

本地核对依据：

- `src/spec/dp/lane/unpack.md:76`：S1P2 的元素值是 `(-1)^s × u/4`，符号独立并保留负零。
- `dp-puzzle.tex:119`：QI.F 明确指 signed two’s-complement；因此 Q1.2 不是该符号—幅值输入的同义编码。
- 例如未施加共享缩放的位串 `1000`：S1P2 为负零，稿件定义的 Q1.2 为 −2。位分配相同不等于逐位编码相同。
- `src/spec/dp/group/dp_group_E.md` §2 与 `dp-top-v1.8.md` §2：U31 是无符号幅值容器；小数位另由模式决定，符号另传。稿件 L159 已列出不同模式的小数位。

建议的 HiF4 表述：`signed-magnitude fixed-point elements with one sign bit, one integer magnitude bit, and two fractional bits`。

待决定：保留现用 QI.F=二补码定义，并把 HiF4 原始编码单独说清（建议）；或为原始输入另外定义带明确 sign-magnitude 限定的 Q 记法。两者都不改变输入编码、数值或硬件。

## Q7

状态：`context_length_and_relative_scale_confirmed`。

1K–1M 表示上下文长度，且 1M = 1024K。

英文候选：`context lengths from 1K to 1M tokens, where 1M = 1024K`

保留现有排版。本回复只明确 M/K 比例，未单独确认 1K 对应多少 tokens；不额外写成 1K=1024 tokens 或新增绝对端点数字。

## 后续边界

Q1 已在本轮开始前的工作区表头中体现；Q2/Q3/Q4 的技术口径已确定。Q5 的 SWA/CSA2 名称已确定，但早先捆绑询问的其它算子标签尚未展开。Q6 的 U31 已核实，Q1.2 需要显式区分编码。Q7 的上下文含义及 M/K 比例已确定，不据此额外假定 1K 的绝对 token 数。

候选清单保留原始审计 ID。原候选数量不是“仍未解决问题数”；记录作者确认也不等于授权本轮修改 `.tex`。
