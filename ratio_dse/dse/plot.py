"""Render both DAC panels directly from the regenerated CSV tables."""
import argparse
import csv
import json
from pathlib import Path
import tempfile

import numpy as np

from figure_style import COLUMN_WIDTH, TEXT_WIDTH, configure

COLORS={'1:4:8':'#cb852e','1:6:12':'#8465a7','1:8:16':'#267569'}
MODE_MARKERS=[('active_BF16','o','#284f76'),('active_MXFP8','s','#c47314'),
              ('active_MXFP4','^','#713e8a')]
META={'CreationDate':None,'ModDate':None}


def read(data, name):
    with (data/name).open(newline='') as stream:
        return list(csv.DictReader(stream))


def budget(data,out,width,alpha):
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch,Rectangle
    bands = [r for r in read(data,'budget_bands.csv') if r['scope']=='map']
    reference = read(data,'reference_bands.csv')
    order = list(dict.fromkeys(r['ratio'] for r in bands))
    winners = {r['ratio'] for r in bands if r['coverage_winner']=='1'}
    winners.update(r['coverage_winner'] for r in reference)
    labels = [r for r in COLORS if r in winners] + [r for r in order if r in winners and r not in COLORS]
    palette = {r:COLORS.get(r,plt.get_cmap('tab20')(i%20)) for i,r in enumerate(labels)}
    fig,(ax,detail)=plt.subplots(1,2,sharey=True,figsize=(width,3.0),
                                  gridspec_kw={'width_ratios':[1,1.1]})
    fig.subplots_adjust(left=.15,right=.988,top=.91,bottom=.24,wspace=.13)
    painted = set()
    for row in bands:
        cell = (row['alpha_lo'],row['beta_lo'])
        if row['coverage_winner']=='1' and cell not in painted:
            painted.add(cell)
            al,ah,lo,hi=(float(row[k]) for k in ('alpha_lo','alpha_hi','beta_lo','beta_hi'))
            ax.add_patch(Rectangle((al,lo),ah-al,hi-lo,facecolor=palette[row['ratio']],
                                   edgecolor='white',lw=.16))
    ax.axvline(alpha,ls='--',color='#232323',lw=.8)
    xlo = min(float(r['alpha_lo']) for r in bands)
    xhi = max(float(r['alpha_hi']) for r in bands)
    yedges = [float(r['beta_lo']) for r in reference]+[float(reference[-1]['beta_hi'])]
    ax.set(xlim=(xlo,xhi),ylim=(yedges[0],yedges[-1]),xlabel=r'$\alpha$',ylabel=r'$\beta$',title='(a)')
    if (xlo,xhi)==(.25,.50):
        ax.set_xticks([.25,.35,.50])
    if len(yedges)<=12:
        ax.set_yticks(yedges)
    if len(yedges)>1 and min(np.diff(yedges))>=.099999:
        ax.yaxis.set_major_formatter('{x:.1f}')
    ax.tick_params(pad=2,length=2)
    detail.tick_params(axis='y',left=False)
    for row in reference:
        lo,hi=(float(row[k]) for k in ('beta_lo','beta_hi'))
        low,mean,high=(float(row[k]) for k in ('winner_min_speedup','winner_band_speedup','winner_max_speedup'))
        y=(lo+hi)/2
        color=palette[row['coverage_winner']]
        detail.axhspan(lo,hi,facecolor=color,alpha=.19,edgecolor='none')
        detail.plot([low,high],[y,y],color=color,lw=1.4,solid_capstyle='butt')
        detail.scatter([mean],[y],s=12,color=color,edgecolors='#272727',linewidths=.35,zorder=3)
        detail.annotate(f'{mean:.2f}',(high,y),xytext=(3,0),textcoords='offset points',va='center')
    detail.set(xlabel='GEMM speedup',title='(b)')
    lows=[float(r['winner_min_speedup']) for r in reference]
    highs=[float(r['winner_max_speedup']) for r in reference]
    if min(lows)>=1.10 and max(highs)<=1.65:
        detail.set(xlim=(1.10,1.84),xticks=[1.2,1.4,1.6])
    else:
        span=max(.1,max(highs)-min(lows))
        detail.set_xlim(min(lows)-.1*span,max(highs)+.45*span)
    detail.xaxis.set_major_formatter('{x:.1f}')
    detail.tick_params(axis='x',pad=2,length=2)
    fig.legend(handles=[Patch(facecolor=c,label=r) for r,c in palette.items()],
               loc='lower center',ncol=3,frameon=False,handlelength=1,columnspacing=1.1)
    fig.savefig(out/'budget_sweep.pdf',metadata=META)
    plt.close(fig)


def heatmap(rows, output_pdf, width):
    import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    from matplotlib.patches import Rectangle
    ratios=list(dict.fromkeys(r['ratio'] for r in rows))
    stages=list(dict.fromkeys(r['scenario'] for r in rows))
    lookup={(r['ratio'],r['scenario']):r for r in rows}
    first=[lookup[r,stages[0]] for r in ratios]
    width=max(width,width*len(stages)/6)
    fig,(left,right)=plt.subplots(1,2,figsize=(width,max(2.86,.27*len(ratios)+.43)),sharey=True,
                                 gridspec_kw={'width_ratios':[1,2.06]})
    fig.subplots_adjust(left=.143,right=.986,top=.89,bottom=.285,wspace=.08)
    y=np.arange(len(ratios))
    left.barh(y,[int(r['physical']) for r in first],height=.84,color='#dadee2',
              edgecolor='#9ca5ad',lw=.4,label='Physical cores')
    for i,(field,marker,color) in enumerate(MODE_MARKERS):
        left.scatter([int(r[field]) for r in first],y+(i-1)*.24,s=10,marker=marker,color=color,zorder=3,
                     label=field.removeprefix('active_'))
    left.set(ylim=(len(ratios)-.5,-.5),xlim=(0,39),xlabel='Core count',title='(a)',xticks=[0,20,36])
    max_cores=max(int(r['physical']) for r in first)
    if max_cores!=36:
        left.set_xlim(0,max(1,max_cores*1.1))
        left.set_xticks(sorted({0,max_cores//2,max_cores}))
    left.set_yticks(y,ratios)
    left.tick_params(length=2,pad=2)
    matrix=np.array([[float(lookup[r,s]['speedup']) for s in stages] for r in ratios])
    bounds=min(.9,np.floor(matrix.min()*10)/10),max(1.1,np.ceil(matrix.max()*10)/10)
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
    handles, labels = left.get_legend_handles_labels()
    entries = dict(zip(labels, handles))
    legend_labels = ['Physical cores', *[field.removeprefix('active_') for field, _, _ in MODE_MARKERS]]
    fig.legend([entries[label] for label in legend_labels], legend_labels, loc='lower center',
               ncol=4, frameon=False, handlelength=.85, handletextpad=.25, columnspacing=.65)
    box=right.get_position()
    cax=fig.add_axes([box.x0,.17,box.width,.022])
    bar=fig.colorbar(image,cax=cax,orientation='horizontal',ticks=[bounds[0],1,bounds[1]])
    bar.solids.set_rasterized(False)
    bar.ax.xaxis.set_major_formatter('{x:.1f}')
    bar.ax.tick_params(length=2,pad=1)
    bar.ax.get_xticklabels()[0].set_ha('left')
    bar.ax.get_xticklabels()[-1].set_ha('right')
    fig.savefig(output_pdf,metadata=META)
    plt.close(fig)


def render(data,alpha,out=None,width=COLUMN_WIDTH):
    out = data if out is None else out
    out.mkdir(parents=True,exist_ok=True)
    configure(Path(tempfile.gettempdir())/'dp-puzzle-dac2027-mpl')
    budget(data,out,width,float(alpha))
    heatmap(read(data,'fixed_scores.csv'),out/'five_scenarios_compare.pdf',width)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data',type=Path,help='Completed run directory')
    parser.add_argument('--output',type=Path,required=True,help='Figure destination')
    parser.add_argument('--width',choices=['column','text'],default='column')
    args=parser.parse_args()
    manifest=json.loads((args.data/'manifest.json').read_text())
    render(args.data,manifest['config']['alpha'],args.output,
           COLUMN_WIDTH if args.width=='column' else TEXT_WIDTH)
