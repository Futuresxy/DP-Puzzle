import json
from pathlib import Path
import tempfile
import unittest

from workload import work_inputs


class OperatorLedgerTest(unittest.TestCase):
    def test_imported_work_drives_request_weighting_and_precision_migration(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            paths = {name: root / name for name in ('operator_ledger', 'trace', 'migrations')}
            paths['model'] = Path(__file__).resolve().parents[1] / 'inputs/deepseek_v41_flash.json'
            paths['operator_ledger'].write_text(
                'context,phase,segment,layer_id,batch,kernel,precision,flops\n'
                '1024,prefill,encoder_prefill,0,1,q_down,FP8,20\n'
                '2048,prefill,encoder_prefill,0,1,q_down,FP8,40\n'
                '2048,prefill,encoder_prefill,1,1,q_down,FP8,60\n'
            )
            paths['trace'].write_text('input_tokens,requests\n800,3\n1400,1\n')
            paths['migrations'].write_text(json.dumps({
                'groups': {'query': ['q_down']},
                'scenarios': [{'id': 'A', 'changes': {}},
                              {'id': 'B', 'parent': 'A', 'changes': {'query': 'FP4'}}],
            }))
            config = {'contexts': [1024, 2048], 'scenarios': ['A', 'B']}
            work, tables = work_inputs(config, paths, ['upper_edge'])
            self.assertEqual(len(tables['layer_operators']), 3)
            self.assertEqual([r['flops'] for r in tables['operator_flops']], [20, 100])
            self.assertEqual(work['upper_edge'].tolist(), [[0, 40, 0], [0, 0, 40]])
            with self.assertRaisesRegex(ValueError, 'lacks.*800'):
                work_inputs(config, paths, ['observed'])
