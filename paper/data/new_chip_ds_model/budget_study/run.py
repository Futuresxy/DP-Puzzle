"""Budget sweep at exact integer-core events and a fixed-length cold-prefill case."""
import csv
from fractions import Fraction as Q
import gzip
import io
from itertools import pairwise
import json
from pathlib import Path
import sys

import numpy as np

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parent))
import evaluate as ev
from hardware_cost import MODES, load_profiles, full_precision_profiles

ALPHA = Q('0.327')
A0, A1 = Q('.25'), Q('.50')
B0, B1 = Q(1), Q(2)
TRACE = 'agent_first'


def write(name, rows):
    ev.write_csv(OUT / name, rows)


def load_work(config):
    root = ev.HERE/'results'
    manifest = json.loads((root/'manifest.json').read_text())
    for name in ['workload.csv','scores.csv']:
        assert ev.digest(root/name) == manifest['outputs'][name]
    path = ev.HERE/'traces/agent_first_histogram.csv'
    counts = ev.histogram(path)
    assert ev.digest(path) == manifest['inputs'][str(path.relative_to(ev.PAPER))]
    n = sum(counts.values())
    assert n == manifest['coverage'][TRACE]['modeled'] == 2047
    stages = [s['id'] for s in config['scenarios']]
    rows = [r for r in ev.csv_rows(root/'workload.csv') if r['trace']==TRACE]
    measured = []
    for s in stages:
        group = [r for r in rows if r['scenario']==s]
        assert sum(int(r['requests']) for r in group)==n
        measured.append([sum(int(r['requests'])*float(r[m+'_mean_flops']) for r in group)/n
                         for m in ev.LETTERS])
    grid = {(r['scenario'],int(r['context'])):[float(r[m+'_flops']) for m in ev.LETTERS]
            for r in ev.csv_rows(ev.EVIDENCE/'cases.csv')}
    # Alternative discretization requested in the length-distribution discussion.
    hist = {k:sum(v for l,v in counts.items() if (k//2 if k>1024 else 0)<l<=k)
            for k in config['contexts']}
    assert sum(hist.values())==n
    upper = [np.average([grid[s,k] for k in hist],axis=0,weights=list(hist.values())) for s in stages]
    write('upper_edge_weights.csv',[dict(upper_tokens=k,requests=v,weight=v/n) for k,v in hist.items()])
    return stages,np.array(measured),np.array(upper),np.array([grid[s,32768] for s in stages])


class Budget:
    def __init__(self, config):
        profiles,metadata = load_profiles()
        profiles = full_precision_profiles(profiles)
        self.ratios = [p['ratio'] for p in profiles]
        self.n0 = config['baseline_cores']
        self.d = config['dp_per_core']
        base = next(p for p in profiles if p['ratio']==ev.BASE)
        self.reference = self.n0 * max(m['power_w'] for m in base['modes'].values())
        self.area = [p['area_um2']/base['area_um2'] for p in profiles]
        source = ev.COST/metadata['source']['local_snapshot']
        assert ev.digest(source)==metadata['source']['sha256']
        static = {(r['top'],r['format']):Q(r['static_mw'])/1000 for r in ev.csv_rows(source)}
        self.idle = [max(static[p['top'],m] for m in MODES) for p in profiles]
        self.on = [[p['modes'][m]['power_w'] for m in MODES] for p in profiles]
        self.per_core = np.array([[float(2*self.d*p['frequency_hz']*p['modes'][m]['native_k']/p['ii'])
                                  for m in MODES] for p in profiles])

    def counts(self, alpha):
        return [self.n0//(1+alpha*(area-1)) for area in self.area]

    def area_events(self):
        edges = {(Q(self.n0,n)-1)/(area-1) for area in self.area if area>1
                 for n in range(1,self.n0+1)}
        return sorted({A0,A1} | {v for v in edges if A0<v<A1})

    def power_steps(self, alpha):
        physical = self.counts(alpha)
        active = np.zeros_like(self.per_core,dtype=int)
        events = {}
        for j,n in enumerate(physical):
            for p,on in enumerate(self.on[j]):
                idle = self.idle[j]
                for k in range(1,n+1):
                    at = (n*idle+k*(on-idle))/self.reference
                    if at<=B0:
                        active[j,p]=k
                    elif at<=B1:
                        events.setdefault(at,[]).append((j,p,k))
        events.setdefault(B1,[])
        assert np.all(active>0)
        yield B0,active.copy()
        for at,changes in sorted(events.items()):
            for j,p,k in changes:
                active[j,p]=k
            yield at,active.copy()


def times(work, rate):
    return work @ (1/rate).T


def winner_ids(t):
    return np.flatnonzero(np.isclose(t,min(t),rtol=1e-12,atol=0))


def merge_intervals(steps):
    result=[]
    for left,right,winners in steps:
        if result and winners==result[-1][2]:
            result[-1]=(result[-1][0],right,winners)
        else:
            result.append((left,right,winners))
    return result


def scan(b,work,upper):
    base=b.ratios.index(ev.BASE)
    area_edges=b.area_events()
    means=np.zeros(len(b.ratios))
    mean_time=np.zeros_like(means)
    wins=np.zeros_like(means)
    approx_wins=np.zeros_like(means)
    region_rows=[]
    bands=[]
    # For increasing alpha, an integer area boundary belongs to its left interval.
    assert b.counts(A0)==b.counts((area_edges[0]+area_edges[1])/2)
    with gzip.GzipFile(OUT/'budget_cells.csv.gz','wb',mtime=0) as gz, io.TextIOWrapper(gz,newline='') as f:
        out=csv.writer(f,lineterminator='\n')
        out.writerow(['alpha_lo','alpha_hi','beta_lo','beta_hi',*b.ratios])
        for al,ah in pairwise(area_edges):
            assert b.counts(ah)==b.counts((al+ah)/2)
            samples=list(b.power_steps(ah))
            runs=[]
            for i,(bl,active) in enumerate(samples):
                bh=samples[i+1][0] if i+1<len(samples) else B1
                rate=active*b.per_core
                t=times(work.mean(axis=0),rate)
                score=t[base]/t
                ids=winner_ids(t)
                approx_ids=winner_ids(times(upper.mean(axis=0),rate))
                frac=float((ah-al)*(bh-bl)/((A1-A0)*(B1-B0)))
                means+=frac*score
                mean_time+=frac*t
                wins[ids]+=frac/len(ids)
                approx_wins[approx_ids]+=frac/len(approx_ids)
                runs.append((bl,bh,tuple(ids)))
                out.writerow([float(al),float(ah),float(bl),float(bh),*score])
            for lo,hi,ids in merge_intervals(runs):
                bands.append((al,ah,lo,hi,ids))
                region_rows.append(dict(alpha_lo=str(al),alpha_hi=str(ah),beta_lo=str(lo),beta_hi=str(hi),
                                        winners='|'.join(b.ratios[j] for j in ids)))
    assert abs(sum(wins)-1)<1e-12 and abs(sum(approx_wins)-1)<1e-12
    write('regions.csv',region_rows)
    write('domain_scores.csv',[dict(ratio=r,mean_speedup=means[j],
                                    ratio_of_mean_times=mean_time[base]/mean_time[j],
                                    winning_budget_fraction=wins[j],
                                    upper_edge_winning_fraction=approx_wins[j])
                               for j,r in enumerate(b.ratios)])
    return bands


def reference(b,work,upper,config):
    samples=list(b.power_steps(ALPHA))
    ref=[];runs=[];approx=[];stage_rows=[]
    for i,(bl,active) in enumerate(samples):
        bh=samples[i+1][0] if i+1<len(samples) else B1
        rate=active*b.per_core
        t=times(work.mean(axis=0),rate)
        score=t[b.ratios.index(ev.BASE)]/t
        stage_time=times(work,rate)
        for scenario,values in zip(config['scenarios'],stage_time):
            order=np.argsort(values)
            j,runner=order[:2]
            stage_rows.append(dict(beta=float(bl),beta_exact=str(bl),scenario=scenario['id'],
                                   winner=b.ratios[j],speedup=values[b.ratios.index(ev.BASE)]/values[j],
                                   runner_up=b.ratios[runner],lead_over_runner=values[runner]/values[j]-1))
        ids=tuple(winner_ids(t))
        runs.append((bl,bh,ids))
        approx.append((bl,bh,tuple(winner_ids(times(upper.mean(axis=0),rate)))))
        ref.append(dict(beta=float(bl), beta_exact=str(bl),best='|'.join(b.ratios[j] for j in ids),
                        **dict(zip(b.ratios,score))))
    for name,seq in [('switches',runs),('switches_upper',approx)]:
        write(name+'.csv',[dict(beta_start=float(l),beta_start_exact=str(l),beta_end=float(h),
                                beta_end_exact=str(h),includes_end=(i==len(merge_intervals(seq))-1),
                                winner='|'.join(b.ratios[j] for j in ids))
                           for i,(l,h,ids) in enumerate(merge_intervals(seq))])
    write('power_slice.csv',ref)
    write('power_slice_scenarios.csv',stage_rows)
    targets=[]
    for target in (1.2,1.3,1.4,1.5,1.6):
        hit=next(row for row in ref if row[row['best']]>=target)
        targets.append(dict(target_speedup=target,beta_min=hit['beta'],beta_exact=hit['beta_exact'],
                            allowance_percent=100*(hit['beta']-1),
                            budget_w=hit['beta']*float(b.reference)*b.d,
                            winner=hit['best'],achieved_speedup=hit[hit['best']]))
    write('power_targets.csv',targets)
    # Compare all nine designs to the independent mode-deployment implementation.
    for a,beta in [(A0,B0),(ALPHA,B0),(ALPHA,Q('1.4')),(A1,B1)]:
        hw,rat,cap=ev.hardware(config|dict(alpha=str(a),beta=str(beta)))
        active=[v for k,v in b.power_steps(a) if k<=beta][-1]
        assert rat==b.ratios and list(dict.fromkeys(r['ratio'] for r in hw))==rat
        np.testing.assert_array_equal(cap,active*b.per_core)
        assert b.counts(a)==[r['physical_cores'] for r in hw[::3]]
    old=[r for r in ev.csv_rows(ev.HERE/'results/scores.csv')
         if r['trace']==TRACE and r['length_method']=='exact' and r['scenario']=='All']
    np.testing.assert_allclose([ref[0][r['ratio']] for r in old],[float(r['speedup']) for r in old])
    return ref,samples[0][1]


def fixed_case(b,active,stages,single):
    t=times(single,active*b.per_core)
    t=np.vstack([t,t.mean(axis=0)])
    scores=t[:,[b.ratios.index(ev.BASE)]]/t
    rows=[]
    for j,r in enumerate(b.ratios):
        for i,s in enumerate(stages+['All']):
            rows.append(dict(ratio=r,scenario=s,seconds=t[i,j],speedup=scores[i,j],
                             rank=1+int(np.sum(t[i]<t[i,j])),physical=b.counts(ALPHA)[j],
                             **dict(zip(('active_BF16','active_MXFP8','active_MXFP4'),active[j]))))
    write('case_32k.csv',rows)
    return scores


def main():
    config=json.loads(ev.CONFIG.read_text())
    stages,work,upper,single=load_work(config)
    b=Budget(config)
    scan(b,work,upper)
    _,active=reference(b,work,upper,config)
    fixed_case(b,active,stages,single)
    inputs=[ev.CONFIG,ev.EVIDENCE/'cases.csv',ev.HERE/'results/manifest.json',
            ev.HERE/'results/workload.csv',ev.HERE/'results/scores.csv',
            ev.HERE/'traces/agent_first_histogram.csv',ev.HERE/'traces/trace_manifest.json',
            ev.COST/'dp11_area_power_fixed_20261116.csv',ev.COST/'dp11_area_power_source_20261112.csv',
            ev.HERE/'evaluate.py',ev.PAPER/'scripts/hardware_cost.py',Path(__file__).resolve()]
    outputs=['budget_cells.csv.gz','domain_scores.csv','regions.csv','power_slice.csv',
             'power_slice_scenarios.csv','power_targets.csv','switches.csv','switches_upper.csv',
             'case_32k.csv','upper_edge_weights.csv']
    manifest=dict(status='analytical_uncalibrated',trace=TRACE,requests=2047,
                  baseline=ev.BASE,alpha=[.25,.50],beta=[1,2],alpha_reference=.327,
                  context_tokens=32768,scenario_weights=dict.fromkeys(stages,1/len(stages)),
                  inputs={str(p.relative_to(ev.PAPER)):ev.digest(p) for p in inputs},
                  outputs={f:ev.digest(OUT/f) for f in outputs})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()
