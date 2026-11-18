"""Evaluate one physical DP design per chip using trace-weighted cold prefill."""
import argparse
from bisect import bisect_left
from collections import Counter
import csv
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
PAPER = HERE.parents[1]
sys.path.insert(0, str(PAPER / 'scripts'))
import deepseek_v41 as model
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles
from v41_core import map_work
from v41_case_study import write_csv

CONFIG = PAPER / 'data/inputs/v41_five_stage.json'
EVIDENCE = PAPER / 'data/evidence/v41_five_stage_20261117'
COST = PAPER / 'data/DP_area_power'
BASE = '1:2:4'
LETTERS = 'HQE'


def csv_rows(path):
    with path.open(newline='') as stream:
        return list(csv.DictReader(stream))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hardware(config):
    profiles, meta = load_profiles()
    profiles = full_precision_profiles(profiles)
    static_path = COST / meta['source']['local_snapshot']
    assert digest(static_path) == meta['source']['sha256']
    static = {(r['top'], r['format']): Fraction(r['static_mw']) / 1000
              for r in csv_rows(static_path)}
    d = config['dp_per_core']
    fixed = deploy(profiles, config['alpha'], config['beta'], config['baseline_cores'], d)
    base = next(p for p in profiles if p['ratio'] == BASE)
    budget = (Fraction(config['beta']) * config['baseline_cores'] * d
              * max(m['power_w'] for m in base['modes'].values()))
    rows, capacities = [], []
    for profile, reference in zip(profiles, fixed):
        n = reference['area_limited_sms']
        idle = max(static[profile['top'], m] for m in MODES)
        rates = []
        for mode in MODES:
            active = profile['modes'][mode]['power_w']
            if not 0 <= idle < active:
                raise ValueError(f"Invalid idle proxy for {profile['ratio']} {mode}")
            count = min(n, (budget / d - n * idle) // (active - idle))
            used = d * (count * active + (n - count) * idle)
            assert 0 < count <= n and used <= budget
            assert count == n or used + d * (active - idle) > budget
            rate = (count * d * 2 * profile['modes'][mode]['native_k']
                    * profile['frequency_hz'] / profile['ii'])
            rates.append(float(rate))
            rows.append(dict(ratio=profile['ratio'], mode=mode, physical_cores=n,
                             fixed_policy_cores=reference['installed_sms'], active_cores=count,
                             area_used_mm2=n*reference['sm_area_mm2'],
                             area_budget_mm2=reference['area_budget_mm2'],
                             dp_active_mw=float(active*1000), dp_idle_proxy_mw=float(idle*1000),
                             array_pool_power_w=float(used), array_pool_budget_w=float(budget),
                             active_tflops=float(rate / 10**12)))
        capacities.append(rates)
    return rows, [p['ratio'] for p in profiles], np.array(capacities)


def histogram(path):
    counts = {}
    for r in csv_rows(path):
        length, n = int(r['input_tokens']), int(r['requests'])
        if length < 1 or n < 1 or length in counts:
            raise ValueError(f'Invalid histogram row in {path}: {r}')
        counts[length] = n
    if not counts:
        raise ValueError(f'Empty histogram: {path}')
    return counts


def mapped_flops(counter, scenarios):
    # Aggregate exact integer work by kernel before applying the existing A--E mapping.
    rows = [dict(kernel=k, precision=p, flops=v) for (k, p), v in counter.items()]
    return np.array([map_work(rows, s)[0] for s in scenarios])


def add_scores(scores, name, method, flops, capacities, ratios, sids):
    times = flops @ (1 / capacities).T
    times = np.vstack((times, times.mean(axis=0)))
    base = ratios.index(BASE)
    regret = times / times.min(axis=1)[:, None] - 1
    for i, scenario in enumerate(sids + ['All']):
        for j, ratio in enumerate(ratios):
            scores.append(dict(trace=name, length_method=method, scenario=scenario, ratio=ratio,
                               mean_seconds=times[i, j], speedup=times[i, base]/times[i, j],
                               rank=1+int(np.sum(times[i] < times[i, j])),
                               loss_to_best=regret[i, j],
                               worst_scenario_loss=float(regret[:-1,j].max()) if scenario=='All' else ''))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, action='append',
                        help='Exact input_tokens,requests histogram. Repeat to score independent traces.')
    parser.add_argument('--output', type=Path, default=HERE / 'results')
    args = parser.parse_args()
    paths = args.trace or sorted((HERE/'traces').glob('*_histogram.csv'))
    if not paths:
        parser.error('Supply a trace histogram or populate traces/*_histogram.csv')
    traces = {p.stem.removesuffix('_histogram'): histogram(p) for p in paths}
    config = json.loads(CONFIG.read_text())
    contexts = config['contexts']
    scenarios = config['scenarios']
    sids = [s['id'] for s in scenarios]
    cuts = [math.isqrt(a*b) for a,b in zip(contexts,contexts[1:])]
    architecture = model.load_config(PAPER / config['model_config'])
    assert contexts[-1] == architecture.max_context and config['batch'] == 1
    if len(traces) != len(paths) or 'uniform_grid' in traces:
        parser.error('Trace identifiers must be distinct from one another and uniform_grid')
    traces['uniform_grid'] = dict.fromkeys(contexts, 1)
    grid_cases = csv_rows(EVIDENCE/'cases.csv')
    grid = {(r['scenario'],int(r['context'])): [float(r[p+'_flops']) for p in LETTERS]
            for r in grid_cases}
    hw, ratios, capacities = hardware(config)
    bins = {name: [Counter() for _ in contexts] for name in traces}
    caps = (128*1024, 256*1024)
    # Conditional request populations, with cuts at the actual input lengths.
    cap_work = {name: {cap: Counter() for cap in caps if min(c) <= cap < max(c)}
                for name,c in traces.items() if name != 'uniform_grid'}
    lengths = sorted(set().union(*(c.keys() for c in traces.values())))
    for length in lengths:
        if length > architecture.max_context:
            break
        ledger = model.prefill_work(length, config=architecture)
        work = Counter()
        for r in ledger:
            work[r['kernel'],r['precision']] += r['flops']
        if length in contexts:
            np.testing.assert_allclose(mapped_flops(work,scenarios),
                                       [grid[s,length] for s in sids],rtol=1e-13)
        index = bisect_left(cuts,length)
        for name, counts in traces.items():
            count = counts.get(length,0)
            if count:
                dest = bins[name][index]
                weighted = {key: value*count for key, value in work.items()}
                dest.update(weighted)
                for cap, subtotal in cap_work.get(name, {}).items():
                    if length <= cap:
                        subtotal.update(weighted)

    frequencies, workloads, scores, coverage, sensitivity = [], [], [], {}, []
    for name, counts in traces.items():
        ns = [0]*len(contexts)
        for length,count in counts.items():
            if length <= contexts[-1]:
                ns[bisect_left(cuts,length)] += count
        total = sum(ns)
        if total == 0:
            raise ValueError(f'No requests in model context range for {name}')
        coverage[name] = dict(total=sum(counts.values()), modeled=total,
                              minimum=min(counts), maximum=max(counts),
                              below_1k=sum(v for l,v in counts.items() if l<1024),
                              above_128k=sum(v for l,v in counts.items() if l>131072),
                              above_256k=sum(v for l,v in counts.items() if l>262144),
                              above_1m=sum(counts.values())-total)
        exact = np.zeros((len(sids),3))
        rounded = np.zeros_like(exact)
        for j,(context,n) in enumerate(zip(contexts,ns)):
            frequencies.append(dict(trace=name,grid_tokens=context,
                                    min_tokens=cuts[j-1]+1 if j else 1,
                                    max_tokens=cuts[j] if j<len(cuts) else contexts[-1],
                                    requests=n,weight=n/total))
            if not n:
                continue
            work = mapped_flops(bins[name][j],scenarios)
            np.testing.assert_allclose(work.sum(axis=1),work[0].sum(),rtol=1e-13)
            exact += work / total
            rounded += n/total * np.array([grid[s,context] for s in sids])
            for s,triplet in zip(sids,work):
                workloads.append(dict(trace=name,grid_tokens=context,scenario=s,requests=n,
                                      **{p+'_mean_flops':v/n for p,v in zip(LETTERS,triplet)}))
        add_scores(scores,name,'exact',exact,capacities,ratios,sids)
        if name!='uniform_grid':
            add_scores(scores,name,'grid',rounded,capacities,ratios,sids)
            for cap, subtotal in cap_work[name].items():
                kept = sum(n for l,n in counts.items() if l <= cap)
                limited = mapped_flops(subtotal, scenarios) / kept
                subset_scores = []
                add_scores(subset_scores,name,'exact',limited,capacities,ratios,sids)
                sensitivity.extend(dict(input_cap=cap, retained_requests=kept, **r)
                                   for r in subset_scores if r['scenario']=='All')
    args.output.mkdir(parents=True,exist_ok=True)
    for key, rows in [('hardware',hw),('context_weights',frequencies),('workload',workloads),
                      ('scores',scores)]:
        write_csv(args.output/(key+'.csv'), rows)
    cap_path = args.output/'length_cap_sensitivity.csv'
    if sensitivity:
        write_csv(cap_path,sensitivity)
    else:
        with cap_path.open('w') as f:
            print(','.join(['input_cap','retained_requests',*scores[0]]),file=f)
    inputs = [CONFIG, PAPER / config['model_config'], EVIDENCE/'cases.csv',
              COST/'dp11_area_power_fixed_20261116.sources.json',
              COST/'dp11_area_power_fixed_20261116.csv',COST/'dp11_area_power_source_20261112.csv',
              *(PAPER/'scripts'/s for s in ('deepseek_v41.py','v41_core.py','hardware_cost.py')),
              Path(__file__).resolve(), *paths]
    def source_name(p):
        p=p.resolve()
        return str(p.relative_to(PAPER)) if p.is_relative_to(PAPER) else p.name
    outputs = ['hardware.csv','context_weights.csv','workload.csv','scores.csv',
               'length_cap_sensitivity.csv']
    manifest = dict(status='analytical_uncalibrated', coverage=coverage,
                    alpha=config['alpha'], beta=config['beta'], dp_per_core=config['dp_per_core'],
                    baseline_cores=config['baseline_cores'], scenario_weights=dict.fromkeys(sids,1/len(sids)),
                    outputs={name:digest(args.output/name) for name in outputs},
                    inputs={source_name(p):digest(p) for p in inputs},
                    validation='All 55 grid cases reproduce the previous ledger. All 27 mode counts are maximal feasible integers.')
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for r in scores:
        if r['scenario']=='All' and r['rank']==1:
            print(r['trace'],r['length_method'],r['ratio'],f"{r['speedup']:.6f}x")


if __name__ == '__main__':
    main()
