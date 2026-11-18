"""Render DAC figures from frozen study CSVs. See captions.tex for LaTeX use."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys
import tempfile

import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parents[3]/'dp-puzzle_dac2027/scripts'))
from figure_style import COLUMN_WIDTH, TEXT_WIDTH, configure

COLORS={'1:4:8':'#cb852e','1:6:12':'#8465a7','1:8:16':'#267569'}
MODE_MARKERS=[('active_BF16','o','#284f76'),('active_MXFP8','s','#c47314'),
              ('active_MXFP4','^','#713e8a')]
META={'CreationDate':None,'ModDate':None}


def read(data,manifest,name):
    path=data/name
    if hashlib.sha256(path.read_bytes()).hexdigest()!=manifest['outputs'][name]:
        raise ValueError(f'Frozen result changed: {path}')
    with path.open(newline='') as f:
        return list(csv.DictReader(f))


def budget(data,out,width,manifest):
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch,Rectangle
    bins_manifest=json.loads((data/'bands_manifest.json').read_text())
    for name in ('power_slice.csv','budget_cells.csv.gz'):
        if manifest['outputs'][name]!=bins_manifest['inputs'][name]:
            raise ValueError('Band and fine-scan data are from different runs')
    bands=read(data,bins_manifest,'budget_bands.csv')
    curve=[r for r in bands if r['scope']=='reference']
    fig,(ax,detail)=plt.subplots(2,1,figsize=(width,4.35))
    fig.subplots_adjust(left=.17,right=.94,top=.94,bottom=.18,hspace=.73)
    for row in bands:
        if row['scope']=='map' and row['coverage_winner']=='1':
            al,ah,lo,hi=(float(row[k]) for k in ('alpha_lo','alpha_hi','beta_lo','beta_hi'))
            ax.add_patch(Rectangle((al,lo),ah-al,hi-lo,facecolor=COLORS[row['ratio']],
                                   edgecolor='none', antialiased=False))
    ax.axvline(.327,ls='--',color='#232323',lw=.7)
    ax.set(xlim=(.25,.50),ylim=(1,2),xlabel=r'$\alpha$',ylabel=r'$\beta$',title='(a)',
           xticks=np.arange(.25,.51,.05),yticks=[1,1.5,2])
    ax.xaxis.set_major_formatter('{x:.2f}')
    ax.yaxis.set_major_formatter('{x:.1f}')
    for r,color in COLORS.items():
        series=[row for row in curve if row['ratio']==r]
        edges=[float(row['beta_lo']) for row in series]+[float(series[-1]['beta_hi'])]
        mean=[float(row['band_speedup']) for row in series]
        detail.stairs(mean,edges,baseline=None,color=color,lw=.85)
        for row,v in zip(series,mean):
            if row['coverage_winner']=='1':
                detail.plot([float(row['beta_lo']),float(row['beta_hi'])],[v,v],
                            color=color,lw=2.4,solid_capstyle='butt')
    detail.set(xlim=(1,2),xlabel=r'$\beta$',ylabel='GEMM speedup',title='(b)')
    detail.xaxis.set_major_formatter('{x:.1f}')
    detail.yaxis.set_major_formatter('{x:.1f}')
    detail.grid(axis='y',color='.88',lw=.4)
    fig.legend(handles=[Patch(facecolor=c,label=r) for r,c in COLORS.items()],
               loc='lower center',ncol=3,frameon=False,handlelength=1,columnspacing=1.1)
    fig.savefig(out/'budget_sweep.pdf',metadata=META)
    plt.close(fig)


def heatmap(data,out,width,manifest):
    import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    from matplotlib.patches import Rectangle
    rows=read(data,manifest,'case_32k.csv')
    ratios=list(dict.fromkeys(r['ratio'] for r in rows))
    stages=list(dict.fromkeys(r['scenario'] for r in rows))
    lookup={(r['ratio'],r['scenario']):r for r in rows}
    first=[lookup[r,stages[0]] for r in ratios]
    fig,(left,right)=plt.subplots(1,2,figsize=(width,2.62),sharey=True,
                                 gridspec_kw={'width_ratios':[1,2.06]})
    fig.subplots_adjust(left=.143,right=.986,top=.885,bottom=.24,wspace=.08)
    y=np.arange(len(ratios))
    left.barh(y,[int(r['physical']) for r in first],height=.84,color='#dadee2',
              edgecolor='#9ca5ad',lw=.4)
    for i,(field,marker,color) in enumerate(MODE_MARKERS):
        left.scatter([int(r[field]) for r in first],y+(i-1)*.24,s=10,marker=marker,color=color,zorder=3)
    left.set(ylim=(len(ratios)-.5,-.5),xlim=(0,39),xlabel='Core count',title='(a)',xticks=[0,20,36])
    left.set_yticks(y,ratios)
    left.tick_params(length=2,pad=2)
    matrix=np.array([[float(lookup[r,s]['speedup']) for s in stages] for r in ratios])
    bounds=np.floor(matrix.min()*10)/10,np.ceil(matrix.max()*10)/10
    norm=TwoSlopeNorm(vmin=bounds[0],vcenter=1,vmax=bounds[1])
    image=right.pcolormesh(np.arange(len(stages)+1)-.5,np.arange(len(ratios)+1)-.5,matrix,
                           shading='flat',cmap='RdBu',norm=norm,antialiased=False)
    right.set(xlim=(-.5,len(stages)-.5),title='(b)')
    right.set_xticks(range(len(stages)),stages)
    right.tick_params(axis='y',left=False,labelleft=False)
    right.tick_params(axis='x',length=0,pad=2)
    right.axvline(len(stages)-1.5,color='white',lw=.9)
    for j,r in enumerate(ratios):
        for i,s in enumerate(stages):
            v=matrix[j,i]
            right.text(i,j,f'{v:.2f}',ha='center',va='center',
                       color='white' if norm(v)<.16 or norm(v)>.84 else '#222222')
            if int(lookup[r,s]['rank'])==1:
                right.add_patch(Rectangle((i-.48,j-.46),.96,.92,fill=False,edgecolor='black',lw=.65))
    box=right.get_position()
    cax=fig.add_axes([box.x0,.098,box.width,.025])
    bar=fig.colorbar(image,cax=cax,orientation='horizontal',ticks=[bounds[0],1,bounds[1]])
    bar.solids.set_rasterized(False)
    bar.ax.xaxis.set_major_formatter('{x:.1f}')
    bar.ax.tick_params(length=2,pad=1)
    bar.ax.get_xticklabels()[0].set_ha('left')
    bar.ax.get_xticklabels()[-1].set_ha('right')
    fig.savefig(out/'case_32k.pdf',metadata=META)
    plt.close(fig)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',type=Path,default=HERE)
    parser.add_argument('--output',type=Path,default=HERE)
    parser.add_argument('--width',choices=['column','text'],default='column')
    parser.add_argument('--figure',choices=['budget','case','both'],default='both')
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    configure(Path(tempfile.gettempdir())/'dp-puzzle-dac2027-mpl')
    manifest=json.loads((args.data/'manifest.json').read_text())
    width=COLUMN_WIDTH if args.width=='column' else TEXT_WIDTH
    if args.figure in ('both','budget'):
        budget(args.data,args.output,width,manifest)
    if args.figure in ('both','case'):
        heatmap(args.data,args.output,width,manifest)


if __name__=='__main__':
    main()
