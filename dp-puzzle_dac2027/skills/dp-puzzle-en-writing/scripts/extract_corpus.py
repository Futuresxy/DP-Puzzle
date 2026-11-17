#!/usr/bin/env python3
"""Replay the curated Stage-A corpus extraction; never opens a TeX file for writing."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import xml.etree.ElementTree as ET

NS = {'h': 'http://www.w3.org/1999/xhtml'}
WORD = re.compile(r"[A-Za-z0-9]+(?:[-’'][A-Za-z0-9]+)*")


def normalize(text):
    # Only compatibility ligatures and whitespace; do not normalize math symbols.
    for a, b in {'ﬁ': 'fi', 'ﬂ': 'fl', 'ﬀ': 'ff', 'ﬃ': 'ffi', 'ﬄ': 'ffl'}.items():
        text = text.replace(a, b)
    return re.sub(r'\s+', ' ', text).strip()


def sentences(text):
    protected = text
    for abbr in ['e.g.', 'i.e.', 'a.k.a.', 'Fig.', 'Figs.', 'Sec.', 'Dr.', 'et al.', 'vs.']:
        protected = protected.replace(abbr, abbr.replace('.', '∯'))
    parts = re.split(r'(?<=[.!?])\s+(?=[A-Z“(])', protected)
    return [p.replace('∯', '.') for p in parts]


def summarize(items):
    counts = [len(WORD.findall(s)) for s in items]
    return {'sentences': len(counts), 'words': sum(counts),
            'mean_words': round(statistics.mean(counts), 3) if counts else None,
            'median_words': statistics.median(counts) if counts else None,
            'over_30': sum(n > 30 for n in counts),
            'over_30_percent': round(100 * sum(n > 30 for n in counts) / len(counts), 3) if counts else None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=Path('.'))
    ap.add_argument('--output', type=Path, default=Path('build/stage-a'))
    ap.add_argument('--evidence', type=Path)
    args = ap.parse_args()
    config = json.loads((Path(__file__).parent.parent / 'references/evidence/curation.json').read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    manifest, records, rows, repairs = [], [], [], []
    tool_version = subprocess.run(['pdftotext', '-v'], capture_output=True, text=True, check=True).stderr.splitlines()[0]
    for spec in config['papers']:
        pid = spec['id']
        pdf = args.root / 'reference' / spec['file']
        folder = args.output / pid
        folder.mkdir(exist_ok=True)
        for name, opts in [('layout.txt', ['-layout']), ('reading.txt', []), ('bbox.html', ['-bbox-layout'])]:
            subprocess.run(['pdftotext', *opts, '-enc', 'UTF-8', str(pdf), str(folder / name)], check=True)
        raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', (folder / 'bbox.html').read_text())
        pages = ET.fromstring(raw).findall('.//h:page', NS)
        blocks = []
        lexicon = set(re.findall(r'\b[A-Za-z]{3,}\b', normalize((folder / 'reading.txt').read_text()).lower()))
        for pn, page in enumerate(pages, 1):
            for block in page.findall('.//h:block', NS):
                lines = [' '.join(w.text or '' for w in line.findall('h:word', NS)) for line in block.findall('h:line', NS)]
                joined = '\n'.join(normalize(line) for line in lines)
                def repair(match):
                    left, right = match.group(1), match.group(2)
                    key = left + '-' + right
                    replacement = config.get('hyphen_overrides', {}).get(key)
                    if replacement is None:
                        replacement = left + right if (left + right).lower() in lexicon else key
                    repairs.append({'paper': pid, 'page': pn, 'block': len(blocks), 'original': key, 'replacement': replacement})
                    return replacement
                joined = re.sub(r'([A-Za-z]+)-\n([a-z][A-Za-z]*)', repair, joined)
                blocks.append({'page': pn, 'text': normalize(joined), 'lines': lines})
        (folder / 'blocks.json').write_text(json.dumps(blocks, ensure_ascii=False, indent=2) + '\n')
        (folder / 'cleaned.txt').write_text('\n\n'.join(f'[{pid} b{i} p{b["page"]}] {b["text"]}' for i, b in enumerate(blocks)) + '\n')
        manifest.append({'id': pid, 'file': str(pdf.relative_to(args.root)), 'sha256': hashlib.sha256(pdf.read_bytes()).hexdigest(),
                         'pages': len(pages), 'tool': tool_version, 'method': 'pdftotext -layout + -bbox-layout; default extraction for lexical dehyphenation',
                         'blocks': len(blocks), 'status': 'text_extracted', 'scanned_only': False,
                         'layout_sha256': hashlib.sha256((folder / 'layout.txt').read_bytes()).hexdigest()})
        for section, ids in spec['sections'].items():
            selected = []
            for entry in ids:
                span = entry if isinstance(entry, dict) else {'blocks': [entry]}
                bid = span['blocks'][0]
                block = blocks[bid]
                t = ' '.join(blocks[n]['text'] for n in span['blocks'])
                if span.get('start'):
                    t = t[t.index(span['start']):]
                if span.get('end'):
                    t = t[:t.index(span['end'])]
                for heading in spec.get('remove_headings', []):
                    t = t.replace(heading, ' ')
                t = re.sub(r'^Abstract\s*[—–-]\s*', '', t)
                t = t.replace('• ', '')
                t = re.sub(r'^\s*\(?\d+\)\s*', '', t)
                # Start/end fragments, equations, lists and captions are excluded, not silently repaired.
                for si, sentence in enumerate(sentences(normalize(t))):
                    if not re.match(r'^[A-Z][a-zA-Z]', sentence) or not re.search(r'[.!?][”"]?$', sentence):
                        continue
                    if len(WORD.findall(sentence)) < 5 or re.search(r'[=⎢⎥⎣⎦]|https?://', sentence):
                        continue
                    if sentence.count('(') != sentence.count(')'):
                        continue
                    if sentence.startswith(('Fig.', 'Figure ', 'TABLE ', 'Table ')) and len(WORD.findall(sentence)) < 12:
                        continue
                    record = {'paper': pid, 'section': section, 'block': bid, 'blocks': span['blocks'], 'page': block['page'], 'sentence_index': si, 'text': sentence,
                              'words': len(WORD.findall(sentence))}
                    records.append(record)
                    selected.append(sentence)
            rows.append({'paper': pid, 'section': section, **summarize(selected)})
        rows.append({'paper': pid, 'section': 'all_selected_prose', **summarize([r['text'] for r in records if r['paper'] == pid])})
    data = {'manifest': manifest, 'sentences': records, 'statistics': rows, 'repairs': repairs}
    (args.output / 'extraction.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    if args.evidence:
        args.evidence.mkdir(parents=True, exist_ok=True)
        (args.evidence / 'corpus-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        with (args.evidence / 'sentence-statistics.csv').open('w') as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
            writer.writeheader(); writer.writerows(rows)
        (args.evidence / 'hyphen-repairs.json').write_text(json.dumps(repairs, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'papers': len(manifest), 'pages': sum(x['pages'] for x in manifest), 'selected_prose': summarize([r['text'] for r in records])}))


if __name__ == '__main__':
    main()
