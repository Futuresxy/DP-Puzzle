"""Read-only manuscript audit; write a separate reproducible DSE review batch."""
import argparse
import csv
import hashlib
import json
from fractions import Fraction
from pathlib import Path

import numpy as np

import deepseek_v41 as model
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles
from v41_core import family, map_work
from v41_portfolio import distribution_weights

ROOT = Path(__file__).resolve().parents[1]


def write_csv(path, rows):
    with path.open('w') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    config = json.loads((ROOT/'data/inputs/v41_core.json').read_text())
    profiles, _ = load_profiles()
    profiles = full_precision_profiles(profiles)
    ratios = [p['ratio'] for p in profiles]
    scenarios = config['scenarios']
    contexts = config['contexts']
    ledgers = {length: model.prefill_work(length, batch=1) for length in contexts}
    cases, works, operator_rows = [], [], []
    for length, ledger in ledgers.items():
        for row in model.aggregate(ledger, ('segment', 'kernel', 'precision')):
            operator_rows.append(dict(context=length, family=family(row['kernel']) or 'background', **row))
    for scenario in scenarios:
        for length, ledger in ledgers.items():
            work, _, excluded, core, index = map_work(ledger, scenario)
            works.append(work)
            cases.append(dict(scenario=scenario['id'], context=length,
                              h_flops=work[0], q_flops=work[1], e_flops=work[2],
                              excluded_fp32_flops=excluded,
                              migration_target_fraction=core/(work.sum()+excluded),
                              index_fraction=index/(work.sum()+excluded),
                              **{f'x_{p}':work[i]/work.sum() for i,p in enumerate('HQE')}))
    works = np.array(works)
    old_cases = list(csv.DictReader((ROOT/'data/evidence/v41_core_20261116/cases.csv').open()))
    assert len(cases) == len(old_cases) == 66
    for new, old in zip(cases, old_cases):
        assert new['scenario'] == old['scenario'] and new['context'] == int(old['context'])
        for key in ('h_flops', 'q_flops', 'e_flops', 'excluded_fp32_flops'):
            assert new[key] == float(old[key])
    write_csv(out/'workload_cases.csv', cases)
    write_csv(out/'operator_work.csv', operator_rows)
    portfolios = {s['id']:[s['id']] for s in scenarios} | {
        'A_to_F':list('ABCDEF'), 'A_to_E':list('ABCDE'), 'A_B':list('AB')}
    distributions = ['balanced', 'short', 'long']
    weights, groups = [], []
    for dist in distributions:
        local = distribution_weights(contexts, dist)
        for name, ids in portfolios.items():
            w = np.array([local[contexts.index(c['context'])] if c['scenario'] in ids else 0 for c in cases])
            w /= w.sum()
            groups.append((dist, name))
            weights.append(w)
    weights = np.array(weights)
    alphas = [Fraction(i,100) for i in range(20,41)]
    betas = [Fraction(i,100) for i in range(100,241)]
    grid, hardware, winner_rows, selected, saturation = [], [], [], [], []
    all_scores = []
    checkpoints_a = {Fraction(1,5), Fraction(3,10), Fraction(2,5)}
    checkpoints_b = {Fraction(v,100) for v in (100,110,125,150,210,240)}
    fig5_rows = []
    baseline_times = None
    for alpha in alphas:
        reference = deploy(profiles, alpha, 1)
        for row in reference:
            saturation.append(dict(alpha=float(alpha), ratio=row['ratio'],
                                   area_sms=int(row['area_limited_sms']),
                                   beta_saturation=row['beta_for_area_full_deployment']))
        for beta in betas:
            deployments = deploy(profiles, alpha, beta)
            grid.append((float(alpha),float(beta)))
            capacity = np.array([[r[m+'_peak_tflops']*1e12 for m in MODES] for r in deployments])
            times = works @ (1/capacity).T
            np.testing.assert_allclose(times[:,0], works@np.array([1/(2e9*256*36*k) for k in (16,32,64)]), rtol=1e-13)
            baseline_times = times[:,0]
            relative = times / times[:,0,None]
            slowdown = times / times.min(axis=1,keepdims=True)
            mean_times = weights @ times
            mean_speedup = mean_times[:,0,None] / mean_times
            normalized_speedup = 1/(weights @ relative)
            geometric_speedup = np.exp(-weights @ np.log(relative))
            regrets = np.array([slowdown[w>0].max(axis=0)-1 for w in weights])
            all_scores.append(np.stack([mean_speedup,normalized_speedup,geometric_speedup,regrets]))
            for j, row in enumerate(deployments):
                hardware.append(dict(alpha=float(alpha),beta=float(beta),ratio=row['ratio'],
                    area_sms=int(row['area_limited_sms']),power_sms=int(row['power_limited_sms']),
                    deployed_sms=int(row['installed_sms']),constraint=row['binding_constraint'],
                    area_budget_mm2=row['area_budget_mm2'],dp_power_budget_w=row['dp_power_budget_w'],
                    **{p+'_tflops':capacity[j,k]/1e12 for k,p in enumerate('HQE')}))
                # Independent reduced-form count check, using exact rational arithmetic.
                aj=profiles[j]['area_um2']/profiles[0]['area_um2']
                rho=max(x['power_w'] for x in profiles[j]['modes'].values())/max(x['power_w'] for x in profiles[0]['modes'].values())
                assert int(row['installed_sms']) == min(36//(1+alpha*(aj-1)),36*beta//rho)
            for gi,(dist,portfolio) in enumerate(groups):
                if portfolio in ('A_to_F','A_to_E','A_B'):
                    best=int(mean_speedup[gi].argmax()); robust=int(regrets[gi].argmin())
                    winner_rows.append(dict(alpha=float(alpha),beta=float(beta),distribution=dist,portfolio=portfolio,
                        mean_winner=ratios[best],mean_speedup=mean_speedup[gi,best],
                        normalized_winner=ratios[int(normalized_speedup[gi].argmax())],
                        geometric_winner=ratios[int(geometric_speedup[gi].argmax())],
                        minimax_winner=ratios[robust],minimax_regret=regrets[gi,robust],
                        mean_winner_regret=regrets[gi,best]))
                if alpha in checkpoints_a and beta in checkpoints_b:
                    for j,ratio in enumerate(ratios):
                        selected.append(dict(alpha=float(alpha),beta=float(beta),distribution=dist,portfolio=portfolio,
                            ratio=ratio,cores=int(deployments[j]['installed_sms']),mean_seconds=mean_times[gi,j],
                            speedup=mean_speedup[gi,j],normalized_speedup=normalized_speedup[gi,j],
                            geometric_speedup=geometric_speedup[gi,j],worst_regret=regrets[gi,j],
                            best_mean=bool(np.isclose(mean_speedup[gi,j],mean_speedup[gi].max(),rtol=1e-12))))
            if alpha==Fraction(3,10) and beta==1:
                saved=list(csv.DictReader((ROOT/'data/evidence/dse_fixed_budget_main_20261116/workload_gains.csv').open()))
                for old in saved:
                    gi=groups.index(('balanced',old['scenario']));j=ratios.index(old['ratio'])
                    np.testing.assert_allclose(mean_speedup[gi,j],float(old['mean_speedup']),rtol=1e-12)
                for i,c in enumerate(cases):
                    for j,ratio in enumerate(ratios):
                        fig5_rows.append(dict(**c,ratio=ratio,cores=int(deployments[j]['installed_sms']),
                            h_seconds=works[i,0]/capacity[j,0],q_seconds=works[i,1]/capacity[j,1],
                            e_seconds=works[i,2]/capacity[j,2],seconds=times[i,j],
                            speedup=times[i,0]/times[i,j],oracle_regret=slowdown[i,j]-1))
    write_csv(out/'hardware_grid.csv',hardware)
    write_csv(out/'budget_winners.csv',winner_rows)
    write_csv(out/'selected_metrics.csv',selected)
    write_csv(out/'beta_saturation.csv',saturation)
    write_csv(out/'figure5_reproduction.csv',fig5_rows)
    # Explicitly expose how equal request probabilities weight relative performance.
    contribution=[]
    for gi,(dist,name) in enumerate(groups):
        weights_effective=weights[gi]*baseline_times
        weights_effective/=weights_effective.sum()
        for i,c in enumerate(cases):
            if weights[gi,i]>0:
                contribution.append(dict(distribution=dist,portfolio=name,scenario=c['scenario'],context=c['context'],
                    request_weight=weights[gi,i],effective_weight_in_mean_time_ratio=weights_effective[i]))
    write_csv(out/'effective_weights.csv',contribution)
    np.savez_compressed(out/'score_grid.npz',grid=np.array(grid),scores=np.array(all_scores),
                        ratios=ratios,groups=np.array(groups),metrics=['mean_speedup','normalized_speedup','geometric_speedup','worst_regret'])
    # Alternative sensitivity: keep the alpha=.3 absolute area and DP-power budgets fixed.
    fixed=[]
    for alpha in sorted(checkpoints_a):
        for beta in sorted(checkpoints_b):
            rows=deploy(profiles,alpha,beta)
            counts=[]
            a0=profiles[0]['area_um2'];ab=36*256*a0/Fraction(3,10)
            for p,row in zip(profiles,rows):
                ao=256*a0*(1/alpha-1)
                counts.append(min(int(ab//(ao+256*p['area_um2'])),int(row['power_limited_sms'])))
            cap=np.array([[2e9*256*counts[j]*p['modes'][m]['native_k'] for m in MODES] for j,p in enumerate(profiles)])
            times=works@(1/cap).T;mean=weights[groups.index(('balanced','A_to_F'))]@times
            for j,ratio in enumerate(ratios):
                fixed.append(dict(alpha=float(alpha),beta=float(beta),ratio=ratio,cores=counts[j],
                    mean_seconds=mean[j],speedup=mean[0]/mean[j],best=bool(np.isclose(mean[j],mean.min(),rtol=1e-12))))
    write_csv(out/'fixed_absolute_budget_check.csv',fixed)
    inputs=[Path(__file__),ROOT/'scripts/hardware_cost.py',ROOT/'scripts/deepseek_v41.py',ROOT/'scripts/v41_core.py',
            ROOT/'scripts/v41_portfolio.py',ROOT/'data/inputs/v41_core.json',
            ROOT/'data/evidence/v41_core_20261116/cases.csv',
            ROOT/'data/evidence/dse_fixed_budget_main_20261116/workload_gains.csv',
            ROOT/'data/inputs/models/DeepSeek-V4.1-Flash/inference/config.json',
            ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv',
            ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json']
    fingerprint=lambda p:dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    manifest=dict(status='analytical_uncalibrated',parameters=dict(alpha=[.2,.4,.01],beta=[1,2.4,.01],
        baseline_cores=36,dp_per_core=256,utilization=1,contexts=contexts,scenarios=list('ABCDEF'),
        budget_points=len(grid),design_deployments=len(hardware),case_design_evaluations=len(grid)*66*9),
        checks=dict(case_ledger_matches_frozen=True,figure5_reproduced=True,reduced_formula_matches_deploy=True,
                    baseline_fixed=True,work_conserved=True),
        inputs=[fingerprint(p) for p in inputs],outputs=[fingerprint(p) for p in out.iterdir() if p.is_file() and p.name!='manifest.json'])
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest['parameters'],indent=2))


if __name__=='__main__':
    main()
