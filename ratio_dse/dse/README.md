# DP-Puzzle · 第五章芯片配比与精度迁移实验

从单 DP 的测量数据和一份 JSON 得到芯片峰值吞吐、分场景计算时间、配比得分与两张矢量图。目录可单独复制运行。自带九种全精度 DP、DeepSeek-V4.1-Flash 的算子形状与原始精度、五个累积迁移场景，以及 FreeInference 首次调用的长度直方图。运行时无需模型权重、网络、EDA 工具或论文目录。

## 运行和复核

在本目录运行。Python 3.11+，Linux/macOS。数值实验依赖 NumPy，绘图额外使用 Matplotlib、TeX Live（latex、type1cm/type1ec、PSNFSS Times 等字体包）。环境对应版本见 requirements.txt。

```bash
python3 -m pip install -r requirements.txt

# 两个实验共用 11 个区间上界和实际请求频率
python3 run.py --config study.json --output results
python3 verify.py results

# 逐表复现投稿稿：扫描使用原始正整数长度，固定预算仍按区间上界
python3 run.py --sweep-lengths observed --output results-paper
python3 verify.py results-paper

# 比较长度统计口径，导出两个优势区域图和参考切片，CSV 标出每个变化格
python3 compare_sweeps.py results-paper results --output results-comparison

# 自选场景，All 对选中的场景重新归一化
python3 run.py --scenarios C D E --output results-cde
```

纯数值运行加 `--no-plots`。之后可独立改图并执行 `python3 plot.py results --output results-figures`。要替换 DP 成本，用 `--hardware your_dp.csv` 或修改配置中的路径。JSON 内所有输入路径相对该 JSON，命令行路径相对当前工作目录。每次运行的 manifest.json 记录实际配置、权重、输入、脚本及结果文件的 SHA-256。verify.py 专用于完整的默认对照实验，自定义配置的得分不应预期等于论文。

## 输入与迁移

| 输入 | 可修改项和单位 |
|---|---|
| study.json | 选择基线配比、基线物理核心数、DP/core、固定点 α/β、扫描区间、绘图分档、场景 ID 与上下文上界。扫描三元组为 [最小值, 最大值, 分档宽度]。 |
| inputs/dp9_area_power.csv | 每行一个独立设计。area_um2 为单 DP 面积，h/q/e_native 是三种模式的每笔 MAC 数，三列 total_mw 是各模式活动总功耗，idle_mw 是该设计的空闲漏电代理。频率以 Hz 计，ii_cycles 是相邻点积的发射间隔。新增候选按相同列填写，ratio 为唯一标识，算力由 K 列推导。默认使用同一 12 nm、TT、0.7 V、85 °C、1 GHz 的综合后数据。 |
| inputs/deepseek_v41_flash.json | 随包保存的公开模型配置。deepseek_v41.py 按模型结构手工分解 GEMM，生成层、形状、计算精度和整数 FLOP 数。采用 batch=1 的 CED 冷启动 prefill，包括 encoder、decoder cache build/replay 与原生 indexer。 |
| inputs/migrations.json | groups 给出可迁移算子名。场景可声明 parent，继承前一场景，只填写 changes。组未指定时继承，未覆盖的算子保留原始精度。可添加精度组或自定义场景，无需更改评分/绘图代码。 |
| inputs/agent_first_histogram.csv | input_tokens,requests 两列。默认是 2026-08-30 至 09-05 的 FreeInference 周分区 step=0，共 2,047 条请求、1,971 个不同长度。来源、版本、提取条件及 SHA-256 见 inputs/provenance.json。替换时提供已计数的正整数长度，最大长度不得超出配置的最后一档。 |

A 使用基线精度，routed gate/up/down 的 W4A8 使用 FP8 算力。B 将 routed experts 改为 FP4。C 继承 B，将主注意力 SWA/CSA QK/PV 和 grouped O-down 改为 FP8。D 将 shared experts 和 Q-up/O-up 改为 FP4。E 将主注意力及 grouped O-down 进一步改为 FP4。Q-down、原生 FP4 indexer 和其余未指定算子沿用原映射。FP32 工作单列。原始模型的 FP8、FP4 用对应的 MXFP8、MXFP4 硬件容量计时。

默认配置已有完整 A–E 数据。`reference/operator_flops.csv` 保存**从原始论文账本独立提取**的 11 个长度 × 算子 × 原精度工作量，`reference/cases.csv` 保存 55 组分精度 FLOP 数。实际运行从形状重新计算，reference/ 仅用于对照。若只修改某个算子，可在 migrations.json 将其划入单独、不重叠的组，再在新场景 changes 中指定 BF16、FP8 或 FP4。选子集时仍加载其祖先的迁移。默认所有选中场景等权，需要改变时在 study.json 设例如 `"scenario_weights":{"A":4,"B":2,"C":1,"D":1,"E":1}`。

## 硬件、评分与预算扫描

设基线核心数 N₀、每核 D 个 DP、候选面积相对基线为 r。芯片面积在每次架构比较中固定，外围每核面积相同。以基线阵列面积占比 α 标定后，物理核数为 floor(N₀ / (1 + α(r−1)))。每扫一个 α，重新用 N₀ 个基线核心标定该点的共同面积预算。

阵列功耗预算 B = β N₀ D maxₚ P₀,ₚ。对各精度分别选取满足 D[n Pⱼ,ₚ + (Nⱼ−n) Iⱼ] ≤ B 的最大整数 n ≤ Nⱼ。默认空闲功耗 Iⱼ 取三份活动报告中的最大静态功耗。该模式的可用 FLOP/s 为 2 f D K n / II。整数边界由有理数计算。无可用核心且有计算需求时，候选用时为无穷大、得分为零。这个计算模型假定满阵列利用率与充分供数，预算覆盖 DP 阵列；不计外围功耗、格式转换、FP32 服务时间和端到端推理开销。

两项实验使用同一条 trace 与同一组所选场景。`fixed_lengths` 和 `sweep_lengths` 各自选择下列口径。

- **upper_edge（默认）**：每个请求映射到首个大于等于输入长度的上界，按落入该档的请求数加权。首档 (0,1024]，末档 (524288,1048576]，空档权重为零。
- **observed**：对每个不同的实际 token 数计算算子 FLOP 数，再按出现次数加权。

每请求的理想 GEMM 时间是各精度 FLOPs/可用 FLOP/s 之和。先按请求频率平均时间，再按所选场景权重平均时间，最后用同预算基线的平均时间除以候选时间得到 All 加速比。扫描中在每个物理/活跃整核数变化处精确切分参数空间。每个显示格中取最低时间所覆盖参数面积最大的配比，参考面积切片改按功耗区间长度计。并列按比例平分，所有并列者保存在 budget_bands.csv，绘图按输入顺序择一。band_speedup 为该格内固定一颗芯片时的平均时间之比。点、整档、整个扫描域的赢家对应不同问题。

## 输出与论文校对

| 输出 | 内容 |
|---|---|
| hardware.csv | 物理核数、各精度活跃核数、阵列功耗使用量/预算与可用 TFLOP/s |
| operator_flops.csv / scenario_operators.csv / cases.csv | 各上下文的原生逐算子 FLOPs、各场景的实际精度映射、各场景各长度的 H/Q/E 与排除的 FP32 FLOPs |
| context_weights.csv / weighted_work.csv | 11 档请求数、实际权重和按所选长度口径加权的每场景计算量 |
| upper_edge_times.csv | 每颗芯片 × 每个场景 × 每个区间上界的理想 GEMM 秒数、同预算基线秒数、加速比、请求数和权重（默认 495 行）。在统一上界模式下，程序逐项核对这些秒数加权后的结果等于逐场景用时。 |
| fixed_scores.csv / sweep_reference_scores.csv | 固定 α、β 下每个设计、每个场景及 All 的时间、加速比、名次；后者与扫描使用同一长度口径 |
| budget_cells.csv / budget_bands.csv | 精确分片每颗芯片的得分；每个显示格和参考切片中各配比的胜出份额、区间加速范围和平均时间赢家标记 |
| reference_bands.csv / domain_scores.csv | 参考面积的功耗区间赢家与收益；对扫描矩形均匀加权时各固定设计的总得分 |
| budget_sweep.pdf / five_scenarios_compare.pdf | 实验一优势区间与参考面积切片；实验二核数、分场景与 All 加速热力图 |

[两种扫参口径的对照图及完整区间表](comparison/README.md)。完整论文复现逐项核对 27 个硬件设计/精度点、308 行原生算子工作量、55 个场景×长度组合、54 行固定预算得分、2,340 行预算格/切片设计记录。统一上界方案在默认固定点给出相同的 1:4:8、29 个物理核、BF16/MXFP8/MXFP4 活跃 29/19/28 核和 1.145448× 综合加速。两种长度口径下 240/250 个预算格与参考切片 10/10 档的优势配比相同。reference/ 的数值来自原论文证据快照，历史硬件测量的留存范围及来源见 inputs/provenance.json。
