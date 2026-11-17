#!/usr/bin/env python3
"""Read-only evidence validation and a deliberately limited TeX surface scan."""
import argparse,hashlib,json,random,re
from pathlib import Path


def walk_evidence(obj):
    if isinstance(obj,dict):
        if {'paper','block','quote'} <= obj.keys():yield obj
        else:
            for v in obj.values():yield from walk_evidence(v)
    elif isinstance(obj,list):
        for v in obj:yield from walk_evidence(v)


def verify(root,skill,corpus):
    ev=skill/'references/evidence'
    ann=json.loads((ev/'annotations.json').read_text())
    manifest=json.loads((ev/'corpus-manifest.json').read_text())
    blocks={m['id']:json.loads((corpus/m['id']/'blocks.json').read_text()) for m in manifest}
    errors=[]
    for m in manifest:
        if hashlib.sha256((root/m['file']).read_bytes()).hexdigest()!=m['sha256']:errors.append('PDF hash mismatch: '+m['file'])
    unique={}
    for e in walk_evidence(ann):
        ids=e.get('blocks',[e['block']])
        text=' '.join(blocks[e['paper']][n]['text'] for n in ids)
        if e['quote'] not in text:errors.append('quote missing: '+str((e['paper'],ids,e['quote'])))
        unique[(e['paper'],tuple(ids),e['quote'])]=e
    samples=random.Random(20261118).sample(ann['rules'],5)
    sampled=[{'rule':r['id'],'evidence':r['evidence'][0], 'matched':r['evidence'][0]['quote'] in ' '.join(blocks[r['evidence'][0]['paper']][n]['text'] for n in r['evidence'][0].get('blocks',[r['evidence'][0]['block']]))} for r in samples]
    before=json.loads((ev/'input-hashes.json').read_text())
    now={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.rglob('*.tex'))}
    unchanged=before['tex']==now
    if not unchanged:errors.append('TeX file set or contents changed')
    if len((skill/'SKILL.md').read_text().splitlines())>250:errors.append('SKILL.md exceeds 250 lines')
    for path in skill.rglob('*.md'):
        for target in re.findall(r'\]\(([^)]+)\)',path.read_text()):
            if '://' in target or target.startswith('#'):continue
            if not (path.parent/target.split('#')[0]).exists():errors.append(f'broken link: {path}: {target}')
    return {'passed':not errors,'errors':errors,'rules':len(ann['rules']),'terms':len(ann['terms']),
            'unique_local_quotations_checked':len(unique),'random_seed':20261118,'sampled_rules':sampled,
            'tex_unchanged':unchanged,'tex_files_checked':len(now),'tex_sha256':now,
            'verification_scope':'fresh pdftotext output + curated whitespace/ligature/line-hyphen normalization; not OCR or linguistic proof'}


def scan(path):
    patterns={'unit-spacing':r'(?<![A-Za-z])\d+(?:\.\d+)?(?:nm|GHz|MHz|mW)\b',
      'defensive-candidate':r'\b(?:It should be noted|It is worth noting|may potentially|We believe|in order to)\b',
      'magnitude-needs-context':r'\b(?:significantly|very|greatly|dramatically)\b',
      'term-variant':r'\b(?:bitwidth|data path|MX-FP[468]|DPU)\b'}
    hits=[]
    for lineno,line in enumerate(path.read_text().splitlines(),1):
        line=re.split(r'(?<!\\)%',line)[0]
        for name,pat in patterns.items():
            for m in re.finditer(pat,line,re.I):hits.append({'line':lineno,'kind':name,'match':m.group(),'context':line})
    return {'file':str(path),'mode':'read-only source regex; math/macros/context not semantically parsed','candidates':hits}


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--verify',action='store_true');ap.add_argument('--scan',type=Path)
    ap.add_argument('--root',type=Path,default=Path('.'));ap.add_argument('--corpus',type=Path,default=Path('build/stage-a'))
    args=ap.parse_args();skill=Path(__file__).resolve().parents[1]
    out={}
    if args.verify:out=verify(args.root,skill,args.corpus)
    if args.scan:out['scan']=scan(args.scan)
    print(json.dumps(out,ensure_ascii=False,indent=2))
    if out.get('passed') is False:raise SystemExit(1)
if __name__=='__main__':main()
