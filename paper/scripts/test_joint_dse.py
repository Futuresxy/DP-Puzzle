"""Check the nine-ratio analysis against independent workload cost sums."""
import unittest
import numpy as np

from hardware_cost import deploy, full_precision_profiles, load_profiles
from reproduce_joint_dse import coefficients
from simplex import winner_regions, workload_grid


class JointDSETests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = full_precision_profiles(load_profiles()[0])

    def test_mode_power_and_workload_accounting(self):
        rows = deploy(self.profiles, '.3', '1.5')
        cap, power, coeff = coefficients(rows)
        work = np.array([2e12, 3e12, 5e12])
        t = coeff['time'] @ work / 1e12
        e = coeff['energy'] @ work / 1e12
        for i, row in enumerate(rows):
            stage_time = work / (cap[i] * 1e12)
            self.assertAlmostEqual(t[i], stage_time.sum())
            self.assertAlmostEqual(e[i], np.dot(stage_time, power[i]))
            self.assertLessEqual(e[i]/t[i], row['dp_power_budget_w'] + 1e-9)

    def test_energy_invariance_and_delay_changes(self):
        a = coefficients(deploy(self.profiles, '.3', '1'))[2]
        b = coefficients(deploy(self.profiles, '.3', '2.1'))[2]
        np.testing.assert_allclose(a['energy'], b['energy'], rtol=1e-12)
        self.assertFalse(np.allclose(a['time'], b['time']))

    def test_region_partition_and_vertices(self):
        for beta in ['1', '1.5', '2.1']:
            for costs in coefficients(deploy(self.profiles, '.3', beta))[2].values():
                regions = winner_regions(costs)
                self.assertAlmostEqual(sum(r['fraction'] for r in regions), 1)
                for r in regions:
                    if r['fraction'] > 1e-9:
                        values = np.array(r['vertices_hqe']) @ costs.T
                        self.assertTrue(np.all(values[:, r['index']] <= values.min(axis=1) + 1e-9))
        self.assertEqual(len(workload_grid(100)), 5151)

    def test_zero_core_scenario_rejected(self):
        with self.assertRaises(ValueError):
            coefficients(deploy(self.profiles, '.3', '.0001'))


if __name__ == '__main__':
    unittest.main()
