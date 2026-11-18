"""Preview Fig. 4 with FreeInference request frequencies and upper-edge context lengths."""
import argparse
import json
from pathlib import Path
import tempfile

import numpy as np

from figures import COLUMN_WIDTH, configure, heatmap, read
from run import OUT, TRACE, ev


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUT / 'trace_case_preview')
    output = parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    configure(Path(tempfile.gettempdir()) / 'dp-puzzle-dac2027-mpl')

    study = json.loads((OUT / 'manifest.json').read_text())
    for path in (ev.CONFIG, ev.EVIDENCE / 'cases.csv'):
        if ev.digest(path) != study['inputs'][str(path.relative_to(ev.PAPER))]:
            raise ValueError(f'Input differs from the frozen budget study: {path}')
    config = json.loads(ev.CONFIG.read_text())
    hardware, ratios, capacity = ev.hardware(config)
    stages = [stage['id'] for stage in config['scenarios']]
    core_counts = {ratio: {} for ratio in ratios}
    mode_names = dict(zip(ev.MODES, ('BF16', 'MXFP8', 'MXFP4')))
    for row in hardware:
        counts = core_counts[row['ratio']]
        counts['physical'] = row['physical_cores']
        counts['active_' + mode_names[row['mode']]] = row['active_cores']

    # Assign each request its bin's upper edge; the first bin includes lengths below 1K.
    bins = read(OUT, study, 'upper_edge_weights.csv')
    assert [int(b['upper_tokens']) for b in bins] == config['contexts']
    frequency = [int(b['requests']) for b in bins]
    assert sum(frequency) == study['requests']
    grid = {(row['scenario'], int(row['context'])):
            [float(row[mode + '_flops']) for mode in ev.LETTERS]
            for row in ev.csv_rows(ev.EVIDENCE / 'cases.csv')}
    work = np.array([np.average([grid[stage, length] for length in config['contexts']],
                                axis=0, weights=frequency) for stage in stages])
    scores = []
    ev.add_scores(scores, TRACE, 'upper_edge', work, capacity, ratios, stages)
    indexed = {(r['ratio'], r['scenario']): r for r in scores}
    rows = []
    for ratio in ratios:
        for stage in [*stages, 'All']:
            row = indexed[ratio, stage]
            rows.append(dict(ratio=ratio, scenario=stage, mean_seconds=row['mean_seconds'],
                             speedup=row['speedup'], rank=row['rank'], **core_counts[ratio]))
    ev.write_csv(output / 'upper_edge_lengths.csv', rows)
    heatmap(rows, output / 'upper_edge_lengths.pdf', COLUMN_WIDTH)


if __name__ == '__main__':
    main()
