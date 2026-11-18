# DAC 2027 Must-fix / Should-fix 逐项确认

本轮以当前工作区稿件为基线。正文基线 SHA-256 为 `f694ae3704eddd6ca98eb7a6178491255fcf7435e66a700f16c9cd3a5fe4ac0f`。以下为待确认稿的实际措辞，原文保留了作者当时暂存的内容。编号沿用全文 A/B 审阅报告。[全文审阅报告](final-ab-audit-20261119.md)

**确认方式。** 逐项回复 `M01 保留`、`M01 恢复原文` 或 `M01 改为 …`。同一项有多个位置时，可单独指定 `M01.1` 等子编号。待补证据的事项可以先确认措辞，再补相应出处。M10 和 S06 的可选方案见该项。

审阅稿纳入 **21 项**的可核验改法。M10 和 S06 等待出处或图源。原稿和审阅稿均编译通过，为正文 6 页、参考文献 1 页。审阅稿摘要约 98 词。S02 合并一条 FPnew 预印本引文后，审阅稿有 40 条参考文献。下列原文和改后引文编号使用各自编译版本。[审阅 PDF](../build/ab_author_review_20261119/compiled/dp-puzzle.pdf) · [源稿 diff](../build/ab_author_review_20261119/draft.diff) · [审阅稿编译日志](../build/ab_author_review_20261119/draft-build.log)

## Must-fix

### M01 · 1.15× 的适用范围

沿用图 4 的固定预算结果。四处明确 1.15× 对应请求长度分桶加权和五场景等权综合。参考预算为 α=0.327、β=1。

**M01.1** [dp-puzzle.tex L38](../dp-puzzle.tex#L38)

> **原文** Under baseline area and power budgets, 1:4:8 offers a balanced choice across five DeepSeek-V4.1-Flash prefill scenarios, yielding a modeled 1.15× GEMM speedup over 1:2:4.
>
> **审阅稿** At the reference budgets, 1:4:8 yields a modeled 1.15× GEMM speedup over 1:2:4 for DeepSeek-V4.1-Flash prefill, using request-weighted length bins and five equally weighted scenarios.

**M01.2** [dp-puzzle.tex L57](../dp-puzzle.tex#L57)

> **原文** With baseline area and power budgets, 1:4:8 minimizes trace-weighted mean GEMM time (1.15× modeled speedup over 1:2:4).
>
> **审阅稿** At the reference budgets, 1:4:8 minimizes the request-weighted mean GEMM time across five equally weighted scenarios (1.15× over 1:2:4).

**M01.3** [dp-puzzle.tex L235](../dp-puzzle.tex#L235)

> **原文** Across all five scenarios, 1:4:8 yields the lowest mean GEMM time and a 1.15× modeled speedup over 1:2:4 (Fig. 4(b)).
>
> **审阅稿** At the reference budgets, 1:4:8 minimizes mean GEMM time over the five equally weighted scenarios, using the request bins in Fig. 4(b). This yields a modeled 1.15× speedup over 1:2:4.

**M01.4** [dp-puzzle.tex L243](../dp-puzzle.tex#L243)

> **原文** At matched area and power, 1:4:8 gives the best overall result across five DeepSeek-V4.1-Flash prefill scenarios, with a modeled GEMM speedup of 1.15× over 1:2:4.
>
> **审阅稿** At the reference budgets, 1:4:8 yields a modeled 1.15× GEMM speedup over 1:2:4 for DeepSeek-V4.1-Flash prefill, based on request-weighted length bins and five equally weighted scenarios.

### M02 · 场景 E 的算子归因

D 到 E 同时迁移主注意力和 grouped O-down。小标题写清两者，段末由 E 场景数字直接支撑。

**M02.1** [dp-puzzle.tex L234](../dp-puzzle.tex#L234)

> **原文** Moving main attention to FP4 shifts the advantage from balanced FP8/FP4 expansion to wider FP4 datapaths.
>
> **审阅稿** Moving main attention and grouped O-down to FP4 favors wider FP4 datapaths.

**M02.2** [dp-puzzle.tex L235](../dp-puzzle.tex#L235)

> **原文** Wider FP4 datapaths thus become attractive when FP4 attention is common in the target workload.
>
> **审阅稿** 删去该句。

### M03 · 不同 α 下如何定面积预算

面积预算在每个 α 处按 N₀ 个基准核心重新标定。同一 α 下各配比共用预算与单核外围面积。

**M03.1** [dp-puzzle.tex L202](../dp-puzzle.tex#L202)

> **原文** With the total area budget and peripheral area per core held at their baseline values, the chip accommodates Nⱼ=⌊N₀/[1+α(rⱼ-1)]⌋ cores of design j, where rⱼ is its DP area relative to baseline.
>
> **审阅稿** At each α, we size the area budget for N₀ baseline cores and use the same peripheral area per core across ratios. The chip accommodates Nⱼ=⌊N₀/[1+α(rⱼ-1)]⌋ cores of design j, where rⱼ is its DP area relative to baseline.

### M04 · W4A8 归类与计时范围

明确 FP4 权重与 FP8 激活属于模型负载描述，场景 A 把计算量计入 MXFP8 峰值。FreeInference 提供长度，GEMM 计时排除 FP32 工作和格式转换。

**M04.1** [dp-puzzle.tex L48](../dp-puzzle.tex#L48)

> **原文** For example, DeepSeek-V4.1-Flash [8] uses FP8 for mixture-of-experts (MoE) computations and most attention projections.
>
> **审阅稿** In DeepSeek-V4.1-Flash [8], routed mixture-of-experts (MoE) computations use FP4 weights and FP8 activations. Most attention projections use FP8.

**M04.2** [dp-puzzle.tex L212](../dp-puzzle.tex#L212)

> **原文** In A, routed experts use FP4 weights and FP8 activations and execute at the FP8 rate.
>
> **审阅稿** In scenario A, we assign routed-expert GEMMs with FP4 weights and FP8 activations to MXFP8 capacity.

**M04.3** [dp-puzzle.tex L215](../dp-puzzle.tex#L215)

> **原文** We use 2,047 first requests from FreeInference agent sessions (Aug. 30–Sept. 5, 2026) [41].
>
> **审阅稿** We take input lengths from 2,047 first requests in FreeInference agent sessions (Aug. 30–Sept. 5, 2026) [40].

**M04.4** [dp-puzzle.tex L215](../dp-puzzle.tex#L215)

> **原文** In both experiments, modeled time sums each mode's FLOPs divided by C_{j,p}, assuming full utilization and sufficient bandwidth.
>
> **审阅稿** We map FP8 and FP4 work to MXFP8 and MXFP4 capacity. Modeled time sums each mode's FLOPs divided by C_{j,p} at full utilization and sufficient bandwidth, excluding FP32 work and format conversion.

### M05 · 块尺度的定义和 NVFP4 接口

定义公式中的 Xⱼ，并注明 NVFP4 Group 使用两侧输入的 E4M3 块尺度。**待确认** FP32 tensor scale 的实际应用位置。若确认由上游或下游处理，再写明位置。[接口核验](../../src/spec/dp/dptop/layout-and-scales.md)

**M05.1** [dp-puzzle.tex L86](../dp-puzzle.tex#L86)

> **原文** The term q_j is the dot product within block j, and X̃ⱼ is its effective scale.
>
> **审阅稿** The term q_j is the dot product within block j, and X̃ⱼ is the corresponding input's effective scale.

**M05.2** [dp-puzzle.tex L86](../dp-puzzle.tex#L86)

> **原文** For MX formats, X̃ⱼ=Xⱼ.
>
> **审阅稿** For MX formats, X̃ⱼ=Xⱼ, where Xⱼ is the decoded block scale.

**M05.3** [dp-puzzle.tex L139](../dp-puzzle.tex#L139)

> **原文** One Group covers a 16-element NVFP4 block, and multiple Groups share a scale for larger blocks.
>
> **审阅稿** Each NVFP4 Group uses the supplied E4M3 scales of its two 16-element operand blocks. Multiple Groups share a scale for larger blocks.

### M06 · Q8 的 Lane 与 Group

Lane 有四个乘法器并省去 E 前端操作，块尺度由 Group 通过指数调整施加。

**M06.1** [dp-puzzle.tex L144](../dp-puzzle.tex#L144)

> **原文** Each Lane in a Q8 Group requires only four 4×4 multipliers and omits E decoding, micro-exponent handling, and scale mantissa multiplication.
>
> **审阅稿** Each Q8 Lane uses four 4×4 multipliers and omits E decoding and micro-exponent handling. The Group applies block scaling by exponent adjustment.

### M07 · 全局指数选择

以参与且部分和有限、非零的 Group 确定指数，保留后文对特殊值归约的说明。

**M07.1** [dp-puzzle.tex L158](../dp-puzzle.tex#L158)

> **原文** Active Groups participate in global exponent selection and apply scales at the original block boundaries.
>
> **审阅稿** Participating Groups apply scales at the original block boundaries. Their finite, nonzero partial sums contribute to global exponent selection.

### M08 · 最高功耗的比较集合

限定为三个被评估的模式和扩展了 MXFP8 吞吐的设计。

**M08.1** [dp-puzzle.tex L56](../dp-puzzle.tex#L56)

> **原文** MXFP8 is the highest-power mode in every evaluated design that expands its throughput.
>
> **审阅稿** Among the three profiled modes, MXFP8 has the highest estimated power in every design with expanded MXFP8 throughput.

### M09 · 历史 QE 扩展和 0:2:4 的来源

说明两档最大联合扩展的历史摘要，以及独立 0:2:4 的面积、功耗来源。**待确认** 0:2:4 的 RTL、PVT 和对应 run/export ID。倍率继续以表 IV 数据为基准。[面积更新](../../paper/data/evidence/related_native_dc_area_20261117/author_area.json) · [功耗更新](../../paper/data/evidence/related_native_power_update_20261117/author_power.json)

**M09.1** [dp-puzzle.tex L176](../dp-puzzle.tex#L176)

> **原文** The designs meet timing and electrical constraints.
>
> **审阅稿** The designs meet timing and electrical constraints. The two largest joint expansions use archived synthesis and power summaries.

**M09.2** [dp-puzzle.tex L184](../dp-puzzle.tex#L184)

> **原文** Under the original-node comparison, the 0:2:4 low-precision unit achieves 5.26×/2.68× the area/energy efficiency of MPICC at FP8 and 2.63×/2.35× at FP4.
>
> **审阅稿** Using separately reported area and power estimates, the 0:2:4 unit achieves 5.26×/2.68× the area/energy efficiency of MPICC at FP8 and 2.63×/2.35× at FP4.

### M10 · 960PR 的表 I 出处

华为公开 keynote 给出 960PR 的 Q3 2027 计划。完整 BF16/MXFP8/MXFP4 的单设备 dense 口径仍待规格。审阅稿保留当前表项供对照，替代写法见下。表 I 的 MX 列名沿用作者决定。[华为 keynote](https://www.huawei.com/en/news/2026/9/hc-wang-keynote)

**M10.A** 补三档单设备 dense 峰值的公开规格或幻灯片，数值核对后保留表项。已有 [6] 可继续支持发布时间。

**M10.B** 按目前可核验的内容保留路线图。把 960PR 的四个数值/配比单元格换成横线，表注候选为 `† Ascend 960PR is a roadmap target for Q3 2027.` II-D 已将 1:2:8 写成本研究的候选配置。[表 I 原行](../tables/vendor_ratios.tex#L25)

### M11 · AI 辅助范围的披露

把 RTL、EDA 工作与 IV/V 的分析作图写成两句。**待确认** 实际使用的模型标识，以及最终稿纳入的生成文本、代码和图。具体用法按记录填写。[DAC 2027 AI 披露要求](https://dac.com/2027/program/research-manuscript-submissions)

**M11.1** [dp-puzzle.tex L248](../dp-puzzle.tex#L248)

> **原文** OpenAI Codex assisted with RTL optimization and testing, EDA script generation, data analysis, and plotting in Sections IV and V.
>
> **审阅稿** OpenAI Codex assisted with RTL optimization, RTL testing, and EDA script generation. It also assisted with data analysis and plotting for Sections IV and V.

## Should-fix

### S01 · 精简引言的混合精度动机

保留 DeepSeek 的算子实例，缩短重复动机。固定输入有效载荷和相同 DP 构成阵列分别是两个推导的适用条件。

**S01.1** [dp-puzzle.tex L48](../dp-puzzle.tex#L48)

> **原文** Inference in large language models (LLMs) involves mixed-precision computation within a single model. Operators use numerical formats according to their accuracy requirements.
>
> **审阅稿** Inference in large language models (LLMs) mixes precisions across operators according to their accuracy requirements.

**S01.2** [dp-puzzle.tex L48](../dp-puzzle.tex#L48)

> **原文** This operator-level mix of precisions requires inference hardware to efficiently support multiple numerical formats, including emerging low-precision formats, within the same workload.
>
> **审阅稿** This mix makes peak throughput allocation across formats a hardware design choice.

**S01.3** [dp-puzzle.tex L50](../dp-puzzle.tex#L50)

> **原文** Supporting these mixed-precision workloads requires not only multiple numerical formats but also suitable throughput ratios across precisions. Under a fixed input data-width budget, halving the element width allows twice as many elements to be supplied in parallel.
>
> **审阅稿** For a fixed input payload width, halving the element width doubles the number of elements supplied in parallel.

**S01.4** [dp-puzzle.tex L52](../dp-puzzle.tex#L52)

> **原文** The array-level throughput ratio follows from the unit-level one, so we focus on the dot-product unit and build nine throughput-ratio configurations.
>
> **审阅稿** An array of identical dot-product units inherits their throughput ratio. We implement nine unit configurations.

### S02 · 相关工作和 D=256 的归属

FPnew 统一引用正式期刊版。将研究差异写成本文所比较的问题，并将 D=256 归为由基准每拍 16 个 BF16 MAC 推得的规模选择。

**S02.1** [dp-puzzle.tex L93](../dp-puzzle.tex#L93)

> **原文** [21]
>
> **审阅稿** [17]

**S02.2** [dp-puzzle.tex L97](../dp-puzzle.tex#L97)

> **原文** In design-space exploration, Crafton et al. and MX-Like further examine trade-offs among low-precision formats, compute organization, and hardware cost [27, 28], but neither addresses throughput-ratio selection.
>
> **审阅稿** Crafton et al. and MX-Like explore trade-offs among low-precision formats, MAC organization, and hardware cost [26, 27]. We vary peak throughput allocation across precisions under joint area and power budgets.

**S02.3** [dp-puzzle.tex L202](../dp-puzzle.tex#L202)

> **原文** We model D=256 DPs per compute core to match the dot-product parallelism of an NVIDIA Blackwell SM [33, 34] and a Huawei Da Vinci AI Core [35]. As for the core number, we size the
>
> **审阅稿** We model D=256 DPs per core, giving 4,096 BF16 MACs/cycle in the baseline. This is comparable to Blackwell's dense BF16 throughput per SM [32, 33] and the FP16 throughput of a Da Vinci Max Cube [34]. We size the

### S03 · 减少重复枚举配比

表 I 提供产品动机，1:2:8 作为本文研究点，完整九档由表 III 给出。

**S03.1** [dp-puzzle.tex L105](../dp-puzzle.tex#L105)

> **原文** Table I summarizes recent products and development roadmaps from major general-purpose graphics processing unit (GPGPU) and neural processing unit (NPU) vendors, illustrating industry interest in 1:2:6, 1:4:8, and 1:2:8 ratios. These disclosures do not explain the rationale for selecting each ratio, and the configurations cover only a small part of the design space. We therefore extend the exploration to 1:4:4, 1:2:12, 1:2:16, 1:6:12, and 1:8:16. Together with the three ratios above and the 1:2:4 baseline, these form a design space of nine candidates. Our objective is to determine how hardware cost should be traded against performance benefits as the precision requirements of future model workloads evolve.
>
> **审阅稿** Products in Table I motivate 1:2:6 and 1:4:8. We also evaluate 1:2:8 and five other configurations to compare separate and joint FP8 and FP4 expansion costs (Table III).

### S04 · HiF4 共享粒度和 E16 输出位宽

按四元素和八元素分别指称两级 micro-exponent，明确 14 位数值与 31 位共享输出的关系。

**S04.1** [dp-puzzle.tex L133](../dp-puzzle.tex#L133)

> **原文** For HiF4 [14], the first micro-exponent shifts the three-bit magnitude left to give a four-bit value with two fractional bits. The second micro-exponent scales the Lane sum.
>
> **审阅稿** For HiF4 [14], the micro-exponent shared by four elements shifts the three-bit magnitude left to give a four-bit value with two fractional bits. The micro-exponent shared by eight elements scales the Lane sum.

**S04.2** [dp-puzzle.tex L129](../dp-puzzle.tex#L129)

> **原文** Each Lane processes eight FP4 operand pairs per cycle because eight elements of each HiF4 input share a second-level micro-exponent.
>
> **审阅稿** Each Lane processes eight FP4 operand pairs per cycle, matching the eight-element micro-exponent groups in HiF4.

**S04.3** [dp-puzzle.tex L146](../dp-puzzle.tex#L146)

> **原文** A narrow adder tree reduces eight fixed-point products to a signed 14-bit Lane output, down from 31 bits in the baseline.
>
> **审阅稿** A narrow adder tree reduces eight fixed-point products to a signed 14-bit Lane sum. The baseline embeds this sum in its shared 31-bit Lane output.

### S05 · 功耗活动窗口

已记录的 1,024 笔原生长度输入和中央 512 周期提炼为一句。

**S05.1** [dp-puzzle.tex L176](../dp-puzzle.tex#L176)

> **原文** Power Compiler estimates total power using steady-state switching activity extracted from gate-level simulation at 1 GHz.
>
> **审阅稿** For each profiled mode, Power Compiler estimates total power from the central 512 cycles of a 1 GHz gate-level simulation with 1,024 native-length input vectors.

### S06 · 图 1 的可读性

**图源待确认。** 审阅稿采用作者最新暂存的 PDF。该图仍是紧裁后的纵向图，按双栏通宽插入的自然高度约 699 pt，高于模板约 666 pt 的正文高度。旧 SVG 的节点与现图不同，建议用匹配的作者图源重排。[审阅稿图 1](../build/ab_author_review_20261119/compiled/dp-puzzle.pdf#page=3)

**S06.A** 使用匹配的作者可编辑矢量源，按单栏宽度简化并放大关键路径标签。

**S06.B** 接受现图作为本轮审阅版，保留核实过的图注改法 S04.2。

### S07 · 图 2 的柱标签基准

分别交代面积与估计功耗的归一化分母。图内字体如需调整，可以单独确认。

**S07.1** [dp-puzzle.tex L168](../dp-puzzle.tex#L168)

> **原文** Synthesized area and total power across the evaluated throughput ratios. Area series use the left axis, with labels indicating ratios relative to 1:2:4. The three power series share the right axis (mW). The labels are normalized to the outlined baseline MXFP8 bar.
>
> **审阅稿** Synthesized area (left axis) and estimated total power (right axis, mW) across the evaluated ratios. Area-bar labels are relative to the 1:2:4 area. Power-bar labels are relative to the outlined baseline MXFP8 bar.

### S08 · 图 3 的获胜份额和整档均值

色块使用获胜份额，圆点使用区间平均时间之比。保留 25 个面积格、各功耗分档边缘和相对 α 扰动的七档结论。

**S08.1** [dp-puzzle.tex L221](../dp-puzzle.tex#L221)

> **原文** Trace-weighted prefill. (a) Color identifies the ratio with the lowest mean GEMM time over the largest fraction of each 0.01×0.1 budget cell. (b) At α=0.327 (dashed line), shading gives the corresponding winner in each power band. Dots compare band-averaged times with 1:2:4, and bars span the winner's speedup range.
>
> **审阅稿** Prefill at observed input lengths. (a) Color marks the ratio that minimizes mean GEMM time over the largest share of each 0.01×0.1 budget cell. (b) At α=0.327 (dashed line), shading marks the ratio with the largest winning share in each power band. Dots show the band-mean GEMM time of 1:2:4 divided by that of the selected ratio. Bars span the selected ratio's speedup range.

**S08.2** [dp-puzzle.tex L225](../dp-puzzle.tex#L225)

> **原文** In the trace-weighted sweep, 1:4:8 leads in all 25 area bins of the lowest power band. At the reference area fraction, 1:6:12 leads over the largest share of each power band from β=1.2 to 1.4, and 1:8:16 leads throughout 1.4≤β≤2 (Fig. 3). Varying α by ±10% around the reference preserves the preferred ratio in seven of ten power bands.
>
> **审阅稿** In the lowest power band, 1:4:8 has the largest winning share in all 25 area bins. At α=0.327, 1:6:12 has the largest share in both bands spanning 1.2≤β<1.4. The 1:8:16 ratio wins throughout 1.4≤β≤2 at this area fraction (Fig. 3). Seven of ten bands retain their winner over a relative ±10% variation around α=0.327.

### S09 · 表 V 与图 4 的命名

场景统一为 Scenario。展开 SWA 和 CSA2。图 4 继续说明三类活跃核、11 个长度上界、五场景等权的 All 和最优框。

**S09.1** [tables/five_stage_migrations.tex L8](../tables/five_stage_migrations.tex#L8)

> **原文** Case
>
> **审阅稿** Scenario

**S09.2** [tables/five_stage_migrations.tex L16](../tables/five_stage_migrations.tex#L16)

> **原文** Experts include gate/up/down; Main QK/PV includes SWA/CSA. Each stage retains earlier migrations; other operators keep their original precision.
>
> **审阅稿** Expert GEMMs include gate, up, and down projections. Main QK/PV includes sliding-window attention (SWA) and Compressed Sparse Attention 2 (CSA2). Each scenario retains earlier migrations. Other operators keep their original precision.

**S09.3** [dp-puzzle.tex L230](../dp-puzzle.tex#L230)

> **原文** Prefill at α=0.327 and β=1, weighted by request frequency across 11 context-length bins and evaluated at each bin's upper edge. (a) Gray bars show physical cores. Circles, squares, and triangles mark active cores in BF16, MXFP8, and MXFP4. (b) Modeled GEMM speedup over 1:2:4. All compares mean times across five equally weighted scenarios. Outlines mark column maxima before rounding.
>
> **审阅稿** Reference-budget prefill (α=0.327, β=1). (a) Gray bars show physical cores. Circles, squares, and triangles mark active cores in BF16, MXFP8, and MXFP4. (b) Modeled GEMM speedup over 1:2:4 using 11 request-weighted bin upper edges. All compares mean times across five equally weighted scenarios. Outlines mark column maxima before rounding.

**S09.4** [dp-puzzle.tex L235](../dp-puzzle.tex#L235)

> **原文** In stage D, experts
>
> **审阅稿** In scenario D, experts

**S09.5** [dp-puzzle.tex L235](../dp-puzzle.tex#L235)

> **原文** in stage E,
>
> **审阅稿** in scenario E,

### S10 · 表 IV 和 14 nm 代理比较

为本文单位补上面积与能效计算口径。表 IV 的 Ten-Four 数值按 Q8/Q16 排列，约 3× 对应该段另述的 14 nm 代理比较。

**S10.1** [dp-puzzle.tex L182](../dp-puzzle.tex#L182)

> **原文** and IV compare format coverage and efficiency. At reported conditions,
>
> **审阅稿** and IV compare format coverage and efficiency. For our units, we divide peak throughput by synthesized area or estimated total power to obtain area or energy efficiency, respectively. At the reported operating points,

**S10.2** [dp-puzzle.tex L182](../dp-puzzle.tex#L182)

> **原文** Separately, we use DeepScaleTool [32] to scale Ten-Four from 7 nm to 14 nm as an approximate reference for our 12 nm implementation. Under this estimate, our baseline achieves approximately 3× the MXFP8 area efficiency of both full-format Ten-Four configurations.
>
> **审阅稿** Using DeepScaleTool [31], we scale Ten-Four from 7 nm to 14 nm as a proxy for our 12 nm implementation. With this proxy, our baseline achieves approximately 3× the MXFP8 area efficiency of the full-format Q8 and Q16 configurations.

**S10.3** [tables/related_ppa_native.tex L24](../tables/related_ppa_native.tex#L24)

> **原文** 表 IV 原无这一说明。
>
> **审阅稿** Ten-Four pairs list the full-format Q8 and Q16 configurations in that order.

### S11 · 收拢功耗结论和冷却讨论

摘要和结论按 DP 阵列功耗约束表述。把冷却的条件性解释集中到 V-C。S11.1 对应你已暂存的摘要句。

**S11.1** [dp-puzzle.tex L38](../dp-puzzle.tex#L38)

> **原文** The power is the main constraint on further low-precision expansion.
>
> **审阅稿** The DP-array power cap limits low-precision expansion over the budgets studied.

**S11.2** [dp-puzzle.tex L57](../dp-puzzle.tex#L57)

> **原文** Reducing low-precision datapath power or improving cooling where thermal limits apply can favor wider FP8 and FP4 configurations.
>
> **审阅稿** 删去该句。

**S11.3** [dp-puzzle.tex L224](../dp-puzzle.tex#L224)

> **原文** The array power cap is the main constraint on translating wider FP8 and FP4 datapaths into chip-level throughput gains.
>
> **审阅稿** The DP-array power cap limits how many cores can use wider FP8 and FP4 datapaths.

**S11.4** [dp-puzzle.tex L243](../dp-puzzle.tex#L243)

> **原文** Across the dot-product designs evaluated here, shared FP8 and FP4 hardware saves area, but array power is the principal limit on how much of the added parallelism the chip can use.
>
> **审阅稿** Shared FP8 and FP4 hardware saves area in the evaluated designs. The DP-array power cap limits the use of added parallelism over the budgets studied.

### S12 · 对齐位宽的出处和专名拼写

把既有研究的背景与本文选择的 26 位对齐窗口、向零截断分句。参考文献题名保护 TensorGauge 和 GEMM。

**S12.1** [dp-puzzle.tex L137](../dp-puzzle.tex#L137)

> **原文** Guided by the bit-width analysis in TensorGauge [29] and reverse engineering of Blackwell FP8 arithmetic [26], we retain 26 fractional bits in the alignment window and truncate toward zero on right shifts.
>
> **审阅稿** Prior studies analyze tensor-core bit widths [28] and Blackwell FP8 arithmetic [25]. Our alignment window retains 26 fractional bits, and right shifts truncate toward zero.

**S12.2** [references/references.bib L24](../references/references.bib#L24)

> **原文** `title={TensorGauge: A Pre-Silicon End-to-End Framework for Quantifying Numerical Effects of Tensor Core Microarchitecture in GEMM}`
>
> **审阅稿** `title={{TensorGauge}: A Pre-Silicon End-to-End Framework for Quantifying Numerical Effects of Tensor Core Microarchitecture in {GEMM}}`
