"""Run the two prefill experiments from a JSON config and standalone input snapshots."""
import argparse
import csv
import fcntl
import hashlib
import json
import os
import tempfile
from pathlib import Path

import numpy as np

from budgets import sweep
from chip import Chip, MODES, number, service_times
from workload import work_inputs

HERE = Path(__file__).resolve().parent
METHODS = ('upper_edge', 'observed')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, rows):
    with path.open('w',newline='') as stream:
        writer = csv.DictWriter(stream,rows[0].keys(),lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def stage_weights(cfg):
    stages = cfg['scenarios']
    if 'scenario_weights' in cfg:
        mapping = cfg['scenario_weights']
        if not set(stages) <= mapping.keys():
            raise ValueError('Every selected scenario needs a weight')
        weights = np.array([float(mapping[s]) for s in stages])
        if not np.isfinite(weights).all() or (weights <= 0).any():
            raise ValueError('Selected scenario weights must be positive and finite')
        return weights / weights.sum()
    return np.full(len(stages),1/len(stages))


def fixed_case(chip, demand, weights, cfg):
    hw, physical, active = chip.hardware(number(cfg['alpha']), number(cfg['beta']))
    rates = active*chip.rate
    times = np.array([service_times(stage,rates) for stage in demand])
    times = np.vstack((times,weights @ times))
    if not np.isfinite(times[:,chip.base]).all():
        raise ValueError('Baseline cannot serve all selected stages at the fixed budget')
    scores = []
    for j,ratio in enumerate(chip.ratios):
        for i,stage in enumerate([*cfg['scenarios'],'All']):
            t = times[i,j]
            scores.append(dict(ratio=ratio,scenario=stage,mean_seconds=t,baseline_seconds=times[i,chip.base],
                               speedup=times[i,chip.base]/t,rank=int(1+(times[i]<t).sum()),
                               physical=physical[j],**{'active_'+m:int(k) for m,k in zip(MODES,active[j])}))
    return hw, scores


def upper_edge_times(chip, hw, cases, bins, scores, cfg):
    """Per-length seconds at the reference budget, before request weighting."""
    active = np.array([row['active'] for row in hw]).reshape(len(chip.ratios),len(MODES))
    rates = chip.rate * active
    by_length = {row['upper_tokens']: row for row in bins}
    rows = []
    for case in cases:
        context = case['context']
        frequency = by_length[context]
        work = [case[k+'_flops'] for k in ('H','Q','E')]
        times = service_times(work,rates)
        if not np.isfinite(times[chip.base]):
            raise ValueError(f'Baseline cannot serve scenario {case["scenario"]} at {context} tokens')
        for ratio,seconds in zip(chip.ratios,times):
            rows.append(dict(context=context,requests=frequency['requests'],weight=frequency['weight'],
                             scenario=case['scenario'],ratio=ratio,seconds=seconds,
                             baseline_seconds=times[chip.base],speedup=times[chip.base]/seconds))
    if cfg['fixed_lengths']=='upper_edge':
        expected = {(r['scenario'],r['ratio']):r['mean_seconds'] for r in scores}
        totals = {}
        for row in rows:
            if row['requests']:
                key = (row['scenario'],row['ratio'])
                totals[key] = totals.get(key,0.0) + row['weight']*row['seconds']
        for key,time in totals.items():
            np.testing.assert_allclose(time,expected[key],rtol=2e-13,atol=0)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,default=HERE/'study.json')
    parser.add_argument('--hardware',type=Path,help='Override the hardware CSV (relative to current directory)')
    parser.add_argument('--scenarios',nargs='+',help='Score these scenario IDs in the given order')
    parser.add_argument('--sweep-lengths',choices=METHODS)
    parser.add_argument('--fixed-lengths',choices=METHODS)
    parser.add_argument('--output',type=Path,default=HERE/'results')
    parser.add_argument('--no-plots',action='store_true',help='Compute tables without a TeX installation')
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text())
    for field in ('scenarios','sweep_lengths','fixed_lengths'):
        value = getattr(args,field)
        if value is not None:
            cfg[field] = value
    methods = list(dict.fromkeys([cfg['fixed_lengths'],cfg['sweep_lengths']]))
    if any(m not in METHODS for m in methods):
        parser.error('Length method must be observed or upper_edge')
    paths = {k:(args.config.parent/cfg[k]).resolve() for k in ('hardware','model','migrations','trace')}
    if args.hardware:
        paths['hardware'] = args.hardware.resolve()
    out = args.output.resolve()
    chip = Chip(paths['hardware'],cfg)
    workloads, tables = work_inputs(cfg,paths,methods)
    weights = stage_weights(cfg)
    hw,scores = fixed_case(chip,workloads[cfg['fixed_lengths']],weights,cfg)
    tables['upper_edge_times'] = upper_edge_times(chip,hw,tables['cases'],tables['context_weights'],scores,cfg)
    tables.update(hardware=hw,fixed_scores=scores)
    if cfg['sweep_lengths'] == cfg['fixed_lengths']:
        tables['sweep_reference_scores'] = scores
    else:
        _, tables['sweep_reference_scores'] = fixed_case(chip,workloads[cfg['sweep_lengths']],weights,cfg)
    tables.update(sweep(chip,weights @ workloads[cfg['sweep_lengths']],cfg))
    summary = sorted((r for r in scores if r['scenario']=='All'),key=lambda r:r['rank'])
    # Publish complete results only after calculations and requested figures succeed.
    out.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.dse-',dir=out.parent) as temp:
        tmp = Path(temp)
        for name,rows in tables.items():
            save(tmp/(name+'.csv'),rows)
        if not args.no_plots:
            from plot import render
            render(tmp,number(cfg['alpha']))
        manifest = dict(format='dp-puzzle-dse-v1',status='analytical_uncalibrated',config=cfg,
                        scenario_weights=dict(zip(cfg['scenarios'],weights)),
                        input_files={k:dict(name=p.name,sha256=digest(p)) for k,p in paths.items()},
                        code_sha256={p.name:digest(p) for p in sorted(HERE.glob('*.py'))},
                        outputs={p.name:digest(p) for p in sorted(tmp.iterdir())})
        marker = tmp/'manifest.json'
        marker.write_text(json.dumps(manifest,indent=2)+'\n')
        out.mkdir(exist_ok=True)
        lock = os.open(out,os.O_RDONLY)
        try:
            fcntl.flock(lock,fcntl.LOCK_EX)
            prior = out/'manifest.json'
            old_outputs = {}
            if any(out.iterdir()):
                if not prior.is_file():
                    raise ValueError(f'Use an empty or previous DSE result directory: {out}')
                old = json.loads(prior.read_text())
                if old.get('format') != 'dp-puzzle-dse-v1':
                    raise ValueError(f'Unrecognized result manifest in {out}')
                old_outputs = old['outputs']
            protected = {*paths.values(),args.config.resolve()}
            if any((out/p.name).resolve() in protected for p in tmp.iterdir()):
                raise ValueError('An output file would overwrite an input')
            for p in tmp.iterdir():
                if p != marker:
                    p.replace(out/p.name)
            for name in ('five_scenarios_compare.pdf','budget_sweep.pdf'):
                if name in old_outputs and name not in manifest['outputs']:
                    (out/name).unlink(missing_ok=True)
            marker.replace(prior)
        finally:
            os.close(lock)
    print(f"Fixed ({cfg['fixed_lengths']}), {','.join(cfg['scenarios'])}, best overall:")
    for r in summary:
        print(f"{r['ratio']:>8}  {r['mean_seconds']:.6f} s  {r['speedup']:.6f}x")
    print(f"Sweep ({cfg['sweep_lengths']}): {out/'reference_bands.csv'}")


if __name__ == '__main__':
    main()
