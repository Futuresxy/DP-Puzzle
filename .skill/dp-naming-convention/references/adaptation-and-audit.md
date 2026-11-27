# 命名规范演进与现有代码审查对照

## 1. 规范演进来源

1. **SN 命名框架基线（2026-11-06）**：确立 `dp_` 模块前缀、`DP_` 宏前缀、父层互联 `{driver}_{receiver}_{function}`、模块端口 `in_/out_`、DFF 实例 `ff_s<src>_s<dst>_<field>` 及禁止局部数值使用裸 `e/f/a` 的原则。
2. **Vortex `hw/rtl/tcu/` 风格融合（2026-11-27）**：
   - **以自解释命名替代逐变量碎片注释**：参考 `/home/songxy/workspace/vortex/hw/rtl/tcu/tfr/`，通过统一的 `rN_<function>`（第 N 级寄存值）、`<function>_d`（本级组合候选值）、`<target>_en`（门控使能）和精确的算术领域词根，使变量名自体说明 *What*，从而只需在相关信号组顶部保留一行简明分组注释，彻底消除逐个 `wire` 写注释的视觉冗余，并移除所有 `// verilog_format: off/on`。
   - **消除跨级混合打包向量**：参考 Vortex `coding_guidelines_verilog.md` §5（避免 `UNOPTFLAT` 伪组合环），将早期模块中的 `valid_q[0:3]`、`type_q[0:3]`、`coeff_q[1:3]` 统一规范为按级独立声明的 `r1_valid..r4_valid`、`r1_datatype..r4_datatype`、`r2_scale_coefficient..r4_scale_coefficient`。

---

## 2. 算术与流水命名迁移对照表

下表总结从早期简写/数组式命名向当前标准命名的映射关系，作为编写新模块与后续按任务整理既有模块的标准对照：

| 作用域 / 模块类别 | 旧式或不规范写法 | 标准化写法 | 核心改进理由 |
| --- | --- | --- | --- |
| 各级流水有效位与旁带 | `valid_q[0:3]`、`type_q[0:3]`、`c_raw_q[0:3]` | `r1_valid..r4_valid`、`r1_datatype..r4_datatype`、`r1_c_raw..r4_c_raw` | 级号一目了然，杜绝 `valid_q[2]` 究竟是 S2 还是 S3 的下标偏移歧义，避免 `UNOPTFLAT` |
| `dp_operand_unpack` 浮点域提取 | `e`、`f`、`eb`、`fb`、`raw` | `exponent_field`、`fraction_field`、`exponent_field_width`、`fraction_field_width`、`raw_encoding` | 严格区分原始编码位域、位域宽度与解码后的数值 |
| `dp_max_tree` 左右子树 | `a` / `b`、`va` / `vb` | `left_max` / `right_max`、`left_active` / `right_active` | 明确二叉树递归左右分支的最大值与活动性标志 |
| `dp_sum_tree` / `dp_lane_e` 成对规约 | `a` / `b`、`i` | `pair_left` / `pair_right`、`pair_index` / `element_index` | 明确树叶配对角色与生成期循环轴 |
| `dp_group` scale 旁带 | `sa` / `sb`、`ea` / `eb`、`coeff_q[1:3]` | `r1_scale_a_magnitude`、`r1_scale_a_exponent`、`r2_scale_coefficient..r4_scale_coefficient` | 区分 scale 解包幅值、无偏指数与 S2 预乘后的比例系数 |
| `dp_functions.vh` 函数形参 | `function ... (input [3:0] t)` | `function automatic ... (input [`DP_TYPE_W-1:0] datatype)` | 函数形参同样禁止单字母 `t`，且使用宏位宽 |

---

## 3. 实施边界

- 新增 RTL 模块、头文件与 Testbench 必须 100% 遵循本命名规范与分组注释风格。
- 对既有已冻结 PPA/验证回执的 RTL 模块进行命名或排版重构时，须按用户指定的模块范围执行，同步检查 `test/rtl_tb/` 中的层级探针（如 `dp_tb_trace_names.vh`），并重新运行对应 Verilator/Icarus 完整回归门禁。
