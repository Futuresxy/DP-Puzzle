"""Rebuild prompt-length histograms from the publishers' request records."""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import csv
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import subprocess
import struct
import tempfile

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

ROOT = Path(__file__).resolve().parent
AZURE_URL = ("https://github.com/Azure/AzurePublicDataset/releases/download/"
             "dataset-llm-2024/AzureLLMInferenceTrace_conv_1week.csv")
AZURE_PREFIX_HASH = '9282b479288546f171d598be4a480189b8e3409b8b9e18f6363baaa09550d1ab'
HF_REV = 'bb26cf72c9c20f2b05f765d88548156a74d3c253'
AGENT_URL = (f'https://huggingface.co/datasets/harvardMadsys/freeinference_agentic_trace/resolve/{HF_REV}/'
             'release/2026-08-30_2026-09-05/processed/requests.parquet')
AGENT_SIZE = 1817646481
AGENT_ETAG = 'e8f4f987f00442348ac09b1d6dc8865cf3dde299944423d54402f620244d3a6a'


def write_counts(name, counts, output):
    path = output / (name + '_histogram.csv')
    expected = json.loads((ROOT / 'trace_manifest.json').read_text())['histograms'][name]
    handle = io.StringIO(newline='')
    with handle:
        writer = csv.writer(handle, lineterminator='\n')
        writer.writerow(['input_tokens', 'requests'])
        writer.writerows(sorted(counts.items()))
        data = handle.getvalue().encode('ascii')
    if hashlib.sha256(data).hexdigest() != expected['sha256']:
        raise ValueError(f'{name} derived histogram mismatch')
    path.write_bytes(data)


def azure(handle, output):
    digest = hashlib.sha256()
    header = handle.readline()
    if header.rstrip() != b'TIMESTAMP,ContextTokens,GeneratedTokens':
        raise ValueError('Unexpected Azure CSV header')
    digest.update(header)
    counts = Counter()
    start = datetime.fromisoformat('2024-05-12T00:00:00+00:00')
    stop = start.replace(hour=6)
    for line in handle:
        timestamp, context, _ = line.rstrip().split(b',')
        time = datetime.fromisoformat(timestamp.decode())
        if time >= stop:
            break
        if time < start or int(context) <= 0:
            raise ValueError('Invalid record in Azure capture window')
        digest.update(line)
        counts[int(context)] += 1
    else:
        raise ValueError('Trace ended before right-hand boundary')
    if digest.hexdigest() != AZURE_PREFIX_HASH:
        raise ValueError('Azure source prefix hash mismatch')
    write_counts('azure_chat', counts, output)


def byte_range(start, end):
    session = requests.Session()
    retry = Retry(total=3, backoff_factor=1, status_forcelist=(429, 500, 502, 503, 504))
    session.mount('https://', HTTPAdapter(max_retries=retry))
    with session, session.get(AGENT_URL, params={'offset':start, 'end':end},
                              headers={'Range': f'bytes={start}-{end-1}'},
                              timeout=90, stream=True) as response:
        response.raise_for_status()
        expected = f'bytes {start}-{end-1}/{AGENT_SIZE}'
        if response.status_code != 206 or response.headers.get('Content-Range') != expected:
            raise ValueError('Server did not return requested range')
        data = response.content
        if len(data) != end-start:
            raise ValueError('Incomplete source range')
        return data


def agent_from_parquet(path, output):
    import pyarrow.parquet as pq

    table = pq.ParquetFile(path)
    groups = {'agent_calls':Counter(), 'agent_first':Counter()}
    eligible = Counter()
    invalid = Counter()
    digest = hashlib.sha256()
    for batch in table.iter_batches(columns=['step','prompt_tokens']):
        steps = batch.column('step').to_pylist()
        prompts = batch.column('prompt_tokens').to_pylist()
        for step, tokens in zip(steps, prompts):
            digest.update(f'{step},{tokens}\n'.encode())
            for name in (['agent_calls', 'agent_first'] if step==0 else ['agent_calls']):
                eligible[name] += 1
                if tokens is None or tokens <= 0:
                    invalid[name] += 1
                else:
                    groups[name][tokens] += 1
    expected = json.loads((ROOT / 'trace_manifest.json').read_text())['sources']['freeinference']
    if digest.hexdigest() != expected['ordered_projection_sha256']:
        raise ValueError('Prompt and step column projection hash mismatch')
    for name, counts in groups.items():
        write_counts(name, counts, output)
        print(name, 'eligible', eligible[name], 'invalid', invalid[name],
              'included', sum(counts.values()), 'min', min(counts), 'max', max(counts))
    print('ordered step,prompt_tokens projection SHA-256', digest.hexdigest())


def agent_remote(output):
    import pyarrow.parquet as pq

    # The footer contains the row groups and offsets of each column chunk.
    tail = byte_range(AGENT_SIZE-65536, AGENT_SIZE)
    if tail[-4:] != b'PAR1':
        raise ValueError('Missing Parquet trailer')
    length = struct.unpack('<I', tail[-8:-4])[0]+8
    footer = tail[-length:] if length <= len(tail) else byte_range(AGENT_SIZE-length, AGENT_SIZE)
    meta = pq.ParquetFile(io.BytesIO(b'PAR1'+footer)).metadata
    intervals = []
    for i in range(meta.num_row_groups):
        group = meta.row_group(i)
        columns = [group.column(j) for j in range(group.num_columns)]
        bounds = [(c.dictionary_page_offset if c.has_dictionary_page else c.data_page_offset,
                   c.total_compressed_size) for c in columns if c.path_in_schema in ('step','prompt_tokens')]
        if len(bounds)!=2:
            raise ValueError('Missing required prompt or step column')
        intervals.append((min(x for x,_ in bounds), max(x+n for x,n in bounds)))
    with tempfile.TemporaryFile() as sparse, ThreadPoolExecutor(max_workers=6) as pool:
        sparse.write(b'PAR1')
        sparse.seek(AGENT_SIZE-length)
        sparse.write(footer)
        def fetch(bounds):
            return byte_range(*bounds)
        for (start,_), chunk in zip(intervals, pool.map(fetch, intervals)):
            sparse.seek(start)
            sparse.write(chunk)
        sparse.seek(0)
        agent_from_parquet(sparse, output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', choices=['azure', 'agent'])
    parser.add_argument('--local', type=Path, help='Publisher CSV or complete Parquet file')
    parser.add_argument('--output', type=Path, default=ROOT)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.trace == 'azure':
        if args.local:
            with args.local.open('rb') as handle:
                azure(handle, args.output)
        else:
            # The last requested line is the first invocation at the cutoff.
            command = ['curl', '--fail', '--location', '--silent', '--show-error',
                       '--connect-timeout', '20', '--max-time', '180',
                       '--range', '0-21400126', AZURE_URL]
            with subprocess.Popen(command, stdout=subprocess.PIPE) as transfer:
                try:
                    azure(transfer.stdout, args.output)
                finally:
                    # Some HTTP mirrors ignore ranges. Stop after the verified prefix.
                    if transfer.poll() is None:
                        transfer.terminate()
    elif args.local:
        with args.local.open('rb') as handle:
            if hashlib.file_digest(handle, 'sha256').hexdigest() != AGENT_ETAG:
                raise ValueError('Full source file hash mismatch')
        agent_from_parquet(args.local, args.output)
    else:
        agent_remote(args.output)
