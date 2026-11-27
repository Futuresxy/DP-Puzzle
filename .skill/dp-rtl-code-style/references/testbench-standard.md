# Testbench 架构、CModel 断点差分与验证流程标准

本文件吸纳 Vortex GPGPU（`hw/unittest/tcu_fedp/` 及 `docs/debugging.md` 的 `SimX-as-Oracle` 方法论）与 DP-Puzzel 硬件门禁要求，定义可用于真实工程实践的 Verilog-2005 Testbench 编写标准。

---

## 1. 双层验证体系（Two-Tier Verification Architecture）

### 1.1 第一层：模块级自检单元测试（Block-Level Unit Testbench）
适用于算术子模块（CSA 树、加法/移位器、LZD、FP32 舍入）、解包模块（`dp_lane_unpack*`）或局部流水模块：
- **内建精确参考模型（Golden Oracle）**：在 TB 内用纯 Verilog 函数或行为级循环计算精确期望值，与 DUT 输出实时比对（使用四态全等 `!==` 严查 `X`/`Z` 传播）。
- **结构化特征激励覆盖（Feature-Driven + Corner + Seeded Random）**：
  借鉴 Vortex `hw/unittest/tcu_fedp/main.cpp`，激励必须显式划分为确定性特征阶段与伪随机阶段：
  1. **零值与符号（Zeros）**：`+0.0`、`-0.0`、全负乘积和为零（检验负零符号保留）。
  2. **正规数边界与抵消（Normals）**：最小正规数、最大有限数、`1.0` 附近、正负对称完全抵消对（`+X` 与 `-X`，检验 `sig_zero` 与 MAX 树屏蔽）。
  3. **非正规数（Subnormals）**：最小 LSB subnormal、最大 subnormal、舍入跨越最小正规数边界。
  4. **无穷大与非法运算（Infinities & Invalid）**：`+Inf`、`-Inf`、`(+Inf) + (-Inf)` 冲突转 NaN、`0 * Inf` 转 invalid NaN。
  5. **NaN 传播（NaNs）**：`qNaN`、`sNaN`、块缩放因子 NaN（如 E8M0 `0xFF`、UE4M3 `0x7F`）。
  6. **块缩放与元数据（Scales & Metadata）**：MX E8M0、NVFP4 UE4M3、HiF4 E6M2 及 `e1[1:0]`/`e2` 全组合。
  7. **整数边界（Integers）**：`0`、`MIN_INT`（`-2^(W-1)`）、`MAX_INT`（`2^(W-1)-1`）、`-1`、奇偶交替符号。
  8. **动态协议压力（Protocol & Gating Stress）**：
     - 连续有效（`II=1` 满吞吐）；
     - 周期性/随机气泡（`in_valid = 1'b0`，验证无复位 `dp_lib_DFFE` 保持且不产生虚假有效输出）；
     - 逐拍动态切换 `in_datatype`（如 `FP16 -> MXFP4 -> HiF4 -> INT8 -> BF16`，验证精度门控寄存器在目的级正确恢复结构零，无旧值残留）；
     - 在途同步复位脉冲（`rst_n = 1'b0`，验证在途 valid 全部清零取消，恢复后首笔请求精确通过）。

### 1.2 第二层：顶层流水线与 CModel-as-Oracle 断点差分（System Pipeline TB）
适用于 `dp_top`、`dp_top_e`、`dp_top_mixed` 及各算力配比顶层（`test/rtl_tb/dp_tb.v`、`dp_mixed_tb.v`）：
- **统一外部驱动接口**：通过 `+INPUTS=<path>`（`DP_INPUTS_V1`）、`+GOLDEN=<path>`、`+SCHEDULE=<path>`、`+OUTPUT=<path>` 驱动。
- **CModel-as-Oracle 逐级轨迹差分（Cutpoint Trace Diffing）**：
  - 当多级流水顶层出现数值偏差时，**严禁在 RTL 中靠猜乱改或到处散落临时 `$display`**。
  - 启用 `+CUTPOINTS=<trace_path>`，在每个 `@(negedge clock)` 对当前级 `rN_valid == 1'b1` 的在途请求（由 `pending[N-1]` 标识请求 ID）导出标准化阶段快照：
    - `S1`: `layout_a` / `layout_b`（解包尾数、指数、符号）
    - `S2`: `product` / `anchor`（各槽无符号乘积、组公共指数 MAX）
    - `S3`: `leaf` / `raw_anchor`（局部对齐后的补码叶子、预计算 anchor）
    - `S4`: `lane`（lane 树规约有符号和 `out_sop`）
    - `S5`: `group` / `c`（组幅值、anchor、`compare_exp`、`z`、special 与 C 解包 token）
    - `S6`: `aligned`（全局对齐后的补码叶子与全局共同 anchor）
    - `S7`: `sum`（最终 CSA+CPA 规约总和）
  - 将 RTL cutpoint 文件与 CModel trace 直接 diff，**第一个出现差异的 stage 与 request ID 即为精确根因位置**。

---

## 2. Testbench 时钟边沿与记分牌守恒规范

1. **时钟边沿分工（防竞争冒险）**：
   - **`@(negedge clock)`**：更新 `rst_n`、`in_valid`、`in_datatype` 与所有输入操作数。
   - **`@(posedge clock)`**：此时组合输出（如 `out_a_ready`）和当前拍寄存器输出（如 `out_valid`、`out_d`）已稳定且尚未被当前上升沿的 NBA（`<=`）覆盖，在此刻执行握手断言、输出比对与 `pending` 移位队列更新。
2. **在途请求记分牌与排空守恒**：
   - 维护 `integer pending_req_id [0:LATENCY-1]`，初始化为 `-1`。
   - 若 `~rst_n`：将 `pending_req_id[0..LATENCY-1]` 中所有 `>= 0` 的项计入 `cancelled_count`，并全部重置为 `-1`。
   - 若 `rst_n`：
     - 检查 `out_valid !== (pending_req_id[LATENCY-1] >= 0)`；若失配立即报错 `$finish`。
     - 若 `pending_req_id[LATENCY-1] >= 0`，用 `!==` 比对输出数据与期望表，通过则 `checked_count = checked_count + 1`。
     - 将队列向高级移位：`pending_req_id[k] = pending_req_id[k-1]`，`pending_req_id[0] = req_fire ? current_req_id : -1`；若 `req_fire` 则 `accepted_count = accepted_count + 1`。
   - **结束门禁**：激励结束后继续运行 `LATENCY` 拍排空流水线，最终必须验证 `accepted_count == checked_count + cancelled_count` 且 `checked_count > 0`。

---

## 3. Testbench 代码编写规范

Testbench 代码与 RTL 保持同等级别的整洁度：
- **单行单声明，按角色分组注释**：将 TB 变量分为“时钟与 DUT 接口信号”、“记分牌与统计计数器”、“黄金参考存储与随机种子”三组，每行一个 `reg` / `wire` / `integer`，禁止十几个变量用逗号挤在一行。
- **强制 `begin` / `end`**：所有 `if`、`else`、`for`、`while`、`task`、`initial` 块必须使用完整的 `begin ... end`，禁止单行塞入多个语句（如 `if (err) begin $display(...); $finish; end` 应规范分行缩进）。
- **DUT 例化对齐**：参数与端口每行一个，左括号 `(` 垂直列对齐。
- **确定性种子与标准输出**：伪随机测试必须固定初始 seed 并在最终 `PASS` 行打印：`PASS cycles=%0d accepted=%0d checked=%0d cancelled=%0d seed=%0h`。

完整可运行示例见 [dp_pipeline_boundary_example_tb.v](../assets/examples/dp_pipeline_boundary_example_tb.v)。
