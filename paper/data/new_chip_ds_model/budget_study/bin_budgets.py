"""Integrate exact compute-budget cells over area/power bins and a fixed-area slice."""
import csv
import gzip
import hashlib
import json
from itertools import pairwise
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
AREA = np.arange(25, 51) / 100
POWER = np.arange(10, 21) / 10


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def aggregate(cells, area_edges, ratios, scope, reference=None):
    """Weight each exact cell by its overlap with the target rectangle."""
    shape = (len(area_edges) - 1, len(POWER) - 1, len(ratios))
    wins = np.zeros(shape)
    times = np.zeros(shape)
    minima = np.full(shape, np.inf)
    maxima = np.zeros(shape)
    coverage = np.zeros(shape[:2])
    for al, ah, bl, bh, speed in cells:
        # The reference has a unit dummy area interval. Only power varies there.
        a = np.maximum(0, np.minimum(area_edges[1:], ah) - np.maximum(area_edges[:-1], al))
        b = np.maximum(0, np.minimum(POWER[1:], bh) - np.maximum(POWER[:-1], bl))
        weights = np.outer(a / np.diff(area_edges), b / np.diff(POWER))
        i, j = np.nonzero(weights)
        w = weights[i, j, None]
        leaders = np.isclose(speed, speed.max(), rtol=1e-12, atol=0)
        wins[i, j] += w * leaders / leaders.sum()
        times[i, j] += w / speed
        minima[i, j] = np.minimum(minima[i, j], speed)
        maxima[i, j] = np.maximum(maxima[i, j], speed)
        coverage[i, j] += weights[i, j]
    np.testing.assert_allclose(coverage, 1, atol=1e-12, rtol=0)
    np.testing.assert_allclose(wins.sum(axis=-1), 1, atol=1e-12, rtol=0)
    np.testing.assert_allclose(times[:, :, ratios.index('1:2:4')], 1, atol=1e-12, rtol=0)
    rows = []
    for i, (al, ah) in enumerate(pairwise(area_edges)):
        for j, (bl, bh) in enumerate(pairwise(POWER)):
            top_share = wins[i, j].max()
            best_time = times[i, j].min()
            for k, ratio in enumerate(ratios):
                rows.append(dict(scope=scope, alpha_lo=al if reference is None else reference,
                                 alpha_hi=ah if reference is None else reference,
                                 beta_lo=bl, beta_hi=bh, ratio=ratio, win_share=wins[i, j, k],
                                 band_speedup=1 / times[i, j, k],
                                 min_speedup=minima[i, j, k], max_speedup=maxima[i, j, k],
                                 coverage_winner=int(np.isclose(wins[i, j, k], top_share, rtol=0, atol=1e-12)),
                                 mean_time_winner=int(np.isclose(times[i, j, k], best_time, rtol=0, atol=1e-12))))
    return rows


def save(path, rows):
    with path.open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=rows[0], lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def main():
    fine = HERE / 'budget_cells.csv.gz'
    line = HERE / 'power_slice.csv'
    domain = HERE / 'domain_scores.csv'
    original = json.loads((HERE / 'manifest.json').read_text())
    for source in (fine, line, domain):
        assert digest(source) == original['outputs'][source.name]
    with gzip.open(fine, 'rt', newline='') as f:
        reader = csv.DictReader(f)
        ratios = reader.fieldnames[4:]
        bounds = reader.fieldnames[:4]
        cells = [(*[float(r[key]) for key in bounds], np.array([float(r[k]) for k in ratios]))
                 for r in reader]
    grid = aggregate(cells, AREA, ratios, 'map')
    with domain.open() as f:
        for row in csv.DictReader(f):
            sampled = [r for r in grid if r['ratio'] == row['ratio']]
            np.testing.assert_allclose(np.mean([r['win_share'] for r in sampled]),
                                       float(row['winning_budget_fraction']), rtol=0, atol=1e-12)
            np.testing.assert_allclose(1 / np.mean([1/r['band_speedup'] for r in sampled]),
                                       float(row['ratio_of_mean_times']), rtol=0, atol=1e-12)

    with line.open() as f:
        points = list(csv.DictReader(f))
    slices = [(0, 1, float(a['beta']), float(b['beta']), np.array([float(a[k]) for k in ratios]))
              for a, b in pairwise(points)]
    alpha = original['alpha_reference']
    unit = np.array([0, 1])
    selected = aggregate(slices, unit, ratios, 'reference', alpha)
    # Validate the exact slice independently against the fine two-dimensional scan.
    cut = [(0, 1, bl, bh, s) for al, ah, bl, bh, s in cells if al < alpha <= ah]
    exact = aggregate(cut, unit, ratios, 'reference', alpha)
    keys = ['win_share', 'band_speedup', 'min_speedup', 'max_speedup']
    for a, b in zip(selected, exact, strict=True):
        np.testing.assert_allclose([a[k] for k in keys], [b[k] for k in keys], rtol=0, atol=1e-12)
    report = []
    for bl, bh in pairwise(POWER):
        band = [r for r in selected if r['beta_lo'] == bl]
        winner, = [r for r in band if r['coverage_winner']]
        best, second, *_ = sorted(band, key=lambda r: -r['band_speedup'])
        map_winner, = [r for r in grid if r['beta_lo'] == bl and r['alpha_lo'] <= alpha < r['alpha_hi']
                       and r['coverage_winner']]
        report.append(dict(beta_lo=bl, beta_hi=bh, coverage_winner=winner['ratio'],
                           winning_fraction=winner['win_share'], winner_band_speedup=winner['band_speedup'],
                           winner_min_speedup=winner['min_speedup'], winner_max_speedup=winner['max_speedup'],
                           grid_column_winner=map_winner['ratio'],
                           fastest_mean=best['ratio'], fastest_speedup=best['band_speedup'],
                           mean_lead_over_second=best['band_speedup']/second['band_speedup']-1))
    out = HERE / 'budget_bands.csv'
    ref = HERE / 'reference_bands.csv'
    save(out, grid + selected)
    save(ref, report)
    manifest = dict(inputs={p.name: digest(p) for p in (fine, line, domain, Path(__file__))},
                    alpha_step=.01, beta_step=.1, alpha_reference=alpha,
                    selection='largest winning fraction under uniform area and power within a bin',
                    outputs={p.name: digest(p) for p in (out, ref)})
    (HERE / 'bands_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
