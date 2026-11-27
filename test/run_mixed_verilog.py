#!/usr/bin/env python3
"""Verify each mixed DP snapshot against CModel and independent math goldens.

The maintained Verilog TB checks L8, atomic ready, bubbles, reset and every result
bit. S5/S6/S7 cutpoints additionally check participation, coordinates and reduction.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import sys

import run_verilog as shared
from adapters.cmodel import ROOT, evaluate
from adapters.rtl import snapshot, record_validation
from cases.common import make, random_request
from cases.mixed import PROFILES, corpus, extended, poison_inactive, groups_for_profile
from dp_rtl_gate import DEFAULT_SCOPE, MIXED_CONFIGS
from reference.exact import DTYPES, reference
from cases.mixed_v19 import directed as v19_directed


def expand(request, profile):
    """Replicate valid group-local fields; native corpus separately varies groups."""
    if not extended(profile, request['a_datatype']):
        return poison_inactive(request, profile)
    result=dict(request)
    groups=groups_for_profile(profile)
    for field,bits in [('a',64),('b',64),('a_scale',8),('b_scale',8),
                       ('a_e1',4),('b_e1',4),('a_e2',2),('b_e2',2)]:
        value=int(request[field],16)
        for group_index in range(4,groups):
            value |= ((value >> (bits*(group_index-4))) & ((1<<bits)-1)) << (bits*group_index)
        result[field]=format(value,'x')
    return result


def compile_tb(profile, local, glob):
    build=shared.RUN/f'build-l{local}-g{glob}'
    build.mkdir(parents=True,exist_ok=True)
    top='dp_top_'+profile
    flags=['--language','1364-2005']
    defines=['-DDP_ARCH_V19']
    if profile == 't8h16q64e64':
        defines += ['-DDP_Q_ONLY_EXTENSION']
    elif profile in ('t8h16q64e128_opt', 't8h16q96e192', 't8h16q128e256'):
        defines += ['-DDP_QE_EXTENSION']
    shared.run([shared.VERILATOR,'--lint-only','-Wall','-Wno-UNUSEDSIGNAL','-Wno-UNUSEDPARAM',
                '-Wno-VARHIDDEN',*flags,'--top-module',top,'-f',str(shared.SOURCE_LIST),
                f'-GLOCAL_W={local}',f'-GGLOBAL_W={glob}'],build/'lint.log')
    shared.run([shared.VERILATOR,'--binary','--timing','-j','4',*flags,
                '-Wno-WIDTH','-Wno-TIMESCALEMOD','-Wno-INITIALDLY',*defines,
                f'-DDP_MIXED_TOP={top}',f"-DDP_MIXED_GROUPS={groups_for_profile(profile)}",
                '--top-module','dp_tb','--Mdir',str(build),
                f'-GLOCAL_W={local}',f'-GGLOBAL_W={glob}',
                '-I'+str(shared.EXPORT/'src/src/verilog/parameter'),
                '-I'+str(ROOT/'test/rtl_tb'),'-f',str(shared.SOURCE_LIST),
                str(ROOT/'test/rtl_tb/dp_mixed_tb.v')],build/'compile.log')
    return build/'Vdp_tb'


def q_only_switching_requests(profile):
    """Exercise Q extension state while consecutive E requests bypass it."""
    requests=[]
    # E4M3 NaN and E5M2 Inf must be masked on the next E request. The
    # finite FP6 maxima also exercise extension exponent/scale state.
    q_codes={'mxfp8_e4m3':0x7f, 'mxfp8_e5m2':0x7c,
             'mxfp6_e3m2':0x1f, 'mxfp6_e2m3':0x1f}
    for q_mode,code in q_codes.items():
        q_request=expand(make(q_mode,a=[code]*32),profile)
        # Only the upper four groups contribute, making lost Q work visible.
        q_request['a']=format(int(q_request['a'],16)&~((1<<256)-1),'x')
        for e_mode in shared.E_MODES:
            e_nonzero=poison_inactive(make(e_mode),profile)
            e_negative_zero=poison_inactive(
                make(e_mode,a=[8]*64,c=0x80000000),profile)
            requests.extend([dict(q_request),e_nonzero,dict(q_request),e_negative_zero])
    # A finite Q extension with a large scale must not win the E request's
    # global MAX, even when no special flag could otherwise hide the error.
    q_large_scale=expand(make('mxfp8_e4m3',sa=[254],sb=[254]),profile)
    q_large_scale['a']=format(int(q_large_scale['a'],16)&~((1<<256)-1),'x')
    for e_mode in shared.E_MODES:
        requests.extend([dict(q_large_scale),poison_inactive(make(e_mode),profile)])
    return requests


def bf16_cancellation_requests(profile):
    """Move the same residual across group boundaries, then stress S6."""
    requests=[]
    for ident, positions, residual_exponent in (
        (0, (0, 1, 2), -28),  # All terms in one group: S3 can lose the residual.
        (1, (0, 4, 8), -28),  # Separate groups: the S6 default window retains it.
        (2, (0, 4, 8), -40),  # Separate groups: S6 can lose the smaller residual.
    ):
        elements=[0]*16
        for index,value in zip(positions,(0x3f80,0xbf80,(127+residual_exponent)<<7)):
            elements[index]=value
        requests.append(poison_inactive(make('bf16',a=elements,ident=ident),profile))
    return requests


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frontend',choices=PROFILES,required=True)
    parser.add_argument('--verilator',default=os.environ.get('VERILATOR','verilator'))
    parser.add_argument('--bf16-only',action='store_true',
                        help='run BF16 corpus and cancellation probes with S3–S7 cutpoint checks')
    parser.add_argument('--local-w',type=int,default=DEFAULT_SCOPE[1],help='S3 unsigned window')
    parser.add_argument('--global-w',type=int,default=DEFAULT_SCOPE[2],help='S6 signed window')
    args=parser.parse_args()
    k,local,glob=DEFAULT_SCOPE[0],args.local_w,args.global_w
    custom=(k,local,glob)!=DEFAULT_SCOPE
    if custom and not args.bf16_only:
        parser.error('custom windows require --bf16-only')
    if local<27 or glob<max(local+4,33):
        parser.error('require LOCAL_W >= 27 and GLOBAL_W >= max(LOCAL_W+4, 33)')
    started=datetime.now(timezone.utc).isoformat()
    shared.FRONTEND=args.frontend
    shared.VERILATOR=args.verilator
    shared.RUN=ROOT/'test/runs/verilog'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    shared.RUN.mkdir(parents=True)
    shared.EXPORT,shared.SOURCE_LIST=snapshot('verilog',args.frontend,diagnostic=args.bf16_only)
    records=[]
    print(f'{args.frontend}: L8 / II=1, base K{k}, windows {local}/{glob}',flush=True)
    exe=compile_tb(args.frontend,local,glob)
    config=dict(frontend=args.frontend,architecture_v19=args.frontend in shared.V19_PROFILES,
                k_fp16=k,local_shift_mag_width=local,global_signed_align_width=glob)
    for mode,requests,golden in corpus(args.frontend):
        if args.bf16_only and mode!='bf16':
            continue
        expected=evaluate(requests,config=config,trace=args.bf16_only,run_dir=shared.RUN/'model')
        for result,golden_row in zip(expected,golden):
            result['exact_fp32_or_int32']=golden_row['exact_fp32_or_int32']
        records.append(shared.campaign(mode,k,local,glob,requests,exe,
                                       expected=expected,observe=args.bf16_only))
        max_ulp=records[-1]['max_ulp']
        if not custom and max_ulp is not None and max_ulp>4:
            raise AssertionError('native corpus exceeds 4 ULP')
        if args.bf16_only:
            break
    if args.bf16_only:
        requests=bf16_cancellation_requests(args.frontend)
        expected=evaluate(requests,config=config,trace=True,run_dir=shared.RUN/'model')
        for result,request in zip(expected,requests):
            result['exact_fp32_or_int32']=f'{reference(request,config)["bits"]:08x}'
        records.append(shared.campaign('bf16-cancellation',k,local,glob,requests,exe,
                                       expected=expected,observe=True))
        summary=shared.RUN/'verilator-verilog-bf16-summary.json'
        summary.write_text(json.dumps(records,indent=2)+'\n')
        print(f'Report: {summary.relative_to(ROOT)}',flush=True)
        return
    rng=random.Random(20271105)
    requests=[expand(random_request(mode,rng,16),args.frontend) for _ in range(48) for mode in DTYPES]
    # Directed nibble/scale/metadata/cancellation/FP32 C edges exercise all groups.
    requests += [expand(req,args.frontend) for req in shared.e_directed(16)]
    requests.append(poison_inactive(make('fp16',a=[0x8000]*16,b=[0]*16,c=0x80000000),args.frontend))
    for update in [dict(b_datatype=2),dict(a_datatype=15,b_datatype=15),dict(c_datatype=1),
                   dict(a_scale_datatype=3),dict(b_scale_datatype=1)]:
        bad=make('fp16');bad.update(update);requests.append(bad)
    # Hold a special token in extension registers, then bypass it on high precision.
    for low_mode,code in [('nvfp4',7),('hif4',7),('mxfp8_e5m2',0x7c)]:
        if not extended(args.frontend,DTYPES[low_mode]): continue
        for index in range(4):
            low=expand(make(low_mode,a=[code]*(64 if DTYPES[low_mode]>=7 else 32)),args.frontend)
            low['a']='%x'%(int(low['a'],16)&~((1<<256)-1))
            requests.extend([low,poison_inactive(make('fp16'),args.frontend)])
    if args.frontend in shared.V19_PROFILES: requests += v19_directed(args.frontend)
    if args.frontend == 't8h16q64e64': requests += q_only_switching_requests(args.frontend)
    for index,request in enumerate(requests): request.update(id=index,last=index%7==0)
    for k,local,glob in MIXED_CONFIGS:
        records.append(shared.campaign(f'mixed-k{k}-l{local}-g{glob}',k,local,glob,requests,
                                        exe if (local,glob)==(28,40) else compile_tb(args.frontend,local,glob),stress=True))
    fingerprint=hashlib.sha256(Path(__file__).read_bytes()+(ROOT/'test/rtl_tb/dp_mixed_tb.v').read_bytes()).hexdigest()
    record_validation(shared.EXPORT,records,fingerprint,phase='all',started=started,run_dir=shared.RUN,
                      backend_scope=True,command=[sys.executable,*sys.argv],
                      simulator_version=subprocess.check_output([args.verilator,'--version'],text=True).strip())
    summary=shared.RUN/'verilator-verilog-all-summary.json'
    summary.write_text(json.dumps(records,indent=2)+'\n')
    print(f'Report: {summary.relative_to(ROOT)}',flush=True)

if __name__=='__main__': main()
