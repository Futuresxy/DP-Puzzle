# DP 功能面积饼图

```bash
python3 figure/H16Q32E64_area/plot_area.py
```

从仓库根目录运行，六张环图输出到本目录的 `out/`。[area.csv](area.csv) 保存 2026-11-10 批次六种 DP 的七类功能面积，共 42 行，单位为 µm²。每张环图以对应设计的七项面积之和为分母。`plot_area_comparison.py` 可另外绘制基线、Q32E64 与 E64 的面积分解对比，三条柱均以基线总面积为分母。

默认输出为 600 dpi PNG，支持 `--dpi` 和 `--figure-dir`。如有新批次的分类报表，原脚本的 `--refresh-from` 可显式导入 `seven_functions_area.csv` 与 `seven_functions_power.csv`，同时更新两份绘图输入。[同批功耗分项](../H16Q32E64_power/power.csv) · [DC 面积记录](../../hw/dc_syn/records/v19_six_dp_20261110.md) · [原始分类与对账](https://github.com/Futuresxy/DP-Puzzel/blob/0582ed58e556e33e13c59bfec8fed787c1f77343/paper/data/H16Q32E64_area/v19_six/README.md)
