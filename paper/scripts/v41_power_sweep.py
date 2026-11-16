"""Strict power budgets: mode bottlenecks, integer effects and fixed-chip regret.

Continuous deployment is a diagnostic relaxation, never a physical chip result.
The maximum measured mode power constrains one physical count in every mode.
"""
import hashlib
import json
from fractions import Fraction
from pathlib import Path

import numpy as np

import deepseek_v41 as v41
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles
from v41_core import evaluate, map_work, summarize
from v41_portfolio import distribution_weights, write_csv

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT/'data/inputs/v41_power_sweep.json'
OUTPUT = ROOT/'data/evidence/v41_power_sweep_20261116'


def continuous_deploy(rows):
    """Relax both area and power integer floors; preserve per-SM resources."""
    relaxed = []
    for row in rows:
        sm_power = row['max_dp_power_w']/row['installed_sms']
        count = min(row['area_budget_mm2']/row['sm_area_mm2'],
                    row['dp_power_budget_w']/sm_power)
        scale = count/row['installed_sms']
        out = dict(row, installed_sms=count)
        for mode in MODES:
            for suffix in ('_peak_tflops', '_dp_power_w'):
                out[mode+suffix] = row[mode+suffix]*scale
        relaxed.append(out)
    return relaxed


def e_crossover(first_capacity, second_capacity, residual_h=0.):
    """E fraction where two times match, holding H:Q within residual fixed."""
    delta = 1/np.asarray(first_capacity)-1/np.asarray(second_capacity)
    residual = residual_h*delta[0]+(1-residual_h)*delta[1]
    return residual/(residual-delta[2])


def arrays(rows):
    return tuple(np.array([[r[m+suffix] for m in MODES] for r in rows])
                 for suffix in ('_peak_tflops', '_dp_power_w'))


def metric_rows(times, energies, cases, portfolios, ratios, distribution, metadata):
    result = []
    for name, members in portfolios.items():
        indices = [i for i, c in enumerate(cases) if c['scenario'] in members]
        weights = distribution_weights([cases[i]['context'] for i in indices], distribution)
        report = summarize(times[indices], energies[indices] if energies is not None else None, weights)
        for j, ratio in enumerate(ratios):
            worst = cases[indices[report['worst_case'][j]]]
            result.append(dict(metadata, portfolio=name, distribution=distribution, ratio=ratio,
                **{k: None if v is None else bool(v[j]) if v.dtype==bool else float(v[j])
                   for k, v in report.items() if k!='worst_case'},
                worst_scenario=worst['scenario'], worst_context=worst['context']))
    return result


def main():
    config = json.loads(CONFIG.read_text())
    core_path = ROOT/config['core_config']
    core = json.loads(core_path.read_text())
    profiles, source = load_profiles()
    profiles = full_precision_profiles(profiles)
    ratios = [p['ratio'] for p in profiles]
    start, stop, step = (Fraction(config[k]) for k in ('beta_start','beta_stop','beta_step'))
    betas = [start+i*step for i in range(int((stop-start)/step)+1)]
    betas = sorted(set(betas+[Fraction(b) for b in config['extra_betas']]))
    checkpoints = set(map(Fraction, config['checkpoints']))
    sensitivity_betas = set(map(Fraction, config['sensitivity_betas']))
    portfolios = {s['id']:[s['id']] for s in core['scenarios']} | core['portfolios']
    cases, work, routed = [], [], []
    for scenario in core['scenarios']:
        for context in core['contexts']:
            f, r, _, _, _ = map_work(v41.prefill_work(context, batch=core['batch']), scenario)
            cases.append(dict(scenario=scenario['id'], context=context))
            work.append(f); routed.append(r)
    work, routed = np.array(work), np.array(routed)
    ideal = dict(q=1., e=1.)
    selections, details, sensitivity, deployments, breakdown, dominance = [], [], [], [], [], []
    total_evaluations = 0
    for alpha in config['alphas']:
        previous = {}
        for beta in betas:
            rows = deploy(profiles, alpha, beta, core['baseline_sms'], core['dp_per_sm'])
            relaxed = continuous_deploy(rows)
            for integer, continuous in zip(rows, relaxed):
                deployments.append(dict(integer, continuous_sms=continuous['installed_sms'],
                    **{m+'_continuous_tflops': continuous[m+'_peak_tflops'] for m in MODES}))
            for model, deployment in [('integer', rows), ('continuous', relaxed)]:
                capacity, power = arrays(deployment)
                times, energies = evaluate(work, routed, capacity, power, ideal)
                total_evaluations += times.size
                if model in previous:
                    assert np.all(times <= previous[model]*(1+1e-12)), 'Increasing budget must not increase time'
                previous[model] = times
                metadata = dict(alpha=float(alpha), beta=float(beta), deployment=model, utilization='ideal')
                report = metric_rows(times, energies, cases, portfolios, ratios, 'balanced', metadata)
                selections.extend(r for r in report if r['minimax'])
                if beta in checkpoints:
                    details.extend(report)
                if model=='integer' and alpha==config['report_alpha'] and beta==Fraction(config['report_beta']):
                    for i, case in enumerate(cases):
                        for j, ratio in enumerate(ratios):
                            service = work[i]/capacity[j]/1e12
                            breakdown.append(dict(case, ratio=ratio, alpha=float(alpha), beta=float(beta),
                                **{p+'_flop_fraction':work[i,k]/sum(work[i]) for k,p in enumerate('HQE')},
                                **{p+'_seconds':service[k] for k,p in enumerate('HQE')},
                                **{p+'_time_fraction':service[k]/sum(service) for k,p in enumerate('HQE')},
                                seconds=sum(service), slowdown=times[i,j]/min(times[i])))
                    for j, ratio in enumerate(ratios):
                        for k, other in enumerate(ratios):
                            if j!=k and np.all(capacity[k]>=capacity[j]*(1-1e-12)) and np.any(capacity[k]>capacity[j]*(1+1e-12)):
                                dominance.append(dict(alpha=float(alpha), beta=float(beta),
                                    dominated=ratio, dominator=other, scope='compute_capacity_only'))
                if model=='integer' and alpha==config['report_alpha'] and beta in sensitivity_betas:
                    for utilization in core['utilization_cases']:
                        t,e = evaluate(work, routed, capacity, power, utilization)
                        total_evaluations += t.size
                        for distribution in core['distributions']:
                            sensitivity.extend(metric_rows(t,e,cases,portfolios,ratios,distribution,
                                dict(metadata,utilization=utilization['id'])))
    # Diagnostic power-only limit: capacity is proportional to K / max(mode power).
    limits = []
    power_capacity = []
    for profile in profiles:
        pmax = max(m['power_w'] for m in profile['modes'].values())
        power_capacity.append([float(profile['modes'][m]['native_k']/pmax) for m in MODES])
        row = dict(ratio=profile['ratio'], max_mode_power_mw=float(pmax*1000),
                   limiting_mode=max(profile['modes'],key=lambda m:profile['modes'][m]['power_w']))
        for mode in MODES:
            info = profile['modes'][mode]
            row[mode+'_power_mw'] = float(info['power_w']*1000)
            row[mode+'_power_only_budget_utilization'] = float(info['power_w']/pmax)
            row[mode+'_power_only_tflops_per_w'] = float(2*profile['frequency_hz']*info['native_k']/profile['ii']/pmax/10**12)
        for alpha in config['alphas']:
            d = next(r for r in deployments if r['alpha']==float(alpha) and r['beta']==1 and r['ratio']==profile['ratio'])
            row['alpha_'+alpha+'_integer_beta_full'] = d['beta_for_area_full_deployment']
            sm_power = d['max_dp_power_w']/d['installed_sms']
            row['alpha_'+alpha+'_continuous_beta_full'] = d['area_budget_mm2']/d['sm_area_mm2']*sm_power/d['dp_power_reference_w']
        limits.append(row)
    thresholds = []
    d = deploy(profiles,config['report_alpha'],config['report_beta'],core['baseline_sms'],core['dp_per_sm'])
    physical_capacity,_ = arrays(d)
    for first,second in [('1:2:8','1:2:16'),('1:2:12','1:2:16')]:
        i,j = ratios.index(first),ratios.index(second)
        for model,cap in [('integer_beta1',physical_capacity),('continuous_power_only',power_capacity)]:
            for h in [0.,1.]:
                thresholds.append(dict(first=first,second=second,deployment=model,residual_h_fraction=h,
                    crossover_e_fraction=e_crossover(cap[i],cap[j],h)))
    datasets = dict(selections=selections,checkpoints=details,sensitivity=sensitivity,deployments=deployments,
                    service_breakdown=breakdown,capacity_dominance=dominance,limits=limits,pairwise_thresholds=thresholds)
    OUTPUT.mkdir(parents=True,exist_ok=True)
    for name,data in datasets.items(): write_csv(OUTPUT/(name+'.csv'),data)
    figures = render(config,ratios,deployments,selections,breakdown)
    def fingerprint(path):
        return dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    inputs = [CONFIG,core_path,Path(__file__),ROOT/'scripts/v41_core.py',ROOT/'scripts/v41_portfolio.py',
              ROOT/'scripts/hardware_cost.py',ROOT/'scripts/deepseek_v41.py',v41.SOURCE_DIR/'inference/config.json',
              ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv',ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json']
    manifest = dict(status='analytical_uncalibrated',config=config,core_config=core,source_metadata=source,
        inputs=list(map(fingerprint,inputs)),outputs=[fingerprint(OUTPUT/(name+'.csv')) for name in datasets]+list(map(fingerprint,figures)),
        counts={name:len(data) for name,data in datasets.items()},case_design_evaluations=total_evaluations,
        checks={'absolute_time_monotone_with_budget':True},
        assumptions=['Same measured three-mode maximum power deployment rule as core analysis',
                     'Budget scan changes physical chip design; no runtime power throttling',
                     'Continuous counts diagnose integer rounding and are not buildable chips',
                     'Uniform log-context weighting for main scan; distribution/utilization sensitivity at declared checkpoints',
                     'Beta below one shrinks baseline too; all speedups use same-budget baseline',
                     'No new hardware, quality, batch-utilization or peripheral-power measurements'])
    (OUTPUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(dict(manifest['counts'],case_design_evaluations=total_evaluations),indent=2))


def render(config,ratios,deployments,selections,breakdown):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.family':'serif','font.serif':['Times New Roman','Liberation Serif'],
                         'font.size':9,'pdf.fonttype':42,'mathtext.fontset':'stix'})
    colors=dict(zip(ratios,['#3c5488','#b88a20','#008b70','#8064a2','#c44e52','#7a6a43','#367fa0','#91614b','#d05c9b']))
    fig,axes=plt.subplots(1,3,figsize=(7.16,2.7))
    fig.subplots_adjust(left=.075,right=.99,bottom=.30,top=.88,wspace=.42)
    for ratio,marker in zip(['1:2:8','1:4:8','1:2:12','1:2:16','1:8:16'],['^','D','<','X','>']):
        rows=[r for r in deployments if r['alpha']==float(config['report_alpha']) and r['beta']<=1.5 and r['ratio']==ratio]
        axes[0].plot([r['beta'] for r in rows],[r['mxfp4_e2m1_peak_tflops'] for r in rows],
                     color=colors[ratio],label=ratio,marker=marker,markevery=20,markersize=3,linewidth=1)
    axes[0].set(xlabel=r'Power budget $\beta$',ylabel='FP4 peak (TFLOP/s)',title='(a) Installed capacity',xlim=(.5,1.5))
    axes[0].legend(fontsize=7,ncol=2,loc='upper left',frameon=False,handlelength=1.2,columnspacing=.6)
    bars=['1:2:8','1:2:12','1:2:16','1:8:16']
    rows=[next(r for r in breakdown if r['scenario']=='F' and r['context']==1024 and r['ratio']==ratio) for ratio in bars]
    reference=rows[1]['seconds'];base=np.zeros(len(rows))
    for p,color in zip('HQE',['#6996c2','#e2ab55','#83b7a0']):
        heights=np.array([r[p+'_seconds']/reference for r in rows])
        axes[1].bar(range(len(rows)),heights,bottom=base,label=p,color=color,width=.65)
        base+=heights
    axes[1].axhline(1,linewidth=.6,linestyle='--',color='gray')
    axes[1].set_xticks(range(len(rows)),bars,rotation=40,ha='right',fontsize=8)
    axes[1].set(ylabel='Time / 1:2:12 time',title='(b) F, 1K, '+r'$\beta=1$',ylim=(0,1.85))
    axes[1].legend(fontsize=8,ncol=3,frameon=False,handlelength=.8,columnspacing=.7,loc='upper left')
    for portfolio,color in [('A_to_E','#3c5488'),('A_to_F','#b85637')]:
        for model,style in [('integer','-'),('continuous','--')]:
            rows=[r for r in selections if r['alpha']==float(config['report_alpha']) and r['beta']<=1.5
                  and r['portfolio']==portfolio and r['deployment']==model]
            axes[2].plot([r['beta'] for r in rows],[r['worst_regret']*100 for r in rows],
                color=color,linestyle=style,linewidth=1,label=portfolio.replace('_to_','–')+' '+('int.' if model=='integer' else 'cont.'))
    axes[2].set(xlabel=r'Power budget $\beta$',ylabel='Best worst regret (%)',title='(c) Fixed-chip coverage',xlim=(.5,1.5),ylim=(0,60))
    axes[2].legend(fontsize=7,loc='upper left',frameon=False,handlelength=1.5)
    for ax in axes:ax.grid(axis='y',alpha=.15,linewidth=.5);ax.tick_params(labelsize=8)
    path=ROOT/'figures/v41_strict_power.pdf'
    fig.savefig(path,bbox_inches='tight',pad_inches=.03,metadata={'CreationDate':None,'ModDate':None})
    plt.close(fig)
    return [path]


if __name__=='__main__': main()
