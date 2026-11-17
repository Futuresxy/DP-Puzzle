# DP-Puzzle — DAC 2027 英文论文独立工程

后续编辑入口为 **`dp-puzzle.tex`**。本目录包含所有 LaTeX 编译依赖，
可以单独复制到其他位置或上传至 Overleaf，无需访问上级 `paper/` 目录。
原目录中的稿件和共享资源保留，供中文稿及历史记录使用；此独立工程的修改
不会自动同步回原文件。

## 编译

使用常规 TeX Live / MiKTeX，编译器为 **pdfLaTeX**，参考文献使用 BibTeX。
不需要原工程的 XeLaTeX、系统字体配置或环境变量。

```sh
cd dp-puzzle_dac2027
make pdf
# 或直接运行 latexmk
```

输出：`build/dp-puzzle.pdf`。`make clean` 清理辅助编译文件。
Overleaf 中将 `dp-puzzle.tex` 设为主文件，编译器选择 pdfLaTeX。

## 编辑位置

- `dp-puzzle.tex`：摘要、正文、结论、AI 使用说明及浮动体插入位置。
- `tables/`：5 张表格的独立英文表体。
- `figures/`：当前使用的基线架构图、面积/功耗图、案例图，以及正文中已注释的
  `unpack_layout.pdf`、`dynamic_add.pdf`。后两张可直接取消注释恢复使用。
- `references/references.bib`：独立参考文献库，含精简显示信息和完整来源元数据。
- `IEEEtran.cls`、`IEEEtran.bst`：从 `paper/template/` 原样复制的模板和引用样式。
- `template/`：原始会议示例、模板来源及上游许可说明；示例不参与正文编译。
- `migration_manifest.json`：资源清单与复制时的 SHA-256，用于核对迁移完整性。

## 格式

沿用官方示例的 IEEEtran conference 模式，10 pt、Letter、双栏，
使用模板默认字体和页边距。模板文件未修改，不通过缩小页边距或压缩字体挤页。
参考文献强制从独立新页开始；源码保留正文超过 6 页、参考文献超过 1 页的告警。
匿名作者和空白作者元数据保留。投稿前仍需作者审核内容和最终 PDF。

`template/SOURCE.md` 是原模板来源记录，其中提到的旧工程路径仅说明历史来源，
不构成本工程的编译依赖。

## 迁移验收

已在清除原工程 TeX 搜索环境变量后，将整个目录复制到临时位置独立编译。
结果仍为 6 页正文＋1 页参考文献，无未定义引用或文字越界，字体全部嵌入。
正文内容与原英文稿一致；核验结果见 `validation.json`。
仓库根目录原有的 `reference/` 为作者准备的阅读资料，不参与正文编译。
