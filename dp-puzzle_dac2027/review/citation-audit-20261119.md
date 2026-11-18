# DAC 2027 英文稿引用审阅报告

2026-11-19，新加坡时间。审阅对象是当前独立英文稿，含表 I–V、正文和编译后的参考文献。稿件 SHA-256 为 `34e6087e819d14a7d9867694e53d96e18169ada23ffbcb7d11ea3bc6953b9804`，包含作者最新的 AI 披露措辞。以下编号对应本轮成稿。表 I 沿用作者确认的 MXFP8、MXFP4 列名。[英文稿](../dp-puzzle.tex) · [参考文献库](../references/references.bib)

**审阅结论。** 41 条参考文献均有引用位置，共 57 次引用键出现，编号与链接目标正常。优先确认表 I 的 **960PR 三档峰值出处**，并把第五章的 **厂商算力、模型精度、trace 数据与本文推导** 分别归到对应来源。最明确可合并的一处是 FPnew 的预印本 [21] 与期刊版 [17]。本报告给出修改候选，待作者审核。

## 编译与格式基线

以 `latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=build/citation_audit_20261119 dp-puzzle.tex` 编译成功。PDF 正文 6 页，第 7 页为参考文献。终轮无未定义引用或越界告警。现有 `IEEEtran`、数字方括号、按首引顺序编号与自动压缩连续编号的用法合理。正文将 `~\cite{...}` 放在被支持的短语、分句或句子之后，编号继续由 LaTeX 生成。[编译日志](../build/citation_audit_20261119/baseline-build.log) · [现稿引用位置](../build/citation_audit_20261119/reference-uses.txt) · [DAC 2027 投稿规则](https://dac.com/2027/program/research-manuscript-submissions) · [IEEE 编辑手册](https://journals.ieeeauthorcenter.ieee.org/wp-content/uploads/sites/7/IEEE-Editorial-Style-Manual-for-Authors.pdf#page=13) · [IEEE Reference Guide](https://edu.ieee.org/mx-udgvalles/wp-content/uploads/sites/121/IEEE-Reference-Guide.pdf)

逐条检查了引用位置与成稿著录。以下建议使用可访问的一手资料、本地作者原文和已固定的实验输入交叉核对。需要进一步查原件的位置已标注，包括 960PR 三档峰值、部分出版社全文，以及 AMD 网页显示精度以外的有效位数。

## Must-fix · 来源与论断边界

| ID | 位置 | 发现与建议 |
| --- | --- | --- |
| C01 | 表 I，960PR [6] | 表中 `1.000 / 2.000 / 8.000` PFLOP/s 需要可定位的三档峰值资料。现有 keynote 的 BibTeX 注释仅把它用于路线图时间。请核出原始幻灯片页、视频时间戳或公开规格及三档格式口径。若只能确认路线图时间，建议表内仅陈述可核实的路线图信息。`†` 标出了目标值的性质，数值仍需来源。[表 I](../tables/vendor_ratios.tex#L25) · [条目说明](../references/references.bib#L176) |
| C02 | 引言与 V-B，DeepSeek-V4.1-Flash [8] | 引言的 `uses FP8 for MoE computations` 把权重格式、激活格式与本文计算速率归类放在同一短语里。建议把原始 routed experts 的 W4A8、attention/indexer 的算子精度分别指向该版本的模型报告或参考实现，随后说明 A 场景在本文模型中按 FP8 算力计入。若标为 MXFP4，注明来自模型格式本身还是本文硬件模式映射。当前 [8] 用技术报告标题著录，链接落在模型首页。宜分别定位报告和固定 revision 下支持所引细节的配置或实现，或在同一条目给出可复查定位。[引言](../dp-puzzle.tex#L48) · [场景 A](../dp-puzzle.tex#L212) · [固定模型来源](../../paper/data/evidence/model_sources.json) · [官方模型配置](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash/blob/314113f8a7dadb388215396ba5fbee2c610a04d6/inference/config.json) |
| C03 | V-A，`D=256` [33]–[36] | `match the dot-product parallelism` 容易被读成厂商直接披露了 DP 个数或组织。本文以基准每 DP 每拍 16 个 BF16 MAC 推得 `D=256` 对应 4,096 BF16 MAC/cycle。Blackwell 幻灯片给出每 SM 的 dense BF16 算力，DaVinci Max 幻灯片给出 FP16 Cube 的 `16³` MAC 规模。建议用两条来源支持各自的峰值粒度，明确 `D` 是本文的建模选择。同期相邻的 `N₀=36` 可继续引用 950 白皮书表 3-1 的 950DT 最大 Cube 核数。`α=0.327` 用另一款 Ascend 的 Cube 簇面积份额作代表值，现稿已有 `separate Ascend study` 的限定，可补第 6.1 节定位。[正文](../dp-puzzle.tex#L202) · [Blackwell Hot Chips 36，PDF 第 15 页](https://hc2024.hotchips.org/assets/program/conference/day1/64_HC2024.NVIDIA.TirumalaWong.pdf#page=15) · [DaVinci Hot Chips 31，PDF 第 9–10 页](https://www.old.hotchips.org/hc31/HC31_1.11_Huawei.Davinci.HengLiao_v4.0.pdf#page=9) · [Ascend 950 白皮书表 3-1](https://public-download.obs.cn-east-2.myhuaweicloud.com/ascend/%E6%98%87%E8%85%BE950%20NPU%E6%9E%B6%E6%9E%84%E7%99%BD%E7%9A%AE%E4%B9%A6.pdf#page=13) · [面积份额核验](../../paper/data/evidence/huawei_area_fraction_20261116.md) |
| C04 | V-B，迁移场景 [38]–[40] | 三篇来源目前集中在整句末尾。把 [38] 放在 NVIDIA 发布的 routed-expert W4A4 NVFP4 实例之后，把 [39]、[40] 接在 FP8、FP4 attention 先例之后。表 V 的 B–E 累积迁移、grouped O-down 降精度和速率映射是本文构造的设计空间。建议就地标明 `modeled precision assignments`，读者据此区分公开实例与本文的性能假设。这些来源的精度结果各自对应原论文所评估的模型和算子。[正文](../dp-puzzle.tex#L212) · [场景表](../tables/five_stage_migrations.tex) · [NVIDIA 模型卡](https://huggingface.co/nvidia/DeepSeek-V4.1-Flash-NVFP4) · [FlashAttention-3](https://proceedings.neurips.cc/paper/2024/hash/7ede97c3e082c6df10a8d6103a2eebd2-Abstract-Conference.html) · [SageAttention3](https://proceedings.neurips.cc/paper_files/paper/2025/hash/4db397e0f760cc573c681e81a01a3dba-Abstract-Conference.html) |
| C05 | V-B，FreeInference [41] | [41] 是数据作者指定的 Zenodo 预印本，DOI `10.5281/zenodo.23903440` 可由作者数据卡核对。建议保留论文引文，并在方法或可复现材料注明实际数据快照 `bb26cf72…`、Aug. 30–Sept. 5 周分区、`step == 0` 和 `prompt_tokens` 字段。需要独立数据集条目时，使用固定发布链接。按当前直方图重算为 2,047 条，`(16K,32K]` 为 687 条，占 33.56%。这三项是本文筛选统计，首次交代数据来源之后可直接报告结果。[正文](../dp-puzzle.tex#L215) · [作者数据卡及引用说明](https://huggingface.co/datasets/harvardMadsys/freeinference_agentic_trace) · [本地数据清单](../../paper/data/new_chip_ds_model/traces/trace_manifest.json) · [直方图](../../paper/data/new_chip_ds_model/traces/agent_first_histogram.csv) |

## Should-fix · 引用位置和比较口径

| ID | 位置 | 发现与建议 |
| --- | --- | --- |
| C06 | 表 I，[1]–[5] | 厂商官方规格是合适的一手来源。表注建议简述 dense、单设备与位宽对应关系。HGX 的 BF16/FP8 由 8 GPU 的稀疏总值换成单卡 dense 峰值，FP4 使用页面单列的 dense 指标。Rubin 的 17.5、35 来自 FP8/FP6 training 和 NVFP4 training，精确归一化为 `1:4.375:8.75`，表内 `≈1:4:8` 是设计类近似。MI455X 官网给出约 `5 / 20.1 / 40.3`，表内三位小数应指向有该精度的原表或写明计算口径。950PR 应定位白皮书表 3-1 的 Cube-only 规格，并注明选用的满配型号。沿用 MX 列名时，说明列内厂商对应位宽的格式，尤其是 Rubin 的 NVFP4。[表 I](../tables/vendor_ratios.tex) · [HGX 规格](https://www.nvidia.com/en-us/data-center/hgx/) · [Rubin 规格](https://www.nvidia.com/en-us/data-center/vera-rubin-nvl72/) · [AMD MI355X](https://www.amd.com/content/dam/amd/en/documents/instinct-tech-docs/product-briefs/amd-instinct-mi355x-gpu-brochure.pdf) · [AMD MI455X 产品规格](https://www.amd.com/en/products/accelerators/instinct/mi400/mi455x.html) · [Ascend 950 白皮书](https://public-download.obs.cn-east-2.myhuaweicloud.com/ascend/%E6%98%87%E8%85%BE950%20NPU%E6%9E%B6%E6%9E%84%E7%99%BD%E7%9A%AE%E4%B9%A6.pdf#page=13) |
| C07 | 引言和 II-A/B，[7]、[9] | [7] 支持 OCP MX 的具体编码、32 元素块和 E8M0 共享尺度。引言中可把它移到 MX 专属短语后，或把该引用仅留在背景。Eq. (1) 如沿用标准的块点积定义，把 [7] 接在该定义后再引出本文的统一表示。[9] 适合支撑 TPU 的 systolic array 例子。若引言保留 broadcast 或 `typically` 的行业概括，需各自有来源。若该句只为交代本文估算，可直接限定为本文的同构 DP 阵列及其峰值推导。[引言](../dp-puzzle.tex#L48) · [背景与公式](../dp-puzzle.tex#L69) · [OCP MX v1.0](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf) · [TPU 原文](https://arxiv.org/abs/1704.04760) |
| C08 | II-C 与 III-B，[22]、[24]–[29] | [22]、[24] 适合支撑 fused dot product 的具体 C 注入、对齐与舍入实例。[25]、[26] 适合支撑不同张量核的数值行为。把 [29]、[26] 支撑的先前位宽分析与探测结果，和本文选择的 **26 fractional bits**、右移向零截断写成独立分句。如要把 26 位说成与某一款 Blackwell 指令一致，需给出精确模式和原文表格或实验，本轮未核实这个等值关系。相关工作 [27]、[28] 可交代各自探索的格式或 MAC 设计，然后明确本文考察三精度峰值配额与联合预算。现有 `neither addresses throughput-ratio selection` 的否定范围需要全文依据，本轮未能查到 [27] 出版商全文。[相关工作](../dp-puzzle.tex#L93) · [26 位实现](../dp-puzzle.tex#L137) · [Fused FP8 原文](../reference/fused-fp8.pdf) · [MMA-Sim v3](https://arxiv.org/html/2511.10909v3) · [Crafton 等的出版记录](https://doi.org/10.1109/DAC63849.2025.11132989) · [MX-Like](https://arxiv.org/html/2610.26083) |
| C09 | IV-A/B，[10]、[11]、[15]–[17]、[30]–[32] | IV-A 把 [10] 就近放到 `Qwen3-8B`，把 [31] 放到 `WikiText-2`。表 II 与表 IV 是不同的比较证据，保留外部设计对应的出处，特别是表 IV 各项原始 PPA。[32] 支撑工艺缩放工具，约 `3×` 是本文对 Ten-Four 两个全格式配置做的估算，结果应就近指向表或计算说明。若贡献段保留 MiniFloats 的具体效率比值，建议同时保留该处 [11] 与 `at reported conditions` 限定。[IV-A/B](../dp-puzzle.tex#L176) · [表 IV](../tables/related_ppa_native.tex) · [Qwen3 报告](https://arxiv.org/abs/2505.09388) · [WikiText 原文](https://arxiv.org/abs/1609.07843) · [工艺缩放记录](../../paper/data/process_normalization/comparison.json) |
| C10 | V-A/C，[37] 与图 3–4 | [37] 支持 NVIDIA GPU 在功耗上限触发频率受限的背景。把引文留在那个陈述内。固定 `f`、最大活跃核数、空闲漏电和 Eq. (2) 的功耗核算属于本文假设与算法。V-C 的散热讨论可停留在条件性推论，图 3–4 的出处是本文预算扫描与方法。若进一步陈述具体冷却设备或可持续功耗值，再引用相应外部数据。[功耗约束](../dp-puzzle.tex#L204) · [V-C](../dp-puzzle.tex#L224) · [NVML R535 时钟事件原因](https://docs.nvidia.com/deploy/archive/R535/nvml-api/group__nvmlClocksEventReasons.html) |

其余主要背景引文可保留。[12]–[14] 分别适合 BF16、NVFP4、HiF4 的格式特征。[15]、[16]、[18]–[20]、[22]、[23] 引用相应作者工作来说明资源共享、可组合乘法、精度分解或融合规约。描述具体机制时继续用原论文的算子范围。[格式段](../dp-puzzle.tex#L69) · [相关工作段](../dp-puzzle.tex#L93) · [NVFP4 原始说明](https://developer.nvidia.com/blog/introducing-nvfp4-for-efficient-and-accurate-low-precision-inference/) · [HiF4](https://arxiv.org/abs/2602.11287) · [MLSys 原文](https://proceedings.mlsys.org/paper_files/paper/2021/hash/e96c462898b47600c6f0b1c40979e8ca-Abstract.html) · [TransDot 原文](../reference/TransDot.pdf) · [MXDOTP 原文](../reference/mxdotp.pdf)

## Should-fix · 参考文献著录

| ID | 条目 | 建议 |
| --- | --- | --- |
| F01 | FPnew [17]、[21] | 同一工作同时列了期刊和预印本。II-C 的 configurable format slices 在期刊版已有说明。将该处 `mach2020fpnew` 换成 `mach2021fpnew` 后，全稿会只列期刊版。MiniFloat-NN [22] 和 MiniFloats [11] 对应机制和 PPA 的不同证据，按各自用法保留。[II-C](../dp-puzzle.tex#L93) · [FPnew 期刊版](https://doi.org/10.1109/TVLSI.2020.3044752) · [FPnew 预印本](https://arxiv.org/abs/2007.01530) |
| F02 | WikiText 原论文 [31]、FlashAttention-3 [39]、SageAttention3 [40] | [31] 现为 2016 arXiv 条目，建议用包含 WikiText 介绍的 ICLR 2017 正式版。[39]、[40] 可用 NeurIPS 2024 vol. 37 和 NeurIPS 2025 vol. 38 的正式条目，DOI 分别为 `10.52202/079017-2193`、`10.52202/085713-1799`。著录按各正式版本的作者顺序和题名。若实际依赖指定 arXiv 修订版的特有内容，注明版本及相关段落。[WikiText 原论文正式版](https://openreview.net/pdf?id=Byj72udxe) · [FlashAttention-3 正式条目](https://proceedings.neurips.cc/paper/2024/hash/7ede97c3e082c6df10a8d6103a2eebd2-Abstract-Conference.html) · [SageAttention3 正式条目](https://proceedings.neurips.cc/paper_files/paper/2025/hash/4db397e0f760cc573c681e81a01a3dba-Abstract-Conference.html) |
| F03 | 第 7 页 [29]、[33]、[34] | 成稿把 `TensorGauge`、`GEMM`、`AI` 印成 `Tensorgauge`、`gemm`、`ai`。BibTeX 用 `{TensorGauge}`、`{GEMM}`、`{AI}` 局部保护专名即可。[29] 的 DOI 仅存在于 `.bib` 的 `doi` 字段，现用样式未输出。核对出版社记录后，如保留 DOI，沿用库里已经能输出的链接 `note` 写法。会议名称建议统一用稿内 ARITH 条目采用的形式。[成稿第 7 页](../build/citation_audit_20261119/dp-puzzle.pdf#page=7) · [TensorGauge 条目](../references/references.bib#L21) |
| F04 | [8]、[34]、[35]、[37]、[41] | 著录类型跟随实际来源。[34]、[35] 的峰值依据是会议演示 PDF，建议注明 slides 并给可见链接或页码。当前 `archiveurl` 不出现在成稿。[37] 保留 R535 版本与小节，便于定位。[8] 区分技术报告与固定版本实现，见 C02。[41] 建议明示预印本性质与发布日期，具体数据引用见 C05。网站资料用原发布机构、页面题名、可访问 URL 及适用的访问日期。[参考文献库](../references/references.bib#L624) · [IEEE Reference Guide](https://edu.ieee.org/mx-udgvalles/wp-content/uploads/sites/121/IEEE-Reference-Guide.pdf) |

arXiv 条目可以保留所用版本。例如 Ten-Four [15] 的 `v3` 决定比较所用的配置和数据，先核对实验口径再更换版本。网站 URL 的正常跨栏内换行和 `[n]` 形式无需手工重排。[Ten-Four v3](https://arxiv.org/abs/2512.00053v3) · [成稿第 7 页](../build/citation_audit_20261119/dp-puzzle.pdf#page=7)

## 可删减或无需新增引用的位置

| 位置 | 审阅建议 |
| --- | --- |
| II-C 的 FPnew [21] | 依 F01 合并到 [17]，是最明确的精简项。 |
| V-A 的 Blackwell Technical Brief [33] | 若正文按 C03 由 [34] 给出每 SM 的量化依据，同一处可去掉 [33]。若继续使用技术简报，先核对实际 PDF 标题、版次和定位。 |
| 贡献第 2 点的 Qwen3 [10] | IV-A 已就地引 Qwen3 和 WikiText-2，贡献段可简写本研究的 workload-driven power estimates，模型来源保留在方法。贡献段中 MiniFloats 的具体外部对照仍按 C09 处理。 |
| 引言的 MX [7]、III-B 的 HiF4 [14] | 若引言只概括格式范围，可在 II-A 集中引用 [7]。III-B 若改成明确讲本设计怎样重编码和复用，且格式规则已在 II-A 交代，可省掉这处 [14]。直接复述格式定义或原作者机制时应就近保留。 |
| 引言的 TPU [9]、V-A 的 NVML [37] | 二者都支持一个外部背景实例。若相应背景句经作者确认删去，引用可随句删除。保留背景句时按 C07、C10 限定支持范围。 |
| Eq. (1) 的常规点积项、V-A 的核数约束和吞吐公式 | 常规乘加定义与本文推导只需解释符号、假设及输入。Eq. (1) 的 MX 块缩放定义仍用 [7]，V-A 的外部参数依据仍按 C03 归属。 |
| Fig. 1–4、表 III、摘要和结论中的本研究结果 | 自有架构、综合与功耗估算、trace 筛选和 GEMM 加速结论由本文方法、图表及可复现输出支撑。摘要和结论复述本研究 `1.15×` 结果时无需添加外部引文。Fig. 3–4 的输入 trace 仍按 C05 引用，表 I、II、IV 的外部数据各自保留来源。 |

## 待作者审阅

1. **960PR。** 请确认可用于投稿的三档峰值原始位置和格式口径，或批准把表内描述收敛到路线图已公开的信息。[C01 对应表项](../tables/vendor_ratios.tex#L25)
2. **第五章。** 请确认 A 的权重、激活和硬件速率映射，以及 B–E 的假设标注。FreeInference 可用正文的一个短句给出筛选字段和固定数据版本，完整版定位放可复现材料。[C02、C04、C05 对应段落](../dp-puzzle.tex#L212)
3. **引文整理。** 确认是否合并 FPnew、采用 WikiText 和两篇 attention 的正式版，以及采用上表的精简项。更新后按实际成稿复查参考文献条目与第 7 页容量。若某条与作者既有工作有关，按 DAC 盲审要求核对第三人称自引与重叠披露。[DAC 2027 盲审说明](https://dac.com/2027/program/research-manuscript-submissions)
