import csv,json,hashlib
from collections import defaultdict
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
src=root/'data/evidence/v41_five_stage_20261117'
def read(n):
 with (src/(n+'.csv')).open() as f:return list(csv.DictReader(f))
hardware=read('hardware');cases=read('cases');ops=read('operators')
fixed={'q_down','swa_kv','index.q_projection','global_kv.projection','index.k_projection','index.head_weights','engram.projection'}
background=defaultdict(lambda:defaultdict(float)); totals=defaultdict(float)
for r in ops:
 c=int(r['context']);p=r['precision'];f=float(r['flops'])
 if p!='FP32':
  totals[c]+=f
  if r['kernel'] in fixed:background[c][(r['kernel'],p)]+=f
print('SHARES of modeled BF16/FP8/FP4 FLOPs (excluding FP32)')
for c in [1024,32768,131072,1048576]:
 print(c, 'total background',100*sum(background[c].values())/totals[c], {k+':'+p:round(100*f/totals[c],5) for (k,p),f in background[c].items()})
print('ALL CONTEXT weighted-by-FLOPs',100*sum(sum(v.values()) for v in background.values())/sum(totals.values()))
prec=['BF16','FP8','FP4'];cap=[[float(h[p+'_tflops'])*1e12 for p in 'HQE'] for h in hardware]
variants=['current','listed_extra','all_extra']
listed={'q_down','swa_kv','index.q_projection','global_kv.projection'}
results={}; detailed=[]
for variant in variants:
 times=[]; bgtimes=[]
 for r in cases:
  c=int(r['context']);s=r['scenario'];work=[float(r[p+'_flops']) for p in 'HQE'];bg=[0.,0.,0.]
  for (k,p),f in background[c].items():
   old=prec.index(p);new=old
   if variant!='current' and (variant=='all_extra' or k in listed):
    if p=='BF16' and s in 'CD':new=1
    if s=='E' or p=='FP8' and s=='D':new=2
   work[old]-=f;work[new]+=f;bg[new]+=f
  assert all(w>=0 for w in work)
  assert abs(sum(work)-totals[c]) <= 1e-12*totals[c]
  t=[sum(w/a for w,a in zip(work,cp)) for cp in cap]
  bt=[sum(w/a for w,a in zip(bg,cp)) for cp in cap]
  times.append(t);bgtimes.append(bt)
  detailed.extend(dict(variant=variant,scenario=s,context=c,ratio=h['ratio'],seconds=t[j],background_seconds=bt[j]) for j,h in enumerate(hardware))
 results[variant]={}
 for s in list('ABCDE')+['All']:
  ids=[i for i,r in enumerate(cases) if s=='All' or r['scenario']==s]
  sums=[sum(times[i][j] for i in ids) for j in range(9)]
  bg=[sum(bgtimes[i][j] for i in ids) for j in range(9)]
  scores=[sums[0]/v for v in sums]
  best=max(range(9),key=lambda j:scores[j])
  results[variant][s]={'best':hardware[best]['ratio'],'scores':{h['ratio']:scores[j] for j,h in enumerate(hardware)},'time_128':sums[2]/len(ids),'background_time_share_128':bg[2]/sums[2],'background_time_share_124':bg[0]/sums[0]}
  print(variant,s,'best',hardware[best]['ratio'],'128',scores[2],'1212',scores[5],'1216',scores[6],'bgtime128%',100*bg[2]/sums[2],'bgtime124%',100*bg[0]/sums[0])
for v in variants[1:]:
 print(v, '128 MEAN TIME reduction',100*(1-results[v]['All']['time_128']/results['current']['All']['time_128']), 'E reduction',100*(1-results[v]['E']['time_128']/results['current']['E']['time_128']))
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')

with (out/'operator_shares.csv').open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=['context','kernel','precision','flops','modeled_flops','fraction'],lineterminator='\n')
 writer.writeheader()
 for c,rows in background.items():
  for (k,p),value in rows.items():writer.writerow(dict(context=c,kernel=k,precision=p,flops=value,modeled_flops=totals[c],fraction=value/totals[c]))
# Reproduce current scores and preserve workload in every modified case.
reference=read('gains')
for r in reference:
 assert abs(results['current'][r['scenario']]['scores'][r['ratio']]-float(r['speedup']))<1e-12
assert all(abs(sum(float(r[p+'_flops']) for p in 'HQE')-totals[int(r['context'])])<1 for r in cases)
source_manifest=json.loads((src/'manifest.json').read_text())
inputs=[src/(n+'.csv') for n in ['hardware','cases','operators','gains']]
for path in inputs:
 expected=next(r['sha256'] for r in source_manifest['outputs'] if r['path']==str(path.relative_to(root)))
 assert hashlib.sha256(path.read_bytes()).hexdigest()==expected
def fingerprint(path):return dict(path=str(path.relative_to(root)),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
manifest=dict(status='analytical_uncalibrated',inputs=[fingerprint(p) for p in inputs+[Path(__file__)]],outputs=[fingerprint(out/n) for n in ['results.json','operator_shares.csv']],checks=dict(current_scores_reproduced=True,source_hashes_verified=True),scope='Background precision migration sensitivity; no EDA or quantization accuracy experiment. Official and temporary manuscript results unchanged.')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
