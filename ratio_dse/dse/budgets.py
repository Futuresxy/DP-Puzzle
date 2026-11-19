"""Integrate constant-throughput regions within the requested display bins."""
from itertools import pairwise

import numpy as np

from chip import bin_edges, number, service_times


def sweep(chip, demand, config):
    area = bin_edges(config['sweep']['alpha'])
    power = bin_edges(config['sweep']['beta'])
    ref = number(config['alpha'])
    if area[-1] > 1:
        raise ValueError('Area fractions cannot exceed 1')
    area_events = chip.area_events(area[0], area[-1])
    power_cache = {}
    cells, bands, reference = [], [], []
    domain_time = np.zeros(len(chip.ratios))
    domain_win = np.zeros_like(domain_time)
    for scope, alpha_bins in [('map', list(pairwise(area))), ('reference', [(ref,ref)])]:
        for al, ah in alpha_bins:
            intervals = list(pairwise([al] + [x for x in area_events if al<x<ah] + [ah]))
            shape = (len(power)-1,len(chip.ratios))
            times = np.zeros(shape)
            wins = np.zeros(shape)
            mins = np.full(shape,np.inf)
            maxs = np.zeros(shape)
            for left,right in intervals:
                area_weight = float((right-left)/(ah-al)) if ah>al else 1
                physical = tuple(chip.counts((left+right)/2))
                if physical not in power_cache:
                    steps = []
                    for bl,bh,rate in chip.power_intervals(physical,power[0],power[-1]):
                        t = service_times(demand,rate)
                        if not np.isfinite(t[chip.base]):
                            raise ValueError('Baseline cannot serve the sweep workload at this budget')
                        speed = t[chip.base]/t
                        lead = np.isclose(speed,speed.max(),rtol=1e-12,atol=0)
                        steps.append((bl,bh,t,speed,lead/lead.sum()))
                    power_cache[physical] = steps
                for bl,bh,t,speed,lead in power_cache[physical]:
                    cells.append(dict(scope=scope,alpha_lo=float(left),alpha_hi=float(right),
                                      beta_lo=float(bl),beta_hi=float(bh),**dict(zip(chip.ratios,speed))))
                    for j,(low,high) in enumerate(pairwise(power)):
                        overlap = min(high,bh)-max(low,bl)
                        if overlap<=0:
                            continue
                        w = area_weight*float(overlap/(high-low))
                        times[j] += w*t
                        wins[j] += w*lead
                        mins[j] = np.minimum(mins[j],speed)
                        maxs[j] = np.maximum(maxs[j],speed)
            np.testing.assert_allclose(wins.sum(axis=1),1,atol=1e-12,rtol=0)
            for j,(low,high) in enumerate(pairwise(power)):
                band_speed = times[j,chip.base]/times[j]
                coverage = np.isclose(wins[j],wins[j].max(),rtol=0,atol=1e-12)
                fastest = np.isclose(band_speed,band_speed.max(),rtol=1e-12,atol=0)
                for i,ratio in enumerate(chip.ratios):
                    bands.append(dict(scope=scope,alpha_lo=float(al),alpha_hi=float(ah),
                                      beta_lo=float(low),beta_hi=float(high),ratio=ratio,
                                      win_share=wins[j,i],band_speedup=band_speed[i],
                                      min_speedup=mins[j,i],max_speedup=maxs[j,i],
                                      coverage_winner=int(coverage[i]),mean_time_winner=int(fastest[i])))
                if scope=='map':
                    weight = float((ah-al)*(high-low)/((area[-1]-area[0])*(power[-1]-power[0])))
                    domain_time += weight*times[j]
                    domain_win += weight*wins[j]
                else:
                    # Keep all co-winners in the detailed table. Use CSV order for plotting ties.
                    i = np.flatnonzero(coverage)[0]
                    reference.append(dict(beta_lo=float(low),beta_hi=float(high),
                                          coverage_winner=chip.ratios[i],winning_fraction=wins[j,i],
                                          winner_band_speedup=band_speed[i],
                                          winner_min_speedup=mins[j,i],winner_max_speedup=maxs[j,i]))
    domains = [dict(ratio=r,ratio_of_mean_times=domain_time[chip.base]/domain_time[i],
                    winning_budget_fraction=domain_win[i]) for i,r in enumerate(chip.ratios)]
    return {'budget_bands':bands, 'reference_bands':reference, 'domain_scores':domains,
            'budget_cells':cells}
