"""Build per-operator work from the released shapes, then apply precision migrations."""
from bisect import bisect_left
from collections import Counter
import csv
from itertools import groupby
import json

import numpy as np

from chip import positive_integer
from deepseek_v41 import load_config, prefill_work

PRECISIONS = ('BF16', 'FP8', 'FP4', 'FP32')


def migration_maps(path, selected):
    spec = json.loads(path.read_text())
    groups = spec['groups']
    owners = {}
    for group, kernels in groups.items():
        if not isinstance(kernels, list) or not kernels:
            raise ValueError(f'Expected a nonempty kernel list for {group}')
        for kernel in kernels:
            if kernel in owners:
                raise ValueError(f'Kernel assigned twice: {kernel}')
            owners[kernel] = group
    resolved = {}
    for scenario in spec['scenarios']:
        name, parent = scenario['id'], scenario.get('parent')
        if not name or name == 'All' or name in resolved or (parent is not None and parent not in resolved):
            raise ValueError(f'Invalid/duplicate scenario ID or undeclared parent: {name}')
        mapping = resolved[parent].copy() if parent is not None else {}
        for group, mode in scenario['changes'].items():
            if group not in groups or mode not in PRECISIONS[:3]:
                raise ValueError(f'Invalid change {group}={mode} in {name}')
            mapping.update(dict.fromkeys(groups[group], mode))
        resolved[name] = mapping
    if not selected or len(set(selected)) != len(selected) or not set(selected) <= resolved.keys():
        raise ValueError(f'Expected distinct defined scenarios, got {selected}')
    return owners, {s: resolved[s] for s in selected}


def read_operator_ledger(path, lengths):
    """Replay one complete batch-1 prefill per requested length, one block at a time."""
    seen = set()
    with path.open(newline='') as stream:
        reader = csv.DictReader(stream)
        required = {'context', 'phase', 'segment', 'layer_id', 'batch', 'kernel', 'precision', 'flops'}
        missing = required.difference(reader.fieldnames or ())
        if missing:
            raise ValueError(f'Operator ledger missing columns: {sorted(missing)}')
        for length, block in groupby(reader, key=lambda row: positive_integer(row['context'])):
            if length not in lengths:
                continue
            if length in seen:
                raise ValueError(f'Keep operator ledger rows for context {length} together')
            seen.add(length)
            operators = []
            keys = set()
            for row in block:
                key = (row['segment'], int(row['layer_id']), row['kernel'])
                if not key[0] or not key[2]:
                    raise ValueError(f'Missing segment or kernel at context {length}')
                if key in keys:
                    raise ValueError(f'Duplicate operator at context {length}: {key}')
                keys.add(key)
                if row['phase'] != 'prefill' or positive_integer(row['batch']) != 1:
                    raise ValueError(f'Expected batch-1 prefill at context {length}: {key}')
                row['flops'] = int(row['flops'])
                if row['flops'] < 0 or row['precision'] not in PRECISIONS:
                    raise ValueError(f'Invalid FLOPs or native precision at context {length}: {key}')
                del row['context']
                operators.append(row)
            yield length, operators
    missing_lengths = sorted(lengths - seen)
    if missing_lengths:
        raise ValueError(f'Operator ledger lacks {len(missing_lengths)} requested lengths '
                         f'(first: {missing_lengths[0]}). Supply these rows or omit operator_ledger '
                         'to calculate them from the model.')


def mapped(counts, mapping):
    totals = dict.fromkeys(PRECISIONS, 0)
    for (op, native), flops in counts.items():
        totals[mapping.get(op, native)] += flops
    return [totals[m] for m in PRECISIONS]


def work_inputs(config, paths, methods):
    contexts = [positive_integer(n) for n in config['contexts']]
    model = load_config(paths['model'])
    if not contexts or contexts != sorted(set(contexts)) or contexts[-1] > model.max_context:
        raise ValueError('Bin edges must increase strictly within the model context limit')
    groups, stages = migration_maps(paths['migrations'], config['scenarios'])
    histogram = {}
    with paths['trace'].open(newline='') as stream:
        for row in csv.DictReader(stream):
            n, count = positive_integer(row['input_tokens']), positive_integer(row['requests'])
            if n in histogram or n > contexts[-1]:
                raise ValueError(f'Duplicate or out-of-range input length: {n}')
            histogram[n] = count
    if not histogram:
        raise ValueError('Empty request histogram')
    total = sum(histogram.values())
    bin_counts = [0]*len(contexts)
    for n,count in histogram.items():
        bin_counts[bisect_left(contexts,n)] += count
    weights = [dict(upper_tokens=n,requests=count,weight=count/total)
               for n,count in zip(contexts,bin_counts)]

    sums = {m: Counter() for m in methods}
    bins = dict(zip(contexts, bin_counts))
    lengths = set(contexts)
    if 'observed' in sums:
        lengths.update(histogram)
    if 'operator_ledger' in paths:
        batches = read_operator_ledger(paths['operator_ledger'], lengths)
    else:
        batches = ((n, prefill_work(n, config=model)) for n in sorted(lengths))
    layer_operators, operators, cases, assignments = [], [], [], set()
    for n, rows in batches:
        counts = Counter()
        for row in rows:
            counts[row['kernel'], row['precision']] += row['flops']
        if n in bins:
            layer_operators.extend({'context': n, **row} for row in rows)
            for (op, native), flops in sorted(counts.items()):
                operators.append(dict(context=n,kernel=op,native_precision=native,flops=flops))
                for stage,mapping in stages.items():
                    assignments.add((stage,op,native,groups.get(op,''),mapping.get(op,native)))
            for stage,mapping in stages.items():
                h,q,e,excluded = mapped(counts,mapping)
                cases.append(dict(scenario=stage,context=n,H_flops=h,Q_flops=q,E_flops=e,
                                  excluded_fp32_flops=excluded))
        for method, counter in sums.items():
            count = (bins if method == 'upper_edge' else histogram).get(n, 0)
            if count:
                counter.update({key: flops*count for key,flops in counts.items()})
    seen = {row['kernel'] for row in operators}
    if groups.keys() - seen:
        raise ValueError(f'Migration mentions unknown kernels: {sorted(groups.keys()-seen)}')
    work = {}
    demand = []
    for method, counter in sums.items():
        result = []
        for stage, mapping in stages.items():
            h,q,e,excluded = mapped(counter,mapping)
            result.append([h/total,q/total,e/total])
            demand.append(dict(length_method=method,scenario=stage,requests=total,
                               H_mean_flops=h/total,Q_mean_flops=q/total,E_mean_flops=e/total,
                               excluded_fp32_mean_flops=excluded/total))
        work[method] = np.array(result)
    columns = ('scenario','kernel','native_precision','migration_group','compute_precision')
    return work, {'context_weights':weights, 'layer_operators':layer_operators,
                  'operator_flops':operators, 'cases':cases,
                  'scenario_operators':[dict(zip(columns,r)) for r in sorted(assignments)],
                  'weighted_work':demand}
