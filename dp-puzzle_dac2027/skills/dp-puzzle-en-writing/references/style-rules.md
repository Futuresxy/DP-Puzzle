# Evidence-based style rules

适用：计算机体系结构、数字 IC、浮点点积及 LLM 硬件论文的最小语言编辑。规则是可采用的修复依据，不是无缺陷重写许可。每个编号均附本地语料原句；原句中的瑕疵不等于推荐写法。

## 语料支持的 18 条规则

### R01 — 先明确论文做了什么

介绍工作时，用具体 artifact 作宾语并交代能力；只有原句信息缺失或指代不清时才补明，不以新颖性形容词替代内容。

- “We present FPnew, a highly configurable open-source transprecision floating-point unit (TP-FPU), capable of supporting a wide range of standard and custom FP formats.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.1, P01/b4

### R02 — 让硬件部件承担动作

解释数据流时优先写部件执行的具体动作；名词化不是禁用项，只有遮蔽施动者或机制时才改。

- “Arbiters feed the operation group outputs toward the output of the unit.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.3, P01/b25

### R03 — 设计手段连接具体目的

可以用 To + purpose 引出实现选择，但不补写原稿未支持的因果或收益。

- “To sustain frequency, the MXDOTP unit is implemented with three levels of pipeline registers.” — `mxdotp.pdf`, PDF p.3, P08/b57

### R04 — 设计与方法可用现在时

设计行为和本文采用的方法常用现在时；保留作者的 we。评测现在时也是实见用法，不能一律改为过去时。

- “We evaluate TransDot through RTL modification and ASIC synthesis using Cadence Genus [23] with a commercial 12nm PDK.” — `TransDot.pdf`, PDF p.3, P05/b220

### R05 — 已完成实验可用过去时

描述一次已经完成的运行、比较或测量可用过去时；依据叙述对象处理时态，不机械统一全文。

- “We performed General Matrix Multiplication (GEMM) with random matrices of different sizes on the MPICC MAC unit to compare the impact of high-precision emulation on Mean Squared Error (MSE), as depicted in Fig. 8.” — `MPICC_paper.pdf`, PDF p.5, P04/b391

### R06 — 结论按陈述对象选时态

结论中的持续贡献可用现在时，回顾完成的工作可用过去时或现在完成时。三者在语料中共存。

- “This work introduces LLMCompass, a fast, accurate, and architecturally descriptive hardware evaluation framework for LLM inference workloads.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.12, P02/b288
- “We presented MXDOTP, a RISC-V ISA extension enabling efficient execution of Microscaling (MX) dot products.” — `mxdotp.pdf`, PDF p.4, P08/b160
- “We have presented FPnew, a configurable open-source transprecision floating-point unit capable of supporting arbitrary FP formats.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.13, P01/b140

### R07 — 已知对象承接下一句

前句建立的硬件对象可成为后句主语，减少读者重新定位的成本；不因此强制重排段落。

- “Input operands are routed toward one of four operation group blocks, each dedicated to a class of instructions.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.3, P01/b25
- “Arbiters feed the operation group outputs toward the output of the unit.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.3, P01/b25

### R08 — 能力边界要一起写

实现支持与不支持的功能必须保留；不能把 while、only 或否定范围视为冗余。

- “While we support the flexible cast-and-pack operations, this version of the core is not equipped with expanding FMA operations.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.6, P01/b67

### R09 — 比较给出基线和指标

倍数或百分比要与被比较指标和基线关联。缺少基线时提问，不猜补数值或重算。

- “Evaluation shows that TransDot achieves 1.46× area efficiency for FP16 DPA and 2.92× area efficiency for FP8 DPA at the cost of 37.3% extra area on average compared with the baseline.” — `TransDot.pdf`, PDF p.4, P05/b278

### R10 — 收益和代价在同一比较范围内

同一候选的收益与面积代价可以并列报告；保持平均、模式和基线等限定。

- “Evaluation shows that TransDot achieves 1.46× area efficiency for FP16 DPA and 2.92× area efficiency for FP8 DPA at the cost of 37.3% extra area on average compared with the baseline.” — `TransDot.pdf`, PDF p.4, P05/b278

### R11 — 区分测量、综合和模型

证据来源是技术限定；不能把 synthesized、simulated、estimated 改成 measured。

- “For this core, we measured the silicon manufactured in Globalfoundries 22FDX technology across a wide voltage range from 0.45 to 1.2 V.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.1, P01/b4
- “Both micro-architectures were synthesized in 5nm technology, and the results revealed different use case scenarios for each of the two.” — `fused-fp8.pdf`, PDF p.8, P06/b230

### R12 — 保留真实不确定性

may 等词在模型假设或未知厂商机制中有实义；不能以去防御性写作为由删除。

- “Cores in NVIDIA GPUs and Matrix Cores in AMD GPUs are simulated as systolic arrays in LLMCompass, which may not be true in reality.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.6, P02/b175

### R13 — 一句突出一个主断言

有独立可报告结论时可用短句；长句只有在存在歧义、嵌套过深等缺陷时才拆，不按词数自动重写。

- “The latency for both microarchitectures is 4 cycles.” — `fused-fp8.pdf`, PDF p.2, P06/b26

### R14 — 首现缩写建立明确映射

在需要独立阅读的语境中可先展开再给缩写；摘要和正文各展开一次是本项目检查要求，而非由这一例证明的普遍惯例。

- “Modern AI accelerators increasingly rely on reduced-precision arithmetic to improve performance and energy efficiency.” — `TransDot.pdf`, PDF p.1, P05/b17
- “Compact floating-point (FP) arithmetic has gained significant attention for energy-efficient computing, particularly in machine learning workloads [1]–[4].” — `mxdotp.pdf`, PDF p.1, P08/b7

### R15 — 物理工况连同单位报告

数字和物理单位分开写的实见形式有 1.09 GHz、25 °C；本项目要求的空格只作为检查，不授权本轮或后续擅改数字/单位。

- “The cluster achieved 1.09 GHz under typical conditions (TT/0.8 V/25 °C) without introducing any new critical paths.” — `mxdotp.pdf`, PDF p.3, P08/b57

### R16 — 归一化标明分母和方向

归一化性能必须说明参考对象及指标方向；不要把 inverse latency 和 latency 混为一谈。

- “Fig. 10: End-to-End Performance of Latency-Oriented Design Normalized to GA100. Performance metric: inverse of latency (higher is better). Settings: batch size 4 16, 4-way tensor parallelism, running 48 GPT-3 layers (half of GPT-3).” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.10, P02/b251

### R17 — 贡献条目保持局部平行

已有贡献列表内可以采用一致的 We + verb 结构；语料也使用名词短语列表，不强制转成 We，也不把普通段落改成列表。

- “We present TransDot, a reconfigurable FPU that supports trans-precision DPA and unifies scalar, SIMD, and DPA execution within a largely shared datapath.” — `TransDot.pdf`, PDF p.2, P05/b148
- “We evaluate TransDot using ASIC flow with a commercial 12nm technology, demonstrating favorable area–delay trade-offs and strong area efficiency.” — `TransDot.pdf`, PDF p.2, P05/b150

### R18 — 用语料多数拼写作局部一致性建议

datapath 与 data path 均出现；本稿已有 datapath 时保持该写法。语料习惯不能推翻原文引用或有意区分的概念。

- “This paper presents TransDot, a reconfigurable FPU that unifies SIMD FMA and trans-precision DPA within a shared reconfigurable datapath.” — `TransDot.pdf`, PDF p.4, P05/b278
- “The overall data path and the key design have been discussed in detail.” — `Low-Cost Multiple-Precision.pdf`, PDF p.6, P03/b290

## 用户指定目标与观察结果分开

`prompt.md` 指定均值 18–22 词、硬上限 30 词。统计见 [corpus-analysis.md](corpus-analysis.md)：这些是项目检查目标，不是八篇语料普遍遵循的规律。超过 30 词应列出候选，只有确有语言缺陷才编辑；不得为压句长改 claim、数字或限定。

时态检查表：设计 present；已完成实验 past；结论中的持续贡献 present。这是提示词建议表。R04–R06 的反例说明评测 present、结论 past / present perfect 也成立，不能将整节时态一致误解为所有动词同一时态。

美式拼写为项目约定：检查 normalize / normalization、optimize / optimization 等，但引用原句不改。语料同时有 amongst、parametrized 等，不能声称全部是美式。

目标格式示例 `28 nm`、`1 GHz`、`2.3×`、`3.2%`、`1 K–1 M` 来自提示词，不是本次实验数据。语料也有 `12nm`、`5.1 %`、`1.06x` 等。尤其 `1 K–1 M` 没有足够本地实例。只报告异常；数字、单位及数学对象的红线优先。

一句一断言是让句子有清楚中心的编辑目标，不禁止带条件的复合句。已知信息在前、动词优先见 R02/R07；不能据此重排原文段落。
