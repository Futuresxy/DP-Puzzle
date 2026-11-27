# 项目技能

本项目所有技能统一存放于此，例如 `.skill/dc-synthesis/SKILL.md`、`.skill/power-analysis/SKILL.md`。辅助脚本和参考资料放在对应技能子目录；技能引用根目录 AGENTS.md 和公共仓库脚本，避免复制另一套实现。

已安装用户指定的 [academic-humanizer](academic-humanizer/SKILL.md)，来源为 AIScientists-Dev/academic-humanizer，固定版本见 [安装记录](academic-humanizer/INSTALLATION.md)。论文写作时由根目录 AGENTS.md 引导读取，无需把技能复制到其他位置。

硬件开发与审查使用 [chisel-design](chisel-design/SKILL.md)：维护 PE/MN-PE/K-PE 架构及 Scala/spec 一一对应，明确位宽、scale、资源复用和流水依据。

单 DP 真实负载功耗的方案和测量使用 [power-analysis](power-analysis/SKILL.md)，包括 VCS 原生门级 SAIF、Power Compiler 注释验收和精度比较口径。

已有 `.codex/`、`.agents/` 等设置保持不变。此目录名是项目统一存放约定；不假定应用会自动扫描任意自定义目录，下轮可显式指定技能文件使用。

维护中的手写 Verilog 设计与审查使用 [dp-rtl-code-style](dp-rtl-code-style/SKILL.md)：融合 SN 基础规范与 Vortex `hw/rtl/tcu/` 工业级 RTL 风格，定义原生列对齐排版（禁用 `verilog_format: off/on` 屏蔽注释）、按功能/相关性分组的精炼注释规范、单变量声明、同步低有效 `rst_n`、显式 DFF 流水保存、多精度写门控与目的级结构零恢复、S/I/F 坐标表以及双层自检 Testbench 与 CModel 断点差分验证规范。现有 RTL 的接口迁移状态见该技能，冻结 SV 不参与迁移。

文件、模块、宏、参数、实例、端口、父层互联、流水变量与 Testbench 的命名使用 [dp-naming-convention](dp-naming-convention/SKILL.md)：统一采用 `rN_<function>`（第 N 级寄存输出）与 `<function>_d`（组合候选）替代跨级打包数组，通过自解释功能词区分 `exponent_field`、`exponent_field_width`、`unbiased_exponent`、`anchor`、`compare_exp`、`fraction_field`、`fractional_bits`、`magnitude` 与 `signed_sum`，消除裸 `e/f/a/tmp` 等不明缩写。
