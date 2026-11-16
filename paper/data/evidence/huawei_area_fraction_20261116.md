# 基准 TensorCore 面积占比的公开参考

- 日期：2026-11-16。作者提供原文链接与第 6.1 节截图，要求为正式稿中的 30% 面积比例补充引用。
- 文献：Yuanyong Luo et al., “Ascend HiFloat8 AI Training and Inference,” Communications of HUAWEI RESEARCH, June 2024, pp. 76–98。
- 来源：https://www-file.huawei.com/-/media/corp2020/pdf/publications/huawei-research/2024/huawei-research-issue6-en.pdf#page=99
- 定位：第 6.1 节 Area Evaluation，印刷页 93 / PDF 第 99 页；文章首页为印刷页 76 / PDF 第 82 页。
- 本地 PDF SHA-256：`c98ab6c309e239e594e07afff13f8e6b3ad3cce8bc41b53caa663942def9d2f2`。核对本地原 PDF 的文本与页面图像，并与作者截图对照；在线直接打开暂返回 503，搜索索引亦返回同一面积说明。
- 原文报告：Ascend XXX1 的 Cube 计算簇占 AI Core 总面积 32.7%。同节在 12 nm、K=32 的 RTL pilot code 上评估增加 HiF8 支持的开销。
- 边界：32.7% 对应计算簇，不是单个 DP 或计算切片。原文另报告计算切片约占计算簇面积的 80%，不能将两者混为同一口径。
- 本文用法：以该公开实例作为基准张量计算部分面积占比的数量级参考，继续取 alpha=0.3；这是本文的近似建模选择，不将其表述为华为实测的 30% 或所有 SM 的通用比例。
- 改动：仅在正式 DSE 模型参数定义处补充说明并引用已有 BibTeX 条目 `luo2024hifloat8area`。模型参数、数据、图表及临时稿快照不变。
