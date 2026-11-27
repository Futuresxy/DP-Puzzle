# RTX 4090 BF16 K16 MMA 与 DP 的同输入精度对比

2026-11-27 在本机 NVIDIA GeForce RTX 4090（SM 8.9，驱动 610.57.04，CUDA 13.1.115）实测。RTX 4090 的最大误差为 **32 个 FP32 ULP**，E96 RTL 的默认 28/40 窗口为 **3 ULP**，29/40 候选为 **1 ULP**。所有实现均使用同一套 961 笔 BF16 K16 A/B 和 FP32 C，以及相同的数学 golden。

| 实现 | 与数学参考逐位一致 | ≤1 ULP | ≤3 ULP | 最大 ULP |
| --- | ---: | ---: | ---: | ---: |
| RTX 4090 PTX MMA | 644 / 961 | 904 / 961 | 948 / 961 | 32 |
| E96 Verilog 28/40 | 958 / 961 | 960 / 961 | 961 / 961 | 3 |
| E96 Verilog 29/40 | 959 / 961 | 961 / 961 | 961 / 961 | 1 |

逐笔比较时，28/40 的 ULP 更小 316 笔、相同 644 笔、较大 1 笔（ID 113，RTL 3 ULP，GPU 2 ULP）。29/40 的 ULP 更小 317 笔、相同 644 笔。全部 961 笔的 FP32 输出位型及 ULP 保存在 [results.csv](results/results.csv)，分段统计和 RTL 回执见 [summary.json](results/summary.json)。

## 最差样本

4090 最差的 ID 511 来自 `batch512_ai_load`。FP32 数学 golden 为 `b986dfe0`，GPU 输出为 `b986dfc0`，绝对误差为 `2^-30`，即约 `9.31×10^-10`。精确点积加 C 的幅值约 `2.57×10^-4`，而各项绝对值之和约 `5.24×10^-2`，比值约 204。抵消后输出落入较小的指数区间，使差值折合为 32 ULP。两个 RTL 配置该笔均输出 `b986dfe0`。三个附加抵消探针中，4090 用其中一种 K 排列计算 `+1 − 1 + 2^-28` 时输出零，换一个排列后保留了残差。这三个探针独立记录于 [summary.json](results/summary.json)，961 笔统计采用固定语料。

## 执行与复核

每笔请求占一个 32 线程 warp。A 和 B 的原始 BF16 编码分别装入矩阵 A 第 0 行和 B 第 0 列，原始 FP32 C 进入 `C[0,0]`，读取 `D[0,0]`。K 顺序与测试向量保持一致，其余矩阵位置置零。CUDA 源码内联 `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32`，以 `-arch=sm_89` 编译。反汇编中该 kernel 有一条 `HMMA.16816.F32.BF16`。16 笔单项映射探针覆盖每个 K 位置并使用非零 C，全部逐位通过。三次 GPU 重放的逐笔结果和反汇编一致。[CUDA 源码](bf16_k16.cu) · [反汇编](results/bf16_k16.sass) · [NVIDIA PTX MMA 合同](https://docs.nvidia.com/cuda/parallel-thread-execution/index.html#warp-level-matrix-instructions-mma)

数学参考对已量化输入做精确有理数点积和加 C，最后舍入一次至 FP32。重算得到的 961 笔数学位型全部与已提交 golden 一致。RTL 列来自先前的冻结 Verilog 重放，脚本核对同一输入 SHA-256 和 RTL 结果 SHA-256 后按 ID 配对。[测试输入](../../dp/bf16/K16/correct_961/inputs.txt) · [数学参考](../../../reference/exact.py) · [RTL 结果记录](../../../results/bf16-rtl-precision-20261127.json)

从仓库根目录运行，`--out` 指向新的输出目录。带上 `--rtl-record` 可读取对应的本地 RTL 运行产物并生成逐笔配对表。

```sh
CUDA_VISIBLE_DEVICES=0 python3 test/data/nvidia/bf16_k16_rtx4090/replay.py \
  --rtl-record test/results/bf16-rtl-precision-20261127.json \
  --out test/runs/nvidia/bf16_k16_rtx4090_replay
```

据此可表述为，在所测 BF16 K16 语料和指定指令下，项目默认 RTL 的最大 FP32 ULP 低于 RTX 4090，且整套语料满足 3 ULP；29/40 候选整套满足 1 ULP。跨格式或其他原生 K 的验收需要对应语料、指令和测试结果。
