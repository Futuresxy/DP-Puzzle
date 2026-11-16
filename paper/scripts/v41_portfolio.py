"""Choose one fixed DP design across context and precision-policy portfolios.

Precision switches are structural experiments, not quality-validated checkpoints.
Request weights, normalized slowdown and worst-case regret remain distinct.
"""
import csv
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np

import deepseek_v41 as v41
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'data/inputs/v41_portfolio.json'
OUTPUT = ROOT / 'data/evidence/v41_portfolio_20261116'
PRECISIONS = ('BF16', 'FP8', 'FP4')


def match(row, switch):
    return (row['kernel'].startswith(switch['prefix']) if 'prefix' in switch
            else row['kernel'] in switch['kernels'])


def policy_work(rows, switches, fractions):
    """Conserve work; interpolate the selected operator family's FLOPs only."""
    fractions = np.asarray(fractions, dtype=float)
    if fractions.shape != (len(switches),) or not np.all(np.isfinite(fractions)) or np.any((fractions < 0) | (fractions > 1)):
        raise ValueError('One migration fraction in [0,1] is required per switch')
    work = np.zeros(3)
    excluded = 0
    matched = np.zeros(len(switches), dtype=int)
    for row in rows:
        matches = [i for i, switch in enumerate(switches) if match(row, switch)]
        if len(matches) > 1:
            raise ValueError('Precision switch groups overlap')
        if row['precision'] not in PRECISIONS:
            if matches:
                raise ValueError('A precision switch selected excluded work')
            excluded += row['flops']
            continue
        source = PRECISIONS.index(row['precision'])
        work[source] += row['flops']
        if matches:
            i = matches[0]
            switch = switches[i]
            if row['precision'] != switch['from']:
                raise ValueError('Switch source precision disagrees with the operator ledger')
            matched[i] += 1
            moved = fractions[i] * row['flops']
            work[source] -= moved
            work[PRECISIONS.index(switch['to'])] += moved
    if np.any(matched == 0):
        raise ValueError('Precision switch matched no operators')
    if not np.isclose(work.sum() + excluded, sum(r['flops'] for r in rows), rtol=1e-13):
        raise AssertionError('Work conservation failed')
    return work, excluded


def distribution_weights(contexts, name):
    """Synthetic request frequencies: equal log bins, short-heavy, long-heavy."""
    contexts = np.asarray(contexts, dtype=float)
    if contexts.ndim != 1 or not len(contexts) or np.any(contexts <= 0) or not np.all(np.isfinite(contexts)):
        raise ValueError('Positive finite contexts required')
    powers = {'balanced': 0, 'short': -1, 'long': 1}
    if name not in powers:
        raise ValueError('Unknown request distribution')
    weights = contexts ** powers[name]
    return weights / weights.sum()


def pareto_mask(values):
    values = np.asarray(values)
    return np.array([not any(np.all(other <= row) and np.any(other < row)
                            for other in values) for row in values])


def portfolio_metrics(times, energies, weights):
    """Rows are cases, columns are fixed physical designs. Never average winners."""
    times, energies, weights = map(lambda a: np.asarray(a, dtype=float), (times, energies, weights))
    if (times.ndim != 2 or times.shape != energies.shape or weights.shape != (len(times),)
            or not np.all(np.isfinite(times)) or np.any(times <= 0)
            or not np.all(np.isfinite(energies)) or np.any(energies < 0)
            or not np.all(np.isfinite(weights)) or np.any(weights < 0) or weights.sum() <= 0):
        raise ValueError('Finite case/design costs and nonnegative request weights required')
    weights = weights / weights.sum()
    slowdown = times / times.min(axis=1, keepdims=True)
    # The explicit scenario envelope remains in the worst-case set even if a
    # distribution assigns zero probability to a case. Weights affect means only.
    worst = slowdown.max(axis=0) - 1
    mean_time, mean_energy = weights @ times, weights @ energies
    frontier = pareto_mask(np.column_stack((worst, mean_time, mean_energy)))
    return dict(worst_regret=worst, mean_slowdown=weights @ slowdown,
                mean_seconds=mean_time, mean_dp_energy_j=mean_energy,
                speedup_over_baseline=mean_time[0] / mean_time,
                energy_over_baseline=mean_energy / mean_energy[0],
                minimax=np.isclose(worst, worst.min(), rtol=1e-10, atol=1e-12),
                pareto=frontier, worst_case_index=slowdown.argmax(axis=0))


def write_csv(path, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def render_report(config, evaluations, metrics, ratios):
    """Vector context curves and a compact table for the declared main budget."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    alpha, beta = config['report_alpha'], config['report_beta']
    selected = [r for r in metrics if r['alpha'] == alpha and r['beta'] == beta
                and r['distribution'] == 'balanced']
    labels = ['Original', '+ Routed E', '+ Shared E', '+ Linear E', '+ Attention Q', '+ Output Q', 'All policies']
    lines = [r'% Generated by scripts/v41_portfolio.py.',
             r'\begin{tabular}{@{}lcrr@{}}\toprule',
             r'Policy & Ratio & $R_j$ (\%) & $\overline{s}_j-1$ (\%) \\\midrule']
    for policy, label in zip(config['representative_policies'] + ['all_policies'], labels):
        for row in selected:
            if row['portfolio'] == policy and row['minimax']:
                lines.append(f"{label} & ${row['ratio']}$ & {100*row['worst_regret']:.2f} & "
                             f"{100*(row['mean_slowdown']-1):.2f}" + r' \\')
    lines.append(r'\bottomrule\end{tabular}')
    table = ROOT/'tables/v41_fixed_choice.tex'
    table.write_text('\n'.join(lines)+'\n')
    plt.rcParams.update({'font.family':'serif', 'font.serif':['Times New Roman','Liberation Serif','STIXGeneral'],
                         'font.size':9, 'mathtext.fontset':'stix', 'pdf.fonttype':42})
    colors = ['#3c5488','#b88a20','#008b70','#8064a2','#c44e52','#7a6a43','#367fa0','#91614b','#d05c9b']
    markers = ['o','s','^','D','v','P','X','<','>']
    fig, axes = plt.subplots(1,3,figsize=(7.16,2.75),sharey=True)
    reference = [r for r in evaluations if r['alpha'] == alpha and r['beta'] == beta]
    for panel,(ax,policy) in enumerate(zip(axes,['P00000','P10000','all_policies'])):
        winners = [r for r in selected if r['portfolio'] == policy and r['minimax']]
        for j,ratio in enumerate(ratios):
            values = [max(r['slowdown'] for r in reference if r['ratio'] == ratio and r['context'] == context
                          and (policy == 'all_policies' or r['policy'] == policy)) for context in config['contexts']]
            chosen = any(r['ratio'] == ratio for r in winners)
            ax.plot(config['contexts'],values,color=colors[j],marker=markers[j],markersize=3,
                    linewidth=1.8 if chosen else .75,linestyle='-' if j<5 else '--',label=ratio)
        ax.set_xscale('log',base=2)
        ax.set_xticks([1024,16384,262144,1048576],['1K','16K','256K','1M'])
        ax.set_xlabel('Context (tokens)')
        ax.tick_params(labelsize=8)
        ax.grid(axis='y',alpha=.18,linewidth=.5)
        ax.set_title('('+chr(97+panel)+')',fontsize=9)
        ax.text(.04,.97, '; '.join(f"{r['ratio']}: {100*r['worst_regret']:.2f}%" for r in winners),
                transform=ax.transAxes,ha='left',va='top',fontsize=8)
    axes[0].set_ylabel('Slowdown vs. pointwise best')
    axes[0].set_ylim(.94, max(r['slowdown'] for r in reference) + .25)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles,labels,loc='lower center',ncol=5,frameon=False,fontsize=8,handlelength=2)
    fig.subplots_adjust(left=.085,right=.99,bottom=.34,top=.9,wspace=.15)
    figure = ROOT/'figures/v41_fixed_ratio.pdf'
    fig.savefig(figure,bbox_inches='tight',pad_inches=.03,metadata={'CreationDate':None,'ModDate':None})
    plt.close(fig)
    return [table,figure]


def main():
    config = json.loads(CONFIG.read_text())
    profiles, source_metadata = load_profiles()
    profiles = full_precision_profiles(profiles)
    ratios = [p['ratio'] for p in profiles]
    switches = config['precision_switches']
    policies = list(itertools.product((0, 1), repeat=len(switches)))
    policy_ids = ['P' + ''.join(map(str, bits)) for bits in policies]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cases, ledger_rows, policy_rows = [], [], []
    work_vectors = []
    ledgers = {context: v41.prefill_work(context, batch=config['batch']) for context in config['contexts']}
    for context, ledger in ledgers.items():
        for row in v41.aggregate(ledger, by=('segment', 'component', 'kernel', 'precision')):
            ledger_rows.append(dict(context=context, **row))
    for policy_id, bits in zip(policy_ids, policies):
        policy_rows.append(dict(policy=policy_id, **dict(zip([s['name'] for s in switches], bits))))
        for context, ledger in ledgers.items():
            work, excluded = policy_work(ledger, switches, bits)
            work_vectors.append(work)
            cases.append(dict(policy=policy_id, context=context,
                              h_flops=work[0], q_flops=work[1], e_flops=work[2],
                              x_H=work[0]/work.sum(), x_Q=work[1]/work.sum(), x_E=work[2]/work.sum(),
                              excluded_fp32_flops=excluded, hqe_coverage=work.sum()/(work.sum()+excluded)))
    work_vectors = np.array(work_vectors)
    evaluations, metrics, aggregate_points = [], [], []
    for alpha, beta in itertools.product(config['alphas'], config['betas']):
        deployments = deploy(profiles, alpha, beta, config['baseline_sms'], config['dp_per_sm'])
        if any(not row['feasible'] for row in deployments):
            raise ValueError('At least one SM per design required')
        capacity = np.array([[row[m+'_peak_tflops'] for m in MODES] for row in deployments])
        power = np.array([[row[m+'_dp_power_w'] for m in MODES] for row in deployments])
        times = work_vectors @ (1/capacity).T / 1e12
        energies = work_vectors @ (power/capacity).T / 1e12
        for i, case in enumerate(cases):
            for j, ratio in enumerate(ratios):
                evaluations.append(dict(alpha=alpha, beta=beta, policy=case['policy'], context=case['context'],
                                        ratio=ratio, seconds=times[i,j], dp_energy_j=energies[i,j],
                                        slowdown=times[i,j]/min(times[i])))
        for portfolio in policy_ids + ['all_policies']:
            indices = [i for i,c in enumerate(cases) if portfolio == 'all_policies' or c['policy'] == portfolio]
            for distribution in config['distributions']:
                weights = distribution_weights([cases[i]['context'] for i in indices], distribution)
                report = portfolio_metrics(times[indices], energies[indices], weights)
                effective = weights @ work_vectors[indices]
                effective /= effective.sum()
                # Expected request time equals evaluating the aggregate FLOP
                # vector, rather than averaging x_H/x_Q/x_E or winning labels.
                np.testing.assert_allclose(report['mean_seconds'],
                    (weights @ work_vectors[indices]) @ (1/capacity).T / 1e12, rtol=1e-12)
                aggregate_points.append(dict(alpha=alpha, beta=beta, portfolio=portfolio, distribution=distribution,
                    effective_x_H=effective[0], effective_x_Q=effective[1], effective_x_E=effective[2]))
                for j, ratio in enumerate(ratios):
                    worst = cases[indices[report['worst_case_index'][j]]]
                    metrics.append(dict(alpha=alpha, beta=beta, portfolio=portfolio, distribution=distribution,
                        ratio=ratio, **{k: (bool(v[j]) if v.dtype == bool else float(v[j]))
                                       for k,v in report.items() if k != 'worst_case_index'},
                        worst_policy=worst['policy'], worst_context=worst['context']))
    datasets = {'operator_work': ledger_rows, 'policies': policy_rows, 'cases': cases,
                'evaluations': evaluations, 'metrics': metrics, 'aggregate_points': aggregate_points}
    for name, rows in datasets.items():
        write_csv(OUTPUT / f'{name}.csv', rows)
    report_files = render_report(config,evaluations,metrics,ratios)
    inputs = [CONFIG, ROOT/'scripts/v41_portfolio.py', ROOT/'scripts/deepseek_v41.py', ROOT/'scripts/hardware_cost.py',
              v41.SOURCE_DIR/'inference/config.json', ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv',
              ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json']
    def fingerprint(path):
        return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    manifest = dict(status='analytical_uncalibrated', config=config, ratios=ratios,
        source_revision=v41.SOURCE_REVISION, source_metadata=source_metadata,
        method={'selection':'minimax relative latency regret over the declared case set; keep all ties',
                'comparison':'mean normalized slowdown, expected request compute time and DP energy reported separately',
                'pareto_objectives':['worst_regret','mean_seconds','mean_dp_energy_j'],
                'balanced':'Equal request counts at each of 11 doubling contexts; all-policy mean additionally uses equal policy weights',
                'sensitivity':'Synthetic request probabilities proportional to L^-1 or L, not measured traffic',
                'precision':'32 binary operator-family migration endpoints, independent of context; no quality validation assumed',
                'continuous_envelope':'With affine work, fixed capacities and no conversion cost, endpoints bound worst relative regret of fractional operator migration at each sampled context',
                'scope':'Full CED cold prefill GEMM accounting; DP-only power and ideal compute service time; other work remains in excluded totals'},
        validation={'contexts':len(ledgers),'policies':len(policies),'cases':len(cases),
                    'budget_scenarios':len(config['alphas'])*len(config['betas']),
                    'evaluations':len(evaluations),'work_conservation_pass':True,'aggregate_time_equivalence_pass':True},
        inputs=list(map(fingerprint,inputs)),outputs=[fingerprint(OUTPUT/f'{name}.csv') for name in datasets]
        + list(map(fingerprint,report_files)))
    (OUTPUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest['validation'],indent=2))


if __name__ == '__main__':
    main()
