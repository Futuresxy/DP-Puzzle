"""Render the separate DSE audit; never overwrite manuscript figures."""
import argparse
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.patches import Patch


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,required=True)
    args=parser.parse_args()
    z=np.load(args.directory/'data/score_grid.npz')
    grid,scores=z['grid'],z['scores']
    ratios=list(z['ratios']);groups=[tuple(x) for x in z['groups']]
    alpha=np.unique(grid[:,0]);beta=np.unique(grid[:,1])
    gi=groups.index(('balanced','A_to_F'))
    winners=scores[:,0,gi,:].argmax(axis=1).reshape(len(alpha),len(beta))
    used=sorted(np.unique(winners))
    compact=np.zeros_like(winners)
    for i,j in enumerate(used):compact[winners==j]=i
    colors=['#3C5488','#D99A29','#238B80','#9266A4','#D05B58']
    plt.rcParams.update({'font.family':'serif','font.serif':['DejaVu Serif'],
                         'font.size':9,'pdf.fonttype':42,'mathtext.fontset':'dejavuserif'})
    fig,axes=plt.subplots(1,2,figsize=(8.0,3.5),gridspec_kw={'width_ratios':[1.25,1]})
    axes[0].pcolormesh(beta,alpha,compact,shading='nearest',cmap=ListedColormap(colors[:len(used)]),
                       norm=BoundaryNorm(np.arange(len(used)+1)-.5,len(used)),rasterized=False)
    axes[0].axvline(2.1,color='white',linestyle='--',linewidth=1)
    axes[0].set(xlabel=r'DP power budget multiplier $\beta$',ylabel=r'Baseline tensor area fraction $\alpha$',
                title='(a) Fixed-design selection: A–F',xlim=(1,2.4),ylim=(.2,.4))
    axes[0].set_xticks([1,1.2,1.4,1.6,1.8,2.1,2.4])
    axes[0].set_yticks([.2,.25,.3,.35,.4])
    axes[0].legend(handles=[Patch(color=colors[i],label=ratios[j]) for i,j in enumerate(used)],
                   loc='upper center',bbox_to_anchor=(.5,-.23),ncol=3,frameon=False,fontsize=8)
    mask=grid[:,1]==1;j=ratios.index('1:2:8')
    for portfolio,color,label in [('A_to_F','#3C5488','A–F'),('A_to_E','#238B80','A–E (exclude F)')]:
        gi=[groups.index((d,portfolio)) for d in ('balanced','short','long')]
        values=scores[mask,0,:,:][:,gi,j]
        axes[1].fill_between(alpha,values.min(axis=1),values.max(axis=1),color=color,alpha=.16)
        axes[1].plot(alpha,values[:,0],color=color,label=label,linewidth=1.8)
    axes[1].axhline(1,color='gray',linewidth=.7,linestyle='--')
    axes[1].set(xlabel=r'Baseline tensor area fraction $\alpha$',ylabel='Modeled compute speedup vs 1:2:4',
                title=r'(b) 1:2:8 at $\beta=1$',xlim=(.2,.4),ylim=(.99,1.18))
    axes[1].set_xticks([.2,.25,.3,.35,.4])
    axes[1].grid(axis='y',alpha=.2)
    axes[1].legend(frameon=False,loc='lower left',fontsize=8)
    axes[1].text(.5,-.26,'Lines: equal request weights\nBands: short/equal/long request weights',
                 ha='center',va='top',transform=axes[1].transAxes,fontsize=8)
    fig.subplots_adjust(left=.075,right=.985,top=.88,bottom=.28,wspace=.32)
    fig.savefig(args.directory/'dse_sensitivity.pdf',metadata={'CreationDate':None,'ModDate':None})
    fig.savefig(args.directory/'dse_sensitivity.png',dpi=180)
    plt.close(fig)


if __name__=='__main__':main()
