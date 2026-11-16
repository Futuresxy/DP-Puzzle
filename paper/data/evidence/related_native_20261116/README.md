# Table I / IV：原工艺比较修订

本批仅修改 `main_temp.tex` 和其独立表格/引用。正式入口、共用表格及章节保留；历史工艺归一化计算不覆盖或删除。

## 改动

- Table IV：取消 DeepScaleTool / 14 nm 代理转换，全部采用原工艺效率；删除 Formats 和 Evaluation 两行。Structure 仅保留结构类型。保留 DP-Puzzle 1:2:4 和 0:2:4 两列。
- 增加 MiniFloats 2024 独立 wDotp FPU；FPnew 已存在，改用 2021 正式期刊引用，不重复列入。
- 按用户最新截图，MiniFloats **能效** FP8/FP16 = 1.63/0.82 TFLOP/s/W，**面效** = 1.06/0.53 TFLOP/s/mm²。这纠正了之前文字的倒置。截图存为 `user_comparison.png`；中间 GLSVLSI23 列不是本次要求的工作，不额外加入。
- FPnew 仍取原文较完整数值：FP16/BF16/FP8 能效 0.49767/0.58196/1.24478，面效 0.15143/0.15143/0.30265，显示到三位小数；和截图粗舍入值对应，不使用归一化后的 0.786/0.919/1.966 等值。
- Table I：增加 MiniFloats 行，保留 FPnew 行并更新引用；两者支持 FP16、BF16 编码的 FP16alt 和 FP8 元素运算，不标作集成 MX scaling。表注补充 FP32/64 与 MiniFloats 的 FP8 E5M2/E4M3。

## TransDot 估算

原文相对面效 1.46×/2.92× 是其内部 12 nm FPnew 基线上的跨时序点平均值，不能乘以本表 22 nm FPnew 的 SIMD 面效。图 7(a) 的 1000 ps 处，full TransDot 单元面积约 6000 μm²；表 II 的 4/8/16 GFLOPS 对应约 0.67/1.33/2.67 TFLOP/s/mm²，均以 `≈` 和 † 标识。此为原图估读及除法推算，不是原文精确表列的绝对面效，也不是新实测；未使用 100×100 μm 的版图占地作为标准单元面积。相对倍率及范围完整保存在 `sources.json` / `manifest.json`。

## 复现及保护范围

运行 `python scripts/build_related_native.py` 生成 `tables/temp/related_ppa_native.tex`、36 行效率 CSV 和指纹清单；再运行 `make pdf-temp`。没有调用会覆盖正式表的历史 normalize_table.py。

由于 Table I 已嵌在用户引言中，临时稿内独立复制当前引言，只改变该表；表外引言正文逐字保留。硬件评价章同样复制到临时稿，只改末尾相关工作比较小节。`snapshot_checks.json` 记录复制与保留检查。用户后续对共用引言的修改不会自动进入这一临时副本，合并时以用户最新正文为准。摘要始终只读引用。

已核对原始格式/工况、截图行顺序、能效倒数及面积单位；编译并查看 Table I 和 Table IV 的整页排版。原工艺跨工作数值用于条件透明的比较，正文只对本项目同工况两种 DP 给出增益。来源和复核定位见 `sources.json`。
