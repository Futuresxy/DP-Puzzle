"""Five context-aggregated points using the existing equal-request time metric."""
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

from simplex import winner_regions, xy
from plot_v41_ternary_preview import (ROOT, SOURCE, FIGURES, fp, read_verified,
                                      dump_csv, draw_regions, triangle_axes,
                                      region_labels, legends)

OUTPUT=ROOT/'data/evidence/v41_ternary_aggregate_20261117'


def main():
    source=json.loads((SOURCE/'manifest.json').read_text())
    cases=read_verified('cases',source)
    hardware=read_verified('hardware',source)
    gains=read_verified('gains',source)
    capacities=np.array([[float(r[p+'_tflops'])*1e12 for p in 'HQE'] for r in hardware])
    ratios=[r['ratio'] for r in hardware]
    costs=1/capacities
    regions=winner_regions(costs/costs.max())
    points=[]
    for stage in 'ABCDE':
        selected=[r for r in cases if r['scenario']==stage]
        assert len(selected)==11
        work=np.sum([[float(r[p+'_flops']) for p in 'HQE'] for r in selected],axis=0)
        shares=work/work.sum()
        times=costs@work/len(selected)
        scores=times[0]/times
        for j,ratio in enumerate(ratios):
            expected=next(float(r['speedup']) for r in gains if r['scenario']==stage and r['ratio']==ratio)
            np.testing.assert_allclose(scores[j],expected,rtol=1e-12)
        winner=int(np.argmin(times))
        point=dict(scenario=stage,contexts=len(selected),**{p+'_flops_sum':work[i] for i,p in enumerate('HQE')},
                   **{p+'_share':shares[i] for i,p in enumerate('HQE')},winner=ratios[winner],
                   speedup=scores[winner],x=xy([shares])[0,0],y=xy([shares])[0,1])
        points.append(point)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    dump_csv(OUTPUT/'points.csv',points)
    plt.rcParams.update({'font.family':'serif','font.serif':['DejaVu Serif'],'font.size':10,'pdf.fonttype':42})
    fig=plt.figure(figsize=(8,7.6))
    ax=fig.add_axes([.07,.17,.86,.68])
    draw_regions(ax,regions)
    triangle_axes(ax)
    for text in ax.texts:
        if text.get_text().startswith('E:'):
            text.set_position((1.08,-.04))
    region_labels(ax,regions,ratios)
    coords=np.array([[p['x'],p['y']] for p in points])
    ax.plot(*coords.T,color='#202020',lw=1.3,zorder=7)
    for start,end in zip(coords[:-1],coords[1:]):
        ax.annotate('',xy=start+.67*(end-start),xytext=start+.43*(end-start),
                    arrowprops=dict(arrowstyle='->',color='#202020',lw=1.3,mutation_scale=13),zorder=8)
    ax.scatter(*coords.T,s=65,facecolor='white',edgecolor='#151515',linewidth=1.6,zorder=10,clip_on=False)
    positions={'A':(.20,.22),'B':(.65,.23),'C':(.55,-.08),'D':(.76,-.08),'E':(.94,-.14)}
    for point in points:
        ax.annotate(point['scenario'],xy=(point['x'],point['y']),xytext=positions[point['scenario']],
                    ha='center',va='center',fontsize=12,weight='bold',zorder=11,
                    arrowprops=dict(arrowstyle='-',color='#303030',lw=.85),
                    bbox=dict(facecolor='white',edgecolor='none',alpha=.9,pad=1))
    fig.suptitle('DeepSeek-V4.1-Flash: context-aggregated precision migration',fontsize=12.5,y=.98)
    fig.text(.5,.94,r'$\alpha=0.327,\ \beta=1$; minimum modeled GEMM compute time',ha='center',fontsize=10)
    fig.text(.5,.90,'Each point sums GEMM FLOPs across 11 equally weighted contexts (1K–1M).',ha='center',fontsize=9)
    legends(fig,regions,ratios,False)
    fig.text(.5,.018,'A → B → C → D → E: sequential precision migration. Point coordinates are not displaced.',
             ha='center',fontsize=8.5)
    figure=FIGURES/'v41_ternary_aggregate.pdf'
    fig.savefig(figure,metadata={'CreationDate':None,'ModDate':None})
    fig.savefig('/tmp/v41_ternary_aggregate.png',dpi=170)
    plt.close(fig)
    result=dict(status='analytical_uncalibrated',scope='Standalone five-point preview; current complete HQE ledger',
        config=source['config'],aggregation='For each stage, sum F_H/F_Q/F_E over all 11 contexts, then normalize; equal request weights. Not mean per-request fractions.',
        inputs=[fp(p) for p in [Path(__file__),ROOT/'scripts/plot_v41_ternary_preview.py',ROOT/'scripts/simplex.py',
                               SOURCE/'manifest.json',SOURCE/'hardware.csv',SOURCE/'cases.csv',SOURCE/'gains.csv']],
        outputs=[fp(figure),fp(OUTPUT/'points.csv')],checks=dict(points=5,contexts_per_point=11,
            all_45_scenario_design_scores_match_existing_results=True,source_hashes_verified=True),
        notes=['No overall All point is plotted; each point aggregates contexts within one scenario.',
               'Longer contexts contribute more FLOPs under equal request probability.',
               'Current complete HQE ledger and background precision retained; not seven-family-only.',
               'No manuscript, accepted figure or original result modified.'])
    (OUTPUT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['checks'],indent=2))
    for p in points:print(p['scenario'],[round(100*p[f+'_share'],5) for f in 'HQE'],p['winner'])


if __name__=='__main__':main()
