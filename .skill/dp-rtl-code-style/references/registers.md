# 同步低有效复位、寄存器所有权与多精度门控合同

## 1. DFF 基础单元合同

项目所有流水与状态寄存器统一通过六种 `dp_lib_DFF*` 封装例化（位于 `src/verilog/common/`，模板位于 `assets/lib/`），底层共用 `dp_dff_sync_reset.v` 和 `dp_dff_en.v` 两个行为级原语：

| 原语模块 | 参数 | 端口 | 时钟上升沿行为 |
| --- | --- | --- | --- |
| `dp_dff_sync_reset` | `WIDTH`, `RESET_VALUE` | `clock, rst_n, in_en, in_d, out_q` | `~rst_n` 同步复位为 `RESET_VALUE`（优先于 `in_en`）；否则 `in_en=1` 更新，否则保持 |
| `dp_dff_en` | `WIDTH` | `clock, in_en, in_d, out_q` | `in_en=1` 更新，否则保持；无复位引脚 |

```verilog
// 控制原语时序核心 (dp_dff_sync_reset)
always @(posedge clock) begin
  if (~rst_n) begin
    out_q <= RESET_VALUE;
  end else if (in_en) begin
    out_q <= in_d;
  end
end

// 数据原语时序核心 (dp_dff_en)
always @(posedge clock) begin
  if (in_en) begin
    out_q <= in_d;
  end
end
```

---

## 2. 接口与寄存器所有权（Vortex Ownership Principle）

1. **单一所有权**：一个信号在哪一级产生，就在哪一级的模块内完成寄存（或声明为纯组合子模块由直接父模块在对应级边界统一捕获）。
2. **禁止跨层重复打拍**：
   - 例如 `dp_lane_operand_unpack` 内部已持有 `S0 -> S1` 的紧凑尾数/指数/符号/分类寄存器（`r1_mantissas` 等），则 `dp_lane` 只寄存同拍的 `r1_valid` 和 `r1_datatype`，**绝不能**在 `dp_lane` 对 `out_a_mantissas` 再次打拍。
   - 例如 `dp_group` 已在 `S4 -> S5` 边界寄存输出 `out_magnitude`、`out_anchor`、`out_compare_exp`，则 `dp_top` 在 S6 全局对齐前直接使用这些已寄存信号与 `S5` 寄存后的 C token 对齐，**绝不**在 `dp_top` 的 S5 再插一层 group 输出寄存器。
3. **禁止将组合输入与各级寄存状态混入同一向量**：
   - 严禁声明 `wire [L:0] valid_pipe; assign valid_pipe[0] = in_valid;`。必须将组合输入 `in_valid`（或 `req_fire`）与各级寄存输出 `r1_valid`、`r2_valid`、...、`r8_valid` 独立声明，杜绝 Verilator `UNOPTFLAT` 假组合环告警。

---

## 3. 控制与数据通路使能规范

对固定流水、无输出反压的 DP 架构（`L=8, II=1`）：

1. **有效位控制链（`r1_valid` .. `r8_valid`）**：
   - 使用 `dp_lib_DFFRU #(.WIDTH(1))`（内部 `in_en = 1'b1`）。
   - 每拍无条件推进，使上游气泡（`in_valid = 1'b0`）自然向下游排空为 `0`；`rst_n = 1'b0` 时在上升沿全部同步清零，立即取消所有在途事务。
2. **普通数据通路 Payload（`dp_lib_DFFE`）**：
   - 使能连接 `in_en = rst_n & r{N-1}_valid`（S1 级为 `rst_n & in_valid` 或 `rst_n & req_fire`）。
   - 复位期间与气泡期间均不翻转，既保证无效拍低动态功耗，也无需复位树布线开销。
3. **多精度分段/分槽门控与目的级恢复零（Write-Gating + Read-Zero-Restoration）**：
   - 当寄存器仅在部分精度下使用（如 Q/H 才用的高比特位、E 才用的后四槽、混合顶层扩展 group 的对齐叶子、HiF4 才用的 `e2` 指数）：
     - **写使能（源级）**：`in_en = rst_n & r{N-1}_valid & r{N-1}_feature_active`。
     - **读出恢复（目的级）**：由于未激活拍寄存器保持旧值，目的级读取端**必须**通过 `r{N}_feature_active ? r{N}_reg_out : {W{1'b0}}` 恢复结构零，确保逐拍切换精度时历史数据绝对不污染当前请求。

```verilog
// S5 -> S6 extension leaves: gated on r5_extension during write, zero-restored on r6_extension during read
wire [EXT_GROUPS*GLOBAL_W-1:0] r6_extension_leaves;

dp_lib_DFFE #(.WIDTH(EXT_GROUPS * GLOBAL_W))
ff_s5_s6_extension_leaves (.clock(clock), .in_en(rst_n & r5_valid & r5_extension), .in_d(leaves_d[BASE_GROUPS*GLOBAL_W+:EXT_GROUPS*GLOBAL_W]), .out_q(r6_extension_leaves));

assign r6_leaves[BASE_GROUPS*GLOBAL_W+:EXT_GROUPS*GLOBAL_W] = r6_extension ? r6_extension_leaves : {(EXT_GROUPS*GLOBAL_W){1'b0}};
```
