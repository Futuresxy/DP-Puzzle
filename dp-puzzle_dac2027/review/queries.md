# Author queries — MODE=report-only

7 条，均未替作者作技术决定；不包含已可直接判定的普通排版偏好。

## Q1 — 表 III 的基础 Group 名称

位置：`tables/group_compositions.tex:13；dp-puzzle.tex:121,126,155`；候选：M01。

表头 T1H2Q4E16 与正文、图注和图内 T2H4Q8E16 不一致。基础 Group 是否确为两个 T1H2Q4E8 Lane？

- A：确认表头是笔误，由作者另行将表头改为 T2H4Q8E16。
- B：表头有意采用不同统计对象；保留它并提供两种名称的关系及正确正文说明。

建议 A。多处正文及图相互一致，但名称含技术数字，必须由作者决定；本轮不动。

## Q2 — 功耗是工具估计还是硅上测量

位置：`dp-puzzle.tex:224,257`；候选：M02。

L224 明写 gate-level activity 驱动的 Power Compiler estimates，L257 却称 measured power。是否全部使用同一份工具估计？

- A：是：候选把 L257 的 measured 改为 estimated，并保留所有工况与限制。
- B：另有实测：保留 measured，但由作者说明测量来源、对应数据和与 L224 的关系。

建议 A，与当前已写的综合后/布线前方法一致；不补造实测证据。

## Q3 — FP4/FP8 的族名与具体测试格式

位置：`dp-puzzle.tex:36,53,224,237；tables/five_stage_migrations.tex:9–13`；候选：S01。

摘要的 FP4 收益是否专指 MXFP4？案例表的 FP8/FP4 是精度族还是具体编码？这些语境是否有意不同？

- A：摘要结果明确写 MXFP4；案例表保留 FP4/FP8 作族名，并用表注说明建模映射由作者定义。
- B：摘要和案例均有独立的多编码结果支持，保留族名，并由作者补明适用范围。

建议 A。L53/L224/L237 已给出具体 MXFP4；不能因此把所有 FP4 全局替换成 MXFP4。

## Q4 — matched 是否指共同预算

位置：`dp-puzzle.tex:36,55,257`；候选：S02。

不同候选取整数核数后，matched area and power 是否仅表示相同上限，而非实际面积与功耗严格相等？

- A：共同上限：摘要候选用 Under common area and power budgets。
- B：实际资源相等：保留 matched，并由作者指出相等条件或预算余量处理。

建议 A，符合 L257 取两种预算可容纳核数的较小值的叙述。

## Q5 — 注意力缩写与 CSA 冲突

位置：`tables/five_stage_migrations.tex:8,16；dp-puzzle.tex:46,179`；候选：M03。

请确认表中 SWA、CSA、Q-up、O-up、Grouped O-down 及 QK/PV 的确切名称；注意力 CSA 与 carry-save adder 的 CSA 是否同缩写不同义？

- A：在表注展开注意力专用缩写，硬件正文保留 CSA=carry-save adder。
- B：为注意力项采用作者认可的另一短标签，并在首次出现处建立映射。

建议 A。表注局部展开最小，且不凭猜测填写术语全称。

## Q6 — S1P2 与 U31 的定义位置

位置：`dp-puzzle.tex:72,119,155,167`；候选：S03。

S1P2、U31 的确切符号合同是什么？U31 是否仅指无符号总位宽，而非固定小数点位置？

- A：作者确认后在首次出现处加一句定义，QI.F/UQI.F 与现有位宽不变。
- B：保留符号并在已有 notation 段补一份作者确认的映射说明。

建议 A。这里缺的是读者可用的定义，不是已证明数值错误；不更改任何符号或位宽。

## Q7 — K/M 与单位格式策略

位置：`dp-puzzle.tex:55,262`；候选：O02。

1K–1M 中 K/M 是何种 token 数量口径？是否保持现有紧排写法，还是另行授权按提示词目标加空格？

- A：明确 K/M 的含义但保持原数值和 1K/1M 写法。
- B：明确同一数值口径，并另行授权统一为带空格的 K/M 写法。

建议 A 先锁定语义；当前写法内部一致，数字/单位红线优先，不能仅凭“11 doubling contexts”猜精确端点。
