"""Aggregate continuous power intervals in 0.1-wide bands without resampling."""
import csv
import gzip
import hashlib
import json
from itertools import groupby, pairwise
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
BANDS = [(i / 10, (i + 1) / 10) for i in range(10, 20)]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(intervals, ratios, alpha_lo, alpha_hi, scope):
    """A fine interval contributes its overlap length, not one vote per event."""
    result = []
    for low, high in BANDS:
        covered = 0.
        wins = np.zeros(len(ratios))
        time = np.zeros(len(ratios))
        for left, right, speeds in intervals:
            overlap = min(right, high) - max(left, low)
            if overlap <= 0:
                continue
            if not np.isclose(speeds[ratios.index('1:2:4')], 1):
                raise ValueError('Invalid baseline speedup')
            w = overlap / (high - low)
            leaders = np.isclose(speeds, speeds.max(), rtol=1e-12, atol=0)
            wins[leaders] += w / np.count_nonzero(leaders)
            time += w / speeds
            covered += w
        np.testing.assert_allclose([covered, wins.sum()], [1., 1.], atol=1e-12)
        # The 36-core baseline is area-limited throughout beta >= 1, so its
        # reference time is constant. 1 / mean(relative time) is the band speedup.
        for j, ratio in enumerate(ratios):
            result.append(dict(scope=scope, alpha_lo=alpha_lo, alpha_hi=alpha_hi,
                               beta_lo=low, beta_hi=high, ratio=ratio, win_share=wins[j],
                               band_speedup=1/time[j],
                               coverage_winner=int(np.isclose(wins[j],wins.max(),rtol=1e-12,atol=1e-12)),
                               mean_time_winner=int(np.isclose(time[j],time.min(),rtol=1e-12,atol=1e-12))))
    return result


def main():
    fine = HERE/'budget_cells.csv.gz'
    line = HERE/'power_slice.csv'
    original = json.loads((HERE/'manifest.json').read_text())
    for p in (fine, line):
        assert digest(p)==original['outputs'][p.name]
    rows = []
    with gzip.open(fine,'rt',newline='') as f:
        reader = csv.DictReader(f)
        ratios = reader.fieldnames[4:]
        for (al, ah), group in groupby(reader, lambda r:(float(r['alpha_lo']),float(r['alpha_hi']))):
            intervals = [(float(r['beta_lo']), float(r['beta_hi']),
                          np.array([float(r[k]) for k in ratios])) for r in group]
            rows.extend(summarize(intervals, ratios, al, ah, 'map'))
    with line.open(newline='') as f:
        reference=list(csv.DictReader(f))
    intervals=[(float(a['beta']),float(b['beta']),np.array([float(a[k]) for k in ratios]))
               for a,b in pairwise(reference)]
    alpha=original['alpha_reference']
    rows.extend(summarize(intervals,ratios,alpha,alpha,'reference'))
    # The dashed slice and the map stripe it intersects must give identical results.
    inside=[r for r in rows if r['scope']=='map' and r['alpha_lo']<alpha<=r['alpha_hi']]
    selected=[r for r in rows if r['scope']=='reference']
    for a,b in zip(inside,selected,strict=True):
        assert a['ratio']==b['ratio'] and a['beta_lo']==b['beta_lo']
        np.testing.assert_allclose([a['win_share'],a['band_speedup']],
                                   [b['win_share'],b['band_speedup']],atol=1e-12)
    def save(path, block):
        with path.open('w',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=block[0],lineterminator='\n')
            writer.writeheader()
            writer.writerows(block)
    out=HERE/'budget_bands.csv'
    save(out,rows)
    report=[]
    for _, block in groupby(selected,lambda r:r['beta_lo']):
        group=list(block)
        common=[r for r in group if r['coverage_winner']]
        best=sorted(group,key=lambda r:-r['band_speedup'])
        assert len(common)==1
        report.append(dict(beta_lo=common[0]['beta_lo'],beta_hi=common[0]['beta_hi'],
                           coverage_winner=common[0]['ratio'],winning_fraction=common[0]['win_share'],
                           winner_band_speedup=common[0]['band_speedup'],
                           fastest_mean=best[0]['ratio'],fastest_speedup=best[0]['band_speedup'],
                           mean_lead_over_second=best[0]['band_speedup']/best[1]['band_speedup']-1))
    ref=HERE/'reference_bands.csv'
    save(ref,report)
    manifest=dict(inputs={p.name:digest(p) for p in (fine,line,Path(__file__))},
                  beta_step=.1, selection='maximum power-interval fraction at minimum GEMM time',
                  outputs={p.name:digest(p) for p in (out,ref)})
    (HERE/'bands_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()
