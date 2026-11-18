# Change log — B2–B5 / C

共 10 处源码位置、16 个局部替换：4 处 must-fix、6 处 should-fix；主类别均为 term。同一源码行合并记录，严重度取该行最高级；各片段保留自身候选 ID。未执行 optional。

基线是本轮开始时的工作区（包括作者已有摘要、关键词和两份表格修改），不是 Git HEAD。完整补丁见 [diff.patch](diff.patch)，完整前后源码行及片段见 [applied-changes.json](evidence/applied-changes.json)。补丁恰为 10 个旧行替换为 10 个新行；原始 `+/-` 总行数是 20，不能当作 20 处语言修改。没有为凑计数重排或拆分源码。

| # | 位置（行号/小节） | 严重度 | 原文 | 改后 | 类别 | 依据 |
| --- | --- | --- | --- | --- | --- | --- |
| C01 | `dp-puzzle.tex:36` | must-fix | `AI workloads`<br>`doubling FP4 throughput`<br>`At matched area and power`<br>`on DeepSeek-V4.1-Flash GEMMs` | `Artificial intelligence (AI) workloads`<br>`doubling MXFP4 throughput`<br>`Under common area and power budgets`<br>`on DeepSeek-V4.1-Flash general matrix multiplications (GEMMs)` | term | M04,M05,S01,S02; R08/R09/R14; author Q3/Q4; terminology T52 |
| C02 | `dp-puzzle.tex:39` | should-fix | `AI workloads`<br>`units,LLM inference` | `artificial intelligence workloads`<br>`units, large language model inference` | term | M05,S05; R14; prompt B1 abstract/keywords/body consistency; adjacent missing keyword separator space |
| C03 | `dp-puzzle.tex:46` | must-fix | `large AI models` | `large artificial intelligence (AI) models` | term | M05; R14; prompt B1 independent body first occurrence |
| C04 | `dp-puzzle.tex:72` | should-fix | `S1P2 fixed-point elements` | `S1P2 sign-magnitude fixed-point elements with one sign bit, one integer magnitude bit, and two fractional bits` | term | S03; R14; author Q6; src/spec/dp/lane/unpack.md:76; encoding and QI.F definition unchanged |
| C05 | `dp-puzzle.tex:93` | should-fix | `Design and DSE` | `Design and Design-Space Exploration` | term | S04; R14; single-use abbreviation expanded |
| C06 | `dp-puzzle.tex:106` | should-fix | `GPGPU and NPU vendors` | `general-purpose graphics processing unit (GPGPU) and neural processing unit (NPU) vendors` | term | S05; R14; explicit first-use mappings of existing acronyms |
| C07 | `dp-puzzle.tex:155` | should-fix | `the U31 magnitude interface` | `the U31 (31-bit unsigned magnitude) interface` | term | S03; R14; author Q6; src/spec/dp/group/dp_group_E.md section 2; mode-specific fractional bits already defined in next paragraph |
| C08 | `dp-puzzle.tex:224` | should-fix | `Verilog RTL`<br>`the TT corner`<br>`first-layer MLP down-projection` | `Verilog at the register-transfer level (RTL)`<br>`the typical-typical (TT) corner`<br>`first-layer multilayer perceptron (MLP) down-projection` | term | S05; R14; existing implementation/PVT/model acronyms expanded; no process conditions changed |
| C09 | `dp-puzzle.tex:257` | must-fix | `maximum measured power` | `maximum estimated power` | term | M02; R11; author Q2; Power Compiler estimates in Experimental Setup |
| C10 | `tables/five_stage_migrations.tex:16` | must-fix | `Sliding Window Attention (SWA) and compressed Sparse attention (CSA)` | `Sliding-Window Attention (SWA) and Compressed Sparse Attention 2 (CSA2)` | term | M03; R08/R14; author Q5 exact attention names; hardware carry-save CSA unchanged |

## 保留与验证

- M01 表头已由作者改成 T2H4Q8E16，本轮零修改，不计入日志；三个 optional 位置逐字不变。
- S1P2 仅补充既有编码说明，未改称二补码 Q1.2；U31 仅解释已确认的位宽，原有小数位与符号公式不变。
- 数学、引用、标签、输入路径、宏、原有数字序列逐项比较通过；新增数字仅为 U31 的 31 位释义和作者指定 CSA2 名称。
- 你已有的摘要开头、1.13× 形式以及表头修正均保留；其他工程文件不参与本次编辑。
- 当前分支沿用 feat/dp-verilog-v14，遵循后来的 AGENTS 工作分支约定；没有创建 en-audit 分支。
- 编译退出码 0，8 页，参考文献从第 8 页开始；正文超 6 页告警未消除。没有 Overfull 或未定义引用。Underfull hbox/vbox 为 11/3。
- 新错误回退规则未触发；当前是页数告警，保留全部内容，另列作者决策。

本轮本地提交保存审计文件与可重放的 diff.patch；含作者已有改动的 TeX 留在工作区，不混入该审计提交。
