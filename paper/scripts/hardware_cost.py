"""Size homogeneous SM pools under joint area and DP power budgets.

All installed SMs may run concurrently in every supported measured mode.
Outputs are analytical peaks at the measured clock, not GEMM latency or TDP.
"""
import argparse
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from fractions import Fraction
from pathlib import Path

PAPER = Path(__file__).resolve().parents[1]
DATA = PAPER / 'data/DP_area_power/dp11_area_power_fixed_20261116.sources.json'
MODES = {'bf16': 'h_native', 'mxfp8_e4m3': 'q_native', 'mxfp4_e2m1': 'e_native'}


def positive(value):
    number = Fraction(str(value))
    if number <= 0:
        raise ValueError('Expected a finite positive number')
    return number


def load_profiles(metadata_path=DATA):
    metadata_path = Path(metadata_path)
    metadata = json.loads(metadata_path.read_text())
    csv_path = metadata_path.parent / metadata['csv']
    payload = csv_path.read_bytes()
    if hashlib.sha256(payload).hexdigest() != metadata['csv_sha256']:
        raise ValueError('Frozen hardware CSV checksum mismatch')
    conditions = metadata['conditions']
    frequency = positive(conditions['frequency_hz'])
    ii = positive(conditions['initiation_interval_cycles'])
    profiles = []
    with csv_path.open(newline='') as stream:
        for row in csv.DictReader(stream):
            modes = {}
            capacities = []
            for mode, field in MODES.items():
                native_k = int(row[field])
                capacities.append(native_k)
                power = row[mode + '_total_mw']
                if native_k < 0 or (native_k > 0) != bool(power):
                    raise ValueError('Capacity and supported power mode disagree')
                if native_k:
                    modes[mode] = {'native_k': native_k, 'power_w': positive(power) / 1000}
            if not modes or any(k % 16 for k in capacities):
                raise ValueError('Invalid HQE capacities')
            if row['ratio'] != ':'.join(str(k // 16) for k in capacities):
                raise ValueError('Ratio disagrees with capacities')
            profiles.append({'ratio': row['ratio'], 'capacity': row['capacity'],
                             'top': row['top'], 'area_um2': positive(row['area_um2']),
                             'modes': modes, 'frequency_hz': frequency, 'ii': ii})
    if len({p['ratio'] for p in profiles}) != len(profiles):
        raise ValueError('Duplicate ratio')
    if len(profiles) != metadata['design_count']:
        raise ValueError('Design count disagrees with frozen manifest')
    if sum(len(p['modes']) for p in profiles) != metadata['measured_power_points']:
        raise ValueError('Measured point count disagrees with frozen manifest')
    return profiles, metadata


def deploy(profiles, alpha, beta, baseline_sms=36, dp_per_sm=256):
    """Calibrate common budgets from 1:2:4, then size each physical design.

    Alpha sweeps recalibrate the area budget while holding baseline SM count.
    Beta scales the original baseline reference, never an already capped pool.
    Fractions prevent an exact integer budget boundary losing one SM to rounding.
    """
    alpha, beta = positive(alpha), positive(beta)
    if alpha > 1:
        raise ValueError('Alpha must be in (0, 1]')
    if any(type(v) is not int or v < 1 for v in (baseline_sms, dp_per_sm)):
        raise ValueError('SM and DP counts must be positive integers')
    baseline = next(p for p in profiles if p['ratio'] == '1:2:4')
    baseline_tensor_area = dp_per_sm * baseline['area_um2']
    baseline_sm_area = baseline_tensor_area / alpha
    peripheral_area = baseline_sm_area - baseline_tensor_area
    area_budget = baseline_sms * baseline_sm_area
    power_reference = baseline_sms * dp_per_sm * max(
        m['power_w'] for m in baseline['modes'].values())
    power_budget = beta * power_reference
    rows = []
    for p in profiles:
        tensor_area = dp_per_sm * p['area_um2']
        sm_area = peripheral_area + tensor_area
        worst_mode = max(p['modes'], key=lambda m: p['modes'][m]['power_w'])
        sm_power = dp_per_sm * p['modes'][worst_mode]['power_w']
        area_limit, power_limit = area_budget // sm_area, power_budget // sm_power
        installed = min(area_limit, power_limit)
        constraint = ('both' if area_limit == power_limit else
                      'area' if area_limit < power_limit else 'power')
        row = dict(alpha=float(alpha), beta=float(beta), ratio=p['ratio'],
                   capacity=p['capacity'], top=p['top'], baseline_sms=baseline_sms,
                   dp_per_sm=dp_per_sm, frequency_hz=float(p['frequency_hz']),
                   ii_cycles=float(p['ii']), area_budget_mm2=float(area_budget / 10**6),
                   dp_power_reference_w=float(power_reference), dp_power_budget_w=float(power_budget),
                   peripheral_area_per_sm_mm2=float(peripheral_area / 10**6),
                   tensor_area_per_sm_mm2=float(tensor_area / 10**6),
                   sm_area_mm2=float(sm_area / 10**6),
                   tensor_area_fraction=float(tensor_area / sm_area),
                   area_limited_sms=area_limit, power_limited_sms=power_limit,
                   installed_sms=installed, installed_dps=installed * dp_per_sm,
                   feasible=installed > 0, binding_constraint=constraint,
                   worst_measured_power_mode=worst_mode,
                   installed_area_mm2=float(installed * sm_area / 10**6),
                   unused_area_mm2=float((area_budget - installed * sm_area) / 10**6),
                   max_dp_power_w=float(installed * sm_power),
                   unused_dp_power_w=float(power_budget - installed * sm_power),
                   beta_for_area_full_deployment=float(area_limit * sm_power / power_reference),
                   status='analytical_uncalibrated')
        for mode in MODES:
            info = p['modes'].get(mode)
            row[mode + '_supported'] = info is not None
            row[mode + '_peak_tflops'] = (float(2 * installed * dp_per_sm * info['native_k']
                * p['frequency_hz'] / p['ii'] / 10**12) if info else None)
            row[mode + '_dp_power_w'] = (float(installed * dp_per_sm * info['power_w'])
                                        if info else None)
        rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--alpha', nargs='+', default=['0.3'])
    parser.add_argument('--beta', nargs='+', required=True,
                        help='Explicit budget scenarios, e.g. 1 1.25 1.5 2 2.1')
    parser.add_argument('--baseline-sms', type=int, default=36)
    parser.add_argument('--dp-per-sm', type=int, default=256)
    parser.add_argument('--output', type=Path, required=True,
                        help='New output directory; existing directories are rejected')
    args = parser.parse_args()
    profiles, metadata = load_profiles()
    alphas = list(dict.fromkeys(positive(v) for v in args.alpha))
    betas = list(dict.fromkeys(positive(v) for v in args.beta))
    rows = [row for alpha in alphas for beta in betas for row in
            deploy(profiles, alpha, beta, args.baseline_sms, args.dp_per_sm)]
    args.output.mkdir(parents=True, exist_ok=False)
    output = args.output / 'hardware_cost.csv'
    with output.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    manifest = {
        'model': 'joint_area_power_physical_sm_sizing_v1',
        'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'command': [sys.executable, *sys.argv],
        'status': 'analytical_uncalibrated',
        'parameters': {'alpha': list(map(float, alphas)), 'beta': list(map(float, betas)),
                       'baseline_sms': args.baseline_sms, 'dp_per_sm': args.dp_per_sm},
        'area_budget_policy': 'Recalibrate from fixed baseline SM count for each alpha; common to all ratios within that alpha.',
        'power_budget_policy': 'Beta times original baseline maximum across three measured modes; common to all ratios and modes.',
        'deployment_policy': 'One physical SM count satisfies both budgets in every supported measured mode; all installed SMs may compute.',
        'assumptions': ['Ideal operand supply and full compute utilization.',
                        'Fixed peripheral area per SM within each alpha scenario.',
                        'Measured DP area used as tensor area proxy; no extra array characterization.',
                        'DP power only; no peripheral, memory or interconnect power.',
                        'Measured window-average activity power proxy, not instantaneous worst-case power.',
                        'Only BF16, MXFP8 E4M3 and MXFP4 E2M1 covered; other supported formats uncharacterized.',
                        'Unsupported modes are null/blank, not zero; workloads requiring them are infeasible.',
                        'Unused area is not automatically repurposed. No DVFS or runtime core disabling.'],
        'source_metadata': metadata,
        'model_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'output': {'path': output.name, 'rows': len(rows),
                   'sha256': hashlib.sha256(output.read_bytes()).hexdigest()},
    }
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Wrote {len(rows)} deployments to {output}')


if __name__ == '__main__':
    main()
