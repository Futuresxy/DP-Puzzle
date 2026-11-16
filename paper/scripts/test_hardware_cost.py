"""Budget feasibility, exact boundaries and unsupported-mode semantics."""
import unittest

from hardware_cost import deploy, load_profiles


class HardwareCostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles, _ = load_profiles()

    def rows(self, alpha='0.3', beta='1', **kwargs):
        return {r['ratio']: r for r in deploy(self.profiles, alpha, beta, **kwargs)}

    def test_baseline_exact_boundary(self):
        for alpha in ['0.1', '0.3', '0.4', '1']:
            r = self.rows(alpha)['1:2:4']
            self.assertEqual(r['installed_sms'], 36)
            self.assertEqual(r['binding_constraint'], 'both')
            self.assertAlmostEqual(r['mxfp8_e4m3_peak_tflops'], 589.824)

    def test_physical_count_is_common_to_all_modes(self):
        r = self.rows()['1:8:16']
        self.assertEqual(r['area_limited_sms'], 22)
        self.assertEqual(r['installed_sms'], 10)
        self.assertAlmostEqual(r['bf16_peak_tflops'], 81.92)
        self.assertAlmostEqual(r['mxfp8_e4m3_peak_tflops'], 655.36)
        self.assertAlmostEqual(r['mxfp4_e2m1_peak_tflops'], 1310.72)

    def test_budget_constraints_and_maximality(self):
        for alpha in ['0.2', '0.3', '0.5', '1']:
            for beta in ['0.01', '0.75', '1', '1.25', '1.5', '2.1', '100']:
                for r in self.rows(alpha, beta).values():
                    self.assertLessEqual(r['installed_area_mm2'], r['area_budget_mm2'] + 1e-9)
                    self.assertLessEqual(r['max_dp_power_w'], r['dp_power_budget_w'] + 1e-9)
                    n = r['installed_sms']
                    self.assertEqual(n, min(r['area_limited_sms'], r['power_limited_sms']))
                    self.assertTrue(n + 1 > r['area_limited_sms'] or n + 1 > r['power_limited_sms'])
                    for mode in ['bf16', 'mxfp8_e4m3', 'mxfp4_e2m1']:
                        p = r[mode + '_dp_power_w']
                        if p is not None:
                            self.assertLessEqual(p, r['dp_power_budget_w'] + 1e-9)

    def test_relaxing_power_never_reduces_deployment(self):
        previous = {ratio: 0 for ratio in self.rows()}
        for beta in ['0.5', '1', '1.25', '1.5', '2', '2.1', '100']:
            for ratio, r in self.rows(beta=beta).items():
                self.assertGreaterEqual(r['installed_sms'], previous[ratio])
                previous[ratio] = r['installed_sms']
                if beta == '100':
                    self.assertEqual(r['installed_sms'], r['area_limited_sms'])

    def test_unsupported_and_zero_deployment_are_distinct(self):
        r = self.rows(beta='0.0001')['0:0:4']
        self.assertFalse(r['feasible'])
        self.assertIsNone(r['bf16_peak_tflops'])
        self.assertIsNone(r['bf16_dp_power_w'])
        self.assertEqual(r['mxfp4_e2m1_peak_tflops'], 0)

    def test_topology_scaling_and_fixed_reference(self):
        a, b = self.rows(), self.rows(dp_per_sm=64)
        for ratio in a:
            self.assertEqual(a[ratio]['installed_sms'], b[ratio]['installed_sms'])
            self.assertAlmostEqual(a[ratio]['dp_power_reference_w'], 4*b[ratio]['dp_power_reference_w'])
        low = self.rows(beta='0.5')['1:2:4']
        self.assertEqual(low['installed_sms'], 18)
        self.assertAlmostEqual(low['dp_power_reference_w'], a['1:2:4']['dp_power_reference_w'])

    def test_invalid_parameters(self):
        for kwargs in [dict(alpha=0), dict(alpha=1.1), dict(beta=-1),
                       dict(beta='nan'), dict(baseline_sms=0), dict(dp_per_sm=2.5)]:
            with self.assertRaises(ValueError):
                self.rows(**kwargs)


if __name__ == '__main__':
    unittest.main()
