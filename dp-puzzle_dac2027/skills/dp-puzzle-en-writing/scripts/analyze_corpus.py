#!/usr/bin/env python3
"""Generate transparent surface-pattern counts and a statistical report from extracted prose."""
import argparse, collections, csv, json, re
from pathlib import Path
from extract_corpus import summarize

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--corpus',type=Path,default=Path('build/stage-a'))
    ap.add_argument('--skill',type=Path,default=Path(__file__).resolve().parents[1])
    a=ap.parse_args(); ev=a.skill/'references/evidence'
    x=json.loads((a.corpus/'extraction.json').read_text())
    ann=json.loads((ev/'annotations.json').read_text())
    records=x['sentences']
    patterns={
      'bitwidth':r'\bbitwidths?\b','bit width':r'\bbit widths?\b','bit-width':r'\bbit-widths?\b',
      'datapath':r'\bdatapaths?\b','data path':r'\bdata paths?\b','dequantization':r'\bdequantization\b',
      'mantissa':r'\bmantissas?\b','significand':r'\bsignificands?\b',
      'It is worth noting that':r'\bit is worth noting that\b','It is worth pointing out that':r'\bit is worth pointing out that\b',
      'We believe':r'\bwe believe\b','It should be noted':r'\bit should be noted\b','may potentially':r'\bmay potentially\b',
      'can help to':r'\bcan help to\b','to some extent':r'\bto some extent\b','suggest … may':r'\bsuggest\w*\b.{0,120}\bmay\b',
      'Aiming at':r'\baiming at\b','In order to':r'\bin order to\b','carry out experiments':r'\bcarry out experiments\b',
      'has good performance':r'\bhas good performance\b','the reason lies in':r'\bthe reason lies in\b',
      'With the rapid development of':r'\bwith the rapid development of\b','plays an important role':r'\bplays an important role\b',
      'not only … but also':r'\bnot only\b.*\bbut also\b','on the one hand … on the other hand':r'\bon the one hand\b.*\bon the other hand\b',
      'significantly':r'\bsignificantly\b','very':r'\bvery\b','greatly':r'\bgreatly\b','dramatically':r'\bdramatically\b',
      'the … of the … of the':r'\bthe\b(?:\W+\w+){1,5}\W+of the\b(?:\W+\w+){1,5}\W+of the\b',
      'which chain':r'\bwhich\b.*\bwhich\b','respectively':r'\brespectively\b',
      '12nm-like unit spacing':r'\b\d+(?:\.\d+)?(?:nm|GHz|MHz|mW)\b',
      'space before percent':r'\d\s+%', 'no space before percent':r'\d%',
      'American normalization':r'\bnormaliz\w*\b','British normalisation':r'\bnormalis\w*\b',
      'American optimization':r'\boptimiz\w*\b','British optimisation':r'\boptimis\w*\b'}
    collocations={
      'support formats':r'\bsupport\w*\b(?:\W+\w+){0,6}\W+formats?\b',
      'reduce area':r'\breduc\w*\b(?:\W+\w+){0,4}\W+area\b',
      'reduce power':r'\breduc\w*\b(?:\W+\w+){0,4}\W+power\b',
      'improve energy efficiency':r'\bimprov\w*\b(?:\W+\w+){0,4}\W+energy efficiency\b',
      'achieve throughput':r'\bachiev\w*\b(?:\W+\w+){0,5}\W+throughput\b',
      'incur overhead':r'\bincur\w*\b(?:\W+\w+){0,5}\W+overhead\b',
      'amortize cost/overhead':r'\bamortiz\w*\b(?:\W+\w+){0,6}\W+(?:cost|overhead)s?\b',
      'hide latency':r'\bhid(?:e|es|ing)\b(?:\W+\w+){0,3}\W+latenc(?:y|ies)\b',
      'exploit sparsity':r'\bexploit\w*\b(?:\W+\w+){0,3}\W+sparsity\b',
      'close timing':r'\bclos(?:e|es|ing)\b(?:\W+\w+){0,2}\W+timing\b'}
    def count(pats):
      out=[]
      for label,pat in pats.items():
        hits=[r for r in records if re.search(pat,r['text'],re.I)]
        out.append({'pattern':label,'regex':pat,'sentence_hits':len(hits),'by_paper':dict(collections.Counter(r['paper'] for r in hits)),
                    'examples':hits[:3]})
      return out
    pc=count(patterns);cc=count(collocations)
    (ev/'pattern-counts.json').write_text(json.dumps(pc,ensure_ascii=False,indent=2)+'\n')
    (ev/'collocations.json').write_text(json.dumps(cc,ensure_ascii=False,indent=2)+'\n')
    metrics=[]
    for p in x['manifest']:
      hits=[r for r in records if r['paper']==p['id'] and re.search(r'\d',r['text']) and re.search(r'compar|baseline|overhead|normalized|efficien|speedup',r['text'],re.I)]
      metrics.append({'paper':p['id'],'sentences':sorted(hits,key=lambda r:r['words'])[:3]})
    (ev/'comparison-examples.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n')
    overall=summarize([r['text'] for r in records])
    l=['# Corpus extraction and statistical evidence','',
       '日期：2026-11-18。只统计 `reference/` 下 8 篇 PDF，共 69 页。外部标准和目标稿均不计入语料统计。', '',
       '## A1：抽取、清洗与可重放范围','',
       '- 首先逐篇运行 `pdftotext -layout -enc UTF-8`，再用 `-bbox-layout` 的独立文本块避免左右栏串行污染；默认阅读顺序抽取仅作为辅助。',
       '- 原始版面、bbox XML、逐块清洗文本和逐句记录留在被忽略的 `build/stage-a/`；PDF hash、工具版本、选块、断词修复和统计摘要保存在本目录 evidence/。',
       '- curation.json 显式列出六个修辞部分的块 ID/起止锚点。章节内背景折入 method；贡献从 introduction 拆出；不把贡献算两次。',
       '- 排除参考文献、作者简介、版权、页眉页脚、行号、图表、程序和公式密集片段；清洗连字与换行空白，断词修复逐条可追溯。不更正语料作者原有语法或拼写。',
       '- 无纯扫描件，跳过列表为空。P07 有大量审稿行号；按块筛除。P08 的乘号存在抽取缺失，不从它推算数值，也不作倍数书写依据。',
       '- 部分块跨段或跨栏，未可靠拼接的首尾残句、少于 5 个 token 的片段和括号不平衡/含等式的句子不纳入句长统计。这是可重放的正文近似统计，不声称 100% 句法标注或 OCR 校对。',
       '- 词定义：英文字母/数字串，内部连字符与撇号计一个词；如 1.09 可能分成两个 token。缩写句点有保护，但数学、小节标题和引文仍可能影响句界。原始 quotes 保留在 annotations.json，可独立核对。','',
       '## A2：句长','',f"筛选后 {overall['sentences']} 句、{overall['words']} 个 token；均值 {overall['mean_words']}，中位数 {overall['median_words']}，>30 词 {overall['over_30']} 句（{overall['over_30_percent']}%）。",'',
       '项目希望均值 18–22、硬上限 30；本次语料不支持把它们当作普遍事实。这个结论受上述筛选和 tokenization 口径限制。','',
       '| Paper | 文件 | 页数 | 句数 | 均值 | 中位数 | >30 词比例 |','| --- | --- | --- | --- | --- | --- | --- |']
    for p in x['manifest']:
      r=next(r for r in x['statistics'] if r['paper']==p['id'] and r['section']=='all_selected_prose')
      l.append(f"| {p['id']} | {Path(p['file']).name} | {p['pages']} | {r['sentences']} | {r['mean_words']} | {r['median_words']} | {r['over_30_percent']}% |")
    l+=['','逐篇六部分的全部统计见 [sentence-statistics.csv](evidence/sentence-statistics.csv)。`contributions` 对无列表的 P06 是叙述式贡献段，不伪造列表。','',
        '## 段首模式（48 个定向样本）','',
        '每篇每个修辞部分取 1 个可辨开篇，手工标注 claim-first（先陈述问题/优势/判断）或 topic-first（先介绍对象/活动/范围）。贡献处取条目开篇；这是平衡的定向样本，不是全篇所有段落的比例估计，不推断整领域偏好。原句、页码和标注理由见 annotations.json → paragraph_openings。','',
        '| Paper | claim-first | topic-first |','| --- | --- | --- |']
    for p in x['manifest']:
      c=collections.Counter(q['label'] for q in ann['paragraph_openings'] if q['paper']==p['id'])
      l.append(f"| {p['id']} | {c['claim-first']} | {c['topic-first']} |")
    l+=['','## 贡献条目动词与平行性','','| Paper | 条目数 | 开头/主干 | 平行性 |','| --- | --- | --- | --- |']
    for q in ann['contributions']:l.append(f"| {q['paper']} | {len(q['heads'])} | {', '.join(q['heads']) or '无显式列表'} | {q['parallelism']} |")
    counts=collections.Counter(h for q in ann['contributions'] for h in q['heads'])
    l+=['', '条目主干计数（不把所有 We 句都当贡献）：'+', '.join(f'{k}={v}' for k,v in counts.most_common())+'。',
        'P08 跨页的 We demonstrate 是最后一项的延续，不另计条目。P05 We extend 跨栏，原始布局中可查。完整摘录见 annotations.json → contributions。','',
        '## 高频动宾搭配（表面模式）','',
        '这是带有限词距的 regex 命中句数，不是句法依存分析。以下输出包括提示词点名但未命中的搭配；0 不等于禁用。每项保存 regex、逐篇计数和原句示例。','',
        '| 搭配 | 命中句数 |','| --- | --- |']
    l += [f"| {r['pattern']} | {r['sentence_hits']} |" for r in sorted(cc,key=lambda r:-r['sentence_hits'])]
    l+=['','## 指标与比较句','',
        '每篇选取最多 3 条带数值及 comparison/efficiency/overhead 等词的原句，见 comparison-examples.json；可复用模板和适用限制见 phrase-bank.md。这只是写法证据，不替本稿核验硬件结果。','',
        '## 拼写与模式频率','','| 模式 | 命中句数 | 涉及论文数 |','| --- | --- | --- |']
    l += [f"| {r['pattern']} | {r['sentence_hits']} | {len(r['by_paper'])} |" for r in pc]
    l+=['','句子命中频率和论文投票数分别报告：长论文的重复词不能等同于多个独立来源。`respectively` 命中不代表超过三项；前置名词数量、重复结论、支持 significantly 的数据需人工判断。','',
        '## A3 与缺口','',
        f"当前 {len(ann['rules'])} 条有本地证据的规则（18 条 style + 6 条 anti-pattern）；{len(ann['terms'])} 条词表项。状态分布："+str(dict(collections.Counter(t['status'] for t in ann['terms'])))+'。',
        '本地语料不足：HiF4、MXFP6、E8M0 的完整术语实例，Q-format，initiation interval，throughput ratio，TOPS/W、TOPS/mm²、pJ/op 的确切写法，以及 calibration、outlier、precision migration、MoE、attention projection、dequantization。',
        'OCP、NVIDIA、HiF4 原始资料只补充术语裁决，不进入本地统计。IEEE 754-2019 官方全文未能读取。没有证据的 anti-pattern 候选仅列在覆盖缺口，不升级成有证据规则。','']
    (a.skill/'references/corpus-analysis.md').write_text('\n'.join(l))
    print(json.dumps(overall))
if __name__=='__main__':main()
