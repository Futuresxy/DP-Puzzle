# DP 分精度功耗饼图

```bash
python3 figure/H16Q32E64_power/plot_power.py
```

从仓库根目录运行，六张图输出到本目录的 `out/`，每张图并列展示该 DP 在 BF16、MXFP8 E4M3 和 MXFP4 E2M1 下的功能功耗分布。[power.csv](power.csv) 保留六种 DP 的七类功能分项，共 42 行。每个精度列记录总功耗（动态加漏电，mW），空白表示该 DP 不支持该精度。每个环图按该模式七个分项的总和计算百分比。

数据来自 2026-11-10 批次，共 15 个支持的精度点。Q32E64 的环图对应该批网表，后续优化版仅有[整单元记录](../DP_area_power/q32e64_updated_20261117.csv)。脚本沿用面积饼图的配色与类别，默认输出 600 dpi PNG，支持 `--dpi` 和 `--figure-dir`。[面积分项](../H16Q32E64_area/area.csv) · [功耗验收记录](../../hw/power/records/v19_six_architectures_20261110.md)
