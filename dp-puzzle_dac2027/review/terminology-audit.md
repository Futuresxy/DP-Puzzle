# Terminology audit

## 阶段 A：语料内冲突与术语裁决（2026-11-18）

本节仅记录语料学习。尚不代表对目标论文进行了 B1 审计，也未修改论文。八篇 PDF、统计和引用证据见 `skills/dp-puzzle-en-writing/references/`。

| 问题 | 语料计数（命中句数 / 论文数） | 裁决与依据 |
| --- | --- | --- |
| datapath / data path | datapath: 56 / 7; data path: 4 / 2 | 多数用法支持 datapath；本稿已用此拼写。不是标准术语强制令，不修改引文。 |
| bitwidth / bit width / bit-width | bitwidth: 10 / 1; bit width: 16 / 2; bit-width: 3 / 2 | 名词 bit width 与复合定语 bit-width 不能直接当同一票；低位宽 low-bitwidth 是另一个搭配。保留本稿上下文用法。 |
| mantissa / significand | mantissa: 48 / 6; significand: 15 / 2 | mantissa 出现更多，但计数不能裁决字段位数。P04 的 mantissa decoding 明示包括 leading bit；P06 区分 fraction 与含 hidden bit 的 significand。维持本稿 significand；IEEE 754-2019 正文未能取得，不作标准逐条背书。 |
| FP8 / MXFP8 / MXFP6 / MXFP4 | 见 glossary 的各格式证据 | OCP MX v1.0 Table 1 确认 MX 前缀形式及 element/scale 分层；不能把 scalar FP8 和 block format MXFP8 当同义词。 |
| MXFP4 / NVFP4 / HiF4 | 后两者本地覆盖薄弱；HiF4 本地缺失 | 以 OCP、NVIDIA TE 2.14.0 和 HiFloat4 v2 原文辅助核对名称，各有不同缩放合同；不作自动替换。补充来源 URL 及短引见 terminology.md。 |
| group / block / lane | 同名对象跨论文层次不同 | P01 operation group 与本稿 Group 不一定同构；大小写或 group/block 差异需要先看定义。 |
| decoding | 既有推理解码，也有输入/尾数字段解码 | 不做全局替换；LLMCompass 的 prefill/decoding 与 MPICC 的 mantissa decoding 分语境处理。 |
| QI.F / UQI.F | 无本地语料用例 | 本稿显式定义 I 不含符号位；只将它记录为作者定义。没有核验 TI 引用全文，不修改符号、位宽或偏置。 |
| throughput ratio / precision migration | 本地语料未检得完整词组 | 可作为本稿自定义术语记录，不能声称是领域共识或拿 throughput、quantization 的近邻命中冒充。 |
| 数值单位空格与倍数 | 同时出现 12nm、1 GHz、5.1 %、百分号紧连等 | 提示词指定写法与语料并不完全一致；遵守数字/单位零改动红线，报告后由作者决定。 |

计数口径：清理后的所选正文中，regex 每句是否命中；“论文数”是有至少一次命中的文献数。不是原始 token 总频率，也不把长文重复当独立多数票。

标准核验边界：OCP、NVIDIA 和 HiF4 为外部一手补充，未加入 8 篇学习统计；IEEE 官方页仅返回 JavaScript/robot 检查。所有语义存疑项保留，不以多数投票覆盖标准或作者定义。


## 阶段 B0：未改动稿件的编译基线

命令：`latexmk -g -pdf -interaction=nonstopmode dp-puzzle.tex`。使用 `-g` 强制重建，避免只得到缓存 up-to-date 结果。完整输出见 [baseline-build.log](baseline-build.log)。

- 退出码 0；生成 `build/dp-puzzle.pdf`，7 页，参考文献从第 7 页开始。Underfull hbox 11 条、vbox 1 条；未检得 Overfull、undefined reference/citation 或 LaTeX error。
- 7 个 `.tex` 的前后 SHA-256 全部一致；见 [source-integrity.json](evidence/source-integrity.json)。编译只更新 build/ 下产物。
- 这是语言审计的可编译基线，不是 DAC 官方格式验收或技术实验复现。

## 阶段 B1：范围、方法与结论

通读 `dp-puzzle.tex` 的摘要、关键词、正文、活动图注，并只读检查五份 `tables/*.tex` 及编译后 PDF。注释掉的图、标签、引用 key、宏定义不作为正文语言命中。图 1 仅用于核对可见名称，未修改图源。未访问/复算实验运行，也未核验全部外部论文与厂商数据。

本轮采用阶段 A skill；项目 academic-humanizer 仅提供诊断参考。其“统一删除 em-dash”“增加证据或软化 claim”等泛化建议受用户“不改内容、无缺陷不改”和 report-only 限制，不自动执行。

最需要作者处理的是基础 Group 表头、功耗证据来源用词和注意力 CSA 的歧义。摘要缩写展开尚不满足用户指定的独立可读要求。尚不能给“摘要/关键词/正文三处术语完全一致”验收打勾。

### 摘要 / 关键词 / 正文对照

| 概念 | 摘要 L36 | 关键词 L39 | 正文 | 结论 |
| --- | --- | --- | --- | --- |
| AI / LLM | AI 未展开；模型名称与 GEMMs | AI workloads；LLM inference | AI 多次；没有 artificial intelligence 的展开；LLM 本身未作正文缩写使用 | M05；S05。关键词 LLM 与模型场景语义一致，不能仅因词形缺席说正文矛盾。 |
| dot-product unit | 摘要写 precision-specific compute units，未出现 dot-product unit | dot-product units | L50 dot-product units；L114 dot-product unit (DP) | 语义相容，摘要不必堆入全部关键词；没有 DPU 或 DP unit 混用。 |
| mixed-/multi-precision | mixed-precision workloads；multi-precision datapaths | mixed-precision arithmetic；multi-precision tensor core | 前者多指负载，后者指硬件支持多格式 | 不作全局统一；这是不同修饰对象。 |
| FP4 / MXFP4 | 结果用 FP4 | 无格式关键词 | L53/L224/L237 的同类结果明确 MXFP4 | S01/Q3：待作者确认摘要所指。 |
| throughput ratio | throughput allocation，出现配置比值 | throughput-ratio allocation | peak throughput ratio、throughput-ratio selection/choices | 构造名称与选择任务有区别；未发现强制必须替换的同义词漂移。 |
| GEMM / compute latency | GEMMs 未展开；modeled compute-only speedup | 无 GEMM | L46 展开 GEMM；L262 给理想计算时间模型 | M04；保留 compute-only/modeled 限定。 |
| area / power / energy | area、power 与 energy efficiency | 无这类指标词 | L224 power estimate，L257 measured power；energy efficiency 为派生指标 | M02/Q2；不把 power 与 energy 当同义词。 |

### 概念及所有写法的逐项清单

可搜索的全部 516 个命中（文件、行号、区域、实际词形和上下文）见 [term-occurrences.json](evidence/term-occurrences.json)。以下是语义审查摘要；命中次数不等于独立问题数。

| 概念 | 实际写法/位置 | 判定 |
| --- | --- | --- |
| 硬件 DP | dot-product unit(s)、DP、DPs；首次展开 L114 | 统一可理解；数学 `DP_K`、项目名 DP-Puzzle 和硬件简称不是重复缩写定义。 |
| Tensor core | tensor cores；作定语 tensor-core | 连字符随语法位置变化；不是不一致。 |
| 层级 | Lane/Lanes、Group/Groups、DP；量化 block(s) | L114/L121 定义明确；表 III T1H2Q4E16 另见 M01。 |
| 数据通路/位宽 | datapath(s)、bit width、low-bit-width | 无 prose data path/bitwidth 漂移；低位宽复合定语不强制改为独立名词。 |
| 有效数与字段 | fraction (L70)、significand(s) 多处、exponent(s) | 描述字段与内部有效数，不能互换；eq:mantissa_reuse 为禁止改动的标签，不是 prose mantissa。 |
| 格式族 | TF32、FP16/BF16、MXFP8/6、MXFP8/6/4、MXFP4/NVFP4/HiF4 | 缩写串列与单个格式有明确上下文；未见 MX-FP4。表 II 的 MX 换行 FP8 是排版，不是格式重命名。 |
| 对齐/规格化 | alignment、normalization、LZD、Anchor_raw/eff、U31 | LZD 已展开；U31/S1P2 定义需 Q6。不改符号或指数公式。 |
| 时延/吞吐 | eight-cycle latency、one independent request per cycle、peak throughput、compute time/compute latency | L181 解释硬件延迟/吞吐；L262 解释芯片理想服务时间。未声称端到端 latency，不混同。 |
| 格式精度/模型效果 | precision、accuracy、quantization error | precision 用于格式/数值，accuracy 用于模型/量化效果；未见 resolution 混用。 |
| 性能证据 | modeled、estimated、ideal、compute-only、measured | 前四者限定范围相容；measured 单独与 L224 冲突，列 M02。 |
| 精度迁移 | precision migration、precision-migration scenarios/assumptions、migrations | 连字符随定语位置变化；假设性质在 L262/L273 明确，保留。 |
| model size | model sizes (L46) | 本稿未与 parameter count 做自动等同；不增加不存在的参数量结论。 |

### 缩写首现与缺失

| 缩写 | 首现/展开 | 处置 |
| --- | --- | --- |
| GEMM | 摘要 L36 未展开；正文 L46 已展开 | M04，仅补摘要候选。 |
| AI / LLM | AI 未展开；LLM 仅关键词 | M05 / S05。 |
| TF32 / MoE | L46 有 TensorFloat-32 / mixture-of-experts | 保留。 |
| OCP / MX | L70 已建立 Open Compute Project / microscaling 映射 | 保留。 |
| DP / LZD / CSA / CPA / MUX | L114 / L167 / L179 / L179 / L195 均展开 | 硬件正文合格；attention 表中 CSA 另义未定义，M03。 |
| DSE | L93 标题先出现；L98 写全称但未括号映射 | S04，标题直接全称候选。 |
| GPGPU / NPU / RTL / TT / MLP | L106 / L106 / L224 / L224 / L224 未展开 | S05 集中报告常见领域缩写；不与专用符号混为一类。 |
| QK/PV / SWA/CSA / Q-up/O-up / Grouped O-down | 正文/表中未完整定义 | Q5 由作者明确；不猜算子名。 |
| BF16/FP16/FP32、INT8/INT32、E5M2 等 | 作为公认格式标识使用，L70 解释关键编码关系 | 不机械将每个格式名改成冗长全称。 |
| T/H/Q/E、QI.F/UQI.F | L119/L121 直接定义 | 保留数学及位宽合同；S1P2/U31 单列查询。 |

### 数字、单位、倍数与范围

- 活动正文未发现 `28nm`、`2.3x`、`3.2 %` 这类直接异常；源码数字与 `%` 使用 LaTeX 转义 `\%`。
- 正文倍数与乘法使用 `\times`，未发现其与字面 Unicode `×` 混用；表 II 的 `\times` 是“不支持”符号，不是性能倍数。图 1 的 `8x8` 等是只读图内信号/结构标签，单独看待。
- 摘要 `12 nm`/`1 GHz` 与正文 `12\,nm`/`1\,GHz` 的空格实现不同，但渲染后均有空格，不据此判技术错误。
- `1K--1M` / `1K to 1M` 内部数值一致；与 prompt 指定带空格形式有差异，列 O02/Q7。不猜 K/M 的精确计数口径。
- 摘要 33.6/49.7/27.3 与正文 33.60/49.70/27.27 的小数位不同。仅记录显示精度差异，不改值、不重算，也不把它们当新增实验结果。
- `85$^\circ$C` 为渲染成温度单位的 LaTeX 组合。按红线不调整单位、符号或数值。

### 图注/表注与比较基准

活动图注 3 处（L126/L216/L251），活动表注 5 份。图注多以名词短语开头，后接必要说明；不强制把每个解释句改为短语。
- 图 1：基础结构和 Group/DP 名称清楚；与正文一致，反证表 III 列头问题。
- 图 2：明确综合面积、总功耗、左右轴及面积归一化基线；保留 synthesized。
- 图 3：给定预算参数、A–E/All 聚合方式和权重；speedup 基线在正文，O03 为可选的图注局部补明。
- 表 I：说明 per-device dense peaks、roadmap，以及 BF16 归一化。厂商数据真实性未在本轮重审。
- 表 II：caption 的大小写/句点与其余表源不同，O01；符号图例正确区分 element arithmetic 与 MX scaling，不改。
- 表 III：含明确物理 Group 列名不一致，M01；脚注区分 instance counts 与 throughput ratios，本来正确。
- 表 IV：caption 明确原工艺节点；脚注说明未做 technology normalization 和 TransDot 估算来源。正文另有标注为 approximate 的缩放比较，未误写成同一批实测。
- 表 V：assumed precision-migration scenarios 已保留；SWA/CSA/Q-up/O-up 等缩写缺定义，Q5。

### 语气、时态与未采纳的扫描建议

本文主要以 we + present 描述设计、方法和分析，结论也以 present 陈述贡献；语料 R04–R06 支持这种组织，不做机械时态改写。贡献三项均为粗体名词性主题 + 具体说明，局部平行，不强改成 We propose/We design。
只读 qa.py 表面扫描未命中防御性套语候选；人工阅读也未发现需要去掉的空泛缓和词。relatively high deployment density 若需量化应查图，不因偏好替换。所有技术 caveat 保留。没有进行 B2/B3 逐句修改、B4 改后复查、B5 改后编译或生成修改 patch。

### 交付与验收边界

候选见 [candidate-changes.md](candidate-changes.md)，作者决策见 [queries.md](queries.md)。目前是报告完成、问题未应用状态；不会声称术语问题已修复。全部 `.tex` 未变，因无应用编辑，不生成伪造的 change-log 或 diff.patch。
