"""Exact joint-budget H/Q/E regions and 25 existing five-stage workloads.

Read-only with respect to manuscript and accepted model outputs. Edge details
use explicit H/E percentage coordinates with independent axis scales; no jitter.
"""
import csv
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import numpy as np

from simplex import HEIGHT, winner_regions, workload_grid, xy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'data/evidence/v41_five_stage_20261117'
OUTPUT = ROOT/'data/evidence/v41_ternary_preview_20261117'
FIGURES = ROOT/'figures/temp'
CONTEXTS = [1024, 8192, 65536, 262144, 1048576]
CONTEXT_LABELS = ['1K', '8K', '64K', '256K', '1M']
CONTEXT_COLORS = ['#0072b2', '#d58900', '#009e73', '#b853a0', '#202020']
MARKERS = dict(A='o', B='s', C='^', D='D', E='P')
REGION_COLORS = ['#dce6f1', '#f7dec0', '#c5e3d3', '#e6d2e8', '#f3d4d3',
                 '#d2c9e9', '#ffe59c', '#eeeeee', '#f7f7f7']


def fp(path):
    return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def read_verified(name, manifest):
    path = SOURCE/(name+'.csv')
    assert fp(path) in manifest['outputs'], name
    with path.open() as stream:
        return list(csv.DictReader(stream))


def dump_csv(path, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def draw_regions(ax, regions, detail=False):
    for r in regions:
        if r['fraction'] <= 1e-10:
            continue
        vertices = np.asarray(r['vertices_hqe'])
        coords = vertices[:, [2, 0]]*100 if detail else xy(vertices)
        ax.fill(*coords.T, facecolor=REGION_COLORS[r['index']],
                edgecolor='#80858a', lw=.7, zorder=1)


def triangle_axes(ax):
    for family in range(3):
        other = [i for i in range(3) if i != family]
        for value in [.2, .4, .6, .8]:
            ends = np.zeros((2, 3))
            ends[:, family] = value
            ends[0, other[0]] = 1-value
            ends[1, other[1]] = 1-value
            ax.plot(*xy(ends).T, color='#8a9299', lw=.5, alpha=.4, zorder=2)
    border = xy([[1,0,0], [0,1,0], [0,0,1], [1,0,0]])
    ax.plot(*border.T, color='#343d46', lw=1, zorder=3)
    for value in [.2, .4, .6, .8]:
        ax.text(value/2-.033, HEIGHT*value+.008, str(round(value*100)),
                ha='right', va='center', fontsize=8, color='#5f6770')
        ax.text(1-value, -.025, str(round(value*100)), ha='center', va='top', fontsize=8, color='#5f6770')
        ax.text(.5+.5*value+.028, HEIGHT*(1-value), str(round(value*100)),
                ha='left', va='center', fontsize=8, color='#5f6770')
    ax.text(.5, HEIGHT+.045, 'H: BF16 (100%)', ha='center', fontsize=11, weight='bold')
    ax.text(-.015, -.075, 'Q: FP8 (100%)', ha='center', fontsize=10, weight='bold')
    ax.text(1.035, -.075, 'E: FP4 (100%)', ha='center', fontsize=10, weight='bold')
    ax.set(xlim=(-.14, 1.21), ylim=(-.15, 1.0))
    ax.set_aspect('equal')
    ax.axis('off')


def region_labels(ax, regions, ratios):
    positions = {0:(.48,.53), 1:(.65,.29), 2:(.80,.12),
                 3:(.28,-.10), 4:(-.025,.18), 5:(1.06,.22), 6:(1.11,.12)}
    for r in regions:
        if r['fraction'] <= 1e-10:
            continue
        i = r['index']
        center = xy(r['vertices_hqe']).mean(axis=0)
        if i < 3:
            ax.text(*positions[i], ratios[i], ha='center', va='center', fontsize=11,
                    weight='bold', color='#33434a', zorder=4)
        else:
            ax.annotate(ratios[i], xy=center, xytext=positions[i],
                        ha='center', va='center', fontsize=9, weight='bold', color='#33434a',
                        arrowprops=dict(arrowstyle='-', color='#56616a', lw=.7), zorder=5,
                        bbox=dict(facecolor='white', edgecolor='none', alpha=.75, pad=1))


def draw_points(ax, points):
    for c, color in zip(CONTEXTS, CONTEXT_COLORS):
        rows = [next(p for p in points if p['context']==c and p['scenario']==s) for s in MARKERS]
        coords = np.array([[p['x'],p['y']] for p in rows])
        ax.plot(*coords.T, color=color, lw=.9, ls=(0,(3,2)), alpha=.7, zorder=6)
        for start, end in zip(coords[:-1], coords[1:]):
            a, b = start+.42*(end-start), start+.64*(end-start)
            ax.annotate('', xy=b, xytext=a, arrowprops=dict(arrowstyle='->', color=color,
                        lw=.9, mutation_scale=8), zorder=7)
        for p in rows:
            ax.scatter(p['x'],p['y'],s=45,marker=MARKERS[p['scenario']],facecolor=color,
                       edgecolor='white',linewidth=.55,zorder=9,clip_on=False)
    labels = {'A':(.13,.23), 'B':(.60,.23), 'C':(.48,-.065), 'D':(.79,-.065), 'E':(.88,-.14)}
    for s, position in labels.items():
        selected = [p for p in points if p['scenario']==s]
        center = np.mean([[p['x'],p['y']] for p in selected], axis=0)
        ax.annotate(s, xy=center, xytext=position, fontsize=10, weight='bold', ha='center',
                    arrowprops=dict(arrowstyle='-', color='#343434', lw=.7),zorder=11,
                    bbox=dict(facecolor='white', edgecolor='none', alpha=.85, pad=1))


def edge_detail(ax, scenario, points, regions, coefficients, ratios):
    draw_regions(ax, regions, detail=True)
    rows = [next(p for p in points if p['scenario']==scenario and p['context']==c) for c in CONTEXTS]
    coords = np.array([[100*p['E_share'],100*p['H_share']] for p in rows])
    # Independent scales expose real near-edge coordinates without displacing any point.
    ax.plot(*coords.T, color='#656565', lw=.9, alpha=.8, zorder=5)
    offsets = [(10, -18), (-8, 13), (-7, -13), (10, 9), (8, 7)]
    for p, color, label, delta in zip(rows, CONTEXT_COLORS, CONTEXT_LABELS, offsets):
        pos = [100*p['E_share'],100*p['H_share']]
        ax.scatter(*pos, marker=MARKERS[scenario], color=color, s=43, edgecolors='white',
                   linewidth=.6,zorder=7)
        ax.annotate(label, xy=pos, xytext=delta, textcoords='offset points',fontsize=8,
                    ha='right' if delta[0]<0 else 'left', va='center',color=color,zorder=8)
    xpad = max(.3, np.ptp(coords[:,0])*.12)
    xmin, xmax = coords[:,0].min()-xpad, coords[:,0].max()+xpad
    ax.set(xlim=(xmin,xmax),ylim=(.023,.043),ylabel='H share (%)',xlabel='E share (%)')
    ax.set_title(f'{scenario}: near-edge detail',fontsize=10,loc='left',pad=4)
    ax.tick_params(labelsize=8)
    ax.grid(alpha=.2,linewidth=.4)
    # Label the actual winning intervals at this panel's vertical midpoint.
    h=.00041
    samples=np.linspace(xmin,xmax,500)
    winners=np.argmin(np.column_stack([np.full(500,h),1-h-samples/100,samples/100])@coefficients.T,axis=1)
    for j in np.unique(winners):
        loc=samples[winners==j].mean()
        ax.text(loc,.0412,ratios[j],ha='center',va='center',fontsize=9,weight='bold',color='#33434a',zorder=9)


def legends(fig, regions, ratios, points):
    handles=[Patch(facecolor=REGION_COLORS[r['index']],edgecolor='#80858a',
                   label=ratios[r['index']]+(' (no region)' if r['fraction']<=1e-10 else '')) for r in regions]
    fig.legend(handles=handles,ncol=5,frameon=False,fontsize=9,loc='lower center',
               bbox_to_anchor=(.5,.035),columnspacing=1.3,handlelength=1.2)
    if points:
        handles=[Line2D([],[],color=c,marker='o',ls='--',ms=5,label=t)
                 for c,t in zip(CONTEXT_COLORS,CONTEXT_LABELS)]
        fig.legend(handles=handles,ncol=5,frameon=False,fontsize=9,loc='upper center',
                   bbox_to_anchor=(.5,.94),columnspacing=1.3,handlelength=2)


def main():
    manifest=json.loads((SOURCE/'manifest.json').read_text())
    hardware=read_verified('hardware',manifest)
    cases=read_verified('cases',manifest)
    evaluations=read_verified('evaluations',manifest)
    ratios=[r['ratio'] for r in hardware]
    capacity=np.array([[float(r[p+'_tflops']) for p in 'HQE'] for r in hardware])
    coefficients=1/capacity
    # Common normalization keeps geometric clipping well away from absolute tolerances.
    coefficients/=coefficients.max()
    regions=winner_regions(coefficients)
    assert abs(sum(r['fraction'] for r in regions)-1)<1e-10
    for region in regions:
        if region['fraction']>1e-10:
            center=np.mean(region['vertices_hqe'],axis=0)
            assert np.argmin(coefficients@center)==region['index']
    points=[]
    for s in MARKERS:
        for c in CONTEXTS:
            row=next(r for r in cases if r['scenario']==s and int(r['context'])==c)
            share=np.array([float(row[p+'_share']) for p in 'HQE'])
            assert np.isclose(share.sum(),1)
            times=coefficients@share
            winner=int(np.argmin(times))
            direct=min((r for r in evaluations if r['scenario']==s and int(r['context'])==c),
                       key=lambda r:float(r['seconds']))
            assert direct['ratio']==ratios[winner]
            point=dict(scenario=s,context=c,**{p+'_share':share[i] for i,p in enumerate('HQE')},
                       winner=ratios[winner],speedup=times[0]/times[winner],
                       x=float(xy([share])[0,0]),y=float(xy([share])[0,1]))
            points.append(point)
    assert len(points)==25
    # Independent dense-grid check of polygon winner against all nine linear costs.
    from matplotlib.path import Path as PolygonPath
    grid=workload_grid(180)
    wins=np.argmin(grid@coefficients.T,axis=1)
    strict=0
    for r in regions:
        if r['fraction']<=1e-10:continue
        inside=PolygonPath(np.array(r['vertices_hqe'])[:,:2]).contains_points(grid[:,:2],radius=-1e-9)
        assert np.all(wins[inside]==r['index'])
        strict+=int(inside.sum())
    OUTPUT.mkdir(parents=True,exist_ok=True)
    dump_csv(OUTPUT/'points.csv',points)
    (OUTPUT/'regions.json').write_text(json.dumps([dict(r,ratio=ratios[r['index']]) for r in regions],indent=2)+'\n')
    dump_csv(OUTPUT/'region_summary.csv',[dict(ratio=ratios[r['index']],geometric_fraction=r['fraction'],
         positive_area=r['fraction']>1e-10,**{p+'_tflops':capacity[r['index'],i] for i,p in enumerate('HQE')}) for r in regions])
    plt.rcParams.update({'font.family':'serif','font.serif':['DejaVu Serif'],'font.size':10,'pdf.fonttype':42})
    outputs=[]
    for name,with_points,with_detail in [('regions',False,False),('points',True,False),('detail',True,True)]:
        fig=plt.figure(figsize=(12.5,8.2) if with_detail else (8,7.6))
        if with_detail:
            ax=fig.add_axes([.02,.19,.62,.64])
        else:
            ax=fig.add_axes([.07,.17,.86,.68])
        draw_regions(ax,regions)
        triangle_axes(ax)
        region_labels(ax,regions,ratios)
        if with_points:draw_points(ax,points)
        if with_detail:
            for i,s in enumerate('CDE'):
                detail=fig.add_axes([.71,.685-i*.24,.255,.16])
                edge_detail(detail,s,points,regions,coefficients,ratios)
            fig.text(.71,.87,'Expanded H axis; Q = 100% - H - E',fontsize=9)
        title='Joint-budget H/Q/E advantage regions'
        if with_points:title='DeepSeek-V4.1-Flash: five contexts and five migration stages'
        fig.suptitle(title,fontsize=13,y=.985)
        fig.text(.5,.95,r'$\alpha=0.327,\ \beta=1$; minimum modeled GEMM compute time',ha='center',fontsize=10)
        legends(fig,regions,ratios,with_points)
        footer='H/Q/E are FLOP fractions. Nine candidates evaluated; region area is not workload probability.'
        if with_points:footer='Colors: context length. Shapes: A circle, B square, C triangle, D diamond, E plus. Arrows: A to E.'
        fig.text(.5,.018,footer,ha='center',fontsize=8.5)
        path=FIGURES/f'v41_ternary_{name}.pdf'
        fig.savefig(path,metadata={'CreationDate':None,'ModDate':None})
        fig.savefig('/tmp/v41_ternary_'+name+'.png',dpi=170)
        outputs.append(path)
        plt.close(fig)
    result=dict(status='analytical_uncalibrated',scope='Preview only; current full HQE ledger, not the proposed seven-family subset',
       config=manifest['config'],display_contexts=CONTEXTS,
       objective='min_j (x_H/C_jH + x_Q/C_jQ + x_E/C_jE); x_H+x_Q+x_E=1',
       inputs=[fp(p) for p in [Path(__file__),ROOT/'scripts/simplex.py',SOURCE/'manifest.json',
               SOURCE/'hardware.csv',SOURCE/'cases.csv',SOURCE/'evaluations.csv']],
       outputs=[fp(p) for p in outputs+[OUTPUT/'points.csv',OUTPUT/'regions.json',OUTPUT/'region_summary.csv']],
       checks=dict(source_hashes_verified=True,points_match_existing_evaluations=True,point_count=25,
                   region_area_sum_one=True,region_centroid_winners_checked=True,strict_grid_points_checked=strict,
                   grid_points=len(grid),positive_area_regions=int(sum(r['fraction']>1e-10 for r in regions))),
       notes=['FP32 is excluded as in the current case study; no new utilization or power assumptions.',
              '1:6:12 has no winning region; 1:8:16 can only tie 1:4:8 along part of H=0, with no exclusive area.',
              'Near-edge panels expand H independently and show exact unjittered coordinates.',
              'All manuscripts and accepted figures remain unchanged.'])
    (OUTPUT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['checks'],indent=2))
    for s in MARKERS:
        print(s, [(p['context'],p['winner']) for p in points if p['scenario']==s])


if __name__=='__main__':
    main()
