---
name: dp-rtl-code-style
description: >
  DP-Puzzel 项目 Verilog-2005 RTL 与 Testbench 标准化编码规范及基础单元库。
  当编写、修改、重构或审查 Verilog RTL 代码（src/verilog/）与测试平台（test/rtl_tb/），
  定义参数/宏头文件（.vh）、例化 DFF/MUX 基础单元、实现多精度寄存器门控或构建单元测试时必须使用此 skill。
  触发词：verilog、RTL、编码规范、代码风格、DFF、dp_、参数注释、testbench、打拍、代码审查。
---

# DP-Puzzel 项目 Verilog RTL 与 Testbench 标准化编码规范

## 适用范围与设计基线

本规范面向 **DP-Puzzel 多精度点积单元（Dot-Product Unit）微架构设计与算力配比探索**，汲取 **Vortex GPGPU（`hw/rtl/tcu/` 及 `docs/coding_guidelines_verilog.md`）** 的简洁工业级 RTL 风格与测试方法论，结合本项目纯 Verilog-2005 + 显式 DFF 基础单元架构凝练而成：

1. **适用范围**：维护中的 `src/verilog/`（多精度基线、E/Q/QE 专用及混合配比顶层、算术/解包/公共库）与 `test/rtl_tb/`。冻结的历史 `src/verilog/systemverilog/` 与已归档快照不回溯修改。
2. **语言与排版基线**：
   - 纯 **Verilog-2005**（可综合 RTL 使用 `wire`/`reg`、`assign`、`generate`、显式位宽扩展，不使用 SV 特有的 `logic`、`always_ff`、`always_comb`、`package`、`struct`、`interface`）。
   - **2 空格缩进**、UTF-8、LF 换行、100 列目标宽度。
   - **严禁在代码中添加 `// verilog_format: off` 或 `// verilog_format: on` 等格式化工具屏蔽注释**——直接通过清晰的原生排版规则保证代码整洁可读。

---

## 核心设计理念

1. **接口与寄存器所有权唯一（Vortex Ownership Rule）**：
   - 谁包含产生某级信号的组合逻辑，谁拥有该级输出边界寄存器。
   - 纯组合子模块（如 `dp_operand_unpack`、`dp_mantissa_bank`、`dp_lane_align`、`dp_global_align`、`dp_final_csa_sum`、`dp_fp32_round`）**绝不暗藏流水寄存器**；父模块或下游消费者路由已寄存接口时**绝不二次打拍**。
2. **控制与数据寄存器严格分离**：
   - 控制信号（`rN_valid`、`rN_last`、`rN_extension`、FSM 状态）使用带**同步低有效复位 `rst_n`** 的 DFF（`dp_lib_DFFRU` / `dp_lib_DFFRE`），确保初始与复位状态确定。
   - 由有效位屏蔽的数据通路 payload 使用**无复位、带使能**的 DFF（`dp_lib_DFFE`），节省复位树资源，并在气泡/未激活期间保持数据以支持后端 ICG 与低翻转功耗。
3. **多精度写门控与读端结构零恢复（Write-Gating & Read-Zero-Restoration）**：
   - 逐拍动态切换精度（`II=1`）时，寄存器写使能使用**源级**类型（`rst_n & r{N-1}_valid & r{N-1}_slot_active`）关闭未用通道/高位；下游消费端使用**目的级**类型（`r{N}_slot_active ? r{N}_data : {W{1'b0}}`）显式恢复结构零，严防历史旧值泄漏。
4. **分组精炼注释，解释 Why 而非重复 What（Vortex TCU Comment Style）**：
   - 命名良好的信号自体表达 *What*；注释只解释**功能分组、非显见硬件不变量、位宽/偏置推导（Why）与 S/I/F 定点坐标契约**。
   - **禁止逐个变量/端口机械添加冗余注释**；按功能或流水级相关性分组，每组上方写 1–2 行简明注释即可。禁止在代码注释中写入 PR/任务编号、版本演进流水账或“修复某 bug”等过程噪音。

---

## 一、标准化代码格式与注释规范（Vortex TCU 风格适配）

### 1.1 模块头部注释与 S/I/F 坐标表

每个 `.v` 文件顶部在 `` `include "dp_defs.vh"`` 之后、``module`` 之前，编写简明头部注释：
- **2–4 行架构职责与契约概述**：说明模块功能、流水级范围、延迟/吞吐（如 `L=8, II=1`）与同步低有效 `rst_n` 行为。
- **S/I/F 定点坐标表（仅数值变换/对齐/规约模块需要）**：简明列出各精度关键节点的符号 `S`、整数位 `I`（不含 `S`）、小数位 `F` 及表示法（`SM` 符号幅值分离 vs `TC` 二补码）。纯控制或透传封装模块无需冗长表格。

```verilog
`include "dp_defs.vh"

// Multi-precision T1H2Q4E8 lane (S1 unpack -> S2 multiply -> S3 align -> S4 sum tree).
// Fixed 4-stage pipeline (II=1, no backpressure); rst_n clears valid only, payload holds.
// Fixed-point coordinates (P = LOCAL_W - 2, I excludes S):
//   Precision              | S3 Leaf (TC)   | S4 Lane SOP (TC)
//   ---------------------- | -------------- | ----------------
//   TF32                   | S1 I2  F(P)    | S1 I2  F(P+2)
//   FP16 / BF16            | S1 I2  F(P)    | S1 I3  F(P+1)
//   MXFP8 / MXFP6          | S1 I2  F(P)    | S1 I4  F(P)
//   MXFP4 / NVFP4 / HiF4   | S1 I9  F(P-7)  | S1 I9  F(P-5)
//   INT8                   | S1 I15 F(P-13) | S1 I17 F(P-13)
```

### 1.2 模块参数与端口声明格式（分组注释 + 垂直列对齐）

借鉴 Vortex `hw/rtl/tcu/` 的模块头格式：
- **参数列表 `#(...)`**：每行一个 `parameter integer`，等号 `=` 纵向对齐；仅在非显见配置开关或派生参数右侧附简短行尾注释 `// ...`，无需每个参数上方都写独立注释行。
- **端口列表 `(...)`**：
  - 每行一个端口，写全 `input wire` / `output wire`、`signed`（如有）和位宽 `[W-1:0]`。
  - **按接口功能或流水级相关性分组**（如全局时钟复位、输入操作数与元数据、跨模块协同接口、输出结果），组间空一行或加一行简短分组注释（`// S2 group exponent MAX sideband`）。
  - 方向/类型、位宽、端口名三列纵向对齐，**不对自解释端口逐行写注释**。

```verilog
module dp_lane #(
  parameter integer LOCAL_W      = `DP_DEFAULT_LOCAL_W,
  parameter integer BASELINE_V18 = 0,                   // 1: E fixed-coordinate bypass
  parameter integer LEAF_W       = LOCAL_W + 1,         // derived: S3 signed leaf width
  parameter integer LANE_SOP_W   = LEAF_W + $clog2(`DP_Q_LANES)
) (
  input  wire                          clock,
  input  wire                          rst_n,

  // S0 input request and packed operands
  input  wire                          in_valid,
  input  wire [`DP_TYPE_W-1:0]         in_datatype,
  input  wire [`DP_LANE_W-1:0]         in_a,
  input  wire [`DP_LANE_W-1:0]         in_b,
  input  wire [1:0]                    in_e1_a,
  input  wire [1:0]                    in_e1_b,
  input  wire                          in_e2_a,
  input  wire                          in_e2_b,

  // S2 combinational group-MAX sideband
  output wire [`DP_PRODUCT_EXP_W-1:0] out_candidate,
  output wire                          out_candidate_active,
  input  wire [`DP_PRODUCT_EXP_W-1:0] in_group_max,

  // S4 registered lane output
  output wire                          out_valid,
  output wire signed [LANE_SOP_W-1:0]  out_sop,
  output wire [`DP_PRODUCT_EXP_W-1:0] out_anchor,
  output wire [`DP_SPECIAL_W-1:0]      out_special,
  output wire                          out_all_negative
);
```

### 1.3 内部常量与变量声明（按相关性分组注释，拒绝逐行注水）

- **单行单变量，按组注释**：每个 `localparam`、`wire`、`genvar` 独占一行（不写逗号并列声明，确保位宽与 diff 清晰），但**把同属一个流水级或同一个计算子步骤的变量聚成一组**，在组上方写 **1 行简明功能/不变量注释**，组内不再穿插单行注释！
- **列对齐**：同组 `localparam` 的 `=` 对齐；同组 `wire` 的位宽与变量名对齐。
- **仅对非显见公式加注释**：当某个 `localparam` 涉及偏置抵消、结构零裁剪或容器余量推导时，在组上方用 1–2 行写清数学公式（如 `// A_raw offset = (MAG_W - 1) - F - 2*bias`）。

```verilog
  // ❌ 反例：过度细节化，每个自解释变量都写一行废话注释，且到处是 verilog_format 注释
  // verilog_format: off
  // S1 解包数据有效标志。
  wire r1_valid;
  // S2 乘积及指数旁带有效标志。
  wire r2_valid;
  // S3 对齐叶子有效标志。
  wire r3_valid;
  // verilog_format: on

  // ✅ 正例（Vortex TCU 风格）：按功能/流水级相关性分组，一组一行简明注释，列对齐
  // Pipeline stage valid and datatype tracking (S1..S4)
  wire                    r1_valid;
  wire                    r2_valid;
  wire                    r3_valid;
  wire                    r4_valid;
  wire [`DP_TYPE_W-1:0]   r1_datatype;
  wire [`DP_TYPE_W-1:0]   r2_datatype;
  wire [`DP_TYPE_W-1:0]   r3_datatype;

  // S1 compact unpack outputs to S2 arithmetic banks (two M16/E10/S4 atoms per lane)
  wire [`DP_UNPACK_MANT_W-1:0] unpack_mantissa_mul_a_mantissas;
  wire [`DP_UNPACK_MANT_W-1:0] unpack_mantissa_mul_b_mantissas;
  wire [`DP_UNPACK_EXP_W-1:0]  unpack_exponent_add_a_exponents;
  wire [`DP_UNPACK_EXP_W-1:0]  unpack_exponent_add_b_exponents;
  wire [`DP_UNPACK_SIGN_W-1:0] unpack_lane_a_signs;
  wire [`DP_UNPACK_SIGN_W-1:0] unpack_lane_b_signs;
```

### 1.4 流水级分段横幅与就地组织（Stage Banners & In-Place Layout）

参照 `VX_tcu_fedp_tfr.sv` 与 `VX_tcu_tfr_align.sv`：
- **多级流水模块**使用清晰的阶段分隔横幅，将每级的**局部信号声明 → 组合逻辑/子模块例化 → 本级边界 DFF 实例**就地组织在一起，严禁把所有 DFF 堆到文件末尾：
  ```verilog
  // ========================================================================
  // Stage 2: Mantissa Multiplication, Exponent Sum & Group MAX
  // ========================================================================
  ```
- **复杂组合模块**内部采用编号子步骤注释划分逻辑层次：
  ```verilog
  // 1. E-format signed pair formation
  ...
  // 2. Shared alignment window placement and low-bit zero padding
  ...
  // 3. Exponent delta and RTZ right shift
  ...
  // 4. Two's-complement leaf restoration
  ```

### 1.5 子模块例化、DFF 例化与表达式排版

1. **普通子模块例化**：每个参数和端口占一行，参数/端口名后留空格使左括号 `(` 垂直对齐：
   ```verilog
   dp_max_tree #(
     .N (`DP_E_LANES),
     .W (`DP_PRODUCT_EXP_W + 1)
   ) u_lane_exponent_max (
     .in_values  (product_exponent_candidates),
     .in_active  (exponent_max_active),
     .out_max    (lane_max_exponent),
     .out_active (out_candidate_active)
   );
   ```
2. **DFF 基础单元例化**：紧随本级计算放置，采用紧凑两行格式（第一行模块与 `#(.WIDTH(...))`，第二行 `ff_sN_sM_*` 与全部端口），**不加 `verilog_format: off/on`**：
   ```verilog
   // S1 -> S2 pipeline registers
   dp_lib_DFFRU #(.WIDTH(1))
   ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(r1_valid), .out_q(r2_valid));
   dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
   ff_s1_s2_datatype (.clock(clock), .in_en(rst_n & r1_valid), .in_d(r1_datatype), .out_q(r2_datatype));
   ```
3. **同组 `assign` 与多分支三目表达式 `?:`**：
   - 相关性强的连续 `assign` 语句按 `=` 垂直对齐。
   - 多分支 `?:` 每行一个 `条件 ? 结果 :`，`?` 与 `:` 纵向对齐，保持完整算术项或函数调用在同一行。

### 1.6 头文件（`.vh`）参数与函数注释格式

- **`dp_defs.vh`**：按主题分块（如 `// ---- Datatype & Scale Encodings ----`、`// ---- Format Field Widths & Biases ----`、`// ---- Compact Unpack Atom Layout ----`），块头用 1–2 行说明编码规律或打包位域（如 `// Number token (23b): [22] sign | [21:11] mag | [10:3] exp | [2:1] class | [0] sig`），宏名与值分列对齐，**无需为每个自解释宏单独写一行注释**。
- **`dp_functions.vh`**：每个 `function automatic` 上方用 1–2 行说明函数用途及综合约束（如运行时 `datatype` 通过 `case` 返回常量位宽以兼容 DC，禁止定义零参数函数）。

---

## 二、RTL 核心编码铁律（18 条硬性规范）

1. **禁止魔鬼数字**：具有格式、容量或位域含义的常数必须定义为 `.vh` 宏或模块内派生 `localparam`；常量字面量显式带位宽（如 `4'd15`、`32'd0`）。
2. **`` `define `` 宏仅在 `.vh` 头文件中定义**：`.v` 源文件内严禁定义 `` `define `` 宏；头文件必须包含 `` `ifndef / `define / `endif `` 保护。
3. **功能组合逻辑使用 `assign`**：可综合功能模块组合逻辑统一用 `assign` + 具名 `wire` + `generate` + 子模块表达；仅 FSM 次态逻辑允许完整赋值的 `always @(*)`（须有默认初值与 `default` 分支）。
4. **按位逻辑运算（禁止布尔 `&&` `||` `!`）**：可综合通路中，多 bit 信号先经显式比较（`==`、`!=`、`<`、`>=`）或归约（`|vec`、`&vec`）转为 1-bit，再用按位 `&`、`|`、`~`、`^` 组合。
5. **动态选择显式例化 MUX**：编译期 `generate` 常量切片允许；运行时变量索引的多路选择必须显式例化 `dp_lib_bin2onehot` + `dp_lib_onehot_mux` 或平衡选择树。
6. **功能层禁止手写 `always @(posedge clock)`**：所有寄存器必须例化 `dp_lib_DFF*` 基础单元（仅 `dp_dff_en.v` 与 `dp_dff_sync_reset.v` 两个底层原语内部包含时序块）。
7. **单行单声明与端口对齐**：`parameter`、`localparam`、端口、`wire`、`reg`、`genvar` 每行只声明一个标识符；普通模块例化每行一个端口且左括号 `(` 对齐，DFF 例化采用紧凑两行。
8. **控制复位与数据无复位分离**：`rN_valid` 等控制信号用 `dp_lib_DFFRU`/`DFFRE`（同步低有效 `rst_n` 优先于 `in_en`）；valid 屏蔽的 payload 用无复位 `dp_lib_DFFE`。
9. **统一命名与 `rN_` 流水级前缀**：遵循 [dp-naming-convention](../dp-naming-convention/SKILL.md)，第 `N` 级寄存输出命名为 `rN_<function>`，待捕获组合输入命名为 `<function>_d`；禁止把组合输入 `in_valid` 与寄存输出 `r1..rN_valid` 拼入同一数组（防止 Verilator `UNOPTFLAT` 伪组合环告警）。
10. **多精度写门控与目的级读清零**：多精度分段/分槽寄存器用源级 `r{N-1}_datatype` 控制 `in_en`，在目的级消费端必须用 `r{N}_datatype` 将未用位段/槽位掩码恢复为 `0`；共享算术单元输入在非激活模式置零隔离。
11. **目录职责与编译清单单一来源**：遵守 `src/verilog/{common,parameter,unpack,arithmetic,lane,group,top}` 结构，显式维护 `files*.f`，不混编 skill 模板与生产原语。
12. **禁止 `localparam` 纯宏别名**：不创建无计算的 `localparam X = `DP_X;`，仅保留有算术推导或位宽转换的派生 `localparam`。
13. **信号名表达硬件功能与数值语义**：禁止裸 `a/b/c/d/e/f/m/n/t/x/y` 或 `tmp/val`；严格区分 `exponent_field`、`exponent_field_width`、`unbiased_exponent`、`anchor`、`compare_exp`、`fraction_field`、`fractional_bits`、`magnitude` 与 `signed_sum`。
14. **接口不盲目打包单总线**：跨模块不同语义信号分端口声明；模块内部若为合并同使能 DFF 临时拼接，必须在 DFF 下一行紧邻解包为具名 `wire`。
15. **位域切片符号化**：使用 `.vh` 位域宏或 `[index*W +: W]` 参数化切片，严禁在业务代码中写裸数字切片 `[49:2]`。
16. **接口与寄存器所有权边界**：组合子模块不暗藏流水寄存器，父模块与消费者不二次打拍已寄存接口；严禁使用 `// verilog_format: off/on` 污染源码。
17. **强制 `begin`/`end` 与零告警卫生**：所有 `if/else/for/while` 必须带 `begin/end`（禁止单语句省略括号）；严禁大范围 `/* verilator lint_off */` 掩盖位宽或锁存器错误。
18. **Elaboration 静态参数断言与有效位门控运行时断言**：模块末尾在 `// synthesis translate_off` 块内检查参数合法性（非法立即 `$display("FAIL ...")` + `$finish`），运行时断言必须以 `rst_n & rN_valid` 门控。

---

## 三、基础单元库（`src/verilog/common/` 与 `assets/lib/`）

### 3.1 DFF 选择决策树

```text
需要寄存器？
├── 控制信号（valid / last / extension / FSM 状态 / 控制计数器）
│   ├── 每拍推进（如 rN_valid 传递气泡） → dp_lib_DFFRU（~rst_n 同步清 0）
│   ├── 条件更新且复位清 0（如 rN_c_datatype） → dp_lib_DFFRE（~rst_n 优先于 in_en）
│   └── 合同明确要求复位为全 1 → dp_lib_DFFSU / dp_lib_DFFSE
│
└── 数据通路信号（由 rN_valid 屏蔽的 payload：幅值、指数、符号、分类、rN_datatype）
    ├── 有效事件门控（in_en = rst_n & r{N-1}_valid [& slot_en]） → dp_lib_DFFE（无复位，带使能）
    └── 特殊合同要求每拍无条件更新的无复位数据 → dp_lib_DFFU
```

### 3.2 六种 DFF 与三种组合选择单元速查

| 模块名 | 参数 | 紧凑两行例化 / 端口列表 | 功能说明 |
| --- | --- | --- | --- |
| `dp_lib_DFFU` | `WIDTH` | `.clock(clock), .in_d(d), .out_q(q)` | 无复位、无使能 DFF |
| `dp_lib_DFFE` | `WIDTH` | `.clock(clock), .in_en(en), .in_d(d), .out_q(q)` | 无复位、带使能 DFF（数据通路主力） |
| `dp_lib_DFFRU` | `WIDTH` | `.clock(clock), .rst_n(rst_n), .in_d(d), .out_q(q)` | 同步低有效复位清 0、无使能 DFF（`rN_valid` 主力） |
| `dp_lib_DFFRE` | `WIDTH` | `.clock(clock), .rst_n(rst_n), .in_en(en), .in_d(d), .out_q(q)` | 同步低有效复位清 0 + 使能 DFF |
| `dp_lib_DFFSU` | `WIDTH` | `.clock(clock), .rst_n(rst_n), .in_d(d), .out_q(q)` | 同步低有效置全 1、无使能 DFF |
| `dp_lib_DFFSE` | `WIDTH` | `.clock(clock), .rst_n(rst_n), .in_en(en), .in_d(d), .out_q(q)` | 同步低有效置全 1 + 使能 DFF |
| `dp_lib_onehot_mux` | `N`, `W` | `.in_select(sel), .in_data(flat_data), .out_data(out)` | `N` 路 `W`-bit 1-hot MUX（零选输出 0） |
| `dp_lib_bin2onehot` | `BIN_W`, `ONEHOT_W` | `.in_binary(idx), .out_onehot(oh)` | 二进制转 1-hot 译码器（支持非二次幂路数） |
| `dp_lib_onehot2bin` | `BIN_W`, `ONEHOT_W` | `.in_onehot(oh), .out_binary(idx)` | 互斥 1-hot 转二进制编码器 |

---

## 四、可真实实践的 Testbench 与验证流程规范

完整模板与实施细节见 [Testbench 与验证规范](references/testbench-standard.md)。借鉴 Vortex `hw/unittest/tcu_fedp/` 与 `SimX-as-Oracle` 调试法则：

1. **双层验证体系**：
   - **模块级自检 Unit Testbench**：内置 Golden 参考函数与固定 seed 伪随机发生器，按特征集（`zeros`、`normals`、`subnormals`、`infinities`、`nans`、`scales/e1/e2`、`integers`）+ 动态协议压力（`II=1` 满吞吐、随机气泡 `in_valid=0`、逐拍 `in_datatype` 切换检验门控零恢复、在途 `rst_n=0` 同步复位取消）全自动比对。
   - **顶层流水线与 CModel-as-Oracle 断点差分 Testbench**：读取 `DP_INPUTS_V1`、`GOLDEN`、`SCHEDULE`，当顶层结果不匹配时，通过 `+CUTPOINTS` 导出 `S1..S7` 逐级有效寄存器轨迹并与 CModel trace 自动 diff，直接定位首个分歧的流水级与请求 ID。
2. **边沿时序与排空守恒定律**：
   - `@(negedge clock)` 驱动输入与复位；`@(posedge clock)`（NBA 更新前）检查 `out_*_ready`、`out_valid` 与输出数据，推进 `pending_req_id[0:L-1]` 记分牌。
   - 测试结束必须满足守恒式 **`accepted_count == checked_count + cancelled_count`**（且 `checked_count > 0`），输出 `PASS cycles=%0d accepted=%0d checked=%0d cancelled=%0d`；任何失配立即打印上下文与 `FAIL` 并 `$finish`。
3. **Testbench 代码风格**：同样遵循单行单声明、按功能分组简明注释、强制 `begin/end`、DUT 端口对齐，不使用 `verilog_format: off/on`。

---

## 五、强制 18 项自检报告模板

每次编写、修改或审查 Verilog RTL 与 Testbench 后，必须逐项核查并在回复中输出以下表格：

```markdown
## RTL 与 Testbench 规范自检报告

| # | 检查项 | 结果 | 说明（文件与行号） |
|---|--------|------|--------------------|
| 1 | 无魔鬼数字（具名宏或派生 localparam，显式位宽） | ✅ / ❌ / N/A | ... |
| 2 | `define 仅在 .vh 头文件（带 include guard 与分块注释） | ✅ / ❌ / N/A | ... |
| 3 | 功能组合逻辑用 assign（仅 FSM 次态用 always @*） | ✅ / ❌ / N/A | ... |
| 4 | 禁止布尔运算符 `&&` `\|\|` `!`（归约后用 `&` `\|` `~`） | ✅ / ❌ / N/A | ... |
| 5 | 禁止多维数组动态索引（显式例化 MUX 或选择树） | ✅ / ❌ / N/A | ... |
| 6 | 功能层时序逻辑 100% 例化 `dp_lib_DFF*`（紧凑两行） | ✅ / ❌ / N/A | ... |
| 7 | 单行单变量声明（无逗号并列声明） | ✅ / ❌ / N/A | ... |
| 8 | 寄存器选型正确（控制用 DFFRU/RE，数据用无复位 DFFE） | ✅ / ❌ / N/A | ... |
| 9 | 命名规范（`dp_`/`DP_`/`u_`/`ff_sN_sM_`/`g_`/`rN_`/`_d`） | ✅ / ❌ / N/A | ... |
| 10 | 多精度寄存器写门控 + 目的级结构零恢复 + 操作数隔离 | ✅ / ❌ / N/A | ... |
| 11 | 目录职责与 `files*.f` 清单一致 | ✅ / ❌ / N/A | ... |
| 12 | 无 `localparam` 纯宏别名 | ✅ / ❌ / N/A | ... |
| 13 | 信号名表达功能与数值语义（无裸 a/e/f/tmp） | ✅ / ❌ / N/A | ... |
| 14 | 端口不盲目打包单总线（内部拼接紧邻 DFF 立即解包） | ✅ / ❌ / N/A | ... |
| 15 | 位域切片使用宏或 `base +: W`（无裸数字切片） | ✅ / ❌ / N/A | ... |
| 16 | 按功能/相关性分组简明注释（无逐变量冗余注释，无 verilog_format 注释） | ✅ / ❌ / N/A | ... |
| 17 | 垂直列对齐（`=`、端口列、例化 `(`）+ 强制 `begin/end` + 阶段就地布局 | ✅ / ❌ / N/A | ... |
| 18 | 末尾 `synthesis translate_off` 静态断言与 TB 守恒自检 | ✅ / ❌ / N/A | ... |

总结：18/18 通过（或列出需修复项）
```

---

## 六、参考文档与模板资产

- **代码格式、分组注释与数值细则**：[references/coding-style.md](references/coding-style.md)
- **同步复位、寄存器所有权与多精度门控合同**：[references/registers.md](references/registers.md)
- **Testbench 架构、CModel 断点差分与验证流程标准**：[references/testbench-standard.md](references/testbench-standard.md)
- **SN 与 Vortex TCU 规范融合记录**：[references/sn-adaptation.md](references/sn-adaptation.md)
- **全局命名规范与术语词典**：[../dp-naming-convention/SKILL.md](../dp-naming-convention/SKILL.md)
- **标准化 RTL 示例模块**：[assets/examples/dp_pipeline_boundary_example.v](assets/examples/dp_pipeline_boundary_example.v)
- **标准化自检 Testbench 示例**：[assets/examples/dp_pipeline_boundary_example_tb.v](assets/examples/dp_pipeline_boundary_example_tb.v)
- **基础单元库模板**：`assets/lib/dp_lib_DFF*.v`、`assets/lib/dp_lib_*onehot*.v`
