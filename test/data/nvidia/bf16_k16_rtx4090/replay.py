#!/usr/bin/env python3
"""Replay the DP BF16 K16 corpus using SM 8.9 Tensor Cores."""

import argparse
from collections import Counter
import csv
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
TEST = HERE.parents[2]
sys.path.insert(0, str(TEST))
from adapters.cmodel import ROOT, read_inputs, sha256
from cases.common import make
from reference.exact import DTYPES, reference, ulp_distance

CORPUS = TEST / "data/dp/bf16/K16/correct_961"
INSTRUCTION = "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32"


def input_line(request):
    a, b, c = (int(request[key], 16) for key in ("a", "b", "c"))
    words = [f"{value >> (16 * index) & 0xffff:04x}"
             for value in (a, b) for index in range(16)]
    return " ".join([str(request["id"]), *words, f"{c:08x}"]) + "\n"


def probes():
    # A single nonzero B term selects every K position in turn, with C=1.
    cases = []
    for index in range(16):
        a = [0x3f80 + 8 * i for i in range(16)]
        b = [0] * 16
        b[index] = 0xc000
        cases.append(make("bf16", a=a, b=b, c=0x3f800000, ident=-1 - index))
    for ident, positions, exponent in ((-17, (0, 1, 2), -28),
                                       (-18, (0, 4, 8), -28),
                                       (-19, (0, 4, 8), -40)):
        a = [0] * 16
        for position, raw in zip(positions, (0x3f80, 0xbf80, (127 + exponent) << 7)):
            a[position] = raw
        cases.append(make("bf16", a=a, ident=ident))
    return cases


def load_outputs(output):
    pairs = [(int(fields[0]), int(fields[1], 16))
             for fields in map(str.split, output.splitlines())]
    results = dict(pairs)
    if len(results) != len(pairs) or any(not 0 <= bits < 2**32 for bits in results.values()):
        raise ValueError("Invalid results or duplicate request IDs")
    return results


def load_rtl(record, input_hash):
    summaries = json.loads(record.read_text())["runs"]
    comparison = {}
    for local in (28, 29):
        summary = next(row for row in summaries if row["frontend"] == "t8h16q32e96"
                       and row["local_width"] == local and row["global_width"] == 40)
        path = ROOT / summary["report"]
        rtl = next(row for row in json.loads(path.read_text()) if row["name"] == "bf16")
        results_path = ROOT / rtl["results_path"]
        if (rtl["input_sha256"] != input_hash or
                sha256(results_path) != summary["output_sha256"]):
            raise ValueError(f"RTL replay does not match the recorded corpus or outputs: {path}")
        label = f"rtl_{local}_40"
        comparison[label] = (load_outputs(results_path.read_text()), {
            key: summary[key] for key in ("export_id", "run_id", "output_sha256")})
    return comparison


def metrics(ids, bits, math_bits):
    distances = {ident: ulp_distance(bits[ident], math_bits[ident]) for ident in ids}
    histogram = Counter(ulp for ulp in distances.values() if ulp is not None)
    maximum = max(histogram, default=None)
    return {
        "count": len(ids),
        "math_exact": sum(bits[ident] == math_bits[ident] for ident in ids),
        "nonfinite_mismatch": sum(ulp is None for ulp in distances.values()),
        "max_ulp": maximum,
        "ulp_histogram": dict(sorted(histogram.items())),
        "worst_ids": [ident for ident, ulp in distances.items() if maximum and ulp == maximum],
    }


def paired_metrics(ids, rtl_bits, gpu_bits, math_bits):
    counts = Counter()
    for ident in ids:
        rtl_error = ulp_distance(rtl_bits[ident], math_bits[ident])
        gpu_error = ulp_distance(gpu_bits[ident], math_bits[ident])
        if rtl_error is None or gpu_error is None:
            counts["nonfinite_mismatch"] += 1
        elif rtl_error < gpu_error:
            counts["rtl_closer"] += 1
        elif rtl_error > gpu_error:
            counts["gpu_closer"] += 1
        else:
            counts["equal_error"] += 1
    return {key: counts[key] for key in
            ("rtl_closer", "equal_error", "gpu_closer", "nonfinite_mismatch")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="new directory for the experiment")
    parser.add_argument("--rtl-record", type=Path, help="prior DP receipt for a paired comparison")
    args = parser.parse_args()
    if args.out.exists():
        parser.error(f"output directory already exists: {args.out}")
    k, requests = read_inputs(CORPUS / "inputs.txt")
    if k != 16 or any(row["a_datatype"] != DTYPES["bf16"] or
                      row["b_datatype"] != DTYPES["bf16"] or row["c_datatype"] != 0
                      for row in requests):
        raise ValueError("Expected BF16 K16 with FP32 C")
    source = HERE / "bf16_k16.cu"
    input_hash = sha256(CORPUS / "inputs.txt")
    golden_path = CORPUS / "expected.jsonl"
    saved = {row["id"]: int(row["exact_fp32_or_int32"], 16)
             for row in map(json.loads, golden_path.read_text().splitlines())}
    ids = [row["id"] for row in requests]
    probe_requests = probes()
    all_requests = requests + probe_requests
    math_bits = {row["id"]: reference(row, {"k_fp16": k})["bits"] for row in all_requests}
    if {ident: math_bits[ident] for ident in ids} != saved:
        raise ValueError("Independent math differs from the corpus golden")
    rtl = load_rtl(args.rtl_record, input_hash) if args.rtl_record else {}
    with tempfile.TemporaryDirectory(prefix="dp-bf16-mma-") as build:
        binary_path = Path(build) / "bf16_k16"
        subprocess.run(["nvcc", "-O3", "-arch=sm_89", str(source), "-o", str(binary_path)],
                       check=True)
        sass = subprocess.check_output(["cuobjdump", "--dump-sass", str(binary_path)], text=True)
        instructions = re.findall(r"^.*\bHMMA\.[^;]+;", sass, re.MULTILINE)
        if not instructions:
            raise RuntimeError("SM 8.9 binary has no HMMA instruction")
        run = subprocess.run([str(binary_path)], input="".join(map(input_line, all_requests)),
                             text=True, capture_output=True)
        if run.returncode or "RTX 4090" not in run.stderr:
            raise RuntimeError(f"Expected a successful RTX 4090 run: {run.stderr}")
    gpu = load_outputs(run.stdout)
    if gpu.keys() != math_bits.keys() or any(gpu[ident] != math_bits[ident] for ident in range(-16, 0)):
        raise RuntimeError("GPU results did not pass the K-position mapping checks")
    args.out.mkdir(parents=True, exist_ok=False)
    sass_path = args.out / "bf16_k16.sass"
    sass_path.write_text("\n".join(line.rstrip() for line in sass.splitlines()) + "\n")
    methods = {"rtx4090": gpu, **{label: data for label, (data, _) in rtl.items()}}
    with (args.out / "results.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(["id", "math_fp32", *[column for name in methods
                                              for column in (f"{name}_fp32", f"{name}_ulp")]])
        for ident in ids:
            writer.writerow([ident, f"{math_bits[ident]:08x}", *[
                column for data in methods.values()
                for column in (f"{data[ident]:08x}", ulp_distance(data[ident], math_bits[ident]))]])

    segments = json.loads((CORPUS / "manifest.json").read_text())["segments"]
    summary = {
        "device": run.stderr.strip(),
        "nvcc": subprocess.check_output(["nvcc", "--version"], text=True).splitlines()[-2],
        "ptx": INSTRUCTION,
        "hmma_sass": [line.strip() for line in instructions],
        "source_sha256": sha256(source),
        "replay_sha256": sha256(Path(__file__)),
        "sass_sha256": sha256(sass_path),
        "input_sha256": input_hash,
        "golden_sha256": sha256(golden_path),
        "results_sha256": sha256(args.out / "results.csv"),
        "rtl_receipts": {label: metadata for label, (_, metadata) in rtl.items()},
        "corpus": {name: metrics(ids, data, math_bits) for name, data in methods.items()},
        "paired_with_rtx4090": {label: paired_metrics(ids, data, gpu, math_bits)
                                for label, (data, _) in rtl.items()},
        "segments": {segment["dataset"]: {
            name: metrics(ids[segment["start"]:segment["stop"]], data, math_bits)
            for name, data in methods.items()} for segment in segments},
        "k_position_mapping_checks": 16,
        "cancellation_probes": [
            {"id": ident, "math_fp32": f"{math_bits[ident]:08x}", "rtx4090_fp32": f"{gpu[ident]:08x}"}
            for ident in (-17, -18, -19)],
    }
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"device": summary["device"], "corpus": summary["corpus"]}, indent=2))


if __name__ == "__main__":
    main()
