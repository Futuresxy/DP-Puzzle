# DP-Puzzle：DSE 主线与后续实验计划

更新：2026-11-16。本文档记录中文审核稿的论证结构与证据边界，不作为论文正文。入口为 [main.tex](main.tex)；英文单文件 [dp_puzzle.tex](dp_puzzle.tex) 等待中文审核后同步。

## 研究问题与论证链

**DP-Puzzle: Exploring Multi-Precision Throughput Ratios in Tensor Cores through Composable Dot-Product Units**

研究对象是 H/Q/E 峰值算力配比的设计空间探索。使用 **throughput ratio**，避免把峰值吞吐、计算工作量占比和面积占比混为一谈。微架构提供可实现候选和测量依据，DSE 用硬件成本与模型执行精度共同解释配比选择。

论证顺序为：

1. 多精度计算需求变化，使传统 1:2:4 不再是唯一候选。
2. 在同一 DP 内组合 Q、E、QE Group，构造 1:2:4、1:2:6、1:2:8、1:4:8、1:4:4、1:2:12、1:2:16、1:6:12、1:8:16 九种全精度候选。
3. 同工况测得单 DP 面积和逐精度功耗，证明算力、面积、功耗不同比例增长；另以解析模型讨论维持吞吐所需带宽。
4. 在 α 标定的面积和 β 标定的 DP 功耗双预算下计算实际整数核心数量与各精度总算力，再由 H/Q/E 有效 GEMM 工作量计算延迟与 DP 能耗。
5. 扫描 α×β×HQE 工作量三角域，并评估模型结构导出的负载点，解释当前配比选择和低精度迁移后的条件性变化。

当前中文稿已取消两种扩展实现的横向比较。只分析 DP 内低精度增配，不再将独立低精度 DP 作为主线候选。历史六 DP 数据、旧图、旧比较脚本仍保留，避免破坏证据或旧英文稿。

## 六章内容与文件

| 章节 | 文件 | 作用 |
| --- | --- | --- |
| I 引言 | `sections/01_introduction.tex` | 配比问题、成本与负载缺口、三项贡献 |
| II 背景与动机 | `sections/02_background.tex` | 格式与组尺度、点积语义、相关工作、商用配比 |
| III 面向配比探索的组合式点积微架构 | `sections/03_architecture.tex` | 保留 Lane/Group/DP 核心复用、Anchor Recompute 与对齐；并入 E/QE 专用化和 DP 内增配 |
| IV 算力配比的硬件成本表征 | `sections/04_evaluation.tex` | 方法、九候选面积与逐模式功耗、供数带宽、共享基线及低精度专用 DP 与已有单元对比 |
| V 面积与功耗约束下的算力配比探索 | `sections/05_dse.tex` | 整核预算、优势区域、模型工作量、当前负载与受控迁移 |
| VI 结论 | `sections/06_conclusion.tex` | 从可实现硬件成本到负载配比选择，明确适用条件 |

旧 `04_expansion.tex` 已合入第三章；旧第五至七章分别由新第四至六章取代。论文正文不包含代码版本、模块路径、run ID 或工程验收细节。英文仍为上一轮七章稿，中英文一致性检查在同步前会报告预期差异。

## 当前确认范围：核心算子与简化利用率（2026-11-16）

用户确认优先分析主要计算负载，降低低占比算子的迁移维度。已落地六场景 A–F，当前入口为 `scripts/v41_core.py`，配置为 `data/inputs/v41_core.json`，结果为 `data/evidence/v41_core_20261116/`。主要投影收窄到 Q-up/O-up，Q-down/SWA-KV/Index-Q 与 Engram 保持原精度；主负载（五类迁移对象加原生 E 索引点积）覆盖 93.22%–95.02% 的 GEMM FLOP。新图每个面板明确一个场景，显示精度占比与固定硬件性能。

路由利用率分开评价：主结果 η=1；敏感性只调整 routed expert 的服务时间，比较 Q/E 共同降效和 E 额外降效。η 为假设，不由平均 batch 大小直接推定；非理想 η 能耗为空值。批内每专家平均分配量 `6*B*L_group/384` 只解释聚合规模，不代表矩阵单元占用率。参考 [MegaBlocks](https://proceedings.mlsys.org/paper_files/paper/2023/hash/5a54f79333768effe7e8927bcccffe40-Abstract-mlsys2023.html)、[cuDNN grouped matmul](https://docs.nvidia.com/cudnn/operations/MoeGroupedMatmul/) 和 [TensorRT-LLM MoE performance guide](https://nvidia.github.io/TensorRT-LLM/developer-guide/moe-perf-guide.html)。

在 α=0.3、β=1.5 时，A/B 覆盖选 1:4:8（6.87% 最坏损失），A–E 覆盖同样选 1:4:8（16.85%），A–F 覆盖变为 1:6:12（49.29%）。更大功耗预算 β=2.1 使 A–F 覆盖选择 1:8:16（16.70%）。最终讨论同时给出场景、覆盖集合、预算、请求分布、利用率假设，避免宣布一个脱离条件的通用配比。

## 基础与历史对照证据

- 固定硬件输入：`data/DP_area_power/dp11_area_power_fixed_20261116.csv`，九种全精度候选进入 DSE；`0:2:4` 用于同类单元比较。
- 双预算部署与区域：`data/evidence/joint_dse_20261116/`，9 个 α×β 场景；配置为 `data/inputs/joint_dse.json`。保留三模型对照批次，但不再用单点获胜次数回答固定芯片选型。
- 当前主要负载为 V4.1-Flash，完整 CED 冷启动 prefill、batch=1、1K–1M 共 11 个上下文。模型与固定配置由 `scripts/deepseek_v41.py` 解析。
- 固定配比框架：`scripts/v41_portfolio.py`、`data/inputs/v41_portfolio.json`，5 类独立精度迁移形成 32 个方案、352 个负载点。结果在 `data/evidence/v41_portfolio_20261116/`，包含算子账本、单点结果、最坏相对损失、均衡及分布敏感性、平均时间/能耗和 Pareto。
- α=0.3、β=1.5 时，原始精度跨上下文选 1:4:4，最坏损失 3.91%；覆盖全部迁移方案选 1:4:8，最坏损失 20.05%。这两项是不同负载集合的固定硬件选择。
- 精度迁移只重分配工作量，不宣称 32 个模型质量方案均已验证。质量约束确定可接受方案子集后，可在相应结果行上重做选型。
- 能耗为 DP-only；Qwen 活动用于 DeepSeek 代理，NVFP4 用 MXFP4 功耗。原始 FP32 与其他未覆盖计算保持单列；计算服务时间不包含外围系统延迟。

## 算子敏感性与迁移场景调研（2026-11-16，后续核心范围以上节为准）

用户指出当前 A/B/C 图中的 C 为 32 方案最坏值包络，无法表达一条具体迁移路径。本轮先整理计算量与文献依据，不修改现有图和精度方案输入。后续每个面板固定一张精度映射，跨上下文评价同一硬件候选；全方案包络作为独立汇总，不冒充一种未来模型。已有 32 组合结果属于压力测试；1:4:8 的 20.05% 最坏损失只对该集合成立。

### 计算量与核心迁移对象

复算命令 `python3 scripts/analyze_v41_migration.py`，数据为 `data/evidence/v41_migration_review_20261116/{groups,operators}.csv`。来自冻结 CED prefill 算子账本，batch=1。下表分母是全部已统计 GEMM FLOP，包括 FP32，不是全部模型操作或耗时。

| 算子族 | 当前乘法类别 | 1K | 64K | 1M |
| --- | --- | ---: | ---: | ---: |
| Routed expert gate/up/down | Q（W4A8） | 50.82% | 47.91% | 35.72% |
| Shared expert gate/up/down | Q | 8.47% | 7.99% | 5.95% |
| Q-up + O-up | Q | 20.08% | 18.93% | 14.11% |
| Q-down + SWA-KV + Index-Q projection | Q | 2.40% | 2.25% | 1.68% |
| Grouped O-down | H | 8.03% | 7.57% | 5.65% |
| Main SWA/CSA2 QK+PV | H | 5.89% | 8.65% | 6.49% |
| Index full/candidate QK | E | 0.06% | 2.28% | 27.10% |
| Engram projection | Q | 3.35% | 3.54% | 2.65% |
| Global-KV projection + pooling gate | H/FP32 | 0.20% | 0.21% | 0.15% |

`q_up` 对应 Q-up，`o_final` 对应 O-up，`o_group` 对应 Grouped O-down。Index-Q projection 仅约 0.13%–0.20%，不与已经为 E、长上下文达到 27.10% 的 Index QK 混淆。Engram projection 占比大于 Index-Q 和 Global-KV，不应漏出总账本，可保持 Q 并单列敏感性。Global-KV 也保持在原始计算量中；不探索它不等于其成本为零。

时间收益还依赖当前硬件：在基线 1:2:4 上，Grouped O-down 虽仅占约 5.65%–8.03% FLOP，却占约 11.52%–14.21% 的 HQE 理想服务时间。迁移优先级因此同时看计算量、服务时间和质量风险，不按参数量或位宽单独排序。

### 证据与推断分开

1. **路由专家 Q→E：已有同模型部署依据。** [NVIDIA V4.1 NVFP4 model card](https://huggingface.co/nvidia/DeepSeek-V4.1-Flash-NVFP4) 与 [Model Optimizer DeepSeek recipe](https://github.com/NVIDIA/Model-Optimizer/blob/main/examples/deepseek/README.md) 明确将 routed experts 转为 NVFP4 W4A4，保留 shared experts 和 attention 原精度。当前模型卡另包含 Engram 表的压缩，不能将联合 benchmark 差值归因于单独的专家迁移，也不能从“被保留”反推其他算子一定不可量化。
2. **共享专家与普通投影 Q→E：条件假设。** 可依据缩放校准、异常值处理、QAT/蒸馏预估更广的 FP4 GEMM，但不能给出 V4.1 的已验证容忍率。[NVIDIA FP4 pretraining](https://arxiv.org/html/2509.25149v1) 使用随机 Hadamard、混合精度等方法并保留敏感层；该训练证据不等于大规模 MoE 的直接 PTQ 保证。
3. **敏感性排序不是“MLP 一定耐量化”。** [Qwen2.5 FP4 isolation study](https://arxiv.org/html/2603.08747v1) 在其 0.5B/7B/14B 实验中发现 up/down projection 更敏感，且层位置也有差异。这仅支持逐算子/逐层检查，不能移植为 V4.1 的确定排序。共享专家每 token 使用、Down 输入受门控激活影响，是需要关注的机制，不是数值质量结论。
4. **主注意力 H→Q：有邻近实现证据。** [FlashAttention-3](https://arxiv.org/abs/2407.08608) 展示 FP8 attention，采用分块量化与 incoherent processing 降低数值误差。把这一路径用于 V4.1 稀疏/跨层复用注意力属于本项目迁移假设。
5. **主注意力 Q/H→E：进取场景。** [SageAttention3](https://arxiv.org/html/2505.11594v3) 使用 FP4 QK/PV、Q/K 平滑和概率矩阵的双级缩放，支持“有专用数值方法时可能进一步迁移”的判断。其评估不能证明 V4.1 的 1M 长上下文无损；QK 与 PV 应保留独立开关及敏感层回退。
6. **存储、量化语义与执行指令分别记录。** [V4.1 report §2.4.4](https://arxiv.org/html/2609.19969v1#S2.SS4.SSS4) 明确 main KV FP4 主要节省缓存，attention 前解量化；不因此将 main QK/PV 归入 E。冻结 [inference/model.py](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash/blob/dba1be0a40aa45a94ad051997016db3960a90277/inference/model.py) 的 `wo_a` 解量化后使用 BF16 einsum，注释提出 FP8 grouped GEMM；H→Q 有执行实现因素，仍需核对激活量化与累加语义。Global-KV r=1 为 BF16，而 r>1 投影/门控为 FP32，不能统称 BF16 后整体降精度。

以上网页查阅于 2026-11-16；论文引用使用上述明确版本。在线 NVIDIA model card/recipe 为当前文档证据，冻结硬件和工作量输入没有随其更新。

### 建议的逐场景面板

面板次序是受控对比，不代表未来模型必然按此时间顺序演进。C 与 D 从 B 分叉，避免将投影 FP4 误写成 attention FP8 的必要前提。

| 面板 | 基础 | 新增精度选择 | 证据定位 |
| --- | --- | --- | --- |
| A | 冻结原始映射 | Routed W4A8；其余原精度；Indexer E | 当前计算基线 |
| B | A | Routed gate/up/down→W4A4 | 同模型已有量化部署路径 |
| C | B | Shared experts、Q-down/up/O-up、SWA-KV/Index-Q projection→W4A4；H 算子保留 | 扩展线性算子 FP4 的条件假设；保留 Shared/Attention-linear 两个子开关 |
| D | B | Grouped O-down、Main SWA/CSA2 QK+PV→Q；其他 Q 仍保持 Q | FP8 执行优化与 attention 迁移分支 |
| E | C+D | 主要线性算子 E，主注意力与 Grouped O 为 Q | 两条路径的联合场景 |
| F | E | Main QK/PV、Grouped O 进一步→E | 主要 GEMM 的进取场景，允许逐层回退；不称整模型全 FP4 |

所有场景保留 Router、softmax、归一化、残差和敏感 FP32 路径；Engram projection 先保持 Q。SWA-KV/Index-Q 可随线性族一起设置但不独立占图；Global-KV 保持原精度。若补充“所有 HQE GEMM 均为 E”，单独命名为算力需求极限场景，而非预测其质量可行。

数值格式应具体到 W4A4、缩放组、NVFP4/MXFP4 及累加精度；“FP4”不是同一个量化误差。采用微缩放、校准、平滑或 QAT 的依据需和场景绑定。不同目标格式的质量证据不互换；功耗仍是现有模式代理，不能把新格式质量论文作为本 DP 新功耗测量。

### 容忍度如何进入后续框架

先用单算子族/逐层隔离观察输出误差、任务指标和长上下文检索，再组成联合方案。QK 观察 logits/attention 分布及检索表现，Indexer 观察 Top-K 召回；PV 与输出投影观察累加后的误差及下游质量；专家区分 gate/up/down 和不同层。局部 MSE/余弦误差用于定位，最终质量容限按任务定义，不能给所有算子编造统一“允许下降 1%”。

对重要算子族允许只迁移通过质量要求的层/块，以其 FLOP 比例 λ 表示迁移量；λ 是通过筛选后的工作量占比，不是质量容忍率。原有最坏相对损失/平均时间/能耗框架保持，但最终目标集合改为有依据的场景或质量可行子集。精度敏感性先约束可选集合，再比较同一芯片对所有上下文的适应性。

## 下一步实验（按优先级）

### 1. 建立可追溯的 GEMM 工作量提取流程

在现有模型解析规则基础上实现，不重复搭建已有 DSE。流程为：固定模型仓库/配置/后端版本 → 提取算子形状与执行次数 → 核验权重、激活及实际计算精度 → 形成算子账本 → 汇总 H/Q/E 和未覆盖部分 → 映射九种候选。

每条账本至少记录：模型及版本、阶段、上下文、层/算子类型、M/N/K、调用次数、激活专家数、权重存储格式、激活格式、执行格式、尺度格式与粒度、累加格式、FLOP、来源和推导规则。未知执行精度保持未分类，不能根据 W4 自动判成 E；填充工作量与有效工作量分开。

先支持配置与模型专用适配器，再在可运行环境以算子图/运行轨迹交叉验证。静态解析能覆盖结构计数，但不能自动证明实际内核使用的精度。验收要求：各类别计算量与算子账本守恒；MoE 不按全部专家计数；当前三模型的冻结工作量可回归；FP32/转换/未覆盖计算显式报告。

### 2. V4.1 精度方案质量与辅助模型对照

当前优先确定 V4.1 五类算子的精度可行性、转换成本与质量约束。跨模型作为辅助对照；后续可加入官方 DeepSeek-V3.2，固定完整模型版本，作为较早 FP8 路线对照。V3.2 可从官方固定配置核验开始：
[config_671B_v3.2.json](https://huggingface.co/deepseek-ai/DeepSeek-V3.2/blob/cda825405824c29b2f55bdf74cd391f015813738/inference/config_671B_v3.2.json)。

与当前 V4/V4.1 使用相同 batch、阶段和上下文口径。对于用户指定的两个专家量化版本，分别固定 checkpoint、量化方案和执行后端，核验真实执行是否为 W4A4。缺失信息不能用理想迁移替代。跨代比较同时改变结构与精度，需另做“固定模型、仅改精度”的对照，避免将结构变化解释成量化收益。

### 3. 受控精度迁移与配比切换阈值

在固定工作量和形状下，以 λ 表示 Q→E 的工作量迁移比例，扫描专家、投影及可行的注意力子集。在九候选集合中求解配比切换的延迟和能耗边界，报告残留 H/Q 比例及相对收益；不预设所有路径都会切换，不将数学迁移视为模型精度验证。

当前已实现五个迁移维度的 32 个端点；在仿射计算模型下给出连续迁移的最坏损失界。下一步针对质量允许的迁移路径生成 λ–收益与切换边界，并接入真实流量权重。上下文之间始终使用同一物理配比。

### 4. 面积、带宽和功耗约束的敏感性

先扫描阵列面积占比、固定外围开销及外围随增配增长的敏感性，检查整数核数台阶是否改变结论。当前充分供数假设保持不变；外围系统建模作为独立扩展，再接入驻留、边界利用率、存储和调度。

功耗上限实验需明确限制 DP、整核还是全芯片，区分活动核数限制与频率调节；没有额外频点测量时，不假定任意 DVFS 曲线。完整系统模型应计入外围和存储，不能用 DP-only 功耗冒充芯片 TDP。阵列当前只获授权建模与方案讨论，本计划不要求实现阵列 RTL。

### 5. 功耗代理校准与写作收敛

NVFP4 活动功耗测量按后续授权补齐；本轮仍用 MXFP4，优先级低于工作量提取与旧版模型对照。随后评估多层/多模型活动差异，重算能耗边界，保持吞吐口径不变。中文结构确认后再同步英文，压缩至投稿页数，重新核验模板与披露要求。

## 图表安排

已有架构图继续使用 `baseline_arch_singlepage.pdf`、`unpack_layout.png`、`DP_CSAmodule.png`；不生成新的架构图片。前者由作者提供的分页 PDF 拼合，保留矢量内容；后续插图优先使用裁剪到绘图内容的单页 PDF。建议作者后续补一张单栏流程图：候选 DP → 测量成本 → 整核面积部署 → 工作量账本 → 配比区域/模型点。需要展示四候选时，画同一 DP 中 4 个共享 Group 与新增 0/2E/4E/4QE Group，不再画独立输出扩展。

数据图只使用可回溯数据及脚本。第四章使用九配比面积/功耗图和全精度/低精度双列比较；第五章使用双预算部署表、优势区域图，以及 V4.1 固定芯片的上下文减速曲线与选型表。


## 严格功耗扫描后的主张收敛（2026-11-16）

作者指出 β=1.5 下选择大 E/QE 的结论过于直观。已追加 β=0.50–1.50 的 0.01 步长扫描与连续部署对照，具体见 [结果与机制](data/evidence/v41_power_sweep_20261116/README.md)。主线调整为：残余精度的时间份额决定 E 扩展阈值；共享模式最高功耗约束全部模式的物理部署；纯功耗限制区的相对排名不随预算变化；混合约束区可能扩大固定芯片的跨迁移场景 regret。预算变化须与绝对时间并列，整数边界须与连续趋势分开。不将这些解析现象未经相关工作对照直接称为首次发现。
