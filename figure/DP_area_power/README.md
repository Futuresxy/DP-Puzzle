# DP 面积与功耗合图

从仓库根目录运行，使用 Python 3、NumPy 和 Matplotlib。

```bash
python3 figure/DP_area_power/plot_latest6_area_power.py --scope nine
```

输出为本目录的 `out/dp_ratio_area_power.pdf`。红色倍率以 `1:2:4` 的综合面积为基准，黑色倍率以该设计的 MXFP8 总功耗为基准，金框标出基准功耗柱。使用 `--output-dir` 可指定其他目录。

| 数据 | 用途 |
| --- | --- |
| [dp11_area_power_fixed_20261116.csv](dp11_area_power_fixed_20261116.csv) | 11 种 DP 的冻结面积（µm²）和分精度总功耗（mW）。合图使用其中 9 种同时支持 BF16、MXFP8 和 MXFP4 的配比。 |
| [dp11_area_power_source_20261112.csv](dp11_area_power_source_20261112.csv) | 逐测量点的来源记录。固定版本、工况、run/export ID 的追溯入口见[原来源清单](dp11_area_power_fixed_20261116.sources.json)。 |
| [q32e64_updated_20261117.csv](q32e64_updated_20261117.csv) | 作者于 11 月 17 日另行给出的优化版 `0:2:4` 整单元数据。面积 9,762.99 µm²，MXFP8、MXFP4 总功耗分别为 12.236951 和 9.189959 mW。两条作者记录均未附 run ID。 |
| `latest6_area.csv`、`latest6_power.csv`、`latest6_sources.json` | 11 月 10 日六种 DP 的测量快照，含 15 个支持的精度点。原脚本的 `--scope six` 与 `--scope ratios` 读取这些数据。`ratio4_costs.csv` 保留四配比的派生结果。 |
| `selected8_area.csv`、`selected8_power.csv`、`sources.json` | 较早的八种设计输入，保留原绘图入口 `plot_area_power.py`。 |

合图数据采用 N12 TT、0.7 V、85 °C、1 GHz。功耗来自 Qwen3-8B 第 0 层 MLP down_proj 输入驱动的门级活动，统计范围为综合后、CTS 与布线前。空白功耗表示该设计不支持相应精度。
