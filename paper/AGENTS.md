# 论文编辑授权范围（用户于 2026-11-16 更新）

## 微架构正式同步（2026-11-17）

用户明确授权将本轮 `main_temp.tex` 修改更新到正式稿。当前第三章已迁入 `sections/03_architecture.tex`，由 `main.tex` 引用；九种配比的 Group 构成表统一使用 `tables/group_compositions.tex`，正式稿与临时稿共用这一表体。基线、解码与扩展累加图分别使用作者提供的 `baseline_arch.pdf`、`unpack_layout.pdf`、`dynamic_add.pdf`。

此次迁移保留正式稿已有的摘要、引言、背景、评估、DSE 和结论，以及首页右栏 Table I；临时稿中这些章节属于较早快照，不用于覆盖正式稿后续编辑。英文稿未同步。后续正式稿修改仍须用户明确要求。

## 共享表格（2026-11-16）

用户随后要求将原 Table III 的格式简称、定点格式和并行度记号改为第三章首个小节的文字说明；`tables/precision_families.tex` 已移除，相关内容在中英文正文的 `sec:notation_conventions` 处维护。

用户要求中英文稿共用每张表的单一文件，并统一使用英文表题、表头和注释。共用入口为 `tables/vendor_ratios.tex`、`tables/related_features.tex` 和 `tables/related_ppa_native.tex`；不再向英文正文内复制表体。英文旧章节专用表放在 `tables/legacy/`，保留现有引用；不据此扩大正文改写范围。临时审阅稿仍保留为历史快照。

## 当前正式稿（2026-11-16 提升）

用户已明确授权将当前 `main_temp.tex` 提升到 `main.tex`，本轮正式同步 Table I/IV 的原工艺比较、第四章 C 带宽分析、面积/功耗联合 DSE 与结论。正式引用使用 `tables/related_ppa_native.tex`、`figures/dse_fixed_budget_v2.pdf` 及 `references/references.bib`。工业芯片配比表 `tables/vendor_ratios.tex` 在首页右栏顶部，按源码顺序自动编号为 Table I；精度支持表为 Table II。不得手动设置 table counter，正文统一通过 label/ref 引用。

本次提升是明确授权，不取消后续修改正式稿仍须用户要求的约定。作者摘要和引言表外正文保持原样；临时稿保留为提升前的审阅快照。后续复现正式展示使用 `make presentation`，默认 `make reproduce` 不再调用历史工艺归一化表生成器。最近关于 collector/L0 的讨论未写入正文或模型。


本文件约束本目录及其子目录，以下用户最新要求优先于此前默认直接修改论文的工作方式。

- 没有用户明确要求，不得修改正式稿 `main.tex` 及其引用的正文、图表、参考文献等内容。讨论、分析或实验请求本身不构成将结论写入正式论文的授权。
- 后续论文内容草稿写入 `main_temp.tex`，由用户审阅并手动搬入正式稿。不得通过修改两个入口共用的 `sections/`、图表或其他引用文件间接改变正式稿。
- 摘要和引言由用户统筹凝练；没有针对这两部分的明确要求，不改写、不回退、不自动同步。保护用户未提交编辑。
- `main_temp.tex` 中的 DSE 为独立内嵌副本。其他章节仍只读引用正式文件；若要起草其他章节，先将对应内容独立放入临时稿，再在临时稿中修改。
- 当前 DSE 以 `1:2:4` 为 baseline，功耗预算探索范围为 `1 <= beta <= 2.1` 左右；不再将 beta<1 纳入当前探索。保留面积与功耗联合约束建模。
- 2026-11-16 本轮用户明确授权撤回上一轮严格功耗探索，正式 DSE 恢复至 `740da79` 的六场景版本。此为本次恢复授权，不表示后续可自动修改正式稿。
- `v41_power_sweep_20261116` 的数据、脚本和图保留为历史记录，已退出当前正文与默认复现流程；不能将其叙述为当前接受的论文结论。

- 2026-11-16 Table I/IV 修订：`main_temp.tex` 已独立内嵌引言和硬件评价章。引言仅获授权修改 Table I，复制时表外正文逐字保留；这不授权修改引言正文或同步覆盖用户后续编辑。硬件评价副本仅修改末尾相关工作比较小节，新表为 `tables/temp/related_ppa_native.tex`，原工艺数据与来源见 `data/evidence/related_native_20261116/`。正式章节与表格继续保留，由作者手动迁移。

- 2026-11-16 后续授权：临时稿硬件评价章 C 已改为 A 复用 x 周期、B 每周期更新的阵列输入带宽分析；只说明 shared memory 的供数条件，不实施阵列或带宽约束模型。临时稿结论亦为独立内嵌副本，正式 `sections/06_conclusion.tex` 不自动同步。
