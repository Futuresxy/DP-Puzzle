# Anti-patterns: observed repairs and coverage limits

以下 6 条均有真实原句。改后仅是教学候选，未应用到目标论文；不能把语料作者的所有写法视为错误。涉及 claim 强度的词先查询，不自动删除。

## A01 — 防御性套语 (should-fix)

原句：“It should be noted that two scalar casts and an additional packing operation, which are not directly available in the ISA, would be required without this functionality.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.9, P01/b93

候选改法：Two scalar casts and an additional packing operation, which are not directly available in the ISA, would be required without this functionality.

原因与限制：若套语仅提醒读者注意，可去掉 It should be noted that；保留 would、without 及 ISA 能力限制。

## A02 — 冗长目的结构 (should-fix)

原句：“The FMA units have a widened port for one of the operands in order to accept an unrounded multiplication result.” — `fused-fp8.pdf`, PDF p.6, P06/b211

候选改法：The FMA units have a widened port for one of the operands to accept an unrounded multiplication result.

原因与限制：in order to 在这里可缩为 to，目的和技术对象不变；不是语法错误，也不是必须修改的所有实例。

## A03 — 冠词误用 (must-fix)

原句：“An multiple-precision multiplication architecture with low hardware overhead is designed through the LPC method.” — `Low-Cost Multiple-Precision.pdf`, PDF p.2, P03/b28

候选改法：A multiple-precision multiplication architecture with low hardware overhead is designed through the LPC method.

原因与限制：multiple 的起始音不是元音；只修冠词，保留被动语态和作者主张。

## A04 — 主谓一致 (must-fix)

原句：“Converting between two formats require special care for vectors as their length can differ.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.5, P01/b49

候选改法：Converting between two formats requires special care for vectors as their length can differ.

原因与限制：动名词短语 Converting between two formats 作单数主语；不因两个 formats 而用复数谓语。

## A05 — 套语与 which 从句堆叠 (should-fix)

原句：“It is worth pointing out that the addition to the accumulator is done in the two last cycles, which adds flexibility to the result forwarding, and allows to substantially reuse a pre-existing, FMA capable FP32 adder, after modification to increase the bit width of one input.” — `fused-fp8.pdf`, PDF p.3, P06/b32

候选改法：The addition to the accumulator is done in the two last cycles. This adds flexibility to the result forwarding and allows substantial reuse of a pre-existing, FMA capable FP32 adder, after modification to increase the bit width of one input.

原因与限制：原句较长且把阶段、收益和前提串联；此候选移除套语、拆开主断言并修 allows to，不改 two、FP32 或复用前提。不能仅因超过 30 词就套用。

## A06 — 未量化的 significantly (optional)

原句：“Low-bitwidth formats significantly reduce memory and bandwidth needs by representing model parameters with fewer bits.” — `mxdotp.pdf`, PDF p.1, P08/b9

候选改法：若上下文没有幅度证据，先提交作者查询；经作者同意后候选为：Low-bitwidth formats reduce memory and bandwidth needs by representing model parameters with fewer bits.

原因与限制：significantly 是幅度主张；需检查上下文证据。删除会弱化 claim，不能自动修。

## 三类覆盖及不得伪造的缺口

防御性写作：A01/A05 展示可以移除的注意套语。`We believe` 在 LLMCompass 中出现，但它界定的是建模假设或作者判断，不能自动去掉；真实 may / without / if 限定按 R08/R12 保留。

中文作者英文缺陷：A02 展示目的结构的最小简化，A03/A04 展示可核查的冠词和主谓问题。这是文本现象分类，不推断作者国籍，也不把 In order to 本身判为语法错误。

冗余与堆叠：A05 为从句堆叠实例，A06 为幅度词证据检查。论文内部重复结论需对照上下文；引用数量多或名词修饰语多不是单独改写理由。

下列来自提示词的候选模式已列入扫描，但本地正文尚无足够实例支撑逐项规则，故不编造“语料原句→改法”：

- 防御性：It is worth noting that；may potentially；can help to；to some extent；连续 suggest … may；已说结论再解释一遍。
- 中文作者常见候选：Aiming at；carry out experiments；has good performance；the reason lies in；With the rapid development of；plays an important role；not only … but also；on the one hand … on the other hand。相近的 rapid advancement 不能冒充 rapid development 命中。
- 冗余候选：very / greatly / dramatically；the … of the … of the；which 链；四个以上前置修饰名词；respectively 超三项。数量门槛不等于已证明的语法禁令。

扫描计数与实际命中见 evidence/pattern-counts.json。未检得只表示本次选定正文/模式未命中，不证明整领域不用。需补充语料或作者同意后才能把未证实候选升级成规则。
