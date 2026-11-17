"""Plot deployment counts beside the existing five-stage case-study scores."""
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

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/evidence/v41_five_stage_20261117'
OUTPUT = ROOT / 'data/evidence/v41_case_panels_overlay_20261118'
FIGURE = ROOT / 'figures/temp/v41_case_panels_overlay.pdf'


def fingerprint(path):
    return {'path': str(path.relative_to(ROOT)),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def read_verified(name, manifest):
    path = SOURCE / (name + '.csv')
    assert fingerprint(path) in manifest['outputs'], f'Changed source: {name}'
    with path.open() as stream:
        return list(csv.DictReader(stream))


def main():
    source_manifest = json.loads((SOURCE / 'manifest.json').read_text())
    hardware = read_verified('hardware', source_manifest)
    gains = read_verified('gains', source_manifest)
    scenarios = [s['id'] for s in source_manifest['config']['scenarios']]
    columns = scenarios + ['All']
    ratios = [h['ratio'] for h in hardware]
    area = np.array([int(h['area_only_cores']) for h in hardware])
    joint = np.array([int(h['cores']) for h in hardware])
    assert np.all(joint <= area)
    matrix = np.array([[float(next(g['speedup'] for g in gains
                                  if g['ratio'] == ratio and g['scenario'] == s))
                        for s in columns] for ratio in ratios])
    np.testing.assert_allclose(matrix[ratios.index('1:2:4')], 1)

    plt.rcParams.update({'font.family': 'serif', 'font.serif': ['DejaVu Serif'],
                         'font.size': 7.5, 'pdf.fonttype': 42})
    fig = plt.figure(figsize=(3.49, 2.65))
    grid = fig.add_gridspec(1, 2, width_ratios=[1, 1.75], left=.16,
                           right=.99, bottom=.24, top=.80, wspace=.10)
    bars = fig.add_subplot(grid[0])
    heat = fig.add_subplot(grid[1], sharey=bars)
    y = np.arange(len(ratios))
    area_color, joint_color = '#d5d8dc', '#3c5488'
    bars.barh(y, area, height=.78, color=area_color,
              edgecolor='#858b92', linewidth=.4)
    bars.barh(y, joint, height=.50, color=joint_color)
    for i, (na, nj) in enumerate(zip(area, joint)):
        if na != nj:
            bars.text(na+.7, i, str(na), ha='left', va='center',
                      fontsize=6.8, color='#50565c')
        bars.text(nj-.7, i, str(nj), ha='right', va='center',
                  fontsize=6.8, color='white')
    bars.set(ylim=(len(ratios)-.5, -.5), xlim=(0, 40),
             yticks=y, yticklabels=ratios, xticks=[0, 20, 40])
    bars.set_xlabel('Core count', labelpad=2)
    bars.tick_params(axis='y', length=0, pad=3, labelsize=7)
    bars.tick_params(axis='x', length=2, pad=2, labelsize=7)
    bars.set_axisbelow(True)
    bars.grid(axis='x', color='#dddddd', linewidth=.4)
    for spine in ('top', 'right'):
        bars.spines[spine].set_visible(False)
    bars.set_title('(a) Deployment', fontsize=8, pad=6)
    fig.legend(handles=[Patch(facecolor=area_color, edgecolor='#858b92', label='Area only'),
                        Patch(facecolor=joint_color, label='Area + power')],
               loc='upper center', bbox_to_anchor=(.56, .98), ncol=2,
               frameon=False, fontsize=7.5, handlelength=1, columnspacing=1.2)

    lower = min(.9, np.floor(matrix.min()*10)/10)
    upper = max(1.1, np.ceil(matrix.max()*10)/10)
    norm = TwoSlopeNorm(vmin=lower, vcenter=1, vmax=upper)
    im = heat.pcolormesh(np.arange(len(columns)+1)-.5, np.arange(len(ratios)+1)-.5,
                        matrix, cmap='RdBu', norm=norm, shading='flat', rasterized=False)
    heat.set(xlim=(-.5, len(columns)-.5), ylim=(len(ratios)-.5, -.5),
             xticks=np.arange(len(columns)), xticklabels=columns)
    heat.tick_params(axis='y', left=False, labelleft=False)
    heat.tick_params(axis='x', length=0, pad=3, labelsize=7.5)
    heat.set_title('(b) Compute speedup', fontsize=8, pad=6)
    heat.axvline(len(columns)-1.5, color='white', linewidth=1.5)
    for i in range(len(ratios)):
        for j in range(len(columns)):
            value = matrix[i, j]
            heat.text(j, i, f'{value:.2f}', ha='center', va='center', fontsize=6.8,
                      color='white' if norm(value) < .16 or norm(value) > .87 else '#202020')
            if np.isclose(value, matrix[:, j].max(), rtol=1e-12):
                heat.add_patch(Rectangle((j-.46, i-.46), .92, .92, fill=False,
                                         edgecolor='#161616', linewidth=.9))
    box = heat.get_position()
    cax = fig.add_axes([box.x0, .115, box.width, .025])
    bar = fig.colorbar(im, cax=cax, orientation='horizontal', ticks=[lower, 1, upper])
    bar.solids.set_rasterized(False)
    bar.ax.tick_params(labelsize=7, pad=1, length=2)
    bar.set_label('Relative to 1:2:4', fontsize=7, labelpad=2)
    bar.ax.get_xticklabels()[0].set_ha('left')
    bar.ax.get_xticklabels()[-1].set_ha('right')
    FIGURE.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGURE, metadata={'CreationDate': None, 'ModDate': None})
    plt.close(fig)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        'status': 'analytical_uncalibrated', 'scope': 'Temporary Chinese Chapter V only',
        'inputs': [fingerprint(p) for p in (Path(__file__), SOURCE/'manifest.json',
                                          SOURCE/'hardware.csv', SOURCE/'gains.csv')],
        'outputs': [fingerprint(FIGURE)], 'config': source_manifest['config'],
        'panels': {'a': 'Overlaid counts: gray area-only and blue joint-budget deployment; equal counts labeled once',
                   'b': 'Joint-budget modeled GEMM speedup; each column winner outlined'},
        'checks': {'source_hashes_verified': True, 'joint_count_not_above_area_count': True,
                   'baseline_speedup_one': True, 'design_rows': len(ratios),
                   'count_values': len(ratios)*2,
                   'count_labels': len(ratios)+int(np.count_nonzero(area != joint)),
                   'heatmap_cells': matrix.size},
        'interpretation': 'Same model, budgets, workloads and scores as the five-stage source; no new experiment.'
    }
    (OUTPUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps(manifest['checks'], indent=2))


if __name__ == '__main__':
    main()
