"""Physical core counts, precision-dependent active cores and exact budget events."""
import csv
from fractions import Fraction
from itertools import pairwise

import numpy as np

MODES = ('BF16', 'MXFP8', 'MXFP4')
K_FIELDS = ('h_native', 'q_native', 'e_native')
POWER_FIELDS = ('bf16_total_mw', 'mxfp8_e4m3_total_mw', 'mxfp4_e2m1_total_mw')


def number(value):
    return Fraction(str(value))


def positive_integer(value):
    n = number(value)
    if n.denominator != 1 or n < 1:
        raise ValueError(f'Expected a positive integer, got {value!r}')
    return int(n)


def bin_edges(spec):
    low, high, step = map(number, spec)
    if not 0 < low < high or step <= 0:
        raise ValueError(f'Invalid sweep [start, stop, step]: {spec}')
    count = -((low - high) // step)
    return [low + step * i for i in range(count)] + [high]


class Chip:
    def __init__(self, path, cfg):
        with path.open(newline='') as stream:
            rows = list(csv.DictReader(stream))
        self.ratios = [r['ratio'] for r in rows]
        if len(set(self.ratios)) != len(rows) or cfg['baseline'] not in self.ratios:
            raise ValueError('Hardware needs unique ratio labels and the configured baseline')
        self.base = self.ratios.index(cfg['baseline'])
        self.n0 = positive_integer(cfg['baseline_cores'])
        self.d = positive_integer(cfg['dp_per_core'])
        self.area = [number(r['area_um2']) for r in rows]
        self.on = [[number(r[f]) for f in POWER_FIELDS] for r in rows]
        self.idle = [number(r['idle_mw']) for r in rows]
        rates = []
        for j, row in enumerate(rows):
            if self.area[j] <= 0 or not 0 <= self.idle[j] < min(self.on[j]):
                raise ValueError(f'Invalid area or active/idle mW for {self.ratios[j]}')
            f, ii = number(row['frequency_hz']), positive_integer(row['ii_cycles'])
            if f <= 0:
                raise ValueError('frequency_hz must be positive')
            rates.append([float(2 * self.d * f * positive_integer(row[k]) / ii) for k in K_FIELDS])
        self.rate = np.array(rates)
        # In mW per DP position: multiply by D/1000 to recover the array budget in W.
        self.reference = self.n0 * max(self.on[self.base])

    def counts(self, alpha):
        if not 0 < alpha <= 1:
            raise ValueError('alpha must be in (0,1]')
        return [self.n0 // (1 + alpha * (a / self.area[self.base] - 1)) for a in self.area]

    def active(self, physical, beta):
        if beta <= 0:
            raise ValueError('beta must be positive')
        budget = beta * self.reference
        return np.array([[max(0, min(n, (budget - n * self.idle[j]) // (on - self.idle[j])))
                          for on in self.on[j]] for j, n in enumerate(physical)], dtype=int)

    def hardware(self, alpha, beta):
        physical = self.counts(alpha)
        active = self.active(physical, beta)
        rows = []
        for j, ratio in enumerate(self.ratios):
            n = physical[j]
            for p, mode in enumerate(MODES):
                k = int(active[j,p])
                used = self.d * (n*self.idle[j] + k*(self.on[j][p]-self.idle[j])) / 1000
                rows.append(dict(ratio=ratio, mode=mode, physical=n, active=k,
                                 area_budget_mm2=float(self.d*self.n0*self.area[self.base]/alpha/10**6),
                                 dp_area_um2=float(self.area[j]), dp_idle_mw=float(self.idle[j]),
                                 dp_active_mw=float(self.on[j][p]), array_power_w=float(used),
                                 array_budget_w=float(self.d*beta*self.reference/1000),
                                 idle_budget_feasible=int(n*self.idle[j] <= beta*self.reference),
                                 tflops=k*self.rate[j,p]/1e12))
        return rows, physical, active

    def area_events(self, lo, hi):
        events = {lo, hi}
        lower_counts, upper_counts = self.counts(lo), self.counts(hi)
        for j, area in enumerate(self.area):
            delta = area / self.area[self.base] - 1
            if not delta:
                continue
            bounds = sorted((lower_counts[j], upper_counts[j]))
            for n in range(max(1, bounds[0]), bounds[1]+1):
                at = (Fraction(self.n0,n)-1)/delta
                if lo < at < hi:
                    events.add(at)
        return sorted(events)

    def power_intervals(self, physical, lo, hi):
        # Only the thresholds that change the integral have nonzero measure.
        active = self.active(physical, lo)
        end = self.active(physical, hi)
        events = {lo: [], hi: []}
        for j,n in enumerate(physical):
            for p,on in enumerate(self.on[j]):
                for k in range(active[j,p]+1, end[j,p]+1):
                    at = (n*self.idle[j]+int(k)*(on-self.idle[j])) / self.reference
                    events.setdefault(at, []).append((j,p,k))
        for start,stop in pairwise(sorted(events)):
            for j,p,k in events[start]:
                active[j,p] = k
            yield start, stop, active*self.rate


def service_times(work, rates):
    """Return seconds per design. An unavailable mode matters only if demanded."""
    demand = np.asarray(work)
    positive = demand > 0
    if not positive.any():
        raise ValueError('No modeled GEMM work in this workload')
    valid = (rates[:,positive] > 0).all(axis=1)
    times = np.full(len(rates), np.inf)
    times[valid] = (demand[positive] / rates[valid][:,positive]).sum(axis=1)
    return times
