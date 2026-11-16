# 临时稿提升为正式稿

用户明确授权提升 `main_temp.tex`，并要求工业芯片配比表位于首页右上角。随后进一步要求按文章顺序自动编号。

- 正式入口 `main.tex` 保留按章节组织；新版硬件评价、DSE、总结从临时稿逐段迁入 `sections/04_evaluation.tex`、`05_dse.tex`、`06_conclusion.tex`。
- `tables/related_features.tex` 承接临时稿精度比较；在引言中引用，表外作者文字不改写。
- 工业表从背景章抽为 `tables/vendor_ratios.tex`，数据不变，主入口标题后提前安排浮动。使用 `[t]` 与左栏顶部浮动抑制使其位于第一页右栏，不能改成 `[!t]` 绕过抑制。
- 所有表格使用自动 caption 编号，不重置 table counter：工业表 I，精度支持 II，精度记号 III，硬件成本 IV。正文通过 label/ref 跟随编号。
- 正式成本表 `tables/related_ppa_native.tex` 与正式 DSE 图 `figures/dse_fixed_budget_v2.pdf` 使用独立正式路径。三条正式引用以规范 key 加入主 bibliography；数据与图保持临时稿批准版本。
- `make presentation` 调用两脚本的 `--official` 模式，独立保存 `related_native_main_20261116` 和 `dse_fixed_budget_main_20261116` 的数据与指纹；默认 reproduce 不再调用历史归一化表生成器。旧批次保留。
- 临时稿内冻结原背景章，避免工业表迁移导致其审阅快照缺表；其余原临时副本保留。有关 collector/L0 的后续讨论仍未进入正文。

作者在任务期间注释了原格式图；保留该编辑并移除正文悬空引用。图序因此依当前工作稿自动变化；此操作不改变任何图的数据。摘要和引言表外正文未改写，作者已有暂存文件不加入本批提交。

验证：正式/临时两入口编译，检查缺失引用与溢出；正式 DSE PDF 与临时 PDF 逐字节一致，正式与临时成本/DSE CSV 一致；正式三节与临时副本仅有路径和引用 key 的迁移；从 PDF 文本坐标和页面渲染确认工业表位于首页右栏顶部。
