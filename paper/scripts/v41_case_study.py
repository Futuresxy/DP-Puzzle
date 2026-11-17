"""Reproduce the fixed-budget case study without writing formal manuscript files."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np

import deepseek_v41 as model
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles
from v41_core import map_work

ROOT = Path(__file__).resolve().parents[1]


def write_csv(path, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def render(figure, hardware, gains, scenario_ids):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import TwoSlopeNorm
    from matplotlib.patches import Rectangle

    columns = scenario_ids + ['All']
    matrix = np.array([[next(g['speedup'] for g in gains
                            if g['ratio'] == h['ratio'] and g['scenario'] == s)
                        for s in columns] for h in hardware])
    plt.rcParams.update({'font.family': 'serif', 'font.serif': ['DejaVu Serif'],
                         'font.size': 8, 'pdf.fonttype': 42})
    fig, ax = plt.subplots(figsize=(3.49, 2.72))
    fig.subplots_adjust(left=.25, right=.985, top=.88, bottom=.26)
    lower = min(.9, np.floor(matrix.min()*10)/10)
    upper = max(1.1, np.ceil(matrix.max()*10)/10)
    norm = TwoSlopeNorm(vmin=lower, vcenter=1, vmax=upper)
    image = ax.pcolormesh(np.arange(len(columns)+1)-.5, np.arange(len(hardware)+1)-.5,
                         matrix, cmap='RdBu', norm=norm,
                         shading='flat', rasterized=False)
    ax.set_xlim(-.5, len(columns)-.5)
    ax.set_ylim(len(hardware)-.5, -.5)
    ax.set_xticks(range(len(columns)), columns)
    ax.set_yticks(range(len(hardware)), [f"{r['ratio']} ({r['cores']})" for r in hardware])
    ax.tick_params(length=0, pad=3, labelsize=7.5)
    ax.text(-.03, 1.03, 'Ratio (cores)', transform=ax.transAxes, ha='right', fontsize=7.5)
    ax.text(.5, 1.03, 'Precision-migration scenario', transform=ax.transAxes, ha='center', fontsize=7.5)
    ax.axvline(len(columns)-1.5, color='white', linewidth=1.5)
    for i in range(matrix.shape[0]):
        for j in range(matrix.shape[1]):
            value = matrix[i, j]
            ax.text(j, i, f'{value:.2f}', ha='center', va='center', fontsize=7.3,
                    color='white' if norm(value) < .16 or norm(value) > .87 else '#202020')
            if np.isclose(value, matrix[:, j].max(), rtol=1e-12):
                ax.add_patch(Rectangle((j-.46, i-.46), .92, .92, fill=False,
                                      edgecolor='#161616', linewidth=1))
    color_axis = fig.add_axes([.26, .105, .70, .035])
    bar = fig.colorbar(image, cax=color_axis, orientation='horizontal', ticks=[lower, 1, upper])
    bar.solids.set_rasterized(False)
    bar.ax.tick_params(labelsize=7, pad=1)
    bar.set_label('Modeled GEMM compute speedup vs 1:2:4', fontsize=7, labelpad=2)
    figure.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(figure, metadata={'CreationDate': None, 'ModDate': None})
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT/'data/inputs/v41_case_study_equal_budget.json')
    parser.add_argument('--output', type=Path, default=ROOT/'data/evidence/v41_case_study_equal_budget_20261117')
    parser.add_argument('--figure', type=Path, default=ROOT/'figures/temp/v41_case_study_equal_budget.pdf')
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    if (config['scope'] != 'ced_cold_prefill' or config['utilization'] != 1
            or config['weighting'] != 'equal_requests_and_scenarios'):
        raise ValueError('This case study uses CED prefill, full utilization and equal request weights')
    contexts = config['contexts']
    scenarios = config['scenarios']
    ids = [s['id'] for s in scenarios]
    if not contexts or not ids or len(set(contexts)) != len(contexts) or len(set(ids)) != len(ids):
        raise ValueError('Contexts and scenario IDs must be nonempty and unique')
    architecture = model.load_config(ROOT/config['model_config'])
    profiles, source_metadata = load_profiles()
    profiles = full_precision_profiles(profiles)
    deployment = deploy(profiles, config['alpha'], config['beta'],
                        config['baseline_cores'], config['dp_per_core'])
    hardware = []
    for row in deployment:
        if not row['feasible']:
            raise ValueError('Every candidate must have at least one deployed core')
        assert row['installed_area_mm2'] <= row['area_budget_mm2'] + 1e-9
        assert row['max_dp_power_w'] <= row['dp_power_budget_w'] + 1e-9
        hardware.append(dict(ratio=row['ratio'], cores=int(row['installed_sms']),
            area_only_cores=int(row['area_limited_sms']), constraint=row['binding_constraint'],
            area_mm2=row['installed_area_mm2'], area_budget_mm2=row['area_budget_mm2'],
            max_dp_power_w=row['max_dp_power_w'], dp_power_budget_w=row['dp_power_budget_w'],
            **{p+'_tflops':row[m+'_peak_tflops'] for p, m in zip('HQE', MODES)}))
    capacity = np.array([[r[p+'_tflops']*1e12 for p in 'HQE'] for r in hardware])
    ledgers = {length: model.prefill_work(length, batch=config['batch'], config=architecture)
               for length in contexts}
    operators = [dict(context=length, **row) for length, rows in ledgers.items() for row in rows]
    cases, work = [], []
    for scenario in scenarios:
        for length, ledger in ledgers.items():
            flops, _, excluded, core, index = map_work(ledger, scenario)
            assert sum(flops)+excluded == sum(r['flops'] for r in ledger)
            work.append(flops)
            cases.append(dict(scenario=scenario['id'], context=length,
                **{p+'_flops':flops[i] for i, p in enumerate('HQE')},
                **{p+'_share':flops[i]/sum(flops) for i, p in enumerate('HQE')},
                excluded_fp32_flops=excluded, migration_target_flops=core, index_flops=index))
    work = np.array(work)
    times = work @ (1/capacity).T
    evaluations = []
    for i, case in enumerate(cases):
        for j, row in enumerate(hardware):
            direct = sum(work[i, p]/capacity[j, p] for p in range(3))
            np.testing.assert_allclose(times[i, j], direct, rtol=1e-13)
            evaluations.append(dict(scenario=case['scenario'], context=case['context'], ratio=row['ratio'],
                seconds=times[i, j], speedup=times[i, 0]/times[i, j],
                **{p+'_seconds':work[i, k]/capacity[j, k] for k, p in enumerate('HQE')}))
    gains = []
    for sid in ids+['All']:
        mask = np.array([sid == 'All' or c['scenario'] == sid for c in cases])
        means = times[mask].mean(axis=0)
        for j, row in enumerate(hardware):
            gains.append(dict(scenario=sid, ratio=row['ratio'], mean_seconds=means[j],
                speedup=means[0]/means[j],
                worst_baseline_time_increase=float((times[mask, j]/times[mask, 0]-1).max()),
                best_mean_time=bool(np.isclose(means[j], means.min(), rtol=1e-12))))
    assert all(np.isclose(g['speedup'], 1) for g in gains if g['ratio'] == '1:2:4')
    for j, h in enumerate(hardware):
        per_scenario = [g['mean_seconds'] for g in gains if g['ratio'] == h['ratio'] and g['scenario'] != 'All']
        np.testing.assert_allclose(np.mean(per_scenario), times[:, j].mean(), rtol=1e-13)
    args.output.mkdir(parents=True, exist_ok=True)
    datasets = {'operators':operators, 'cases':cases, 'hardware':hardware, 'evaluations':evaluations, 'gains':gains}
    for name, rows in datasets.items():
        write_csv(args.output/(name+'.csv'), rows)
    render(args.figure, hardware, gains, ids)
    paths = [args.config, Path(__file__), ROOT/config['model_config'], ROOT/'scripts/deepseek_v41.py',
             ROOT/'scripts/v41_core.py', ROOT/'scripts/hardware_cost.py', ROOT/'data/evidence/model_sources.json',
             ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv',
             ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json']
    def fingerprint(path):
        return dict(path=str(path.resolve().relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    manifest = dict(status='analytical_uncalibrated', config=config, hardware_source=source_metadata,
        inputs=[fingerprint(p) for p in paths],
        outputs=[fingerprint(args.output/(n+'.csv')) for n in datasets]+[fingerprint(args.figure)],
        checks=dict(work_conserved=True, budget_feasibility=True, direct_time_recomputed=True,
                    baseline_speedup_one=True, overall_time_matches_scenario_mean=True,
                    workload_cases=len(cases), hardware_candidates=len(hardware), figure_cells=len(gains)),
        interpretation=['Fixed AI-core area budget and DP-array power ceiling; all cores may operate in each measured mode.',
            'Full-CED cold prefill; HQE compute time only; FP32 work recorded separately.',
            'Precision migration is a configurable hypothesis; no new quantization-quality or inference measurement.',
            'Uniform request probabilities over contexts and scenarios; score is a ratio of mean times, not mean speedups.',
            'The model source revision constant differs from the stored config provenance; both input files are hashed.'])
    (args.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(manifest['checks'], indent=2))


if __name__ == '__main__':
    main()
