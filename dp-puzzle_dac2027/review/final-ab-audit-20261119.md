# DAC 2027 英文稿全文 A/B 审阅

审阅日期为 2026-11-19（新加坡时间）。以工作区独立英文稿及其编译 PDF 为准，稿件 SHA-256 为 `e8f362a70b53a466c9ed2c2454575121d83dfee570a5ebf59df786f8fcb246dd`。本轮按 `report-only` 执行 A1–A3、自检及 B0–B1，候选措辞和作者决策集中在本报告。表 I 沿用作者确认的 MXFP8、MXFP4 列名。[独立英文稿](../dp-puzzle.tex) · [审阅任务约定](../prompt.md)

**建议先确认三件事。** 摘要和结论应把 `1.15×` 绑定到图 4 的固定预算与加权方式。第五章还需交代按精度计时的模型范围和面积扫参的基准重标定。表 I 的 960PR 峰值和表 IV 的 `0:2:4` 更新数据需要作者定位原始证据。其余优先项集中在第三章的实现归属、功耗比较分母和图 1 的可读性。清单共 11 项 must-fix、12 项 should-fix 和 4 项 optional。

## A1–A3 与自检

- **A1。** 用 `pdftotext -layout` 和 `-bbox-layout` 重放 8 份、69 页语料的抽取与清洗。PDF 指纹均匹配，8 份均得到可用文本。重放产物留在独立审阅目录。[抽取摘要](../build/final_ab_audit_20261119/stage-a/extraction.log) · [语料指纹](../build/final_ab_audit_20261119/stage-a/skill/references/evidence/corpus-manifest.json)
- **A2。** 六类修辞部分的统计复现了 1,314 句、平均 22.329 词，以及 16.971% 的样本超过 30 词。本轮按句子是否有歧义、层次堆叠或重复筛选问题。沿用原语料的搭配、段首和比较句取样口径。[语料分析](../build/final_ab_audit_20261119/stage-a/skill/references/corpus-analysis.md)
- **A3 与自检。** 复核 24 条规则、60 条术语及 112 条归一化的本地引文。固定种子抽中的 A03、R07、R11、R03、R02 均可在新抽取中复现。表层扫描命中 0 条，下文的问题来自逐句阅读、成稿检查与源数据核验。厂商数据、模型迁移和真实请求加权仍需各自用一手规格或项目冻结记录裁决。[自检结果](../build/final_ab_audit_20261119/stage-a/self-check.json) · [项目写作规范](../skills/dp-puzzle-en-writing/SKILL.md)

## B0 基线

命令为 `latexmk -g -pdf -interaction=nonstopmode -halt-on-error -outdir=build/final_ab_audit_20261119 dp-puzzle.tex`，退出码为 0。终轮无越界、未定义引用或页数告警。输入指纹包含当前正文、五张表、四张插图、BibTeX、模板及编译配置。[编译日志](../build/final_ab_audit_20261119/baseline-build.log) · [退出码](../build/final_ab_audit_20261119/baseline.exit) · [输入指纹](../build/final_ab_audit_20261119/inputs.sha256)

| 核验项 | 当前结果 |
| --- | --- |
| 版面与盲审 | Letter、IEEEtran conference 10 pt 双栏，正文 6 页，第 7 页为 41 条参考文献，PDF `Author` 为空。摘要按连字符术语和配比各计一词，约 96 词。第 6 页已含 AI 披露，终稿署名和致谢的空间需用最终模板另行复核。[成稿](../build/final_ab_audit_20261119/dp-puzzle.pdf) · [DAC 2027 投稿规则](https://dac.com/2027/program/research-manuscript-submissions) |
| 图、表与引用 | 四张图、五张表均能定位，图注在下、表题在上，41 个参考文献链接目标均在第 7 页。图 1 局部小字、图 2 比较分母和图 3 区间评分最值得处理，见 S06–S08。[成稿版面文本](../build/final_ab_audit_20261119/manuscript-layout.txt) · [字体清单](../build/final_ab_audit_20261119/fonts.txt) |
| 上轮已解决 | 2022 MiniFloat-NN/ExSdotp 用于机制，2024 MiniFloats wDot FPU 用于表 II、表 IV 和 PPA 对比。图 2 三档功耗共用右轴，表 III 的 `T2H4Q8E16` 与正文一致。引言已定义 LLM、MoE 和 GEMM，III-A 将 T/H/Q/E 明确为浮点类别，INT8 单独说明。[II-C](../dp-puzzle.tex#L93) · [III-A](../dp-puzzle.tex#L118) · [IV-B](../dp-puzzle.tex#L182) |

## B1 术语与范围核对

| 核心概念 | 摘要、关键词、正文及图表的用法 | 裁决 |
| --- | --- | --- |
| 结构 | 摘要和关键词 `dot-product units`，III 首现 `dot-product unit (DP)`，随后 `DPs`、`Lane`、`Group` | 对应清楚。`DP array`、`compute core` 和 `chip` 指不同层级，V-A 应保留。统一 `stand-alone` 与 `standalone` 属可选。 |
| 峰值配比 | 摘要 `BF16:MXFP8:MXFP4 peak throughput ratios`，关键词 `throughput ratios`。引言另用 `BF16:FP8:FP4`，表 III 和图 2 用 `H:Q:E` | 位宽家族可用于背景，本文实际设计点用 MX 格式或已定义的 H/Q/E。表 I 保持现列名，可在表注交代 Rubin 对应 NVFP4 与按位宽归类的口径。 |
| 精度与编码 | `FP8/FP4`、`MXFP8/6/4`、`NVFP4`、`HiF4`、`S1P2`、`31-bit unsigned magnitude` | 格式名拼写稳定。表 V 的 FP8/FP4 是场景标签，硬件速率映射见 M04。`S1P2` 已明示符号位和幅值位。若后续改用 `Q1.2`，需保留符号–幅值编码的限定。 |
| 负载与算子 | 摘要 `Large language models`、`GEMM`，关键词 `LLMs`，正文已独立展开 LLM/GEMM。表 V 用 `SWA/CSA`、`QK/PV` | 摘要单次使用 GEMM 可直接写 `matrix-multiplication compute speedup`。表 V 展开注意力名并定义同一组算子。`K` 作为 dot-product 长度与请求 token 的 `1K–1M` 各有明确范围。 |
| 面积与功耗 | `synthesized area`、`estimated total power`、`maximum estimated power`、`array power budget` | 前三项分别为综合 DP 面积、活动模式估计和三模式最大值。系统预算覆盖 DP 阵列，限定词应贯穿贡献、图注和结论。体例 `12\,nm`、`1\,GHz`、`$1.15\times$` 已一致。 |
| 时间与权重 | `GEMM compute latency`、`mean GEMM time`、`modeled GEMM speedup`、`trace-weighted` | 统一指计算模型。图 3 按实长、图 4 按上界分桶，五场景等权独立于请求频率。`baseline/reference budgets` 对应 `α=0.327, β=1`，比较共用上限。 |

## Must-fix

### 模型与结论

| ID 与位置 | 问题、证据和候选修改 |
| --- | --- |
| M01 · [摘要 L38](../dp-puzzle.tex#L38)、[贡献 3 L57](../dp-puzzle.tex#L57)、[V-C L235](../dp-puzzle.tex#L235)、[结论 L243](../dp-puzzle.tex#L243) | **明确 `1.15×` 对应的实验与评分。** `Across all five scenarios` 容易被读成 `1:4:8` 五场景分别获胜。图 4 在参考预算、11 个长度上界按请求频率加权、A–E 等权时的整体速度比为 1.145448，五个单场景各有别的最优配比。实际长度在同预算计算得 1.137242，综合最优配比相同。V-C 可写 `Using the request bins of Fig. 4 at the reference budgets, 1:4:8 minimizes mean GEMM time across the five equally weighted scenarios (1.15× versus 1:2:4).` 摘要和结论保留 `reference budgets`、`trace-weighted` 和 `compute-only` 中可消除歧义的限定，详见 Q01。R09、R11、R12。[图 4 输出](../../paper/data/new_chip_ds_model/budget_study/trace_case_preview/upper_edge_lengths.csv) · [实际长度评分](../../paper/data/new_chip_ds_model/results/scores.csv) |
| M02 · [V-C L234–235](../dp-puzzle.tex#L234) | **场景 E 的归因涵盖两个算子组。** 标题只说主注意力切到 FP4，D→E 同时迁移 grouped O-down。改为 `Moving main attention and grouped O-down to FP4 favors wider FP4 datapaths.` 将末句也限定在该联合迁移。17.3% 和 21.4% 是 E 场景相对 `1:4:8` 的结果，可保留。R08、R10。[场景映射](../../paper/scripts/v41_core.py#L23) · [图 4 输出](../../paper/data/new_chip_ds_model/budget_study/trace_case_preview/upper_edge_lengths.csv) |
| M03 · [V-A L202](../dp-puzzle.tex#L202) | **面积预算按每个 `α` 重标定。** `held at their baseline values` 容易被读成扫参过程中绝对面积与单核外围面积始终固定。代码对每个 `α` 用 36 个基线 core 标定共同预算，在给定 `α` 下各配比共用该预算和单 core 外围面积。保留原公式，补 `At each α, we calibrate the area budget to 36 baseline cores and use the same peripheral area per core across ratios.` R08、R11。[面积模型](../../paper/scripts/hardware_cost.py#L76) |
| M04 · [引言 L48](../dp-puzzle.tex#L48)、[V-B L212–215](../dp-puzzle.tex#L212) | **交代 W4A8 的模型归类与计时边界。** `uses FP8 for MoE computations` 和 `execute at the FP8 rate` 混合了权重、激活及硬件速率。DP 接口要求 A/B 元素格式匹配。可写 `In A, we charge routed-expert GEMMs with FP4 weights and FP8 activations to MXFP8 compute capacity.` 再说明按 BF16、MXFP8、MXFP4 算力分别对三个模式的 GEMM 计时，FP32 工作单列。保留满利用率与供数充足假设，交代格式转换和端到端开销的范围。FreeInference 提供 `step=0` 的输入长度分布，计算量取自 DeepSeek 模型账本。R08、R11、R12。[DP 接口](../../src/spec/dp/dptop/interface.md#L72) · [计时映射](../../paper/scripts/v41_core.py#L37) · [Trace 来源](../../paper/data/new_chip_ds_model/traces/README.md) |

### 架构、实验来源与投稿项

| ID 与位置 | 问题、证据和候选修改 |
| --- | --- |
| M05 · [II-B L86](../dp-puzzle.tex#L86)、[III-B L139](../dp-puzzle.tex#L139) | **有效尺度定义缺一环。** Eq. (1) 给出 `X̃_j = X_j` 后未定义 `X_j`。可补 `For MX, X_j is the block scale decoded for the corresponding input.` II-A 介绍 NVFP4 的每块 E4M3 与全张量 FP32 尺度，接口只给每块 E4M3。请确认 FP32 tensor scale 的处理位置后再说明有效尺度与 RTL 的关系，见 Q02。R02、R08。[接口与尺度](../../src/spec/dp/dptop/layout-and-scales.md) · [OCP MX v1.0](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf) |
| M06 · [III-C L144](../dp-puzzle.tex#L144) | **Q8 的缩放尾数乘法归属。** `Each Lane ... omits ... scale mantissa multiplication` 把 Group 缩放写进 Lane。建议 `Each Lane in a Q8 Group uses four 4×4 multipliers and omits E decoding and micro-exponent handling. The Group applies its block scale by exponent adjustment.` QE 的上一句已正确把这项运算归给 Group。R02。[Q8 Group 规格](../../src/spec/dp/group/dp_group_q.md#L5) |
| M07 · [III-D L158](../dp-puzzle.tex#L158) | **区分使能、数值参与和特殊值归约。** `Active Groups participate in global exponent selection` 漏有限非零条件。建议 `Global exponent selection uses the finite, nonzero partial sums of participating Groups.` 保留后文对非参与 Group 和特殊值的说明。R02、R08。[扩展后端规格](../../src/spec/dp/dptop/qe192-qe256-expansion.md) |
| M08 · [贡献 2 L56](../dp-puzzle.tex#L56)、[IV-A L176](../dp-puzzle.tex#L176) | **限制最高功耗的模式集合。** 当前 `highest-power mode in every evaluated design that expands its throughput` 未说功耗来自 BF16、MXFP8 E4M3、MXFP4 E2M1 三档。可写 `Among the three profiled modes, MXFP8 has the highest estimated power in every MXFP8-expanded design.` 前一句的 `about half the added area` 以两设计相对基线的面积增量作分母，39% 以联合翻倍设计的最大模式功耗作分母，复算分别为 49.26% 与 38.88%。R09、R11。[冻结面积与功耗](../../paper/data/DP_area_power/dp11_area_power_fixed_20261116.csv) |
| M09 · [表 IV](../tables/related_ppa_native.tex#L17)、[IV-A/B L176、L184](../dp-puzzle.tex#L184) | **补 `0:2:4` 的配套实现回执。** 表 IV 使用作者更新的面积 `9,762.99 µm²` 和 FP8/FP4 功耗 `12.236951/9.189959 mW`，当前两份来源记录的 run ID 均为空。绘图所用冻结数据表另存一组 Q32E64 数值。现表的收益可复算，请确认面积与功耗对应同一 RTL、PVT 与工况，并在方法标明 `0:2:4` 的独立来源。九个配比中两种 QE 档使用保留的历史 PPA 摘要，现有原始重放依赖缺口也宜由作者确认，见 Q03。R09、R11。[面积更新](../../paper/data/evidence/related_native_dc_area_20261117/author_area.json) · [功耗更新](../../paper/data/evidence/related_native_power_update_20261117/author_power.json) · [九档数据来源](../../paper/data/DP_area_power/dp11_area_power_fixed_20261116.sources.json) |
| M10 · [表 I 的 960PR](../tables/vendor_ratios.tex#L25) | **三档峰值需可定位的公开出处。** `1.000 / 2.000 / 8.000` 的现有 keynote 在参考库中用于路线图时间。请给原始页、时间戳或规格，验证格式和 dense 峰值口径。若公开出处只覆盖路线图，表项和 II-D 的解读需随出处调整，见 Q04。R09、R11。[已有来源核验 C01](citation-audit-20261119.md) · [参考库的来源备注](../references/references.bib#L176) |
| M11 · [AI 披露 L247–248](../dp-puzzle.tex#L247) | **由作者校对具体模型与生成范围。** 现有标题正确，文字已说明 Codex 协助 RTL、EDA、分析和 IV/V 绘图。按 DAC 规则，用实际记录标识相关 LLM、生成内容或涉及章节，以及参与程度。请核实当前稿件中的生成代码、图和正文各有哪些，分别处理只做润色或翻译的操作，见 Q05。[DAC 2027 AI 披露政策](https://dac.com/2027/program/research-manuscript-submissions) |

## Should-fix

| ID 与位置 | 最小改法与依据 |
| --- | --- |
| S01 · [引言 L48–52](../dp-puzzle.tex#L48) | 开篇与 L48 末句重复“一个模型包含多种精度”，L50 又以相同动机开头。保留 DeepSeek 的具体算子差异，末句转为 `This mix makes peak throughput allocation across formats a hardware design choice.` L50 将供数假设限定为 `a fixed element-payload width`，使其明确是在引出 `1:2:4` 的直观设计基准。L52 将“阵列配比由 DP 配比决定”限定到本文由相同 DP 组成的阵列。R01、R07、R08、R13。 |
| S02 · [II-C L93–97](../dp-puzzle.tex#L93)、[V-A L202](../dp-puzzle.tex#L202) | 对齐引用与断言。FPnew 的 [21] 预印本可合并到已用的 [17] 期刊版，MiniFloat 两条引用已有明确分工。把 `neither addresses throughput-ratio selection` 收敛为说明已有工作讨论的格式与 MAC 组织，然后点明本文比较联合预算下的峰值配额。V-A 用 `D=256` 推得基线 4,096 BF16 MAC/cycle，接着分别引用 Blackwell dense BF16 和 DaVinci Max 的 FP16 比较粒度。`N₀=36` 与独立来源的 `α=0.327` 各自就地归属。R08、R11、R12。[引用核验 C03、F01](citation-audit-20261119.md) |
| S03 · [II-D L105](../dp-puzzle.tex#L105) | 一段枚举全部九档，表 III 完整重复。保留 `1:2:6`、`1:4:8`、`1:2:8` 的厂商动机，五档扩展用 `We add five configurations to isolate and combine FP8 and FP4 expansion costs (Table III).` 段尾目标句与引言 L52 相同，可省一处。R01、R07、R13。[表 III](../tables/group_compositions.tex) |
| S04 · [III-B/C L133、L146](../dp-puzzle.tex#L133) | HiF4 可用 `the micro-exponent shared by four elements` 与 `the micro-exponent shared by eight elements` 替代 first/second，和图 1 的共享粒度对应。`14-bit ... down from 31 bits` 可改成 E16 直接输出 14 位 Lane 和，基线把相同 E 路 Lane 和嵌入 31 位共享容器，以免读者理解为丢失 17 位计算精度。R02、R08、R12。[HiF4 原文](https://arxiv.org/html/2602.11287v1) · [基线规格](../../src/spec/dp/dptop/dp-top-v1.8.md) |
| S05 · [IV-A L176](../dp-puzzle.tex#L176) | 复现实验的最小补充是 DP 原生长度与活动窗口。已确认的同一评测批次可写 `For each profiled mode, we issue 1,024 native-length vectors and estimate power from the central 512-cycle gate-level activity window.` 若加验证覆盖率，可给功能回归对象、独立参考和通过口径。现稿 `before clock-tree synthesis and place-and-route` 应随功耗限定保留。R09、R11。[评测复核](../../paper/data/evidence/evaluation_methods_20261117/review.json) |
| S06 · [图 1 L128–129](../dp-puzzle.tex#L128) | **成稿可读性。** 原图宽约 585 PDF pt，缩到 252 TeX pt 单栏后，`S9`、`U8`、`S10` 局部标签约 3 pt，`Sign XOR` 约 4 pt，字体为 Arial。建议作者从矢量源按单栏尺寸重排，保留 Lane、Group、DP 数据流及共享对齐接口，压缩过密的旁路位宽标记。图 3/4 的主要数字接近 10 pt。此处按项目作图约定评估。[成稿第 3 页](../build/final_ab_audit_20261119/dp-puzzle.pdf#page=3) · [项目作图规范](../../.skill/dac2027_picture_skill/SKILL.md) |
| S07 · [图 2 L168](../dp-puzzle.tex#L168) | 首句用 `Synthesized area and estimated total power across the evaluated ratios.` 将最后一句改为 `Power-bar labels are normalized to the outlined baseline MXFP8 bar.` 面积倍率已在前句给出分母。当前柱内标签约 7–8 pt 且使用 STIXGeneral，与项目的 10 pt Nimbus Roman 目标有差异，是否调整由作者决定。R09、R11、R16。[绘图口径](../../paper/data/DP_area_power/README.md) · [成稿第 5 页](../build/final_ab_audit_20261119/dp-puzzle.pdf#page=5) |
| S08 · [图 3 L221](../dp-puzzle.tex#L221)、[V-C L225](../dp-puzzle.tex#L225) | **区分获胜份额和区间平均用时。** 最低功耗档的 25 个 `α` 格按获胜份额都选 `1:4:8`，格内份额约 61.90%–97.81%。固定 `α=0.327` 的 `[1.3,1.4)` 档中，`1:6:12` 在约 66.41% 的范围内领先，按整个档的平均用时则 `1:8:16` 略优。可用 `Shading identifies the ratio with the largest winning share in each band. Dots show the baseline-to-selected ratio of band-mean times.` 说明 `±10%` 是相对 `α=0.327` 的扰动，将 `β≥1.4` 的结论就地限定在该切片。R09、R16。[分档方法](../../paper/data/new_chip_ds_model/budget_study/bin_budgets.py) · [切片结果](../../paper/data/new_chip_ds_model/budget_study/reference_bands.csv) |
| S09 · [表 V 原表注](../tables/five_stage_migrations.tex#L16)、[V-B/V-C](../dp-puzzle.tex#L212) | 用 `Scenario` 对应 A–E。表注展开 `sliding-window attention (SWA)` 与 `Compressed Sparse Attention 2 (CSA2)`，说明 Main QK/PV 含两者。`Experts include gate/up/down` 可写 `Expert GEMMs include gate, up, and down projections.` 图 4 图注可用 `Reference-budget prefill (α=0.327, β=1).` 开头，在 (b) 交代请求加权速度比。保留 (a)/(b)、基线、All 和边框含义。R14、R16。[模型说明](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash/blob/main/README.md) · [成稿第 6 页](../build/final_ab_audit_20261119/dp-puzzle.pdf#page=6) |
| S10 · [IV-B L182–184](../dp-puzzle.tex#L182)、[表 IV](../tables/related_ppa_native.tex) | 表注给 Ten-Four 的两组数据按 Q8/Q16 排列。正文 `approximately 3×` 显式绑定 `using the 14 nm proxy`，表 IV 展示原工艺点。保留 MiniFloats 2024 的 `standalone wDot` 范围。把 `Under the original-node comparison` 改成 `At the reported operating points`，并说明面积、能效分别用峰值吞吐除以各自所列面积、各自报告功耗。R09、R10、R11。[归一化计算](../../paper/data/process_normalization/comparison.json) |
| S11 · [贡献 3 L57](../dp-puzzle.tex#L57)、[V-C L225](../dp-puzzle.tex#L225)、[结论 L243](../dp-puzzle.tex#L243) | 功耗瓶颈与放宽条件重复。贡献 3 聚焦面积限制物理核数、功耗限制活跃核数和参考点结果。V-C 保留 `1:8:16` 的活跃核数量化和扫参证据。散热仅在 V-C 留一句条件性解释，或删该句腾篇幅。结论可说 `the DP-array power cap constrained low-precision expansion over the budgets studied`，将适用面绑定到单模型与约束。R11、R12、R13。[模型范围](../../paper/data/new_chip_ds_model/README.md) |
| S12 · [III-B L137](../dp-puzzle.tex#L137)、[参考文献页](../build/final_ab_audit_20261119/dp-puzzle.pdf#page=7) | 将 TensorGauge、MMA-Sim 对位宽和舍入的背景与本文 `26 fractional bits`、右移向零截断的实现决定分句。若主张某 Blackwell 模式同为 26 位，需要指向相应实验。第 7 页 `Tensorgauge`、`gemm` 有大小写丢失，改 BibTeX 时保护 `{TensorGauge}`、`{GEMM}`。后续采用的正式出版条目和 DOI 建议沿用引用专审 F02–F04。R08、R11。[引用专审 C08、F02–F04](citation-audit-20261119.md) |

## Optional

| ID 与位置 | 建议 |
| --- | --- |
| O01 · [摘要 L38](../dp-puzzle.tex#L38)、[引言 L50](../dp-puzzle.tex#L50) | 芯片设计周期与模型更迭的对比在引言已有完整逻辑，摘要可用一句串起固定配比与工作负载演变，将省出的词留给 M01 的加权口径。`GEMM` 在摘要仅用一次时可直接展开。R01、R13、R14。 |
| O02 · [IV-C L189–193](../dp-puzzle.tex#L189) | 将三段保留为“共享面积收益”“FP4-only 的功耗代价”“联合扩展时功耗增速”。最后一段 `1:4:8` 两个倍率前文已给，可将并列倍率交给图 2，仅解释扩展最大档的 37.79% 面效和 13.78% 功率密度。需作者选择数字详略。R07、R09、R13。 |
| O03 · [表 II 标题](../tables/related_features.tex#L5)、[表 V 标题](../tables/five_stage_migrations.tex#L5)、[IV-B 标题](../dp-puzzle.tex#L178) | 源文件标题统一 sentence case 和末尾标点即可。IV-B 同时讨论基线和 `0:2:4`，可短为 `Comparison with Prior Multi-Precision Units`。IEEEtran 成稿的大小写样式由模板处理。 |
| O04 · [V-B L215](../dp-puzzle.tex#L215)、[V-C L225](../dp-puzzle.tex#L225) | 可在复现材料明示 `1M=1024K` 与 FreeInference 固定 revision。若作者希望主文说明精确切换，将 `β` 的点边界与图 3 的 0.1 档分开交代，使用 `switches.csv` 固定切片。其中首次实际长度切换约为 `β=1.08613`，与已绘色带的起止点各有口径。R09、R15。[Trace 清单](../../paper/data/new_chip_ds_model/traces/trace_manifest.json) · [精确切片边界](../../paper/data/new_chip_ds_model/budget_study/switches.csv) |

## 需作者决策

1. **Q01 · 选定摘要主数字（M01）。** A 保留图 4 的 `1.15×` 并写明参考预算、分桶和五场景综合。B 采用同预算实际长度评分，并联动正文与相应图注。建议 A，与当前主图及冻结数字一致。
2. **Q02 · NVFP4 tensor scale（M05）。** A 确认 FP32 tensor scale 由 DP 外部应用，正文交代 DP 处理块 scale。B 如 DP 内也含相应计算，给出路径与端口后明确两级 scale。建议先按现有 E4M3 块尺度接口检查 A。
3. **Q03 · `0:2:4` 及历史 QE 证据（M09）。** A 给 `0:2:4` 对应的 RTL、面积与功耗回执和两项 QE 历史数据索引，在方法标注。B 若只确认作者汇总数，明确是单独的更新数据及适用范围，并缩窄强比较。建议 A。
4. **Q04 · 960PR（M10）。** A 补三档峰值可公开核验的定位。B 保留能以公开资料确认的路线图信息，并据此调整 II-D 举例。建议有可用原始出处时选 A。
5. **Q05 · AI 披露（M11）。** A 提供实际模型标识和稿件所用生成内容的记录，补齐具体章节与程度。B 模型标识只能由服务记录确认时，按可追溯标识和实际生成范围拟稿，交作者核对。建议 A，模型信息按实际记录填入。
6. **Q06 · 图 1（S06）。** A 用作者矢量源压缩路径说明并适配单栏。B 试双栏，核查面积功耗与模型两组图的流动及 6 页上限。建议先 A。
