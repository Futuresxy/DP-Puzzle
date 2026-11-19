# DP-Puzzle 芯片算力配比与 DeepSeek-V4.1-Flash 精度迁移实验

给定一份实验 JSON 和一张单 DP 面积、功耗表，模型在相同预算下比较不同算力配比的芯片。**查看指定预算下的性能，读 `fixed_scores.csv`**。每个配比在每个迁移场景各有一行，另有一行 `All` 汇总所选场景。时间单位为秒，表示 batch=1 冷启动 prefill 中所建模 GEMM 的理想计算时间。运行所需的算子形状、精度映射、硬件数据和请求长度直方图都在本目录中。

**调整核数、每核 DP 数、α 或 β 时，只改 `study.json` 即可。** 换单 DP 面积和功耗时改 `hardware` 指向的 CSV，换算子精度时改 `migrations` 指向的 JSON，换请求分布时改 `trace` 指向的直方图。默认五场景可以直接使用随包的 `inputs/`。

## 1. 跑通默认五场景

从仓库根目录执行以下命令。如果当前位于 `paper/`，第一行用 `cd ../ratio_dse/dse`。后续示例均在 `ratio_dse/dse/` 下执行。运行环境为 Linux/macOS、Python 3.11+。

```bash
cd ratio_dse/dse
python3 -m pip install -r requirements.txt
python3 run.py --config study.json --output results --no-plots
python3 verify.py results
```

`run.py` 一次生成固定预算的结果和面积、功耗扫描结果。终端先按 `All` 排名打印各配比的平均秒数和加速比。仅计算 CSV 时使用 NumPy，去掉 `--no-plots` 会在同一结果目录生成两张 PDF。已有数值结果也可用 `python3 plot.py results --output results-figures` 单独绘图。绘图需 Matplotlib 与带有 type1cm/type1ec 和 Times 字体包的 TeX Live。

默认输入为九种 DP、五个迁移场景和 11 个上下文长度。固定点取面积占比 α=0.327、阵列功耗预算倍率 β=1，基线为 `1:2:4`。按以下方式查看结果，可将配比替换成任一 CSV 中的标识。

```bash
# 指定芯片在 A–E 及 All 下的理想时间、基线时间、加速比和名次
awk -F, 'NR==1 || $1=="1:4:8"' results/fixed_scores.csv

# 所有候选芯片的综合结果
awk -F, 'NR==1 || $2=="All"' results/fixed_scores.csv

# 拆开一个场景，查看该芯片在各上下文上界的请求数、权重及用时
awk -F, 'NR==1 || ($4=="E" && $5=="1:4:8")' results/upper_edge_times.csv
```

默认运行应得到以下数值。各场景行已经按上下文请求频率加权，`All` 再对五个场景等权。

| 场景 | 1:2:4 基线（秒/请求） | 1:4:8（秒/请求） | 相对基线加速比 |
|---|---:|---:|---:|
| A | 4.774060 | 4.818038 | 0.990872× |
| B | 3.822814 | 3.627192 | 1.053932× |
| C | 3.177529 | 2.636427 | 1.205240× |
| D | 2.643187 | 1.967496 | 1.343427× |
| E | 2.320544 | 1.563586 | 1.484117× |
| **All** | **3.347627** | **2.922548** | **1.145448×** |

## 2. 配置核数、阵列、预算与候选 DP

先复制两份可编辑的输入。以下示例将基线改为 **32 核，每核 2 个阵列、每阵列 64 个 DP**，同时保留五个场景和真实请求分布。

```bash
cp inputs/dp9_area_power.csv dp-local.csv
cp inputs/migrations.json migrations-local.json
```

在 `study.json` 同级新建 `study-local.json`，内容如下。JSON 内的输入路径均相对于该 JSON 所在目录。

```json
{
  "hardware": "dp-local.csv",
  "model": "inputs/deepseek_v41_flash.json",
  "migrations": "migrations-local.json",
  "trace": "inputs/agent_first_histogram.csv",
  "contexts": [1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576],
  "scenarios": ["A", "B", "C", "D", "E"],
  "baseline": "1:2:4",
  "baseline_cores": 32,
  "dp_per_core": 128,
  "alpha": "0.327",
  "beta": "1",
  "fixed_lengths": "upper_edge",
  "sweep_lengths": "upper_edge",
  "sweep": {
    "alpha": ["0.25", "0.50", "0.01"],
    "beta": ["1", "2", "0.1"]
  }
}
```

| 要调整的量 | 如何设置 |
|---|---|
| 基线与核数 | `baseline` 匹配硬件 CSV 的一行。`baseline_cores` 是基线芯片的物理核数。候选芯片在等面积下可容纳的物理核数、各精度在功耗约束下可开启的核数由模型计算。 |
| 每核阵列数、每阵列 DP 数 | 设置 `dp_per_core = 每核阵列数 × 每阵列 DP 数`。默认 4×64 填 256，示例 2×64 填 128。同一次对比里的所有芯片共用该值，每颗芯片使用一种 DP。阵列形状和调度不单独建模，相同 DP 总数给出相同的建模吞吐。 |
| 固定预算 | `alpha` 是基线 DP 阵列占基线计算核心面积的比例，范围 (0,1]。`beta` 是相对于基线全核运行最高功耗精度时的阵列功耗预算倍率，1 表示持平，1.2 表示可增加 20%。更换基线、核数或每核 DP 数会重新标定绝对预算。 |
| 预算扫描 | `sweep.alpha` 和 `sweep.beta` 分别填写 [下界, 上界, 显示分档宽度]。示例按 0.01 面积占比、0.1 功耗倍率汇总。指定预算下的逐场景结果由顶层 `alpha`、`beta` 决定。 |

### 填写自己的单 DP 数据

在 `dp-local.csv` 中每行填写一种候选 DP，保留指定的基线行。可以删除不参与比较的行，或追加新设计。下面是随包基线行及完整表头，可按相同顺序填写新行。

```csv
ratio,top,area_um2,h_native,q_native,e_native,bf16_total_mw,mxfp8_e4m3_total_mw,mxfp4_e2m1_total_mw,idle_mw,frequency_hz,ii_cycles
1:2:4,dp_top,16165.122154,16,32,64,15.3282642364502,16.0019989013672,11.1965341567993,0.14223475000000002,1000000000,1
```

- `ratio` 是唯一设计标识，`top` 记录实现名称。模型从 `h_native,q_native,e_native` 读取 BF16、MXFP8、MXFP4 每次点积的 MAC 数。基线的 16、32、64 对应 1:2:4。当前输入要求三列均为正整数，适用于三种精度均可运行的候选。
- `area_um2` 是单 DP 面积（µm²）。三列 `*_total_mw` 是单 DP 在对应模式下的活动总功耗（mW，含静态功耗）。`idle_mw` 是同一 DP 的空闲功耗，须非负且小于三种活动功耗的最小值。随包数据取三份活动报告的最大静态功耗作为空闲代理，测量工况为 12 nm、TT、0.7 V、85 °C、1 GHz，综合后。
- `frequency_hz` 为工作频率（Hz），`ii_cycles` 为连续两次发射点积之间的周期间隔。吞吐按 2 FLOP/MAC 计算。

保存后运行以下命令。也可直接用 `--hardware 路径` 覆盖 JSON 中的硬件 CSV，此命令行路径相对于当前工作目录。

```bash
python3 run.py --config study-local.json --output results-local --no-plots
awk -F, 'NR==1 || $1=="1:4:8"' results-local/hardware.csv
awk -F, 'NR==1 || $2=="All"' results-local/fixed_scores.csv
```

## 3. 定义迁移场景与权重

### 从模型结构追到芯片时间

[deepseek_v41.py](deepseek_v41.py) 是本目录内的模型拆解代码。`layer_schedule` 根据 [模型配置](inputs/deepseek_v41_flash.json) 展开 40 个主干层的计算模式及 KV/index 归属，`block_work` 列出该层的投影、注意力、MoE 和 indexer 等算子，`prefill_work` 将 encoder prefill、decoder cache build/replay 和首个输出 token 的 LM head 组合成一次请求。稠密 GEMM 使用 2 × M × N × K × 重复次数计算 FLOPs，变长注意力按实际可见位置对数计算。

论文原始的[逐层算子明细](inputs/deepseek_v41_prefill_operators.csv)也随包提供，共 11 档上下文、8,294 行。一行表示某个输入长度下，一层在一个执行阶段的一个算子。文件保留原始层号、阶段、操作数格式、计算精度、形状、有效位置对数、公式和整数 FLOPs。仅修改预算或场景时可直接复用。

例如，32K 请求在第 0 个 encoder 层的 `q_down` 使用 FP8，M=32,768、N=1,280、K=5,120，执行一次得到 429,496,729,600 FLOPs。跨层汇总时还会计入其他层各自的 `q_down` 调用。

默认运行从模型形状生成同结构的 `results/layer_operators.csv`。[workload.py](workload.py) 将**同一批明细**按算子与原生精度汇总为 `operator_flops.csv`，按 `scenario_operators.csv` 的映射归入各场景的 `cases.csv`。最后使用各精度的可用芯片吞吐计算 `upper_edge_times.csv` 和 `fixed_scores.csv`。例如，以下命令可从 32K 的第 0 层逐项追到各场景时间。

```bash
# 查看 32K 上下文下第 0 层的所有算子、形状与 FLOPs
awk -F, 'NR==1 || ($1==32768 && $4==0)' results/layer_operators.csv
# 查看主滑窗注意力 QK 在各场景实际使用的精度
awk -F, 'NR==1 || $2=="swa.qk"' results/scenario_operators.csv
# 查看该长度下 1:4:8 芯片在五个场景各自的秒数及加速比
awk -F, 'NR==1 || ($1==32768 && $5=="1:4:8")' results/upper_edge_times.csv
```

**直接从已有算子数据运行。** 若已手工整理计算量，可在实验 JSON 顶层加入下面的字段。此时各算子的原始精度和 FLOPs 取自 CSV，后续场景迁移、请求加权和预算扫描沿用同一套代码。去掉该字段则从模型形状重新计算，适用于改变模型维度或引入新的上下文长度。

```json
"operator_ledger": "inputs/deepseek_v41_prefill_operators.csv"
```

可先复制随包明细再编辑，并把配置指向副本。每个使用的长度都需提供完整请求的明细，同一上下文的行放在一起。必填列为 `context,phase,segment,layer_id,batch,kernel,precision,flops`，同一上下文内的 `segment,layer_id,kernel` 组合唯一。`phase` 填 `prefill`，`batch` 填 1，`precision` 填 BF16、FP8、FP4 或 FP32，`flops` 填非负整数。导入时直接使用 `flops` 列。随包 CSV 覆盖默认 `upper_edge` 的 11 个上界。按实际 token 长度运行 `observed` 时，可使用默认的按形状计算模式。

### 五个默认场景与自定义示例

`inputs/deepseek_v41_flash.json` 给出模型参数，`deepseek_v41.py` 从各算子形状计算 prefill FLOPs，覆盖 encoder、decoder cache build/replay 和 indexer。`migrations-local.json` 只需描述哪些算子改用哪种计算精度。内置五个场景逐步继承，每一步沿用父场景中其余算子的精度。

| 场景 | 父场景 | 本步变动 |
|---|---|---|
| A | 无 | 使用原生映射。Routed experts 的 W4A8 用 FP8 吞吐计时。 |
| B | A | Routed experts 的 gate/up/down 改为 FP4。 |
| C | B | 主注意力 SWA/CSA 的 QK/PV 和 grouped O-down 改为 FP8。 |
| D | C | Shared experts 的 gate/up/down 和 Q-up/O-up 改为 FP4。 |
| E | D | 主注意力 QK/PV 和 grouped O-down 进一步改为 FP4。 |

**单独评估 Q-down 迁移到 FP4 的收益。** 先在 `results/operator_flops.csv` 的 `kernel` 列确认算子名 `q_down`。以下命令在本地迁移配置中新建场景 `Dq`，它继承 D，仅将原先的 FP8 Q-down 改为 FP4。算子组名可自定，同一算子只能归入一个组。若算子已在某组中而需要单独控制，先拆分原组，并在原有场景中给拆出的组保留相同的迁移规则。

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path("migrations-local.json")
spec = json.loads(path.read_text())
spec["groups"]["q_down_only"] = ["q_down"]
scenario = {"id": "Dq", "parent": "D", "changes": {"q_down_only": "FP4"}}
spec["scenarios"] = [s for s in spec["scenarios"] if s["id"] != "Dq"] + [scenario]
path.write_text(json.dumps(spec, indent=2) + "\n")
PY

python3 run.py --config study-local.json --scenarios D Dq --output results-qdown --no-plots
awk -F, 'NR==1 || $2=="q_down"' results-qdown/scenario_operators.csv
awk -F, 'NR==1 || $1=="1:4:8"' results-qdown/fixed_scores.csv
```

`changes` 使用算子**组名**和 `BF16`、`FP8`、`FP4`。后两者分别映射到 MXFP8 和 MXFP4 硬件吞吐。父场景须先定义，ID 唯一，`All` 留给汇总。仅选 D 和 Dq 时仍会解析 A–C 的继承关系，综合得分只统计 D 和 Dq。要长期使用自定义场景，将它写入实验 JSON 的 `scenarios` 即可。五场景默认等权。如有使用频率，可在 JSON 顶层增加 `"scenario_weights": {"A": 4, "B": 2, "C": 1, "D": 1, "E": 1}`，此时 A 占 4/9，所有选中场景都须给出正权重。

## 4. 读懂时间、加速比与扫描结果

1. **物理核和开启核。** 设基线核数为 N₀，候选与基线单 DP 面积之比为 r。固定每核外围面积后，等面积可部署核数为 ⌊N₀ / (1 + α(r−1))⌋。设每核 D 个 DP，阵列功耗上限为 β × N₀ × D × 基线三种活动功耗的最大值。每种精度分别取满足预算的最多整核数，同时计入未开启核的空闲功耗。以默认 `1:4:8` 为例，芯片部署 29 核，运行 BF16、MXFP8、MXFP4 时分别可开启 29、19、28 核。
2. **每个场景的时间。** 对一个请求，分别将三种精度的 GEMM FLOPs 除以该模式可用吞吐，再将三段时间相加。可用吞吐等于开启核数 × 每核 DP 数 × 原生 MAC 数 × 2 × 频率 / 发射间隔。模型假设阵列充分供数并满利用，FP32 工作量另列，外围功耗、访存、格式转换和端到端开销在计时范围之外。
3. **请求和场景的权重。** 默认两个实验均使用 `upper_edge`。2,047 条 FreeInference 首次请求按输入长度归入 1K–1M 的 11 档，每档按上界计算（例如 20,000 tokens 使用 32,768），再按该档请求数占比平均各档秒数。`mean_seconds` 是该场景每请求的期望计算时间。`All` 用所选场景权重再平均一次时间。`baseline_seconds` 使用相同预算、请求及场景权重，`speedup = baseline_seconds / mean_seconds`，大于 1 表示快于基线。汇总时先平均秒数，再计算比值。
4. **扫描图的读法。** 程序在物理核数或开启核数改变的位置精确切分参数空间。一个显示格的优势配比为取得最低时间的预算区域占比最大的设计。固定 α 切片按各配比获胜的 β 区间长度计算。平局平分覆盖份额，绘图按输入顺序展示并列者之一。`band_speedup` 是在该格固定使用同一颗芯片时，基线平均时间与候选平均时间之比。

| 想看什么 | 结果目录中的文件与字段 |
|---|---|
| 每个配比在每个场景及整体的结果 | `fixed_scores.csv`。按 `ratio,scenario` 查 `mean_seconds,baseline_seconds,speedup,rank`。默认 9×(5+1)=54 行。 |
| 每个具体上下文下的延时 | `upper_edge_times.csv`。按 `ratio,scenario,context` 查 `seconds,baseline_seconds,speedup` 和该档请求数、权重。默认 9×5×11=495 行。 |
| 实际使用了多少核、多少算力 | `hardware.csv`。按 `ratio,mode` 查 `physical,active,tflops` 及 `array_power_w,array_budget_w`。 |
| 模型算了什么、精度是否迁移成功 | `layer_operators.csv` 为各上下文上界的逐层逐算子原始明细，`operator_flops.csv` 为跨层汇总，`scenario_operators.csv` 对照 `native_precision,compute_precision`，`cases.csv` 汇总每个场景各长度的 H/Q/E FLOPs 和单列的 FP32 FLOPs。 |
| 实际权重 | `context_weights.csv` 列出各长度档的请求数与权重，`weighted_work.csv` 列出各场景按请求加权的工作量。`manifest.json` 保存生效配置、归一化场景权重和文件校验值。 |
| 预算变化时选哪个配比 | `reference_bands.csv` 为固定 α 下各 β 档的优势配比及收益，`budget_bands.csv` 为显示格和切片的各设计获胜份额，`budget_cells.csv` 为精确分片加速比，`domain_scores.csv` 为整个预算域内各设计的综合结果。`sweep_reference_scores.csv` 是采用扫描长度口径的固定点结果。 |
| 两张实验图 | `five_scenarios_compare.pdf` 展示固定预算的核数和逐场景/整体加速比。`budget_sweep.pdf` 展示扫描优势区域和固定 α 切片。 |

## 数据来源与论文复核

随包提供 DeepSeek-V4.1-Flash 模型参数、单 DP 数据和 2026-08-30 至 09-05 的 FreeInference 首次调用（step=0）直方图。原始版本、提取条件和输入指纹见 [inputs/provenance.json](inputs/provenance.json)。自带直方图有 1,971 个不同长度。自换 trace 时，在 `input_tokens,requests` 两列中为每个不同长度提供一次正整数计数，配置的最后一个上界须覆盖最大请求长度。原始论文归档的逐算子 FLOPs 和 55 个场景×长度总量见 [reference/](reference/)。

`verify.py` 用于复核完整默认配置及历史投稿配置。历史扫描按每个不同的原始 token 长度计算（`observed`），固定预算仍取区间上界。可用下列命令重放并比较。两个扫描口径的 250 个预算格中有 240 个优势配比一致，参考 α 切片的 10 档全部一致。详见[对照图及完整区间表](comparison/README.md)。

```bash
python3 run.py --config study.json --sweep-lengths observed --output results-paper --no-plots
python3 verify.py results-paper
python3 compare_sweeps.py results-paper results --output results-comparison
```
