"""Independent checks of fixed-design selection and operator migration."""
import itertools
import json
import unittest

import numpy as np

from costs import mapped_work
from hardware_cost import deploy, full_precision_profiles, load_profiles, MODES
from v41_portfolio import CONFIG, policy_work, portfolio_metrics, distribution_weights, pareto_mask
import deepseek_v41 as v41


class PortfolioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.switches = json.loads(CONFIG.read_text())['precision_switches']
        cls.ledger = v41.prefill_work(8192)

    def test_matches_existing_reference_and_expert_endpoint(self):
        for bits, profile in [([0]*5, 'reference_work'), ([1,0,0,0,0], 'nvfp4_experts')]:
            work, excluded = policy_work(self.ledger, self.switches, bits)
            previous, previous_excluded, _ = mapped_work('DeepSeek-V4.1-Flash','prefill',8192,profile)
            np.testing.assert_allclose(work, [previous[0],previous[1],previous[2]+previous[3]])
            self.assertEqual(excluded, previous_excluded)

    def test_only_selected_family_moves_and_work_is_conserved(self):
        before, excluded = policy_work(self.ledger, self.switches, [0]*5)
        after, excluded_after = policy_work(self.ledger, self.switches, [.25,0,0,0,0])
        moved = sum(r['flops'] for r in self.ledger if r['kernel'].startswith('moe.routed.'))*.25
        np.testing.assert_allclose(after-before,[0,-moved,moved],atol=1e-3)
        self.assertEqual(excluded, excluded_after)
        for bits in itertools.product((0,1), repeat=5):
            self.assertAlmostEqual(policy_work(self.ledger,self.switches,bits)[0].sum(),before.sum())

    def test_majority_wins_is_not_fixed_design_selection(self):
        times = np.array([[1,2],[1,2],[100,1]])
        report = portfolio_metrics(times,np.ones_like(times),[1,1,1])
        self.assertEqual(list(report['minimax']),[False,True])
        np.testing.assert_allclose(report['worst_regret'],[99,1])
        np.testing.assert_allclose(report['mean_seconds'],[34,5/3])

    def test_scale_invariance_of_regret_not_request_time(self):
        times = np.array([[2.,3.],[5.,4.]])
        before = portfolio_metrics(times,times,[1,1])
        after = portfolio_metrics(times*[[100],[1]],times,[1,1])
        np.testing.assert_allclose(before['worst_regret'],after['worst_regret'])
        self.assertFalse(np.allclose(before['mean_seconds'],after['mean_seconds']))

    def test_request_weighting_uses_flops_not_mean_fractions(self):
        work = np.array([[1,0,0],[0,100,0]])
        costs = np.array([[1,2,1],[2,1,1]])
        q = np.array([.5,.5])
        report = portfolio_metrics(work@costs.T,np.ones((2,2)),q)
        np.testing.assert_allclose(report['mean_seconds'],(q@work)@costs.T)
        self.assertEqual(report['mean_seconds'].argmin(),1)

    def test_continuous_migration_regret_bounded_by_endpoints(self):
        rows = deploy(full_precision_profiles(load_profiles()[0]),'.3','1.5')
        costs = 1/np.array([[r[m+'_peak_tflops'] for m in MODES] for r in rows])
        endpoints = np.array([policy_work(self.ledger,self.switches,bits)[0]
                              for bits in itertools.product((0,1),repeat=5)])@costs.T
        bound = (endpoints/endpoints.min(axis=1,keepdims=True)).max(axis=0)
        rng = np.random.default_rng(20261116)
        for fractions in rng.random((40,5)):
            values = policy_work(self.ledger,self.switches,fractions)[0]@costs.T
            self.assertTrue(np.all(values/values.min() <= bound+1e-10))

    def test_distributions_and_pareto(self):
        for name in ['balanced','short','long']:
            weights = distribution_weights([1024,2048,4096],name)
            self.assertAlmostEqual(weights.sum(),1)
        self.assertGreater(distribution_weights([1,2],'short')[0],.5)
        self.assertGreater(distribution_weights([1,2],'long')[1],.5)
        np.testing.assert_array_equal(pareto_mask([[1,2],[2,1],[3,3],[1,2]]),[True,True,False,True])

    def test_invalid_inputs_fail(self):
        for fractions in [[0]*4,[0,0,0,0,2],[0,0,0,0,float('nan')]]:
            with self.assertRaises(ValueError):
                policy_work(self.ledger,self.switches,fractions)
        with self.assertRaises(ValueError):
            policy_work(self.ledger,self.switches+[self.switches[0]],[0]*6)
        for weights in [[0,0],[-1,2],[float('nan'),1]]:
            with self.assertRaises(ValueError):
                portfolio_metrics([[1,2],[2,1]],[[1,1],[1,1]],weights)


if __name__ == '__main__':
    unittest.main()
