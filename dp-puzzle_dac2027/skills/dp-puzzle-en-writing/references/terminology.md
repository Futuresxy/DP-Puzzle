# Terminology and evidence

状态：`corpus`=本地原句；`related`=相关用法但不是完整术语；`external`=外部一手资料补充；`gap`=未核验；`manuscript-only`=仅作者当前定义。后四种不能充当本地语料已覆盖的证据。原句保留拼写及语法瑕疵；PDF 页码从 1 起。

五类术语是审计词表，不是自动替换表。TF32 等全称、Q-format 位数以及 group 的物理层次须尊重作者技术合同。

## 浮点算术

| ID / English | 中文 | 典型搭配 | 语料原句及出处 | 状态与限制 |
| --- | --- | --- | --- | --- | --- |
| T01 / exponent | 指数 | product exponent | “This produces a SoP with a FP32 range exponent and a normalized 68-bit significand.” — `fused-fp8.pdf`, PDF p.3, P06/b32 | corpus； |
| T02 / mantissa | 尾数（需说明含隐藏位与否） | mantissa decoding | “The 8-bit result of the mantissa decoding includes the leading bit.” — `MPICC_paper.pdf`, PDF p.3, P04/b156 | corpus； |
| T03 / significand | 有效数 | accumulator significand | “The accumulator significand is aligned in parallel with the summation of the SoP.” — `fused-fp8.pdf`, PDF p.5, P06/b189 | corpus； |
| T04 / hidden bit | 隐藏位 | forming the significand | “Note that an implict 1, the hidden bit, is concatenated to the fraction as an integer bit, forming the significand.” — `fused-fp8.pdf`, PDF p.1, P06/b16 | corpus； |
| T05 / subnormal | 次正规数 | subnormal inputs and results | “However, subnormal inputs and results are supported.” — `fused-fp8.pdf`, PDF p.3, P06/b42 | corpus； |
| T06 / rounding mode | 舍入模式 | roundTiesToEven (RNE) | “We implement roundTiesToEven (RNE), the most commonly used rounding mode in AI workloads, ensuring compliance with the specification, which leaves other modes optional.” — `mxdotp.pdf`, PDF p.2, P08/b24 | corpus； |
| T07 / normalization | 规格化 | normalization and rounding | “The rounding process is executed immediately after normalization and is the last step of FP multiplications.” — `Low-Cost Multiple-Precision.pdf`, PDF p.4, P03/b124 | corpus； |
| T08 / alignment | 对齐 | alignment of the accumulator significand | “Notably, the alignment of the accumulator significand is performed with a single bi-directional shifter.” — `fused-fp8.pdf`, PDF p.5, P06/b189 | corpus； |
| T09 / sticky bit | 粘滞位 | guard bit, round bit, and sticky bit | “The round carry bit is generated according to the guard bit, round bit, and sticky bit, which can be seen in Algorithm 1.” — `Low-Cost Multiple-Precision.pdf`, PDF p.4, P03/b124 | corpus； |
| T10 / exponent bias | 指数偏置 | exponent bias | “The exponent bias is 7 for E4M3 and 15 for E5M2.” — `fused-fp8.pdf`, PDF p.1, P06/b16 | corpus； |
| T11 / fraction | 小数部分/编码字段，按上下文裁决 | fraction / significand | “Note that an implict 1, the hidden bit, is concatenated to the fraction as an integer bit, forming the significand.” — `fused-fp8.pdf`, PDF p.1, P06/b16 | corpus； |

## 数据格式

| ID / English | 中文 | 典型搭配 | 语料原句及出处 | 状态与限制 |
| --- | --- | --- | --- | --- | --- |
| T12 / TF32 | TensorFloat-32 | Tensor float 32 (TF32) | “Some of these representations are Tensor float 32 (TF32), with 8-bit exponent and 10-bit fraction, IEEE half-precision (FP16), with 5-bit exponent and 10-bit fraction, and bfloat16 (BF16), with 8-bit exponent and 7-bit fraction [1], [2].” — `fused-fp8.pdf`, PDF p.1, P06/b18 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T13 / FP16 | 16 位浮点格式 | IEEE half-precision (FP16) | “Some of these representations are Tensor float 32 (TF32), with 8-bit exponent and 10-bit fraction, IEEE half-precision (FP16), with 5-bit exponent and 10-bit fraction, and bfloat16 (BF16), with 8-bit exponent and 7-bit fraction [1], [2].” — `fused-fp8.pdf`, PDF p.1, P06/b18 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T14 / BF16 | bfloat16 格式 | bfloat16 (BF16) | “Some of these representations are Tensor float 32 (TF32), with 8-bit exponent and 10-bit fraction, IEEE half-precision (FP16), with 5-bit exponent and 10-bit fraction, and bfloat16 (BF16), with 8-bit exponent and 7-bit fraction [1], [2].” — `fused-fp8.pdf`, PDF p.1, P06/b18 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T15 / FP8 E4M3 / E5M2 | 两种 FP8 编码 | MXFP8 (E5M2, E4M3) data formats | “We introduce MXDOTP, a RISC-V ISA extension that fuses scaling and dot product into a single four-operand instruction.” — `mxdotp.pdf`, PDF p.1, P08/b10 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T16 / MXFP8 | 微缩放 FP8 | MXFP8 general dot product | “In this work, we focus on the MXFP8 general dot product to evaluate the efficiency of MX formats in low-bitwidth arithmetic operations.” — `mxdotp.pdf`, PDF p.2, P08/b19 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T17 / MXFP4 | 微缩放 FP4 | per-block quantization | “Along the granularity axis, strategies have progressed from coarse per-tensor/per-channel schemes (supported by vector units) to fine-grained per-block quantization (e.g., MXFP4 [29] or NVFP4 [1]), which requires tensor cores to natively support fine-grained scaling factors.” — `iccad2026-paper544.pdf`, PDF p.1, P07/b118 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T18 / per-tensor scaling | 逐张量缩放 | traditional per-tensor scaling | “Unlike traditional per-tensor scaling or BFP, which share a single exponent across large blocks, MX offers finer-grained scaling by allowing individual elements or smaller blocks to retain independent scales.” — `mxdotp.pdf`, PDF p.2, P08/b15 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T19 / per-channel scaling | 逐通道缩放 | per-tensor/per-channel schemes | “Along the granularity axis, strategies have progressed from coarse per-tensor/per-channel schemes (supported by vector units) to fine-grained per-block quantization (e.g., MXFP4 [29] or NVFP4 [1]), which requires tensor cores to natively support fine-grained scaling factors.” — `iccad2026-paper544.pdf`, PDF p.1, P07/b118 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T20 / NVFP4 | NVIDIA FP4 格式 | NVFP4 | “Along the granularity axis, strategies have progressed from coarse per-tensor/per-channel schemes (supported by vector units) to fine-grained per-block quantization (e.g., MXFP4 [29] or NVFP4 [1]), which requires tensor cores to natively support fine-grained scaling factors.” — `iccad2026-paper544.pdf`, PDF p.1, P07/b118 | corpus；编码定义另见外部标准核对；这里仅证明用法。 |
| T21 / MXFP6 | 微缩放 FP6 | MXFP6 format | 未取得本地语料原句。 | external；8 篇正文未检得该完整拼写；OCP MX v1.0 Table 1 规定名称。不得将 FP6 自动视为 MXFP6。 |
| T22 / E8M0 | 8 位指数、0 位尾数字段的缩放编码 | E8M0 scale data type | 未取得本地语料原句。 | external；以 OCP MX v1.0 §5.4.1 核对；无本地语料原句。 |
| T23 / per-group scaling | 逐组缩放 | per-group scaling factor | 未取得本地语料原句。 | gap；仅有 group/block 相关表述；未检得此固定搭配。不能把项目 Group 与量化 group 等同。 |
| T24 / HiF4 | HiFloat4 格式 | HiFloat4 (HiF4) | 未取得本地语料原句。 | external；8 篇未检得；补充 HiFloat4 原文 arXiv:2602.11287v2，不能伪称来自 reference/。 |
| T25 / Q-format (QI.F / UQI.F) | 有符号/无符号定点记法 | signed QI.F / unsigned UQI.F | 未取得本地语料原句。 | manuscript-only；本稿明确 I 不含符号位，位宽为 1+I+F / I+F；这只是作者定义，语料及 TI 原始定义尚未核验，不改符号或位宽。 |

## 微架构

| ID / English | 中文 | 典型搭配 | 语料原句及出处 | 状态与限制 |
| --- | --- | --- | --- | --- | --- |
| T26 / lane | 计算通道 | additional narrow lanes | “FPnew enables SIMD execution by instantiating additional narrow lanes for lower-precision formats, while a shared wide datapath supports multi-format mixed-precision FMA.” — `TransDot.pdf`, PDF p.2, P05/b151 | corpus； |
| T27 / group | 组（需按层次定义） | operation group blocks | “Input operands are routed toward one of four operation group blocks, each dedicated to a class of instructions.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.3, P01/b25 | corpus； |
| T28 / dot-product unit | 点积单元 | fused dot-product units | “The two proposed fused dot-product units compute the fused FP8 4-way dot product with scaling and FP32 accumulation in four cycles.” — `fused-fp8.pdf`, PDF p.2, P06/b29 | corpus； |
| T29 / systolic array | 脉动阵列 | systolic arrays | “Lack of software knowledge.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.6, P02/b175 | corpus； |
| T30 / broadcast dataflow | 广播数据流 | broadcast-style array construction | “Since GPU tensor cores are exposed through regular MMA-style instructions, this work focuses on compute-unit organization and broadcast-style array construction rather than systolic/dataflow scheduling.” — `iccad2026-paper544.pdf`, PDF p.3, P07/b509 | related； |
| T31 / reduction tree | 规约树 | a reduction tree is implemented | “For the reduction within each core, a reduction tree is implemented.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.5, P02/b153 | corpus； |
| T32 / carry-save | 进位保留 | carry-save form | “Multiplier uses the usm signal to convert intermediate products, which are in carry-save form, to signed numbers and then uses a carry-propagate adder (CPA) to generate a signed product.” — `fused-fp8.pdf`, PDF p.4, P06/b117 | corpus； |
| T33 / carry-propagate adder | 进位传播加法器 | carry-propagate adder (CPA) | “Multiplier uses the usm signal to convert intermediate products, which are in carry-save form, to signed numbers and then uses a carry-propagate adder (CPA) to generate a signed product.” — `fused-fp8.pdf`, PDF p.4, P06/b117 | corpus； |
| T34 / alignment shifter | 对齐移位器 | alignment shifter aligns | “An alignment shifter aligns the mantissa of C with the product, after which the aligned operands are accumulated using an adder sized to a no-precision-loss range ((3p + 4), where p denotes the precision in bits, i.e., mantissa bits + 1).” — `TransDot.pdf`, PDF p.2, P05/b151 | corpus； |
| T35 / pipeline stage | 流水级 | without using pipeline stages | “Achieving a relaxed clock frequency of 200 MHz without using pipeline stages, the total area of the MPICC MAC unit is 1619.16 µm2.” — `MPICC_paper.pdf`, PDF p.5, P04/b371 | corpus； |
| T36 / initiation interval | 启动间隔 | initiation interval (II) | 未取得本地语料原句。 | gap；8 篇未检得该完整词组；不可用 latency 或每周期吞吐的表述替代定义。 |

## 指标

| ID / English | 中文 | 典型搭配 | 语料原句及出处 | 状态与限制 |
| --- | --- | --- | --- | --- | --- |
| T37 / peak throughput | 峰值吞吐 | achieves a peak throughput | “At the same frequency, the tensor core achieves a peak throughput of 2.89 TFLOPS.” — `iccad2026-paper544.pdf`, PDF p.8, P07/b1583 | corpus； |
| T38 / area overhead | 面积开销 | area overhead of supporting multiple modes | “The area overhead of supporting multiple modes can be estimated by the additional multiplexers required.” — `TransDot.pdf`, PDF p.3, P05/b187 | corpus； |
| T39 / utilization | 利用率 | hardware utilization rate | “Larger batch sizes can also improve the hardware utilization rate.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.10, P02/b255 | corpus； |
| T40 / latency | 延迟 | latency for both microarchitectures | “The latency for both microarchitectures is 4 cycles.” — `fused-fp8.pdf`, PDF p.2, P06/b26 | corpus； |
| T41 / power | 功耗 | power consumption | “We average power consumption over ten samples extracted from DeiT-Tiny [11], quantized to MXFP8 using Microsoft’s MX PyTorch Emulation Library 2 .” — `mxdotp.pdf`, PDF p.3, P08/b58 | corpus； |
| T42 / energy | 能量 | consumes 26.7 pJ | “For example, the FP64 FMA fmadd.d consumes 26.7 pJ, while performing the same operation on FP32 requires 65% less energy.” — `FPnew_An_Open-Source_Multiformat_Floating-Point_Unit_Architecture_for_Energy-Proportional_Transprecision_Computing.pdf`, PDF p.8, P01/b89 | corpus； |
| T43 / area efficiency | 面积效率 | area efficiency | “Evaluation shows that TransDot achieves 1.46× area efficiency for FP16 DPA and 2.92× area efficiency for FP8 DPA at the cost of 37.3% extra area on average compared with the baseline.” — `TransDot.pdf`, PDF p.4, P05/b278 | corpus； |
| T44 / throughput ratio | 吞吐配比 | peak throughput ratio | 未取得本地语料原句。 | gap；本稿主题术语；语料有 throughput 比较，未检得完整词组。 |
| T45 / TOPS/W | 每瓦每秒万亿操作 | energy efficiency in TOPS/W | 未取得本地语料原句。 | gap；语料多用 GFLOPS/W / Tflop/sW，不据此推导 OP 计数。 |
| T46 / TOPS/mm² | 单位面积每秒万亿操作 | area efficiency in TOPS/mm² | 未取得本地语料原句。 | gap；未检得完整正文用例；不能直接替换文中的 FLOPS 面积单位。 |
| T47 / pJ/op | 每操作皮焦 | energy per operation | 未取得本地语料原句。 | gap；有 pJ 和 per-operation energy 的近邻证据，未检得该确切斜线单位。 |

## 量化与负载

| ID / English | 中文 | 典型搭配 | 语料原句及出处 | 状态与限制 |
| --- | --- | --- | --- | --- | --- |
| T48 / weight-only quantization | 仅权重量化 | weight-only W4A16 methods | “Along the precision axis, different quantization algorithms impose heterogeneous requirements on numerical formats: weight-only W4A16 methods such as GPTQ [7], AWQ [19] convert INT4 weights to FP16/BF16 via vector units during LLM inference and thus require FP16/BF16 tensor core; SmoothQuant [32] uses W8A8 and relies on INT8 precision; the DeepSeek V3 training pipeline [6] demands FP8 E4M3 with high-precision accumulation; and SVDQuant [17] joint weight–activation 4-bit quantization calls for emerging formats such as NVFP4 [1].” — `iccad2026-paper544.pdf`, PDF p.1, P07/b118 | corpus； |
| T49 / weight-activation quantization | 权重与激活量化 | joint weight–activation 4-bit quantization | “Along the precision axis, different quantization algorithms impose heterogeneous requirements on numerical formats: weight-only W4A16 methods such as GPTQ [7], AWQ [19] convert INT4 weights to FP16/BF16 via vector units during LLM inference and thus require FP16/BF16 tensor core; SmoothQuant [32] uses W8A8 and relies on INT8 precision; the DeepSeek V3 training pipeline [6] demands FP8 E4M3 with high-precision accumulation; and SVDQuant [17] joint weight–activation 4-bit quantization calls for emerging formats such as NVFP4 [1].” — `iccad2026-paper544.pdf`, PDF p.1, P07/b118 | corpus；原文使用 en dash；不等于所有 weight-activation 策略都采用同一编码。 |
| T50 / prefill | 预填充阶段 | prefill and decoding | “We find that prefill and decoding pose different hardware requirements.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.2, P02/b24 | corpus； |
| T51 / decoding | 自回归解码阶段 | prefill and decoding | “We find that prefill and decoding pose different hardware requirements.” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.2, P02/b24 | corpus；与微架构 input decoding / mantissa decoding 分开判别。 |
| T52 / GEMM | 通用矩阵乘法 | General Matrix Multiplication (GEMM) | “We performed General Matrix Multiplication (GEMM) with random matrices of different sizes on the MPICC MAC unit to compare the impact of high-precision emulation on Mean Squared Error (MSE), as depicted in Fig. 8.” — `MPICC_paper.pdf`, PDF p.5, P04/b391 | corpus； |
| T53 / calibration | 量化校准 | quantization calibration | 未取得本地语料原句。 | gap；未检得量化语境；不能混同硬件模型校准。 |
| T54 / outlier | 离群值 | activation outlier | 未取得本地语料原句。 | gap；8 篇未检得；NVIDIA 补充页面讨论 outliers，但此行不伪造本地原句。 |
| T55 / precision migration | 精度迁移 | precision-migration scenario | 未取得本地语料原句。 | gap；本稿自定义情景术语；需保留其假设性质。 |
| T56 / MoE | 混合专家模型 | mixture-of-experts (MoE) | 未取得本地语料原句。 | gap；本稿出现，8 篇正文未检得。 |
| T57 / attention projection | 注意力投影 | attention projections | 未取得本地语料原句。 | gap；本稿出现；不可用 attention 或 self-attention 命中代替此术语证据。 |
| T58 / dequantization | 反量化 | dequantization overhead | 未取得本地语料原句。 | gap；8 篇所选正文未检得；不要与 general format conversion 自动等同。 |
| T59 / model size | 模型规模（需明确参数量或存储） | model size | “The capability of LLMs is related to their model size [29], [31], and larger models [8], [11] show impressive abilities [77] compared to smaller counterparts [16], [57], with future models expected to exceed trillions of parameters [17].” — `LLMCompass_Enabling_Efficient_Hardware_Design_for_Large_Language_Model_Inference.pdf`, PDF p.1, P02/b20 | corpus； |
| T60 / parameter count | 参数个数 | model parameters | 未取得本地语料原句。 | related；本地语料有 parameters 数量叙述，但未检得 parameter count 完整搭配；不可与模型存储字节数互换。 |

## 外部原始资料（不纳入 8 篇统计）

- S01 [OCP Microscaling Formats (MX) Specification v1.0 (Sep 2023)](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf)，Table 1, §5.2; §5.4.1 (PDF p.10, p.14)。MXFP8/6/4 为格式名；不能用 FP8/6/4 代替完整 block format。E8M0 是 scale type。 原文短引：“E8M0 is an unsigned representation of a conventional biased Float32 exponent.”
- S02 [NVIDIA Transformer Engine 2.14.0, Using FP8 and FP4, NVFP4 Format](https://docs.nvidia.com/deeplearning/transformer-engine-releases/release-2.14/user-guide/examples/fp8_primer.html)，NVFP4 Format。NVFP4 与 MXFP4 不是别名；NVIDIA 文档区分局部块缩放和额外张量缩放。 原文短引：“Therefore, NVFP4 uses an additional single per-tensor FP32 scaling factor to avoid overflows.”
- S03 [HiFloat4 Format for Language Model Inference, arXiv:2602.11287v2](https://arxiv.org/html/2602.11287v2)，Abstract。可核验 HiFloat4 / HiF4 名称；不以补充来源冒充本地八篇统计。 原文短引：“This paper introduces HiFloat4 (HiF4), a block floating-point data format tailored for deep learning.”
- S04 [IEEE Std 754-2019 official landing page](https://ieeexplore.ieee.org/document/8766229)，official access attempt。2026-11-18 官方页面返回 JavaScript/robot 检查，未获得标准正文。significand 与 trailing significand field 的标准条文裁决仍待核验，不拿二手网页代替。

访问日期：2026-11-18。IEEE 官方全文未取得；不能声称已完成 IEEE 754-2019 的条文级裁决。术语冲突、投票口径及本稿定义见 `review/terminology-audit.md` 的阶段 A 部分。
