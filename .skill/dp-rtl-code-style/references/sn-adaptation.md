# SN 与 Vortex TCU 规范融合及演进记录

## 1. 演进背景

DP-Puzzel 的 Verilog RTL 编码规范历经两个阶段凝练：

1. **第一阶段（2026-11-06，SN 基础移植）**：
   - 引入显式 `dp_lib_DFF*` 基础单元例化（功能层禁写 `always @(posedge clock)`）、控制/数据复位分离（同步低有效 `rst_n`）、组合逻辑 `assign`、按位运算符（`&` `|` `~` `^`）、显式 MUX、单行单变量声明与基础自检清单。
2. **第二阶段（2026-11-27，Vortex `hw/rtl/tcu/` 工业级风格与验证体系融合）**：
   - 参考 `/home/songxy/workspace/vortex`（特别是 `docs/coding_guidelines_verilog.md`、`.agents/skills/rtl-review/SKILL.md`、`hw/rtl/tcu/tfr/VX_tcu_fedp_tfr.sv`、`VX_tcu_tfr_mul_*.sv`、`VX_tcu_tfr_align.sv`、`hw/unittest/tcu_fedp/`），解决此前 RTL 代码中存在的两大痛点：
     - **痛点 1：满篇 `// verilog_format: off` / `// verilog_format: on` 污染源码**。
       - **改进**：全面移除并禁止 `verilog_format: off/on` 注释，直接定义模块参数、端口、内部信号、子模块例化、DFF 紧凑两行和三目运算符的原生垂直对齐规范。
     - **痛点 2：变量注释过度碎片化（每个自解释 `wire` 上方都写一行冗余注释）**。
       - **改进**：全面采用 Vortex `hw/rtl/tcu` 的**功能/相关性分组注释法**——按流水级或计算步骤将相关信号聚成一组，组顶写 1–2 行简明功能或硬件不变量注释（Why），组内保持紧凑列对齐，不再为每个自解释变量单独写注释。

---

## 2. 从 Vortex 提炼的核心工程规范映射表

| Vortex 规范与 TCU 实践 | DP-Puzzel Verilog-2005 落地规范 |
| --- | --- |
| **接口与寄存器所有权**（`coding_guidelines_verilog.md` §4）：驱动方在自身输出边界完成寄存，下游与父层禁止二次打拍 | 组合子模块不暗藏流水寄存器；各级 DFF 由对应 stage owner 持有并就地放置（`ff_sN_sM_*`），父模块路由已寄存信号不重复打拍 |
| **垂直列对齐**（`coding_guidelines_verilog.md` §12）：参数 `=` 对齐、端口类型/位宽/名称列对齐、例化 `.port (sig)` 左括号 `(` 对齐 | 全面采纳；DFF 基础单元保留紧凑两行例化，不加 `verilog_format` 屏蔽注释 |
| **分组与意图注释**（`coding_guidelines_verilog.md` §9 & `hw/rtl/tcu/tfr/`）：注释解释 Why 与分组职责，禁写逐变量废话与 PR/bug 过程记录 | 模块头保留简明架构/S-I-F 契约；内部信号按流水级/相关性分组注释；复杂阶段用 `// ==== Stage N ====` 横幅与 `// 1. ...` 子步骤组织 |
| **强制 `begin`/`end`**（`coding_guidelines_verilog.md` §3）：所有分支与循环必须带 `begin/end`，禁止单语句省略 | 全面强制适用于所有 `if/else/for/while`（含 `generate` 与 Testbench） |
| **避免 `UNOPTFLAT` 伪组合环**（`coding_guidelines_verilog.md` §5）：禁止把组合输入与寄存级拼入同一向量 | 废弃 `valid_q[0:N]` 混合数组，统一按级独立命名 `in_valid`、`r1_valid` .. `r8_valid` |
| **分通道掩码流水寄存器与消零**（`VX_tcu_tfr_pipe_register.sv` & `VX_tcu_tfr_shared_mul.sv`） | 多精度寄存器写使能用源级 `r{N-1}_datatype` 门控，读取端用目的级 `r{N}_datatype` 恢复结构零 |
| **静态与运行时断言**（`VX_platform.vh` `STATIC_ASSERT` / `RUNTIME_ASSERT`） | 模块末尾 `synthesis translate_off` 块内编写参数合法性静态检查与 `rst_n & rN_valid` 门控的运行时断言 |
| **特征激励单元测试与 SimX-as-Oracle 轨迹差分**（`hw/unittest/tcu_fedp/` & `docs/debugging.md`） | 建立模块级特征+随机+气泡/切换/复位压力 Unit TB，以及顶层 `CUTPOINTS` 逐级轨迹与 CModel diff 流程 |
