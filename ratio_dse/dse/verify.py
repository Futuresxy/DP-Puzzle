"""Check independently frozen chapter V tables against one completed reference run."""
import argparse
import csv
import gzip
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
REF = HERE/'reference'


def table(path, keys):
    opener = gzip.open if path.suffix=='.gz' else open
    with opener(path,'rt',newline='') as f:
        rows = list(csv.DictReader(f))
    keyed = {tuple(r[k] for k in keys):r for r in rows}
    if len(keyed)!=len(rows):
        raise ValueError(f'Duplicate key in {path.name}')
    return keyed


def compare(run, output, source, keys, fields):
    expected = table(REF/source,keys.split())
    actual = table(run/(output+'.csv'),keys.split())
    if actual.keys()!=expected.keys():
        raise ValueError(f'{output}: row keys differ')
    for key,row in expected.items():
        for name in fields.split():
            a,b = actual[key][name],row[name]
            if a==b:
                continue
            try:
                matches = math.isclose(float(a),float(b),rel_tol=2e-13,abs_tol=1e-13)
            except ValueError:
                matches = False
            if not matches:
                raise ValueError(f'{output} {key} {name}: got {a}, expected {b}')
    print(f'{output}: {len(actual)} rows match')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('run',type=Path)
    args = p.parse_args()
    import json
    import hashlib
    manifest = json.loads((args.run/'manifest.json').read_text())
    cfg = manifest['config']
    for name,expected in manifest['outputs'].items():
        if hashlib.sha256((args.run/name).read_bytes()).hexdigest()!=expected:
            raise ValueError(f'Run output modified: {name}')
    compare(args.run,'hardware','hardware.csv','ratio mode',
            'physical active area_budget_mm2 dp_idle_mw dp_active_mw array_power_w array_budget_w tflops')
    compare(args.run,'context_weights','context_weights.csv','upper_tokens','requests weight')
    compare(args.run,'operator_flops','operator_flops.csv','context kernel native_precision','flops')
    compare(args.run,'cases','cases.csv','context scenario','H_flops Q_flops E_flops excluded_fp32_flops')
    ref_scores = 'fixed_scores.csv' if cfg['fixed_lengths']=='upper_edge' else 'observed_scores.csv'
    fields = 'mean_seconds speedup rank'
    if cfg['fixed_lengths']=='upper_edge':
        fields += ' physical active_BF16 active_MXFP8 active_MXFP4'
    compare(args.run,'fixed_scores',ref_scores,'scenario ratio',fields)
    if cfg['sweep_lengths']=='observed':
        compare(args.run,'budget_bands','budget_bands.csv.gz','scope alpha_lo alpha_hi beta_lo beta_hi ratio',
                'win_share band_speedup min_speedup max_speedup coverage_winner mean_time_winner')
        compare(args.run,'reference_bands','reference_bands.csv','beta_lo beta_hi',
                'coverage_winner winning_fraction winner_band_speedup winner_min_speedup winner_max_speedup')
        compare(args.run,'domain_scores','domain_scores.csv','ratio','winning_budget_fraction ratio_of_mean_times')
    else:
        prior = table(REF/'domain_scores.csv',['ratio'])
        fresh = table(args.run/'domain_scores.csv',['ratio'])
        if fresh.keys()!=prior.keys() or any(not math.isclose(float(row['winning_budget_fraction']),
                float(prior[k]['upper_edge_winning_fraction']),abs_tol=1e-12) for k,row in fresh.items()):
            raise ValueError('Upper-edge domain win shares differ from independent original sensitivity run')
        print('domain_scores: upper-edge winning fractions match the original sensitivity run')


if __name__=='__main__':
    main()
