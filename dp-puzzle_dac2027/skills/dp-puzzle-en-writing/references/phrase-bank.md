# Phrase bank

模板是语料句法的抽象；方括号是槽位，不是允许生成新事实的占位数据。只有修复确有缺陷的句子时才使用。

## Abstract

模板：`We present [artifact], [capability].`

“We present FPnew, a highly configurable open-source transprecision floating-point unit (TP-FPU), capable of supporting a wide range of standard and custom FP formats.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.1, P01/b4

保留具体任务与能力边界；不得新加 first 或 novel。

## Introduction

模板：`To address [observed limitation], we propose [mechanism].`

“To address these limitations, we propose MXDOTP, a dedicated ISA extension that natively integrates scaling within a dot product-accumulate operation.” — `mxdotp.pdf`, PDF p.1, P08/b9

前文必须已建立 limitation。

## Contributions

模板：`We [present / extend / evaluate] [object].`

“We present TransDot, a reconfigurable FPU that supports trans-precision DPA and unifies scalar, SIMD, and DPA execution within a largely shared datapath.” — `TransDot.pdf`, PDF p.2, P05/b148

只用于已有列表，不把段落改成项目符号。

## Method

模板：`To [purpose], [component] is implemented with [choice].`

“To sustain frequency, the MXDOTP unit is implemented with three levels of pipeline registers.” — `mxdotp.pdf`, PDF p.3, P08/b57

purpose 必须有原稿依据。

## Method

模板：`[Component] feeds [data] toward [destination].`

“Arbiters feed the operation group outputs toward the output of the unit.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.3, P01/b25

保留信号方向与物理层次。

## Evaluation

模板：`[Design] achieves [metric] under [conditions].`

“The cluster achieved 1.09 GHz under typical conditions (TT/0.8 V/25 °C) without introducing any new critical paths.” — `mxdotp.pdf`, PDF p.3, P08/b57

技术条件不可删除。

## Comparison

模板：`[Result] compared with [baseline], at the cost of [overhead].`

“Evaluation shows that TransDot achieves 1.46× area efficiency for FP16 DPA and 2.92× area efficiency for FP8 DPA at the cost of 37.3% extra area on average compared with the baseline.” — `TransDot.pdf`, PDF p.4, P05/b278

倍数和百分比从作者原文保留，不按模板重算。

## Normalized result

模板：`[Metric] normalized to [reference]; [direction].`

“Fig. 10: End-to-End Performance of Latency-Oriented Design Normalized to GA100. Performance metric: inverse of latency (higher is better). Settings: batch size 4 16, 4-way tensor parallelism, running 48 GPT-3 layers (half of GPT-3).” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.10, P02/b251

图区分原指标和倒数。

## Conclusion

模板：`We presented [artifact], [supported scope].`

“We presented MXDOTP, a RISC-V ISA extension enabling efficient execution of Microscaling (MX) dot products.” — `mxdotp.pdf`, PDF p.4, P08/b160

结论回顾用过去时可成立。
