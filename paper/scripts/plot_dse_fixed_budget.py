"""One temporary-manuscript figure: deployment and matched-workload gains.

Reads the existing six-scenario results without changing the model or official
manuscript figures. Every candidate keeps one physical count across contexts.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from matplotlib.patches import Patch, Rectangle
import numpy as np

from hardware_cost import full_precision_profiles, load_profiles
from v41_portfolio import write_csv

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'data/evidence/v41_core_20261116'
OUTPUT = ROOT/'data/evidence/dse_fixed_budget_v2_20261116'
FIGURE = ROOT/'figures/temp/dse_fixed_budget_v2.pdf'


def read(name):
    with (SOURCE/(name+'.csv')).open() as stream:
        return list(csv.DictReader(stream))


def main():
    global OUTPUT, FIGURE
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--official',action='store_true',help='Write the promoted official figure and a separate evidence batch')
    args=parser.parse_args()
    if args.official:
        OUTPUT=ROOT/'data/evidence/dse_fixed_budget_main_20261116'
        FIGURE=ROOT/'figures/dse_fixed_budget_v2.pdf'
    manifest = json.loads((SOURCE/'manifest.json').read_text())
    for name in ('metrics','deployments','evaluations','cases'):
        path = SOURCE/(name+'.csv')
        entry = next(e for e in manifest['outputs'] if e['path']==str(path.relative_to(ROOT)))
        assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'], name
    profiles,_ = load_profiles()
    profiles = full_precision_profiles(profiles)
    ratios = [p['ratio'] for p in profiles]
    scenarios = list('ABCDEF') + ['A_to_F']
    metrics = [r for r in read('metrics') if float(r['alpha'])==.3 and float(r['beta'])==1
               and r['utilization']=='ideal' and r['distribution']=='balanced' and r['portfolio'] in scenarios]
    deployments = {r['ratio']:r for r in read('deployments') if float(r['alpha'])==.3 and float(r['beta'])==1}
    evaluations = [r for r in read('evaluations') if float(r['alpha'])==.3 and float(r['beta'])==1 and r['utilization']=='ideal']
    cases = {(r['scenario'],r['context']):r for r in read('cases')}
    cells=[]
    for ratio in ratios:
        for scenario in scenarios:
            r = next(r for r in metrics if r['ratio']==ratio and r['portfolio']==scenario)
            baseline = next(r for r in metrics if r['ratio']=='1:2:4' and r['portfolio']==scenario)
            speedup = float(baseline['mean_seconds'])/float(r['mean_seconds'])
            assert np.isclose(speedup,float(r['speedup_over_baseline']),rtol=1e-12)
            point = {(x['scenario'],x['context']):float(x['seconds']) for x in evaluations if x['ratio']==ratio and (scenario=='A_to_F' or x['scenario']==scenario)}
            base_point = {(x['scenario'],x['context']):float(x['seconds']) for x in evaluations if x['ratio']=='1:2:4' and (scenario=='A_to_F' or x['scenario']==scenario)}
            point_gains = [base_point[k]/point[k] for k in point]
            cells.append(dict(alpha=.3,beta=1,ratio=ratio,scenario=scenario,
                mean_seconds=float(r['mean_seconds']),mean_speedup=speedup,
                min_context_speedup=min(point_gains),max_context_speedup=max(point_gains),
                mean_dp_energy_j=float(r['mean_dp_energy_j']),
                dp_energy_reduction=1-float(r['mean_dp_energy_j'])/float(baseline['mean_dp_energy_j']),
                oracle_worst_regret=float(r['worst_regret'])))
    # The overall column uses the mean of all 66 scenario/context times, not mean speedups.
    for ratio in ratios:
        overall=next(r for r in cells if r['ratio']==ratio and r['scenario']=='A_to_F')
        np.testing.assert_allclose(overall['mean_seconds'],np.mean([r['mean_seconds'] for r in cells
            if r['ratio']==ratio and r['scenario']!='A_to_F']),rtol=1e-12)
    matrix = np.array([[next(r['mean_speedup'] for r in cells if r['ratio']==ratio and r['scenario']==s)
                       for s in scenarios] for ratio in ratios])
    area_cells=[]
    for r in cells:
        d=deployments[r['ratio']]
        scale=int(d['installed_sms'])/int(d['area_limited_sms'])
        area_cells.append(dict(r,mean_seconds=r['mean_seconds']*scale,
            mean_speedup=r['mean_speedup']/scale,min_context_speedup=r['min_context_speedup']/scale,
            max_context_speedup=r['max_context_speedup']/scale))
    # Independently recompute service time from the useful FLOP ledger and area-only capacities.
    for r in evaluations:
        d=deployments[r['ratio']]; case=cases[(r['scenario'],r['context'])]
        scale=int(d['area_limited_sms'])/int(d['installed_sms'])
        direct=sum(float(case[p+'_flops'])/(float(d[m+'_peak_tflops'])*scale*1e12)
                   for p,m in [('h','bf16'),('q','mxfp8_e4m3'),('e','mxfp4_e2m1')])
        assert np.isclose(direct,float(r['seconds'])/scale,rtol=1e-12,atol=1e-15)
    area_matrix=np.array([[next(r['mean_speedup'] for r in area_cells if r['ratio']==ratio and r['scenario']==s)
                           for s in scenarios] for ratio in ratios])
    np.testing.assert_allclose(matrix[0],1,rtol=1e-12)
    for row in cells:
        j=scenarios.index(row['scenario'])
        row['best_mean_time'] = bool(np.isclose(row['mean_speedup'],matrix[:,j].max(),rtol=1e-10))
    for row in area_cells:
        j=scenarios.index(row['scenario'])
        row['best_mean_time']=bool(np.isclose(row['mean_speedup'],area_matrix[:,j].max(),rtol=1e-10))
        row.pop('oracle_worst_regret')
        row['constraint']='area_only'
        row['beta']=None
    hardware=[]
    for profile in profiles:
        d=deployments[profile['ratio']]
        worst=max(profile['modes'],key=lambda m:profile['modes'][m]['power_w'])
        hardware.append(dict(ratio=profile['ratio'],area_sms=int(d['area_limited_sms']),
            installed_sms=int(d['installed_sms']),max_dp_power_mw=float(profile['modes'][worst]['power_w']*1000),
            limiting_mode={'bf16':'H','mxfp8_e4m3':'Q','mxfp4_e2m1':'E'}[worst],
            h_peak_tflops=float(d['bf16_peak_tflops']),q_peak_tflops=float(d['mxfp8_e4m3_peak_tflops']),
            e_peak_tflops=float(d['mxfp4_e2m1_peak_tflops'])))
    plt.rcParams.update({'font.family':'serif','font.serif':['Times New Roman','Liberation Serif'],
                         'font.size':9,'pdf.fonttype':42,'mathtext.fontset':'stix'})
    fig=plt.figure(figsize=(3.49,2.18))
    grid=fig.add_gridspec(1,2,width_ratios=[.95,1.95],left=.145,right=.99,bottom=.25,top=.79,wspace=.10)
    bars=fig.add_subplot(grid[0]);heat=fig.add_subplot(grid[1],sharey=bars)
    y=np.arange(len(ratios))
    bars.barh(y,[r['area_sms'] for r in hardware],height=.68,color='#d5d8dc',edgecolor='#a5abb1',linewidth=.4)
    bars.barh(y,[r['installed_sms'] for r in hardware],height=.48,color='#3c5488')
    for i,r in enumerate(hardware):
        bars.text(r['installed_sms']-.7,i,str(r['installed_sms']),color='white',ha='right',va='center',fontsize=7)
    bars.set(ylim=(len(ratios)-.5,-.5),xlim=(0,39),xlabel='SM count',yticks=y,yticklabels=ratios)
    bars.set_xticks([0,20,40]);bars.set_xlim(0,40)
    bars.set_xlabel('SM count',fontsize=8,labelpad=1)
    bars.tick_params(axis='y',length=0,labelsize=7.5,pad=2)
    bars.tick_params(axis='x',labelsize=7.5,pad=1)
    bars.set_title('(a)',fontsize=9,pad=3)
    fig.legend(handles=[Patch(facecolor='#d5d8dc',label='Area only'),Patch(facecolor='#3c5488',label='Area + power')],
                ncol=2,frameon=False,fontsize=8,loc='upper center',bbox_to_anchor=(.57,1.015),handlelength=.9,columnspacing=1)
    bars.set_axisbelow(True);bars.grid(axis='x',alpha=.12,linewidth=.5)
    norm=TwoSlopeNorm(vmin=.5,vcenter=1,vmax=1.7)
    im=heat.pcolormesh(np.arange(8)-.5,np.arange(10)-.5,matrix,
                       cmap='RdBu',norm=norm,shading='flat',rasterized=False)
    heat.set(xlim=(-.5,6.5),ylim=(8.5,-.5))
    heat.set_title('(b)',fontsize=9,pad=3)
    heat.tick_params(axis='y',left=False,labelleft=False)
    heat.set_xticks(np.arange(7),list('ABCDEF')+['All'],fontsize=8)
    heat.axvline(5.5,color='white',linewidth=1.5)
    heat.tick_params(axis='x',length=0,pad=2)
    for i in range(len(ratios)):
        for j in range(7):
            value=matrix[i,j]
            heat.text(j,i,f'{value:.2f}',ha='center',va='center',fontsize=7.5,
                      color='white' if value<.65 or value>1.5 else '#202020')
            if np.isclose(value,matrix[:,j].max(),rtol=1e-10):
                heat.add_patch(Rectangle((j-.48,i-.48),.96,.96,fill=False,edgecolor='black',linewidth=.8))
            if np.isclose(area_matrix[i,j],area_matrix[:,j].max(),rtol=1e-10):
                heat.add_patch(Rectangle((j-.45,i-.45),.90,.90,fill=False,edgecolor='white',linewidth=1.5))
                heat.add_patch(Rectangle((j-.45,i-.45),.90,.90,fill=False,edgecolor='black',linewidth=.65,linestyle='--'))
    cax=fig.add_axes([.48,.105,.49,.027])
    cb=fig.colorbar(im,cax=cax,orientation='horizontal',ticks=[.5,1,1.5,1.7])
    cb.solids.set_rasterized(False)
    cb.ax.tick_params(labelsize=7.5,pad=1)
    cb.set_label('Compute speedup vs 1:2:4',fontsize=7.5,labelpad=1)
    FIGURE.parent.mkdir(parents=True,exist_ok=True)
    fig.savefig(FIGURE,bbox_inches='tight',pad_inches=.03,metadata={'CreationDate':None,'ModDate':None})
    plt.close(fig)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    write_csv(OUTPUT/'hardware.csv',hardware);write_csv(OUTPUT/'workload_gains.csv',cells)
    write_csv(OUTPUT/'area_only_gains.csv',area_cells)
    portfolio_context=[r for r in read('metrics') if float(r['alpha'])==.3 and float(r['beta']) in (1,1.5)
        and r['utilization']=='ideal' and r['distribution']=='balanced' and r['portfolio'] in ('A_to_E','A_to_F')]
    write_csv(OUTPUT/'portfolio_context.csv',portfolio_context)
    def fp(path):return dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    inputs=[Path(__file__),ROOT/'scripts/hardware_cost.py',ROOT/'scripts/v41_portfolio.py',
            SOURCE/'manifest.json',SOURCE/'metrics.csv',SOURCE/'deployments.csv',SOURCE/'evaluations.csv',SOURCE/'cases.csv',
            ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv',ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json']
    result=dict(status='analytical_uncalibrated',scope=('official manuscript' if args.official else 'temporary manuscript only'),
        parameters=dict(alpha=.3,beta=1,utilization='ideal',contexts=manifest['config']['contexts'],
                        weighting='Equal request probabilities over 11 log-spaced contexts; All additionally weights A-F equally',
                        speedup='Ratio of mean compute times for the same scenario, baseline/candidate',
                        selection='Minimum mean time; solid outlines joint-budget winners, dashed outlines area-only winners',
                        area_only='Same area and per-SM resources; remove power cap and deploy area-limited count'),
        inputs=list(map(fp,inputs)),outputs=list(map(fp,[OUTPUT/'hardware.csv',OUTPUT/'workload_gains.csv',OUTPUT/'area_only_gains.csv',OUTPUT/'portfolio_context.csv',FIGURE])),
        checks=dict(frozen_input_hashes=True,baseline_speedup_one=True,reported_speedup_recomputed=True,
                    area_only_time_checked_against_flop_ledger=True,hardware_rows=9,overall_time_independently_averaged=True,workload_cells=63,area_only_cells=63),
        limitations=['DP-pool power ceiling, not full-chip measured TDP','C–F are precision migration scenarios, not model-quality validation',
                     'Ideal compute service; no new EDA or inference measurement'])
    (OUTPUT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Wrote '+('official' if args.official else 'temporary')+' figure, 9 hardware rows, and 63 matched-workload comparisons (including 9 overall entries).')


if __name__=='__main__': main()
