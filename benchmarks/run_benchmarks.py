#!/usr/bin/env python3
"""Build matched baseline/custom pairs, verify results, and measure kernels."""

import argparse
import csv
import hashlib
import json
import os
import pathlib
import platform
import random
import re
import statistics
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKLOADS = ("array", "numerical", "nested", "repeated_arithmetic")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(values):
    median = statistics.median(values)
    mad = statistics.median(abs(value - median) for value in values)
    return median, mad


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--llvm-config", default="llvm-config-21")
    parser.add_argument("--plugin", type=pathlib.Path, default=ROOT / "build/lib/OptiForgePlugin.so")
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "results/local")
    parser.add_argument("--samples", type=int, default=9)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--size", type=int, default=32768)
    parser.add_argument("--repetitions", type=int, default=16)
    parser.add_argument("--max-repetitions", type=int, default=16384)
    parser.add_argument("--min-ms", type=float, default=50)
    parser.add_argument("--seed", type=int, default=20261014)
    parser.add_argument("--modes", nargs="+", choices=("controlled", "standard"), default=["controlled", "standard"])
    parser.add_argument("--workloads", nargs="+", choices=WORKLOADS, default=list(WORKLOADS))
    args = parser.parse_args()
    if (args.samples < 3 or args.warmups < 0 or not 1 <= args.size <= (1 << 20)
            or not 1 <= args.repetitions <= args.max_repetitions <= (1 << 24)
            or args.min_ms < 0):
        parser.error("require samples>=3, warmups>=0, size 1..2^20, valid repetitions 1..2^24, min-ms>=0")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error(f"output must be empty to avoid overwriting measurements: {output}")
    output.mkdir(parents=True, exist_ok=True)
    artifacts = output / "artifacts"
    artifacts.mkdir()
    commands = []

    def run(command):
        command = [str(part) for part in command]
        commands.append(command)
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
        if result.returncode:
            raise RuntimeError(f"Command failed: {command}\n{result.stdout}\n{result.stderr}")
        return result

    version = run([args.llvm_config, "--version"]).stdout.strip()
    if version.split(".")[0] != "21":
        raise RuntimeError(f"Expected LLVM 21, got {version}")
    bindir = pathlib.Path(run([args.llvm_config, "--bindir"]).stdout.strip())
    clang, opt = bindir / "clang++", bindir / "opt"
    for tool in (clang, opt):
        banner = run([tool, "--version"]).stdout
        if not re.search(r"version\s+" + re.escape(version) + r"\b", banner):
            raise RuntimeError(f"Version mismatch: {banner}")
    plugin = args.plugin.resolve(strict=True)
    sources = [ROOT / "benchmarks/driver.cpp", pathlib.Path(__file__).resolve()]
    sources += sorted((ROOT / "benchmarks/workloads").iterdir())
    cpu = "unknown"
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        match = re.search(r"^model name\s*:\s*(.+)$", cpuinfo.read_text(), re.M)
        if match:
            cpu = match.group(1)
    metadata = {
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(), "cpu": cpu, "logical_cpus": os.cpu_count(),
        "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
        "python": platform.python_version(), "llvm_version": version,
        "clang_version": run([clang, "--version"]).stdout.strip(),
        "git_base_commit": run(["git", "rev-parse", "HEAD"]).stdout.strip(),
        "git_dirty": bool(run(["git", "status", "--porcelain"]).stdout.strip()),
        "plugin_sha256": digest(plugin),
        "source_sha256": {str(p.relative_to(ROOT)): digest(p) for p in sources},
        "options": {key: str(value) if isinstance(value, pathlib.Path) else value for key, value in vars(args).items()},
        "timing": "C++ steady_clock nanoseconds around kernel only; initialization/digest excluded",
        "instruction_metric": "static LLVM IR instructions after the selected opt pipeline, before backend compilation",
        "preparation": "C++ -O1 -Xclang -disable-llvm-passes; shared mem2reg,loop-simplify,verify",
        "driver_flags": ["-std=c++17", "-O2"],
        "kernel_flags": {"controlled": ["-O0"], "standard": ["-O2"]},
        "standard_pipeline": "default<O2> applied identically before identical -O2 backend compilation",
        "warnings": [], "commands": commands,
    }
    driver_object = artifacts / "driver.o"
    run([clang, "-std=c++17", "-O2", "-c", ROOT / "benchmarks/driver.cpp", "-o", driver_object])
    sample_rows, summary_rows = [], []
    rng = random.Random(args.seed)

    def execute(executable, size, repetitions):
        result = json.loads(run([executable, size, repetitions]).stdout)
        if result["elapsed_ns"] <= 0:
            raise RuntimeError("Nonpositive kernel timing")
        return result

    def signature(result):
        return result["result"], result["memory_digest"]

    def count_instructions(ir):
        result = run([opt, f"-load-pass-plugin={plugin}", "-passes=optiforge-analyze", "-disable-output", ir])
        return sum(int(x) for x in re.findall(r"^Instructions: (\d+)$", result.stderr, re.M))

    for workload in args.workloads:
        cpp = ROOT / f"benchmarks/workloads/{workload}.cpp"
        raw = artifacts / f"{workload}.raw.ll"
        if cpp.exists():
            run([clang, "-std=c++17", "-O1", "-Xclang", "-disable-llvm-passes", "-S", "-emit-llvm", cpp, "-o", raw])
        else:
            raw = ROOT / f"benchmarks/workloads/{workload}.ll"
        prepared = artifacts / f"{workload}.prepared.ll"
        run([opt, "-passes=mem2reg,loop-simplify,verify", "-verify-each", "-S", raw, "-o", prepared])
        for mode in args.modes:
            executables, instructions, object_sizes = {}, {}, {}
            for variant in ("baseline", "custom"):
                stem = artifacts / f"{workload}.{mode}.{variant}"
                ir, obj, exe = pathlib.Path(str(stem) + ".ll"), pathlib.Path(str(stem) + ".o"), pathlib.Path(str(stem) + ".exe")
                pipeline = "optiforge" if variant == "custom" else "verify"
                if mode == "standard":
                    pipeline += ",default<O2>,verify"
                run([opt, f"-load-pass-plugin={plugin}", f"-passes={pipeline}", "-verify-each", "-S", prepared, "-o", ir])
                instructions[variant] = count_instructions(ir)
                run([clang, "-Wno-override-module", "-O0" if mode == "controlled" else "-O2", "-c", ir, "-o", obj])
                run([clang, driver_object, obj, "-o", exe])
                object_sizes[variant] = obj.stat().st_size
                executables[variant] = exe
            # Deterministic edge cases before any timings enter the report.
            for size in (0, 1, 7, 1024):
                for repetitions in (0, 1, 3):
                    pair = [execute(executables[v], size, repetitions) for v in ("baseline", "custom")]
                    if signature(pair[0]) != signature(pair[1]):
                        raise RuntimeError(f"Correctness mismatch: {workload}/{mode}, size={size}, repetitions={repetitions}")
            repetitions = args.repetitions
            while True:
                pair = [execute(executables[v], args.size, repetitions) for v in ("baseline", "custom")]
                if signature(pair[0]) != signature(pair[1]):
                    raise RuntimeError(f"Calibration correctness mismatch: {workload}/{mode}")
                if min(x["elapsed_ns"] for x in pair) >= args.min_ms * 1_000_000:
                    break
                if repetitions == args.max_repetitions:
                    metadata["warnings"].append(f"{workload}/{mode}: calibration cap reached below target duration")
                    break
                repetitions = min(2 * repetitions, args.max_repetitions)
            expected = signature(pair[0])
            for _ in range(args.warmups):
                for variant in executables:
                    if signature(execute(executables[variant], args.size, repetitions)) != expected:
                        raise RuntimeError("Warmup correctness mismatch")
            timings = {"baseline": [], "custom": []}
            for sample in range(args.samples):
                order = ["baseline", "custom"]
                rng.shuffle(order)
                for position, variant in enumerate(order):
                    result = execute(executables[variant], args.size, repetitions)
                    if signature(result) != expected:
                        raise RuntimeError("Timed sample correctness mismatch")
                    elapsed = result["elapsed_ns"] / 1_000_000
                    timings[variant].append(elapsed)
                    sample_rows.append({"workload": workload, "mode": mode, "variant": variant,
                                        "sample": sample, "position": position, "size": args.size,
                                        "repetitions": repetitions, "elapsed_ms": elapsed,
                                        "result": result["result"], "memory_digest": result["memory_digest"]})
            baseline, baseline_mad = summarize(timings["baseline"])
            custom, custom_mad = summarize(timings["custom"])
            row = {"workload": workload, "mode": mode, "samples": args.samples,
                   "size": args.size, "repetitions": repetitions,
                   "baseline_median_ms": baseline, "baseline_mad_ms": baseline_mad,
                   "custom_median_ms": custom, "custom_mad_ms": custom_mad,
                   "speedup": baseline / custom, "runtime_improvement_pct": (baseline - custom) / baseline * 100,
                   "baseline_ir_instructions": instructions["baseline"], "custom_ir_instructions": instructions["custom"],
                   "baseline_object_bytes": object_sizes["baseline"], "custom_object_bytes": object_sizes["custom"],
                   "correctness": "passed"}
            summary_rows.append(row)
            print(f"{workload}/{mode}: {baseline:.3f} -> {custom:.3f} ms, {row['speedup']:.3f}x", flush=True)

    for name, rows in (("samples.csv", sample_rows), ("summary.csv", summary_rows)):
        with (output / name).open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    metadata["finished_utc"] = datetime.now(timezone.utc).isoformat()
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    lines = ["# Measured benchmark run", "", f"LLVM {version}; {cpu}; {metadata['platform']}.", "",
             "Kernel-only median milliseconds; MAD is median absolute deviation. Negative improvement means slowdown.", "",
             "| Workload | Mode | Baseline ms (MAD) | Custom ms (MAD) | Speedup | Improvement | IR instructions |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for row in summary_rows:
        lines.append(f"| {row['workload']} | {row['mode']} | {row['baseline_median_ms']:.3f} ({row['baseline_mad_ms']:.3f}) | "
                     f"{row['custom_median_ms']:.3f} ({row['custom_mad_ms']:.3f}) | {row['speedup']:.3f}x | "
                     f"{row['runtime_improvement_pct']:+.2f}% | {row['baseline_ir_instructions']} -> {row['custom_ir_instructions']} |")
    lines += ["", "Controlled mode isolates custom passes on shared canonicalized IR with -O0 backend compilation.",
              "Standard mode uses the same default<O2> pipeline and -O2 backend settings for both variants.",
              "These are local WSL measurements, not evidence of outperforming production compilers.",
              "Static IR counts are not dynamic or machine instruction counts. Binary sizes are object file bytes.",
              "See samples.csv, metadata.json, and docs/benchmarking.md for raw samples and limitations."]
    lines += ["", *metadata["warnings"]]
    (output / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Reports: {output}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
