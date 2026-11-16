# DAC 2027 论文

## 当前恢复状态与写作约定（2026-11-16）

按用户要求，正式 DSE `sections/05_dse.tex` 已恢复为 `740da79` 的六场景版本，撤回上一轮严格功耗探索的正文与图引用，保留面积占比 α 与功耗倍率 β 的联合部署模型。当前预算范围为 β=1–2.1，现用配置仍为 1/1.5/2.1。此次未修改 `main.tex`，也未修改用户正在编辑的摘要和引言。

后续论文内容仅在 [main_temp.tex](main_temp.tex) 起草，由用户手动搬入正式稿。临时稿的 DSE 已内嵌为独立副本；其余章节只读引用正式稿，不能通过改共用文件影响正式稿。摘要、引言没有单独明确要求时不改。持续约定见 [AGENTS.md](AGENTS.md)。

```bash
make pdf       # 当前正式稿
make pdf-temp  # 临时稿 build/main_temp.pdf
```

此前 β<1 的 [严格功耗批次](data/evidence/v41_power_sweep_20261116/README.md) 仅作为历史记录保留，已退出正文和默认复现入口，不作为当前论文结论。`make reproduce` 恢复九配比联合建模及六场景分析；`make test` 恢复其 26 项测试。本轮不执行新的 DSE 扫描。

## 当前主分析：六个核心迁移场景与路由利用率（2026-11-16）

用户确认将分析收敛到主要计算负载。当前中文 DSE 使用 `data/inputs/v41_core.json` 和 `scripts/v41_core.py`：只迁移路由专家、共享专家、Q-up/O-up、主 SWA/CSA2 QK/PV、Grouped O-down 五类算子；连同原生 FP4 索引点积覆盖 93.22%–95.02% 的已统计 GEMM 工作量。Q-down、SWA-KV、Index-Q projection、Engram 等背景计算保留原精度和成本；FP32 工作仍单列。这里的简化是减少迁移变量，不是删除小算子。

A 原始；B 路由专家 E；C 在 B 上加入共享专家和 Q-up/O-up 的 E；D 从 B 分支，将主注意力与 Grouped O 转 Q；E 合并 C/D；F 将 E 的主注意力与 Grouped O 进一步转 E。六张面板分别展示明确的精度场景，上部是 HQE 工作量占比，下部是九种固定芯片的相对减速。当前图：[v41_core_scenarios.pdf](figures/v41_core_scenarios.pdf)。

```bash
MPLCONFIGDIR=/tmp/dp-paper-mpl make portfolio        # 当前六场景
MPLCONFIGDIR=/tmp/dp-paper-mpl make portfolio-stress # 历史 32 组合包络
MPLCONFIGDIR=/tmp/dp-paper-mpl make test             # 26 项测试
make pdf
```

当前结果：[data/evidence/v41_core_20261116/manifest.json](data/evidence/v41_core_20261116/manifest.json)。66 个负载点 × 9 种设计 × 9 个预算 × 5 组利用率，共 26,730 项评估。`cases.csv` 保留有用 FLOP，`evaluations.csv` 保存单点服务时间，`metrics.csv` 包含均衡/偏短/偏长分布、最坏损失、平均时间、能耗和 Pareto，`scenarios.csv` 明示算子精度；`routing_scale.csv` 给出批内专家分组规模。固定集合分别为 A/B、A–E、A–F，不将进取场景自动等同于近期必须覆盖的需求。

主分析假设充分利用；另外仅给 routed GEMM 引入有效算力系数 η。扫描 Q/E 共同为 0.75、0.5，以及 Q=1、E=0.75/0.5，候选间使用相同系数。η 不改变工作量或实例数，不能以激活专家比例 6/384 再折扣已统计 FLOP。平均每专家 token 数为 `6*B*L_group/384`；`L_group` 是一次分组中实际处理的 token 数，分块 prefill 和 128-token replay 不能按完整上下文推断利用率。该规模表不是 batch→η 的实测映射。没有低利用率功耗曲线，非理想 η 行的能耗输出空值；功耗预算仍由原始已测模式设定。

α=0.3、β=1.5、η=1：A/B/C/D/E/F 的最小最坏损失设计分别是 1:4:4、1:4:8、1:2:16、1:8:16、1:8:16、1:2:16。A/B 固定选 1:4:8，最坏损失 6.87%；A–E 也选 1:4:8，损失 16.85%；A–F 则选 1:6:12，损失 49.29%，体现进取 FP4 场景与现有负载的部署取舍。β=2.1 时 A–F 选择 1:8:16，损失降至 16.70%。场景 E 的平均时间/能耗分别偏向 1:8:16/1:2:16；C 的两项目标均选择 1:2:16。B 在五组 η 下的选型不变；E 在 routed E η=0.5 时转为 1:2:16。

此前六场景批次 PDF 正文 9 页、参考文献 1 页；本轮恢复后的摘要和引言以作者工作区编辑为准。当前检查记录为 [review.json](data/evidence/v41_core_20261116/review.json)。保留历史数据与图，英文未同步。

## 精度迁移假设的后续核对（2026-11-16）

用户要求先按算子计算量、精度敏感性与论文依据选择合理迁移场景。分析已写入 [research_plan.md](research_plan.md)，重算数据为 [groups.csv](data/evidence/v41_migration_review_20261116/groups.csv) 与逐算子 `operators.csv`，入口 `python3 scripts/analyze_v41_migration.py`。建议采用 A 原始、B 路由专家 FP4、C 主要线性 FP4、D 主注意力/Grouped O FP8、E 两分支合并、F 主要 GEMM 进一步 FP4；C/D 为不同分支，且保留小算子原精度成本。该阶段尚未替换 ABC 图；随后按用户确认的核心算子范围生成上方六场景分析，质量证据等级保持原定义。全 32 组合包络作为压力测试，不再视为唯一的未来精度集合。

## 历史 32 组合：跨上下文与精度迁移的固定芯片选型（2026-11-16）

中文稿现在以 DeepSeek-V4.1-Flash 为主要负载。保持一个物理芯片配置，评估 1K–1M 的 11 个逐次翻倍上下文与 32 个算子精度方案。五个独立开关依次为路由专家 Q→E、共享专家 Q→E、注意力线性投影 Q→E、主注意力 QK/PV H→Q、分组输出投影 H→Q；未选算子保持原精度。`P10000` 表示仅路由专家迁移，`P11111` 表示全部开关启用。策略不随上下文改变；这些开关定义计算需求探索，模型质量可接受的子集由作者确定。

评价分成两层：每个精度方案内跨上下文选型，以及一个芯片覆盖全部精度方案。主准则是最小化 **最坏相对延迟损失** `max(T_j/min_k(T_k)-1)`；均衡基准对上下文等权，另报告平均相对减速、平均请求计算时间、DP 能耗和三目标 Pareto 候选。不会用获胜次数选芯片，也不会在每个上下文重新选择硬件。所有预算分别评价，不跨 α/β 混合排名。

用户确认先做均衡评测，再做分布敏感性。偏短和偏长场景分别用请求概率 ∝ `1/L` 和 `L`；这些是合成流量假设。全方案平均值对精度方案也等权；最坏损失仅取决于目标负载集合，不依赖这些权重。均衡基准的平均时间仍会受到大请求计算量的影响，所以同时报告等权平均相对减速。加权时间的有效 HQE 点由加权 **FLOP 总量** 归一化得到，不平均每点的精度占比。

```bash
MPLCONFIGDIR=/tmp/dp-paper-mpl make portfolio-stress  # 重算历史 32 组合框架、图、表
MPLCONFIGDIR=/tmp/dp-paper-mpl make test       # 20 项测试
make pdf
```

输入：[data/inputs/v41_portfolio.json](data/inputs/v41_portfolio.json)。输出索引：[manifest.json](data/evidence/v41_portfolio_20261116/manifest.json)；`operator_work.csv` 为按算子归并的原始 FLOP 账本，`policies.csv` 为策略开关，`cases.csv` 为 352 个负载点，`evaluations.csv` 为 28,512 项候选计算结果，`metrics.csv` 为固定配比评价，`aggregate_points.csv` 为加权有效 HQE 点。精度迁移守恒、原始/专家迁移与旧模型一致性、请求加权、最坏损失与连续迁移端点界均有检查。

α=0.3、β=1.5 时，原始方案的最小最坏损失配比为 **1:4:4（3.91%）**，仅路由专家迁移时为 **1:4:8（0%）**，覆盖全部 32 个方案时为 **1:4:8（20.05%）**。原始方案的最低平均时间选择会随请求分布从偏短的 1:4:4 变为均衡/偏长的 1:4:8。因而“均衡表现”“最坏损失”“平均时间”是不同指标。连续迁移界只针对已采样上下文、固定容量和仿射工作量，不含精度转换成本。

图为 [v41_fixed_ratio.pdf](figures/v41_fixed_ratio.pdf)，正文表为 `tables/v41_fixed_choice.tex`。该历史批次 PDF 正文 8 页、参考文献 1 页；该批次检查见 [review.json](data/evidence/v41_portfolio_20261116/review.json)。英文稿未同步，三模型的历史对照结果保留。

## 九配比与双预算 DSE 基础批次（2026-11-16）

本轮在作者工作区稿件上更新九种全精度 DP 的组合说明、设计动机、硬件成本与 DSE。`main.tex` 为中文入口；英文 `dp_puzzle.tex` 保留历史版本。当前正文使用 `scripts/reproduce_joint_dse.py` 和 `data/inputs/joint_dse.json`，从固定 11 设计数据中选取九种完整 HQE 候选。低精度 `0:2:4` 仅用于相关工作表，与共享基线并列；独立 E/QE 不参与全精度负载扫描。

```bash
MPLCONFIGDIR=/tmp/dp-paper-mpl make reproduce  # 九配比部署、区域、模型点评估与对比表
MPLCONFIGDIR=/tmp/dp-paper-mpl make test       # 当前为 20 项测试
make pdf                                    # build/main.pdf
```

结果索引为 [data/evidence/joint_dse_20261116/manifest.json](data/evidence/joint_dse_20261116/manifest.json)：9 个 α×β 场景、每场景 5,151 个 HQE 组成、42 个模型/迁移负载点和 3,402 次候选评估。部署、区域份额、模型点与候选评估为受控 CSV/JSON；完整 92,718 行双目标网格及算子账本放在被忽略的 `data/results/joint_dse_20261116/`。图为矢量 PDF `figures/joint_dse_regions.pdf`，表为 `tables/hardware_joint_table.tex`。作者提供的九配比成本图 `figures/dp_ratio_area_power.pdf` 保留原稿。

该三模型对照批次中，α=0.3、β=1.5 时 W4A8 21 点有 16 点选择 1:4:4、5 点选择 1:4:8；现稿主线已进一步转为上方 V4.1 固定芯片评价。当前模型中配置数量同时缩放吞吐和功耗，预算改变延迟区域，DP 单位工作能耗排序保持不变。旧四候选流程以 `make reproduce-legacy`、`make test-legacy` 保留。

作者待补内容用可见斜体集中在 III、IV、V 章末尾，不将未核验内容补写为结果。新计算依据固定硬件记录与既有模型结构分析，未新增 EDA 或推理测量。该基础批次稿件为正文 7 页、参考文献 2 页；这是历史版面记录。该批次待补清单和数字核对记录见 `data/evidence/joint_dse_20261116/manuscript_review.json`。

## 面积与功耗联合硬件成本模型（2026-11-16）

用户确认的选型口径：基准计算阵列面积占比 `alpha` 标定固定每 SM 外围面积，功耗倍率 `beta` 标定共同 DP 功耗预算。两项预算共同决定候选**实际配置的整数 SM 数**，所有已配置 SM 在每个受支持且已测功耗的模式下均可同时计算。同一物理设计的 SM 数不随 H/Q/E 工作量变化；超过预算的 SM 不实例化，剩余面积单列，不假定其已重新利用。

[独立计算入口](scripts/hardware_cost.py) 使用 [11 种 DP 固定数据](data/DP_area_power/dp11_area_power_fixed_20261116.csv)，先校验 SHA-256。仅使用 BF16、MXFP8 E4M3、MXFP4 E2M1；纯 E/QE 的不支持模式输出空值，要求该模式的工作负载不可行。`0:2:0` 不参与。默认选取其中九种全精度设计；`--include-specialized` 可导出全部 11 种。正文的 HQE 扫描已通过 `scripts/reproduce_joint_dse.py` 接入该模型。

令 `D` 为每 SM 的 DP 数（默认 256）、`N0` 为基准 SM 数（默认 36）、`a_j` 为单 DP 面积、`p_j,p` 为单 DP 测量总功耗，基准 0 为 `1:2:4`：

```text
A_tensor,0 = D * a_0
A_other = A_tensor,0 * (1/alpha - 1)
A_budget = N0 * A_tensor,0 / alpha
A_SM,j = A_other + D * a_j
P_reference = N0 * D * max_p(p_0,p)
P_budget = beta * P_reference
N_area,j = floor(A_budget / A_SM,j)
N_power,j = floor(P_budget / (D * max_supported_measured_p(p_j,p)))
N_j = min(N_area,j, N_power,j)
C_j,p = 2 * frequency * N_j * D * K_j,p / II
P_j,p = N_j * D * p_j,p
```

`alpha` 只标定 baseline；其他配比的阵列面积占比会改变。扫描 alpha 时固定 N0，因此各 alpha 对应不同的外围假设与总面积预算；同一个 alpha 内所有配比共享同一面积预算，不能把跨 alpha 的结果解释成同一固定 mm² 芯片的比较。扫描 beta 不重新标定 baseline：即使 beta<1 使 baseline 配置核数减少，功耗参照仍为原 N0 核的值。三个模式使用同一个预算；不按工作量组成或模式分别改变上限。

默认 alpha=0.3 时，面积预算为 496.59255257088006 mm²，功耗参照为 147.4744218750001 W。Beta 是显式场景参数，没有默认的唯一物理上限。示例扫描（从 paper 目录运行，输出目录必须尚不存在）：

```bash
python3 scripts/hardware_cost.py --alpha 0.2 0.3 0.4 \
  --beta 1 1.25 1.5 2 2.1 --output data/results/hardware_cost_20261116
python3 -m unittest discover -s scripts -p test_hardware_cost.py -v
```

输出 `hardware_cost.csv` 和 `manifest.json`，包含两项预算分别允许的 SM 数、实际 SM/DP 数、约束来源、已用/剩余面积与功耗、分精度峰值 TFLOP/s、分精度 DP 功耗，以及面积部署全部开启所需 beta。每个模式按 2 FLOP/MAC，互斥模式峰值不能相加。状态为 `analytical_uncalibrated`：DP 数值来自测量，核心部署和理想供数下的绝对峰值是解析推导。

假设每 SM 外围面积固定、供数充分、计算资源充分利用；DP 面积之和作为计算阵列面积代理。没有新增阵列 RTL、寄存器/广播网络表征、DVFS、外围功耗或端到端延迟模型。功耗为 DP 计算池的已测活动窗口平均功耗外推，不是整芯片 TDP 或瞬时最坏峰值；固定外围面积不能推出固定外围功耗。约束只覆盖三种已测格式，不保证其他支持格式也能全核运行。

## 历史四候选工作流说明（2026-11-11）

以下记录为旧四候选稿的复放说明；当前入口与结果以上方九配比说明为准。旧稿按六章组织：引言、背景与动机、组合式点积微架构、硬件成本表征、面积约束 DSE、结论。第三章已并入 E/QE 专用 Group 与 DP 内增配；原有两种扩展方式的比较从正文撤下。主线是“可实现 DP → 同工况成本 → 整核部署 → 工作量组成 → 配比选择”。章节映射、证据边界和下一步实验见 [research_plan.md](research_plan.md)。

本轮仅修改中文。英文单文件 [dp_puzzle.tex](dp_puzzle.tex) 保留上一轮七章版本，待用户确认后同步。当前中英文的章节、公式、表格和图源存在有意差异；`Makefile.en check` 会报告这些差异，不能当作已通过一致性检查。不得用旧英文内容覆盖本轮中文结构。

```bash
make -C paper pdf                    # 中文：paper/build/main.pdf
make -C paper watch                  # 中文保存后持续编译
make -C paper -f Makefile.en          # 上一轮英文：paper/build/dp_puzzle.pdf
```

硬件成本继续引用现有 N12、0.7 V、85°C、1 GHz 测量，未重新执行 EDA。四种配比面积及逐精度功耗图为 `figures/ratio4_{area,power}.png`，功耗柱高为实测 mW，所有倍率统一以 1:2:4 的 BF16 功耗为基线。生成数据与 hash 见 [data/DP_area_power/README.md](data/DP_area_power/README.md)。旧六 DP 图、测量数据和历史对比依赖保留。

当前负载来自固定配置和模型特定规则；新增通用提取流程、V3.2/R1 及两个实际专家量化版本的核验列为后续实验。正文中的专家 W4A4 是迁移场景，NVFP4 能耗暂用 MXFP4 活动功耗代理。`data/results` 是当前硬件结果；`data/expected` 保持历史工作量回归，不用于替换现行时间/能耗。

定点记号采用 `QI.F` / `UQI.F`，整数位数 I 不含符号位，位宽分别为 `1+I+F` / `I+F`；精度类别 Q 与定点 Q 格式由上下文区分。Lane 和 DP 的对齐窗口均为无符号幅值，基线分别为 28 和 39 位。论文正文不使用代码版本与 run ID。

架构图只使用作者现有图稿；需要补画的内容列在研究计划中。本轮仅用既有绘图代码和测量数据生成四配比数据图。中文保留 10 pt 工作稿排版，本轮编译为正文 6 页、参考文献 1 页；未发现未解析引用或溢出。英文尚未同步，需单独复核其最终篇幅。

## 保存后预览 PDF

当前中英文架构图均引用 `figures/baseline_arch_singlepage.pdf`。作者提供的 `figures/baseline_arch.pdf` 是 3×3 分页导出，直接插入只显示第一页；单页版本由同目录的 `baseline_arch_singlepage.tex` 拼合并裁剪空白，保留原图的矢量内容与嵌入字体，原 PDF 不变。旧 PNG/SVG 和六 DP 数据图位于 `figures/oldfig/`。

### 加入矢量图

2026-11-11 约定：**后续论文插图以 PDF 为主要插入格式**。数据图从绘图代码直接导出矢量 PDF，架构图由作者提供；SVG 保留为可编辑源文件，PNG 用于预览或已有位图素材。当前已有 PNG 不通过简单封装 PDF 冒充矢量图。

推荐从绘图工具直接导出 **单页 PDF**，选择“裁剪到绘图内容”，避免按 A4 纸张分页；保留矢量线条、嵌入字体，或将文字转为路径。放入 `figures/` 后直接引用：

```latex
\includegraphics[width=\columnwidth]{figure_name.pdf}
```

也可以先用 Inkscape 将普通 SVG 转为 PDF；正文仍引用 PDF。SVG 和 PDF 不保证内部全是矢量：嵌入的 PNG/JPEG 转换后仍是位图。原绘图工具直接导出 PDF 通常能更可靠地保留文字；部分 SVG 的 HTML 标签（`foreignObject`）在其他转换器中可能显示不完整。

直接在 LaTeX 中管理 SVG 可使用 `svg` 宏包的 `\includesvg`，但需另外安装 Inkscape 并允许编译时调用转换程序，见 [svg 宏包说明](https://ctan.org/pkg/svg)。当前采用直接插入 PDF 的方式，无需额外转换程序或 shell escape。

**工作区范围：** 若 VS Code 打开的是上一级 `workspace/`，不会加载嵌套的 `DP-Puzzel/.vscode` 设置。推荐通过「文件 → 从文件打开工作区」打开 `paper/paper.code-workspace`；直接打开 `paper/` 也已配置。`main.tex` 首行的 `% !TeX program = latexmk` 让默认编译按钮使用本地 `.latexmkrc` 中的 XeLaTeX，而不采用插件默认的 `latexmk -pdf`。已有的错误不是字体缺失，而是 pdfLaTeX 不支持 `fontspec`。

切换配置后可执行 `Developer: Reload Window`。若手动选过旧 recipe，执行 `LaTeX Workshop: Build with recipe`，选择 `DP-Puzzel (XeLaTeX)`；正确日志应出现 `Running 'xelatex ...'`。不要用 `-f` 忽略引擎错误。

本机 VS Code 项目已配置 LaTeX Workshop；也可使用「文件 → 从文件打开工作区」打开 [paper.code-workspace](paper.code-workspace)，直接进入论文写作区。

1. 打开 `main.tex`，按 `Ctrl+Alt+B` 首次编译。
2. 按 `Ctrl+Alt+V`，在右侧打开内置 PDF 预览。
3. 编辑 `sections/*.tex` 后按 `Ctrl+S`；插件自动编译完整论文，成功后刷新 PDF。

各章节首行的 `% !TeX root = ../main.tex` 指定完整论文入口。编译使用 XeLaTeX 与现有 `.latexmkrc`，输出始终为 `build/main.pdf`；`Ctrl+Alt+J` 可从源码光标跳转到 PDF 对应位置。若编译失败，预览保留上一次成功结果，可在 LaTeX Workshop 输出面板查看错误。

不使用插件自动编译时，可在 `paper/` 运行 `make watch` 持续监视文件，按 `Ctrl+C` 停止；不必同时运行两套自动编译。`make` 仍可用于单次编译，`make cost-figures` 用于更新面积/功耗 PNG。

## 编译与重绘

需要 XeLaTeX、latexmk、BibTeX（TeX Live 的 xeCJK、IEEEtran、subfig/caption 相关依赖），以及 Python 3、NumPy、Matplotlib。正文采用 TeX Gyre 和 Fandol 字体；新 DSE 图采用 Times New Roman 衬线字体。IEEE 模板随目录保留，来源见 [template/SOURCE.md](template/SOURCE.md)。

```bash
cd paper
python3 -m pip install -r requirements.txt  # 缺少依赖时执行
make                    # 仅编译正文，输出 build/main.pdf
make reproduce-legacy   # 重算旧四候选部署、负载、三角分区、两张图和三张表
# make diagrams         # 历史示意图入口；本轮不调用，架构图由作者维护
make cost-figures       # 按可编辑 CSV 重绘 select8 面积/功耗和 H16Q32E64 面积占比
make check              # 重算九配比结果并核验部署、区域与时间/能耗
make test               # 20 项成本、区域与固定配比评价测试
```

`make` 不会自动覆盖图表。可先运行 `make reproduce` 检查新结果，再 `make` 更新 PDF。编译和分析均不依赖原工程、网络或 GPU。

### 历史四候选负载配比分区图

旧稿第六节使用 `figures/k4_n12_prefill_comparison.png`，左右分别为整数核心部署下的最小计算延迟与最小 DP 计算能耗。图内标注四种配比及其最优区域的几何面积占比，并提供 H/Q/E 百分比刻度、20%/30%/50% 读数示例和三模型×两种专家量化映射的图例。原区域表不再单独排入正文；连续/整数部署及能耗的数值仍保留于 `tables/region_table.tex` 和 `data/results/regions.json`。

组合图将读数示例置于两三角图之间的上方空白处，底部仅保留两行量化方案、三列模型的紧凑图例。配比标签不加底色；区域百分比、轨迹方向和实心终点的解释放在论文图注。

仅重绘、不重算负载或覆盖结果数据：

```bash
python3 scripts/plot_triangles.py  # 使用已安装 requirements.txt 的 Python 环境
```

脚本读取 `data/results/{regions.json,prefill_points.csv,nvfp4_prefill_points.csv}`，仅输出组合图及两个独立面板的 400 dpi PNG，字体与 `data/H16Q32E64_area/plot_area_comparison.py` 使用相同的衬线字体配置；输入哈希、实际字体和区域百分比记录于 `figures/k4_n12_prefill_plot_manifest.json`。完整 `reproduce.py` 使用同一绘图入口。NVFP4 能耗仍使用 MXFP4 活动功耗代理；读数示例不是模型负载点。

### 旧 PETile 的 17 配比与 DeepSeek 精度迁移

运行 `make petile17 PYTHON=python3.11` 可复算 [N12 等面积延迟三角图](figures/petile17_n12_prefill_time.pdf) 和 [渐进迁移的局部放大图](figures/petile17_precision_migration.pdf)。输入为 [旧 PETile 的 17 项 DC 面积](data/evidence/n12_legacy/README.md)。[实验记录](data/results/petile17_n12/README.md) 给出部署条件、两种专家映射的工作量，以及投影、共享专家和主注意力的四步迁移结果。

## 修改哪些数据

| 文件 | 修改内容 |
| --- | --- |
| [data/inputs/experiment.json](data/inputs/experiment.json) | 基准核数、阵列 M/N、基准阵列面积占比、外围增长系数、batch、上下文序列、三角扫描密度 |
| [data/inputs/hardware_n12.json](data/inputs/hardware_n12.json) | 四配比的单 DP 面积、各格式 MAC/cycle、频率和活动功耗；保留测量批次与原始来源 hash |
| `data/inputs/models/<模型>/inference/config.json` | 三模型结构、专家数量、隐藏维度、压缩比例等；改变后代表对应的结构分析场景 |
| [scripts/costs.py](scripts/costs.py) | 执行精度映射、固定外围部署和时间/能耗公式 |
| [scripts/workloads.py](scripts/workloads.py)、[scripts/deepseek_v41.py](scripts/deepseek_v41.py) | V4/V4.1 的有效 GEMM 工作量、注意力与 CED 计算规则 |
| [scripts/plot_triangles.py](scripts/plot_triangles.py) | 配色、字号、标记和轨迹；标题及图注由 LaTeX 管理 |

例如把 `baseline_cores` 改为 32 后，默认硬件下部署核数变为 32/30/29/26。修改面积和功耗应同时更新来源信息；自行设定的数据属于敏感性分析，不能作为新的硬件测量。

独立试验可以不覆盖论文图表：

```bash
python3 scripts/reproduce.py --config data/inputs/experiment.json --output /tmp/dp-paper-trial
```

`--config` 中的 `hardware` 相对该配置文件解析；模型配置固定从本目录 `data/inputs/models/` 读取。此历史入口针对四种既定配比和三个模型。

**重绘更新数值表格和图形，不自动改写正文结论。** 修改参数后需同步审核正文中的面积、核数、百分比、轨迹端点和图注中的上下文范围。`make check` 核对默认测量输入，并检查历史工作量保持不变；自定义参数用独立输出目录和 `make test` 验证，不要求新硬件结果匹配历史值。

## 建模口径

设每阵列包含 `m*n` 个 DP，单 DP 面积为 `a_j`，基准阵列面积占比为 `alpha`，基准核数为 `N0`：

```text
A_T,j = m*n*a_j
A_O,0 = (1/alpha - 1)*A_T,0
A_budget = N0*A_T,0/alpha
A_core,j = A_T,j + A_O,0 + growth*(A_T,j - A_T,0)
n_j = floor(A_budget/A_core,j)
C_j,f = n_j*m*n*2*k_j,f*frequency
P_j,f = n_j*m*n*p_j,f
T_j = sum_f(F_f/C_j,f)
E_j = sum_f(F_f*P_j,f/C_j,f)
```

默认 `growth=0`，固定每个核心的外围面积；预算为等效核心池面积，并非商业芯片实测 die 面积。固定频率、充分利用的模型中，增加实例同时增加功耗和吞吐，所以实例数在单位工作能耗中抵消。外围面积不能按比例换算外围功耗。

三角坐标是 H/Q/E 的 **FLOP 占比**，不是执行时间占比。吞吐分区比较总时间；能耗分区比较总 DP 能耗。MX/NV 两类 FP4 使用相同峰值，数据结构保留独立功耗字段。当前 NV 功耗取 MX 代理，因此图中编码选择区域完全重合，不能据此声称实际 NV/MX 能耗相同。换入独立 NV 功耗后，绘图支持标出随编码混合比例改变的区域。

两类轨迹均由配置和计算公式重算：

- `reference_work`：BF16 归 H、FP8/W4A8 专家归 Q、原生 MXFP4 索引归 E。
- `nvfp4_experts`：仅把路由专家 gate/up/down 三个 GEMM 转为 NVFP4 W4A4，其余工作量不变。

三模型均统计纯文本冷 prefill 的有效 GEMM；V4.1 包含 CED 缓存构建与有限窗口重放。FP32 单独统计并排除出 H/Q/E 分母。这是由已固定版本来源导出的计算需求，不是现场运行 vLLM 的 trace，不代表量化精度验证或端到端延迟实测。

当前 12 nm 功耗来自 Qwen3-8B 第一层 MLP down-projection 的连续活动窗口，用于 DeepSeek 工作量时属于活动代理。H 以 BF16 代表，NVFP4 暂用 MXFP4 功耗；结果不包含外设、存储、通信及停顿能耗。本次写作复用已有硬件测量，未重新运行 EDA 或模型推理。

更新输入后可运行：

```bash
python3 scripts/import_dp_measurements.py
make check
make test
```

导入脚本读取仓库中固定批次的六架构 CSV，并保留来源 hash、测量工况和代理说明。若要更新测量批次，应修改导入来源并核验测量条件。

## 目录与结果

- `sections/`：摘要及六章正文；微架构与增配为 `03_architecture.tex`，成本表征为 `04_evaluation.tex`，DSE 为 `05_dse.tex`，结论为 `06_conclusion.tex`。
- `references/references.bib`：文献和 BibTeX 格式控制条目；五项 DP 相关工作的比较条件另存于 notes。
- `figures/`：正文插图；四张原有架构/格式图保留 PNG，其余提供绘图代码。
- `tables/`：固定面积部署、MXFP4 区域占比及 prefill 端点三张表，由脚本生成。其余表格在章节内维护。
- `data/inputs/`：可修改的实验输入。
- `data/results/`：重新计算的核数/算力/功耗 CSV、两类模型点与逐配比结果、工作量账本、扫描结果、精确区域及输入 hash。由 Git 忽略，随时重建。
- `data/expected/`：历史论文的五份精简基准，不参与新结果计算；当前回归核对其中不应随硬件变化的工作量字段。
- `data/evidence/`：输入来源、版本、校验和及其他正文表格的紧凑证据；原始路径仅用于溯源，不是运行依赖。
- `template/`、`submission/`：保留目标工程原有模板来源、投稿要求和 AI 使用记录。

默认面积预算为 496.59255257088006 mm²，四配比核心数为 36/34/32/29，两类映射共 42 个工作量点、168 个配比评估。1:2:6 的延迟/能耗最优区域分别占 7.94%/2.84%，旧稿的“无优势区域”结论不再适用。模型输出为计算服务时间和 DP 活动能耗，不能表述成整芯片实测。

## Select8 成本与 DP 面积占比图

运行 `make cost-figures` 可重建历史 Select8 面积与功耗图；当前正文不引用这些图。[Select8 数据说明](data/DP_area_power/README.md) · [PETile 参考图](figures/H16Q32E64_area_pie.png)

新版六种 DP 的七类面积与总功耗分别保存在两张 CSV。运行 `make dp-share-figures` 重绘六张面积图和六张总功耗图。[面积](data/H16Q32E64_area/README.md) · [总功耗](data/H16Q32E64_power/README.md)


## 图表排版约定

图片使用单栏 `figure`，宽度不超过 `\columnwidth`。组合图用 `\subfloat` 编号及命名，图内不嵌入图片标题；模型、符号、颜色、子图含义和比较条件在图下 `caption` 说明。当前两张负载三角图上下排在同一栏，使用已有 PNG 和绘图代码。架构图保留作者素材与空缺图位，不自动绘制。

相关工作比较使用原生 LaTeX 双表：`tables/related_features.tex` 是精度/功能勾选矩阵；`tables/related_ppa.tex` 按工作分列、按精度分行列出实现条件和效率。两表包含五项相关工作及本设计，采用跨栏表格保持文字可读性，不作为图片插入。数值来源与换算见 `references/notes/dp_comparison.md`。
