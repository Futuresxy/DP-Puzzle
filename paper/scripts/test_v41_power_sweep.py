import unittest

import numpy as np

from hardware_cost import deploy, full_precision_profiles, load_profiles
from v41_power_sweep import arrays, continuous_deploy, e_crossover


class StrictPowerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = full_precision_profiles(load_profiles()[0])

    def test_continuous_relaxation_bounds_integer_and_satisfies_budgets(self):
        for alpha in ['.2','.3','.4']:
            for beta in ['.5','1','1.5','2.1']:
                rows = deploy(self.profiles,alpha,beta)
                relaxed = continuous_deploy(rows)
                for physical, diagnostic in zip(rows,relaxed):
                    count = diagnostic['installed_sms']
                    self.assertGreaterEqual(count+1e-12,physical['installed_sms'])
                    self.assertLess(count,physical['installed_sms']+1+1e-12)
                    self.assertLessEqual(count*physical['sm_area_mm2'],physical['area_budget_mm2']*(1+1e-12))
                    per_sm = physical['max_dp_power_w']/physical['installed_sms']
                    self.assertLessEqual(count*per_sm,physical['dp_power_budget_w']*(1+1e-12))

    def test_power_limited_capacity_scales_with_beta_not_alpha(self):
        reference,_ = arrays(continuous_deploy(deploy(self.profiles,'.3','.5')))
        for alpha in ['.2','.3','.4']:
            capacity,_ = arrays(continuous_deploy(deploy(self.profiles,alpha,'.75')))
            np.testing.assert_allclose(capacity,reference*1.5,rtol=1e-12)

    def test_deployment_scaling_preserves_mode_energy_per_flop(self):
        rows = deploy(self.profiles,'.3','1')
        ci,pi = arrays(rows)
        cc,pc = arrays(continuous_deploy(rows))
        np.testing.assert_allclose(pi/ci,pc/cc,rtol=1e-12)

    def test_e_crossover_has_correct_times_on_both_sides(self):
        first=np.array([24.,48.,288.]);second=np.array([19.,38.,304.])
        for residual_h in [0.,.2,1.]:
            boundary=e_crossover(first,second,residual_h)
            def time_difference(e):
                work=np.array([(1-e)*residual_h,(1-e)*(1-residual_h),e])
                return np.sum(work/first)-np.sum(work/second)
            self.assertAlmostEqual(time_difference(boundary),0,places=14)
            self.assertLess(time_difference(boundary-.01),0)
            self.assertGreater(time_difference(boundary+.01),0)

    def test_modewise_dominance_implies_all_nonnegative_work_slower(self):
        rows=deploy(self.profiles,'.3','1')
        cap,_=arrays(rows)
        lookup={r['ratio']:i for i,r in enumerate(rows)}
        small=cap[lookup['1:4:8']];large=cap[lookup['1:8:16']]
        self.assertTrue(np.all(small>=large*(1-1e-12)))
        work=np.random.default_rng(20261116).dirichlet([1,1,1],size=100)
        self.assertTrue(np.all(work@(1/small)<work@(1/large)))


if __name__=='__main__': unittest.main()
