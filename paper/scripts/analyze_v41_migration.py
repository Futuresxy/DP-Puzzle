"""Rank migration targets using the frozen CED prefill operator ledger.

This summarizes existing analytical work; it does not assign quality tolerances
or change the published precision policies and plots.
"""
import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from hardware_cost import deploy, load_profiles

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'data/evidence/v41_portfolio_20261116/operator_work.csv'
OUTPUT = ROOT/'data/evidence/v41_migration_review_20261116'
MODE = {'BF16':'bf16', 'FP8':'mxfp8_e4m3', 'FP4':'mxfp4_e2m1'}


def group(kernel):
    if kernel.startswith('moe.routed.'):
        return 'routed_experts'
    if kernel.startswith('moe.shared.'):
        return 'shared_experts'
    if kernel in ('q_up','o_final'):
        return 'q_up_o_up'
    if kernel in ('q_down','swa_kv','index.q_projection'):
        return 'q_down_swa_kv_index_q'
    if kernel == 'o_group':
        return 'grouped_o_down'
    if kernel in ('swa.qk','swa.pv','global.qk','global.pv'):
        return 'main_attention_qk_pv'
    if kernel in ('index.full_qk','index.candidate_qk'):
        return 'index_dot_products'
    if kernel == 'engram.projection':
        return 'engram_projection'
    if kernel.startswith('global_kv.'):
        return 'global_kv_projection_and_gate'
    return 'other'


def main():
    source = list(csv.DictReader(SOURCE.open()))
    baseline = next(r for r in deploy(load_profiles()[0],'.3','1.5') if r['ratio']=='1:2:4')
    capacity = {p:baseline[m+'_peak_tflops']*1e12 for p,m in MODE.items()}
    kernels, totals, hqe_times = defaultdict(int), defaultdict(int), defaultdict(float)
    for row in source:
        context, flops = int(row['context']), int(row['flops'])
        kernels[(context,row['kernel'],row['precision'])] += flops
        totals[context] += flops
        if row['precision'] in capacity:
            hqe_times[context] += flops/capacity[row['precision']]
    rows, groups = [], defaultdict(lambda: {'flops':0,'seconds':0.,'precisions':set()})
    for (context,kernel,precision),flops in sorted(kernels.items()):
        seconds = flops/capacity[precision] if precision in capacity else None
        rows.append(dict(context=context,kernel=kernel,precision=precision,group=group(kernel),flops=flops,
                         total_gemm_flop_share=flops/totals[context],
                         baseline_hqe_time_share=seconds/hqe_times[context] if seconds is not None else None))
        record=groups[(context,group(kernel))]
        record['flops']+=flops
        record['seconds']+=seconds or 0
        record['precisions'].add(precision)
    summaries=[]
    for (context,name),record in sorted(groups.items()):
        summaries.append(dict(context=context,group=name,precisions='|'.join(sorted(record['precisions'])),
            flops=record['flops'],total_gemm_flop_share=record['flops']/totals[context],
            baseline_hqe_time_share=record['seconds']/hqe_times[context]))
    for context in totals:
        assert sum(r['flops'] for r in summaries if r['context']==context)==totals[context]
        assert abs(sum(r['baseline_hqe_time_share'] for r in summaries if r['context']==context)-1)<1e-12
    OUTPUT.mkdir(parents=True,exist_ok=True)
    for name,data in [('operators',rows),('groups',summaries)]:
        with (OUTPUT/f'{name}.csv').open('w',newline='') as stream:
            writer=csv.DictWriter(stream,fieldnames=list(data[0]),lineterminator='\n')
            writer.writeheader();writer.writerows(data)
    def fingerprint(path):
        return dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    manifest=dict(status='analytical_uncalibrated',scope='Frozen V4.1 CED cold prefill, batch 1, 11 contexts',
        flop_denominator='All GEMM FLOPs in ledger, including FP32; excludes non-GEMM operations',
        time_denominator='Baseline 1:2:4 ideal HQE compute service time, alpha=0.3 beta=1.5; excludes FP32',
        validation='All operator FLOPs partitioned; HQE time fractions sum to one for every context',
        inputs=[fingerprint(p) for p in [SOURCE,Path(__file__),ROOT/'scripts/hardware_cost.py',ROOT/'data/DP_area_power/dp11_area_power_fixed_20261116.csv']],
        outputs=[fingerprint(OUTPUT/f'{n}.csv') for n in ['operators','groups']])
    (OUTPUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for row in summaries:
        if row['context'] in (1024,65536,1048576):
            print(row['context'],row['group'],f"{100*row['total_gemm_flop_share']:.2f}% FLOPs",f"{100*row['baseline_hqe_time_share']:.2f}% HQE time")


if __name__=='__main__':
    main()
