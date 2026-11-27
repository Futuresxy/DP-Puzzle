# 代码格式、分组注释与数值编码细则

本文件详细规定 DP-Puzzel 项目 Verilog-2005 代码的排版格式、分组注释准则（参考 Vortex `hw/rtl/tcu/`）、头文件组织与多精度数值表达。

---

## 1. 原生排版与对齐规范（禁用 `verilog_format: off/on`）

代码中**严禁出现 `// verilog_format: off` 或 `// verilog_format: on`**。所有代码在编写时直接按以下规则对齐：

### 1.1 模块参数与端口列对齐
- 每个 `parameter` 和端口独占一行。
- 参数区的 `parameter integer` 后参数名左对齐，`=` 纵向对齐；仅非显见配置开关在行尾加 `// ...` 简短说明。
- 端口区按功能分组（组间空行 + 一行分组注释），`input wire` / `output wire`、位宽 `[W-1:0]`、端口名三列纵向对齐：

```verilog
module dp_lane_align #(
  parameter integer LOCAL_W       = `DP_DEFAULT_LOCAL_W,
  parameter integer LEAF_W        = LOCAL_W + 1,
  parameter integer QE_ONLY       = 0,                   // 1: prune T/H/INT8 decode paths
  parameter integer E_FIXED_COORD = 0,                   // 1: E pair bypasses wide shifter
  parameter integer PRODUCT_W     = `DP_PRODUCT_W,
  parameter integer EXPONENT_W    = `DP_PRODUCT_EXP_W
) (
  input  wire                               in_valid,
  input  wire [`DP_TYPE_W-1:0]              in_datatype,

  // S2 registered product magnitudes, signs, activity and exponents
  input  wire [`DP_E_LANES*PRODUCT_W-1:0]   in_products,
  input  wire [`DP_E_LANES-1:0]             in_negative,
  input  wire [`DP_E_LANES-1:0]             in_active,
  input  wire [EXPONENT_W-1:0]              in_anchor,
  input  wire [`DP_E_LANES*EXPONENT_W-1:0]  in_exponents,

  // S3 aligned signed leaves to lane reduction tree
  output wire [`DP_Q_LANES*LEAF_W-1:0]      out_leaves
);
```

### 1.2 内部变量与 `localparam` 的分组声明
- 保持**每行声明一个变量**（不使用逗号并列声明，以便清晰审阅位宽和 git diff），但**绝不逐个变量写注释**。
- 将同一流水级或同一逻辑功能的 `localparam` / `wire` 聚为一组，在组顶写 **1 行简明功能或数学关系注释**，组内按位宽列与名称列对齐：

```verilog
  // S5 scale multiplication and container padding widths
  localparam integer COEFF_W         = 2 * `DP_SCALE_M;
  localparam integer SCALE_MAG_W     = `DP_SCALE_SOP_W - 1;
  localparam integer STRUCTURAL_DROP = GROUP_W - `DP_SCALE_SOP_W;
  localparam integer SCALE_PRODUCT_W = SCALE_MAG_W + COEFF_W;
  localparam integer SCALE_LOW_PAD   = MAG_W - SCALE_PRODUCT_W;

  // S1 -> S2 scale unpack and pre-multiply signals
  wire [`DP_SCALE_M-1:0] scale_a_magnitude_d;
  wire [`DP_SCALE_M-1:0] scale_b_magnitude_d;
  wire [`DP_EXP_W-1:0]   scale_a_exponent_d;
  wire [`DP_EXP_W-1:0]   scale_b_exponent_d;
  wire                   scale_a_nan_d;
  wire                   scale_b_nan_d;
  wire [`DP_SCALE_M-1:0] r1_scale_a_magnitude;
  wire [`DP_SCALE_M-1:0] r1_scale_b_magnitude;
  wire [`DP_EXP_W-1:0]   r1_scale_a_exponent;
  wire [`DP_EXP_W-1:0]   r1_scale_b_exponent;
  wire                   r1_scale_nan;
```

### 1.3 子模块例化、DFF 例化与 `assign` 对齐
- **普通模块例化**：参数和端口逐行连接，名称与左括号 `(` 之间留空格，使所有 `(` 纵向成列。
- **DFF 基础单元例化**：统一采用紧凑两行写法（第一行模块与参数，第二行 `ff_sN_sM_*` 与全部端口），紧跟在本级组合计算之后。
- **`assign` 与多分支三目表达式**：同组 `assign` 的 `=` 对齐；多分支三目表达式每行一个分支，`?` 与 `:` 对齐。

---

## 2. 注释编写准则（借鉴 Vortex `hw/rtl/tcu/`）

1. **只写分组注释与 Why 注释，不写逐变量废话注释**：
   - 自解释的信号名（如 `r1_valid`、`r2_datatype`、`product_negative_d`）已经说明了信号是什么，**不要**再在上方写 `// S1 valid signal`。
   - 注释应放在**功能块/信号组开头**，用 1–2 句话说明该块的职责、时序边界或非显见的硬件设计原因（例如：为什么某指数比较排除零乘积、为什么减法反向并行计算能省去取反进位链、为什么无效槽位仍需计算 `0 * Inf` 异常）。
2. **分阶段横幅与编号子步骤**：
   - 多级流水模块在每个阶段起点使用横幅：
     ```verilog
     // ======================================================================
     // Stage 3: Local Magnitude Alignment & Two's-Complement Restoration
     // ======================================================================
     ```
   - 阶段内部或复杂组合模块使用 `// 1. ...`、`// 2. ...` 标记数据流步骤（如同 `VX_tcu_tfr_align.sv`）。
3. **禁止过程性噪音**：
   - 严禁在代码中出现任务号、PR 号、“修复某某问题”、“此前旧写法”等历史流水账。

---

## 3. 头文件（`.vh`）标准化组织

### 3.1 `dp_defs.vh` 宏定义规范
- 顶部使用 `` `ifndef DP_DEFS_VH `` / `` `define DP_DEFS_VH `` 保护。
- 按逻辑主题分块，每块用分隔注释标题说明用途，宏名与值纵向对齐：

```verilog
`ifndef DP_DEFS_VH
`define DP_DEFS_VH

// ----------------------------------------------------------------------
// Datatype, Scale Type & Accumulator Format Encodings
// ----------------------------------------------------------------------
`define DP_TYPE_W                (4)
`define DP_SCALE_TYPE_W          (2)
`define DP_C_TYPE_W              (1)

`define DP_DT_TF32               4'd0
`define DP_DT_FP16               4'd1
`define DP_DT_BF16               4'd2
`define DP_DT_MX8_E4M3           4'd3
`define DP_DT_MX8_E5M2           4'd4
`define DP_DT_MX6_E3M2           4'd5
`define DP_DT_MX6_E2M3           4'd6
`define DP_DT_MXFP4              4'd7
`define DP_DT_NVFP4              4'd8
`define DP_DT_HIF4               4'd9
`define DP_DT_INT8               4'd10

// ----------------------------------------------------------------------
// S1 Decoded Number Token Layout (23b):
//   [22] sign | [21:11] magnitude(11b) | [10:3] exp(8b) | [2:1] class(2b) | [0] signaling
// ----------------------------------------------------------------------
`define DP_NUM_W                 (1 + `DP_MANT_W + `DP_EXP_W + 2 + 1)
`define DP_NUM_SIGNAL            (0)
`define DP_NUM_CLASS_LO          (1)
`define DP_NUM_CLASS_W           (2)
`define DP_NUM_EXP_LO            (`DP_NUM_CLASS_LO + `DP_NUM_CLASS_W)
`define DP_NUM_MAG_LO            (`DP_NUM_EXP_LO + `DP_EXP_W)
`define DP_NUM_SIGN              (`DP_NUM_W - 1)

`endif // DP_DEFS_VH
```

### 3.2 `dp_functions.vh` 纯函数规范
- 所有辅助函数声明为 `function automatic`，并包含完整 `begin ... end`。
- **禁止零参数函数**（Vortex `VX_tcu_pkg.sv` 实测教训：零参数函数在嵌套 generate 作用域中易被综合/转换工具错误展开为非法层次调用）。
- 运行时信号（如 `in_datatype`）严禁直接传入 `$clog2(...)`；必须通过 `case (datatype)` 映射到基于常量宏的表达式，确保 Design Compiler 综合通过。

---

## 4. 多精度数值、位宽与告警边界

- **显式符号与位宽扩展**：
  - 区分无符号幅值（`SM`，`S=0`，符号位独立传递）与二补码（`TC`，`S=1`）。
  - 算术运算前显式写出零扩展 `{{(OUT_W-IN_W){1'b0}}, in_val}` 或符号扩展 `{{(OUT_W-IN_W){in_val[IN_W-1]}}, in_val}`，避免隐式位宽截断或有符号/无符号混算告警。
- **右移向零截断（RTZ） vs 算术右移**：
  - 在共享对齐阶段，对无符号幅值做逻辑右移（丢弃低位即向零截断 RTZ），移位完成后再根据独立符号位恢复二补码（`sign ? -$signed({1'b0, shifted}) : $signed({1'b0, shifted})`），不得直接对负二补码做算术右移代替 RTZ。
- **零告警要求**：
  - 通过显式切片与参数校验消除 `WIDTH`、`LATCH`、`UNOPTFLAT`、`MULTIDRIVEN` 告警，禁止在 `.v` 中使用大段 `/* verilator lint_off */`。
