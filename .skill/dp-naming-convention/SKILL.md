---
name: dp-naming-convention
description: >
  DP-Puzzel 项目全局文件、目录、模块、宏、参数、端口、父层互联、流水级变量、算术术语及 Testbench 命名规范。
  当新增、重构或审查 Verilog RTL 代码（src/verilog/）、头文件（.vh）、测试平台（test/rtl_tb/）或微架构接口文档，
  以及消除 e/f/a/tmp 等含义不明缩写与 valid_q[] 跨级打包数组时必须使用此 skill。
  触发词：命名规范、变量名、模块名、端口命名、rN_、信号命名、dp_、代码审查。
---

# DP-Puzzel 全局命名规范（Vortex TCU 风格适配版）

## 核心原则：以自解释命名承载 What，配合分组简明注释

本规范与 [dp-rtl-code-style](../dp-rtl-code-style/SKILL.md) 紧密配合。参考 **Vortex GPGPU（`hw/rtl/tcu/`）** 的工程实践，代码中**不对每个变量逐行写冗余注释，也不使用 `// verilog_format: off/on`**；因此**标识符命名本身必须精准、自解释（Self-Documenting）**，让阅读者仅凭名字即可一眼识别：
1. **信号所处的流水级或时序角色**（组合候选 `_d` vs 第 `N` 级寄存输出 `rN_` vs 使能 `_en`）；
2. **信号在模块层级中的归属**（模块端口 `in_/out_` vs 父层子模块间互联 `{driver}_{receiver}_{function}` vs 模块内部局部变量）；
3. **多精度算术中的精确数值语义**（原始编码位 vs 指数域 vs 指数域位宽 vs 去偏指数 vs 物理 MSB 坐标 `anchor` vs 归一化比较键 `compare_exp` vs 无符号幅值 `magnitude` vs 二补码有符号和 `signed_sum` / `sop`）。

---

## 一、流水级变量命名规范（`rN_` 与 `_d` 统一标准）

在所有新建与优化的 RTL 模块中，全面采用显式流水级前缀 `rN_`，废弃隐藏级号的 `valid_q[0:3]`、`type_q[0:3]`、`coeff_q[1:3]` 等跨级数组：

| 信号角色 | 命名模板 | 标准示例 | 规范说明 |
| --- | --- | --- | --- |
| 第 `N` 级有效控制输出 | `r<N>_valid` | `r1_valid`、`r4_valid`、`r8_valid` | 由 `ff_s{N-1}_s{N}_valid`（`dp_lib_DFFRU`）输出；严禁与组合输入 `in_valid` 混入同一数组（防 Verilator `UNOPTFLAT`） |
| 第 `N` 级控制/格式旁带 | `r<N>_<control>` | `r1_datatype`、`r5_extension`、`r8_last` | 明确随第 `N` 级在途请求同拍保存的格式或控制标志 |
| 第 `N` 级格式分类谓词 | `r<N>_is_<mode>` | `r1_is_e`、`r2_is_hif4`、`r3_is_e` | 基于 `r<N>_datatype` 解码出的本级模式布尔标志（用于写门控与读端恢复零） |
| 待写入寄存器的组合候选值 | `<function>_d` | `product_magnitudes_d`、`aligned_leaves_d`、`lane_sum_d` | 本级组合逻辑产生、即将送入本级边界 DFF `.in_d` 的信号 |
| 第 `N` 级数据寄存器输出 | `r<N>_<function>` | `r2_product_magnitudes`、`r3_aligned_leaves`、`r7_sum` | 本级边界 DFF `.out_q` 输出（或经目的级结构零恢复后的同拍信号），不再重复追加 `_q` 后缀 |
| 寄存器更新使能 | `<target>_en` | `product_slot_en`、`product_upper_en`、`payload_s3_en` | 送入 `dp_lib_DFFE` / `dp_lib_DFFRE` 的 `.in_en` 信号 |
| DFF 基础单元实例名 | `ff_s<src>_s<dst>_<field>` | `ff_s0_s1_valid`、`ff_s1_s2_exponents`、`ff_s6_s7_sum` | 显式标出源阶段与目标阶段边界（`s0` 代表模块输入级） |

**标准分组声明示例（无需逐行注释，无需 `verilog_format` 标记）**：

```verilog
  // Pipeline stage valid, datatype and mode predicates (S1..S4)
  wire                  r1_valid;
  wire                  r2_valid;
  wire                  r3_valid;
  wire                  r4_valid;
  wire [`DP_TYPE_W-1:0] r1_datatype;
  wire [`DP_TYPE_W-1:0] r2_datatype;
  wire [`DP_TYPE_W-1:0] r3_datatype;
  wire                  r1_is_e;
  wire                  r2_is_e;
  wire                  r3_is_e;
  wire                  r1_is_hif4;
  wire                  r2_is_hif4;
```

---

## 二、文件、模块、宏、参数与实例命名规范

### 2.1 命名维度总表

| 维度 | 命名规则 | 标准示例 | 约束与例外 |
| --- | --- | --- | --- |
| RTL 源文件 | `dp_<function>[_<variant>].v` | `dp_lane.v`、`dp_lane_qe.v`、`dp_final_csa_sum.v` | 每文件仅一个 `module`，文件名与模块名严格一致 |
| RTL 模块名 | `dp_<function>[_<variant>]` | `dp_group`、`dp_group_e`、`dp_top_t8h16q32e96` | 可变参数（`K_FP16`/`LOCAL_W`）不编码进通用模块名；固定配比顶层封装除外 |
| 基础库模块 | `dp_lib_<TYPE>` / `dp_dff_*` | `dp_lib_DFFE`、`dp_lib_DFFRU`、`dp_lib_onehot_mux` | DFF 类型后缀保持大写（`DFFU/DFFE/DFFRU/DFFRE/DFFSU/DFFSE`） |
| 头文件（`.vh`） | `dp_<purpose>.vh` | `dp_defs.vh`、`dp_functions.vh` | 宏名统一 `DP_` 前缀、`UPPER_SNAKE_CASE` |
| 模块配置参数 | `parameter integer <NAME>` | `K_FP16`、`LOCAL_W`、`GLOBAL_W`、`BASELINE_V18` | 全大写下划线；优先使用 `OPERAND_A_W`、`INPUT_COUNT` 等自解释名，兼容算术库保留 `N`/`W` |
| 模块派生常量 | `localparam integer <NAME>` | `LEAF_W`、`LANE_SOP_W`、`GROUP_MAG_W`、`Q_ANCHOR_OFFSET` | 全大写下划线；禁止定义无运算的纯宏别名 |
| 普通子模块实例 | `u_<role_or_function>` | `u_lane_unpack`、`u_mantissa_mul_bank`、`u_local_alignment` | 体现实例在本层的架构职责，禁止叫 `u0`、`u_inst1`、`tree0` |
| DFF 原语实例 | `ff_s<src>_s<dst>_<field>` | `ff_s0_s1_valid`、`ff_s2_s3_leaf_upper`、`ff_s7_s8_out_d` | 紧随本级计算就地放置 |
| `generate` 块名 | `g_<function_or_branch>` | `g_group`、`g_lane`、`g_product_register`、`g_v19` | 所有 `generate for / if / else` 分支必须带 `: g_*` 标签 |
| 循环 / `genvar` 索引 | `<role>_index` | `group_index`、`lane_index`、`element_index`、`pair_index`、`bit_index` | 严禁在 RTL 中使用无语义的 `i/j/k` 或 `index1/index2` |
| 辅助纯函数 | `<verb_or_target>_<noun>` | `merge_special`、`elements`、`scale_type`、`element_bias`、`anchor_width` | `function automatic`，形参名须具名（如 `datatype`、`local_width`，禁叫 `t`/`w`） |
| RTL Testbench | `dp_<target>_tb.v` | `dp_tb.v`、`dp_mixed_tb.v`、`dp_csa_tb.v` | 存放于 `test/rtl_tb/` 或 skill `assets/examples/` |

### 2.2 DP 架构层级与互联短名对照表

在父模块内部连接两个子模块时，使用下表定义的标准短名作为 `{driver}` 与 `{receiver}`：

| 架构层级 / 功能单元 | 对应模块名 | 父层互联短名 | 职责说明 |
| --- | --- | --- | --- |
| 单 DP 顶层 | `dp_top`、`dp_top_e`、`dp_top_mixed`、`dp_top_lowp` | `top` | 顶层请求握手、C 管道、S6–S8 公共后端 |
| 点积组（2 Lanes） | `dp_group`、`dp_group_e`、`dp_group_qe`、`dp_group_q` | `group` | 两 lane 汇总、S2 公共 MAX、S1–S5 scale 与 LZD |
| 通道（Lane） | `dp_lane`、`dp_lane_e`、`dp_lane_qe`、`dp_lane_q` | `lane` | S1 解包、S2 乘积/指数、S3 局部对齐、S4 四项树 |
| 操作数解包器 | `dp_lane_unpack*`、`dp_operand_unpack*`、`dp_c_unpack` | `unpack` | 原始浮点/定点位流译码与特殊值分类 |
| 尾数乘法阵列 | `dp_mantissa_bank`、`dp_qe_product_bank`、`dp_mul_unsigned` | `mantissa_mul` | 无符号尾数/系数乘法 |
| 指数加法与最大树 | `dp_exponent_bank`、`dp_max_tree` | `exponent_add` / `exponent_max` | 乘积指数求和与有符号活动最大值选择 |
| 局部/全局对齐 | `dp_lane_align`、`dp_global_align`、`dp_mixed_global_align` | `local_align` / `global_align` | 指数差右移/双向移位与补码叶子恢复 |
| 缩放系数乘法 | `dp_scale_multiply` | `scale_mul` | S5 组幅值与块缩放系数 `14x8` 无符号乘法 |
| 累加压缩与求和树 | `dp_sum_tree`、`dp_final_csa_sum`、`dp_mixed_csa_sum` | `sop_tree` / `final_sum` | 平衡树或 4:2/3:2 CSA + CPA 规约 |
| FP32 归一化舍入 | `dp_fp32_round` | `fp32_round` | S8 RNE 舍入、渐进下溢与 FP32 打包 |

---

## 三、端口、父层互联与内部信号的三层作用域规则

```text
1. 模块端口（Port）：         clock, rst_n, in_<function>, out_<function>
2. 父层子模块互联（Wire）：    <driver>_<receiver>_<function>[_s<stage>]
3. 模块内部运算信号（Wire）：  <function>_d, r<N>_<function>, <function>_en
```

1. **模块端口（`in_` / `out_`）**：
   - 时钟固定为 `clock`，同步低有效复位固定为 `rst_n`。
   - 其余输入端口一律以 `in_` 开头，输出端口以 `out_` 开头（如 `in_valid`、`in_datatype`、`out_sop`、`out_compare_exp`）。
   - 顶层数学操作数 `in_a`、`in_b`、`in_c` 与输出 `out_d`、以及 DFF 原语端口 `in_d`、`out_q`、`in_en` 为固定合同名。
2. **父层子模块间互联线（`{driver}_{receiver}_{function}`）**：
   - 连接同一父模块内两个子模块的 `wire` 写明驱动方、接收方与传递内容，例如：
     - `unpack_mantissa_mul_a_mantissas`（`u_lane_unpack` → `u_mantissa_mul_bank` 的 A 紧凑尾数）
     - `unpack_exponent_add_a_exponents`（`u_lane_unpack` → `u_exponent_add` 的 A 紧凑指数）
     - `lane_group_sum`（`u_lane` → `dp_group` 累加树的 S4 有符号和）
     - `group_align_magnitude`（`u_group_unit` → `u_global_alignment` 的 S5 组幅值）
3. **模块内部局部信号**：
   - 直接描述数值或控制含义（如 `product_magnitudes_d`、`r2_product_magnitudes`、`exponent_max_active`），**不重复添加本模块名或外部端点前缀**。

---

## 四、多精度点积领域标准术语词典（禁止不明单字母缩写）

在 RTL 与 CModel 中，**严禁使用裸 `a/b/c/d/e/f/m/n/t/x/y` 或 `tmp/tmp1/val/res/data0`**。所有数值与控制变量必须使用以下标准词根：

### 4.1 浮点/定点编码与指数域

| 物理/数学含义 | 标准命名词根 / 示例 | 严禁混淆的错误命名 |
| --- | --- | --- |
| 原始输入打包位流 | `raw_encoding`、`operand_bits`、`in_scale_a`、`r4_c_raw` | 不叫 `raw`、`n` 或 `magnitude` |
| 原始编码中的指数位域（带偏置） | `exponent_field`、`a_exponent_field` | 不叫 `e`、`exp`（易混淆偏置/无偏） |
| 指数位域的编码位宽（如 FP16 为 5） | `exponent_field_width` | 不叫 `eb`、`exp_w` 或与指数数值混用 |
| 指数编码偏置常数（如 127、15、7） | `exponent_bias`、`element_bias` | 不叫 `b` 或 `bias0` |
| 去偏置后的数学指数值 | `unbiased_exponent`、`scale_a_exponent_d` | 区分带偏编码域与有符号无偏指数 |
| 有限数重编码/有效偏置指数 | `finite_exponent`、`product_exponents_d`、`r2_product_exponents` | 明确处于哪套偏置坐标系 |
| 容器物理最高位（MSB）对应的指数坐标 | `anchor`、`r2_group_anchor`、`r3_raw_anchor`、`out_anchor` | `anchor` 是容器坐标 `A_raw`，不等于真实最高非零位指数 |
| 前导零计数（Leading-Zero Count） | `leading_zero_count`、`z_d`、`out_z` | 不用裸 `l` 或 `lz` 表示多种不同宽度计数 |
| 扣除前导零后的归一化 MAX 比较键 | `compare_exp`、`compare_exp_d`、`out_compare_exp` | `compare_exp = A_raw - z`，专供 S6 MAX 比较，移位差仍用 `A_raw` |
| 指数对齐差值 / 移位量 | `alignment_delta`、`net_shift`、`e_lane_shift`、`shift_value` | 双向移位必须注释正负方向（如 `<0` 左移、`>0` 右移） |

### 4.2 尾数、幅值、二补码规约与舍入

| 物理/数学含义 | 标准命名词根 / 示例 | 严禁混淆的错误命名 |
| --- | --- | --- |
| 原始编码中的显式尾数域（不含隐含 1） | `fraction_field` | 不叫 `f`、`mantissa`（`mantissa` 含隐含位） |
| 显式尾数域的编码位宽（如 FP16 为 10） | `fraction_field_width` | 不叫 `fb`，且区别于定点通路小数位 `F` |
| 定点容器的小数位数（S/I/F 中的 `F`） | `fractional_bits`、`product_fraction`、`group_fraction` | 对应二进制小数点右侧位数 |
| 恢复隐含位后的无符号有效数/尾数 | `mantissa`、`a_mantissas`、`finite_magnitude` | 同一模块内保持统一，不与 `fraction_field` 混用 |
| 符号分离的无符号绝对幅值（`S=0`） | `magnitude`、`product_magnitudes_d`、`compact_magnitude` | 二补码有符号数严禁命名为 `magnitude` |
| 独立符号位（`1` 表示负，含 `-0.0`） | `negative`、`product_negative_d`、`out_negative`、`sign_value` | 明确 `1` 为负；全负乘积摘要用 `all_products_negative` |
| 二补码（TC）有符号乘积或成对和 | `signed_products`、`pair_left`、`pair_right`、`pair_sum`、`pair_leaf` | 区分无符号乘积与带符号二补码项 |
| 二补码（TC）对齐叶子与树规约和 | `aligned_leaves_d`、`r3_aligned_leaves`、`lane_sum_d`、`out_sop`、`group_sum` | 当前单 DP 无跨请求累加状态，不把单拍规约树叫 `accumulator` |
| CSA 进位保存压缩行 | `group_sum` / `group_carry`、`total_sum` / `total_carry`、`base_sum` / `base_carry` | 明确区分 sum 行与已左移一位位权的 carry 行 |
| RNE 舍入位与进位 | `guard_bit`、`round_bit`、`sticky_bit`、`round_increment`、`rounded` | 区分舍入 `guard_bit` 与防左移溢出的 `DP_E_GUARD` 保护位 |
| 活动掩码 vs 请求有效 vs 非零 | `in_valid` / `rN_valid`、`product_active_d`、`in_participate`、`magnitude_active` | `valid` 表流水事务有效；`active` 表参与数值 MAX/规约；不可混用 |
| IEEE/格式特殊值分类 | `number_class`、`is_nan`、`is_inf`、`is_signaling`、`special_flags` | 4-bit 摘要固定为 `{NAN, INVALID, POS_INF, NEG_INF}` |

---

## 五、Testbench 与断点探针（Cutpoint Trace）命名规范

1. **Testbench 模块与内部信号**：
   - TB 顶层模块：`dp_<target>_tb`（如 `dp_csa_tb`、`dp_pipeline_boundary_example_tb`）。
   - 激励与黄金存储数组：使用清晰复数名词（如 `stimulus_a`、`stimulus_b`、`expected_result`、`pending_req_id`）。
   - 统计计数器：`cycle_count`、`accepted_count`、`checked_count`、`cancelled_count`。
   - 驱动与检查任务：`reset_dut`、`drive_request`、`random_step`、`tick_and_check`。
2. **层级探针宏（`test/rtl_tb/dp_tb_trace_names.vh`）**：
   - 跨版本或跨实现的 TB 内部观察点统一通过 `` `DP_TRACE_* `` 宏映射（如 `` `DP_TRACE_LANE_PRODUCTS `` 映射到 `r2_product_magnitudes`），不在 TB 循环内硬编码未对齐的历史局部信号名。

---

## 六、命名审查与重构检查清单

1. **文件与模块**：`.v` 文件名与 `module` 名完全一致，均带 `dp_` 前缀（DFF 库 `dp_lib_DFF*` 例外）。
2. **流水级清晰度**：所有跨级寄存器输出采用 `r1_..r8_<function>`，组合候选采用 `<function>_d`，不存在将 `in_valid` 与寄存 valid 混入同一数组的写法。
3. **无不明单字母与过程噪音**：无裸 `a/b/c/d/e/f/m/n/t/x/y` 或 `tmp/val/data2`；注释按功能组简洁编写，无 `// verilog_format: off/on`。
4. **作用域分明**：端口用 `in_/out_`，父层互联用 `{driver}_{receiver}_{function}`，内部变量用纯功能名。
5. **数值语义精确**：`exponent_field` / `exponent_field_width` / `unbiased_exponent` / `anchor` / `compare_exp` / `fraction_field` / `fractional_bits` / `magnitude` / `signed_sum` 严格区分。
6. **消费端同步**：修改任何模块名、端口名或被 TB cutpoint 观察的 `rN_*` 内部寄存器名时，必须同步更新 `src/verilog/files*.f`、父模块例化、`test/rtl_tb/*.vh` 探针及验证脚本。
