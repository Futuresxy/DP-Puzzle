"""Core-only migration isolation and routed-utilization accounting."""
import json
import unittest

import numpy as np

import deepseek_v41 as v41
from costs import mapped_work
from hardware_cost import MODES, deploy, full_precision_profiles, load_profiles
from v41_core import CONFIG, evaluate, family, map_work, summarize
from v41_portfolio import portfolio_metrics


class CoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config=json.loads(CONFIG.read_text())
        cls.scenarios={s['id']:s for s in cls.config['scenarios']}
        cls.ledger=v41.prefill_work(16384)
        rows=deploy(full_precision_profiles(load_profiles()[0]),'.3','1.5')
        cls.capacity=np.array([[r[m+'_peak_tflops'] for m in MODES] for r in rows])
        cls.power=np.array([[r[m+'_dp_power_w'] for m in MODES] for r in rows])

    def mapped(self,case):
        return map_work(self.ledger,self.scenarios[case])

    def test_original_and_routed_migration_match_previous_ledger(self):
        for case,profile in [('A','reference_work'),('B','nvfp4_experts')]:
            f,r,excluded,_,_=self.mapped(case)
            previous,excluded_previous,_=mapped_work('DeepSeek-V4.1-Flash','prefill',16384,profile)
            np.testing.assert_allclose(f,[previous[0],previous[1],previous[2]+previous[3]])
            self.assertEqual(excluded,excluded_previous)
            self.assertAlmostEqual(r.sum(),sum(x['flops'] for x in self.ledger if x['kernel'].startswith('moe.routed.')))

    def test_background_kept_and_branch_composition(self):
        # Even the aggressive F case retains non-migrating BF16/FP8 work.
        background=np.zeros(3)
        for row in self.ledger:
            if not family(row['kernel']) and row['precision'] in ('BF16','FP8','FP4'):
                background[('BF16','FP8','FP4').index(row['precision'])]+=row['flops']
        f=self.mapped('F')[0]
        np.testing.assert_allclose(f[:2],background[:2])
        self.assertGreater(f[0],0);self.assertGreater(f[1],0)
        b,c,d,e=[self.mapped(x)[0] for x in 'BCDE']
        np.testing.assert_allclose(e-b,(c-b)+(d-b))

    def test_conservation_all_contexts_and_cases(self):
        for context in self.config['contexts']:
            ledger=v41.prefill_work(context)
            total=sum(r['flops'] for r in ledger)
            for scenario in self.scenarios.values():
                f,r,excluded,core,index=map_work(ledger,scenario)
                self.assertAlmostEqual(f.sum()+excluded,total)
                self.assertTrue(np.all(f>=r))
                self.assertGreater((core+index)/total,.93)

    def test_utilization_changes_routed_service_only(self):
        f,r,*_=self.mapped('B')
        t,e=evaluate(f,r,self.capacity,self.power,{'q':1,'e':1})
        slow,no_energy=evaluate(f,r,self.capacity,self.power,{'q':1,'e':.5})
        np.testing.assert_allclose(slow-t,r@(1/self.capacity).T/1e12)
        self.assertIsNone(no_energy)
        self.assertTrue(np.all(e>0))
        f,r,*_=self.mapped('A')
        a,_=evaluate(f,r,self.capacity,self.power,{'q':1,'e':1})
        b,_=evaluate(f,r,self.capacity,self.power,{'q':1,'e':.5})
        np.testing.assert_array_equal(a,b)

    def test_summary_preserves_previous_fixed_chip_metrics(self):
        times=np.array([[1.,2.],[3.,2.]])
        energies=np.array([[2.,1.],[3.,4.]])
        report=summarize(times,energies,[.4,.6])
        previous=portfolio_metrics(times,energies,[.4,.6])
        for key in ['worst_regret','mean_slowdown','mean_seconds','mean_dp_energy_j','minimax','pareto']:
            np.testing.assert_allclose(report[key],previous[key])
        report=summarize(times,None,[.4,.6])
        self.assertIsNone(report['mean_dp_energy_j'])

    def test_invalid_utilization_fails(self):
        f,r,*_=self.mapped('B')
        for value in [0,-1,1.1,float('nan')]:
            with self.assertRaises(ValueError):evaluate(f,r,self.capacity,self.power,{'q':1,'e':value})


if __name__=='__main__':unittest.main()
