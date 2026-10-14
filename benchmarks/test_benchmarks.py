"""Fast runner regression: statistics, failure handling, and real toolchain IO."""

import csv
import json
import pathlib
import subprocess
import sys
import tempfile

from run_benchmarks import summarize


def main():
    plugin = sys.argv[1]
    runner = pathlib.Path(__file__).with_name("run_benchmarks.py")
    if summarize([1, 2, 9]) != (2, 1):
        raise AssertionError("Incorrect median or MAD")
    invalid = subprocess.run([sys.executable, str(runner), "--samples", "1"], capture_output=True)
    if invalid.returncode == 0:
        raise AssertionError("Invalid sample count was accepted")
    with tempfile.TemporaryDirectory(prefix="optiforge-benchmark-") as directory:
        output = pathlib.Path(directory) / "run"
        command = [sys.executable, str(runner), "--plugin", plugin, "--output", str(output),
                   "--samples", "3", "--warmups", "0", "--size", "32", "--repetitions", "1",
                   "--max-repetitions", "1", "--min-ms", "0", "--workloads", "repeated_arithmetic"]
        subprocess.run(command, check=True)
        with (output / "summary.csv").open() as stream:
            rows = list(csv.DictReader(stream))
        with (output / "samples.csv").open() as stream:
            samples = list(csv.DictReader(stream))
        if len(rows) != 2 or len(samples) != 12 or any(row["correctness"] != "passed" for row in rows):
            raise AssertionError("Incomplete or incorrect report")
        for row in rows:
            measured = {variant: [float(s["elapsed_ms"]) for s in samples
                                 if s["mode"] == row["mode"] and s["variant"] == variant]
                        for variant in ("baseline", "custom")}
            for variant, values in measured.items():
                median, mad = summarize(values)
                if float(row[f"{variant}_median_ms"]) != median or float(row[f"{variant}_mad_ms"]) != mad:
                    raise AssertionError("Summary does not agree with raw samples")
        controlled = next(row for row in rows if row["mode"] == "controlled")
        if int(controlled["custom_ir_instructions"]) >= int(controlled["baseline_ir_instructions"]):
            raise AssertionError("Controlled fixture was not transformed")
        metadata = json.loads((output / "metadata.json").read_text())
        if not metadata["commands"] or not metadata["source_sha256"]:
            raise AssertionError("Missing provenance")
        refused = subprocess.run(command, capture_output=True)
        if refused.returncode == 0:
            raise AssertionError("Runner overwrote an existing report")
    print("Benchmark runner regression passed")


if __name__ == "__main__":
    main()
