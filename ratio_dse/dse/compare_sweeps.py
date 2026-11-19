"""Compare observed-length and upper-edge sweeps on identical hardware, traces and budgets."""
import argparse
import csv
import json
from pathlib import Path
import tempfile

import numpy as np

from figure_style import configure, TEXT_WIDTH
from plot import COLORS, META
from run import digest, save


def load(directory, method):
    manifest = json.loads((directory/'manifest.json').read_text())
    if manifest['config']['sweep_lengths'] != method:
        raise ValueError(f'Expected {method} sweep in {directory}')
    tables = {}
    for name in ('budget_bands','budget_cells','reference_bands'):
        p = directory/(name+'.csv')
        if digest(p) != manifest['outputs'][p.name]:
            raise ValueError(f'Changed output: {p}')
        with p.open(newline='') as f:
            tables[name] = list(csv.DictReader(f))
    settings = {k:v for k,v in manifest['config'].items()
                if k not in ('fixed_lengths','sweep_lengths',*manifest['input_files'])}
    return tables, (settings,{k:v['sha256'] for k,v in manifest['input_files'].items()})


def compare(first, second):
    def winners(rows):
        grouped = {}
        for r in rows:
            if r['scope']=='map' and int(r['coverage_winner']):
                key = tuple(float(r[k]) for k in ('alpha_lo','alpha_hi','beta_lo','beta_hi'))
                grouped.setdefault(key,[]).append(r)
        return grouped
    a,b = [winners(t['budget_bands']) for t in (first,second)]
    if a.keys()!=b.keys():
        raise ValueError('Different budget grids')
    cells = []
    for bounds, obs in a.items():
        edge = b[bounds]
        left,right = ['|'.join(r['ratio'] for r in entries) for entries in (obs,edge)]
        cells.append(dict(zip(('alpha_lo','alpha_hi','beta_lo','beta_hi'),bounds)) |
                     dict(observed=left,upper_edge=right,changed=int(left!=right),
                          observed_speedup=float(obs[0]['band_speedup']),
                          upper_edge_speedup=float(edge[0]['band_speedup'])))
    bands = []
    for r,s in zip(first['reference_bands'],second['reference_bands'],strict=True):
        bands.append(dict(beta_lo=float(r['beta_lo']),beta_hi=float(r['beta_hi']),
                          observed=r['coverage_winner'],upper_edge=s['coverage_winner'],
                          observed_speedup=float(r['winner_band_speedup']),
                          upper_edge_speedup=float(s['winner_band_speedup'])))
    fine = []
    for r,s in zip((x for x in first['budget_cells'] if x['scope']=='reference'),
                   (x for x in second['budget_cells'] if x['scope']=='reference'),strict=True):
        if (r['beta_lo'],r['beta_hi'])!=(s['beta_lo'],s['beta_hi']):
            raise ValueError('Different exact activation boundaries')
        ratios = [k for k in r if k not in ('scope','alpha_lo','alpha_hi','beta_lo','beta_hi')]
        labels = []
        for row in (r,s):
            values = np.array([float(row[k]) for k in ratios])
            labels.append('|'.join(k for k,v in zip(ratios,values) if np.isclose(v,values.max(),rtol=1e-12,atol=0)))
        if fine and [fine[-1]['observed'],fine[-1]['upper_edge']]==labels:
            fine[-1]['beta_hi'] = float(r['beta_hi'])
        else:
            fine.append(dict(beta_lo=float(r['beta_lo']),beta_hi=float(r['beta_hi']),
                             observed=labels[0],upper_edge=labels[1]))
    return cells,bands,fine


def draw(cells,bands,alpha,out):
    configure(Path(tempfile.gettempdir())/'dp-puzzle-dac2027-mpl')
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch,Rectangle
    fig,axes=plt.subplots(1,3,sharey=True,figsize=(TEXT_WIDTH,2.9),
                          gridspec_kw={'width_ratios':[1,1,1.22]})
    fig.subplots_adjust(left=.075,right=.99,bottom=.22,top=.89,wspace=.14)
    labels=list(dict.fromkeys(r[k].split('|')[0] for r in cells for k in ('observed','upper_edge')))
    colors={r:COLORS.get(r,plt.get_cmap('tab20')(i%20)) for i,r in enumerate(labels)}
    for ax,key,panel in zip(axes[:2],('observed','upper_edge'),('(a)','(b)')):
        for r in cells:
            label=r[key].split('|')[0]
            ax.add_patch(Rectangle((r['alpha_lo'],r['beta_lo']),r['alpha_hi']-r['alpha_lo'],
                                   r['beta_hi']-r['beta_lo'],facecolor=colors[label],
                                   edgecolor='#222222' if r['changed'] else 'white',
                                   lw=.85 if r['changed'] else .15,zorder=2 if r['changed'] else 1))
        ax.set(xlim=(min(r['alpha_lo'] for r in cells),max(r['alpha_hi'] for r in cells)),
               title=panel,xlabel=r'$\alpha$')
        ax.axvline(alpha,color='black',ls='--',lw=.7)
    axes[0].set(ylabel=r'$\beta$',ylim=(bands[0]['beta_lo'],bands[-1]['beta_hi']))
    series=[('observed_speedup','o','Observed'),('upper_edge_speedup','s','Upper edge')]
    for field,marker,label in series:
        axes[2].plot([r[field] for r in bands],[(r['beta_hi']+r['beta_lo'])/2 for r in bands],
                     marker=marker,ms=3,mfc='white',lw=1,label=label)
    axes[2].set(title='(c)',xlabel='GEMM speedup')
    axes[2].legend(loc='upper left',frameon=False,handlelength=1)
    handles=[Patch(facecolor=c,label=r) for r,c in colors.items()]
    handles.append(Patch(facecolor='white',edgecolor='black',label='Changed winner'))
    fig.legend(handles=handles,loc='lower center',ncol=min(5,len(handles)),frameon=False)
    fig.savefig(out,metadata=META)
    plt.close(fig)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('observed',type=Path)
    p.add_argument('upper_edge',type=Path)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    first,settings=load(a.observed,'observed')
    second,other=load(a.upper_edge,'upper_edge')
    if settings!=other:
        raise ValueError('Inputs or study parameters differ between runs')
    cells,bands,fine=compare(first,second)
    a.output.mkdir(parents=True,exist_ok=True)
    save(a.output/'grid_comparison.csv',cells)
    save(a.output/'slice_comparison.csv',bands)
    save(a.output/'slice_intervals.csv',fine)
    draw(cells,bands,float(settings[0]['alpha']),a.output/'sweep_comparison.pdf')
    print(f"{sum(r['changed'] for r in cells)} / {len(cells)} budget cells changed winner")
